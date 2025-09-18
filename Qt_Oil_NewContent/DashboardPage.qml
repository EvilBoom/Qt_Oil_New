import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: dashboardPage
    color: "#f5f7fa"

    // 添加语言属性，从父窗口继承
    property bool isChinese: parent && parent.parent && parent.parent.parent ? parent.parent.parent.parent.isChinese : true

    // 🔥 统计数据属性
    property var statisticsData: ({
        "activeWells": 0,
        "equipmentModels": 0,
        "selectionAccuracy": 0.0,
        "monthlyReports": 0
    })

    signal quickAction(string action)

    // 🔥 连接统计数据控制器
    Connections {
        target: dashboardController
        enabled: dashboardController !== undefined

        function onStatisticsUpdated(stats) {
            console.log("仪表盘统计数据更新:", JSON.stringify(stats))
            statisticsData = stats
        }

        function onError(errorMsg) {
            console.error("仪表盘统计数据错误:", errorMsg)
        }
    }

    // 🔥 组件加载完成后刷新统计数据
    Component.onCompleted: {
        console.log("Dashboard页面加载完成")
        if (typeof dashboardController !== 'undefined' && dashboardController) {
            dashboardController.refreshStatistics()
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width

        ColumnLayout {
            width: parent.width
            spacing: 24

            // 项目信息和新建项目按钮
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 24
                Layout.preferredHeight: 80
                radius: 12
                color: "white"

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.leftMargin: 2
                    radius: parent.radius
                    color: "#10000000"
                    z: -1
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Column {
                        spacing: 8

                        Text {
                            text: isChinese ? "当前项目" : "Current Project"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#2c3e50"
                        }

                        Text {
                            text: {
                                // 🔥 从 MainWindow 获取当前项目名称
                                if (typeof mainWindow !== 'undefined' && mainWindow.currentProjectName) {
                                    return mainWindow.currentProjectName
                                }
                                return isChinese ? "未选择项目" : "No Project Selected"
                            }
                            font.pixelSize: 14
                            color: "#666"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: isChinese ? "➕ 新建项目" : "➕ New Project"
                        Material.background: "#4CAF50"
                        Material.foreground: "white"
                        font.bold: true
                        
                        onClicked: {
                            console.log("新建项目按钮被点击")
                            dashboardPage.quickAction("new-project")
                        }
                    }

                    // 🔥 添加切换项目按钮
                    // Button {
                    //     text: isChinese ? "🔄 切换项目" : "🔄 Switch Project"
                    //     Material.background: "#2196F3"
                    //     Material.foreground: "white"
                        
                    //     onClicked: {
                    //         console.log("切换项目按钮被点击")
                    //         dashboardPage.quickAction("switch-project")
                    //     }
                    // }
                }
            }

            // 快速操作区 (保持不变)
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 24
                Layout.preferredHeight: 120
                radius: 12
                color: "white"

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.leftMargin: 2
                    radius: parent.radius
                    color: "#10000000"
                    z: -1
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    Text {
                        text: isChinese ? "快速操作" : "Quick Actions"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#2c3e50"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        QuickActionButton {
                            text: isChinese ? "录入生产参数" : "Input Parameters"
                            icon: "➕"
                            isPrimary: true
                            onClicked: dashboardPage.quickAction("well-info")
                        }

                        QuickActionButton {
                            text: isChinese ? "设备选型推荐" : "Equipment Selection"
                            icon: "🔍"
                            isPrimary: true
                            onClicked: dashboardPage.quickAction("device-recommend")
                        }

                        QuickActionButton {
                            text: isChinese ? "设备数据管理" : "Device Management"
                            icon: "💾"
                            isPrimary: false
                            onClicked: dashboardPage.quickAction("equipment-manage")
                        }

                        QuickActionButton {
                            text: isChinese ? "模型训练" : "Model Training"
                            icon: "🤖"
                            isPrimary: false
                            onClicked: dashboardPage.quickAction("continuous-learning-main")
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // 功能模块网格 (保持不变)
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                columns: 2
                rowSpacing: 20
                columnSpacing: 20

                FunctionCard {
                    title: isChinese ? "油井信息管理" : "Well Information"
                    description: isChinese ?
                        "管理油井基本信息、井身结构参数，维护油井档案数据库" :
                        "Manage well information, structure parameters, and maintain well database"
                    iconText: "🛢️"
                    gradientColor1: "#667eea"
                    gradientColor2: "#764ba2"
                    onClicked: dashboardPage.quickAction("well-info")
                }

                FunctionCard {
                    title: isChinese ? "设备选型推荐" : "Equipment Selection"
                    description: isChinese ?
                        "基于油井参数智能推荐最适合的生产设备配置方案" :
                        "Intelligent equipment recommendation based on well parameters"
                    iconText: "📊"
                    gradientColor1: "#667eea"
                    gradientColor2: "#764ba2"
                    onClicked: dashboardPage.quickAction("device-recommend")
                }

                FunctionCard {
                    title: isChinese ? "设备数据库" : "Equipment Database"
                    description: isChinese ?
                        "管理各类油田设备信息，包括技术参数、性能指标等" :
                        "Manage equipment information including technical parameters and performance"
                    iconText: "💾"
                    gradientColor1: "#4facfe"
                    gradientColor2: "#00f2fe"
                    onClicked: dashboardPage.quickAction("equipment-manage")
                }

                FunctionCard {
                    title: isChinese ? "持续学习" : "AI Learning Platform"
                    description: isChinese ?
                        "持续优化推荐模型，提升设备选型准确性" :
                        "Continuously optimize recommendation models to improve selection accuracy"
                    iconText: "🤖"
                    gradientColor1: "#4facfe"
                    gradientColor2: "#00f2fe"
                    onClicked: dashboardPage.quickAction("continuous-learning-main")
                }
            }

            // 🔥 统计信息 - 使用真实数据
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
                spacing: 20

                StatCard {
                    value: statisticsData.activeWells ? statisticsData.activeWells.toString() : "0"
                    label: isChinese ? "在管油井数量" : "Active Wells"
                    iconText: "🛢️"
                    accentColor: "#3498db"
                }

                StatCard {
                    value: statisticsData.equipmentModels ? statisticsData.equipmentModels.toString() : "0"
                    label: isChinese ? "设备型号总数" : "Equipment Models"
                    iconText: "📦"
                    accentColor: "#2ecc71"
                }

                // StatCard {
                //     value: statisticsData.selectionAccuracy ? statisticsData.selectionAccuracy.toFixed(1) + "%" : "0%"
                //     label: isChinese ? "选型准确率" : "Selection Accuracy"
                //     iconText: "🎯"
                //     accentColor: "#e74c3c"
                // }

                StatCard {
                    value: statisticsData.monthlyReports ? statisticsData.monthlyReports.toString() : "0"
                    label: isChinese ? "本月选型报告" : "Monthly Reports"
                    iconText: "📊"
                    accentColor: "#f39c12"
                }
            }

            // 🔥 添加刷新按钮
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24

                Item { Layout.fillWidth: true }

                Button {
                    text: isChinese ? "🔄 刷新统计数据" : "🔄 Refresh Statistics"
                    Material.background: "#9b59b6"
                    Material.foreground: "white"
                    
                    onClicked: {
                        console.log("刷新统计数据")
                        if (typeof dashboardController !== 'undefined' && dashboardController) {
                            dashboardController.refreshStatistics()
                        }
                    }
                }
            }
        }
    }

    // 组件定义 (保持不变)
    component QuickActionButton: Rectangle {
        property string text: "Button"
        property string icon: "📋"
        property bool isPrimary: true

        signal clicked()

        Layout.preferredWidth: 140
        Layout.preferredHeight: 60
        radius: 8
        color: isPrimary ? "#4a90e2" : "#ecf0f1"

        border.color: isPrimary ? "#357abd" : "#bdc3c7"
        border.width: 1

        opacity: mouseArea.pressed ? 0.8 : (mouseArea.containsMouse ? 0.9 : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: icon
                font.pixelSize: 20
                color: isPrimary ? "white" : "#2c3e50"
            }

            Text {
                text: parent.parent.text
                font.pixelSize: 12
                font.bold: true
                color: isPrimary ? "white" : "#2c3e50"
                wrapMode: Text.WordWrap
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    component FunctionCard: Rectangle {
        property string title: "Function"
        property string description: "Description"
        property string iconText: "📋"
        property string gradientColor1: "#4a90e2"
        property string gradientColor2: "#357abd"

        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 160
        radius: 12

        gradient: Gradient {
            GradientStop { position: 0.0; color: gradientColor1 }
            GradientStop { position: 1.0; color: gradientColor2 }
        }

        opacity: mouseArea1.pressed ? 0.8 : (mouseArea1.containsMouse ? 0.9 : 1.0)

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: iconText
                font.pixelSize: 36
                color: "white"
            }

            Text {
                text: title
                font.pixelSize: 18
                font.bold: true
                color: "white"
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: description
                font.pixelSize: 12
                color: "white"
                opacity: 0.9
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }

        MouseArea {
            id: mouseArea1
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }

    // 🔥 增强的 StatCard 组件
    component StatCard: Rectangle {
        property string value: "0"
        property string label: "Label"
        property string iconText: "📊"
        property string accentColor: "#3498db"

        Layout.fillWidth: true
        Layout.preferredHeight: 120
        radius: 12
        color: "white"

        border.color: "#e1e8ed"
        border.width: 1

        // 左侧彩色边条
        Rectangle {
            width: 4
            height: parent.height
            color: parent.accentColor
            radius: 2
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            // 图标区域
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                radius: 25
                color: parent.parent.accentColor + "20"  // 添加透明度

                Text {
                    anchors.centerIn: parent
                    text: iconText
                    font.pixelSize: 24
                    color: parent.parent.accentColor
                }
            }

            // 数据区域
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: value
                    font.pixelSize: 24
                    font.bold: true
                    color: "#2c3e50"
                }

                Text {
                    text: label
                    font.pixelSize: 12
                    color: "#7f8c8d"
                    wrapMode: Text.WordWrap
                }
            }
        }

        // 悬浮效果
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            
            onEntered: {
                parent.scale = 1.02
            }
            
            onExited: {
                parent.scale = 1.0
            }
        }

        Behavior on scale {
            NumberAnimation { duration: 150 }
        }
    }
}
