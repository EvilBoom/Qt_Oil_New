# DataManage/models/__init__.py

from .base import Base
from .well_trajectory import WellTrajectory, WellTrajectoryImport
from .casing import Casing, WellCalculationResult
from .device import (
    Device, DeviceType, DevicePump, DeviceMotor,
    DeviceProtector, DeviceSeparator, MotorFrequencyParam
)
from .production_parameters import ProductionParameters, ProductionPrediction

# 🔥 阶段1: 基础泵性能模型
from .pump_performance import (
    PumpCurveData, PumpEnhancedParameters, 
    PumpOperatingPoint, PumpSystemCurve
)

# 🔥 阶段2: 性能预测和磨损分析模型
from .performance_prediction import (
    DevicePerformancePrediction, PumpWearData, MaintenanceRecord
)

# 🔥 阶段2: 工况对比和优化模型
from .condition_comparison import (
    PumpConditionComparison, ConditionOptimization
)

__all__ = [
    'Base',
    'WellTrajectory', 'WellTrajectoryImport',
    'Casing', 'WellCalculationResult', 
    'Device', 'DeviceType', 'DevicePump', 'DeviceMotor',
    'DeviceProtector', 'DeviceSeparator', 'MotorFrequencyParam',
    'ProductionParameters', 'ProductionPrediction',
    
    # 阶段1: 泵性能模型
    'PumpCurveData', 'PumpEnhancedParameters',
    'PumpOperatingPoint', 'PumpSystemCurve',
    
    # 阶段2: 预测和分析模型
    'DevicePerformancePrediction', 'PumpWearData', 'MaintenanceRecord',
    'PumpConditionComparison', 'ConditionOptimization'
]