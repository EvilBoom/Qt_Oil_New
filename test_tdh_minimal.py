#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TDH模型测试 - 极简版

最简单的TDH模型测试工具：
1. 加载模型
2. 手动输入数据
3. 获取预测值

使用方法:
1. 修改MODEL_FOLDER为您的模型文件夹名称
2. 运行脚本
"""

import sys
from pathlib import Path
import numpy as np

# 添加项目路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from models.model import TDHPredictor, SVRInput


class SimpleTDHTester:
    """极简TDH测试器"""
    
    def __init__(self, model_folder_name):
        self.project_root = Path(__file__).parent
        self.model_path = self.project_root / "TDHsave" / model_folder_name
        self.predictor = None
        
    def load_model(self):
        """加载模型"""
        if not self.model_path.exists():
            raise FileNotFoundError(f"模型路径不存在: {self.model_path}")
        
        print(f"加载模型: {self.model_path.name}")
        self.predictor = TDHPredictor([], [])
        
        if self.predictor.load_model(str(self.model_path)):
            print("✅ 模型加载成功!")
            return True
        else:
            print("❌ 模型加载失败!")
            return False
    
    def predict_single(self, test_input):
        """
        单个预测
        
        Args:
            test_input: SVRInput实例或11个数值的列表
            
        Returns:
            float: 预测的TDH值
        """
        if self.predictor is None:
            raise RuntimeError("请先加载模型")
        
        # 处理输入数据
        if hasattr(test_input, 'to_list'):
            # SVRInput实例
            features = np.array(test_input.to_list()).reshape(1, -1)
        else:
            # 数值列表
            features = np.array(test_input).reshape(1, -1)
        
        # 预测
        print(f"预测输入特征: {features}")
        prediction = self.predictor._predict_batch(features)[0]
        return float(prediction)
    
    def predict_batch(self, test_inputs):
        """
        批量预测
        
        Args:
            test_inputs: SVRInput实例列表或二维数值数组
            
        Returns:
            list: 预测的TDH值列表
        """
        if self.predictor is None:
            raise RuntimeError("请先加载模型")
        
        # 处理输入数据
        if isinstance(test_inputs, list) and hasattr(test_inputs[0], 'to_list'):
            # SVRInput实例列表
            features = np.array([item.to_list() for item in test_inputs])
        else:
            # 数值数组
            features = np.array(test_inputs)
        
        # 预测
        predictions = self.predictor._predict_batch(features)
        return predictions.tolist()


def quick_predict(model_folder, phdm, freq, pr, ip, bht, qf, bsw, api, gor, pb, whp):
    """
    快速预测函数 - 直接传入参数
    
    Args:
        model_folder: 模型文件夹名称
        phdm: 射孔垂深
        freq: 泵挂垂深
        pr: 油藏压力PR
        ip: 生产指数IP
        bht: 井底温度BHT
        qf: 期望产量QF
        bsw: 含水率BSW
        api: 原油密度API
        gor: 油气比GOR
        pb: 泡点压力Pb
        whp: 井口压力WHP
        
    Returns:
        float: 预测的TDH值
    """
    tester = SimpleTDHTester(model_folder)
    if not tester.load_model():
        return None
    
    test_input = SVRInput(phdm=phdm, freq=freq, Pr=pr, IP=ip, BHT=bht, Qf=qf,
                         BSW=bsw, API=api, GOR=gor, Pb=pb, WHP=whp)
    
    return tester.predict_single(test_input)


def example_usage():
    """使用示例"""
    
    # 或者使用测试器类
    tester = SimpleTDHTester("D:\projects\Qt_Oil_New\TDHsave\TDH-20250803_204112")
    if tester.load_model():
        # 单个预测
        test_input = SVRInput(phdm=8843.96, freq=8878.9, Pr=3350.37, IP=0.62, BHT=210.02, 
                             Qf=1000, BSW=40, API=19.0, GOR=199.894, Pb=649.77, WHP=349.541)
        prediction = tester.predict_single(test_input)
        print(f"TDH预测值: {prediction:.2f}")
        
        test_input = SVRInput(phdm=9000, freq=9324, Pr=3033, IP=0.35, BHT=200, 
                             Qf=486, BSW=30, API=20.8, GOR=87.1, Pb=691, WHP=349.541)
        prediction = tester.predict_single(test_input)
        print(f"TDH预测值: {prediction:.2f}")


if __name__ == "__main__":
    example_usage()
