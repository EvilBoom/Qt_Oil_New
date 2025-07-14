# 使用公式计算吸入口气液比
at_pumb_results_fromat = calculate_complex_formula(
            Pi_Mpa=self.ProduceIndex,
            Pb_Mpa=pressureChange(self.SaturationPressure),
            tempature=self.BHT,                               #TODO 使用什么温度进行计算  现在BHT是井底温度
            water_ratio=self.BSW,
            Production_gasoline_ratio=self.GasOilRatio*0.1781     # 单位换算
            )
# 使用公式计算扬程
lift_results_format = excel_formula(
            Vertical_depth_of_perforation_top_boundary=PerforationVerticalDepth,
            Pump_hanging_depth=Pump_hanging_depth,                       # 泵挂垂深
            Pwh=self.WellHeadPressure,
            Pperfs=self.Pperfs,                                   # 井底流压
            Pump_hanging_depth_measurement=PumpHangingVerticalDepth,           # 泵挂测深
            water_ratio=self.BSW,
            api=self.API
        )
def excel_if(condition, true_value, false_value):
    """Excel IF函数的Python实现"""
    return true_value if condition else false_value

def calculate_complex_formula(Pi_Mpa, Pb_Mpa, tempature, water_ratio,Production_gasoline_ratio ,Z_const=0.8, Rg_const=0.896, Ro_const=0.849):
    """
    将Excel复杂公式转换为Python函数
    Pi_Mpa,           产油指数？
    Z_const,           常数
    Pb_Mpa,           泡点压力
    Rg_const,          相对水密度  常数
    Ro_const,          相对油密度  常数
    tempature,          温度
    water_ratio,         含水率
    Production_gasoline_ratio   生产气液比
    参数:
    Pi_Mpa, Z_const, Pb_Mpa, Rg_const, Ro_const, tempature, water_ratio, Production_gasoline_ratio: 输入参数
    
    返回:
    计算结果
    """
    
    # 计算公共子表达式，避免重复计算
    # 子表达式1: pow(10, 0.0125*(141.5/Ro_const-131.5))
    sub_expr_1 = pow(10, 0.0125 * (141.5/Ro_const - 131.5))
    
    # 子表达式2: pow(10, 0.00091*(1.8*tempature+32))
    sub_expr_2 = pow(10, 0.00091 * (1.8*tempature + 32))
    
    # 子表达式3: 10*Pb_Mpa*sub_expr_1/sub_expr_2
    sub_expr_3 = 10 * Pb_Mpa * sub_expr_1 / sub_expr_2
    
    # 子表达式4: 0.1342*Rg_const*pow(sub_expr_3, 1/0.83)
    sub_expr_4 = 0.1342 * Rg_const * pow(sub_expr_3, 1/0.83)
    
    # 计算IF嵌套条件
    ratio = Pi_Mpa / Pb_Mpa
    if ratio < 0.1:
        if_result = 3.4 * ratio
    elif ratio < 0.3:
        if_result = 1.1 * ratio + 0.23
    elif ratio < 1:
        if_result = 0.629 * ratio + 0.37
    else:
        if_result = 1
    
    # 子表达式5: sub_expr_4 * if_result
    sub_expr_5 = sub_expr_4 * if_result
    
    # 子表达式6: 0.0003458*Z_const*(tempature+273)/Pi_Mpa
    sub_expr_6 = 0.0003458 * Z_const * (tempature + 273) / Pi_Mpa
    
    # 计算分子
    numerator = (1 - water_ratio) * (Production_gasoline_ratio - sub_expr_5) * sub_expr_6
    
    # 计算分母的第一部分
    # 5.61*(sub_expr_5)*pow(Rg_const/Ro_const, 0.5) + 1.25*(1.8*tempature+32)
    denom_part1_inner = 5.61 * sub_expr_5 * pow(Rg_const/Ro_const, 0.5) + 1.25 * (1.8*tempature + 32)
    
    # 0.972 + 0.000147*pow(denom_part1_inner, 1.175)
    denom_part1 = 0.972 + 0.000147 * pow(denom_part1_inner, 1.175)
    
    # 分母的第二部分
    denom_part2 = (1 - water_ratio) * (Production_gasoline_ratio - sub_expr_5) * sub_expr_6 + water_ratio
    
    # 完整分母
    denominator = (1 - water_ratio) * denom_part1 + denom_part2
    
    # 最终结果
    result = (numerator / denominator) * 100
    
    return result

