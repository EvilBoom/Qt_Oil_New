# services/well_visualization_service.py

from typing import List, Dict, Optional, Any
import numpy as np
import logging

logger = logging.getLogger(__name__)

class WellVisualizationService:
    """井可视化服务 - 生成井身结构草图和轨迹图数据"""

    def __init__(self):
        self.last_error = ""

    def generate_well_sketch(self,
                           trajectory_data: List[Dict[str, Any]],
                           casing_data: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """
        生成井身结构草图数据（修复比例和单位问题）
        """
        try:
            if not trajectory_data:
                self.last_error = "没有轨迹数据"
                return None

            logger.info(f"开始生成井身结构草图: 轨迹点数={len(trajectory_data)}, 套管数={len(casing_data)}")

            # 提取轨迹数据（统一使用英尺）
            tvd_values = []
            md_values = []
            
            for i, d in enumerate(trajectory_data):
                try:
                    tvd = d.get('tvd', 0)
                    md = d.get('md', 0)
                    
                    # 确保数值有效并转换为英尺
                    tvd = float(tvd) if tvd is not None else 0.0
                    md = float(md) if md is not None else 0.0
                    
                    tvd_values.append(tvd)
                    md_values.append(md)
                    
                except Exception as e:
                    logger.warning(f"处理轨迹点 {i} 时出错: {e}")
                    tvd_values.append(0.0)
                    md_values.append(0.0)

            if not tvd_values:
                self.last_error = "没有有效的轨迹数据"
                return None

            tvd_array = np.array(tvd_values)
            md_array = np.array(md_values)

            # 计算水平位移（英尺）
            horizontal_displacement = self._calculate_horizontal_displacement(trajectory_data)

            # 生成井眼轨迹点
            well_path = []
            for i, (tvd, md, h_disp) in enumerate(zip(tvd_array, md_array, horizontal_displacement)):
                well_path.append({
                    'x': float(h_disp),  # 水平位移（英尺）
                    'y': float(tvd),     # 垂深（英尺，向下为正）
                    'md': float(md),     # 测深（英尺）
                    'index': i
                })

            # 处理套管数据（修复比例问题）
            casing_shapes = []
            for i, casing in enumerate(casing_data):
                try:
                    if casing.get('is_deleted', False):
                        continue

                    # 深度数据（英尺）
                    top_depth = casing.get('top_tvd') or casing.get('top_depth', 0)
                    bottom_depth = casing.get('bottom_tvd') or casing.get('bottom_depth', 0)
                    
                    top_depth = float(top_depth) if top_depth is not None else 0.0
                    bottom_depth = float(bottom_depth) if bottom_depth is not None else 0.0
                    
                    if bottom_depth <= top_depth:
                        bottom_depth = top_depth + 328.084  # 默认100米 = 328.084英尺
                    
                    # 直径数据（英寸） - 确保使用英制
                    inner_diameter = casing.get('inner_diameter', 0)
                    outer_diameter = casing.get('outer_diameter', 0)
                    
                    inner_diameter = float(inner_diameter) if inner_diameter is not None else 0.0
                    outer_diameter = float(outer_diameter) if outer_diameter is not None else 0.0
                    
                    # 如果直径数据看起来是公制，转换为英制
                    if outer_diameter > 50:  # 可能是毫米
                        outer_diameter = outer_diameter / 25.4  # 毫米转英寸
                        inner_diameter = inner_diameter / 25.4
                        logger.warning(f"套管 {i} 直径似乎是公制，已转换为英制")
                    
                    # 确保外径大于内径
                    if outer_diameter <= inner_diameter:
                        outer_diameter = inner_diameter + 2  # 默认2英寸壁厚
                    
                    # 🔥 关键修复：计算合理的绘图半径
                    # 深度范围通常是几千英尺，直径是几英寸
                    # 需要将直径按比例缩放到适合的绘图尺寸
                    depth_range = max(tvd_values) - min(tvd_values) if tvd_values else 1000
                    
                    # 缩放因子：让最大套管直径占井深的合理比例（约1-2%）
                    scale_factor = depth_range * 0.015 / max(outer_diameter, 1)
                    
                    scaled_inner_radius = inner_diameter * scale_factor / 2
                    scaled_outer_radius = outer_diameter * scale_factor / 2
                    
                    casing_shape = {
                        'type': casing.get('casing_type', '未知套管'),
                        'top_depth': top_depth,
                        'bottom_depth': bottom_depth,
                        'inner_diameter': inner_diameter,        # 原始直径（英寸）
                        'outer_diameter': outer_diameter,        # 原始直径（英寸）
                        'scaled_inner_radius': scaled_inner_radius,  # 缩放后的绘图半径
                        'scaled_outer_radius': scaled_outer_radius,  # 缩放后的绘图半径
                        'id': casing.get('id', i),
                        'label': f"{casing.get('casing_type', '套管')} {casing.get('casing_size', '')}",
                        'unit': 'imperial',  # 标记单位系统
                        'scale_factor': scale_factor
                    }
                    casing_shapes.append(casing_shape)
                    
                    logger.info(f"套管 {i}: {casing_shape['type']}, 深度 {top_depth:.1f}-{bottom_depth:.1f} ft, 直径 {inner_diameter:.3f}-{outer_diameter:.3f} in")
                    
                except Exception as e:
                    logger.warning(f"处理套管 {i} 时出错: {e}")

            # 如果没有套管数据，创建一个默认套管
            if not casing_shapes and tvd_values:
                max_depth = max(tvd_values)
                depth_range = max_depth
                scale_factor = depth_range * 0.015 / 7.0  # 基于7英寸套管计算
                
                default_casing = {
                    'type': '生产套管',
                    'top_depth': 0.0,
                    'bottom_depth': max_depth * 0.8,
                    'inner_diameter': 6.184,   # 英寸
                    'outer_diameter': 7.000,   # 英寸
                    'scaled_inner_radius': 6.184 * scale_factor / 2,
                    'scaled_outer_radius': 7.000 * scale_factor / 2,
                    'id': 999,
                    'label': '默认生产套管 7"',
                    'unit': 'imperial',
                    'scale_factor': scale_factor
                }
                casing_shapes.append(default_casing)

            # 排序套管（按外径从大到小）
            casing_shapes.sort(key=lambda x: x['outer_diameter'], reverse=True)

            # 生成标注信息
            annotations = self._generate_annotations_imperial(trajectory_data, casing_shapes)

            # 计算图形尺寸（英制）
            max_tvd = float(np.max(tvd_array)) if len(tvd_array) > 0 else 1000.0
            max_horizontal = float(np.max(np.abs(horizontal_displacement))) if len(horizontal_displacement) > 0 else 100.0
            
            # 确保最小尺寸
            max_tvd = max(max_tvd, 100.0)
            max_horizontal = max(max_horizontal, 50.0)

            dimensions = {
                'max_depth': max_tvd,               # 英尺
                'max_horizontal': max_horizontal,   # 英尺
                'aspect_ratio': max_tvd / max(max_horizontal, 1),
                'padding': 0.1,                     # 10%边距
                'unit': 'imperial',                 # 单位标识
                'depth_unit': 'ft',                 # 深度单位
                'diameter_unit': 'in'               # 直径单位
            }

            sketch_data = {
                'well_path': well_path,
                'casings': casing_shapes,
                'annotations': annotations,
                'dimensions': dimensions,
                'type': 'well_sketch',
                'unit_system': 'imperial'
            }

            logger.info("井身结构草图数据生成完成（英制单位）")
            logger.info(f"最终数据: 轨迹点={len(well_path)}, 套管={len(casing_shapes)}")
            logger.info(f"尺寸: 最大深度={max_tvd:.1f} ft, 最大水平={max_horizontal:.1f} ft")
            
            return sketch_data

        except Exception as e:
            self.last_error = f"生成草图失败: {str(e)}"
            logger.error(self.last_error)
            import traceback
            traceback.print_exc()
            return None


    def generate_trajectory_chart(self,
                                trajectory_data: List[Dict[str, Any]],
                                calculation_result: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        生成井轨迹图数据（修复版本）
        """
        try:
            if not trajectory_data:
                self.last_error = "没有轨迹数据"
                return None

            # 提取基本数据，修复None值问题
            tvd_array = []
            md_array = []
            
            for d in trajectory_data:
                tvd = d.get('tvd', 0)
                md = d.get('md', 0)
                # 确保数值不为None
                tvd_array.append(float(tvd) if tvd is not None else 0.0)
                md_array.append(float(md) if md is not None else 0.0)

            MD = md_array
            TVD = tvd_array

            # 井斜角数据
            inclination_data = None
            if any('inclination' in d and d.get('inclination') is not None for d in trajectory_data):
                inclinations = []
                for d in trajectory_data:
                    inc = d.get('inclination', 0)
                    inclinations.append(float(inc) if inc is not None else 0.0)
                    
                inclination_data = {
                    'x': md_array,
                    'y': inclinations,
                    'name': 'Inclination',
                    'type': 'line'
                }

            # 方位角数据
            azimuth_data = None
            if any('azimuth' in d and d.get('azimuth') is not None for d in trajectory_data):
                azimuths = []
                for d in trajectory_data:
                    az = d.get('azimuth', 0)
                    azimuths.append(float(az) if az is not None else 0.0)
                    
                azimuth_data = {
                    'x': md_array,
                    'y': azimuths,
                    'name': 'Azimuth',
                    'type': 'line'
                }

            # 狗腿度数据
            dls_data = None
            if any('dls' in d and d.get('dls') is not None for d in trajectory_data):
                dls_values = []
                for d in trajectory_data:
                    dls = d.get('dls', 0)
                    dls_values.append(float(dls) if dls is not None else 0.0)
                    
                dls_data = {
                    'x': md_array,
                    'y': dls_values,
                    'name': 'DLS',
                    'type': 'line'
                }

            # 标记点
            markers = []

            # 添加计算结果标记
            if calculation_result:
                if 'pump_hanging_depth' in calculation_result:
                    markers.append({
                        'type': 'pump',
                        'tvd': calculation_result['pump_hanging_depth'],
                        'label': f"泵挂: {calculation_result['pump_hanging_depth']}m",
                        'color': '#FF6B6B'
                    })

                if 'perforation_depth' in calculation_result:
                    markers.append({
                        'type': 'perforation',
                        'tvd': calculation_result['perforation_depth'],
                        'label': f"射孔: {calculation_result['perforation_depth']}m",
                        'color': '#4ECDC4'
                    })

            # 3D轨迹数据（如果有北/东坐标）
            trajectory_3d = None
            if any('north_south' in d and 'east_west' in d for d in trajectory_data):
                north_coords = []
                east_coords = []
                for d in trajectory_data:
                    north = d.get('north_south', 0)
                    east = d.get('east_west', 0)
                    north_coords.append(float(north) if north is not None else 0.0)
                    east_coords.append(float(east) if east is not None else 0.0)

                trajectory_3d = {
                    'x': east_coords,
                    'y': north_coords,
                    'z': tvd_array,
                    'name': '3D Trajectory',
                    'type': 'scatter3d'
                }

            # 计算水平位移数据，修复delta计算
            X = [0.0]  # 初始水平位移
            for i in range(1, len(MD)):
                delta_MD = MD[i] - MD[i-1]
                delta_TVD = TVD[i] - TVD[i-1]
                
                # 确保数值有效
                delta_MD = float(delta_MD) if delta_MD is not None else 0.0
                delta_TVD = float(delta_TVD) if delta_TVD is not None else 0.0
                
                delta_MD = round(delta_MD, 3)
                delta_TVD = round(delta_TVD, 3)

                # 修复：确保平方根内的值非负
                displacement_squared = max(0, delta_MD**2 - delta_TVD**2)
                delta_X = np.sqrt(displacement_squared)
                X.append(X[-1] + delta_X)

            # TVD vs 水平位移数据
            tvd_vs_md = {
                'x': [float(x) for x in X],
                'y': tvd_array,
                'name': 'Well Trajectory Profile',
                'type': 'line'
            }

            chart_data = {
                'tvd_vs_md': tvd_vs_md,
                'inclination_data': inclination_data,
                'azimuth_data': azimuth_data,
                'dls_data': dls_data,
                'trajectory_3d': trajectory_3d,
                'markers': markers,
                'type': 'trajectory_chart'
            }

            logger.info("井轨迹图数据生成完成")
            return chart_data

        except Exception as e:
            self.last_error = f"生成轨迹图失败: {str(e)}"
            logger.error(self.last_error)
            import traceback
            traceback.print_exc()
            return None

    def _calculate_horizontal_displacement(self, trajectory_data: List[Dict[str, Any]]) -> np.ndarray:
        """
        计算水平位移（修复版本）- 处理None值和数据类型错误
        """
        n = len(trajectory_data)
        displacement = np.zeros(n)

        try:
            # 如果有北/东坐标，计算实际位移
            has_coordinates = any(
                d.get('north_south') is not None and d.get('east_west') is not None 
                for d in trajectory_data
            )
            
            if has_coordinates:
                logger.info("使用北/东坐标计算水平位移")
                for i, data in enumerate(trajectory_data):
                    north = data.get('north_south', 0)
                    east = data.get('east_west', 0)
                    
                    # 安全转换为浮点数
                    north = float(north) if north is not None else 0.0
                    east = float(east) if east is not None else 0.0
                    
                    displacement[i] = np.sqrt(north**2 + east**2)
            else:
                logger.info("使用MD和TVD计算水平位移")
                # 计算水平位移 - 使用MD和TVD的差值
                for i, data in enumerate(trajectory_data):
                    md = data.get('md', 0)
                    tvd = data.get('tvd', 0)
                    
                    # 安全转换为浮点数
                    md = float(md) if md is not None else 0.0
                    tvd = float(tvd) if tvd is not None else 0.0
                    
                    # 使用勾股定理计算水平位移，确保平方根内的值非负
                    horizontal_component = max(0, md**2 - tvd**2)
                    displacement[i] = np.sqrt(horizontal_component)

        except Exception as e:
            logger.error(f"计算水平位移时出错: {e}")
            # 如果计算失败，返回零位移数组
            displacement = np.zeros(n)

        return displacement

    def _generate_annotations(self,
                            trajectory_data: List[Dict[str, Any]],
                            casing_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        生成标注信息（修复版本）
        """
        annotations = []

        try:
            # 井口标注
            annotations.append({
                'type': 'well_head',
                'x': 0,
                'y': 0,
                'text': '井口',
                'anchor': 'top'
            })

            # 井底标注
            if trajectory_data:
                tvd_values = [float(d.get('tvd', 0) or 0) for d in trajectory_data]
                md_values = [float(d.get('md', 0) or 0) for d in trajectory_data]
                
                if tvd_values and md_values:
                    max_tvd = max(tvd_values)
                    max_md = max(md_values)

                    # 找到井底对应的水平位移
                    bottom_index = -1
                    for i, d in enumerate(trajectory_data):
                        tvd = float(d.get('tvd', 0) or 0)
                        if tvd == max_tvd:
                            bottom_index = i
                            break

                    if bottom_index >= 0:
                        displacement = self._calculate_horizontal_displacement(trajectory_data)
                        annotations.append({
                            'type': 'well_bottom',
                            'x': float(displacement[bottom_index]),
                            'y': float(max_tvd),
                            'text': f'井底 TVD: {max_tvd:.1f}m, MD: {max_md:.1f}m',
                            'anchor': 'bottom'
                        })

            # 套管标注
            for casing in casing_data:
                if casing.get('is_deleted', False):
                    continue

                top_depth = casing.get('top_tvd') or casing.get('top_depth', 0)
                top_depth = float(top_depth) if top_depth is not None else 0.0
                
                casing_type = casing.get('casing_type', '套管')

                annotations.append({
                    'type': 'casing',
                    'x': 0,
                    'y': top_depth,
                    'text': casing_type,
                    'anchor': 'left'
                })

        except Exception as e:
            logger.error(f"生成标注时出错: {e}")

        return annotations

    def export_visualization_data(self,
                                 visualization_type: str,
                                 data: Dict[str, Any],
                                 format: str = 'json') -> Optional[str]:
        """
        导出可视化数据

        Args:
            visualization_type: 可视化类型（sketch/trajectory）
            data: 可视化数据
            format: 导出格式（json/csv）

        Returns:
            导出的数据字符串
        """
        try:
            if format == 'json':
                import json
                return json.dumps(data, indent=2, ensure_ascii=False)
            elif format == 'csv':
                # TODO: 实现CSV导出
                pass
            else:
                self.last_error = f"不支持的导出格式: {format}"
                return None

        except Exception as e:
            self.last_error = f"导出失败: {str(e)}"
            logger.error(self.last_error)
            return None

    def get_last_error(self) -> str:
        """获取最后的错误信息"""
        return self.last_error

    def _generate_annotations_imperial(self,
                                     trajectory_data: List[Dict[str, Any]],
                                     casing_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        生成标注信息（英制单位）
        """
        annotations = []

        try:
            # 井口标注
            annotations.append({
                'type': 'well_head',
                'x': 0,
                'y': 0,
                'text': 'Wellhead',
                'anchor': 'top',
                'unit': 'ft'
            })

            # 井底标注
            if trajectory_data:
                tvd_values = [float(d.get('tvd', 0) or 0) for d in trajectory_data]
                md_values = [float(d.get('md', 0) or 0) for d in trajectory_data]
                
                if tvd_values and md_values:
                    max_tvd = max(tvd_values)
                    max_md = max(md_values)

                    # 找到井底对应的水平位移
                    bottom_index = -1
                    for i, d in enumerate(trajectory_data):
                        tvd = float(d.get('tvd', 0) or 0)
                        if tvd == max_tvd:
                            bottom_index = i
                            break

                    if bottom_index >= 0:
                        displacement = self._calculate_horizontal_displacement(trajectory_data)
                        annotations.append({
                            'type': 'well_bottom',
                            'x': float(displacement[bottom_index]),
                            'y': float(max_tvd),
                            'text': f'TD: {max_tvd:.0f} ft TVD, {max_md:.0f} ft MD',
                            'anchor': 'bottom',
                            'unit': 'ft'
                        })

            # 套管标注（英制）
            for casing in casing_data:
                if casing.get('is_deleted', False):
                    continue

                top_depth = casing.get('top_tvd') or casing.get('top_depth', 0)
                top_depth = float(top_depth) if top_depth is not None else 0.0
                
                casing_type = casing.get('casing_type', '套管')
                casing_size = casing.get('casing_size', '')
                outer_diameter = casing.get('outer_diameter', 0)

                # 标注文本包含尺寸信息
                label_text = f"{casing_size} {casing_type}"
                if outer_diameter:
                    label_text += f" (OD: {outer_diameter:.3f}\")"

                annotations.append({
                    'type': 'casing',
                    'x': 0,
                    'y': top_depth,
                    'text': label_text,
                    'anchor': 'left',
                    'unit': 'ft/in'
                })

        except Exception as e:
            logger.error(f"生成标注时出错: {e}")

        return annotations