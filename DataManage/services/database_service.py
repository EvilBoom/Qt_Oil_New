# DataManage/services/database_service.py

import os
import json
from pathlib import Path
import logging
from datetime import datetime
from typing import List, Dict, Optional, Any, Type

from sqlalchemy import create_engine, Column, Integer, String, Float, ForeignKey, DateTime, Boolean, Text
from sqlalchemy.orm import sessionmaker, relationship, Session, scoped_session
from sqlalchemy.pool import QueuePool

from PySide6.QtCore import QObject, Signal, Slot

# 从配置文件导入数据库配置
from ..config.database_config import get_config, DatabaseConfig

from DataManage.models.base import Base

# 导入新的模型类
from DataManage.models.well_trajectory import WellTrajectory, WellTrajectoryImport
from DataManage.models.casing import Casing, WellCalculationResult
from DataManage.models.device import (
    Device, DeviceType, DevicePump, DeviceMotor,
    DeviceProtector, DeviceSeparator, MotorFrequencyParam, LiftMethod
)
from DataManage.models.production_parameters import ProductionParameters, ProductionPrediction
   # 在现有导入部分添加新模型
from DataManage.models.pump_performance import (
        PumpCurveData, PumpEnhancedParameters, 
        PumpOperatingPoint, PumpSystemCurve
)
# 在 database_service.py 的导入部分添加新模型
from DataManage.models.performance_prediction import (
    DevicePerformancePrediction, PumpWearData, MaintenanceRecord
)
from DataManage.models.condition_comparison import (
    PumpConditionComparison, ConditionOptimization
)

# 创建日志记录器
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)



# 定义SQLAlchemy模型
class ProjectModel(Base):
    """项目数据模型"""
    __tablename__ = 'projects'

    id = Column(Integer, primary_key=True)
    project_name = Column(String(100), nullable=False, unique=True)
    user_name = Column(String(50), nullable=False)
    company_name = Column(String(100))
    well_name = Column(String(100))
    oil_name = Column(String(50))
    location = Column(String(200))
    ps = Column(Text)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

    # 关系定义
    # well_data = relationship("WellModel", back_populates="project", uselist=False, cascade="all, delete-orphan")
    wells = relationship("WellModel", back_populates="project", cascade="all, delete-orphan")
    reservoir_data = relationship("ReservoirModel", back_populates="project", uselist=False, cascade="all, delete-orphan")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'project_name': self.project_name,
            'user_name': self.user_name,
            'company_name': self.company_name,
            'well_name': self.well_name,
            'oil_name': self.oil_name,
            'location': self.location,
            'ps': self.ps,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


class WellModel(Base):
    """井数据模型 - 支持一个项目多个井"""
    __tablename__ = 'wells_new'  # 使用新表名避免冲突

    id = Column(Integer, primary_key=True)
    project_id = Column(Integer, ForeignKey('projects.id', ondelete='CASCADE'), nullable=False)
    well_name = Column(String(100), nullable=False)  # 新增井名字段
    well_md = Column(Float)
    well_tvd = Column(Float)
    well_dls = Column(Float)
    inner_diameter = Column(Float)
    outer_diameter = Column(Float)
    roughness = Column(Float)
    perforation_vertical_depth = Column(Float)
    pump_hanging_vertical_depth = Column(Float)
    pump_depth = Column(Float)  # 新增泵挂深度
    tubing_diameter = Column(Float)  # 新增管径
    well_type = Column(String(50))  # 新增井型
    well_status = Column(String(50))  # 新增井状态
    completion_date = Column(DateTime)  # 新增完井日期
    notes = Column(Text)  # 新增备注
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    is_deleted = Column(Boolean, default=False)  # 软删除标记

    # 关系定义 - 修改为多对一
    project = relationship("ProjectModel", back_populates="wells")
    # 第二个页面井身结构信息：在WellModel类的relationship部分添加：
    trajectories = relationship("WellTrajectory", back_populates="well", cascade="all, delete-orphan", order_by="WellTrajectory.sequence_number")
    casings = relationship("Casing", back_populates="well", cascade="all, delete-orphan")
    calculation_results = relationship("WellCalculationResult", back_populates="well", cascade="all, delete-orphan")
    # 在 database_service.py 的 WellModel 类中添加
    production_parameters = relationship("ProductionParameters", back_populates="well", cascade="all, delete-orphan")

    def to_dict(self) -> Dict[str, Any]:
        result = {
                    'id': self.id,
                    'project_id': self.project_id,
                    'well_name': self.well_name,
                    'well_md': self.well_md,
                    'well_tvd': self.well_tvd,
                    'well_dls': self.well_dls,
                    'inner_diameter': self.inner_diameter,
                    'outer_diameter': self.outer_diameter,
                    'roughness': self.roughness,
                    'perforation_vertical_depth': self.perforation_vertical_depth,
                    'pump_hanging_vertical_depth': self.pump_hanging_vertical_depth,
                    'pump_depth': self.pump_depth,
                    'tubing_diameter': self.tubing_diameter,
                    'well_type': self.well_type,
                    'well_status': self.well_status,
                    'completion_date': self.completion_date.isoformat() if self.completion_date else None,
                    'notes': self.notes,
                    'created_at': self.created_at.isoformat() if self.created_at else None,
                    'updated_at': self.updated_at.isoformat() if self.updated_at else None,
                    'is_deleted': self.is_deleted
        }

        return  result



