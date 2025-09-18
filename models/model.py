import pickle
import sqlite3
from abc import ABC, ABCMeta, abstractmethod
from pathlib import Path
from typing import List, Dict, Any, Callable, Optional, Union
from dataclasses import dataclass
from enum import Enum

import joblib
import pandas as pd
import numpy as np
from PySide6.QtWidgets import QVBoxLayout, QPlainTextEdit, QWidget
from PySide6.QtCore import QObject, Signal
from sklearn.preprocessing import StandardScaler, PolynomialFeatures
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.metrics import mean_absolute_percentage_error, mean_absolute_error
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.svm import SVR
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.models import load_model as keras_load_model
from tensorflow.keras.layers import Dense, Dropout, Add, Input
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import Callback
import tensorflow as tf
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from loguru import logger
from models.eval import CustomMAPE


root = Path(__file__).parent.parent


class ABCQObjectMeta(type(QObject), ABCMeta):
    """组合 QObject 和 ABC 的元类，解决元类冲突"""
    pass


class CallbackEvent(Enum):
    """回调事件类型"""
    TRAINING_START = "training_start"
    TRAINING_END = "training_end"
    EPOCH_START = "epoch_start"
    EPOCH_END = "epoch_end"
    BATCH_START = "batch_start"
    BATCH_END = "batch_end"
    VALIDATION_START = "validation_start"
    VALIDATION_END = "validation_end"
    PROGRESS_UPDATE = "progress_update"
    LOSS_UPDATE = "loss_update"
    METRIC_UPDATE = "metric_update"


class CallbackData:
    """回调数据容器"""
    def __init__(self, event: CallbackEvent, **kwargs):
        self.event = event
        self.data = kwargs
        
    def get(self, key: str, default=None):
        return self.data.get(key, default)


class BaseCallback:
    """基础回调类"""
    def __call__(self, callback_data: CallbackData):
        """回调函数入口"""
        event = callback_data.event
        if hasattr(self, f'on_{event.value}'):
            getattr(self, f'on_{event.value}')(callback_data)


class MetricsCallback(BaseCallback):
    """指标计算回调"""
    def __init__(self, metrics_funcs: Dict[str, Callable] = None):
        self.metrics_funcs = metrics_funcs or {}
        self.metrics_history = []
        
    def on_epoch_end(self, callback_data: CallbackData):
        y_true = callback_data.get('y_true')
        y_pred = callback_data.get('y_pred')
        epoch = callback_data.get('epoch', 0)
        
        if y_true is not None and y_pred is not None:
            metrics = {}
            for name, func in self.metrics_funcs.items():
                try:
                    metrics[name] = func(y_true, y_pred)
                except Exception as e:
                    logger.error(f"Error calculating metric {name}: {e}")
                    metrics[name] = None
            
            self.metrics_history.append({
                'epoch': epoch,
                'metrics': metrics
            })
            
            logger.info(f"Epoch {epoch} metrics: {metrics}")


class ProgressCallback(BaseCallback):
    """进度回调"""
    def __init__(self, progress_signal: Signal = None):
        self.progress_signal = progress_signal
        
    def on_progress_update(self, callback_data: CallbackData):
        progress = callback_data.get('progress', 0)
        if self.progress_signal:
            self.progress_signal.emit(progress)


class LossCallback(BaseCallback):
    """损失回调"""
    def __init__(self, loss_signal: Signal = None):
        self.loss_signal = loss_signal
        self.loss_history = []
        
    def on_loss_update(self, callback_data: CallbackData):
        loss_data = callback_data.data
        self.loss_history.append(loss_data)
        if self.loss_signal:
            self.loss_signal.emit(loss_data)


@dataclass
class TrainingConfig:
    """训练配置"""
    epochs: int = 1000
    batch_size: int = 32
    learning_rate: float = 0.001
    test_size: float = 0.2
    validation_split: float = 0.0
    patience: int = 100
    verbose: int = 1
    random_state: int = 42


@dataclass 
class ModelInfo:
    """模型信息"""
    name: str
    task: str
    model_type: str
    version: str = "1.0"


