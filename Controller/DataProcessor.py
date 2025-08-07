"""
数据处理工具类 - 基于用户原有的数据处理逻辑
"""

import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler, MinMaxScaler
from sklearn.model_selection import train_test_split
from loguru import logger


class DataProcessor:
    """数据处理器，处理NaN值、异常值等数据质量问题"""
    
    def __init__(self, remove_outliers=True, outlier_factor=1.5):
        """
        初始化数据处理器
        
        参数:
            remove_outliers (bool): 是否移除异常值
            outlier_factor (float): IQR异常值因子
        """
        self.remove_outliers = remove_outliers
        self.outlier_factor = outlier_factor
        self.scaler = StandardScaler()
        
    def clean_data(self, df, features, target_label):
        """
        清理数据，处理缺失值和异常值
        
        参数:
            df (DataFrame): 原始数据
            features (list): 特征列名列表
            target_label (str): 目标变量列名
            
        返回:
            tuple: (X, y, cleaning_info) 清理后的特征和标签，以及清理信息
        """
        cleaning_info = {
            "original_count": len(df),
            "missing_values": {},
            "outliers_removed": 0,
            "final_count": 0,
            "cleaning_steps": []
        }
        
        try:
            # 1. 选择需要的列
            required_cols = features + [target_label]
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                raise ValueError(f"缺少字段: {missing_cols}")
            
            df_work = df[required_cols].copy()
            cleaning_info["cleaning_steps"].append(f"选择了 {len(required_cols)} 个需要的列")
            
            # 2. 处理无穷大值和非数值数据
            try:
                # 首先识别数值列
                numeric_cols = df_work.select_dtypes(include=[np.number]).columns
                
                if len(numeric_cols) > 0:
                    # 仅对数值列检查无穷大值
                    infinite_mask = np.isinf(df_work[numeric_cols])
                    if infinite_mask.any().any():
                        df_work[numeric_cols] = df_work[numeric_cols].replace([np.inf, -np.inf], np.nan)
                        cleaning_info["cleaning_steps"].append("将数值列中的无穷大值替换为NaN")
                
                # 对于非数值列，尝试转换为数值类型
                non_numeric_cols = [col for col in df_work.columns if col not in numeric_cols]
                if non_numeric_cols:
                    for col in non_numeric_cols:
                        try:
                            df_work[col] = pd.to_numeric(df_work[col], errors='coerce')
                            cleaning_info["cleaning_steps"].append(f"将列 {col} 转换为数值类型")
                        except Exception:
                            logger.warning(f"列 {col} 无法转换为数值类型")
                            
            except Exception as e:
                logger.warning(f"处理无穷大值时出现警告: {str(e)}")
                cleaning_info["cleaning_steps"].append("无穷大值处理过程中遇到问题，已跳过")
            
            # 3. 记录缺失值情况
            missing_values = df_work.isnull().sum()
            cleaning_info["missing_values"] = missing_values.to_dict()
            
            # 4. 删除包含NaN的行
            before_nan_removal = len(df_work)
            df_work = df_work.dropna()
            nan_removed = before_nan_removal - len(df_work)
            if nan_removed > 0:
                cleaning_info["cleaning_steps"].append(f"移除了 {nan_removed} 行包含NaN的数据")
            
            if len(df_work) == 0:
                raise ValueError("数据清理后没有有效数据")
            
            # 5. 确保数据类型正确，添加更强的类型转换
            try:
                # 首先尝试将数据转换为数值型，处理可能的字符串数据
                feature_data = df_work[features].copy()
                target_data = df_work[target_label].copy()
                
                # 处理特征数据
                for col in features:
                    if col in feature_data.columns:
                        # 尝试转换为数值型，如果失败则用 pandas.to_numeric 强制转换
                        try:
                            feature_data[col] = pd.to_numeric(feature_data[col], errors='coerce')
                        except Exception:
                            logger.warning(f"特征列 {col} 包含无法转换的数据，将使用 NaN 替代")
                            feature_data[col] = pd.to_numeric(feature_data[col], errors='coerce')
                
                # 处理目标数据
                try:
                    target_data = pd.to_numeric(target_data, errors='coerce')
                except Exception:
                    logger.warning(f"目标列 {target_label} 包含无法转换的数据，将使用 NaN 替代")
                    target_data = pd.to_numeric(target_data, errors='coerce')
                
                # 重新组合数据，移除转换后产生的 NaN
                df_work = pd.concat([feature_data, target_data], axis=1)
                df_work = df_work.dropna()
                
                if len(df_work) == 0:
                    raise ValueError("数据类型转换后没有有效数据")
                
                # 重新提取转换后的数据
                feature_data = df_work[features].astype(float)
                target_data = df_work[target_label].astype(float)
                
                cleaning_info["cleaning_steps"].append("完成数据类型转换和NaN清理")
                
            except (ValueError, TypeError) as e:
                raise ValueError(f"数据类型转换失败: {str(e)}")
            
            # 6. 移除异常值（如果启用）
            if self.remove_outliers and len(df_work) > 10:  # 至少需要10个样本才进行异常值检测
                before_outlier_removal = len(df_work)
                
                # 对目标变量使用分位数方法移除极端异常值
                target_q01 = target_data.quantile(0.01)
                target_q99 = target_data.quantile(0.99)
                target_mask = (target_data >= target_q01) & (target_data <= target_q99)
                
                # 对特征变量也进行异常值检测
                feature_mask = pd.Series([True] * len(df_work), index=df_work.index)
                for feature in features:
                    q01 = feature_data[feature].quantile(0.01)
                    q99 = feature_data[feature].quantile(0.99)
                    feature_mask &= (feature_data[feature] >= q01) & (feature_data[feature] <= q99)
                
                # 组合掩码
                final_mask = target_mask & feature_mask
                df_work = df_work[final_mask]
                
                outliers_removed = before_outlier_removal - len(df_work)
                cleaning_info["outliers_removed"] = outliers_removed
                
                if outliers_removed > 0:
                    cleaning_info["cleaning_steps"].append(f"移除了 {outliers_removed} 个异常值")
                
                # 如果移除了超过50%的数据，发出警告
                if outliers_removed > before_outlier_removal * 0.5:
                    logger.warning(f"异常值移除过多: {outliers_removed}/{before_outlier_removal}")
            
            # 7. 最终数据提取
            X = df_work[features].values
            y = df_work[target_label].values
            
            # 8. 最终数据验证 - 使用安全的检查方法
            try:
                # 确保数据为数值类型
                X = np.array(X, dtype=float)
                y = np.array(y, dtype=float)
                
                # 检查NaN值
                if np.any(np.isnan(X)) or np.any(np.isnan(y)):
                    raise ValueError("清理后的数据仍包含NaN值")
                    
                # 检查无穷大值
                if np.any(np.isinf(X)) or np.any(np.isinf(y)):
                    raise ValueError("清理后的数据仍包含无穷大值")
                    
            except (ValueError, TypeError) as e:
                raise ValueError(f"最终数据验证失败: {str(e)}")
                
            if len(X) == 0 or len(y) == 0:
                raise ValueError("清理后没有数据")
            
            cleaning_info["final_count"] = len(X)
            cleaning_info["cleaning_steps"].append(f"最终获得 {len(X)} 个有效样本")
            
            logger.info(f"数据清理完成: {cleaning_info['original_count']} -> {cleaning_info['final_count']} 个样本")
            
            return X, y, cleaning_info
            
        except Exception as e:
            logger.error(f"数据清理失败: {str(e)}")
            raise
    
    def prepare_data_for_training(self, df, features, target_label, test_size=0.2, random_state=42):
        """
        为训练准备数据，包括清理和分割
        
        参数:
            df (DataFrame): 原始数据
            features (list): 特征列名列表  
            target_label (str): 目标变量列名
            test_size (float): 测试集比例
            random_state (int): 随机种子
            
        返回:
            tuple: (X_train, X_test, y_train, y_test, cleaning_info)
        """
        # 清理数据
        X, y, cleaning_info = self.clean_data(df, features, target_label)
        
        # 分割数据
        if len(X) < 2:
            # 数据太少，不分割
            logger.warning("数据量太少，不进行训练/测试分割")
            return X, np.array([]), y, np.array([]), cleaning_info
        
        try:
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=test_size, random_state=random_state
            )
            
            cleaning_info["train_samples"] = len(X_train)
            cleaning_info["test_samples"] = len(X_test)
            
            logger.info(f"数据分割完成: 训练集 {len(X_train)} 个，测试集 {len(X_test)} 个样本")
            
            return X_train, X_test, y_train, y_test, cleaning_info
            
        except Exception as e:
            logger.error(f"数据分割失败: {str(e)}")
            # 如果分割失败，返回全部数据作为训练集
            return X, np.array([]), y, np.array([]), cleaning_info
    
    @staticmethod
    def remove_outliers_iqr(data, factor=1.5):
        """
        使用IQR方法移除异常值
        
        参数:
            data (Series): 数据
            factor (float): IQR因子
            
        返回:
            Series: 移除异常值后的数据掩码
        """
        Q1 = data.quantile(0.25)
        Q3 = data.quantile(0.75)
        IQR = Q3 - Q1
        lower_bound = Q1 - factor * IQR
        upper_bound = Q3 + factor * IQR
        return (data >= lower_bound) & (data <= upper_bound)
    
    def get_data_statistics(self, df, features, target_label):
        """
        获取数据统计信息
        
        参数:
            df (DataFrame): 数据
            features (list): 特征列
            target_label (str): 目标列
            
        返回:
            dict: 统计信息
        """
        stats = {
            "total_records": len(df),
            "features": {},
            "target": {}
        }
        
        # 特征统计
        for feature in features:
            if feature in df.columns:
                series = df[feature]
                stats["features"][feature] = {
                    "count": series.count(),
                    "mean": series.mean() if series.dtype in ['int64', 'float64'] else None,
                    "std": series.std() if series.dtype in ['int64', 'float64'] else None,
                    "min": series.min() if series.dtype in ['int64', 'float64'] else None,
                    "max": series.max() if series.dtype in ['int64', 'float64'] else None,
                    "missing": series.isnull().sum(),
                    "dtype": str(series.dtype)
                }
        
        # 目标变量统计
        if target_label in df.columns:
            target_series = df[target_label]
            stats["target"] = {
                "count": target_series.count(),
                "mean": target_series.mean() if target_series.dtype in ['int64', 'float64'] else None,
                "std": target_series.std() if target_series.dtype in ['int64', 'float64'] else None,
                "min": target_series.min() if target_series.dtype in ['int64', 'float64'] else None,
                "max": target_series.max() if target_series.dtype in ['int64', 'float64'] else None,
                "missing": target_series.isnull().sum(),
                "dtype": str(target_series.dtype)
            }
        
        return stats


if __name__ == "__main__":
    # 测试用例
    np.random.seed(42)
    
    # 创建测试数据
    n_samples = 100
    data = {
        'feature1': np.random.normal(10, 2, n_samples),
        'feature2': np.random.normal(5, 1, n_samples), 
        'target': np.random.normal(20, 3, n_samples)
    }
    
    # 添加一些缺失值和异常值
    data['feature1'][5:10] = np.nan
    data['feature2'][15] = 1000  # 异常值
    data['target'][20] = -1000   # 异常值
    
    df = pd.DataFrame(data)
    
    # 测试数据处理器
    processor = DataProcessor(remove_outliers=True)
    
    features = ['feature1', 'feature2']
    target = 'target'
    
    try:
        X_train, X_test, y_train, y_test, info = processor.prepare_data_for_training(
            df, features, target, test_size=0.2
        )
        
        print("数据处理成功!")
        print(f"训练集大小: {len(X_train)}")
        print(f"测试集大小: {len(X_test)}")
        print(f"清理信息: {info}")
        
    except Exception as e:
        print(f"数据处理失败: {e}")