class ReservoirModel(Base):
    """油藏数据模型"""
    __tablename__ = 'reservoir_data'

    id = Column(Integer, primary_key=True)
    project_id = Column(Integer, ForeignKey('projects.id', ondelete='CASCADE'), nullable=False)
    geo_produce_index = Column(Float)
    expected_production = Column(Float)
    saturation_pressure = Column(Float)
    geo_pressure = Column(Float)
    bht = Column(Float)
    bsw = Column(Float)
    api = Column(Float)
    gas_oil_ratio = Column(Float)
    well_head_pressure = Column(Float)
    created_at = Column(DateTime, default=datetime.now)

    # 关系定义
    project = relationship("ProjectModel", back_populates="reservoir_data")

    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            'id': self.id,
            'project_id': self.project_id,
            'geo_produce_index': self.geo_produce_index,
            'expected_production': self.expected_production,
            'saturation_pressure': self.saturation_pressure,
            'geo_pressure': self.geo_pressure,
            'bht': self.bht,
            'bsw': self.bsw,
            'api': self.api,
            'gas_oil_ratio': self.gas_oil_ratio,
            'well_head_pressure': self.well_head_pressure,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class DatabaseService(QObject):
    """数据库服务类 - 单例模式"""
    _instance = None

    # 定义信号
    projectCreated = Signal(int, str)  # 项目ID, 项目名称
    projectUpdated = Signal(int, str)  # 项目ID, 项目名称
    projectDeleted = Signal(int, str)  # 项目ID, 项目名称
    wellDataSaved = Signal(int)        # 项目ID
    reservoirDataSaved = Signal(int)   # 项目ID
    databaseError = Signal(str)        # 错误消息

    # 井身结构相关信号
    trajectoryDataSaved = Signal(int)         # 井ID - 轨迹数据保存完成
    trajectoryImported = Signal(int, int)     # 井ID, 导入记录数
    casingDataSaved = Signal(int)            # 套管ID
    casingDeleted = Signal(int)              # 套管ID
    calculationCompleted = Signal(int)        # 井ID - 计算完成

    # 设备相关信号
    deviceCreated = Signal(int, str)     # 设备ID, 设备型号
    deviceUpdated = Signal(int, str)     # 设备ID, 设备型号
    deviceDeleted = Signal(int)          # 设备ID
    deviceListUpdated = Signal()         # 设备列表更新

    def __new__(cls, config: Optional[DatabaseConfig] = None):
        if cls._instance is None:
            cls._instance = super(DatabaseService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self, config: Optional[DatabaseConfig] = None):
        if self._initialized:
            return

        super().__init__()

        # 使用提供的配置或默认配置
        self.config = config or get_config()

        # 确保数据库目录存在
        db_dir = os.path.dirname(self.config.db_path)
        if db_dir and not os.path.exists(db_dir):
            os.makedirs(db_dir, exist_ok=True)

        # 创建数据库引擎
        self.engine = create_engine(
            f"sqlite:///{self.config.db_path}",
            echo=self.config.log_level == "DEBUG",
            pool_size=self.config.max_connections,
            max_overflow=self.config.max_connections * 2,
            pool_timeout=self.config.connection_timeout,
            pool_recycle=3600,  # 重连接周期
            connect_args={"check_same_thread": False}  # 允许多线程访问
        )

        # 创建会话工厂
        self.Session = scoped_session(sessionmaker(bind=self.engine))

        # 创建表
        Base.metadata.create_all(self.engine)

        # 🔥 新增：初始化示例泵数据
        self._initialize_sample_pump_data()

        # 设置初始化标志
        self._initialized = True

        logger.info(f"数据库服务初始化完成: {self.config.db_path}")

    def __del__(self):
        """析构函数，关闭数据库连接"""
        if hasattr(self, 'Session'):
            self.Session.remove()

    def get_session(self) -> Session:
        """获取数据库会话"""
        return self.Session()

    def close_session(self, session: Session):
        """关闭会话"""
        if session:
            session.close()

    # 项目相关方法
    def create_project(self, project_data: Dict[str, Any]) -> int:
        """创建新项目"""
        session = self.get_session()
        try:
            # 检查项目名是否已存在
            existing = session.query(ProjectModel).filter_by(
                project_name=project_data.get('project_name')
            ).first()

            if existing:
                raise ValueError(f"项目名已存在: {project_data.get('project_name')}")

            # 创建新项目
            new_project = ProjectModel(**project_data)
            session.add(new_project)
            session.commit()

            # 发射信号
            self.projectCreated.emit(new_project.id, new_project.project_name)

            logger.info(f"创建项目成功: {new_project.project_name}, ID: {new_project.id}")
            return new_project.id

        except Exception as e:
            session.rollback()
            error_msg = f"创建项目失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_project_by_name(self, project_name: str) -> Optional[Dict[str, Any]]:
        """根据项目名获取项目"""
        session = self.get_session()
        try:
            project = session.query(ProjectModel).filter_by(project_name=project_name).first()
            if project:
                return project.to_dict()
            return None

        except Exception as e:
            error_msg = f"获取项目失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    def get_all_projects(self) -> List[Dict[str, Any]]:
        """获取所有项目"""
        session = self.get_session()
        try:
            projects = session.query(ProjectModel).order_by(ProjectModel.created_at.desc()).all()
            return [p.to_dict() for p in projects]

        except Exception as e:
            error_msg = f"获取所有项目失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    def update_project(self, project_id: int, updates: Dict[str, Any]) -> bool:
        """更新项目信息"""
        if not updates:
            return False

        session = self.get_session()
        try:
            project = session.query(ProjectModel).filter_by(id=project_id).first()
            if not project:
                raise ValueError(f"项目不存在: ID {project_id}")

            # 如果更新项目名，检查是否有冲突
            if 'project_name' in updates and updates['project_name'] != project.project_name:
                existing = session.query(ProjectModel).filter_by(
                    project_name=updates['project_name']
                ).first()
                if existing:
                    raise ValueError(f"项目名已存在: {updates['project_name']}")

            # 应用更新
            for key, value in updates.items():
                if hasattr(project, key):
                    setattr(project, key, value)

            session.commit()

            # 发射信号
            self.projectUpdated.emit(project.id, project.project_name)

            logger.info(f"更新项目成功: ID {project_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"更新项目失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def delete_project(self, project_id: int) -> bool:
        """删除项目"""
        session = self.get_session()
        try:
            project = session.query(ProjectModel).filter_by(id=project_id).first()
            if not project:
                raise ValueError(f"项目不存在: ID {project_id}")

            project_name = project.project_name

            session.delete(project)
            session.commit()

            # 发射信号
            self.projectDeleted.emit(project_id, project_name)

            logger.info(f"删除项目成功: ID {project_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"删除项目失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)


        # 在 DatabaseService 类中添加以下井的相关方法

    def create_well(self, well_data: Dict[str, Any]) -> int:
        """创建新井"""
        session = self.get_session()
        try:
            project_id = well_data.get('project_id')
            if not project_id:
                raise ValueError("缺少项目ID")

            # 检查项目是否存在
            project = session.query(ProjectModel).filter_by(id=project_id).first()
            if not project:
                raise ValueError(f"项目不存在: ID {project_id}")

            # 检查井名是否已存在于该项目
            existing = session.query(WellModel).filter_by(
                project_id=project_id,
                well_name=well_data.get('well_name'),
                is_deleted=False
            ).first()

            if existing:
                raise ValueError(f"井名已存在: {well_data.get('well_name')}")

            # 创建新井
            new_well = WellModel(**well_data)
            session.add(new_well)
            session.commit()

            # 发射信号
            self.wellDataSaved.emit(project_id)

            logger.info(f"创建井成功: {new_well.well_name}, ID: {new_well.id}")
            return new_well.id

        except Exception as e:
            session.rollback()
            error_msg = f"创建井失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_wells_by_project(self, project_id: int) -> List[Dict[str, Any]]:
        """获取项目下所有井列表"""
        session = self.get_session()
        try:
            wells = session.query(WellModel).filter_by(
                project_id=project_id,
                is_deleted=False
            ).order_by(WellModel.created_at.desc()).all()

            return [well.to_dict() for well in wells]

        except Exception as e:
            error_msg = f"获取井列表失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    def get_well_by_id(self, well_id: int) -> Optional[Dict[str, Any]]:
        """根据ID获取井信息"""
        session = self.get_session()
        try:
            well = session.query(WellModel).filter_by(
                        id=well_id,
                        is_deleted=False
                    ).first()

            if well:
                return well.to_dict()
            return None

        except Exception as e:
            error_msg = f"获取井信息失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    def update_well(self, well_id: int, updates: Dict[str, Any]) -> bool:
        """更新井信息"""
        if not updates:
            return False

        session = self.get_session()
        try:
            well = session.query(WellModel).filter_by(
                        id=well_id,
                        is_deleted=False
                    ).first()

            if not well:
                raise ValueError(f"井不存在: ID {well_id}")

            # 如果更新井名，检查是否有冲突
            if 'well_name' in updates and updates['well_name'] != well.well_name:
                existing = session.query(WellModel).filter_by(
                            project_id=well.project_id,
                            well_name=updates['well_name'],
                            is_deleted=False
                        ).first()
                if existing:
                    raise ValueError(f"井名已存在: {updates['well_name']}")

            # 应用更新
            for key, value in updates.items():
                if hasattr(well, key) and key not in ['id', 'project_id', 'created_at']:
                    setattr(well, key, value)

            session.commit()

            # 发射信号
            self.wellDataSaved.emit(well.project_id)

            logger.info(f"更新井成功: ID {well_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"更新井失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def delete_well(self, well_id: int) -> bool:
        """删除井（软删除）"""
        session = self.get_session()
        try:
            well = session.query(WellModel).filter_by(
                        id=well_id,
                        is_deleted=False
                    ).first()

            if not well:
                raise ValueError(f"井不存在: ID {well_id}")

            # 软删除
            well.is_deleted = True
            session.commit()

            # 发射信号
            self.wellDataSaved.emit(well.project_id)

            logger.info(f"删除井成功: ID {well_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"删除井失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def search_wells(self, project_id: int, keyword: str) -> List[Dict[str, Any]]:
        """搜索井"""
        session = self.get_session()
        try:
            query = session.query(WellModel).filter(
                        WellModel.project_id == project_id,
                        WellModel.is_deleted == False,
                        WellModel.well_name.like(f"%{keyword}%")
                    )

            wells = query.order_by(WellModel.created_at.desc()).all()
            return [well.to_dict() for well in wells]

        except Exception as e:
            error_msg = f"搜索井失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    # 井数据相关方法
    def save_well_data(self, well_data: Dict[str, Any]) -> int:
        """保存井数据"""
        session = self.get_session()
        try:
            project_id = well_data.get('project_id')
            if not project_id:
                raise ValueError("缺少项目ID")

            # 检查项目是否存在
            project = session.query(ProjectModel).filter_by(id=project_id).first()
            if not project:
                raise ValueError(f"项目不存在: ID {project_id}")

            # 查找现有井数据
            existing = session.query(WellModel).filter_by(project_id=project_id).first()

            if existing:
                # 更新现有数据
                for key, value in well_data.items():
                    if hasattr(existing, key):
                        setattr(existing, key, value)
                well_id = existing.id
            else:
                # 创建新数据
                new_well = WellModel(**well_data)
                session.add(new_well)
                well_id = new_well.id

            session.commit()

            # 发射信号
            self.wellDataSaved.emit(project_id)

            logger.info(f"保存井数据成功: 项目ID {project_id}")
            return well_id

        except Exception as e:
            session.rollback()
            error_msg = f"保存井数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_well_data_by_project(self, project_id: int) -> Optional[Dict[str, Any]]:
        """根据项目ID获取井数据"""
        session = self.get_session()
        try:
            well = session.query(WellModel).filter_by(project_id=project_id).first()
            if well:
                return well.to_dict()
            return None

        except Exception as e:
            error_msg = f"获取井数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    # 油藏数据相关方法
    def save_reservoir_data(self, reservoir_data: Dict[str, Any]) -> int:
        """保存油藏数据"""
        session = self.get_session()
        try:
            project_id = reservoir_data.get('project_id')
            if not project_id:
                raise ValueError("缺少项目ID")

            # 检查项目是否存在
            project = session.query(ProjectModel).filter_by(id=project_id).first()
            if not project:
                raise ValueError(f"项目不存在: ID {project_id}")

            # 查找现有油藏数据
            existing = session.query(ReservoirModel).filter_by(project_id=project_id).first()

            if existing:
                # 更新现有数据
                for key, value in reservoir_data.items():
                    if hasattr(existing, key):
                        setattr(existing, key, value)
                reservoir_id = existing.id
            else:
                # 创建新数据
                new_reservoir = ReservoirModel(**reservoir_data)
                session.add(new_reservoir)
                reservoir_id = new_reservoir.id

            session.commit()

            # 发射信号
            self.reservoirDataSaved.emit(project_id)

            logger.info(f"保存油藏数据成功: 项目ID {project_id}")
            return reservoir_id

        except Exception as e:
            session.rollback()
            error_msg = f"保存油藏数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_reservoir_data_by_project(self, project_id: int) -> Optional[Dict[str, Any]]:
        """根据项目ID获取油藏数据"""
        session = self.get_session()
        try:
            reservoir = session.query(ReservoirModel).filter_by(project_id=project_id).first()
            if reservoir:
                return reservoir.to_dict()
            return None

        except Exception as e:
            error_msg = f"获取油藏数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    # 复杂查询
    def get_project_summary(self, project_id: int) -> Optional[Dict[str, Any]]:
        """获取项目汇总信息"""
        session = self.get_session()
        try:
            project = session.query(ProjectModel).filter_by(id=project_id).first()
            if not project:
                return None

            result = project.to_dict()

            # 获取井数据
            well = session.query(WellModel).filter_by(project_id=project_id).first()
            if well:
                well_dict = well.to_dict()
                # 将井数据添加到结果中，去除重复字段
                for k, v in well_dict.items():
                    if k not in ('id', 'project_id', 'created_at'):
                        result[k] = v

            # 获取油藏数据
            reservoir = session.query(ReservoirModel).filter_by(project_id=project_id).first()
            if reservoir:
                reservoir_dict = reservoir.to_dict()
                # 将油藏数据添加到结果中，去除重复字段
                for k, v in reservoir_dict.items():
                    if k not in ('id', 'project_id', 'created_at'):
                        result[k] = v

            return result

        except Exception as e:
            error_msg = f"获取项目汇总失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    def execute_custom_query(self, query_func, *args, **kwargs):
        """执行自定义查询"""
        session = self.get_session()
        try:
            result = query_func(session, *args, **kwargs)
            return result

        except Exception as e:
            session.rollback()
            error_msg = f"执行自定义查询失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    # 在DatabaseService类中添加以下方法：

    # ========== 井轨迹数据相关方法 ==========
    def save_well_trajectories(self, well_id: int, trajectories: List[Dict[str, Any]]) -> bool:
        """批量保存井轨迹数据"""
        session = self.get_session()
        try:
            # 检查井是否存在
            well = session.query(WellModel).filter_by(id=well_id).first()
            if not well:
                raise ValueError(f"井不存在: ID {well_id}")

            # 删除旧的轨迹数据
            session.query(WellTrajectory).filter_by(well_id=well_id).delete()

            # 批量插入新数据
            for idx, traj_data in enumerate(trajectories):
                trajectory = WellTrajectory(
                        well_id=well_id,
                            sequence_number=idx + 1,
                            tvd=traj_data.get('tvd'),
                            md=traj_data.get('md'),
                            dls=traj_data.get('dls'),
                            inclination=traj_data.get('inclination'),
                            azimuth=traj_data.get('azimuth'),
                            north_south=traj_data.get('north_south'),
                            east_west=traj_data.get('east_west')
                )
                session.add(trajectory)

            session.commit()
            logger.info(f"保存井轨迹数据成功: 井ID {well_id}, 共{len(trajectories)}条记录")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"保存井轨迹数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def get_well_trajectories(self, well_id: int) -> List[Dict[str, Any]]:
        """获取井轨迹数据（修复版本）- 确保QML兼容性"""
        session = self.get_session()
        try:
            trajectories = session.query(WellTrajectory).filter_by(
                        well_id=well_id,
                        is_deleted=False
                    ).order_by(WellTrajectory.sequence_number).all()

            logger.info(f"从数据库获取到 {len(trajectories)} 条轨迹记录")

            # 转换为字典并确保所有QML需要的属性都存在
            result = []
            for i, traj in enumerate(trajectories):
                traj_dict = traj.to_dict()
                
                # 为QML添加缺失的属性（这些可能是套管相关的字段，但QML错误地期望它们）
                # 设置为None或合适的默认值，让QML能够创建角色
                missing_fields = {
                    'bottom_tvd': traj_dict.get('tvd', 0),  # 使用当前TVD作为底深
                    'top_tvd': traj_dict.get('tvd', 0),     # 使用当前TVD作为顶深
                    'grade': 'Standard',                     # 默认等级
                    'installation_date': None,              # 安装日期
                    'manufacturer': 'Unknown',              # 制造商
                    'material': 'Steel',                    # 材料
                    'notes': '',                            # 备注
                    'roughness': 0.0046,                   # 默认粗糙度
                    'wall_thickness': 0.0,                 # 壁厚
                    'weight': 0.0                          # 重量
                }
                
                # 添加缺失字段
                for field, default_value in missing_fields.items():
                    if field not in traj_dict or traj_dict[field] is None:
                        traj_dict[field] = default_value
                
                # 确保数值字段不为None，避免计算错误
                numeric_fields = ['tvd', 'md', 'dls', 'inclination', 'azimuth', 'north_south', 'east_west']
                for field in numeric_fields:
                    if field in traj_dict:
                        value = traj_dict[field]
                        if value is None or value == '':
                            traj_dict[field] = 0.0
                        else:
                            try:
                                traj_dict[field] = float(value)
                            except (ValueError, TypeError):
                                traj_dict[field] = 0.0
                
                result.append(traj_dict)
                logger.debug(f"轨迹记录 {i}: TVD={traj_dict['tvd']}, MD={traj_dict['md']}")

            logger.info(f"处理完成，返回 {len(result)} 条有效记录")
            return result

        except Exception as e:
            error_msg = f"获取井轨迹数据失败: {str(e)}"
            logger.error(error_msg)
            import traceback
            traceback.print_exc()
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    def save_trajectory_import_record(self, import_data: Dict[str, Any]) -> int:
        """保存轨迹导入记录"""
        session = self.get_session()
        try:
            import_record = WellTrajectoryImport(**import_data)
            session.add(import_record)
            session.commit()

            logger.info(f"保存导入记录成功: {import_data.get('file_name')}")
            return import_record.id

        except Exception as e:
            session.rollback()
            error_msg = f"保存导入记录失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    # ========== 套管数据相关方法 ==========
    def save_casing(self, casing_data: Dict[str, Any]) -> int:
        """保存套管数据（修复版本）"""
        session = self.get_session()
        try:
            logger.info(f"开始保存套管数据: {casing_data}")
            
            # 检查是否已存在
            casing_id = casing_data.get('id')
            if casing_id:
                casing = session.query(Casing).filter_by(id=casing_id).first()
                if casing:
                    # 更新现有记录
                    for key, value in casing_data.items():
                        if hasattr(casing, key) and key != 'id':
                            setattr(casing, key, value)
                    logger.info(f"更新套管数据: ID {casing_id}")
                else:
                    raise ValueError(f"套管不存在: ID {casing_id}")
            else:
                # 创建新套管
                # 验证well_id
                well_id = casing_data.get('well_id')
                if not well_id:
                    raise ValueError("缺少井ID")
                    
                # 检查井是否存在
                well = session.query(WellModel).filter_by(id=well_id, is_deleted=False).first()
                if not well:
                    raise ValueError(f"井不存在或已删除: ID {well_id}")
                
                # 移除不属于Casing模型的字段
                valid_fields = {
                    'well_id', 'casing_type', 'casing_size', 'top_depth', 'bottom_depth',
                    'top_tvd', 'bottom_tvd', 'inner_diameter', 'outer_diameter',
                    'wall_thickness', 'roughness', 'material', 'grade', 'weight',
                    'manufacturer', 'installation_date', 'notes'
                }
                
                filtered_data = {k: v for k, v in casing_data.items() if k in valid_fields}
                logger.info(f"过滤后的套管数据: {filtered_data}")
                
                casing = Casing(**filtered_data)
                session.add(casing)
                logger.info("创建新套管记录")

            session.commit()
            
            # 发射信号
            self.casingDataSaved.emit(casing.id)
            
            logger.info(f"保存套管数据成功: ID {casing.id}")
            return casing.id

        except Exception as e:
            session.rollback()
            error_msg = f"保存套管数据失败: {str(e)}"
            logger.error(error_msg)
            import traceback
            traceback.print_exc()
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_casings_by_well(self, well_id: int) -> List[Dict[str, Any]]:
        """获取井的所有套管数据"""
        session = self.get_session()
        try:
            casings = session.query(Casing).filter_by(
                        well_id=well_id,
                        is_deleted=False
                    ).order_by(Casing.top_depth).all()

            return [casing.to_dict() for casing in casings]

        except Exception as e:
            error_msg = f"获取套管数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    def delete_casing(self, casing_id: int) -> bool:
        """删除套管（软删除）"""
        session = self.get_session()
        try:
            casing = session.query(Casing).filter_by(id=casing_id).first()
            if not casing:
                raise ValueError(f"套管不存在: ID {casing_id}")

            casing.is_deleted = True
            session.commit()

            logger.info(f"删除套管成功: ID {casing_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"删除套管失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    # ========== 计算结果相关方法 ==========
    def save_calculation_result(self, result_data: Dict[str, Any]) -> int:
        """保存计算结果"""
        session = self.get_session()
        try:
            # 检查是否已有计算结果
            well_id = result_data.get('well_id')
            existing = session.query(WellCalculationResult).filter_by(
                        well_id=well_id
                    ).order_by(WellCalculationResult.calculation_date.desc()).first()

            # 创建新的计算结果记录
            result = WellCalculationResult(**result_data)
            session.add(result)
            session.commit()

            logger.info(f"保存计算结果成功: 井ID {well_id}")
            return result.id

        except Exception as e:
            session.rollback()
            error_msg = f"保存计算结果失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_latest_calculation_result(self, well_id: int) -> Optional[Dict[str, Any]]:
        """获取最新的计算结果"""
        session = self.get_session()
        try:
            result = session.query(WellCalculationResult).filter_by(
                        well_id=well_id
                    ).order_by(WellCalculationResult.calculation_date.desc()).first()

            if result:
                return result.to_dict()
            return None

        except Exception as e:
            error_msg = f"获取计算结果失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    def get_calculation_history(self, well_id: int, limit: int = 10) -> List[Dict[str, Any]]:
        """获取计算历史记录"""
        session = self.get_session()
        try:
            results = session.query(WellCalculationResult).filter_by(
                        well_id=well_id
                    ).order_by(
                        WellCalculationResult.calculation_date.desc()
                    ).limit(limit).all()

            return [result.to_dict() for result in results]

        except Exception as e:
            error_msg = f"获取计算历史失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    # ========== 设备管理相关方法 ==========
    def create_device(self, device_data: Dict[str, Any]) -> int:
        """创建新设备"""
        session = self.get_session()
        try:
            # 提取设备类型
            device_type_str = device_data.get('device_type')
            if not device_type_str:
                raise ValueError("缺少设备类型")

            # 转换设备类型
            try:
                device_type = DeviceType(device_type_str)
            except ValueError:
                raise ValueError(f"无效的设备类型: {device_type_str}")

            # 检查序列号是否已存在
            serial_number = device_data.get('serial_number')
            if serial_number:
                existing = session.query(Device).filter_by(
                                serial_number=serial_number,
                                is_deleted=False
                            ).first()
                if existing:
                    raise ValueError(f"序列号已存在: {serial_number}")

            # 创建基础设备记录
            base_device_data = {
                            'device_type': device_type,
                            'manufacturer': device_data.get('manufacturer'),
                            'model': device_data.get('model'),
                            'serial_number': serial_number,
                            'status': device_data.get('status', 'active'),
                            'description': device_data.get('description'),
                            'lift_method': device_data.get('lift_method')
                }

            new_device = Device(**base_device_data)
            session.add(new_device)
            session.flush()  # 获取设备ID

            # 根据设备类型创建详细信息
            if device_type == DeviceType.PUMP:
                pump_data = device_data.get('pump_details', {})
                pump = DevicePump(
                                device_id=new_device.id,
                                impeller_model=pump_data.get('impeller_model'),
                                displacement_min=pump_data.get('displacement_min'),
                                displacement_max=pump_data.get('displacement_max'),
                                single_stage_head=pump_data.get('single_stage_head'),
                                single_stage_power=pump_data.get('single_stage_power'),
                                shaft_diameter=pump_data.get('shaft_diameter'),
                                mounting_height=pump_data.get('mounting_height'),
                                outside_diameter=pump_data.get('outside_diameter'),
                                max_stages=pump_data.get('max_stages'),
                                efficiency=pump_data.get('efficiency')
                            )
                session.add(pump)

            elif device_type == DeviceType.MOTOR:
                motor_data = device_data.get('motor_details', {})
                motor = DeviceMotor(
                                device_id=new_device.id,
                                motor_type=motor_data.get('motor_type'),
                                outside_diameter=motor_data.get('outside_diameter'),
                                length=motor_data.get('length'),
                                weight=motor_data.get('weight'),
                                insulation_class=motor_data.get('insulation_class'),
                                protection_class=motor_data.get('protection_class')
                            )
                session.add(motor)
                session.flush()

                # 添加频率参数
                frequency_params = motor_data.get('frequency_params', [])
                for freq_param in frequency_params:
                    param = MotorFrequencyParam(
                                    motor_id=motor.id,
                                    frequency=freq_param.get('frequency'),
                                    power=freq_param.get('power'),
                                    voltage=freq_param.get('voltage'),
                                    current=freq_param.get('current'),
                                    speed=freq_param.get('speed')
                                )
                    session.add(param)

            elif device_type == DeviceType.PROTECTOR:
                protector_data = device_data.get('protector_details', {})
                protector = DeviceProtector(
                                device_id=new_device.id,
                                outer_diameter=protector_data.get('outer_diameter'),
                                length=protector_data.get('length'),
                                weight=protector_data.get('weight'),
                                thrust_capacity=protector_data.get('thrust_capacity'),
                                seal_type=protector_data.get('seal_type'),
                                max_temperature=protector_data.get('max_temperature')
                            )
                session.add(protector)

            elif device_type == DeviceType.SEPARATOR:
                separator_data = device_data.get('separator_details', {})
                separator = DeviceSeparator(
                    device_id=new_device.id,
                        outer_diameter=separator_data.get('outer_diameter'),
                                length=separator_data.get('length'),
                                weight=separator_data.get('weight'),
                                separation_efficiency=separator_data.get('separation_efficiency'),
                                gas_handling_capacity=separator_data.get('gas_handling_capacity'),
                                liquid_handling_capacity=separator_data.get('liquid_handling_capacity')
                            )
                session.add(separator)

            session.commit()

            # 发射信号
            self.deviceCreated.emit(new_device.id, new_device.model)
            self.deviceListUpdated.emit()

            logger.info(f"创建设备成功: {new_device.model}, ID: {new_device.id}")
            return new_device.id

        except Exception as e:
            session.rollback()
            error_msg = f"创建设备失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise

        finally:
            self.close_session(session)

    def get_devices(self, device_type: Optional[str] = None,
                            status: Optional[str] = None,
                            page: int = 1,
                            page_size: int = 20) -> Dict[str, Any]:
        """获取设备列表（支持分页和筛选）"""
        session = self.get_session()
        try:
            query = session.query(Device).filter_by(is_deleted=False)
        
     
            # 🔥 特别查看是否有SEPARATOR类型
            separator_count = session.query(Device).filter(
                Device.device_type == DeviceType.SEPARATOR,
                Device.is_deleted == False
            ).count()
            logger.info(f"SEPARATOR类型设备数量: {separator_count}")
        
            # 应用筛选条件
            if device_type:
                try:
                    device_type_upper = device_type.upper()
                    if device_type_upper == 'PUMP':
                        dt = DeviceType.PUMP
                    elif device_type_upper == 'MOTOR':
                        dt = DeviceType.MOTOR
                    elif device_type_upper == 'PROTECTOR':
                        dt = DeviceType.PROTECTOR
                    elif device_type_upper == 'SEPARATOR':
                        dt = DeviceType.SEPARATOR
                    else:
                        logger.warning(f"无效的设备类型筛选: {device_type}")
                        dt = None
                    if dt is not None:
                        query = query.filter(Device.device_type == dt)
                        logger.info(f"✅ 设备类型筛选成功: {device_type} -> {dt}")

                except ValueError as e:
                    logger.warning(f"设备类型转换失败: {device_type}, 错误: {e}")

            # 状态筛选
            if status is not None:
                before_status_filter = query.count()
                logger.info(f"状态筛选前设备数量: {before_status_filter}")
            
                query = query.filter(Device.status == status)
                after_status_filter = query.count()
                logger.info(f"状态筛选后设备数量 (精确匹配 '{status}'): {after_status_filter}")

            # 获取总数
            total_count = query.count()
            logger.info(f"获取设备总数 {total_count}")

            # 分页
            offset = (page - 1) * page_size
            devices = query.order_by(Device.created_at.desc())\
                                      .offset(offset)\
                                      .limit(page_size)\
                                      .all()

            # 转换为字典列表
            device_list = []
            for device in devices:
                device_dict = device.to_dict()
                device_list.append(device_dict)
            
            return {
                            'devices': device_list,
                            'total_count': total_count,
                            'page': page,
                            'page_size': page_size,
                            'total_pages': (total_count + page_size - 1) // page_size
                        }

        except Exception as e:
            error_msg = f"获取设备列表失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return {
                            'devices': [],
                            'total_count': 0,
                            'page': 1,
                            'page_size': page_size,
                            'total_pages': 0
                        }

        finally:
            self.close_session(session)

    def get_devices1(self, device_type: Optional[str] = None,
                                status: Optional[str] = None,
                                page: int = 1,
                                page_size: int = 20) -> Dict[str, Any]:
        """获取设备列表（支持分页和筛选）"""
        session = self.get_session()
        try:
            query = session.query(Device).filter_by(is_deleted=False)
            # print("筛选前获取设备总数", query.count())
            # 应用筛选条件
            if device_type:
                try:
                    # 将传入的字符串转换为对应的枚举值
                    device_type_upper = device_type.upper()
                    # 检查是否为有效的设备类型
                    if device_type_upper == 'PUMP':
                        dt = DeviceType.PUMP
                    elif device_type_upper == 'MOTOR':
                        dt = DeviceType.MOTOR
                    elif device_type_upper == 'PROTECTOR':
                        dt = DeviceType.PROTECTOR
                    elif device_type_upper == 'SEPARATOR':
                        dt = DeviceType.SEPARATOR
                    else:
                        logger.warning(f"无效的设备类型筛选: {device_type}")
                        # 🔥 不抛出异常，而是记录警告并继续
                        dt = None
                    if dt is not None:
                        query = query.filter(Device.device_type == dt)
                        logger.info(f"✅ 设备类型筛选成功: {device_type} -> {dt}")


                    # dt = DeviceType(device_type)
                    # print(f"设备类型枚举转换成功: {dt} (值: {dt.value})")
                     # 查看数据库中实际的设备类型
                    # all_device_types = session.query(Device.device_type).distinct().all()
                    # print(f"数据库中存在的设备类型: {[str(dt[0]) for dt in all_device_types]}")
                
                    # query = query.filter(Device.device_type == dt)
                    # after_type_filter = query.count()
                    # print(f"类型筛选后设备数量: {after_type_filter}")
                
                except ValueError:
                    # logger.warning(f"无效的设备类型筛选: {device_type}")
                    logger.warning(f"设备类型转换失败: {device_type}, 错误: {e}")
                    # 继续执行，不过滤设备类型

            if status is not None:
                # 添加调试信息：查看所有设备的状态值
                all_statuses = session.query(Device.status).distinct().all()
                logger.info(f"数据库中所有设备状态值: {[s[0] for s in all_statuses]}")
            
                # 如果传入的是'active'，但数据库中可能存储的是其他值
                # 先尝试精确匹配
                before_status_filter = query.count()
                logger.info(f"状态筛选前设备数量: {before_status_filter}")
            
                query = query.filter(Device.status == status)
                after_status_filter = query.count()
                logger.info(f"状态筛选后设备数量 (精确匹配 '{status}'): {after_status_filter}")
            
                # 🔥 如果精确匹配没有结果，尝试模糊匹配或使用默认逻辑
                if after_status_filter == 0 and before_status_filter > 0:
                    logger.warning(f"精确状态匹配 '{status}' 无结果，尝试其他状态值")
                
                    # 重新构建查询（去掉状态筛选）
                    query = session.query(Device).filter_by(is_deleted=False)
                    if device_type and dt is not None:
                        query = query.filter(Device.device_type == dt)
                
                    # 尝试找到常见的状态值
                    if status.lower() == 'active':
                        # 尝试常见的激活状态值
                        common_active_statuses = ['active', 'Active', 'ACTIVE', 'available', 'Available', 'enabled', 'Enabled']
                        status_filter = Device.status.in_(common_active_statuses)
                        query = query.filter(status_filter)
                    
                        flexible_count = query.count()
                        logger.info(f"灵活状态匹配后设备数量: {flexible_count}")
                    
                        # 如果还是没有，就不筛选状态（显示所有非删除设备）
                        if flexible_count == 0:
                            logger.warning(f"所有状态匹配都无结果，忽略状态筛选")
                            query = session.query(Device).filter_by(is_deleted=False)
                            if device_type and dt is not None:
                                query = query.filter(Device.device_type == dt)

            # 获取总数
            total_count = query.count()
            print("获取设备总数", total_count)
            
            # 🔥 如果仍然没有结果，输出调试信息
            if total_count == 0:
                logger.warning("=== 调试：查看所有设备详情 ===")
                all_devices = session.query(Device).filter_by(is_deleted=False).all()
                for device in all_devices[:5]:  # 只显示前5个
                    logger.warning(f"设备 ID={device.id}: 类型={device.device_type} (类型:{type(device.device_type)}), 状态={device.status}, 型号={device.model}")

            # 如果没有结果，查看一些具体的设备信息
            # if total_count == 0:
            #     print("=== 调试：查看所有设备详情 ===")
            #     all_devices = session.query(Device).filter_by(is_deleted=False).all()
            #     for device in all_devices[:5]:  # 只显示前5个
            #         print(f"设备 ID={device.id}: 类型={device.device_type} (类型:{type(device.device_type)}), 状态={device.status}, 型号={device.model}")


            # 分页
            offset = (page - 1) * page_size
            devices = query.order_by(Device.created_at.desc())\
                                      .offset(offset)\
                                      .limit(page_size)\
                                      .all()

            # 转换为字典列表
            device_list = []
            for device in devices:

                device_dict = device.to_dict()
                device_list.append(device_dict)
            # print("这里是getdevice获取到的数据", device_list)
            return {
                            'devices': device_list,
                            'total_count': total_count,
                            'page': page,
                            'page_size': page_size,
                            'total_pages': (total_count + page_size - 1) // page_size
                        }

        except Exception as e:
            error_msg = f"获取设备列表失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return {
                            'devices': [],
                            'total_count': 0,
                            'page': 1,
                            'page_size': page_size,
                            'total_pages': 0
                        }

        finally:
            self.close_session(session)

    def get_device_by_id(self, device_id: int) -> Optional[Dict[str, Any]]:
        """根据ID获取设备详情"""
        session = self.get_session()
        try:
            device = session.query(Device).filter_by(
                            id=device_id,
                            is_deleted=False
                        ).first()

            if device:
                return device.to_dict()
            return None

        except Exception as e:
            error_msg = f"获取设备详情失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None

        finally:
            self.close_session(session)

    def update_device(self, device_id: int, updates: Dict[str, Any]) -> bool:
        """更新设备信息"""
        if not updates:
            return False

        session = self.get_session()
        try:
            device = session.query(Device).filter_by(
                            id=device_id,
                            is_deleted=False
                        ).first()

            if not device:
                raise ValueError(f"设备不存在: ID {device_id}")

            # 检查序列号唯一性
            if 'serial_number' in updates and updates['serial_number'] != device.serial_number:
                existing = session.query(Device).filter_by(
                                serial_number=updates['serial_number'],
                                is_deleted=False
                            ).first()
                if existing:
                    raise ValueError(f"序列号已存在: {updates['serial_number']}")

            # 更新基础信息
            base_fields = ['manufacturer', 'model', 'serial_number', 'status', 'description']
            for field in base_fields:
                if field in updates:
                    setattr(device, field, updates[field])

            # 更新特定设备信息
            if device.device_type == DeviceType.PUMP and 'pump_details' in updates:
                pump_data = updates['pump_details']
                if device.pump:
                    for key, value in pump_data.items():
                        if hasattr(device.pump, key):
                            setattr(device.pump, key, value)

            elif device.device_type == DeviceType.MOTOR and 'motor_details' in updates:
                motor_data = updates['motor_details']
                if device.motor:
                    # 更新电机基本信息
                    motor_fields = ['motor_type', 'outside_diameter', 'length',
                                               'weight', 'insulation_class', 'protection_class']
                    for field in motor_fields:
                        if field in motor_data:
                            setattr(device.motor, field, motor_data[field])

                    # 更新频率参数
                    if 'frequency_params' in motor_data:
                        # 删除旧的频率参数
                        session.query(MotorFrequencyParam).filter_by(
                                        motor_id=device.motor.id
                                    ).delete()

                        # 添加新的频率参数
                        for freq_param in motor_data['frequency_params']:
                            param = MotorFrequencyParam(
                                            motor_id=device.motor.id,
                                            frequency=freq_param.get('frequency'),
                                            power=freq_param.get('power'),
                                            voltage=freq_param.get('voltage'),
                                            current=freq_param.get('current'),
                                            speed=freq_param.get('speed')
                                        )
                            session.add(param)

            elif device.device_type == DeviceType.PROTECTOR and 'protector_details' in updates:
                protector_data = updates['protector_details']
                if device.protector:
                    for key, value in protector_data.items():
                        if hasattr(device.protector, key):
                            setattr(device.protector, key, value)

            elif device.device_type == DeviceType.SEPARATOR and 'separator_details' in updates:
                separator_data = updates['separator_details']
                if device.separator:
                    for key, value in separator_data.items():
                        if hasattr(device.separator, key):
                            setattr(device.separator, key, value)

            session.commit()

            # 发射信号
            self.deviceUpdated.emit(device.id, device.model)
            self.deviceListUpdated.emit()

            logger.info(f"更新设备成功: ID {device_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"更新设备失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def delete_device(self, device_id: int) -> bool:
        """删除设备（软删除）"""
        session = self.get_session()
        try:
            device = session.query(Device).filter_by(
                            id=device_id,
                            is_deleted=False
                        ).first()

            if not device:
                raise ValueError(f"设备不存在: ID {device_id}")

            # 软删除
            device.is_deleted = True
            session.commit()

            # 发射信号
            self.deviceDeleted.emit(device_id)
            self.deviceListUpdated.emit()

            logger.info(f"删除设备成功: ID {device_id}")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"删除设备失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def search_devices(self, keyword: str, device_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """搜索设备"""
        session = self.get_session()
        try:
            query = session.query(Device).filter(
                Device.is_deleted == False,
                            (Device.model.like(f"%{keyword}%") |
                             Device.manufacturer.like(f"%{keyword}%") |
                             Device.serial_number.like(f"%{keyword}%") |
                             Device.description.like(f"%{keyword}%"))
                        )

            if device_type:
                try:
                    dt = DeviceType(device_type)
                    query = query.filter(Device.device_type == dt)
                except ValueError:
                    pass

            devices = query.order_by(Device.created_at.desc()).all()
            return [device.to_dict() for device in devices]

        except Exception as e:
            error_msg = f"搜索设备失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    def batch_delete_devices(self, device_ids: List[int]) -> bool:
        """批量删除设备"""
        session = self.get_session()
        try:
            # 批量软删除
            session.query(Device).filter(
                            Device.id.in_(device_ids),
                            Device.is_deleted == False
                        ).update({Device.is_deleted: True}, synchronize_session=False)

            session.commit()

            # 发射信号
            for device_id in device_ids:
                self.deviceDeleted.emit(device_id)
            self.deviceListUpdated.emit()

            logger.info(f"批量删除设备成功: 共{len(device_ids)}个")
            return True

        except Exception as e:
            session.rollback()
            error_msg = f"批量删除设备失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

        finally:
            self.close_session(session)

    def get_device_statistics(self) -> Dict[str, Any]:
        """获取设备统计信息"""
        session = self.get_session()
        try:
            # 统计各类型设备数量
            type_stats = {}
            for device_type in DeviceType:
                count = session.query(Device).filter_by(
                                device_type=device_type,
                                is_deleted=False
                            ).count()
                type_stats[device_type.value] = count

            # 统计各状态设备数量
            status_stats = {}
            for status in ['active', 'inactive', 'maintenance']:
                count = session.query(Device).filter_by(
                                status=status,
                                is_deleted=False
                            ).count()
                status_stats[status] = count

            # 获取总数
            total_count = session.query(Device).filter_by(is_deleted=False).count()

            return {
                            'total_count': total_count,
                            'type_statistics': type_stats,
                            'status_statistics': status_stats
                        }

        except Exception as e:
            error_msg = f"获取设备统计失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return {
                            'total_count': 0,
                            'type_statistics': {},
                            'status_statistics': {}
                        }

        finally:
            self.close_session(session)

    def import_devices_from_excel(self, excel_data: List[Dict], device_type: str, is_metric: bool = False):
        """
        从Excel数据导入设备（修复版本 - 支持所有表）
    
        Args:
            excel_data: Excel数据列表
            device_type: 设备类型
            is_metric: 是否为公制单位
        """
        session = self.get_session()
        success_count = 0
        error_list = []

        try:
            # 验证设备类型
            # try:
            #     dt = DeviceType(device_type.upper())
            # except ValueError:
            #     raise ValueError(f"无效的设备类型: {device_type}")

            for idx, row_data in enumerate(excel_data):
                try:
                    # 🔥 根据设备类型处理不同的数据格式
                    if device_type.lower() == 'pump':
                        device_data = self._process_pump_excel_data(row_data, is_metric, idx + 2)
                    elif device_type.lower() == 'motor':
                        device_data = self._process_motor_excel_data(row_data, is_metric, idx + 2)
                    elif device_type.lower() == 'protector':
                        device_data = self._process_protector_excel_data(row_data, is_metric, idx + 2)
                    elif device_type.lower() == 'separator':
                        device_data = self._process_separator_excel_data(row_data, is_metric, idx + 2)
                    else:
                        raise ValueError(f"不支持的设备类型: {device_type}")

                    # 🔥 调用create_device创建设备（会自动创建相关详细表记录）
                    device_id = self.create_device(device_data)
                    if device_id:
                        success_count += 1
                        logger.info(f"导入设备成功: {device_data.get('model', '')} (ID: {device_id})")
                    else:
                        error_list.append({
                            'row': idx + 2,
                            'error': '设备创建失败'
                        })

                except Exception as e:
                    error_list.append({
                        'row': idx + 2,
                        'error': str(e)
                    })
                    logger.error(f"导入第{idx + 2}行失败: {e}")

            return {
                'success_count': success_count,
                'error_count': len(error_list),
                'errors': error_list
            }

        except Exception as e:
            session.rollback()
            logger.error(f"批量导入失败: {e}")
            raise

        finally:
            self.close_session(session)

    def _parse_float(self, value: Any) -> Optional[float]:
        """安全地解析浮点数"""
        if value is None or value == '':
            return None
        try:
            return float(value)
        except (ValueError, TypeError):
            return None

    def _parse_int(self, value: Any) -> Optional[int]:
        """安全地解析整数"""
        if value is None or value == '':
            return None
        try:
            return int(value)
        except (ValueError, TypeError):
            return None

    def export_devices_to_dict(self, device_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """导出设备数据为字典列表（用于Excel导出）"""
        session = self.get_session()
        try:
            query = session.query(Device).filter_by(is_deleted=False)

            if device_type:
               try:
                   dt = DeviceType(device_type)
                   query = query.filter(Device.device_type == dt)
               except ValueError:
                   pass

            devices = query.order_by(Device.created_at.desc()).all()

            export_data = []
            for device in devices:
                # 基础信息
                row = {
                                'manufacturer': device.manufacturer,
                                'model': device.model,
                                'serial_number': device.serial_number,
                                'status': device.status,
                                'description': device.description,
                                'created_at': device.created_at.strftime('%Y-%m-%d %H:%M:%S') if device.created_at else ''
                            }

                # 添加特定设备信息
                if device.device_type == DeviceType.PUMP and device.pump:
                    row.update({
                                    'impeller_model': device.pump.impeller_model,
                                    'displacement_min': device.pump.displacement_min,
                                    'displacement_max': device.pump.displacement_max,
                                    'single_stage_head': device.pump.single_stage_head,
                                    'single_stage_power': device.pump.single_stage_power,
                                    'shaft_diameter': device.pump.shaft_diameter,
                                    'mounting_height': device.pump.mounting_height,
                                    'outside_diameter': device.pump.outside_diameter,
                                    'max_stages': device.pump.max_stages,
                                    'efficiency': device.pump.efficiency
                                })

                elif device.device_type == DeviceType.MOTOR and device.motor:
                    row.update({
                                    'motor_type': device.motor.motor_type,
                                    'outside_diameter': device.motor.outside_diameter,
                                    'length': device.motor.length,
                                    'weight': device.motor.weight,
                                    'insulation_class': device.motor.insulation_class,
                                    'protection_class': device.motor.protection_class
                                })

                    # 添加频率参数
                    for freq_param in device.motor.frequency_params:
                        freq_suffix = f'_{freq_param.frequency}hz'
                        row.update({
                                        f'power{freq_suffix}': freq_param.power,
                                        f'voltage{freq_suffix}': freq_param.voltage,
                                        f'current{freq_suffix}': freq_param.current,
                                        f'speed{freq_suffix}': freq_param.speed
                                    })

                elif device.device_type == DeviceType.PROTECTOR and device.protector:
                    row.update({
                                    'outer_diameter': device.protector.outer_diameter,
                                    'length': device.protector.length,
                                    'weight': device.protector.weight,
                                    'thrust_capacity': device.protector.thrust_capacity,
                                    'seal_type': device.protector.seal_type,
                                    'max_temperature': device.protector.max_temperature
                                })

                elif device.device_type == DeviceType.SEPARATOR and device.separator:
                    row.update({
                                    'outer_diameter': device.separator.outer_diameter,
                                    'length': device.separator.length,
                                    'weight': device.separator.weight,
                                    'separation_efficiency': device.separator.separation_efficiency,
                                    'gas_handling_capacity': device.separator.gas_handling_capacity,
                                    'liquid_handling_capacity': device.separator.liquid_handling_capacity
                                })

                export_data.append(row)

            return export_data

        except Exception as e:
            error_msg = f"导出设备数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []

        finally:
            self.close_session(session)

    # 在 DatabaseService 类中添加以下方法：

    # ========== 生产参数相关方法 ==========

    def create_production_parameters(self, params_data: Dict, create_new_version: bool = True) -> int:
        """
        创建生产参数
    
        Args:
            params_data: 参数数据
            create_new_version: 是否创建新版本（True）或更新现有活跃版本（False）
    
        Returns:
            参数记录ID
        """
        session = self.get_session()
        try:
            well_id = params_data.get('well_id')
            if not well_id:
                raise ValueError("缺少井ID")
        
            # 检查井是否存在
            well = session.query(WellModel).filter_by(id=well_id, is_deleted=False).first()
            if not well:
                raise ValueError(f"井不存在: ID {well_id}")
        
            # 如果不创建新版本，尝试更新现有活跃版本
            if not create_new_version:
                active_params = session.query(ProductionParameters).filter_by(
                    well_id=well_id,
                    is_active=True
                ).first()
            
                if active_params:
                    # 更新现有记录
                    for key, value in params_data.items():
                        if hasattr(active_params, key) and key not in ['id', 'well_id', 'created_at']:
                            setattr(active_params, key, value)
                
                    session.commit()
                    logger.info(f"更新生产参数成功: ID {active_params.id}")
                    return active_params.id
        
            # 创建新版本时，先将其他版本设为非活跃
            if create_new_version:
                session.query(ProductionParameters).filter_by(
                    well_id=well_id
                ).update({'is_active': False})
        
            # 创建新参数记录
            new_params = ProductionParameters(**params_data)
            new_params.is_active = True
        
            # 验证参数
            is_valid, error_msg = new_params.validate()
            if not is_valid:
                raise ValueError(f"参数验证失败: {error_msg}")
        
            session.add(new_params)
            session.commit()
        
            logger.info(f"创建生产参数成功: 井ID {well_id}, 参数ID {new_params.id}")
            return new_params.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
        
        finally:
            self.close_session(session)

    def get_production_parameters(self, well_id: int, active_only: bool = True) -> List[Dict[str, Any]]:
        """
        获取井的生产参数
    
        Args:
            well_id: 井ID
            active_only: 是否只获取活跃参数
    
        Returns:
            参数列表
        """
        session = self.get_session()
        try:
            query = session.query(ProductionParameters).filter_by(well_id=well_id)
        
            if active_only:
                query = query.filter_by(is_active=True)
        
            params = query.order_by(ProductionParameters.created_at.desc()).all()
            return [p.to_dict() for p in params]
        
        except Exception as e:
            error_msg = f"获取生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
        
        finally:
            self.close_session(session)

    def get_production_parameters_by_id(self, params_id: int) -> Optional[Dict[str, Any]]:
        """根据ID获取生产参数"""
        session = self.get_session()
        try:
            params = session.query(ProductionParameters).filter_by(id=params_id).first()
            if params:
                return params.to_dict()
            return None
        
        except Exception as e:
            error_msg = f"获取生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None
        
        finally:
            self.close_session(session)

    def get_production_parameters_history(self, well_id: int, limit: int = 10) -> List[Dict[str, Any]]:
        """
        获取生产参数历史版本
    
        Args:
            well_id: 井ID
            limit: 返回记录数限制
    
        Returns:
            参数历史列表
        """
        session = self.get_session()
        try:
            params_list = session.query(ProductionParameters).filter_by(
                well_id=well_id
            ).order_by(
                ProductionParameters.created_at.desc()
            ).limit(limit).all()
        
            return [p.to_dict() for p in params_list]
        
        except Exception as e:
            error_msg = f"获取参数历史失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
        
        finally:
            self.close_session(session)

    def set_active_production_parameters(self, params_id: int) -> bool:
        """
        设置某个版本为活跃版本
    
        Args:
            params_id: 参数ID
    
        Returns:
            是否成功
        """
        session = self.get_session()
        try:
            params = session.query(ProductionParameters).filter_by(id=params_id).first()
            if not params:
                raise ValueError(f"参数不存在: ID {params_id}")
        
            # 将同一井的其他参数设为非活跃
            session.query(ProductionParameters).filter_by(
                well_id=params.well_id
            ).update({'is_active': False})
        
            # 设置当前参数为活跃
            params.is_active = True
            session.commit()
        
            logger.info(f"设置活跃参数成功: ID {params_id}")
            return True
        
        except Exception as e:
            session.rollback()
            error_msg = f"设置活跃参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False
        
        finally:
            self.close_session(session)

    def delete_production_parameters(self, params_id: int) -> bool:
        """删除生产参数（硬删除）"""
        session = self.get_session()
        try:
            params = session.query(ProductionParameters).filter_by(id=params_id).first()
            if not params:
                raise ValueError(f"参数不存在: ID {params_id}")
        
            # 如果删除的是活跃版本，需要激活最近的一个版本
            if params.is_active:
                latest_params = session.query(ProductionParameters).filter(
                    ProductionParameters.well_id == params.well_id,
                    ProductionParameters.id != params_id
                ).order_by(ProductionParameters.created_at.desc()).first()
            
                if latest_params:
                    latest_params.is_active = True
        
            session.delete(params)
            session.commit()
        
            logger.info(f"删除生产参数成功: ID {params_id}")
            return True
        
        except Exception as e:
            session.rollback()
            error_msg = f"删除生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False
        
        finally:
            self.close_session(session)

    def clone_production_parameters(self, params_id: int, new_name: Optional[str] = None) -> int:
        """
        克隆生产参数（用于创建基于现有参数的新版本）
    
        Args:
            params_id: 源参数ID
            new_name: 新参数集名称
    
        Returns:
            新参数ID
        """
        session = self.get_session()
        try:
            source_params = session.query(ProductionParameters).filter_by(id=params_id).first()
            if not source_params:
                raise ValueError(f"源参数不存在: ID {params_id}")
        
            # 创建新参数
            params_dict = source_params.to_dict()
            # 移除不需要复制的字段
            for field in ['id', 'created_at', 'updated_at']:
                params_dict.pop(field, None)
        
            # 设置新名称
            if new_name:
                params_dict['parameter_name'] = new_name
            else:
                params_dict['parameter_name'] = f"{source_params.parameter_name}_复制" if source_params.parameter_name else "参数集_复制"
        
            # 设置为非活跃（用户可以手动激活）
            params_dict['is_active'] = False
        
            new_params = ProductionParameters(**params_dict)
            session.add(new_params)
            session.commit()
        
            logger.info(f"克隆生产参数成功: 源ID {params_id}, 新ID {new_params.id}")
            return new_params.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"克隆生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
        
        finally:
            self.close_session(session)

    # ========== 预测结果相关方法 ==========

    def save_production_prediction(self, prediction_data: Dict[str, Any]) -> int:
        """保存生产预测结果"""
        session = self.get_session()
        try:
            # 检查参数是否存在
            params_id = prediction_data.get('parameters_id')
            params = session.query(ProductionParameters).filter_by(id=params_id).first()
            if not params:
                raise ValueError(f"生产参数不存在: ID {params_id}")
        
            # 创建预测记录
            prediction = ProductionPrediction(**prediction_data)
            session.add(prediction)
            session.commit()
        
            logger.info(f"保存预测结果成功: ID {prediction.id}")
            return prediction.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存预测结果失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
        
        finally:
            self.close_session(session)

    def get_latest_prediction(self, parameters_id: int) -> Optional[Dict[str, Any]]:
        """获取最新的预测结果"""
        session = self.get_session()
        try:
            prediction = session.query(ProductionPrediction).filter_by(
                parameters_id=parameters_id
            ).order_by(ProductionPrediction.created_at.desc()).first()
        
            if prediction:
                return prediction.to_dict()
            return None
        
        except Exception as e:
            error_msg = f"获取预测结果失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None
        
        finally:
            self.close_session(session)

    # ========== 扩展井查询方法 ==========

    def get_well_with_production_params(self, well_id: int) -> Optional[Dict[str, Any]]:
        """
        获取井信息及其活跃的生产参数
    
        Returns:
            包含井信息和生产参数的字典
        """
        session = self.get_session()
        try:
            well = session.query(WellModel).filter_by(
                id=well_id,
                is_deleted=False
            ).first()
        
            if not well:
                return None
        
            well_dict = well.to_dict()
        
            # 获取活跃的生产参数
            active_params = session.query(ProductionParameters).filter_by(
                well_id=well_id,
                is_active=True
            ).first()
        
            if active_params:
                well_dict['production_parameters'] = active_params.to_dict()
            else:
                well_dict['production_parameters'] = None
        
            return well_dict
        
        except Exception as e:
            error_msg = f"获取井及生产参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None
        
        finally:
            self.close_session(session)

    def get_wells_with_production_params(self, project_id: int) -> List[Dict[str, Any]]:
        """
        获取项目下所有井及其生产参数状态
    
        Returns:
            井列表，每个井包含是否有生产参数的标识
        """
        session = self.get_session()
        try:
            wells = session.query(WellModel).filter_by(
                project_id=project_id,
                is_deleted=False
            ).all()
        
            result = []
            for well in wells:
                well_dict = well.to_dict()
            
                # 检查是否有活跃的生产参数
                has_params = session.query(ProductionParameters).filter_by(
                    well_id=well.id,
                    is_active=True
                ).count() > 0
            
                well_dict['has_production_parameters'] = has_params
                result.append(well_dict)
        
            return result
        
        except Exception as e:
            error_msg = f"获取井列表失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
        
        finally:
            self.close_session(session)

    # 在 DatabaseService 类中添加以下方法（在现有方法后面添加）

    # ========== 泵性能曲线相关方法 ==========

    def get_pump_curves(self, pump_id: str, active_only: bool = True) -> Dict[str, List]:
        """
        获取泵性能曲线数据
    
        Args:
            pump_id: 泵型号ID
            active_only: 是否只获取活跃版本数据
    
        Returns:
            包含曲线数据的字典
        """
        session = self.get_session()
        try:
            logger.info(f"{pump_id}")
            query = session.query(PumpCurveData).filter_by(pump_id=pump_id)
            if active_only:
                query = query.filter_by(is_active=True)
            
            # 不需要orderby
            # 因为我们会在后续处理时按流量排序
            curves = query.all()
            logger.info(f"获取泵 {pump_id} 的性能曲线数据，{curves}")
            # curves = query.order_by(PumpCurveData.flow_rate).all()
        
            if not curves:
                # 如果没有找到数据，返回空结构，让控制器生成模拟数据
                logger.warning(f"未找到泵 {pump_id} 的性能曲线数据")
                return {
                    'flow': [],
                    'head': [],
                    'power': [],
                    'efficiency': [],
                    'standard_frequency': 60.0
                }
        
            # 提取曲线数据
            result = {
                'flow': [curve.flow_rate for curve in curves],
                'head': [curve.head for curve in curves],
                'power': [curve.power for curve in curves],
                'efficiency': [curve.efficiency for curve in curves],
                'standard_frequency': curves[0].standard_frequency
            }
        
            logger.info(f"获取泵曲线数据成功: {pump_id}, 共{len(curves)}个点")
            return result
        
        except Exception as e:
            error_msg = f"获取泵曲线数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            # 返回空数据结构而不是抛出异常
            return {
                'flow': [],
                'head': [],
                'power': [],
                'efficiency': [],
                'standard_frequency': 60.0
            }
    
        finally:
            self.close_session(session)

    def save_pump_curves(self, pump_id: str, curve_data: Dict[str, Any]) -> bool:
        """
        保存泵性能曲线数据
    
        Args:
            pump_id: 泵型号ID
            curve_data: 曲线数据字典
    
        Returns:
            是否保存成功
        """
        session = self.get_session()
        try:
            # 验证数据完整性
            required_fields = ['flow', 'head', 'power', 'efficiency']
            for field in required_fields:
                if field not in curve_data or not curve_data[field]:
                    raise ValueError(f"缺少必要的曲线数据: {field}")
        
            # 检查数据长度一致性
            data_length = len(curve_data['flow'])
            for field in required_fields:
                if len(curve_data[field]) != data_length:
                    raise ValueError(f"数据长度不一致: {field}")
        
            # 将旧版本标记为非活跃
            session.query(PumpCurveData).filter_by(
                pump_id=pump_id,
                is_active=True
            ).update({'is_active': False})
        
            # 保存新数据
            standard_frequency = curve_data.get('standard_frequency', 60.0)
            data_source = curve_data.get('data_source', 'manual_input')
            version = curve_data.get('version', '1.0')
        
            for i in range(data_length):
                curve_point = PumpCurveData(
                    pump_id=pump_id,
                    flow_rate=curve_data['flow'][i],
                    head=curve_data['head'][i],
                    power=curve_data['power'][i],
                    efficiency=curve_data['efficiency'][i],
                    standard_frequency=standard_frequency,
                    data_source=data_source,
                    version=version,
                    is_active=True
                )
                session.add(curve_point)
        
            session.commit()
        
            logger.info(f"保存泵曲线数据成功: {pump_id}, 共{data_length}个点")
            return True
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存泵曲线数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False
    
        finally:
            self.close_session(session)

    def get_pump_enhanced_parameters(self, pump_id: str) -> Dict[str, List]:
        """
        获取泵增强性能参数
    
        Args:
            pump_id: 泵型号ID
    
        Returns:
            增强参数数据字典
        """
        session = self.get_session()
        try:
            params = session.query(PumpEnhancedParameters).filter_by(
                pump_id=pump_id
            ).order_by(PumpEnhancedParameters.flow_point).all()
        
            if not params:
                logger.warning(f"未找到泵 {pump_id} 的增强参数数据")
                return {}
        
            # 按参数类型组织数据
            result = {}
            param_fields = [
                'npsh_required', 'temperature_rise', 'vibration_level',
                'noise_level', 'wear_rate', 'radial_load', 'axial_thrust',
                'material_stress', 'energy_efficiency_ratio', 'cavitation_margin',
                'stability_score'
            ]
        
            for field in param_fields:
                values = []
                for param in params:
                    value = getattr(param, field)
                    if value is not None:
                        values.append(value)
            
                if values:  # 只添加有数据的字段
                    result[field] = values
        
            logger.info(f"获取增强参数成功: {pump_id}, 共{len(result)}类参数")
            return result
        
        except Exception as e:
            error_msg = f"获取增强参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return {}
    
        finally:
            self.close_session(session)

    def get_pump_operating_points(self, pump_id: str) -> List[Dict[str, Any]]:
        """
        获取泵关键工况点
    
        Args:
            pump_id: 泵型号ID
    
        Returns:
            工况点列表
        """
        session = self.get_session()
        try:
            points = session.query(PumpOperatingPoint).filter_by(
                pump_id=pump_id
            ).order_by(PumpOperatingPoint.flow_rate).all()
        
            return [point.to_dict() for point in points]
        
        except Exception as e:
            error_msg = f"获取工况点失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
    
        finally:
            self.close_session(session)

    def save_system_curve(self, curve_data: Dict[str, Any]) -> int:
        """
        保存系统特性曲线
    
        Args:
            curve_data: 系统曲线数据
    
        Returns:
            曲线ID
        """
        session = self.get_session()
        try:
            system_curve = PumpSystemCurve(**curve_data)
            session.add(system_curve)
            session.commit()
        
            logger.info(f"保存系统曲线成功: {system_curve.curve_name}")
            return system_curve.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存系统曲线失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
    
        finally:
            self.close_session(session)

    def import_pump_curves_from_csv(self, pump_id: str, csv_file_path: str) -> bool:
        """
        从CSV文件导入泵曲线数据
    
        Args:
            pump_id: 泵型号ID
            csv_file_path: CSV文件路径
    
        Returns:
            是否导入成功
        """
        try:
            import pandas as pd
        
            # 读取CSV文件
            df = pd.read_csv(csv_file_path)
        
            # 验证必要列
            required_columns = ['flow', 'head', 'power', 'efficiency']
            missing_columns = [col for col in required_columns if col not in df.columns]
            if missing_columns:
                raise ValueError(f"CSV文件缺少必要列: {missing_columns}")
        
            # 转换为字典格式
            curve_data = {
                'flow': df['flow'].tolist(),
                'head': df['head'].tolist(),
                'power': df['power'].tolist(),
                'efficiency': df['efficiency'].tolist(),
                'standard_frequency': df.get('frequency', [60.0])[0],
                'data_source': f'csv_import:{csv_file_path}',
                'version': '1.0'
            }
        
            # 保存数据
            return self.save_pump_curves(pump_id, curve_data)
        
        except Exception as e:
            error_msg = f"从CSV导入泵曲线失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False

    def _initialize_sample_pump_data(self):
        """初始化示例泵数据"""
        session = self.get_session()
        try:
            # 检查是否已有数据
            existing_count = session.query(PumpCurveData).count()
            if existing_count > 0:
                logger.info("泵曲线数据已存在，跳过初始化")
                return
        
            # 创建几个示例泵的数据
            sample_pumps = ['FLEXPump_400', 'FLEXPump_600', 'Baker_Hughes_ESP']
        
            for pump_id in sample_pumps:
                self._create_sample_pump_curves(session, pump_id)
        
            session.commit()
            logger.info("示例泵数据初始化完成")
        
        except Exception as e:
            session.rollback()
            logger.error(f"初始化示例数据失败: {str(e)}")
    
        finally:
            self.close_session(session)

    def _create_sample_pump_curves(self, session, pump_id: str):
        """创建示例泵曲线数据"""
        import numpy as np
    
        # 基于pump_id生成不同特征的曲线
        base_params = {
            'FLEXPump_400': {'max_flow': 4000, 'max_head': 400, 'efficiency_peak': 75},
            'FLEXPump_600': {'max_flow': 6000, 'max_head': 600, 'efficiency_peak': 78},
            'Baker_Hughes_ESP': {'max_flow': 5000, 'max_head': 500, 'efficiency_peak': 72}
        }
    
        params = base_params.get(pump_id, {'max_flow': 4000, 'max_head': 400, 'efficiency_peak': 70})
    
        # 生成21个曲线点
        for i in range(21):
            flow_ratio = i / 20
            flow = params['max_flow'] * flow_ratio
        
            # 扬程曲线
            head = params['max_head'] * (1 - 0.8 * (flow_ratio ** 1.8))
        
            # 效率曲线
            efficiency = params['efficiency_peak'] * np.exp(-((flow_ratio - 0.6) / 0.25) ** 2)
        
            # 功率曲线
            power = flow * head * 1.2 / (3600 * max(efficiency, 10) / 100)
        
            # 创建数据记录
            curve_point = PumpCurveData(
                pump_id=pump_id,
                flow_rate=flow,
                head=max(head, 0),
                power=max(power, 0),
                efficiency=max(efficiency, 0),
                standard_frequency=60.0,
                data_source='sample_data',
                version='1.0',
                is_active=True
            )
            session.add(curve_point)

    # ========== 阶段2: 增强参数和预测相关方法 ==========

    def save_enhanced_parameters(self, pump_id: str, enhanced_data: List[Dict[str, Any]]) -> bool:
        """
        保存泵增强性能参数
    
        Args:
            pump_id: 泵型号ID
            enhanced_data: 增强参数数据列表
    
        Returns:
            是否保存成功
        """
        session = self.get_session()
        try:
            # 删除现有数据
            session.query(PumpEnhancedParameters).filter_by(pump_id=pump_id).delete()
        
            # 保存新数据
            for data in enhanced_data:
                enhanced_param = PumpEnhancedParameters(
                    pump_id=pump_id,
                    **data
                )
                session.add(enhanced_param)
        
            session.commit()
            logger.info(f"保存增强参数成功: {pump_id}, 共{len(enhanced_data)}个点")
            return True
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存增强参数失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False
    
        finally:
            self.close_session(session)

    def save_performance_prediction(self, prediction_data: Dict) -> Dict:
        """保存性能预测数据"""
        try:
            with self.get_session() as session:
                # 🔥 修复：确保所有必需字段都有值
                prediction = DevicePerformancePrediction(
                    device_id=prediction_data.get('device_id'),
                    pump_id=prediction_data.get('pump_id'),
                    prediction_years=prediction_data.get('prediction_years', 5),
                    base_efficiency=prediction_data.get('base_efficiency'),
                    base_power=prediction_data.get('base_power'),
                    base_flow=prediction_data.get('base_flow'),
                    base_head=prediction_data.get('base_head'),
                    # 🔥 修复：使用json.dumps序列化复杂数据
                    annual_predictions=json.dumps(prediction_data.get('annual_predictions', [])),
                    wear_progression=json.dumps(prediction_data.get('wear_progression', [])),
                    maintenance_schedule=json.dumps(prediction_data.get('maintenance_schedule', [])),
                    lifecycle_cost=json.dumps(prediction_data.get('lifecycle_cost', {})),
                    performance_degradation=json.dumps(prediction_data.get('performance_degradation', {})),
                    wear_model=prediction_data.get('wear_model', 'exponential'),
                    efficiency_degradation_rate=prediction_data.get('efficiency_degradation_rate', 0.02),
                    maintenance_cost_base=prediction_data.get('maintenance_cost_base', 5000.0),
                    energy_cost_rate=prediction_data.get('energy_cost_rate', 0.1),
                    prediction_accuracy=prediction_data.get('prediction_accuracy', 'estimated'),
                    model_version=prediction_data.get('model_version', '1.0'),
                    calculation_method=prediction_data.get('calculation_method'),
                    created_by=prediction_data.get('created_by', 'system'),
                    prediction_notes=prediction_data.get('prediction_notes')
                )
                
                session.add(prediction)
                session.commit()
                
                logger.info(f"性能预测保存成功: {prediction.id}")
                return prediction.to_dict()
                
        except Exception as e:
            error_msg = f"保存性能预测失败: {str(e)}"
            logger.error(error_msg)
            raise Exception(error_msg)

    def get_performance_prediction(self, device_id: int = None, pump_id: str = None) -> Optional[Dict[str, Any]]:
        """
        获取设备性能预测
    
        Args:
            device_id: 设备ID
            pump_id: 泵型号ID
    
        Returns:
            预测数据
        """
        session = self.get_session()
        try:
            query = session.query(DevicePerformancePrediction)
        
            if device_id:
                query = query.filter_by(device_id=device_id)
            elif pump_id:
                query = query.filter_by(pump_id=pump_id)
            else:
                raise ValueError("必须提供 device_id 或 pump_id")
        
            prediction = query.order_by(DevicePerformancePrediction.created_at.desc()).first()
        
            if prediction:
                return prediction.to_dict()
            return None
        
        except Exception as e:
            error_msg = f"获取性能预测失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None
    
        finally:
            self.close_session(session)

    def save_wear_data(self, wear_data: Dict[str, Any]) -> int:
        """
        保存磨损数据
    
        Args:
            wear_data: 磨损数据
    
        Returns:
            磨损记录ID
        """
        session = self.get_session()
        try:
            # 处理零部件更换记录
            if 'parts_replaced' in wear_data and isinstance(wear_data['parts_replaced'], list):
                wear_data['parts_replaced'] = json.dumps(wear_data['parts_replaced'])
        
            wear_record = PumpWearData(**wear_data)
            session.add(wear_record)
            session.commit()
        
            logger.info(f"保存磨损数据成功: ID {wear_record.id}")
            return wear_record.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存磨损数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
    
        finally:
            self.close_session(session)

    def get_wear_data(self, pump_id: str, device_id: int = None) -> List[Dict[str, Any]]:
        """
        获取磨损数据
    
        Args:
            pump_id: 泵型号ID
            device_id: 设备ID（可选）
    
        Returns:
            磨损数据列表
        """
        session = self.get_session()
        try:
            query = session.query(PumpWearData).filter_by(pump_id=pump_id)
        
            if device_id:
                query = query.filter_by(device_id=device_id)
        
            wear_records = query.order_by(PumpWearData.operating_hours).all()
            return [record.to_dict() for record in wear_records]
        
        except Exception as e:
            error_msg = f"获取磨损数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
    
        finally:
            self.close_session(session)

    def save_maintenance_record(self, maintenance_data: Dict[str, Any]) -> int:
        """
        保存维护记录
    
        Args:
            maintenance_data: 维护数据
    
        Returns:
            维护记录ID
        """
        session = self.get_session()
        try:
            # 处理JSON字段
            if 'parts_replaced' in maintenance_data and isinstance(maintenance_data['parts_replaced'], list):
                maintenance_data['parts_replaced'] = json.dumps(maintenance_data['parts_replaced'])
        
            maintenance = MaintenanceRecord(**maintenance_data)
            session.add(maintenance)
            session.commit()
        
            logger.info(f"保存维护记录成功: ID {maintenance.id}")
            return maintenance.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存维护记录失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
    
        finally:
            self.close_session(session)

    def get_maintenance_records(self, device_id: int = None, pump_id: str = None, 
                              limit: int = 50) -> List[Dict[str, Any]]:
        """
        获取维护记录
    
        Args:
            device_id: 设备ID
            pump_id: 泵型号ID
            limit: 记录数限制
    
        Returns:
            维护记录列表
        """
        session = self.get_session()
        try:
            query = session.query(MaintenanceRecord)
        
            if device_id:
                query = query.filter_by(device_id=device_id)
            elif pump_id:
                query = query.filter_by(pump_id=pump_id)
        
            records = query.order_by(MaintenanceRecord.maintenance_date.desc()).limit(limit).all()
            return [record.to_dict() for record in records]
        
        except Exception as e:
            error_msg = f"获取维护记录失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
    
        finally:
            self.close_session(session)

    def save_condition_comparison(self, comparison_data: Dict[str, Any]) -> int:
        """
        保存工况对比分析
    
        Args:
            comparison_data: 对比数据
    
        Returns:
            对比记录ID
        """
        session = self.get_session()
        try:
            # 处理JSON字段
            json_fields = ['base_condition', 'comparison_conditions', 'comparison_parameters',
                          'performance_metrics', 'efficiency_comparison', 'power_comparison',
                          'cost_comparison', 'reliability_analysis', 'recommendations',
                          'optimal_condition', 'risk_assessment', 'weight_factors', 'evaluation_criteria']
        
            for field in json_fields:
                if field in comparison_data and isinstance(comparison_data[field], (dict, list)):
                    comparison_data[field] = json.dumps(comparison_data[field])
        
            comparison = PumpConditionComparison(**comparison_data)
            session.add(comparison)
            session.commit()
        
            logger.info(f"保存工况对比成功: ID {comparison.id}")
            return comparison.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存工况对比失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
    
        finally:
            self.close_session(session)

    def get_condition_comparisons(self, pump_id: str = None, project_id: int = None) -> List[Dict[str, Any]]:
        """
        获取工况对比记录
    
        Args:
            pump_id: 泵型号ID
            project_id: 项目ID
    
        Returns:
            对比记录列表
        """
        session = self.get_session()
        try:
            query = session.query(PumpConditionComparison)
        
            if pump_id:
                query = query.filter_by(pump_id=pump_id)
            if project_id:
                query = query.filter_by(project_id=project_id)
        
            comparisons = query.order_by(PumpConditionComparison.created_at.desc()).all()
            return [comp.to_dict() for comp in comparisons]
        
        except Exception as e:
            error_msg = f"获取工况对比失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
    
        finally:
            self.close_session(session)

    def get_pump_reliability_stats(self, pump_id: str) -> Dict[str, Any]:
        """
        获取泵可靠性统计
    
        Args:
            pump_id: 泵型号ID
    
        Returns:
            可靠性统计数据
        """
        session = self.get_session()
        try:
            # 获取维护记录统计
            maintenance_stats = session.query(MaintenanceRecord).filter_by(pump_id=pump_id).all()
        
            # 获取磨损数据统计
            wear_stats = session.query(PumpWearData).filter_by(pump_id=pump_id).all()
        
            # 计算统计指标
            total_maintenance = len(maintenance_stats)
            total_cost = sum(record.total_cost or 0 for record in maintenance_stats)
            avg_downtime = sum(record.downtime_hours or 0 for record in maintenance_stats) / max(total_maintenance, 1)
        
            # 计算MTBF（平均故障间隔时间）
            corrective_maintenance = [r for r in maintenance_stats if r.maintenance_type == 'corrective']
            mtbf = 0
            if len(corrective_maintenance) > 1:
                operating_hours = [w.operating_hours for w in wear_stats]
                if operating_hours:
                    total_hours = max(operating_hours) - min(operating_hours)
                    mtbf = total_hours / (len(corrective_maintenance) - 1)
        
            # 计算平均磨损率
            avg_wear_rate = 0
            if wear_stats:
                wear_percentages = [w.wear_percentage for w in wear_stats if w.wear_percentage]
                if wear_percentages:
                    avg_wear_rate = sum(wear_percentages) / len(wear_percentages)
        
            return {
                'pump_id': pump_id,
                'total_maintenance_records': total_maintenance,
                'total_maintenance_cost': total_cost,
                'average_downtime_hours': avg_downtime,
                'mtbf_hours': mtbf,
                'average_wear_rate': avg_wear_rate,
                'preventive_maintenance_ratio': len([r for r in maintenance_stats if r.maintenance_type == 'preventive']) / max(total_maintenance, 1),
                'last_maintenance_date': max([r.maintenance_date for r in maintenance_stats]) if maintenance_stats else None,
                'reliability_score': self._calculate_reliability_score(pump_id, mtbf, avg_wear_rate, avg_downtime)
            }
        
        except Exception as e:
            error_msg = f"获取可靠性统计失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return {}
    
        finally:
            self.close_session(session)

    def _calculate_reliability_score(self, pump_id: str, mtbf: float, wear_rate: float, downtime: float) -> float:
        """
        计算可靠性评分
    
        Args:
            pump_id: 泵ID
            mtbf: 平均故障间隔时间
            wear_rate: 平均磨损率
            downtime: 平均停机时间
    
        Returns:
            可靠性评分 (0-100)
        """
        try:
            # 基础评分
            base_score = 70
        
            # MTBF评分 (权重30%)
            mtbf_score = min(30, mtbf / 1000 * 30) if mtbf > 0 else 10
        
            # 磨损率评分 (权重25%)
            wear_score = max(0, 25 - wear_rate * 5) if wear_rate > 0 else 20
        
            # 停机时间评分 (权重25%)
            downtime_score = max(0, 25 - downtime * 2) if downtime > 0 else 20
        
            # 维护频率评分 (权重20%)
            # 这里简化处理，实际可以根据维护间隔计算
            maintenance_score = 15
        
            total_score = base_score + mtbf_score + wear_score + downtime_score + maintenance_score
            return min(100, max(0, total_score))
        
        except:
            return 60  # 默认评分


    # 在 DatabaseService 类中添加阶段3相关方法

    def get_condition_comparison_by_id(self, comparison_id: int) -> Optional[Dict[str, Any]]:
        """根据ID获取工况对比分析"""
        session = self.get_session()
        try:
            comparison = session.query(PumpConditionComparison).filter_by(id=comparison_id).first()
        
            if comparison:
                return comparison.to_dict()
            return None
        
        except Exception as e:
            error_msg = f"获取工况对比分析失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return None
    
        finally:
            self.close_session(session)

    def update_condition_comparison(self, comparison_id: int, updates: Dict[str, Any]) -> bool:
        """更新工况对比分析"""
        session = self.get_session()
        try:
            comparison = session.query(PumpConditionComparison).filter_by(id=comparison_id).first()
        
            if not comparison:
                raise ValueError(f"工况对比不存在: ID {comparison_id}")
        
            # 处理JSON字段更新
            json_fields = ['base_condition', 'comparison_conditions', 'comparison_parameters',
                          'performance_metrics', 'efficiency_comparison', 'power_comparison',
                          'cost_comparison', 'reliability_analysis', 'recommendations',
                          'optimal_condition', 'risk_assessment', 'weight_factors', 'evaluation_criteria']
        
            for field in json_fields:
                if field in updates and isinstance(updates[field], (dict, list)):
                    updates[field] = json.dumps(updates[field])
        
            # 应用更新
            for key, value in updates.items():
                if hasattr(comparison, key):
                    setattr(comparison, key, value)
        
            session.commit()
            logger.info(f"更新工况对比成功: ID {comparison_id}")
            return True
        
        except Exception as e:
            session.rollback()
            error_msg = f"更新工况对比失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return False
    
        finally:
            self.close_session(session)

    def save_optimization_result(self, optimization_data: Dict[str, Any]) -> int:
        """保存优化结果"""
        session = self.get_session()
        try:
            # 处理JSON字段
            json_fields = ['target_values', 'constraints', 'algorithm_parameters',
                          'optimal_solution', 'optimization_history', 'validation_results',
                          'sensitivity_analysis', 'implementation_plan', 'risk_mitigation', 'expected_benefits']
        
            for field in json_fields:
                if field in optimization_data and isinstance(optimization_data[field], (dict, list)):
                    optimization_data[field] = json.dumps(optimization_data[field])
        
            optimization = ConditionOptimization(**optimization_data)
            session.add(optimization)
            session.commit()
        
            logger.info(f"保存优化结果成功: ID {optimization.id}")
            return optimization.id
        
        except Exception as e:
            session.rollback()
            error_msg = f"保存优化结果失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            raise
    
        finally:
            self.close_session(session)

    def get_optimization_results(self, comparison_id: int = None) -> List[Dict[str, Any]]:
        """获取优化结果"""
        session = self.get_session()
        try:
            query = session.query(ConditionOptimization)
        
            if comparison_id:
                query = query.filter_by(comparison_id=comparison_id)
        
            optimizations = query.order_by(ConditionOptimization.created_at.desc()).all()
            return [opt.to_dict() for opt in optimizations]
        
        except Exception as e:
            error_msg = f"获取优化结果失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
    
        finally:
            self.close_session(session)

    def get_pump_performance_trends(self, pump_id: str, days: int = 90) -> List[Dict[str, Any]]:
        """获取泵性能趋势数据"""
        session = self.get_session()
        try:
            from datetime import datetime, timedelta
        
            # 计算查询起始日期
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days)
        
            # 获取性能预测历史记录
            predictions = session.query(DevicePerformancePrediction).filter(
                DevicePerformancePrediction.pump_id == pump_id,
                DevicePerformancePrediction.created_at >= start_date
            ).order_by(DevicePerformancePrediction.created_at).all()
        
            trend_data = []
            for prediction in predictions:
                annual_predictions = prediction.get_annual_predictions()
                if annual_predictions:
                    # 取第一年的数据作为当时的预测
                    current_prediction = annual_predictions[0] if annual_predictions else {}
                    trend_data.append({
                        'timestamp': prediction.created_at.isoformat(),
                        'efficiency': current_prediction.get('efficiency', 0),
                        'power': current_prediction.get('power', 0),
                        'flow': current_prediction.get('flow', 0),
                        'head': current_prediction.get('head', 0),
                        'wear_factor': current_prediction.get('wear_factor', 0),
                        'reliability': current_prediction.get('reliability', 0)
                    })
        
            return trend_data
        
        except Exception as e:
            error_msg = f"获取性能趋势失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return []
    
        finally:
            self.close_session(session)

    def get_comprehensive_pump_analysis(self, pump_id: str) -> Dict[str, Any]:
        """获取泵的综合分析数据"""
        session = self.get_session()
        try:
            analysis_data = {
                'pump_id': pump_id,
                'basic_curves': {},
                'enhanced_parameters': {},
                'performance_predictions': [],
                'condition_comparisons': [],
                'maintenance_records': [],
                'wear_data': [],
                'reliability_stats': {},
                'trends': {}
            }
        
            # 基础曲线数据
            logger.info(f"3143line获取泵 {pump_id} 的基础曲线数据")
            analysis_data['basic_curves'] = self.get_pump_curves(pump_id)
            
        
            # 增强参数
            analysis_data['enhanced_parameters'] = self.get_pump_enhanced_parameters(pump_id)
        
            # 性能预测
            predictions = session.query(DevicePerformancePrediction).filter_by(
                pump_id=pump_id
            ).order_by(DevicePerformancePrediction.created_at.desc()).limit(5).all()
            analysis_data['performance_predictions'] = [pred.to_dict() for pred in predictions]
        
            # 工况对比
            comparisons = session.query(PumpConditionComparison).filter_by(
                pump_id=pump_id
            ).order_by(PumpConditionComparison.created_at.desc()).limit(5).all()
            analysis_data['condition_comparisons'] = [comp.to_dict() for comp in comparisons]
        
            # 维护记录
            analysis_data['maintenance_records'] = self.get_maintenance_records(pump_id=pump_id, limit=10)
        
            # 磨损数据
            analysis_data['wear_data'] = self.get_wear_data(pump_id)
        
            # 可靠性统计
            analysis_data['reliability_stats'] = self.get_pump_reliability_stats(pump_id)
        
            # 趋势数据
            analysis_data['trends'] = self.get_pump_performance_trends(pump_id, days=180)
        
            return analysis_data
        
        except Exception as e:
            error_msg = f"获取综合分析数据失败: {str(e)}"
            logger.error(error_msg)
            self.databaseError.emit(error_msg)
            return {}
    
        finally:
            self.close_session(session)

    def get_devices_by_model(self, model: str) -> List[Dict]:
        """根据型号获取设备列表"""
        try:
            with self.get_session() as session:
                devices = session.query(Device).filter(Device.model == model).all()
                return [device.to_dict() for device in devices]
        except Exception as e:
            logger.error(f"根据型号获取设备失败: {str(e)}")
            return []

    def get_devices_by_lift_method(self, device_type: str = None, lift_method: str = None, status: str = 'active'):
        """根据举升方式获取设备 - 修复版本"""
        session = self.get_session()  # 🔥 修复：使用正确的会话获取方法
        try:
            query = session.query(Device).filter(Device.is_deleted == False)
        
            if device_type:
                try:
                    device_type_enum = DeviceType(device_type.upper())  # 🔥 修复：转为大写
                    query = query.filter(Device.device_type == device_type_enum)
                except ValueError:
                    logger.warning(f"无效的设备类型: {device_type}")
        
            if lift_method:
                try:
                    lift_method_enum = LiftMethod(lift_method.upper())  # 🔥 修复：转为大写
                    query = query.filter(Device.lift_method == lift_method_enum)
                except ValueError:
                    logger.warning(f"无效的举升方式: {lift_method}")
        
            if status:
                query = query.filter(Device.status == status)
        
            devices = query.all()
        
            device_list = []
            for device in devices:
                device_dict = device.to_dict()
                device_list.append(device_dict)
        
            logger.info(f"查询到 {len(device_list)} 个 {lift_method} {device_type} 设备")
        
            return {
                'devices': device_list,
                'total': len(device_list)
            }
        
        except Exception as e:
            logger.error(f"按举升方式查询设备失败: {e}")
            return {'devices': [], 'total': 0}
        finally:
            self.close_session(session)  # 🔥 修复：正确关闭会话

    def _extract_performance_curve_data(self, row_data: Dict) -> Dict:
        """提取性能曲线数据"""
        curves = {
            'flow_points': [],
            'head_points': [],
            'efficiency_points': [],
            'power_points': [],
            'best_efficiency_point': {}
        }
    
        # 提取5个性能点
        for i in range(1, 6):
            flow_key = f'流量点{i}(m³/d)' if '流量点' in str(row_data.keys()) else f'流量点{i}(bbl/d)'
            head_key = f'扬程点{i}(m)' if '扬程点' in str(row_data.keys()) else f'扬程点{i}(ft)'
            eff_key = f'效率点{i}(%)'
            power_key = f'功率点{i}(kW)' if '功率点' in str(row_data.keys()) else f'功率点{i}(HP)'
        
            if row_data.get(flow_key):
                curves['flow_points'].append(float(row_data[flow_key]))
                curves['head_points'].append(float(row_data.get(head_key, 0)))
                curves['efficiency_points'].append(float(row_data.get(eff_key, 0)))
                curves['power_points'].append(float(row_data.get(power_key, 0)))
    
        # 最优工况点
        opt_flow_key = '最优流量(m³/d)' if '最优流量' in str(row_data.keys()) else '最优流量(bbl/d)'
        if row_data.get(opt_flow_key):
            curves['best_efficiency_point'] = {
                'flow': float(row_data[opt_flow_key]),
                'head': float(row_data.get('最优扬程(m)') or row_data.get('最优扬程(ft)') or 0),
                'efficiency': float(row_data.get('最优效率(%)', 0)),
                'power': float(row_data.get('最优功率(kW)') or row_data.get('最优功率(HP)') or 0)
            }
    
        return curves

    def _convert_units_if_needed(self, row_data: Dict, device_type: str, is_metric: bool) -> Dict:
        """根据需要转换单位"""
        # 如果模板是公制但系统需要英制存储，或反之，进行转换
        # 这里的具体实现取决于系统的单位存储策略
        if is_metric:
            # 转换为公制单位
            row_data['最小流量(m³/d)'] = float(row_data.get('最小流量(bbl/d)', 0)) * 0.158987
            row_data['最大流量(m³/d)'] = float(row_data.get('最大流量(bbl/d)', 0)) * 0.158987
            row_data['单级扬程(m)'] = float(row_data.get('单级扬程(ft)', 0)) * 0.3048
            row_data['单级功率(kW)'] = float(row_data.get('单级功率(HP)', 0)) * 0.7457
        else:
            # 转换为英制单位
            row_data['最小流量(bbl/d)'] = float(row_data.get('最小流量(m³/d)', 0)) / 0.158987
            row_data['最大流量(bbl/d)'] = float(row_data.get('最大流量(m³/d)', 0)) / 0.158987
            row_data['单级扬程(ft)'] = float(row_data.get('单级扬程(m)', 0)) / 0.3048
            row_data['单级功率(HP)'] = float(row_data.get('单级功率(kW)', 0)) / 0.7457

        return row_data

    def _process_pump_excel_data(self, row_data: Dict, is_metric: bool, row_index: int) -> Dict:
        """处理泵设备Excel数据"""
        try:
            # 🔥 统一字段映射 - 处理中英文字段名
            field_mapping = {
                # 基本信息映射
                'manufacturer': ['制造商', 'Manufacturer', 'manufacturer'],
                'model': ['型号', 'Model', 'model'],
                'series': ['系列', 'Series', 'series'],
                'lift_method': ['举升方式', 'Lift Method', 'lift_method'],
                'serial_number': ['序列号', 'Serial Number', 'serial_number'],
                'status': ['状态', 'Status', 'status'],
                'description': ['描述', 'Description', 'description'],
            
                # 泵参数映射
                'impeller_model': ['叶轮型号', 'Impeller Model', 'impeller_model'],
                'efficiency': ['效率(%)', 'Efficiency(%)', 'efficiency'],
                'max_stages': ['最大级数', 'Max Stages', 'max_stages'],
            }
        
            # 🔥 流量、扬程、功率等需要单位转换的字段
            if is_metric:
                # 公制字段映射
                unit_mapping = {
                    'displacement_min': ['最小流量(m³/d)', 'Min Flow(m³/d)'],
                    'displacement_max': ['最大流量(m³/d)', 'Max Flow(m³/d)'],
                    'single_stage_head': ['单级扬程(m)', 'Single Stage Head(m)'],
                    'single_stage_power': ['单级功率(kW)', 'Single Stage Power(kW)'],
                    'outside_diameter': ['外径(mm)', 'Outside Diameter(mm)'],
                    'shaft_diameter': ['轴径(mm)', 'Shaft Diameter(mm)'],
                    'weight': ['重量(kg)', 'Weight(kg)'],
                    'length': ['长度(mm)', 'Length(mm)']
                }
            else:
                # 英制字段映射
                unit_mapping = {
                    'displacement_min': ['最小流量(bbl/d)', 'Min Flow(bbl/d)'],
                    'displacement_max': ['最大流量(bbl/d)', 'Max Flow(bbl/d)'],
                    'single_stage_head': ['单级扬程(ft)', 'Single Stage Head(ft)'],
                    'single_stage_power': ['单级功率(HP)', 'Single Stage Power(HP)'],
                    'outside_diameter': ['外径(in)', 'Outside Diameter(in)'],
                    'shaft_diameter': ['轴径(in)', 'Shaft Diameter(in)'],
                    'weight': ['重量(lbs)', 'Weight(lbs)'],
                    'length': ['长度(in)', 'Length(in)']
                }

            # 🔥 提取基本设备信息
            device_data = {
                'device_type': 'pump',
                'manufacturer': self._get_excel_value(row_data, field_mapping['manufacturer']),
                'model': self._get_excel_value(row_data, field_mapping['model']),
                'serial_number': (self._get_excel_value(row_data, field_mapping['serial_number']) or 
                                f'IMP_PUMP_{int(datetime.now().timestamp())}_{row_index}'),
                'status': self._get_excel_value(row_data, field_mapping['status']) or 'active',
                'description': self._get_excel_value(row_data, field_mapping['description']) or '',
                'lift_method': self._get_excel_value(row_data, field_mapping['lift_method']) or 'esp'
            }

            # 🔥 提取泵详细参数
            pump_details = {}
        
            # 基本参数
            pump_details['impeller_model'] = self._get_excel_value(row_data, field_mapping['impeller_model']) or ''
            pump_details['efficiency'] = self._safe_float(self._get_excel_value(row_data, field_mapping['efficiency'])) or 75.0
            pump_details['max_stages'] = self._safe_int(self._get_excel_value(row_data, field_mapping['max_stages'])) or 100

            # 🔥 单位相关参数
            for param, field_names in unit_mapping.items():
                value = self._get_excel_value(row_data, field_names)
                if value is not None:
                    # 如果是英制单位且系统存储需要公制，进行转换
                    converted_value = self._convert_pump_units(param, self._safe_float(value), is_metric)
                    pump_details[param] = converted_value

            # 🔥 处理性能曲线数据
            pump_details['performance_curves'] = self._extract_performance_curves(row_data, is_metric)

            device_data['pump_details'] = pump_details
        
            # 验证必要字段
            if not device_data['manufacturer'] or not device_data['model']:
                raise ValueError("缺少必要字段：制造商或型号")

            return device_data

        except Exception as e:
            logger.error(f"处理泵Excel数据失败 (第{row_index}行): {e}")
            raise ValueError(f"第{row_index}行数据格式错误: {e}")

    def _process_motor_excel_data(self, row_data: Dict, is_metric: bool, row_index: int) -> Dict:
        """处理电机设备Excel数据"""
        try:
            device_data = {
                'device_type': 'motor',
                'manufacturer': self._get_excel_value(row_data, ['制造商', 'Manufacturer']),
                'model': self._get_excel_value(row_data, ['型号', 'Model']),
                'serial_number': (self._get_excel_value(row_data, ['序列号', 'Serial Number']) or 
                                f'IMP_MOTOR_{int(datetime.now().timestamp())}_{row_index}'),
                'status': self._get_excel_value(row_data, ['状态', 'Status']) or 'active',
                'description': self._get_excel_value(row_data, ['描述', 'Description']) or ''
            }

            # 电机详细参数
            motor_details = {
                'motor_type': self._get_excel_value(row_data, ['电机类型', 'Motor Type']) or '',
                'insulation_class': self._get_excel_value(row_data, ['绝缘等级', 'Insulation Class']) or '',
                'protection_class': self._get_excel_value(row_data, ['防护等级', 'Protection Class']) or '',
            }

            # 🔥 尺寸参数（根据单位制）
            if is_metric:
                motor_details['outside_diameter'] = self._safe_float(self._get_excel_value(row_data, ['外径(mm)', 'Outside Diameter(mm)']))
                motor_details['length'] = self._safe_float(self._get_excel_value(row_data, ['长度(mm)', 'Length(mm)']))
                motor_details['weight'] = self._safe_float(self._get_excel_value(row_data, ['重量(kg)', 'Weight(kg)']))
            else:
                # 英制转公制存储
                od_in = self._safe_float(self._get_excel_value(row_data, ['外径(in)', 'Outside Diameter(in)']))
                length_in = self._safe_float(self._get_excel_value(row_data, ['长度(in)', 'Length(in)']))
                weight_lbs = self._safe_float(self._get_excel_value(row_data, ['重量(lbs)', 'Weight(lbs)']))
            
                motor_details['outside_diameter'] = od_in * 25.4 if od_in else None  # in to mm
                motor_details['length'] = length_in * 25.4 if length_in else None   # in to mm
                motor_details['weight'] = weight_lbs * 0.453592 if weight_lbs else None  # lbs to kg

            # 🔥 频率参数
            frequency_params = []
        
            # 50Hz参数
            if is_metric:
                power_50 = self._safe_float(self._get_excel_value(row_data, ['50Hz功率(kW)', '50Hz Power(kW)']))
            else:
                power_hp = self._safe_float(self._get_excel_value(row_data, ['50Hz功率(HP)', '50Hz Power(HP)']))
                power_50 = power_hp * 0.746 if power_hp else None  # HP to kW

            if power_50:
                frequency_params.append({
                    'frequency': 50,
                    'power': power_50,
                    'voltage': self._safe_float(self._get_excel_value(row_data, ['50Hz电压(V)', '50Hz Voltage(V)'])),
                    'current': self._safe_float(self._get_excel_value(row_data, ['50Hz电流(A)', '50Hz Current(A)'])),
                    'speed': self._safe_int(self._get_excel_value(row_data, ['50Hz转速(rpm)', '50Hz Speed(rpm)']))
                })

            # 60Hz参数
            if is_metric:
                power_60 = self._safe_float(self._get_excel_value(row_data, ['60Hz功率(kW)', '60Hz Power(kW)']))
            else:
                power_hp = self._safe_float(self._get_excel_value(row_data, ['60Hz功率(HP)', '60Hz Power(HP)']))
                power_60 = power_hp * 0.746 if power_hp else None  # HP to kW

            if power_60:
                frequency_params.append({
                    'frequency': 60,
                    'power': power_60,
                    'voltage': self._safe_float(self._get_excel_value(row_data, ['60Hz电压(V)', '60Hz Voltage(V)'])),
                    'current': self._safe_float(self._get_excel_value(row_data, ['60Hz电流(A)', '60Hz Current(A)'])),
                    'speed': self._safe_int(self._get_excel_value(row_data, ['60Hz转速(rpm)', '60Hz Speed(rpm)']))
                })

            motor_details['frequency_params'] = frequency_params
            device_data['motor_details'] = motor_details

            return device_data

        except Exception as e:
            logger.error(f"处理电机Excel数据失败 (第{row_index}行): {e}")
            raise ValueError(f"第{row_index}行数据格式错误: {e}")

    def _process_protector_excel_data(self, row_data: Dict, is_metric: bool, row_index: int) -> Dict:
        """处理保护器设备Excel数据"""
        try:
            device_data = {
                'device_type': 'protector',
                'manufacturer': self._get_excel_value(row_data, ['制造商', 'Manufacturer']),
                'model': self._get_excel_value(row_data, ['型号', 'Model']),
                'serial_number': (self._get_excel_value(row_data, ['序列号', 'Serial Number']) or 
                                f'IMP_PROTECTOR_{int(datetime.now().timestamp())}_{row_index}'),
                'status': self._get_excel_value(row_data, ['状态', 'Status']) or 'active',
                'description': self._get_excel_value(row_data, ['描述', 'Description']) or ''
            }

            # 保护器详细参数
            protector_details = {
                'seal_type': self._get_excel_value(row_data, ['密封类型', 'Seal Type']) or '',
            }

            # 🔥 尺寸和载荷参数（根据单位制）
            if is_metric:
                protector_details['outer_diameter'] = self._safe_float(self._get_excel_value(row_data, ['外径(mm)', 'Outer Diameter(mm)']))
                protector_details['length'] = self._safe_float(self._get_excel_value(row_data, ['长度(mm)', 'Length(mm)']))
                protector_details['weight'] = self._safe_float(self._get_excel_value(row_data, ['重量(kg)', 'Weight(kg)']))
                protector_details['thrust_capacity'] = self._safe_float(self._get_excel_value(row_data, ['推力承载能力(kN)', 'Thrust Capacity(kN)']))
                protector_details['max_temperature'] = self._safe_float(self._get_excel_value(row_data, ['最高工作温度(°C)', 'Max Temperature(°C)']))
            else:
                # 英制转公制
                od_in = self._safe_float(self._get_excel_value(row_data, ['外径(in)', 'Outer Diameter(in)']))
                length_in = self._safe_float(self._get_excel_value(row_data, ['长度(in)', 'Length(in)']))
                weight_lbs = self._safe_float(self._get_excel_value(row_data, ['重量(lbs)', 'Weight(lbs)']))
                thrust_lbs = self._safe_float(self._get_excel_value(row_data, ['推力承载能力(lbs)', 'Thrust Capacity(lbs)']))
                temp_f = self._safe_float(self._get_excel_value(row_data, ['最高工作温度(°F)', 'Max Temperature(°F)']))
            
                protector_details['outer_diameter'] = od_in * 25.4 if od_in else None  # in to mm
                protector_details['length'] = length_in * 25.4 if length_in else None   # in to mm
                protector_details['weight'] = weight_lbs * 0.453592 if weight_lbs else None  # lbs to kg
                protector_details['thrust_capacity'] = thrust_lbs * 0.004448 if thrust_lbs else None  # lbs to kN
                protector_details['max_temperature'] = (temp_f - 32) * 5/9 if temp_f else None  # °F to °C

            device_data['protector_details'] = protector_details
            return device_data

        except Exception as e:
            logger.error(f"处理保护器Excel数据失败 (第{row_index}行): {e}")
            raise ValueError(f"第{row_index}行数据格式错误: {e}")

    def _process_separator_excel_data(self, row_data: Dict, is_metric: bool, row_index: int) -> Dict:
        """处理分离器设备Excel数据"""
        try:
            device_data = {
                'device_type': 'separator',
                'manufacturer': self._get_excel_value(row_data, ['制造商', 'Manufacturer']),
                'model': self._get_excel_value(row_data, ['型号', 'Model']),
                'serial_number': (self._get_excel_value(row_data, ['序列号', 'Serial Number']) or 
                                f'IMP_SEPARATOR_{int(datetime.now().timestamp())}_{row_index}'),
                'status': self._get_excel_value(row_data, ['状态', 'Status']) or 'active',
                'description': self._get_excel_value(row_data, ['描述', 'Description']) or ''
            }

            # 分离器详细参数
            separator_details = {
                'separation_efficiency': self._safe_float(self._get_excel_value(row_data, ['分离效率(%)', 'Separation Efficiency(%)'])) or 95.0
            }

            # 🔥 尺寸和处理能力参数（根据单位制）
            if is_metric:
                separator_details['outer_diameter'] = self._safe_float(self._get_excel_value(row_data, ['外径(mm)', 'Outer Diameter(mm)']))
                separator_details['length'] = self._safe_float(self._get_excel_value(row_data, ['长度(mm)', 'Length(mm)']))
                separator_details['weight'] = self._safe_float(self._get_excel_value(row_data, ['重量(kg)', 'Weight(kg)']))
                separator_details['gas_handling_capacity'] = self._safe_float(self._get_excel_value(row_data, ['气体处理量(m³/d)', 'Gas Handling(m³/d)']))
                separator_details['liquid_handling_capacity'] = self._safe_float(self._get_excel_value(row_data, ['液体处理量(m³/d)', 'Liquid Handling(m³/d)']))
            else:
                # 英制转公制
                od_in = self._safe_float(self._get_excel_value(row_data, ['外径(in)', 'Outer Diameter(in)']))
                length_in = self._safe_float(self._get_excel_value(row_data, ['长度(in)', 'Length(in)']))
                weight_lbs = self._safe_float(self._get_excel_value(row_data, ['重量(lbs)', 'Weight(lbs)']))
                gas_scfd = self._safe_float(self._get_excel_value(row_data, ['气体处理量(scf/d)', 'Gas Handling(scf/d)']))
                liquid_bpd = self._safe_float(self._get_excel_value(row_data, ['液体处理量(bbl/d)', 'Liquid Handling(bbl/d)']))
            
                separator_details['outer_diameter'] = od_in * 25.4 if od_in else None  # in to mm
                separator_details['length'] = length_in * 25.4 if length_in else None   # in to mm
                separator_details['weight'] = weight_lbs * 0.453592 if weight_lbs else None  # lbs to kg
                separator_details['gas_handling_capacity'] = gas_scfd * 0.0283168 if gas_scfd else None  # scf/d to m³/d
                separator_details['liquid_handling_capacity'] = liquid_bpd * 0.158987 if liquid_bpd else None  # bbl/d to m³/d

            device_data['separator_details'] = separator_details
            return device_data

        except Exception as e:
            logger.error(f"处理分离器Excel数据失败 (第{row_index}行): {e}")
            raise ValueError(f"第{row_index}行数据格式错误: {e}")

    # 🔥 辅助方法
    def _get_excel_value(self, row_data: Dict, field_names: List[str]):
        """从Excel行数据中获取值（支持多个可能的字段名）"""
        for field_name in field_names:
            if field_name in row_data and row_data[field_name] is not None:
                value = row_data[field_name]
                # 处理空字符串和NaN
                if value != '' and str(value).lower() != 'nan':
                    return value
        return None

    def _safe_float(self, value):
        """安全转换为浮点数"""
        if value is None or value == '' or str(value).lower() == 'nan':
            return None
        try:
            return float(value)
        except (ValueError, TypeError):
            return None

    def _safe_int(self, value):
        """安全转换为整数"""
        if value is None or value == '' or str(value).lower() == 'nan':
            return None
        try:
            return int(float(value))  # 先转float再转int，处理"100.0"这种情况
        except (ValueError, TypeError):
            return None

    def _convert_pump_units(self, param: str, value: float, is_metric: bool) -> float:
        """转换泵参数单位"""
        if value is None:
            return None
        
        # 如果模板已经是正确单位，直接返回
        if is_metric:
            return value
    
        # 英制转公制（系统存储为公制）
        conversion_map = {
            'displacement_min': lambda x: x * 0.158987,  # bbl/d to m³/d
            'displacement_max': lambda x: x * 0.158987,  # bbl/d to m³/d
            'single_stage_head': lambda x: x * 0.3048,   # ft to m
            'single_stage_power': lambda x: x * 0.746,   # HP to kW
            'outside_diameter': lambda x: x * 25.4,      # in to mm
            'shaft_diameter': lambda x: x * 25.4,        # in to mm
            'weight': lambda x: x * 0.453592,            # lbs to kg
            'length': lambda x: x * 25.4,                # in to mm
        }
    
        if param in conversion_map:
            return conversion_map[param](value)
    
        return value

    def _extract_performance_curves(self, row_data: Dict, is_metric: bool) -> Dict:
        """提取性能曲线数据"""
        curves = {
            'flow_points': [],
            'head_points': [],
            'efficiency_points': [],
            'power_points': [],
            'best_efficiency_point': {}
        }
    
        # 🔥 提取5个性能点
        for i in range(1, 6):
            if is_metric:
                flow_key = f'流量点{i}(m³/d)'
                head_key = f'扬程点{i}(m)'
                power_key = f'功率点{i}(kW)'
            else:
                flow_key = f'流量点{i}(bbl/d)'
                head_key = f'扬程点{i}(ft)'
                power_key = f'功率点{i}(HP)'
        
            eff_key = f'效率点{i}(%)'
        
            flow_value = self._get_excel_value(row_data, [flow_key])
            if flow_value:
                flow = self._safe_float(flow_value)
                head = self._safe_float(self._get_excel_value(row_data, [head_key])) or 0
                efficiency = self._safe_float(self._get_excel_value(row_data, [eff_key])) or 0
                power = self._safe_float(self._get_excel_value(row_data, [power_key])) or 0
            
                # 🔥 单位转换（如果需要）
                if not is_metric:  # 英制转公制存储
                    flow = flow * 0.158987 if flow else 0      # bbl/d to m³/d
                    head = head * 0.3048 if head else 0        # ft to m
                    power = power * 0.746 if power else 0      # HP to kW
            
                curves['flow_points'].append(flow)
                curves['head_points'].append(head)
                curves['efficiency_points'].append(efficiency)
                curves['power_points'].append(power)
    
        # 🔥 最优工况点
        if is_metric:
            opt_flow_key = '最优流量(m³/d)'
            opt_head_key = '最优扬程(m)'
            opt_power_key = '最优功率(kW)'
        else:
            opt_flow_key = '最优流量(bbl/d)'
            opt_head_key = '最优扬程(ft)'
            opt_power_key = '最优功率(HP)'
    
        opt_eff_key = '最优效率(%)'
    
        opt_flow = self._safe_float(self._get_excel_value(row_data, [opt_flow_key]))
        if opt_flow:
            opt_head = self._safe_float(self._get_excel_value(row_data, [opt_head_key])) or 0
            opt_efficiency = self._safe_float(self._get_excel_value(row_data, [opt_eff_key])) or 0
            opt_power = self._safe_float(self._get_excel_value(row_data, [opt_power_key])) or 0
        
            # 🔥 单位转换
            if not is_metric:
                opt_flow = opt_flow * 0.158987
                opt_head = opt_head * 0.3048
                opt_power = opt_power * 0.746
        
            curves['best_efficiency_point'] = {
                'flow': opt_flow,
                'head': opt_head,
                'efficiency': opt_efficiency,
                'power': opt_power
            }
    
        return curves