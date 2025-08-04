# Controller/UnitSystemController.py
from PySide6.QtCore import QObject, Signal, Slot, Property, QTimer
import logging

logger = logging.getLogger(__name__)


class UnitSystemController_new(QObject):
    # 信号
    unitSystemChanged = Signal(bool)  # isMetric
    
    def __init__(self):
        super().__init__()
        self._isMetric = False  # 默认使用英制
        
        # 🔥 支持的单位类型和转换系数
        self._conversion_factors = {
            "length": {"ft_to_m": 0.3048, "in_to_mm": 25.4},
            "pressure": {"psi_to_mpa": 1/145.038},
            "temperature": {"f_offset": 32, "f_scale": 5/9},
            "flow": {"bbl_to_m3": 0.159},
            "density": {"lbft3_to_kgm3": 16.018},
            "power": {"hp_to_kw": 0.746},      # 🔥 新增
            "force": {"lbs_to_n": 4.448},      # 🔥 新增
            "weight": {"lbs_to_kg": 0.453592}  # 🔥 新增
        }
        
        # 🔥 单位标签定义
        self._unit_labels = {
            "metric": {
                "depth": "m", "diameter": "mm", "pressure": "MPa", 
                "temperature": "°C", "flow": "m³/d", "density": "kg/m³",
                "power": "kW", "force": "N", "weight": "kg"
            },
            "imperial": {
                "depth": "ft", "diameter": "in", "pressure": "psi", 
                "temperature": "°F", "flow": "bbl/d", "density": "lb/ft³",
                "power": "HP", "force": "lbs", "weight": "lbs"
            }
        }

    @Property(bool, notify=unitSystemChanged)
    def isMetric(self):
        return self._isMetric

    @isMetric.setter 
    def isMetric(self, value):
        if self._isMetric != value:
            self._isMetric = value
            self.unitSystemChanged.emit(value)
            print(f"单位制切换为: {'公制' if value else '英制'}")

    @Slot()
    def toggleUnitSystem(self):
        """切换单位制"""
        self.isMetric = not self._isMetric

    @Slot(str, bool, result=str)
    def getUnitLabel(self, unit_type, is_metric=None):
        """获取单位标签"""
        if is_metric is None:
            is_metric = self._isMetric
            
        system = "metric" if is_metric else "imperial"
        return self._unit_labels.get(system, {}).get(unit_type, "")

    @Slot(float, str, str, result=float)
    def convertValue(self, value, from_unit, to_unit):
        """转换数值"""
        if from_unit == to_unit:
            return value
            
        # 🔥 实现各种单位转换
        conversion_map = {
            ("ft", "m"): lambda x: x * self._conversion_factors["length"]["ft_to_m"],
            ("m", "ft"): lambda x: x / self._conversion_factors["length"]["ft_to_m"],
            ("in", "mm"): lambda x: x * self._conversion_factors["length"]["in_to_mm"],
            ("mm", "in"): lambda x: x / self._conversion_factors["length"]["in_to_mm"],
            ("psi", "MPa"): lambda x: x * self._conversion_factors["pressure"]["psi_to_mpa"],
            ("MPa", "psi"): lambda x: x / self._conversion_factors["pressure"]["psi_to_mpa"],
            ("HP", "kW"): lambda x: x * self._conversion_factors["power"]["hp_to_kw"],
            ("kW", "HP"): lambda x: x / self._conversion_factors["power"]["hp_to_kw"],
            ("lbs", "N"): lambda x: x * self._conversion_factors["force"]["lbs_to_n"],
            ("N", "lbs"): lambda x: x / self._conversion_factors["force"]["lbs_to_n"],
            ("lbs", "kg"): lambda x: x * self._conversion_factors["weight"]["lbs_to_kg"],
            ("kg", "lbs"): lambda x: x / self._conversion_factors["weight"]["lbs_to_kg"],
        }
        
        converter = conversion_map.get((from_unit, to_unit))
        if converter:
            return converter(value)
            
        # 特殊处理温度转换
        if from_unit == "°F" and to_unit == "°C":
            return (value - self._conversion_factors["temperature"]["f_offset"]) * self._conversion_factors["temperature"]["f_scale"]
        elif from_unit == "°C" and to_unit == "°F":
            return value / self._conversion_factors["temperature"]["f_scale"] + self._conversion_factors["temperature"]["f_offset"]
            
        return value  # 如果没有匹配的转换，返回原值

    @Slot(float, str, result=str)
    def formatValue(self, value, unit_type):
        """格式化数值显示"""
        try:
            unit_label = self.getUnitLabel(unit_type)
            
            # 根据单位类型选择合适的小数位数
            decimal_places = {
                "temperature": 0,
                "pressure": 1 if self._isMetric else 0,
                "power": 1,
                "force": 0 if self._isMetric else 0,
                "weight": 0,
                "diameter": 0 if self._isMetric else 2,
                "depth": 1 if self._isMetric else 1,
                "flow": 1,
                "density": 1
            }.get(unit_type, 2)
            
            formatted_value = f"{value:.{decimal_places}f}"
            return f"{formatted_value} {unit_label}"
            
        except Exception as e:
            print(f"格式化数值时出错: {e}")
            return str(value)

    @Slot(result='QVariantMap')
    def getAllUnitLabels(self):
        """获取所有单位标签"""
        system = "metric" if self._isMetric else "imperial"
        return self._unit_labels.get(system, {})
        
    @Slot(str, result=str)  
    def getLocalizedUnitName(self, unit_type):
        """获取本地化的单位名称（中文）"""
        if self._isMetric:
            chinese_names = {
                "depth": "米", "diameter": "毫米", "pressure": "兆帕",
                "temperature": "摄氏度", "flow": "立方米每天", "density": "千克每立方米",
                "power": "千瓦", "force": "牛顿", "weight": "千克"
            }
        else:
            chinese_names = {
                "depth": "英尺", "diameter": "英寸", "pressure": "磅每平方英寸",
                "temperature": "华氏度", "flow": "桶每天", "density": "磅每立方英尺", 
                "power": "马力", "force": "磅力", "weight": "磅"
            }
        return chinese_names.get(unit_type, "")

