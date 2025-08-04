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
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from datetime import datetime
import logging
logger = logging.getLogger(__name__)


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
            model_value = device.get('model', '')
            result = str(model_value) if model_value is not None else ''
            print(f'返回 model 值: "{result}" (原始值: {model_value})')
            return result  # 🔥 确保返回字符串
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
        self.ModelRole: b'deviceModel',
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
    # 添加信号定义（在类的开头信号部分）
    pumpCurvesDataReady = Signal('QVariant')  # 泵性能曲线数据准备就绪
    # 🔥 新增导出相关信号
    exportCompleted = Signal(str, int)      # 文件路径, 导出数量
    exportProgress = Signal(int, int)       # 当前进度, 总数
    exportFailed = Signal(str)              # 错误信息
    # 🔥 添加模板生成相关信号
    templateGenerated = Signal(str)        # 模板生成成功
    templateGenerationFailed = Signal(str) # 模板生成失败

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

    @Slot(str, str, bool)
    def importFromExcel(self, file_url, device_type, is_metric=False):
        """从Excel导入设备（修复版本）"""
        self._setLoading(True)

        try:
            # 处理文件路径
            file_path = QUrl(file_url).toLocalFile()
            if not os.path.exists(file_path):
                raise ValueError("文件不存在")

            # 读取Excel文件
            df = pd.read_excel(file_path)
            excel_data = df.to_dict('records')

            # 🔥 调用修复后的数据库导入方法
            result = self._db.import_devices_from_excel(excel_data, device_type, is_metric)

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

    # 在DeviceController类中添加以下方法

    @Slot(int, result='QVariant')
    def getPumpPerformanceCurves(self, pump_id):
        """获取泵性能曲线数据"""
        try:
            # 获取泵的基本信息
            pump = self._db.get_device_by_id(pump_id)
            if not pump or pump.get('device_type') != 'pump':
                return {'has_data': False, 'error': 'pump_not_found'}
            
            pump_details = pump.get('pump_details', {})
        
            # 生成性能曲线数据（基于泵的参数）
            curves_data = self._generatePumpCurves(pump_details)
        
            return {
                'has_data': True,
                'pump_info': {
                    'manufacturer': pump.get('manufacturer', ''),
                    'model': pump.get('modelDevice', ''),
                    'impeller_model': pump_details.get('impeller_model', ''),
                    'stages': pump_details.get('max_stages', 87),
                    'outside_diameter': pump_details.get('outside_diameter', 5.62)
                },
                'baseCurves': curves_data['baseCurves'],
                'operatingPoints': curves_data['operatingPoints'],
                'performanceZones': curves_data['performanceZones']
            }
        
        except Exception as e:
            print(f"获取泵性能曲线失败: {str(e)}")
            return {'has_data': False, 'error': str(e)}

    @Slot(str, result='QVariant') 
    def getPumpCurvesByModel(self, pump_model):
        """根据泵型号获取性能曲线数据"""
        try:
            # 根据型号查找泵
            pumps = self._db.search_devices(keyword=pump_model, device_type='pump')
            if not pumps:
                return {'has_data': False, 'error': 'pump_model_not_found'}
            
            # 使用第一个匹配的泵
            pump = pumps[0]
            return self.getPumpPerformanceCurves(pump.get('id'))
        
        except Exception as e:
            print(f"根据型号获取泵性能曲线失败: {str(e)}")
            return {'has_data': False, 'error': str(e)}

    def _generatePumpCurves(self, pump_details):
        """生成泵性能曲线数据"""
        import numpy as np
    
        # 获取泵的基本参数
        single_stage_head = pump_details.get('single_stage_head', 12.0)  # ft
        single_stage_power = pump_details.get('single_stage_power', 2.5)  # HP
        efficiency = pump_details.get('efficiency', 75.0)  # %
        displacement_min = pump_details.get('displacement_min', 100)  # bbl/d
        displacement_max = pump_details.get('displacement_max', 2000)  # bbl/d
        max_stages = pump_details.get('max_stages', 87)
    
        # 生成流量范围（bbl/d）
        flow_points = np.linspace(displacement_min, displacement_max, 20)
    
        # 计算性能曲线（基于典型的离心泵特性）
        flow_normalized = flow_points / displacement_max
    
        # 扬程曲线（抛物线形状）
        head_curve = []
        for f_norm in flow_normalized:
            # 典型的扬程-流量关系：H = H0 * (1 - a*Q^2)
            head_coeff = 1.0 - 0.3 * (f_norm ** 2)
            head = single_stage_head * head_coeff
            head_curve.append(max(head, 0))
    
        # 效率曲线（钟形曲线）
        efficiency_curve = []
        for f_norm in flow_normalized:
            # 效率在60-80%流量范围内最高
            if f_norm < 0.3:
                eff = efficiency * (0.5 + 1.67 * f_norm)
            elif f_norm <= 0.8:
                eff = efficiency * (0.9 + 0.1 * np.cos(2 * np.pi * (f_norm - 0.55)))
            else:
                eff = efficiency * (1.1 - 0.6 * (f_norm - 0.8))
            efficiency_curve.append(max(min(eff, 100), 0))
    
        # 功率曲线（随流量增加）
        power_curve = []
        for i, f_norm in enumerate(flow_normalized):
            # 功率与流量和扬程相关
            flow_bbl_d = flow_points[i]
            head_ft = head_curve[i] 
            eff_percent = efficiency_curve[i]
        
            # 水力功率计算：P = ρ * g * Q * H / η
            flow_m3_s = flow_bbl_d * 0.158987 / 86400  # bbl/d to m³/s
            head_m = head_ft * 0.3048  # ft to m
            eff_decimal = eff_percent / 100
        
            if eff_decimal > 0.1:
                hydraulic_power = (1000 * 9.81 * flow_m3_s * head_m) / 1000  # kW
                shaft_power = hydraulic_power / eff_decimal
                power_hp = shaft_power * 1.341  # kW to HP
            else:
                power_hp = single_stage_power * f_norm
            
            power_curve.append(power_hp)
    
        # 关键工作点
        operating_points = [
            {
                'flow': displacement_max * 0.7,
                'head': single_stage_head * 0.85,
                'efficiency': efficiency,
                'power': single_stage_power * 0.9,
                'label': 'BEP'  # Best Efficiency Point
            }
        ]
    
        # 性能区域
        performance_zones = {
            'optimal': {
                'minFlow': displacement_max * 0.6,
                'maxFlow': displacement_max * 0.8,
                'label': '最佳效率区'
            },
            'acceptable': {
                'minFlow': displacement_max * 0.4,
                'maxFlow': displacement_max * 0.9,
                'label': '可接受区域'
            }
        }
    
        return {
            'baseCurves': {
                'flow': flow_points.tolist(),
                'head': head_curve,
                'efficiency': efficiency_curve,
                'power': power_curve
            },
            'operatingPoints': operating_points,
            'performanceZones': performance_zones
        }

    @Slot(str, result=str)
    def getPumpCurvesDataString(self, pump_model):
        """根据泵型号获取性能曲线数据（返回JSON字符串）"""
        try:
            import json
        
            # 根据型号查找泵
            if pump_model:
                pumps = self._db.search_devices(keyword=pump_model, device_type='pump')
                if pumps:
                    pump = pumps[0]
                    pump_details = pump.get('pump_details', {})
                
                    # 生成性能曲线数据
                    curves_data = self._generatePumpCurves(pump_details)
                
                    result = {
                        'has_data': True,
                        'pump_info': {
                            'manufacturer': pump.get('manufacturer', ''),
                            'model': pump.get('modelDevice', ''),
                            'impeller_model': pump_details.get('impeller_model', ''),
                            'stages': pump_details.get('max_stages', 87),
                            'outside_diameter': pump_details.get('outside_diameter', 5.62)
                        },
                        'baseCurves': curves_data['baseCurves'],
                        'operatingPoints': curves_data['operatingPoints'],
                        'performanceZones': curves_data['performanceZones']
                    }
                
                    return json.dumps(result, ensure_ascii=False)
        
            # 没有找到泵或型号为空，返回空数据
            return json.dumps({'has_data': False, 'error': 'pump_not_found'})
        
        except Exception as e:
            print(f"获取泵性能曲线失败: {str(e)}")
            return json.dumps({'has_data': False, 'error': str(e)})

    @Slot('QVariant', result=str) 
    def getPumpCurvesFromStepData(self, step_data):
        """从stepData中获取泵信息并返回性能曲线数据"""
        try:
            import json
            from PySide6.QtQml import QJSValue
        
            # 🔥 修复：处理QJSValue对象
            if isinstance(step_data, QJSValue):
                # 将QJSValue转换为Python对象
                step_data_dict = step_data.toVariant()
            else:
                step_data_dict = step_data
            
            print(f"转换后的stepData类型: {type(step_data_dict)}")
        
            # 从stepData中提取泵信息
            if not step_data_dict:
                return json.dumps({'has_data': False, 'error': 'no_step_data'})
            
            pump_info = step_data_dict.get('pump', {}) if hasattr(step_data_dict, 'get') else {}
        
            # 🔥 处理pump_info也可能是QJSValue的情况
            if isinstance(pump_info, QJSValue):
                pump_info = pump_info.toVariant()
        
            pump_model = pump_info.get('model', '') if pump_info else ''
            pump_id = pump_info.get('id', 0) if pump_info else 0
        
            print(f"从stepData获取泵信息: 型号={pump_model}, ID={pump_id}")
            print(f"泵信息详情: {pump_info}")
        
            # 如果有具体的泵参数，直接使用
            if pump_info and (pump_info.get('singleStageHead') or pump_info.get('stages')):
                curves_data = self._generatePumpCurvesFromParams(pump_info)
            
                result = {
                    'has_data': True,
                    'pump_info': {
                        'manufacturer': pump_info.get('manufacturer', 'Centrilift'),
                        'model': pump_model,
                        'stages': pump_info.get('stages', 87),
                        'outside_diameter': pump_info.get('outsideDiameter', 5.62)
                    },
                    'baseCurves': curves_data['baseCurves'],
                    'operatingPoints': curves_data['operatingPoints'],
                    'performanceZones': curves_data['performanceZones']
                }
            
                return json.dumps(result, ensure_ascii=False)
        
            # 否则尝试从数据库查找
            elif pump_model:
                return self.getPumpCurvesDataString(pump_model)
        
            # 都没有，返回默认数据
            else:
                curves_data = self._generateDefaultPumpCurves()
                result = {
                    'has_data': True,
                    'pump_info': {
                        'manufacturer': 'Centrilift',
                        'model': 'GN4000',
                        'stages': 87,
                        'outside_diameter': 5.62
                    },
                    'baseCurves': curves_data['baseCurves'],
                    'operatingPoints': curves_data['operatingPoints'],
                    'performanceZones': curves_data['performanceZones']
                }
            
                return json.dumps(result, ensure_ascii=False)
        
        except Exception as e:
            import traceback
            print(f"从stepData获取泵性能曲线失败: {str(e)}")
            print(f"错误堆栈: {traceback.format_exc()}")
            return json.dumps({'has_data': False, 'error': str(e)})

    @Slot(str, result=str)
    def getPumpCurvesFromStepDataString(self, step_data_json):
        """从stepData JSON字符串中获取泵信息并返回性能曲线数据"""
        try:
            import json
        
            # 解析JSON字符串
            step_data_dict = json.loads(step_data_json)
            print(f"解析stepData成功，keys: {list(step_data_dict.keys()) if step_data_dict else 'None'}")
        
            # 从stepData中提取泵信息
            if not step_data_dict:
                return json.dumps({'has_data': False, 'error': 'no_step_data'})
            
            pump_info = step_data_dict.get('pump', {})
            pump_model = pump_info.get('model', '')
            pump_id = pump_info.get('id', 0)
        
            print(f"从stepData获取泵信息: 型号={pump_model}, ID={pump_id}")
            print(f"泵信息详情: {pump_info}")
        
            # 如果有具体的泵参数，直接使用
            if pump_info and (pump_info.get('singleStageHead') or pump_info.get('stages')):
                curves_data = self._generatePumpCurvesFromParams(pump_info)
            
                result = {
                    'has_data': True,
                    'pump_info': {
                        'manufacturer': pump_info.get('manufacturer', 'Centrilift'),
                        'model': pump_model,
                        'stages': pump_info.get('stages', 87),
                        'outside_diameter': pump_info.get('outsideDiameter', 5.62)
                    },
                    'baseCurves': curves_data['baseCurves'],
                    'operatingPoints': curves_data['operatingPoints'],
                    'performanceZones': curves_data['performanceZones']
                }
            
                return json.dumps(result, ensure_ascii=False)
        
            # 否则尝试从数据库查找
            elif pump_model:
                return self.getPumpCurvesDataString(pump_model)
        
            # 都没有，返回默认数据
            else:
                print("使用默认泵参数生成性能曲线")
                curves_data = self._generateDefaultPumpCurves()
                result = {
                    'has_data': True,
                    'pump_info': {
                        'manufacturer': 'Centrilift',
                        'model': 'GN4000',
                        'stages': 87,
                        'outside_diameter': 5.62
                    },
                    'baseCurves': curves_data['baseCurves'],
                    'operatingPoints': curves_data['operatingPoints'],
                    'performanceZones': curves_data['performanceZones']
                }
            
                return json.dumps(result, ensure_ascii=False)
        
        except Exception as e:
            import traceback
            print(f"从stepData JSON获取泵性能曲线失败: {str(e)}")
            print(f"错误堆栈: {traceback.format_exc()}")
            return json.dumps({'has_data': False, 'error': str(e)})

    def _generatePumpCurvesFromParams(self, pump_info):
        """从泵参数生成性能曲线"""
        import numpy as np
    
        # 获取泵参数
        single_stage_head = pump_info.get('singleStageHead', 12.0)
        single_stage_power = pump_info.get('singleStagePower', 2.5)
        efficiency = pump_info.get('efficiency', 75.0)
        min_flow = pump_info.get('minFlow', 100)
        max_flow = pump_info.get('maxFlow', 2000)
        stages = pump_info.get('stages', 87)
    
        # 生成流量点
        flow_points = np.linspace(min_flow, max_flow, 25)
    
        # 计算多级泵的性能
        flow_normalized = flow_points / max_flow
    
        head_curve = []
        efficiency_curve = []
        power_curve = []
    
        for f_norm in flow_normalized:
            # 扬程曲线（多级）
            head_coeff = 1.0 - 0.25 * (f_norm ** 2)
            single_head = single_stage_head * head_coeff
            total_head = single_head * stages
            head_curve.append(max(total_head, 0))
        
            # 效率曲线
            if f_norm < 0.2:
                eff = efficiency * (0.4 + 3 * f_norm)
            elif f_norm <= 0.8:
                eff = efficiency * (0.85 + 0.15 * np.cos(np.pi * (f_norm - 0.5)))
            else:
                eff = efficiency * (1.0 - 0.4 * (f_norm - 0.8))
            efficiency_curve.append(max(min(eff, 95), 10))
        
            # 功率曲线（多级）
            power_factor = 0.3 + 0.7 * f_norm + 0.2 * (f_norm ** 2)
            total_power = single_stage_power * stages * power_factor
            power_curve.append(total_power)
    
        return {
            'baseCurves': {
                'flow': flow_points.tolist(),
                'head': head_curve,
                'efficiency': efficiency_curve,
                'power': power_curve
            },
            'operatingPoints': [
                {
                    'flow': max_flow * 0.7,
                    'head': single_stage_head * stages * 0.85,
                    'efficiency': efficiency,
                    'power': single_stage_power * stages * 0.8,
                    'label': 'BEP'
                }
            ],
            'performanceZones': {
                'optimal': {
                    'minFlow': max_flow * 0.6,
                    'maxFlow': max_flow * 0.8
                },
                'acceptable': {
                    'minFlow': max_flow * 0.4,
                    'maxFlow': max_flow * 0.9
                }
            }
        }


    def _generateDefaultPumpCurves(self):
        """生成默认泵性能曲线"""
        default_params = {
            'singleStageHead': 12.0,
            'singleStagePower': 2.5,
            'efficiency': 75.0,
            'minFlow': 100,
            'maxFlow': 2000,
            'stages': 87
        }
        return self._generatePumpCurvesFromParams(default_params)   

    @Slot(str, str)
    def exportDevices(self, file_url: str, device_type: str):
        """
        导出设备数据到Excel文件
        
        Args:
            file_url: 文件保存路径
            device_type: 设备类型 (all, pump, motor, protector, separator)
        """
        try:
            logger.info(f"开始导出设备数据: 类型={device_type}, 路径={file_url}")
            
            # 处理文件路径
            if file_url.startswith('file:///'):
                file_path = file_url[8:]  # Windows
            elif file_url.startswith('file://'):
                file_path = file_url[7:]  # Unix/Mac
            else:
                file_path = file_url
            
            file_path = os.path.normpath(file_path)
            
            # 确保目录存在
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            
            # 创建Excel工作簿
            workbook = openpyxl.Workbook()
            
            # 根据设备类型导出数据
            if device_type == "all":
                self._export_all_devices(workbook)
            else:
                self._export_single_device_type(workbook, device_type)
            
            # 保存文件
            workbook.save(file_path)
            
            # 获取导出的设备数量
            total_exported = self._count_exported_devices(device_type)
            
            logger.info(f"设备导出完成: {total_exported}个设备已导出到 {file_path}")
            self.exportCompleted.emit(file_path, total_exported)
            
        except Exception as e:
            error_msg = f"导出设备数据失败: {str(e)}"
            logger.error(error_msg)
            self.exportFailed.emit(error_msg)

    def _export_all_devices(self, workbook):
        """导出所有类型的设备"""
        device_types = ['pump', 'motor', 'protector', 'separator']
        
        # 移除默认工作表
        if 'Sheet' in workbook.sheetnames:
            workbook.remove(workbook['Sheet'])
        
        # 为每种设备类型创建工作表
        for device_type in device_types:
            self._export_single_device_type(workbook, device_type, create_new_sheet=True)

    def _export_single_device_type(self, workbook, device_type: str, create_new_sheet: bool = False):
        """导出单一类型的设备"""
        try:
            # 获取设备数据
            devices_data = self._db.get_devices(
                device_type=device_type.upper(),
                status='active'
            )
            
            devices = devices_data.get('devices', [])
            
            if not devices:
                logger.warning(f"没有找到{device_type}类型的设备数据")
                return
            
            # 创建或获取工作表
            if create_new_sheet:
                sheet_name = self._get_sheet_name(device_type)
                worksheet = workbook.create_sheet(sheet_name)
            else:
                worksheet = workbook.active
                worksheet.title = self._get_sheet_name(device_type)
            
            # 根据设备类型设置不同的列结构
            if device_type == 'pump':
                self._setup_pump_export_sheet(worksheet, devices)
            elif device_type == 'motor':
                self._setup_motor_export_sheet(worksheet, devices)
            elif device_type == 'protector':
                self._setup_protector_export_sheet(worksheet, devices)
            elif device_type == 'separator':
                self._setup_separator_export_sheet(worksheet, devices)
            
            logger.info(f"已导出{device_type}设备: {len(devices)}个")
            
        except Exception as e:
            logger.error(f"导出{device_type}设备失败: {e}")

    def _setup_pump_export_sheet(self, worksheet, devices):
        """设置泵设备导出表格"""
        # 设置样式
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center")
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
        
        # 设置表头
        headers = [
            "设备ID", "制造商", "型号", "系列", "单级扬程(ft)", "单级功率(HP)",
            "最大级数", "最小流量(bbl/d)", "最大流量(bbl/d)", "效率(%)",
            "外径(in)", "轴径(in)", "重量(lbs)", "长度(in)", "状态", "创建时间", "备注"
        ]
        
        # 设置表头
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
        
        # 设置列宽
        column_widths = [10, 15, 15, 10, 12, 12, 10, 12, 12, 8, 10, 10, 10, 10, 8, 15, 20]
        for col, width in enumerate(column_widths, 1):
            worksheet.column_dimensions[openpyxl.utils.get_column_letter(col)].width = width
        
        # 填充数据
        for row, device in enumerate(devices, 2):
            pump_details = device.get('pump_details', {})
            
            data = [
                device.get('id', ''),
                device.get('manufacturer', ''),
                device.get('model', ''),
                device.get('series', ''),
                pump_details.get('single_stage_head', ''),
                pump_details.get('single_stage_power', ''),
                pump_details.get('max_stages', ''),
                pump_details.get('displacement_min', ''),
                pump_details.get('displacement_max', ''),
                pump_details.get('efficiency', ''),
                pump_details.get('outside_diameter', ''),
                pump_details.get('shaft_diameter', ''),
                pump_details.get('weight', ''),
                pump_details.get('length', ''),
                device.get('status', ''),
                device.get('created_at', ''),
                device.get('description', '')
            ]
            
            for col, value in enumerate(data, 1):
                cell = worksheet.cell(row=row, column=col, value=value)
                cell.border = border
                cell.alignment = Alignment(horizontal="left", vertical="center")

    def _setup_motor_export_sheet(self, worksheet, devices):
        """设置电机导出表格"""
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="2E7D32", end_color="2E7D32", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center")
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
        
        headers = [
            "设备ID", "制造商", "型号", "系列", "功率(HP)", "效率(%)",
            "绝缘等级", "防护等级", "外径(in)", "长度(in)", "重量(lbs)",
            "状态", "创建时间", "备注"
        ]
        
        # 设置表头
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
        
        # 设置列宽
        for col in range(1, len(headers) + 1):
            worksheet.column_dimensions[openpyxl.utils.get_column_letter(col)].width = 12
        
        # 填充数据
        for row, device in enumerate(devices, 2):
            motor_details = device.get('motor_details', {})
            
            # 获取主要参数（60Hz）
            freq_params = motor_details.get('frequency_params', [])
            main_params = next((p for p in freq_params if p.get('frequency') == 60), 
                             freq_params[0] if freq_params else {})
            
            data = [
                device.get('id', ''),
                device.get('manufacturer', ''),
                device.get('model', ''),
                device.get('series', ''),
                main_params.get('power', ''),
                main_params.get('efficiency', ''),
                motor_details.get('insulation_class', ''),
                motor_details.get('protection_class', ''),
                motor_details.get('outside_diameter', ''),
                motor_details.get('length', ''),
                motor_details.get('weight', ''),
                device.get('status', ''),
                device.get('created_at', ''),
                device.get('description', '')
            ]
            
            for col, value in enumerate(data, 1):
                cell = worksheet.cell(row=row, column=col, value=value)
                cell.border = border

    def _setup_protector_export_sheet(self, worksheet, devices):
        """设置保护器导出表格"""
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="FF6F00", end_color="FF6F00", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center")
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
        
        headers = [
            "设备ID", "制造商", "型号", "系列", "额定推力(lbs)", "最大推力(lbs)",
            "外径(in)", "长度(in)", "重量(lbs)", "状态", "创建时间", "备注"
        ]
        
        # 设置表头和数据（类似泵的实现）
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
        
        # 填充数据...（实现细节）

    def _setup_separator_export_sheet(self, worksheet, devices):
        """设置分离器导出表格"""
        # 实现分离器导出逻辑...

    def _get_sheet_name(self, device_type: str) -> str:
        """获取工作表名称"""
        names = {
            'pump': '潜油离心泵',
            'motor': '电机',
            'protector': '保护器',
            'separator': '分离器'
        }
        return names.get(device_type, device_type)

    def _count_exported_devices(self, device_type: str) -> int:
        """统计导出的设备数量"""
        try:
            if device_type == "all":
                total = 0
                for dtype in ['pump', 'motor', 'protector', 'separator']:
                    devices_data = self._db.get_devices(
                        device_type=dtype.upper(),
                        status='active'
                    )
                    total += len(devices_data.get('devices', []))
                return total
            else:
                devices_data = self._db.get_devices(
                    device_type=device_type.upper(),
                    status='active'
                )
                return len(devices_data.get('devices', []))
        except:
            return 0

    @Slot(str, str, bool)
    def generateTemplate(self, device_type: str, save_path: str, is_metric: bool):
        """
        生成设备导入模板
    
        Args:
            device_type: 设备类型 (pump, motor, protector, separator)
            save_path: 保存路径
            is_metric: 是否使用公制单位
        """
        try:
            logger.info(f"生成{device_type}模板: 单位制={is_metric}, 保存到={save_path}")
        
            # 处理文件路径
            if save_path.startswith('file:///'):
                file_path = save_path[8:]  # Windows
            elif save_path.startswith('file://'):
                file_path = save_path[7:]  # Unix/Mac
            else:
                file_path = save_path
        
            file_path = os.path.normpath(file_path)
        
            # 确保目录存在
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
            # 创建Excel工作簿
            workbook = openpyxl.Workbook()
        
            # 根据设备类型生成不同模板
            if device_type == 'pump':
                self._generate_pump_template(workbook, is_metric)
            elif device_type == 'motor':
                self._generate_motor_template(workbook, is_metric)
            elif device_type == 'protector':
                self._generate_protector_template(workbook, is_metric)
            elif device_type == 'separator':
                self._generate_separator_template(workbook, is_metric)
            else:
                raise ValueError(f"不支持的设备类型: {device_type}")
        
            # 保存文件
            workbook.save(file_path)
        
            logger.info(f"模板生成成功: {file_path}")
            self.templateGenerated.emit(file_path)
        
        except Exception as e:
            error_msg = f"生成模板失败: {str(e)}"
            logger.error(error_msg)
            self.templateGenerationFailed.emit(error_msg)

    def _generate_pump_template(self, workbook, is_metric: bool):
        """生成泵设备导入模板"""
        # 设置工作表
        if 'Sheet' in workbook.sheetnames:
            worksheet = workbook['Sheet']
        else:
            worksheet = workbook.create_sheet()
    
        worksheet.title = "泵设备导入模板"
    
        # 设置样式
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="4472C4", end_color="4472C4", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
    
        # 🔥 根据单位制设置不同的表头
        if is_metric:
            headers = [
                "制造商", "型号", "系列", "举升方式", "序列号", "状态", "描述",
                # 基本参数（公制）
                "叶轮型号", "最小流量(m³/d)", "最大流量(m³/d)", 
                "单级扬程(m)", "单级功率(kW)", "最大级数", "效率(%)",
                "外径(mm)", "轴径(mm)", "重量(kg)", "长度(mm)",
                # 🔥 性能曲线数据点（公制）
                "流量点1(m³/d)", "扬程点1(m)", "效率点1(%)", "功率点1(kW)",
                "流量点2(m³/d)", "扬程点2(m)", "效率点2(%)", "功率点2(kW)",
                "流量点3(m³/d)", "扬程点3(m)", "效率点3(%)", "功率点3(kW)",
                "流量点4(m³/d)", "扬程点4(m)", "效率点4(%)", "功率点4(kW)",
                "流量点5(m³/d)", "扬程点5(m)", "效率点5(%)", "功率点5(kW)",
                # 最优工况点
                "最优流量(m³/d)", "最优扬程(m)", "最优效率(%)", "最优功率(kW)",
                # 应用范围
                "最低温度(°C)", "最高温度(°C)", "最低压力(MPa)", "最高压力(MPa)", 
                "最低粘度(mPa·s)", "最高粘度(mPa·s)"
            ]
        else:
            headers = [
                "制造商", "型号", "系列", "举升方式", "序列号", "状态", "描述",
                # 基本参数（英制）
                "叶轮型号", "最小流量(bbl/d)", "最大流量(bbl/d)",
                "单级扬程(ft)", "单级功率(HP)", "最大级数", "效率(%)",
                "外径(in)", "轴径(in)", "重量(lbs)", "长度(in)",
                # 🔥 性能曲线数据点（英制）
                "流量点1(bbl/d)", "扬程点1(ft)", "效率点1(%)", "功率点1(HP)",
                "流量点2(bbl/d)", "扬程点2(ft)", "效率点2(%)", "功率点2(HP)",
                "流量点3(bbl/d)", "扬程点3(ft)", "效率点3(%)", "功率点3(HP)",
                "流量点4(bbl/d)", "扬程点4(ft)", "效率点4(%)", "功率点4(HP)",
                "流量点5(bbl/d)", "扬程点5(ft)", "效率点5(%)", "功率点5(HP)",
                # 最优工况点
                "最优流量(bbl/d)", "最优扬程(ft)", "最优效率(%)", "最优功率(HP)",
                # 应用范围
                "最低温度(°F)", "最高温度(°F)", "最低压力(psi)", "最高压力(psi)", 
                "最低粘度(cp)", "最高粘度(cp)"
            ]
    
        # 设置表头
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
    
        # 设置列宽
        for col in range(1, len(headers) + 1):
            worksheet.column_dimensions[openpyxl.utils.get_column_letter(col)].width = 12
    
        # 🔥 添加示例数据行
        if is_metric:
            example_data = [
                "Baker Hughes", "FLEXPump™ 400", "400", "esp", "BH-ESP-400-001", "active", "高效ESP泵",
                "D400", "50", "1500", "7.6", "1.9", "400", "68",
                "101.6", "19.05", "45.4", "1219",
                # 性能曲线点（5个点）
                "200", "25", "45", "3.2",
                "400", "23", "58", "5.8",
                "600", "21", "68", "8.1",
                "800", "18", "65", "10.2",
                "1000", "15", "58", "12.1",
                # 最优工况点
                "600", "21", "68", "8.1",
                # 应用范围
                "4", "121", "0.1", "13.8", "0.5", "1000"
            ]
        else:
            example_data = [
                "Baker Hughes", "FLEXPump™ 400", "400", "esp", "BH-ESP-400-001", "active", "高效ESP泵",
                "D400", "315", "9450", "25", "2.5", "400", "68",
                "4.0", "0.75", "100", "48",
                # 性能曲线点（5个点）
                "1260", "82", "45", "4.3",
                "2520", "75", "58", "7.8",
                "3780", "69", "68", "10.9",
                "5040", "59", "65", "13.7",
                "6300", "49", "58", "16.2",
                # 最优工况点
                "3780", "69", "68", "10.9",
                # 应用范围
                "40", "250", "15", "2000", "0.5", "1000"
            ]
    
        # 填充示例数据
        for col, value in enumerate(example_data, 1):
            cell = worksheet.cell(row=2, column=col, value=value)
            cell.border = border
            cell.alignment = Alignment(horizontal="left", vertical="center")
    
        # 🔥 添加数据验证和说明
        self._add_pump_template_notes(worksheet, is_metric, len(headers))

    def _generate_motor_template(self, workbook, is_metric: bool):
        """生成电机导入模板"""
        # 设置工作表
        if 'Sheet' in workbook.sheetnames:
            worksheet = workbook['Sheet']
        else:
            worksheet = workbook.create_sheet()
    
        worksheet.title = "电机导入模板"
    
        # 设置样式
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="2E7D32", end_color="2E7D32", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
    
        # 根据单位制设置表头
        if is_metric:
            headers = [
                "制造商", "型号", "系列", "序列号", "状态", "描述",
                # 基本参数（公制）
                "电机类型", "外径(mm)", "长度(mm)", "重量(kg)",
                "绝缘等级", "防护等级", "额定转速(rpm)",
                # 50Hz参数（公制）
                "50Hz功率(kW)", "50Hz电压(V)", "50Hz电流(A)", "50Hz转速(rpm)", "50Hz效率(%)",
                # 60Hz参数（公制）
                "60Hz功率(kW)", "60Hz电压(V)", "60Hz电流(A)", "60Hz转速(rpm)", "60Hz效率(%)",
                # 性能参数
                "启动转矩(%)", "最大转矩(%)", "堵转转矩(%)", "功率因数",
                "温升限值(°C)", "噪音等级(dB)", "振动等级(mm/s)",
                # 环境条件
                "最低工作温度(°C)", "最高工作温度(°C)", "最大湿度(%)", "海拔限制(m)"
            ]
        else:
            headers = [
                "制造商", "型号", "系列", "序列号", "状态", "描述",
                # 基本参数（英制）
                "电机类型", "外径(in)", "长度(in)", "重量(lbs)",
                "绝缘等级", "防护等级", "额定转速(rpm)",
                # 50Hz参数（英制）
                "50Hz功率(HP)", "50Hz电压(V)", "50Hz电流(A)", "50Hz转速(rpm)", "50Hz效率(%)",
                # 60Hz参数（英制）
                "60Hz功率(HP)", "60Hz电压(V)", "60Hz电流(A)", "60Hz转速(rpm)", "60Hz效率(%)",
                # 性能参数
                "启动转矩(%)", "最大转矩(%)", "堵转转矩(%)", "功率因数",
                "温升限值(°F)", "噪音等级(dB)", "振动等级(in/s)",
                # 环境条件
                "最低工作温度(°F)", "最高工作温度(°F)", "最大湿度(%)", "海拔限制(ft)"
            ]
    
        # 设置表头
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
    
        # 设置列宽
        for col in range(1, len(headers) + 1):
            worksheet.column_dimensions[openpyxl.utils.get_column_letter(col)].width = 12
    
        # 添加示例数据
        if is_metric:
            example_data = [
                "Baker Hughes", "Electrospeed 3", "ES3", "BH-ES3-001", "active", "高效潜油电机",
                "三相感应电机", "114", "3048", "136",
                "F", "IP68", "3500",
                # 50Hz参数
                "75", "1000", "75", "2900", "92",
                # 60Hz参数
                "75", "1200", "62", "3500", "93",
                # 性能参数
                "150", "200", "300", "0.85",
                "80", "75", "2.8",
                # 环境条件
                "4", "149", "95", "3000"
            ]
        else:
            example_data = [
                "Baker Hughes", "Electrospeed 3", "ES3", "BH-ES3-001", "active", "高效潜油电机",
                "三相感应电机", "4.5", "120", "300",
                "F", "IP68", "3500",
                # 50Hz参数
                "100", "1000", "75", "2900", "92",
                # 60Hz参数
                "100", "1200", "62", "3500", "93",
                # 性能参数
                "150", "200", "300", "0.85",
                "176", "75", "0.11",
                # 环境条件
                "40", "300", "95", "10000"
            ]
    
        # 填充示例数据
        for col, value in enumerate(example_data, 1):
            cell = worksheet.cell(row=2, column=col, value=value)
            cell.border = border
            cell.alignment = Alignment(horizontal="left", vertical="center")
    
        # 添加说明
        self._add_motor_template_notes(worksheet, is_metric, len(headers))

    def _generate_protector_template(self, workbook, is_metric: bool):
        """生成保护器导入模板"""
        # 设置工作表
        if 'Sheet' in workbook.sheetnames:
            worksheet = workbook['Sheet']
        else:
            worksheet = workbook.create_sheet()
    
        worksheet.title = "保护器导入模板"
    
        # 设置样式
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="FF6F00", end_color="FF6F00", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
    
        # 根据单位制设置表头
        if is_metric:
            headers = [
                "制造商", "型号", "系列", "序列号", "状态", "描述",
                # 基本参数（公制）
                "外径(mm)", "长度(mm)", "重量(kg)",
                "推力承载能力(kN)", "径向载荷(kN)", "轴向载荷(kN)",
                "密封类型", "密封等级", "材料等级",
                # 工作条件
                "最高工作温度(°C)", "最高工作压力(MPa)", "最大转速(rpm)",
                "轴径适配(mm)", "连接螺纹", "安装长度(mm)",
                # 密封性能
                "静密封压力(MPa)", "动密封压力(MPa)", "泄漏率(ml/h)",
                "磨损寿命(h)", "维护周期(h)", "更换周期(h)",
                # 流体兼容性
                "原油兼容性", "天然气兼容性", "水相兼容性", "化学兼容性",
                # 认证标准
                "API标准", "ISO认证", "制造标准"
            ]
        else:
            headers = [
                "制造商", "型号", "系列", "序列号", "状态", "描述",
                # 基本参数（英制）
                "外径(in)", "长度(in)", "重量(lbs)",
                "推力承载能力(lbs)", "径向载荷(lbs)", "轴向载荷(lbs)",
                "密封类型", "密封等级", "材料等级",
                # 工作条件
                "最高工作温度(°F)", "最高工作压力(psi)", "最大转速(rpm)",
                "轴径适配(in)", "连接螺纹", "安装长度(in)",
                # 密封性能
                "静密封压力(psi)", "动密封压力(psi)", "泄漏率(oz/h)",
                "磨损寿命(h)", "维护周期(h)", "更换周期(h)",
                # 流体兼容性
                "原油兼容性", "天然气兼容性", "水相兼容性", "化学兼容性",
                # 认证标准
                "API标准", "ISO认证", "制造标准"
            ]
    
        # 设置表头
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
    
        # 设置列宽
        for col in range(1, len(headers) + 1):
            worksheet.column_dimensions[openpyxl.utils.get_column_letter(col)].width = 12
    
        # 添加示例数据
        if is_metric:
            example_data = [
                "Baker Hughes", "TandemSeal", "TS400", "BH-TS400-001", "active", "高性能保护器",
                "114", "1524", "68",
                "890", "445", "667", 
                "机械密封", "API 682", "316SS",
                "149", "34.5", "3600",
                "25.4", "API螺纹", "1524",
                "69", "34.5", "5",
                "8760", "4380", "17520",
                "优秀", "良好", "优秀", "良好",
                "API 11AX", "ISO 9001", "API标准"
            ]
        else:
            example_data = [
                "Baker Hughes", "TandemSeal", "TS400", "BH-TS400-001", "active", "高性能保护器",
                "4.5", "60", "150",
                "200000", "100000", "150000",
                "机械密封", "API 682", "316SS",
                "300", "5000", "3600",
                "1.0", "API螺纹", "60",
                "10000", "5000", "0.17",
                "8760", "4380", "17520",
                "优秀", "良好", "优秀", "良好",
                "API 11AX", "ISO 9001", "API标准"
            ]
    
        # 填充示例数据
        for col, value in enumerate(example_data, 1):
            cell = worksheet.cell(row=2, column=col, value=value)
            cell.border = border
            cell.alignment = Alignment(horizontal="left", vertical="center")
    
        # 添加说明
        self._add_protector_template_notes(worksheet, is_metric, len(headers))

    def _generate_separator_template(self, workbook, is_metric: bool):
        """生成分离器导入模板"""
        # 设置工作表
        if 'Sheet' in workbook.sheetnames:
            worksheet = workbook['Sheet']
        else:
            worksheet = workbook.create_sheet()
    
        worksheet.title = "分离器导入模板"
    
        # 设置样式
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="9C27B0", end_color="9C27B0", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        border = Border(
            left=Side(style='thin'), right=Side(style='thin'),
            top=Side(style='thin'), bottom=Side(style='thin')
        )
    
        # 根据单位制设置表头
        if is_metric:
            headers = [
                "制造商", "型号", "系列", "序列号", "状态", "描述",
                # 基本参数（公制）
                "外径(mm)", "长度(mm)", "重量(kg)",
                "分离器类型", "分离原理", "级数",
                # 性能参数
                "气体处理量(m³/d)", "液体处理量(m³/d)", "分离效率(%)",
                "最小分离粒径(μm)", "压力损失(kPa)", "操作压力(MPa)",
                # 工作条件
                "最低温度(°C)", "最高温度(°C)", "最低压力(MPa)", "最高压力(MPa)",
                "入口速度(m/s)", "出口速度(m/s)", "停留时间(s)",
                # 材料信息
                "主体材料", "内衬材料", "密封材料", "防腐等级",
                # 连接信息
                "入口尺寸(mm)", "出口尺寸(mm)", "排污口(mm)", "安装方式",
                # 性能特征
                "旋流强度", "Re数范围", "Cut粒径(μm)", "分离因子"
            ]
        else:
            headers = [
                "制造商", "型号", "系列", "序列号", "状态", "描述",
                # 基本参数（英制）
                "外径(in)", "长度(in)", "重量(lbs)",
                "分离器类型", "分离原理", "级数",
                # 性能参数
                "气体处理量(scf/d)", "液体处理量(bbl/d)", "分离效率(%)",
                "最小分离粒径(μm)", "压力损失(psi)", "操作压力(psi)",
                # 工作条件
                "最低温度(°F)", "最高温度(°F)", "最低压力(psi)", "最高压力(psi)",
                "入口速度(ft/s)", "出口速度(ft/s)", "停留时间(s)",
                # 材料信息
                "主体材料", "内衬材料", "密封材料", "防腐等级",
                # 连接信息
                "入口尺寸(in)", "出口尺寸(in)", "排污口(in)", "安装方式",
                # 性能特征
                "旋流强度", "Re数范围", "Cut粒径(μm)", "分离因子"
            ]
    
        # 设置表头
        for col, header in enumerate(headers, 1):
            cell = worksheet.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
            cell.border = border
    
        # 设置列宽
        for col in range(1, len(headers) + 1):
            worksheet.column_dimensions[openpyxl.utils.get_column_letter(col)].width = 12
    
        # 添加示例数据
        if is_metric:
            example_data = [
                "Halliburton", "VORTEX-S500", "VORTEX", "HAL-VS500-001", "active", "高效旋流分离器",
                "152", "2438", "227",
                "旋流分离器", "离心分离", "单级",
                "50000", "2000", "95",
                "10", "69", "6.9",
                "4", "149", "0.7", "34.5",
                "15", "8", "3",
                "316L不锈钢", "陶瓷", "聚四氟乙烯", "NACE MR0175",
                "100", "75", "50", "立式安装",
                "高", "1000-10000", "15", "500"
            ]
        else:
            example_data = [
                "Halliburton", "VORTEX-S500", "VORTEX", "HAL-VS500-001", "active", "高效旋流分离器",
                "6", "96", "500",
                "旋流分离器", "离心分离", "单级",
                "1.8M", "12600", "95",
                "10", "10", "1000",
                "40", "300", "100", "5000",
                "49", "26", "3",
                "316L不锈钢", "陶瓷", "聚四氟乙烯", "NACE MR0175",
                "4", "3", "2", "立式安装",
                "高", "1000-10000", "15", "500"
            ]
    
        # 填充示例数据
        for col, value in enumerate(example_data, 1):
            cell = worksheet.cell(row=2, column=col, value=value)
            cell.border = border
            cell.alignment = Alignment(horizontal="left", vertical="center")
    
        # 添加说明
        self._add_separator_template_notes(worksheet, is_metric, len(headers))

    def _add_pump_template_notes(self, worksheet, is_metric: bool, header_count: int):
        """添加泵模板说明"""
        notes_start_row = 4
    
        notes = [
            "📋 泵设备导入说明：",
            "",
            "1. 基本信息填写：",
            "   - 制造商：设备制造商名称",
            "   - 型号：完整的设备型号",
            "   - 系列：产品系列（如400、500、600等）",
            "   - 举升方式：esp/pcp/jet/espcp/hpp",
            "   - 状态：active/inactive/maintenance",
            "",
            "2. 性能参数：",
            f"   - 流量单位：{'m³/d' if is_metric else 'bbl/d'}",
            f"   - 扬程单位：{'m' if is_metric else 'ft'}",
            f"   - 功率单位：{'kW' if is_metric else 'HP'}",
            f"   - 直径单位：{'mm' if is_metric else 'in'}",
            f"   - 重量单位：{'kg' if is_metric else 'lbs'}",
            "",
            "3. 性能曲线数据：",
            "   - 提供5个关键流量点的性能数据",
            "   - 数据点应覆盖泵的工作范围",
            "   - 最优工况点为BEP点",
            "",
            "4. 举升方式说明：",
            "   - esp: 潜油离心泵",
            "   - pcp: 螺杆泵",
            "   - jet: 射流泵",
            "   - espcp: 柱塞泵",
            "   - hpp: 水力泵",
            "",
            "5. 注意事项：",
            "   - 确保数值单位正确",
            "   - 性能曲线数据用于生成完整特性曲线",
            "   - 留空的字段将使用默认值",
            "   - 序列号必须唯一"
        ]
    
        for i, note in enumerate(notes):
            cell = worksheet.cell(row=notes_start_row + i, column=1, value=note)
            if note.startswith("📋"):
                cell.font = Font(bold=True, size=14, color="4472C4")
            elif note.startswith(("1.", "2.", "3.", "4.", "5.")):
                cell.font = Font(bold=True)
        
            # 合并说明文本的单元格
            if note:
                worksheet.merge_cells(
                    start_row=notes_start_row + i, 
                    start_column=1,
                    end_row=notes_start_row + i,
                    end_column=min(8, header_count)
                )

    def _add_motor_template_notes(self, worksheet, is_metric: bool, header_count: int):
        """添加电机模板说明"""
        notes_start_row = 4
    
        notes = [
            "📋 电机导入说明：",
            "",
            "1. 基本信息：",
            "   - 电机类型：三相感应电机/永磁同步电机等",
            "   - 绝缘等级：B/F/H等",
            "   - 防护等级：IP54/IP55/IP68等",
            "",
            "2. 频率参数：",
            "   - 50Hz和60Hz参数可分别填写",
            "   - 功率、电压、电流、转速、效率",
            f"   - 功率单位：{'kW' if is_metric else 'HP'}",
            f"   - 尺寸单位：{'mm' if is_metric else 'in'}",
            "",
            "3. 性能指标：",
            "   - 启动转矩：额定转矩的百分比",
            "   - 最大转矩：额定转矩的百分比",
            "   - 堵转转矩：额定转矩的百分比",
            "   - 功率因数：0.8-0.95之间",
            "",
            "4. 环境条件：",
            f"   - 温度范围：{'-40°C到+150°C' if is_metric else '-40°F到+300°F'}",
            "   - 湿度：相对湿度百分比",
            f"   - 海拔限制：{'m' if is_metric else 'ft'}"
        ]
    
        for i, note in enumerate(notes):
            cell = worksheet.cell(row=notes_start_row + i, column=1, value=note)
            if note.startswith("📋"):
                cell.font = Font(bold=True, size=14, color="2E7D32")
            elif note.startswith(("1.", "2.", "3.", "4.")):
                cell.font = Font(bold=True)
        
            if note:
                worksheet.merge_cells(
                    start_row=notes_start_row + i, 
                    start_column=1,
                    end_row=notes_start_row + i,
                    end_column=min(8, header_count)
                )

    def _add_protector_template_notes(self, worksheet, is_metric: bool, header_count: int):
        """添加保护器模板说明"""
        notes_start_row = 4
    
        notes = [
            "📋 保护器导入说明：",
            "",
            "1. 密封性能：",
            "   - 密封类型：机械密封/唇形密封/组合密封",
            "   - 密封等级：API 682标准等级",
            "   - 泄漏率：允许的最大泄漏量",
            "",
            "2. 载荷能力：",
            f"   - 推力承载：{'kN' if is_metric else 'lbs'}",
            f"   - 径向载荷：{'kN' if is_metric else 'lbs'}",
            f"   - 轴向载荷：{'kN' if is_metric else 'lbs'}",
            "",
            "3. 工作条件：",
            f"   - 温度范围：{'-20°C到+200°C' if is_metric else '0°F到+400°F'}",
            f"   - 压力范围：{'MPa' if is_metric else 'psi'}",
            "   - 转速范围：rpm",
            "",
            "4. 材料兼容性：",
            "   - 原油兼容性：优秀/良好/一般",
            "   - 天然气兼容性：优秀/良好/一般",
            "   - 化学兼容性：根据介质确定"
        ]
    
        for i, note in enumerate(notes):
            cell = worksheet.cell(row=notes_start_row + i, column=1, value=note)
            if note.startswith("📋"):
                cell.font = Font(bold=True, size=14, color="FF6F00")
            elif note.startswith(("1.", "2.", "3.", "4.")):
                cell.font = Font(bold=True)
        
            if note:
                worksheet.merge_cells(
                    start_row=notes_start_row + i, 
                    start_column=1,
                    end_row=notes_start_row + i,
                    end_column=min(8, header_count)
                )

    def _add_separator_template_notes(self, worksheet, is_metric: bool, header_count: int):
        """添加分离器模板说明"""
        notes_start_row = 4
    
        notes = [
            "📋 分离器导入说明：",
            "",
            "1. 分离器类型：",
            "   - 旋流分离器：利用离心力分离",
            "   - 重力分离器：利用密度差分离",
            "   - 膜分离器：利用膜技术分离",
            "",
            "2. 性能参数：",
            f"   - 气体处理量：{'m³/d' if is_metric else 'scf/d'}",
            f"   - 液体处理量：{'m³/d' if is_metric else 'bbl/d'}",
            "   - 分离效率：百分比",
            "   - 最小分离粒径：微米",
            "",
            "3. 工作条件：",
            f"   - 温度范围：{'-20°C到+200°C' if is_metric else '0°F到+400°F'}",
            f"   - 压力范围：{'MPa' if is_metric else 'psi'}",
            f"   - 流速范围：{'m/s' if is_metric else 'ft/s'}",
            "",
            "4. 安装信息：",
            "   - 安装方式：立式/卧式/倾斜",
            "   - 连接方式：法兰/螺纹/焊接",
            f"   - 连接尺寸：{'mm' if is_metric else 'in'}"
        ]
    
        for i, note in enumerate(notes):
            cell = worksheet.cell(row=notes_start_row + i, column=1, value=note)
            if note.startswith("📋"):
                cell.font = Font(bold=True, size=14, color="9C27B0")
            elif note.startswith(("1.", "2.", "3.", "4.")):
                cell.font = Font(bold=True)
        
            if note:
                worksheet.merge_cells(
                    start_row=notes_start_row + i, 
                    start_column=1,
                    end_row=notes_start_row + i,
                    end_column=min(8, header_count)
                )
