# Controller/ContinuousLearningController.py
from PySide6.QtCore import QObject, Signal, Slot, Property, QThread, QMutex
from PySide6.QtWidgets import QVBoxLayout, QFileDialog, QApplication
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
import sys
sys.path.append(str(Path(__file__).parent.parent))

# 导入数据处理器
from .DataProcessor import DataProcessor
from models.model import (
    BasePredictor, GLRPredictor, QFPredictor, TDHPredictor,
    TrainingConfig, ModelInfo, CallbackEvent, CallbackData,
    BaseCallback, MetricsCallback, ProgressCallback, LossCallback,
    GLRInput, QFInput, SVRInput
)


from models.ModelFeatureConfig import ModelFeatureConfig


logger = logging.getLogger(__name__)


class ThreadProgressCallback(BaseCallback):
    """线程进度回调 - 将预测器的回调转发到线程信号"""
    
    def __init__(self, thread):
        self.thread = thread
        
    def on_progress_update(self, callback_data: CallbackData):
        progress = callback_data.get('progress', 0)
        status = callback_data.get('status', '训练中...')
        self.thread.trainingProgressUpdated.emit(progress, {"status": status})
        
    def on_loss_update(self, callback_data: CallbackData):
        self.thread.lossDataUpdated.emit(callback_data.data)
        
    def on_epoch_end(self, callback_data: CallbackData):
        epoch = callback_data.get('epoch', 0)
        loss = callback_data.get('train_loss', 0)
        val_loss = callback_data.get('val_loss', 0)
        
        # 发送训练日志
        log_msg = f"Epoch {epoch}: train_loss={loss:.4f}, val_loss={val_loss:.4f}"
        self.thread.trainingLogUpdated.emit(log_msg)


class ThreadMetricsCallback(MetricsCallback):
    """线程指标回调 - 计算并转发训练指标"""
    
    def __init__(self, thread, metrics_funcs=None):
        super().__init__(metrics_funcs)
        self.thread = thread
        
    def on_epoch_end(self, callback_data: CallbackData):
        super().on_epoch_end(callback_data)
        
        # 转发到线程的日志信号
        if self.metrics_history:
            latest_metrics = self.metrics_history[-1]['metrics']
            for name, value in latest_metrics.items():
                if value is not None:
                    log_msg = f"Metric {name}: {value:.4f}"
                    self.thread.trainingLogUpdated.emit(log_msg)


