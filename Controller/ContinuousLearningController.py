# Controller/ContinuousLearningController.py
from PySide6.QtCore import QObject, Signal, Slot, Property, QThread, QMutex
from PySide6.QtWidgets import QVBoxLayout, QFileDialog
from typing import Dict, Any, List
import logging
import sqlite3
import pandas as pd
import numpy as np
from pathlib import Path
import joblib
from matplotlib.figure import Figure
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
import json
import time
import sys

# 导入数据处理器
from .DataProcessor import DataProcessor

# 导入实际的模型
import sys
sys.path.append(str(Path(__file__).parent.parent))
from models.svrTDH import SVRPredictor as TDHPredictor, SVRInput as TDHInput
from models.svrQF import QFPredictor, QFInput
from models.keraGLR import GLRPredictor, GLRInput
from models.ModelFeatureConfig import ModelFeatureConfig

logger = logging.getLogger(__name__)

class ModelTrainingThread(QThread):
    """模型训练线程类"""
    # 训练线程信号
    trainingProgressUpdated = Signal(float, dict)
    trainingCompleted = Signal(str, dict)
    trainingError = Signal(str)
    trainingLogUpdated = Signal(str)  # 新增：训练日志更新信号
    lossDataUpdated = Signal(dict)   # 新增：损失数据更新信号
    
    def __init__(self, project_id, table_names, features, target_label, task_type, db_path, feature_mapping=None, training_params=None):
        super().__init__()
        self.project_id = project_id
        self.table_names = table_names
        self.features = features
        self.target_label = target_label
        self.task_type = task_type
        self.db_path = db_path
        self.feature_mapping = feature_mapping or {}
        self.training_params = training_params or {}
        self.model_info = None
        self.model_name = None
        
        # 自定义日志处理器，用于捕获模型训练日志
        self.log_handler = None
        self.setup_log_capture()
    
    def setup_log_capture(self):
        """设置日志捕获"""
        import logging
        from loguru import logger
        
        class LogHandler(logging.Handler):
            def __init__(self, signal_emitter):
                super().__init__()
                self.signal_emitter = signal_emitter
                
            def emit(self, record):
                log_entry = self.format(record)
                if self.signal_emitter:
                    self.signal_emitter.trainingLogUpdated.emit(log_entry)
        
        # 创建处理器并添加到logger
        self.log_handler = LogHandler(self)
        self.log_handler.setFormatter(logging.Formatter('%(asctime)s | %(levelname)s | %(name)s:%(funcName)s:%(lineno)d - %(message)s'))
        
        # 添加到Python标准logging
        root_logger = logging.getLogger()
        root_logger.addHandler(self.log_handler)
        
        # 为loguru创建一个拦截器
        class LoguruInterceptHandler(logging.Handler):
            def emit(self, record):
                try:
                    level = logger.level(record.levelname).name
                except ValueError:
                    level = record.levelno
                
                frame, depth = logging.currentframe(), 2
                while frame.f_code.co_filename == logging.__file__:
                    frame = frame.f_back
                    depth += 1
                
                # 发送到我们的信号
                if hasattr(self, 'thread_ref') and self.thread_ref:
                    message = f"{record.levelname} | {record.name}:{record.funcName}:{record.lineno} - {record.getMessage()}"
                    self.thread_ref.trainingLogUpdated.emit(message)
        
        self.loguru_handler = LoguruInterceptHandler()
        self.loguru_handler.thread_ref = self
        
        # 添加loguru sink来捕获loguru日志
        logger.add(self.emit_log_message, format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level} | {name}:{function}:{line} - {message}")
    
    def emit_log_message(self, message):
        """发送日志消息到UI"""
        # 清理消息格式
        clean_message = str(message).strip()
        if clean_message:
            self.trainingLogUpdated.emit(clean_message)
    
    def cleanup_log_capture(self):
        """清理日志捕获"""
        if self.log_handler:
            logging.getLogger().removeHandler(self.log_handler)
            self.log_handler = None
        
    def run(self):
        """执行训练任务"""
        try:
            import sqlite3
            import pandas as pd
            
            # 合并多个表的数据
            all_dfs = []
            conn = sqlite3.connect(self.db_path)
            
            for table_name in self.table_names:
                try:
                    df = pd.read_sql_query(f"SELECT * FROM \"{table_name}\"", conn)
                    if not df.empty:
                        df['data_source'] = table_name
                        all_dfs.append(df)
                        logger.info(f"从表 {table_name} 加载了 {len(df)} 条记录")
                except Exception as e:
                    logger.warning(f"加载表 {table_name} 失败: {e}")
                    continue
            
            conn.close()
            
            if not all_dfs:
                self.trainingError.emit("没有有效的数据表可用于训练")
                return
            
            # 合并所有数据
            df = pd.concat(all_dfs, ignore_index=True)
            logger.info(f"总共合并了 {len(df)} 条记录")
            
            # 应用特征映射（如果有）
            mapped_features = []
            if self.feature_mapping:
                logger.info("应用特征映射:")
                # 只使用已映射的特征
                for model_feature, user_feature in self.feature_mapping.items():
                    if user_feature and user_feature.strip():  # 确保映射值不为空
                        mapped_features.append(user_feature)
                        logger.info(f"  模型特征 {model_feature} → 用户数据 {user_feature}")
                
                if not mapped_features:
                    logger.warning("特征映射为空，使用用户选择的特征")
                    mapped_features = self.features
            else:
                mapped_features = self.features
                logger.info("未使用特征映射，直接使用用户选择的特征")
            
            # 检查字段是否存在（使用映射后的特征）
            required_cols = mapped_features + [self.target_label]
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                self.trainingError.emit(f"数据表中缺少字段: {missing_cols}")
                return
            
            logger.info(f"原始数据记录数: {len(df)}")
            logger.info(f"最终使用特征: {mapped_features}")
            
            # 使用数据处理器清理数据（使用映射后的特征）
            try:
                data_processor = DataProcessor(remove_outliers=True, outlier_factor=1.5)
                X, y, cleaning_info = data_processor.clean_data(df, mapped_features, self.target_label)
                
                # 记录清理信息
                logger.info(f"数据清理信息: {cleaning_info}")
                for step in cleaning_info["cleaning_steps"]:
                    logger.info(f"  - {step}")
                    
                if cleaning_info["final_count"] < 2:
                    self.trainingError.emit(f"数据清理后样本数量不足({cleaning_info['final_count']})，无法进行训练")
                    return
                    
            except Exception as e:
                error_msg = f"数据清理失败: {str(e)}"
                logger.error(error_msg)
                self.trainingError.emit(error_msg)
                return
            
            # 发送进度更新
            self.trainingProgressUpdated.emit(20.0, {"status": "数据准备完成"})
            
            # 根据任务类型创建相应的模型实例
            model_instance = None
            try:
                if self.task_type == "head":
                    # TDH预测任务
                    from models.svrTDH import SVRPredictor
                    model_instance = SVRPredictor(X, y, test_size=0.2)
                    self.trainingProgressUpdated.emit(40.0, {"status": "开始TDH模型训练"})
                    train_mape, test_mape, y_test_actual, y_test_pred, _ = model_instance.train()
                    
                elif self.task_type == "production":
                    # QF产量预测任务
                    from models.svrQF import QFPredictor
                    model_instance = QFPredictor(X, y, test_size=0.2)
                    self.trainingProgressUpdated.emit(40.0, {"status": "开始QF模型训练"})
                    train_mape, test_mape, y_test_actual, y_test_pred, _ = model_instance.train()
                    
                elif self.task_type == "glr":
                    # GLR气液比预测任务
                    from models.keraGLR import GLRPredictor
                    model_instance = GLRPredictor(X, y, test_size=0.2)
                    self.trainingProgressUpdated.emit(40.0, {"status": "开始GLR模型训练"})
                    
                    # 连接信号
                    model_instance.lossUpdated.connect(self.on_loss_updated)
                    model_instance.trainingProgress.connect(self.on_training_progress)
                    
                    # 设置训练参数（如果有的话）
                    training_params = getattr(self, 'training_params', {})
                    learning_rate = training_params.get('learning_rate', 0.001)
                    epochs = training_params.get('epochs', 1000)
                    batch_size = training_params.get('batch_size', 48)
                    patience = training_params.get('patience', 100)
                    
                    model_instance.set_training_params(
                        learning_rate=learning_rate,
                        epochs=epochs,
                        batch_size=batch_size,
                        patience=patience
                    )
                    
                    # GLR模型训练流程
                    train_mape, test_mape = model_instance.train()
                    y_test_actual = model_instance.y_test
                    y_test_pred = model_instance.model.predict(model_instance.X_test).flatten()
                    
                else:
                    self.trainingError.emit(f"未知任务类型: {self.task_type}")
                    return
                
                self.trainingProgressUpdated.emit(80.0, {"status": "计算评估指标"})
                
                # 计算R²和MSE指标
                from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
                
                if self.task_type in ["head", "production"]:
                    train_pred = model_instance.model.predict(model_instance.X_train_scaled)
                    train_r2 = r2_score(model_instance.y_train, train_pred)
                    train_mse = mean_squared_error(model_instance.y_train, train_pred)
                    train_mae = mean_absolute_error(model_instance.y_train, train_pred)
                elif self.task_type == "glr":
                    train_pred = model_instance.model.predict(model_instance.X_train).flatten()
                    train_r2 = r2_score(model_instance.y_train, train_pred)
                    train_mse = mean_squared_error(model_instance.y_train, train_pred)
                    train_mae = mean_absolute_error(model_instance.y_train, train_pred)
                
                test_r2 = r2_score(y_test_actual, y_test_pred)
                test_mse = mean_squared_error(y_test_actual, y_test_pred)
                test_mae = mean_absolute_error(y_test_actual, y_test_pred)
                
                # 计算MAPE指标 (使用自定义MAPE避免除零错误)
                def custom_mape(y_true, y_pred):
                    """自定义MAPE计算，处理零值"""
                    import numpy as np
                    # 替换零值为非零均值
                    nonzero_mask = y_true != 0
                    if np.any(nonzero_mask):
                        label_mean = np.mean(y_true[nonzero_mask])
                    else:
                        label_mean = 1  # 如果所有值都是零，使用1作为默认值
                    
                    y_true_adj = np.where(y_true == 0, label_mean, y_true)
                    return np.mean(np.abs((y_true_adj - y_pred) / y_true_adj)) * 100
                
                if self.task_type in ["head", "production"]:
                    train_mape = custom_mape(model_instance.y_train, train_pred)
                elif self.task_type == "glr":
                    train_mape = custom_mape(model_instance.y_train, train_pred)
                
                test_mape = custom_mape(y_test_actual, y_test_pred)
                
                model = model_instance.model
                scaler = model_instance.scaler
                
            except Exception as model_error:
                logger.exception(f"模型训练失败: {model_error}")
                self.trainingError.emit(f"模型训练失败: {str(model_error)}")
                return
            
            # 生成R²图数据
            if self.task_type in ["head", "production"]:
                r2_plot_data = {
                    "actual_train": model_instance.y_train.tolist(),
                    "predicted_train": model_instance.model.predict(model_instance.X_train_scaled).flatten().tolist(),
                    "actual_test": y_test_actual.tolist(),
                    "predicted_test": y_test_pred.tolist()
                }
            elif self.task_type == "glr":
                r2_plot_data = {
                    "actual_train": model_instance.y_train.tolist(),
                    "predicted_train": model_instance.model.predict(model_instance.X_train).flatten().tolist(),
                    "actual_test": y_test_actual.tolist(),
                    "predicted_test": y_test_pred.tolist()
                }
            
            # 生成误差图数据 (同样的数据，用于误差图显示)
            error_plot_data = r2_plot_data.copy()
            
            # 生成模型名称
            tables_str = "_".join(self.table_names[:2])
            self.model_name = f"model_{tables_str}_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}"
            
            # 保存模型信息
            self.model_info = {
                "model": model,
                "scaler": scaler,
                "model_instance": model_instance,
                "task_type": self.task_type,
                "features": mapped_features,  # 保存映射后的特征
                "original_features": self.features,  # 保存原始特征映射关系
                "feature_mapping": self.feature_mapping,  # 保存特征映射
                "target": self.target_label,
                "type": "SVR" if not self.task_type or self.task_type not in ["head", "production", "glr"] else self.task_type.upper(),
                "table_names": self.table_names,
                "train_mse": train_mse,
                "train_r2": train_r2,
                "train_mae": train_mae,
                "train_mape": train_mape,
                "test_mse": test_mse,
                "test_r2": test_r2,
                "test_mae": test_mae,
                "test_mape": test_mape,
                "r2_plot_data": r2_plot_data,
                "error_plot_data": error_plot_data,
                "trained_at": pd.Timestamp.now().isoformat()
            }
            
            # 生成训练结果
            result = {
                "model_name": self.model_name,
                "model_type": "SVR",
                "table_names": self.table_names,
                "train_mse": train_mse,
                "train_r2": train_r2,
                "train_mae": train_mae,
                "train_mape": train_mape,
                "test_mse": test_mse,
                "test_r2": test_r2,
                "test_mae": test_mae,
                "test_mape": test_mape,
                "r2_plot_data": r2_plot_data,
                "error_plot_data": error_plot_data,
                "features": self.features,
                "target": self.target_label,
                "training_time": "训练完成"
            }
            
            self.trainingProgressUpdated.emit(100.0, {"status": "训练完成"})
            self.trainingCompleted.emit(self.model_name, result)
            
        except Exception as e:
            self.trainingError.emit(f"模型训练失败: {str(e)}")
        finally:
            # 清理日志捕获
            self.cleanup_log_capture()

    def on_loss_updated(self, loss_data):
        """处理损失数据更新"""
        logger.info(f"=== ModelTrainingThread: 接收到损失数据 ===")
        logger.info(f"损失数据: {loss_data}")
        
        try:
            self.lossDataUpdated.emit(loss_data)
            logger.info("损失数据信号发射成功")
        except Exception as e:
            logger.error(f"发射损失数据信号失败: {e}")

    def on_training_progress(self, progress):
        """处理训练进度更新"""
        self.trainingProgressUpdated.emit(progress, {"status": f"训练进行中... {progress:.1f}%"})

