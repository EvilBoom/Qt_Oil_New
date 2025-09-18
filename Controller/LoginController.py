# Controller/LoginController.py

from PySide6.QtCore import QObject, Signal, Slot, Property
from typing import List, Dict, Any
import logging

# 导入项目控制器
from .ProjectController import ProjectController

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class LoginController(QObject):
    """登录控制器 - 处理用户登录和项目管理"""

    # 定义信号
    loginSuccess = Signal(str, str)  # 项目名称, 用户名
    loginFailed = Signal(str)  # 错误信息
    projectListChanged = Signal()  # 项目列表变更信号
    languageChanged = Signal(bool)  # 语言变更信号 (True=中文, False=英文)
    projectIdChanged = Signal(int)  # 🔥 新增：项目ID变更信号

    def __init__(self, parent=None):
        super().__init__(parent)

        # 获取项目控制器实例
        self._project_controller = ProjectController()

        # 项目列表
        self._project_list = []

        # 当前语言设置 (True=中文, False=英文)
        self._current_language = True

        # 🔥 新增：当前项目ID
        self._current_project_id = -1

        # 连接项目控制器信号
        self._connect_signals()

        # 加载项目列表
        self._load_projects()

        logger.info("登录控制器初始化完成")

    def _connect_signals(self):
        """连接项目控制器信号"""
        # 连接项目列表加载信号
        self._project_controller.projectsLoaded.connect(self._on_projects_loaded)

        # 连接项目创建信号
        self._project_controller.projectCreated.connect(self._on_project_created)

        # 连接错误信号
        self._project_controller.error.connect(self._on_project_error)
    
    # 🔥 新增：当前项目ID属性
    def get_current_project_id(self) -> int:
        """获取当前项目ID"""
        return self._current_project_id

    def set_current_project_id(self, project_id: int):
        """设置当前项目ID"""
        if self._current_project_id != project_id:
            self._current_project_id = project_id
            self.projectIdChanged.emit(project_id)
            logger.info(f"当前项目ID已更新: {project_id}")

    currentProjectId = Property(int, get_current_project_id, set_current_project_id, notify=projectIdChanged)


    def _on_projects_loaded(self, projects):
        """处理项目列表加载完成信号"""
        self._project_list = projects
        self.projectListChanged.emit()
        logger.info(f"项目列表已更新，共 {len(projects)} 个项目")

    def _on_project_created(self, project_id, project_name):
        """处理项目创建成功信号"""
        logger.info(f"项目创建成功: {project_name} (ID: {project_id})")
        # 重新加载项目列表
        self._load_projects()

    def _on_project_error(self, error_message):
        """处理项目控制器错误信号"""
        error_msg = "项目操作错误: " + error_message if self._current_language else "Project operation error: " + error_message
        logger.error(error_msg)
        self.loginFailed.emit(error_msg)

    def _load_projects(self):
        """从数据库加载项目列表"""
        try:
            # 调用项目控制器加载项目列表
            self._project_controller.loadProjects()
        except Exception as e:
            error_msg = f"加载项目列表失败: {str(e)}"
            logger.error(error_msg)
            self.loginFailed.emit(error_msg)

    # 项目列表属性
    def get_project_list(self) -> List[str]:
        """获取项目列表名称"""
        return [project.get("project_name", "") for project in self._project_list]

    # 完整项目列表属性
    def get_full_project_list(self) -> List[Dict[str, Any]]:
        """获取完整项目列表数据"""
        return self._project_list

    # 属性定义
    projectList = Property(list, get_project_list, notify=projectListChanged)
    fullProjectList = Property(list, get_full_project_list, notify=projectListChanged)

    # 语言属性
    def get_language(self) -> bool:
        """获取当前语言设置"""
        return self._current_language

    def set_language(self, is_chinese: bool):
        """设置当前语言"""
        if self._current_language != is_chinese:
            self._current_language = is_chinese
            self.languageChanged.emit(is_chinese)

    language = Property(bool, get_language, set_language, notify=languageChanged)

    @Slot(str, str, result=bool)
    def createProject(self, project_name: str, user_name: str) -> bool:
        """创建新项目"""
        try:
            # 验证输入
            if not project_name or not user_name:
                error_msg = "项目名称和用户名不能为空" if self._current_language else "Project name and user name cannot be empty"
                self.loginFailed.emit(error_msg)
                return False

            # 检查项目名是否已存在
            for project in self._project_list:
                if project.get("project_name", "") == project_name:
                    error_msg = "项目名称已存在" if self._current_language else "Project name already exists"
                    self.loginFailed.emit(error_msg)
                    return False

            # 调用项目控制器创建项目
            project_id = self._project_controller.createProject(
                project_name=project_name,
                user_name=user_name,
                company_name="",
                well_name="",
                oil_name="",
                location="",
                ps=""
            )

            if project_id <= 0:
                error_msg = "创建项目失败" if self._current_language else "Failed to create project"
                self.loginFailed.emit(error_msg)
                return False

            # 通知QML登录成功
            self.loginSuccess.emit(project_name, user_name)
            return True

        except Exception as e:
            error_msg = f"创建项目异常: {str(e)}"
            logger.error(error_msg)
            self.loginFailed.emit(error_msg)
            return False

    @Slot(int, str, result=bool)
    def openProject(self, project_index: int, user_name: str) -> bool:
        """打开已有项目"""
        try:
            # 验证输入
            if project_index < 0 or project_index >= len(self._project_list):
                error_msg = "无效的项目选择" if self._current_language else "Invalid project selection"
                self.loginFailed.emit(error_msg)
                return False

            if not user_name:
                error_msg = "用户名不能为空" if self._current_language else "User name cannot be empty"
                self.loginFailed.emit(error_msg)
                return False

            # 获取项目信息
            project = self._project_list[project_index]
            project_name = project.get("project_name", "")
            project_id = project.get("id", -1)  # 获取项目ID

            # 更新项目的用户名（可选）
            if user_name != project.get("user_name", ""):
                # 如果新用户打开项目，可以选择更新项目的用户名
                # self._project_controller.updateProject(project["id"], user_name=user_name)
                pass

            # 通知QML登录成功
            self.loginSuccess.emit(project_name, user_name)
            return True

        except Exception as e:
            error_msg = f"打开项目异常: {str(e)}"
            logger.error(error_msg)
            self.loginFailed.emit(error_msg)
            return False

    # 🔥 新增：获取项目信息的方法
    @Slot(str, result='QVariant')
    def getProjectByName(self, project_name: str):
        """根据项目名获取项目信息"""
        for project in self._project_list:
            if project.get("project_name", "") == project_name:
                return project
        return {}
