// Qt_Oil_NewContent/DeviceRecommendation/Components/PumpSelectionCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var pumpData: null
    property bool isSelected: false
    property int matchScore: 50
    property bool isChineseMode: true

    signal clicked()

    color: isSelected ? Material.accent : Material.backgroundColor
    border.color: isSelected ? Material.accent : Material.dividerColor
    border.width: isSelected ? 2 : 1
    radius: 8

    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -4
        width: 60
        height: 24
        radius: 12
        color: Material.color(Material.Green)
        visible: matchScore >= 80
        z: 1

        Text {
            anchors.centerIn: parent
            text: isChineseMode ? "推荐" : "Best"
            color: "white"
            font.pixelSize: 10
            font.bold: true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16  // 🔥 统一边距
        spacing: 12

        // 头部信息
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: pumpData ? pumpData.manufacturer : ""
                    font.pixelSize: 12
                    color: isSelected ? "white" : Material.secondaryTextColor
                }

                Text {
                    text: pumpData ? pumpData.model : ""
                    font.pixelSize: 16
                    font.bold: true
                    color: isSelected ? "white" : Material.primaryTextColor
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: pumpData ? pumpData.series + " Series" : ""
                    font.pixelSize: 11
                    color: isSelected ? "white" : Material.hintTextColor
                }
            }

            // 匹配度
            Rectangle {
                width: 50
                height: 50
                radius: 25
                color: "transparent"
                border.color: isSelected ? "white" : Material.accent
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: isSelected ? "white" : Material.accent
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: isSelected ? Qt.rgba(1,1,1,0.3) : Material.dividerColor
        }

        // 关键参数 - 使用更简洁的布局
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: isChineseMode ? "关键参数" : "Key Parameters"
                font.pixelSize: 13
                font.bold: true
                color: isSelected ? "white" : Material.primaryTextColor
            }

            // 🔥 使用Column + Row的简单布局
            Column {
                Layout.fillWidth: true
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: isChineseMode ? "流量:" : "Flow:"
                        font.pixelSize: 11
                        color: isSelected ? Qt.rgba(1,1,1,0.8) : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: pumpData ? pumpData.minFlow + "-" + pumpData.maxFlow + " bbl/d" : "N/A"
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "white" : Material.primaryTextColor
                        width: parent.width - 72
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: isChineseMode ? "扬程:" : "Head:"
                        font.pixelSize: 11
                        color: isSelected ? Qt.rgba(1,1,1,0.8) : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: pumpData ? pumpData.headPerStage + " ft/stage" : "N/A"
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "white" : Material.primaryTextColor
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: isChineseMode ? "效率:" : "Efficiency:"
                        font.pixelSize: 11
                        color: isSelected ? Qt.rgba(1,1,1,0.8) : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: pumpData ? pumpData.efficiency + "%" : "N/A"
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "white" : "#4CAF50"
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: isChineseMode ? "外径:" : "OD:"
                        font.pixelSize: 11
                        color: isSelected ? Qt.rgba(1,1,1,0.8) : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: pumpData ? pumpData.outerDiameter + " in" : "N/A"
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "white" : Material.primaryTextColor
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // 选择按钮
        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 36

            text: isSelected ?
                  (isChineseMode ? "✓ 已选择" : "✓ Selected") :
                  (isChineseMode ? "选择此泵" : "Select Pump")

            Material.background: isSelected ? "white" : Material.accent
            Material.foreground: isSelected ? Material.accent : "white"
            font.pixelSize: 12
            font.bold: true

            onClicked: {
                console.log("泵选择按钮被点击:", pumpData ? pumpData.model : "unknown")
                root.clicked()
            }
        }
    }

    // 整体点击区域（作为备用）
    MouseArea {
        anchors.fill: parent
        onClicked: {
            console.log("泵卡片被点击:", pumpData ? pumpData.model : "unknown")
            root.clicked()
        }
        z: -1  // 确保按钮可以接收点击
    }
}
