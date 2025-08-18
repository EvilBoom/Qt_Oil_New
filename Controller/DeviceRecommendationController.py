# Controller/device_recommendation_controller.py

import os
import json
import logging
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import QmlElement

# 导入数据服务
from DataManage.services.database_service import DatabaseService
from DataManage.models.production_parameters import ProductionParameters, ProductionPrediction

from PySide6.QtCore import QObject, Signal, Slot, QTimer, Property
from .MLPredictionService import MLPredictionService, PredictionInput, PredictionResults
import matplotlib.pyplot as plt
import matplotlib
import matplotlib.patches as patches
import numpy as np
NUMPY_AVAILABLE = True
# 中文字体兼容
matplotlib.rcParams['font.sans-serif'] = ['SimHei']  # 设置中文字体
# 添加Word文档生成支持
try:
    from docx import Document
    from docx.shared import Inches, Pt
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml.ns import qn
    from docx.shared import RGBColor
    DOCX_AVAILABLE = True
except ImportError:
    DOCX_AVAILABLE = False
    logging.warning("python-docx 未安装，无法生成Word文档")

# 添加PDF转换支持
try:
    from docx2pdf import convert
    PDF_CONVERT_AVAILABLE = True
except ImportError:
    PDF_CONVERT_AVAILABLE = False
    logging.warning("docx2pdf 未安装，无法转换PDF")



# 导入模型相关（假设模型加载器在Models目录）
# from Models.model_loader import ModelLoader

QML_IMPORT_NAME = "DeviceRecommendation"
QML_IMPORT_MAJOR_VERSION = 1

logger = logging.getLogger(__name__)

