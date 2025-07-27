#!/usr/bin/env python3
"""
修复现有GLR模型的多项式变换器
为现有的GLR模型添加缺失的多项式变换器文件
"""

import joblib
import numpy as np
from pathlib import Path
from sklearn.preprocessing import PolynomialFeatures

def fix_glr_model():
    """为现有的GLR模型添加多项式变换器"""
    
    # GLR模型路径
    model_dir = Path("GLRsave/GLR-SVR-20250728_032003")
    
    if not model_dir.exists():
        print(f"模型目录不存在: {model_dir}")
        return False
    
    # 检查是否已经有多项式变换器文件
    poly_path = model_dir / "GLR-Poly.pkl"
    if poly_path.exists():
        print(f"多项式变换器文件已存在: {poly_path}")
        return True
    
    print(f"为GLR模型创建多项式变换器: {model_dir}")
    
    try:
        # 创建多项式变换器（与训练时使用的参数相同）
        poly = PolynomialFeatures(degree=2, include_bias=False)
        
        # 创建一个虚拟的9维输入数据来拟合变换器
        # 这样可以确保变换器知道输入特征的数量
        dummy_data = np.random.random((10, 9))  # 10个样本，9个特征
        poly.fit(dummy_data)
        
        # 保存多项式变换器
        joblib.dump(poly, poly_path)
        
        print(f"多项式变换器已保存到: {poly_path}")
        
        # 验证变换器工作正常
        test_input = np.random.random((1, 9))
        transformed = poly.transform(test_input)
        print(f"测试变换: {test_input.shape} -> {transformed.shape}")
        
        return True
        
    except Exception as e:
        print(f"创建多项式变换器失败: {e}")
        return False

if __name__ == "__main__":
    success = fix_glr_model()
    if success:
        print("GLR模型修复完成！")
    else:
        print("GLR模型修复失败！")
