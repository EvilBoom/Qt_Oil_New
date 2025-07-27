from pathlib import Path

import joblib
from typing import List
from sklearn.svm import SVR
from dataclasses import dataclass
from sklearn.preprocessing import StandardScaler
from loguru import logger
import numpy as np
import joblib
from sklearn.svm import SVR
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import GridSearchCV, train_test_split
from PySide6.QtWidgets import QPlainTextEdit, QVBoxLayout, QWidget
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

root = Path(__file__).parent.parent

@dataclass
class SVRInput:
    phdm: float  
    freq: float
    Pr: float
    IP: float
    BHT: float
    Qf: float
    BSW: float
    API: float
    GOR: float
    Pb: float
    WHP: float

    def to_list(self) -> List[float]:
        """Convert the dataclass to a list of values."""
        return [self.phdm, self.freq, self.Pr, self.IP, self.BHT, self.Qf,
                self.BSW, self.API, self.GOR, self.Pb, self.WHP]
    
    def to_list2(self) -> List[float]:
        """Convert the dataclass to a list of values."""
        return [self.Pr, self.IP, self.BHT, self.Qf,
                self.BSW, self.API, self.GOR, self.Pb, self.WHP]

    @classmethod
    def get_features(cls):
        return ("射孔垂深度freq","泵挂垂深phdm","油藏压力Pr","生产指数IP","井底温度BHT","期望产量QF","BSW","API度","GOR油气比","泡点压力Pb","井口压力WHP")


class SVRPredictor:
    name = "svr"
    task = 'TDH'
    def __init__(self,  X, y, log_widget: QPlainTextEdit=None, plot_widget: QWidget=None,
                 test_size=0.2):
        self.model = None
        self.name = "svr"
        self.scaler = StandardScaler()
        self.log_widget = log_widget
        self.plot_widget = plot_widget
        self.X = X
        self.y = y
        self.test_size = test_size

        self.logger = logger

    def init(self, plot_widget: QWidget):
        self.plot_widget = plot_widget


    def prepare_data(self, X, y, test_size=0.2):
        """分割数据集"""
        X_array = np.array(X)
        y_array = np.array(y)
        X_train, X_test, y_train, y_test = train_test_split(X_array, y_array, test_size=test_size)
        self.log(f"Data prepared, train/test split: {1 - test_size}/{test_size}")
        return X_train, X_test, y_train, y_test


    def log(self, message: str):
        """将日志消息写到小部件和控制台"""
        self.logger.info(message)

    def load_model_and_scaler(self, model_dir:str):
        try:
            self.model = joblib.load(f"{model_dir}/TDH-Model.joblib")
            self.scaler = joblib.load(f"{model_dir}/TDH-Scaler.joblib")

            if not isinstance(self.model, SVR):
                raise ValueError("Loaded model is not an SVR model.")
            self.log("Model loaded successfully.")

            if not isinstance(self.scaler, StandardScaler):
                raise ValueError("Loaded scaler is not a StandardScaler instance.")
            self.log("Scaler loaded successfully.")
        except Exception as e:
            self.log(f"Error loading model or scaler: {e}")

    def save_model(self, model_path: str):
        try:
            """保存模型和标准化器"""
            save_path = Path(f"{root}/TDHsave/{model_path}")
            save_path.mkdir(exist_ok=True,parents=True)
            joblib.dump(self.model, save_path/"TDH-Model.joblib")
            joblib.dump(self.scaler, save_path/"TDH-Scaler.joblib")
            self.log("Model and scaler saved.")
            return True
        except Exception as e:
            logger.exception(e)
            self.log(str(e))
            return False

    def scale_features(self):
        """对特征进行缩放"""
        self.X_train_scaled = self.scaler.fit_transform(self.X_train)
        self.X_test_scaled = self.scaler.transform(self.X_test)
        self.log("Features have been scaled.")

    def train(self):
        self.X_train, self.X_test, self.y_train, self.y_test = self.prepare_data(self.X, self.y, self.test_size)
        self.log(f"训练集shape：feature: {self.X_train.shape },label:{self.y_train.shape}")
        self.log(f"测试集shape：feature: {self.X_test.shape},label:{self.y_test.shape}")

        """训练模型，通过 GridSearchCV 来优化超参数"""
        self.scale_features()

        # 检查训练集大小，决定是否使用网格搜索
        n_samples = len(self.X_train)
        min_cv_folds = 2  # 至少需要2折交叉验证
        
        if n_samples < min_cv_folds:
            # 数据太少，直接使用默认参数训练
            self.log(f"Training set too small ({n_samples} samples), using default SVR parameters")
            self.model = SVR(C=1.0, epsilon=0.1, kernel='rbf', gamma='scale')
            self.model.fit(self.X_train_scaled, self.y_train)
            self.log("Model training completed with default parameters.")
        else:
            # 根据样本数量调整交叉验证折数
            cv_folds = min(5, n_samples)  # 最多5折，但不超过样本数
            
            param_grid = {
                'C': [0.1, 1, 10, 20, 100],
                'epsilon': [0.01, 0.1, 0.5, 1, 2],
                'kernel': ['rbf', 'linear', 'sigmoid'],
                'gamma': ['scale', 'auto', 0.01, 0.1, 1, 10]
            }
            svr = SVR()
            grid_search = GridSearchCV(estimator=svr, param_grid=param_grid, cv=cv_folds, scoring='neg_mean_squared_error')

            self.log(f"Starting grid search with {cv_folds}-fold cross-validation...")
            grid_search.fit(self.X_train_scaled, self.y_train)
            
            self.log(f"Best parameters found: {grid_search.best_params_}")
            self.model = grid_search.best_estimator_
            self.log("Model training completed with grid search.")

        # 进行训练集和测试集上的预测与评估
        y_pred_train = self.model.predict(self.X_train_scaled)
        y_pred_test = self.model.predict(self.X_test_scaled)

        train_mape = self.mean_absolute_percentage_error(self.y_train, y_pred_train)
        test_mape = self.mean_absolute_percentage_error(self.y_test, y_pred_test)
        self.log(f"Train MAPE: {train_mape}")
        self.log(f"Test MAPE: {test_mape}")

        # 绘制结果
        return train_mape,test_mape,self.y_test,y_pred_test,"TDH predict error"

    def mean_absolute_percentage_error(self, y_true, y_pred):
        """计算平均绝对百分比误差"""
        y_true, y_pred = np.array(y_true), np.array(y_pred)
        return np.mean(np.abs((y_true - y_pred) / y_true))

    def test_offline(self,model_dir,):
        """测试模型"""
        self.load_model_and_scaler(model_dir)
        X_train, X_test, y_train, y_test = self.prepare_data(self.X, self.y, 1)
        X_test_scaled = self.scaler.transform(X_test)
        y_pred_test = self.model.predict(X_test_scaled)
        test_mape = self.mean_absolute_percentage_error(y_test, y_pred_test)
        self.log(f"Test MAPE: {test_mape}")
        return test_mape

    def plot_residuals(self, y_true, y_pred, title):
        """在 UI 中显示残差图。"""
        residuals = np.array(y_true) - np.array(y_pred)

        # 创建 Matplotlib 图形和画布
        fig = Figure()
        canvas = FigureCanvas(fig)
        ax = fig.add_subplot(111)

        # 绘制残差图
        ax.scatter(y_pred, residuals, color='green', label='Residuals')
        ax.axhline(y=0, color='black', linestyle='--', label='Zero Error')

        upper_limit = 0.15 * np.array(y_true)
        lower_limit = -0.15 * np.array(y_true)

        ax.axhline(y=np.mean(upper_limit), color='red', linestyle='--', label='+15% Error')
        ax.axhline(y=np.mean(lower_limit), color='blue', linestyle='--', label='-15% Error')

        ax.set_xlabel('Predicted Values')
        ax.set_ylabel('Residuals')
        ax.set_title(title)
        ax.legend()

        # 清空并添加新画布
        layout = QVBoxLayout(self.plot_widget)
        if self.plot_widget.layout() is not None:
            # 如果已有布局，移除之前的内容
            old_layout = self.plot_widget.layout()
            for i in reversed(range(old_layout.count())):
                old_layout.itemAt(i).widget().setParent(None)
            self.plot_widget.setLayout(None)

        # 设置布局并添加画布
        layout.addWidget(canvas)
        self.plot_widget.setLayout(layout)
        canvas.draw()

        # 记录日志
        self.log("Plot displayed in application.")
    

def svr_predict(input_data: SVRInput, model_path: str, scaler_path: str) -> float:
    """
    Load the pre-trained SVR model and scaler, scale the input data,
    and predict the label.

    :param input_data: An instance of SVRInput containing the features for prediction.
    :param model_path: The file path to the pre-trained SVR model.
    :param scaler_path: The file path to the scaler used during training.
    :return: The predicted label as a float.
    """
    # Load the pre-trained SVR model
    svr_model = joblib.load(model_path)
    
    # Ensure the loaded model is an instance of sklearn's SVR
    if not isinstance(svr_model, SVR):
        raise ValueError("Loaded model is not an SVR model.")
    
    # Load the scaler used during training
    scaler = joblib.load(scaler_path)
    
    # Ensure the loaded scaler is an instance of StandardScaler
    if not isinstance(scaler, StandardScaler):
        raise ValueError("Loaded scaler is not a StandardScaler instance.")
    
    # Convert the input data to a list of features
    features = input_data.to_list()
    
    # Scale the input features using the loaded scaler
    features_scaled = scaler.transform([features])
    
    # Predict the label using the scaled features
    prediction = svr_model.predict(features_scaled)[0]
    
    return prediction


if __name__ == "__main__":
    data = SVRInput(9000,9324,3033,0.35,200,486,30,20.8,87.1,691,350)
    label = 5875.18
    print(svr_predict(data,'./TDH-SVR-Model-Best.joblib','./TDH-SVR-SCALER.pkl'))
    