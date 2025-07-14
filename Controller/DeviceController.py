# Controller/DeviceController.py

import json
import os
from typing import List, Dict, Any, Optional
from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property, QAbstractListModel, QModelIndex, Qt
from PySide6.QtCore import QUrl
from PySide6.QtQml import QJSValue
import pandas as pd

from DataManage.services.database_service import DatabaseService
from DataManage.models.device import DeviceType


class DeviceListModel(QAbstractListModel):
    """设备列表模型"""

    # 定义角色
    IdRole = Qt.UserRole + 1
    TypeRole = Qt.UserRole + 2
    ManufacturerRole = Qt.UserRole + 3
    ModelRole = Qt.UserRole + 4
    SerialNumberRole = Qt.UserRole + 5
    StatusRole = Qt.UserRole + 6
    DescriptionRole = Qt.UserRole + 7
    CreatedAtRole = Qt.UserRole + 8
    DetailsRole = Qt.UserRole + 9

    def __init__(self, parent=None):
        super().__init__(parent)
        self._devices = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._devices)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._devices):
            print('怎么他妈的进入这里了')
            return None

        device = self._devices[index.row()]
        # print('让我看啊看role到底是啥', role)
        # print("检查 role 字段",self.IdRole)
        # print("当前设备信息", device)
        # print("当前设备ID", device.get('id'))
        
        if role == self.IdRole:
            device_id = device.get('id')
            # print('yeah device_id:', device_id)
            return device_id
        elif role == self.TypeRole:
            return device.get('device_type', '')
        elif role == self.ManufacturerRole:
            return device.get('manufacturer', '')
        elif role == self.ModelRole:
            # print('yeah model:', device.get('modelDevice', ''))
            return device.get('modelDevice', '')
        elif role == self.SerialNumberRole:
            return device.get('serial_number', '')
        elif role == self.StatusRole:
            return device.get('status', 'active')
        elif role == self.DescriptionRole:
            return device.get('description', '')
        elif role == self.CreatedAtRole:
            return device.get('created_at', '')
        elif role == self.DetailsRole:
            # 返回设备详细信息的JSON字符串
            if device.get('device_type') == 'pump':
                return json.dumps(device.get('pump_details', {}))
            elif device.get('device_type') == 'motor':
                return json.dumps(device.get('motor_details', {}))
            elif device.get('device_type') == 'protector':
                return json.dumps(device.get('protector_details', {}))
            elif device.get('device_type') == 'separator':
                return json.dumps(device.get('separator_details', {}))
            return "{}"
        else:
            print("NOOOOOOOOOOOOOOOO, DeviceController ERROR, line77")

        return None

    def roleNames(self):
        return {
        self.IdRole: b'deviceId',
        self.TypeRole: b'deviceType',
        self.ManufacturerRole: b'manufacturer',
        self.ModelRole: b'modelDevice',
        self.SerialNumberRole: b'serialNumber',
        self.StatusRole: b'status',
        self.DescriptionRole: b'description',
        self.CreatedAtRole: b'createdAt',
        self.DetailsRole: b'details'
    }

    def setDevices(self, devices):
        """设置设备列表"""
        # print(f"这里是setDEVICE,设置设备列表: {len(devices)} 条记录")
        # 调试前3条数据
        # for i, dev in enumerate(devices[:3]):
        #     print(f"设备 {i+1}: ID={dev.get('id')}, 类型={dev.get('device_type')}")
    
        self.beginResetModel()
        self._devices = devices
        self.endResetModel()

    def getDevice(self, index):
        """获取指定索引的设备"""
        if 0 <= index < len(self._devices):
            return self._devices[index]
        return None

    def clear(self):
        """清空列表"""
        self.beginResetModel()
        self._devices = []
        self.endResetModel()


class DeviceController(QObject):
    """设备控制器"""

    # 信号定义
    deviceListChanged = Signal()
    deviceSaved = Signal(bool, str)  # success, message
    deviceDeleted = Signal(bool, str)  # success, message
    importCompleted = Signal(bool, str, int, int)  # success, message, successCount, errorCount
    exportCompleted = Signal(bool, str)  # success, filePath
    errorOccurred = Signal(str)  # errorMessage
    loadingChanged = Signal()
    selectedDeviceChanged = Signal()
    statisticsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

        # 数据库服务
        self._db = DatabaseService()

        # 模型
        self._deviceListModel = DeviceListModel(self)

        # 状态
        self._loading = False
        self._currentPage = 1
        self._pageSize = 20
        self._totalCount = 0
        self._totalPages = 1
        self._currentFilter = {
            'device_type': None,
            'status': None,
            'keyword': ''
        }
        self._selectedDevice = None
        self._statistics = {
            'total_count': 0,
            'type_statistics': {},
            'status_statistics': {}
        }

        # 连接数据库信号
        self._db.deviceListUpdated.connect(self._onDeviceListUpdated)
        self._db.databaseError.connect(self._onDatabaseError)

        # 初始加载
        self.loadDevices()
        self.loadStatistics()

    # 属性
    @Property(QObject, notify=deviceListChanged)
    def deviceListModel(self):
        return self._deviceListModel

    @Property(bool, notify=loadingChanged)
    def loading(self):
        return self._loading

    @Property(int, notify=deviceListChanged)
    def currentPage(self):
        return self._currentPage

    @Property(int, notify=deviceListChanged)
    def totalPages(self):
        return self._totalPages

    @Property(int, notify=deviceListChanged)
    def totalCount(self):
        return self._totalCount

    @Property('QVariant', notify=selectedDeviceChanged)
    def selectedDevice(self):
        return self._selectedDevice or {}

    @Property('QVariant', notify=statisticsChanged)
    def statistics(self):
        return self._statistics

    def _setLoading(self, loading):
        if self._loading != loading:
            self._loading = loading
            self.loadingChanged.emit()

    def _onDeviceListUpdated(self):
        """设备列表更新时重新加载"""
        self.loadDevices()
        self.loadStatistics()

    def _onDatabaseError(self, error_msg):
        """处理数据库错误"""
        self.errorOccurred.emit(error_msg)

    # 设备列表操作
    @Slot()
    def loadDevices(self):
        """加载设备列表"""
        self._setLoading(True)

        try:
            # 调试信息
            # print(f"加载设备: 过滤条件={self._currentFilter}")
        
            # 如果有搜索关键词，使用搜索功能
            if self._currentFilter.get('keyword'):
                devices = self._db.search_devices(
                    keyword=self._currentFilter['keyword'],
                    device_type=self._currentFilter.get('device_type')
                )
                # 打印找到的设备
                # print(f"这里是loaddevice，检索到 {len(devices)} 个设备")
                # for device in devices[:3]:  # 只打印前三个
                #     print(f"设备: ID={device.get('id')}, 型号={device.get('modelDevice')}")
                
                self._deviceListModel.setDevices(devices)
                self._totalCount = len(devices)
                self._totalPages = 1
                self._currentPage = 1
            else:
                # 否则使用分页加载
                result = self._db.get_devices(
                    device_type=self._currentFilter.get('device_type'),
                    status=self._currentFilter.get('status'),
                    page=self._currentPage,
                    page_size=self._pageSize
                )

                self._deviceListModel.setDevices(result['devices'])
                self._totalCount = result['total_count']
                self._totalPages = result['total_pages']

            self.deviceListChanged.emit()

        except Exception as e:
            self.errorOccurred.emit(f"加载设备列表失败: {str(e)}")

        finally:
            self._setLoading(False)

    @Slot(str)
    def filterByType(self, device_type):
        """按类型筛选"""
        if device_type == "all":
            self._currentFilter['device_type'] = None
        else:
            self._currentFilter['device_type'] = device_type
        self._currentPage = 1
        self.loadDevices()

    @Slot(str)
    def filterByStatus(self, status):
        """按状态筛选"""
        if status == "all":
            self._currentFilter['status'] = None
        else:
            self._currentFilter['status'] = status
        self._currentPage = 1
        self.loadDevices()

    @Slot(str)
    def searchDevices(self, keyword):
        """搜索设备"""
        self._currentFilter['keyword'] = keyword.strip()
        self._currentPage = 1
        self.loadDevices()

    @Slot(int)
    def goToPage(self, page):
        """跳转到指定页"""
        if 1 <= page <= self._totalPages:
            self._currentPage = page
            self.loadDevices()

    @Slot()
    def nextPage(self):
        """下一页"""
        if self._currentPage < self._totalPages:
            self._currentPage += 1
            self.loadDevices()

    @Slot()
    def previousPage(self):
        """上一页"""
        if self._currentPage > 1:
            self._currentPage -= 1
            self.loadDevices()

    # 设备详情操作
    @Slot(int)
    def selectDevice(self, device_id):
        """选择设备查看详情"""
        self._setLoading(True)

        try:
            device = self._db.get_device_by_id(device_id)
            if device:
                self._selectedDevice = device
                self.selectedDeviceChanged.emit()
            else:
                self.errorOccurred.emit("设备不存在")

        except Exception as e:
            self.errorOccurred.emit(f"获取设备详情失败: {str(e)}")

        finally:
            self._setLoading(False)

    @Slot()
    def clearSelectedDevice(self):
        """清除选中的设备"""
        self._selectedDevice = None
        self.selectedDeviceChanged.emit()

    # 设备CRUD操作
    @Slot(str)
    def saveDevice(self, device_data):
        """保存设备（新建或更新）"""
        self._setLoading(True)


        try:
             # 解析JSON字符串为Python字典
            data = json.loads(device_data)
        
            # 转换QML传来的数据
            # data = dict(device_data)

            # 处理设备详情数据
            device_type = data.get('device_type')
            if device_type == 'pump':
                data['pump_details'] = data.get('pump_details', {})
            elif device_type == 'motor':
                data['motor_details'] = data.get('motor_details', {})
                # 处理频率参数
                freq_params = data['motor_details'].get('frequency_params', [])
                if isinstance(freq_params, str):
                    data['motor_details']['frequency_params'] = json.loads(freq_params)
            elif device_type == 'protector':
                data['protector_details'] = data.get('protector_details', {})
            elif device_type == 'separator':
                data['separator_details'] = data.get('separator_details', {})

            # 判断是新建还是更新
            device_id = data.get('id', -1)
            if device_id and device_id > 0:
                # 更新
                success = self._db.update_device(device_id, data)
                if success:
                    self.deviceSaved.emit(True, "设备更新成功")
                else:
                    self.deviceSaved.emit(False, "设备更新失败")
            else:
                # 新建
                new_id = self._db.create_device(data)
                if new_id:
                    self.deviceSaved.emit(True, "设备创建成功")
                else:
                    self.deviceSaved.emit(False, "设备创建失败")

        except Exception as e:
            self.deviceSaved.emit(False, str(e))
            self.errorOccurred.emit(f"保存设备失败: {str(e)}")

        finally:
            self._setLoading(False)

    @Slot(int)
    def deleteDevice(self, device_id):
        """删除设备"""
        self._setLoading(True)

        try:
            success = self._db.delete_device(device_id)
            if success:
                self.deviceDeleted.emit(True, "设备删除成功")
                # 如果删除的是当前选中的设备，清除选择
                if self._selectedDevice and self._selectedDevice.get('id') == device_id:
                    self.clearSelectedDevice()
            else:
                self.deviceDeleted.emit(False, "设备删除失败")

        except Exception as e:
            self.deviceDeleted.emit(False, str(e))
            self.errorOccurred.emit(f"删除设备失败: {str(e)}")

        finally:
            self._setLoading(False)

    @Slot(list)
    def batchDeleteDevices(self, device_ids):
        """批量删除设备"""
        self._setLoading(True)

        try:
            success = self._db.batch_delete_devices(device_ids)
            if success:
                self.deviceDeleted.emit(True, f"成功删除{len(device_ids)}个设备")
            else:
                self.deviceDeleted.emit(False, "批量删除失败")

        except Exception as e:
            self.deviceDeleted.emit(False, str(e))
            self.errorOccurred.emit(f"批量删除失败: {str(e)}")

        finally:
            self._setLoading(False)

    # 导入导出操作
    @Slot(str, str)
    def importFromExcel(self, file_url, device_type):
        """从Excel导入设备"""
        self._setLoading(True)

        try:
            # 处理文件路径
            file_path = QUrl(file_url).toLocalFile()
            if not os.path.exists(file_path):
                raise ValueError("文件不存在")

            # 读取Excel文件
            df = pd.read_excel(file_path)
            excel_data = df.to_dict('records')

            # 导入数据
            result = self._db.import_devices_from_excel(excel_data, device_type)

            self.importCompleted.emit(
                True,
                f"导入完成：成功{result['success_count']}条，失败{result['error_count']}条",
                result['success_count'],
                result['error_count']
            )

            # 如果有错误，显示错误详情
            if result['errors']:
                error_details = "\n".join([
                    f"第{err['row']}行: {err['error']}"
                    for err in result['errors'][:5]  # 只显示前5个错误
                ])
                if len(result['errors']) > 5:
                    error_details += f"\n...还有{len(result['errors']) - 5}个错误"
                self.errorOccurred.emit(f"导入错误详情:\n{error_details}")

        except Exception as e:
            self.importCompleted.emit(False, str(e), 0, 0)
            self.errorOccurred.emit(f"导入失败: {str(e)}")

        finally:
            self._setLoading(False)

    @Slot(str, str, result=str)
    def exportToExcel(self, save_url, device_type):
        """导出设备到Excel"""
        self._setLoading(True)

        try:
            # 处理文件路径
            file_path = QUrl(save_url).toLocalFile()

            # 确定设备类型
            export_type = None if device_type == "all" else device_type

            # 获取数据
            data = self._db.export_devices_to_dict(export_type)

            if not data:
                self.exportCompleted.emit(False, "没有数据可导出")
                return file_path

            # 创建DataFrame
            df = pd.DataFrame(data)

            # 根据设备类型设置列顺序
            if device_type == "pump":
                columns = [
                    'manufacturer', 'modelDevice', 'serial_number', 'status',
                    'impeller_model', 'displacement_min', 'displacement_max',
                    'single_stage_head', 'single_stage_power', 'shaft_diameter',
                    'mounting_height', 'outside_diameter', 'max_stages', 'efficiency',
                    'description', 'created_at'
                ]
            elif device_type == "motor":
                columns = [
                    'manufacturer', 'modelDevice', 'serial_number', 'status',
                    'motor_type', 'outside_diameter', 'length', 'weight',
                    'insulation_class', 'protection_class',
                    'power_50hz', 'voltage_50hz', 'current_50hz', 'speed_50hz',
                    'power_60hz', 'voltage_60hz', 'current_60hz', 'speed_60hz',
                    'description', 'created_at'
                ]
            elif device_type == "protector":
                columns = [
                    'manufacturer', 'modelDevice', 'serial_number', 'status',
                    'outer_diameter', 'length', 'weight', 'thrust_capacity',
                    'seal_type', 'max_temperature',
                    'description', 'created_at'
                ]
            elif device_type == "separator":
                columns = [
                    'manufacturer', 'modelDevice', 'serial_number', 'status',
                    'outer_diameter', 'length', 'weight',
                    'separation_efficiency', 'gas_handling_capacity',
                    'liquid_handling_capacity',
                    'description', 'created_at'
                ]
            else:
                # 所有设备类型，使用所有列
                columns = list(df.columns)

            # 重新排序列
            columns = [col for col in columns if col in df.columns]
            df = df[columns]

            # 保存到Excel
            with pd.ExcelWriter(file_path, engine='openpyxl') as writer:
                df.to_excel(writer, sheet_name='设备数据', index=False)

                # 调整列宽
                worksheet = writer.sheets['设备数据']
                for idx, col in enumerate(df.columns):
                    max_length = max(
                        df[col].astype(str).map(len).max(),
                        len(str(col))
                    ) + 2
                    worksheet.column_dimensions[chr(65 + idx)].width = min(max_length, 30)

            self.exportCompleted.emit(True, file_path)
            return file_path

        except Exception as e:
            self.exportCompleted.emit(False, "")
            self.errorOccurred.emit(f"导出失败: {str(e)}")
            return ""

        finally:
            self._setLoading(False)

    # 统计功能
    @Slot()
    def loadStatistics(self):
        """加载设备统计信息"""
        try:
            self._statistics = self._db.get_device_statistics()
            self.statisticsChanged.emit()

        except Exception as e:
            self.errorOccurred.emit(f"加载统计信息失败: {str(e)}")

    # 工具方法
    @Slot(result=list)
    def getDeviceTypes(self):
        """获取设备类型列表"""
        return [
            {'value': 'pump', 'label': '潜油离心泵', 'label_en': 'Centrifugal Pump'},
            {'value': 'motor', 'label': '电机', 'label_en': 'Motor'},
            {'value': 'protector', 'label': '保护器', 'label_en': 'Protector'},
            {'value': 'separator', 'label': '分离器', 'label_en': 'Separator'}
        ]

    @Slot(result=list)
    def getDeviceStatuses(self):
        """获取设备状态列表"""
        return [
            {'value': 'active', 'label': '正常', 'label_en': 'Active'},
            {'value': 'inactive', 'label': '停用', 'label_en': 'Inactive'},
            {'value': 'maintenance', 'label': '维护中', 'label_en': 'Maintenance'}
        ]

    @Slot(str, result=str)
    def getDeviceTypeLabel(self, device_type):
        """获取设备类型标签"""
        type_labels = {
            'pump': '潜油离心泵',
            'motor': '电机',
            'protector': '保护器',
            'separator': '分离器'
        }
        return type_labels.get(device_type, device_type)

    @Slot(str, result=str)
    def getStatusLabel(self, status):
        """获取状态标签"""
        status_labels = {
            'active': '正常',
            'inactive': '停用',
            'maintenance': '维护中'
        }
        return status_labels.get(status, status)

    @Slot(result=str)
    def getExcelTemplate(self, device_type):
        """获取Excel导入模板路径"""
        # 这里可以返回预定义的Excel模板文件路径
        template_dir = os.path.join(os.path.dirname(__file__), '..', 'templates')
        template_path = os.path.join(template_dir, f'{device_type}_template.xlsx')

        if os.path.exists(template_path):
            return QUrl.fromLocalFile(template_path).toString()
        else:
            return ""

    @Slot(str)
    def saveDeviceFromJson(self, formDataJson):
        """从JSON字符串保存设备"""
        self._setLoading(True)

        try:
            # 解析JSON字符串为Python字典
            data = json.loads(formDataJson)
        
            # 处理设备详情数据
            device_type = data.get('device_type')
            device_id = data.get('id')
        
            # 判断是新建还是更新
            if device_id and device_id > 0:
                # 更新
                success = self._db.update_device(device_id, data)
                if success:
                    self.deviceSaved.emit(True, "设备更新成功")
                else:
                    self.deviceSaved.emit(False, "设备更新失败")
            else:
                # 新建
                new_id = self._db.create_device(data)
                if new_id:
                    self.deviceSaved.emit(True, "设备创建成功")
                else:
                    self.deviceSaved.emit(False, "设备创建失败")

        except Exception as e:
            self.deviceSaved.emit(False, str(e))
            self.errorOccurred.emit(f"保存设备失败: {str(e)}")

        finally:
            self._setLoading(False)

