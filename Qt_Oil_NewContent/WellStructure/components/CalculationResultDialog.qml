import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Dialog {
    id: root

    property bool isChineseMode: true
    property var calculationResult: null

    title: isChineseMode ? "计算结果" : "Calculation Results"
    width: 600
    height: 500
    modal: true
    standardButtons: Dialog.Ok

    contentItem: ScrollView {
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 20

            // 主要结果
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "计算结果" : "Calculation Results"

                background: Rectangle {
                    color: "#f0f8ff"
                    border.color: "#4a90e2"
                    radius: 4
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 16
                    columnSpacing: 30

                    // 泵挂垂深
                    Label {
                        text: isChineseMode ? "泵挂垂深:" : "Pump Hanging Depth:"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    Label {
                        text: calculationResult ?
                            `${calculationResult.pump_hanging_depth} m` : "-"
                        font.pixelSize: 18
                        color: "#4a90e2"
                        font.bold: true
                    }

                    // 射孔垂深
                    Label {
                        text: isChineseMode ? "射孔垂深:" : "Perforation Depth:"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    Label {
                        text: calculationResult ?
                            `${calculationResult.perforation_depth} m` : "-"
                        font.pixelSize: 18
                        color: "#4a90e2"
                        font.bold: true
                    }

                    // 计算时间
                    Label {
                        text: isChineseMode ? "计算时间:" : "Calculation Time:"
                        font.pixelSize: 14
                    }
                    Label {
                        text: calculationResult && calculationResult.calculation_date ?
                            formatDateTime(calculationResult.calculation_date) : "-"
                        font.pixelSize: 14
                        color: "#666"
                    }

                    // 计算方法
                    Label {
                        text: isChineseMode ? "计算方法:" : "Calculation Method:"
                        font.pixelSize: 14
                    }
                    Label {
                        text: calculationResult ?
                            (calculationResult.calculation_method || "default") : "-"
                        font.pixelSize: 14
                        color: "#666"
                    }
                }
            }

            // 轨迹统计
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "轨迹统计" : "Trajectory Statistics"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 30

                    Label {
                        text: isChineseMode ? "总垂深:" : "Total TVD:"
                    }
                    Label {
                        text: calculationResult ?
                            `${calculationResult.total_depth_tvd} m` : "-"
                        color: "#333"
                    }

                    Label {
                        text: isChineseMode ? "总测深:" : "Total MD:"
                    }
                    Label {
                        text: calculationResult ?
                            `${calculationResult.total_depth_md} m` : "-"
                        color: "#333"
                    }

                    Label {
                        text: isChineseMode ? "最大井斜角:" : "Max Inclination:"
                    }
                    Label {
                        text: calculationResult && calculationResult.max_inclination ?
                            `${calculationResult.max_inclination}°` : "-"
                        color: calculationResult && calculationResult.max_inclination > 45 ?
                            "#ff9800" : "#333"
                    }

                    Label {
                        text: isChineseMode ? "最大狗腿度:" : "Max DLS:"
                    }
                    Label {
                        text: calculationResult && calculationResult.max_dls ?
                            `${calculationResult.max_dls}°/30m` : "-"
                        color: calculationResult && calculationResult.max_dls > 10 ?
                            "#f44336" : "#333"
                    }
                }
            }

            // 计算参数
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "计算参数" : "Calculation Parameters"
                visible: calculationResult && calculationResult.parameters

                ScrollView {
                    anchors.fill: parent
                    height: 100

                    TextArea {
                        text: formatParameters(calculationResult ? calculationResult.parameters : "{}")
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextArea.Wrap
                        font.family: "Consolas, Monaco, monospace"
                        font.pixelSize: 12

                        background: Rectangle {
                            color: "#f5f5f5"
                            radius: 4
                        }
                    }
                }
            }

            // 建议
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "建议" : "Recommendations"

                background: Rectangle {
                    color: "#fff8e1"
                    border.color: "#ffc107"
                    radius: 4
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Row {
                        spacing: 5

                        Text {
                            text: "💡"
                            font.pixelSize: 16
                        }

                        Label {
                            text: getRecommendation()
                            wrapMode: Text.Wrap
                            color: "#795548"
                        }
                    }
                }
            }
        }
    }

    footer: DialogButtonBox {
        RowLayout {
            spacing: 10

            Button {
                text: isChineseMode ? "查看历史记录" : "View History"
                flat: true
                onClicked: showHistory()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: isChineseMode ? "导出结果" : "Export Results"
                onClicked: exportResults()
            }
        }
    }

    // 显示计算结果
    function showResult(result) {
        calculationResult = result
        open()
    }

    // 格式化日期时间
    function formatDateTime(dateStr) {
        try {
            var date = new Date(dateStr)
            return Qt.formatDateTime(date, "yyyy-MM-dd hh:mm:ss")
        } catch (e) {
            return dateStr
        }
    }

    // 格式化参数
    function formatParameters(paramsStr) {
        try {
            var params = JSON.parse(paramsStr)
            return JSON.stringify(params, null, 2)
        } catch (e) {
            return paramsStr
        }
    }

    // 获取建议
    function getRecommendation() {
        if (!calculationResult) {
            return ""
        }

        var recommendations = []

        // 基于最大井斜角的建议
        if (calculationResult.max_inclination > 60) {
            recommendations.push(isChineseMode ?
                "井斜角较大，建议使用特殊的泵挂工具" :
                "High inclination angle, special pump hanging tools recommended")
        }

        // 基于狗腿度的建议
        if (calculationResult.max_dls > 15) {
            recommendations.push(isChineseMode ?
                "狗腿度过大，可能影响设备下入，建议进行详细评估" :
                "High DLS may affect equipment running, detailed evaluation recommended")
        }

        // 基于深度的建议
        if (calculationResult.total_depth_tvd > 3000) {
            recommendations.push(isChineseMode ?
                "井深较大，建议考虑温度和压力对设备的影响" :
                "Deep well, consider temperature and pressure effects on equipment")
        }

        if (recommendations.length === 0) {
            recommendations.push(isChineseMode ?
                "计算结果在正常范围内，可按常规工艺进行施工" :
                "Results are within normal range, standard procedures can be followed")
        }

        return recommendations.join("\n")
    }

    // 显示历史记录
    function showHistory() {
        // TODO: 实现历史记录查看
        console.log("Show calculation history")
    }

    // 导出结果
    function exportResults() {
        // TODO: 实现结果导出
        console.log("Export calculation results")
    }
}
