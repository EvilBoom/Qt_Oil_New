# Controller/ExcelImportController.py

from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from typing import List, Dict, Optional, Any
import os
import json
import logging

from DataManage.services.excel_import_service import ExcelImportService
from DataManage.services.database_service import DatabaseService

logger = logging.getLogger(__name__)

class ExcelImportController(QObject):
    """Excel导入控制器 - 处理井轨迹数据的Excel导入"""

    # 信号定义
    fileLoaded = Signal(str)                    # 文件路径
    columnsIdentified = Signal(dict)            # 列映射
    previewDataReady = Signal(list)             # 预览数据
    importProgress = Signal(int, int)           # 当前行, 总行数
    importCompleted = Signal(int, int)          # 井ID, 导入行数
    importFailed = Signal(str)                  # 错误信息
    sheetsLoaded = Signal(list)                 # 工作表列表
    validationCompleted = Signal(dict)          # 验证结果

    def __init__(self):
        super().__init__()
        self._excel_service = ExcelImportService()
        self._db_service = DatabaseService()
        self._current_file_path = ""
        self._current_well_id = -1
        self._trajectory_data = []
        self._preview_data = []
        self._sheet_names = []
        self._import_summary = {}

    # ========== 属性定义 ==========
    @Property(str, notify=fileLoaded)
    def currentFilePath(self):
        """当前文件路径"""
        return self._current_file_path

    @Property(list, notify=previewDataReady)
    def previewData(self):
        """预览数据"""
        return self._preview_data

    @Property(list, notify=sheetsLoaded)
    def sheetNames(self):
        """工作表名称列表"""
        return self._sheet_names

    @Property(dict, notify=validationCompleted)
    def importSummary(self):
        """导入摘要"""
        return self._import_summary

    # ========== 文件操作 ==========

    @Slot(str)
    def loadExcelFile(self, file_url: str):
        """
        加载Excel文件

        Args:
            file_url: 文件URL（可能是file://开头）
        """
        try:
            # 处理文件URL
            if file_url.startswith('file:///'):
                file_path = file_url[8:]  # Windows
            elif file_url.startswith('file://'):
                file_path = file_url[7:]  # Unix/Mac
            else:
                file_path = file_url

            # 规范化路径
            file_path = os.path.normpath(file_path)

            if not os.path.exists(file_path):
                self.importFailed.emit(f"文件不存在: {file_path}")
                return

            # 检查文件扩展名
            if not file_path.lower().endswith(('.xls', '.xlsx')):
                self.importFailed.emit("请选择Excel文件(.xls或.xlsx)")
                return

            self._current_file_path = file_path

            # 获取工作表名称
            self._sheet_names = self._excel_service.get_sheet_names(file_path)
            self.sheetsLoaded.emit(self._sheet_names)

            # 加载第一个工作表
            if self._sheet_names:
                self.loadSheet(self._sheet_names[0])

            self.fileLoaded.emit(file_path)
            logger.info(f"Excel文件已加载: {file_path}")

        except Exception as e:
            error_msg = f"加载文件失败: {str(e)}"
            logger.error(error_msg)
            self.importFailed.emit(error_msg)

    @Slot(str)
    def loadSheet(self, sheet_name: str):
        """
        加载指定的工作表

        Args:
            sheet_name: 工作表名称
        """
        try:
            # 清空之前的数据
            self._excel_service.clear()

            # 读取Excel文件
            if not self._excel_service.read_excel_file(self._current_file_path, sheet_name):
                errors = self._excel_service.errors
                self.importFailed.emit("\n".join(errors) if errors else "读取Excel失败")
                return

            # 识别列
            column_mapping = self._excel_service.identify_columns()
            if not column_mapping:
                errors = self._excel_service.errors
                self.importFailed.emit("\n".join(errors) if errors else "无法识别必需的列")
                return

            self.columnsIdentified.emit(column_mapping)

            # 获取预览数据
            self._preview_data = self._excel_service.get_preview_data(20)
            self.previewDataReady.emit(self._preview_data)

            # 执行数据验证
            self.validateData()

        except Exception as e:
            error_msg = f"加载工作表失败: {str(e)}"
            logger.error(error_msg)
            self.importFailed.emit(error_msg)

    # ========== 数据验证 ==========

    @Slot()
    def validateData(self):
        """验证数据"""
        try:
            # 提取轨迹数据
            self._trajectory_data = self._excel_service.extract_trajectory_data()

            # 获取导入摘要
            self._import_summary = self._excel_service.get_import_summary()
            self._import_summary['data_count'] = len(self._trajectory_data)

            # 添加数据统计
            if self._trajectory_data:
                tvd_values = [d['tvd'] for d in self._trajectory_data]
                md_values = [d['md'] for d in self._trajectory_data]

                self._import_summary['statistics'] = {
                    'min_tvd': min(tvd_values),
                    'max_tvd': max(tvd_values),
                    'min_md': min(md_values),
                    'max_md': max(md_values),
                    'data_points': len(self._trajectory_data)
                }

            self.validationCompleted.emit(self._import_summary)

        except Exception as e:
            error_msg = f"数据验证失败: {str(e)}"
            logger.error(error_msg)
            self.importFailed.emit(error_msg)

    # ========== 数据导入 ==========

    @Slot(int)
    def importToWell(self, well_id: int):
        """
        导入数据到指定井

        Args:
            well_id: 井ID
        """
        if not self._trajectory_data:
            self.importFailed.emit("没有可导入的数据")
            return

        self._current_well_id = well_id

        try:
            # 准备导入数据
            import_data = []
            total_rows = len(self._trajectory_data)

            for idx, traj_data in enumerate(self._trajectory_data):
                # 发送进度
                self.importProgress.emit(idx + 1, total_rows)

                # 准备数据记录 - 修正字段映射
                record = {
                    'tvd': traj_data['tvd'],
                    'md': traj_data['md'],
                    'dls': traj_data.get('dls'),
                    'inclination': traj_data.get('inclination'),  # 修正：使用正确的字段名
                    'azimuth': traj_data.get('azimuth'),          # 修正：使用正确的字段名
                    'north_south': traj_data.get('north_south'),
                    'east_west': traj_data.get('east_west')
                }

                import_data.append(record)

            # 保存到数据库
            success = self._db_service.save_well_trajectories(well_id, import_data)

            if success:
                # 保存导入记录
                import_record = {
                    'well_id': well_id,
                    'file_name': os.path.basename(self._current_file_path),
                    'row_count': len(import_data),
                    'status': 'success',
                    'imported_by': 'current_user'  # TODO: 获取当前用户
                }

                # 添加统计信息到导入记录
                statistics = self._calculate_import_statistics(import_data)
                if statistics:
                    import_record['error_message'] = f"统计: {statistics}"

                if self._import_summary.get('warnings'):
                    warnings_text = '; '.join(self._import_summary['warnings'][:3])
                    import_record['error_message'] = (import_record.get('error_message', '') + 
                                                    f" 警告: {warnings_text}").strip()

                self._db_service.save_trajectory_import_record(import_record)

                self.importCompleted.emit(well_id, len(import_data))
                logger.info(f"成功导入{len(import_data)}条轨迹数据到井ID: {well_id}")
                logger.info(f"导入统计: {statistics}")
            else:
                self.importFailed.emit("保存数据到数据库失败")

        except Exception as e:
            error_msg = f"导入失败: {str(e)}"
            logger.error(error_msg)

            # 保存失败记录
            try:
                import_record = {
                    'well_id': well_id,
                    'file_name': os.path.basename(self._current_file_path),
                    'row_count': 0,
                    'status': 'failed',
                    'error_message': error_msg,
                    'imported_by': 'current_user'
                }
                self._db_service.save_trajectory_import_record(import_record)
            except:
                pass

            self.importFailed.emit(error_msg)

    
    def _calculate_import_statistics(self, import_data: List[Dict]) -> str:
        """计算导入统计信息"""
        if not import_data:
            return ""
        
        stats = []
        total = len(import_data)
        
        # 统计各字段的数据完整性
        field_counts = {}
        for record in import_data:
            for field in ['dls', 'inclination', 'azimuth', 'north_south', 'east_west']:
                if record.get(field) is not None:
                    field_counts[field] = field_counts.get(field, 0) + 1
        
        field_names = {
            'dls': '狗腿度',
            'inclination': '井斜角',
            'azimuth': '方位角',
            'north_south': '南北坐标',
            'east_west': '东西坐标'
        }
        
        for field, count in field_counts.items():
            percentage = (count / total) * 100
            stats.append(f"{field_names.get(field, field)}: {count}/{total}({percentage:.1f}%)")
        
        return '; '.join(stats)

    # ========== 辅助方法 ==========

    @Slot(result=dict)
    def getColumnMapping(self) -> dict:
        """获取列映射"""
        return self._excel_service.column_mapping.copy()

    @Slot(result=list)
    def getTrajectoryData(self) -> list:
        """获取轨迹数据"""
        return self._trajectory_data.copy()

    @Slot()
    def clearData(self):
        """清空数据"""
        self._excel_service.clear()
        self._current_file_path = ""
        self._trajectory_data = []
        self._preview_data = []
        self._sheet_names = []
        self._import_summary = {}

    @Slot(int, result=list)
    def getImportHistory(self, well_id: int) -> list:
        """
        获取导入历史

        Args:
            well_id: 井ID

        Returns:
            导入历史记录列表
        """
        try:
            # 这里需要在DatabaseService中添加相应的方法
            # 暂时返回空列表
            return []
        except Exception as e:
            logger.error(f"获取导入历史失败: {e}")
            return []
