# DataManage/models/performance_prediction.py

from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean, Text, Index
from sqlalchemy.orm import relationship
from datetime import datetime
from typing import Dict, List, Any
import json

from .base import Base


class DevicePerformancePrediction(Base):
    """设备性能预测表"""
    __tablename__ = 'device_performance_predictions'

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey('devices.id'), nullable=False)  # 关联设备表
    pump_id = Column(String(50), nullable=False)  # 泵型号ID
    prediction_years = Column(Integer, default=5)  # 预测年限
    
    # 预测基础参数
    base_efficiency = Column(Float)  # 基础效率
    base_power = Column(Float)      # 基础功率
    base_flow = Column(Float)       # 基础流量
    base_head = Column(Float)       # 基础扬程
    
    # 预测结果（JSON存储）
    annual_predictions = Column(Text)      # JSON: 年度性能预测数据
    wear_progression = Column(Text)        # JSON: 磨损进程数据
    maintenance_schedule = Column(Text)    # JSON: 维护计划
    lifecycle_cost = Column(Text)          # JSON: 生命周期成本
    performance_degradation = Column(Text) # JSON: 性能衰减分析
    
    # 预测配置
    wear_model = Column(String(50), default='exponential')  # 磨损模型类型
    efficiency_degradation_rate = Column(Float, default=0.02)  # 年效率衰减率
    maintenance_cost_base = Column(Float, default=5000)     # 基础维护成本
    energy_cost_rate = Column(Float, default=0.1)          # 能源成本费率
    
    # 预测质量和来源
    prediction_accuracy = Column(String(20), default='estimated')  # high, medium, low, estimated
    model_version = Column(String(20), default='1.0')      # 预测模型版本
    calculation_method = Column(String(100))               # 计算方法描述
    
    # 元数据
    created_by = Column(String(50))                        # 创建者
    prediction_notes = Column(Text)                        # 预测说明
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 创建索引
    __table_args__ = (
        Index('idx_prediction_device', 'device_id', 'pump_id'),
        Index('idx_prediction_created', 'created_at'),
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
            'device_id': self.device_id,
            'pump_id': self.pump_id,
            'prediction_years': self.prediction_years,
            'base_efficiency': self.base_efficiency,
            'base_power': self.base_power,
            'base_flow': self.base_flow,
            'base_head': self.base_head,
            'annual_predictions': safe_json_loads(self.annual_predictions),
            'wear_progression': safe_json_loads(self.wear_progression),
            'maintenance_schedule': safe_json_loads(self.maintenance_schedule),
            'lifecycle_cost': safe_json_loads(self.lifecycle_cost),
            'performance_degradation': safe_json_loads(self.performance_degradation),
            'wear_model': self.wear_model,
            'efficiency_degradation_rate': self.efficiency_degradation_rate,
            'maintenance_cost_base': self.maintenance_cost_base,
            'energy_cost_rate': self.energy_cost_rate,
            'prediction_accuracy': self.prediction_accuracy,
            'model_version': self.model_version,
            'calculation_method': self.calculation_method,
            'created_by': self.created_by,
            'prediction_notes': self.prediction_notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

    def set_annual_predictions(self, predictions: List[Dict]):
        """设置年度预测数据"""
        self.annual_predictions = json.dumps(predictions)

    def get_annual_predictions(self) -> List[Dict]:
        """获取年度预测数据"""
        if self.annual_predictions:
            try:
                return json.loads(self.annual_predictions)
            except:
                return []
        return []

    def set_wear_progression(self, progression: List[Dict]):
        """设置磨损进程数据"""
        self.wear_progression = json.dumps(progression)

    def get_wear_progression(self) -> List[Dict]:
        """获取磨损进程数据"""
        if self.wear_progression:
            try:
                return json.loads(self.wear_progression)
            except:
                return []
        return []

    def set_maintenance_schedule(self, schedule: List[Dict]):
        """设置维护计划"""
        self.maintenance_schedule = json.dumps(schedule)

    def get_maintenance_schedule(self) -> List[Dict]:
        """获取维护计划"""
        if self.maintenance_schedule:
            try:
                return json.loads(self.maintenance_schedule)
            except:
                return []
        return []

    def set_lifecycle_cost(self, cost_data: Dict):
        """设置生命周期成本"""
        self.lifecycle_cost = json.dumps(cost_data)

    def get_lifecycle_cost(self) -> Dict:
        """获取生命周期成本"""
        if self.lifecycle_cost:
            try:
                return json.loads(self.lifecycle_cost)
            except:
                return {}
        return {}

    def set_performance_degradation(self, degradation: Dict):
        """设置性能衰减分析"""
        self.performance_degradation = json.dumps(degradation)

    def get_performance_degradation(self) -> Dict:
        """获取性能衰减分析"""
        if self.performance_degradation:
            try:
                return json.loads(self.performance_degradation)
            except:
                return {}
        return {}


class PumpWearData(Base):
    """泵磨损数据表"""
    __tablename__ = 'pump_wear_data'

    id = Column(Integer, primary_key=True)
    pump_id = Column(String(50), nullable=False)  # 泵型号ID
    device_id = Column(Integer, ForeignKey('devices.id'))  # 关联具体设备（可选）
    
    # 运行时间
    operating_hours = Column(Float, nullable=False)  # 运行小时数
    operating_days = Column(Integer)                 # 运行天数
    
    # 磨损指标
    wear_percentage = Column(Float, default=0)       # 总体磨损百分比
    impeller_wear = Column(Float)                    # 叶轮磨损
    bearing_wear = Column(Float)                     # 轴承磨损
    seal_wear = Column(Float)                        # 密封磨损
    shaft_wear = Column(Float)                       # 轴磨损
    
    # 性能衰减
    efficiency_degradation = Column(Float)           # 效率衰减百分比
    head_reduction = Column(Float)                   # 扬程降低百分比
    flow_reduction = Column(Float)                   # 流量降低百分比
    power_increase = Column(Float)                   # 功率增加百分比
    
    # 运行条件
    average_flow_rate = Column(Float)                # 平均流量
    average_head = Column(Float)                     # 平均扬程
    average_frequency = Column(Float)                # 平均频率
    fluid_viscosity = Column(Float)                  # 流体粘度
    fluid_density = Column(Float)                    # 流体密度
    temperature = Column(Float)                      # 运行温度
    
    # 维护记录
    last_maintenance_date = Column(DateTime)         # 最后维护日期
    maintenance_type = Column(String(50))            # 维护类型
    parts_replaced = Column(Text)                    # 更换部件（JSON）
    
    # 数据来源
    data_source = Column(String(100))                # 数据来源
    measurement_method = Column(String(50))          # 测量方法
    data_quality = Column(String(20), default='good')  # 数据质量
    
    # 时间戳
    recorded_at = Column(DateTime, default=datetime.now)
    created_at = Column(DateTime, default=datetime.now)

    # 创建索引
    __table_args__ = (
        Index('idx_wear_pump_hours', 'pump_id', 'operating_hours'),
        Index('idx_wear_recorded', 'recorded_at'),
    )

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        # 解析零部件更换记录
        parts_replaced = None
        if self.parts_replaced:
            try:
                parts_replaced = json.loads(self.parts_replaced)
            except:
                parts_replaced = self.parts_replaced

        return {
            'id': self.id,
            'pump_id': self.pump_id,
            'device_id': self.device_id,
            'operating_hours': self.operating_hours,
            'operating_days': self.operating_days,
            'wear_percentage': self.wear_percentage,
            'impeller_wear': self.impeller_wear,
            'bearing_wear': self.bearing_wear,
            'seal_wear': self.seal_wear,
            'shaft_wear': self.shaft_wear,
            'efficiency_degradation': self.efficiency_degradation,
            'head_reduction': self.head_reduction,
            'flow_reduction': self.flow_reduction,
            'power_increase': self.power_increase,
            'average_flow_rate': self.average_flow_rate,
            'average_head': self.average_head,
            'average_frequency': self.average_frequency,
            'fluid_viscosity': self.fluid_viscosity,
            'fluid_density': self.fluid_density,
            'temperature': self.temperature,
            'last_maintenance_date': self.last_maintenance_date.isoformat() if self.last_maintenance_date else None,
            'maintenance_type': self.maintenance_type,
            'parts_replaced': parts_replaced,
            'data_source': self.data_source,
            'measurement_method': self.measurement_method,
            'data_quality': self.data_quality,
            'recorded_at': self.recorded_at.isoformat() if self.recorded_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

    def set_parts_replaced(self, parts_list: List[str]):
        """设置更换部件列表"""
        self.parts_replaced = json.dumps(parts_list)

    def get_parts_replaced(self) -> List[str]:
        """获取更换部件列表"""
        if self.parts_replaced:
            try:
                return json.loads(self.parts_replaced)
            except:
                return [self.parts_replaced]
        return []


class MaintenanceRecord(Base):
    """维护记录表"""
    __tablename__ = 'maintenance_records'

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey('devices.id'), nullable=False)
    pump_id = Column(String(50), nullable=False)
    
    # 维护基本信息
    maintenance_date = Column(DateTime, nullable=False)
    maintenance_type = Column(String(50), nullable=False)  # preventive, corrective, emergency
    maintenance_category = Column(String(50))             # inspection, repair, replacement, overhaul
    
    # 维护内容
    work_description = Column(Text)                       # 工作描述
    parts_replaced = Column(Text)                         # 更换部件（JSON）
    parts_cost = Column(Float)                           # 部件成本
    labor_hours = Column(Float)                          # 工时
    labor_cost = Column(Float)                           # 人工成本
    total_cost = Column(Float)                           # 总成本
    
    # 维护前后状态
    condition_before = Column(Text)                       # 维护前状态
    condition_after = Column(Text)                        # 维护后状态
    performance_improvement = Column(Text)                # 性能改善情况
    
    # 停机信息
    downtime_hours = Column(Float)                        # 停机时间（小时）
    production_loss = Column(Float)                       # 生产损失
    
    # 维护人员
    technician_name = Column(String(100))                # 技术员姓名
    supervisor_name = Column(String(100))                # 监督员姓名
    maintenance_company = Column(String(100))            # 维护公司
    
    # 质量评估
    maintenance_quality = Column(String(20))              # excellent, good, satisfactory, poor
    effectiveness_rating = Column(Integer)                # 有效性评分 1-10
    
    # 下次维护预测
    next_maintenance_due = Column(DateTime)               # 下次维护到期日
    next_maintenance_hours = Column(Float)                # 下次维护运行小时数
    
    # 文档和备注
    work_order_number = Column(String(50))               # 工单号
    documentation_path = Column(String(200))             # 文档路径
    photos_path = Column(String(200))                    # 照片路径
    notes = Column(Text)                                 # 备注
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 创建索引
    __table_args__ = (
        Index('idx_maintenance_device_date', 'device_id', 'maintenance_date'),
        Index('idx_maintenance_type', 'maintenance_type'),
        Index('idx_maintenance_due', 'next_maintenance_due'),
    )

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        # 解析JSON字段
        def safe_json_loads(json_str):
            if json_str:
                try:
                    return json.loads(json_str)
                except:
                    return json_str
            return None

        return {
            'id': self.id,
            'device_id': self.device_id,
            'pump_id': self.pump_id,
            'maintenance_date': self.maintenance_date.isoformat() if self.maintenance_date else None,
            'maintenance_type': self.maintenance_type,
            'maintenance_category': self.maintenance_category,
            'work_description': self.work_description,
            'parts_replaced': safe_json_loads(self.parts_replaced),
            'parts_cost': self.parts_cost,
            'labor_hours': self.labor_hours,
            'labor_cost': self.labor_cost,
            'total_cost': self.total_cost,
            'condition_before': self.condition_before,
            'condition_after': self.condition_after,
            'performance_improvement': self.performance_improvement,
            'downtime_hours': self.downtime_hours,
            'production_loss': self.production_loss,
            'technician_name': self.technician_name,
            'supervisor_name': self.supervisor_name,
            'maintenance_company': self.maintenance_company,
            'maintenance_quality': self.maintenance_quality,
            'effectiveness_rating': self.effectiveness_rating,
            'next_maintenance_due': self.next_maintenance_due.isoformat() if self.next_maintenance_due else None,
            'next_maintenance_hours': self.next_maintenance_hours,
            'work_order_number': self.work_order_number,
            'documentation_path': self.documentation_path,
            'photos_path': self.photos_path,
            'notes': self.notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }