#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
诊断数据加载问题 - 检查是否把表头当作数据处理了
"""
import pandas as pd
import numpy as np
import sys
from pathlib import Path

# 添加项目路径
sys.path.append(str(Path(__file__).parent))

from DataManage.DataManage import DatabaseManager

def diagnose_data_loading_issue():
    """诊断数据加载问题"""
    
    print("=== 诊断数据加载问题 ===\n")
    
    # 1. 创建测试Excel文件
    test_excel_path = "test_data_with_headers.xlsx"
    
    # 创建包含中文表头的测试数据
    test_data = {
        '井深': [1000, 1500, 2000, 2500, 3000],
        '产量': [100, 150, 200, 180, 220],
        '压力': [150, 200, 250, 220, 280],
        '温度': [60, 70, 80, 75, 85],
        '含水率': [0.1, 0.2, 0.15, 0.25, 0.18]
    }
    
    df_original = pd.DataFrame(test_data)
    df_original.to_excel(test_excel_path, index=False)
    
    print("1. 创建测试Excel文件")
    print(f"原始数据（应该有表头）:")
    print(df_original)
    print(f"列名: {df_original.columns.tolist()}")
    print(f"数据类型: {df_original.dtypes.to_dict()}")
    print()
    
    # 2. 模拟文件上传过程
    print("2. 模拟文件上传过程")
    
    # 读取Excel文件（模拟上传）
    df_loaded = pd.read_excel(test_excel_path)
    print(f"从Excel加载的数据:")
    print(df_loaded)
    print(f"列名: {df_loaded.columns.tolist()}")
    print(f"数据类型: {df_loaded.dtypes.to_dict()}")
    print()
    
    # 3. 模拟数据库存储
    print("3. 模拟数据库存储")
    
    # 创建临时数据库
    import tempfile
    import os
    
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as tmp_file:
        db_path = tmp_file.name
    
    try:
        db_manager = DatabaseManager(db_path)
        
        # 创建表
        table_name = "test_table"
        columns = df_loaded.columns.tolist()
        col_defs = ', '.join([f'"{col}" TEXT' for col in columns])
        create_sql = f'CREATE TABLE IF NOT EXISTS "{table_name}" ({col_defs})'
        
        print(f"创建表SQL: {create_sql}")
        db_manager.execute_custom_query(create_sql)
        
        # 插入数据
        data_list = df_loaded.to_dict(orient='records')
        print(f"要插入的数据（前2条）:")
        for i, record in enumerate(data_list[:2]):
            print(f"  记录{i+1}: {record}")
        
        db_manager.batch_insert(table_name, data_list)
        print(f"✓ 数据插入成功")
        print()
        
        # 4. 从数据库读取数据
        print("4. 从数据库读取数据")
        
        rows = db_manager.execute_custom_query(f'SELECT * FROM "{table_name}"')
        df_from_db = pd.DataFrame(rows)
        
        print(f"从数据库读取的数据:")
        print(df_from_db)
        print(f"列名: {df_from_db.columns.tolist()}")
        print(f"数据类型: {df_from_db.dtypes.to_dict()}")
        print()
        
        # 5. 检查数据内容
        print("5. 数据内容分析")
        
        for col in df_from_db.columns:
            print(f"列 '{col}':")
            values = df_from_db[col].tolist()
            print(f"  值: {values}")
            print(f"  类型: {[type(v).__name__ for v in values]}")
            
            # 尝试转换为数值
            try:
                numeric_values = pd.to_numeric(df_from_db[col], errors='coerce')
                nan_count = numeric_values.isna().sum()
                print(f"  转换为数值后NaN数量: {nan_count}")
                if nan_count > 0:
                    non_numeric = df_from_db[col][numeric_values.isna()].tolist()
                    print(f"  无法转换的值: {non_numeric}")
            except Exception as e:
                print(f"  数值转换失败: {e}")
            print()
        
        # 6. 检查是否有表头混入数据的问题
        print("6. 检查表头混入问题")
        
        # 检查第一行是否是表头
        first_row = df_from_db.iloc[0] if len(df_from_db) > 0 else None
        if first_row is not None:
            print(f"第一行数据: {first_row.to_dict()}")
            
            # 检查是否包含列名
            column_names = df_from_db.columns.tolist()
            first_row_values = [str(v) for v in first_row.tolist()]
            
            header_in_data = any(col_name in first_row_values for col_name in column_names)
            if header_in_data:
                print("❌ 发现问题：第一行数据包含列名，可能是表头被当作数据处理了！")
            else:
                print("✓ 第一行数据正常，不包含列名")
        
        # 7. 模拟数据处理过程
        print("\n7. 模拟数据处理过程")
        
        features = ['井深', '产量', '压力', '温度']
        target = '含水率'
        
        try:
            # 检查所需列是否存在
            required_cols = features + [target]
            missing_cols = [col for col in required_cols if col not in df_from_db.columns]
            if missing_cols:
                print(f"❌ 缺少列: {missing_cols}")
                return
            
            # 提取特征和目标数据
            feature_data = df_from_db[features]
            target_data = df_from_db[target]
            
            print(f"特征数据:")
            print(feature_data)
            print(f"目标数据:")
            print(target_data)
            
            # 尝试转换为数值类型
            print(f"\n尝试数值转换:")
            for col in features:
                try:
                    numeric_col = pd.to_numeric(feature_data[col], errors='coerce')
                    nan_count = numeric_col.isna().sum()
                    print(f"  {col}: {nan_count} 个NaN值")
                    if nan_count > 0:
                        problematic_values = feature_data[col][numeric_col.isna()].tolist()
                        print(f"    问题值: {problematic_values}")
                except Exception as e:
                    print(f"  {col}: 转换失败 - {e}")
            
            # 检查目标变量
            try:
                numeric_target = pd.to_numeric(target_data, errors='coerce')
                nan_count = numeric_target.isna().sum()
                print(f"  {target}: {nan_count} 个NaN值")
                if nan_count > 0:
                    problematic_values = target_data[numeric_target.isna()].tolist()
                    print(f"    问题值: {problematic_values}")
            except Exception as e:
                print(f"  {target}: 转换失败 - {e}")
                
        except Exception as e:
            print(f"❌ 数据处理失败: {e}")
            import traceback
            traceback.print_exc()
    
    except Exception as e:
        print(f"❌ 诊断过程失败: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        # 清理文件
        try:
            os.unlink(db_path)
            os.unlink(test_excel_path)
        except:
            pass

if __name__ == "__main__":
    diagnose_data_loading_issue()
