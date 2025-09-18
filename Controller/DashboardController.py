# Controller/DashboardController.py

import logging
from typing import Dict, Any
from PySide6.QtCore import QObject, Signal, Slot, Property
from PySide6.QtQml import QmlElement

# 导入数据服务
from DataManage.services.database_service import DatabaseService

QML_IMPORT_NAME = "Dashboard"
QML_IMPORT_MAJOR_VERSION = 1

logger = logging.getLogger(__name__)

@QmlElement
class DashboardController(QObject):
    """仪表盘控制器 - 提供统计数据"""
    
    # 信号定义
    statisticsUpdated = Signal('QVariant')  # 统计数据更新
    error = Signal(str)                     # 错误信号
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._db_service = DatabaseService()
        self._current_project_id = -1
        
        logger.info("仪表盘控制器初始化完成")
    
    @Property(int)
    def currentProjectId(self):
        return self._current_project_id
    
    @currentProjectId.setter
    def currentProjectId(self, value: int):
        if self._current_project_id != value:
            self._current_project_id = value
            # 项目变更时刷新统计数据
            self.refreshStatistics()
    
    @Slot()
    def refreshStatistics(self):
        """刷新统计数据"""
        try:
            logger.info("刷新仪表盘统计数据")
            
            statistics = {
                'activeWells': self._getActiveWellsCount(),
                'equipmentModels': self._getEquipmentModelsCount(),
                'selectionAccuracy': self._getSelectionAccuracy(),
                'monthlyReports': self._getMonthlyReportsCount()
            }
            
            logger.info(f"统计数据获取成功: {statistics}")
            self.statisticsUpdated.emit(statistics)
            
        except Exception as e:
            error_msg = f"获取统计数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
    
    def _getActiveWellsCount(self) -> int:
        """获取活跃井数量"""
        try:
            if self._current_project_id <= 0:
                # 如果没有选择项目，获取所有项目的井数量
                projects = self._db_service.get_all_projects()
                total_wells = 0
                for project in projects:
                    wells = self._db_service.get_wells_by_project(project['id'])
                    total_wells += len(wells)
                return total_wells
            else:
                # 获取当前项目的井数量
                wells = self._db_service.get_wells_by_project(self._current_project_id)
                return len(wells)
        except Exception as e:
            logger.error(f"获取活跃井数量失败: {e}")
            return 0
    
    def _getEquipmentModelsCount(self) -> int:
        """获取设备型号总数"""
        try:
            # 获取所有设备类型的数量
            pumps = self._db_service.get_devices(device_type='PUMP')
            motors = self._db_service.get_devices(device_type='MOTOR')
            protectors = self._db_service.get_devices(device_type='PROTECTOR')
            separators = self._db_service.get_devices(device_type='SEPARATOR')
            
            total = (pumps.get('total_count', 0) + 
                    motors.get('total_count', 0) + 
                    protectors.get('total_count', 0) + 
                    separators.get('total_count', 0))
            
            return total
        except Exception as e:
            logger.error(f"获取设备型号总数失败: {e}")
            return 0
    
    def _getSelectionAccuracy(self) -> float:
        """获取选型准确率"""
        try:
            # 这里可以基于历史选型数据计算准确率
            # 暂时返回模拟数据，实际可以从选型历史记录中计算
            return 89.5
        except Exception as e:
            logger.error(f"获取选型准确率失败: {e}")
            return 0.0
    
    def _getMonthlyReportsCount(self) -> int:
        """获取本月选型报告数量"""
        try:
            # 这里可以查询本月生成的报告数量
            # 暂时返回模拟数据
            return 42
        except Exception as e:
            logger.error(f"获取月报告数量失败: {e}")
            return 0
    
    @Slot()
    def exportStatisticsReport(self):
        """导出统计报告"""
        try:
            logger.info("导出统计报告")
            # 这里可以实现导出功能
            # 暂时只记录日志
        except Exception as e:
            error_msg = f"导出统计报告失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)