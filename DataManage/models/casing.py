# DataManage/models/casing.py

from sqlalchemy import Column, Integer, Float, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from typing import Dict, Any

from DataManage.models.base import Base

class Casing(Base):
    """套管数据模型"""
    __tablename__ = 'casings'

    id = Column(Integer, primary_key=True, autoincrement=True)
    well_id = Column(Integer, ForeignKey('wells_new.id', ondelete='CASCADE'), nullable=False)

    # 套管基本信息
    casing_type = Column(String(100))  # 套管类型：表层套管、技术套管、生产套管等
    casing_size = Column(String(50))   # 套管尺寸规格

    # 深度信息
    top_depth = Column(Float)          # 顶深 (m)
    bottom_depth = Column(Float)       # 底深 (m)
    top_tvd = Column(Float)           # 顶部垂深 (m)
    bottom_tvd = Column(Float)        # 底部垂深 (m)

    # 尺寸信息
    inner_diameter = Column(Float)     # 内径 (mm)
    outer_diameter = Column(Float)     # 外径 (mm)
    wall_thickness = Column(Float)     # 壁厚 (mm)
    roughness = Column(Float)          # 粗糙度

    # 材质和等级
    material = Column(String(100))     # 材质
    grade = Column(String(50))         # 钢级
    weight = Column(Float)             # 单位重量 (kg/m)

    # 其他信息
    manufacturer = Column(String(200)) # 制造商
    installation_date = Column(DateTime)  # 安装日期
    notes = Column(String(500))        # 备注

    # 元数据
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    is_deleted = Column(Boolean, default=False)

    # 关系
    well = relationship("WellModel", back_populates="casings")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'well_id': self.well_id,
            'casing_type': self.casing_type,
            'casing_size': self.casing_size,
            'top_depth': self.top_depth,
            'bottom_depth': self.bottom_depth,
            'top_tvd': self.top_tvd,
            'bottom_tvd': self.bottom_tvd,
            'inner_diameter': self.inner_diameter,
            'outer_diameter': self.outer_diameter,
            'wall_thickness': self.wall_thickness,
            'roughness': self.roughness,
            'material': self.material,
            'grade': self.grade,
            'weight': self.weight,
            'manufacturer': self.manufacturer,
            'installation_date': self.installation_date.isoformat() if self.installation_date else None,
            'notes': self.notes,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class WellCalculationResult(Base):
    """井计算结果模型"""
    __tablename__ = 'well_calculation_results'

    id = Column(Integer, primary_key=True, autoincrement=True)
    well_id = Column(Integer, ForeignKey('wells_new.id', ondelete='CASCADE'), nullable=False)

    # 计算结果
    pump_hanging_depth = Column(Float)     # 泵挂垂深 (m)
    perforation_depth = Column(Float)      # 射孔垂深 (m)

    # 计算参数（记录计算时使用的参数）
    calculation_date = Column(DateTime, default=datetime.now)
    calculation_method = Column(String(100))  # 计算方法
    parameters = Column(String(1000))         # JSON格式的计算参数

    # 其他计算结果
    total_depth_tvd = Column(Float)           # 总垂深
    total_depth_md = Column(Float)            # 总测深
    max_inclination = Column(Float)           # 最大井斜角
    max_dls = Column(Float)                   # 最大狗腿度

    # 元数据
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 关系
    well = relationship("WellModel", back_populates="calculation_results")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'well_id': self.well_id,
            'pump_hanging_depth': self.pump_hanging_depth,
            'perforation_depth': self.perforation_depth,
            'calculation_date': self.calculation_date.isoformat() if self.calculation_date else None,
            'calculation_method': self.calculation_method,
            'parameters': self.parameters,
            'total_depth_tvd': self.total_depth_tvd,
            'total_depth_md': self.total_depth_md,
            'max_inclination': self.max_inclination,
            'max_dls': self.max_dls,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
