import pickle
import sqlite3
from pathlib import Path

import joblib
import pandas as pd
import numpy as np
from PySide6.QtWidgets import QVBoxLayout
from PySide6.QtCore import QObject, Signal
from sklearn.preprocessing import StandardScaler, PolynomialFeatures
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_percentage_error, mean_absolute_error
from tensorflow.keras.models import Sequential, Model, load_model
from tensorflow.keras.layers import Dense, Dropout, Add, Input
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import Callback
import tensorflow as tf
from typing import List
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from dataclasses import dataclass
from loguru import logger

from models.eval import CustomMAPE

root = Path(__file__).parent.parent


@dataclass
class GLRInput:
    Geopressure: float = 0  # 射孔垂深
    ProduceIndex: float = 0  # 泵挂垂深
    BHT: float = 0  # 井低温度
    Qf: float = 0  # 期望产量
    BSW: float = 0  # 水和沉淀物
    API: float = 0  # 油的重度
    GOR: float = 0  # 油气比
    Pb: float = 0  # 泡点压力
    WHP: float = 0  # 井口压力

    def to_list(self) -> List[float]:
        """Convert the dataclass to a list of values."""
        return [self.Geopressure, self.ProduceIndex, self.BHT, self.Qf, self.BSW, self.API,
                self.GOR, self.Pb, self.WHP]

    # Pr, IP, BHT, Qf, BSW, API, GOR, Pb, WHP
    # Geopressure, ProduceIndex, BHT, Expectedproduction, BSW, API, GasOilRatio, SaturationPressure, WellHeadPressure,
    # @classmethod
    # def get_features(cls):
    #     return ("Geopressure", "ProduceIndex", "BHT", "Expectedproduction", "BSW", "API", "GasOilRatio", "SaturationPressure",
    #             "WellHeadPressure")
    
    @classmethod
    def get_features(cls):
        return ("地层压力Pr", "生产指数IP", "井底温度BHT", "期望产量QF", "BSW", "API度", "GOR油气比", "泡点压力Pb",
                "井口压力WHP")
    
    


# LossHistory 回调类
class LossHistory(Callback):
    def __init__(self, loss_signal=None):
        super(LossHistory, self).__init__()
        self.epoch_loss = []
        self.epoch_val_loss = []
        self.loss_signal = loss_signal

    def on_epoch_end(self, epoch, logs=None):
        logs = logs or {}
        train_loss = logs.get('loss', 0)
        val_loss = logs.get('val_loss', 0)
        
        self.epoch_loss.append(train_loss)
        self.epoch_val_loss.append(val_loss)
        
        logger.info(f"Epoch {epoch + 1}: loss = {train_loss:.4f}, val_loss = {val_loss:.4f}")
        
        # 发送损失数据信号
        if self.loss_signal is not None:
            loss_data = {
                'epoch': epoch + 1,
                'train_loss': float(train_loss),
                'val_loss': float(val_loss),
                'train_losses': list(self.epoch_loss),
                'val_losses': list(self.epoch_val_loss)
            }
            
            # 添加调试信息
            logger.info(f"=== GLR Model: 发送损失数据信号 ===")
            logger.info(f"Epoch: {epoch + 1}, Train Loss: {train_loss:.4f}, Val Loss: {val_loss:.4f}")
            logger.info(f"Total train losses count: {len(self.epoch_loss)}")
            logger.info(f"Total val losses count: {len(self.epoch_val_loss)}")
            
            try:
                self.loss_signal.emit(loss_data)
                logger.info("损失数据信号发送成功")
            except Exception as e:
                logger.error(f"发送损失数据信号失败: {e}")
        else:
            logger.warning("loss_signal is None, 无法发送损失数据")

# 进度回调类
class ProgressCallback(Callback):
    def __init__(self, progress_signal=None, total_epochs=1000):
        super(ProgressCallback, self).__init__()
        self.progress_signal = progress_signal
        self.total_epochs = total_epochs

    def on_epoch_end(self, epoch, logs=None):
        if self.progress_signal is not None:
            progress = ((epoch + 1) / self.total_epochs) * 100
            self.progress_signal.emit(progress)


# GLRPredictor 类
class GLRPredictor(QObject):
    # 定义信号
    lossUpdated = Signal(dict)
    trainingProgress = Signal(float)
    
    name = "keras"
    task = "GLR"

    def __init__(self, X, y, log_widget=None, plot_widget=None, test_size=0.2):
        super().__init__()
        self.model = None
        self.scaler = None
        self.log_widget = log_widget
        self.plot_widget = plot_widget
        self.X = X
        self.y = y
        self.test_size = test_size
        self.logger = logger
        self.X_train = None
        self.X_test = None
        self.y_train = None
        self.y_test = None
        self.mape = CustomMAPE()
        
        # 训练参数
        self.learning_rate = 0.001
        self.epochs = 1000
        self.batch_size = 48
        self.patience = 100

    def init(self, plot_widget):
        self.plot_widget = plot_widget

    def log(self, message: str):
        """将日志消息写到小部件和控制台"""
        self.logger.info(message)

    def set_training_params(self, learning_rate=0.001, epochs=1000, batch_size=48, patience=100):
        """设置训练参数"""
        self.learning_rate = learning_rate
        self.epochs = epochs
        self.batch_size = batch_size
        self.patience = patience
        self.log(f"Training parameters updated: lr={learning_rate}, epochs={epochs}, batch_size={batch_size}, patience={patience}")

    def prepare_data(self, X, y, test_size=0.2):
        """分割数据集"""
        # 记录原始特征数量
        original_features = X.shape[1]
        self.log(f"原始特征数量: {original_features}")
        
        # 应用多项式特征变换
        self.poly = PolynomialFeatures(degree=2, include_bias=False)
        X_poly = self.poly.fit_transform(X)
        poly_features = X_poly.shape[1]
        
        self.log(f"多项式变换后特征数量: {poly_features} (从 {original_features} 扩展)")
        self.log(f"多项式特征包括: 原始特征({original_features}) + 二次交互项({poly_features - original_features})")

        if not getattr(self,'scaler',False):
            self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X_poly)

        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            np.array(X_scaled), np.array(y), test_size=test_size, random_state=42)

        self.log(f"Data prepared, train/test split: {1 - test_size}/{test_size}")

    def prepare_data_bak(self, X, y, test_size=0.2):
        """分割数据集"""
        poly = PolynomialFeatures(degree=2, include_bias=False)
        X_poly = poly.fit_transform(X)

        if not getattr(self,'scaler',False):
            self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X_poly)

        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            np.array(X_scaled), np.array(y), test_size=test_size, random_state=42)

        self.log(f"Data prepared, train/test split: {1 - test_size}/{test_size}")

    # def load_data_from_sqlite(self, dbmanager: str="../projects.db", table_name: str="GLRTest") -> List[GLRInput]:
    #     """从 SQLite 数据库加载指定表的数据，并转换为 GLRInput 实例列表"""

    #     rows = dbmanager.getFromTable(table_name)

    #     # 将查询结果转换为 GLRInput 实例列表
    #     features = [GLRInput(*row[:-1]).to_list() for row in rows]
    #     label = [row[-1] for row in rows]
    #     return features,label

    def build_model(self,lr):
        """构建 Keras 模型"""
        inputs = Input(shape=(self.X_train.shape[1],))
        x = Dense(128, activation='relu')(inputs)
        x = Dropout(0.3)(x)

        for _ in range(7):
            residual = x
            x = Dense(128, activation='relu')(x)
            x = Dropout(0.1)(x)
            x = Dense(128, activation='relu')(x)
            x = Add()([x, residual])  # 加入残差连接

        outputs = Dense(1)(x)

        self.model = Model(inputs=inputs, outputs=outputs)
        self.model.compile(optimizer=Adam(learning_rate=lr), loss=self.custom_mape)
        self.log("Model built and compiled.")

    def init_train(self, lr=0.001):
        self.prepare_data(self.X, self.y, self.test_size)
        self.log(f"训练集shape：feature: {self.X_train.shape},label:{self.y_train.shape}")
        self.log(f"测试集shape：feature: {self.X_test.shape},label:{self.y_test.shape}")

        self.build_model(lr)

    def train(self):
        # 准备数据
        self.prepare_data(self.X, self.y, self.test_size)
        self.log(f"训练集shape：feature: {self.X_train.shape},label:{self.y_train.shape}")
        self.log(f"测试集shape：feature: {self.X_test.shape},label:{self.y_test.shape}")

        # 构建模型
        self.build_model(lr=self.learning_rate)

        # 训练模型并实时更新损失曲线
        history = LossHistory(loss_signal=self.lossUpdated)
        early_stop = tf.keras.callbacks.EarlyStopping(
            monitor='val_loss', 
            patience=self.patience, 
            restore_best_weights=True
        )
        model_checkpoint = tf.keras.callbacks.ModelCheckpoint(
            'best_model.keras', 
            save_best_only=True,
            monitor='val_loss'
        )

        # 自定义进度回调
        progress_callback = ProgressCallback(self.trainingProgress, self.epochs)

        self.log(f"开始训练，参数：lr={self.learning_rate}, epochs={self.epochs}, batch_size={self.batch_size}")
        
        self.model.fit(
            self.X_train, self.y_train, 
            epochs=self.epochs, 
            batch_size=self.batch_size, 
            validation_data=(self.X_test, self.y_test),
            callbacks=[history, early_stop, model_checkpoint, progress_callback],
            verbose=1
        )

        return self.test(self.X_test, self.y_test)

    def test_offline(self,model_dir):
        try:
            self.load_model_and_scaler(model_dir)
            self.prepare_data_bak(self.X, self.y,1)
            y_pred = self.model.predict(self.X_test)
            test_mape = self.mape.forward(self.y_test, y_pred)
            self.log(f"Test MAPE: {test_mape}")
            return test_mape
        except Exception as e:
            logger.exception(e)
            return -1


    def test(self, X_test, y_test):
        """测试模型"""
        y_pred = self.model.predict(X_test)
        test_mape = self.mape.forward(y_test, y_pred)

        train_pred = self.model.predict(self.X_train)
        train_mape = self.mape.forward(self.y_train, train_pred)
        self.log(f"Train Mape: {train_mape}")
        self.log(f"Test MAPE: {test_mape}")
        return train_mape, test_mape

    def save_model(self, model_path: str):
        try:
            """保存模型和标准化器"""
            save_path = Path(f"{root}/GLRsave/{model_path}")
            save_path.mkdir(exist_ok=True,parents=True)
            model_path = f"{save_path}/GLR-Model.h5"
            scaler_path = f"{save_path}/GLR-Scaler.pkl"
            poly_path = f"{save_path}/GLR-Poly.pkl"
            
            self.model.save(model_path)
            joblib.dump(self.scaler, scaler_path)
            
            # 保存多项式变换器
            if hasattr(self, 'poly') and self.poly is not None:
                joblib.dump(self.poly, poly_path)
                self.log(f"Model, scaler and polynomial transformer saved as {model_path}, {scaler_path}, {poly_path}")
            else:
                self.log(f"Model and scaler saved as {model_path} and {scaler_path}")
            
            return True
        except Exception as e:
            self.log(str(e))
            return False


    def load_model_and_scaler(self,model_dir):
        try:
            """从指定目录加载模型和标准化器"""
            model_dir = Path(model_dir)
            self.log(f"从{model_dir}中加载模型")

            # 加载模型和标准化器
            self.model = load_model(
                f"{model_dir}/GLR-Model.h5",
                custom_objects = {"custom_mape": CustomMAPE}
            )
            self.scaler = joblib.load(f"{model_dir}/GLR-Scaler.pkl")
            
            # 尝试加载多项式变换器
            poly_path = f"{model_dir}/GLR-Poly.pkl"
            if Path(poly_path).exists():
                self.poly = joblib.load(poly_path)
                self.log(f"Successfully loaded model, scaler and polynomial transformer from {model_dir}")
            else:
                # 如果没有保存的多项式变换器，设置为None，在预测时会报错提示用户
                self.poly = None
                self.log(f"Successfully loaded model and scaler from {model_dir}, but no polynomial transformer found")
                self.log("WARNING: This GLR model was saved without polynomial transformer, prediction may fail")

            return True
        except Exception as e:
            logger.exception(e)
            self.log(f"Error loading model and scaler: {str(e)}")
            return False



    def predict(self, input_data: GLRInput) -> float:
        """推理预测"""
        data = np.array(input_data.to_list()).reshape(1, -1)
        
        # 使用保存的多项式变换器
        if hasattr(self, 'poly') and self.poly is not None:
            data_poly = self.poly.transform(data)
        else:
            # 如果没有保存的多项式变换器，报错提示
            raise ValueError("GLR模型缺少多项式变换器，请重新训练模型以保存完整的预处理器")
            
        data_scaled = self.scaler.transform(data_poly)
        prediction = self.model.predict(data_scaled)
        return float(prediction[0, 0])

    def custom_mape(self, y_true, y_pred):
        epsilon = 1e-7
        return tf.reduce_mean(tf.abs((y_true - y_pred) / (tf.abs(y_true) + epsilon)))