class ModelTrainingThread(QThread):
    """模型训练线程类 - 重构为使用统一预测器接口"""
    
    # 训练线程信号
    trainingProgressUpdated = Signal(float, dict)
    trainingCompleted = Signal(str, dict)
    trainingError = Signal(str)
    trainingLogUpdated = Signal(str)
    lossDataUpdated = Signal(dict)
    
    def __init__(self, project_id, table_names, features, target_label, task_type, 
                 db_path, feature_mapping=None, training_params=None):
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
        self.predictor = None
        
        # 设置日志捕获
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
        self.log_handler.setFormatter(logging.Formatter(
            '%(asctime)s | %(levelname)s | %(name)s:%(funcName)s:%(lineno)d - %(message)s'
        ))
        
        # 添加到Python标准logging
        root_logger = logging.getLogger()
        root_logger.addHandler(self.log_handler)
    
    def cleanup_log_capture(self):
        """清理日志捕获"""
        if hasattr(self, 'log_handler') and self.log_handler:
            logging.getLogger().removeHandler(self.log_handler)
            self.log_handler = None
    
    def run(self):
        """执行训练任务 - 使用统一预测器接口"""
        try:
            # 加载和合并数据
            self.trainingLogUpdated.emit("开始加载训练数据...")
            X, y, cleaning_info = self._load_and_prepare_data()
            
            if X is None or y is None:
                self.trainingError.emit("数据准备失败")
                return
            
            self.trainingProgressUpdated.emit(20.0, {"status": "数据准备完成"})
            
            # 创建训练配置
            config = TrainingConfig(
                epochs=self.training_params.get('epochs', 1000),
                batch_size=self.training_params.get('batch_size', 48),
                learning_rate=self.training_params.get('learning_rate', 0.001),
                patience=self.training_params.get('patience', 100),
                test_size=0.2,
                random_state=42
            )
            
            # 根据任务类型创建预测器
            self.trainingLogUpdated.emit(f"创建{self.task_type}预测器...")
            self.predictor = self._create_predictor(X, y, config)
            
            if self.predictor is None:
                self.trainingError.emit(f"不支持的任务类型: {self.task_type}")
                return
            
            # 添加回调函数
            self._setup_callbacks()
            
            self.trainingProgressUpdated.emit(40.0, {"status": f"开始{self.task_type}模型训练"})
            
            # 执行训练
            self.trainingLogUpdated.emit("开始模型训练...")
            train_result = self.predictor.train()
            
            # 调试：检查训练后的预测器状态
            self.trainingLogUpdated.emit(f"训练完成，检查预测器状态:")
            self.trainingLogUpdated.emit(f"  - 是否已训练: {getattr(self.predictor, 'is_trained', False)}")
            self.trainingLogUpdated.emit(f"  - 是否有X_train: {hasattr(self.predictor, 'X_train')}")
            self.trainingLogUpdated.emit(f"  - 是否有y_train: {hasattr(self.predictor, 'y_train')}")
            self.trainingLogUpdated.emit(f"  - 是否有X_test: {hasattr(self.predictor, 'X_test')}")
            self.trainingLogUpdated.emit(f"  - 是否有y_test: {hasattr(self.predictor, 'y_test')}")
            
            if hasattr(self.predictor, 'X_train'):
                self.trainingLogUpdated.emit(f"  - X_train shape: {self.predictor.X_train.shape}")
            if hasattr(self.predictor, 'y_train'):
                self.trainingLogUpdated.emit(f"  - y_train shape: {self.predictor.y_train.shape}")
            if hasattr(self.predictor, 'X_test'):
                self.trainingLogUpdated.emit(f"  - X_test shape: {self.predictor.X_test.shape}")
            if hasattr(self.predictor, 'y_test'):
                self.trainingLogUpdated.emit(f"  - y_test shape: {self.predictor.y_test.shape}")
            
            self.trainingProgressUpdated.emit(80.0, {"status": "计算评估指标"})
            
            # 获取测试结果
            self.trainingLogUpdated.emit("开始测试模型...")
            test_result = self.predictor.test()
            
            # 调试：检查测试结果
            self.trainingLogUpdated.emit(f"测试结果类型: {type(test_result)}")
            self.trainingLogUpdated.emit(f"测试结果键: {list(test_result.keys()) if isinstance(test_result, dict) else 'Not a dict'}")
            if 'y_true' in test_result:
                y_true = test_result['y_true']
                self.trainingLogUpdated.emit(f"y_true类型: {type(y_true)}, 长度: {len(y_true) if hasattr(y_true, '__len__') else 'No length'}")
            if 'y_pred' in test_result:
                y_pred = test_result['y_pred']
                self.trainingLogUpdated.emit(f"y_pred类型: {type(y_pred)}, 长度: {len(y_pred) if hasattr(y_pred, '__len__') else 'No length'}")
            
            # 准备结果数据
            result_data = self._prepare_training_results(train_result, test_result)
            
            # 生成模型名称和保存模型信息
            self.model_name = self._generate_model_name()
            self._save_model_info(result_data)
            
            self.trainingProgressUpdated.emit(100.0, {"status": "训练完成"})
            self.trainingCompleted.emit(self.model_name, result_data)
            
        except Exception as e:
            error_msg = f"模型训练失败: {str(e)}"
            logger.exception(error_msg)
            self.trainingError.emit(error_msg)
        finally:
            self.cleanup_log_capture()
    
    def _load_and_prepare_data(self):
        """加载和准备训练数据"""
        try:
            # 合并多个表的数据
            all_dfs = []
            conn = sqlite3.connect(self.db_path)
            
            for table_name in self.table_names:
                try:
                    df = pd.read_sql_query(f"SELECT * FROM \"{table_name}\"", conn)
                    if not df.empty:
                        df['data_source'] = table_name
                        all_dfs.append(df)
                        self.trainingLogUpdated.emit(f"从表 {table_name} 加载了 {len(df)} 条记录")
                except Exception as e:
                    self.trainingLogUpdated.emit(f"加载表 {table_name} 失败: {e}")
                    continue
            
            conn.close()
            
            if not all_dfs:
                self.trainingError.emit("没有有效的数据表可用于训练")
                return None, None, None
            
            # 合并所有数据
            df = pd.concat(all_dfs, ignore_index=True)
            self.trainingLogUpdated.emit(f"总共合并了 {len(df)} 条记录")
            
            # 应用特征映射
            mapped_features = self._apply_feature_mapping()
            
            # 检查字段是否存在
            required_cols = mapped_features + [self.target_label]
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                self.trainingError.emit(f"数据表中缺少字段: {missing_cols}")
                return None, None, None
            
            # 使用数据处理器清理数据
            data_processor = DataProcessor(remove_outliers=True, outlier_factor=1.5)
            X, y, cleaning_info = data_processor.clean_data(df, mapped_features, self.target_label)
            
            # 记录清理信息
            self.trainingLogUpdated.emit(f"数据清理信息: {cleaning_info}")
            for step in cleaning_info["cleaning_steps"]:
                self.trainingLogUpdated.emit(f"  - {step}")
            
            # 详细记录清理后的数据状态
            self.trainingLogUpdated.emit(f"清理后数据状态:")
            self.trainingLogUpdated.emit(f"  - X类型: {type(X)}, 形状: {X.shape if hasattr(X, 'shape') else '无shape属性'}")
            self.trainingLogUpdated.emit(f"  - y类型: {type(y)}, 形状: {y.shape if hasattr(y, 'shape') else '无shape属性'}")
            self.trainingLogUpdated.emit(f"  - X前5行数据: {X[:5].tolist() if hasattr(X, 'tolist') else str(X)[:200]}")
            self.trainingLogUpdated.emit(f"  - y前5个值: {y[:5].tolist() if hasattr(y, 'tolist') else str(y)[:200]}")
                
            if cleaning_info["final_count"] < 2:
                self.trainingError.emit(f"数据清理后样本数量不足({cleaning_info['final_count']})，无法进行训练")
                return None, None, None
            
            # 额外检查：确保有足够的数据进行训练和测试分割
            min_test_samples = max(1, int(cleaning_info["final_count"] * 0.2))  # 至少1个测试样本
            if cleaning_info["final_count"] < 4:  # 至少需要4个样本才能分割成训练和测试集
                self.trainingError.emit(f"数据样本过少({cleaning_info['final_count']})，至少需要4个样本进行训练")
                return None, None, None
            
            self.trainingLogUpdated.emit(f"数据清理成功，将用于训练的样本数: {cleaning_info['final_count']}")
            
            return X, y, cleaning_info
            
        except Exception as e:
            self.trainingLogUpdated.emit(f"数据准备失败: {str(e)}")
            return None, None, None
    
    def _apply_feature_mapping(self):
        """应用特征映射，直接按照model.py中Input类的to_list方法顺序返回特征"""
        
        # 根据任务类型获取对应Input类的特征顺序
        def get_model_feature_order(task_type):
            """获取模型特征的标准顺序"""
            if task_type == "glr":
                # GLRInput.to_list() 的顺序 - 9个特征
                return GLRInput.get_features()
            elif task_type in ["production"]:
                # QFInput 和 SVRInput 的 to_list() 顺序相同 - 11个特征
                return QFInput.get_features()
            elif task_type in ["head"]:
                # SVRInput 的 to_list() 顺序 - 11个特征
                return SVRInput.get_features()
            else:
                self.trainingLogUpdated.emit(f"警告: 未知任务类型 {task_type}")
                return []
        
        # 获取模型期望的特征顺序
        model_feature_order = get_model_feature_order(self.task_type)
        
        if not model_feature_order:
            self.trainingLogUpdated.emit("无法确定模型特征顺序，使用用户原始特征")
            return self.features
        
        self.trainingLogUpdated.emit(f"任务类型 {self.task_type} 期望 {len(model_feature_order)} 个特征: {model_feature_order}")
        
        # 如果有特征映射，直接按照to_list顺序从映射中取特征
        if self.feature_mapping:
            self.trainingLogUpdated.emit("应用特征映射:")
            self.trainingLogUpdated.emit(f"特征映射字典: {self.feature_mapping}")
            mapped_features = []
            
            for i, model_feature in enumerate(model_feature_order):
                if model_feature in self.feature_mapping:
                    user_feature = self.feature_mapping[model_feature]
                    mapped_features.append(user_feature)
                    self.trainingLogUpdated.emit(f"  [{i}] {model_feature} → {user_feature}")
                else:
                    self.trainingLogUpdated.emit(f"  [{i}] 错误: 特征映射中缺少 {model_feature}")
                    self.trainingLogUpdated.emit(f"映射不完整，返回原始特征: {self.features}")
                    return self.features  # 映射不完整，返回原始特征
            
            self.trainingLogUpdated.emit(f"映射完成，最终特征数量: {len(mapped_features)}")
            self.trainingLogUpdated.emit(f"映射完成，最终特征顺序: {mapped_features}")
            self.trainingLogUpdated.emit(f"期望特征顺序: {model_feature_order}")
            return mapped_features
        else:
            # 没有特征映射，直接取用户特征的前N个
            expected_count = len(model_feature_order)
            if len(self.features) >= expected_count:
                selected_features = self.features[:expected_count]
                self.trainingLogUpdated.emit(f"无特征映射，取前 {expected_count} 个用户特征:")
                self.trainingLogUpdated.emit(f"原始用户特征: {self.features}")
                self.trainingLogUpdated.emit(f"选择的特征: {selected_features}")
                return selected_features
            else:
                self.trainingLogUpdated.emit(f"用户特征数量 {len(self.features)} 少于期望的 {expected_count} 个")
                self.trainingLogUpdated.emit(f"返回所有用户特征: {self.features}")
                return self.features
    
    def _create_predictor(self, X, y, config):
        """根据任务类型创建预测器"""
        try:
            if self.task_type == "head":
                # TDH预测任务
                self.trainingLogUpdated.emit("创建TDH预测器...")
                return TDHPredictor(X, y, config)
                
            elif self.task_type == "production":
                # QF产量预测任务
                self.trainingLogUpdated.emit("创建QF预测器...")
                return QFPredictor(X, y, config)
                
            elif self.task_type == "glr":
                # GLR气液比预测任务
                self.trainingLogUpdated.emit("创建GLR预测器...")
                self.trainingLogUpdated.emit(f"输入特征维度: {X.shape}")
                self.trainingLogUpdated.emit("注意: GLR模型将自动应用多项式特征变换，特征维度会从9扩展到54")
                return GLRPredictor(X, y, config)
                
            else:
                self.trainingLogUpdated.emit(f"未知任务类型: {self.task_type}")
                return None
                
        except Exception as e:
            self.trainingLogUpdated.emit(f"创建预测器失败: {str(e)}")
            logger.exception(f"创建预测器异常: {e}")
            return None
    
    def _setup_callbacks(self):
        """设置回调函数"""
        # 进度回调
        progress_callback = ThreadProgressCallback(self)
        self.predictor.add_callback(progress_callback)
        
        # 指标回调
        metrics_funcs = {
            'r2_score': lambda y_true, y_pred: 1 - np.sum((y_true - y_pred)**2) / np.sum((y_true - np.mean(y_true))**2),
            'mse': lambda y_true, y_pred: np.mean((y_true - y_pred)**2),
            'mae': lambda y_true, y_pred: np.mean(np.abs(y_true - y_pred))
        }
        metrics_callback = ThreadMetricsCallback(self, metrics_funcs)
        self.predictor.add_callback(metrics_callback)
    
    def _prepare_training_results(self, train_result, test_result):
        """准备训练结果数据"""
        # 提取训练和测试指标
        train_metrics = train_result.get('train_metrics', {})
        test_metrics = train_result.get('test_metrics', {})
        
        self.trainingLogUpdated.emit(f"准备训练结果数据:")
        self.trainingLogUpdated.emit(f"  - 训练指标: {list(train_metrics.keys())}")
        self.trainingLogUpdated.emit(f"  - 测试指标: {list(test_metrics.keys())}")
    
        # 生成绘图数据
        self.trainingLogUpdated.emit("开始生成绘图数据...")
        plot_data = self._generate_plot_data(test_result)
        
        # 计算特征重要性（如果支持）
        feature_importance = self._calculate_feature_importance()
        
        result = {
            "model_name": self.model_name,
            "model_type": self.predictor.model_info.model_type.upper(),
            "task_type": self.task_type,
            "table_names": self.table_names,
            "features": self.features,
            "target": self.target_label,
            "feature_mapping": self.feature_mapping,
            
            # 训练指标
            "train_mape": train_metrics.get('mape', 0),
            "train_r2": train_metrics.get('r2', 0),
            "train_mse": train_metrics.get('mse', 0),
            "train_mae": train_metrics.get('mae', 0),
            
            # 测试指标
            "test_mape": test_metrics.get('mape', 0),
            "test_r2": test_metrics.get('r2', 0),
            "test_mse": test_metrics.get('mse', 0),
            "test_mae": test_metrics.get('mae', 0),
            
            # 绘图数据
            "r2_plot_data": plot_data,
            "error_plot_data": plot_data,
            
            # 其他信息
            "feature_importance": feature_importance,
            "training_time": "训练完成",
            "trained_at": pd.Timestamp.now().isoformat()
        }
        
        self.trainingLogUpdated.emit(f"结果数据准备完成，绘图数据长度检查:")
        self.trainingLogUpdated.emit(f"  - actual_train: {len(plot_data.get('actual_train', []))}")
        self.trainingLogUpdated.emit(f"  - predicted_train: {len(plot_data.get('predicted_train', []))}")
        self.trainingLogUpdated.emit(f"  - actual_test: {len(plot_data.get('actual_test', []))}")
        self.trainingLogUpdated.emit(f"  - predicted_test: {len(plot_data.get('predicted_test', []))}")
        
        return result
    
    def _generate_plot_data(self, test_result):
        """生成绘图数据"""
        try:
            y_true = test_result.get('y_true', [])
            y_pred = test_result.get('y_pred', [])
            
            self.trainingLogUpdated.emit(f"生成绘图数据 - 测试数据长度: y_true={len(y_true)}, y_pred={len(y_pred)}")
            
            # 转换测试数据为列表格式
            test_actual = y_true.tolist() if hasattr(y_true, 'tolist') else (y_true if isinstance(y_true, list) else [])
            test_predicted = y_pred.tolist() if hasattr(y_pred, 'tolist') else (y_pred if isinstance(y_pred, list) else [])
            
            # 获取训练集预测
            train_actual = []
            train_predicted = []
            
            if hasattr(self.predictor, 'X_train') and hasattr(self.predictor, 'y_train'):
                try:
                    self.trainingLogUpdated.emit(f"找到训练数据 - X_train: {self.predictor.X_train.shape}, y_train: {self.predictor.y_train.shape}")
                    
                    # 使用预测器的批量预测方法
                    train_pred = self.predictor._predict_batch(self.predictor.X_train)
                    
                    train_actual = self.predictor.y_train.tolist() if hasattr(self.predictor.y_train, 'tolist') else self.predictor.y_train
                    train_predicted = train_pred.tolist() if hasattr(train_pred, 'tolist') else train_pred
                    
                    self.trainingLogUpdated.emit(f"训练数据长度: actual={len(train_actual)}, predicted={len(train_predicted)}")
                    
                except Exception as e:
                    self.trainingLogUpdated.emit(f"获取训练集预测失败: {str(e)}")
                    train_actual = []
                    train_predicted = []
            else:
                self.trainingLogUpdated.emit("预测器缺少 X_train 或 y_train 属性")
            
            result = {
                "actual_train": train_actual,
                "predicted_train": train_predicted,
                "actual_test": test_actual,
                "predicted_test": test_predicted
            }
            
            # 记录最终结果
            self.trainingLogUpdated.emit(f"绘图数据生成完成: train_len={len(train_actual)}, test_len={len(test_actual)}")
            
            return result
            
        except Exception as e:
            error_msg = f"生成绘图数据失败: {str(e)}"
            self.trainingLogUpdated.emit(error_msg)
            logger.exception(error_msg)
            return {"actual_train": [], "predicted_train": [], "actual_test": [], "predicted_test": []}
    
    def _calculate_feature_importance(self):
        """计算特征重要性"""
        try:
            if hasattr(self.predictor, 'model'):
                model = self.predictor.model
                
                if hasattr(model, 'feature_importances_'):
                    # 随机森林等模型
                    importance = model.feature_importances_
                elif hasattr(model, 'coef_'):
                    # 线性模型、SVR等
                    importance = np.abs(model.coef_).flatten()
                else:
                    # 不支持特征重要性的模型，返回均匀分布
                    feature_count = len(self.features)
                    importance = np.ones(feature_count) / feature_count
                
                return [
                    {"feature": feature, "importance": float(imp)}
                    for feature, imp in zip(self.features, importance)
                ]
            
            return []
            
        except Exception as e:
            self.trainingLogUpdated.emit(f"计算特征重要性失败: {str(e)}")
            return []
    
    def _generate_model_name(self):
        """生成模型名称"""
        tables_str = "_".join(self.table_names[:2])
        timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
        return f"model_{tables_str}_{timestamp}"
    
    def _save_model_info(self, result_data):
        """保存模型信息到线程对象"""
        self.model_info = {
            "model": self.predictor.model,
            "scaler": self.predictor.scaler,
            "model_instance": self.predictor,
            "task_type": self.task_type,
            "features": self.feature_mapping.values() if self.feature_mapping else self.features,
            "original_features": self.features,
            "feature_mapping": self.feature_mapping,
            "target": self.target_label,
            "type": self.predictor.model_info.model_type.upper(),
            "table_names": self.table_names,
            **{k: v for k, v in result_data.items() if k.startswith(('train_', 'test_'))},
            "r2_plot_data": result_data.get("r2_plot_data", {}),
            "error_plot_data": result_data.get("error_plot_data", {}),
            "trained_at": result_data.get("trained_at")
        }


