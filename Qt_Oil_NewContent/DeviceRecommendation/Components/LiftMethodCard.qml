import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    property var methodData: null
    property bool isSelected: false
    property int matchScore: 50
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性

    signal clicked()

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
        }
    }

    color: isSelected ? '#F5F5DC' : Material.backgroundColor
    radius: 8
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.DeepPurple : Material.Brown

    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -8
        width: 80
        height: 28
        radius: 14
        color: Material.DeepPurple
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

            // 匹配度
            Rectangle {
                id: progressContainer
                width: 48
                height: 48
                color: Material.backgroundColor
                radius: 4
                border.width: 1
                border.color: Material.dividerColor

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

        // 🔥 修改优缺点显示，添加单位转换
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
                            text: convertTextUnits(methodData.advantages[index])  // 🔥 转换文本中的单位
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
                    color: Material.color(Material.Blue)
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
                            text: convertTextUnits(methodData.limitations[index])  // 🔥 转换文本中的单位
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

            text: {
                if (isSelected) {
                    return (isChineseMode ? "✓ 已选择" : "✓ Selected")
                } else if (matchScore >= 80) {
                    return (isChineseMode ? "🌟 选择此方案" : "🌟 Select This")
                } else {
                    return (isChineseMode ? "选择" : "Select")
                }
            }

            Material.background: {
                if (isSelected) {
                    return Material.Green
                } else if (matchScore >= 80) {
                    return Material.color(Material.Blue)
                } else {
                    return Material.Gray
                }
            }

            Material.foreground: "white"
            Material.roundedScale: Material.MediumScale

            font.pixelSize: 14
            font.bold: isSelected

            onClicked: {
                console.log("=== Select button clicked ===")
                root.clicked()
            }

        }
    }

    // 🔥 添加单位转换函数
    function convertTextUnits(text) {
        if (!text || typeof text !== "string") return text

        var convertedText = text

        if (root.isMetric) {
            // 英制 → 公制转换
            // 流量: bbl/d → m³/d
            convertedText = convertedText.replace(/(\d+(?:-\d+)?)\s*bbl\/d/g, function(match, range) {
                if (range.includes("-")) {
                    var parts = range.split("-")
                    var min = (parseFloat(parts[0]) * 0.159).toFixed(0)
                    var max = (parseFloat(parts[1]) * 0.159).toFixed(0)
                    return min + "-" + max + " m³/d"
                } else {
                    var converted = (parseFloat(range) * 0.159).toFixed(0)
                    return converted + " m³/d"
                }
            })

            // 深度: ft → m
            convertedText = convertedText.replace(/(\d+(?:,\d+)?)\s*ft/g, function(match, value) {
                var numValue = parseFloat(value.replace(/,/g, ""))
                var converted = (numValue * 0.3048).toFixed(0)
                return converted.toLocaleString() + " m"
            })

            // 温度: °F → °C
            convertedText = convertedText.replace(/(\d+)\s*°F/g, function(match, value) {
                var converted = ((parseFloat(value) - 32) * 5/9).toFixed(0)
                return converted + " °C"
            })

            // 压力: psi → kPa
            convertedText = convertedText.replace(/(\d+(?:,\d+)?)\s*psi/g, function(match, value) {
                var numValue = parseFloat(value.replace(/,/g, ""))
                var converted = (numValue * 6.895).toFixed(0)
                return converted.toLocaleString() + " kPa"
            })
        }
        // 如果是英制，不需要转换（数据库中本来就是英制）

        return convertedText
    }

    Component.onCompleted: {
        console.log("=== LiftMethodCard completed with isMetric:", root.isMetric)
    }
}