class BasePredictor(QObject, ABC, metaclass=ABCQObjectMeta):
    """预测器基类"""
    
    # 定义信号
    lossUpdated = Signal(dict)
    trainingProgress = Signal(float)
    metricUpdated = Signal(dict)
    
    def __init__(self, X, y, config: TrainingConfig = None, log_widget: QPlainTextEdit = None, 
                 plot_widget: QWidget = None):
        super().__init__()
        
        # 调试：记录传入的原始数据
        self.logger = logger
        self.log(f"BasePredictor构造函数 - 接收到的X类型: {type(X)}, 形状/长度: {getattr(X, 'shape', len(X) if hasattr(X, '__len__') else 'unknown')}")
        self.log(f"BasePredictor构造函数 - 接收到的y类型: {type(y)}, 长度: {len(y) if hasattr(y, '__len__') else 'unknown'}")
        
        # 确保X和y是numpy数组
        self.X = np.array(X) if not isinstance(X, np.ndarray) else X
        self.y = np.array(y) if not isinstance(y, np.ndarray) else y
        
        # 调试：记录转换后的数据
        self.log(f"BasePredictor构造函数 - 转换后的X形状: {self.X.shape}")
        self.log(f"BasePredictor构造函数 - 转换后的y形状: {self.y.shape}")
        
        self.config = config or TrainingConfig()
        self.log_widget = log_widget
        self.plot_widget = plot_widget
        
        # 模型相关
        self.model = None
        self.scaler = None
        self.is_trained = False
        
        # 数据相关
        self.X_train = None
        self.X_test = None 
        self.y_train = None
        self.y_test = None
        
        # 回调函数列表
        self.callbacks = []
        
        # 模型信息
        self.model_info = self._get_model_info()
        
    @abstractmethod
    def _get_model_info(self) -> ModelInfo:
        """获取模型信息"""
        pass
        
    @abstractmethod
    def _build_model(self):
        """构建模型"""
        pass
        
    @abstractmethod
    def _fit_model(self):
        """训练模型"""
        pass
        
    @abstractmethod
    def _predict_batch(self, X):
        """批量预测"""
        pass
        
    @abstractmethod
    def get_input_class(self):
        """获取输入数据类"""
        pass
        
    def add_callback(self, callback: BaseCallback):
        """添加回调函数"""
        self.callbacks.append(callback)
        
    def remove_callback(self, callback: BaseCallback):
        """移除回调函数"""
        if callback in self.callbacks:
            self.callbacks.remove(callback)
            
    def _trigger_callback(self, event: CallbackEvent, **kwargs):
        """触发回调函数"""
        callback_data = CallbackData(event, **kwargs)
        for callback in self.callbacks:
            try:
                callback(callback_data)
            except Exception as e:
                self.logger.error(f"Callback error: {e}")
                
    def log(self, message: str):
        """日志记录"""
        self.logger.info(message)
        
    def set_config(self, **kwargs):
        """设置训练配置"""
        for key, value in kwargs.items():
            if hasattr(self.config, key):
                setattr(self.config, key, value)
            else:
                self.logger.warning(f"Unknown config parameter: {key}")
                
    def prepare_data(self):
        """数据预处理"""
        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            np.array(self.X), np.array(self.y), 
            test_size=self.config.test_size, 
            random_state=self.config.random_state
        )
        
        self.log(f"Data prepared - Train: {self.X_train.shape}, Test: {self.X_test.shape}")
        
    def train(self) -> Dict[str, float]:
        """训练模型"""
        self._trigger_callback(CallbackEvent.TRAINING_START)
        
        # 准备数据
        self.prepare_data()
        
        # 构建模型
        self._build_model()
        
        # 训练模型
        result = self._fit_model()
        print(result)
        self.is_trained = True
        self._trigger_callback(CallbackEvent.TRAINING_END)
        
        return result
        
    def test(self) -> Dict[str, Any]:
        """测试模型"""
        if not self.is_trained:
            raise ValueError("Model must be trained before testing")
            
        y_pred = self._predict_batch(self.X_test)
        test_metrics = self.evaluate(self.y_test, y_pred)
        
        return {
            'metrics': test_metrics,
            'y_true': self.y_test,
            'y_pred': y_pred,
            'title': f"{self.model_info.task} Test Results"
        }
        
    def predict(self, input_data) -> float:
        """单个预测"""
        if not self.is_trained:
            raise ValueError("Model must be trained before prediction")
            
        # 转换输入数据
        if hasattr(input_data, 'to_list'):
            features = np.array(input_data.to_list()).reshape(1, -1)
        else:
            features = np.array(input_data).reshape(1, -1)
            
        prediction = self._predict_batch(features)
        return float(prediction[0])
        
    def evaluate(self, y_true, y_pred) -> Dict[str, float]:
        """评估模型"""
        try:
            mape = self.mean_absolute_percentage_error(y_true, y_pred)
            mae = mean_absolute_error(y_true, y_pred)
            mse = np.mean((y_true - y_pred) ** 2)
            rmse = np.sqrt(mse)
            
            # 使用sklearn计算R2
            r2 = r2_score(y_true, y_pred)
            
            return {
                'mape': float(mape),
                'mae': float(mae),
                'mse': float(mse),
                'rmse': float(rmse),
                'r2': r2
            }
        except Exception as e:
            self.logger.error(f"Error in evaluation: {e}")
            return {'mape': -1, 'mae': -1, 'mse': -1, 'rmse': -1, 'r2': -1}
            
    @staticmethod
    def mean_absolute_percentage_error(y_true, y_pred):
        """计算MAPE"""
        y_true, y_pred = np.array(y_true), np.array(y_pred)
        epsilon = 1e-7
        return np.mean(np.abs((y_true - y_pred) / (np.abs(y_true) + epsilon)))
        
    @abstractmethod
    def save_model(self, model_path: str) -> bool:
        """保存模型"""
        pass
        
    @abstractmethod
    def load_model(self, model_path: str) -> bool:
        """加载模型"""
        pass


