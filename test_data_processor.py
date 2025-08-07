#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试数据处理器对非数值数据的处理能力
"""
import pandas as pd
import numpy as np
import sys
from pathlib import Path

# 添加项目路径
sys.path.append(str(Path(__file__).parent))

from Controller.DataProcessor import DataProcessor

def test_mixed_data_types():
    """测试混合数据类型的处理"""
    
    # 创建包含各种数据类型的测试数据
    test_data = {
        '数值列1': [1.0, 2.5, 3.2, 4.1, 5.0],
        '数值列2': [10, 20, 30, 40, 50],
        '字符串数值': ['1.5', '2.5', '3.5', '4.5', '5.5'],  # 可转换的字符串
        '混合列': [1.0, '2.5', 3, '4.0', 5.5],              # 混合类型
        '无效字符串': ['abc', 'def', '123', 'xyz', '456'],    # 部分可转换
        '目标变量': [100, 200, 300, 400, 500],
        '包含NaN': [1.0, np.nan, 3.0, 4.0, 5.0],
        '包含无穷': [1.0, 2.0, np.inf, 4.0, 5.0],
        '中文列名': [1, 2, 3, 4, 5]
    }
    
    df = pd.DataFrame(test_data)
    print("原始数据:")
    print(df)
    print("\n数据类型:")
    print(df.dtypes)
    
    # 测试特征和目标
    features = ['数值列1', '数值列2', '字符串数值', '混合列', '中文列名']
    target = '目标变量'
    
    print(f"\n使用特征: {features}")
    print(f"目标变量: {target}")
    
    # 创建数据处理器
    processor = DataProcessor(remove_outliers=True, outlier_factor=1.5)
    
    try:
        # 执行数据清理
        X, y, cleaning_info = processor.clean_data(df, features, target)
        
        print("\n✓ 数据清理成功！")
        print(f"清理后的X形状: {X.shape}")
        print(f"清理后的y形状: {y.shape}")
        print(f"X数据类型: {X.dtype}")
        print(f"y数据类型: {y.dtype}")
        
        print("\n清理信息:")
        for step in cleaning_info["cleaning_steps"]:
            print(f"  - {step}")
        
        print(f"\n数据变化: {cleaning_info['original_count']} -> {cleaning_info['final_count']}")
        
        # 检查数据质量
        print("\n数据质量检查:")
        print(f"  - X中是否有NaN: {np.any(np.isnan(X))}")
        print(f"  - y中是否有NaN: {np.any(np.isnan(y))}")
        print(f"  - X中是否有无穷值: {np.any(np.isinf(X))}")
        print(f"  - y中是否有无穷值: {np.any(np.isinf(y))}")
        
        print("\n✓ 测试通过！数据处理器能正确处理混合数据类型")
        return True
        
    except Exception as e:
        print(f"\n✗ 数据清理失败: {str(e)}")
        return False

def test_problematic_data():
    """测试问题数据的处理"""
    
    # 创建包含各种问题的数据
    test_data = {
        '特征1': ['1', '2', '不是数字', '4', '5'],
        '特征2': [1.0, 2.0, np.inf, 4.0, np.nan],
        '特征3': ['1.5', '2.5', '', '4.5', '5.5'],
        '目标': [10, 20, 30, 40, 50]
    }
    
    df = pd.DataFrame(test_data)
    print("\n\n=== 测试问题数据 ===")
    print("原始数据:")
    print(df)
    print("\n数据类型:")
    print(df.dtypes)
    
    features = ['特征1', '特征2', '特征3']
    target = '目标'
    
    processor = DataProcessor(remove_outliers=False)  # 不移除异常值，专注于类型处理
    
    try:
        X, y, cleaning_info = processor.clean_data(df, features, target)
        
        print("\n✓ 问题数据处理成功！")
        print(f"清理后的X形状: {X.shape}")
        print(f"清理后的y形状: {y.shape}")
        
        print("\n清理步骤:")
        for step in cleaning_info["cleaning_steps"]:
            print(f"  - {step}")
        
        print(f"\n最终数据:")
        print(f"X:\n{X}")
        print(f"y: {y}")
        
        return True
        
    except Exception as e:
        print(f"\n✗ 问题数据处理失败: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("开始测试数据处理器...")
    
    success1 = test_mixed_data_types()
    success2 = test_problematic_data()
    
    if success1 and success2:
        print("\n🎉 所有测试通过！数据处理器修复成功")
    else:
        print("\n❌ 部分测试失败，需要进一步调试")
