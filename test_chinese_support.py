#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试中文列名支持
"""
import pandas as pd
import tempfile
import os
from DataManage.DataManage import DatabaseManager

def test_chinese_column_support():
    """测试中文列名支持"""
    
    # 创建测试数据，包含中文列名
    test_data = {
        '井深': [1000, 1500, 2000, 2500],
        '产量': [100, 150, 200, 180],
        '压力': [150, 200, 250, 220],
        '温度': [60, 70, 80, 75],
        '含水率': [0.1, 0.2, 0.15, 0.25],
        'index': [1, 2, 3, 4]  # 添加index列，这可能是导致错误的原因
    }
    
    df = pd.DataFrame(test_data)
    
    print("原始数据:")
    print(df)
    print("\n列名:", df.columns.tolist())
    
    # 创建临时数据库
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as tmp_file:
        db_path = tmp_file.name
    
    try:
        # 初始化数据库管理器
        db_manager = DatabaseManager(db_path)
        
        # 测试表名
        table_name = "测试表_中文列名"
        
        # 创建表
        columns = df.columns.tolist()
        col_defs = ', '.join([f'"{col}" TEXT' for col in columns])
        create_sql = f'CREATE TABLE IF NOT EXISTS "{table_name}" ({col_defs})'
        
        print(f"\n创建表SQL: {create_sql}")
        
        try:
            db_manager.execute_custom_query(create_sql)
            print("✓ 创建表成功")
        except Exception as e:
            print(f"✗ 创建表失败: {e}")
            return False
        
        # 插入数据
        data_list = df.to_dict(orient='records')
        print(f"\n要插入的数据: {data_list[:2]}...")  # 只打印前两条
        
        try:
            db_manager.batch_insert(table_name, data_list)
            print("✓ 插入数据成功")
        except Exception as e:
            print(f"✗ 插入数据失败: {e}")
            return False
        
        # 查询数据
        try:
            rows = db_manager.execute_custom_query(f'SELECT * FROM "{table_name}"')
            print(f"✓ 查询数据成功，共 {len(rows)} 行")
            
            if rows:
                print("查询结果（前2行）:")
                for i, row in enumerate(rows[:2]):
                    print(f"  行{i+1}: {dict(row)}")
        except Exception as e:
            print(f"✗ 查询数据失败: {e}")
            return False
        
        # 获取表结构
        try:
            result = db_manager.execute_custom_query(f'PRAGMA table_info("{table_name}")')
            print(f"✓ 获取表结构成功")
            print("表结构:")
            for col_info in result:
                print(f"  {col_info['name']} ({col_info['type']})")
        except Exception as e:
            print(f"✗ 获取表结构失败: {e}")
            return False
        
        print("\n✓ 所有测试通过！中文列名支持正常")
        return True
        
    except Exception as e:
        print(f"✗ 测试失败: {e}")
        return False
    
    finally:
        # 清理临时文件
        try:
            os.unlink(db_path)
        except:
            pass

if __name__ == "__main__":
    test_chinese_column_support()
