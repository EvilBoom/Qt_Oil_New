# DataManage/models/condition_comparison.py

from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean, Text, Index
from sqlalchemy.orm import relationship
from datetime import datetime
from typing import Dict, List, Any
import json

from .base import Base


class PumpConditionComparison(Base):
    """泵工况对比表"""
    __tablename__ = 'pump_condition_comparisons'

    id = Column(Integer, primary_key=True)
    comparison_name = Column(String(100), nullable=False)  # 对比名称
    pump_id = Column(String(50), nullable=False)           # 泵型号ID
    project_id = Column(Integer)                           # 关联项目（可选）
    well_id = Column(Integer)                              # 关联井（可选）
    
    # 对比配置
    base_condition = Column(Text)                          # JSON: 基础工况配置
    comparison_conditions = Column(Text)                   # JSON: 对比工况列表
    comparison_parameters = Column(Text)                   # JSON: 对比参数设置
    
    # 对比结果
    performance_metrics = Column(Text)                     # JSON: 性能指标对比
    efficiency_comparison = Column(Text)                   # JSON: 效率对比
    power_comparison = Column(Text)                        # JSON: 功率对比
    cost_comparison = Column(Text)                         # JSON: 成本对比
    reliability_analysis = Column(Text)                    # JSON: 可靠性分析
    
    # 推荐结果
    recommendations = Column(Text)                         # JSON: 推荐方案
    optimal_condition = Column(Text)                       # JSON: 最优工况
    risk_assessment = Column(Text)                         # JSON: 风险评估
    
    # 分析配置
    analysis_method = Column(String(50))                   # 分析方法
    weight_factors = Column(Text)                          # JSON: 权重因子
    evaluation_criteria = Column(Text)                     # JSON: 评价准则
    
    # 元数据
    created_by = Column(String(50))                        # 创建者
    analysis_purpose = Column(String(200))                 # 分析目的
    notes = Column(Text)                                   # 备注
    
    # 结果状态
    status = Column(String(20), default='draft')           # draft, completed, archived
    confidence_level = Column(String(20))                  # high, medium, low
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 创建索引
    __table_args__ = (
        Index('idx_comparison_pump', 'pump_id'),
        Index('idx_comparison_project', 'project_id', 'well_id'),
        Index('idx_comparison_status', 'status'),
    )

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        # 解析JSON字段
        def safe_json_loads(json_str):
            if json_str:
                try:
                    return json.loads(json_str)
                except:
                    return None
            return None

        return {
            'id': self.id,
            'comparison_name': self.comparison_name,
            'pump_id': self.pump_id,
            'project_id': self.project_id,
            'well_id': self.well_id,
            'base_condition': safe_json_loads(self.base_condition),
            'comparison_conditions': safe_json_loads(self.comparison_conditions),
            'comparison_parameters': safe_json_loads(self.comparison_parameters),
            'performance_metrics': safe_json_loads(self.performance_metrics),
            'efficiency_comparison': safe_json_loads(self.efficiency_comparison),
            'power_comparison': safe_json_loads(self.power_comparison),
            'cost_comparison': safe_json_loads(self.cost_comparison),
            'reliability_analysis': safe_json_loads(self.reliability_analysis),
            'recommendations': safe_json_loads(self.recommendations),
            'optimal_condition': safe_json_loads(self.optimal_condition),
            'risk_assessment': safe_json_loads(self.risk_assessment),
            'analysis_method': self.analysis_method,
            'weight_factors': safe_json_loads(self.weight_factors),
            'evaluation_criteria': safe_json_loads(self.evaluation_criteria),
            'created_by': self.created_by,
            'analysis_purpose': self.analysis_purpose,
            'notes': self.notes,
            'status': self.status,
            'confidence_level': self.confidence_level,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

    # JSON字段的设置和获取方法
    def set_base_condition(self, condition: Dict):
        """设置基础工况"""
        self.base_condition = json.dumps(condition)

    def get_base_condition(self) -> Dict:
        """获取基础工况"""
        if self.base_condition:
            try:
                return json.loads(self.base_condition)
            except:
                return {}
        return {}

    def set_comparison_conditions(self, conditions: List[Dict]):
        """设置对比工况列表"""
        self.comparison_conditions = json.dumps(conditions)

    def get_comparison_conditions(self) -> List[Dict]:
        """获取对比工况列表"""
        if self.comparison_conditions:
            try:
                return json.loads(self.comparison_conditions)
            except:
                return []
        return []

    def set_recommendations(self, recommendations: List[Dict]):
        """设置推荐方案"""
        self.recommendations = json.dumps(recommendations)

    def get_recommendations(self) -> List[Dict]:
        """获取推荐方案"""
        if self.recommendations:
            try:
                return json.loads(self.recommendations)
            except:
                return []
        return []


class ConditionOptimization(Base):
    """工况优化表"""
    __tablename__ = 'condition_optimizations'

    id = Column(Integer, primary_key=True)
    comparison_id = Column(Integer, ForeignKey('pump_condition_comparisons.id'))
    optimization_name = Column(String(100), nullable=False)
    
    # 优化目标
    optimization_objective = Column(String(50))            # efficiency, cost, reliability, multi_objective
    target_values = Column(Text)                           # JSON: 目标值设置
    constraints = Column(Text)                             # JSON: 约束条件
    
    # 优化算法
    algorithm_type = Column(String(50))                    # genetic, particle_swarm, gradient_descent
    algorithm_parameters = Column(Text)                    # JSON: 算法参数
    iterations = Column(Integer)                           # 迭代次数
    convergence_criteria = Column(Float)                   # 收敛准则
    
    # 优化结果
    optimal_solution = Column(Text)                        # JSON: 最优解
    optimization_history = Column(Text)                    # JSON: 优化历史
    performance_improvement = Column(Float)                # 性能改善百分比
    confidence_score = Column(Float)                       # 置信度评分
    
    # 验证结果
    validation_method = Column(String(50))                 # 验证方法
    validation_results = Column(Text)                      # JSON: 验证结果
    sensitivity_analysis = Column(Text)                    # JSON: 敏感性分析
    
    # 实施建议
    implementation_plan = Column(Text)                     # JSON: 实施计划
    risk_mitigation = Column(Text)                         # JSON: 风险缓解措施
    expected_benefits = Column(Text)                       # JSON: 预期收益
    
    # 状态信息
    status = Column(String(20), default='pending')         # pending, validated, implemented, rejected
    validation_date = Column(DateTime)                     # 验证日期
    implementation_date = Column(DateTime)                 # 实施日期
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        def safe_json_loads(json_str):
            if json_str:
                try:
                    return json.loads(json_str)
                except:
                    return None
            return None

        return {
            'id': self.id,
            'comparison_id': self.comparison_id,
            'optimization_name': self.optimization_name,
            'optimization_objective': self.optimization_objective,
            'target_values': safe_json_loads(self.target_values),
            'constraints': safe_json_loads(self.constraints),
            'algorithm_type': self.algorithm_type,
            'algorithm_parameters': safe_json_loads(self.algorithm_parameters),
            'iterations': self.iterations,
            'convergence_criteria': self.convergence_criteria,
            'optimal_solution': safe_json_loads(self.optimal_solution),
            'optimization_history': safe_json_loads(self.optimization_history),
            'performance_improvement': self.performance_improvement,
            'confidence_score': self.confidence_score,
            'validation_method': self.validation_method,
            'validation_results': safe_json_loads(self.validation_results),
            'sensitivity_analysis': safe_json_loads(self.sensitivity_analysis),
            'implementation_plan': safe_json_loads(self.implementation_plan),
            'risk_mitigation': safe_json_loads(self.risk_mitigation),
            'expected_benefits': safe_json_loads(self.expected_benefits),
            'status': self.status,
            'validation_date': self.validation_date.isoformat() if self.validation_date else None,
            'implementation_date': self.implementation_date.isoformat() if self.implementation_date else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }