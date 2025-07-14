# Controller/WellDataController.py

from PySide6.QtCore import QObject, Signal, Slot, Property
from typing import List, Dict, Optional
import logging

logger = logging.getLogger(__name__)

class WellDataController(QObject):
    """井数据控制器 - 管理井数据的CRUD操作"""

    # 原有信号
    wellDataLoaded = Signal(dict)      # 井数据加载完成
    wellDataSaved = Signal(bool)       # 井数据保存结果
    operationStarted = Signal()        # 操作开始
    operationFinished = Signal()       # 操作结束
    error = Signal(str)                # 错误信号

    # 新增信号
    wellListLoaded = Signal(list)      # 井列表加载完成
    wellCreated = Signal(int, str)     # 井ID, 井名
    wellUpdated = Signal(int, str)     # 井ID, 井名
    wellDeleted = Signal(int, str)     # 井ID, 井名
    currentWellChanged = Signal()      # 当前井改变

    def __init__(self):
        super().__init__()
        self._db_service = None
        self._current_well_data = {}
        self._well_list = []
        self._current_well_id = -1

        # 获取数据库服务实例
        from DataManage.services.database_service import DatabaseService
        self._db_service = DatabaseService()

        # 连接数据库信号
        self._db_service.wellDataSaved.connect(self._on_well_data_saved)
        self._db_service.databaseError.connect(self._on_database_error)

    # ========== 信号处理函数 ==========

    @Slot(int)
    def _on_well_data_saved(self, project_id):
        """处理数据库井数据保存信号"""
        logger.info(f"井数据已保存，项目ID: {project_id}")
        # 可以在这里添加额外的处理逻辑

    @Slot(str)
    def _on_database_error(self, error_msg):
        """处理数据库错误信号"""
        logger.error(f"数据库错误: {error_msg}")
        self.error.emit(error_msg)

    # ========== 属性定义 ==========

    @Property(dict, notify=currentWellChanged)
    def currentWellData(self):
        """当前井数据属性"""
        return self._current_well_data

    @Property(list, notify=wellListLoaded)
    def wellList(self):
        """井列表属性"""
        return self._well_list

    # ========== 井列表管理方法 ==========

    @Slot(int)
    def getWellList(self, project_id: int):
        """获取项目下所有井列表"""
        self.operationStarted.emit()
        try:
            wells = self._db_service.get_wells_by_project(project_id)
            self._well_list = wells
            self.wellListLoaded.emit(wells)
            logger.info(f"加载井列表成功，共 {len(wells)} 口井")
        except Exception as e:
            error_msg = f"获取井列表失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(int)
    def getWellById(self, well_id: int):
        """根据ID获取井信息"""
        self.operationStarted.emit()
        try:
            well_data = self._db_service.get_well_by_id(well_id)
            if well_data:
                self._current_well_data = well_data
                self._current_well_id = well_id
                self.currentWellChanged.emit()
                self.wellDataLoaded.emit(well_data)
                logger.info(f"加载井信息成功: {well_data.get('well_name')}")
            else:
                self.error.emit("井不存在")
        except Exception as e:
            error_msg = f"获取井信息失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(dict)
    def createWell(self, well_data: dict):
        """创建新井"""
        self.operationStarted.emit()
        try:
            # 数据验证
            is_valid, error_msg = self.validateWellData(well_data)
            if not is_valid:
                self.error.emit(error_msg)
                self.wellDataSaved.emit(False)
                return

            well_id = self._db_service.create_well(well_data)
            well_name = well_data.get('well_name', '')

            self.wellCreated.emit(well_id, well_name)
            self.wellDataSaved.emit(True)
            logger.info(f"创建井成功: {well_name}, ID: {well_id}")

        except Exception as e:
            error_msg = f"创建井失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.wellDataSaved.emit(False)
        finally:
            self.operationFinished.emit()

    @Slot(dict)
    def updateWellData(self, updates: dict):
        """更新井数据"""
        self.operationStarted.emit()
        try:
            well_id = updates.get('id')
            if not well_id:
                self.error.emit("缺少井ID")
                self.wellDataSaved.emit(False)
                return

            # 移除id字段，避免更新主键
            update_data = {k: v for k, v in updates.items() if k != 'id'}

            # 数据验证
            is_valid, error_msg = self.validateWellData(update_data, is_update=True)
            if not is_valid:
                self.error.emit(error_msg)
                self.wellDataSaved.emit(False)
                return

            success = self._db_service.update_well(well_id, update_data)
            if success:
                well_name = update_data.get('well_name', '')
                self.wellUpdated.emit(well_id, well_name)
                self.wellDataSaved.emit(True)

                # 如果是当前井，更新缓存
                if well_id == self._current_well_id:
                    self._current_well_data.update(update_data)
                    self.currentWellChanged.emit()

                logger.info(f"更新井成功: ID {well_id}")
            else:
                self.wellDataSaved.emit(False)

        except Exception as e:
            error_msg = f"更新井失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.wellDataSaved.emit(False)
        finally:
            self.operationFinished.emit()

    @Slot(int)
    def deleteWell(self, well_id: int):
        """删除井"""
        self.operationStarted.emit()
        try:
            well = self._db_service.get_well_by_id(well_id)
            if not well:
                self.error.emit("井不存在")
                return

            success = self._db_service.delete_well(well_id)
            if success:
                well_name = well.get('well_name', '')
                self.wellDeleted.emit(well_id, well_name)

                # 如果删除的是当前井，清空当前井数据
                if well_id == self._current_well_id:
                    self._current_well_data = {}
                    self._current_well_id = -1
                    self.currentWellChanged.emit()

                logger.info(f"删除井成功: {well_name}")

        except Exception as e:
            error_msg = f"删除井失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    @Slot(int, str)
    def searchWells(self, project_id: int, keyword: str):
        """搜索井"""
        self.operationStarted.emit()
        try:
            wells = self._db_service.search_wells(project_id, keyword)
            self._well_list = wells
            self.wellListLoaded.emit(wells)
            logger.info(f"搜索井完成，找到 {len(wells)} 口井")
        except Exception as e:
            error_msg = f"搜索井失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
        finally:
            self.operationFinished.emit()

    # ========== 兼容旧接口的方法 ==========

    @Slot(int)
    def getWellData(self, project_id: int):
        """获取井数据（兼容旧接口）"""
        # 旧接口是获取项目的第一口井
        # 新版本改为获取井列表
        self.getWellList(project_id)

    @Slot(dict)
    def saveWellData(self, well_data: dict):
        """保存井数据（兼容旧接口）"""
        # 判断是创建还是更新
        if well_data.get('id'):
            self.updateWellData(well_data)
        else:
            self.createWell(well_data)

    # ========== 便捷更新方法 ==========

    @Slot(float)
    def updateWellMD(self, value: float):
        """更新井深"""
        if self._current_well_id > 0:
            self.updateWellData({'id': self._current_well_id, 'well_md': value})

    @Slot(float)
    def updateInnerDiameter(self, value: float):
        """更新内径"""
        if self._current_well_id > 0:
            self.updateWellData({'id': self._current_well_id, 'inner_diameter': value})

    @Slot(float)
    def updateOuterDiameter(self, value: float):
        """更新外径"""
        if self._current_well_id > 0:
            self.updateWellData({'id': self._current_well_id, 'outer_diameter': value})

    @Slot(float)
    def updatePumpDepth(self, value: float):
        """更新泵挂深度"""
        if self._current_well_id > 0:
            self.updateWellData({'id': self._current_well_id, 'pump_depth': value})

    @Slot(float)
    def updateTubingDiameter(self, value: float):
        """更新管径"""
        if self._current_well_id > 0:
            self.updateWellData({'id': self._current_well_id, 'tubing_diameter': value})

    # ========== 辅助方法 ==========

    @Slot(result=dict)
    def getCurrentWell(self) -> dict:
        """获取当前井数据"""
        return self._current_well_data

    @Slot(dict, result=list)
    def validateWellData(self, well_data: dict, is_update: bool = False) -> tuple:
        """验证井数据

        Args:
            well_data: 井数据字典
            is_update: 是否是更新操作

        Returns:
            (is_valid, error_message) 元组
        """
        errors = []

        # 新建时必须有项目ID
        if not is_update and not well_data.get('project_id'):
            errors.append("缺少项目ID")

        # 井名验证
        if not is_update and not well_data.get('well_name'):
            errors.append("井名不能为空")
        elif 'well_name' in well_data:
            well_name = well_data.get('well_name', '').strip()
            if not well_name:
                errors.append("井名不能为空")
            elif len(well_name) > 100:
                errors.append("井名长度不能超过100个字符")

        # 井深验证
        if 'well_md' in well_data and well_data['well_md'] is not None:
            try:
                depth = float(well_data['well_md'])
                if depth <= 0:
                    errors.append("井深必须大于0")
                elif depth > 10000:
                    errors.append("井深数值异常，请检查")
            except (ValueError, TypeError):
                errors.append("井深必须是有效数字")

        # 数值字段验证
        numeric_fields = {
            'inner_diameter': ("内径", 0, 5000),
            'outer_diameter': ("外径", 0, 5000),
            'pump_depth': ("泵挂深度", 0, 10000),
            'tubing_diameter': ("管径", 0, 5000),
            'roughness': ("粗糙度", 0, 100),
            'well_tvd': ("垂深", 0, 10000),
            'well_dls': ("造斜率", 0, 90)
        }

        for field, (name, min_val, max_val) in numeric_fields.items():
            if field in well_data and well_data[field] is not None:
                try:
                    value = float(well_data[field])
                    if value < min_val:
                        errors.append(f"{name}不能小于{min_val}")
                    elif value > max_val:
                        errors.append(f"{name}不能大于{max_val}")
                except (ValueError, TypeError):
                    errors.append(f"{name}必须是有效数字")

        # 逻辑验证
        if ('inner_diameter' in well_data and 'outer_diameter' in well_data and
            well_data['inner_diameter'] is not None and well_data['outer_diameter'] is not None):
            try:
                inner = float(well_data['inner_diameter'])
                outer = float(well_data['outer_diameter'])
                if inner >= outer:
                    errors.append("内径必须小于外径")
            except (ValueError, TypeError):
                pass

        if errors:
            return False, "; ".join(errors)
        return True, ""

    @Slot()
    def clearCurrentWell(self):
        """清空当前井数据"""
        self._current_well_data = {}
        self._current_well_id = -1
        self.currentWellChanged.emit()
