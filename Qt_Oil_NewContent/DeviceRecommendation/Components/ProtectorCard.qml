// Qt_Oil_NewContent/DeviceRecommendation/Components/ProtectorCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    // 正确的保护器卡片属性
    property var protectorData: null
    property bool isSelected: false
    property int matchScore: 50
    property real requiredThrust: 0
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
        anchors.margins: 8
        width: 60
        height: 24
        radius: 12
        color: Material.accent
        visible: matchScore >= 80

        Text {
            anchors.centerIn: parent
            text: isChineseMode ? "推荐" : "Best"
            color: "white"
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // 头部信息
        RowLayout {
            Layout.fillWidth: true

            // 图标
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: Material.color(Material.Blue)

                Text {
                    anchors.centerIn: parent
                    text: "🛡️"
                    font.pixelSize: 20
                }
            }

            // 标题信息
            Column {
                Layout.fillWidth: true

                Text {
                    text: protectorData ? protectorData.manufacturer : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }

                Text {
                    text: protectorData ? protectorData.model : ""
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.primaryTextColor
                }

                Text {
                    text: protectorData ? protectorData.type : ""
                    font.pixelSize: 12
                    color: Material.secondaryTextColor
                }
            }

            // 匹配度
            CircularProgress {
                width: 40
                height: 40
                value: matchScore / 100

                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }

        // 关键参数
        Grid {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 8

            // 推力承载能力
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "推力承载" : "Thrust Capacity"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Row {
                    spacing: 4

                    Text {
                        text: (protectorData ? protectorData.thrustCapacity : 0) + " lbs"
                        font.pixelSize: 12
                        font.bold: true
                        color: getThrustColor()
                    }

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: getThrustColor()
                        anchors.verticalCenter: parent.verticalCenter
                        visible: requiredThrust > 0

                        Text {
                            anchors.centerIn: parent
                            text: getThrustIcon()
                            font.pixelSize: 8
                            color: "white"
                        }
                    }
                }
            }

            // 最高温度
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "最高温度" : "Max Temp"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Text {
                    text: (protectorData ? protectorData.maxTemperature : 0) + " °F"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }

            // 密封类型
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "密封类型" : "Seal Type"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Text {
                    text: protectorData ? protectorData.sealType : ""
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }

            // 外径
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "外径" : "OD"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Text {
                    text: (protectorData ? protectorData.outerDiameter : 0) + " in"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }

        // 特性描述
        Text {
            Layout.fillWidth: true
            text: protectorData ? protectorData.features : ""
            font.pixelSize: 11
            color: Material.secondaryTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // 选中效果
    Rectangle {
        anchors.fill: parent
        color: Material.accent
        opacity: 0.1
        radius: parent.radius
        visible: isSelected
    }

    // 辅助函数
    function getThrustColor() {
        if (!protectorData || requiredThrust === 0) return Material.primaryTextColor

        if (protectorData.thrustCapacity >= requiredThrust) {
            return Material.color(Material.Green)
        } else {
            return Material.color(Material.Red)
        }
    }

    function getThrustIcon() {
        if (!protectorData || requiredThrust === 0) return ""

        if (protectorData.thrustCapacity >= requiredThrust) {
            return "✓"
        } else {
            return "✗"
        }
    }
}


