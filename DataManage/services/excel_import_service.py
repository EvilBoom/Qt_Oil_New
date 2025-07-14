# services/excel_import_service.py

import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional, Any
import os
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

class ExcelImportService:
    """Excel导入服务 - 处理井轨迹数据的Excel导入"""

    # 支持的列名映射 - 增强版，支持更多变体
    COLUMN_MAPPINGS = {
        'TVD': ['TVD', 'tvd', 'Tvd', 'True Vertical Depth', '垂深', '垂直深度'],
        'MD': ['MD', 'md', 'Md', 'Measured Depth', '测深', '测量深度', '斜深'],
        'DLS': ['DLS', 'dls', 'Dls', 'Dog Leg Severity', '狗腿度', '狗腿严重度'],
        'INCLINATION': [
            'Inclination', 'Inc', 'inc', 'Incl', 'incl', 'INCL',
            'Deviation', 'Dev', 'Inclination Angle', 'Well Deviation',
            '井斜角', '井斜', '倾角', '偏斜角'
        ],
        'AZIMUTH': [
            'Azimuth', 'Azi', 'azi', 'AZI', 'Azim', 'azim', 'AZIM',
            'Azim Grid', 'azim grid', 'AZIM GRID', 'Azimuth Grid',
            'Direction', 'Dir', 'Azimuth Angle', 'Well Direction',
            '方位角', '方位', '方向角'
        ],
        'NORTH_SOUTH': ['North/South', 'N/S', 'NS', 'North', 'Y', 'Northing', '南北坐标', '北坐标', 'N-S'],
        'EAST_WEST': ['East/West', 'E/W', 'EW', 'East', 'X', 'Easting', '东西坐标', '东坐标', 'E-W']
    }

    def __init__(self):
        self.data = None
        self.column_mapping = {}
        self.errors = []
        self.warnings = []

    def read_excel_file(self, file_path: str, sheet_name: Optional[str] = None) -> bool:
        """
        读取Excel文件

        Args:
            file_path: Excel文件路径
            sheet_name: 工作表名称，如果为None则读取第一个工作表

        Returns:
            是否成功读取
        """
        try:
            if not os.path.exists(file_path):
                self.errors.append(f"文件不存在: {file_path}")
                return False

            # 读取Excel文件
            if sheet_name:
                self.data = pd.read_excel(file_path, sheet_name=sheet_name)
            else:
                # 读取第一个工作表
                excel_file = pd.ExcelFile(file_path)
                if excel_file.sheet_names:
                    self.data = pd.read_excel(file_path, sheet_name=excel_file.sheet_names[0])
                else:
                    self.errors.append("Excel文件中没有找到工作表")
                    return False

            logger.info(f"成功读取Excel文件: {file_path}, 数据行数: {len(self.data)}")
            return True

        except Exception as e:
            self.errors.append(f"读取Excel文件失败: {str(e)}")
            logger.error(f"读取Excel文件失败: {e}")
            return False

    def identify_columns(self) -> Dict[str, str]:
        """
        识别Excel中的列名，自动匹配TVD、MD、DLS、井斜角、方位角等列
        Returns:
            列名映射字典
        """
        if self.data is None:
            self.errors.append("未加载Excel数据")
            return {}

        self.column_mapping = {}
        found_columns = []

        # 打印所有列名用于调试
        logger.info("Excel中的列名:")
        for i, col in enumerate(self.data.columns):
            logger.info(f"  列{i}: '{col}' (类型: {type(col)}, 长度: {len(str(col))})")

        # 遍历Excel的列名
        for excel_col in self.data.columns:
            # 确保是字符串并清理
            excel_col_str = str(excel_col).strip()
            excel_col_upper = excel_col_str.upper()

            logger.debug(f"处理列: '{excel_col_str}'")

            # 检查每个标准列名
            matched = False
            for std_col, variations in self.COLUMN_MAPPINGS.items():
                if matched:
                    break

                for variation in variations:
                    variation_upper = variation.upper()

                    # 多种匹配方式
                    is_match = False

                    # 1. 完全匹配
                    if excel_col_upper == variation_upper:
                        is_match = True
                        logger.debug(f"  完全匹配: '{excel_col_upper}' == '{variation_upper}'")

                    # 2. 去除空格后匹配
                    elif excel_col_upper.replace(' ', '') == variation_upper.replace(' ', ''):
                        is_match = True
                        logger.debug(f"  去空格匹配: '{excel_col_upper}' ~ '{variation_upper}'")

                    # 3. 包含关系匹配
                    elif variation_upper in excel_col_upper:
                        # 特殊处理：避免 "INCL" 匹配到 "INCLINATION" 以外的词
                        if variation_upper == 'INCL' and len(excel_col_upper) > 4:
                            # 确保 INCL 是独立的词或者是 INCLINATION 的缩写
                            if ('INCL' in excel_col_upper and 
                                not any(x in excel_col_upper for x in ['INCLUDE', 'INCLUSIVE'])):
                                is_match = True
                        elif variation_upper == 'AZIM':
                            # 特殊处理：AZIM 可以匹配 "AZIM GRID" 等
                            if 'AZIM' in excel_col_upper:
                                is_match = True
                        else:
                            is_match = True
                        
                        if is_match:
                            logger.debug(f"  包含匹配: '{variation_upper}' in '{excel_col_upper}'")

                    # 4. Excel列包含在变体中（对于长变体名）
                    elif len(variation_upper) > len(excel_col_upper) and excel_col_upper in variation_upper:
                        is_match = True
                        logger.debug(f"  反向包含匹配: '{excel_col_upper}' in '{variation_upper}'")

                    if is_match:
                        self.column_mapping[std_col] = excel_col
                        found_columns.append(std_col)
                        logger.info(f"识别列: '{excel_col}' -> {std_col}")
                        matched = True
                        break

        logger.info(f"识别结果:")
        logger.info(f"找到的列: {found_columns}")
        logger.info(f"列映射: {self.column_mapping}")

        # 检查必需的列
        required_columns = ['TVD', 'MD']
        missing_columns = [col for col in required_columns if col not in found_columns]

        if missing_columns:
            self.errors.append(f"缺少必需的列: {', '.join(missing_columns)}")
            logger.error(f"错误: 缺少必需的列: {missing_columns}")

            # 提供更多调试信息
            logger.error("可能的原因:")
            logger.error("1. 列名可能包含额外的空格或特殊字符")
            logger.error("2. 列名大小写不匹配")
            logger.error("3. 列名使用了不在映射表中的变体")
            logger.error("请检查Excel文件中的列名，或联系支持人员添加新的列名变体")

            return {}

        # 警告可选列
        optional_columns = ['DLS', 'INCLINATION', 'AZIMUTH', 'NORTH_SOUTH', 'EAST_WEST']
        missing_optional = [col for col in optional_columns if col not in found_columns]
        if missing_optional:
            self.warnings.append(f"未找到可选列: {', '.join(missing_optional)}")
            logger.warning(f"未找到可选列: {missing_optional}")

        return self.column_mapping

    def extract_trajectory_data(self, start_row: int = 0) -> List[Dict[str, Any]]:
        """
        提取轨迹数据，包括井斜角和方位角

        Args:
            start_row: 开始读取的行号

        Returns:
            轨迹数据列表
        """
        if not self.column_mapping:
            self.errors.append("未识别列名，请先调用identify_columns()")
            return []

        trajectory_data = []

        try:
            # 获取TVD和MD列（必需）
            tvd_col = self.column_mapping.get('TVD')
            md_col = self.column_mapping.get('MD')

            if not tvd_col or not md_col:
                self.errors.append("未找到TVD或MD列")
                return []

            # 从指定行开始读取
            for idx in range(start_row, len(self.data)):
                row = self.data.iloc[idx]

                # 获取TVD和MD值
                tvd_value = row[tvd_col]
                md_value = row[md_col]

                # 检查是否为空值（遇到第一个空值就停止）
                if pd.isna(tvd_value) or pd.isna(md_value):
                    logger.info(f"在第{idx+1}行遇到空值，停止读取")
                    break

                # 尝试转换为浮点数
                try:
                    tvd = float(tvd_value)
                    md = float(md_value)
                except (ValueError, TypeError):
                    self.warnings.append(f"第{idx+1}行的TVD或MD值无效: TVD={tvd_value}, MD={md_value}")
                    continue

                # 创建数据记录
                record = {
                    'tvd': tvd,
                    'md': md,
                    'row_number': idx + 1  # Excel行号（从1开始）
                }

                # 读取可选列，使用更好的键名映射
                optional_fields = {
                    'DLS': 'dls',
                    'INCLINATION': 'inclination',  # 映射到数据库字段名
                    'AZIMUTH': 'azimuth',          # 映射到数据库字段名
                    'NORTH_SOUTH': 'north_south',
                    'EAST_WEST': 'east_west'
                }

                for excel_col_key, db_field in optional_fields.items():
                    if excel_col_key in self.column_mapping:
                        excel_col = self.column_mapping[excel_col_key]
                        value = row[excel_col]
                        if not pd.isna(value):
                            try:
                                record[db_field] = float(value)
                                logger.debug(f"第{idx+1}行: {excel_col_key}({excel_col}) = {value}")
                            except (ValueError, TypeError):
                                self.warnings.append(f"第{idx+1}行的{excel_col_key}值无效: {value}")

                trajectory_data.append(record)

            # 数据验证
            if trajectory_data:
                self._validate_trajectory_data(trajectory_data)

            logger.info(f"成功提取{len(trajectory_data)}条轨迹数据")
            
            # 输出统计信息
            self._log_data_statistics(trajectory_data)
            
            return trajectory_data

        except Exception as e:
            self.errors.append(f"提取轨迹数据失败: {str(e)}")
            logger.error(f"提取轨迹数据失败: {e}")
            return []

    def _log_data_statistics(self, data: List[Dict[str, Any]]) -> None:
        """记录数据统计信息"""
        if not data:
            return

        # 统计包含各字段的记录数量
        field_counts = {}
        for record in data:
            for field in ['dls', 'inclination', 'azimuth', 'north_south', 'east_west']:
                if field in record:
                    field_counts[field] = field_counts.get(field, 0) + 1

        logger.info("数据统计:")
        logger.info(f"  总记录数: {len(data)}")
        for field, count in field_counts.items():
            field_names = {
                'dls': '狗腿度',
                'inclination': '井斜角',
                'azimuth': '方位角',
                'north_south': '南北坐标',
                'east_west': '东西坐标'
            }
            logger.info(f"  包含{field_names.get(field, field)}的记录: {count}")

    def _validate_trajectory_data(self, data: List[Dict[str, Any]]) -> None:
        """
        验证轨迹数据的合理性，包括井斜角和方位角

        Args:
            data: 轨迹数据列表
        """
        if not data:
            return

        # 检查深度递增
        prev_md = 0
        prev_tvd = 0

        for i, record in enumerate(data):
            md = record.get('md', 0)
            tvd = record.get('tvd', 0)

            # MD应该递增
            if md < prev_md:
                self.warnings.append(f"第{record['row_number']}行: MD值({md})小于前一行({prev_md})")

            # TVD不应该超过MD
            if tvd > md:
                self.warnings.append(f"第{record['row_number']}行: TVD({tvd})大于MD({md})")

            # DLS合理范围检查
            if 'dls' in record:
                dls = record['dls']
                if dls < 0:
                    self.warnings.append(f"第{record['row_number']}行: DLS为负值({dls})")
                elif dls > 30:  # 一般认为超过30度/30m的狗腿度过大
                    self.warnings.append(f"第{record['row_number']}行: DLS过大({dls})")

            # 井斜角合理范围检查
            if 'inclination' in record:
                incl = record['inclination']
                if incl < 0:
                    self.warnings.append(f"第{record['row_number']}行: 井斜角为负值({incl})")
                elif incl > 90:  # 井斜角不应超过90度
                    self.warnings.append(f"第{record['row_number']}行: 井斜角过大({incl})")

            # 方位角合理范围检查
            if 'azimuth' in record:
                azim = record['azimuth']
                if azim < 0 or azim >= 360:  # 方位角应在0-360度范围内
                    self.warnings.append(f"第{record['row_number']}行: 方位角超出范围({azim})")

            prev_md = md
            prev_tvd = tvd

    def get_preview_data(self, max_rows: int = 10) -> List[Dict[str, Any]]:
        """
        获取预览数据

        Args:
            max_rows: 最大预览行数

        Returns:
            预览数据列表
        """
        if self.data is None:
            return []

        preview_data = []
        columns = list(self.data.columns)

        for idx in range(min(max_rows, len(self.data))):
            row_data = {
                'row_number': idx + 1,
                'data': {}
            }

            for col in columns:
                value = self.data.iloc[idx][col]
                # 转换为可序列化的类型
                if pd.isna(value):
                    row_data['data'][col] = None
                elif isinstance(value, (np.integer, np.floating)):
                    row_data['data'][col] = float(value)
                else:
                    row_data['data'][col] = str(value)

            preview_data.append(row_data)

        return preview_data

    def get_sheet_names(self, file_path: str) -> List[str]:
        """
        获取Excel文件中的所有工作表名称

        Args:
            file_path: Excel文件路径

        Returns:
            工作表名称列表
        """
        try:
            excel_file = pd.ExcelFile(file_path)
            logger.info(f"工作表列表: {excel_file.sheet_names}")
            return excel_file.sheet_names
        except Exception as e:
            self.errors.append(f"获取工作表名称失败: {str(e)}")
            logger.error(f"获取工作表名称失败: {str(e)}")
            return []

    def clear(self):
        """清空数据和错误信息"""
        self.data = None
        self.column_mapping = {}
        self.errors = []
        self.warnings = []

    def get_import_summary(self) -> Dict[str, Any]:
        """
        获取导入摘要信息

        Returns:
            包含导入信息的字典
        """
        return {
            'total_rows': len(self.data) if self.data is not None else 0,
            'identified_columns': list(self.column_mapping.keys()),
            'column_mapping': self.column_mapping.copy(),
            'errors': self.errors.copy(),
            'warnings': self.warnings.copy(),
            'has_errors': len(self.errors) > 0,
            'has_warnings': len(self.warnings) > 0
        }