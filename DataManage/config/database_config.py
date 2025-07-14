# database_config.py
"""
数据库配置文件
用于管理数据库连接参数、缓存设置等
"""

import os
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class DatabaseConfig:
    """数据库配置类"""
    # 数据库文件路径
    db_path: str = "data/oil_analysis.db"

    # 连接超时设置 (秒)
    connection_timeout: int = 30

    # 缓存设置
    cache_enabled: bool = True
    cache_timeout: int = 300  # 5分钟
    max_cache_size: int = 1000  # 最大缓存条目数

    # SQLite 优化参数
    journal_mode: str = "WAL"  # Write-Ahead Logging
    synchronous: str = "NORMAL"  # 同步模式
    cache_size: int = 10000  # 页面缓存大小
    temp_store: str = "MEMORY"  # 临时存储在内存中

    # 连接池设置
    max_connections: int = 10
    min_connections: int = 2

    # 批处理设置
    batch_size: int = 1000

    # 日志级别
    log_level: str = "INFO"

    # 备份设置
    backup_enabled: bool = True
    backup_interval: int = 3600  # 1小时
    backup_path: str = "backups/"
    max_backup_files: int = 10

    def __post_init__(self):
        """配置初始化后的处理"""
        # 确保数据库目录存在
        db_dir = os.path.dirname(self.db_path)
        if db_dir and not os.path.exists(db_dir):
            os.makedirs(db_dir, exist_ok=True)

        # 确保备份目录存在
        if self.backup_enabled and not os.path.exists(self.backup_path):
            os.makedirs(self.backup_path, exist_ok=True)

    def get_sqlite_pragmas(self) -> Dict[str, Any]:
        """获取SQLite PRAGMA设置"""
        return {
            'journal_mode': self.journal_mode,
            'synchronous': self.synchronous,
            'cache_size': self.cache_size,
            'temp_store': self.temp_store,
            'foreign_keys': 'ON',
            'auto_vacuum': 'INCREMENTAL',
            'page_size': 4096,
            'mmap_size': 268435456,  # 256MB
        }

# 默认配置实例
DEFAULT_CONFIG = DatabaseConfig()

# 生产环境配置
PRODUCTION_CONFIG = DatabaseConfig(
    db_path="production/oil_analysis.db",
    cache_timeout=600,  # 10分钟
    max_cache_size=5000,
    cache_size=50000,
    max_connections=20,
    backup_interval=1800,  # 30分钟
    log_level="WARNING"
)

# 开发环境配置
DEVELOPMENT_CONFIG = DatabaseConfig(
    db_path="dev/oil_analysis.db",
    cache_timeout=60,  # 1分钟
    max_cache_size=100,
    backup_enabled=False,
    log_level="DEBUG"
)

# 测试环境配置
TEST_CONFIG = DatabaseConfig(
    db_path=":memory:",  # 内存数据库
    cache_enabled=False,
    backup_enabled=False,
    log_level="ERROR"
)

def get_config(environment: str = "default") -> DatabaseConfig:
    """根据环境获取配置"""
    configs = {
        "default": DEFAULT_CONFIG,
        "production": PRODUCTION_CONFIG,
        "development": DEVELOPMENT_CONFIG,
        "test": TEST_CONFIG
    }

    return configs.get(environment.lower(), DEFAULT_CONFIG)

# 从环境变量获取配置
def get_config_from_env() -> DatabaseConfig:
    """从环境变量获取配置"""
    return DatabaseConfig(
        db_path=os.getenv("DB_PATH", DEFAULT_CONFIG.db_path),
        connection_timeout=int(os.getenv("DB_TIMEOUT", DEFAULT_CONFIG.connection_timeout)),
        cache_enabled=os.getenv("CACHE_ENABLED", "true").lower() == "true",
        cache_timeout=int(os.getenv("CACHE_TIMEOUT", DEFAULT_CONFIG.cache_timeout)),
        max_cache_size=int(os.getenv("MAX_CACHE_SIZE", DEFAULT_CONFIG.max_cache_size)),
        journal_mode=os.getenv("JOURNAL_MODE", DEFAULT_CONFIG.journal_mode),
        synchronous=os.getenv("SYNCHRONOUS", DEFAULT_CONFIG.synchronous),
        cache_size=int(os.getenv("CACHE_SIZE", DEFAULT_CONFIG.cache_size)),
        max_connections=int(os.getenv("MAX_CONNECTIONS", DEFAULT_CONFIG.max_connections)),
        batch_size=int(os.getenv("BATCH_SIZE", DEFAULT_CONFIG.batch_size)),
        log_level=os.getenv("LOG_LEVEL", DEFAULT_CONFIG.log_level),
        backup_enabled=os.getenv("BACKUP_ENABLED", "true").lower() == "true",
        backup_interval=int(os.getenv("BACKUP_INTERVAL", DEFAULT_CONFIG.backup_interval)),
        backup_path=os.getenv("BACKUP_PATH", DEFAULT_CONFIG.backup_path),
        max_backup_files=int(os.getenv("MAX_BACKUP_FILES", DEFAULT_CONFIG.max_backup_files))
    )