class ContinuousLearningController(QObject):
    """持续学习控制器"""
    
    # 信号定义
    taskSelectionChanged = Signal(int)  # 任务选择变化
    phaseChanged = Signal(str)          # 阶段变化
    predictionStarted = Signal(int)     # 开始预测
    predictionCompleted = Signal(int, dict)  # 预测完成
    predictionFailed = Signal(int, str)      # 预测失败
    dataPreparationStarted = Signal(int)     # 数据准备开始
    dataPreparationCompleted = Signal(int, dict)  # 数据准备完成
    trainingStarted = Signal(int)            # 训练开始
    trainingCompleted = Signal(str, dict)    # 训练完成 - 修改为字符串类型的模型名
    evaluationStarted = Signal(int)          # 评估开始
    evaluationCompleted = Signal(int, dict)  # 评估完成
    
    # 新增信号 - 深度学习可视化
    lossDataUpdated = Signal(dict)           # 损失数据更新
    trainingProgressUpdated = Signal(float, dict)  # 训练进度更新  
    trainingLogUpdated = Signal(str)         # 训练日志更新
    
    # 新增信号 - 数据管理
    dataListUpdated = Signal(list)           # 数据列表更新
    dataLoaded = Signal(dict)                # 数据加载完成
    dataAdded = Signal(dict)                 # 数据添加
    dataUpdated = Signal(dict)               # 数据更新
    dataDeleted = Signal(int)                # 数据删除
    
    # 新增信号 - 模型管理
    modelListUpdated = Signal(list)          # 模型列表更新
    trainingProgressUpdated = Signal(float, dict)  # 训练进度更新
    trainingProgressChanged = Signal(float)  # 训练进度变化 (兼容性)
    trainingError = Signal(str)              # 训练错误
    trainingLogUpdated = Signal(str)         # 训练日志更新
    modelSaved = Signal(str, str)            # 模型保存完成 (模型名称, 保存路径)
    testResultsUpdated = Signal(dict)        # 测试结果更新
    testProgressUpdated = Signal(float)      # 测试进度更新
    testLogUpdated = Signal(str)             # 测试日志更新
    
    # 数据库信号
    tablesListUpdated = Signal(list)         # 数据表列表更新
    fieldsListUpdated = Signal(list)         # 字段列表更新
    
    def __init__(self):
        super().__init__()
        self._selected_task = -1
        self._current_phase = "task_selection"  # task_selection, data_management, model_training, model_testing
        self._task_names = {
            0: {"zh": "扬程预测", "en": "Head Prediction"},
            1: {"zh": "产量预测", "en": "Production Prediction"}, 
            2: {"zh": "气液比预测", "en": "Gas-Liquid Ratio Prediction"}
        }
        self._ml_service = None
        self._project_id = -1
        self._db_path = "data/oil_analysis.db"
        
        # 训练参数 - 用于深度学习模型
        self._training_params = {
            'learning_rate': 0.001,
            'epochs': 1000,
            'batch_size': 48,
            'patience': 100
        }
        
        # 数据管理11
        self._training_data = []
        self._test_data = []
        self._selected_tables = []
        self._selected_features = []
        self._target_label = ""
        
        # 模型管理
        self._models = {}
        self._current_model = None
        self._training_history = {}
        self._test_results = {}
        
        # Excel文件路径
        self._excel_file_path = ""
        
        # 训练线程
        self._training_thread = None
        self._mutex = QMutex()
        
    # ================== 任务选择功能 ==================
    
    @Slot(int)
    def setSelectedTask(self, task_id):
        """设置选择的任务"""
        if task_id in self._task_names:
            self._selected_task = task_id
            self.taskSelectionChanged.emit(task_id)
            logger.info(f"选择任务: {self._task_names[task_id]['zh']}")
    
    @Slot(result=int)
    def getSelectedTask(self):
        """获取当前选择的任务"""
        return self._selected_task
    
    @Slot(result=list)
    def getTaskList(self):
        """获取任务列表"""
        return [
            {"id": 0, "name": "扬程预测", "name_en": "Head Prediction"},
            {"id": 1, "name": "产量预测", "name_en": "Production Prediction"},
            {"id": 2, "name": "气液比预测", "name_en": "Gas-Liquid Ratio Prediction"}
        ]
    
    # ================== 训练参数设置功能 ==================
    
    @Slot(float, int, int, int)
    def setTrainingParams(self, learning_rate, epochs, batch_size, patience):
        """设置训练参数"""
        self._training_params = {
            'learning_rate': learning_rate,
            'epochs': epochs,
            'batch_size': batch_size,
            'patience': patience
        }
        logger.info(f"训练参数已更新: lr={learning_rate}, epochs={epochs}, batch_size={batch_size}, patience={patience}")
    
    @Slot(result='QVariant')
    def getTrainingParams(self):
        """获取当前训练参数"""
        return self._training_params
    
    # ================== Excel文件上传功能 ==================
    
    @Slot(str)
    def setDataFilePath(self, file_path):
        """设置数据文件路径"""
        self._excel_file_path = file_path
        logger.info(f"设置数据文件路径: {file_path}")
    
    @Slot(str)
    def setExcelFilePath(self, file_path):
        """设置Excel文件路径（保持向后兼容）"""
        self.setDataFilePath(file_path)
    
    @Slot(result=dict)
    @Slot(str, result=dict)
    def uploadDataFileToDatabase(self, custom_table_name=""):
        """上传数据文件（Excel或CSV）到数据库"""
        try:
            if not self._excel_file_path:
                return {"success": False, "error": "未选择数据文件"}
            
            file_path = self._excel_file_path
            
            # 根据文件扩展名选择读取方法
            if file_path.lower().endswith('.csv'):
                df = pd.read_csv(file_path)
            elif file_path.lower().endswith(('.xlsx', '.xls')):
                df = pd.read_excel(file_path)
            else:
                return {"success": False, "error": "不支持的文件格式，请选择Excel(.xlsx/.xls)或CSV(.csv)文件"}
            
            # 确定表名
            if custom_table_name.strip():
                # 使用用户提供的表名
                table_name = custom_table_name.strip()
            else:
                # 生成默认表名
                import time
                timestamp = int(time.time())
                table_name = f"data_upload_{timestamp}"
            
            # 连接数据库
            conn = sqlite3.connect(self._db_path)
            
            # 保存到数据库
            df.to_sql(table_name, conn, if_exists='replace', index=False)
            conn.close()
            
            logger.info(f"数据文件成功上传到表: {table_name}")
            self.tablesListUpdated.emit(self.getAvailableTables())
            
            return {
                "success": True, 
                "table_name": table_name,
                "records": len(df),
                "columns": list(df.columns)
            }
            
        except Exception as e:
            error_msg = f"数据文件上传失败: {str(e)}"
            logger.error(error_msg)
            return {"success": False, "error": error_msg}
    
    @Slot(result=dict)
    def uploadExcelToDatabase(self):
        """上传Excel文件到数据库（保持向后兼容）"""
        return self.uploadDataFileToDatabase()
    
    # ================== 数据表管理功能 ==================
        
    @Property(str, notify=phaseChanged)
    def currentPhase(self):
        """当前阶段"""
        return self._current_phase
        
    @currentPhase.setter
    def currentPhase(self, phase):
        if self._current_phase != phase:
            self._current_phase = phase
            self.phaseChanged.emit(phase)
            logger.info(f"阶段切换到: {phase}")
        
    @Property(int, notify=taskSelectionChanged)
    def selectedTask(self):
        """当前选择的任务"""
        return self._selected_task
        
    @selectedTask.setter 
    def selectedTask(self, task_id):
        if self._selected_task != task_id:
            self._selected_task = task_id
            self.taskSelectionChanged.emit(task_id)
            
    @Slot(int)
    def selectTask(self, task_id):
        """选择预测任务"""
        if task_id in self._task_names:
            self.selectedTask = task_id
            logger.info(f"选择预测任务: {self.getTaskName(task_id, True)}")
        else:
            logger.warning(f"无效的任务ID: {task_id}")
            
    @Slot(int, bool, result=str)
    def getTaskName(self, task_id, is_chinese=True):
        """获取任务名称"""
        if task_id in self._task_names:
            lang = "zh" if is_chinese else "en"
            return self._task_names[task_id][lang]
        return ""
        
    @Slot(result=list)
    def getAvailableTasks(self):
        """获取可用任务列表"""
        tasks = []
        for task_id, names in self._task_names.items():
            tasks.append({
                "id": task_id,
                "name_zh": names["zh"],
                "name_en": names["en"]
            })
        return tasks
        
    @Slot(str)
    def setPhase(self, phase):
        """设置当前阶段"""
        self.currentPhase = phase
        
    @Slot(int)
    def setProjectId(self, project_id):
        """设置项目ID"""
        self._project_id = project_id
        logger.info(f"设置项目ID: {project_id}")
        
    @Slot()
    def startDataPreparation(self):
        """开始数据准备"""
        if self._selected_task < 0:
            logger.warning("未选择任务，无法开始数据准备")
            return
            
        try:
            self.dataPreparationStarted.emit(self._selected_task)
            logger.info(f"开始数据准备，任务类型: {self._selected_task}")
            
            # 模拟数据准备过程
            result = self._prepare_data()
            self.dataPreparationCompleted.emit(self._selected_task, result)
            
        except Exception as e:
            error_msg = f"数据准备失败: {str(e)}"
            logger.error(error_msg)
            
    @Slot()
    def startTraining(self):
        """开始模型训练"""
        if self._selected_task < 0:
            logger.warning("未选择任务，无法开始训练")
            return
            
        try:
            self.trainingStarted.emit(self._selected_task)
            logger.info(f"开始模型训练，任务类型: {self._selected_task}")
            
            # 模拟训练过程
            result = self._train_model()
            
            # 生成模型名称 - 应该与实际训练保持一致
            import time
            timestamp = int(time.time())
            current_time = time.strftime("%Y%m%d_%H%M%S", time.localtime())
            model_name = f"model_data_upload_{timestamp}_{current_time}"
            
            self.trainingCompleted.emit(model_name, result)
            
        except Exception as e:
            error_msg = f"模型训练失败: {str(e)}"
            logger.error(error_msg)
    
    @Slot(int, list, list, str, str, dict)
    def startModelTrainingWithData(self, project_id, table_names, features, target_label, task_type="", feature_mapping=None):
        """使用指定数据开始模型训练 - 使用多线程防止界面卡死"""
        try:
            # 如果有正在运行的训练线程，先停止它
            if self._training_thread and self._training_thread.isRunning():
                self._training_thread.quit()
                self._training_thread.wait()
            
            # 创建新的训练线程
            self._training_thread = ModelTrainingThread(
                project_id, table_names, features, target_label, task_type, self._db_path, feature_mapping, self._training_params
            )
            
            # 连接信号
            self._training_thread.trainingProgressUpdated.connect(self.trainingProgressUpdated.emit)
            self._training_thread.trainingCompleted.connect(self._on_training_completed)
            self._training_thread.trainingError.connect(self.trainingError.emit)
            self._training_thread.trainingLogUpdated.connect(self.trainingLogUpdated.emit)  # 连接日志信号
            
            # 连接损失数据信号，增加调试信息
            def on_loss_data_relay(loss_data):
                logger.info(f"=== ContinuousLearningController: 中继损失数据 ===")
                logger.info(f"接收到的损失数据: {loss_data}")
                try:
                    self.lossDataUpdated.emit(loss_data)
                    logger.info("损失数据信号发射到UI成功")
                except Exception as e:
                    logger.error(f"发射损失数据信号到UI失败: {e}")
            
            self._training_thread.lossDataUpdated.connect(on_loss_data_relay)  # 连接损失数据信号
            
            # 启动训练
            self.trainingStarted.emit(project_id)
            self._training_thread.start()
            
        except Exception as e:
            error_msg = f"启动模型训练失败: {str(e)}"
            logger.error(error_msg)
            self.trainingError.emit(error_msg)
            
    @Slot()
    def startEvaluation(self):
        """开始模型评估"""
        if self._selected_task < 0:
            logger.warning("未选择任务，无法开始评估")
            return
            
        try:
            self.evaluationStarted.emit(self._selected_task)
            logger.info(f"开始模型评估，任务类型: {self._selected_task}")
            
            # 模拟评估过程
            result = self._evaluate_model()
            self.evaluationCompleted.emit(self._selected_task, result)
            
        except Exception as e:
            error_msg = f"模型评估失败: {str(e)}"
            logger.error(error_msg)
            
    def _prepare_data(self):
        """数据准备实现"""
        logger.info("执行数据准备")
        
        # 模拟数据准备结果
        result = {
            "task_type": self._selected_task,
            "phase": "data_preparation",
            "data_count": 1000,
            "feature_count": 15,
            "train_split": 0.8,
            "test_split": 0.2,
            "data_quality": "good",
            "preprocessing_steps": [
                "数据清洗",
                "特征工程", 
                "数据标准化",
                "训练集分割"
            ]
        }
        return result
        
    def _train_model(self):
        """模型训练实现"""
        logger.info("执行模型训练")
        
        # 模拟训练结果
        result = {
            "task_type": self._selected_task,
            "phase": "training",
            "model_type": "SVR" if self._selected_task == 0 else "Neural Network",
            "training_accuracy": 0.92,
            "validation_accuracy": 0.87,
            "epochs": 100,
            "best_epoch": 85,
            "training_time": "15分钟",
            "hyperparameters": {
                "learning_rate": 0.001,
                "batch_size": 32,
                "regularization": 0.01
            }
        }
        return result
        
    def _evaluate_model(self):
        """模型评估实现"""
        logger.info("执行模型评估")
        
        # 模拟评估结果
        result = {
            "task_type": self._selected_task,
            "phase": "evaluation", 
            "test_accuracy": 0.85,
            "mse": 0.12,
            "mae": 0.08,
            "r2_score": 0.88,
            "cross_validation_score": 0.84,
            "feature_importance": [
                {"feature": "地层压力", "importance": 0.25},
                {"feature": "产液量", "importance": 0.20},
                {"feature": "井深", "importance": 0.18},
                {"feature": "温度", "importance": 0.15},
                {"feature": "含水率", "importance": 0.12}
            ],
            "model_performance": "优秀",
            "recommendations": [
                "模型性能良好，可以部署使用",
                "建议收集更多数据以进一步提升精度",
                "定期重新训练以保持模型性能"
            ]
        }
        return result
            
    def _predict_head(self, parameters):
        """扬程预测"""
        # 这里调用MLPredictionService进行扬程预测
        logger.info("执行扬程预测")
        
        # 模拟预测结果
        result = {
            "task_type": 0,
            "task_name": "扬程预测", 
            "predicted_head": 2160.0,
            "confidence": 0.85,
            "parameters": parameters,
            "method": "ML_SVR_Model"
        }
        return result
        
    def _predict_production(self, parameters):
        """产量预测"""
        logger.info("执行产量预测")
        
        # 模拟预测结果
        result = {
            "task_type": 1,
            "task_name": "产量预测",
            "predicted_production": 1000.0,
            "confidence": 0.82,
            "parameters": parameters,
            "method": "ML_Neural_Network"
        }
        return result
        
    def _predict_gas_liquid_ratio(self, parameters):
        """气液比预测"""
        logger.info("执行气液比预测")
        
        # 模拟预测结果  
        result = {
            "task_type": 2,
            "task_name": "气液比预测",
            "predicted_glr": 5.6,
            "confidence": 0.78,
            "parameters": parameters,
            "method": "ML_Random_Forest"
        }
        return result
        
    def set_ml_service(self, ml_service):
        """设置ML预测服务"""
        self._ml_service = ml_service
        
    @Slot()
    def resetTask(self):
        """重置任务选择"""
        self.selectedTask = -1
        
    @Slot(result=bool)
    def hasTaskSelected(self):
        """是否已选择任务"""
        return self._selected_task >= 0
        
    # ================== 数据管理功能 ==================
    
    @Slot(result=list)
    def getAvailableTables(self):
        """获取数据库中的可用表（只返回data或test开头的表）"""
        try:
            logger.info("getAvailableTables called")
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            all_tables = [row[0] for row in cursor.fetchall()]
            conn.close()
            
            # 过滤只保留data或test开头的表
            filtered_tables = [table for table in all_tables if table.startswith('data') or table.startswith('test')]
            
            logger.info(f"Found {len(all_tables)} total tables, {len(filtered_tables)} filtered tables: {filtered_tables}")
            self.tablesListUpdated.emit(filtered_tables)
            return filtered_tables
        except Exception as e:
            logger.error(f"获取数据表失败: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def getTableFields(self, table_name):
        """获取指定表的字段"""
        try:
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            cursor.execute(f"PRAGMA table_info({table_name})")
            fields = [row[1] for row in cursor.fetchall()]
            conn.close()
            
            self.fieldsListUpdated.emit(fields)
            return fields
        except Exception as e:
            logger.error(f"获取表字段失败: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def getModelExpectedFeatures(self, task_type):
        """获取指定任务类型的模型期望特征"""
        try:
            return ModelFeatureConfig.get_expected_features(task_type)
        except Exception as e:
            logger.error(f"获取模型期望特征失败: {str(e)}")
            return []
    
    @Slot(str, result=list)
    def getModelExpectedTargets(self, task_type):
        """获取指定任务类型的可能目标变量"""
        try:
            return ModelFeatureConfig.get_expected_targets(task_type)
        except Exception as e:
            logger.error(f"获取模型期望目标失败: {str(e)}")
            return []
    
    @Slot(result=list)
    def getAllSupportedTasks(self):
        """获取所有支持的任务类型"""
        try:
            return ModelFeatureConfig.get_all_tasks()
        except Exception as e:
            logger.error(f"获取支持的任务类型失败: {str(e)}")
            return []
    
    @Slot(result=list)
    def getTrainingTables(self):
        """获取训练数据表（data开头的表）"""
        try:
            all_tables = self.getAvailableTables()
            training_tables = [t for t in all_tables if t.startswith('data_')]
            return training_tables
        except Exception as e:
            logger.error(f"获取训练数据表失败: {str(e)}")
            return []
    
    @Slot(result=list)
    def getTestTables(self):
        """获取测试数据表（test开头的表）"""
        try:
            all_tables = self.getAvailableTables()
            test_tables = [t for t in all_tables if t.startswith('test_')]
            return test_tables
        except Exception as e:
            logger.error(f"获取测试数据表失败: {str(e)}")
            return []
    
    @Slot(str)
    def loadTableFields(self, table_name):
        """加载表字段并发射信号"""
        fields = self.getTableFields(table_name)
        self.fieldsListUpdated.emit(fields)
    
    @Slot(list)
    def setSelectedTables(self, tables):
        """设置选择的数据表"""
        self._selected_tables = tables
        logger.info(f"选择数据表: {tables}")
    
    @Slot(list)
    def setSelectedFeatures(self, features):
        """设置选择的输入特征"""
        self._selected_features = features
        logger.info(f"选择输入特征: {features}")
    
    @Slot(str)
    def setTargetLabel(self, label):
        """设置预测标签"""
        self._target_label = label
        logger.info(f"设置预测标签: {label}")
    
    @Slot(result=dict)
    def loadDataFromTables(self):
        """从选择的数据表中加载数据"""
        try:
            if not self._selected_tables:
                raise ValueError("未选择数据表")
                
            conn = sqlite3.connect(self._db_path)
            combined_data = None
            
            for table in self._selected_tables:
                df = pd.read_sql_query(f"SELECT * FROM \"{table}\"", conn)
                if combined_data is None:
                    combined_data = df
                else:
                    combined_data = pd.concat([combined_data, df], ignore_index=True)
            
            conn.close()
            
            # 检查字段一致性
            required_fields = set(self._selected_features + [self._target_label])
            available_fields = set(combined_data.columns)
            
            if not required_fields.issubset(available_fields):
                missing_fields = required_fields - available_fields
                raise ValueError(f"缺少字段: {missing_fields}")
            
            # 数据预处理
            data_info = {
                "total_records": len(combined_data),
                "feature_count": len(self._selected_features),
                "target_label": self._target_label,
                "data_shape": combined_data.shape,
                "missing_values": combined_data.isnull().sum().to_dict(),
                "data_types": combined_data.dtypes.to_dict()
            }
            
            # 保存数据
            self._training_data = combined_data
            self.dataListUpdated.emit([data_info])
            self.dataLoaded.emit(data_info)  # 发出新的信号
            
            return data_info
            
        except Exception as e:
            error_msg = f"加载数据失败: {str(e)}"
            logger.error(error_msg)
            return {"error": error_msg}
    
    @Slot(dict)
    def addTrainingData(self, data_record):
        """添加训练数据记录"""
        try:
            # 这里可以实现数据添加逻辑
            logger.info(f"添加训练数据: {data_record}")
            self.dataAdded.emit(data_record)
        except Exception as e:
            logger.error(f"添加数据失败: {str(e)}")
    
    @Slot(int, dict)
    def updateTrainingData(self, record_id, data_record):
        """更新训练数据记录"""
        try:
            # 这里可以实现数据更新逻辑
            logger.info(f"更新训练数据ID {record_id}: {data_record}")
            self.dataUpdated.emit(data_record)
        except Exception as e:
            logger.error(f"更新数据失败: {str(e)}")
    
    @Slot(int)
    def deleteTrainingData(self, record_id):
        """删除训练数据记录"""
        try:
            # 这里可以实现数据删除逻辑
            logger.info(f"删除训练数据ID: {record_id}")
            self.dataDeleted.emit(record_id)
        except Exception as e:
            logger.error(f"删除数据失败: {str(e)}")
    
    @Slot(result=list)
    def getTrainingDataList(self):
        """获取训练数据列表"""
        try:
            if hasattr(self, '_training_data') and self._training_data is not None:
                # 确保 _training_data 是 DataFrame 对象
                if isinstance(self._training_data, pd.DataFrame):
                    data_list = self._training_data.head(100).to_dict('records')  # 只返回前100条用于显示
                    return data_list
                elif isinstance(self._training_data, list):
                    # 如果是列表，直接返回前100个元素
                    return self._training_data[:100]
            return []
        except Exception as e:
            logger.error(f"获取训练数据列表失败: {str(e)}")
            return []
    
    # ================== 模型训练功能 ==================
    
    @Slot()
    def startModelTraining(self):
        """开始模型训练 - 使用实际模型"""
        try:
            if self._training_data is None or self._training_data.empty:
                raise ValueError("无训练数据")
                
            if not self._selected_features or not self._target_label:
                raise ValueError("未选择特征或标签")
            
            self.trainingStarted.emit(self._selected_task)
            logger.info("开始模型训练...")
            
            # 准备训练数据
            X = self._training_data[self._selected_features].values
            y = self._training_data[self._target_label].values
            
            # 根据任务类型选择并创建实际模型
            if self._selected_task == 0:  # 扬程预测 - TDH
                predictor = TDHPredictor(X, y, test_size=0.2)
                model_type = "SVR-TDH"
            elif self._selected_task == 1:  # 产量预测 - QF  
                predictor = QFPredictor(X, y, test_size=0.2)
                model_type = "SVR-QF"
            elif self._selected_task == 2:  # 气液比预测 - GLR
                predictor = GLRPredictor(X, y, test_size=0.2)
                model_type = "Keras-GLR"
            else:
                raise ValueError(f"未知任务类型: {self._selected_task}")
            
            # 执行训练
            predictor.train()
            
            # 评估模型
            y_pred = predictor.predict(predictor.X_test)
            
            # 计算评估指标
            from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
            mse = mean_squared_error(predictor.y_test, y_pred)
            r2 = r2_score(predictor.y_test, y_pred)
            mae = mean_absolute_error(predictor.y_test, y_pred)
            
            # 保存模型
            model_name = f"model_{self._selected_task}_{model_type}_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}"
            self._models[model_name] = {
                "predictor": predictor,
                "model": predictor.model,
                "scaler": predictor.scaler,
                "features": self._selected_features,
                "target": self._target_label,
                "type": model_type,
                "task_id": self._selected_task,
                "mse": mse,
                "r2": r2,
                "mae": mae,
                "trained_at": pd.Timestamp.now().isoformat()
            }
            self._current_model = model_name
            
            # 生成训练历史（根据模型类型）
            if self._selected_task == 2 and hasattr(predictor, 'history'):  # Keras模型有历史记录
                train_loss = predictor.history.history.get('loss', [])
                val_loss = predictor.history.history.get('val_loss', [])
            else:  # SVR模型模拟训练历史
                epochs = 100
                train_loss = [mse * (1 + 0.1 * np.exp(-i/20)) for i in range(epochs)]
                val_loss = [mse * (1 + 0.15 * np.exp(-i/15)) for i in range(epochs)]
            
            self._training_history[model_name] = {
                "train_loss": train_loss,
                "val_loss": val_loss,
                "epochs": list(range(len(train_loss)))
            }
            
            # 生成特征重要性（如果支持）
            feature_importance = []
            if hasattr(predictor.model, 'feature_importances_'):
                for i, importance in enumerate(predictor.model.feature_importances_):
                    feature_importance.append({
                        "feature": self._selected_features[i],
                        "importance": float(importance)
                    })
            elif hasattr(predictor.model, 'coef_'):
                for i, coef in enumerate(predictor.model.coef_.flatten()):
                    feature_importance.append({
                        "feature": self._selected_features[i],
                        "importance": float(abs(coef))
                    })
            
            result = {
                "model_name": model_name,
                "model_type": model_type,
                "task_id": self._selected_task,
                "mse": mse,
                "r2": r2,
                "mae": mae,
                "train_loss": train_loss,
                "val_loss": val_loss,
                "feature_importance": feature_importance,
                "training_time": "训练完成"
            }
            
            self.trainingCompleted.emit(model_name, result)
            self.modelListUpdated.emit(list(self._models.keys()))
            
        except Exception as e:
            error_msg = f"模型训练失败: {str(e)}"
            logger.error(error_msg)
            self.predictionFailed.emit(self._selected_task, error_msg)
    
    def _get_model_type(self):
        """根据任务类型选择模型"""
        if self._selected_task == 0:  # 扬程预测
            return "SVR"
        elif self._selected_task == 1:  # 产量预测
            return "RandomForest"
        else:  # 气液比预测
            return "NeuralNetwork"
    
    def _get_feature_importance(self, model):
        """获取特征重要性"""
        try:
            if hasattr(model, 'feature_importances_'):
                importance = model.feature_importances_
            elif hasattr(model, 'coef_'):
                importance = np.abs(model.coef_).flatten()
            else:
                # 对于不支持特征重要性的模型，返回均匀分布
                importance = np.ones(len(self._selected_features)) / len(self._selected_features)
            
            return [
                {"feature": feature, "importance": float(imp)}
                for feature, imp in zip(self._selected_features, importance)
            ]
        except:
            return []
    
    @Slot(result=list)
    def getAvailableModels(self):
        """获取可用模型列表"""
        return list(self._models.keys())
    
    @Slot(str, result=dict)
    def getModelInfo(self, model_name):
        """获取模型信息"""
        if model_name in self._models:
            model_info = self._models[model_name].copy()
            # 移除不能序列化的对象
            model_info.pop('model', None)
            model_info.pop('scaler', None)
            return model_info
        return {}
    
    @Slot(int, list, list, str, str)
    @Slot(str, result=str)
    def saveModelWithDialog(self, model_name):
        """通过对话框保存模型"""
        try:
            if model_name not in self._models:
                raise ValueError("模型不存在")
            
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 使用QFileDialog选择保存位置，并显示默认文件夹名
            from PySide6.QtWidgets import QFileDialog
            
            # 设置默认路径 - 根据任务类型创建对应的默认保存目录
            default_base_path = Path(__file__).parent.parent
            if task_type == "head":
                default_save_dir = default_base_path / "TDHsave"
                task_name = "TDH"
            elif task_type == "production":
                default_save_dir = default_base_path / "QFsave"
                task_name = "QF"
            elif task_type == "glr":
                default_save_dir = default_base_path / "GLRsave"
                task_name = "GLR"
            else:
                default_save_dir = default_base_path / "saved_models"
                task_name = "MODEL"
            
            # 确保默认目录存在
            default_save_dir.mkdir(parents=True, exist_ok=True)
            
            # 生成包含任务名称的模型文件夹名
            timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
            model_folder_name = f"{task_name}-SVR-{timestamp}"
            
            # 构建完整的默认保存路径（显示给用户看）
            default_full_path = default_save_dir / model_folder_name
            
            # 使用getSaveFileName，这样可以显示建议的文件夹名称
            save_path, _ = QFileDialog.getSaveFileName(
                None,
                f"保存 {task_name} 模型",
                str(default_full_path),
                "模型文件夹 (*);;所有文件 (*)"
            )
            
            if save_path:
                # 调用内部保存方法
                return self._save_model_internal(model_name, save_path)
            
            return ""  # 用户取消保存
            
        except Exception as e:
            error_msg = f"保存模型失败: {str(e)}"
            logger.error(error_msg)
            return ""
    
    @Slot(str, str, result=str)
    def saveModelWithCustomName(self, model_name, custom_name):
        """使用自定义名称保存模型"""
        try:
            if not model_name or model_name not in self._models:
                logger.warning(f"模型 {model_name} 不存在")
                return ""
            
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 根据任务类型选择默认保存目录
            default_base_path = Path(__file__).parent.parent
            if task_type == "head":
                default_save_dir = default_base_path / "TDHsave"
                task_name = "TDH"
            elif task_type == "production":
                default_save_dir = default_base_path / "QFsave"
                task_name = "QF"
            elif task_type == "glr":
                default_save_dir = default_base_path / "GLRsave"
                task_name = "GLR"
            else:
                default_save_dir = default_base_path / "saved_models"
                task_name = "MODEL"
            
            default_save_dir.mkdir(parents=True, exist_ok=True)
            
            # 在自定义名称前添加任务名称前缀
            final_name = f"{task_name}-{custom_name}" if custom_name else f"{task_name}-SVR-{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}"
            save_path = default_save_dir / final_name
            
            return self._save_model_internal(model_name, str(save_path))
            
        except Exception as e:
            logger.error(f"使用自定义名称保存模型失败: {e}")
            return ""
    
    def _save_model_internal(self, model_name, save_path):
        """内部模型保存方法"""
        try:
            model_info = self._models[model_name]
            model_instance = model_info.get('model_instance')
            task_type = model_info.get('task_type', 'unknown')
            
            if not model_instance:
                logger.error("模型实例不存在")
                return ""
            
            # 调用模型自带的保存方法
            if hasattr(model_instance, 'save_model'):
                # 对于不同的模型类型，需要传递不同的参数格式
                # 因为每个模型类的save_model方法有自己的目录结构逻辑
                
                # 从完整路径中提取模型名称
                save_path_obj = Path(save_path)
                model_folder_name = save_path_obj.name  # 获取最后一级目录名作为模型名
                
                logger.info(f"开始保存模型: {task_type}, 模型名: {model_folder_name}")
                
                # 调用模型的save_model方法，传递模型文件夹名称
                # 每个模型类会在自己的专用目录下创建这个文件夹
                success = model_instance.save_model(model_folder_name)
                
                if success:
                    # 根据任务类型确定实际保存路径
                    root_path = Path(__file__).parent.parent
                    if task_type == "head":
                        actual_save_path = root_path / "TDHsave" / model_folder_name
                    elif task_type == "production":
                        actual_save_path = root_path / "QFsave" / model_folder_name
                    elif task_type == "glr":
                        actual_save_path = root_path / "GLRsave" / model_folder_name
                    else:
                        # 对于未知类型，使用通用保存路径
                        actual_save_path = save_path_obj
                    
                    logger.info(f"模型已保存到: {actual_save_path}")
                    self.modelSaved.emit(model_name, str(actual_save_path))
                    return str(actual_save_path)
                else:
                    logger.error("模型保存失败")
                    return ""
            else:
                # 如果模型没有save_model方法，使用joblib保存
                import joblib
                
                # 确保保存路径存在
                save_path_obj = Path(save_path)
                save_path_obj.mkdir(parents=True, exist_ok=True)
                
                model_file = save_path_obj / f"{task_type}_model.joblib"
                scaler_file = save_path_obj / f"{task_type}_scaler.joblib"
                
                joblib.dump(model_info['model'], model_file)
                if 'scaler' in model_info and model_info['scaler']:
                    joblib.dump(model_info['scaler'], scaler_file)
                
                # 保存模型元数据
                metadata = {
                    'task_type': task_type,
                    'features': model_info.get('features', []),
                    'target': model_info.get('target', ''),
                    'train_r2': model_info.get('train_r2', 0),
                    'test_r2': model_info.get('test_r2', 0),
                    'train_mse': model_info.get('train_mse', 0),
                    'test_mse': model_info.get('test_mse', 0),
                    'saved_at': pd.Timestamp.now().isoformat()
                }
                
                metadata_file = save_path_obj / "model_metadata.json"
                import json
                with open(metadata_file, 'w', encoding='utf-8') as f:
                    json.dump(metadata, f, ensure_ascii=False, indent=2)
                
                logger.info(f"模型已保存到: {save_path}")
                self.modelSaved.emit(model_name, str(save_path_obj))
                return str(save_path_obj)
                
        except Exception as e:
            logger.error(f"保存模型失败: {e}")
            return ""
    
    @Slot(result=str)
    def saveCurrentModel(self):
        """保存当前模型"""
        if self._current_model and self._current_model in self._models:
            return self.saveModelWithDialog(self._current_model)
        else:
            logger.warning("没有当前模型可以保存")
            return ""
    
    def _on_training_completed(self, model_name, result):
        """训练完成回调"""
        try:
            if self._training_thread and self._training_thread.model_info:
                # 确保模型名称是字符串
                model_name_str = str(model_name) if model_name else ""
                logger.info(f"训练完成回调收到：model_name={model_name_str}, type={type(model_name)}")
                
                # 保存模型到字典
                self._models[model_name_str] = self._training_thread.model_info
                self._current_model = model_name_str
                
                logger.info(f"设置 _current_model = {self._current_model}")
                
                # 发送完成信号，确保传递字符串类型
                self.trainingCompleted.emit(model_name_str, result)
                self.modelListUpdated.emit(list(self._models.keys()))
                
                logger.info(f"模型训练完成: {model_name_str}")
            else:
                logger.warning("训练线程或模型信息为空")
            
        except Exception as e:
            error_msg = f"训练完成处理失败: {str(e)}"
            logger.error(error_msg)
            self.trainingError.emit(error_msg)
    
    @Slot(str, result=dict)
    def getTrainingHistory(self, model_name):
        """获取训练历史"""
        return self._training_history.get(model_name, {})
    
    # ================== 模型测试功能 ==================
    
    @Slot(str)
    def loadExternalModel(self, file_path):
        """加载外部模型"""
        try:
            if file_path.endswith('.joblib'):
                model = joblib.load(file_path)
                model_name = f"external_{Path(file_path).stem}"
                
                self._models[model_name] = {
                    "model": model,
                    "type": "External",
                    "features": self._selected_features,  # 需要用户指定
                    "target": self._target_label,
                    "loaded_from": file_path,
                    "loaded_at": pd.Timestamp.now().isoformat()
                }
                
                self.modelListUpdated.emit(list(self._models.keys()))
                logger.info(f"成功加载外部模型: {model_name}")
                
        except Exception as e:
            error_msg = f"加载外部模型失败: {str(e)}"
            logger.error(error_msg)
    
    @Slot(str)
    def selectModelForTesting(self, model_name):
        """选择模型进行测试"""
        if model_name in self._models:
            self._current_model = model_name
            logger.info(f"选择测试模型: {model_name}")
    
    @Slot()
    def startModelTesting(self):
        """开始模型测试 - 使用实际模型"""
        try:
            if not self._current_model or self._current_model not in self._models:
                raise ValueError("未选择测试模型")
                
            if self._training_data is None or self._training_data.empty:
                raise ValueError("无测试数据")
            
            model_info = self._models[self._current_model]
            
            # 如果是我们训练的模型，有predictor对象
            if "predictor" in model_info:
                predictor = model_info["predictor"]
                
                # 使用模型的测试集进行测试
                y_pred = predictor.predict(predictor.X_test)
                y_true = predictor.y_test
            else:
                # 外部模型或旧格式模型
                model = model_info["model"]
                scaler = model_info.get("scaler")
                
                # 准备测试数据
                X_test = self._training_data[model_info["features"]].values
                y_true = self._training_data[model_info["target"]].values
                
                # 数据预处理
                if scaler:
                    X_test_scaled = scaler.transform(X_test)
                else:
                    X_test_scaled = X_test
                
                # 进行预测
                y_pred = model.predict(X_test_scaled)
            
            # 计算评估指标
            from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
            
            mse = mean_squared_error(y_true, y_pred)
            mae = mean_absolute_error(y_true, y_pred)
            r2 = r2_score(y_true, y_pred)
            
            # 保存测试结果
            test_results = {
                "model_name": self._current_model,
                "model_type": model_info["type"],
                "task_id": model_info.get("task_id", self._selected_task),
                "mse": float(mse),
                "mae": float(mae),
                "r2": float(r2),
                "predictions": y_pred.tolist()[:100],  # 只保存前100个预测结果
                "actual": y_true.tolist()[:100],
                "test_samples": len(y_true),
                "tested_at": pd.Timestamp.now().isoformat()
            }
            
            self._test_results[self._current_model] = test_results
            self.testResultsUpdated.emit(test_results)
            
            logger.info(f"模型测试完成 - MSE: {mse:.4f}, R2: {r2:.4f}")
            
        except Exception as e:
            error_msg = f"模型测试失败: {str(e)}"
            logger.error(error_msg)
    
    @Slot(str, result=dict)
    def getTestResults(self, model_name):
        """获取测试结果"""
        return self._test_results.get(model_name, {})
    
    @Slot(str, str, list, str)
    def startModelTestingWithData(self, model_name, table_name, features, target_label):
        """使用指定数据开始模型测试"""
        try:
            if model_name not in self._models:
                error_msg = f"模型不存在: {model_name}"
                logger.error(error_msg)
                self.predictionFailed.emit(-1, error_msg)
                return
            
            # 从数据库加载测试数据
            conn = sqlite3.connect(self._db_path)
            df = pd.read_sql_query(f"SELECT * FROM \"{table_name}\"", conn)
            conn.close()
            
            # 检查字段是否存在
            required_cols = features + [target_label]
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                error_msg = f"测试数据表中缺少字段: {missing_cols}"
                logger.error(error_msg)
                self.predictionFailed.emit(-1, error_msg)
                return
            
            model_info = self._models[model_name]
            model = model_info["model"]
            scaler = model_info.get("scaler")
            
            # 准备测试数据
            X_test = df[features].values
            y_true = df[target_label].values
            
            # 数据预处理
            if scaler:
                X_test_scaled = scaler.transform(X_test)
            else:
                X_test_scaled = X_test
            
            # 进行预测
            y_pred = model.predict(X_test_scaled)
            
            # 计算评估指标
            from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
            
            mse = mean_squared_error(y_true, y_pred)
            mae = mean_absolute_error(y_true, y_pred)
            r2 = r2_score(y_true, y_pred)
            
            # 保存测试结果
            test_results = {
                "model_name": model_name,
                "model_type": model_info["type"],
                "test_table": table_name,
                "features": features,
                "target": target_label,
                "mse": float(mse),
                "mae": float(mae),
                "r2": float(r2),
                "predictions": y_pred.tolist()[:100],  # 只保存前100个预测结果
                "actual": y_true.tolist()[:100],
                "test_samples": len(y_true),
                "tested_at": pd.Timestamp.now().isoformat()
            }
            
            self._test_results[model_name] = test_results
            self.testResultsUpdated.emit(test_results)
            
            logger.info(f"模型测试完成 - 表: {table_name}, MSE: {mse:.4f}, R2: {r2:.4f}")
            
        except Exception as e:
            error_msg = f"模型测试失败: {str(e)}"
            logger.error(error_msg)
            self.predictionFailed.emit(-1, error_msg)
    
    @Slot(str, str, list, list, str, dict)
    def startModelTestingWithConfiguration(self, model_path, model_type, data_tables, features, target_label, feature_mapping):
        """使用完整配置开始模型测试"""
        try:
            self.testLogUpdated.emit("开始模型测试...")
            self.testProgressUpdated.emit(0.0)
            
            # 设置日志转发
            self._setup_log_forwarding()
            
            # 加载模型
            self.testLogUpdated.emit(f"加载模型: {model_path}")
            self.testLogUpdated.emit(f"模型类型: {model_type}")
            
            # 检查路径是否存在
            if not Path(model_path).exists():
                error_msg = f"模型路径不存在: {model_path}"
                self.testLogUpdated.emit(error_msg)
                return
            
            self.testLogUpdated.emit(f"路径检查通过，开始加载模型...")
            
            model, scaler = self._load_external_model(model_path, model_type)
            if model is None:
                error_msg = f"无法加载模型: {model_path}"
                self.testLogUpdated.emit(error_msg)
                return
            
            self.testLogUpdated.emit(f"模型加载成功: {type(model).__name__}")
            if scaler:
                self.testLogUpdated.emit(f"缩放器加载成功: {type(scaler).__name__}")
            else:
                self.testLogUpdated.emit("未使用缩放器")
            
            self.testProgressUpdated.emit(20.0)
            
            # 合并所有数据表
            self.testLogUpdated.emit(f"加载测试数据表: {', '.join(data_tables)}")
            all_data = []
            
            for table_name in data_tables:
                try:
                    conn = sqlite3.connect(self._db_path)
                    df = pd.read_sql_query(f"SELECT * FROM \"{table_name}\"", conn)
                    conn.close()
                    all_data.append(df)
                    self.testLogUpdated.emit(f"已加载表 {table_name}: {len(df)} 行")
                except Exception as e:
                    self.testLogUpdated.emit(f"加载表 {table_name} 失败: {str(e)}")
                    continue
            
            if not all_data:
                error_msg = "没有成功加载任何数据表"
                self.testLogUpdated.emit(error_msg)
                return
            
            # 合并数据
            combined_df = pd.concat(all_data, ignore_index=True)
            self.testLogUpdated.emit(f"合并数据完成: 总共 {len(combined_df)} 行")
            self.testProgressUpdated.emit(40.0)
            
            # 检查必要的列
            required_cols = features + [target_label]
            missing_cols = [col for col in required_cols if col not in combined_df.columns]
            if missing_cols:
                error_msg = f"数据中缺少必要的列: {missing_cols}"
                self.testLogUpdated.emit(error_msg)
                return
            
            # 应用特征映射（如果有）
            mapped_features = []
            for feature in features:
                if feature_mapping and feature in feature_mapping and feature_mapping[feature]:
                    mapped_feature = feature_mapping[feature]
                    mapped_features.append(mapped_feature)
                    self.testLogUpdated.emit(f"特征映射: {feature} → {mapped_feature}")
                else:
                    mapped_features.append(feature)
            
            self.testProgressUpdated.emit(60.0)
            
            # 准备测试数据
            X_test = combined_df[mapped_features].values
            y_true = combined_df[target_label].values
            
            # 移除包含NaN的行
            valid_indices = ~(np.isnan(X_test).any(axis=1) | np.isnan(y_true))
            X_test = X_test[valid_indices]
            y_true = y_true[valid_indices]
            
            self.testLogUpdated.emit(f"有效测试样本: {len(X_test)} 个")
            
            if len(X_test) == 0:
                error_msg = "没有有效的测试样本"
                self.testLogUpdated.emit(error_msg)
                return
            
            self.testProgressUpdated.emit(80.0)
            
            # 数据预处理
            if scaler:
                X_test_scaled = scaler.transform(X_test)
                self.testLogUpdated.emit("应用数据缩放")
            else:
                X_test_scaled = X_test
                self.testLogUpdated.emit("未使用数据缩放")
            
            # 进行预测
            self.testLogUpdated.emit("开始预测...")
            y_pred = model.predict(X_test_scaled)
            
            self.testProgressUpdated.emit(90.0)
            
            # 计算评估指标
            from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
            
            mse = mean_squared_error(y_true, y_pred)
            mae = mean_absolute_error(y_true, y_pred)
            r2 = r2_score(y_true, y_pred)
            
            # 计算MAPE
            mape = np.mean(np.abs((y_true - y_pred) / np.where(y_true != 0, y_true, 1))) * 100
            
            # 准备结果数据
            test_results = {
                "model_path": model_path,
                "model_type": model_type,
                "test_tables": data_tables,
                "features": features,
                "mapped_features": mapped_features,
                "target": target_label,
                "feature_mapping": feature_mapping,
                "mse": float(mse),
                "mae": float(mae),
                "r2": float(r2),
                "mape": float(mape),
                "test_samples": len(y_true),
                "error_plot_data": {
                    "actual": y_true.tolist(),
                    "predicted": y_pred.tolist()
                },
                "tested_at": pd.Timestamp.now().isoformat()
            }
            
            self.testProgressUpdated.emit(100.0)
            self.testLogUpdated.emit(f"测试完成! MAPE: {mape:.2f}%, R²: {r2:.4f}")
            
            # 发送测试结果
            self.testResultsUpdated.emit(test_results)
            
        except Exception as e:
            error_msg = f"模型测试失败: {str(e)}"
            logger.error(error_msg)
            self.testLogUpdated.emit(error_msg)
    
    def _load_external_model(self, model_path, model_type):
        """加载外部模型文件"""
        try:
            logger.info(f"开始加载模型: 路径={model_path}, 类型={model_type}")
            
            if model_type.lower() == "local":
                # 本地保存的模型
                logger.info("处理本地模型类型")
                model_data = joblib.load(model_path)
                if isinstance(model_data, dict):
                    model = model_data.get("model")
                    scaler = model_data.get("scaler")
                else:
                    model = model_data
                    scaler = None
                return model, scaler
            
            elif model_type.lower() in ["external", "folder"]:
                # 外部模型或文件夹，根据路径判断类型
                path_obj = Path(model_path)
                logger.info(f"处理外部模型类型: 路径对象={path_obj}, 是否为目录={path_obj.is_dir()}")
                
                if path_obj.is_dir():
                    # 文件夹，根据文件夹中的内容判断模型类型
                    model_files = list(path_obj.glob("*.joblib")) + list(path_obj.glob("*.pkl"))
                    h5_files = list(path_obj.glob("*.h5")) + list(path_obj.glob("*.keras"))
                    
                    logger.info(f"找到的模型文件: {[f.name for f in model_files]}")
                    logger.info(f"找到的H5文件: {[f.name for f in h5_files]}")
                    
                    if any("TDH" in f.name for f in model_files):
                        # TDH SVR模型
                        logger.info("检测到TDH模型，开始加载")
                        from models.svrTDH import SVRPredictor as TDHPredictor
                        predictor = TDHPredictor([], [], log_widget=None)
                        logger.info(f"创建TDH预测器成功，开始加载模型和缩放器")
                        predictor.load_model_and_scaler(str(model_path))
                        logger.info(f"加载完成，模型状态: {predictor.model is not None}, 缩放器状态: {predictor.scaler is not None}")
                        if predictor.model is not None and predictor.scaler is not None:
                            logger.info(f"TDH模型加载成功: {model_path}")
                            return predictor.model, predictor.scaler
                        else:
                            logger.error(f"TDH模型加载失败: {model_path}")
                            return None, None
                    
                    elif any("QF" in f.name for f in model_files):
                        # QF SVR模型
                        logger.info("检测到QF模型，开始加载")
                        from models.svrQF import QFPredictor
                        predictor = QFPredictor([], [], log_widget=None)
                        predictor.load_model_and_scaler(str(model_path))
                        if predictor.model is not None and predictor.scaler is not None:
                            logger.info(f"QF模型加载成功: {model_path}")
                            return predictor.model, predictor.scaler
                        else:
                            logger.error(f"QF模型加载失败: {model_path}")
                            return None, None
                    
                    elif any("GLR" in f.name for f in h5_files):
                        # GLR Keras模型
                        logger.info("检测到GLR模型，开始加载")
                        from models.keraGLR import GLRPredictor
                        predictor = GLRPredictor([], [], log_widget=None)
                        predictor.load_model_and_scaler(str(model_path))
                        if predictor.model is not None and predictor.scaler is not None:
                            logger.info(f"GLR模型加载成功: {model_path}")
                            return predictor.model, predictor.scaler
                        else:
                            logger.error(f"GLR模型加载失败: {model_path}")
                            return None, None
                    
                    else:
                        # 通用joblib文件加载
                        logger.info("未检测到特定模型类型，尝试通用加载")
                        if model_files:
                            logger.info(f"加载第一个模型文件: {model_files[0]}")
                            model_data = joblib.load(model_files[0])
                            if isinstance(model_data, dict):
                                return model_data.get("model"), model_data.get("scaler")
                            return model_data, None
                        else:
                            logger.error("文件夹中没有找到可加载的模型文件")
                            return None, None
                    
                elif path_obj.suffix in ['.pth', '.pt']:
                    # PyTorch模型文件 (GLR)
                    logger.info("处理PyTorch模型文件")
                    try:
                        import torch
                        from models.keraGLR import GLRPredictor
                        
                        # 加载GLR模型
                        predictor = GLRPredictor([], [], log_widget=None)
                        # 对于单个.pth文件，我们假设它所在的目录包含完整的GLR模型
                        model_dir = str(path_obj.parent)
                        predictor.load_model_and_scaler(model_dir)
                        if predictor.model is not None and predictor.scaler is not None:
                            logger.info(f"GLR模型加载成功: {model_path}")
                            return predictor.model, predictor.scaler
                        else:
                            logger.error(f"GLR模型权重加载失败: {model_path}")
                            return None, None
                    except ImportError:
                        logger.error("PyTorch未安装，无法加载.pth模型")
                        return None, None
                    except Exception as e:
                        logger.error(f"GLR模型加载异常: {str(e)}")
                        return None, None
                    
                elif path_obj.suffix in ['.joblib', '.pkl']:
                    # joblib或pickle文件
                    logger.info("处理joblib/pickle文件")
                    model_data = joblib.load(model_path)
                    if isinstance(model_data, dict):
                        return model_data.get("model"), model_data.get("scaler")
                    return model_data, None
                    
                elif path_obj.suffix in ['.h5', '.keras']:
                    # Keras模型文件 (GLR)
                    logger.info("处理Keras模型文件")
                    from models.keraGLR import GLRPredictor
                    predictor = GLRPredictor([], [], log_widget=None)
                    # 对于单个.h5文件，假设它所在的目录包含完整的GLR模型
                    model_dir = str(path_obj.parent)
                    predictor.load_model_and_scaler(model_dir)
                    if predictor.model is not None and predictor.scaler is not None:
                        logger.info(f"GLR模型加载成功: {model_path}")
                        return predictor.model, predictor.scaler
                    else:
                        logger.error(f"GLR模型加载失败: {model_path}")
                        return None, None
                        
            else:
                logger.error(f"不支持的模型类型: {model_type}")
            
            return None, None
            
        except Exception as e:
            logger.error(f"加载模型失败: {str(e)}")
            import traceback
            logger.error(f"详细错误信息: {traceback.format_exc()}")
            return None, None
    
    @Slot(dict, result=str)
    def saveTestResultsWithDialog(self, test_results):
        """使用文件对话框保存测试结果"""
        try:
            # 打开文件保存对话框
            file_path, _ = QFileDialog.getSaveFileName(
                None,
                "保存测试结果",
                f"test_results_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.json",
                "JSON Files (*.json);;All Files (*)"
            )
            
            if file_path:
                # 保存结果到JSON文件
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(test_results, f, ensure_ascii=False, indent=2)
                
                logger.info(f"测试结果已保存到: {file_path}")
                return file_path
            
            return ""
            
        except Exception as e:
            logger.error(f"保存测试结果失败: {str(e)}")
            return ""
    
    def _setup_log_forwarding(self):
        """设置日志转发到UI"""
        class UILogHandler(logging.Handler):
            def __init__(self, signal):
                super().__init__()
                self.signal = signal
                
            def emit(self, record):
                log_entry = self.format(record)
                self.signal.emit(log_entry)
        
        # 创建并添加UI日志处理器
        if not hasattr(self, '_ui_log_handler'):
            self._ui_log_handler = UILogHandler(self.testLogUpdated)
            self._ui_log_handler.setLevel(logging.INFO)
            logger.addHandler(self._ui_log_handler)
    
    def plot_loss(self, train_loss, val_loss, widget=None):
        """在 UI 中显示损失下降曲线"""
        try:
            fig = Figure(figsize=(10, 6))
            canvas = FigureCanvas(fig)
            ax = fig.add_subplot(111)

            ax.plot(train_loss, label='Train Loss', color='blue')
            ax.plot(val_loss, label='Validation Loss', color='red')
            ax.set_xlabel('Epoch')
            ax.set_ylabel('Loss')
            ax.set_title('Training Loss Curve')
            ax.legend()
            ax.grid(True, alpha=0.3)

            if widget:
                # 清除旧布局并添加新图
                layout = widget.layout()
                if layout is None:
                    layout = QVBoxLayout(widget)
                    widget.setLayout(layout)
                else:
                    for i in reversed(range(layout.count())):
                        old_widget = layout.itemAt(i).widget()
                        if old_widget:
                            old_widget.setParent(None)

                layout.addWidget(canvas)
                canvas.draw()
                
            return canvas
            
        except Exception as e:
            logger.error(f"绘制损失曲线失败: {str(e)}")
            return None
    
    @Slot(str, result=str)
    def saveModel(self, model_name):
        """保存模型到文件"""
        try:
            if model_name not in self._models:
                raise ValueError("模型不存在")
                
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 生成默认保存路径 - 根据任务类型
            default_base_path = Path(__file__).parent.parent
            if task_type == "head":
                default_save_dir = default_base_path / "TDHsave"
                task_name = "TDH"
            elif task_type == "production":
                default_save_dir = default_base_path / "QFsave"
                task_name = "QF"
            elif task_type == "glr":
                default_save_dir = default_base_path / "GLRsave"
                task_name = "GLR"
            else:
                default_save_dir = default_base_path / "saved_models"
                task_name = "MODEL"
            
            default_save_dir.mkdir(parents=True, exist_ok=True)
            
            # 生成包含任务名称的时间戳文件夹名
            timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
            model_folder_name = f"{task_name}-SVR-{timestamp}"
            save_path = default_save_dir / model_folder_name
            
            # 调用内部保存方法
            return self._save_model_internal(model_name, str(save_path))
            
        except Exception as e:
            error_msg = f"保存模型失败: {str(e)}"
            logger.error(error_msg)
            return ""
    
    @Slot(str, result=str)
    def saveModelWithDialog(self, model_name):
        """通过对话框保存模型"""
        try:
            if model_name not in self._models:
                raise ValueError("模型不存在")
            
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 设置默认路径 - 根据任务类型创建对应的默认保存目录
            default_base_path = Path(__file__).parent.parent
            if task_type == "head":
                default_save_dir = default_base_path / "TDHsave"
                task_name = "TDH"
            elif task_type == "production":
                default_save_dir = default_base_path / "QFsave"
                task_name = "QF"
            elif task_type == "glr":
                default_save_dir = default_base_path / "GLRsave"
                task_name = "GLR"
            else:
                default_save_dir = default_base_path / "saved_models"
                task_name = "MODEL"
            
            # 确保默认目录存在
            default_save_dir.mkdir(parents=True, exist_ok=True)
            
            # 生成包含任务名称的模型文件夹名
            timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
            model_folder_name = f"{task_name}-SVR-{timestamp}"
            
            # 构建完整的默认保存路径
            default_full_path = default_save_dir / model_folder_name
            
            # 使用getSaveFileName对话框，让用户可以修改文件夹名称
            from PySide6.QtWidgets import QFileDialog
            
            save_path, _ = QFileDialog.getSaveFileName(
                None,
                f"保存 {task_name} 模型 - 请确认或修改文件夹名称",
                str(default_full_path),
                "模型文件夹 (*);;所有文件 (*)"
            )
            
            if save_path:
                # 调用内部保存方法
                return self._save_model_internal(model_name, save_path)
            
            return ""  # 用户取消保存
            
        except Exception as e:
            error_msg = f"保存模型失败: {str(e)}"
            logger.error(error_msg)
            return ""
    
    @Slot(result=str)
    def getCurrentModelName(self):
        """获取当前训练的模型名称"""
        current_model = self._current_model if self._current_model else ""
        logger.info(f"getCurrentModelName 被调用，返回: {current_model}")
        logger.info(f"_current_model 类型: {type(self._current_model)}")
        return current_model
    
    @Slot(str, result='QVariant')
    def previewTableData(self, table_name):
        """预览表数据，返回结构化数据用于表格显示"""
        try:
            logger.info(f"previewTableData called for table: {table_name}")
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            
            # 获取前20行数据
            cursor.execute(f"SELECT * FROM \"{table_name}\" LIMIT 20")
            rows = cursor.fetchall()
            logger.info(f"Found {len(rows)} rows in table {table_name}")
            
            # 获取列名
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns = [row[1] for row in cursor.fetchall()]
            logger.info(f"Table {table_name} has columns: {columns}")
            
            conn.close()
            
            if not rows:
                logger.info(f"Table {table_name} is empty")
                return {
                    "success": True,
                    "columns": [],
                    "rows": [],
                    "message": "表为空"
                }
            
            # 格式化数据为二维数组
            formatted_rows = []
            for row in rows:
                formatted_row = [str(val) if val is not None else "NULL" for val in row]
                formatted_rows.append(formatted_row)
            
            return {
                "success": True,
                "columns": columns,
                "rows": formatted_rows,
                "total_rows": len(rows)
            }
            
        except Exception as e:
            error_msg = f"预览表数据失败: {str(e)}"
            logger.error(error_msg)
            return {
                "success": False,
                "error": error_msg
            }
    
    @Slot(str, result='QVariant')
    def deleteTable(self, table_name):
        """删除数据表"""
        try:
            logger.info(f"deleteTable called for table: {table_name}")
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            
            # 先检查表是否存在
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table_name,))
            exists = cursor.fetchone()
            if not exists:
                logger.warning(f"Table {table_name} does not exist")
                conn.close()
                return {
                    "success": False,
                    "error": f"表 {table_name} 不存在"
                }
            
            cursor.execute(f"DROP TABLE IF EXISTS {table_name}")
            conn.commit()
            conn.close()
            
            logger.info(f"成功删除表: {table_name}")
            return {
                "success": True,
                "message": f"表 {table_name} 已删除"
            }
            
        except Exception as e:
            error_msg = f"删除表失败: {str(e)}"
            logger.error(error_msg)
            return {
                "success": False,
                "error": error_msg
            }
