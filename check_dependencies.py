#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查和安装持续学习模块所需的依赖包
Check and install dependencies for Continuous Learning Module
"""

import subprocess
import sys
import os

def check_and_install_package(package_name, import_name=None):
    """检查包是否已安装，如果没有则安装"""
    if import_name is None:
        import_name = package_name
    
    try:
        __import__(import_name)
        print(f"✅ {package_name} 已安装")
        return True
    except ImportError:
        print(f"❌ {package_name} 未安装，正在安装...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", package_name])
            print(f"✅ {package_name} 安装成功")
            return True
        except subprocess.CalledProcessError:
            print(f"❌ {package_name} 安装失败")
            return False

def main():
    """主函数"""
    print("🔍 检查持续学习模块依赖...")
    
    required_packages = [
        ("pandas", "pandas"),
        ("numpy", "numpy"),
        ("scikit-learn", "sklearn"),
        ("matplotlib", "matplotlib"),
        ("joblib", "joblib"),
        ("PySide6", "PySide6"),
    ]
    
    all_installed = True
    
    for package_name, import_name in required_packages:
        if not check_and_install_package(package_name, import_name):
            all_installed = False
    
    # sqlite3 是 Python 内置模块
    try:
        import sqlite3
        print("✅ sqlite3 (内置模块) 可用")
    except ImportError:
        print("❌ sqlite3 不可用")
        all_installed = False
    
    if all_installed:
        print("\n🎉 所有依赖包检查完成！")
        print("📋 可以正常使用持续学习模块的所有功能")
    else:
        print("\n⚠️  某些依赖包安装失败")
        print("📝 请手动执行: pip install pandas numpy scikit-learn matplotlib joblib")
    
    return all_installed

if __name__ == "__main__":
    success = main()
    if not success:
        sys.exit(1)
