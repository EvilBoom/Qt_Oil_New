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
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    signal clicked()

    color: isSelected ? '#F5F5DC' : Material.backgroundColor
    border.color: isSelected ? Material.DeepPurple : Material.Brown
    border.width: isSelected ? 2 : 1
    radius: 8

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("PumpSelectionCard中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }
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
                    color: isSelected ? "black" : Material.secondaryTextColor
                }

                Text {
                    text: pumpData ? pumpData.model : ""
                    font.pixelSize: 16
                    font.bold: true
                    color: isSelected ? "black" : Material.primaryTextColor
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: pumpData ? pumpData.series + " Series" : ""
                    font.pixelSize: 11
                    color: isSelected ? "black" : Material.hintTextColor
                }
            }

            // 匹配度
            Rectangle {
                width: 50
                height: 50
                radius: 25
                color: "transparent"
                border.color: isSelected ? "black" : Material.Blue
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: isSelected ? "black" : Material.Blue
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
                color: isSelected ? "black" : Material.primaryTextColor
            }

            // 🔥 使用Column + Row的简单布局
            Column {
                Layout.fillWidth: true
                spacing: 6

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        font.pixelSize: 11
                        color: isSelected ? "black" : Material.secondaryTextColor
                        text: "流量:"
                        width: 60
                    }
                    Text {
                        text: {
                            if (!pumpData) return "N/A"
                            return formatFlowRange(pumpData.minFlow, pumpData.maxFlow)
                        }
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "black" : Material.primaryTextColor
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
                        color: isSelected ? "black" : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: {
                            if (!pumpData) return "N/A"
                            return formatHeadPerStage(pumpData.headPerStage)
                        }
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "black" : Material.primaryTextColor
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: isChineseMode ? "效率:" : "Efficiency:"
                        font.pixelSize: 11
                        color: isSelected ? "black" : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: pumpData ? pumpData.efficiency + "%" : "N/A"
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "black" : "#4CAF50"
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    Text {
                        text: isChineseMode ? "外径:" : "OD:"
                        font.pixelSize: 11
                        color: isSelected ? "black" : Material.secondaryTextColor
                        width: 60
                    }
                    Text {
                        text: {
                            if (!pumpData) return "N/A"
                            return formatDiameter(pumpData.outerDiameter)
                        }
                        font.pixelSize: 11
                        font.bold: true
                        color: isSelected ? "black" : Material.primaryTextColor
                    }
                }
                // 🔥 可选：添加最大级数显示
                // Row {
                //     width: parent.width
                //     spacing: 12

                //     Text {
                //         text: isChineseMode ? "级数:" : "Max Stages:"
                //         font.pixelSize: 11
                //         color: isSelected ? "black" : Material.secondaryTextColor
                //         width: 60
                //     }
                //     Text {
                //         text: pumpData ? pumpData.maxStages + (isChineseMode ? " 级" : " stages") : "N/A"
                //         font.pixelSize: 11
                //         font.bold: true
                //         color: isSelected ? "black" : Material.primaryTextColor
                //     }
                // }
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

            Material.background: isSelected ? "white" : Material.Green
            Material.foreground: isSelected ? Material.Green : "white"
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
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatFlowRange(minFlow, maxFlow) {
        if (!minFlow || !maxFlow) return "N/A"

        if (!isMetric) {
            // 转换为 m³/d
            var minM3 = minFlow / 0.159
            var maxM3 = maxFlow / 0.159
            return minM3.toFixed(0) + "-" + maxM3.toFixed(0) + " bbl/d"
        } else {
            // 保持 bbl/d
            return minFlow + "-" + maxFlow + " m³/d"
        }
    }

    function formatHeadPerStage(headPerStage) {
        if (!headPerStage) return "N/A"

        if (!isMetric) {
            // 转换为 m/级
            var mPerStage = headPerStage / 0.3048
            return mPerStage.toFixed(1) + " " + (isChineseMode ? "ft/级" : "ft/stage")
        } else {
            // 保持 ft/stage
            return headPerStage + " " + (isChineseMode ? "m/级" : "m/stage")
        }
    }

    function formatDiameter(diameter) {
        if (!diameter) return "N/A"

        if (!isMetric) {
            // 转换为毫米
            var mmValue = diameter / 25.4
            return mmValue.toFixed(0) + " in"
        } else {
            // 保持英寸
            return diameter.toFixed(1) + " mm"
        }
    }

    function formatPower(powerPerStage) {
        if (!powerPerStage) return "N/A"

        if (isMetric) {
            // 功率通常保持kW不变，或者转换
            return powerPerStage.toFixed(1) + " kW/stage"
        } else {
            // 保持HP
            return powerPerStage.toFixed(1) + " HP/stage"
        }
    }
}
