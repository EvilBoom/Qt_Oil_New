import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // 添加语言属性
    property bool isChinese: parent && parent.parent ? parent.parent.isChinese : true
    property int selectedTask: -1

    Dialog {
        id: dialog
        width: 700
        height: 500
        modal: true
        anchors.centerIn: parent

        // 自定义标题栏
        header: Rectangle {
            height: 60
            color: "#1e3a5f"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 16

                Text {
                    text: root.isChinese ? "选择预测任务" : "Select Prediction Task"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                RoundButton {
                    width: 32
                    height: 32

                    background: Rectangle {
                        radius: width / 2
                        color: parent.hovered ? Qt.rgba(255, 255, 255, 0.2) : "transparent"
                    }

                    contentItem: Text {
                        text: "✕"
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: dialog.close()
                }
            }
        }

        // 内容区域
        contentItem: Rectangle {
            color: "#f5f7fa"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 24
                contentWidth: parent.width - 48

                ColumnLayout {
                    width: parent.width
                    spacing: 20

                    // 任务说明
                    Text {
                        Layout.fillWidth: true
                        text: root.isChinese ?
                            "请选择要执行的机器学习任务类型，系统将根据您的选择准备相应的训练数据和模型。" :
                            "Please select the type of machine learning task to execute. The system will prepare corresponding training data and models based on your selection."
                        wrapMode: Text.WordWrap
                        color: "#666"
                        font.pixelSize: 14
                        lineHeight: 1.4
                    }

                    // 任务选项
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        // 产能预测
                        TaskOptionCard {
                            Layout.fillWidth: true
                            taskId: 0
                            title: root.isChinese ? "产能预测模型" : "Production Forecast Model"
                            description: root.isChinese ?
                                "基于历史生产数据和油井参数，预测未来产能变化趋势，帮助制定生产计划。" :
                                "Predict future production trends based on historical data and well parameters to help with production planning."
                            icon: "📈"
                            isSelected: root.selectedTask === 0
                            onClicked: root.selectedTask = 0
                        }

                        // 设备故障预测
                        TaskOptionCard {
                            Layout.fillWidth: true
                            taskId: 1
                            title: root.isChinese ? "设备故障预测" : "Equipment Failure Prediction"
                            description: root.isChinese ?
                                "分析设备运行数据，预测可能发生故障的时间和类型，实现预防性维护。" :
                                "Analyze equipment operation data to predict failure time and type for preventive maintenance."
                            icon: "🔧"
                            isSelected: root.selectedTask === 1
                            onClicked: root.selectedTask = 1
                        }

                        // 选型优化
                        TaskOptionCard {
                            Layout.fillWidth: true
                            taskId: 2
                            title: root.isChinese ? "选型优化模型" : "Selection Optimization Model"
                            description: root.isChinese ?
                                "优化设备选型推荐算法，提高推荐准确率和适配性。" :
                                "Optimize equipment selection recommendation algorithm to improve accuracy and adaptability."
                            icon: "🎯"
                            isSelected: root.selectedTask === 2
                            onClicked: root.selectedTask = 2
                        }

                        // 能耗优化
                        TaskOptionCard {
                            Layout.fillWidth: true
                            taskId: 3
                            title: root.isChinese ? "能耗优化分析" : "Energy Optimization Analysis"
                            description: root.isChinese ?
                                "分析设备能耗数据，识别节能潜力，提供优化建议。" :
                                "Analyze equipment energy consumption data, identify energy-saving potential, and provide optimization suggestions."
                            icon: "⚡"
                            isSelected: root.selectedTask === 3
                            onClicked: root.selectedTask = 3
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // 底部按钮
        footer: Rectangle {
            height: 60
            color: "white"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#e0e0e0"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: root.isChinese ? "取消" : "Cancel"
                    flat: true

                    contentItem: Text {
                        text: parent.text
                        color: "#666"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#f5f5f5" : "transparent"
                        border.color: "#ddd"
                        border.width: 1
                        radius: 6
                    }

                    onClicked: dialog.close()
                }

                Button {
                    text: root.isChinese ? "下一步" : "Next"
                    enabled: root.selectedTask >= 0

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? "#357abd" : "#4a90e2") : "#cccccc"
                        radius: 6
                    }

                    onClicked: {
                        selectTask()
                        dialog.close()
                    }
                }
            }
        }
    }

    // 任务选项卡片组件
    component TaskOptionCard: Rectangle {
        property int taskId: 0
        property string title: ""
        property string description: ""
        property string icon: ""
        property bool isSelected: false

        signal clicked()

        height: 100
        color: "white"
        radius: 8
        border.width: isSelected ? 2 : 1
        border.color: isSelected ? "#4a90e2" : "#e0e0e0"

        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // 图标
            Rectangle {
                width: 48
                height: 48
                radius: 12
                color: isSelected ? "#e8f0fe" : "#f5f7fa"

                Text {
                    anchors.centerIn: parent
                    text: icon
                    font.pixelSize: 24
                }
            }

            // 文本内容
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: title
                    font.pixelSize: 16
                    font.bold: true
                    color: "#2c3e50"
                }

                Text {
                    Layout.fillWidth: true
                    text: description
                    font.pixelSize: 13
                    color: "#666"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }
            }

            // 选中标记
            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: "transparent"
                border.width: 2
                border.color: isSelected ? "#4a90e2" : "#ddd"

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    anchors.centerIn: parent
                    color: "#4a90e2"
                    visible: isSelected
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: parent.clicked()

            onEntered: {
                if (!parent.isSelected) {
                    parent.color = "#fafafa"
                }
            }

            onExited: {
                parent.color = "white"
            }
        }
    }

    // 选择任务
    function selectTask() {
        var taskNames = [
            root.isChinese ? "产能预测模型" : "Production Forecast Model",
            root.isChinese ? "设备故障预测" : "Equipment Failure Prediction",
            root.isChinese ? "选型优化模型" : "Selection Optimization Model",
            root.isChinese ? "能耗优化分析" : "Energy Optimization Analysis"
        ]

        console.log(root.isChinese ? "选择的任务:" : "Selected task:", taskNames[root.selectedTask])
        // 这里调用后端API或导航到下一步
    }

    // 打开对话框
    function open() {
        dialog.open()
    }

    // 关闭对话框
    function close() {
        dialog.close()
    }
}
