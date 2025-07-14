# Controller/ReservoirDataController.py

from PySide6.QtCore import QObject, Signal, Slot, Property
from typing import Dict, Any, Optional
import logging

# 导入数据库服务
from DataManage.services.database_service import DatabaseService

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ReservoirDataController(QObject):
    """油藏数据控制器 - 处理油藏数据相关操作"""

    # 定义信号
    reservoirDataLoaded = Signal(dict)     # 油藏数据加载完成
    reservoirDataSaved = Signal(int)       # 油藏数据保存成功 (项目ID)
    operationStarted = Signal(str)         # 操作开始 (操作类型)
    operationFinished = Signal(str, bool)  # 操作结束 (操作类型, 是否成功)
    error = Signal(str)                    # 错误信息

    def __init__(self, parent=None):
        super().__init__(parent)

        # 获取数据库服务实例
        self._db_service = DatabaseService()

        # 当前油藏数据
        self._current_reservoir_data = {}

        # 连接数据库服务信号
        self._connect_signals()

        logger.info("油藏数据控制器初始化完成")

    def _connect_signals(self):
        """连接数据库服务信号"""
        # 连接油藏数据保存信号
        self._db_service.reservoirDataSaved.connect(self._on_reservoir_data_saved)

        # 连接错误信号
        self._db_service.databaseError.connect(self._on_database_error)

    # 信号处理函数
    def _on_reservoir_data_saved(self, project_id: int):
        """处理油藏数据保存信号"""
        logger.info(f"油藏数据已保存: 项目ID {project_id}")
        # 重新加载油藏数据
        self.getReservoirData(project_id)
        # 发射油藏数据保存信号
        self.reservoirDataSaved.emit(project_id)
        self.operationFinished.emit("save", True)

    def _on_database_error(self, error_message: str):
        """处理数据库错误信号"""
        logger.error(f"数据库错误: {error_message}")
        # 发射错误信号
        self.error.emit(error_message)
        self.operationFinished.emit("unknown", False)

    # 属性 - 当前油藏数据
    def _get_current_reservoir_data(self) -> Dict[str, Any]:
        return self._current_reservoir_data

    # 定义当前油藏数据属性，可以在QML中绑定
    currentReservoirData = Property(dict, _get_current_reservoir_data, notify=reservoirDataLoaded)

    # 槽函数 - 供QML调用
    @Slot(int, result=dict)
    def getReservoirData(self, project_id: int) -> Dict[str, Any]:
        """根据项目ID获取油藏数据"""
        try:
            logger.info(f"获取油藏数据: 项目ID {project_id}")

            # 调用数据库服务获取油藏数据
            reservoir_data = self._db_service.get_reservoir_data_by_project(project_id)

            if reservoir_data:
                # 更新当前油藏数据缓存
                self._current_reservoir_data = reservoir_data
                # 发射油藏数据加载信号
                self.reservoirDataLoaded.emit(reservoir_data)

                logger.info(f"油藏数据加载成功: 项目ID {project_id}")
                return reservoir_data
            else:
                logger.info(f"未找到油藏数据: 项目ID {project_id}")
                self._current_reservoir_data = {}
                self.reservoirDataLoaded.emit({})
                return {}

        except Exception as e:
            error_msg = f"获取油藏数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            return {}

    @Slot(int, float, float, float, float, float, float, float, float, float, result=bool)
    def saveReservoirData(self, project_id: int,
                         geo_produce_index: float = None,
                         expected_production: float = None,
                         saturation_pressure: float = None,
                         geo_pressure: float = None,
                         bht: float = None,
                         bsw: float = None,
                         api: float = None,
                         gas_oil_ratio: float = None,
                         well_head_pressure: float = None) -> bool:
        """保存油藏数据"""
        try:
            logger.info(f"开始保存油藏数据: 项目ID {project_id}")
            self.operationStarted.emit("save")

            # 创建油藏数据字典
            reservoir_data = {
                'project_id': project_id
            }

            # 只添加非None的值
            if geo_produce_index is not None: reservoir_data['geo_produce_index'] = geo_produce_index
            if expected_production is not None: reservoir_data['expected_production'] = expected_production
            if saturation_pressure is not None: reservoir_data['saturation_pressure'] = saturation_pressure
            if geo_pressure is not None: reservoir_data['geo_pressure'] = geo_pressure
            if bht is not None: reservoir_data['bht'] = bht
            if bsw is not None: reservoir_data['bsw'] = bsw
            if api is not None: reservoir_data['api'] = api
            if gas_oil_ratio is not None: reservoir_data['gas_oil_ratio'] = gas_oil_ratio
            if well_head_pressure is not None: reservoir_data['well_head_pressure'] = well_head_pressure

            # 调用数据库服务保存油藏数据
            reservoir_id = self._db_service.save_reservoir_data(reservoir_data)

            if reservoir_id <= 0:
                raise Exception("保存油藏数据失败")

            logger.info(f"油藏数据保存成功: 项目ID {project_id}, 油藏数据ID {reservoir_id}")
            return True

        except Exception as e:
            error_msg = f"保存油藏数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.operationFinished.emit("save", False)
            return False

    @Slot(int, dict, result=bool)
    def updateReservoirData(self, project_id: int, updates: Dict[str, Any]) -> bool:
        """更新油藏数据 - 接受字典格式的更新数据"""
        try:
            logger.info(f"开始更新油藏数据: 项目ID {project_id}")
            self.operationStarted.emit("update")

            # 确保有项目ID
            updates['project_id'] = project_id

            # 调用数据库服务保存/更新油藏数据
            reservoir_id = self._db_service.save_reservoir_data(updates)

            if reservoir_id <= 0:
                raise Exception("更新油藏数据失败")

            logger.info(f"油藏数据更新成功: 项目ID {project_id}")
            return True

        except Exception as e:
            error_msg = f"更新油藏数据失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.operationFinished.emit("update", False)
            return False

    # 便捷更新方法 - 单个字段
    @Slot(int, float, result=bool)
    def updateGeoProduceIndex(self, project_id: int, geo_produce_index: float) -> bool:
        """更新地质生产指数"""
        return self.updateReservoirData(project_id, {'geo_produce_index': geo_produce_index})

    @Slot(int, float, result=bool)
    def updateExpectedProduction(self, project_id: int, expected_production: float) -> bool:
        """更新预期产量"""
        return self.updateReservoirData(project_id, {'expected_production': expected_production})

    @Slot(int, float, result=bool)
    def updateSaturationPressure(self, project_id: int, saturation_pressure: float) -> bool:
        """更新饱和压力"""
        return self.updateReservoirData(project_id, {'saturation_pressure': saturation_pressure})

    @Slot(int, float, result=bool)
    def updateGeoPressure(self, project_id: int, geo_pressure: float) -> bool:
        """更新地层压力"""
        return self.updateReservoirData(project_id, {'geo_pressure': geo_pressure})

    @Slot(int, float, result=bool)
    def updateBHT(self, project_id: int, bht: float) -> bool:
        """更新油藏温度"""
        return self.updateReservoirData(project_id, {'bht': bht})

    @Slot(int, float, result=bool)
    def updateBSW(self, project_id: int, bsw: float) -> bool:
        """更新含水率"""
        return self.updateReservoirData(project_id, {'bsw': bsw})

    @Slot(int, float, result=bool)
    def updateAPI(self, project_id: int, api: float) -> bool:
        """更新API度"""
        return self.updateReservoirData(project_id, {'api': api})

    @Slot(int, float, result=bool)
    def updateGasOilRatio(self, project_id: int, gas_oil_ratio: float) -> bool:
        """更新气油比"""
        return self.updateReservoirData(project_id, {'gas_oil_ratio': gas_oil_ratio})

    @Slot(int, float, result=bool)
    def updateWellHeadPressure(self, project_id: int, well_head_pressure: float) -> bool:
        """更新井口压力"""
        return self.updateReservoirData(project_id, {'well_head_pressure': well_head_pressure})

    @Slot(result=dict)
    def getCurrentReservoirData(self) -> Dict[str, Any]:
        """获取当前油藏数据"""
        return self._current_reservoir_data

    @Slot(dict, result=dict)
    def validateReservoirData(self, reservoir_data: Dict[str, Any]) -> Dict[str, Any]:
        """验证油藏数据的有效性，返回验证结果"""
        validation_result = {
            'isValid': True,
            'errors': {}
        }

        # 验证逻辑 - 可以根据实际需求扩展
        # 例如：验证压力范围、温度范围等

        if 'saturation_pressure' in reservoir_data and 'geo_pressure' in reservoir_data:
            if reservoir_data['saturation_pressure'] > reservoir_data['geo_pressure']:
                validation_result['isValid'] = False
                validation_result['errors']['saturation_pressure'] = "饱和压力不能大于地层压力"

        if 'bsw' in reservoir_data:
            if reservoir_data['bsw'] < 0 or reservoir_data['bsw'] > 100:
                validation_result['isValid'] = False
                validation_result['errors']['bsw'] = "含水率必须在0-100之间"

        if 'api' in reservoir_data:
            if reservoir_data['api'] < 0:
                validation_result['isValid'] = False
                validation_result['errors']['api'] = "API度必须为正数"

        # 返回验证结果
        return validation_result
