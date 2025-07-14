# DataManage/models/device.py

from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean, Text, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum

from .base import Base


class DeviceType(enum.Enum):
    """设备类型枚举"""
    PUMP = "pump"
    MOTOR = "motor"
    PROTECTOR = "protector"
    SEPARATOR = "separator"


class Device(Base):
    """设备基础表"""
    __tablename__ = 'devices'

    id = Column(Integer, primary_key=True)
    device_type = Column(Enum(DeviceType), nullable=False)
    manufacturer = Column(String(100))
    model = Column(String(100), nullable=False)
    serial_number = Column(String(100), unique=True)
    status = Column(String(20), default='active')  # active, inactive, maintenance
    description = Column(Text)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)
    is_deleted = Column(Boolean, default=False)

    # 多态关系
    pump = relationship("DevicePump", back_populates="device", uselist=False, cascade="all, delete-orphan")
    motor = relationship("DeviceMotor", back_populates="device", uselist=False, cascade="all, delete-orphan")
    protector = relationship("DeviceProtector", back_populates="device", uselist=False, cascade="all, delete-orphan")
    separator = relationship("DeviceSeparator", back_populates="device", uselist=False, cascade="all, delete-orphan")

    def to_dict(self):
        data = {
            'id': self.id,
            'device_type': self.device_type.value if self.device_type else None,
            'manufacturer': self.manufacturer,
            'model': self.model,
            'serial_number': self.serial_number,
            'status': self.status,
            'description': self.description,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

        # 添加特定设备的详细信息
        if self.device_type == DeviceType.PUMP and self.pump:
            data['pump_details'] = self.pump.to_dict()
        elif self.device_type == DeviceType.MOTOR and self.motor:
            data['motor_details'] = self.motor.to_dict()
        elif self.device_type == DeviceType.PROTECTOR and self.protector:
            data['protector_details'] = self.protector.to_dict()
        elif self.device_type == DeviceType.SEPARATOR and self.separator:
            data['separator_details'] = self.separator.to_dict()
        # 添加设备特定详细信息
        if self.device_type == DeviceType.MOTOR and self.motor:
            motor_details = {
                'motor_type': self.motor.motor_type,
                'outside_diameter': self.motor.outside_diameter,
                'length': self.motor.length,
                'weight': self.motor.weight,
                'insulation_class': self.motor.insulation_class,
                'protection_class': self.motor.protection_class,
                'frequency_params': []
            }
        
            # 添加频率参数
            for param in self.motor.frequency_params:
                motor_details['frequency_params'].append({
                    'frequency': param.frequency,
                    'power': param.power,
                    'voltage': param.voltage,
                    'current': param.current,
                    'speed': param.speed
                })
        
            data['motor_details'] = motor_details
        return data


class DevicePump(Base):
    """潜油离心泵表"""
    __tablename__ = 'device_pumps'

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey('devices.id', ondelete='CASCADE'), nullable=False)
    impeller_model = Column(String(50))
    displacement_min = Column(Float)  # 最小排量 (m³/d)
    displacement_max = Column(Float)  # 最大排量 (m³/d)
    single_stage_head = Column(Float)  # 单级扬程 (m)
    single_stage_power = Column(Float)  # 单级功率 (kW)
    shaft_diameter = Column(Float)  # 轴径 (mm)
    mounting_height = Column(Float)  # 安装高度 (mm)
    outside_diameter = Column(Float)  # 外径 (mm)
    max_stages = Column(Integer)  # 最大级数
    efficiency = Column(Float)  # 效率 (%)

    device = relationship("Device", back_populates="pump")

    def to_dict(self):
        return {
            'id': self.id,
            'impeller_model': self.impeller_model,
            'displacement_min': self.displacement_min,
            'displacement_max': self.displacement_max,
            'single_stage_head': self.single_stage_head,
            'single_stage_power': self.single_stage_power,
            'shaft_diameter': self.shaft_diameter,
            'mounting_height': self.mounting_height,
            'outside_diameter': self.outside_diameter,
            'max_stages': self.max_stages,
            'efficiency': self.efficiency
        }


