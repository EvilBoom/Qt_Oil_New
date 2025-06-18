import sqlite3
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
from contextlib import contextmanager
from dataclasses import dataclass, asdict
import threading

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class Project:
    """项目数据类"""
    project_name: str
    user_name: str
    company_name: Optional[str] = None
    well_name: Optional[str] = None
    oil_name: Optional[str] = None
    location: Optional[str] = None
    ps: Optional[str] = None
    id: Optional[int] = None

@dataclass
class WellData:
    """井数据类"""
    project_id: int
    well_md: Optional[float] = None
    well_tvd: Optional[float] = None
    well_dls: Optional[float] = None
    inner_diameter: Optional[float] = None
    outer_diameter: Optional[float] = None
    roughness: Optional[float] = None
    perforation_vertical_depth: Optional[float] = None
    pump_hanging_vertical_depth: Optional[float] = None
    id: Optional[int] = None

@dataclass
class ReservoirData:
    """油藏数据类"""
    project_id: int
    geo_produce_index: Optional[float] = None
    expected_production: Optional[float] = None
    saturation_pressure: Optional[float] = None
    geo_pressure: Optional[float] = None
    bht: Optional[float] = None
    bsw: Optional[float] = None
    api: Optional[float] = None
    gas_oil_ratio: Optional[float] = None
    well_head_pressure: Optional[float] = None
    id: Optional[int] = None

