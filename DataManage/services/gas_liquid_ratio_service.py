# DataManage/services/gas_liquid_ratio_service.py

import logging
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

class GasLiquidRatioService:
    """气液比计算服务 - 包含经验公式和模型预测"""
    
    def __init__(self):
        self.last_error = ""
    
    def calculate_inlet_glr_empirical(self, parameters: Dict[str, Any]) -> float:
        """
        使用经验公式计算吸入口气液比
        
        Args:
            parameters: 包含计算参数的字典
                - produce_index: 生产指数 (bbl/d/psi)
                - saturation_pressure: 饱和压力 (psi)
                - bht: 井底温度 (°F)
                - bsw: 含水率 (小数形式，0-1)
                - gas_oil_ratio: 油气比 (scf/bbl)
        
        Returns:
            吸入口气液比计算结果
        """
        try:
            # 导入经验公式函数
            from formulas_.glr import calculate_complex_formula
            
            # 参数提取和单位转换
            produce_index = parameters.get('produce_index', 0)
            saturation_pressure = parameters.get('saturation_pressure', 0)
            bht = parameters.get('bht', 0)
            bsw = parameters.get('bsw', 0)
            gas_oil_ratio = parameters.get('gas_oil_ratio', 0)
            
            # 单位转换
            # 压力从 psi 转换到 MPa
            pb_mpa = self._pressure_psi_to_mpa(saturation_pressure)
            
            # 油气比单位转换 (scf/bbl 到所需单位)
            production_gasoline_ratio = gas_oil_ratio * 0.1781
            
            # 调用经验公式
            result = calculate_complex_formula(
                Pi_Mpa=produce_index,  # 注意：这里可能需要单位转换
                Pb_Mpa=pb_mpa,
                tempature=bht,
                water_ratio=bsw,
                Production_gasoline_ratio=production_gasoline_ratio
            )
            
            logger.info(f"经验公式计算完成: 吸入口气液比 = {result}")
            return result
            
        except Exception as e:
            self.last_error = f"经验公式计算失败: {str(e)}"
            logger.error(self.last_error)
            return 0.0
    
    def calculate_inlet_glr_combined(self, 
                                   parameters: Dict[str, Any], 
                                   model_prediction: float) -> Dict[str, Any]:
        """
        结合经验公式和模型预测计算最终的吸入口气液比
        
        Args:
            parameters: 计算参数
            model_prediction: 模型预测值
            
        Returns:
            包含计算结果的字典
        """
        try:
            # 经验公式计算
            empirical_result = self.calculate_inlet_glr_empirical(parameters)
            
            # 选择最优值
            from formulas_.mape import select_greate_value
            error, final_result = select_greate_value(model_prediction, empirical_result)
            
            result = {
                'empirical_value': empirical_result,
                'model_prediction': model_prediction,
                'final_value': final_result,
                'error': error,
                'method_used': 'empirical' if abs(final_result - empirical_result) < 1e-6 else 'model'
            }
            
            logger.info(f"吸入口气液比计算结果: "
                       f"模型预测值={model_prediction:.4f}, "
                       f"经验公式值={empirical_result:.4f}, "
                       f"误差={error:.2f}, "
                       f"最终选择={final_result:.4f}")
            
            return result
            
        except Exception as e:
            self.last_error = f"综合计算失败: {str(e)}"
            logger.error(self.last_error)
            return {
                'empirical_value': 0.0,
                'model_prediction': model_prediction,
                'final_value': model_prediction,
                'error': 0.0,
                'method_used': 'model_fallback'
            }
    
    def _pressure_psi_to_mpa(self, pressure_psi: float) -> float:
        """压力单位转换：psi 到 MPa"""
        return pressure_psi * 0.00689476
    
    def validate_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        """验证计算参数"""
        required_params = [
            'produce_index', 'saturation_pressure', 'bht', 'bsw', 'gas_oil_ratio'
        ]
        
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
    
    def get_last_error(self) -> str:
        """获取最后的错误信息"""
        return self.last_error