# Controller/KnowledgeGraphController.py

import logging
import math
from typing import Dict, Any, List, Optional
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import QmlElement, QJSValue
import json

# 导入数据服务
from DataManage.services.database_service import DatabaseService

QML_IMPORT_NAME = "KnowledgeGraph"
QML_IMPORT_MAJOR_VERSION = 1

logger = logging.getLogger(__name__)

@QmlElement
class KnowledgeGraphController(QObject):
    """知识图谱控制器 - 修复QJSValue问题"""
    
    # 信号定义
    knowledgeGraphDataReady = Signal('QVariant')  # 知识图谱数据准备完成
    relationshipsUpdated = Signal('QVariant')     # 关系数据更新
    recommendationsGenerated = Signal('QVariant') # 推荐生成完成
    error = Signal(str)                           # 错误信号
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._db_service = DatabaseService()
        self._current_step_id = ""
        self._current_constraints = {}
        self._current_step_data = {}
        
        logger.info("知识图谱控制器初始化完成")
    
    @Slot(str, 'QVariant', 'QVariant')
    def generateKnowledgeGraph(self, step_id: str, step_data, constraints):
        """生成知识图谱数据 - 修复QJSValue处理"""
        try:
            logger.info(f"生成知识图谱: 步骤={step_id}")
            
            self._current_step_id = step_id
            
            # 🔥 修复：正确转换QJSValue为Python字典
            self._current_constraints = self._convert_qjs_value(constraints)
            self._current_step_data = self._convert_qjs_value(step_data)
            
            logger.info(f"转换后的约束条件: {self._current_constraints}")
            logger.info(f"转换后的步骤数据: {self._current_step_data}")
            
            # 🔥 根据步骤生成不同的图谱
            if step_id == "lift_method":
                graph_data = self._generate_lift_method_graph()
            elif step_id == "pump":
                graph_data = self._generate_pump_selection_graph()
            elif step_id == "separator":
                graph_data = self._generate_separator_graph()
            elif step_id == "protector":
                graph_data = self._generate_protector_graph()
            elif step_id == "motor":
                graph_data = self._generate_motor_graph()
            else:
                graph_data = self._generate_default_graph()
            
            graph_data['stepId'] = step_id
            graph_data['timestamp'] = self._get_timestamp()
            
            logger.info(f"知识图谱生成完成: {len(graph_data['nodes'])}个节点, {len(graph_data['edges'])}条边")
            self.knowledgeGraphDataReady.emit(graph_data)
            
        except Exception as e:
            error_msg = f"生成知识图谱失败: {str(e)}"
            logger.error(error_msg)
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            self.error.emit(error_msg)
    
    @Slot(str, 'QVariant')
    def generateRecommendations(self, step_id: str, constraints):
        """生成智能推荐 - 修复QJSValue处理"""
        try:
            logger.info(f"生成推荐建议: 步骤={step_id}")
            
            # 🔥 修复：正确转换QJSValue
            constraints_dict = self._convert_qjs_value(constraints)
            logger.info(f"转换后的推荐约束: {constraints_dict}")
            
            recommendations = []
            
            if step_id == "lift_method":
                recommendations = self._generate_lift_method_recommendations(constraints_dict)
            elif step_id == "pump":
                recommendations = self._generate_pump_recommendations(constraints_dict)
            elif step_id == "separator":
                recommendations = self._generate_separator_recommendations(constraints_dict)
            elif step_id == "protector":
                recommendations = self._generate_protector_recommendations(constraints_dict)
            elif step_id == "motor":
                recommendations = self._generate_motor_recommendations(constraints_dict)
            
            logger.info(f"生成了 {len(recommendations)} 条推荐")
            self.recommendationsGenerated.emit(recommendations)
            
        except Exception as e:
            error_msg = f"生成推荐失败: {str(e)}"
            logger.error(error_msg)
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            self.error.emit(error_msg)
    
    def _convert_qjs_value(self, qjs_value) -> Dict:
        """🔥 关键修复：将QJSValue转换为Python字典"""
        try:
            if qjs_value is None:
                return {}
            
            # 如果已经是Python字典，直接返回
            if isinstance(qjs_value, dict):
                return qjs_value
            
            # 如果是QJSValue，尝试转换为字典
            if hasattr(qjs_value, 'toVariant'):
                variant_value = qjs_value.toVariant()
                if isinstance(variant_value, dict):
                    return variant_value
                elif isinstance(variant_value, str):
                    # 尝试JSON解析
                    try:
                        return json.loads(variant_value)
                    except json.JSONDecodeError:
                        logger.warning(f"无法解析JSON字符串: {variant_value}")
                        return {}
                else:
                    logger.warning(f"QJSValue转换结果类型: {type(variant_value)}")
                    return {}
            
            # 如果有property方法，尝试提取属性
            if hasattr(qjs_value, 'property'):
                result = {}
                # 尝试提取常见的约束条件属性
                common_props = ['minProduction', 'maxProduction', 'totalHead', 'gasRate', 'totalPower', 'liftMethod']
                for prop in common_props:
                    prop_value = qjs_value.property(prop)
                    if hasattr(prop_value, 'toVariant'):
                        variant = prop_value.toVariant()
                        if variant is not None and variant != "":
                            result[prop] = variant
                
                logger.info(f"通过property方法提取的数据: {result}")
                return result
            
            # 最后尝试直接转换
            logger.warning(f"无法转换QJSValue，类型: {type(qjs_value)}")
            return {}
            
        except Exception as e:
            logger.error(f"QJSValue转换失败: {e}")
            return {}
    
    def _generate_lift_method_graph(self) -> Dict:
        """生成举升方式选择图谱"""
        nodes = []
        edges = []
        
        # 🔥 核心决策节点
        decision_node = {
            'id': 'lift_decision',
            'label': '举升方式决策',
            'type': 'decision',
            'icon': '🎯',
            'size': 45,
            'color': '#2196F3',
            'importance': 5
        }
        nodes.append(decision_node)
        
        # 🔥 输入参数节点
        min_production = self._current_constraints.get("minProduction", 0)
        total_head = self._current_constraints.get("totalHead", 0)
        
        input_params = [
            {
                'id': 'production_rate',
                'label': f'产量需求\n{min_production:.0f} bbl/d',
                'type': 'input',
                'icon': '📊',
                'size': 30,
                'color': '#4CAF50',
                'value': min_production
            },
            {
                'id': 'well_depth',
                'label': f'井深/扬程\n{total_head:.0f} ft',
                'type': 'input',
                'icon': '📏',
                'size': 30,
                'color': '#4CAF50',
                'value': total_head
            },
            {
                'id': 'fluid_properties',
                'label': '流体性质\n(粘度/密度)',
                'type': 'input',
                'icon': '🧪',
                'size': 25,
                'color': '#4CAF50'
            },
            {
                'id': 'well_conditions',
                'label': '井况条件\n(温度/压力)',
                'type': 'input',
                'icon': '🌡️',
                'size': 25,
                'color': '#4CAF50'
            }
        ]
        nodes.extend(input_params)
        
        # 🔥 举升方式选项
        selected_method = ""
        if isinstance(self._current_step_data, dict):
            lift_method_data = self._current_step_data.get('lift_method', {})
            if isinstance(lift_method_data, dict):
                selected_method = lift_method_data.get('selectedMethod', '')
        
        lift_methods = [
            {
                'id': 'esp_method',
                'label': 'ESP举升\n电潜泵',
                'type': 'lift_option',
                'icon': '⚡',
                'size': 40,
                'color': '#FF9800',
                'suitability': self._calculate_esp_suitability(),
                'selected': selected_method == 'esp'
            },
            {
                'id': 'pcp_method',
                'label': 'PCP举升\n螺杆泵',
                'type': 'lift_option',
                'icon': '🔄',
                'size': 35,
                'color': '#9C27B0',
                'suitability': self._calculate_pcp_suitability(),
                'selected': selected_method == 'pcp'
            },
            {
                'id': 'jet_method',
                'label': 'JET举升\n射流泵',
                'type': 'lift_option',
                'icon': '💨',
                'size': 30,
                'color': '#607D8B',
                'suitability': self._calculate_jet_suitability(),
                'selected': selected_method == 'jet'
            }
        ]
        
        # 根据适用性调整颜色
        for method in lift_methods:
            if method['selected']:
                method['color'] = '#F44336'  # 已选择 - 红色
            elif method['suitability'] > 0.8:
                method['color'] = '#4CAF50'  # 高适用性 - 绿色
            elif method['suitability'] > 0.6:
                method['color'] = '#FF9800'  # 中等适用性 - 橙色
            else:
                method['color'] = '#9E9E9E'  # 低适用性 - 灰色
        
        nodes.extend(lift_methods)
        
        # 🔥 决策规则节点
        decision_rules = [
            {
                'id': 'production_rule',
                'label': '产量适用性\n>1000 bbl/d → ESP',
                'type': 'rule',
                'icon': '📋',
                'size': 20,
                'color': '#795548'
            },
            {
                'id': 'depth_rule',
                'label': '深度适用性\n>2000 ft → ESP',
                'type': 'rule',
                'icon': '📋',
                'size': 20,
                'color': '#795548'
            }
        ]
        nodes.extend(decision_rules)
        
        # 🔥 生成边关系
        # 输入参数到决策中心
        for param in input_params:
            edges.append({
                'id': f'edge_{param["id"]}_to_decision',
                'source': param['id'],
                'target': 'lift_decision',
                'type': 'influences',
                'label': '影响',
                'strength': 0.8,
                'color': '#2196F3'
            })
        
        # 决策中心到举升方式
        for method in lift_methods:
            edges.append({
                'id': f'edge_decision_to_{method["id"]}',
                'source': 'lift_decision',
                'target': method['id'],
                'type': 'evaluates',
                'label': f'{method["suitability"]*100:.0f}%',
                'strength': method['suitability'],
                'color': '#4CAF50' if method['suitability'] > 0.7 else '#FF9800'
            })
        
        # 决策规则到举升方式
        edges.append({
            'id': 'edge_production_rule_to_esp',
            'source': 'production_rule',
            'target': 'esp_method',
            'type': 'supports',
            'label': '支持',
            'strength': 0.9,
            'color': '#4CAF50'
        })
        
        edges.append({
            'id': 'edge_depth_rule_to_esp',
            'source': 'depth_rule',
            'target': 'esp_method',
            'type': 'supports',
            'label': '支持',
            'strength': 0.9,
            'color': '#4CAF50'
        })
        
        layout = self._generate_lift_method_layout(nodes)
        
        return {'nodes': nodes, 'edges': edges, 'layout': layout}
    
    def _generate_pump_selection_graph(self) -> Dict:
        """生成泵选择图谱"""
        nodes = []
        edges = []
        
        # 🔥 需求分析节点
        requirements_node = {
            'id': 'pump_requirements',
            'label': '泵需求分析',
            'type': 'analysis',
            'icon': '🎯',
            'size': 40,
            'color': '#2196F3',
            'importance': 5
        }
        nodes.append(requirements_node)
        
        # 🔥 性能要求节点
        min_production = self._current_constraints.get("minProduction", 0)
        total_head = self._current_constraints.get("totalHead", 0)
        
        performance_requirements = [
            {
                'id': 'flow_requirement',
                'label': f'流量需求\n{min_production:.0f} bbl/d',
                'type': 'requirement',
                'icon': '💧',
                'size': 30,
                'color': '#03A9F4'
            },
            {
                'id': 'head_requirement',
                'label': f'扬程需求\n{total_head:.0f} ft',
                'type': 'requirement',
                'icon': '⬆️',
                'size': 30,
                'color': '#03A9F4'
            },
            {
                'id': 'efficiency_requirement',
                'label': '效率要求\n>75%',
                'type': 'requirement',
                'icon': '⚡',
                'size': 25,
                'color': '#03A9F4'
            }
        ]
        nodes.extend(performance_requirements)
        
        # 🔥 获取真实泵数据并分析
        pumps_data = self._get_suitable_pumps()
        pump_nodes = []
        
        for i, pump_info in enumerate(pumps_data[:5]):  # 限制显示5个最适合的泵
            pump = pump_info['pump']
            pump_details = pump.get('pump_details', {})
            
            # 计算推荐级数
            head_per_stage = pump_details.get('single_stage_head', 25)
            recommended_stages = int(total_head / head_per_stage) if head_per_stage > 0 else 0
            
            pump_node = {
                'id': f'pump_{pump["id"]}',
                'label': f'{pump.get("manufacturer", "Unknown")}\n{pump.get("model", "Model")}\n推荐{recommended_stages}级',
                'type': 'pump_candidate',
                'icon': '⚙️',
                'size': 35 + pump_info['match_score'] * 10,  # 大小反映匹配度
                'color': self._get_pump_color_by_score(pump_info['match_score']),
                'deviceData': pump,
                'matchScore': pump_info['match_score'],
                'recommendedStages': recommended_stages,
                'specs': {
                    'maxFlow': pump_details.get('displacement_max', 0),
                    'minFlow': pump_details.get('displacement_min', 0),
                    'efficiency': pump_details.get('efficiency', 0),
                    'headPerStage': head_per_stage
                }
            }
            pump_nodes.append(pump_node)
        
        nodes.extend(pump_nodes)
        
        # 🔥 选型约束节点
        constraints = [
            {
                'id': 'size_constraint',
                'label': '尺寸约束\n套管内径限制',
                'type': 'constraint',
                'icon': '📐',
                'size': 25,
                'color': '#F44336'
            },
            {
                'id': 'power_constraint',
                'label': '功率约束\n电机功率匹配',
                'type': 'constraint',
                'icon': '🔋',
                'size': 25,
                'color': '#F44336'
            }
        ]
        nodes.extend(constraints)
        
        # 🔥 生成关系边
        # 需求到泵的匹配关系
        for pump_node in pump_nodes:
            # 流量匹配
            flow_match = self._calculate_flow_match(pump_node, min_production)
            if flow_match > 0.3:
                edges.append({
                    'id': f'edge_flow_to_{pump_node["id"]}',
                    'source': 'flow_requirement',
                    'target': pump_node['id'],
                    'type': 'matches',
                    'label': f'{flow_match*100:.0f}%',
                    'strength': flow_match,
                    'color': '#4CAF50' if flow_match > 0.8 else '#FF9800'
                })
            
            # 扬程匹配
            head_match = self._calculate_head_match(pump_node, total_head)
            if head_match > 0.3:
                edges.append({
                    'id': f'edge_head_to_{pump_node["id"]}',
                    'source': 'head_requirement',
                    'target': pump_node['id'],
                    'type': 'matches',
                    'label': f'{head_match*100:.0f}%',
                    'strength': head_match,
                    'color': '#4CAF50' if head_match > 0.8 else '#FF9800'
                })
            
            # 需求分析中心到泵
            edges.append({
                'id': f'edge_analysis_to_{pump_node["id"]}',
                'source': 'pump_requirements',
                'target': pump_node['id'],
                'type': 'recommends',
                'label': f'推荐度{pump_node["matchScore"]*100:.0f}%',
                'strength': pump_node['matchScore'],
                'color': self._get_pump_color_by_score(pump_node['matchScore'])
            })
        
        # 约束到泵的限制关系
        for pump_node in pump_nodes:
            for constraint in constraints:
                edges.append({
                    'id': f'edge_{constraint["id"]}_to_{pump_node["id"]}',
                    'source': constraint['id'],
                    'target': pump_node['id'],
                    'type': 'constrains',
                    'label': '限制',
                    'strength': 0.6,
                    'color': '#F44336'
                })
        
        layout = self._generate_pump_layout(nodes)
        
        return {'nodes': nodes, 'edges': edges, 'layout': layout}
    
    def _generate_separator_graph(self) -> Dict:
        """生成分离器选择图谱"""
        nodes = []
        edges = []
        
        # 🔥 气液比分析中心
        gas_rate = self._current_constraints.get("gasRate", 0)
        glr_analysis = {
            'id': 'glr_analysis',
            'label': f'气液比分析\nGLR: {gas_rate:.1f}',
            'type': 'analysis',
            'icon': '🔬',
            'size': 40,
            'color': '#2196F3'
        }
        nodes.append(glr_analysis)
        
        # 🔥 决策节点
        decision_options = [
            {
                'id': 'separator_required',
                'label': '需要分离器\n气液比过高',
                'type': 'decision',
                'icon': '✅',
                'size': 35,
                'color': '#4CAF50' if gas_rate > 100 else '#9E9E9E',
                'recommended': gas_rate > 100
            },
            {
                'id': 'separator_optional',
                'label': '可选分离器\n预防性配置',
                'type': 'decision',
                'icon': '❓',
                'size': 30,
                'color': '#FF9800' if 50 < gas_rate <= 100 else '#9E9E9E',
                'recommended': 50 < gas_rate <= 100
            },
            {
                'id': 'no_separator',
                'label': '无需分离器\n气液比较低',
                'type': 'decision',
                'icon': '❌',
                'size': 25,
                'color': '#4CAF50' if gas_rate <= 50 else '#9E9E9E',
                'recommended': gas_rate <= 50
            }
        ]
        nodes.extend(decision_options)
        
        # 如果需要分离器，显示分离器选项
        if gas_rate > 50:
            separators_data = self._get_suitable_separators()
            for separator_info in separators_data[:3]:
                separator = separator_info['separator']
                separator_node = {
                    'id': f'separator_{separator["id"]}',
                    'label': f'{separator.get("manufacturer", "Unknown")}\n{separator.get("model", "Model")}',
                    'type': 'separator_option',
                    'icon': '🔄',
                    'size': 30,
                    'color': '#00BCD4',
                    'deviceData': separator
                }
                nodes.append(separator_node)
        
        # 影响因素
        factors = [
            {
                'id': 'pump_protection',
                'label': '泵保护\n延长寿命',
                'type': 'benefit',
                'icon': '🛡️',
                'size': 25,
                'color': '#4CAF50'
            },
            {
                'id': 'efficiency_improvement',
                'label': '效率提升\n减少汽蚀',
                'type': 'benefit',
                'icon': '📈',
                'size': 25,
                'color': '#4CAF50'
            }
        ]
        nodes.extend(factors)
        
        layout = self._generate_separator_layout(nodes)
        
        return {'nodes': nodes, 'edges': edges, 'layout': layout}
    
    def _generate_protector_graph(self) -> Dict:
        """生成保护器选择图谱"""
        nodes = []
        edges = []
        
        # 保护需求分析
        protection_analysis = {
            'id': 'protection_analysis',
            'label': '保护需求分析',
            'type': 'analysis',
            'icon': '🛡️',
            'size': 40,
            'color': '#2196F3'
        }
        nodes.append(protection_analysis)
        
        # 根据功率确定保护器配置
        pump_power = self._current_constraints.get("totalPower", 0)
        
        protection_configs = [
            {
                'id': 'single_protector',
                'label': f'单保护器\n适用<100HP',
                'type': 'config',
                'icon': '🛡️',
                'size': 30,
                'color': '#4CAF50' if pump_power < 100 else '#9E9E9E',
                'recommended': pump_power < 100
            },
            {
                'id': 'dual_protector',
                'label': f'双保护器\n适用≥100HP',
                'type': 'config',
                'icon': '🛡️🛡️',
                'size': 35,
                'color': '#4CAF50' if pump_power >= 100 else '#9E9E9E',
                'recommended': pump_power >= 100
            }
        ]
        nodes.extend(protection_configs)
        
        layout = self._generate_protector_layout(nodes)
        
        return {'nodes': nodes, 'edges': edges, 'layout': layout}
    
    def _generate_motor_graph(self) -> Dict:
        """生成电机选择图谱"""
        nodes = []
        edges = []
        
        # 功率需求分析
        total_power = self._current_constraints.get("totalPower", 0)
        power_analysis = {
            'id': 'power_analysis',
            'label': f'功率需求分析\n泵功率: {total_power:.0f} HP',
            'type': 'analysis',
            'icon': '⚡',
            'size': 40,
            'color': '#2196F3'
        }
        nodes.append(power_analysis)
        
        # 电机功率建议
        recommended_power = total_power * 1.15  # 15%安全裕量
        
        power_recommendations = [
            {
                'id': 'motor_power_rec',
                'label': f'推荐功率\n{recommended_power:.0f} HP\n(含15%裕量)',
                'type': 'recommendation',
                'icon': '🔋',
                'size': 35,
                'color': '#4CAF50'
            }
        ]
        nodes.extend(power_recommendations)
        
        # 获取合适的电机
        motors_data = self._get_suitable_motors(recommended_power)
        for motor_info in motors_data[:4]:
            motor = motor_info['motor']
            motor_details = motor.get('motor_details', {})
            freq_params = motor_details.get('frequency_params', [{}])
            main_params = freq_params[0] if freq_params else {}
            
            motor_node = {
                'id': f'motor_{motor["id"]}',
                'label': f'{motor.get("manufacturer", "Unknown")}\n{motor.get("model", "Model")}\n{main_params.get("power", 0)} HP',
                'type': 'motor_option',
                'icon': '⚡',
                'size': 30,
                'color': '#FF9800',
                'deviceData': motor,
                'specs': main_params
            }
            nodes.append(motor_node)
        
        layout = self._generate_motor_layout(nodes)
        
        return {'nodes': nodes, 'edges': edges, 'layout': layout}
    
    def _generate_default_graph(self) -> Dict:
        """生成默认图谱"""
        nodes = [
            {
                'id': 'default_center',
                'label': '选型分析',
                'type': 'center',
                'icon': '🎯',
                'size': 40,
                'color': '#2196F3'
            }
        ]
        edges = []
        layout = {'default_center': {'x': 400, 'y': 300}}
        
        return {'nodes': nodes, 'edges': edges, 'layout': layout}
    
    # 🔥 布局生成方法
    def _generate_lift_method_layout(self, nodes: List[Dict]) -> Dict:
        """生成举升方式图谱布局"""
        layout = {}
        center_x, center_y = 400, 300
        
        # 中心决策节点
        layout['lift_decision'] = {'x': center_x, 'y': center_y}
        
        # 输入参数 - 左侧
        input_positions = [
            {'x': center_x - 200, 'y': center_y - 80},
            {'x': center_x - 200, 'y': center_y - 20},
            {'x': center_x - 200, 'y': center_y + 40},
            {'x': center_x - 200, 'y': center_y + 100}
        ]
        
        input_nodes = [n for n in nodes if n['type'] == 'input']
        for i, node in enumerate(input_nodes):
            if i < len(input_positions):
                layout[node['id']] = input_positions[i]
        
        # 举升方式选项 - 右侧
        method_positions = [
            {'x': center_x + 200, 'y': center_y - 60},
            {'x': center_x + 200, 'y': center_y},
            {'x': center_x + 200, 'y': center_y + 60}
        ]
        
        method_nodes = [n for n in nodes if n['type'] == 'lift_option']
        for i, node in enumerate(method_nodes):
            if i < len(method_positions):
                layout[node['id']] = method_positions[i]
        
        # 决策规则 - 下方
        rule_nodes = [n for n in nodes if n['type'] == 'rule']
        for i, node in enumerate(rule_nodes):
            layout[node['id']] = {'x': center_x - 50 + i * 100, 'y': center_y + 150}
        
        return layout
    
    def _generate_pump_layout(self, nodes: List[Dict]) -> Dict:
        """生成泵选择图谱布局"""
        layout = {}
        center_x, center_y = 400, 300
        
        # 需求分析中心
        layout['pump_requirements'] = {'x': center_x, 'y': center_y}
        
        # 性能要求 - 上方
        req_nodes = [n for n in nodes if n['type'] == 'requirement']
        for i, node in enumerate(req_nodes):
            angle = (i / len(req_nodes)) * math.pi * 2 - math.pi/2
            radius = 120
            layout[node['id']] = {
                'x': center_x + radius * math.cos(angle),
                'y': center_y + radius * math.sin(angle)
            }
        
        # 泵候选 - 右侧环形
        pump_nodes = [n for n in nodes if n['type'] == 'pump_candidate']
        for i, node in enumerate(pump_nodes):
            angle = (i / len(pump_nodes)) * math.pi - math.pi/2
            radius = 200
            layout[node['id']] = {
                'x': center_x + radius * math.cos(angle),
                'y': center_y + radius * math.sin(angle)
            }
        
        # 约束 - 左侧
        constraint_nodes = [n for n in nodes if n['type'] == 'constraint']
        for i, node in enumerate(constraint_nodes):
            layout[node['id']] = {'x': center_x - 150, 'y': center_y - 30 + i * 60}
        
        return layout
    
    def _generate_separator_layout(self, nodes: List[Dict]) -> Dict:
        """生成分离器图谱布局"""
        layout = {}
        center_x, center_y = 400, 300
        
        # GLR分析中心
        layout['glr_analysis'] = {'x': center_x, 'y': center_y}
        
        # 决策选项
        decision_nodes = [n for n in nodes if n['type'] == 'decision']
        for i, node in enumerate(decision_nodes):
            layout[node['id']] = {'x': center_x + 150, 'y': center_y - 60 + i * 60}
        
        # 分离器选项
        separator_nodes = [n for n in nodes if n['type'] == 'separator_option']
        for i, node in enumerate(separator_nodes):
            layout[node['id']] = {'x': center_x + 300, 'y': center_y - 40 + i * 40}
        
        # 影响因素
        factor_nodes = [n for n in nodes if n['type'] == 'benefit']
        for i, node in enumerate(factor_nodes):
            layout[node['id']] = {'x': center_x - 150, 'y': center_y - 30 + i * 60}
        
        return layout
    
    def _generate_protector_layout(self, nodes: List[Dict]) -> Dict:
        """生成保护器图谱布局"""
        layout = {}
        center_x, center_y = 400, 300
        
        # 保护分析中心
        layout['protection_analysis'] = {'x': center_x, 'y': center_y}
        
        # 配置选项
        config_nodes = [n for n in nodes if n['type'] == 'config']
        for i, node in enumerate(config_nodes):
            layout[node['id']] = {'x': center_x + 150, 'y': center_y - 30 + i * 60}
        
        return layout
    
    def _generate_motor_layout(self, nodes: List[Dict]) -> Dict:
        """生成电机图谱布局"""
        layout = {}
        center_x, center_y = 400, 300
        
        # 功率分析中心
        layout['power_analysis'] = {'x': center_x, 'y': center_y}
        
        # 功率推荐
        rec_nodes = [n for n in nodes if n['type'] == 'recommendation']
        for i, node in enumerate(rec_nodes):
            layout[node['id']] = {'x': center_x - 150, 'y': center_y}
        
        # 电机选项
        motor_nodes = [n for n in nodes if n['type'] == 'motor_option']
        for i, node in enumerate(motor_nodes):
            angle = (i / len(motor_nodes)) * math.pi * 2
            radius = 180
            layout[node['id']] = {
                'x': center_x + radius * math.cos(angle),
                'y': center_y + radius * math.sin(angle)
            }
        
        return layout
    
    # 🔥 辅助计算方法
    def _calculate_esp_suitability(self) -> float:
        """计算ESP适用性"""
        production = self._current_constraints.get("minProduction", 0)
        head = self._current_constraints.get("totalHead", 0)
        
        score = 0.0
        if production > 1000:
            score += 0.4
        elif production > 500:
            score += 0.2
        
        if head > 2000:
            score += 0.4
        elif head > 1000:
            score += 0.2
        
        score += 0.2  # 基础适用性
        
        return min(score, 1.0)
    
    def _calculate_pcp_suitability(self) -> float:
        """计算PCP适用性"""
        production = self._current_constraints.get("minProduction", 0)
        
        if production <= 500:
            return 0.8
        elif production <= 1000:
            return 0.6
        else:
            return 0.3
    
    def _calculate_jet_suitability(self) -> float:
        """计算JET适用性"""
        production = self._current_constraints.get("minProduction", 0)
        
        if production <= 200:
            return 0.7
        elif production <= 500:
            return 0.5
        else:
            return 0.2
    
    def _get_suitable_pumps(self) -> List[Dict]:
        """获取合适的泵"""
        try:
            pumps = self._db_service.get_devices(device_type='PUMP', status='active')
            suitable_pumps = []
            
            required_flow = self._current_constraints.get('minProduction', 0)
            required_head = self._current_constraints.get('totalHead', 0)
            
            for pump_data in pumps.get('devices', []):
                match_score = self._calculate_pump_match_score(pump_data, self._current_constraints)
                if match_score > 0.3:  # 只显示匹配度较高的
                    suitable_pumps.append({
                        'pump': pump_data,
                        'match_score': match_score
                    })
            
            # 按匹配度排序
            suitable_pumps.sort(key=lambda x: x['match_score'], reverse=True)
            return suitable_pumps[:8]  # 返回前8个
            
        except Exception as e:
            logger.error(f"获取合适泵失败: {e}")
            return []
    
    def _get_suitable_separators(self) -> List[Dict]:
        """获取合适的分离器"""
        try:
            separators = self._db_service.get_devices(device_type='SEPARATOR', status='active')
            return [{'separator': sep} for sep in separators.get('devices', [])[:5]]
        except Exception as e:
            logger.error(f"获取分离器失败: {e}")
            return []
    
    def _get_suitable_motors(self, required_power: float) -> List[Dict]:
        """获取合适的电机"""
        try:
            motors = self._db_service.get_devices(device_type='MOTOR', status='active')
            suitable_motors = []
            
            for motor_data in motors.get('devices', []):
                motor_details = motor_data.get('motor_details', {})
                freq_params = motor_details.get('frequency_params', [{}])
                motor_power = freq_params[0].get('power', 0) if freq_params else 0
                
                # 功率在合理范围内
                if required_power * 0.8 <= motor_power <= required_power * 1.3:
                    suitable_motors.append({'motor': motor_data})
            
            return suitable_motors[:6]
            
        except Exception as e:
            logger.error(f"获取合适电机失败: {e}")
            return []
    
    def _calculate_flow_match(self, pump_node: Dict, required_flow: float) -> float:
        """计算流量匹配度"""
        specs = pump_node.get('specs', {})
        max_flow = specs.get('maxFlow', 0)
        min_flow = specs.get('minFlow', 0)
        
        if min_flow <= required_flow <= max_flow:
            return 1.0
        elif required_flow < min_flow:
            return max(0.0, 1.0 - (min_flow - required_flow) / min_flow)
        else:
            return max(0.0, 1.0 - (required_flow - max_flow) / max_flow)
    
    def _calculate_head_match(self, pump_node: Dict, required_head: float) -> float:
        """计算扬程匹配度"""
        specs = pump_node.get('specs', {})
        head_per_stage = specs.get('headPerStage', 25)
        recommended_stages = pump_node.get('recommendedStages', 0)
        
        achievable_head = head_per_stage * recommended_stages
        
        if achievable_head == 0:
            return 0.0
        
        ratio = required_head / achievable_head
        if 0.8 <= ratio <= 1.2:
            return 1.0
        elif 0.6 <= ratio <= 1.4:
            return 0.8
        else:
            return 0.5
    
    def _get_pump_color_by_score(self, score: float) -> str:
        """根据匹配分数获取泵颜色"""
        if score >= 0.8:
            return '#4CAF50'  # 绿色 - 高匹配
        elif score >= 0.6:
            return '#FF9800'  # 橙色 - 中等匹配
        elif score >= 0.4:
            return '#FFC107'  # 黄色 - 低匹配
        else:
            return '#9E9E9E'  # 灰色 - 不推荐
    
    def _calculate_pump_match_score(self, pump_data: Dict, constraints: Dict) -> float:
        """计算泵匹配分数"""
        try:
            score = 0.0
            
            pump_details = pump_data.get('pump_details', {})
            
            # 流量匹配 (40%)
            max_flow = pump_details.get('displacement_max', 0)
            min_flow = pump_details.get('displacement_min', 0)
            required_flow = constraints.get('minProduction', 0)
            
            if min_flow <= required_flow <= max_flow:
                # 理想工况点在流量范围的60-80%
                optimal_range_start = min_flow + (max_flow - min_flow) * 0.6
                optimal_range_end = min_flow + (max_flow - min_flow) * 0.8
                
                if optimal_range_start <= required_flow <= optimal_range_end:
                    score += 0.4
                else:
                    distance = min(abs(required_flow - optimal_range_start), 
                                 abs(required_flow - optimal_range_end))
                    score += 0.4 * max(0, 1 - distance / (max_flow - min_flow))
            
            # 效率匹配 (30%)
            efficiency = pump_details.get('efficiency', 0)
            if efficiency >= 75:
                score += 0.3
            elif efficiency >= 60:
                score += 0.2
            elif efficiency >= 45:
                score += 0.1
            
            # 扬程匹配 (20%)
            head_per_stage = pump_details.get('single_stage_head', 25)
            required_head = constraints.get('totalHead', 0)
            required_stages = int(required_head / head_per_stage) if head_per_stage > 0 else 0
            max_stages = pump_details.get('max_stages', 100)
            
            if required_stages <= max_stages * 0.8:  # 不超过最大级数的80%
                score += 0.2
            elif required_stages <= max_stages:
                score += 0.1
            
            # 制造商信誉 (10%)
            manufacturer = pump_data.get('manufacturer', '').lower()
            if manufacturer in ['schlumberger', 'baker hughes', 'halliburton']:
                score += 0.1
            elif manufacturer in ['weatherford', 'novomet']:
                score += 0.05
            
            return min(score, 1.0)
            
        except Exception as e:
            logger.error(f"计算泵匹配分数失败: {e}")
            return 0.5
    
    # 推荐生成方法
    def _generate_lift_method_recommendations(self, constraints: Dict) -> List[Dict]:
        """生成举升方式推荐"""
        recommendations = []
        
        production = constraints.get('minProduction', 0)
        head = constraints.get('totalHead', 0)
        
        # ESP推荐
        esp_score = self._calculate_esp_suitability()
        if esp_score > 0.7:
            recommendations.append({
                'id': 'rec_esp_lift',
                'title': '强烈推荐ESP举升',
                'description': f'产量{production:.0f} bbl/d，扬程{head:.0f} ft，ESP举升效率最高',
                'confidence': esp_score,
                'type': 'primary',
                'icon': '⚡',
                'actionText': '选择ESP',
                'data': {'method': 'esp', 'reason': 'high_suitability'}
            })
        
        # PCP推荐
        pcp_score = self._calculate_pcp_suitability()
        if pcp_score > 0.6:
            recommendations.append({
                'id': 'rec_pcp_lift',
                'title': '考虑PCP举升',
                'description': f'低产量井适用，运维成本较低',
                'confidence': pcp_score,
                'type': 'secondary',
                'icon': '🔄',
                'actionText': '选择PCP',
                'data': {'method': 'pcp', 'reason': 'low_production_suitable'}
            })
        
        return recommendations
    
    def _generate_pump_recommendations(self, constraints: Dict) -> List[Dict]:
        """生成泵推荐"""
        recommendations = []
        
        # 获取最佳匹配的泵
        suitable_pumps = self._get_suitable_pumps()
        
        for i, pump_info in enumerate(suitable_pumps[:3]):
            pump = pump_info['pump']
            pump_details = pump.get('pump_details', {})
            
            # 计算推荐级数
            required_head = constraints.get('totalHead', 0)
            head_per_stage = pump_details.get('single_stage_head', 25)
            recommended_stages = int(required_head / head_per_stage) if head_per_stage > 0 else 0
            
            recommendations.append({
                'id': f'rec_pump_{pump["id"]}',
                'title': f'推荐: {pump.get("manufacturer", "")} {pump.get("model", "")}',
                'description': f'建议{recommended_stages}级配置，匹配度{pump_info["match_score"]*100:.0f}%，效率{pump_details.get("efficiency", 0):.0f}%',
                'confidence': pump_info['match_score'],
                'type': 'primary' if i == 0 else 'secondary',
                'icon': '⚙️',
                'actionText': '选择此泵',
                'data': {
                    'pumpId': pump['id'],
                    'manufacturer': pump.get('manufacturer'),
                    'model': pump.get('model'),
                    'stages': recommended_stages,
                    'matchScore': pump_info['match_score']
                }
            })
        
        return recommendations
    
    def _generate_separator_recommendations(self, constraints: Dict) -> List[Dict]:
        """生成分离器推荐"""
        recommendations = []
        
        gas_rate = constraints.get('gasRate', 0)
        
        if gas_rate > 100:
            recommendations.append({
                'id': 'rec_separator_required',
                'title': '强烈推荐安装分离器',
                'description': f'气液比{gas_rate:.1f}过高，分离器必需',
                'confidence': 0.95,
                'type': 'primary',
                'icon': '🔄',
                'actionText': '配置分离器',
                'data': {'separatorRequired': True, 'gasRate': gas_rate}
            })
        elif gas_rate > 50:
            recommendations.append({
                'id': 'rec_separator_optional',
                'title': '建议配置分离器',
                'description': f'气液比{gas_rate:.1f}中等，分离器可提升性能',
                'confidence': 0.75,
                'type': 'secondary',
                'icon': '🔄',
                'actionText': '可选配置',
                'data': {'separatorRequired': False, 'gasRate': gas_rate}
            })
        else:
            recommendations.append({
                'id': 'rec_separator_skip',
                'title': '可跳过分离器',
                'description': f'气液比{gas_rate:.1f}较低，分离器非必需',
                'confidence': 0.85,
                'type': 'info',
                'icon': 'ℹ️',
                'actionText': '跳过',
                'data': {'separatorRequired': False, 'gasRate': gas_rate}
            })
        
        return recommendations
    
    def _generate_protector_recommendations(self, constraints: Dict) -> List[Dict]:
        """生成保护器推荐"""
        recommendations = []
        
        pump_power = constraints.get('totalPower', 0)
        
        if pump_power > 100:
            recommendations.append({
                'id': 'rec_dual_protector',
                'title': '推荐双保护器配置',
                'description': f'泵功率{pump_power:.0f} HP，需要上下保护器',
                'confidence': 0.9,
                'type': 'primary',
                'icon': '🛡️',
                'actionText': '配置双保护器',
                'data': {'quantity': 2, 'totalPower': pump_power}
            })
        else:
            recommendations.append({
                'id': 'rec_single_protector',
                'title': '单保护器足够',
                'description': f'泵功率{pump_power:.0f} HP，单保护器即可',
                'confidence': 0.8,
                'type': 'secondary',
                'icon': '🛡️',
                'actionText': '配置单保护器',
                'data': {'quantity': 1, 'totalPower': pump_power}
            })
        
        return recommendations
    
    def _generate_motor_recommendations(self, constraints: Dict) -> List[Dict]:
        """生成电机推荐"""
        recommendations = []
        
        required_power = constraints.get('totalPower', 0)
        recommended_power = required_power * 1.15
        
        if required_power > 0:
            recommendations.append({
                'id': 'rec_motor_power',
                'title': f'推荐电机功率: {recommended_power:.0f} HP',
                'description': f'泵需求{required_power:.0f} HP + 15%安全裕量',
                'confidence': 0.9,
                'type': 'primary',
                'icon': '⚡',
                'actionText': '选择电机',
                'data': {
                    'recommendedPower': recommended_power,
                    'requiredPower': required_power,
                    'safetyMargin': 0.15
                }
            })
        
        return recommendations
    
    # 工具方法
    def _get_step_display_name(self, step_id: str) -> str:
        """获取步骤显示名称"""
        names = {
            'lift_method': '举升方式选择',
            'pump': '泵型选择',
            'separator': '分离器选择',
            'protector': '保护器选择',
            'motor': '电机选择',
            'report': '选型报告'
        }
        return names.get(step_id, step_id)
    
    def _get_step_icon(self, step_id: str) -> str:
        """获取步骤图标"""
        icons = {
            'lift_method': '🔧',
            'pump': '⚙️',
            'separator': '🔄',
            'protector': '🛡️',
            'motor': '⚡',
            'report': '📄'
        }
        return icons.get(step_id, '❓')
    
    def _get_timestamp(self) -> str:
        """获取时间戳"""
        from datetime import datetime
        return datetime.now().isoformat()