class DeviceMotor(Base):
    """电机表"""
    __tablename__ = 'device_motors'

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey('devices.id', ondelete='CASCADE'), nullable=False)
    motor_type = Column(String(50))
    outside_diameter = Column(Float)  # 外径 (mm)
    length = Column(Float)  # 长度 (mm)
    weight = Column(Float)  # 重量 (kg)
    insulation_class = Column(String(10))  # 绝缘等级
    protection_class = Column(String(10))  # 防护等级

    device = relationship("Device", back_populates="motor")
    frequency_params = relationship("MotorFrequencyParam", back_populates="motor", cascade="all, delete-orphan")

    def to_dict(self):
        data = {
            'id': self.id,
            'motor_type': self.motor_type,
            'outside_diameter': self.outside_diameter,
            'length': self.length,
            'weight': self.weight,
            'insulation_class': self.insulation_class,
            'protection_class': self.protection_class
        }

        # 添加频率参数
        if self.frequency_params:
            data['frequency_params'] = [fp.to_dict() for fp in self.frequency_params]

        return data


class MotorFrequencyParam(Base):
    """电机频率参数表"""
    __tablename__ = 'motor_frequency_params'

    id = Column(Integer, primary_key=True)
    motor_id = Column(Integer, ForeignKey('device_motors.id', ondelete='CASCADE'), nullable=False)
    frequency = Column(Integer, nullable=False)  # 频率 (Hz)
    power = Column(Float)  # 功率 (kW)
    voltage = Column(Float)  # 电压 (V)
    current = Column(Float)  # 电流 (A)
    speed = Column(Integer)  # 转速 (rpm)

    motor = relationship("DeviceMotor", back_populates="frequency_params")

    def to_dict(self):
        return {
            'id': self.id,
            'frequency': self.frequency,
            'power': self.power,
            'voltage': self.voltage,
            'current': self.current,
            'speed': self.speed
        }


class DeviceProtector(Base):
    """保护器表"""
    __tablename__ = 'device_protectors'

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey('devices.id', ondelete='CASCADE'), nullable=False)
    outer_diameter = Column(Float)  # 外径 (mm)
    length = Column(Float)  # 长度 (mm)
    weight = Column(Float)  # 重量 (kg)
    thrust_capacity = Column(Float)  # 推力承载能力 (kN)
    seal_type = Column(String(50))  # 密封类型
    max_temperature = Column(Float)  # 最高温度 (℃)

    device = relationship("Device", back_populates="protector")

    def to_dict(self):
        return {
            'id': self.id,
            'outer_diameter': self.outer_diameter,
            'length': self.length,
            'weight': self.weight,
            'thrust_capacity': self.thrust_capacity,
            'seal_type': self.seal_type,
            'max_temperature': self.max_temperature
        }


class DeviceSeparator(Base):
    """分离器表"""
    __tablename__ = 'device_separators'

    id = Column(Integer, primary_key=True)
    device_id = Column(Integer, ForeignKey('devices.id', ondelete='CASCADE'), nullable=False)
    outer_diameter = Column(Float)  # 外径 (mm)
    length = Column(Float)  # 长度 (mm)
    weight = Column(Float)  # 重量 (kg)
    separation_efficiency = Column(Float)  # 分离效率 (%)
    gas_handling_capacity = Column(Float)  # 气体处理能力 (m³/d)
    liquid_handling_capacity = Column(Float)  # 液体处理能力 (m³/d)

    device = relationship("Device", back_populates="separator")

    def to_dict(self):
        return {
            'id': self.id,
            'outer_diameter': self.outer_diameter,
            'length': self.length,
            'weight': self.weight,
            'separation_efficiency': self.separation_efficiency,
            'gas_handling_capacity': self.gas_handling_capacity,
            'liquid_handling_capacity': self.liquid_handling_capacity
        }
