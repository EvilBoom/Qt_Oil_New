import sys
# import os
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

class LoginController(QObject):
    """登录控制器 - 处理用户登录和项目管理"""

    # 定义信号
    loginSuccess = Signal(str, str)  # 项目名称, 用户名
    loginFailed = Signal(str)  # 错误信息
    projectListChanged = Signal()  # 项目列表变更信号
    languageChanged = Signal(bool)  # 语言变更信号 (True=中文, False=英文)

    def __init__(self, db_manager=None, parent=None):
        super().__init__(parent)
        self._db_manager = db_manager
        self._project_list = []
        self._current_language = True  # True=中文, False=英文

        # 加载项目列表
        self._load_projects()

    def _load_projects(self):
        """从数据库加载项目列表"""
        # 在实际应用中，从数据库获取项目列表
        # 这里为示例，使用模拟数据
        if self._db_manager:
            # 使用数据库管理器获取项目列表
            # self._project_list = self._db_manager.get_projects()
            pass
        else:
            # 模拟数据
            self._project_list = [
                {"id": 1, "name": "渤海A站台改造项目", "date": "2023-10-15"},
                {"id": 2, "name": "海洋平台举升系统新建", "date": "2024-02-20"},
                {"id": 3, "name": "渤海湾B2站台系统升级", "date": "2023-12-15"}
            ]

        # 通知QML项目列表已更新
        self.projectListChanged.emit()

    # 项目列表属性
    def get_project_list(self):
        """获取项目列表"""
        return [project["name"] for project in self._project_list]

    projectList = Property(list, get_project_list, notify=projectListChanged)

    # 语言属性
    def get_language(self):
        """获取当前语言设置"""
        return self._current_language

    def set_language(self, is_chinese):
        """设置当前语言"""
        if self._current_language != is_chinese:
            self._current_language = is_chinese
            self.languageChanged.emit(is_chinese)

    language = Property(bool, get_language, set_language, notify=languageChanged)

    @Slot(str, str, result=bool)
    def createProject(self, project_name, user_name):
        """创建新项目"""
        if not project_name or not user_name:
            self.loginFailed.emit("项目名称和用户名不能为空" if self._current_language else
                                 "Project name and user name cannot be empty")
            return False

        # 检查项目名是否已存在
        if project_name in [p["name"] for p in self._project_list]:
            self.loginFailed.emit("项目名称已存在" if self._current_language else
                                 "Project name already exists")
            return False

        # 在实际应用中，将新项目保存到数据库
        if self._db_manager:
            # success = self._db_manager.create_project(project_name, user_name)
            pass
        else:
            # 模拟创建项目
            new_id = max([p["id"] for p in self._project_list], default=0) + 1
            self._project_list.append({
                "id": new_id,
                "name": project_name,
                "date": "2025-06-15"  # 使用当前日期
            })

        # 通知QML登录成功，传递项目名称和用户名
        self.loginSuccess.emit(project_name, user_name)
        return True

    @Slot(int, str, result=bool)
    def openProject(self, project_index, user_name):
        """打开已有项目"""
        if project_index < 0 or project_index >= len(self._project_list):
            self.loginFailed.emit("无效的项目选择" if self._current_language else
                                 "Invalid project selection")
            return False

        if not user_name:
            self.loginFailed.emit("用户名不能为空" if self._current_language else
                                 "User name cannot be empty")
            return False

        project_name = self._project_list[project_index]["name"]

        # 在实际应用中，验证项目是否可以打开
        if self._db_manager:
            # success = self._db_manager.open_project(project_id)
            pass

        # 通知QML登录成功
        self.loginSuccess.emit(project_name, user_name)
        return True

# 主函数，仅用于测试登录控制器
if __name__ == "__main__":
    app = QGuiApplication(sys.argv)

    # 创建QML引擎
    engine = QQmlApplicationEngine()

    # 创建并注册登录控制器
    login_controller = LoginController()
    engine.rootContext().setContextProperty("loginController", login_controller)

    # 加载QML文件
    engine.load(QUrl.fromLocalFile("login.qml"))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())