# 输入数据类保持不变
@dataclass
class GLRInput:
    Geopressure: float = 0
    ProduceIndex: float = 0
    BHT: float = 0
    Qf: float = 0
    BSW: float = 0
    API: float = 0
    GOR: float = 0
    Pb: float = 0
    WHP: float = 0

    def to_list(self) -> List[float]:
        return [self.Geopressure, self.ProduceIndex, self.BHT, self.Qf, self.BSW, 
                self.API, self.GOR, self.Pb, self.WHP]
    
    @classmethod
    def get_features(cls):
        return ("地层压力Pr", "生产指数IP", "井底温度BHT", "期望产量QF", "含水率BSW", "原油密度API", "油气比GOR",
                "泡点压力Pb", "井口压力WHP")


@dataclass
class QFInput:
    phdm: float = 0
    freq: float = 0
    Pr: float = 0
    IP: float = 0
    BHT: float = 0
    Qf: float = 0
    BSW: float = 0
    API: float = 0
    GOR: float = 0
    Pb: float = 0
    WHP: float = 0
    Liq_Gas: float = 0

    def to_list(self) -> List[float]:
        return [self.phdm, self.freq, self.Pr, self.IP, self.BHT, self.Qf,
                self.BSW, self.API, self.GOR, self.Pb, self.WHP]
    
    @classmethod
    def get_features(cls):
        return ("射孔垂深", "泵挂垂深", "油藏压力PR", "生产指数IP", "井底温度BHT", 
                "期望产量QF", "含水率BSW", "原油密度API", "油气比GOR", "泡点压力Pb", "井口压力WHP")


@dataclass
class SVRInput:
    phdm: float = 0
    freq: float = 0
    Pr: float = 0
    IP: float = 0
    BHT: float = 0
    Qf: float = 0
    BSW: float = 0
    API: float = 0
    GOR: float = 0
    Pb: float = 0
    WHP: float = 0

    def to_list(self) -> List[float]:
        return [self.phdm, self.freq, self.Pr, self.IP, self.BHT, self.Qf,
                self.BSW, self.API, self.GOR, self.Pb, self.WHP]
    
    @classmethod
    def get_features(cls):
        return ("射孔垂深", "泵挂垂深", "油藏压力PR", "生产指数IP", "井底温度BHT",
                "期望产量QF", "含水率BSW", "原油密度API", "油气比GOR", "泡点压力Pb", "井口压力WHP")