class ContinuousLearningController(QObject):
    """持续学习控制器 - 重构为使用统一预测器接口"""
    
    # 信号定义
    taskSelectionChanged = Signal(int)
    phaseChanged = Signal(str)
    predictionStarted = Signal(int)
    predictionCompleted = Signal(int, dict)
    predictionFailed = Signal(int, str)
    dataPreparationStarted = Signal(int)
    dataPreparationCompleted = Signal(int, dict)
    trainingStarted = Signal(int)
    trainingCompleted = Signal(str, dict)
    evaluationStarted = Signal(int)
    evaluationCompleted = Signal(int, dict)
    
    # 深度学习可视化信号
    lossDataUpdated = Signal(dict)
    trainingProgressUpdated = Signal(float, dict)
    trainingLogUpdated = Signal(str)
    
    # 数据管理信号
    dataListUpdated = Signal(list)
    dataLoaded = Signal(dict)
    dataAdded = Signal(dict)
    dataUpdated = Signal(dict)
    dataDeleted = Signal(int)
    
    # 模型管理信号
    modelListUpdated = Signal(list)
    trainingProgressChanged = Signal(float)
    trainingError = Signal(str)
    modelSaved = Signal(str, str)
    testResultsUpdated = Signal(dict)
    testProgressUpdated = Signal(float)
    testLogUpdated = Signal(str)
    
    # 数据库信号
    tablesListUpdated = Signal(list)
    fieldsListUpdated = Signal(list)
    
    def __init__(self):
        super().__init__()
        self._selected_task = -1
        self._current_phase = "task_selection"
        self._task_names = {
            0: {"zh": "扬程预测", "en": "Head Prediction"},
            1: {"zh": "产量预测", "en": "Production Prediction"}, 
            2: {"zh": "气液比预测", "en": "Gas-Liquid Ratio Prediction"}
        }
        self._ml_service = None
        self._project_id = -1
        self._db_path = "data/oil_analysis.db"
        
        # 训练配置 - 使用新的配置类
        self._training_config = TrainingConfig(
            learning_rate=0.001,
            epochs=1000,
            batch_size=48,
            patience=100,
            test_size=0.2
        )
        
        # 数据管理
        self._training_data = []
        self._test_data = []
        self._selected_tables = []
        self._selected_features = []
        self._target_label = ""
        
        # 模型管理 - 使用统一的预测器接口
        self._predictors = {}  # 存储预测器实例
        self._models = {}      # 存储模型信息
        self._current_model = None
        self._training_history = {}
        self._test_results = {}
        
        # Excel文件路径
        self._excel_file_path = ""
        
        # 训练线程
        self._training_thread = None
        self._mutex = QMutex()
    
    # ================== 训练参数设置功能 ==================
    
    @Slot(float, int, int, int)
    def setTrainingParams(self, learning_rate, epochs, batch_size, patience):
        """设置训练参数 - 使用新的配置系统"""
        self._training_config.learning_rate = learning_rate
        self._training_config.epochs = epochs
        self._training_config.batch_size = batch_size
        self._training_config.patience = patience
        
        logger.info(f"训练参数已更新: lr={learning_rate}, epochs={epochs}, batch_size={batch_size}, patience={patience}")
    
    @Slot(result='QVariant')
    def getTrainingParams(self):
        """获取当前训练参数"""
        return {
            'learning_rate': self._training_config.learning_rate,
            'epochs': self._training_config.epochs,
            'batch_size': self._training_config.batch_size,
            'patience': self._training_config.patience
        }
        
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
    
    # ================== 模型训练功能 - 使用统一接口 ==================
    
    @Slot(int, list, list, str, str, dict)
    def startModelTrainingWithData(self, project_id, table_names, features, target_label, task_type="", feature_mapping=None):
        """使用指定数据开始模型训练 - 使用统一预测器接口"""
        try:
            # 如果有正在运行的训练线程，先停止它
            if self._training_thread and self._training_thread.isRunning():
                self._training_thread.quit()
                self._training_thread.wait()
            
            # 准备训练参数
            training_params = {
                'learning_rate': self._training_config.learning_rate,
                'epochs': self._training_config.epochs,
                'batch_size': self._training_config.batch_size,
                'patience': self._training_config.patience
            }
            
            # 创建新的训练线程
            self._training_thread = ModelTrainingThread(
                project_id, table_names, features, target_label, task_type, 
                self._db_path, feature_mapping, training_params
            )
            
            # 连接信号
            self._training_thread.trainingProgressUpdated.connect(self.trainingProgressUpdated.emit)
            self._training_thread.trainingCompleted.connect(self._on_training_completed)
            self._training_thread.trainingError.connect(self.trainingError.emit)
            self._training_thread.trainingLogUpdated.connect(self.trainingLogUpdated.emit)
            
            # 连接损失数据信号
            def on_loss_data_relay(loss_data):
                logger.info(f"=== ContinuousLearningController: 中继损失数据 ===")
                logger.info(f"接收到的损失数据: {loss_data}")
                try:
                    self.lossDataUpdated.emit(loss_data)
                    logger.info("损失数据信号发射到UI成功")
                except Exception as e:
                    logger.error(f"发射损失数据信号到UI失败: {e}")
            
            self._training_thread.lossDataUpdated.connect(on_loss_data_relay)
            
            # 启动训练
            self.trainingStarted.emit(project_id)
            self._training_thread.start()
            
        except Exception as e:
            error_msg = f"启动模型训练失败: {str(e)}"
            logger.error(error_msg)
            self.trainingError.emit(error_msg)
    
    def _on_training_completed(self, model_name, result):
        """训练完成回调 - 使用统一接口"""
        try:
            if self._training_thread and self._training_thread.model_info:
                # 保存预测器实例
                model_name_str = str(model_name)
                self._predictors[model_name_str] = self._training_thread.predictor
                self._models[model_name_str] = self._training_thread.model_info
                self._current_model = model_name_str
                
                logger.info(f"设置 _current_model = {self._current_model}")
                
                # 发送完成信号
                self.trainingCompleted.emit(model_name_str, result)
                self.modelListUpdated.emit(list(self._models.keys()))
                
                logger.info(f"模型训练完成: {model_name_str}")
            else:
                logger.warning("训练线程或模型信息为空")
            
        except Exception as e:
            error_msg = f"训练完成处理失败: {str(e)}"
            logger.error(error_msg)
            self.trainingError.emit(error_msg)
    
    # ================== 模型管理功能 - 使用统一接口 ==================
    
    @Slot(result=list)
    def getAvailableModels(self):
        """获取可用模型列表 - 包括从任务默认文件夹扫描的模型"""
        models = []
        
        # 添加当前内存中的模型
        models.extend(list(self._models.keys()))
        
        # 扫描任务默认文件夹中的模型
        try:
            base_path = Path(__file__).parent.parent
            save_dirs = {
                "TDHsave": "TDH",
                "QFsave": "QF", 
                "GLRsave": "GLR"
            }
            
            for folder_name, task_prefix in save_dirs.items():
                save_dir = base_path / folder_name
                if save_dir.exists():
                    # 扫描文件夹中的模型目录
                    for model_dir in save_dir.iterdir():
                        if model_dir.is_dir():
                            model_name = model_dir.name
                            # 避免重复添加
                            if model_name not in models:
                                models.append(model_name)
                            
        except Exception as e:
            logger.warning(f"扫描模型文件夹失败: {str(e)}")
        
        return models
    
    @Slot(str, result=dict)
    def getModelInfo(self, model_name):
        """获取模型信息"""
        if model_name in self._models:
            model_info = self._models[model_name].copy()
            # 移除不能序列化的对象
            model_info.pop('model', None)
            model_info.pop('scaler', None)
            model_info.pop('model_instance', None)
            return model_info
        return {}
    
    @Slot(str, result=str)
    def getModelPath(self, model_name):
        """获取模型的完整文件路径"""
        try:
            base_path = Path(__file__).parent.parent
            save_dirs = ["TDHsave", "QFsave", "GLRsave"]
            
            # 首先检查是否是内存中的模型
            if model_name in self._models:
                model_info = self._models[model_name]
                # 如果模型信息中有保存路径，返回它
                if 'save_path' in model_info:
                    return str(model_info['save_path'])
            
            # 在各个保存文件夹中查找模型
            for save_dir_name in save_dirs:
                save_dir = base_path / save_dir_name
                model_dir = save_dir / model_name
                if model_dir.exists() and model_dir.is_dir():
                    return str(model_dir)
            
            logger.warning(f"未找到模型路径: {model_name}")
            return ""
            
        except Exception as e:
            logger.error(f"获取模型路径失败: {str(e)}")
            return ""
    
    @Slot(str, result=str)
    def saveModelWithDialog(self, model_name):
        """通过对话框保存模型 - 使用统一接口"""
        try:
            if model_name not in self._predictors:
                raise ValueError("预测器不存在")
            
            predictor = self._predictors[model_name]
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 设置默认路径
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
            
            # 生成模型文件夹名
            timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
            model_folder_name = f"{task_name}-{timestamp}"
            default_full_path = default_save_dir / model_folder_name
            
            # 使用文件对话框
            from PySide6.QtWidgets import QFileDialog
            save_path, _ = QFileDialog.getSaveFileName(
                None,
                f"保存 {task_name} 模型",
                str(default_full_path),
                "模型文件夹 (*);;所有文件 (*)"
            )
            
            if save_path:
                # 使用预测器的统一保存接口
                save_path_obj = Path(save_path)
                model_folder_name = save_path_obj.name
                
                success = predictor.save_model(model_folder_name)
                
                if success:
                    # 计算实际保存路径
                    if task_type == "head":
                        actual_save_path = default_base_path / "TDHsave" / model_folder_name
                    elif task_type == "production":
                        actual_save_path = default_base_path / "QFsave" / model_folder_name
                    elif task_type == "glr":
                        actual_save_path = default_base_path / "GLRsave" / model_folder_name
                    else:
                        actual_save_path = save_path_obj
                    
                    logger.info(f"模型已保存到: {actual_save_path}")
                    self.modelSaved.emit(model_name, str(actual_save_path))
                    return str(actual_save_path)
                else:
                    logger.error("模型保存失败")
                    return ""
            
            return ""  # 用户取消保存
            
        except Exception as e:
            error_msg = f"保存模型失败: {str(e)}"
            logger.error(error_msg)
            return ""
    
    @Slot(str, str, result=str)
    def saveModelWithCustomName(self, model_name, custom_name):
        """使用自定义名称保存模型 - 使用统一接口"""
        try:
            if model_name not in self._predictors:
                logger.warning(f"预测器 {model_name} 不存在")
                return ""
            
            predictor = self._predictors[model_name]
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 根据任务类型选择默认保存目录
            default_base_path = Path(__file__).parent.parent
            if task_type == "head":
                task_name = "TDH"
            elif task_type == "production":
                task_name = "QF"
            elif task_type == "glr":
                task_name = "GLR"
            else:
                task_name = "MODEL"
            
            # 生成最终名称
            final_name = f"{task_name}-{custom_name}" if custom_name else f"{task_name}-{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}"
            
            # 使用预测器的统一保存接口
            success = predictor.save_model(final_name)
            
            if success:
                # 计算实际保存路径
                if task_type == "head":
                    actual_save_path = default_base_path / "TDHsave" / final_name
                elif task_type == "production":
                    actual_save_path = default_base_path / "QFsave" / final_name
                elif task_type == "glr":
                    actual_save_path = default_base_path / "GLRsave" / final_name
                else:
                    actual_save_path = default_base_path / "saved_models" / final_name
                
                logger.info(f"模型已保存到: {actual_save_path}")
                self.modelSaved.emit(model_name, str(actual_save_path))
                return str(actual_save_path)
            else:
                logger.error("模型保存失败")
                return ""
            
        except Exception as e:
            logger.error(f"使用自定义名称保存模型失败: {e}")
            return ""
    
    @Slot(result=str)
    def getCurrentModelName(self):
        """获取当前训练的模型名称"""
        current_model = self._current_model if self._current_model else ""
        logger.info(f"getCurrentModelName 被调用，返回: {current_model}")
        return current_model
    
    @Slot(result=str)
    def saveCurrentModel(self):
        """保存当前训练的模型 - 使用统一接口"""
        try:
            if not self._current_model:
                logger.warning("没有当前模型可保存")
                return ""
            
            model_name = self._current_model
            logger.info(f"开始保存当前模型: {model_name}")
            
            if model_name not in self._predictors:
                logger.warning(f"预测器 {model_name} 不存在")
                return ""
            
            predictor = self._predictors[model_name]
            model_info = self._models[model_name]
            task_type = model_info.get('task_type', 'unknown')
            
            # 根据任务类型生成模型名称和保存路径
            default_base_path = Path(__file__).parent.parent
            timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
            
            if task_type == "head":
                save_name = f"TDH-{timestamp}"
            elif task_type == "production":
                save_name = f"QF-{timestamp}"
            elif task_type == "glr":
                save_name = f"GLR-{timestamp}"
            else:
                save_name = f"MODEL-{timestamp}"
            
            # 使用预测器的统一保存接口
            success = predictor.save_model(save_name)
            
            if success:
                # 计算实际保存路径
                if task_type == "head":
                    actual_save_path = default_base_path / "TDHsave" / save_name
                elif task_type == "production":
                    actual_save_path = default_base_path / "QFsave" / save_name
                elif task_type == "glr":
                    actual_save_path = default_base_path / "GLRsave" / save_name
                else:
                    actual_save_path = default_base_path / "saved_models" / save_name
                
                logger.info(f"模型已成功保存到: {actual_save_path}")
                self.modelSaved.emit(model_name, str(actual_save_path))
                return str(actual_save_path)
            else:
                logger.error("模型保存失败")
                return ""
            
        except Exception as e:
            error_msg = f"保存当前模型失败: {str(e)}"
            logger.error(error_msg)
            return ""
    
    # ================== 模型测试功能 - 使用统一接口 ==================
    
    @Slot(str, str, list, list, str, dict)
    def startModelTestingWithConfiguration(self, model_path, model_type, data_tables, features, target_label, feature_mapping):
        """使用完整配置开始模型测试 - 使用统一接口"""
        try:
            self.testLogUpdated.emit("开始模型测试...")
            self.testProgressUpdated.emit(0.0)
            print(f"开始测试模型: {model_path}, 类型: {model_type}")
            # 加载外部模型 - 创建预测器实例
            predictor = self._load_external_predictor(model_path, model_type)
            if predictor is None:
                error_msg = f"无法加载模型: {model_path},{model_type}"
                self.testLogUpdated.emit(error_msg)
                return
            
            self.testProgressUpdated.emit(20.0)
            
            # 加载测试数据 - 传递任务类型信息
            task_type = self._infer_task_type_from_model_type(model_type, model_path)
            X_test, y_test = self._load_test_data(data_tables, features, target_label, feature_mapping, task_type)
            if X_test is None or y_test is None:
                error_msg = "测试数据加载失败"
                self.testLogUpdated.emit(error_msg)
                return
            
            self.testProgressUpdated.emit(60.0)
            
            # 使用预测器的统一测试接口
            self.testLogUpdated.emit("开始预测...")
            
            # 手动设置测试数据到预测器
            predictor.X_test = X_test
            predictor.y_test = y_test
            predictor.is_trained = True
            
            # 执行测试
            test_result = predictor.test()
            
            self.testProgressUpdated.emit(90.0)
            
            # 准备结果数据
            test_results = {
                "model_path": model_path,
                "model_type": model_type,
                "test_tables": data_tables,
                "features": features,
                "target": target_label,
                "feature_mapping": feature_mapping,
                "test_samples": len(y_test),
                "tested_at": pd.Timestamp.now().isoformat(),
                **test_result['metrics'],
                "error_plot_data": {
                    "actual": test_result['y_true'].tolist(),
                    "predicted": test_result['y_pred'].tolist()
                }
            }
            
            self.testProgressUpdated.emit(100.0)
            self.testLogUpdated.emit(f"测试完成! MAPE: {test_results.get('mape', 0):.2f}%, R²: {test_results.get('r2', 0):.4f}")
            
            # 发送测试结果
            self.testResultsUpdated.emit(test_results)
            
        except Exception as e:
            error_msg = f"模型测试失败: {str(e)}"
            logger.error(error_msg)
            self.testLogUpdated.emit(error_msg)
    
    def _load_external_predictor(self, model_path, model_type):
        """加载外部预测器 - 使用统一接口"""
        try:
            path_obj = Path(model_path)
            # 根据模型类型或路径特征判断使用哪个预测器
            if "GLR" in model_type.upper() or "glr" in model_path.lower():
                predictor = GLRPredictor([], [])
                success = predictor.load_model(model_path)
                if success:
                    self.testLogUpdated.emit("GLR预测器加载成功")
                    return predictor
                    
            elif "TDH" in model_type.upper() or "tdh" in model_path.lower() or "head" in model_path.lower():
                predictor = TDHPredictor([], [])
                success = predictor.load_model(model_path)
                if success:
                    self.testLogUpdated.emit("TDH预测器加载成功")
                    return predictor
                    
            elif "QF" in model_type.upper() or "qf" in model_path.lower() or "production" in model_path.lower():
                predictor = QFPredictor([], [])
                success = predictor.load_model(model_path)
                if success:
                    self.testLogUpdated.emit("QF预测器加载成功")
                    return predictor
            
            self.testLogUpdated.emit(f"无法识别模型类型: {model_type}")
            return None
            
        except Exception as e:
            self.testLogUpdated.emit(f"加载预测器失败: {str(e)}")
            return None
    
    def _infer_task_type_from_model_type(self, model_type, model_path):
        """从模型类型和路径推断任务类型"""
        try:
            model_type_upper = model_type.upper()
            model_path_lower = model_path.lower()
            
            if "GLR" in model_type_upper or "glr" in model_path_lower:
                return "glr"
            elif "TDH" in model_type_upper or "tdh" in model_path_lower or "head" in model_path_lower:
                return "head"
            elif "QF" in model_type_upper or "qf" in model_path_lower or "production" in model_path_lower:
                return "production"
            else:
                self.testLogUpdated.emit(f"无法从模型类型 {model_type} 和路径 {model_path} 推断任务类型")
                return "unknown"
                
        except Exception as e:
            self.testLogUpdated.emit(f"推断任务类型失败: {str(e)}")
            return "unknown"
    
    def _load_test_data(self, data_tables, features, target_label, feature_mapping, task_type=None):
        """加载测试数据"""
        try:
            # 合并所有数据表
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
                self.testLogUpdated.emit("没有成功加载任何数据表")
                return None, None
            
            # 合并数据
            combined_df = pd.concat(all_data, ignore_index=True)
            self.testLogUpdated.emit(f"合并数据完成: 总共 {len(combined_df)} 行")
            
            # 使用与训练时相同的特征映射逻辑
            def get_model_feature_order(task_type):
                """获取模型特征的标准顺序（与训练时保持一致）"""
                if task_type == "glr":
                    return 
                    return ["Geopressure", "ProduceIndex", "BHT", "Qf", "BSW", "API", "GOR", "Pb", "WHP"]
                elif task_type in ["production", "head"]:
                    return ["phdm", "freq", "Pr", "IP", "BHT", "Qf", "BSW", "API", "GOR", "Pb", "WHP"]
                else:
                    self.testLogUpdated.emit(f"警告: 未知任务类型 {task_type}")
                    return []
            
            # 获取模型期望的特征顺序
            model_feature_order = get_model_feature_order(task_type) if task_type else []
            
            if not model_feature_order:
                self.testLogUpdated.emit("无法确定模型特征顺序，使用用户原始特征")
                mapped_features = features
            elif feature_mapping:
                # 有特征映射，直接按照to_list顺序从映射中取特征
                self.testLogUpdated.emit("应用特征映射:")
                self.testLogUpdated.emit(f"特征映射字典: {feature_mapping}")
                self.testLogUpdated.emit(f"期望特征顺序: {model_feature_order}")
                mapped_features = []
                
                for i, model_feature in enumerate(model_feature_order):
                    if model_feature in feature_mapping:
                        user_feature = feature_mapping[model_feature]
                        mapped_features.append(user_feature)
                        self.testLogUpdated.emit(f"  [{i}] {model_feature} → {user_feature}")
                    else:
                        self.testLogUpdated.emit(f"  [{i}] 错误: 特征映射中缺少 {model_feature}")
                        self.testLogUpdated.emit(f"映射不完整，返回原始特征: {features}")
                        mapped_features = features  # 映射不完整，返回原始特征
                        break
            else:
                # 没有特征映射，直接取用户特征的前N个
                expected_count = len(model_feature_order)
                if len(features) >= expected_count:
                    mapped_features = features[:expected_count]
                    self.testLogUpdated.emit(f"无特征映射，取前 {expected_count} 个用户特征:")
                    self.testLogUpdated.emit(f"原始用户特征: {features}")
                    self.testLogUpdated.emit(f"选择的特征: {mapped_features}")
                else:
                    self.testLogUpdated.emit(f"用户特征数量 {len(features)} 少于期望的 {expected_count} 个")
                    self.testLogUpdated.emit(f"返回所有用户特征: {features}")
                    mapped_features = features
            
            self.testLogUpdated.emit(f"最终特征数量: {len(mapped_features)}")
            self.testLogUpdated.emit(f"最终特征顺序: {mapped_features}")
            self.testLogUpdated.emit(f"期望特征顺序: {model_feature_order}")
            
            # 验证特征顺序是否正确
            if len(mapped_features) == len(model_feature_order) and feature_mapping:
                self.testLogUpdated.emit("特征顺序验证:")
                for i, (expected, actual) in enumerate(zip(model_feature_order, mapped_features)):
                    if expected in feature_mapping and feature_mapping[expected] == actual:
                        self.testLogUpdated.emit(f"  ✓ [{i}] {expected} → {actual}")
                    else:
                        self.testLogUpdated.emit(f"  ✗ [{i}] 期望 {expected}，实际 {actual}")
            
            # 检查必要的列
            required_cols = mapped_features + [target_label]
            missing_cols = [col for col in required_cols if col not in combined_df.columns]
            if missing_cols:
                self.testLogUpdated.emit(f"数据中缺少必要的列: {missing_cols}")
                return None, None
            
            X_test = combined_df[mapped_features].values
            y_test = combined_df[target_label].values
            
            # 移除包含NaN的行
            valid_indices = ~(np.isnan(X_test).any(axis=1) | np.isnan(y_test))
            X_test = X_test[valid_indices]
            y_test = y_test[valid_indices]
            
            self.testLogUpdated.emit(f"有效测试样本: {len(X_test)} 个")
            
            if len(X_test) == 0:
                self.testLogUpdated.emit("没有有效的测试样本")
                return None, None
            
            return X_test, y_test
            
        except Exception as e:
            self.testLogUpdated.emit(f"加载测试数据失败: {str(e)}")
            return None, None
    
    # ================== 其他功能保持不变 ==================
    
    # Excel文件上传功能
    @Slot(str)
    def setDataFilePath(self, file_path):
        """设置数据文件路径"""
        self._excel_file_path = file_path
        logger.info(f"设置数据文件路径: {file_path}")
    
    @Slot(result=dict)
    @Slot(str, result=dict)
    def uploadDataFileToDatabase(self, custom_table_name=""):
        """上传数据文件到数据库"""
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
                table_name = custom_table_name.strip()
            else:
                timestamp = int(time.time())
                table_name = f"data_upload_{timestamp}"
            
            # 连接数据库
            conn = sqlite3.connect(self._db_path)
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
    
    # 数据库管理功能
    @Slot(result=list)
    def getAvailableTables(self):
        """获取数据库中的可用表"""
        try:
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            all_tables = [row[0] for row in cursor.fetchall()]
            conn.close()
            
            # 过滤只保留data或test开头的表
            filtered_tables = [table for table in all_tables if table.startswith('data') or table.startswith('test')]
            
            logger.info(f"Found {len(filtered_tables)} filtered tables: {filtered_tables}")
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
    
    @Slot(str, result='QVariant')
    def previewTableData(self, table_name):
        """预览表数据"""
        try:
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            
            # 获取前20行数据
            cursor.execute(f"SELECT * FROM \"{table_name}\" LIMIT 20")
            rows = cursor.fetchall()
            
            # 获取列名
            cursor.execute(f"PRAGMA table_info({table_name})")
            columns = [row[1] for row in cursor.fetchall()]
            
            conn.close()
            
            if not rows:
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
        
    
    @Slot(str, result='QVariant')
    def deleteTable(self, table_name):
        """删除数据表"""
        try:
            conn = sqlite3.connect(self._db_path)
            cursor = conn.cursor()
            
            # 先检查表是否存在
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table_name,))
            exists = cursor.fetchone()
            if not exists:
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
    
    @Slot(str, result='QVariant')
    def downloadTemplate(self, task_type):
        """下载对应任务的Excel模板文件"""
        try:
            task_type = task_type.lower()
            
            # 定义每个任务类型的模板数据
            templates = {
                "glr": {
                    "filename": "GLR_预测模板.xlsx",
                    "headers_cn": [
                        "泵挂垂深", "射孔垂深", "地层压力", "生产指数", "井底温度", "期望产量", 
                        "含水率", "原油密度", "油气比", "泡点压力", "井口压力", "GLR目标值"
                    ],
                    "headers_en": [
                        "phdm", "freq", "Geopressure", "ProduceIndex", "BHT", "Qf", 
                        "BSW", "API", "GOR", "Pb", "WHP", "GLR_target"
                    ],
                    "units": [
                        "ft", "ft", "psi", "bbl/d/psi", "°F", "bbl/d", 
                        "%", "°API", "scf/bbl", "psi", "psi", "无量纲"
                    ],
                    "sample_data": [
                        [8500.0, 8200.0, 2500.0, 1.5, 180.0, 1500.0, 20.0, 35.0, 300.0, 1800.0, 120.0, 0.2],
                        [8200.0, 7800.0, 2400.0, 1.8, 175.0, 1800.0, 15.0, 38.0, 320.0, 1750.0, 100.0, 0.18],
                        [8800.0, 8400.0, 2600.0, 1.2, 185.0, 1200.0, 25.0, 32.0, 280.0, 1900.0, 140.0, 0.22]
                    ],
                    "description": "气液比(GLR)预测模型训练数据模板。基于GLRInput类的11个特征进行预测。",
                    "features_count": 11
                },
                "qf": {
                    "filename": "QF_预测模板.xlsx",
                    "headers_cn": [
                        "射孔垂深", "泵挂垂深", "油藏压力", "生产指数", "井底温度", "期望产量", 
                        "含水率", "原油密度", "油气比", "泡点压力", "井口压力", "QF目标值"
                    ],
                    "headers_en": [
                        "phdm", "freq", "Pr", "IP", "BHT", "Qf", 
                        "BSW", "API", "GOR", "Pb", "WHP", "QF_target"
                    ],
                    "units": [
                        "ft", "ft", "psi", "bbl/d/psi", "°F", "bbl/d", 
                        "%", "°API", "scf/bbl", "psi", "psi", "bbl/d"
                    ],
                    "sample_data": [
                        [8500.0, 55.0, 2500.0, 1.5, 180.0, 1500.0, 20.0, 35.0, 300.0, 1800.0, 120.0, 1520.0],
                        [8200.0, 60.0, 2400.0, 1.8, 175.0, 1800.0, 15.0, 38.0, 320.0, 1750.0, 100.0, 1850.0],
                        [8800.0, 50.0, 2600.0, 1.2, 185.0, 1200.0, 25.0, 32.0, 280.0, 1900.0, 140.0, 1180.0]
                    ],
                    "description": "产量(QF)预测模型训练数据模板。基于QFInput类的11个特征进行预测。",
                    "features_count": 11
                },
                "tdh": {
                    "filename": "TDH_预测模板.xlsx",
                    "headers_cn": [
                        "射孔垂深", "泵挂垂深", "油藏压力", "生产指数", "井底温度", "期望产量", 
                        "含水率", "原油密度", "油气比", "泡点压力", "井口压力", "TDH目标值"
                    ],
                    "headers_en": [
                        "phdm", "freq", "Pr", "IP", "BHT", "Qf", 
                        "BSW", "API", "GOR", "Pb", "WHP", "TDH_target"
                    ],
                    "units": [
                        "ft", "ft", "psi", "bbl/d/psi", "°F", "bbl/d", 
                        "%", "°API", "scf/bbl", "psi", "psi", "ft"
                    ],
                    "sample_data": [
                        [8500.0, 55.0, 2500.0, 1.5, 180.0, 1500.0, 20.0, 35.0, 300.0, 1800.0, 120.0, 8950.0],
                        [8200.0, 60.0, 2400.0, 1.8, 175.0, 1800.0, 15.0, 38.0, 320.0, 1750.0, 100.0, 8480.0],
                        [8800.0, 50.0, 2600.0, 1.2, 185.0, 1200.0, 25.0, 32.0, 280.0, 1900.0, 140.0, 9320.0]
                    ],
                    "description": "总扬程(TDH)预测模型训练数据模板。基于SVRInput类的11个特征进行预测。",
                    "features_count": 11
                }
            }
            
            if task_type not in templates:
                return {
                    "success": False,
                    "error": f"不支持的任务类型: {task_type}"
                }
            
            template_info = templates[task_type]
            
            # 使用文件保存对话框让用户选择保存位置
            from PySide6.QtWidgets import QFileDialog, QApplication
            if QApplication.instance():
                # 获取用户文档目录作为默认路径
                from PySide6.QtCore import QStandardPaths
                documents_path = QStandardPaths.writableLocation(QStandardPaths.DocumentsLocation)
                default_path = f"{documents_path}/{template_info['filename']}"
                
                # 弹出保存文件对话框
                file_path, _ = QFileDialog.getSaveFileName(
                    None,
                    "保存模板文件" if task_type.lower() in ['glr', 'qf', 'tdh'] else "Save Template File",
                    default_path,
                    "Excel files (*.xlsx);;All files (*.*)"
                )
                
                # 如果用户取消了保存
                if not file_path:
                    return {
                        "success": False,
                        "error": "用户取消了保存操作"
                    }
            else:
                # 如果没有GUI环境，使用默认路径
                from PySide6.QtCore import QStandardPaths
                documents_path = QStandardPaths.writableLocation(QStandardPaths.DocumentsLocation)
                file_path = f"{documents_path}/{template_info['filename']}"
            
            # 创建带有中文标题和单位行的DataFrame
            # 第一行：中文字段名
            # 第二行：单位行（实际使用时需要删除此行）
            # 第三行开始：示例数据
            excel_data = []
            excel_data.append(template_info["headers_cn"])  # 中文标题行
            excel_data.append(template_info["units"])       # 单位行
            excel_data.extend(template_info["sample_data"]) # 示例数据
            
            df = pd.DataFrame(excel_data)
            
            # 保存Excel文件，包含数据和说明
            with pd.ExcelWriter(file_path, engine='openpyxl') as writer:
                # 写入主数据表（不要列标题，因为我们已经在数据中包含了）
                df.to_excel(writer, sheet_name='数据模板', index=False, header=False)
                
                # 创建字段说明表
                field_desc_data = []
                field_desc_data.append(['中文字段名', '英文字段名', '单位', '说明'])
                
                # 添加每个字段的具体说明
                for i, (cn_name, en_name, unit) in enumerate(zip(
                    template_info["headers_cn"], 
                    template_info["headers_en"], 
                    template_info["units"]
                )):
                    if i == len(template_info["headers_cn"]) - 1:  # 目标字段
                        desc = f"{task_type.upper()}预测的目标值"
                    else:  # 特征字段
                        desc = f"{task_type.upper()}模型的输入特征"
                    
                    field_desc_data.append([cn_name, en_name, unit, desc])
                
                field_desc_df = pd.DataFrame(field_desc_data[1:], columns=field_desc_data[0])
                field_desc_df.to_excel(writer, sheet_name='字段说明', index=False)
                
                # 创建使用说明表
                description_df = pd.DataFrame({
                    '重要使用说明': [
                        '⚠️ 重要提醒：上传Excel文件时，必须删除第2行单位行！',
                        '',
                        '模板说明：' + template_info["description"],
                        '',
                        '模板结构：',
                        '• 第1行：中文字段名（请保持不变）',
                        '• 第2行：字段单位（仅供参考，上传时请删除此行）',
                        '• 第3行开始：示例数据（请替换为真实数据）',
                        '',
                        '数据要求：',
                        '• 数值字段：请填入数字，避免文本',
                        '• 单位：请按照第2行显示的单位填写数据',
                        '',
                        '数据质量要求：',
                        '• 避免空值和异常值',
                        '• 数值范围要合理（参考示例数据）',
                        '• 建议数据量不少于100条以获得更好训练效果',
                        '',
                        '使用步骤：',
                        '1. 保留第1行（中文字段名）',
                        '2. 删除第2行（单位行）',
                        '3. 删除第3行开始的示例数据',
                        '4. 填入您的真实数据',
                        '5. 检查数据格式和完整性',
                        '6. 保存文件并在数据管理界面上传',
                        '',
                        '⚠️ 特别注意：',
                        '• 上传时只保留第1行字段名和实际数据',
                        '• 必须删除第2行单位行，否则会影响数据导入',
                        '• 数据列顺序必须与模板保持一致',
                        '• 目标值列是您要预测的量（最后一列）',
                        '',
                        f'模板信息：',
                        f'• 任务类型：{task_type.upper()}预测模型',
                        f'• 输入特征数：{template_info["features_count"]}个',
                        f'• 对应模型类：{task_type.upper()}Input'
                    ]
                })
                description_df.to_excel(writer, sheet_name='使用说明', index=False, header=False)
            
            logger.info(f"成功创建{task_type.upper()}模板文件: {file_path}")
            return {
                "success": True,
                "message": f"模板已保存到: {file_path}",
                "file_path": file_path
            }
            
        except Exception as e:
            error_msg = f"下载模板失败: {str(e)}"
            logger.error(error_msg)
            return {
                "success": False,
                "error": error_msg
            }
    
    # Property 定义
    @Property(str, notify=phaseChanged)
    def currentPhase(self):
        return self._current_phase
        
    @currentPhase.setter
    def currentPhase(self, phase):
        if self._current_phase != phase:
            self._current_phase = phase
            self.phaseChanged.emit(phase)
            logger.info(f"阶段切换到: {phase}")
        
    @Property(int, notify=taskSelectionChanged)
    def selectedTask(self):
        return self._selected_task
        
    @selectedTask.setter 
    def selectedTask(self, task_id):
        if self._selected_task != task_id:
            self._selected_task = task_id
            self.taskSelectionChanged.emit(task_id)