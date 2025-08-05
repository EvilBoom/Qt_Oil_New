import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Effects

Window {
    id: mainWindow
    visible: true
    width: 1200
    height: 800
    minimumWidth: 1000
    minimumHeight: 600
    title: qsTr("油井设备智能管理系统")

    // 属性定义
    property string currentUserName: ""
    property string currentProjectName: ""
    property int currentPageIndex: 0
    property bool sidebarCollapsed: false
    property bool isChinese: true  // 语言设置
    // 在 MainWindow 的属性定义部分添加
    property int currentWellId: -1
    property var currentSelectionData: ({})

    // 监听页面索引变化
    onCurrentPageIndexChanged: {
        console.log("=== currentPageIndex changed ===")
        console.log("New index:", currentPageIndex)
        console.log("Previous index:", contentStack.currentIndex)
        console.log("Call stack:", new Error().stack)
    }

    // 在MainWindow.qml的属性定义部分添加：
    property int currentProjectId: -1

    // 添加信号
    signal continuousLearningPageLoaded()
    
    // 防抖控制
    property bool navigationInProgress: false
    property var lastNavigationTime: 0

    // 连接LoginController的语言变化信号
    Connections {
        target: loginController
        function onLanguageChanged(chinese) {
            mainWindow.isChinese = chinese
        }
    }
    
    Component.onCompleted: {
        console.log("MainWindow.qml - Component.onCompleted")
        console.log("MainWindow.qml - continuousLearningController:", typeof continuousLearningController !== 'undefined' ? continuousLearningController : "UNDEFINED")
        console.log("MainWindow.qml - loginController:", typeof loginController !== 'undefined' ? loginController : "UNDEFINED")
    }
    onCurrentProjectIdChanged: {
        console.log("MainWindow - currentProjectId 变更为:", currentProjectId)
        // 更新所有已加载的页面的 projectId
        updateAllProjectIds()
    }

    Rectangle {
        id: rootContainer
        anchors.fill: parent
        color: "#f5f7fa"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // 侧边栏
            Rectangle {
                id: sidebar
                Layout.preferredWidth: sidebarCollapsed ? 60 : 240
                Layout.fillHeight: true
                color: "#1e3a5f"

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Logo区域
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                radius: 8
                                color: "#4a90e2"

                                Text {
                                    anchors.centerIn: parent
                                    text: "⚙"
                                    font.pixelSize: 24
                                    color: "white"
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: isChinese ? "智能管理系统" : "Management System"
                                color: "white"
                                font.pixelSize: 16
                                font.bold: true
                                visible: !sidebarCollapsed
                                opacity: sidebarCollapsed ? 0 : 1

                                Behavior on opacity {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.1)
                        }
                    }

                    // 导航菜单
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Column {
                            width: parent.width
                            spacing: 4

                            // 添加顶部间距
                            Item { height: 10 }

                            // 油井信息管理
                            NavigationItem {
                                id: wellInfoNav
                                width: parent.width
                                iconText: "🛢️"
                                title: isChinese ? "油井信息管理" : "Well Information"
                                collapsed: sidebarCollapsed
                                subItemsList: [
                                    {"title": isChinese ? "油井基本信息" : "Basic Well Info", "action": "well-info"},
                                    {"title": isChinese ? "井身结构信息" : "Well Structure", "action": "well-structure"}
                                ]
                                onSubItemClicked: function(action) {
                                    handleNavigation(action)
                                }
                            }
                            // 设备选型推荐
                            NavigationItem {
                                width: parent.width
                                iconText: "📊"
                                title: isChinese ? "设备选型推荐" : "Equipment Selection"
                                collapsed: sidebarCollapsed
                                subItemsList: [
                                 {"title": isChinese ? "设备选型推荐" : "Equipment Selection", "action": "device-recommend"}, // Added new selection item
                                ] 
                                onSubItemClicked: function(action) {
                                    handleNavigation(action)
                                }
                            }


                            // 设备数据库管理
                            NavigationItem {
                                width: parent.width
                                iconText: "💾"
                                title: isChinese ? "设备数据库管理" : "Equipment Database"
                                collapsed: sidebarCollapsed
                                subItemsList: [
                                {"title": isChinese ? "设备数据管理" : "Equipment Selection", "action": "equipment-manage"}, // Added new selection item
                                
                                ]
                                onSubItemClicked: function(action) {
                                    handleNavigation(action)
                                }
                            }

                            // 模型持续学习
                            NavigationItem {
                                width: parent.width
                                iconText: "🤖"
                                title: isChinese ? "模型持续学习" : "Model Training"
                                collapsed: sidebarCollapsed
                                subItemsList: [
                                    {"title": isChinese ? "数据管理" : "Data Management", "action": "data-management"},
                                    {"title": isChinese ? "模型训练" : "Model Training", "action": "model-training"},
                                    {"title": isChinese ? "模型测试" : "Model Testing", "action": "model-testing"}
                                ]
                                onSubItemClicked: function(action) {
                                    handleNavigation(action)
                                }
                                onMainItemClicked: {
                                    console.log("=== 模型持续学习主导航被点击 ===")
                                    console.log("Time:", new Date().toLocaleTimeString())
                                    handleNavigation("continuous-learning-main")
                                }
                            }

                            // 填充空间，确保菜单项不会被压缩
                            Item {
                                width: parent.width
                                height: 100 // 添加底部空间
                            }
                        }
                    }

                    // 折叠按钮
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: "transparent"

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.1)
                        }

                        Button {
                            anchors.centerIn: parent
                            width: 40
                            height: 40

                            background: Rectangle {
                                color: parent.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                                radius: 20
                            }

                            contentItem: Text {
                                text: sidebarCollapsed ? "→" : "←"
                                color: "white"
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: sidebarCollapsed = !sidebarCollapsed
                        }
                    }
                }
            }

            // 主内容区
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // 顶部栏
                Rectangle {
                    id: topBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: "white"

                    // 阴影效果
                    Rectangle {
                        anchors.top: parent.bottom
                        width: parent.width
                        height: 4
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#20000000" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24

                        // 面包屑导航
                        Text {
                            text: getBreadcrumb()
                            color: "#666"
                            font.pixelSize: 14
                        }

                        Item { Layout.fillWidth: true }

                        // 操作按钮
                        Button {
                            text: isChinese ? "导出报告" : "Export Report"
                            flat: true

                            contentItem: RowLayout {
                                Text {
                                    text: "📄"
                                    font.pixelSize: 16
                                }
                                Text {
                                    text: parent.parent.text
                                    color: "#4a90e2"
                                    font.pixelSize: 14
                                }
                            }

                            background: Rectangle {
                                color: parent.hovered ? "#e8f0fe" : "transparent"
                                radius: 6
                            }
                        }

                        // 用户信息
                        RowLayout {
                            spacing: 12

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: "#4a90e2"

                                Text {
                                    anchors.centerIn: parent
                                    text: currentUserName.length > 0 ? currentUserName[0] : "U"
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                            }

                            Text {
                                text: currentUserName
                                color: "#333"
                                font.pixelSize: 14
                            }
                        }
                    }
                }

                // 内容区域
                StackLayout {
                    id: contentStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: currentPageIndex
                    
                    onCurrentIndexChanged: {
                        console.log("StackLayout currentIndex changed to:", currentIndex)
                        console.log("Total children:", children.length)
                        for (var i = 0; i < children.length; i++) {
                            var child = children[i]
                            console.log("Child", i, "visible:", child.visible, "type:", child.toString())
                        }
                    }

                    // 首页仪表盘
                    Loader {
                        source: "DashboardPage.qml"

                        Connections {
                            target: item
                            function onQuickAction(action) {
                                handleNavigation(action)
                            }
                        }
                    }

                    // 油井信息的页面
                    Loader {
                        source: "OilWellManagement/OilWellManagementPage.qml"

                        property int projectId: mainWindow.currentProjectId
                        property bool isChineseMode: mainWindow.isChinese
                    }
                    // 井身结构信息页面
                    Loader {
                        source: "WellStructure/WellStructurePage.qml"

                        property int projectId: mainWindow.currentProjectId
                        property bool isChineseMode: mainWindow.isChinese
                        onLoaded: {
                            console.log("传递给 WellStructure 的 projectId:", projectId)
                            console.log("mainWindow.currentProjectId:", mainWindow.currentProjectId)
                         
                        }
                    }

                    // 设备选型推荐页面
                    Loader {
                        source: "DeviceRecommendation/DeviceRecommendationPage.qml"
        
                        property int projectId: mainWindow.currentProjectId
                        property bool isChineseMode: mainWindow.isChinese

                        onLoaded: {
                            console.log("传递给 DeviceRecommendationPage 的 projectId:", projectId)
                            console.log("mainWindow.currentProjectId:", mainWindow.currentProjectId)
                            if (item) {
                                console.log("DeviceRecommendationPage 接收到的 projectId:", item.projectId)
                            }
                        }

                        onStatusChanged: {
                            console.log("DeviceRecommendation Loader status:", status)
                            if (status === Loader.Error) {
                                console.log("Error loading DeviceRecommendation page")
                            } else if (status === Loader.Ready) {
                                console.log("DeviceRecommendation page loaded successfully")
                            }
                        }
                        onSourceChanged: console.log("Source changed to:", source)
                    }


                    // 设备数据库管理页面
                    Loader {
                        id: deviceManagementLoader
                        source: "DeviceManagement/DeviceManagementPage.qml"
                        property bool isChineseMode: mainWindow.isChinese
                        
                        onLoaded: {
                            console.log("Minimal DeviceManagement page loaded successfully")
                            console.log("DeviceManagement visible:", visible)
                            console.log("DeviceManagement active:", active)
                            if (item) {
                                console.log("DeviceManagement item created:", typeof item)
                                console.log("Setting isChineseMode to:", mainWindow.isChinese)
                            } else {
                                console.log("DeviceManagement item is null")
                            }
                        }
                        
                        onStatusChanged: {
                            console.log("DeviceManagement Loader status:", status)
                            if (status === Loader.Error) {
                                console.log("Error loading DeviceManagement page")
                                console.log("Source:", source)
                            } else if (status === Loader.Ready) {
                                console.log("DeviceManagement page ready")
                            } else if (status === Loader.Loading) {
                                console.log("DeviceManagement page loading...")
                            }
                        }
                        
                        Component.onCompleted: {
                            console.log("DeviceManagement Loader completed, source:", source)
                        }


                        onStatusChanged: {
                            console.log("=== DeviceManagementLoader 状态变化 ===")
                            console.log("Status:", status)
                            switch(status) {
                                case Loader.Null:
                                    console.log("状态: Null - 没有源文件或源文件为空")
                                    break
                                case Loader.Ready:
                                    console.log("状态: Ready - 组件加载成功")
                                    break
                                case Loader.Loading:
                                    console.log("状态: Loading - 正在加载")
                                    break
                                case Loader.Error:
                                    console.log("状态: Error - 加载失败")
                                    console.log("错误信息:", sourceComponent ? sourceComponent.errorString() : "未知错误")
                                    break
                            }
                        }

                        Component.onCompleted: {
                            console.log("=== DeviceManagementLoader 初始化完成 ===")
                            console.log("源文件:", source)
                            console.log("初始状态:", status)
                        }
                    }


                    // 添加设备分类管理页面（占位）
                    Rectangle {
                            color: "#f5f7fa"
                            Text {
                                anchors.centerIn: parent
                                text: isChinese ? "设备分类管理" : "Device Category Management"
                                font.pixelSize: 24
                                color: "#666"
                            }
                    }

                    // 持续学习页面
                    Loader {
                        id: continuousLearningLoader
                        source: "ContinuousLearning/ContinuousLearningPage.qml"
                        
                        property int projectId: mainWindow.currentProjectId
                        property bool isChineseMode: mainWindow.isChinese
                        property string pendingModule: ""  // 待设置的模块
                        
                        onLoaded: {
                            console.log("MainWindow: Loading ContinuousLearningPage")
                            console.log("MainWindow: continuousLearningController available:", typeof continuousLearningController !== 'undefined')
                            console.log("传递给 ContinuousLearningPage 的 projectId:", projectId)
                            if (item) {
                                item.isChinese = mainWindow.isChinese
                                item.currentProjectId = mainWindow.currentProjectId
                                item.continuousLearningController = continuousLearningController
                                console.log("MainWindow: Set continuousLearningController to:", item.continuousLearningController)
                                
                                // 如果有待设置的模块，现在设置
                                if (pendingModule !== "") {
                                    console.log("MainWindow: Setting pending module:", pendingModule)
                                    item.currentModule = pendingModule
                                    pendingModule = ""
                                }
                            }
                            
                            // 发出页面加载完成信号
                            continuousLearningPageLoaded()
                        }
                        
                        onStatusChanged: {
                            if (status === Loader.Error) {
                                console.log("Error loading ContinuousLearning page")
                            } else if (status === Loader.Ready) {
                                console.log("ContinuousLearning page loaded successfully")
                            }
                        }
                    }
                }
            }
        }
    }

    // 对话框加载器
    Loader {
        id: dialogLoader
        anchors.fill: parent
        source: ""
        active: false
        z: 1000

        onLoaded: {
            if (item) {
                // 尝试调用 open 方法（如果存在）
                if (typeof item.open === 'function') {
                    item.open()
                } else if (item.hasOwnProperty("visible")) {
                    item.visible = true
                }
            }
        }

        Connections {
            target: dialogLoader.item
            function onAccepted() {
                dialogLoader.source = ""
                dialogLoader.active = false
            }
            function onRejected() {
                dialogLoader.source = ""
                dialogLoader.active = false
            }
        }
    }

    // 2. 更新handleNavigation函数，添加设备管理相关的导航处理：
    function handleNavigation(action) {
        console.log("=== handleNavigation called ===")
        console.log("Navigation to:", action)
        console.log("Current page index:", currentPageIndex)
        console.log("Call stack:", new Error().stack)

        // 防抖检查
        var currentTime = Date.now()
        if (navigationInProgress || (currentTime - lastNavigationTime < 500)) {
            console.log("Navigation ignored due to debounce. InProgress:", navigationInProgress, "TimeDiff:", currentTime - lastNavigationTime)
            return
        }
        
        navigationInProgress = true
        lastNavigationTime = currentTime

        switch(action) {
            case "continuous-learning-main":
                currentPageIndex = 6  // 持续学习页面
                console.log("=== Switching to continuous learning main page ===")
                console.log("Target page index:", currentPageIndex)
                // 确保跳转到主页面（而不是子模块）
                Qt.callLater(function() {
                    setContinuousLearningModule("main")
                })
                break
            case "data-management":
                currentPageIndex = 6  // 持续学习页面
                console.log("Switching to continuous learning page - data management, index:", currentPageIndex)
                // 延迟一小段时间确保页面切换完成
                Qt.callLater(function() {
                    setContinuousLearningModule("data_management")
                })
                break
            case "model-training":
                currentPageIndex = 6  // 跳转到持续学习页面
                console.log("Switching to continuous learning page - model training")
                Qt.callLater(function() {
                    setContinuousLearningModule("model_training")
                })
                break
            case "model-testing":
                currentPageIndex = 6
                console.log("Switching to continuous learning page - model testing")
                Qt.callLater(function() {
                    setContinuousLearningModule("model_testing")
                })
                break
            case "well-info":
                currentPageIndex = 1
                break
            case "well-structure":
                currentPageIndex = 2
                break
            case "device-recommend":
                currentPageIndex = 3
                console.log("Switching to device recommendation page, index:", currentPageIndex)
                // 确保在页面加载后设置 projectId
                var loader = contentStack.children[3]
                if (loader && loader.item) {
                    console.log("直接设置 DeviceRecommendationPage 的 projectId:", currentProjectId)
                    loader.item.projectId = currentProjectId
                }
                break
            case "equipment-manage":
                currentPageIndex = 4  // 设备列表页面
                console.log("Switching to device list page, index:", currentPageIndex)
                break
            case "device-category":
                currentPageIndex = 5  // 设备分类管理页面
                break
            default:
                console.log("Unknown action:", action)
        }
        console.log("=== handleNavigation end ===")
        
        // 重置防抖状态
        Qt.callLater(function() {
            navigationInProgress = false
        })
    }

    // 显示对话框
    function showDialog(dialogFile) {
        dialogLoader.source = dialogFile
        dialogLoader.active = true
    }
    function updateAllProjectIds() {
        // 检查所有已加载的页面，更新其 projectId
        for (var i = 0; i < contentStack.children.length; i++) {
            var loader = contentStack.children[i]
            if (loader && loader.item) {
                // 处理标准的 projectId 属性
                if (loader.item.hasOwnProperty("projectId")) {
                    console.log(`更新页面 ${i} 的 projectId:`, currentProjectId)
                    loader.item.projectId = currentProjectId
                }
                // 处理持续学习页面的 currentProjectId 属性
                if (loader.item.hasOwnProperty("currentProjectId")) {
                    console.log(`更新页面 ${i} 的 currentProjectId:`, currentProjectId)
                    loader.item.currentProjectId = currentProjectId
                }
                // 确保语言设置也同步更新
                if (loader.item.hasOwnProperty("isChinese")) {
                    loader.item.isChinese = isChinese
                }
            }
        }
    }

    // 3. 修改 getBreadcrumb 函数
    function getBreadcrumb() {
        var home = isChinese ? "首页" : "Home"
        switch(currentPageIndex) {
            case 0: return home + (isChinese ? " / 系统概览" : " / Dashboard")
            case 1: return home + (isChinese ? " / 油井信息管理 / 油井基本信息" : " / Well Information / Basic Well Info")
            case 2: return home + (isChinese ? " / 油井信息管理 / 井身结构信息" : " / Well Information / Well Structure")
            case 3: return home + (isChinese ? " / 设备选型推荐 / 设备选型推荐" : " / Equipment Selection / Equipment Recommendation")
            case 4: return home + (isChinese ? " / 设备数据库管理 / 设备列表" : " / Equipment Database / Equipment List")
            case 5: return home + (isChinese ? " / 设备数据库管理 / 设备分类管理" : " / Equipment Database / Category Management")
            case 6: 
                var clLoader = contentStack.children[6]
                if (clLoader && clLoader.item) {
                    var currentModule = clLoader.item.currentModule
                    switch(currentModule) {
                        case "data_management":
                            return home + (isChinese ? " / 模型持续学习 / 数据管理" : " / Model Training / Data Management")
                        case "model_training":
                            return home + (isChinese ? " / 模型持续学习 / 模型训练" : " / Model Training / Model Training")
                        case "model_testing":
                            return home + (isChinese ? " / 模型持续学习 / 模型测试" : " / Model Training / Model Testing")
                        default:
                            return home + (isChinese ? " / 模型持续学习" : " / Model Training")
                    }
                }
                return home + (isChinese ? " / 模型持续学习" : " / Model Training")
            default: return home
        }
    }
    
    // 设置持续学习页面模块的函数
    function setContinuousLearningModule(module) {
        console.log("setContinuousLearningModule called with module:", module)
        
        // 首先尝试直接访问
        var clLoader = contentStack.children[6]
        if (clLoader && clLoader.item) {
            console.log("直接设置 ContinuousLearningPage 的属性")
            clLoader.item.currentProjectId = currentProjectId
            clLoader.item.isChinese = isChinese
            clLoader.item.currentModule = module
            console.log("设置 currentModule 为:", module)
            return
        }
        
        // 如果页面还没加载完成，将模块存储为待设置状态
        if (clLoader) {
            console.log("页面还在加载中，设置待处理模块:", module)
            clLoader.pendingModule = module
            return
        }
        
        console.log("警告: 无法找到 ContinuousLearning Loader")
    }
}
