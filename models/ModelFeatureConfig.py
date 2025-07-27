"""
模型特征配置类
定义不同任务类型所需的输入特征
"""
from .svrQF import  QFInput
from .svrTDH import SVRInput as TDHInput
from .keraGLR import GLRInput

class ModelFeatureConfig:
    """模型特征配置管理类"""
    
    
    # 任务类型对应的期望特征
    TASK_FEATURES = {
        "head": TDHInput.get_features(),
        "production": QFInput.get_features(),
        "glr": GLRInput.get_features()
    }
    
    # 任务类型对应的目标变量
    TASK_TARGETS = {
        "head": ["TDH", "Head", "扬程"],
        "production": ["QF", "Production", "产量"],
        "glr": ["GLR", "GasLiquidRatio", "气液比"]
    }
    
    @classmethod
    def get_expected_features(cls, task_type: str) -> list:
        """
        获取指定任务类型的期望特征列表
        
        Args:
            task_type: 任务类型 ("head", "production", "glr")
            
        Returns:
            list: 期望特征列表
        """
        return cls.TASK_FEATURES.get(task_type, [])
    
    @classmethod
    def get_expected_targets(cls, task_type: str) -> list:
        """
        获取指定任务类型的可能目标变量
        
        Args:
            task_type: 任务类型 ("head", "production", "glr")
            
        Returns:
            list: 可能的目标变量列表
        """
        return cls.TASK_TARGETS.get(task_type, [])
    
    @classmethod
    def get_all_tasks(cls) -> list:
        """
        获取所有支持的任务类型
        
        Returns:
            list: 所有任务类型列表
        """
        return list(cls.TASK_FEATURES.keys())
    
    @classmethod
    def validate_feature_mapping(cls, task_type: str, feature_mapping: dict) -> tuple:
        """
        验证特征映射的完整性
        
        Args:
            task_type: 任务类型
            feature_mapping: 特征映射字典 {期望特征: 实际特征}
            
        Returns:
            tuple: (is_valid, missing_features, error_message)
        """
        expected_features = cls.get_expected_features(task_type)
        missing_features = []
        
        for expected_feature in expected_features:
            mapped_feature = feature_mapping.get(expected_feature, "")
            if not mapped_feature:
                missing_features.append(expected_feature)
        
        is_valid = len(missing_features) == 0
        error_message = ""
        
        if not is_valid:
            error_message = f"以下特征需要映射: {', '.join(missing_features)}"
        
        return is_valid, missing_features, error_message
