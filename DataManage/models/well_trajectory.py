# DataManage/models/well_trajectory.py

from sqlalchemy import Column, Integer, Float, ForeignKey, DateTime, Boolean, String
from sqlalchemy.orm import relationship
from datetime import datetime
from typing import Dict, Any

from DataManage.models.base import Base

class WellTrajectory(Base):
    """井轨迹数据模型"""
    __tablename__ = 'well_trajectories'

    id = Column(Integer, primary_key=True, autoincrement=True)
    well_id = Column(Integer, ForeignKey('wells_new.id', ondelete='CASCADE'), nullable=False)
    sequence_number = Column(Integer, nullable=False)  # 数据序号，保证顺序
    tvd = Column(Float, nullable=False)  # True Vertical Depth 垂深
    md = Column(Float, nullable=False)   # Measured Depth 测深
    dls = Column(Float)                  # Dog Leg Severity 狗腿度

    # 可选的额外字段
    inclination = Column(Float)          # 井斜角
    azimuth = Column(Float)              # 方位角
    north_south = Column(Float)          # 南北坐标
    east_west = Column(Float)            # 东西坐标

    # 元数据
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    is_deleted = Column(Boolean, default=False)

    # 关系
    well = relationship("WellModel", back_populates="trajectories")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'well_id': self.well_id,
            'sequence_number': self.sequence_number,
            'tvd': self.tvd,
            'md': self.md,
            'dls': self.dls,
            'inclination': self.inclination,
            'azimuth': self.azimuth,
            'north_south': self.north_south,
            'east_west': self.east_west,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class WellTrajectoryImport(Base):
    """井轨迹导入记录"""
    __tablename__ = 'well_trajectory_imports'

    id = Column(Integer, primary_key=True, autoincrement=True)
    well_id = Column(Integer, ForeignKey('wells_new.id', ondelete='CASCADE'), nullable=False)
    file_name = Column(String(255))
    import_date = Column(DateTime, default=datetime.now)
    row_count = Column(Integer)
    status = Column(String(50))  # 'success', 'failed', 'partial'
    error_message = Column(String(500))
    imported_by = Column(String(100))

    # 关系
    well = relationship("WellModel")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'well_id': self.well_id,
            'file_name': self.file_name,
            'import_date': self.import_date.isoformat() if self.import_date else None,
            'row_count': self.row_count,
            'status': self.status,
            'error_message': self.error_message,
            'imported_by': self.imported_by
        }
