# Controller/ProjectController.py

from PySide6.QtCore import QObject, Signal, Slot, Property
from typing import List, Dict, Any, Optional
import logging

# 导入数据库服务
from DataManage.services.database_service import DatabaseService

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ProjectController(QObject):
    """项目控制器 - 处理项目相关操作"""

    # 定义信号
    projectsLoaded = Signal(list)           # 项目列表加载完成
    projectCreated = Signal(int, str)       # 项目创建成功 (id, name)
    projectUpdated = Signal(int, str)       # 项目更新成功 (id, name)
    projectDeleted = Signal(int, str)       # 项目删除成功 (id, name)
    projectDetailsLoaded = Signal(dict)     # 项目详情加载完成
    operationStarted = Signal(str)          # 操作开始 (操作类型)
    operationFinished = Signal(str, bool)   # 操作结束 (操作类型, 是否成功)
    error = Signal(str)                     # 错误信息

    def __init__(self, parent=None):
        super().__init__(parent)

        # 获取数据库服务实例
        self._db_service = DatabaseService()

        # 项目列表缓存
        self._projects = []

        # 当前项目详情
        self._current_project = {}

        # 连接数据库服务信号
        self._connect_signals()

        logger.info("项目控制器初始化完成")

    def _connect_signals(self):
        """连接数据库服务信号"""
        # 连接项目创建信号
        self._db_service.projectCreated.connect(self._on_project_created)

        # 连接项目更新信号
        self._db_service.projectUpdated.connect(self._on_project_updated)

        # 连接项目删除信号
        self._db_service.projectDeleted.connect(self._on_project_deleted)

        # 连接错误信号
        self._db_service.databaseError.connect(self._on_database_error)

    # 信号处理函数
    def _on_project_created(self, project_id: int, project_name: str):
        """处理项目创建信号"""
        logger.info(f"项目已创建: {project_name} (ID: {project_id})")
        # 重新加载项目列表
        self.loadProjects()
        # 发射项目创建信号
        self.projectCreated.emit(project_id, project_name)
        self.operationFinished.emit("create", True)

    def _on_project_updated(self, project_id: int, project_name: str):
        """处理项目更新信号"""
        logger.info(f"项目已更新: {project_name} (ID: {project_id})")
        # 重新加载项目列表
        self.loadProjects()
        # 发射项目更新信号
        self.projectUpdated.emit(project_id, project_name)
        self.operationFinished.emit("update", True)

    def _on_project_deleted(self, project_id: int, project_name: str):
        """处理项目删除信号"""
        logger.info(f"项目已删除: {project_name} (ID: {project_id})")
        # 重新加载项目列表
        self.loadProjects()
        # 发射项目删除信号
        self.projectDeleted.emit(project_id, project_name)
        self.operationFinished.emit("delete", True)

    def _on_database_error(self, error_message: str):
        """处理数据库错误信号"""
        logger.error(f"数据库错误: {error_message}")
        # 发射错误信号
        self.error.emit(error_message)
        self.operationFinished.emit("unknown", False)

    # 属性 - 项目列表
    def _get_projects(self) -> List[Dict[str, Any]]:
        return self._projects

    # 定义项目列表属性，可以在QML中绑定
    projects = Property(list, _get_projects, notify=projectsLoaded)

    # 槽函数 - 供QML调用
    @Slot(result=list)
    def loadProjects(self) -> List[Dict[str, Any]]:
        """加载所有项目"""
        try:
            logger.info("开始加载项目列表")
            self.operationStarted.emit("load")

            # 从数据库服务获取项目列表
            projects = self._db_service.get_all_projects()

            # 更新缓存
            self._projects = projects

            # 发射信号通知UI
            self.projectsLoaded.emit(projects)
            self.operationFinished.emit("load", True)

            logger.info(f"项目列表加载完成，共 {len(projects)} 个项目")
            return projects

        except Exception as e:
            error_msg = f"加载项目列表失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.operationFinished.emit("load", False)
            return []

    @Slot(str, str, str, str, str, str, str, result=int)
    def createProject(self, project_name: str, user_name: str, company_name: str = "",
                     well_name: str = "", oil_name: str = "", location: str = "",
                     ps: str = "") -> int:
        """创建新项目"""
        try:
            logger.info(f"开始创建项目: {project_name}")
            self.operationStarted.emit("create")

            # 创建项目数据字典
            project_data = {
                'project_name': project_name,
                'user_name': user_name,
                'company_name': company_name,
                'well_name': well_name,
                'oil_name': oil_name,
                'location': location,
                'ps': ps
            }

            # 调用数据库服务创建项目
            project_id = self._db_service.create_project(project_data)

            logger.info(f"项目创建成功: {project_name} (ID: {project_id})")
            return project_id

        except Exception as e:
            error_msg = f"创建项目失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.operationFinished.emit("create", False)
            return -1

    @Slot(int, str, str, str, str, str, str, str, result=bool)
    def updateProject(self, project_id: int, project_name: str = "", user_name: str = "",
                     company_name: str = "", well_name: str = "", oil_name: str = "",
                     location: str = "", ps: str = "") -> bool:
        """更新项目信息"""
        try:
            logger.info(f"开始更新项目: ID {project_id}")
            self.operationStarted.emit("update")

            # 创建更新数据字典，只包含非空值
            updates = {}
            if project_name: updates['project_name'] = project_name
            if user_name: updates['user_name'] = user_name
            if company_name or company_name == "": updates['company_name'] = company_name
            if well_name or well_name == "": updates['well_name'] = well_name
            if oil_name or oil_name == "": updates['oil_name'] = oil_name
            if location or location == "": updates['location'] = location
            if ps or ps == "": updates['ps'] = ps

            if not updates:
                logger.info("没有需要更新的数据")
                self.operationFinished.emit("update", True)
                return True

            # 调用数据库服务更新项目
            success = self._db_service.update_project(project_id, updates)

            if not success:
                raise Exception("数据库更新失败")

            logger.info(f"项目更新成功: ID {project_id}")
            return True

        except Exception as e:
            error_msg = f"更新项目失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.operationFinished.emit("update", False)
            return False

    @Slot(int, result=bool)
    def deleteProject(self, project_id: int) -> bool:
        """删除项目"""
        try:
            logger.info(f"开始删除项目: ID {project_id}")
            self.operationStarted.emit("delete")

            # 调用数据库服务删除项目
            success = self._db_service.delete_project(project_id)

            if not success:
                raise Exception("数据库删除失败")

            logger.info(f"项目删除成功: ID {project_id}")
            return True

        except Exception as e:
            error_msg = f"删除项目失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            self.operationFinished.emit("delete", False)
            return False

    @Slot(str, result=dict)
    def getProjectByName(self, project_name: str) -> Dict[str, Any]:
        """根据项目名获取项目"""
        try:
            logger.info(f"获取项目信息: {project_name}")

            # 调用数据库服务获取项目
            project = self._db_service.get_project_by_name(project_name)

            if project:
                # 更新当前项目缓存
                self._current_project = project
                # 发射项目详情加载信号
                self.projectDetailsLoaded.emit(project)

                logger.info(f"项目信息加载成功: {project_name}")
                return project
            else:
                logger.warning(f"项目不存在: {project_name}")
                return {}

        except Exception as e:
            error_msg = f"获取项目信息失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            return {}

    @Slot(int, result=dict)
    def getProjectSummary(self, project_id: int) -> Dict[str, Any]:
        """获取项目汇总信息，包括井数据和油藏数据"""
        try:
            logger.info(f"获取项目汇总信息: ID {project_id}")

            # 调用数据库服务获取项目汇总
            summary = self._db_service.get_project_summary(project_id)

            if summary:
                # 发射项目详情加载信号
                self.projectDetailsLoaded.emit(summary)

                logger.info(f"项目汇总信息加载成功: ID {project_id}")
                return summary
            else:
                logger.warning(f"项目不存在: ID {project_id}")
                return {}

        except Exception as e:
            error_msg = f"获取项目汇总信息失败: {str(e)}"
            logger.error(error_msg)
            self.error.emit(error_msg)
            return {}

    @Slot(result=dict)
    def getCurrentProject(self) -> Dict[str, Any]:
        """获取当前项目信息"""
        return self._current_project
