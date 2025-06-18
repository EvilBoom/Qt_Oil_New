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

    // 连接LoginController的语言变化信号
    Connections {
        target: loginController
        function onLanguageChanged(chinese) {
            mainWindow.isChinese = chinese
        }
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
                                    {"title": isChinese ? "生产参数录入" : "Production Parameters", "action": "production-params"},
                                    {"title": isChinese ? "设备推荐" : "Equipment Recommendation", "action": "device-recommend"},
                                    {"title": isChinese ? "选型报告生成" : "Selection Report", "action": "report-generate"}
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
                                    {"title": isChinese ? "设备列表" : "Equipment List", "action": "device-list"},
                                    {"title": isChinese ? "添加设备" : "Add Equipment", "action": "add-device"},
                                    {"title": isChinese ? "设备分类管理" : "Category Management", "action": "device-category"}
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
                                    {"title": isChinese ? "选择预测任务" : "Select Task", "action": "select-task"},
                                    {"title": isChinese ? "训练数据管理" : "Training Data", "action": "training-data"},
                                    {"title": isChinese ? "特征工程" : "Feature Engineering", "action": "feature-engineering"},
                                    {"title": isChinese ? "训练监控" : "Training Monitor", "action": "training-monitor"}
                                ]
                                onSubItemClicked: function(action) {
                                    handleNavigation(action)
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

                    // 其他页面占位
                    Rectangle {
                        color: "#f5f7fa"
                        Text {
                            anchors.centerIn: parent
                            text: isChinese ? "油井信息页面" : "Well Information Page"
                            font.pixelSize: 24
                            color: "#666"
                        }
                    }

                    Rectangle {
                        color: "#f5f7fa"
                        Text {
                            anchors.centerIn: parent
                            text: isChinese ? "设备推荐页面" : "Equipment Recommendation Page"
                            font.pixelSize: 24
                            color: "#666"
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
            if (item && typeof item.open === 'function') {
                item.open()
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

    // 导航处理函数
    function handleNavigation(action) {
        console.log("Navigation to:", action)

        switch(action) {
            case "production-params":
                showDialog("ProductionParamsDialog.qml")
                break
            case "add-device":
                showDialog("AddDeviceDialog.qml")
                break
            case "select-task":
                showDialog("SelectTaskDialog.qml")
                break
            case "well-info":
                currentPageIndex = 1
                break
            case "device-recommend":
                currentPageIndex = 2
                break
            default:
                console.log("Unknown action:", action)
        }
    }

    // 显示对话框
    function showDialog(dialogFile) {
        dialogLoader.source = dialogFile
        dialogLoader.active = true
    }

    // 获取面包屑导航文字
    function getBreadcrumb() {
        var home = isChinese ? "首页" : "Home"
        switch(currentPageIndex) {
            case 0: return home + (isChinese ? " / 系统概览" : " / Dashboard")
            case 1: return home + (isChinese ? " / 油井信息管理" : " / Well Information")
            case 2: return home + (isChinese ? " / 设备选型推荐" : " / Equipment Selection")
            default: return home
        }
    }
}
