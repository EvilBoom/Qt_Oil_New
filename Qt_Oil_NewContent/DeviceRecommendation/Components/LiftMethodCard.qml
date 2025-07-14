// Qt_Oil_NewContent/DeviceRecommendation/Components/LiftMethodCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var methodData: null
    property bool isSelected: false
    property int matchScore: 50
    property bool isChineseMode: true

    signal clicked()

    color: isSelected ? Material.dialogColor : Material.backgroundColor
    radius: 8
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.accent : Material.dividerColor

    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -8
        width: 80
        height: 28
        radius: 14
        color: Material.accent
        visible: matchScore >= 80
        z: 1

        Text {
            anchors.centerIn: parent
            text: isChineseMode ? "推荐" : "Recommended"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
    }
  
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        // 添加测试按钮
        // Button {
        //     Layout.fillWidth: true
        //     text: "测试点击 - " + (methodData ? methodData.name : "Unknown")

        //     onClicked: {
        //         console.log("=== Button clicked ===")
        //         root.clicked()
        //     }
        // }
        // 头部
        RowLayout {
            Layout.fillWidth: true

            // 图标
            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: methodData ? methodData.color : "#ccc"

                Text {
                    anchors.centerIn: parent
                    text: methodData ? methodData.icon : ""
                    font.pixelSize: 24
                }
            }

            // 标题
            Column {
                Layout.fillWidth: true

                Text {
                    text: methodData ? methodData.name : ""
                    font.pixelSize: 16
                    font.bold: true
                    color: Material.primaryTextColor
                }

                Text {
                    text: methodData ? methodData.shortName : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }
            }

            // 匹配度 - 修复作用域问题
            Rectangle {
                id: progressContainer
                width: 48
                height: 48
                color: Material.backgroundColor
                radius: 4
                border.width: 1
                border.color: Material.dividerColor

                // 将属性定义在这里，确保作用域正确
                readonly property real progressValue: matchScore / 100
                readonly property color progressColor: {
                    if (progressValue >= 0.8) return Material.color(Material.Green)
                    if (progressValue >= 0.6) return Material.color(Material.Orange)
                    return Material.color(Material.Red)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: matchScore + "%"
                        font.pixelSize: 12
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    // 简单的线性进度条
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36
                        height: 4
                        color: Qt.rgba(0, 0, 0, 0.1)
                        radius: 2

                        Rectangle {
                            width: parent.width * progressContainer.progressValue
                            height: parent.height
                            color: progressContainer.progressColor
                            radius: parent.radius

                            Behavior on width {
                                NumberAnimation { duration: 300 }
                            }
                        }
                    }
                }
            }
        }

        // 描述
        Text {
            Layout.fillWidth: true
            text: methodData ? methodData.description : ""
            font.pixelSize: 13
            color: Material.secondaryTextColor
            wrapMode: Text.Wrap
            lineHeight: 1.3
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }

        // 优缺点
        Row {
            Layout.fillWidth: true
            spacing: 12

            // 优点
            Column {
                width: (parent.width - 12) / 2
                spacing: 4

                Text {
                    text: isChineseMode ? "优点" : "Advantages"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.color(Material.Green)
                }

                Repeater {
                    model: methodData ? (methodData.advantages.length > 2 ? 2 : methodData.advantages.length) : 0

                    Row {
                        spacing: 4

                        Text {
                            text: "•"
                            font.pixelSize: 11
                            color: Material.color(Material.Green)
                        }

                        Text {
                            width: parent.parent.width - 12
                            text: methodData.advantages[index]
                            font.pixelSize: 11
                            color: Material.secondaryTextColor
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // 限制
            Column {
                width: (parent.width - 12) / 2
                spacing: 4

                Text {
                    text: isChineseMode ? "限制" : "Limitations"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.color(Material.Orange)
                }

                Repeater {
                    model: methodData ? (methodData.limitations.length > 2 ? 2 : methodData.limitations.length) : 0

                    Row {
                        spacing: 4

                        Text {
                            text: "•"
                            font.pixelSize: 11
                            color: Material.color(Material.Orange)
                        }

                        Text {
                            width: parent.parent.width - 12
                            text: methodData.limitations[index]
                            font.pixelSize: 11
                            color: Material.secondaryTextColor
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
        // 间隔弹簧，将按钮推到底部
        Item {
            Layout.fillHeight: true
        }
        // 选择按钮
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            // 根据选中状态和匹配度设置按钮文本和样式
            text: {
                if (isSelected) {
                    return (isChineseMode ? "✓ 已选择" : "✓ Selected")
                } else if (matchScore >= 80) {
                    return (isChineseMode ? "🌟 选择此方案" : "🌟 Select This")
                } else {
                    return (isChineseMode ? "选择" : "Select")
                }
            }

            // 动态设置按钮样式
            Material.background: {
                if (isSelected) {
                    return Material.accent
                } else if (matchScore >= 80) {
                    return Material.color(Material.Green)
                } else {
                    return Material.primary
                }
            }

            Material.foreground: "white"

            // 按钮圆角
            Material.roundedScale: Material.MediumScale

            // 字体设置
            font.pixelSize: 14
            font.bold: isSelected

            // 按钮状态动画
            // Behavior on Material.background {
            //     ColorAnimation { duration: 200 }
            // }

            // 点击事件
            onClicked: {
                console.log("=== Select button clicked ===")
                root.clicked()
            }

            // 悬停效果
            // HoverHandler {
            //     id: hoverHandler
            // }

            // 根据悬停状态调整透明度
            // opacity: hoverHandler.hovered ? 0.9 : 1.0

            // Behavior on opacity {
            //     NumberAnimation { duration: 150 }
            // }
        }
    }


    // MouseArea {
    //     id: mainMouseArea
    //     anchors.fill: parent
    //     // cursorShape: Qt.PointingHandCursor
    //     // onClicked: root.clicked()
    //     onClicked: {
    //         // console.log("LiftMethodCard clicked:", methodData ? methodData.name : "unknown")
    //         console.log("has actual clicked")
    //         root.clicked()
    //     }

    // }
    Component.onCompleted: {
         console.log("=== LiftMethodCard completed")
    }

    // 选中效果 - 整个卡片的高亮边框
    // Rectangle {
    //     anchors.fill: parent
    //     color: "transparent"
    //     radius: parent.radius
    //     border.width: isSelected ? 3 : 0
    //     border.color: Material.accent

    //     Behavior on border.width {
    //         NumberAnimation { duration: 200 }
    //     }
    // }

    // 悬停效果
    // Rectangle {
    //     id: hoverEffect
    //     anchors.fill: parent
    //     color: Material.primaryTextColor
    //     opacity: 0
    //     radius: parent.radius

    //     NumberAnimation on opacity {
    //         id: hoverAnimation
    //         to: 0.05
    //         duration: 200
    //         running: false

    //         onStopped: {
    //             if (!parent.containsMouse) {
    //                 hoverEffect.opacity = 0
    //             }
    //         }
    //     }
    // }
}
