// Qt_Oil_NewContent/DeviceRecommendation/Components/PumpPerformanceCurve.qml
// 优化布局版本

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var pumpData: null
    property var operatingPoint: {"flow": 0, "head": 0}
    property int stages: 1
    property bool isChineseMode: true

    // 🔥 新增：处理增强泵数据
    property var enhancedCurveData: null

    color: "white"
    radius: 4
    border.color: "#e1e5e9"
    border.width: 1

    // 🔥 监听增强数据变化
    onEnhancedCurveDataChanged: {
        console.log("PumpPerformanceCurve: 增强曲线数据变化")
        if (enhancedCurveData && enhancedCurveData.baseCurves) {
            console.log("使用增强曲线数据，流量点数:", enhancedCurveData.baseCurves.flow.length)
            console.log("扬程点数:", enhancedCurveData.baseCurves.head.length)
            console.log("级数:", enhancedCurveData.stages)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // 标题
        Text {
            Layout.fillWidth: true
            text: isChineseMode ? "泵性能曲线" : "Pump Performance Curve"
            font.pixelSize: 14
            font.bold: true
            color: "#333"  // 🔥 修复颜色
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#e1e5e9"
        }

        // 图表区域 - 使用增强数据
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
            color: "white"
            border.color: "#f0f0f0"
            border.width: 1

            Item {
                id: chartArea
                anchors.fill: parent
                anchors.margins: 15

                property real leftMargin: 70
                property real bottomMargin: 50
                property real rightMargin: 30
                property real topMargin: 20
                property real chartWidth: width - leftMargin - rightMargin
                property real chartHeight: height - topMargin - bottomMargin

                // 🔥 计算显示范围
                property var displayData: {
                    if (enhancedCurveData && enhancedCurveData.baseCurves) {
                        return enhancedCurveData.baseCurves
                    } else if (pumpData) {
                        // 使用原始pumpData生成模拟曲线
                        return generateSimulatedCurve()
                    }
                    return null
                }

                property real maxFlow: displayData ? Math.max(...displayData.flow) : 1000
                property real minFlow: displayData ? Math.min(...displayData.flow) : 0
                property real maxHead: displayData ? Math.max(...displayData.head) : 100
                property real minHead: displayData ? Math.min(...displayData.head) : 0

                Component.onCompleted: {
                    console.log("图表区域尺寸:", "width=", width, "height=", height)
                    console.log("图表绘制区域:", "chartWidth=", chartWidth, "chartHeight=", chartHeight)
                    if (displayData) {
                        console.log("显示范围 - 流量:", minFlow, "到", maxFlow, "bbl/d")
                        console.log("显示范围 - 扬程:", minHead, "到", maxHead, "ft")
                    }
                }

                // 背景网格
                Repeater {
                    model: 6
                    Rectangle {
                        x: chartArea.leftMargin + (chartArea.chartWidth * index / 5)
                        y: chartArea.topMargin
                        width: 1
                        height: chartArea.chartHeight
                        color: index === 0 ? "#333" : "#f0f0f0"
                        visible: chartArea.chartWidth > 0
                    }
                }

                Repeater {
                    model: 6
                    Rectangle {
                        x: chartArea.leftMargin
                        y: chartArea.topMargin + (chartArea.chartHeight * index / 5)
                        width: chartArea.chartWidth
                        height: index === 5 ? 2 : 1
                        color: index === 5 ? "#333" : "#f0f0f0"
                        visible: chartArea.chartHeight > 0
                    }
                }

                // 🔥 性能曲线点 - 使用真实数据
                Repeater {
                    id: curvePoints
                    model: chartArea.displayData ? chartArea.displayData.flow.length : 0

                    Rectangle {
                        property real flowValue: chartArea.displayData ? chartArea.displayData.flow[index] : 0
                        property real headValue: chartArea.displayData ? chartArea.displayData.head[index] : 0

                        // 🔥 修正坐标计算
                        property real normalizedFlow: chartArea.maxFlow > chartArea.minFlow ?
                            (flowValue - chartArea.minFlow) / (chartArea.maxFlow - chartArea.minFlow) : 0
                        property real normalizedHead: chartArea.maxHead > chartArea.minHead ?
                            (headValue - chartArea.minHead) / (chartArea.maxHead - chartArea.minHead) : 0

                        property real chartX: chartArea.leftMargin + (normalizedFlow * chartArea.chartWidth)
                        property real chartY: chartArea.topMargin + chartArea.chartHeight * (1 - normalizedHead)

                        x: chartX - width/2
                        y: chartY - height/2

                        width: 4
                        height: 4
                        radius: 2
                        color: "#2196F3"

                        visible: chartArea.displayData !== null &&
                                !isNaN(chartX) && !isNaN(chartY) &&
                                chartX >= chartArea.leftMargin &&
                                chartX <= chartArea.leftMargin + chartArea.chartWidth &&
                                chartY >= chartArea.topMargin &&
                                chartY <= chartArea.topMargin + chartArea.chartHeight

                        // 🔥 调试信息
                        Component.onCompleted: {
                            if (index < 3) {  // 只打印前3个点
                                console.log(`曲线点${index}: flow=${flowValue}, head=${headValue}, x=${chartX}, y=${chartY}`)
                            }
                        }
                    }
                }

                // 🔥 工作点 - 修正计算
                Rectangle {
                    id: workingPointIndicator
                    width: 12
                    height: 12
                    radius: 6
                    color: "#F44336"
                    border.color: "white"
                    border.width: 2
                    visible: false
                    z: 10

                    property real workingFlow: {
                        if (!operatingPoint || operatingPoint.flow <= 0) return 0
                        var flow = operatingPoint.flow
                        if (flow < 1) flow *= 1000  // 单位转换
                        return flow
                    }

                    property real workingHead: {
                        if (!chartArea.displayData || workingFlow <= 0) return 0

                        // 🔥 从真实数据中插值计算扬程
                        return interpolateHead(workingFlow)
                    }

                    function interpolateHead(targetFlow) {
                        if (!chartArea.displayData || !chartArea.displayData.flow || !chartArea.displayData.head) {
                            return 0
                        }

                        var flows = chartArea.displayData.flow
                        var heads = chartArea.displayData.head

                        // 找到最接近的两个点进行插值
                        for (var i = 0; i < flows.length - 1; i++) {
                            if (targetFlow >= flows[i] && targetFlow <= flows[i + 1]) {
                                var ratio = (targetFlow - flows[i]) / (flows[i + 1] - flows[i])
                                return heads[i] + ratio * (heads[i + 1] - heads[i])
                            }
                        }

                        // 边界情况
                        if (targetFlow <= flows[0]) return heads[0]
                        if (targetFlow >= flows[flows.length - 1]) return heads[heads.length - 1]

                        return 0
                    }

                    Component.onCompleted: updatePosition()

                    Connections {
                        target: root
                        function onOperatingPointChanged() { workingPointIndicator.updatePosition() }
                        function onEnhancedCurveDataChanged() { workingPointIndicator.updatePosition() }
                        function onStagesChanged() { workingPointIndicator.updatePosition() }
                    }

                    function updatePosition() {
                        if (!chartArea.displayData || workingFlow <= 0 || chartArea.chartWidth <= 0 || chartArea.chartHeight <= 0) {
                            visible = false
                            return
                        }

                        var normalizedFlow = (workingFlow - chartArea.minFlow) / (chartArea.maxFlow - chartArea.minFlow)
                        var normalizedHead = (workingHead - chartArea.minHead) / (chartArea.maxHead - chartArea.minHead)

                        if (normalizedFlow < 0 || normalizedFlow > 1 || normalizedHead < 0 || normalizedHead > 1) {
                            visible = false
                            console.log("工作点超出范围:", workingFlow, workingHead)
                            return
                        }

                        var chartX = chartArea.leftMargin + (normalizedFlow * chartArea.chartWidth)
                        var chartY = chartArea.topMargin + chartArea.chartHeight * (1 - normalizedHead)

                        x = chartX - width/2
                        y = chartY - height/2
                        visible = true

                        console.log("工作点位置更新:", "flow=", workingFlow, "head=", workingHead, "x=", x, "y=", y)
                    }
                }

                // X轴刻度值 - 修正
                Repeater {
                    model: 6
                    Text {
                        x: chartArea.leftMargin + (chartArea.chartWidth * index / 5) - width/2
                        y: chartArea.topMargin + chartArea.chartHeight + 8
                        text: chartArea.displayData ?
                              (chartArea.minFlow + (index * (chartArea.maxFlow - chartArea.minFlow) / 5)).toFixed(0) :
                              (index * 500).toString()
                        font.pixelSize: 10
                        color: "#666"
                        visible: chartArea.chartWidth > 0
                    }
                }

                // Y轴刻度值 - 修正
                Repeater {
                    model: 6
                    Text {
                        x: chartArea.leftMargin - width - 8
                        y: chartArea.topMargin + chartArea.chartHeight - (chartArea.chartHeight * index / 5) - height/2
                        text: chartArea.displayData ?
                              (chartArea.minHead + (index * (chartArea.maxHead - chartArea.minHead) / 5)).toFixed(0) :
                              (index * 20).toString()
                        font.pixelSize: 10
                        color: "#666"
                        horizontalAlignment: Text.AlignRight
                        visible: chartArea.chartHeight > 0
                    }
                }

                // 🔥 生成模拟曲线函数
                function generateSimulatedCurve() {
                    if (!pumpData) return null

                    var flow = []
                    var head = []
                    var efficiency = []

                    var numPoints = 15
                    for (var i = 0; i < numPoints; i++) {
                        var flowValue = pumpData.minFlow + (i * (pumpData.maxFlow - pumpData.minFlow) / (numPoints - 1))
                        var normalizedFlow = i / (numPoints - 1)
                        var headRatio = 1.1 - 0.4 * normalizedFlow - 0.6 * normalizedFlow * normalizedFlow
                        var headValue = pumpData.headPerStage * stages * Math.max(0.2, headRatio)
                        var effValue = pumpData.efficiency * (1 - Math.pow(2 * normalizedFlow - 1, 4))

                        flow.push(flowValue)
                        head.push(headValue)
                        efficiency.push(Math.max(0, effValue))
                    }

                    return {
                        flow: flow,
                        head: head,
                        efficiency: efficiency
                    }
                }

                // 空状态提示
                Text {
                    anchors.centerIn: parent
                    text: isChineseMode ? "暂无泵数据" : "No pump data"
                    font.pixelSize: 14
                    color: "#999"
                    visible: !chartArea.displayData
                }
            }
        }

        // 🔥 数据信息栏 - 显示真实数据
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#f8f9fa"
            radius: 4
            visible: pumpData !== null || enhancedCurveData !== null

            GridLayout {
                anchors.fill: parent
                anchors.margins: 8
                columns: 4
                columnSpacing: 12
                rowSpacing: 4

                // 级数
                Text {
                    text: isChineseMode ? "级数:" : "Stages:"
                    font.pixelSize: 10
                    color: "#666"
                    Layout.alignment: Qt.AlignRight
                }
                Text {
                    text: {
                        var stageCount = enhancedCurveData ? enhancedCurveData.stages : stages
                        return stageCount + " " + (isChineseMode ? "级" : "stages")
                    }
                    font.pixelSize: 11
                    font.bold: true
                    color: "#333"
                }

                // 单级扬程
                Text {
                    text: isChineseMode ? "单级扬程:" : "Head/Stage:"
                    font.pixelSize: 10
                    color: "#666"
                    Layout.alignment: Qt.AlignRight
                }
                Text {
                    text: {
                        if (enhancedCurveData && enhancedCurveData.baseCurves && enhancedCurveData.stages > 0) {
                            var maxHead = Math.max(...enhancedCurveData.baseCurves.head)
                            var headPerStage = maxHead / enhancedCurveData.stages
                            return headPerStage.toFixed(1) + " ft"
                        } else if (pumpData) {
                            return pumpData.headPerStage + " ft"
                        }
                        return "N/A"
                    }
                    font.pixelSize: 11
                    font.bold: true
                    color: "#333"
                }

                // 总扬程
                Text {
                    text: isChineseMode ? "总扬程:" : "Total Head:"
                    font.pixelSize: 10
                    color: "#666"
                    Layout.alignment: Qt.AlignRight
                }
                Text {
                    text: {
                        if (enhancedCurveData && enhancedCurveData.baseCurves) {
                            var maxHead = Math.max(...enhancedCurveData.baseCurves.head)
                            return maxHead.toFixed(0) + " ft"
                        } else if (pumpData) {
                            return (pumpData.headPerStage * stages).toFixed(0) + " ft"
                        }
                        return "N/A"
                    }
                    font.pixelSize: 11
                    font.bold: true
                    color: "#2196F3"
                }

                // 最佳效率
                Text {
                    text: isChineseMode ? "最佳效率:" : "Best Eff:"
                    font.pixelSize: 10
                    color: "#666"
                    Layout.alignment: Qt.AlignRight
                }
                Text {
                    text: {
                        if (enhancedCurveData && enhancedCurveData.baseCurves) {
                            var maxEff = Math.max(...enhancedCurveData.baseCurves.efficiency)
                            return maxEff.toFixed(1) + "%"
                        } else if (pumpData) {
                            return pumpData.efficiency + "%"
                        }
                        return "N/A"
                    }
                    font.pixelSize: 11
                    font.bold: true
                    color: "#4CAF50"
                }
            }
        }
    }

    // 数据变化监听
    onPumpDataChanged: {
        console.log("PumpPerformanceCurve: pumpData changed")
        if (pumpData) {
            console.log("泵型:", pumpData.model, "单级扬程:", pumpData.headPerStage, "效率:", pumpData.efficiency)
        }
    }

    onStagesChanged: {
        console.log("PumpPerformanceCurve: stages changed to", stages)
    }

    onOperatingPointChanged: {
        console.log("PumpPerformanceCurve: operatingPoint changed", JSON.stringify(operatingPoint))
    }
}
