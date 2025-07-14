# DataManage/services/empirical_formulas_service.py

import logging
import math
import numpy as np
from typing import Dict, Any, Tuple, Union, List

logger = logging.getLogger(__name__)

class EmpiricalFormulasService:
    """经验公式计算服务"""
    
    def __init__(self):
        self.last_error = ""
    
    def calculate_inlet_glr_empirical(self, parameters: Dict[str, Any]) -> float:
        """
        使用经验公式计算吸入口气液比
        
        Args:
            parameters: 包含以下参数的字典
                - produce_index: 生产指数 (bbl/d/psi)
                - saturation_pressure: 饱和压力 (psi)
                - bht: 井底温度 (°F)
                - bsw: 含水率 (小数形式 0-1)
                - gas_oil_ratio: 油气比 (scf/bbl)
                - z_factor: 气体偏差因子 (可选，默认0.8)
                - gas_gravity: 气体相对密度 (可选，默认0.896)
                - oil_gravity: 油相对密度 (可选，默认0.849)
        
        Returns:
            吸入口气液比计算结果
        """
        try:
            # 参数提取
            produce_index = float(parameters.get('produce_index', 0))
            saturation_pressure = float(parameters.get('saturation_pressure', 0))
            bht = float(parameters.get('bht', 0))
            bsw = float(parameters.get('bsw', 0))
            gas_oil_ratio = float(parameters.get('gas_oil_ratio', 0))
            
            # 可选参数，使用默认值
            z_factor = float(parameters.get('z_factor', 0.8))
            gas_gravity = float(parameters.get('gas_gravity', 0.896))
            oil_gravity = float(parameters.get('oil_gravity', 0.849))
            
            # 单位转换
            # 注意：这里需要确认Pi_Mpa的单位，可能需要转换
            pi_mpa = self._convert_produce_index_to_mpa_units(produce_index)
            pb_mpa = self._pressure_psi_to_mpa(saturation_pressure)
            production_gasoline_ratio = gas_oil_ratio * 0.1781  # 单位转换系数
            
            # 调用经验公式
            result = self._calculate_complex_formula(
                Pi_Mpa=pi_mpa,
                Pb_Mpa=pb_mpa,
                tempature=bht,
                water_ratio=bsw,
                Production_gasoline_ratio=production_gasoline_ratio,
                Z_const=z_factor,
                Rg_const=gas_gravity,
                Ro_const=oil_gravity
            )
            
            logger.info(f"经验公式计算吸入口气液比: {result:.4f}")
            return result
            
        except Exception as e:
            self.last_error = f"吸入口气液比经验公式计算失败: {str(e)}"
            logger.error(self.last_error)
            return 0.0
    
    def calculate_pump_depth_empirical(self, parameters: Dict[str, Any]) -> float:
        """
        使用经验公式计算泵挂深度
        
        Args:
            parameters: 包含以下参数的字典
                - perforation_top_depth: 射孔顶界垂深 (ft)
                - pump_hanging_depth: 初始泵挂垂深 (ft)
                - wellhead_pressure: 井口压力 (psi)
                - bottom_hole_pressure: 井底流压 (psi)
                - pump_measured_depth: 泵挂测深 (ft)
                - water_ratio: 含水率 (小数形式 0-1)
                - friction_factor: 油管摩擦系数 (可选，默认0.017)
                - api_gravity: API重度 (可选，默认18.5)
        
        Returns:
            优化后的泵挂深度
        """
        try:
            # 参数提取
            perforation_top_depth = float(parameters.get('perforation_top_depth', 0))
            pump_hanging_depth = float(parameters.get('pump_hanging_depth', 0))
            wellhead_pressure = float(parameters.get('wellhead_pressure', 0))
            bottom_hole_pressure = float(parameters.get('bottom_hole_pressure', 0))
            pump_measured_depth = float(parameters.get('pump_measured_depth', 0))
            water_ratio = float(parameters.get('water_ratio', 0))
            
            # 可选参数
            friction_factor = float(parameters.get('friction_factor', 0.017))
            api_gravity = float(parameters.get('api_gravity', 18.5))
            
            # 调用经验公式
            result = self._excel_formula(
                Vertical_depth_of_perforation_top_boundary=perforation_top_depth,
                Pump_hanging_depth=pump_hanging_depth,
                Pwh=wellhead_pressure,
                Pperfs=bottom_hole_pressure,
                Pump_hanging_depth_measurement=pump_measured_depth,
                water_ratio=water_ratio,
                Kf=friction_factor,
                api=api_gravity
            )
            
            logger.info(f"经验公式计算泵挂深度: {result:.2f} ft")
            return result
            
        except Exception as e:
            self.last_error = f"泵挂深度经验公式计算失败: {str(e)}"
            logger.error(self.last_error)
            return 0.0
    
    def select_optimal_value(self, model_value: float, empirical_value: float, max_error: float = 15.0) -> Dict[str, Any]:
        """
        比较模型预测值和经验公式值，选择最优结果
        
        Args:
            model_value: 模型预测值
            empirical_value: 经验公式值
            max_error: 最大允许误差百分比
            
        Returns:
            包含选择结果的字典
        """
        try:
            error_percent, selected_value = self._select_greate_value(
                model_value, empirical_value, max_error
            )
            
            result = {
                'model_value': model_value,
                'empirical_value': empirical_value,
                'selected_value': selected_value,
                'error_percent': error_percent,
                'selection_method': 'model' if abs(selected_value - model_value) < 1e-6 else 'empirical',
                'is_reliable': error_percent < max_error
            }
            
            logger.info(f"值选择结果: 模型={model_value:.4f}, 经验={empirical_value:.4f}, "
                       f"误差={error_percent:.2f}%, 选择={result['selection_method']}")
            
            return result
            
        except Exception as e:
            self.last_error = f"值选择失败: {str(e)}"
            logger.error(self.last_error)
            return {
                'model_value': model_value,
                'empirical_value': empirical_value,
                'selected_value': model_value,
                'error_percent': 0.0,
                'selection_method': 'model_fallback',
                'is_reliable': False
            }
    
    # ========== 私有方法：经验公式实现 ==========
    
    def _calculate_complex_formula(self, Pi_Mpa, Pb_Mpa, tempature, water_ratio, 
                                 Production_gasoline_ratio, Z_const=0.8, Rg_const=0.896, Ro_const=0.849):
        """吸入口气液比复杂经验公式"""
        # 计算公共子表达式，避免重复计算
        sub_expr_1 = pow(10, 0.0125 * (141.5/Ro_const - 131.5))
        sub_expr_2 = pow(10, 0.00091 * (1.8*tempature + 32))
        sub_expr_3 = 10 * Pb_Mpa * sub_expr_1 / sub_expr_2
        sub_expr_4 = 0.1342 * Rg_const * pow(sub_expr_3, 1/0.83)
        
        # 计算IF嵌套条件
        ratio = Pi_Mpa / Pb_Mpa
        if ratio < 0.1:
            if_result = 3.4 * ratio
        elif ratio < 0.3:
            if_result = 1.1 * ratio + 0.23
        elif ratio < 1:
            if_result = 0.629 * ratio + 0.37
        else:
            if_result = 1
        
        sub_expr_5 = sub_expr_4 * if_result
        sub_expr_6 = 0.0003458 * Z_const * (tempature + 273) / Pi_Mpa
        
        # 计算分子
        numerator = (1 - water_ratio) * (Production_gasoline_ratio - sub_expr_5) * sub_expr_6
        
        # 计算分母
        denom_part1_inner = 5.61 * sub_expr_5 * pow(Rg_const/Ro_const, 0.5) + 1.25 * (1.8*tempature + 32)
        denom_part1 = 0.972 + 0.000147 * pow(denom_part1_inner, 1.175)
        denom_part2 = (1 - water_ratio) * (Production_gasoline_ratio - sub_expr_5) * sub_expr_6 + water_ratio
        denominator = (1 - water_ratio) * denom_part1 + denom_part2
        
        # 最终结果
        result = (numerator / denominator) * 100
        return result
    
    def _excel_formula(self, Vertical_depth_of_perforation_top_boundary, Pump_hanging_depth, 
                      Pwh, Pperfs, Pump_hanging_depth_measurement, water_ratio, Kf=0.017, api=18.5):
        """泵挂深度经验公式"""
        pfi = water_ratio + (1-water_ratio) * 141.5 / (131.5 + api)
        Pwf_Pi = 0.433 * (Vertical_depth_of_perforation_top_boundary - Pump_hanging_depth) * pfi
        result = Pump_hanging_depth + (Pwh - (Pperfs - Pwf_Pi)) * 2.31 / pfi + Kf * Pump_hanging_depth_measurement
        return result
    
    def _select_greate_value(self, model_value, formal_value, max_error=15):
        """选择最优值"""
        cmape = self._CustomMAPE((model_value + formal_value) / 2)
        error_value = cmape(model_value, formal_value)
        return error_value, model_value if error_value < max_error else formal_value
    
    # ========== 辅助方法 ==========
    
    def _pressure_psi_to_mpa(self, pressure_psi: float) -> float:
        """压力单位转换：psi 到 MPa"""
        return pressure_psi * 0.00689476
    
    def _convert_produce_index_to_mpa_units(self, produce_index: float) -> float:
        """
        转换生产指数到MPa单位
        注意：这里需要根据实际的单位转换需求来调整
        """
        # TODO: 确认生产指数的正确单位转换
        # 目前假设直接使用，可能需要调整
        return produce_index
    
    def _CustomMAPE(self, label_mean: float):
        """自定义MAPE计算"""
        class CustomMAPE:
            def __init__(self, label_mean):
                self.label_mean = label_mean
            
            def __call__(self, predict, target):
                predict = float(predict)
                target = float(target)
                
                # 处理目标值为0的情况
                if target == 0:
                    target = self.label_mean
                
                # 计算MAPE
                if target != 0:
                    return abs((target - predict) / target) * 100
                else:
                    return 0.0
        
        return CustomMAPE(label_mean)
    
    def validate_glr_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        """验证气液比计算参数"""
        required_params = ['produce_index', 'saturation_pressure', 'bht', 'bsw', 'gas_oil_ratio']
        
        for param in required_params:
            if param not in parameters:
                return False, f"缺少参数: {param}"
            
            value = parameters[param]
            if value is None or (isinstance(value, (int, float)) and value < 0):
                return False, f"参数 {param} 的值无效: {value}"
        
        # 含水率范围检查
        bsw = parameters['bsw']
        if not (0 <= bsw <= 1):
            return False, f"含水率超出范围 [0,1]: {bsw}"
        
        return True, ""
    
    def validate_pump_depth_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        """验证泵挂深度计算参数"""
        required_params = [
            'perforation_top_depth', 'pump_hanging_depth', 'wellhead_pressure',
            'bottom_hole_pressure', 'pump_measured_depth', 'water_ratio'
        ]
        
        for param in required_params:
            if param not in parameters:
                return False, f"缺少参数: {param}"
            
            value = parameters[param]
            if value is None:
                return False, f"参数 {param} 不能为空"
        
        return True, ""
    
    def get_last_error(self) -> str:
        """获取最后的错误信息"""
        return self.last_error