# DataManage/models/pump_performance.py

from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean, Text, Index
from sqlalchemy.orm import relationship
from datetime import datetime
from typing import Dict, List, Any

from .base import Base


class PumpCurveData(Base):
    """泵性能曲线数据表"""
    __tablename__ = 'pump_curve_data'

    id = Column(Integer, primary_key=True)
    pump_id = Column(String(50), nullable=False)  # 泵型号ID，关联到设备表的model字段
    flow_rate = Column(Float, nullable=False)     # 流量 (m³/d)
    head = Column(Float, nullable=False)          # 扬程 (m)
    power = Column(Float, nullable=False)         # 功率 (kW)
    efficiency = Column(Float, nullable=False)    # 效率 (%)
    standard_frequency = Column(Float, default=60.0)  # 标准频率 (Hz)
    
    # 数据来源和版本控制
    data_source = Column(String(100))            # 数据来源（厂商、测试等）
    version = Column(String(20), default='1.0')  # 数据版本
    is_active = Column(Boolean, default=True)    # 是否为活跃版本
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 创建复合索引提高查询性能
    __table_args__ = (
        Index('idx_pump_flow', 'pump_id', 'flow_rate'),
        Index('idx_pump_active', 'pump_id', 'is_active'),
    )

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'pump_id': self.pump_id,
            'flow_rate': self.flow_rate,
            'head': self.head,
            'power': self.power,
            'efficiency': self.efficiency,
            'standard_frequency': self.standard_frequency,
            'data_source': self.data_source,
            'version': self.version,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class PumpEnhancedParameters(Base):
    """泵增强性能参数表"""
    __tablename__ = 'pump_enhanced_parameters'

    id = Column(Integer, primary_key=True)
    pump_id = Column(String(50), nullable=False)  # 泵型号ID
    flow_point = Column(Float, nullable=False)    # 对应的流量点 (m³/d)
    
    # 核心增强参数
    npsh_required = Column(Float)                 # NPSH要求 (m)
    temperature_rise = Column(Float)              # 温升 (°C)
    vibration_level = Column(Float)               # 振动水平 (mm/s)
    noise_level = Column(Float)                   # 噪音水平 (dB)
    wear_rate = Column(Float)                     # 磨损率 (%/年)
    
    # 高级工程参数（可选）
    radial_load = Column(Float)                   # 径向载荷 (N)
    axial_thrust = Column(Float)                  # 轴向推力 (N)
    material_stress = Column(Float)               # 材料应力 (MPa)
    energy_efficiency_ratio = Column(Float)      # 能效比
    cavitation_margin = Column(Float)             # 空化余量 (m)
    stability_score = Column(Float)               # 稳定性评分 (0-100)
    
    # 数据质量和来源
    data_quality = Column(String(20), default='estimated')  # measured, calculated, estimated
    measurement_date = Column(DateTime)           # 测量日期
    notes = Column(Text)                          # 备注说明
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 创建索引
    __table_args__ = (
        Index('idx_enhanced_pump_flow', 'pump_id', 'flow_point'),
    )

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'pump_id': self.pump_id,
            'flow_point': self.flow_point,
            'npsh_required': self.npsh_required,
            'temperature_rise': self.temperature_rise,
            'vibration_level': self.vibration_level,
            'noise_level': self.noise_level,
            'wear_rate': self.wear_rate,
            'radial_load': self.radial_load,
            'axial_thrust': self.axial_thrust,
            'material_stress': self.material_stress,
            'energy_efficiency_ratio': self.energy_efficiency_ratio,
            'cavitation_margin': self.cavitation_margin,
            'stability_score': self.stability_score,
            'data_quality': self.data_quality,
            'measurement_date': self.measurement_date.isoformat() if self.measurement_date else None,
            'notes': self.notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class PumpOperatingPoint(Base):
    """泵运行工况点表"""
    __tablename__ = 'pump_operating_points'

    id = Column(Integer, primary_key=True)
    pump_id = Column(String(50), nullable=False)  # 泵型号ID
    point_name = Column(String(100), nullable=False)  # 工况点名称（如BEP、MinFlow等）
    point_type = Column(String(50), nullable=False)   # 点类型：BEP, MIN_FLOW, MAX_FLOW, SHUTOFF
    
    # 工况点参数
    flow_rate = Column(Float, nullable=False)     # 流量 (m³/d)
    head = Column(Float, nullable=False)          # 扬程 (m)
    power = Column(Float, nullable=False)         # 功率 (kW)
    efficiency = Column(Float, nullable=False)    # 效率 (%)
    
    # 运行范围定义
    flow_min = Column(Float)                      # 建议最小流量 (m³/d)
    flow_max = Column(Float)                      # 建议最大流量 (m³/d)
    
    # 工况评估
    performance_rating = Column(String(20))       # 性能评级：optimal, good, acceptable, poor
    operation_notes = Column(Text)                # 运行注意事项
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 创建索引
    __table_args__ = (
        Index('idx_operating_point_pump', 'pump_id', 'point_type'),
    )

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'pump_id': self.pump_id,
            'point_name': self.point_name,
            'point_type': self.point_type,
            'flow_rate': self.flow_rate,
            'head': self.head,
            'power': self.power,
            'efficiency': self.efficiency,
            'flow_min': self.flow_min,
            'flow_max': self.flow_max,
            'performance_rating': self.performance_rating,
            'operation_notes': self.operation_notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class PumpSystemCurve(Base):
    """系统特性曲线表"""
    __tablename__ = 'pump_system_curves'

    id = Column(Integer, primary_key=True)
    curve_name = Column(String(100), nullable=False)  # 曲线名称
    project_id = Column(Integer)                      # 关联项目ID（可选）
    well_id = Column(Integer)                         # 关联井ID（可选）
    
    # 系统参数
    static_head = Column(Float, nullable=False)       # 静扬程 (m)
    friction_coefficient = Column(Float, nullable=False)  # 摩阻系数
    
    # 系统曲线点数据（可以存储为JSON或单独表）
    curve_points = Column(Text)                       # JSON格式存储曲线点
    
    # 计算参数
    pipe_diameter = Column(Float)                     # 管径 (mm)
    pipe_length = Column(Float)                       # 管长 (m)
    pipe_roughness = Column(Float)                    # 管壁粗糙度 (mm)
    
    # 元数据
    calculation_method = Column(String(50))           # 计算方法
    created_by = Column(String(50))                   # 创建者
    description = Column(Text)                        # 描述
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'curve_name': self.curve_name,
            'project_id': self.project_id,
            'well_id': self.well_id,
            'static_head': self.static_head,
            'friction_coefficient': self.friction_coefficient,
            'curve_points': self.curve_points,
            'pipe_diameter': self.pipe_diameter,
            'pipe_length': self.pipe_length,
            'pipe_roughness': self.pipe_roughness,
            'calculation_method': self.calculation_method,
            'created_by': self.created_by,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }