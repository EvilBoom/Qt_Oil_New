[app]

# title of your application
title = pyside_app_demo

# project root directory. default = The parent directory of input_file
project_dir = D:\projects\Oil\Qt_Oil_New

# source file entry point path. default = main.py
input_file = D:\projects\Oil\Qt_Oil_New\main.py

# directory where the executable output is generated
exec_directory = .

# path to the project file relative to project_dir
project_file = Qt_Oil_New.pyproject

# application icon
icon = D:\projects\Oil\Qt_Oil\Ot_Oil_env\Lib\site-packages\PySide6\scripts\deploy_lib\pyside_icon.ico

[python]

# python path
python_path = D:\projects\Oil\Qt_Oil\Ot_Oil_env\Scripts\python.exe

# python packages to install
packages = Nuitka==2.6.8

# buildozer = for deploying Android application
android_packages = buildozer==1.5.0,cython==0.29.33

[qt]

# paths to required qml files. comma separated
# normally all the qml files required by the project are added automatically
# qml_files = Qt_Oil_NewContent\DashboardPage.qml,Qt_Oil_NewContent\FunctionCard.qml,Qt_Oil_NewContent\MainWindow.qml,Qt_Oil_NewContent\NavigationItem.qml,Qt_Oil_NewContent\OilWellManagement\OilWellManagementPage.qml,Qt_Oil_NewContent\OilWellManagement\WellDataDialog.qml,Qt_Oil_NewContent\OilWellManagement\components\WellDataDialogForm.ui.qml,Qt_Oil_NewContent\ProductionParamsDialog.qml,Qt_Oil_NewContent\QuickActionButton.qml,Qt_Oil_NewContent\StartWindow.qml,Qt_Oil_NewContent\StatCard.qml,Qt_Oil_NewContent\WellStructure\WellSchematicView.qml,Qt_Oil_NewContent\WellStructure\WellStructurePage.qml,Qt_Oil_NewContent\WellStructure\components\CasingListItem.qml,Qt_Oil_NewContent\WellStructure\components\CasingEditDialog.qml,Qt_Oil_NewContent\WellStructure\components\ExcelImportDialog.qml,Qt_Oil_NewContent\WellStructure\components\WellTrajectoryDataView.qml,main.qml,Qt_Oil_NewContent\WellStructure\components\CalculationResultDialog.qml,Qt_Oil_NewContent\WellStructure\components\CasingListView.qml,Qt_Oil_NewContent\WellStructure\components\WellTrajectoryChart.qml,Qt_Oil_NewContent\DeviceManagement\DeviceManagementPage.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceListView.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceDetailPanel.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceFilterBar.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceCard.qml,Qt_Oil_NewContent\DeviceManagement\components\AddEditDeviceDialog.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceImportDialog.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceExportDialog.qml,Qt_Oil_NewContent\DeviceManagement\components\Toast.qml
# 补齐 qml 文件（在原有列表后面追加以下项）
qml_files = Qt_Oil_NewContent\DashboardPage.qml,Qt_Oil_NewContent\FunctionCard.qml,Qt_Oil_NewContent\MainWindow.qml,Qt_Oil_NewContent\NavigationItem.qml,Qt_Oil_NewContent\OilWellManagement\OilWellManagementPage.qml,Qt_Oil_NewContent\OilWellManagement\WellDataDialog.qml,Qt_Oil_NewContent\OilWellManagement\components\WellDataDialogForm.ui.qml,Qt_Oil_NewContent\ProductionParamsDialog.qml,Qt_Oil_NewContent\QuickActionButton.qml,Qt_Oil_NewContent\StartWindow.qml,Qt_Oil_NewContent\StatCard.qml,Qt_Oil_NewContent\WellStructure\WellSchematicView.qml,Qt_Oil_NewContent\WellStructure\WellStructurePage.qml,Qt_Oil_NewContent\WellStructure\components\CasingListItem.qml,Qt_Oil_NewContent\WellStructure\components\CasingEditDialog.qml,Qt_Oil_NewContent\WellStructure\components\ExcelImportDialog.qml,Qt_Oil_NewContent\WellStructure\components\WellTrajectoryDataView.qml,main.qml,Qt_Oil_NewContent\WellStructure\components\CalculationResultDialog.qml,Qt_Oil_NewContent\WellStructure\components\CasingListView.qml,Qt_Oil_NewContent\WellStructure\components\WellTrajectoryChart.qml,Qt_Oil_NewContent\DeviceManagement\DeviceManagementPage.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceListView.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceDetailPanel.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceFilterBar.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceCard.qml,Qt_Oil_NewContent\DeviceManagement\components\AddEditDeviceDialog.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceImportDialog.qml,Qt_Oil_NewContent\DeviceManagement\components\DeviceExportDialog.qml,Qt_Oil_NewContent\DeviceManagement\components\Toast.qml,Qt_Oil_NewContent\DeviceRecommendation\DeviceRecommendationPage.qml,Qt_Oil_NewContent\DeviceRecommendation\Steps\Step1_ProductionParameters.qml,Qt_Oil_NewContent\DeviceRecommendation\Steps\Step2_PredictionResults.qml,Qt_Oil_NewContent\DeviceRecommendation\Steps\Step3_LiftMethodSelection.qml,Qt_Oil_NewContent\DeviceRecommendation\Steps\Step4_PumpSelection.qml,Qt_Oil_NewContent\DeviceRecommendation\Steps\Step8_ReportGeneration.qml,Qt_Oil_NewContent\DeviceRecommendation\Components\EnhancedPumpCurvesChart.qml,Qt_Oil_NewContent\DeviceRecommendation\Components\KnowledgeGraphWindow.qml,Qt_Oil_NewContent\DeviceRecommendation\Components\KnowledgeRecommendationPanel.qml,Qt_Oil_NewContent\DeviceRecommendation\Components\KnowledgeGraphCanvas.qml