class DatabaseManager:
    """数据库管理器 - 单例模式，带连接池和缓存"""

    _instance = None
    _lock = threading.Lock()

    def __new__(cls, db_path: str = "oil_data.db"):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self, db_path: str = "oil_data.db"):
        if hasattr(self, 'initialized'):
            return

        self.db_path = db_path
        self.cache = {}
        self.cache_timeout = 300  # 5分钟缓存
        self.cache_timestamps = {}
        self._local = threading.local()
        self.initialized = True

        # 初始化数据库
        self._init_database()

    def _get_connection(self):
        """获取线程本地连接"""
        if not hasattr(self._local, 'connection'):
            self._local.connection = sqlite3.connect(
                self.db_path,
                check_same_thread=False,
                timeout=30
            )
            self._local.connection.row_factory = sqlite3.Row
            # 启用外键约束
            self._local.connection.execute("PRAGMA foreign_keys = ON")
            # 优化设置
            self._local.connection.execute("PRAGMA journal_mode = WAL")
            self._local.connection.execute("PRAGMA synchronous = NORMAL")
            self._local.connection.execute("PRAGMA cache_size = 10000")

        return self._local.connection

    @contextmanager
    def get_cursor(self):
        """上下文管理器获取游标"""
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            yield cursor
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"数据库操作错误: {e}")
            raise
        finally:
            cursor.close()

    def _init_database(self):
        """初始化数据库表结构"""
        # 这里会包含之前设计的所有表结构
        # 由于篇幅限制，这里只展示核心表
        init_sql = """
        -- 项目表
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_name VARCHAR(100) NOT NULL UNIQUE,
            user_name VARCHAR(50) NOT NULL,
            company_name VARCHAR(100),
            well_name VARCHAR(100),
            oil_name VARCHAR(50),
            location VARCHAR(200),
            ps TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- 井数据表
        CREATE TABLE IF NOT EXISTS wells (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            well_md REAL,
            well_tvd REAL,
            well_dls REAL,
            inner_diameter REAL,
            outer_diameter REAL,
            roughness REAL,
            perforation_vertical_depth REAL,
            pump_hanging_vertical_depth REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );

        -- 油藏数据表
        CREATE TABLE IF NOT EXISTS reservoir_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            geo_produce_index REAL,
            expected_production REAL,
            saturation_pressure REAL,
            geo_pressure REAL,
            bht REAL,
            bsw REAL,
            api REAL,
            gas_oil_ratio REAL,
            well_head_pressure REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );

        -- 创建索引
        CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(project_name);
        CREATE INDEX IF NOT EXISTS idx_wells_project ON wells(project_id);
        CREATE INDEX IF NOT EXISTS idx_reservoir_project ON reservoir_data(project_id);
        """

        with self.get_cursor() as cursor:
            cursor.executescript(init_sql)

    def _is_cache_valid(self, key: str) -> bool:
        """检查缓存是否有效"""
        if key not in self.cache_timestamps:
            return False
        return (datetime.now() - self.cache_timestamps[key]).seconds < self.cache_timeout

    def _set_cache(self, key: str, value: Any):
        """设置缓存"""
        self.cache[key] = value
        self.cache_timestamps[key] = datetime.now()

    def _get_cache(self, key: str) -> Optional[Any]:
        """获取缓存"""
        if self._is_cache_valid(key):
            return self.cache[key]
        else:
            # 清理过期缓存
            if key in self.cache:
                del self.cache[key]
            if key in self.cache_timestamps:
                del self.cache_timestamps[key]
            return None

    def clear_cache(self):
        """清空缓存"""
        self.cache.clear()
        self.cache_timestamps.clear()

    # 项目相关操作
    def create_project(self, project: Project) -> int:
        """创建项目"""
        data = asdict(project)
        data.pop('id', None)  # 移除id字段

        columns = ', '.join(data.keys())
        placeholders = ', '.join(['?' for _ in data])

        with self.get_cursor() as cursor:
            cursor.execute(
                f"INSERT INTO projects ({columns}) VALUES ({placeholders})",
                list(data.values())
            )
            project_id = cursor.lastrowid

        # 清除相关缓存
        self.cache.pop('all_projects', None)
        logger.info(f"创建项目成功: {project.project_name}, ID: {project_id}")
        return project_id

    def get_project_by_name(self, project_name: str) -> Optional[Dict]:
        """根据项目名获取项目"""
        cache_key = f"project_{project_name}"
        cached_result = self._get_cache(cache_key)
        if cached_result:
            return cached_result

        with self.get_cursor() as cursor:
            cursor.execute(
                "SELECT * FROM projects WHERE project_name = ?",
                (project_name,)
            )
            row = cursor.fetchone()

        result = dict(row) if row else None
        if result:
            self._set_cache(cache_key, result)

        return result

    def get_all_projects(self) -> List[Dict]:
        """获取所有项目"""
        cache_key = "all_projects"
        cached_result = self._get_cache(cache_key)
        if cached_result:
            return cached_result

        with self.get_cursor() as cursor:
            cursor.execute("SELECT * FROM projects ORDER BY created_at DESC")
            rows = cursor.fetchall()

        result = [dict(row) for row in rows]
        self._set_cache(cache_key, result)
        return result

    def update_project(self, project_id: int, updates: Dict) -> bool:
        """更新项目"""
        if not updates:
            return False

        updates['updated_at'] = datetime.now().isoformat()
        columns = ', '.join([f"{k} = ?" for k in updates.keys()])

        with self.get_cursor() as cursor:
            cursor.execute(
                f"UPDATE projects SET {columns} WHERE id = ?",
                list(updates.values()) + [project_id]
            )
            success = cursor.rowcount > 0

        if success:
            # 清除相关缓存
            self.clear_cache()
            logger.info(f"更新项目成功: ID {project_id}")

        return success

    def delete_project(self, project_id: int) -> bool:
        """删除项目（级联删除相关数据）"""
        with self.get_cursor() as cursor:
            cursor.execute("DELETE FROM projects WHERE id = ?", (project_id,))
            success = cursor.rowcount > 0

        if success:
            self.clear_cache()
            logger.info(f"删除项目成功: ID {project_id}")

        return success

    # 井数据相关操作
    def save_well_data(self, well_data: WellData) -> int:
        """保存井数据"""
        data = asdict(well_data)
        data.pop('id', None)

        # 检查是否已存在
        with self.get_cursor() as cursor:
            cursor.execute(
                "SELECT id FROM wells WHERE project_id = ?",
                (well_data.project_id,)
            )
            existing = cursor.fetchone()

        if existing:
            # 更新
            columns = ', '.join([f"{k} = ?" for k in data.keys() if k != 'project_id'])
            values = [v for k, v in data.items() if k != 'project_id']

            with self.get_cursor() as cursor:
                cursor.execute(
                    f"UPDATE wells SET {columns} WHERE project_id = ?",
                    values + [well_data.project_id]
                )
                return existing['id']
        else:
            # 插入
            columns = ', '.join(data.keys())
            placeholders = ', '.join(['?' for _ in data])

            with self.get_cursor() as cursor:
                cursor.execute(
                    f"INSERT INTO wells ({columns}) VALUES ({placeholders})",
                    list(data.values())
                )
                return cursor.lastrowid

    def get_well_data_by_project(self, project_id: int) -> Optional[Dict]:
        """根据项目ID获取井数据"""
        cache_key = f"well_data_{project_id}"
        cached_result = self._get_cache(cache_key)
        if cached_result:
            return cached_result

        with self.get_cursor() as cursor:
            cursor.execute(
                "SELECT * FROM wells WHERE project_id = ?",
                (project_id,)
            )
            row = cursor.fetchone()

        result = dict(row) if row else None
        if result:
            self._set_cache(cache_key, result)

        return result

    # 油藏数据相关操作
    def save_reservoir_data(self, reservoir_data: ReservoirData) -> int:
        """保存油藏数据"""
        data = asdict(reservoir_data)
        data.pop('id', None)

        # 检查是否已存在
        with self.get_cursor() as cursor:
            cursor.execute(
                "SELECT id FROM reservoir_data WHERE project_id = ?",
                (reservoir_data.project_id,)
            )
            existing = cursor.fetchone()

        if existing:
            # 更新
            columns = ', '.join([f"{k} = ?" for k in data.keys() if k != 'project_id'])
            values = [v for k, v in data.items() if k != 'project_id']

            with self.get_cursor() as cursor:
                cursor.execute(
                    f"UPDATE reservoir_data SET {columns} WHERE project_id = ?",
                    values + [reservoir_data.project_id]
                )
                return existing['id']
        else:
            # 插入
            columns = ', '.join(data.keys())
            placeholders = ', '.join(['?' for _ in data])

            with self.get_cursor() as cursor:
                cursor.execute(
                    f"INSERT INTO reservoir_data ({columns}) VALUES ({placeholders})",
                    list(data.values())
                )
                return cursor.lastrowid

    def get_reservoir_data_by_project(self, project_id: int) -> Optional[Dict]:
        """根据项目ID获取油藏数据"""
        cache_key = f"reservoir_data_{project_id}"
        cached_result = self._get_cache(cache_key)
        if cached_result:
            return cached_result

        with self.get_cursor() as cursor:
            cursor.execute(
                "SELECT * FROM reservoir_data WHERE project_id = ?",
                (project_id,)
            )
            row = cursor.fetchone()

        result = dict(row) if row else None
        if result:
            self._set_cache(cache_key, result)

        return result

    # 批量操作
    def batch_insert(self, table_name: str, data_list: List[Dict]) -> bool:
        """批量插入数据"""
        if not data_list:
            return False

        # 获取列名
        columns = list(data_list[0].keys())
        columns_str = ', '.join(columns)
        placeholders = ', '.join(['?' for _ in columns])

        with self.get_cursor() as cursor:
            cursor.executemany(
                f"INSERT INTO {table_name} ({columns_str}) VALUES ({placeholders})",
                [list(item.values()) for item in data_list]
            )

        logger.info(f"批量插入 {len(data_list)} 条记录到 {table_name}")
        return True

    # 复杂查询
    def get_project_summary(self, project_id: int) -> Optional[Dict]:
        """获取项目汇总信息"""
        cache_key = f"project_summary_{project_id}"
        cached_result = self._get_cache(cache_key)
        if cached_result:
            return cached_result

        with self.get_cursor() as cursor:
            cursor.execute("""
                SELECT
                    p.*,
                    w.well_md, w.well_tvd, w.inner_diameter, w.outer_diameter,
                    r.expected_production, r.bht, r.bsw, r.api, r.gas_oil_ratio
                FROM projects p
                LEFT JOIN wells w ON p.id = w.project_id
                LEFT JOIN reservoir_data r ON p.id = r.project_id
                WHERE p.id = ?
            """, (project_id,))
            row = cursor.fetchone()

        result = dict(row) if row else None
        if result:
            self._set_cache(cache_key, result)

        return result

    def execute_custom_query(self, query: str, params: Tuple = ()) -> List[Dict]:
        """执行自定义查询"""
        with self.get_cursor() as cursor:
            cursor.execute(query, params)
            rows = cursor.fetchall()

        return [dict(row) for row in rows]

    def close(self):
        """关闭数据库连接"""
        if hasattr(self._local, 'connection'):
            self._local.connection.close()


# 使用示例
if __name__ == "__main__":
    # 创建数据库管理器实例
    db = DatabaseManager("oil_data.db")

    # 创建项目
    project = Project(
        project_name="测试项目001",
        user_name="张三",
        company_name="石油公司",
        well_name="井001",
        oil_name="轻质原油"
    )

    project_id = db.create_project(project)
    print(f"创建项目ID: {project_id}")

    # 保存井数据
    well_data = WellData(
        project_id=project_id,
        well_md=2500.0,
        well_tvd=2450.0,
        inner_diameter=150.0,
        outer_diameter=170.0
    )

    db.save_well_data(well_data)

    # 获取项目汇总
    summary = db.get_project_summary(project_id)
    print("项目汇总:", summary)

    # 获取所有项目
    all_projects = db.get_all_projects()
    print(f"共有 {len(all_projects)} 个项目")