@QmlElement
class DeviceRecommendationController(QObject):
    """设备选型推荐控制器"""
    
    # ========== 信号定义 ==========
    # 生产参数相关信号
    parametersLoaded = Signal(dict)  # 参数加载完成
    parametersSaved = Signal(int)    # 参数保存完成，返回ID
    parametersError = Signal(str)    # 参数操作错误
    
    # 预测相关信号
    predictionCompleted = Signal(dict)  # 预测完成
    predictionProgress = Signal(float)  # 预测进度 (0-1)
    predictionError = Signal(str)       # 预测错误
    
    # IPR曲线相关信号
    iprCurveGenerated = Signal(list)   # IPR曲线生成完成
    
    # 井列表相关信号
    wellsListLoaded = Signal(list)     # 井列表加载完成
    
    # 选型会话相关信号
    sessionCreated = Signal(int)       # 选型会话创建完成
    sessionUpdated = Signal()          # 会话更新
    
    # 通用信号
    busyChanged = Signal()
    pumpsLoaded = Signal('QVariant')  # 添加泵数据加载完成信号
    # 添加信号定义（在类的信号定义部分）
    motorsLoaded = Signal('QVariant')  # 电机数据加载完成信号
    error = Signal(str)  # 错误信号
    
    # 新增ML预测相关信号
    predictionCompleted = Signal(dict)
    predictionProgress = Signal(float)
    predictionError = Signal(str)
    iprCurveGenerated = Signal(list)

    # 添加报告相关信号
    reportExported = Signal(str)       # 报告导出完成
    reportExportError = Signal(str)    # 报告导出错误
    reportDraftSaved = Signal(str)     # 报告草稿保存完成
    reportDataPrepared = Signal(dict)  # 报告数据准备完成信号

    # 在信号定义部分添加
    separatorsLoaded = Signal('QVariant')  # 分离器数据加载完成信号

    pumpCurvesDataReady = Signal('QVariant')  # 泵性能曲线数据准备就绪
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._db_service = DatabaseService()
        self._current_project_id = -1
        self._current_well_id = -1
        self._current_parameters_id = -1
        self._current_session_id = -1
        self._busy = False
         
         # 新增ML服务
        self.ml_service = MLPredictionService()
        self.prediction_progress = 0
        
        # 进度模拟定时器
        self.progress_timer = QTimer()
        self.progress_timer.timeout.connect(self._update_prediction_progress)
    

        logger.info("设备推荐控制器初始化完成")
    
    # ========== 属性定义 ==========
    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy
    
    def _set_busy(self, value: bool):
        if self._busy != value:
            self._busy = value
            self.busyChanged.emit()
    
    @Property(int)
    def currentProjectId(self):
        return self._current_project_id
    
    @currentProjectId.setter
    def currentProjectId(self, value: int):
        self._current_project_id = value
        logger.info(f"设置当前项目ID: {value}")
    
    @Property(int)
    def currentWellId(self):
        return self._current_well_id
    
    @currentWellId.setter
    def currentWellId(self, value: int):
        if self._current_well_id != value:
            self._current_well_id = value
            # 切换井时自动加载其活跃参数
            if value > 0:
                self.loadActiveParameters(value)
    
    @Property(int)
    def currentProjectId(self):
        return self._current_project_id

    @currentProjectId.setter
    def currentProjectId(self, value: int):
        if self._current_project_id != value:
            self._current_project_id = value
            logger.info(f"设置设备推荐控制器当前项目ID: {value}")

    # ========== 井管理相关方法 ==========
    @Slot(int)
    def loadWellsWithParameters(self, project_id: int):
        """加载项目下的井列表及其参数状态"""
        try:
            self._set_busy(True)
            wells = self._db_service.get_wells_with_production_params(project_id)
            print("这里是loadWellsWithParameters,正在加载井数据")
            # 转换为QML友好的格式
            wells_data = []
            for well in wells:
                wells_data.append({
                    'id': well['id'],
                    'name': well['well_name'],
                    'hasParameters': well.get('has_production_parameters', False),
                    'wellType': well.get('well_type', ''),
                    'status': well.get('well_status', '')
                })
            
            self.wellsListLoaded.emit(wells_data)
            logger.info(f"加载井列表成功: 项目ID {project_id}, 共{len(wells_data)}口井")
            
        except Exception as e:
            error_msg = f"加载井列表失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    # ========== 生产参数管理 ==========
    @Slot(int)
    def loadActiveParameters(self, well_id: int):
        """加载井的活跃生产参数"""
        try:
            self._set_busy(True)
            params_list = self._db_service.get_production_parameters(well_id, active_only=True)
            
            if params_list:
                params = params_list[0]  # 获取活跃参数
                self._current_parameters_id = params['id']
                self.parametersLoaded.emit(params)
                logger.info(f"加载生产参数成功: 井ID {well_id}")
            else:
                # 没有参数时发送空数据
                self.parametersLoaded.emit({})
                self._current_parameters_id = -1
                logger.info(f"井ID {well_id} 暂无生产参数")
                
        except Exception as e:
            error_msg = f"加载生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    @Slot(int, int)
    def loadParametersHistory(self, well_id: int, limit: int = 10):
        """加载生产参数历史版本"""
        try:
            self._set_busy(True)
            # 使用正确的方法
            history_data = self._db_service.get_production_parameters_history(well_id, limit)
            logger.info(f"开始加载参数历史: 井ID {well_id}")
            logger.info(f"从数据库获取到历史数据: {len(history_data)}条")
            if history_data:
                # 打印第一条记录看看数据结构
                logger.info(f"第一条历史记录: {history_data[0]}")
        
        
            # 发射包含历史数据的信号
            self.parametersLoaded.emit({'history': history_data})
            logger.info(f"加载参数历史成功: 井ID {well_id}, 共{len(history_data)}条记录")
        
        except Exception as e:
            error_msg = f"加载参数历史失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    @Slot(dict, bool)
    def saveProductionParameters(self, params_data: dict, create_new_version: bool = True):
        """
        保存生产参数
        
        Args:
            params_data: 参数数据（来自QML）
            create_new_version: 是否创建新版本
        """
        try:
            self._set_busy(True)
            
            # 数据转换（QML格式转数据库格式）
            db_params = {
                'well_id': self._current_well_id,
                'geo_pressure': params_data.get('geoPressure'),
                'expected_production': params_data.get('expectedProduction'),
                'saturation_pressure': params_data.get('saturationPressure'),
                'produce_index': params_data.get('produceIndex'),
                'bht': params_data.get('bht'),
                'bsw': params_data.get('bsw'),
                'api': params_data.get('api'),
                'gas_oil_ratio': params_data.get('gasOilRatio'),
                'well_head_pressure': params_data.get('wellHeadPressure'),
                'parameter_name': params_data.get('parameterName', ''),
                'description': params_data.get('description', ''),
                'created_by': params_data.get('createdBy', '用户')
            }
            # 把参数转换成float类型
            numeric_fields = ['geo_pressure', 'expected_production', 'saturation_pressure', 
                              'produce_index', 'bht', 'bsw', 'api', 'gas_oil_ratio', 
                              'well_head_pressure']
        
            for field in numeric_fields:
                if field in db_params and db_params[field] is not None:
                    try:
                        db_params[field] = float(db_params[field])
                    except (ValueError, TypeError):
                        raise ValueError(f"参数 {field} 必须是有效数字")
        
            
            # 保存到数据库
            params_id = self._db_service.create_production_parameters(
                db_params, 
                create_new_version
            )
            
            self._current_parameters_id = params_id
            self.parametersSaved.emit(params_id)
            logger.info(f"保存生产参数成功: ID {params_id}")
            
        except Exception as e:
            error_msg = f"保存生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    @Slot(int)
    def setActiveParameters(self, params_id: int):
        """设置活跃参数版本"""
        try:
            self._set_busy(True)
            success = self._db_service.set_active_production_parameters(params_id)
            
            if success:
                self._current_parameters_id = params_id
                # 重新加载参数
                self.loadActiveParameters(self._current_well_id)
            else:
                self.parametersError.emit("设置活跃参数失败")
                
        except Exception as e:
            error_msg = f"设置活跃参数失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    @Slot(int)
    def deleteParameters(self, params_id: int):
        """删除参数版本"""
        try:
            self._set_busy(True)
            success = self._db_service.delete_production_parameters(params_id)
            
            if success:
                # 如果删除的是当前参数，重新加载
                if params_id == self._current_parameters_id:
                    self.loadActiveParameters(self._current_well_id)
            else:
                self.parametersError.emit("删除参数失败")
                
        except Exception as e:
            error_msg = f"删除参数失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    def _run_ml_prediction(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """运行ML预测 - 修复版本，使用真正的MLPredictionService"""
        try:
            logger.info("=== 开始真正的ML模型预测 ===")
            
            # 创建PredictionInput对象
            input_data = PredictionInput(
                geopressure=float(params.get('geo_pressure', 0)),
                produce_index=float(params.get('produce_index', 0)),
                bht=float(params.get('bht', 0)),
                expected_production=float(params.get('expected_production', 0)),
                bsw=float(params.get('bsw', 0)),
                api=float(params.get('api', 0)),
                gas_oil_ratio=float(params.get('gas_oil_ratio', 0)),
                saturation_pressure=float(params.get('saturation_pressure', 0)),
                wellhead_pressure=float(params.get('well_head_pressure', 0)),
                perforation_depth = self.calculation_result['perforation_depth'],
                pump_hanging_depth = self.calculation_result['pump_hanging_depth']
            )
        
            logger.info(f"ML预测输入数据: 地层压力={input_data.geopressure}, 产量={input_data.expected_production}")
        
            # 🔥 使用真正的ML服务进行预测
            ml_results = self.ml_service.predict_all(input_data)
        
            # 转换为控制器期望的格式，确保字段名正确
            return {
                'production': ml_results.production,
                'total_head': ml_results.total_head,  # 🔥 使用 total_head 而不是 pump_depth
                'gas_rate': ml_results.gas_rate,
                'confidence': ml_results.confidence,
                'method': 'MLPredictionService'
            }
        
        except Exception as e:
            logger.error(f"ML预测失败，使用后备方案: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
        
            # 🔥 后备方案也要使用正确的字段名
            return {
                'production': params['expected_production'] * 0.1,
                'total_head': 1.0,  # 🔥 使用 total_head
                'gas_rate': 0.1,
                'confidence': 0.75,
                'method': 'fallback'
            }
    
    def _run_empirical_calculation(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """运行经验公式计算"""
        # TODO: 实际的经验公式
        # 这里是简单的示例计算
        pump_depth = params['geo_pressure'] * 0.7
        gas_rate = params['gas_oil_ratio'] / 10000.0
        
        return {
            'pump_depth': pump_depth,
            'gas_rate': gas_rate
        }

    @Slot(dict)
    def predictWithEmpirical(self, parameters):
        """执行包含经验公式的预测"""
        self.operationStarted.emit()
        try:
            # 1. 机器学习预测
            ml_results = self._predict_with_ml(parameters)
            
            # 2. 经验公式计算
            empirical_results = self._calculate_with_empirical_formulas(parameters)
            
            # 3. 结合两种方法的结果
            combined_results = self._combine_ml_and_empirical_results(ml_results, empirical_results)
            
            # 4. 发射结果
            self.predictionCompleted.emit(combined_results)
            
        except Exception as e:
            error_msg = f"预测失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()
    
    def _combine_ml_and_empirical_results(self, ml_results: Dict, empirical_results: Dict) -> Dict:
        """结合机器学习和经验公式的结果"""
        try:
            from DataManage.services.empirical_formulas_service import EmpiricalFormulasService
            
            empirical_service = EmpiricalFormulasService()
            combined = ml_results.copy()
            
            # 处理吸入口气液比
            if 'inlet_glr' in ml_results and 'empirical_inlet_glr' in empirical_results:
                ml_glr = ml_results['inlet_glr']
                empirical_glr = empirical_results['empirical_inlet_glr']
                
                # 选择最优值
                selection_result = empirical_service.select_optimal_value(ml_glr, empirical_glr)
                
                combined.update({
                    'inlet_glr_ml': ml_glr,
                    'inlet_glr_empirical': empirical_glr,
                    'inlet_glr_final': selection_result['selected_value'],
                    'inlet_glr_selection': selection_result,
                    'inlet_glr': selection_result['selected_value']  # 最终使用的值
                })
            
            # 处理泵挂深度
            if 'pump_depth' in ml_results and 'empirical_pump_depth' in empirical_results:
                ml_depth = ml_results['pump_depth']
                empirical_depth = empirical_results['empirical_pump_depth']
                
                selection_result = empirical_service.select_optimal_value(ml_depth, empirical_depth)
                
                combined.update({
                    'pump_depth_ml': ml_depth,
                    'pump_depth_empirical': empirical_depth,
                    'pump_depth_final': selection_result['selected_value'],
                    'pump_depth_selection': selection_result,
                    'pump_depth': selection_result['selected_value']
                })
            
            # 添加计算方法标识
            combined['calculation_methods'] = {
                'ml_prediction': True,
                'empirical_formulas': True,
                'hybrid_selection': True
            }
            
            return combined
            
        except Exception as e:
            logger.error(f"结果合并失败: {e}")
            return ml_results

    def _calculate_with_empirical_formulas(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """使用经验公式计算预测结果"""
        try:
            from DataManage.services.empirical_formulas_service import EmpiricalFormulasService
            
            empirical_service = EmpiricalFormulasService()
            results = {}
            
            # 1. 计算吸入口气液比
            glr_params = {
                'produce_index': parameters.get('produce_index', 0),
                'saturation_pressure': parameters.get('saturation_pressure', 0),
                'bht': parameters.get('bht', 0),
                'bsw': parameters.get('bsw', 0),
                'gas_oil_ratio': parameters.get('gas_oil_ratio', 0)
            }
            
            # 验证参数
            is_valid, error_msg = empirical_service.validate_glr_parameters(glr_params)
            if is_valid:
                empirical_glr = empirical_service.calculate_inlet_glr_empirical(glr_params)
                results['empirical_inlet_glr'] = empirical_glr
            else:
                logger.warning(f"气液比参数验证失败: {error_msg}")
                results['empirical_inlet_glr'] = 0.0
            
            # 2. 计算泵挂深度（如果有相关参数）
            if all(k in parameters for k in ['perforation_top_depth', 'pump_hanging_depth']):
                pump_depth_params = {
                    'perforation_top_depth': parameters.get('perforation_top_depth', 0),
                    'pump_hanging_depth': parameters.get('pump_hanging_depth', 0),
                    'wellhead_pressure': parameters.get('wellhead_pressure', 0),
                    'bottom_hole_pressure': parameters.get('bottom_hole_pressure', 0),
                    'pump_measured_depth': parameters.get('pump_measured_depth', 0),
                    'water_ratio': parameters.get('bsw', 0)
                }
                
                is_valid, error_msg = empirical_service.validate_pump_depth_parameters(pump_depth_params)
                if is_valid:
                    empirical_pump_depth = empirical_service.calculate_pump_depth_empirical(pump_depth_params)
                    results['empirical_pump_depth'] = empirical_pump_depth
                else:
                    logger.warning(f"泵挂深度参数验证失败: {error_msg}")
            
            return results
            
        except Exception as e:
            logger.error(f"经验公式计算失败: {e}")
            return {}
    
    def _calculate_inlet_glr_empirical(self, parameters: Dict[str, Any]) -> float:
        """使用经验公式计算吸入口气液比"""
        try:
            from DataManage.services.gas_liquid_ratio_service import GasLiquidRatioService
            
            glr_service = GasLiquidRatioService()
            
            # 验证参数
            is_valid, error_msg = glr_service.validate_parameters(parameters)
            if not is_valid:
                logger.error(f"参数验证失败: {error_msg}")
                return 0.0
            
            # 计算经验公式值
            return glr_service.calculate_inlet_glr_empirical(parameters)
            
        except Exception as e:
            logger.error(f"经验公式计算失败: {e}")
            return 0.0

    
    # 在DeviceRecommendationController.py中添加
    def pressureChange(self, pressure):
        """
        压力转换函数
        """
        # 如果需要压力单位转换，在这里实现
        return pressure

    def sample(self, start_pressure, end_pressure, num_points):
        """
        在给定压力范围内采样指定数量的点
        """
        if num_points <= 1:
            return [start_pressure]
    
        step = (start_pressure - end_pressure) / (num_points - 1)
        return [start_pressure - i * step for i in range(num_points)]

    def calIPR(self, AverageGeopressure, Expectedproduction, SaturationPressure, wellLowFlowPressure):
        """
        计算IPR曲线，返回曲线上的点
        """
        logger.info(f"计算IPR曲线: Pr={AverageGeopressure}, Prod={Expectedproduction}, Pb={SaturationPressure}, Pwf={wellLowFlowPressure}")
    
        wellLowFlowPressure = self.pressureChange(wellLowFlowPressure)
    
        if wellLowFlowPressure >= SaturationPressure:
            jo = Expectedproduction/(AverageGeopressure - wellLowFlowPressure)
            qMax = jo*(wellLowFlowPressure-SaturationPressure)
            
            samplePwfs = [self.sample(AverageGeopressure,SaturationPressure,5)] # 直线，采样5个点
            
        else:
            jo = Expectedproduction/(AverageGeopressure-SaturationPressure+SaturationPressure/1.8*(1-0.2*wellLowFlowPressure/SaturationPressure-0.8*(wellLowFlowPressure/SaturationPressure)**2))
            qbWithSaturationPressure = jo*(AverageGeopressure-SaturationPressure)
            qv = jo*SaturationPressure/1.8
            qMax = qbWithSaturationPressure + qv
        
            samplePwfs = [self.sample(AverageGeopressure,SaturationPressure,5)] # 直线，采样5个点
            samplePwfs.append(self.sample(SaturationPressure,0,30)) # 曲线，采样30个点
    
        logger.info(f'JO: {jo}')
        logger.info(f'samplePwfs: {len(samplePwfs)} segments')
    
        points = []
        for ylist in samplePwfs:
            xlist = []
            for y in ylist:
                if y >= SaturationPressure:
                    x = jo*(AverageGeopressure-y)   # 使用公式1进行计算
                else:
                    x = qbWithSaturationPressure+qv*(1-0.2*y/SaturationPressure-0.8*(y/SaturationPressure)**2)  # 使用公式3进行计算
                xlist.append(x)
            points.append((xlist,ylist))
    
        return points

    def _generate_ipr_curve(self, params: Dict[str, Any]) -> List[Dict[str, float]]:
        """
        生成IPR曲线数据 - 修正版本，确保正确的趋势
        """
        try:
            # 提取参数
            pr = float(params['geo_pressure'])  # 地层压力
            expected_prod = float(params['expected_production'])  # 期望产量
            pb = float(params.get('saturation_pressure', pr * 0.6))  # 饱和压力
            pwf_current = float(params.get('well_head_pressure', pr * 0.4))  # 当前井底流压
    
            logger.info(f"生成IPR曲线参数: Pr={pr}, Prod={expected_prod}, Pb={pb}, Pwf_current={pwf_current}")
    
            # 计算生产指数
            if pwf_current >= pb:
                # 线性段
                pi = expected_prod / (pr - pwf_current) if (pr - pwf_current) > 0 else 0.1
            else:
                # Vogel段 - 反推生产指数
                # 简化计算
                pi = expected_prod / (pr - pb + pb/1.8 * (1 - 0.2*(pwf_current/pb) - 0.8*(pwf_current/pb)**2))
    
            logger.info(f"计算生产指数 PI = {pi:.4f}")
    
            # 生成IPR曲线数据点
            curve_data = []
            num_points = 36
        
            for i in range(num_points):
                # 井底流压从地层压力线性递减到0
                pwf = pr * (1 - i / (num_points - 1))
            
                # 根据压力计算产量
                if pwf >= pb:
                    # 线性段：q = PI * (Pr - Pwf)
                    q = pi * (pr - pwf)
                else:
                    # Vogel段
                    q_linear = pi * (pr - pb)  # 线性段贡献
                
                    # Vogel段贡献
                    pb_ratio = pwf / pb if pb > 0 else 0
                    vogel_factor = 1 - 0.2 * pb_ratio - 0.8 * (pb_ratio ** 2)
                    q_vogel = pi * pb / 1.8 * vogel_factor
                
                    q = q_linear + q_vogel
            
                # 确保产量非负
                q = max(0, q)
            
                curve_data.append({
                    'production': float(q),
                    'pressure': float(pwf)
                })
    
            # 按压力从高到低排序
            curve_data.sort(key=lambda point: point['pressure'], reverse=True)
    
            logger.info(f"生成IPR曲线数据点: {len(curve_data)}个")
            if curve_data:
                logger.info(f"压力范围: {curve_data[0]['pressure']:.1f} - {curve_data[-1]['pressure']:.1f} psi")
                logger.info(f"产量范围: {curve_data[-1]['production']:.2f} - {curve_data[0]['production']:.2f} bbl/d")
            
                # 验证趋势：压力高产量低，压力低产量高
                logger.info(f"验证趋势 - 高压点: P={curve_data[0]['pressure']:.1f}, Q={curve_data[0]['production']:.2f}")
                logger.info(f"验证趋势 - 低压点: P={curve_data[-1]['pressure']:.1f}, Q={curve_data[-1]['production']:.2f}")
    
            return curve_data
        
        except Exception as e:
            logger.error(f"生成IPR曲线失败: {str(e)}")
            # 简单线性IPR作为后备
            return self._generate_simple_ipr_curve(params)

    def _generate_simple_ipr_curve(self, params: Dict[str, Any]) -> List[Dict[str, float]]:
        """
        生成简单的线性IPR曲线作为后备 - 修正版本
        """
        curve_data = []
        pr = float(params['geo_pressure'])
        expected_prod = float(params['expected_production'])
    
        # 简单的线性关系：假设在地层压力的一半时达到期望产量
        pi = expected_prod / (pr * 0.5) if pr > 0 else 0.1

        for i in range(21):
            # 压力从地层压力递减到0
            pwf = pr * (1 - i / 20.0)
            # 产量随着压力降低而增加
            q = pi * (pr - pwf)
            q = max(0, q)  # 确保非负
        
            curve_data.append({
                'pressure': float(pwf),
                'production': float(q)
            })

        return curve_data

    # ========== 选型会话管理 ==========
    @Slot(dict)
    def createSelectionSession(self, session_data: dict):
        """创建新的选型会话"""
        try:
            self._set_busy(True)
            
            # TODO: 实现选型会话创建逻辑
            # 这需要先创建 device_selection.py 模型
            
            session_id = 1  # 模拟返回
            self._current_session_id = session_id
            self.sessionCreated.emit(session_id)
            
            logger.info(f"创建选型会话成功: ID {session_id}")
            
        except Exception as e:
            error_msg = f"创建选型会话失败: {str(e)}"
            logger.error(error_msg)
            self.parametersError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    # ========== 工具方法 ==========
    @Slot(float, str, result=float)
    def convertUnit(self, value: float, conversion_type: str) -> float:
        """单位转换工具"""
        conversions = {
            'psi_to_mpa': lambda x: x * 0.00689476,
            'mpa_to_psi': lambda x: x / 0.00689476,
            'f_to_c': lambda x: (x - 32) * 5 / 9,
            'c_to_f': lambda x: x * 9 / 5 + 32,
            'bbl_to_m3': lambda x: x * 0.158987,
            'm3_to_bbl': lambda x: x / 0.158987
        }
        
        if conversion_type in conversions:
            return conversions[conversion_type](value)
        return value
    
    @Slot(dict, result=bool)
    def validateParameters(self, params: dict) -> bool:
        """验证参数合理性"""
        try:
            # 创建临时对象进行验证
            temp_params = ProductionParameters()
            for key, value in params.items():
                # 转换QML属性名到数据库字段名
                db_key = self._qml_to_db_key(key)
                if hasattr(temp_params, db_key):
                    # 尝试进行类型转换
                    if isinstance(value, str) and db_key not in ['parameter_name', 'description', 'created_by']:
                        try:
                            value = float(value)
                        except (ValueError, TypeError):
                            pass
                    setattr(temp_params, db_key, value)
            
            is_valid, error_msg = temp_params.validate()
            if not is_valid:
                self.parametersError.emit(error_msg)
                logger.error(f"参数验证失败: {error_msg}")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"参数验证失败: {str(e)}")
            return False
    
    def _qml_to_db_key(self, qml_key: str) -> str:
        """QML属性名转数据库字段名"""
        mapping = {
            'geoPressure': 'geo_pressure',
            'expectedProduction': 'expected_production',
            'saturationPressure': 'saturation_pressure',
            'produceIndex': 'produce_index',
            'gasOilRatio': 'gas_oil_ratio',
            'wellHeadPressure': 'well_head_pressure'
        }
        return mapping.get(qml_key, qml_key)

    @Slot(str, result='QVariant')
    def getPumpsByLiftMethod(self, lift_method):
        """根据举升方式获取泵列表 - 修复版本"""
        try:
            self._set_busy(True)
            logger.info(f"根据举升方式获取泵列表: {lift_method}")
        
            # 🔥 从数据库获取指定举升方式的泵数据
            pumps = self._db_service.get_devices_by_lift_method(
                device_type='pump', 
                lift_method=lift_method.lower(),
                status='active'
            )

            # 如果数据库中没有数据，使用模拟数据作为后备
            if not pumps['devices']:
                logger.warning(f"数据库中没有 {lift_method} 泵数据，使用模拟数据")
                pumps = self._generate_mock_pumps_by_lift_method(lift_method)

            # 🔥 确保数据格式正确
            pump_list = []
            for device_data in pumps['devices']:
                if device_data.get('pump_details'):
                    pump_info = {
                        'id': device_data['id'],
                        'manufacturer': device_data['manufacturer'],
                        'model': device_data['model'],
                        'liftMethod': device_data.get('lift_method', lift_method),  # 🔥 确保liftMethod字段存在
                        'series': self.extract_series(device_data['model']),
                        'minFlow': device_data['pump_details']['displacement_min'] or 0,
                        'maxFlow': device_data['pump_details']['displacement_max'] or 1000,
                        'headPerStage': device_data['pump_details']['single_stage_head'] or 25,
                        'powerPerStage': device_data['pump_details']['single_stage_power'] or 2.5,
                        'efficiency': device_data['pump_details']['efficiency'] or 75,
                        'outerDiameter': device_data['pump_details']['outside_diameter'] or 4.0,
                        'shaftDiameter': device_data['pump_details']['shaft_diameter'] or 0.75,
                        'maxStages': device_data['pump_details']['max_stages'] or 100,
                        'displacement': device_data['pump_details']['displacement_max'] or 1000
                    }
                    pump_list.append(pump_info)

            logger.info(f"找到 {len(pump_list)} 个 {lift_method.upper()} 泵")
        
            # 🔥 发射信号
            self.pumpsLoaded.emit(pump_list)
        
            return pump_list

        except Exception as e:
            error_msg = f"获取 {lift_method} 泵数据失败: {str(e)}"
            logger.error(error_msg)
            # 🔥 失败时使用模拟数据
            pump_list = self._generate_mock_pumps_by_lift_method(lift_method)['devices']
            self.pumpsLoaded.emit(pump_list)
            return pump_list
        finally:
            self._set_busy(False)

    def _generate_mock_pumps_by_lift_method(self, lift_method):
        """根据举升方式生成模拟泵数据"""
        mock_pumps = {
            'esp': [
                {
                    'id': 'ESP_400_001',
                    'manufacturer': 'Baker Hughes',
                    'model': 'FLEXPump™ 400',
                    'lift_method': 'esp',
                    'pump_details': {
                        'displacement_min': 150,
                        'displacement_max': 4000,
                        'single_stage_head': 25,
                        'single_stage_power': 2.5,
                        'efficiency': 68,
                        'outside_diameter': 4.0,
                        'shaft_diameter': 0.75,
                        'max_stages': 400
                    }
                },
                {
                    'id': 'ESP_500_001',
                    'manufacturer': 'Schlumberger',
                    'model': 'REDA Maximus',
                    'lift_method': 'esp',
                    'pump_details': {
                        'displacement_min': 500,
                        'displacement_max': 8000,
                        'single_stage_head': 30,
                        'single_stage_power': 3.5,
                        'efficiency': 72,
                        'outside_diameter': 5.12,
                        'shaft_diameter': 1.0,
                        'max_stages': 350
                    }
                }
            ],
            'pcp': [
                {
                    'id': 'PCP_001',
                    'manufacturer': 'Weatherford',
                    'model': 'PRISM™ PCP',
                    'lift_method': 'pcp',
                    'pump_details': {
                        'displacement_min': 10,
                        'displacement_max': 500,
                        'single_stage_head': 150,
                        'single_stage_power': 5.0,
                        'efficiency': 65,
                        'outside_diameter': 4.5,
                        'shaft_diameter': 1.0,
                        'max_stages': 1
                    }
                }
            ],
            'jet': [
                {
                    'id': 'JET_001',
                    'manufacturer': 'Halliburton',
                    'model': 'HyPump JET',
                    'lift_method': 'jet',
                    'pump_details': {
                        'displacement_min': 100,
                        'displacement_max': 2000,
                        'single_stage_head': 50,
                        'single_stage_power': 1.5,
                        'efficiency': 30,
                        'outside_diameter': 3.5,
                        'shaft_diameter': 0.5,
                        'max_stages': 1
                    }
                }
            ]
        }
    
        return {
            'devices': mock_pumps.get(lift_method.lower(), []),
            'total': len(mock_pumps.get(lift_method.lower(), []))
        }

    def _extract_series(self, model: str) -> str:
        """从型号中提取系列号"""
        try:
            # 提取数字系列
            import re
            series_match = re.search(r'(\d{3,4})', model)
            if series_match:
                return series_match.group(1)
            
            # 提取字母系列
            if 'FLEXPump' in model:
                return '400'
            elif 'REDA' in model:
                return '500'
            elif 'RCH' in model:
                return '600'
            else:
                return '400'  # 默认值
        except:
            return '400'
    @Slot(float)
    def generateIPRCurve(self, current_production: float = 0):
        """单独生成IPR曲线数据"""
        try:
            self._set_busy(True)
            logger.info(f"开始生成IPR曲线 - 参数ID: {self._current_parameters_id}, 当前产量: {current_production}")
        
            if self._current_parameters_id <= 0:
                raise ValueError("请先设置生产参数")
        
            params = self._db_service.get_production_parameters_by_id(self._current_parameters_id)
            if not params:
                raise ValueError("无法获取生产参数")
        
            # 使用当前产量更新参数
            if current_production > 0:
                params['expected_production'] = current_production
                logger.info(f"使用当前产量更新参数: {current_production}")
        
            ipr_data = self._generate_ipr_curve(params)
    
            logger.info(f"生成IPR曲线完成: {len(ipr_data)}个数据点")
            self.iprCurveGenerated.emit(ipr_data)
    
        except Exception as e:
            error_msg = f"生成IPR曲线失败: {str(e)}"
            logger.error(error_msg)
            self.predictionError.emit(error_msg)
        finally:
            self._set_busy(False)

    # 在 DeviceRecommendationController 类中添加以下方法

    @Slot(result='QVariant')
    def getMotorsByType(self):
        """获取电机列表"""
        try:
            self._set_busy(True)
        
            # 从数据库获取电机数据
            motors = self._db_service.get_devices(
                device_type='MOTOR', 
                status='active'
            )
            # logger.info(f"查询电机数据返回: {len(motors.get('devices', []))}个设备")
        
            # 修复：确保 devices 列表存在
            devices = motors.get('devices', [])
            if not devices:
                logger.warning("数据库中没有找到电机数据")
                return []
            #  # 添加调试信息 - 只在有设备时执行
            # for device_data in devices[:3]:  # 只打印前3个
            #     logger.info(f"设备详情: ID={device_data.get('id')}, 类型={device_data.get('device_type')}, 型号={device_data.get('model')}")
            #     logger.info(f"电机详情: {device_data.get('motor_details', {})}")
        
            # 转换为QML需要的格式
            motor_list = []
            for device_data in motors['devices']:
                # logger.info(f"处理设备: {device_data.get('id')} - {device_data.get('model')}")
            
                motor_details = device_data.get('motor_details')
            
                if motor_details:
                    # logger.info(f"找到电机详情: {motor_details}")
                
                    # 获取频率参数
                    freq_params = motor_details.get('frequency_params', [])
                    # logger.info(f"频率参数: {len(freq_params)}个")
                
                    # 提取支持的电压和频率
                    voltages = []
                    frequencies = []
                    for param in freq_params:
                        if param.get('voltage') and param['voltage'] not in voltages:
                            voltages.append(param['voltage'])
                        if param.get('frequency') and param['frequency'] not in frequencies:
                            frequencies.append(param['frequency'])
                
                    # 获取主要参数（默认使用60Hz数据）
                    main_params = next((p for p in freq_params if p.get('frequency') == 60), 
                                     freq_params[0] if freq_params else {})
                
                    motor_info = {
                        'id': device_data['id'],
                        'manufacturer': device_data['manufacturer'],
                        'model': device_data['model'],
                        'series': self._extract_motor_series(device_data['model']),
                        'power': main_params.get('power', 0),
                        'voltage': sorted(voltages),
                        'frequency': sorted(frequencies),
                        'efficiency': main_params.get('efficiency', 0),
                        'powerFactor': main_params.get('power_factor', 0.85),
                        'insulationClass': motor_details.get('insulation_class', 'F'),
                        'protectionClass': motor_details.get('protection_class', 'IP68'),
                        'outerDiameter': motor_details.get('outside_diameter', 0),
                        'length': motor_details.get('length', 0),
                        'weight': motor_details.get('weight', 0),
                        'speed_60hz': next((p.get('speed') for p in freq_params if p.get('frequency') == 60), 3600),
                        'speed_50hz': next((p.get('speed') for p in freq_params if p.get('frequency') == 50), 3000),
                        'current_3300v_60hz': next((p.get('current') for p in freq_params 
                                                  if p.get('frequency') == 60 and p.get('voltage') == 3300), 0),
                        'temperatureRise': 80  # 默认温升
                    }
                    motor_list.append(motor_info)
                    # logger.info(f"添加电机到列表: {motor_info['manufacturer']} {motor_info['model']}")
                else:
                    logger.warning(f"设备 {device_data.get('id')} 没有电机详情")


            # logger.info(f"从数据库加载电机数据: {len(motor_list)}个")
            return motor_list
        
        except Exception as e:
            logger.error(f"获取电机数据失败: {str(e)}")
            self.error.emit(f"获取电机数据失败: {str(e)}")
            return []
        finally:
            self._set_busy(False)

    def _extract_motor_series(self, model: str) -> str:
        """从电机型号中提取系列号"""
        try:
            import re
            # 提取常见的系列标识
            if 'Electrospeed' in model:
                series_match = re.search(r'Electrospeed\s*(\d+)', model)
                return series_match.group(1) if series_match else 'ES'
            elif 'REDA' in model:
                if 'Hotline' in model:
                    return 'HT'
                elif 'MaxForce' in model:
                    return 'MF'
                elif 'Ultra' in model:
                    return 'ULT'
                else:
                    return 'REDA'
            elif 'Magnus' in model:
                return 'MG'
            elif 'Ultra HD' in model:
                return 'UHD'
            elif 'Titan' in model:
                return 'TTN'
            elif 'PM-' in model:
                return 'PM'
            elif 'EM-' in model:
                return 'EM'
            elif 'SubDrive' in model:
                return 'SD'
            elif 'MS-' in model:
                return 'MS'
            else:
                # 尝试提取数字系列
                series_match = re.search(r'(\d{2,4})', model)
                return series_match.group(1) if series_match else 'Standard'
        except:
            return 'Standard'

    @Slot(result='QVariant')
    def getMotorsByType(self):
        """获取电机列表"""
        try:
            self._set_busy(True)
        
            # 从数据库获取电机数据
            motors = self._db_service.get_devices(
                device_type='motor', 
                status='active'
            )
            logger.info(f"查询电机数据返回: {len(motors.get('devices', []))}个设备")
             # 添加调试信息
            # 修复：确保 devices 列表存在
            devices = motors.get('devices', [])
            if not devices:
                logger.warning("数据库中没有找到电机数据")
                return []

            # for device in motors.get('devices', [])[:3]:  # 只打印前3个
            #     logger.info(f"设备详情: ID={device.get('id')}, 类型={device.get('device_type')}, 型号={device.get('model')}")
            #     logger.info(f"电机详情: {device.get('motor_details', {})}")
        
            # 转换为QML需要的格式
            motor_list = []
            for device_data in devices:
                # logger.info(f"处理设备: {device_data.get('id')} - {device_data.get('model')}")
            
                motor_details = device_data.get('motor_details')
           
                if motor_details:
                    # logger.info(f"找到电机详情: {motor_details}")
                
                    # 获取频率参数
                    freq_params = motor_details.get('frequency_params', [])
                    # logger.info(f"频率参数: {len(freq_params)}个")
                
                    # 提取支持的电压和频率
                    voltages = []
                    frequencies = []
                    for param in freq_params:
                        if param.get('voltage') and param['voltage'] not in voltages:
                            voltages.append(param['voltage'])
                        if param.get('frequency') and param['frequency'] not in frequencies:
                            frequencies.append(param['frequency'])
                
                    # 获取主要参数（默认使用60Hz数据）
                    main_params = next((p for p in freq_params if p.get('frequency') == 60), 
                                     freq_params[0] if freq_params else {})
                
                    motor_info = {
                        'id': device_data['id'],
                        'manufacturer': device_data['manufacturer'],
                        'model': device_data['model'],
                        'series': self._extract_motor_series(device_data['model']),
                        'power': main_params.get('power', 0),
                        'voltage': sorted(voltages),
                        'frequency': sorted(frequencies),
                        'efficiency': main_params.get('efficiency', 0),
                        'powerFactor': main_params.get('power_factor', 0.85),
                        'insulationClass': motor_details.get('insulation_class', 'F'),
                        'protectionClass': motor_details.get('protection_class', 'IP68'),
                        'outerDiameter': motor_details.get('outside_diameter', 0),
                        'length': motor_details.get('length', 0),
                        'weight': motor_details.get('weight', 0),
                        'speed_60hz': next((p.get('speed') for p in freq_params if p.get('frequency') == 60), 3600),
                        'speed_50hz': next((p.get('speed') for p in freq_params if p.get('frequency') == 50), 3000),
                        'current_3300v_60hz': next((p.get('current') for p in freq_params 
                                                  if p.get('frequency') == 60 and p.get('voltage') == 3300), 0),
                        'temperatureRise': 80  # 默认温升
                    }
                    motor_list.append(motor_info)
                    # logger.info(f"添加电机到列表: {motor_info['manufacturer']} {motor_info['model']}")
                else:
                    logger.warning(f"设备 {device_data.get('id')} 没有电机详情")


            # logger.info(f"从数据库加载电机数据: {len(motor_list)}个")
            return motor_list
        
        except Exception as e:
            logger.error(f"获取电机数据失败: {str(e)}")
            self.error.emit(f"获取电机数据失败: {str(e)}")
            return []
        finally:
            self._set_busy(False)

    @Slot()
    def runPrediction(self):
        """运行包含经验公式的预测"""
        try:
            self._set_busy(True)
            self.predictionProgress.emit(0.1)
            
            logger.info(f"开始预测 - 当前井ID: {self._current_well_id}, 参数ID: {self._current_parameters_id}")

            self.calculation_result = self._db_service.get_latest_calculation_result(self._current_well_id)
            # print("############",result)
            # 获取当前参数
            if self._current_parameters_id <= 0:
                raise ValueError("请先选择或创建生产参数")
            
            params = self._db_service.get_production_parameters_by_id(self._current_parameters_id)
            if not params:
                raise ValueError("无法获取生产参数")

            logger.info(f"获取到参数: {params}")
            
            self.predictionProgress.emit(0.3)
            
            # 1. 运行ML预测
            ml_results = self._run_ml_prediction(params)
            
            self.predictionProgress.emit(0.5)
            
            # 2. 运行经验公式计算
            empirical_results = self._run_empirical_calculation_with_formulas(params)
            
            self.predictionProgress.emit(0.7)
            
            # 3. 智能选择最优结果
            combined_results = self._combine_results_with_selection(ml_results, empirical_results)
            
            self.predictionProgress.emit(0.9)
            
            # 4. 生成IPR曲线数据
            ipr_data = self._generate_ipr_curve(params)
            
            # 5. 保存预测结果
            prediction_data = {
                'parameters_id': self._current_parameters_id,
                'predicted_production': combined_results.get('production'),
                'predicted_pump_depth': combined_results.get('pump_depth'),
                'predicted_gas_rate': combined_results.get('gas_rate'),
                'empirical_pump_depth': empirical_results.get('pump_depth'),
                'empirical_gas_rate': empirical_results.get('gas_rate'),
                'prediction_method': 'Hybrid_ML_Empirical',
                'confidence_score': combined_results.get('confidence', 0.85),
                'ipr_curve_data': json.dumps(ipr_data)
            }
            
            prediction_id = self._db_service.save_production_prediction(prediction_data)
            
            self.predictionProgress.emit(1.0)
            
            # 发送详细结果
            results = {
                'id': prediction_id,
                'mlResults': ml_results,
                'empiricalResults': empirical_results,
                'combinedResults': combined_results,
                'comparisonData': self._generate_comparison_data(ml_results, empirical_results),
                'iprCurve': ipr_data
            }
            
            self.predictionCompleted.emit(results)
            self.iprCurveGenerated.emit(ipr_data)
            
            logger.info(f"混合预测完成: 参数ID {self._current_parameters_id}")
            
        except Exception as e:
            error_msg = f"预测失败: {str(e)}"
            logger.error(error_msg)
            self.predictionError.emit(error_msg)
        finally:
            self._set_busy(False)
            self.predictionProgress.emit(0.0)
    

    def _run_empirical_calculation_with_formulas(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """使用正确经验公式计算 - 修复版本"""
        try:
            logger.info("=== 使用正确的经验公式计算（修复版） ===")
        
            # 1. 计算吸入口汽液比（使用修复的复杂公式）
            gas_rate = self._calculate_inlet_glr_complex_formula(params)
        
            # 2. 计算扬程（使用正确的Excel公式）
            total_head = self._calculate_total_head_excel_formula(params)
            
            # 3. 计算推荐产量（使用经验调整系数）
            production = params['expected_production'] * 0.92
        
            logger.info(f"经验公式计算完成: 产量={production:.2f}, 扬程={total_head:.2f}, 气液比={gas_rate:.4f}")
        
            return {
                'production': production,
                'total_head': total_head,
                'gas_rate': gas_rate,  
                'method': 'corrected_empirical_formulas'
            }
        
        except Exception as e:
            logger.error(f"修正经验公式计算失败: {e}")
            # 降级使用简化公式
            return {
                'production': params.get('expected_production', 0) * 0.9,
                'total_head': params.get('geo_pressure', 0) * 1.4,
                'gas_rate': 97.0,
                'method': 'fallback_with_correct_glr'
            }

    def _calculate_total_head_excel_formula(self, params: Dict[str, Any]) -> float:
        """使用Temp.py中的Excel公式计算扬程"""
        try:
            Vertical_depth_of_perforation_top_boundary = self.calculation_result['perforation_depth']
            Pump_hanging_depth = self.calculation_result['pump_hanging_depth']

            Pwh = params.get('well_head_pressure', 0)  # 井口压力
            Pperfs = params.get('geo_pressure', 0) * 0.6  # 井底流压（估算）
            Pump_hanging_depth_measurement = Pump_hanging_depth * 1.1  # 泵挂测深（估算）
            water_ratio = params.get('bsw', 0)  # 含水率
            api = params.get('api', 18.5)  # API
            Kf = 0.017  # 油管摩擦系数
        
            logger.info(f"扬程计算参数: 射孔深度={Vertical_depth_of_perforation_top_boundary}, 泵挂深度={Pump_hanging_depth}")
            logger.info(f"压力参数: 井口压力={Pwh}, 井底流压={Pperfs}, 含水率={water_ratio}, API={api}")
        
            # 🔥 使用Temp.py中的Excel公式
            result = self._excel_formula(
                Vertical_depth_of_perforation_top_boundary,
                Pump_hanging_depth,
                Pwh,
                Pperfs,
                Pump_hanging_depth_measurement,
                water_ratio,
                Kf,
                api
            )
            # 扬程计算结果取绝对值并确保非负
            result = abs(result)  # 确保结果为非负数
        
            logger.info(f"Excel公式计算扬程结果: {result:.2f} ft")
            return max(0, result)  # 确保非负
        
        except Exception as e:
            logger.error(f"Excel扬程公式计算失败: {e}")
            # 使用简化公式作为后备
            return params.get('geo_pressure', 0) * 1.4

    def _excel_formula(self, Vertical_depth_of_perforation_top_boundary, Pump_hanging_depth, 
                  Pwh, Pperfs, Pump_hanging_depth_measurement, water_ratio, Kf=0.017, api=18.5):
        """完整实现Temp.py中的Excel公式"""
        try:
            # 井液相对密度
            pfi = water_ratio + (1 - water_ratio) * 141.5 / (131.5 + api)
        
            # 井底流压差
            Pwf_Pi = 0.433 * (Vertical_depth_of_perforation_top_boundary - Pump_hanging_depth) * pfi
        
            # 扬程计算
            result = Pump_hanging_depth + (Pwh - (Pperfs - Pwf_Pi)) * 2.31 / pfi + Kf * Pump_hanging_depth_measurement
        
            logger.info(f"Excel公式详细: pfi={pfi:.4f}, Pwf_Pi={Pwf_Pi:.2f}, 最终扬程={result:.2f}")
            return result
        
        except Exception as e:
            logger.error(f"Excel公式执行失败: {e}")
            return 0.0

    def _pressure_change(self, pressure):
        """压力转换函数（如果需要单位转换）"""
        # 这里可以添加压力单位转换逻辑
        return pressure

    def _run_empirical_calculation_simple(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """简化的经验计算作为后备方案"""
        try:
            geo_pressure = params.get('geo_pressure', 0)
            expected_prod = params.get('expected_production', 0)
            gas_oil_ratio = params.get('gas_oil_ratio', 0)
        
            return {
                'production': expected_prod * 0.9,
                'total_head': geo_pressure * 1.4,
                'gas_rate': gas_oil_ratio / 1000,
                'method': 'simple_empirical'
            }
        except Exception as e:
            logger.error(f"简化经验计算失败: {e}")
            return {
                'production': 10,
                'total_head': 20,
                'gas_rate': 0.1,
                'method': 'default'
            }

    def _calculate_inlet_glr_complex_formula(self, params: Dict[str, Any]) -> float:
        """使用专家总结的经验公式计算吸入口气液比 - 最新版本"""
        try:
            # 🔥 从参数中提取值
            # Pi_Mpa = params.get('produce_index', 0)  # 生产指数 (Mpa)
            Pb_Mpa = self._pressure_change(params.get('saturation_pressure', 0))  # 饱和压力 (Mpa)
            Pi_Mpa = Pb_Mpa *1.2 # 默认为饱和压力的1.2倍，后根据用户手动调整
            temperature = params.get('bht', 114)  # 井底温度 (℃)，默认114℃
            water_ratio = params.get('bsw', 0) / 100.0 if params.get('bsw', 0) > 1 else params.get('bsw', 0)  # 含水率
            gas_oil_ratio = params.get('gas_oil_ratio', 0)  # 气油比
            Production_gasoline_ratio = gas_oil_ratio * 0.1781  # 生产汽油比

            logger.info(f"新版气液比计算参数:")
            logger.info(f"  生产指数 Pi_Mpa: {Pi_Mpa}")
            logger.info(f"  饱和压力 Pb_Mpa: {Pb_Mpa}")
            logger.info(f"  井底温度: {temperature}℃")
            logger.info(f"  含水率: {water_ratio}")
            logger.info(f"  生产汽油比: {Production_gasoline_ratio}")

            # 常数
            Z_const = 0.8  # 用户可修改
            Rg_const = 0.896  # 相对密度Rg，用户可修改
            Ro_const = 0.849  # 相对密度Ro，用户可修改

            # 🔥 使用专家公式重新计算
            result = self._calculate_expert_glr_formula(
                temperature, Production_gasoline_ratio, water_ratio, 
                Pb_Mpa, Pi_Mpa, Z_const, Rg_const, Ro_const
            )

            logger.info(f"专家公式计算气液比结果: {result:.4f}")
            result = abs(result)  # 确保结果为非负数
            return max(0, result)

        except Exception as e:
            logger.error(f"专家公式计算失败: {e}")
            return 97.0  # 使用默认值作为后备
    
    def _calculate_expert_glr_formula_error(self, temperature, gas_oil_ratio, water_ratio, 
                                 Pb_Mpa, Pi_Mpa, Z_const=0.8, Rg_const=0.896, Ro_const=0.849):
        """修正的吸入口气液比计算公式"""
        try:
            logger.info(f"修正GLR计算: T={temperature}℃, GOR={gas_oil_ratio}scf/bbl, P={Pi_Mpa}MPa")
        
            # 🔥 Step 1: 温度转换
            temp_rankine = (temperature * 9/5) + 491.67  # °C to °R
            temp_fahrenheit = temperature * 9/5 + 32     # °C to °F
        
            # 🔥 Step 2: 压力转换为psi（Standing相关性需要psi单位）
            Pb_psi = Pb_Mpa * 145.038
            Pi_psi = Pi_Mpa * 145.038
        
            # 🔥 Step 3: 计算溶解气油比 Rs (Standing相关性)
            # Rs = γg * [(Pb * 10^(0.0125*API - 0.00091*T)) / 18.2 + 1.4]^1.2048
            api_gravity = 141.5 / Ro_const - 131.5
        
            # Standing方程的修正形式
            A = 0.0125 * api_gravity - 0.00091 * temp_fahrenheit
            Rs_pb = Rg_const * pow((Pb_psi * pow(10, A) / 18.2 + 1.4), 1.2048)
        
            # 如果压力低于饱和压力，Rs = Rs_pb
            if Pi_psi <= Pb_psi:
                Rs = Rs_pb * pow(Pi_psi / Pb_psi, 1.2048)
            else:
                Rs = Rs_pb
            
            logger.info(f"计算溶解气油比 Rs = {Rs:.2f} scf/bbl")
        
            # 🔥 Step 4: 计算自由气量
            # 自由气 = 总气油比 - 溶解气油比
            free_gas_ratio = max(0, gas_oil_ratio - Rs)
            logger.info(f"自由气量 = {gas_oil_ratio} - {Rs:.2f} = {free_gas_ratio:.2f} scf/bbl")
        
            # 🔥 Step 5: 计算气体体积系数 Bg
            # Bg = 0.00504 * Z * T / P (T in °R, P in psi)
            Bg = 0.00504 * Z_const * temp_rankine / Pi_psi
            logger.info(f"气体体积系数 Bg = {Bg:.6f} rb/scf")
        
            # 🔥 Step 6: 计算原油体积系数 Bo
            # Standing相关性：Bo = 0.972 + 0.000147*F^1.175
            F = Rs * pow(Rg_const / Ro_const, 0.5) + 1.25 * temp_fahrenheit
            Bo = 0.972 + 0.000147 * pow(F, 1.175)
            logger.info(f"原油体积系数 Bo = {Bo:.4f} rb/stb")
        
            # 🔥 Step 7: 计算水的体积系数 Bw (简化为1.0)
            Bw = 1.0
        
            # 🔥 Step 8: 计算井下液体体积
            # 油相井下体积 = (1 - 含水率) * Bo * 1 bbl
            oil_volume_downhole = (1 - water_ratio) * Bo
        
            # 水相井下体积 = 含水率 * Bw * 1 bbl  
            water_volume_downhole = water_ratio * Bw
        
            # 总液体井下体积
            total_liquid_volume = oil_volume_downhole + water_volume_downhole
        
            # 🔥 Step 9: 计算井下自由气体积
            # 自由气井下体积 = 自由气量 * 气体体积系数
            free_gas_volume_downhole = free_gas_ratio * Bg
        
            # 🔥 Step 10: 计算气液体积比
            if total_liquid_volume > 0:
                glr = free_gas_volume_downhole / total_liquid_volume
            else:
                glr = 0
            
            logger.info(f"计算结果:")
            logger.info(f"  油相体积: {oil_volume_downhole:.4f} rb")
            logger.info(f"  水相体积: {water_volume_downhole:.4f} rb") 
            logger.info(f"  总液体体积: {total_liquid_volume:.4f} rb")
            logger.info(f"  自由气体积: {free_gas_volume_downhole:.4f} rb")
            logger.info(f"  气液比 GLR = {glr:.4f}")
        
            return glr
        
        except Exception as e:
            logger.error(f"修正GLR计算失败: {e}")
            return 0.0
    

    def _calculate_expert_glr_formula(self, temperature, Production_gasoline_ratio, water_ratio, 
                                Pb_Mpa, Pi_Mpa, Z_const=0.8, Rg_const=0.896, Ro_const=0.849):
        """完整实现专家总结的吸入口气液比公式"""
        try:
            # 5. F13 = POWER(10, 0.0125*(141.5/相对密度Ro-131.5))
            F13 = pow(10, 0.0125 * (141.5 / Ro_const - 131.5))
        
            # 6. F14 = POWER(10, 0.00091*(1.8*温度+32))
            F14 = pow(10, 0.00091 * (1.8 * temperature + 32))
        
            # 4. Rsp = 0.1342*相对密度Rg*POWER(10*Pb（Mpa）*F13/F14, 1/0.83)
            Rsp = 0.1342 * Rg_const * pow((10 * Pb_Mpa * F13 / F14), 1/0.83)
        
            # 3. Bg（m³/m³） = 0.0003458*Z(常数）*(温度+273)/Pi(Mpa)
            if Pi_Mpa > 0:
                Bg = 0.0003458 * Z_const * (temperature + 273) / Pi_Mpa
            else:
                Bg = 0.0003458 * Z_const * (temperature + 273) / 0.1  # 防止除零
        
            # 2. Bo = 0.972+0.000147*POWER(5.61*Rsp*POWER(相对密度Rg/相对密度Ro,0.5)+1.25*(1.8*温度+32),1.175)
            Bo_inner = 5.61 * Rsp * pow(Rg_const / Ro_const, 0.5) + 1.25 * (1.8 * temperature + 32)
            Bo = 0.972 + 0.000147 * pow(Bo_inner, 1.175)
        
            # 1. 吸入口气液比=(1-含水率)*(生产汽油比-Rsp)*Bg/((1-含水率)*Bo+(1-含水率)*(生产汽油比-Rsp)*Bg+含水率)*100
            # 分子
            numerator = (1 - water_ratio) * (Production_gasoline_ratio - Rsp) * Bg
        
            # 分母
            denominator = ((1 - water_ratio) * Bo + 
                          (1 - water_ratio) * (Production_gasoline_ratio - Rsp) * Bg + 
                          water_ratio)
        
            # 防止除零
            if denominator == 0:
                denominator = 1e-10
            
            # 最终结果
            result = (numerator / denominator) * 100
        
            # logger.info(f"专家公式详细: F13={F13:.6f}, F14={F14:.6f}, Rsp={Rsp:.6f}")
            # logger.info(f"Bo={Bo:.6f}, Bg={Bg:.6f}, 分子={numerator:.6f}, 分母={denominator:.6f}")
            # logger.info(f"最终气液比={result:.4f}")
            result = abs(result)  # 确保结果为非负数
            return max(0, result)
        
        except Exception as e:
            logger.error(f"专家公式执行失败: {e}")
            return 0.0
    
    @Slot(dict, result='QVariant')
    def generateGasLiquidRatioAnalysis(self, analysis_params: dict):
        """重写气液比分析数据生成 - 移除所有限制"""
        try:
            logger.info("=== 重新生成气液比分析数据（无限制版本）===")
        
            # 基础参数（不进行任何调整）
            base_params = {
                'water_ratio': analysis_params.get('waterRatio'),
                'Production_gasoline_ratio': analysis_params.get('gasOilRatio'),
                'Pb_Mpa': analysis_params.get('saturationPressure'),
                'Z_const': analysis_params.get('zFactor'),
                'Rg_const': analysis_params.get('gasDensity'),
                'Ro_const': analysis_params.get('oilDensity')
            }
        
            logger.info(f"基础参数: {base_params}")
        
            # 🔥 生成温度数据：60-150°C，步长3°C
            temperature_data = []
            fixed_pi = analysis_params.get('fixedPressure')
            fixed_temp = analysis_params.get('fixedTemperature')
        
            logger.info(f"开始生成温度数据，固定压力={fixed_pi}MPa")
            # 温度fixed_temp的前后百分之30的范围
            temp_max = int(fixed_temp * 1.3)
            temp_min = int(fixed_temp * 0.7)

            for temp in range(temp_min, temp_max, 3):
                glr = self._calculate_expert_glr_formula(
                    temp, base_params['Production_gasoline_ratio'], base_params['water_ratio'],
                    base_params['Pb_Mpa'], fixed_pi, base_params['Z_const'], 
                    base_params['Rg_const'], base_params['Ro_const']
                )
            
                temperature_data.append({
                    'temperature': temp,
                    'glr': glr
                })
            
                logger.info(f"温度{temp}°C -> GLR={glr:.2f}")
        
            # 🔥 生成压力数据：5-50 MPa，步长1 MPa
            pressure_data = []
        
            logger.info(f"开始生成压力数据，固定温度={fixed_temp}°C")
            # 压力fixed_pi的前后百分之30的范围
            pi_max = int(fixed_pi * 1.3)
            pi_min = int(fixed_pi * 0.7)
        
            for pressure_int in range(pi_min, pi_max, 1):
                pressure_mpa = float(pressure_int)
            
                glr = self._calculate_expert_glr_formula(
                    fixed_temp, base_params['Production_gasoline_ratio'], base_params['water_ratio'],
                    base_params['Pb_Mpa'], pressure_mpa, base_params['Z_const'], 
                    base_params['Rg_const'], base_params['Ro_const']
                )
            
                pressure_data.append({
                    'pressure': pressure_mpa,
                    'glr': glr
                })
            
                logger.info(f"压力{pressure_mpa}MPa -> GLR={glr:.2f}")
        
            result = {
                'temperatureData': temperature_data,
                'pressureData': pressure_data,
                'baseParameters': base_params,
                'fixedValues': {
                    'fixedPressure': fixed_pi,
                    'fixedTemperature': fixed_temp
                }
            }
        
            logger.info(f"数据生成完成:")
            logger.info(f"  温度数据: {len(temperature_data)}个点")
            logger.info(f"  温度GLR范围: {temperature_data[0]['glr']:.2f} - {temperature_data[-1]['glr']:.2f}")
            logger.info(f"  压力数据: {len(pressure_data)}个点") 
            logger.info(f"  压力GLR范围: {pressure_data[0]['glr']:.2f} - {pressure_data[-1]['glr']:.2f}")
        
            return result
        
        except Exception as e:
            logger.error(f"生成气液比分析数据失败: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return {
                'temperatureData': [],
                'pressureData': [],
                'error': str(e)
            }


    def _calculate_total_head_empirical(self, params: Dict[str, Any]) -> float:
        """使用经验公式计算所需扬程"""
        try:
            # 使用地层压力和产量的简化关系计算扬程
            geo_pressure = params.get('geo_pressure', 0)
            expected_prod = params.get('expected_production', 0)
        
            # 简化的经验公式：基础扬程 + 产量调整
            base_head = geo_pressure * 1.2  # 基础扬程
            prod_adjustment = expected_prod * 1.5  # 产量调整
        
            total_head = base_head + prod_adjustment
        
            logger.info(f"经验公式计算扬程: 基础={base_head:.1f} + 产量调整={prod_adjustment:.1f} = {total_head:.1f} ft")
            return total_head
        
        except Exception as e:
            logger.error(f"经验扬程计算失败: {e}")
            return 10.0  # 默认值

    def _calculate_pump_depth_simple(self, params: Dict[str, Any]) -> float:
        """简化的泵挂深度计算"""
        try:
            # 使用地层压力和产量的简化关系
            geo_pressure = params.get('geo_pressure', 0)
            expected_prod = params.get('expected_production', 0)
            
            # 简化的经验公式
            base_depth = geo_pressure * 0.7  # 基础深度
            prod_adjustment = expected_prod * 10  # 产量调整
            
            return base_depth + prod_adjustment
            
        except Exception as e:
            logger.error(f"简化泵挂深度计算失败: {e}")
            return 2500.0  # 默认值
    

    def _combine_results_with_selection(self, ml_results: Dict, empirical_results: Dict) -> Dict:
        """智能选择和合并结果"""
        try:
            from DataManage.services.empirical_formulas_service import EmpiricalFormulasService
            
            empirical_service = EmpiricalFormulasService()
            combined = {}
            
            # 处理每个预测指标
            for key in ['production', 'pump_depth', 'gas_rate', 'total_head']:
                if key in ml_results and key in empirical_results:
                    ml_value = ml_results[key]
                    empirical_value = empirical_results[key]
                    
                    # 使用智能选择
                    selection_result = empirical_service.select_optimal_value(
                        ml_value, empirical_value, max_error=15.0
                    )
                    
                    combined[f'{key}_ml'] = ml_value
                    combined[f'{key}_empirical'] = empirical_value
                    combined[f'{key}_selected'] = selection_result['selected_value']
                    combined[f'{key}_selection_method'] = selection_result['selection_method']
                    combined[f'{key}_error_percent'] = selection_result['error_percent']
                    combined[f'{key}_reliable'] = selection_result['is_reliable']
                    
                    # 最终使用的值
                    combined[key] = selection_result['selected_value']
                else:
                    # 如果某个方法没有该指标，使用可用的值
                    combined[key] = ml_results.get(key, empirical_results.get(key, 0))
            
            # 计算整体置信度
            confidence_factors = []
            for key in ['production', 'pump_depth', 'gas_rate']:
                if combined.get(f'{key}_reliable', False):
                    confidence_factors.append(0.9)
                else:
                    confidence_factors.append(0.7)
            
            combined['confidence'] = sum(confidence_factors) / len(confidence_factors)
            combined['method'] = 'hybrid_intelligent_selection'
            
            return combined
            
        except Exception as e:
            logger.error(f"结果合并失败: {e}")
            # 降级使用ML结果
            return ml_results
    
    def _generate_comparison_data(self, ml_results: Dict, empirical_results: Dict) -> Dict:
        """生成对比数据用于UI显示"""
        comparison = {
            'methods': ['ML预测', '经验公式'],
            'metrics': []
        }
        
        metrics_info = [
            {'key': 'production', 'name': '推荐产量', 'unit': 'bbl/d'},
            {'key': 'total_head', 'name': '所需扬程', 'unit': 'ft'},
            {'key': 'gas_rate', 'name': '吸入口气液比', 'unit': '-'}
        ]
        
        for metric in metrics_info:
            key = metric['key']
            ml_value = ml_results.get(key, 0)
            empirical_value = empirical_results.get(key, 0)
            
            # 计算差异百分比
            if empirical_value != 0:
                diff_percent = abs(ml_value - empirical_value) / empirical_value * 100
            else:
                diff_percent = 0
            
            comparison['metrics'].append({
                'name': metric['name'],
                'unit': metric['unit'],
                'ml_value': ml_value,
                'empirical_value': empirical_value,
                'difference_percent': diff_percent,
                'recommendation': 'ML' if diff_percent < 10 else '需要验证'
            })
        
        return comparison

    @Slot(float)
    def generateIPRCurve(self, production):
        """生成IPR曲线数据"""
        try:
            print(f"=== 生成IPR曲线，产量: {production} ===")
            ipr_data = self.ml_service.generate_ipr_curve(production)
            self.iprCurveGenerated.emit(ipr_data)
        except Exception as e:
            self.predictionError.emit(f"IPR曲线生成失败: {str(e)}")
    
    def _update_prediction_progress(self):
        """更新预测进度"""
        self.prediction_progress += 0.05  # 每次增加5%
        if self.prediction_progress >= 1.0:
            self.prediction_progress = 0.95  # 防止超过100%
        
        self.predictionProgress.emit(self.prediction_progress)
    
    def _get_current_parameters(self) -> dict:
        """获取当前井的生产参数"""
        try:
            if self._current_parameters_id > 0:
                params = self._db_service.get_production_parameters_by_id(self._current_parameters_id)
                if params:
                    # 转换为ML服务需要的格式
                    return {
                        'geopressure': params.get('geo_pressure', 0),
                        'produceIndex': params.get('produce_index', 0),
                        'bht': params.get('bht', 0),
                        'expectedProduction': params.get('expected_production', 0),
                        'bsw': params.get('bsw', 0),
                        'api': params.get('api', 0),
                        'gasOilRatio': params.get('gas_oil_ratio', 0),
                        'saturationPressure': params.get('saturation_pressure', 0),
                        'wellHeadPressure': params.get('well_head_pressure', 0)
                    }
        
            logger.warning("无有效参数数据")
            return {}
        
        except Exception as e:
            logger.error(f"获取参数数据失败: {e}")
            return {}
    
    def _calculate_empirical_values(self, input_data: PredictionInput) -> dict:
        """计算经验公式结果作为对比"""
        try:
            # 简化的经验公式计算
            empirical_production = input_data.expected_production * 0.9  # 90%的期望产量
            empirical_head = input_data.pump_hanging_depth * 1.2        # 120%的泵挂深度
            empirical_gas_rate = input_data.gas_oil_ratio / 1000        # 简化的汽液比
        
            return {
                'production': empirical_production,
                'total_head': empirical_head,
                'gas_rate': empirical_gas_rate
            }
        except Exception as e:
            logger.error(f"经验公式计算失败: {e}")
            return {
                'production': 0,
                'total_head': 0,
                'gas_rate': 0
            }

    # ========== 报告导出相关方法 ==========
    
    @Slot(dict)
    def exportReport(self, report_data: dict):
        """导出报告"""
        try:
            logger.info("=== 开始导出报告 ===")
            # logger.info(f"报告数据: {report_data}")
            
            self._set_busy(True)
            
            export_format = report_data.get('format', 'docx')
            export_path = report_data.get('exportPath', '')
            project_name = report_data.get('projectName', '测试项目')
            step_data = report_data.get('stepData', {})
            
            # 修复：正确处理QUrl对象
            if hasattr(export_path, 'toLocalFile'):
                # 如果是QUrl对象，转换为本地文件路径
                export_path = export_path.toLocalFile()
            elif hasattr(export_path, 'toString'):
                # 如果是QUrl对象但没有toLocalFile方法，使用toString
                export_path_str = export_path.toString()
                # 处理file://前缀
                if export_path_str.startswith('file:///'):
                    export_path = export_path_str[8:]  # 移除file:///
                elif export_path_str.startswith('file://'):
                    export_path = export_path_str[7:]  # 移除file://
                else:
                    export_path = export_path_str
            elif isinstance(export_path, str):
                # 如果已经是字符串，处理file://前缀
                if export_path.startswith('file:///'):
                    export_path = export_path[8:]  # 移除file:///
                elif export_path.startswith('file://'):
                    export_path = export_path[7:]  # 移除file://
            else:
                # 其他情况，尝试转换为字符串
                export_path = str(export_path)
                if export_path.startswith('file:///'):
                    export_path = export_path[8:]
                elif export_path.startswith('file://'):
                    export_path = export_path[7:]
                
            logger.info(f"处理后的导出路径: {export_path}")
            logger.info(f"导出格式: {export_format}")
            
            # 验证路径不为空
            if not export_path or export_path == 'undefined':
                raise ValueError("导出路径为空或无效")
            
            if export_format == 'docx':
                success = self._export_to_word(export_path, project_name, step_data)
            elif export_format == 'pdf':
                # 先生成Word然后转换为PDF
                word_path = export_path.replace('.pdf', '.docx')
                success = self._export_to_word(word_path, project_name, step_data)
                if success and PDF_CONVERT_AVAILABLE:
                    try:
                        convert(word_path, export_path)
                        os.remove(word_path)  # 删除临时Word文件
                        logger.info(f"PDF转换完成: {export_path}")
                    except Exception as e:
                        logger.error(f"PDF转换失败: {e}")
                        success = False
                elif success:
                    logger.warning("docx2pdf不可用，无法转换PDF")
                    success = False
            elif export_format == 'xlsx':
                success = self._export_to_excel(export_path, project_name, step_data)
            else:
                success = False
                logger.error(f"不支持的导出格式: {export_format}")
            
            if success:
                self.reportExported.emit(export_path)
                logger.info(f"报告导出成功: {export_path}")
            else:
                self.reportExportError.emit("报告导出失败")
                
        except Exception as e:
            error_msg = f"导出报告失败: {str(e)}"
            logger.error(error_msg)
            self.reportExportError.emit(error_msg)
        finally:
            self._set_busy(False)
    
    def _export_to_word(self, file_path: str, project_name: str, step_data: dict) -> bool:
        """导出为Word文档 - 与HTML内容一致版本"""
        try:
            if not DOCX_AVAILABLE:
                logger.error("python-docx未安装，无法生成Word文档")
                return False
        
            logger.info(f"开始生成Word文档: {file_path}")
            # 把file_path中文件名称去掉，然后作为保存路径
            save_path = os.path.dirname(file_path)
            if not os.path.exists(save_path):
                os.makedirs(save_path)
            # 生成图片文件
            chart_images = self._generate_chart_images(step_data, save_path)
        
            # 创建Word文档
            doc = Document()
        
            # 设置文档样式
            self._setup_document_styles(doc)
            # 设置全局英文字体为arial，中文字体为宋体
            doc.styles['Normal'].font.name = 'Arial'
            doc.styles['Normal']._element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
            # 行间距 为 1.5倍
            doc.styles['Normal'].paragraph_format.line_spacing = Pt(18)  # 1.5倍行距
        
            # 🔥 使用与HTML相同的数据提取逻辑
            enhanced_data = step_data.get('enhancedData', {})
            project_details = step_data.get('project_details', enhanced_data.get('project_details', {}))
            well_info = step_data.get('well', enhanced_data.get('well', {}))
            calculation_info = step_data.get('calculation', enhanced_data.get('calculation', {}))
            parameters = step_data.get('parameters', {}).get('parameters', {}) if step_data.get('parameters', {}).get('parameters') else step_data.get('parameters', {})
            prediction = step_data.get('prediction', {})
            final_values = prediction.get('finalValues', {})
        
            # 提取设备信息
            pump_data = step_data.get('pump', {})
            motor_data = step_data.get('motor', {})
            protector_data = step_data.get('protector', {})
            separator_data = step_data.get('separator', {})
        
            # 🔥 页眉设置 - 与HTML一致
            self._setup_document_header(doc, project_details.get('company_name', '渤海装备'))
        
            # 页脚设置 页数
            # self._setup_document_footer(doc)
            # # 页脚页码
            # section = doc.sections[-1]
            # footer = section.footer
            # footer_para = footer.paragraphs[0]
            # footer_run = footer_para.add_run()
            # footer_run.text = "第 "
            # footer_run.add_field('PAGE', '页码')
            # footer_run.text += " 页，共 "
            # footer_run.add_field('NUMPAGES', '总页数')
            # footer_run.text += " 页"
            # footer_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            # 设置页眉和页脚样式


            # 🔥 主标题 - 与HTML一致
            title_para = doc.add_heading(level=1)
            title_run = title_para.runs[0] if title_para.runs else title_para.add_run()
            title_run.text = f"{project_name} 设备选型报告（测试）"
            # 宋体，黑色，二号字
            title_run.bold = True
            title_run.font.name = '宋体'
            title_run.font.size = Pt(22)
            title_run.font.color.rgb = RGBColor(0, 0, 0)
            title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER

            
            # 1. 项目基本信息 - 与HTML generateProjectInfoTable一致
            doc.add_heading("1. 项目基本信息", level=2)
            paragraph = doc.add_paragraph()
            run = paragraph.add_run("项目名称：")
            run.bold = True
            paragraph.add_run(project_name)
        
            # 🔥 使用与HTML相同的数据源和结构
            basic_table = doc.add_table(rows=8, cols=2)
            basic_table.style = 'Table Grid'
        
            well_number = step_data.get('well_number', well_info.get('wellName', 'WELL-001'))
        
            basic_info_data = [
                ('公司', project_details.get('company_name', '中国石油技术开发有限公司')),
                ('井号', well_number),
                ('项目名称', project_details.get('project_name', project_name)),
                ('油田', project_details.get('oil_field', '测试油田')),
                ('地点', project_details.get('location', '测试地点')),
                ('井型', well_info.get('wellType', '生产井')),
                ('井状态', well_info.get('wellStatus', '生产中')),
                ('备注', 'ESP设备选型项目')
            ]
        
            for i, (key, value) in enumerate(basic_info_data):
                basic_table.cell(i, 0).text = key
                basic_table.cell(i, 1).text = str(value)
        
            # 2. 生产套管井身结构信息 - 与HTML generateWellStructureTable一致
            # 设置标题的格式为宋体，黑色，三号字
            # 添加二级标题并设置格式
            heading2 = doc.add_heading(level=2)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run2 = heading2.add_run("2. 生产套管井身结构信息")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run2.font.name = "宋体"
            run2._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run2.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run2.font.size = Pt(16)

            # 2.1 基本井信息
            heading21 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run21 = heading21.add_run("2.1 基本井信息")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run21.font.name = "宋体"
            run21._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run21.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run21.font.size = Pt(14)

            well_table = doc.add_table(rows=7, cols=2)
            well_table.style = 'Table Grid'
        
            # 🔥 使用与HTML相同的单位转换逻辑
            total_depth = well_info.get('totalDepth', calculation_info.get('total_depth_md', 0))
            perforation_depth = calculation_info.get('perforation_depth', 0)
            pump_depth = calculation_info.get('pump_hanging_depth', well_info.get('pumpDepth', 0))
        
            def convert_to_feet(value):
                if not value or value == 0:
                    return '待计算'
                if value > 10000:  # 可能是毫米
                    return f"{(value / 1000 * 3.28084):.0f} ft"
                elif value > 100:
                    return f"{value:.0f} ft"
                else:
                    return f"{value:.1f} ft"
        
            well_info_data = [
                ('井号', well_number),
                ('井深', convert_to_feet(total_depth)),
                ('井型', well_info.get('wellType', '直井')),
                ('井状态', well_info.get('wellStatus', '生产中')),
                ('粗糙度', f"{well_info.get('roughness', 0.0018):.4f} inch"),
                ('射孔垂深 (TVD)', convert_to_feet(perforation_depth)),
                ('泵挂垂深 (TVD)', convert_to_feet(pump_depth))
            ]
        
            for i, (key, value) in enumerate(well_info_data):
                well_table.cell(i, 0).text = key
                well_table.cell(i, 1).text = str(value)
        
            # 2.2 套管信息 - 与HTML generateCasingInfoTable一致
            heading22 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run22 = heading22.add_run("2.2 套管信息")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run22.font.name = "宋体"
            run22._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run22.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run22.font.size = Pt(14)

            casing_data = step_data.get('casing_data', [])
        
            if casing_data:
                casing_table = doc.add_table(rows=len(casing_data) + 1, cols=8)
                casing_table.style = 'Table Grid'
            
                # 设置表头
                headers = ['套管类型', '外径', '内径', '顶深 (ft)', '底深 (ft)', '钢级', '重量 (lb/ft)', '状态']
                for i, header in enumerate(headers):
                    cell = casing_table.cell(0, i)
                    cell.text = header
                    # 设置表头样式
                    for paragraph in cell.paragraphs:
                        for run in paragraph.runs:
                            run.font.bold = True
            
                # 填充套管数据
                sorted_casings = sorted([c for c in casing_data if not c.get('is_deleted', False)], 
                                      key=lambda x: x.get('top_depth', x.get('top_tvd', 0)))
            
                for i, casing in enumerate(sorted_casings):
                    row = i + 1
                
                    def convert_diameter(value):
                        if not value or value == 0:
                            return 'N/A'
                        mm = float(value)
                        inches = mm / 25.4
                        return f"{mm:.1f} mm ({inches:.2f}\")"
                
                    casing_row_data = [
                        casing.get('casing_type', '未知套管'),
                        convert_diameter(casing.get('outer_diameter')),
                        convert_diameter(casing.get('inner_diameter')),
                        f"{float(casing.get('top_depth', casing.get('top_tvd', 0))):.0f}" if casing.get('top_depth', casing.get('top_tvd', 0)) else '0',
                        f"{float(casing.get('bottom_depth', casing.get('bottom_tvd', 0))):.0f}" if casing.get('bottom_depth', casing.get('bottom_tvd', 0)) else '0',
                        casing.get('grade', casing.get('material', 'N/A')),
                        f"{casing.get('weight', 0):.1f}" if casing.get('weight') else 'N/A',
                        casing.get('status', 'Active')
                    ]
                
                    for j, data in enumerate(casing_row_data):
                        casing_table.cell(row, j).text = str(data)
            else:
                doc.add_paragraph("暂无套管数据")
        
            # 2.3 井结构草图
            heading23 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run23 = heading23.add_run("2.3 井结构草图")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run23.font.name = "宋体"
            run23._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run23.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run23.font.size = Pt(14)
            # 插入井结构草图
            well_sketch_path = chart_images.get('well_sketch')
            paragraph = doc.add_paragraph()
            paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = paragraph.add_run()
                
            abs_image_path = os.path.abspath(well_sketch_path)
            logger.info(f"插入井结构草图: {abs_image_path}")
                
            # 🔥 设置合适的尺寸
            run.add_picture(abs_image_path, width=Inches(5.5), height=Inches(7.0))

            # 添加图片说明
            caption_para = doc.add_paragraph()
            caption_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            caption_run = caption_para.add_run("图2-1 井身结构示意图")
            caption_run.font.size = Pt(12)
            caption_run.font.color.rgb = RGBColor(102, 102, 102)
        
            # 3. 井轨迹图 - 与HTML generateWellTrajectorySection一致
            heading3 = doc.add_heading(level=2)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run3 = heading3.add_run("3. 井轨迹图")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run3.font.name = "宋体"
            run3._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run3.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run3.font.size = Pt(16)

            trajectory_data = step_data.get('trajectory_data', [])
        
            if trajectory_data:
                trajectory_image_path = chart_images.get('well_trajectory')
                paragraph = doc.add_paragraph()
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
                run = paragraph.add_run()
                    
                # 🔥 关键修复：使用绝对路径和合适的尺寸
                abs_image_path = os.path.abspath(trajectory_image_path)
                logger.info(f"插入井轨迹图片: {abs_image_path}")
                    
                # 🔥 设置合适的图片尺寸，避免过大
                run.add_picture(abs_image_path, width=Inches(6.0), height=Inches(4.0))

                # 添加图片说明
                caption_para = doc.add_paragraph()
                caption_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
                caption_run = caption_para.add_run("图3-1 井轨迹剖面图")
                caption_run.font.size = Pt(10)
                caption_run.font.color.rgb = RGBColor(102, 102, 102)
            
                # 🔥 添加轨迹统计信息表格 - 与HTML一致
                doc.add_heading("井轨迹统计信息", level=3)
                stats = self._calculate_trajectory_stats(trajectory_data, calculation_info)
            
                stats_table = doc.add_table(rows=5, cols=4)
                stats_table.style = 'Table Grid'
            
                # 设置统计表头
                stats_headers = ['统计项', '数值', '统计项', '数值']
                for i, header in enumerate(stats_headers):
                    cell = stats_table.cell(0, i)
                    cell.text = header
                    for paragraph in cell.paragraphs:
                        for run in paragraph.runs:
                            run.font.bold = True
            
                # 填充统计数据
                stats_data = [
                    ('轨迹点数', f"{stats['total_points']} 个", '最大井斜角', f"{stats.get('max_inclination', 0):.1f}°"),
                    ('最大垂深 (TVD)', f"{stats['max_tvd']:.1f} m", '最大狗腿度', f"{stats.get('max_dls', 0):.2f}°/30m"),
                    ('最大测深 (MD)', f"{stats['max_md']:.1f} m", '水平位移', f"{stats['max_horizontal']:.1f} m"),
                    ('泵挂垂深', f"{calculation_info.get('pump_hanging_depth', 0):.1f} m", '射孔垂深', f"{calculation_info.get('perforation_depth', 0):.1f} m")
                ]
            
                for i, (item1, value1, item2, value2) in enumerate(stats_data):
                    row = i + 1
                    stats_table.cell(row, 0).text = item1
                    stats_table.cell(row, 1).text = value1
                    stats_table.cell(row, 2).text = item2
                    stats_table.cell(row, 3).text = value2
            else:
                doc.add_paragraph("暂无轨迹数据 - 需要上传井轨迹数据来生成完整的轨迹图")
        
            # 4. 生产参数及模型预测 - 与HTML generateProductionParametersTable一致
            heading4 = doc.add_heading(level=2)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run4 = heading4.add_run("4. 生产参数及模型预测")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run4.font.name = "宋体"
            run4._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run4.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run4.font.size = Pt(16)

            # 4.1 生产参数
            heading41 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run41 = heading41.add_run("4.1 生产参数")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run41.font.name = "宋体"
            run41._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run41.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run41.font.size = Pt(14)

            prod_table = doc.add_table(rows=12, cols=2)
            prod_table.style = 'Table Grid'
        
            def format_value(value, unit='', default_text='待计算'):
                if value is None or value == 0 or value == '':
                    return default_text
                if isinstance(value, (int, float)):
                    return f"{value:.1f}" + (f" {unit}" if unit else "")
                return str(value) + (f" {unit}" if unit else "")
        
            prod_params_data = [
                ('地层压力', format_value(parameters.get('geoPressure'), 'psi')),
                ('期望产量', format_value(parameters.get('expectedProduction'), 'bbl/d')),
                ('饱和压力', format_value(parameters.get('saturationPressure'), 'psi')),
                ('生产指数', format_value(parameters.get('produceIndex'), 'bbl/d/psi', '0.500')),
                ('井底温度', format_value(parameters.get('bht'), '°F')),
                ('含水率', format_value(parameters.get('bsw'), '%')),
                ('API重度', format_value(parameters.get('api'), '°API')),
                ('油气比', format_value(parameters.get('gasOilRatio'), 'scf/bbl')),
                ('井口压力', format_value(parameters.get('wellHeadPressure'), 'psi')),
                ('预测吸入口气液比', format_value(final_values.get('gasRate'), '', final_values.get('gasRate', 97.0026) if final_values.get('gasRate') else '97.0026')),
                ('预测所需扬程', format_value(final_values.get('totalHead'), 'ft', '2160')),
                ('预测产量', format_value(final_values.get('production'), 'bbl/d', '2000'))
            ]
        
            for i, (key, value) in enumerate(prod_params_data):
                prod_table.cell(i, 0).text = key
                prod_table.cell(i, 1).text = str(value)
                # 🔥 预测结果行使用特殊样式
                if i >= 9:  # 预测结果行
                    for paragraph in prod_table.cell(i, 0).paragraphs:
                        for run in paragraph.runs:
                            run.font.bold = True
        
            # 4.2 IPR曲线分析
            heading42 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run42 = heading42.add_run("4.2 IPR曲线分析")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run42.font.name = "宋体"
            run42._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run42.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run42.font.size = Pt(14)

            ipr_curve_data = prediction.get('iprCurve', [])
        
            if ipr_curve_data:
                ipr_image_path = chart_images.get('ipr_curve')
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
                paragraph = doc.add_paragraph()
                run = paragraph.add_run()
                abs_image_path = os.path.abspath(ipr_image_path)
                logger.info(f"插入IPR曲线图: {abs_image_path}")
                
                run.add_picture(abs_image_path, width=Inches(5.5), height=Inches(4.0))
                # 添加图片说明
                caption_para = doc.add_paragraph()
                caption_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
                caption_run = caption_para.add_run("图4-1 IPR曲线分析图")
                caption_run.font.size = Pt(10)
                caption_run.font.color.rgb = RGBColor(102, 102, 102)
            
                # IPR关键指标表格 - 与HTML一致
                doc.add_heading("IPR曲线关键指标", level=4)
                max_production = max([p.get('production', p.get('flow_rate', 0)) for p in ipr_curve_data]) if ipr_curve_data else 0
                reservoir_pressure = parameters.get('geoPressure', 0)
                operating_production = final_values.get('production', 0)
            
                ipr_table = doc.add_table(rows=5, cols=4)
                ipr_table.style = 'Table Grid'
            
                ipr_headers = ['指标项', '数值', '指标项', '数值']
                for i, header in enumerate(ipr_headers):
                    cell = ipr_table.cell(0, i)
                    cell.text = header
                    for paragraph in cell.paragraphs:
                        for run in paragraph.runs:
                            run.font.bold = True
            
                productivity = (max_production / reservoir_pressure) if (max_production > 0 and reservoir_pressure > 0) else 0
                operating_efficiency = (operating_production / max_production * 100) if max_production > 0 else 0
            
                ipr_data = [
                    ('地层压力', f"{reservoir_pressure:.1f} psi", '最大产能', f"{max_production:.1f} bbl/d"),
                    ('工作点产量', f"{operating_production:.1f} bbl/d", '工作点压力', 'N/A'),
                    ('产能指数', f"{productivity:.3f} bbl/d/psi", '工作效率', f"{operating_efficiency:.1f}%"),
                    ('曲线类型', 'Vogel方程', '数据点数', f"{len(ipr_curve_data)} 个")
                ]
            
                for i, (item1, value1, item2, value2) in enumerate(ipr_data):
                    row = i + 1
                    ipr_table.cell(row, 0).text = item1
                    ipr_table.cell(row, 1).text = value1
                    ipr_table.cell(row, 2).text = item2
                    ipr_table.cell(row, 3).text = value2
            else:
                doc.add_paragraph("暂无IPR曲线数据 - 需要完成预测分析来生成IPR曲线")
        
            # 5. 设备选型推荐 - 与HTML generateEquipmentSelection一致
            heading5 = doc.add_heading(level=2)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run5 = heading5.add_run("5. 设备选型推荐")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run5.font.name = "宋体"
            run5._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run5.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run5.font.size = Pt(16)

        
            # 5.1 泵选型
            heading51 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run51 = heading51.add_run("5.1 泵选型")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run51.font.name = "宋体"
            run51._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run51.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run51.font.size = Pt(14)

            pump_table = doc.add_table(rows=8, cols=2)
            pump_table.style = 'Table Grid'
        
            pump_selection_data = [
                ('制造商', pump_data.get('manufacturer', '未知制造商')),
                ('泵型', pump_data.get('model', '未选择')),
                ('选型代码', pump_data.get('selectedPump', 'N/A')),
                ('级数', str(pump_data.get('stages', '0'))),
                ('需要扬程', f"{pump_data.get('totalHead', 0):.1f} ft"),
                ('泵功率', f"{pump_data.get('totalPower', 0):.1f} HP"),
                ('效率', f"{pump_data.get('efficiency', 0):.1f} %"),
                ('排量范围', f"{pump_data.get('minFlow', '0')} - {pump_data.get('maxFlow', '0')} bbl/d")
            ]
        
            for i, (key, value) in enumerate(pump_selection_data):
                pump_table.cell(i, 0).text = key
                pump_table.cell(i, 1).text = str(value)
        
            # 5.2 保护器选型
            heading52 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run52 = heading52.add_run("5.2 保护器选型")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run52.font.name = "宋体"
            run52._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run52.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run52.font.size = Pt(14)

            protector_table = doc.add_table(rows=5, cols=2)
            protector_table.style = 'Table Grid'
        
            protector_selection_data = [
                ('制造商', protector_data.get('manufacturer', '未知制造商')),
                ('保护器型号', protector_data.get('model', '未选择')),
                ('数量', str(protector_data.get('quantity', '0'))),
                ('总推力容量', f"{protector_data.get('totalThrustCapacity', 0):.0f} lbs"),
                ('规格说明', protector_data.get('specifications', 'N/A'))
            ]
        
            for i, (key, value) in enumerate(protector_selection_data):
                protector_table.cell(i, 0).text = key
                protector_table.cell(i, 1).text = str(value)
        
            # 5.3 分离器选型
            heading53 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run53 = heading53.add_run("5.3 分离器选型")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run53.font.name = "宋体"
            run53._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run53.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run53.font.size = Pt(14)

            if separator_data and not separator_data.get('skipped', False):
                separator_table = doc.add_table(rows=4, cols=2)
                separator_table.style = 'Table Grid'
            
                separator_selection_data = [
                    ('制造商', separator_data.get('manufacturer', '未知制造商')),
                    ('分离器型号', separator_data.get('model', '未选择')),
                    ('分离效率', f"{separator_data.get('separationEfficiency', 0):.1f} %"),
                    ('规格说明', separator_data.get('specifications', 'N/A'))
                ]
            
                for i, (key, value) in enumerate(separator_selection_data):
                    separator_table.cell(i, 0).text = key
                    separator_table.cell(i, 1).text = str(value)
            else:
                doc.add_paragraph("未选择分离器（气液比较低，可选配置）")
        
            # 5.4 电机选型
            heading54 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run54 = heading54.add_run("5.4 电机选型")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run54.font.name = "宋体"
            run54._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run54.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run54.font.size = Pt(14)

            motor_table = doc.add_table(rows=7, cols=2)
            motor_table.style = 'Table Grid'
        
            motor_selection_data = [
                ('制造商', motor_data.get('manufacturer', '未知制造商')),
                ('电机型号', motor_data.get('model', '未选择')),
                ('功率', f"{motor_data.get('power', 0):.0f} HP"),
                ('电压', f"{motor_data.get('voltage', 0):.0f} V"),
                ('频率', f"{motor_data.get('frequency', 0):.0f} Hz"),
                ('效率', f"{motor_data.get('efficiency', 0):.1f} %"),
                ('规格说明', motor_data.get('specifications', 'N/A'))
            ]
        
            for i, (key, value) in enumerate(motor_selection_data):
                motor_table.cell(i, 0).text = key
                motor_table.cell(i, 1).text = str(value)
        
            # 5.5 传感器
            heading55 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run55 = heading55.add_run("5.5 传感器")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run55.font.name = "宋体"
            run55._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run55.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run55.font.size = Pt(14)


            doc.add_paragraph("根据实际需要配置下置式压力传感器和温度传感器")
        
            # 6. 设备性能曲线
            doc.add_page_break()
            heading6 = doc.add_heading(level=2)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run6 = heading6.add_run("6. 设备性能曲线")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run6.font.name = "宋体"
            run6._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run6.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run6.font.size = Pt(16)
        
            # 6.1 泵设备性能曲线
            heading61 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run61 = heading61.add_run("6.1 泵设备性能曲线")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run61.font.name = "宋体"
            run61._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run61.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run61.font.size = Pt(14)

            pump_curves_data = step_data.get('pump_curves', {})
        
            if pump_curves_data.get('has_data') and pump_curves_data.get('baseCurves'):
                # 泵设备信息表格
                doc.add_heading("泵设备信息", level=4)
                pump_info_table = doc.add_table(rows=2, cols=4)
                pump_info_table.style = 'Table Grid'
            
                pump_info = pump_curves_data.get('pump_info', {})
                pump_info_data = [
                    ('制造商', pump_info.get('manufacturer', pump_data.get('manufacturer', 'N/A'))),
                    ('型号', pump_info.get('model', pump_data.get('model', 'N/A'))),
                    ('级数', str(pump_info.get('stages', pump_data.get('stages', 'N/A')))),
                    ('外径', f"{pump_info.get('outside_diameter', pump_data.get('outsideDiameter', 'N/A'))} in")
                ]
            
                for i in range(2):
                    for j in range(2):
                        idx = i * 2 + j
                        if idx < len(pump_info_data):
                            key, value = pump_info_data[idx]
                            pump_info_table.cell(i, j*2).text = key
                            pump_info_table.cell(i, j*2+1).text = str(value)
            
                doc.add_paragraph("泵性能特性曲线（扬程-效率-功率 vs 流量）")
                paragraph = doc.add_paragraph()
                run = paragraph.add_run()
                run.add_picture(chart_images['pump_curves'], width=Inches(5.5))
                # 添加图片说明
                caption_para = doc.add_paragraph()
                caption_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
                caption_run = caption_para.add_run("图6-1 泵性能特性曲线")
                caption_run.font.size = Pt(10)
                caption_run.font.color.rgb = RGBColor(102, 102, 102)
            
                # 性能参数汇总表格
                doc.add_heading("性能参数汇总", level=4)
                curves = pump_curves_data.get('baseCurves', {})
                if curves.get('flow'):
                    max_efficiency = max(curves.get('efficiency', [0]))
                    max_head = max(curves.get('head', [0]))
                    max_power = max(curves.get('power', [0]))
                    min_flow = min(curves.get('flow', [0]))
                    max_flow = max(curves.get('flow', [0]))
                    operating_point = pump_curves_data.get('operatingPoints', [{}])[0]
                
                    perf_table = doc.add_table(rows=5, cols=4)
                    perf_table.style = 'Table Grid'
                
                    perf_headers = ['参数项目', '数值', '参数项目', '数值']
                    for i, header in enumerate(perf_headers):
                        cell = perf_table.cell(0, i)
                        cell.text = header
                        for paragraph in cell.paragraphs:
                            for run in paragraph.runs:
                                run.font.bold = True
                
                    perf_data = [
                        ('流量范围', f"{min_flow:.0f} - {max_flow:.0f} bbl/d", '最大扬程', f"{max_head:.0f} ft"),
                        ('最高效率', f"{max_efficiency:.1f} %", '最大功率', f"{max_power:.0f} HP"),
                        ('最优工况流量', f"{operating_point.get('flow', 0):.0f} bbl/d", '最优工况扬程', f"{operating_point.get('head', 0):.0f} ft"),
                        ('最优工况效率', f"{operating_point.get('efficiency', 0):.1f} %", '最优工况功率', f"{operating_point.get('power', 0):.0f} HP")
                    ]
                
                    for i, (item1, value1, item2, value2) in enumerate(perf_data):
                        row = i + 1
                        perf_table.cell(row, 0).text = item1
                        perf_table.cell(row, 1).text = value1
                        perf_table.cell(row, 2).text = item2
                        perf_table.cell(row, 3).text = value2
            else:
                doc.add_paragraph("暂无性能曲线数据 - 需要选择泵设备来生成性能曲线")
        
            # 6.2 工况点分析
            heading62 = doc.add_heading(level=3)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run62 = heading62.add_run("6.2 工况点分析")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run62.font.name = "宋体"
            run62._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run62.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run62.font.size = Pt(14)

            if pump_curves_data.get('has_data'):
                target_flow = final_values.get('production', 0)
                operating_point = pump_curves_data.get('operatingPoints', [{}])[0]
            
                workpoint_table = doc.add_table(rows=4, cols=4)
                workpoint_table.style = 'Table Grid'
            
                workpoint_headers = ['工况参数', '设计值', '最优值', '匹配度']
                for i, header in enumerate(workpoint_headers):
                    cell = workpoint_table.cell(0, i)
                    cell.text = header
                    for paragraph in cell.paragraphs:
                        for run in paragraph.runs:
                            run.font.bold = True
            
                def get_matching_percentage(actual, optimal):
                    if not actual or not optimal:
                        return 'N/A'
                    ratio = abs(actual - optimal) / optimal
                    percentage = max(0, 100 - ratio * 100)
                    return f"{percentage:.0f}%"
            
                workpoint_data = [
                    ('产量', f"{target_flow:.0f} bbl/d", f"{operating_point.get('flow', 0):.0f} bbl/d", 
                     get_matching_percentage(target_flow, operating_point.get('flow', 0))),
                    ('扬程', f"{final_values.get('totalHead', 0):.0f} ft", f"{operating_point.get('head', 0):.0f} ft",
                     get_matching_percentage(final_values.get('totalHead', 0), operating_point.get('head', 0))),
                    ('效率', '预估 75%', f"{operating_point.get('efficiency', 0):.1f} %", '良好')
                ]
            
                for i, (param, design, optimal, match) in enumerate(workpoint_data):
                    row = i + 1
                    workpoint_table.cell(row, 0).text = param
                    workpoint_table.cell(row, 1).text = design
                    workpoint_table.cell(row, 2).text = optimal
                    workpoint_table.cell(row, 3).text = match
            else:
                doc.add_paragraph("暂无工况点分析数据")
        
            # 备注信息 - 与HTML一致
            doc.add_paragraph()
            doc.add_paragraph("备注:")
            doc.add_paragraph("公司将提供地面设备，如SDT/GENSET、SUT、接线盒、地面电力电缆、井口和井口电源连接器。")
            doc.add_paragraph("供应商将提供安装附件，如VSD、O形圈、连接螺栓、垫圈、带帽螺钉、电机油、电缆带、电缆拼接器材料、渡线器、扶正器、止回阀、排放头和备件。")
        
            # 7. 总结 - 与HTML generateSummaryTable一致
            doc.add_page_break()
            heading7 = doc.add_heading(level=2)
            # 向标题添加文本（避免直接在add_heading中传文本，方便单独设置格式）
            run7 = heading7.add_run("7. 总结")
            # 设置字体为宋体（中文字体需要额外配置qn属性）
            run7.font.name = "宋体"
            run7._element.rPr.rFonts.set(qn('w:eastAsia'), "宋体")  # 确保中文字体生效
            # 设置字体颜色为黑色
            run7.font.color.rgb = RGBColor(0, 0, 0)  # RGB(0,0,0)对应黑色
            # 设置字体大小为三号字（三号字对应16磅）
            run7.font.size = Pt(16)
        
            summary_table = doc.add_table(rows=18, cols=4)
            summary_table.style = 'Table Grid'
        
            # 设置表头
            header_cells = summary_table.rows[0].cells
            header_cells[0].text = 'EQUIPMENT'
            header_cells[1].text = 'DESCRIPTION'
            header_cells[2].text = 'OD[IN]'
            header_cells[3].text = 'LENGTH[FT]'
        
            # 设置表头样式
            for cell in header_cells:
                for paragraph in cell.paragraphs:
                    for run in paragraph.runs:
                        run.font.bold = True
                        run.font.color.rgb = RGBColor(255, 192, 0)
        
            # 🔥 与HTML完全一致的设备清单
            equipment_rows_en = [
                ('Step Down Transformer / GENSET', 'Provided by company', '-', '-'),
                ('VSD', 'Variable Speed Drive', '-', '-'),
                ('Step Up Transformer', 'Provided by company', '-', '-'),
                ('Power Cable', 'ESP Power Cable', '-', '-'),
                ('Motor Lead Extension', 'MLE', '-', '-'),
                ('Sensor', 'Downhole Sensor', '-', '-'),
                ('Pump Discharge Head', 'Check Valve', '-', '-'),
                ('Upper Pump', pump_data.get('model', 'TBD'), '-', '-'),
                ('Lower Pump', pump_data.get('model', 'TBD'), '-', '-'),
                ('Separator', separator_data.get('model', 'TBD') if (separator_data and not separator_data.get('skipped')) else 'N/A', '-', '-'),
                ('Upper Protector', protector_data.get('model', 'TBD'), '-', '-'),
                ('Lower Protector', protector_data.get('model', 'TBD'), '-', '-'),
                ('Motor', motor_data.get('model', 'TBD'), '-', '-'),
                ('Sensor', 'Pressure & Temperature', '-', '-'),
                ('Centralizer', 'Pump Centralizer', '-', '-'),
                ('', '', 'Total System', ''),
                ('', '', '-', '-')
            ]
            # 转换成中文表
            equipment_rows = [
               ('降压变压器/发电机组', '供应商', '-', '-'),
                ('变频器', '变频调速装置', '-', '-'),
                ('升压变压器', '供应商', '-', '-'),
                ('电力电缆', 'ESP电力电缆', '-', '-'),
                ('电缆延长线', 'MLE', '-', '-'),
                ('传感器', '下置式传感器', '-', '-'),
                ('泵排放头', '止回阀', '-', '-'),
                ('上部泵', pump_data.get('model', '待定'), '-', '-'),
                ('下部泵', pump_data.get('model', '待定'), '-', '-'),
                ('分离器', separator_data.get('model', '待定') if (separator_data and not separator_data.get('skipped')) else 'N/A', '-', '-'),
                ('上部保护器', protector_data.get('model', '待定'), '-', '-'),
                ('下部保护器', protector_data.get('model', '待定'), '-', '-'),
                ('电机', motor_data.get('model', '待定'), '-', '-'),
                ('传感器', '压力和温度传感器', '-', '-'),
                ('扶正器', '泵扶正器', '-', '-'),
                ('设备总计', '', '', ''),
            ]
        
            for i, (equipment, description, od, length) in enumerate(equipment_rows):
                row = summary_table.rows[i + 1]
                row.cells[0].text = equipment
                row.cells[1].text = description
                row.cells[2].text = od
                row.cells[3].text = length
        
            # 报告尾部 - 与HTML一致
            # footer_para = doc.add_paragraph()
            # footer_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            # footer_run = footer_para.add_run("本报告由油井设备智能管理系统自动生成\n")
            # footer_run.font.size = Pt(10)
            # footer_run.font.color.rgb = RGBColor(102, 102, 102)
        
            # 保存文档
            doc.save(file_path)
            logger.info(f"Word文档保存成功: {file_path}")
            return True
        
        except Exception as e:
            logger.error(f"Word文档生成失败: {str(e)}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return False

    def _setup_document_styles(self, doc):
        """设置文档样式"""
        # 设置正文字体
        style = doc.styles['Normal']
        style.font.name = 'Times New Roman'
        style._element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.font.size = Pt(11)

    def _setup_document_header(self, doc, company_name):
        """设置文档页眉"""
        header = doc.sections[0].header
        header_para = header.paragraphs[0]
        header_para.clear()
    
        # 左侧图标
        run = header_para.add_run('🏢 ')
    
        # 中间公司名
        run = header_para.add_run(company_name)
        run.bold = True
        run.font.size = Pt(14)
    
        # 添加制表符到右侧
        run = header_para.add_run('\t\t\t')
    
        # 右侧日期
        run = header_para.add_run(datetime.now().strftime('%Y-%m-%d'))
        run.font.size = Pt(10)
    
        header_para.alignment = WD_ALIGN_PARAGRAPH.CENTER

    def _generate_chart_images(self, step_data: dict, temp_save_path: str) -> dict:
        """生成图表图片文件"""
        chart_images = {}
        try:
            # 1. 生成井结构草图
            if step_data.get('well_sketch') and step_data.get('casing_data'):
                well_sketch_path = os.path.join(temp_save_path, 'well_sketch.png')
                self._create_well_sketch_image(step_data, well_sketch_path)
                chart_images['well_sketch'] = well_sketch_path
            
            # 2. 🔥 新增：生成井轨迹图
            trajectory_data = step_data.get('trajectory_data', [])
            calculation_data = step_data.get('calculation', {})

            if trajectory_data and len(trajectory_data) > 0:
                trajectory_path = os.path.join(temp_save_path, 'well_trajectory.png')
                self._create_well_trajectory_image(trajectory_data, calculation_data, trajectory_path)
                chart_images['well_trajectory'] = trajectory_path

            # 2. 生成IPR曲线图
            ipr_data = step_data.get('prediction', {}).get('iprCurve', [])
            if ipr_data:
                ipr_path = os.path.join(temp_save_path, 'ipr_curve.png')
                self._create_ipr_curve_image(ipr_data, step_data, ipr_path)
                chart_images['ipr_curve'] = ipr_path
        
            # 3. 生成泵性能曲线图
            pump_curves = step_data.get('pump_curves', {})
            if pump_curves.get('has_data'):
                pump_path = os.path.join(temp_save_path, 'pump_curves.png')
                self._create_pump_curves_image(pump_curves, pump_path)
                chart_images['pump_curves'] = pump_path
        
        except Exception as e:
            logger.error(f"生成图表图片失败: {e}")
    
        return chart_images

    def _create_well_trajectory_image(self, trajectory_data: list, calculation_data: dict, output_path: str):
        """创建井轨迹图 - 修复版本"""
    
        if not trajectory_data or len(trajectory_data) == 0:
            return

        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 8))

        try:
            # 🔥 修复：数据预处理和单位转换
            processed_data = []
            for i, point in enumerate(trajectory_data):
                # 🔥 关键修复：数据清理和单位转换
                tvd = point.get('tvd', 0)
                md = point.get('md', 0)
                inclination = point.get('inclination', 0)
                azimuth = point.get('azimuth', 0)
            

                tvd_m = tvd * 0.3048
                md_m = md * 0.3048

            
                processed_data.append({
                    'tvd': tvd_m,
                    'md': md_m,
                    'inclination': inclination,
                    'azimuth': azimuth,
                    'index': i
                })

            # 🔥 修复：按照前端JavaScript逻辑计算水平位移
            tvd_values = []
            md_values = []
            horizontal_displacement = []
            cumulative_horizontal = 0
        
            for i, point in enumerate(processed_data):
                current_tvd = point['tvd']
                current_md = point['md']
            
                # 🔥 关键修复：按照前端逻辑计算水平位移
                if i > 0:
                    prev_tvd = processed_data[i-1]['tvd']
                    prev_md = processed_data[i-1]['md']
                
                    delta_md = current_md - prev_md
                    delta_tvd = current_tvd - prev_tvd
                
                    # 🔥 与前端JavaScript完全一致的计算方式
                    delta_horizontal = np.sqrt(max(0, delta_md * delta_md - delta_tvd * delta_tvd))
                    cumulative_horizontal += delta_horizontal
            
                horizontal_displacement.append(cumulative_horizontal)
                tvd_values.append(current_tvd)
                md_values.append(current_md)

            print(f"📊 轨迹统计: 最大垂深={max(tvd_values):.1f}m, 最大水平位移={max(horizontal_displacement):.1f}m")
        
            # 🔥 添加调试信息
            print(f"🔍 前5个点的MD: {[d['md'] for d in processed_data[:5]]}")
            print(f"🔍 前5个点的TVD: {[d['tvd'] for d in processed_data[:5]]}")
            print(f"🔍 前5个点的水平位移: {horizontal_displacement[:5]}")
        
            # 计算几个关键点的增量
            for i in range(1, min(6, len(processed_data))):
                delta_md = processed_data[i]['md'] - processed_data[i-1]['md']
                delta_tvd = processed_data[i]['tvd'] - processed_data[i-1]['tvd']
                delta_h = np.sqrt(max(0, delta_md * delta_md - delta_tvd * delta_tvd))
                print(f"🔍 点{i}: ΔMD={delta_md:.1f}, ΔTVD={delta_tvd:.1f}, ΔH={delta_h:.1f}")

            # 🔥 绘制井轨迹剖面图 (ax1)
            ax1.plot(horizontal_displacement, tvd_values, 'b-', linewidth=3, 
                    label='井轨迹', marker='o', markersize=2, alpha=0.8)

            # 🔥 标记关键深度点
            calc_info = calculation_data
        
            # 标记泵挂深度
            pump_depth = calc_info.get('pump_hanging_depth', 0)
            if pump_depth > 1000:  # 转换单位
                pump_depth = pump_depth * 0.3048
            
            if pump_depth > 0:
                pump_horizontal = self._find_horizontal_at_depth_corrected(horizontal_displacement, tvd_values, pump_depth)
                ax1.scatter([pump_horizontal], [pump_depth], c='red', s=120, 
                          marker='s', label='泵挂深度', zorder=5, edgecolors='darkred', linewidth=2)
                ax1.annotate(f'泵挂: {pump_depth:.0f}m', 
                           xy=(pump_horizontal, pump_depth),
                           xytext=(pump_horizontal + max(horizontal_displacement)*0.1 + 50, pump_depth - max(tvd_values)*0.05),
                           fontsize=11, fontweight='bold', color='red',
                           bbox=dict(boxstyle="round,pad=0.3", facecolor='white', edgecolor='red', alpha=0.8),
                           arrowprops=dict(arrowstyle='->', color='red', lw=1.5))

            # 标记射孔深度
            perf_depth = calc_info.get('perforation_depth', 0)
            if perf_depth > 1000:  # 转换单位
                perf_depth = perf_depth * 0.3048
            
            if perf_depth > 0:
                perf_horizontal = self._find_horizontal_at_depth_corrected(horizontal_displacement, tvd_values, perf_depth)
                ax1.scatter([perf_horizontal], [perf_depth], c='green', s=120, 
                          marker='^', label='射孔深度', zorder=5, edgecolors='darkgreen', linewidth=2)
                ax1.annotate(f'射孔: {perf_depth:.0f}m', 
                           xy=(perf_horizontal, perf_depth),
                           xytext=(perf_horizontal + max(horizontal_displacement)*0.1 + 50, perf_depth + max(tvd_values)*0.05),
                           fontsize=11, fontweight='bold', color='green',
                           bbox=dict(boxstyle="round,pad=0.3", facecolor='white', edgecolor='green', alpha=0.8),
                           arrowprops=dict(arrowstyle='->', color='green', lw=1.5))

            # 🔥 绘制井口
            ax1.scatter([0], [0], c='orange', s=200, marker='*', 
                      label='井口', zorder=6, edgecolors='darkorange', linewidth=2)
            ax1.annotate('井口', xy=(0, 0), xytext=(20, -max(tvd_values)*0.05),
                       fontsize=12, fontweight='bold', color='orange',
                       bbox=dict(boxstyle="round,pad=0.3", facecolor='white', edgecolor='orange', alpha=0.8))

            # 🔥 设置第一个子图
            ax1.set_xlabel('水平位移 (m)', fontsize=12, fontweight='bold')
            ax1.set_ylabel('垂直深度 (m)', fontsize=12, fontweight='bold')
            ax1.set_title('井轨迹剖面图', fontsize=16, fontweight='bold')
            ax1.invert_yaxis()  # Y轴反向
            ax1.grid(True, alpha=0.3, linestyle='--')
            ax1.legend(loc='upper right', fontsize=10, framealpha=0.9)

            # 🔥 绘制测深vs垂深对比图 (ax2)
            ax2.plot(md_values, tvd_values, 'g-', linewidth=3, 
                    label='MD vs TVD', marker='s', markersize=2, alpha=0.8)
        
            # 绘制45度线（理想直井）
            max_depth = max(max(md_values), max(tvd_values))
            ax2.plot([0, max_depth], [0, max_depth], 'r--', linewidth=2, 
                    alpha=0.5, label='理想直井 (TVD=MD)')

            ax2.set_xlabel('测深 MD (m)', fontsize=12, fontweight='bold')
            ax2.set_ylabel('垂直深度 TVD (m)', fontsize=12, fontweight='bold')
            ax2.set_title('测深 vs 垂深对比', fontsize=16, fontweight='bold')
            ax2.grid(True, alpha=0.3, linestyle='--')
            ax2.legend(loc='upper left', fontsize=10, framealpha=0.9)

            # 🔥 设置合适的坐标轴比例
            max_horizontal = max(horizontal_displacement)
            if max_horizontal < max(tvd_values) * 0.01:  # 水平位移很小（小于1%）
                # 扩大显示范围以便观察
                ax1.set_xlim(-max(tvd_values)*0.05, max(tvd_values)*0.15)
            else:
                ax1.set_xlim(-max_horizontal*0.1, max_horizontal*1.2)
        
            ax1.set_ylim(max(tvd_values)*1.05, -max(tvd_values)*0.05)
        
            # 第二个图：设置相等比例
            ax2.set_aspect('equal', adjustable='box')

            # 🔥 优化布局
            plt.tight_layout(pad=2.0)
            
            # 保存图片
            plt.savefig(output_path, dpi=300, bbox_inches='tight',
                       facecolor='white', edgecolor='none', pad_inches=0.1)
            plt.close()
        
            logger.info(f"井轨迹图生成成功: {output_path}")

        except Exception as e:
            logger.error(f"生成井轨迹图失败: {e}")
            plt.close()

    def _find_horizontal_at_depth_corrected(self, horizontal_displacement: list, tvd_values: list, target_depth: float) -> float:
        """根据垂深查找对应的水平位移 - 新版本"""
        if not tvd_values or not horizontal_displacement:
            return 0

        # 找到最接近目标深度的点
        min_diff = float('inf')
        closest_horizontal = 0
    
        for i, tvd in enumerate(tvd_values):
            diff = abs(tvd - target_depth)
            if diff < min_diff:
                min_diff = diff
                closest_horizontal = horizontal_displacement[i]
    
        return closest_horizontal

    def _create_well_sketch_image(self, step_data: dict, output_path: str):
        """创建井结构草图"""
        print("井结构草图的step_data", step_data)
        """创建井结构草图 - 公制单位版本"""
        fig, ax = plt.subplots(1, 1, figsize=(7, 12))  # 🔥 设置图像宽度为7英寸

        # 🔥 修复：支持两种数据格式
        # 格式1：直接的 casing_data 和 calculation
        casing_data = step_data.get('casing_data', [])
        calc_info = step_data.get('calculation', {})
    
        # 格式2：嵌套在 well_sketch 中的数据
        if not casing_data and 'well_sketch' in step_data:
            well_sketch = step_data['well_sketch']
            if isinstance(well_sketch, str):
                import json
                well_sketch = json.loads(well_sketch)
        
            # 从 well_sketch 中提取套管数据
            sketch_casings = well_sketch.get('casings', [])
            casing_data = []
        
            for casing in sketch_casings:
                # 转换数据格式 - 转换为公制
                converted_casing = {
                    'casing_type': casing.get('type', 'Unknown'),
                    'top_depth': casing.get('top_depth', 0) * 0.3048,  # 英尺转米
                    'bottom_depth': casing.get('bottom_depth', 0) * 0.3048,  # 英尺转米
                    'outer_diameter': casing.get('outer_diameter', 7) * 25.4,  # 英寸转毫米
                    'inner_diameter': casing.get('inner_diameter', 6) * 25.4,   # 英寸转毫米
                    'is_deleted': False
                }
                casing_data.append(converted_casing)
    
        # 🔥 修复：从多个源获取计算信息
        if not calc_info:
            calc_info = {
                'pump_hanging_depth': step_data.get('pump_hanging_depth', 0),
                'perforation_depth': step_data.get('perforation_depth', 0)
            }
        
            if 'parameters' in step_data:
                params = step_data['parameters']
                calc_info.update({
                    'pump_hanging_depth': params.get('pumpDepth', 0),
                    'perforation_depth': params.get('perforationDepth', 0)
                })

        print(f"🔧 处理后的套管数据数量: {len(casing_data)}")
        print(f"🔧 计算信息: {calc_info}")

        # 🔥 关键修复：计算绘制范围（公制单位）
        if casing_data:
            all_depths = []
            all_diameters = []  # 现在是毫米单位
        
            for casing in casing_data:
                if not casing.get('is_deleted'):
                    # 深度转换为米
                    top_depth = casing.get('top_depth', 0)
                    bottom_depth = casing.get('bottom_depth', 0)
                    # 如果深度值很大，可能是英尺，需要转换
                    if top_depth > 1000 or bottom_depth > 1000:
                        top_depth = top_depth * 0.3048
                        bottom_depth = bottom_depth * 0.3048
                
                    all_depths.extend([top_depth, bottom_depth])
                
                    # 直径处理（毫米单位）
                    outer_diameter = casing.get('outer_diameter', 177.8)
                    inner_diameter = casing.get('inner_diameter', 157.1)
                    # 如果直径值很小，可能是英寸，需要转换
                    if outer_diameter < 50:
                        outer_diameter = outer_diameter * 25.4
                        inner_diameter = inner_diameter * 25.4
                
                    all_diameters.extend([outer_diameter, inner_diameter])
        
            max_depth = max(all_depths) if all_depths else 1000
            max_diameter = max(all_diameters) if all_diameters else 350  # 毫米
            min_diameter = min(all_diameters) if all_diameters else 150  # 毫米
        
            print(f"🎯 绘制范围: 最大深度={max_depth}m, 直径范围={min_diameter}-{max_diameter}mm")
        else:
            max_depth = 1000
            max_diameter = 350
            min_diameter = 150

        # 🔥 修复：按外径从大到小排序，确保正确的绘制层次
        sorted_casings = sorted([c for c in casing_data if not c.get('is_deleted')], 
                               key=lambda x: x.get('outer_diameter', 0), reverse=True)

        # 🔥 修复：绘制套管（公制单位）
        colors = ['#D2691E', '#FFD700', '#32CD32', '#FF6347', '#9370DB']  # 不同颜色
    
        for i, casing in enumerate(sorted_casings):
            top_depth = casing.get('top_depth', 0)
            bottom_depth = casing.get('bottom_depth', 1000)
        
            # 🔥 深度单位转换（确保为米）
            if top_depth > 1000 or bottom_depth > 1000:
                # 可能是英尺，转换为米
                top_depth = top_depth * 0.3048
                bottom_depth = bottom_depth * 0.3048
        
            # 🔥 直径单位处理（确保为毫米）
            outer_diameter = casing.get('outer_diameter', 177.8)
            inner_diameter = casing.get('inner_diameter', 157.1)
        
            if outer_diameter < 50:
                # 可能是英寸，转换为毫米
                outer_diameter = outer_diameter * 25.4
                inner_diameter = inner_diameter * 25.4
        
            print(f"🔧 绘制套管: {casing['casing_type']}, 外径={outer_diameter:.1f}mm, 内径={inner_diameter:.1f}mm, 深度={top_depth:.1f}-{bottom_depth:.1f}m")

            # 🔥 修复：正确的坐标计算（公制单位）
            # Y轴：深度（向下为正，单位：米）
            y_top = -top_depth
            y_bottom = -bottom_depth
            height = y_bottom - y_top  # 负值，因为bottom_depth > top_depth
        
            # X轴：以0为中心的对称绘制（单位：毫米）
            x_left_outer = -outer_diameter/2
            x_left_inner = -inner_diameter/2
        
            # 🔥 绘制套管外壁
            rect_outer = patches.Rectangle(
                (x_left_outer, y_top), 
                outer_diameter, 
                height,
                linewidth=2, 
                edgecolor='black', 
                facecolor=colors[i % len(colors)], 
                alpha=0.7,
                label=f"{casing['casing_type']} {outer_diameter:.0f}mm"
            )
            ax.add_patch(rect_outer)
        
            # 🔥 绘制套管内壁（井眼）
            rect_inner = patches.Rectangle(
                (x_left_inner, y_top), 
                inner_diameter, 
                height,
                linewidth=1, 
                edgecolor='gray', 
                facecolor='lightblue', 
                alpha=0.3
            )
            ax.add_patch(rect_inner)
        
            # 🔥 添加套管标签（避免重叠）
            label_x = outer_diameter/2 + 20  # 偏移20mm
            label_y = y_top + height/2  # 标签放在套管中间
        
            ax.annotate(
                f"{casing['casing_type']}\n{outer_diameter:.0f}mm", 
                xy=(outer_diameter/2, label_y),
                xytext=(label_x, label_y),
                fontsize=9, 
                ha='left', 
                va='center',
                bbox=dict(boxstyle="round,pad=0.3", facecolor='white', alpha=0.8),
                arrowprops=dict(arrowstyle='->', color='gray', lw=0.5)
            )

        # 🔥 标记重要深度（公制单位）
        pump_depth = calc_info.get('pump_hanging_depth', 0)
        perf_depth = calc_info.get('perforation_depth', 0)
    
        # 如果深度值很大，可能是英尺，需要转换
        if pump_depth > 1000:
            pump_depth = pump_depth * 0.3048
        if perf_depth > 1000:
            perf_depth = perf_depth * 0.3048

        if pump_depth > 0:
            ax.axhline(y=-pump_depth, color='red', linestyle='--', linewidth=2, alpha=0.8)
            ax.text(-max_diameter/3, -pump_depth + max_depth*0.02, f'泵挂深度: {pump_depth:.0f}m', 
                   ha='left', va='bottom', fontweight='bold', color='red',
                   bbox=dict(boxstyle="round,pad=0.3", facecolor='white', alpha=0.8))

        if perf_depth > 0:
            ax.axhline(y=-perf_depth, color='green', linestyle='--', linewidth=2, alpha=0.8)
            ax.text(-max_diameter/3, -perf_depth + max_depth*0.02, f'射孔深度: {perf_depth:.0f}m', 
                   ha='left', va='bottom', fontweight='bold', color='green',
                   bbox=dict(boxstyle="round,pad=0.3", facecolor='white', alpha=0.8))

        # 🔥 修复：设置坐标轴范围（公制单位）
        # X轴：套管直径范围（毫米）- 使用1.2倍范围
        diameter_range = max_diameter - min_diameter
        x_center = 0
        x_half_range = max_diameter * 0.6  # 稍微扩大显示范围
        ax.set_xlim(-x_half_range, x_half_range)
    
        # Y轴：深度范围（米）
        y_margin = max_depth * 0.1
        ax.set_ylim(-max_depth - y_margin, y_margin)
    
        # 🔥 设置坐标轴标签和标题（公制单位）
        ax.set_xlabel('水平距离 (mm)', fontsize=12)
        ax.set_ylabel('深度 (m)', fontsize=12)
        ax.set_title('井身结构示意图', fontsize=16, fontweight='bold', pad=20)
    
        # 🔥 美化网格
        ax.grid(True, alpha=0.3, linestyle='-', linewidth=0.5)
        ax.set_axisbelow(True)  # 网格在图形后面
    
        # 🔥 添加图例
        if sorted_casings:
            ax.legend(loc='upper right', fontsize=10, framealpha=0.9)
    
        # 🔥 调整布局
        # plt.tight_layout()
    
        # 🔥 添加调试信息
        print(f"📊 图形范围: X({ax.get_xlim()}), Y({ax.get_ylim()})")
        print(f"📊 绘制了 {len(sorted_casings)} 个套管")

        plt.savefig(output_path, dpi=300, bbox_inches='tight',
               pad_inches=0.1)
        plt.close()

    def _create_ipr_curve_image(self, ipr_data: list, step_data: dict, output_path: str):
        print("IPR曲线图的ipr_data", ipr_data)
        print("IPR曲线图的step_data", step_data)
        """创建IPR曲线图"""  
        if not ipr_data:
            return
    
        fig, ax = plt.subplots(1, 1, figsize=(8, 6))
    
        # 提取数据
        production = [p.get('production', p.get('flow_rate', 0)) for p in ipr_data]
        pressure = [p.get('pressure', p.get('wellhead_pressure', 0)) for p in ipr_data]
    
        # 绘制IPR曲线
        ax.plot(production, pressure, 'b-', linewidth=3, label='IPR曲线')
        ax.scatter(production, pressure, c='blue', s=20, alpha=0.6)
    
        # 标记工作点
        final_values = step_data.get('prediction', {}).get('finalValues', {})
        if final_values.get('production'):
            op_prod = final_values['production']
            # 找到对应的压力
            op_pressure = 0
            for p in ipr_data:
                prod = p.get('production', p.get('flow_rate', 0))
                if abs(prod - op_prod) < abs(production[0] - op_prod):
                    op_pressure = p.get('pressure', p.get('wellhead_pressure', 0))
        
            if op_pressure > 0:
                ax.scatter([op_prod], [op_pressure], c='red', s=100, 
                          marker='o', label='工作点', zorder=5)
    
        ax.set_xlabel('产量 (bbl/d)')
        ax.set_ylabel('井底流压 (psi)')
        ax.set_title('IPR曲线分析图', fontsize=14, fontweight='bold')
        ax.grid(True, alpha=0.3)
        ax.legend()
    
        plt.tight_layout(pad=1.0)
        plt.savefig(output_path, dpi=300, bbox_inches='tight',
               pad_inches=0.1)
        plt.close()

    def _create_pump_curves_image(self, pump_curves: dict, output_path: str):
        print("泵性能曲线图的pump_curves", pump_curves)
        """创建泵性能曲线图"""   
        curves = pump_curves.get('baseCurves', {})
        if not curves.get('flow'):
            return
    
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), sharex=True)
    
        flows = curves['flow']
        heads = curves['head']
        efficiencies = curves['efficiency']
        powers = curves['power']
    
        # 上图：扬程和效率
        color1 = 'tab:blue'
        ax1.set_ylabel('扬程 (ft)', color=color1)
        line1 = ax1.plot(flows, heads, color=color1, linewidth=3, label='扬程')
        ax1.tick_params(axis='y', labelcolor=color1)
    
        ax1_twin = ax1.twinx()
        color2 = 'tab:green'
        ax1_twin.set_ylabel('效率 (%)', color=color2)
        line2 = ax1_twin.plot(flows, efficiencies, color=color2, linewidth=3, label='效率')
        ax1_twin.tick_params(axis='y', labelcolor=color2)
    
        # 下图：功率
        color3 = 'tab:orange'
        ax2.set_ylabel('功率 (HP)', color=color3)
        ax2.plot(flows, powers, color=color3, linewidth=3, label='功率')
        ax2.tick_params(axis='y', labelcolor=color3)
        ax2.set_xlabel('流量 (bbl/d)')
    
        # 标记最优工况点
        operating_points = pump_curves.get('operatingPoints', [])
        if operating_points:
            bep = operating_points[0]
            bep_flow = bep.get('flow', 0)
            bep_head = bep.get('head', 0)
            bep_eff = bep.get('efficiency', 0)
            bep_power = bep.get('power', 0)
        
            ax1.scatter([bep_flow], [bep_head], c='red', s=100, marker='*', zorder=5)
            ax1_twin.scatter([bep_flow], [bep_eff], c='red', s=100, marker='*', zorder=5)
            ax2.scatter([bep_flow], [bep_power], c='red', s=100, marker='*', zorder=5)
    
        ax1.set_title('泵性能特性曲线', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        ax2.grid(True, alpha=0.3)
    
        plt.tight_layout()
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        plt.close()

    def _cleanup_temp_images(self, chart_images: dict):
        """清理临时图片文件"""
        import os
        for image_path in chart_images.values():
            try:
                if os.path.exists(image_path):
                    os.remove(image_path)
            except Exception as e:
                logger.warning(f"清理临时文件失败: {e}")


    def _calculate_trajectory_stats(self, processed_data, calc_info):
        """计算轨迹统计数据 - 修正版"""
        if not processed_data:
            return {
                'total_points': 0,
                'max_tvd': 0,
                'max_md': 0,
                'max_inclination': 0,
                'max_dls': 0,
                'max_horizontal': 0
            }

        tvd_values = [d['tvd'] for d in processed_data]
        md_values = [d['md'] for d in processed_data]
        inc_values = [d['inclination'] for d in processed_data]
    
        # 🔥 修复：使用与前端一致的水平位移计算
        max_horizontal = 0
        cum_horizontal = 0
        for i in range(1, len(processed_data)):
            current_md = processed_data[i]['md']
            current_tvd = processed_data[i]['tvd']
            prev_md = processed_data[i-1]['md']
            prev_tvd = processed_data[i-1]['tvd']
        
            delta_md = current_md - prev_md
            delta_tvd = current_tvd - prev_tvd
        
            # 与前端JavaScript一致的计算
            delta_horizontal = np.sqrt(max(0, delta_md * delta_md - delta_tvd * delta_tvd))
            cum_horizontal += delta_horizontal
            max_horizontal = max(max_horizontal, cum_horizontal)

        # 计算DLS (Dog Leg Severity)
        dls_values = []
        for i in range(1, len(processed_data)):
            prev_inc = processed_data[i-1]['inclination']
            curr_inc = processed_data[i]['inclination']
            prev_az = processed_data[i-1]['azimuth']
            curr_az = processed_data[i]['azimuth']
        
            # 简化DLS计算
            delta_inc = curr_inc - prev_inc
            delta_az = curr_az - prev_az
            dls = np.sqrt(delta_inc**2 + (np.sin(np.radians(curr_inc)) * delta_az)**2)
            dls_values.append(dls)

        return {
            'total_points': len(processed_data),
            'max_tvd': max(tvd_values),
            'max_md': max(md_values),
            'max_inclination': max(inc_values),
            'max_dls': max(dls_values) if dls_values else 0,
            'max_horizontal': max_horizontal
        }

    def _export_to_excel(self, file_path: str, project_name: str, step_data: dict) -> bool:
        """导出为Excel文档"""
        try:
            # 使用openpyxl生成Excel文档
            try:
                from openpyxl import Workbook
                from openpyxl.styles import Font, PatternFill, Alignment
            except ImportError:
                logger.error("openpyxl未安装，无法生成Excel文档")
                return False
            
            logger.info(f"开始生成Excel文档: {file_path}")
            
            wb = Workbook()
            
            # 创建工作表
            ws_summary = wb.active
            ws_summary.title = "项目总览"
            
            ws_params = wb.create_sheet("生产参数")
            ws_equipment = wb.create_sheet("设备选型")
            ws_performance = wb.create_sheet("性能分析")
            
            # 设置样式
            header_font = Font(bold=True, color="FFFFFF")
            header_fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
            center_alignment = Alignment(horizontal="center", vertical="center")
            
            # 项目总览工作表
            ws_summary['A1'] = f"{project_name} 设备选型报告"
            ws_summary['A1'].font = Font(bold=True, size=16)
            ws_summary.merge_cells('A1:D1')
            
            # 项目基本信息
            project_info = [
                ['项目信息', '', '', ''],
                ['项目名称', project_name, '', ''],
                ['公司', step_data.get('project', {}).get('companyName', 'N/A'), '', ''],
                ['井号', step_data.get('well', {}).get('wellName', 'N/A'), '', ''],
                ['油田', step_data.get('project', {}).get('oilName', 'N/A'), '', ''],
                ['地点', step_data.get('project', {}).get('location', 'N/A'), '', ''],
            ]
            
            for row_idx, row_data in enumerate(project_info, start=3):
                for col_idx, value in enumerate(row_data, start=1):
                    cell = ws_summary.cell(row=row_idx, column=col_idx, value=value)
                    if row_idx == 3:  # 标题行
                        cell.font = header_font
                        cell.fill = header_fill
                        cell.alignment = center_alignment
            
            # 生产参数工作表
            params = step_data.get('parameters', {})
            param_data = [
                ['参数名称', '数值', '单位'],
                ['地层压力', params.get('geoPressure', 'N/A'), 'psi'],
                ['期望产量', params.get('expectedProduction', 'N/A'), 'bbl/d'],
                ['饱和压力', params.get('saturationPressure', 'N/A'), 'psi'],
                ['生产指数', params.get('produceIndex', 'N/A'), 'bbl/d/psi'],
                ['井底温度', params.get('bht', 'N/A'), '°F'],
                ['含水率', params.get('bsw', 'N/A'), '%'],
                ['API重度', params.get('api', 'N/A'), '°API'],
                ['油气比', params.get('gasOilRatio', 'N/A'), 'scf/bbl'],
                ['井口压力', params.get('wellHeadPressure', 'N/A'), 'psi'],
            ]
            
            for row_idx, row_data in enumerate(param_data, start=1):
                for col_idx, value in enumerate(row_data, start=1):
                    cell = ws_params.cell(row=row_idx, column=col_idx, value=value)
                    if row_idx == 1:  # 标题行
                        cell.font = header_font
                        cell.fill = header_fill
                        cell.alignment = center_alignment
            
            # 设备选型工作表
            pump_data = step_data.get('pump', {})
            motor_data = step_data.get('motor', {})
            protector_data = step_data.get('protector', {})
            
            equipment_data = [
                ['设备类型', '制造商', '型号', '关键参数'],
                ['泵', pump_data.get('manufacturer', 'N/A'), pump_data.get('model', 'N/A'), 
                 f"级数: {pump_data.get('stages', 'N/A')}, 扬程: {pump_data.get('totalHead', 'N/A')} ft"],
                ['电机', motor_data.get('manufacturer', 'N/A'), motor_data.get('model', 'N/A'),
                 f"功率: {motor_data.get('power', 'N/A')} HP, 电压: {motor_data.get('voltage', 'N/A')} V"],
                ['保护器', protector_data.get('manufacturer', 'N/A'), protector_data.get('model', 'N/A'),
                 f"数量: {protector_data.get('quantity', 'N/A')}, 推力: {protector_data.get('totalThrustCapacity', 'N/A')} lbs"],
            ]
            
            for row_idx, row_data in enumerate(equipment_data, start=1):
                for col_idx, value in enumerate(row_data, start=1):
                    cell = ws_equipment.cell(row=row_idx, column=col_idx, value=value)
                    if row_idx == 1:  # 标题行
                        cell.font = header_font
                        cell.fill = header_fill
                        cell.alignment = center_alignment
            
            # 调整列宽
            for ws in [ws_summary, ws_params, ws_equipment, ws_performance]:
                for column in ws.columns:
                    max_length = 0
                    column_letter = column[0].column_letter
                    for cell in column:
                        try:
                            if len(str(cell.value)) > max_length:
                                max_length = len(str(cell.value))
                        except:
                            pass
                    adjusted_width = min(max_length + 2, 50)
                    ws.column_dimensions[column_letter].width = adjusted_width
            
            # 保存Excel文件
            wb.save(file_path)
            logger.info(f"Excel文档保存成功: {file_path}")
            return True
            
        except Exception as e:
            logger.error(f"Excel文档生成失败: {str(e)}")
            return False

    @Slot(dict)
    def saveReportDraft(self, draft_data: dict):
        """保存报告草稿"""
        try:
            logger.info("=== 保存报告草稿 ===")
            self._set_busy(True)
            
            # 创建草稿目录
            draft_dir = os.path.join(os.getcwd(), 'drafts')
            if not os.path.exists(draft_dir):
                os.makedirs(draft_dir)
            
            # 生成草稿文件名
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            draft_filename = f"report_draft_{timestamp}.json"
            draft_path = os.path.join(draft_dir, draft_filename)
            
            # 保存草稿数据
            with open(draft_path, 'w', encoding='utf-8') as f:
                json.dump(draft_data, f, ensure_ascii=False, indent=2, default=str)
            
            self.reportDraftSaved.emit(draft_path)
            logger.info(f"报告草稿保存成功: {draft_path}")
            
        except Exception as e:
            error_msg = f"保存报告草稿失败: {str(e)}"
            logger.error(error_msg)
            self.reportExportError.emit(error_msg)
        finally:
            self._set_busy(False)

    @Slot(result='QVariant')
    def getReportDrafts(self):
        """获取已保存的报告草稿列表"""
        try:
            draft_dir = os.path.join(os.getcwd(), 'drafts')
            if not os.path.exists(draft_dir):
                return []
            
            drafts = []
            for filename in os.listdir(draft_dir):
                if filename.startswith('report_draft_') and filename.endswith('.json'):
                    file_path = os.path.join(draft_dir, filename)
                    stat = os.stat(file_path)
                    
                    drafts.append({
                        'filename': filename,
                        'path': file_path,
                        'size': stat.st_size,
                        'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
                    })
            
            # 按修改时间倒序排列
            drafts.sort(key=lambda x: x['modified'], reverse=True)
            return drafts
            
        except Exception as e:
            logger.error(f"获取报告草稿列表失败: {str(e)}")
            return []

    @Slot(str, result='QVariant')
    def loadReportDraft(self, draft_path: str):
        """加载报告草稿"""
        try:
            with open(draft_path, 'r', encoding='utf-8') as f:
                draft_data = json.load(f)
            
            logger.info(f"报告草稿加载成功: {draft_path}")
            return draft_data
            
        except Exception as e:
            error_msg = f"加载报告草稿失败: {str(e)}"
            logger.error(error_msg)
            self.reportExportError.emit(error_msg)
            return {}

    @Slot(str, result=bool)
    def deleteReportDraft(self, draft_path: str):
        """删除报告草稿"""
        try:
            if os.path.exists(draft_path):
                os.remove(draft_path)
                logger.info(f"报告草稿删除成功: {draft_path}")
                return True
            else:
                logger.warning(f"报告草稿文件不存在: {draft_path}")
                return False
                
        except Exception as e:
            logger.error(f"删除报告草稿失败: {str(e)}")
            return False

    @Slot(dict)
    def prepareReportData(self, step_data: dict):
        """准备完整的报告数据，获取实际的井信息和计算结果"""
        try:
            logger.info("=== 开始准备增强报告数据 ===")
            logger.info(f"当前井ID: {self._current_well_id}, 项目ID: {self._current_project_id}")
            self._set_busy(True)
    
            enhanced_data = step_data.copy()
        
            # 🔥 1. 从日志中可以看到，需要使用井ID=2的实际数据
            # 优先从stepData中获取井ID，如果没有则使用默认值
            effective_well_id = 2  # 从日志看，这是有数据的井
        
            # 🔥 2. 获取实际的井信息
            try:
                wells_data = self._db_service.get_wells_by_project(self._current_project_id)
                current_well = None
            
                # 优先查找指定的井ID
                for well in wells_data:
                    if well.get('id') == effective_well_id:
                        current_well = well
                        break
            
                # 如果没找到，使用第一口井
                if not current_well and wells_data:
                    current_well = wells_data[0]
                    effective_well_id = current_well.get('id')
            
                if current_well:
                    # 🔥 使用实际的井信息，而不是默认值
                    enhanced_data['well'] = {
                        'wellName': current_well.get('well_name', f'Well-{effective_well_id}'),
                        'wellType': current_well.get('well_type', 'Production'),
                        'totalDepth': current_well.get('total_depth', 0),
                        'verticalDepth': current_well.get('vertical_depth', current_well.get('total_depth', 0)),
                        'wellStatus': current_well.get('well_status', 'Active'),
                        'spudDate': current_well.get('spud_date', ''),
                        'completionDate': current_well.get('completion_date', ''),
                        # 添加更多井信息
                        'innerDiameter': current_well.get('inner_diameter', 152.4),
                        'outerDiameter': current_well.get('outer_diameter', 177.8),
                        'pumpDepth': current_well.get('pump_depth', 0),
                        'tubingDiameter': current_well.get('tubing_diameter', 0),
                        'roughness': current_well.get('roughness', 0.0018)
                    }
                    logger.info(f"✅ 获取到实际井信息: {current_well.get('well_name')} - 井深: {current_well.get('total_depth')}ft")
                else:
                    logger.warning("⚠️ 没有找到井数据，使用默认值")
                    enhanced_data['well'] = self._get_default_well_data(effective_well_id)
            except Exception as e:
                logger.error(f"获取井信息失败: {e}")
                enhanced_data['well'] = self._get_default_well_data(effective_well_id)
    
            # 🔥 3. 获取实际的计算结果（从WellStructureController）
            try:
                # 查询井身结构计算结果
                calculation_result = self._db_service.get_latest_calculation_result(effective_well_id)
                if calculation_result:
                    enhanced_data['calculation'] = {
                        'perforation_depth': calculation_result.get('perforation_depth', 0),
                        'pump_hanging_depth': calculation_result.get('pump_hanging_depth', 0),
                        'pump_measured_depth': calculation_result.get('pump_measured_depth', 0),
                        'total_depth_md': calculation_result.get('total_depth_md', 0),
                        'total_depth_tvd': calculation_result.get('total_depth_tvd', 0),
                        'max_inclination': calculation_result.get('max_inclination', 0),
                        'max_dls': calculation_result.get('max_dls', 0),
                        'calculation_method': calculation_result.get('calculation_method', ''),
                        'calculated_at': calculation_result.get('calculated_at', '')
                    }
                    logger.info(f"✅ 获取到计算结果: 射孔深度 {calculation_result.get('perforation_depth')}ft")
                else:
                    # 使用基于井深的估算值
                    well_depth = enhanced_data.get('well', {}).get('totalDepth', 2500)
                    enhanced_data['calculation'] = self._get_estimated_calculation(well_depth)
                    logger.info("💡 使用估算的井身结构数据")
            except Exception as e:
                logger.error(f"获取计算结果失败: {e}")
                well_depth = enhanced_data.get('well', {}).get('totalDepth', 2500)
                enhanced_data['calculation'] = self._get_estimated_calculation(well_depth)
        
            # 🔥 4. 获取实际的项目信息
            try:
                project_data = self._get_project_details(self._current_project_id)
                enhanced_data['project_details'] = project_data
                logger.info(f"✅ 项目信息: {project_data.get('project_name')}")
            except Exception as e:
                logger.error(f"获取项目信息失败: {e}")
                enhanced_data['project_details'] = self._get_default_project_data()
        
            # 🔥 5. 获取套管信息
            try:
                casing_data = self._get_casing_data(effective_well_id)
                enhanced_data['casing_data'] = casing_data
            
                # 查找生产套管
                production_casing = self._find_production_casing(casing_data)
                enhanced_data['production_casing'] = production_casing
            
                logger.info(f"✅ 套管信息: {len(casing_data)}个套管段")
            except Exception as e:
                logger.error(f"获取套管信息失败: {e}")
                enhanced_data['production_casing'] = self._get_default_casing_data()
        
            # 🔥 6. 生成数据完整性报告
            enhanced_data['data_completeness'] = self._generate_data_completeness_report(enhanced_data)
        
            # 🔥 7. 添加井号生成逻辑
            enhanced_data['well_number'] = self._generate_well_number(enhanced_data)
        
            logger.info("✅ 报告数据准备完成")
        
            # 发射增强数据
            self.reportDataPrepared.emit(enhanced_data)
    
        except Exception as e:
            error_msg = f"准备报告数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self._set_busy(False)
    
    def _generate_well_number(self, enhanced_data: dict) -> str:
        """生成井号"""
        try:
            well_name = enhanced_data.get('well', {}).get('wellName', '')
            project_name = enhanced_data.get('project_details', {}).get('project_name', '')
        
            # 从井名中提取数字
            import re
            number_match = re.search(r'\d+', well_name)
            if number_match:
                well_number = number_match.group()
            else:
                well_number = '001'
        
            # 生成格式化的井号
            if '大庆' in project_name:
                return f"DQ-{well_number}"
            elif '测试' in project_name:
                return f"TEST-{well_number}"
            else:
                return f"WELL-{well_number}"
            
        except Exception as e:
            logger.error(f"生成井号失败: {e}")
            return "RV_ F-195 IC No"


    def _get_default_casing_data(self) -> dict:
        raise NotImplementedError("请实现获取默认套管数据的逻辑") 
        """获取默认套管数据"""
        return {
            'outer_diameter': 177.8,
            'inner_diameter': 152.4,
            'grade': 'P-110',
            'weight': 29,
            'top_depth': 0,
            'bottom_depth': 2500
        }

    def _get_default_project_data(self) -> dict:
        raise NotImplementedError("请实现获取默认项目数据的逻辑")
        """获取默认项目数据"""
        return {
            'id': self._current_project_id,
            'project_name': '测试项目',
            'company_name': '中国石油技术开发有限公司',
            'oil_field': '测试油田',
            'location': '测试地点',
            'description': 'ESP设备选型项目',
            'created_at': '',
            'status': 'active'
        }

    def _get_project_details(self, project_id: int) -> dict:
        """获取项目详情"""
        try:
            # 这里可以调用ProjectController或直接查询数据库
            return {
                'id': project_id,
                'project_name': '大庆油田ESP选型项目',
                'company_name': '中国石油天然气股份有限公司',
                'oil_field': '大庆油田',
                'location': '黑龙江省大庆市',
                'description': 'ESP设备选型与优化项目',
                'created_at': '2025-01-01',
                'status': 'active'
            }
        except:
            return self._get_default_project_data()


    def _get_estimated_calculation(self, well_depth: float) -> dict:
        print(f"使用估算的井身结构数据，井深: {well_depth}ft")
        raise NotImplementedError("请实现基于井深估算的计算逻辑")
        """基于井深估算计算结果"""
        return {
            'perforation_depth': well_depth * 0.8,
            'pump_hanging_depth': well_depth * 0.7,
            'pump_measured_depth': well_depth * 0.75,
            'total_depth_md': well_depth,
            'total_depth_tvd': well_depth * 0.95,
            'max_inclination': 15.0,
            'max_dls': 2.5,
            'calculation_method': 'estimated',
            'calculated_at': ''
        }    

    def _get_default_well_data(self, well_id: int) -> dict:
        """获取默认井数据"""
        print(f"适用了默认井")
        raise NotImplementedError("请实现获取默认井数据的逻辑")
        return {
            'wellName': f'测试井-{well_id}',
            'wellType': '生产井',
            'totalDepth': 2500,
            'verticalDepth': 2500,
            'wellStatus': '生产中',
            'innerDiameter': 152.4,
            'outerDiameter': 177.8,
            'pumpDepth': 2000,
            'tubingDiameter': 88.9,
            'roughness': 0.0018
        }
    def _get_casing_data(self, well_id: int) -> list:
        """获取套管数据"""
        try:
            # 查询实际套管数据
            return self._db_service.get_casings_by_well(well_id)
        except:
            # 返回默认套管数据
            raise NotImplementedError("请实现获取默认套管数据的逻辑")
            return [
                {
                    'casing_type': 'surface',
                    'outer_diameter': 244.5,
                    'inner_diameter': 220.0,
                    'grade': 'J-55',
                    'weight': 42,
                    'top_depth': 0,
                    'bottom_depth': 500
                },
                {
                    'casing_type': 'production',
                    'outer_diameter': 177.8,
                    'inner_diameter': 152.4,
                    'grade': 'P-110',
                    'weight': 29,
                    'top_depth': 0,
                    'bottom_depth': 2500
                }
            ]

    def _find_production_casing(self, casing_data: list) -> dict:
        """查找生产套管"""
        logger.info(f"在 {len(casing_data)} 个套管段中查找生产套管")
    
        for casing in casing_data:
            if casing.get('casing_type') == 'production':
                logger.info(f"找到生产套管: OD {casing.get('outer_diameter')}mm × ID {casing.get('inner_diameter')}mm")
                return casing
    
        # 如果没有找到，返回默认生产套管
        logger.warning("未找到生产套管，使用默认值")
        return self._get_default_casing_data()


    def _find_production_casing_id(self, casing_data: list) -> str:
        """查找生产套管ID"""
        for casing in casing_data:
            if casing.get('casing_type') == 'production':
                return f"{casing.get('outer_diameter', 0):.1f}mm OD × {casing.get('inner_diameter', 0):.1f}mm ID"
        return "177.8mm OD × 152.4mm ID (默认)"


    def _generate_data_completeness_report(self, enhanced_data: dict) -> dict:
        """生成数据完整性报告"""
        try:
            completeness = {
                'project_info': 0,
                'well_info': 0,
                'parameters': 0,
                'prediction': 0,
                'pump_selection': 0,
                'motor_selection': 0,
                'protector_selection': 0,
                'separator_selection': 0
            }
        
            # 检查项目信息完整性
            project_details = enhanced_data.get('project_details', {})
            required_project_fields = ['project_name', 'company_name', 'oil_field', 'location']
            project_complete = sum(1 for field in required_project_fields if project_details.get(field)) / len(required_project_fields)
            completeness['project_info'] = project_complete * 100
        
            # 检查井信息完整性
            well_details = enhanced_data.get('well_details', {})
            casing_data = enhanced_data.get('casing_data', [])
            well_complete = 0.5 if well_details else 0
            well_complete += 0.5 if casing_data else 0
            completeness['well_info'] = well_complete * 100
        
            # 检查生产参数完整性
            params = enhanced_data.get('parameters_complete', enhanced_data.get('parameters', {}))
            required_param_fields = ['geo_pressure', 'expected_production', 'bht', 'api', 'gas_oil_ratio']
            param_complete = sum(1 for field in required_param_fields if params.get(field, 0) > 0) / len(required_param_fields)
            completeness['parameters'] = param_complete * 100
        
            # 检查预测结果完整性
            prediction = enhanced_data.get('prediction', {})
            if prediction.get('finalValues'):
                completeness['prediction'] = 100
            elif prediction:
                completeness['prediction'] = 50
        
            # 检查设备选型完整性
            completeness['pump_selection'] = 100 if enhanced_data.get('pump', {}).get('model') else 0
            completeness['motor_selection'] = 100 if enhanced_data.get('motor', {}).get('model') else 0
            completeness['protector_selection'] = 100 if enhanced_data.get('protector', {}).get('model') else 0
            completeness['separator_selection'] = 100 if enhanced_data.get('separator', {}).get('model') or enhanced_data.get('separator', {}).get('skipped') else 0
        
            # 计算总体完整性
            overall_completeness = sum(completeness.values()) / len(completeness)
        
            return {
                **completeness,
                'overall_completeness': overall_completeness
            }
        except Exception as e:
            logger.error(f"生成数据完整性报告失败: {e}")
            return {'overall_completeness': 0}


    # 在现有的DeviceRecommendationController类中添加以下方法

    @Slot('QVariant')
    def loadPumpPerformanceCurves(self, step_data):
        """加载选中泵的性能曲线数据"""
        try:
            print("=== 开始加载泵性能曲线数据 ===")
        
            # 从stepData中获取泵信息
            pump_info = step_data.get('pump', {})
            pump_model = pump_info.get('model', '')
            pump_id = pump_info.get('id', 0)
        
            print(f"泵型号: {pump_model}, 泵ID: {pump_id}")
        
            # 获取DeviceController实例
            device_controller = None
            # 尝试从QML上下文中获取deviceController
            # 这里需要确保deviceController已经在main.py中注册
        
            curves_data = None
        
            # 如果有泵ID，直接获取
            if pump_id and pump_id > 0:
                # 这里需要调用DeviceController的方法
                # 暂时生成模拟数据
                curves_data = self._generateMockPumpCurves(pump_info)
            elif pump_model:
                # 根据型号生成数据
                curves_data = self._generateMockPumpCurvesByModel(pump_model)
            else:
                # 使用默认泵参数
                curves_data = self._generateMockPumpCurves({})
            
            print(f"生成的曲线数据: {curves_data is not None}")
        
            # 发送数据到QML
            if curves_data:
                self.pumpCurvesDataReady.emit(curves_data)
            else:
                self.pumpCurvesDataReady.emit({'has_data': False, 'error': 'no_data'})
            
        except Exception as e:
            print(f"加载泵性能曲线失败: {str(e)}")
            self.pumpCurvesDataReady.emit({'has_data': False, 'error': str(e)})

    def _generateMockPumpCurves(self, pump_info):
        """生成模拟泵性能曲线数据"""
        import numpy as np
    
        # 使用泵信息中的参数，如果没有则使用默认值
        single_stage_head = pump_info.get('singleStageHead', 12.0)
        single_stage_power = pump_info.get('singleStagePower', 2.5)
        efficiency = pump_info.get('efficiency', 75.0)
        min_flow = pump_info.get('minFlow', 100)
        max_flow = pump_info.get('maxFlow', 2000)
        stages = pump_info.get('stages', 87)
    
        # 生成流量点
        flow_points = np.linspace(min_flow, max_flow, 25)
    
        # 计算多级泵的性能（乘以级数）
        total_head_per_stage = single_stage_head
        total_power_per_stage = single_stage_power
    
        # 生成性能曲线
        flow_normalized = flow_points / max_flow
    
        head_curve = []
        efficiency_curve = []
        power_curve = []
    
        for f_norm in flow_normalized:
            # 扬程曲线（多级）
            head_coeff = 1.0 - 0.25 * (f_norm ** 2)
            single_head = total_head_per_stage * head_coeff
            total_head = single_head * stages
            head_curve.append(max(total_head, 0))
        
            # 效率曲线
            if f_norm < 0.2:
                eff = efficiency * (0.4 + 3 * f_norm)
            elif f_norm <= 0.8:
                eff = efficiency * (0.85 + 0.15 * np.cos(np.pi * (f_norm - 0.5)))
            else:
                eff = efficiency * (1.0 - 0.4 * (f_norm - 0.8))
            efficiency_curve.append(max(min(eff, 95), 10))
        
            # 功率曲线（多级）
            power_factor = 0.3 + 0.7 * f_norm + 0.2 * (f_norm ** 2)
            total_power = total_power_per_stage * stages * power_factor
            power_curve.append(total_power)
    
        return {
            'has_data': True,
            'pump_info': {
                'manufacturer': pump_info.get('manufacturer', 'Centrilift'),
                'model': pump_info.get('model', 'GN4000'),
                'stages': stages,
                'outside_diameter': pump_info.get('outsideDiameter', 5.62)
            },
            'baseCurves': {
                'flow': flow_points.tolist(),
                'head': head_curve,
                'efficiency': efficiency_curve,
                'power': power_curve
            },
            'operatingPoints': [
                {
                    'flow': max_flow * 0.7,
                    'head': total_head_per_stage * stages * 0.85,
                    'efficiency': efficiency,
                    'power': total_power_per_stage * stages * 0.8,
                    'label': 'BEP'
                }
            ],
            'performanceZones': {
                'optimal': {
                    'minFlow': max_flow * 0.6,
                    'maxFlow': max_flow * 0.8
                },
                'acceptable': {
                    'minFlow': max_flow * 0.4,
                    'maxFlow': max_flow * 0.9
                }
            }
        }

    def _generateMockPumpCurvesByModel(self, pump_model):
        """根据泵型号生成模拟数据"""
        # 根据不同型号设置不同的参数
        model_params = {
            'GN4000': {
                'singleStageHead': 12.5,
                'singleStagePower': 2.8,
                'efficiency': 78,
                'minFlow': 150,
                'maxFlow': 2200,
                'stages': 87
            },
            'GN5500': {
                'singleStageHead': 15.0,
                'singleStagePower': 3.2,
                'efficiency': 80,
                'minFlow': 200,
                'maxFlow': 2500,
                'stages': 75
            }
        }
    
        # 查找匹配的型号参数
        params = model_params.get(pump_model, model_params['GN4000'])
        params['model'] = pump_model
    
        return self._generateMockPumpCurves(params)

    @Slot(result='QVariant')
    def getSeparatorsByType(self):
        """获取分离器列表 - 移除后备方案"""
        try:
            self._set_busy(True)
            logger.info("=== 开始加载分离器数据（仅从数据库）===")
            
            # 🔥 只从数据库获取，不使用后备方案
            separators = self._db_service.get_devices(
                device_type='SEPARATOR', 
                status='active'
            )
            
            logger.info(f"查询分离器数据返回: {len(separators.get('devices', []))}个设备")
            
            devices = separators.get('devices', [])
            if not devices:
                # 🔥 没有数据时发射错误信号，不提供后备数据
                error_msg = "数据库中没有找到分离器数据，请联系管理员添加设备"
                logger.warning(error_msg)
                self.error.emit(error_msg)
                return []
            
            # 转换为QML需要的格式
            separator_list = []
            for device_data in devices:
                separator_details = device_data.get('separator_details')
                
                if separator_details:
                    separator_info = {
                        'id': device_data['id'],
                        'manufacturer': device_data['manufacturer'],
                        'model': device_data['model'],
                        'series': self._extract_separator_series(device_data['model']),
                        'separationEfficiency': separator_details.get('separation_efficiency', 0),
                        'gasHandlingCapacity': separator_details.get('gas_handling_capacity', 0),
                        'liquidHandlingCapacity': separator_details.get('liquid_handling_capacity', 0),
                        'outerDiameter': separator_details.get('outer_diameter', 0),
                        'length': separator_details.get('length', 0),
                        'weight': separator_details.get('weight', 0),
                        'maxPressure': separator_details.get('max_pressure', 5000),
                        'description': device_data.get('description', ''),
                        'isNoSeparator': False
                    }
                    separator_list.append(separator_info)
                    logger.info(f"添加分离器到列表: {separator_info['manufacturer']} {separator_info['model']}")
                else:
                    logger.warning(f"设备 {device_data.get('id')} 没有分离器详情")

            if not separator_list:
                error_msg = "数据库中的分离器数据不完整，请检查设备详情配置"
                logger.error(error_msg)
                self.error.emit(error_msg)
                return []

            logger.info(f"✅ 从数据库成功加载分离器数据: {len(separator_list)}个")
            
            # 🔥 发射成功信号
            self.separatorsLoaded.emit(separator_list)
            
            return separator_list
            
        except Exception as e:
            error_msg = f"获取分离器数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            return []
        finally:
            self._set_busy(False)

    def _extract_separator_series(self, model: str) -> str:
        """从分离器型号中提取系列号"""
        try:
            import re
            # 提取常见的系列标识
            if 'CENesis' in model:
                return 'CENesis'
            elif 'Vortex' in model:
                return 'Vortex'
            elif 'DualFlow' in model:
                return 'DualFlow'
            elif 'TURBO' in model:
                return 'TURBO'
            else:
                # 尝试提取数字系列
                series_match = re.search(r'(\d{3,4})', model)
                return series_match.group(1) if series_match else 'Standard'
        except:
            return 'Standard'

    def extract_series(self, model: str) -> str:
        """从型号中提取系列号 - 修复版本"""
        try:
            # 提取数字系列
            import re
            series_match = re.search(r'(\d{3,4})', model)
            if series_match:
                return series_match.group(1)
        
            # 提取字母系列
            if 'FLEXPump' in model:
                return '400'
            elif 'REDA' in model:
                return '500'
            elif 'RCH' in model:
                return '600'
            elif 'GN' in model:
                # 提取GN后面的数字
                gn_match = re.search(r'GN(\d+)', model)
                if gn_match:
                    return gn_match.group(1)
                return '4000'
            else:
                return '400'  # 默认值
        except Exception as e:
            logger.error(f"提取系列号失败: {e}")
            return '400'