class UnitSystemController(QObject):
    """单位制控制器 - 管理公制和英制单位转换"""
    
    # 信号定义
    unitSystemChanged = Signal(bool)  # True=公制, False=英制
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._is_metric = True  # 默认公制
        logger.info("单位制控制器初始化完成")
        
    # 单位制属性
    def get_is_metric(self) -> bool:
        """获取当前单位制"""
        return self._is_metric
    
    def set_is_metric(self, is_metric: bool):
        """设置单位制"""
        if self._is_metric != is_metric:
            self._is_metric = is_metric
            self.unitSystemChanged.emit(is_metric)
            logger.info(f"单位制已切换为: {'公制' if is_metric else '英制'}")
    
    isMetric = Property(bool, get_is_metric, set_is_metric, notify=unitSystemChanged)
    
    # 转换方法
    @Slot(float, str, result=float)
    def convertValue(self, value, unit_type):
        """转换数值"""
        if not self._is_metric:  # 如果当前是英制，不需要转换
            return value
            
        # 公制转英制的转换
        if unit_type == "depth":  # 深度：米 → 英尺
            return value * 3.28084
        elif unit_type == "diameter":  # 直径：毫米 → 英寸
            return value / 25.4
        elif unit_type == "pressure":  # 压力：kPa → psi
            return value / 6.895
        elif unit_type == "temperature":  # 温度：°C → °F
            return value * 9/5 + 32
        elif unit_type == "flow":  # 流量：m³/d → bbl/d
            return value / 0.159
        elif unit_type == "density":  # 密度：kg/m³ → lb/ft³
            return value / 16.018
        
        return value
    
    @Slot(str, result=str)
    def getUnitLabel(self, unit_type):
        """获取单位标签"""
        if self._is_metric:
            metric_units = {
                "depth": "m",
                "diameter": "mm", 
                "pressure": "MPa",
                "temperature": "°C",
                "flow": "m³/d",
                "density": "kg/m³"
            }
            return metric_units.get(unit_type, "")
        else:
            imperial_units = {
                "depth": "ft",
                "diameter": "in",
                "pressure": "psi", 
                "temperature": "°F",
                "flow": "bbl/d",
                "density": "lb/ft³"
            }
            return imperial_units.get(unit_type, "")
    
    @Slot(str, bool, result=str)
    def getUnitDisplayText(self, unit_type, is_chinese):
        """获取单位显示文本"""
        if self._is_metric:
            if is_chinese:
                metric_text = {
                    "depth": "米",
                    "diameter": "毫米",
                    "pressure": "千帕",
                    "temperature": "摄氏度",
                    "flow": "立方米/天",
                    "density": "千克/立方米"
                }
                return metric_text.get(unit_type, "")
            else:
                return self.getUnitLabel(unit_type)
        else:
            if is_chinese:
                imperial_text = {
                    "depth": "英尺",
                    "diameter": "英寸", 
                    "pressure": "磅/平方英寸",
                    "temperature": "华氏度",
                    "flow": "桶/天",
                    "density": "磅/立方英尺"
                }
                return imperial_text.get(unit_type, "")
            else:
                return self.getUnitLabel(unit_type)

# 单位转换工具类
class UnitConverter:
    """静态单位转换工具类"""
    
    # 长度转换
    @staticmethod
    def feet_to_meters(feet):
        return feet * 0.3048
    
    @staticmethod
    def meters_to_feet(meters):
        return meters / 0.3048
    
    # 直径转换
    @staticmethod
    def inches_to_mm(inches):
        return inches * 25.4
    
    @staticmethod
    def mm_to_inches(mm):
        return mm / 25.4
    
    # 压力转换
    @staticmethod
    def psi_to_kpa(psi):
        return psi * 6.895
    
    @staticmethod
    def kpa_to_psi(kpa):
        return kpa / 6.895
    
    # 温度转换
    @staticmethod
    def fahrenheit_to_celsius(f):
        return (f - 32) * 5/9
    
    @staticmethod
    def celsius_to_fahrenheit(c):
        return c * 9/5 + 32
    
    # 流量转换
    @staticmethod
    def bbl_to_m3(bbl):
        return bbl * 0.159
    
    @staticmethod
    def m3_to_bbl(m3):
        return m3 / 0.159
    
    # 密度转换
    @staticmethod
    def lbft3_to_kgm3(lbft3):
        return lbft3 * 16.018
    
    @staticmethod
    def kgm3_to_lbft3(kgm3):
        return kgm3 / 16.018