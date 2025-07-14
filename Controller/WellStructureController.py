# Controller/WellStructureController.py

from PySide6.QtCore import QObject, Signal, Slot, Property
from typing import List, Dict, Optional, Any
import json
import logging

from DataManage.services.database_service import DatabaseService
from DataManage.services.well_calculation_service import WellCalculationService
from DataManage.services.well_visualization_service import WellVisualizationService

logger = logging.getLogger(__name__)

class WellStructureController(QObject):
    """井身结构控制器 - 管理井轨迹、套管和计算"""

    # 信号定义
    trajectoryDataLoaded = Signal(list)         # 轨迹数据加载完成
    casingDataLoaded = Signal(list)            # 套管数据加载完成
    calculationCompleted = Signal(dict)         # 计算完成
    visualizationReady = Signal(dict)          # 可视化数据准备完成
    operationStarted = Signal()                # 操作开始
    operationFinished = Signal()               # 操作结束
    error = Signal(str)                        # 错误信号

    # 套管相关信号
    casingCreated = Signal(int)                # 套管创建成功
    casingUpdated = Signal(int)                # 套管更新成功
    casingDeleted = Signal(int)                # 套管删除成功

    def __init__(self):
        super().__init__()
        self._db_service = DatabaseService()
        self._calc_service = WellCalculationService()
        self._viz_service = WellVisualizationService()

        self._current_well_id = -1
        self._trajectory_data = []
        self._casing_data = []
        self._calculation_result = {}

        # 连接数据库信号
        self._db_service.trajectoryDataSaved.connect(self._on_trajectory_saved)
        self._db_service.casingDataSaved.connect(self._on_casing_saved)
        self._db_service.calculationCompleted.connect(self._on_calculation_completed)
        self._db_service.databaseError.connect(self._on_database_error)

    # ========== 属性定义 ==========

    @Property(int)
    def currentWellId(self):
        """当前井ID"""
        return self._current_well_id

    @Property(list, notify=trajectoryDataLoaded)
    def trajectoryData(self):
        """轨迹数据"""
        return self._trajectory_data

    @Property(list, notify=casingDataLoaded)
    def casingData(self):
        """套管数据"""
        return self._casing_data

    @Property(dict, notify=calculationCompleted)
    def calculationResult(self):
        """计算结果"""
        return self._calculation_result

    # ========== 信号处理 ==========

    @Slot(int)
    def _on_trajectory_saved(self, well_id: int):
        """轨迹数据保存完成"""
        logger.info(f"轨迹数据已保存，井ID: {well_id}")
        if well_id == self._current_well_id:
            self.loadTrajectoryData(well_id)

    @Slot(int)
    def _on_casing_saved(self, casing_id: int):
        """套管数据保存完成"""
        logger.info(f"套管数据已保存，ID: {casing_id}")
        self.loadCasingData(self._current_well_id)

    @Slot(int)
    def _on_calculation_completed(self, well_id: int):
        """计算完成"""
        logger.info(f"计算完成，井ID: {well_id}")
        if well_id == self._current_well_id:
            self.loadCalculationResult(well_id)

    @Slot(str)
    def _on_database_error(self, error_msg: str):
        """数据库错误"""
        self.error.emit(error_msg)

    # ========== 轨迹数据管理 ==========

    @Slot(int)
    def loadTrajectoryData(self, well_id: int):
        """加载井轨迹数据"""
        self.operationStarted.emit()
        try:
            self._current_well_id = well_id
            self._trajectory_data = self._db_service.get_well_trajectories(well_id)
            self.trajectoryDataLoaded.emit(self._trajectory_data)
            logger.info(f"加载轨迹数据成功，共{len(self._trajectory_data)}条")
        except Exception as e:
            error_msg = f"加载轨迹数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(int)
    def deleteTrajectoryData(self, well_id: int):
        """删除井轨迹数据"""
        self.operationStarted.emit()
        try:
            # 清空轨迹数据
            success = self._db_service.save_well_trajectories(well_id, [])
            if success:
                self._trajectory_data = []
                self.trajectoryDataLoaded.emit([])
                logger.info(f"删除井轨迹数据成功: 井ID {well_id}")
            else:
                self.error.emit("删除轨迹数据失败")
        except Exception as e:
            error_msg = f"删除轨迹数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    # ========== 套管数据管理 ==========

    # 在 onCasingDataLoaded 方法中添加单位信息的日志输出
    @Slot(int)
    def loadCasingData(self, well_id: int):
        """加载套管数据"""
        self.operationStarted.emit()
        try:
            self._current_well_id = well_id
            casing_data = self._db_service.get_casings_by_well(well_id)
        
            # 🔥 添加单位检查和标识
            for casing in casing_data:
                if 'inner_diameter' in casing and casing['inner_diameter']:
                    diameter_value = float(casing['inner_diameter'])
                    if diameter_value > 50:
                        # 可能是毫米单位
                        casing['diameter_unit'] = 'mm'
                        casing['diameter_inches'] = diameter_value / 25.4
                        logger.info(f"套管 {casing.get('casing_type', '')} 内径: {diameter_value} mm ({casing['diameter_inches']:.2f} in)")
                    else:
                        # 可能是英寸单位
                        casing['diameter_unit'] = 'in'
                        casing['diameter_mm'] = diameter_value * 25.4
                        logger.info(f"套管 {casing.get('casing_type', '')} 内径: {diameter_value} in ({casing['diameter_mm']:.1f} mm)")
        
            self._casing_data = casing_data
            self.casingDataLoaded.emit(self._casing_data)
            logger.info(f"加载套管数据成功，共{len(self._casing_data)}个套管")
        except Exception as e:
            error_msg = f"加载套管数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(dict)
    def createCasing(self, casing_data: dict):
        """创建套管（修复版本）"""
        self.operationStarted.emit()
        try:
            logger.info(f"开始创建套管，数据: {casing_data}")
            
            # 确保包含井ID
            if self._current_well_id <= 0:
                self.error.emit("当前没有选择有效的井")
                return
                
            casing_data['well_id'] = self._current_well_id

            # 数据预处理 - 确保数值字段正确
            processed_data = self._preprocess_casing_data(casing_data)
            
            # 数据验证
            is_valid, error_msg = self.validateCasingData(processed_data)
            if not is_valid:
                logger.error(f"套管数据验证失败: {error_msg}")
                self.error.emit(error_msg)
                return

            logger.info(f"套管数据验证通过，开始保存...")
            casing_id = self._db_service.save_casing(processed_data)
            
            if casing_id:
                self.casingCreated.emit(casing_id)
                # 重新加载套管数据
                self.loadCasingData(self._current_well_id)
                logger.info(f"创建套管成功: ID {casing_id}")
            else:
                self.error.emit("保存套管失败")

        except Exception as e:
            error_msg = f"创建套管失败: {str(e)}"
            logger.error(error_msg)
            import traceback
            traceback.print_exc()
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    def _preprocess_casing_data(self, casing_data: dict) -> dict:
        """预处理套管数据，确保使用英制单位"""
        processed = casing_data.copy()
    
        # 数值字段列表（英制单位）
        numeric_fields = [
            'top_depth',        # 英尺
            'bottom_depth',     # 英尺  
            'top_tvd',          # 英尺
            'bottom_tvd',       # 英尺
            'inner_diameter',   # 英寸
            'outer_diameter',   # 英寸
            'wall_thickness',   # 英寸
            'roughness',        # 英寸
            'weight'            # 磅/英尺
        ]
    
        # 处理数值字段
        for field in numeric_fields:
            if field in processed:
                value = processed[field]
                if value is not None and value != '':
                    try:
                        # 检查是否需要单位转换
                        float_value = float(value)
                    
                        # 如果直径值太大，可能是毫米，需要转换
                        if field in ['inner_diameter', 'outer_diameter'] and float_value > 50:
                            float_value = float_value / 25.4  # 毫米转英寸
                            logger.info(f"字段 {field} 从 {value} mm 转换为 {float_value:.3f} in")
                    
                        processed[field] = float_value
                    except (ValueError, TypeError):
                        logger.warning(f"字段 {field} 的值 '{value}' 无法转换为数字，设为默认值")
                        # 设置合理的默认值（英制）
                        defaults = {
                            'inner_diameter': 6.184,    # 7" 套管内径
                            'outer_diameter': 7.000,    # 7" 套管外径
                            'wall_thickness': 0.408,    # 标准壁厚
                            'roughness': 0.0018,        # 标准粗糙度
                            'weight': 29                 # 标准重量
                        }
                        processed[field] = defaults.get(field, 0.0)
                else:
                    # 空值也设置默认值
                    defaults = {
                        'inner_diameter': 6.184,
                        'outer_diameter': 7.000,
                        'wall_thickness': 0.408,
                        'roughness': 0.0018,
                        'weight': 29
                    }
                    processed[field] = defaults.get(field, 0.0)
    
        # 添加单位标识
        processed['unit_system'] = 'imperial'
        processed['depth_unit'] = 'ft'
        processed['diameter_unit'] = 'in'
    
        # 特殊处理：如果没有提供TVD，使用depth值
        if 'top_tvd' not in processed or processed['top_tvd'] == 0:
            processed['top_tvd'] = processed.get('top_depth', 0)
        if 'bottom_tvd' not in processed or processed['bottom_tvd'] == 0:
            processed['bottom_tvd'] = processed.get('bottom_depth', 0)
    
        logger.info(f"预处理后的套管数据（英制）: {processed}")
        return processed

    @Slot(dict)
    def updateCasing(self, casing_data: dict):
        """更新套管"""
        self.operationStarted.emit()
        try:
            casing_id = casing_data.get('id')
            if not casing_id:
                self.error.emit("缺少套管ID")
                return

            # 数据验证
            is_valid, error_msg = self.validateCasingData(casing_data, is_update=True)
            if not is_valid:
                self.error.emit(error_msg)
                return

            self._db_service.save_casing(casing_data)
            self.casingUpdated.emit(casing_id)
            logger.info(f"更新套管成功: ID {casing_id}")

        except Exception as e:
            error_msg = f"更新套管失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(int)
    def deleteCasing(self, casing_id: int):
        """删除套管"""
        self.operationStarted.emit()
        try:
            success = self._db_service.delete_casing(casing_id)
            if success:
                self.casingDeleted.emit(casing_id)
                logger.info(f"删除套管成功: ID {casing_id}")
            else:
                self.error.emit("删除套管失败")

        except Exception as e:
            error_msg = f"删除套管失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    # ========== 计算功能 ==========

    @Slot(dict)
    def calculateDepths(self, parameters: dict):
        """
        计算泵挂垂深和射孔垂深

        Args:
            parameters: 计算参数字典
        """
        self.operationStarted.emit()
        try:
            if not self._trajectory_data:
                self.error.emit("没有轨迹数据，无法进行计算")
                return

            # 调用计算服务
            calc_result = self._calc_service.calculate_depths(
                self._trajectory_data,
                self._casing_data,
                parameters
            )

            if calc_result:
                # 保存计算结果
                calc_result['well_id'] = self._current_well_id
                calc_result['calculation_method'] = parameters.get('method', 'default')
                calc_result['parameters'] = json.dumps(parameters)

                result_id = self._db_service.save_calculation_result(calc_result)

                self._calculation_result = calc_result
                self.calculationCompleted.emit(calc_result)
                logger.info(f"计算完成: 泵挂垂深={calc_result.get('pump_hanging_depth')}, 射孔垂深={calc_result.get('perforation_depth')}")
            else:
                self.error.emit("计算失败")

        except Exception as e:
            error_msg = f"计算失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(int)
    def loadCalculationResult(self, well_id: int):
        """加载最新计算结果"""
        try:
            result = self._db_service.get_latest_calculation_result(well_id)
            if result:
                self._calculation_result = result
                self.calculationCompleted.emit(result)
        except Exception as e:
            logger.error(f"加载计算结果失败: {e}")

    # ========== 可视化功能 ==========

    @Slot()
    def generateWellSketch(self):
        """生成井身结构草图"""
        self.operationStarted.emit()
        try:
            if not self._trajectory_data:
                self.error.emit("没有轨迹数据，无法生成草图")
                return

            # 调用可视化服务生成草图数据
            sketch_data = self._viz_service.generate_well_sketch(
                self._trajectory_data,
                self._casing_data
            )

            if sketch_data:
                self.visualizationReady.emit({'type': 'sketch', 'data': sketch_data})
                logger.info("井身结构草图数据生成完成")
            else:
                self.error.emit("生成草图失败")

        except Exception as e:
            error_msg = f"生成草图失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot()
    def generateTrajectoryChart(self):
        """生成井轨迹图"""
        self.operationStarted.emit()
        try:
            if not self._trajectory_data:
                self.error.emit("没有轨迹数据，无法生成轨迹图")
                return

            # 调用可视化服务生成轨迹图数据
            chart_data = self._viz_service.generate_trajectory_chart(
                self._trajectory_data,
                self._calculation_result
            )

            if chart_data:
                print(chart_data)
                self.visualizationReady.emit({'type': 'trajectory', 'data': chart_data})
                logger.info("井轨迹图数据生成完成")
            else:
                self.error.emit("生成轨迹图失败")

        except Exception as e:
            error_msg = f"生成轨迹图失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    # ========== 数据验证 ==========

    @Slot(int)
    def setCurrentWellId(self, well_id: int):
        """设置当前井ID"""
        if self._current_well_id != well_id:
            self._current_well_id = well_id
            logger.info(f"设置当前井ID: {well_id}")
            
            # 加载新井的数据
            if well_id > 0:
                self.loadTrajectoryData(well_id)
                self.loadCasingData(well_id)

    @Slot(dict, result=bool)  # 修改返回类型注解
    def validateCasingData(self, casing_data: dict, is_update: bool = False) -> tuple:
        """验证套管数据（修复版本）"""
        errors = []

        try:
            # 新建时必须有井ID
            if not is_update and not casing_data.get('well_id'):
                errors.append("缺少井ID")

            # 套管类型验证
            casing_type = casing_data.get('casing_type', '').strip()
            if not casing_type:
                errors.append("套管类型不能为空")

            # 深度验证
            top_depth = casing_data.get('top_depth')
            bottom_depth = casing_data.get('bottom_depth')
            
            if top_depth is not None and bottom_depth is not None:
                try:
                    top = float(top_depth)
                    bottom = float(bottom_depth)
                    if top < 0 or bottom < 0:
                        errors.append("深度不能为负数")
                    elif top >= bottom:
                        errors.append("顶深必须小于底深")
                except (ValueError, TypeError):
                    errors.append("深度必须是有效数字")

            # 直径验证
            inner_diameter = casing_data.get('inner_diameter')
            outer_diameter = casing_data.get('outer_diameter')
            
            if inner_diameter is not None and outer_diameter is not None:
                try:
                    inner = float(inner_diameter)
                    outer = float(outer_diameter)
                    if inner < 0 or outer < 0:
                        errors.append("直径不能为负数")
                    elif inner >= outer:
                        errors.append("内径必须小于外径")
                except (ValueError, TypeError):
                    errors.append("直径必须是有效数字")

            # 壁厚验证
            wall_thickness = casing_data.get('wall_thickness')
            if wall_thickness is not None:
                try:
                    thickness = float(wall_thickness)
                    if thickness < 0:
                        errors.append("壁厚不能为负数")
                except (ValueError, TypeError):
                    errors.append("壁厚必须是有效数字")

        except Exception as e:
            logger.error(f"验证套管数据时出错: {e}")
            errors.append(f"数据验证过程出错: {str(e)}")

        if errors:
            return False, "; ".join(errors)
        return True, ""


    # ========== 辅助方法 ==========

    @Slot(result=dict)
    def getStatistics(self) -> dict:
        """获取统计信息"""
        stats = {
            'trajectory_count': len(self._trajectory_data),
            'casing_count': len(self._casing_data),
            'has_calculation': bool(self._calculation_result)
        }

        if self._trajectory_data:
            tvd_values = [d['tvd'] for d in self._trajectory_data]
            md_values = [d['md'] for d in self._trajectory_data]

            stats.update({
                'max_tvd': max(tvd_values) if tvd_values else 0,
                'max_md': max(md_values) if md_values else 0,
                'min_tvd': min(tvd_values) if tvd_values else 0,
                'min_md': min(md_values) if md_values else 0
            })

        return stats

    @Slot()
    def clearData(self):
        """清空数据"""
        self._trajectory_data = []
        self._casing_data = []
        self._calculation_result = {}
        self._current_well_id = -1


    @Property(str)
    def unitSystem(self):
        """当前单位系统"""
        return getattr(self, '_unit_system', 'imperial')  # 默认英制
    
    @Slot(str)
    def setUnitSystem(self, unit_system: str):
        """设置单位系统"""
        if unit_system in ['metric', 'imperial']:
            self._unit_system = unit_system
            # 重新生成草图
            if hasattr(self, '_current_well_id') and self._current_well_id > 0:
                self.generateWellSketch()
    
    @Slot(str, result='QVariant')
    def getCasingDimensions(self, casing_size: str) -> dict:
        """
        根据套管尺寸获取标准内外径（英制单位）
        """
        # 标准套管尺寸对照表（英寸）
        casing_dimensions = {
            "13-3/8": {
                "outer_diameter": 13.375,     # 英寸
                "inner_diameter": 12.415,     # 英寸
                "wall_thickness": 0.480,      # 英寸
                "weight_per_foot": 68          # 磅/英尺
            },
            "9-5/8": {
                "outer_diameter": 9.625,      # 英寸
                "inner_diameter": 8.681,      # 英寸
                "wall_thickness": 0.472,      # 英寸
                "weight_per_foot": 47         # 磅/英尺
            },
            "7": {
                "outer_diameter": 7.000,      # 英寸
                "inner_diameter": 6.184,      # 英寸
                "wall_thickness": 0.408,      # 英寸
                "weight_per_foot": 29         # 磅/英尺
            },
            "5-1/2": {
                "outer_diameter": 5.500,      # 英寸
                "inner_diameter": 4.778,      # 英寸
                "wall_thickness": 0.361,      # 英寸
                "weight_per_foot": 20         # 磅/英尺
            }
        }
        
        # 清理输入的套管尺寸
        size_key = casing_size.strip().replace('"', '').replace('inch', '').replace('\"', '')
        
        if size_key in casing_dimensions:
            return casing_dimensions[size_key]
        else:
            # 返回默认值
            return {
                "outer_diameter": 7.000,
                "inner_diameter": 6.184,
                "wall_thickness": 0.408,
                "weight_per_foot": 29,
                "error": f"未找到尺寸 {casing_size} 的标准数据"
            }

    @Slot(str, str, result='QVariant')
    def getPrefilledCasingData(self, casing_type: str, casing_size: str) -> dict:
        """
        获取预填充的套管数据（英制单位）
        """
        dimensions = self.getCasingDimensions(casing_size)
        
        # 根据套管类型设置默认参数
        type_defaults = {
            "conductor": {
                "material": "Steel",
                "grade": "K-55",
                "roughness": 0.0018,  # 英寸
                "manufacturer": "API Standard"
            },
            "surface": {
                "material": "Steel", 
                "grade": "N-80",
                "roughness": 0.0018,  # 英寸
                "manufacturer": "API Standard"
            },
            "intermediate": {
                "material": "Steel",
                "grade": "P-110", 
                "roughness": 0.0018,  # 英寸
                "manufacturer": "API Standard"
            },
            "production": {
                "material": "Steel",
                "grade": "P-110",
                "roughness": 0.0018,  # 英寸
                "manufacturer": "API Standard"
            }
        }
        
        base_data = {
            "casing_type": casing_type,
            "casing_size": casing_size,
            "outer_diameter": dimensions.get("outer_diameter", 7.0),     # 英寸
            "inner_diameter": dimensions.get("inner_diameter", 6.184),   # 英寸
            "wall_thickness": dimensions.get("wall_thickness", 0.408),   # 英寸
            "weight": dimensions.get("weight_per_foot", 29),              # 磅/英尺
            "unit_system": "imperial"
        }
        
        # 合并类型默认值
        if casing_type in type_defaults:
            base_data.update(type_defaults[casing_type])
        
        return base_data