# services/well_calculation_service.py

from typing import List, Dict, Optional, Tuple, Any
import numpy as np
import logging

logger = logging.getLogger(__name__)

class WellCalculationService:
    """井计算服务 - 处理泵挂垂深和射孔垂深的计算"""

    def __init__(self):
        self.last_error = ""

    def calculate_depths(self,
                        trajectory_data: List[Dict[str, Any]],
                        casing_data: List[Dict[str, Any]],
                        parameters: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        计算泵挂垂深和射孔垂深

        Args:
            trajectory_data: 井轨迹数据列表
            casing_data: 套管数据列表
            parameters: 计算参数
                - method: 计算方法
                - safety_factor: 安全系数
                - other parameters...

        Returns:
            计算结果字典，包含：
            - pump_hanging_depth: 泵挂垂深
            - perforation_depth: 射孔垂深
            - total_depth_tvd: 总垂深
            - total_depth_md: 总测深
            - max_inclination: 最大井斜角
            - max_dls: 最大狗腿度
        """
        try:
            if not trajectory_data:
                self.last_error = "没有轨迹数据"
                return None

            # 提取轨迹数据
            tvd_array = np.array([d['tvd'] for d in trajectory_data])
            md_array = np.array([d['md'] for d in trajectory_data])
            dls_array = np.array([d.get('dls', 0) for d in trajectory_data])

            # 基本统计
            total_depth_tvd = float(np.max(tvd_array))
            total_depth_md = float(np.max(md_array))
            max_dls = float(np.max(dls_array)) if len(dls_array) > 0 else 0

            # 计算井斜角（如果有数据）, 测试中不能打开，会导致报错
            max_inclination = 0
            # if any('inclination' in d for d in trajectory_data):
            #     inclinations = [d.get('inclination', 0) for d in trajectory_data]
            #     max_inclination = float(np.max(inclinations))

            # TODO: 这里插入您的具体计算逻辑
            # 以下是示例计算，请替换为实际的计算方法

            # 根据狗腿度DLS计算泵挂垂深和射孔垂深
            # MD中与顶深的最近的两个点
            TopDepthIndex = 0
            TopDepthNew = 0
            MD = md_array.tolist()
            TVD = tvd_array.tolist()
            # 找到TVD的最大值作为顶深数据
            # 获取顶深数据，找到顶深的最近的两个点
            TopDepth = total_depth_md
            print(TopDepth)
            for i in range(len(MD)):
                if MD[i] >= TopDepth:
                    print(i,len(MD))
                    TopDepthIndex = i
                    break
            # TopDepthNew = round(((TVD[TopDepthIndex]+TVD[TopDepthIndex+1])/2), 2)  # 用于在井轨迹图中画出图来

            # 读取TopDepthIndex和TopDepthIndex-1两个点的TVD数据
            PumpHangingVerticalDepth = TVD[TopDepthIndex] # 泵挂垂深，人工举升设备的安装深度，即泵的进液口所在的垂直深度（TVD）
            PerforationVerticalDepth = TVD[TopDepthIndex-1] # 射孔垂深，油藏射孔的垂直深度

            print(PumpHangingVerticalDepth, PerforationVerticalDepth)
            # 获取计算参数
            method = parameters.get('method', 'default')
            # safety_factor = parameters.get('safety_factor', 1.1)

            # 示例计算逻辑
            if method == 'default':
                # 泵挂垂深计算（示例：取总垂深的80%）
                # pump_hanging_depth = self._calculate_pump_depth_default(trajectory_data, casing_data, parameters)
                pump_hanging_depth = PumpHangingVerticalDepth

                # 射孔垂深计算（示例：取总垂深的90%）
                # perforation_depth = self._calculate_perforation_depth_default(trajectory_data, casing_data, parameters)
                perforation_depth = PerforationVerticalDepth
            else:
                # 其他计算方法
                pump_hanging_depth = total_depth_tvd * 0.8
                perforation_depth = total_depth_tvd * 0.9

            # 返回计算结果
            result = {
                'pump_hanging_depth': round(pump_hanging_depth, 2),
                'perforation_depth': round(perforation_depth, 2),
                'total_depth_tvd': round(total_depth_tvd, 2),
                'total_depth_md': round(total_depth_md, 2),
                'max_inclination': round(max_inclination, 2),
                'max_dls': round(max_dls, 2)
            }

            logger.info(f"计算完成: {result}")
            return result

        except Exception as e:
            self.last_error = f"计算错误: {str(e)}"
            logger.error(self.last_error)
            return None

    def _calculate_pump_depth_default(self,
                                    trajectory_data: List[Dict[str, Any]],
                                    casing_data: List[Dict[str, Any]],
                                    parameters: Dict[str, Any]) -> float:
        """
        默认泵挂深度计算方法

        TODO: 请在此处添加您的实际计算逻辑
        """
        # 示例计算逻辑
        tvd_array = np.array([d['tvd'] for d in trajectory_data])
        total_tvd = np.max(tvd_array)

        # 获取生产套管信息
        production_casing = None
        for casing in casing_data:
            if casing.get('casing_type') == '生产套管':
                production_casing = casing
                break

        if production_casing:
            # 如果有生产套管，在套管底深以上一定距离
            casing_bottom_tvd = production_casing.get('bottom_tvd', total_tvd)
            safety_margin = parameters.get('pump_safety_margin', 50)  # 默认50米安全距离
            pump_depth = casing_bottom_tvd - safety_margin
        else:
            # 没有套管信息，使用默认比例
            pump_depth = total_tvd * 0.8

        return max(0, pump_depth)

    def _calculate_perforation_depth_default(self,
                                           trajectory_data: List[Dict[str, Any]],
                                           casing_data: List[Dict[str, Any]],
                                           parameters: Dict[str, Any]) -> float:
        """
        默认射孔深度计算方法

        TODO: 请在此处添加您的实际计算逻辑
        """
        # 示例计算逻辑
        tvd_array = np.array([d['tvd'] for d in trajectory_data])
        total_tvd = np.max(tvd_array)

        # 获取计算参数
        perforation_ratio = parameters.get('perforation_ratio', 0.9)
        min_distance_from_bottom = parameters.get('min_distance_from_bottom', 20)

        # 计算射孔深度
        perforation_depth = min(
            total_tvd * perforation_ratio,
            total_tvd - min_distance_from_bottom
        )

        return max(0, perforation_depth)

    def validate_calculation_parameters(self, parameters: Dict[str, Any]) -> Tuple[bool, str]:
        """
        验证计算参数

        Args:
            parameters: 计算参数字典

        Returns:
            (是否有效, 错误信息)
        """
        errors = []

        # 验证计算方法
        method = parameters.get('method')
        if not method:
            errors.append("缺少计算方法")
        elif method not in ['default', 'advanced', 'custom']:
            errors.append(f"不支持的计算方法: {method}")

        # 验证数值参数
        numeric_params = {
            'safety_factor': (0.5, 2.0),
            'pump_safety_margin': (0, 200),
            'perforation_ratio': (0.5, 1.0),
            'min_distance_from_bottom': (0, 100)
        }

        for param, (min_val, max_val) in numeric_params.items():
            if param in parameters:
                try:
                    value = float(parameters[param])
                    if value < min_val or value > max_val:
                        errors.append(f"{param}必须在{min_val}到{max_val}之间")
                except (ValueError, TypeError):
                    errors.append(f"{param}必须是有效数字")

        if errors:
            return False, "; ".join(errors)
        return True, ""

    def interpolate_tvd_at_md(self,
                             trajectory_data: List[Dict[str, Any]],
                             target_md: float) -> Optional[float]:
        """
        根据测深插值计算垂深

        Args:
            trajectory_data: 轨迹数据
            target_md: 目标测深

        Returns:
            插值得到的垂深
        """
        try:
            if not trajectory_data:
                return None

            md_array = np.array([d['md'] for d in trajectory_data])
            tvd_array = np.array([d['tvd'] for d in trajectory_data])

            # 检查目标MD是否在范围内
            if target_md < md_array[0]:
                return tvd_array[0]
            elif target_md > md_array[-1]:
                return tvd_array[-1]

            # 线性插值
            tvd_interpolated = np.interp(target_md, md_array, tvd_array)
            return float(tvd_interpolated)

        except Exception as e:
            logger.error(f"插值计算失败: {e}")
            return None

    def get_last_error(self) -> str:
        """获取最后的错误信息"""
        return self.last_error