# excluded qml plugin binaries
excluded_qml_plugins = QtQuick3D,QtSensors,QtTest

# qt modules used. comma separated
# modules = Qml,QuickControls2,WebEngineQuick,Quick,Core,Gui,Widgets
# 增加 webengine 模块
modules = Gui,Core,Quick,Widgets,WebEngineQuick,QuickControls2,Qml

# qt plugins used by the application. only relevant for desktop deployment
# for qt plugins used in android application see [android][plugins]
plugins = platforms/darwin,generic,scenegraph,platformthemes,qmltooling,accessiblebridge,egldeviceintegrations,tls,iconengines,platforms,xcbglintegrations,qmllint,styles,networkinformation,platforminputcontexts,networkaccess,imageformats

[android]

# path to pyside wheel
wheel_pyside = 

# path to shiboken wheel
wheel_shiboken = 

# plugins to be copied to libs folder of the packaged application. comma separated
plugins = 

[nuitka]

# usage description for permissions requested by the app as found in the info.plist file
# of the app bundle. comma separated
# eg = extra_args = --show-modules --follow-stdlib
macos.permissions = 

# mode of using nuitka. accepts standalone or onefile. default = onefile
# mode = onefile
mode = standalone

# specify any extra nuitka arguments
extra_args = --quiet --noinclude-qt-translations --output-dir=deployment --output-filename=Recommendation

[buildozer]

# build mode
# possible values = ["aarch64", "armv7a", "i686", "x86_64"]
# release creates a .aab, while debug creates a .apk
mode = debug

# path to pyside6 and shiboken6 recipe dir
recipe_dir = 

# path to extra qt android .jar files to be loaded by the application
jars_dir = 

# if empty, uses default ndk path downloaded by buildozer
ndk_path = 

# if empty, uses default sdk path downloaded by buildozer
sdk_path = 

# other libraries to be loaded at app startup. comma separated.
local_libs = 

# architecture of deployed platform
arch = 

