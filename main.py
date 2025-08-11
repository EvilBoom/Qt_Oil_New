# This Python file uses the following encoding: utf-8
import sys
from pathlib import Path
from PySide6.QtGui import QGuiApplication
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Signal, Slot, QUrl

# 导入控制器
from Controller.LoginController import LoginController
from Controller.ProjectController import ProjectController
from Controller.UnitSystemController import UnitSystemController
from Controller.WellDataController import WellDataController
from Controller.ReservoirDataController import ReservoirDataController

# 在main.py的导入部分添加：
from Controller.WellStructureController import WellStructureController
from Controller.ExcelImportController import ExcelImportController
from Controller.PumpCurvesController import PumpCurvesController
from Controller.ContinuousLearningController import ContinuousLearningController
from Controller.KnowledgeGraphController import KnowledgeGraphController

# 导入数据库服务
from DataManage.services.database_service import DatabaseService

from Controller.DeviceController import DeviceController                                                            
from Controller.DeviceRecommendationController import DeviceRecommendationController

import os
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface
from PySide6.QtGui import QSurfaceFormat, QFont
# os.environ["QT_QUICK_BACKEND"] = "software"  # 使用软件渲染避免GPU问题
# 在创建QApplication之前设置
QQuickWindow.setGraphicsApi(QSGRendererInterface.OpenGL)

# 设置OpenGL格式
format = QSurfaceFormat()
format.setDepthBufferSize(24)
format.setStencilBufferSize(8)
format.setVersion(3, 2)
format.setProfile(QSurfaceFormat.CoreProfile)
QSurfaceFormat.setDefaultFormat(format)

# 禁用图形API自动检测
import os
os.environ['QSG_RHI_BACKEND'] = 'opengl'



# 主应用类 - 管理应用程序生命周期
class Application(QObject):
    def __init__(self):
        super().__init__()

        # 设置Qt图形相关环境变量
        # os.environ["QT_OPENGL"] = "software"
        # os.environ["QT_QUICK_BACKEND"] = "software"

        self.app = QApplication(sys.argv)
        self.engine = QQmlApplicationEngine()
        # 设置全局字体
        # self.setup_global_font()
        # 设置应用程序信息
        self.app.setOrganizationName("OilTech")
        self.app.setOrganizationDomain("oiltech.com")
        self.app.setApplicationName("油井设备智能管理系统")

        # 初始化数据库服务
        self.db_service = DatabaseService()

        # 初始化控制器
        self.login_controller = LoginController()
        self.project_controller = ProjectController()
        self.well_controller = WellDataController()
        self.reservoir_controller = ReservoirDataController()
        # 在Application类的__init__方法中，初始化控制器部分添加：
        self.well_structure_controller = WellStructureController()
        self.excel_import_controller = ExcelImportController()
        self.device_controller = DeviceController()
        self.device_recommendation_controller = DeviceRecommendationController()
        self.pump_curves_controller = PumpCurvesController()
        self.pump_curves_controller.set_database_service(self.db_service)
        self.continuous_learning_controller = ContinuousLearningController()

        self.unit_system_controller = UnitSystemController()

        # 存储用户信息
        self.current_user = ""
        self.current_project = ""
        self.current_project_id = -1

        # 连接登录信号
        self.login_controller.loginSuccess.connect(self.on_login_success)
        self.login_controller.loginFailed.connect(self.on_login_failed)

        # 连接项目控制器信号
        self.project_controller.projectsLoaded.connect(self.on_projects_loaded)
        self.project_controller.projectCreated.connect(self.on_project_created)
        self.project_controller.projectDetailsLoaded.connect(self.on_project_details_loaded)

        # 连接井控制器信号
        self.well_controller.wellListLoaded.connect(self.on_well_list_loaded)
        self.well_controller.wellCreated.connect(self.on_well_created)
        self.well_controller.wellUpdated.connect(self.on_well_updated)
        self.well_controller.wellDeleted.connect(self.on_well_deleted)

        # 连接错误信号处理
        self.project_controller.error.connect(self.on_controller_error)
        self.well_controller.error.connect(self.on_controller_error)
        self.reservoir_controller.error.connect(self.on_controller_error)
        # 🔥 连接单位制变化信号到其他控制器
        # self.unit_system_controller.unitSystemChanged.connect(self.on_unit_system_changed)

        # 将控制器注册到QML引擎
        self.engine.rootContext().setContextProperty("loginController", self.login_controller)
        self.engine.rootContext().setContextProperty("projectController", self.project_controller)
        self.engine.rootContext().setContextProperty("wellController", self.well_controller)
        self.engine.rootContext().setContextProperty("reservoirController", self.reservoir_controller)
        # 在注册控制器到QML引擎部分添加：
        self.engine.rootContext().setContextProperty("wellStructureController", self.well_structure_controller)
        self.engine.rootContext().setContextProperty("excelImportController", self.excel_import_controller)

        self.engine.rootContext().setContextProperty("deviceController", self.device_controller)
        self.engine.rootContext().setContextProperty("deviceRecommendationController", self.device_recommendation_controller)
        self.engine.rootContext().setContextProperty("pumpCurvesController", self.pump_curves_controller)
        self.engine.rootContext().setContextProperty("continuousLearningController", self.continuous_learning_controller)

        self.engine.rootContext().setContextProperty("unitSystemController", self.unit_system_controller)

        # 连接Excel导入控制器信号
        self.excel_import_controller.templateGenerated.connect(self.on_template_generated)
        self.excel_import_controller.templateGenerationFailed.connect(self.on_template_generation_failed)
        # 🔥 连接设备导出信号
        self.device_controller.exportCompleted.connect(self.on_device_export_completed)
        self.device_controller.exportProgress.connect(self.on_device_export_progress)
        self.device_controller.exportFailed.connect(self.on_device_export_failed)

        # 加载登录QML文件
        qml_file = Path(__file__).resolve().parent / "QT_Oil_NewContent/StartWindow.qml"
        self.engine.load(QUrl.fromLocalFile(str(qml_file)))

        if not self.engine.rootObjects():
            print("Failed to load StartWindow.qml")
            sys.exit(-1)

    # 在您的main.py中添加字体设置
    def setup_global_font(self):
        """设置全局字体为宋体"""
        try:
            # 设置应用程序默认字体
            font = QFont("SimSun", 10)
            if font.family() != "SimSun":
                # 如果宋体不可用，尝试其他中文字体
                fallback_fonts = ["Microsoft YaHei", "微软雅黑", "Arial Unicode MS"]
                for fallback in fallback_fonts:
                    test_font = QFont(fallback, 10)
                    if test_font.family() == fallback:
                        font = test_font
                        break
        
            self.app.setFont(font)
        
            # 将字体信息传递给QML
            self.engine.rootContext().setContextProperty("globalFontFamily", font.family())
            self.engine.rootContext().setContextProperty("globalFontSize", 10)
        
            print(f"全局字体设置完成: {font.family()}")
        
        except Exception as e:
            print(f"设置字体失败: {e}")

    def run(self):
        """运行应用程序主循环"""
        return self.app.exec()

    @Slot(str, str)
    def on_login_success(self, project_name, user_name):
        """登录成功处理函数"""
        print(f"登录成功! 项目: {project_name}, 用户: {user_name}")

        # 保存用户信息
        self.current_user = user_name
        self.current_project = project_name

        # 获取项目详情
        project = self.project_controller.getProjectByName(project_name)
        if project and 'id' in project:
            self.current_project_id = project['id']

        # 切换到主窗口
        self.open_main_window(project_name, user_name)

    @Slot(str)
    def on_login_failed(self, error_message):
        """登录失败处理函数"""
        print(f"登录失败: {error_message}")
        # 错误提示已在QML中处理

    @Slot(list)
    def on_projects_loaded(self, projects):
        """项目列表加载完成处理函数"""
        print(f"项目列表加载完成，共 {len(projects)} 个项目")

    @Slot(int, str)
    def on_project_created(self, project_id, project_name):
        """项目创建成功处理函数"""
        print(f"项目创建成功: {project_name} (ID: {project_id})")

    @Slot(dict)
    def on_project_details_loaded(self, project_details):
        """项目详情加载完成处理函数"""
        print(f"项目详情加载完成: {project_details.get('project_name', '')}")

        # 如果是当前项目，加载相关数据
        if project_details.get('id') == self.current_project_id:
            # 加载井数据和油藏数据
            self.well_controller.getWellData(self.current_project_id)
            self.reservoir_controller.getReservoirData(self.current_project_id)

    @Slot(str)
    def on_controller_error(self, error_message):
        """控制器错误处理函数"""
        print(f"控制器错误: {error_message}")
        # 这里可以添加全局错误处理逻辑

    def open_main_window(self, project_name, user_name):
        
        """打开主窗口"""
        try:
            # 先加载主窗口
            main_qml = Path(__file__).resolve().parent / "QT_Oil_NewContent/MainWindow.qml"

            # 确保文件存在
            if not main_qml.exists():
                print(f"MainWindow.qml not found at: {main_qml}")
                return

            # 关闭登录窗口
            if self.engine.rootObjects():
                login_window = self.engine.rootObjects()[0]
                login_window.close()

            # 清理引擎
            self.engine.clearComponentCache()

            # 重新注册所有控制器，确保主窗口能访问
            self.engine.rootContext().setContextProperty("loginController", self.login_controller)
            self.engine.rootContext().setContextProperty("projectController", self.project_controller)
            self.engine.rootContext().setContextProperty("wellController", self.well_controller)
            self.engine.rootContext().setContextProperty("reservoirController", self.reservoir_controller)
            # 在open_main_window方法中，重新注册控制器部分也要添加：
            self.engine.rootContext().setContextProperty("wellStructureController", self.well_structure_controller)
            self.engine.rootContext().setContextProperty("excelImportController", self.excel_import_controller)
            self.engine.rootContext().setContextProperty("deviceController", self.device_controller)
            self.engine.rootContext().setContextProperty("deviceRecommendationController", self.device_recommendation_controller)
            self.engine.rootContext().setContextProperty("continuousLearningController", self.continuous_learning_controller)
            # 加载主窗口
            self.engine.load(QUrl.fromLocalFile(str(main_qml)))

            # 设置主窗口的信息  
            if self.engine.rootObjects():
                # 找到新加载的主窗口（最后一个）
                main_window = self.engine.rootObjects()[-1]
                print(f"设置主窗口 currentProjectId: {self.current_project_id}")
                main_window.setProperty("currentProjectId", self.current_project_id)

                main_window.setProperty("currentUserName", user_name)
                main_window.setProperty("currentProjectName", project_name)
                
                main_window.setProperty("isChinese", self.login_controller.language)
                # 在 open_main_window 方法中添加
                main_window.setProperty("isMetric", self.unit_system_controller.isMetric)
                print(f"主窗口已加载，用户: {user_name}, 项目: {project_name}, 项目ID: {self.current_project_id}, 语言: {'中文' if self.login_controller.language else '英文'}")

                # 加载项目数据
                if self.current_project_id > 0:
                    # 获取项目详情
                    self.project_controller.getProjectSummary(self.current_project_id)
                    # 加载井数据和油藏数据
                    self.well_controller.getWellData(self.current_project_id)
                    self.reservoir_controller.getReservoirData(self.current_project_id)
            else:
                print("Failed to load MainWindow.qml")
            # 确保设备推荐控制器有项目ID
            if self.current_project_id > 0:
                self.device_recommendation_controller.currentProjectId = self.current_project_id
    

        except Exception as e:
            print(f"打开主窗口时出错: {e}")
            import traceback
            traceback.print_exc()

    @Slot(list)
    def on_well_list_loaded(self, wells):
        """井列表加载完成处理函数"""
        print(f"井列表加载完成，共 {len(wells)} 口井")

    @Slot(int, str)
    def on_well_created(self, well_id, well_name):
        """井创建成功处理函数"""
        print(f"井创建成功: {well_name} (ID: {well_id})")

    @Slot(int, str)
    def on_well_updated(self, well_id, well_name):
        """井更新成功处理函数"""
        print(f"井更新成功: {well_name} (ID: {well_id})")

    @Slot(int, str)
    def on_well_deleted(self, well_id, well_name):
        """井删除成功处理函数"""
        print(f"井删除成功: {well_name} (ID: {well_id})")

    @Slot(str)
    def on_template_generated(self, file_path):
        """模板生成成功处理"""
        print(f"模板生成成功: {file_path}")

    @Slot(str)  
    def on_template_generation_failed(self, error_msg):
        """模板生成失败处理"""
        print(f"模板生成失败: {error_msg}")

    @Slot(str, int)
    def on_device_export_completed(self, file_path, count):
        """设备导出完成处理"""
        print(f"设备导出完成: {count}个设备已导出到 {file_path}")

    @Slot(int, int)
    def on_device_export_progress(self, current, total):
        """设备导出进度处理"""
        print(f"导出进度: {current}/{total}")

    @Slot(str)
    def on_device_export_failed(self, error_msg):
        """设备导出失败处理"""
        print(f"设备导出失败: {error_msg}")

if __name__ == "__main__":
    app = Application()
    sys.exit(app.run())