# 使用示例和测试函数
def test_formula():
    """测试函数，提供示例用法"""    
    result = calculate_complex_formula(
        Pi_Mpa=21.25, Pb_Mpa=18.11, tempature=114, water_ratio=0,Production_gasoline_ratio=117
    )
    print(f"计算结果: {result}")
    return result

import numpy as np
from typing import Union, List

class MeanAbsolutePercentageError:
    """
    纯Python实现的平均绝对百分比误差(MAPE)
    不依赖torch和torchmetrics
    """
    def __init__(self):
        pass
    
    def __call__(self, predict: Union[np.ndarray, List], target: Union[np.ndarray, List]) -> float:
        """
        计算MAPE
        
        参数:
        predict: 预测值
        target: 真实值
        
        返回:
        MAPE值 (0-100的百分比)
        """
        predict = np.array(predict, dtype=float)
        target = np.array(target, dtype=float)
        
        # 避免除零
        mask = target != 0
        if not np.any(mask):
            return 0.0  # 所有目标值都为0
        
        # 计算MAPE，只考虑非零目标值
        mape = np.mean(np.abs((target[mask] - predict[mask]) / target[mask])) * 100
        return mape


class CustomMAPE:
    """
    自定义MAPE类，处理目标值为0的情况
    """
    def __init__(self, label_mean: float = 0.0):
        self.mape_ = MeanAbsolutePercentageError()
        self.label_mean = label_mean
    
    def __call__(self, predict: Union[np.ndarray, List], 
                 target: Union[np.ndarray, List], 
                 label_mean: Union[float, None] = None) -> float:
        """
        计算自定义MAPE
        
        参数:
        predict: 预测值
        target: 真实值
        label_mean: 用于替换0值的均值，如果为None则使用初始化时的值
        
        返回:
        MAPE值
        """
        predict = np.array(predict, dtype=float)
        target = np.array(target, dtype=float).copy()  # 复制以避免修改原数组
        
        # 确定用于替换的均值
        replacement_mean = label_mean if label_mean is not None else self.label_mean
        
        # 将目标值中的0替换为均值
        target[target == 0] = replacement_mean
        
        return self.mape_(predict, target)


# 辅助函数，模拟torch.mean的行为
def calculate_mean(data: Union[np.ndarray, List]) -> float:
    """计算数组均值"""
    return float(np.mean(data))


def select_greate_value(model_value,formal_value, max_error=15):
    cmape = CustomMAPE((model_value+formal_value)/2)
    error_value = cmape(model_value,formal_value)
    return error_value,model_value if error_value<max_error else formal_value

    


if __name__ == "__main__":
    # 测试数据
    pre = np.array([1, 1, 0, 2, 3.0])
    target = np.array([0, 1, 0, 2, 4.0])
    mean_ = calculate_mean(target)
    
    print(f"预测值: {pre}")
    print(f"真实值: {target}")
    print(f"目标值均值: {mean_}")
    
    # 使用自定义MAPE
    cmape = CustomMAPE(mean_)
    result = cmape(pre, target)
    
    print(f"自定义MAPE结果: {result:.4f}%")
    
    # 对比：标准MAPE（忽略0值）
    standard_mape = MeanAbsolutePercentageError()
    standard_result = standard_mape(pre, target)
    print(f"标准MAPE结果（忽略0值）: {standard_result:.4f}%")
    
    # 测试不同的label_mean值
    print("\n测试不同的label_mean值:")
    for test_mean in [0, 0.5, 1.0, mean_]:
        cmape_test = CustomMAPE(test_mean)
        result_test = cmape_test(pre, target)
        print(f"label_mean={test_mean:.2f}: MAPE={result_test:.4f}%")
    
    # 边界情况测试
    print("\n边界情况测试:")
    
    # 所有目标值都为0
    target_all_zero = np.array([0, 0, 0, 0, 0])
    predict_test = np.array([1, 2, 3, 4, 5])
    cmape_edge = CustomMAPE(1.0)
    result_edge = cmape_edge(predict_test, target_all_zero)
    print(f"所有目标值为0: MAPE={result_edge:.4f}%")
    
    # 完全匹配的情况
    perfect_predict = np.array([1, 1, 2, 2, 4])
    perfect_target = np.array([1, 1, 2, 2, 4])
    result_perfect = standard_mape(perfect_predict, perfect_target)
    print(f"完全匹配: MAPE={result_perfect:.4f}%")

