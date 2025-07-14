# DataManage/models/production_parameters.py

from datetime import datetime
from typing import Dict, Any, Optional

from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime, Text, String, Boolean
from sqlalchemy.orm import relationship

from .base import Base


class ProductionParameters(Base):
    """生产参数模型"""
    __tablename__ = 'production_parameters'
    
    id = Column(Integer, primary_key=True)
    well_id = Column(Integer, ForeignKey('wells_new.id', ondelete='CASCADE'), nullable=False)
    
    # 基础生产参数
    geo_pressure = Column(Float, comment='地层压力 (psi)')  # Pr
    expected_production = Column(Float, comment='期望产量 (bbl/d)')  # QF
    saturation_pressure = Column(Float, comment='饱和压力/泡点压力 (psi)')  # Pb
    produce_index = Column(Float, comment='生产指数 (bbl/d/psi)')  # IP/PI
    bht = Column(Float, comment='井底温度 (°F)')  # Bottom Hole Temperature
    bsw = Column(Float, comment='含水率 (小数)')  # Basic Sediment & Water
    api = Column(Float, comment='原油API重度 (°API)')  # API Gravity
    gas_oil_ratio = Column(Float, comment='油气比 (scf/bbl)')  # GOR
    well_head_pressure = Column(Float, comment='井口压力 (psi)')  # WHP
    
    # 元数据
    parameter_name = Column(String(100), comment='参数集名称')
    description = Column(Text, comment='备注说明')
    is_active = Column(Boolean, default=True, comment='是否为当前活跃参数')
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    created_by = Column(String(50), comment='创建人')
    
    # 关系定义
    well = relationship("WellModel", back_populates="production_parameters")
    predictions = relationship("ProductionPrediction", back_populates="parameters", cascade="all, delete-orphan")
    # selection_sessions = relationship("DeviceSelectionSession", back_populates="production_parameters", cascade="all, delete-orphan")
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'well_id': self.well_id,
            'geo_pressure': self.geo_pressure,
            'expected_production': self.expected_production,
            'saturation_pressure': self.saturation_pressure,
            'produce_index': self.produce_index,
            'bht': self.bht,
            'bsw': self.bsw,
            'api': self.api,
            'gas_oil_ratio': self.gas_oil_ratio,
            'well_head_pressure': self.well_head_pressure,
            'parameter_name': self.parameter_name,
            'description': self.description,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by
        }
    
    def validate(self) -> tuple[bool, Optional[str]]:
        """验证参数的合理性"""
        # 基础非空验证
        required_fields = [
            ('geo_pressure', '地层压力'),
            ('expected_production', '期望产量'),
            ('produce_index', '生产指数'),
            ('bht', '井底温度'),
            ('bsw', '含水率'),
            ('api', 'API重度'),
            ('gas_oil_ratio', '油气比'),
            ('well_head_pressure', '井口压力')
        ]
        
        for field, name in required_fields:
            if getattr(self, field) is None:
                return False, f"{name}不能为空"
        
        # 数值范围验证
        if self.geo_pressure <= 0:
            return False, "地层压力必须大于0"
        
        if self.expected_production <= 0:
            return False, "期望产量必须大于0"
        
        if self.produce_index <= 0:
            return False, "生产指数必须大于0"
        
        if not (0 <= self.bsw <= 1):
            return False, "含水率必须在0-1之间"
        
        if not (0 < self.api < 100):
            return False, "API重度必须在0-100之间"
        
        if self.gas_oil_ratio < 0:
            return False, "油气比不能为负数"
        
        if self.well_head_pressure < 0:
            return False, "井口压力不能为负数"
        
        # 逻辑关系验证
        if self.saturation_pressure and self.saturation_pressure > self.geo_pressure:
            return False, "饱和压力不能大于地层压力"
        
        if self.well_head_pressure > self.geo_pressure:
            return False, "井口压力不能大于地层压力"
        
        return True, None


class ProductionPrediction(Base):
    """生产参数预测结果模型"""
    __tablename__ = 'production_predictions'
    
    id = Column(Integer, primary_key=True)
    parameters_id = Column(Integer, ForeignKey('production_parameters.id', ondelete='CASCADE'), nullable=False)
    
    # 预测结果
    predicted_production = Column(Float, comment='预测产量 (bbl/d)')
    predicted_pump_depth = Column(Float, comment='预测泵挂深度 (ft)')
    predicted_gas_rate = Column(Float, comment='预测吸入口气液比')
    
    # 经验公式计算结果
    empirical_pump_depth = Column(Float, comment='经验公式泵挂深度 (ft)')
    empirical_gas_rate = Column(Float, comment='经验公式气液比')
    
    # 预测方法和置信度
    prediction_method = Column(String(50), comment='预测方法 (ML/NN/Empirical)')
    confidence_score = Column(Float, comment='预测置信度 (0-1)')
    
    # IPR曲线数据（JSON格式存储）
    ipr_curve_data = Column(Text, comment='IPR曲线数据点')
    
    created_at = Column(DateTime, default=datetime.now)
    
    # 关系定义
    parameters = relationship("ProductionParameters", back_populates="predictions")
    
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'parameters_id': self.parameters_id,
            'predicted_production': self.predicted_production,
            'predicted_pump_depth': self.predicted_pump_depth,
            'predicted_gas_rate': self.predicted_gas_rate,
            'empirical_pump_depth': self.empirical_pump_depth,
            'empirical_gas_rate': self.empirical_gas_rate,
            'prediction_method': self.prediction_method,
            'confidence_score': self.confidence_score,
            'ipr_curve_data': self.ipr_curve_data,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }