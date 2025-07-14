# Controller/MLPredictionService.py
import os
import sys
import numpy as np
import joblib
import tensorflow as tf
from dataclasses import dataclass
from typing import List, Dict, Any
from pathlib import Path
import logging
from sklearn.preprocessing import StandardScaler, PolynomialFeatures

logger = logging.getLogger(__name__)

@dataclass
class PredictionInput:
    """ML预测输入数据结构"""
    # 从Step1参数获取
    geopressure: float = 0          # 地层压力
    produce_index: float = 0        # 生产指数
    bht: float = 0                  # 井底温度
    expected_production: float = 0  # 期望产量
    bsw: float = 0                  # 含水率
    api: float = 0                  # API重度
    gas_oil_ratio: float = 0        # 油气比
    saturation_pressure: float = 0  # 饱和压力
    wellhead_pressure: float = 0    # 井口压力
    
    # 从WellStructure计算结果获取
    perforation_depth: float = 0    # 射孔垂深
    pump_hanging_depth: float = 0   # 泵挂垂深

    def to_qf_list(self) -> List[float]:
        """转换为QF预测所需的输入格式"""
        return [
            self.perforation_depth,      # 射孔垂深
            self.pump_hanging_depth,     # 泵挂垂深
            self.geopressure,            # 地层压力
            self.produce_index,          # 生产指数
            self.bht,                    # 井底温度
            self.expected_production,    # 期望产量
            self.bsw,                    # 含水率
            self.api,                    # API重度
            self.gas_oil_ratio,          # 油气比
            self.saturation_pressure,    # 饱和压力
            self.wellhead_pressure       # 井口压力
        ]
    
    def to_lift_list(self) -> List[float]:
        """转换为扬程预测所需的输入格式"""
        return [
            self.perforation_depth,      # 射孔垂深
            self.pump_hanging_depth,     # 泵挂垂深
            self.geopressure,            # 地层压力
            self.produce_index,          # 生产指数
            self.bht,                    # 井底温度
            self.expected_production,    # 期望产量
            self.bsw,                    # 含水率
            self.api,                    # API重度
            self.gas_oil_ratio,          # 油气比
            self.saturation_pressure,    # 饱和压力
            self.wellhead_pressure       # 井口压力
        ]
    
    def to_atpump_list(self) -> List[float]:
        """转换为吸入口汽液比预测所需的输入格式"""
        return [
            self.geopressure,            # 地层压力
            self.produce_index,          # 生产指数
            self.bht,                    # 井底温度
            self.expected_production,    # 期望产量
            self.bsw,                    # 含水率
            self.api,                    # API重度
            self.gas_oil_ratio,          # 油气比
            self.saturation_pressure,    # 饱和压力
            self.wellhead_pressure       # 井口压力
        ]

@dataclass
class PredictionResults:
    """ML预测结果数据结构"""
    production: float = 0       # 推荐产量 (bbl/d)
    total_head: float = 0       # 所需扬程 (ft)
    gas_rate: float = 0         # 吸入口汽液比 (-)
    confidence: float = 0       # 整体置信度