# Keras训练回调
class KerasTrainingCallback(Callback):
    def __init__(self, predictor):
        super().__init__()
        self.predictor = predictor
        self.epoch_loss = []
        self.epoch_val_loss = []

    def on_epoch_end(self, epoch, logs=None):
        logs = logs or {}
        train_loss = logs.get('loss', 0)
        val_loss = logs.get('val_loss', 0)
        
        self.epoch_loss.append(train_loss)
        self.epoch_val_loss.append(val_loss)
        
        # 触发损失更新回调
        loss_data = {
            'epoch': epoch + 1,
            'train_loss': float(train_loss),
            'val_loss': float(val_loss),
            'train_losses': list(self.epoch_loss),
            'val_losses': list(self.epoch_val_loss)
        }
        
        self.predictor._trigger_callback(CallbackEvent.LOSS_UPDATE, **loss_data)
        
        # 触发进度更新
        if hasattr(self.params, 'epochs'):
            progress = ((epoch + 1) / self.params['epochs']) * 100
            self.predictor._trigger_callback(CallbackEvent.PROGRESS_UPDATE, progress=progress)


class GLRPredictor(BasePredictor):
    """GLR预测器 - Keras实现"""
    
    def _get_model_info(self) -> ModelInfo:
        return ModelInfo(name="GLR", task="GLR", model_type="keras")
        
    def get_input_class(self):
        return GLRInput
        
    def prepare_data(self):
        """GLR特有的数据预处理（包含多项式特征）"""
        # 记录原始特征数量
        original_features = self.X.shape[1]
        self.log(f"原始特征数量: {original_features}")
        self.log(f"原始数据样本数: {len(self.X)}")
        
        # 应用多项式特征变换
        self.poly = PolynomialFeatures(degree=2, include_bias=False)
        X_poly = self.poly.fit_transform(self.X)
        poly_features = X_poly.shape[1]
        
        self.log(f"多项式变换后特征数量: {poly_features}")
        
        # 标准化
        if not self.scaler:
            self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X_poly)
        
        # 分割数据
        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            X_scaled, np.array(self.y), 
            test_size=self.config.test_size, 
            random_state=self.config.random_state
        )
        
        self.log(f"Data prepared - Train: {self.X_train.shape}, Test: {self.X_test.shape}")
        self.log(f"训练样本数: {len(self.X_train)}, 测试样本数: {len(self.X_test)}")
        
        # 检查数据完整性
        if len(self.X_test) == 0:
            self.log("警告: 测试集为空！")
        if len(self.X_train) == 0:
            self.log("警告: 训练集为空！")
            
        # 检查是否有NaN值
        if np.any(np.isnan(self.X_train)) or np.any(np.isnan(self.y_train)):
            self.log("警告: 训练数据包含NaN值")
        if np.any(np.isnan(self.X_test)) or np.any(np.isnan(self.y_test)):
            self.log("警告: 测试数据包含NaN值")
        
    def test(self) -> Dict[str, Any]:
        """测试模型 - GLR特殊实现"""
        if not self.is_trained:
            raise ValueError("Model must be trained before testing")
        
        # 确保数据是numpy数组
        if hasattr(self, 'X_test') and self.X_test is not None:
            self.X_test = np.array(self.X_test) if not isinstance(self.X_test, np.ndarray) else self.X_test
        if hasattr(self, 'y_test') and self.y_test is not None:
            self.y_test = np.array(self.y_test) if not isinstance(self.y_test, np.ndarray) else self.y_test
        
        # 检查数据有效性 - 优先使用测试数据
        if hasattr(self, 'X_test') and hasattr(self, 'y_test') and self.X_test is not None and self.y_test is not None:
            # 有外部设置的测试数据，使用测试数据进行检查
            test_X = self.X_test
            test_y = self.y_test
        else:
            # 使用内部原始数据
            test_X = self.X
            test_y = self.y
            
        if test_X.size == 0 or len(test_y) == 0:
            raise ValueError(f"测试数据为空: X shape: {test_X.shape}, y length: {len(test_y)}")
        
        # 检查数据是否已经预处理过（通过特征维度判断）
        # 预处理过的数据应该有54个特征（多项式变换后），原始数据只有9个特征
        if (hasattr(self, 'X_test') and hasattr(self, 'y_test') and 
            self.X_test is not None and self.X_test.size > 0 and 
            len(self.X_test.shape) == 2 and self.X_test.shape[1] > 9):
            # 数据已经过多项式变换和标准化，直接使用
            self.log(f"GLR测试开始 - 使用预处理数据 X_test shape: {self.X_test.shape}, y_test shape: {self.y_test.shape}")
            y_pred = self.model.predict(self.X_test).flatten()
            test_metrics = self.evaluate(self.y_test, y_pred)
            
            result = {
                'metrics': test_metrics,
                'y_true': self.y_test,
                'y_pred': y_pred,
                'title': f"{self.model_info.task} Test Results"
            }
        else:
            # 使用原始数据（需要预处理）
            self.log(f"GLR测试开始 - 使用原始数据 test_X shape: {test_X.shape}, test_y shape: {len(test_y)}")
            
            # 确保test_X是2D数组
            if len(test_X.shape) == 1:
                # 如果是1D数组，需要根据预期的特征数重新整形
                if test_X.size % 9 == 0:
                    test_X = test_X.reshape(-1, 9)
                    self.log(f"将1D数组重新整形为: {test_X.shape}")
                else:
                    raise ValueError(f"无法将数据重新整形为9个特征: 数据大小 {test_X.size} 不是9的倍数")
            
            y_pred = self._predict_batch(test_X)
            test_metrics = self.evaluate(test_y, y_pred)
            
            result = {
                'metrics': test_metrics,
                'y_true': test_y,
                'y_pred': y_pred,
                'title': f"{self.model_info.task} Test Results"
            }
        
        self.log(f"GLR预测完成 - y_pred shape: {y_pred.shape}")
        self.log(f"GLR测试指标: {test_metrics}")
        self.log(f"GLR测试结果 - y_true长度: {len(result['y_true'])}, y_pred长度: {len(result['y_pred'])}")
        
        return result
        
    def _build_model(self):
        """构建Keras模型"""
        inputs = Input(shape=(self.X_train.shape[1],))
        x = Dense(128, activation='relu')(inputs)
        x = Dropout(0.3)(x)

        for _ in range(7):
            residual = x
            x = Dense(128, activation='relu')(x)
            x = Dropout(0.1)(x)
            x = Dense(128, activation='relu')(x)
            x = Add()([x, residual])

        outputs = Dense(1)(x)

        self.model = Model(inputs=inputs, outputs=outputs)
        self.model.compile(
            optimizer=Adam(learning_rate=self.config.learning_rate), 
            loss=self._custom_mape
        )
        self.log("GLR Model built and compiled.")
        
    def _custom_mape(self, y_true, y_pred):
        """自定义MAPE损失"""
        epsilon = 1e-7
        return tf.reduce_mean(tf.abs((y_true - y_pred) / (tf.abs(y_true) + epsilon)))
        
    def _fit_model(self):
        """训练Keras模型"""
        # 创建Keras回调
        keras_callback = KerasTrainingCallback(self)
        early_stop = tf.keras.callbacks.EarlyStopping(
            monitor='val_loss', 
            patience=self.config.patience, 
            restore_best_weights=True
        )
        
        # 训练模型
        self.model.fit(
            self.X_train, self.y_train, 
            epochs=self.config.epochs, 
            batch_size=self.config.batch_size, 
            validation_data=(self.X_test, self.y_test),
            callbacks=[keras_callback, early_stop],
            verbose=self.config.verbose
        )
        
        # 评估训练和测试性能
        train_pred = self.model.predict(self.X_train)
        test_pred = self.model.predict(self.X_test)
        
        train_metrics = self.evaluate(self.y_train, train_pred)
        test_metrics = self.evaluate(self.y_test, test_pred)
        
        self.log(f"Train MAPE: {train_metrics['mape']:.4f}")
        self.log(f"Test MAPE: {test_metrics['mape']:.4f}")
        
        return {'train_metrics': train_metrics, 'test_metrics': test_metrics}
        
    def _predict_batch(self, X):
        """批量预测 - 输入应为原始特征数据（9个特征），会自动应用多项式变换和标准化"""
        # 应用多项式变换和标准化
        X_poly = self.poly.transform(X)
        X_scaled = self.scaler.transform(X_poly)
        return self.model.predict(X_scaled).flatten()
        
    def save_model(self, model_path: str) -> bool:
        """保存GLR模型"""
        try:
            save_path = Path(f"{root}/GLRsave/{model_path}")
            save_path.mkdir(exist_ok=True, parents=True)
            
            self.model.save(f"{save_path}/GLR-Model.h5")
            joblib.dump(self.scaler, f"{save_path}/GLR-Scaler.pkl")
            joblib.dump(self.poly, f"{save_path}/GLR-Poly.pkl")
            
            self.log(f"GLR model saved to {save_path}")
            return True
        except Exception as e:
            self.log(f"Error saving GLR model: {e}")
            return False
            
    def load_model(self, model_path: str) -> bool:
        """加载GLR模型"""
        try:
            model_dir = Path(model_path)
            # 使用重命名后的keras_load_model避免与方法名冲突
            self.model = keras_load_model(
                f"{model_dir}/GLR-Model.h5",
                custom_objects = {"_custom_mape": self._custom_mape}
                )
            self.scaler = joblib.load(f"{model_dir}/GLR-Scaler.pkl")
            self.poly = joblib.load(f"{model_dir}/GLR-Poly.pkl")
            
            self.is_trained = True
            self.log(f"GLR model loaded from {model_dir}")
            return True
        except Exception as e:
            self.log(f"Error loading GLR model: {e}")
            logger.exception(e)
            return False


