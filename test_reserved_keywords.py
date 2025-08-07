#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试包含 SQLite 保留关键字的列名支持
"""
import pandas as pd
import tempfile
import os
from DataManage.DataManage import DatabaseManager

def test_reserved_keywords_support():
    """测试 SQLite 保留关键字作为列名的支持"""
    
    # 创建包含常见 SQLite 保留关键字的测试数据
    test_data = {
        'index': [1, 2, 3, 4],      # SQLite 保留关键字
        'order': [100, 150, 200, 180],  # SQLite 保留关键字
        'group': [1, 2, 1, 2],      # SQLite 保留关键字
        'select': [10, 20, 30, 40], # SQLite 保留关键字
        '井深': [1000, 1500, 2000, 2500],
        '产量': [100, 150, 200, 180],
        'normal_column': ['A', 'B', 'C', 'D']
    }
    
    df = pd.DataFrame(test_data)
    
    print("测试数据（包含SQLite保留关键字）:")
    print(df)
    print("\n列名:", df.columns.tolist())
    
    # 创建临时数据库
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as tmp_file:
        db_path = tmp_file.name
    
    try:
        # 初始化数据库管理器
        db_manager = DatabaseManager(db_path)
        
        # 测试表名
        table_name = "测试保留关键字表"
        
        # 创建表 - 使用双引号包围所有列名
        columns = df.columns.tolist()
        col_defs = ', '.join([f'"{col}" TEXT' for col in columns])
        create_sql = f'CREATE TABLE IF NOT EXISTS "{table_name}" ({col_defs})'
        
        print(f"\n创建表SQL: {create_sql}")
        
        try:
            db_manager.execute_custom_query(create_sql)
            print("✓ 创建表成功（包含保留关键字列名）")
        except Exception as e:
            print(f"✗ 创建表失败: {e}")
            return False
        
        # 插入数据
        data_list = df.to_dict(orient='records')
        print(f"\n要插入的数据: {data_list[0]}")  # 只打印第一条
        
        try:
            db_manager.batch_insert(table_name, data_list)
            print("✓ 插入数据成功（包含保留关键字列名）")
        except Exception as e:
            print(f"✗ 插入数据失败: {e}")
            return False
        
        # 查询特定列（测试保留关键字列的查询）
        try:
            # 测试查询保留关键字列
            rows = db_manager.execute_custom_query(
                f'SELECT "index", "order", "井深", "产量" FROM "{table_name}" LIMIT 2'
            )
            print(f"✓ 查询保留关键字列成功，共 {len(rows)} 行")
            
            if rows:
                print("查询结果:")
                for i, row in enumerate(rows):
                    print(f"  行{i+1}: {dict(row)}")
        except Exception as e:
            print(f"✗ 查询保留关键字列失败: {e}")
            return False
        
        # 测试更新操作
        try:
            update_sql = f'UPDATE "{table_name}" SET "index" = 999 WHERE "order" = 100'
            db_manager.execute_custom_query(update_sql)
            print("✓ 更新保留关键字列成功")
        except Exception as e:
            print(f"✗ 更新保留关键字列失败: {e}")
            return False
        
        # 验证更新结果
        try:
            rows = db_manager.execute_custom_query(
                f'SELECT "index", "order" FROM "{table_name}" WHERE "order" = 100'
            )
            if rows and rows[0]['index'] == '999':
                print("✓ 更新结果验证成功")
            else:
                print("✗ 更新结果验证失败")
                return False
        except Exception as e:
            print(f"✗ 验证更新结果失败: {e}")
            return False
        
        print("\n✓ 所有测试通过！SQLite保留关键字作为列名支持正常")
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
    test_reserved_keywords_support()