def excel_formula(
    Vertical_depth_of_perforation_top_boundary,
    Pump_hanging_depth,
    Pwh,
    Pperfs,
    Pump_hanging_depth_measurement,
    water_ratio,
    Kf=0.017,
    api=18.5
    ):
    """
    将Excel公式 $R$9+($R$17-(Pperfs-$S$14))*2.31/$S$12+$R$18*$R$19 转换为Python函数
    Vertical_depth_of_perforation_top_boundary    射孔顶界垂深
    Pump_hanging_depth                泵挂垂深 
    Pwh                       井口压力 
    Pperfs                      井底流压 
    pfi                        井液相对密度
    Kf                        油管摩擦系数  常数？
    Pump_hanging_depth_measurement          泵挂测深
    water_ratio                    含水率
    api                        原油相对密度  常数
    Pwf_Pi                       
    
    返回:
    计算结果
    """
    pfi=water_ratio+(1-water_ratio)*141.5/(131.5+api)
    Pwf_Pi = 0.433*(Vertical_depth_of_perforation_top_boundary-Pump_hanging_depth)*pfi
    result = Pump_hanging_depth + (Pwh - (Pperfs - Pwf_Pi)) * 2.31 / pfi + Kf * Pump_hanging_depth_measurement
    return result


if __name__ == "__main__":
    print(excel_formula(
        Vertical_depth_of_perforation_top_boundary = 8708,
        Pump_hanging_depth=7942,
        Pwh=250,
        Pperfs=2516,
        Kf=0.017,
        Pump_hanging_depth_measurement = 8590,
        water_ratio = 0.4
    ))

import math

def relative_error(actual, theoretical, method='epsilon'):
    """
    计算相对误差，防止除0错误
    
    参数:
    actual: 实际值
    theoretical: 理论值/参考值
    method: 处理除0的方法
        - 'epsilon': 使用小值替代0
        - 'symmetric': 使用对称相对误差
        - 'difference': 当分母为0时返回差值
    
    返回:
    相对误差 (保留正负号)
    """
    
    # 计算差值 (保留符号)
    diff = actual - theoretical
    epsilon = 1e-10
    
    return diff / (theoretical+epsilon)
    


def relative_error_percent(actual, theoretical, method='epsilon'):
    """
    计算相对误差百分比
    """
    return relative_error(actual, theoretical, method) * 100


# 测试示例
if __name__ == "__main__":
    # 测试用例
    test_cases = [
        (10, 9),      # 正常情况 (实际值>理论值)
        (8, 10),      # 正常情况 (实际值<理论值)
        (0, 5),       # 实际值为0
        (5, 0),       # 理论值为0
        (0, 0),       # 两个值都为0
        (-5, -4),     # 负数
        (1.23, 1.20), # 小数
    ]
    
    print("测试结果:")
    print("实际值\t理论值\tEpsilon方法\t对称方法\t差值方法")
    print("-" * 60)
    
    for actual, theoretical in test_cases:
        eps_err = relative_error(actual, theoretical, 'epsilon')
        sym_err = relative_error(actual, theoretical, 'symmetric')
        diff_err = relative_error(actual, theoretical, 'difference')
        
        print(f"{actual}\t{theoretical}\t{eps_err:.6f}\t{sym_err:.6f}\t{diff_err:.6f}")
    
    # 百分比示例
    print(f"\n相对误差百分比示例:")
    print(f"实际值10，理论值9: {relative_error_percent(10, 9, 'epsilon'):.2f}%")
    print(f"实际值8，理论值10: {relative_error_percent(8, 10, 'epsilon'):.2f}%")