class SVRPredictor(BasePredictor):
    """SVR预测器基类"""
    
    def __init__(self, X, y, config: TrainingConfig = None, log_widget: QPlainTextEdit = None,
                 plot_widget: QWidget = None, task_name: str = "SVR"):
        self.task_name = task_name  # 在调用父类init之前设置task_name
        super().__init__(X, y, config, log_widget, plot_widget)
        
    def _get_model_info(self) -> ModelInfo:
        return ModelInfo(name=self.task_name, task=self.task_name, model_type="svr")
        
    def _build_model(self):
        """构建SVR模型"""
        # 标准化数据
        if not self.scaler:
            self.scaler = StandardScaler()
        self.X_train_scaled = self.scaler.fit_transform(self.X_train)
        self.X_test_scaled = self.scaler.transform(self.X_test)
        
    def _fit_model(self):
        """训练SVR模型"""
        n_samples = len(self.X_train)
        
        if n_samples < 2:  # 数据太少，使用默认参数
            self.log(f"Training set too small ({n_samples} samples), using default SVR parameters")
            self.model = SVR(C=1.0, epsilon=0.1, kernel='rbf', gamma='scale')
            self.model.fit(self.X_train_scaled, self.y_train)
        else:
            # 网格搜索优化参数
            cv_folds = min(5, n_samples)
            param_grid = {
                'C': [0.1, 1, 10, 100],
                'epsilon': [0.01, 0.1, 0.5, 1],
                'kernel': ['rbf', 'linear', 'sigmoid'],
                'gamma': ['scale', 'auto', 0.01, 0.1, 1]
            }
            
            svr = SVR()
            grid_search = GridSearchCV(
                estimator=svr, param_grid=param_grid, 
                cv=cv_folds, scoring='neg_mean_squared_error'
            )
            
            self.log(f"Starting grid search with {cv_folds}-fold cross-validation...")
            grid_search.fit(self.X_train_scaled, self.y_train)
            
            self.log(f"Best parameters: {grid_search.best_params_}")
            self.model = grid_search.best_estimator_
            
        # 评估性能
        train_pred = self.model.predict(self.X_train_scaled)
        test_pred = self.model.predict(self.X_test_scaled)
        
        train_metrics = self.evaluate(self.y_train, train_pred)
        test_metrics = self.evaluate(self.y_test, test_pred)
        
        self.log(f"Train MAPE: {train_metrics['mape']:.4f}")
        self.log(f"Test MAPE: {test_metrics['mape']:.4f}")
        
        return {'train_metrics': train_metrics, 'test_metrics': test_metrics}
        
    def _predict_batch(self, X):
        """批量预测"""
        X_scaled = self.scaler.transform(X)
        return self.model.predict(X_scaled)
        
    def save_model(self, model_path: str) -> bool:
        """保存SVR模型"""
        try:
            save_path = Path(f"{root}/{self.task_name}save/{model_path}")
            save_path.mkdir(exist_ok=True, parents=True)
            
            joblib.dump(self.model, save_path / f"{self.task_name}-Model.joblib")
            joblib.dump(self.scaler, save_path / f"{self.task_name}-Scaler.joblib")
            
            self.log(f"{self.task_name} model saved to {save_path}")
            return True
        except Exception as e:
            self.log(f"Error saving {self.task_name} model: {e}")
            return False
            
    def load_model(self, model_path: str) -> bool:
        """加载SVR模型"""
        try:
            model_dir = Path(model_path)
            self.model = joblib.load(model_dir / f"{self.task_name}-Model.joblib")
            self.scaler = joblib.load(model_dir / f"{self.task_name}-Scaler.joblib")
            
            self.is_trained = True
            self.log(f"{self.task_name} model loaded from {model_dir}")
            return True
        except Exception as e:
            self.log(f"Error loading {self.task_name} model: {e}")
            return False


