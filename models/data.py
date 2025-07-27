from typing import Optional
from dataclasses import dataclass

@dataclass  
class UIData:    # 两相流数据类
    IP: float                        # 生产指数 b/p/d
    PR: Optional[float] = None       # 地层压力   Mpa
    BHT: float                       # 井底温度 °F
    Pb: float                        # 泡点压力 psi
    BSW: float                       # 含水率   %
    QF: Optional[float] = None       # 期望产量 bls
    GOR: float                       # 油气比   scf/bbl
    API: float                       # 油的重度  °API
    WHP: float                       # 井口压力

    aPr: Optional[float] = None        # 平均地层压力 Mpa
    wellLowFlowPressure: float =None  # 井底流压  Mpa
    saturationPressure:float=None # 饱和压力
    rg: float = 0.7 # 相对密度
    ro: float = 0.9 # 相对密度
    rsb:Optional[float] =None#   
    temp: Optional[float] =None# 温度
    productionGasolineRatio: Optional[float] =None # 生产汽油比 m^3/m^3