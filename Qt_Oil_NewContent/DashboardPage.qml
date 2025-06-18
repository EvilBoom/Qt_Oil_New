import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: dashboardPage
    color: "#f5f7fa"

    // 添加语言属性，从父窗口继承
    property bool isChinese: parent && parent.parent && parent.parent.parent ? parent.parent.parent.parent.isChinese : true

    signal quickAction(string action)

    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width

        ColumnLayout {
            width: parent.width
            spacing: 24

            // 快速操作区
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 24
                Layout.preferredHeight: 120
                radius: 12
                color: "white"

                // 简单阴影效果
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
                            onClicked: dashboardPage.quickAction("production-params")
                        }

                        QuickActionButton {
                            text: isChinese ? "设备选型推荐" : "Equipment Selection"
                            icon: "🔍"
                            isPrimary: true
                            onClicked: dashboardPage.quickAction("device-recommend")
                        }

                        QuickActionButton {
                            text: isChinese ? "生成选型报告" : "Generate Report"
                            icon: "📊"
                            isPrimary: false
                            onClicked: dashboardPage.quickAction("report-generate")
                        }

                        QuickActionButton {
                            text: isChinese ? "添加新设备" : "Add Equipment"
                            icon: "📦"
                            isPrimary: false
                            onClicked: dashboardPage.quickAction("add-device")
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // 功能模块网格
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
                    gradientColor1: "#f093fb"
                    gradientColor2: "#f5576c"
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
                    onClicked: dashboardPage.quickAction("device-list")
                }

                FunctionCard {
                    title: isChinese ? "智能学习平台" : "AI Learning Platform"
                    description: isChinese ?
                        "持续优化推荐模型，提升设备选型准确性" :
                        "Continuously optimize recommendation models to improve selection accuracy"
                    iconText: "🤖"
                    gradientColor1: "#fa709a"
                    gradientColor2: "#fee140"
                    onClicked: dashboardPage.quickAction("training-monitor")
                }
            }

            // 统计信息
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.bottomMargin: 24
                spacing: 20

                StatCard {
                    value: "156"
                    label: isChinese ? "在管油井数量" : "Active Wells"
                }

                StatCard {
                    value: "1,234"
                    label: isChinese ? "设备型号总数" : "Equipment Models"
                }

                StatCard {
                    value: "89%"
                    label: isChinese ? "选型准确率" : "Selection Accuracy"
                }

                StatCard {
                    value: "42"
                    label: isChinese ? "本月选型报告" : "Monthly Reports"
                }
            }
        }
    }
}