class MLPredictionService:
    """机器学习预测服务类"""
    
    def __init__(self):
        self.models = {}
        self.scalers = {}
        self.models_loaded = False
        self.model_base_path = self._get_model_base_path()
        logger.info(f"ML预测服务初始化，模型路径: {self.model_base_path}")
        
    def _get_model_base_path(self) -> str:
        """获取模型文件基础路径"""
        if getattr(sys, 'frozen', False):
            # 打包后的执行文件
            base_path = sys._MEIPASS
        else:
            # 开发环境
            base_path = os.path.dirname(__file__)
        
        return os.path.join(base_path, 'models')
    
    def _get_model_path(self, model_type: str, file_type: str) -> str:
        """获取特定模型文件路径"""
        model_files = {
            'production': {
                'model': 'QF-SVR-Model-Best-03-16.joblib',
                'scaler': 'QF-SVR-SCALER-Best-03-16.pkl'
            },
            'total_head': {
                'model': 'TDH-SVR-Model-Best-05-16.joblib',
                'scaler': 'TDH-SVR-SCALER-Best-05-16.pkl'
            },
            'gas_rate': {
                'model': 'best_model_0815.keras',
                'scaler': None  # Keras模型包含预处理
            }
        }
        
        if model_type in model_files and file_type in model_files[model_type]:
            filename = model_files[model_type][file_type]
            if filename:
                return os.path.join(self.model_base_path, filename)
        
        return None
    
    def load_models(self):
        """加载所有ML模型"""
        try:
            logger.info("开始加载ML模型...")
            
            # 加载产量预测模型
            production_model_path = self._get_model_path('production', 'model')
            production_scaler_path = self._get_model_path('production', 'scaler')
            
            if production_model_path and os.path.exists(production_model_path):
                self.models['production'] = joblib.load(production_model_path)
                logger.info("产量预测模型加载成功")
                if production_scaler_path and os.path.exists(production_scaler_path):
                    self.scalers['production'] = joblib.load(production_scaler_path)
                    logger.info("产量预测标准化器加载成功")
            else:
                logger.warning(f"产量预测模型文件不存在: {production_model_path}")
            
            # 加载扬程预测模型
            head_model_path = self._get_model_path('total_head', 'model')
            head_scaler_path = self._get_model_path('total_head', 'scaler')
            
            if head_model_path and os.path.exists(head_model_path):
                self.models['total_head'] = joblib.load(head_model_path)
                logger.info("扬程预测模型加载成功")
                if head_scaler_path and os.path.exists(head_scaler_path):
                    self.scalers['total_head'] = joblib.load(head_scaler_path)
                    logger.info("扬程预测标准化器加载成功")
            else:
                logger.warning(f"扬程预测模型文件不存在: {head_model_path}")
            
            # 加载汽液比预测模型
            gas_model_path = self._get_model_path('gas_rate', 'model')
            if gas_model_path and os.path.exists(gas_model_path):
                # 自定义损失函数
                def custom_mape(y_true, y_pred):
                    epsilon = 1e-7
                    return tf.reduce_mean(tf.abs((y_true - y_pred) / (tf.abs(y_true) + epsilon)))
                
                self.models['gas_rate'] = tf.keras.models.load_model(
                    gas_model_path, 
                    custom_objects={'custom_mape': custom_mape}
                )
                logger.info("汽液比预测模型加载成功")
            else:
                logger.warning(f"汽液比预测模型文件不存在: {gas_model_path}")
            
            self.models_loaded = True
            logger.info(f"成功加载 {len(self.models)} 个ML模型")
            
        except Exception as e:
            logger.error(f"模型加载失败: {e}")
            self.models_loaded = False
    
    def predict_production(self, input_data: PredictionInput) -> float:
        """预测推荐产量"""
        if 'production' not in self.models:
            logger.warning("产量预测模型未加载，使用经验公式")
            return input_data.expected_production * 0.9
        
        try:
            features = input_data.to_qf_list()
            logger.info(f"产量预测输入特征: {features}")
            
            if 'production' in self.scalers:
                features_scaled = self.scalers['production'].transform([features])
            else:
                features_scaled = [features]
            
            prediction = self.models['production'].predict(features_scaled)[0]
            logger.info(f"产量预测结果: {prediction:.2f} bbl/d")
            return float(prediction)
            
        except Exception as e:
            logger.error(f"产量预测失败: {e}")
            return input_data.expected_production * 0.9
    
    def predict_total_head(self, input_data: PredictionInput) -> float:
        """预测所需扬程"""
        if 'total_head' not in self.models:
            logger.warning("扬程预测模型未加载，使用经验公式")
            return input_data.pump_hanging_depth * 1.2
        
        try:
            features = input_data.to_lift_list()
            logger.info(f"扬程预测输入特征: {features}")
            
            if 'total_head' in self.scalers:
                features_scaled = self.scalers['total_head'].transform([features])
            else:
                features_scaled = [features]
            
            prediction = self.models['total_head'].predict(features_scaled)[0]
            logger.info(f"扬程预测结果: {prediction:.2f} ft")
            return float(prediction)
            
        except Exception as e:
            logger.error(f"扬程预测失败: {e}")
            return input_data.pump_hanging_depth * 1.2
    
    def predict_gas_rate(self, input_data: PredictionInput) -> float:
        """预测吸入口汽液比"""
        if 'gas_rate' not in self.models:
            logger.warning("汽液比预测模型未加载，使用经验公式")
            return input_data.gas_oil_ratio / 1000
        
        try:
            features = [input_data.to_atpump_list()]
            logger.info(f"汽液比预测输入特征: {features}")
            
            # 使用Temp.py中的数据处理逻辑
            # 做交叉特征
            poly = PolynomialFeatures(degree=2, include_bias=False)
            features_poly = poly.fit_transform(features)
            
            # 数据标准化
            scaler = StandardScaler()
            features_scaled = scaler.fit_transform(features_poly)
            
            # 调整输入数据的形状以适应模型需求
            features_reshaped = features_scaled.reshape(features_scaled.shape[0], features_scaled.shape[1], 1)
            
            prediction = self.models['gas_rate'].predict(features_reshaped)
            result = float(prediction[0][0])
            logger.info(f"汽液比预测结果: {result:.4f}")
            return result
            
        except Exception as e:
            logger.error(f"汽液比预测失败: {e}")
            return input_data.gas_oil_ratio / 1000
    
    def predict_all(self, input_data: PredictionInput) -> PredictionResults:
        """执行所有预测"""
        if not self.models_loaded:
            logger.info("首次预测，加载模型...")
            self.load_models()
        
        logger.info("开始执行所有预测...")
        
        # 执行三个预测
        production = self.predict_production(input_data)
        total_head = self.predict_total_head(input_data)
        gas_rate = self.predict_gas_rate(input_data)
        
        # 计算综合置信度 (简化版本)
        confidence = 0.85  # 固定值，可以后续改进为实际计算
        
        results = PredictionResults(
            production=production,
            total_head=total_head,
            gas_rate=gas_rate,
            confidence=confidence
        )
        
        logger.info(f"预测完成 - 产量: {production:.2f}, 扬程: {total_head:.2f}, 汽液比: {gas_rate:.4f}")
        return results
    
    def generate_ipr_curve(self, production: float) -> List[Dict[str, float]]:
        """生成IPR曲线数据 (使用正确的Vogel方程) - 修复版本"""
        logger.info(f"生成IPR曲线，基准产量: {production:.2f} bbl/d")

        curve_data = []

        try:
            # 合理的参数设置
            reservoir_pressure = 2000  # 地层压力 psi
            saturation_pressure = 1200  # 饱和压力 psi (一般为地层压力的60%)
    
            # 根据基准产量估算最大产量（使用Vogel方程反推）
            # 假设当前产量对应的井底流压为地层压力的40%
            current_bhp = reservoir_pressure * 0.4
    
            # 🔥 修复：确保 pi 变量在所有情况下都被初始化
            pi = 0.0  # 生产指数初始化
    
            # 使用Vogel方程计算生产指数
            if current_bhp >= saturation_pressure:
                # 线性段：PI = q / (Pr - Pwf)
                if reservoir_pressure > current_bhp:  # 防止除零
                    pi = production / (reservoir_pressure - current_bhp)
                else:
                    pi = production / 100  # 使用默认值防止除零错误
                logger.info(f"线性段生产指数: {pi:.6f} bbl/d/psi")
            else:
                # Vogel段：使用简化的生产指数估算
                if reservoir_pressure > 0:
                    pi = production / (reservoir_pressure * 0.6)  # 简化计算
                else:
                    pi = production / 1000  # 默认值
                logger.info(f"Vogel段生产指数: {pi:.6f} bbl/d/psi")
    
            # 🔥 确保生产指数合理，防止负值或过大值
            if pi <= 0:
                pi = production / 1000  # 使用合理的默认值
                logger.warning(f"生产指数异常，使用默认值: {pi:.6f}")
    
            # 生成IPR曲线数据点（从高压到低压）
            num_points = 36
            for i in range(num_points):
                # 压力从地层压力递减到0
                pwf = reservoir_pressure * (1 - i / (num_points - 1))
        
                # 根据压力范围使用不同公式计算产量
                if pwf >= saturation_pressure:
                    # 高于饱和压力：线性关系
                    q = pi * (reservoir_pressure - pwf)
                else:
                    # 低于饱和压力：Vogel方程
                    # q = q_linear + q_vogel
                    q_linear = pi * (reservoir_pressure - saturation_pressure)
            
                    # Vogel段的产量
                    if saturation_pressure > 0:
                        pb_ratio = pwf / saturation_pressure
                    else:
                        pb_ratio = 0
                    
                    vogel_factor = 1 - 0.2 * pb_ratio - 0.8 * (pb_ratio ** 2)
            
                    # Vogel段的最大产量（饱和压力处的产量）
                    q_vogel_max = pi * saturation_pressure / 1.8
                    q_vogel = q_vogel_max * vogel_factor
            
                    q = q_linear + q_vogel
        
                # 确保产量非负
                q = max(0, q)
        
                curve_data.append({
                    "production": float(q),
                    "pressure": float(pwf)
                })
    
            # 按压力从高到低排序（确保曲线正确绘制）
            curve_data.sort(key=lambda point: point['pressure'], reverse=True)
    
            logger.info(f"生成IPR曲线数据点: {len(curve_data)}个")
            if curve_data:
                logger.info(f"压力范围: {curve_data[0]['pressure']:.1f} - {curve_data[-1]['pressure']:.1f} psi")
                logger.info(f"产量范围: {curve_data[-1]['production']:.2f} - {curve_data[0]['production']:.2f} bbl/d")
    
                # 打印前几个点验证趋势
                for i in range(min(5, len(curve_data))):
                    logger.info(f"点{i}: 压力={curve_data[i]['pressure']:.1f} psi, 产量={curve_data[i]['production']:.2f} bbl/d")
        
        except Exception as e:
            logger.error(f"生成IPR曲线失败: {e}")
            import traceback
            logger.error(f"详细错误信息: {traceback.format_exc()}")
        
            # 🔥 简化的线性IPR作为后备方案
            try:
                logger.info("使用后备线性IPR曲线")
                curve_data = []
                for i in range(21):
                    pressure_ratio = 1 - i / 20.0
                    pwf = 2000 * pressure_ratio
                    q = production * 2 * (i / 20.0)  # 线性增长
                    curve_data.append({
                        "production": float(q),
                        "pressure": float(pwf)
                    })
            except Exception as backup_error:
                logger.error(f"后备方案也失败: {backup_error}")
                # 最简单的默认数据
                curve_data = [
                    {"production": 0.0, "pressure": 2000.0},
                    {"production": float(production), "pressure": 1000.0},
                    {"production": float(production * 2), "pressure": 0.0}
                ]

        return curve_data