// Qt_Oil_NewContent/DeviceRecommendation/Components/StepIndicator.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var steps: []
    property int currentStep: 0
    // property color activeColor: Material.accent
    // property color inactiveColor: Material.hintTextColor
    // property color completedColor: Material.primaryColor
    property color activeColor: "#2196F3"  // 蓝色
    property color inactiveColor: "#9E9E9E" // 灰色
    property color completedColor: "#4CAF50" // 绿色

    signal stepClicked(int index)

    color: Material.background

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Material.dividerColor
    }

    // 单行显示所有步骤
    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: steps.length

            Row {
                spacing: 0

                // 步骤项
                Rectangle {
                    width: stepContent.width + 12
                    height: 60
                    color: "transparent"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.stepClicked(index)
                        enabled: index <= currentStep + 1
                    }

                    Column {
                        id: stepContent
                        anchors.centerIn: parent
                        spacing: 4

                        // 步骤圆圈
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: {
                                if (index < currentStep) return completedColor
                                if (index === currentStep) return activeColor
                                return "transparent"
                            }
                            border.width: 2
                            border.color: {
                                if (index <= currentStep) return "transparent"
                                return inactiveColor
                            }

                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (index < currentStep) return "✓"
                                    return (index + 1).toString()
                                }
                                color: {
                                    if (index <= currentStep) return "white"
                                    return inactiveColor
                                }
                                font.pixelSize: 12
                                font.bold: index === currentStep
                            }
                        }

                        // 简化的步骤文本
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: getSimplifiedTitle(index)
                            color: {
                                if (index <= currentStep) return Material.primaryTextColor
                                return inactiveColor
                            }
                            font.pixelSize: 11
                            font.bold: index === currentStep
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // 当前步骤显示下划线
                        Rectangle {
                            width: parent.width
                            height: 2
                            color: activeColor
                            visible: index === currentStep
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // 连接线（最后一个步骤后不显示）
                Rectangle {
                    width: 20
                    height: 2
                    color: index < steps.length - 1 ?
                           (index < currentStep ? completedColor : inactiveColor) :
                           "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: index < steps.length - 1
                }
            }
        }
    }

    // 简化标题的函数
    function getSimplifiedTitle(index) {
        if (index >= steps.length) return ""

        var step = steps[index]
        var title = step.title

        // 根据中英文模式简化标题
        if (title.includes("生产参数录入") || title.includes("Production Parameters")) {
            return "参数录入"
        } else if (title.includes("预测与IPR曲线") || title.includes("Prediction & IPR Curve")) {
            return "预测分析"
        } else if (title.includes("举升方式选择") || title.includes("Lift Method Selection")) {
            return "举升方式"
        } else if (title.includes("泵型选择") || title.includes("Pump Selection")) {
            return "泵型选择"
        } else if (title.includes("分离器选择") || title.includes("Separator Selection")) {
            return "分离器"
        } else if (title.includes("保护器选择") || title.includes("Protector Selection")) {
            return "保护器"
        } else if (title.includes("电机选择") || title.includes("Motor Selection")) {
            return "电机选择"
        } else if (title.includes("选型报告") || title.includes("Selection Report")) {
            return "选型报告"
        }

        return title
    }
}
