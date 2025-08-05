import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    // 🔥 修改属性以匹配Step2的用法
    property string title: ""
    property string unit: ""
    property string icon: ""
    property real mlValue: 0
    property real empiricalValue: 0
    property real confidence: 0
    property bool isAdjustable: false
    property real finalValue: 0
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    // 🔥 兼容原有的resultData属性（用于其他地方的调用）
    property var resultData: null

    // 🔥 修复：只保留一个信号定义，移除重复的信号
    signal cardClicked()
    // signal finalValueChanged(real finalValue)

    width: 340
    height: 280
    radius: 8
    color: "#FFFFFF"
    border.width: 1
    border.color: "#E0E0E0"

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cardClicked()

        onEntered: {
            parent.color = "#F8F9FA"
        }

        onExited: {
            parent.color = "#FFFFFF"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 3

        // 🔥 修改标题显示逻辑，支持两种模式
        RowLayout {
            Layout.fillWidth: true

            // 图标
            Text {
                text: root.icon || "📊"
                font.pixelSize: 24
                visible: root.icon !== ""
            }

            Column {
                Layout.fillWidth: true
                spacing: 4

                // 标题
                Text {
                    text: root.title || (resultData ? `${isChineseMode ? '方案' : 'Option'} ${resultData.option_id || 1}` : "")
                    font.pixelSize: 16
                    font.bold: true
                    color: "#1976D2"
                    elide: Text.ElideRight
                    width: parent.width
                }

                // 单位显示
                Text {
                    text: root.unit || ""
                    font.pixelSize: 12
                    color: "#666666"
                    visible: root.unit !== ""
                }
            }

            Item { Layout.fillWidth: true }

            // 置信度指示器
            Rectangle {
                width: 60
                height: 20
                radius: 10
                color: getConfidenceColor()
                visible: root.confidence > 0 || (resultData && resultData.confidence)

                Text {
                    anchors.centerIn: parent
                    text: {
                        var conf = root.confidence || (resultData ? resultData.confidence : 0)
                        return `${Math.round(conf * 100)}%`
                    }
                    font.pixelSize: 11
                    color: "white"
                    font.bold: true
                }
            }
        }

        // 🔥 根据是否有title属性来决定显示模式
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Step2预测结果卡片模式（有title属性）
            Column {
                anchors.fill: parent
                spacing: 16
                visible: root.title !== ""

                // 数值显示区域
                Rectangle {
                    width: parent.width
                    height: 80
                    color: "#F8F9FA"
                    radius: 8
                    border.width: 1
                    border.color: "#E0E0E0"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 20

                        // 机器学习结果
                        Column {
                            Layout.preferredWidth: parent.width * 0.4
                            spacing: 4

                            Text {
                                text: isChineseMode ? "机器学习" : "ML"
                                font.pixelSize: 10
                                color: Material.color(Material.Blue)
                                font.bold: true
                            }

                            Text {
                                text: formatValue(root.mlValue) + " " + root.unit
                                font.pixelSize: 14
                                font.bold: true
                                color: Material.color(Material.Blue)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // 分隔线
                        Rectangle {
                            width: 1
                            Layout.fillHeight: true
                            color: "#E0E0E0"
                        }

                        // 经验公式结果
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "经验公式" : "Empirical"
                                font.pixelSize: 10
                                color: Material.color(Material.Green)
                                font.bold: true
                            }

                            Text {
                                text: formatValue(root.empiricalValue) + " " + root.unit
                                font.pixelSize: 14
                                font.bold: true
                                color: Material.color(Material.Green)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }

                // 最终值调整区域
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 8
                    border.color: "#05298a"
                    border.width: 1
                    visible: root.isAdjustable
                    color: "#daeafe"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Column {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter // Add this line to vertically center this column
                            Layout.fillHeight: true

                            Text {
                                color: "#07191b"
                                text: isChineseMode ? "最终值" : "Final Value"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            Text {
                                color: "#07191b"
                                text: formatValue(root.finalValue) + " " + root.unit
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // 调整按钮
                        Column {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter // Add this line to vertically center this column
                            Layout.fillHeight: true

                            Button {
                                width: 30
                                height: 20
                                text: "+"
                                // 定制文本样式（包括颜色）
                                // contentItem: Text {
                                //     text: parent.text  // 关联Button的text属性
                                //     font.pixelSize: 12
                                //     font.bold: true
                                //     color: "black"  // 在这里设置文本颜色

                                // }
                                contentItem: Text {
                                    anchors.fill: parent
                                    text: "+"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "black"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideNone

                                    // 关键：像素级微调垂直位置（根据实际效果调整数值）
                                    topPadding: 1   // 向上微调1px
                                    bottomPadding: 0
                                }
                                onClicked: adjustValue(0.05)

                                background: Rectangle {
                                    color: "#5ce9b0"
                                    radius: 4
                                }
                            }

                            Button {
                                width: 30
                                height: 20
                                text: "-"
                                // // 定制文本样式（包括颜色）
                                // contentItem: Text {
                                //     text: parent.text  // 关联Button的text属性
                                //     font.pixelSize: 12
                                //     font.bold: true
                                //     color: "black"  // 在这里设置文本颜色

                                // }
                                contentItem: Text {
                                    anchors.fill: parent
                                    text: "-"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "black"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideNone

                                    // 关键：像素级微调垂直位置（根据实际效果调整数值）
                                    topPadding: 1   // 向上微调1px
                                    bottomPadding: 0
                                }
                                onClicked: adjustValue(-0.05)

                                background: Rectangle {
                                    color: "#5ce9b0"
                                    radius: 4
                                }
                            }
                        }
                    }
                }

                // 误差分析
                Rectangle {
                    width: parent.width
                    height: 40
                    color: "transparent"
                    visible: root.mlValue > 0 && root.empiricalValue > 0

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (root.mlValue > 0 && root.empiricalValue > 0) {
                                var error = Math.abs(root.mlValue - root.empiricalValue) / Math.max(root.mlValue, root.empiricalValue) * 100
                                var errorText = isChineseMode ? "误差: " : "Error: "
                                return errorText + error.toFixed(1) + "%"
                            }
                            return ""
                        }
                        font.pixelSize: 12
                        color: {
                            if (root.mlValue > 0 && root.empiricalValue > 0) {
                                var error = Math.abs(root.mlValue - root.empiricalValue) / Math.max(root.mlValue, root.empiricalValue) * 100
                                return error < 10 ? Material.color(Material.Green) :
                                       error < 20 ? Material.color(Material.Orange) : Material.color(Material.Red)
                            }
                            return "#666666"
                        }
                        font.bold: true
                    }
                }
            }

            // 原有的设备推荐卡片模式（无title属性，使用resultData）
            ColumnLayout {
                anchors.fill: parent
                spacing: 12
                visible: root.title === "" && resultData

                // 主要预测参数
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 16

                    // 🔥 使用UnitDisplay组件显示resultData
                    Text {
                        text: isChineseMode ? "流量:" : "Flow Rate:"
                        font.pixelSize: 12
                        color: "#666666"
                    }

                    CommonComponents.UnitDisplay {
                        value: resultData ? (resultData.flow_rate || 0) : 0
                        unitType: "flow"
                        isChinese: root.isChineseMode
                        isMetric: root.isMetric
                        fontSize: 12
                        bold: true
                    }

                    Text {
                        text: isChineseMode ? "扬程:" : "Head:"
                        font.pixelSize: 12
                        color: "#666666"
                    }

                    CommonComponents.UnitDisplay {
                        value: resultData ? (resultData.required_head || 0) : 0
                        unitType: "depth"
                        isChinese: root.isChineseMode
                        isMetric: root.isMetric
                        fontSize: 12
                        bold: true
                    }

                    Text {
                        text: isChineseMode ? "压力:" : "Pressure:"
                        font.pixelSize: 12
                        color: "#666666"
                    }

                    CommonComponents.UnitDisplay {
                        value: resultData ? (resultData.working_pressure || 0) : 0
                        unitType: "pressure"
                        isChinese: root.isChineseMode
                        isMetric: root.isMetric
                        fontSize: 12
                        bold: true
                    }

                    Text {
                        text: isChineseMode ? "效率:" : "Efficiency:"
                        font.pixelSize: 12
                        color: "#666666"
                    }

                    Text {
                        text: resultData ? `${(resultData.efficiency || 0).toFixed(1)}%` : "0%"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#4CAF50"
                    }
                }

                // 推荐设备信息
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: deviceInfo.height + 16
                    color: "#F8F9FA"
                    radius: 6
                    visible: resultData && resultData.recommended_device

                    Column {
                        id: deviceInfo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 4

                        Text {
                            text: isChineseMode ? "推荐设备:" : "Recommended Device:"
                            font.pixelSize: 11
                            color: "#666666"
                            font.bold: true
                        }

                        Text {
                            text: resultData && resultData.recommended_device ?
                                  resultData.recommended_device.device_name || "Unknown Device" : ""
                            font.pixelSize: 12
                            color: "#1976D2"
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: resultData && resultData.recommended_device ?
                                  resultData.recommended_device.manufacturer || "Unknown Manufacturer" : ""
                            font.pixelSize: 10
                            color: "#666666"
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                // 成本估算
                RowLayout {
                    Layout.fillWidth: true
                    visible: resultData && resultData.estimated_cost

                    Text {
                        text: isChineseMode ? "预估成本:" : "Estimated Cost:"
                        font.pixelSize: 12
                        color: "#666666"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: resultData ? `$${(resultData.estimated_cost || 0).toLocaleString()}` : "$0"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#FF9800"
                    }
                }

                Item { Layout.fillHeight: true }

                // 选择指示器
                Rectangle {
                    Layout.fillWidth: true
                    height: 2
                    color: "#1976D2"
                    radius: 1
                    visible: resultData
                }
            }
        }
    }

    // 🔥 添加辅助函数
    function formatValue(value) {
        if (typeof value !== "number" || isNaN(value)) return "0.00"

        // 根据数值大小决定小数位数
        if (Math.abs(value) >= 1000) {
            return value.toFixed(0)  // 大于1000的数值不显示小数
        } else if (Math.abs(value) >= 10) {
            return value.toFixed(1)  // 10-1000之间显示1位小数
        } else {
            return value.toFixed(2)  // 小于10显示2位小数
        }
    }

    function adjustValue(factor) {
        if (!root.isAdjustable) return

        var newValue = root.finalValue * (1 + factor)
        if (newValue >= 0) {  // 确保不为负数
            root.finalValue = newValue
            root.finalValueChanged(root.finalValue)
        }
    }

    function getConfidenceColor() {
        var conf = root.confidence || (resultData ? resultData.confidence : 0)
        if (conf <= 0) return "#999999"

        var confidence = conf * 100
        if (confidence >= 80) return "#4CAF50"      // 绿色 - 高置信度
        else if (confidence >= 60) return "#FF9800" // 橙色 - 中置信度
        else return "#F44336"                       // 红色 - 低置信度
    }
}