class QFPredictor(SVRPredictor):
    """QF预测器"""
    
    def __init__(self, X, y, config: TrainingConfig = None, log_widget: QPlainTextEdit = None,
                 plot_widget: QWidget = None):
        super().__init__(X, y, config, log_widget, plot_widget, task_name="QF")
        
    def get_input_class(self):
        return QFInput


class TDHPredictor(SVRPredictor):
    """TDH预测器"""
    
    def __init__(self, X, y, config: TrainingConfig = None, log_widget: QPlainTextEdit = None,
                 plot_widget: QWidget = None):
        super().__init__(X, y, config, log_widget, plot_widget, task_name="TDH")
        
    def get_input_class(self):
        return SVRInput


# 使用示例
if __name__ == "__main__":
    # 示例数据
    X = np.random.rand(100, 9)
    y = np.random.rand(100)
    
    # 创建配置
    config = TrainingConfig(epochs=100, batch_size=16, learning_rate=0.001)
    
    # 创建GLR预测器
    glr_predictor = GLRPredictor(X, y, config)
    
    # 添加回调函数
    metrics_callback = MetricsCallback({
        'custom_mape': lambda y_true, y_pred: np.mean(np.abs((y_true - y_pred) / y_true)),
        'r2_score': lambda y_true, y_pred: 1 - np.sum((y_true - y_pred)**2) / np.sum((y_true - np.mean(y_true))**2)
    })
    
    progress_callback = ProgressCallback()
    loss_callback = LossCallback()
    
    glr_predictor.add_callback(metrics_callback)
    glr_predictor.add_callback(progress_callback)
    glr_predictor.add_callback(loss_callback)
    
    # 训练模型
    train_results = glr_predictor.train()
    print("Training results:", train_results)
    
    # 测试模型
    test_results = glr_predictor.test()
    print("Test results:", test_results)
    
    # 单个预测
    test_input = GLRInput(Geopressure=1.0, ProduceIndex=2.0, BHT=3.0, Qf=4.0, 
                         BSW=5.0, API=6.0, GOR=7.0, Pb=8.0, WHP=9.0)
    prediction = glr_predictor.predict(test_input)
    print("Prediction:", prediction)