// Qt_Oil_NewContent/DeviceRecommendation/Components/MotorEfficiencyCurve.qml
// 使用Canvas绘图，参照PumpPerformanceChart.qml的逻辑

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var motorData: null
    property real operatingPower: 0
    property int frequency: 60
    property bool isChineseMode: true

    width: 900
    height: 600
    color: "transparent"

    // 使用Popup来显示图表
    Popup {
        id: chartPopup
        anchors.centerIn: parent
        width: 900
        height: 600
        modal: true

        background: Rectangle {
            color: "white"
            border.color: "#e1e5e9"
            border.width: 1
            radius: 8

            // 添加阴影效果
            Rectangle {
                anchors.fill: parent
                anchors.margins: -5
                color: "transparent"
                radius: 13
                z: -1

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0.1
                    radius: 13
                }
            }
        }

        // 标题栏
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: Material.primary
            radius: 8

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "⚡"
                    font.pixelSize: 18
                    color: "white"
                }

                Text {
                    text: isChineseMode ? "电机性能曲线" : "Motor Performance Curve"
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "✕"
                    flat: true
                    Material.theme: Material.Dark
                    onClicked: chartPopup.close()
                }
            }
        }

        // 主内容区域
        contentItem: Item {
            anchors.topMargin: 60

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Canvas 图表区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    border.color: "#e1e5e9"
                    border.width: 1
                    radius: 4

                    Canvas {
                        id: motorCanvas
                        anchors.fill: parent
                        anchors.margins: 20

                        property real leftMargin: 80
                        property real bottomMargin: 60
                        property real rightMargin: 80  // 右边距增大，为右Y轴留空间
                        property real topMargin: 30

                        // 强制软件渲染
                        renderStrategy: Canvas.Threaded
                        renderTarget: Canvas.Image

                        onPaint: {
                            console.log("=== Canvas开始绘制电机性能曲线 ===")
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            if (!motorData) {
                                drawEmptyState(ctx)
                                return
                            }

                            try {
                                drawChart(ctx)
                                console.log("=== Canvas绘制完成 ===")
                            } catch (error) {
                                console.error("Canvas绘制错误:", error)
                                drawErrorState(ctx)
                            }
                        }

                        function drawEmptyState(ctx) {
                            ctx.fillStyle = "#999"
                            ctx.font = "16px Arial"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "暂无电机数据" : "No motor data",
                                width / 2, height / 2
                            )
                        }

                        function drawErrorState(ctx) {
                            ctx.fillStyle = "#F44336"
                            ctx.font = "14px Arial"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "图表渲染错误" : "Chart rendering error",
                                width / 2, height / 2
                            )
                        }

                        function drawChart(ctx) {
                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 数据范围
                            var maxLoad = 120  // 负载率%
                            var minLoad = 0
                            var maxEfficiency = 100  // 效率%
                            var maxPowerFactor = 1.0  // 功率因数

                            // 绘制坐标轴
                            drawAxes(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxEfficiency, maxPowerFactor)

                            // 绘制效率曲线
                            drawEfficiencyCurve(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxEfficiency)

                            // 绘制功率因数曲线
                            drawPowerFactorCurve(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxPowerFactor)

                            // 绘制工作点
                            drawWorkingPoint(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxEfficiency)
                        }

                        function drawAxes(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxEfficiency, maxPowerFactor) {
                            // 主坐标轴
                            ctx.strokeStyle = "#333"
                            ctx.lineWidth = 2

                            // Y轴（左侧 - 效率）
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, topMargin)
                            ctx.lineTo(leftMargin, topMargin + chartHeight)
                            ctx.stroke()

                            // Y轴（右侧 - 功率因数）
                            ctx.beginPath()
                            ctx.moveTo(leftMargin + chartWidth, topMargin)
                            ctx.lineTo(leftMargin + chartWidth, topMargin + chartHeight)
                            ctx.stroke()

                            // X轴
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, topMargin + chartHeight)
                            ctx.lineTo(leftMargin + chartWidth, topMargin + chartHeight)
                            ctx.stroke()

                            // 网格线
                            ctx.strokeStyle = "#f0f0f0"
                            ctx.lineWidth = 1

                            for (var i = 1; i < 6; i++) {
                                // 水平网格线
                                var y = topMargin + (chartHeight * i / 6)
                                ctx.beginPath()
                                ctx.moveTo(leftMargin, y)
                                ctx.lineTo(leftMargin + chartWidth, y)
                                ctx.stroke()

                                // 垂直网格线
                                var x = leftMargin + (chartWidth * i / 6)
                                ctx.beginPath()
                                ctx.moveTo(x, topMargin)
                                ctx.lineTo(x, topMargin + chartHeight)
                                ctx.stroke()
                            }

                            // 轴标签
                            ctx.fillStyle = "#333"
                            ctx.font = "14px Arial"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText(
                                isChineseMode ? "负载率 (%)" : "Load (%)",
                                leftMargin + chartWidth / 2,
                                topMargin + chartHeight + 35
                            )

                            // 左Y轴标签（效率）
                            ctx.save()
                            ctx.translate(25, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "效率 (%)" : "Efficiency (%)",
                                0, 0
                            )
                            ctx.restore()

                            // 右Y轴标签（功率因数）
                            ctx.save()
                            ctx.translate(width - 25, topMargin + chartHeight / 2)
                            ctx.rotate(Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "功率因数" : "Power Factor",
                                0, 0
                            )
                            ctx.restore()

                            // 刻度值
                            ctx.font = "12px Arial"
                            ctx.fillStyle = "#666"

                            // X轴刻度（负载率）
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            for (var j = 0; j <= 6; j++) {
                                var loadValue = minLoad + (j * (maxLoad - minLoad) / 6)
                                var xPos = leftMargin + (chartWidth * j / 6)
                                ctx.fillText(loadValue.toFixed(0), xPos, topMargin + chartHeight + 8)
                            }

                            // 左Y轴刻度（效率）
                            ctx.textAlign = "right"
                            ctx.textBaseline = "middle"
                            for (var k = 0; k <= 6; k++) {
                                var effValue = maxEfficiency * k / 6
                                var yPos = topMargin + chartHeight - (chartHeight * k / 6)
                                ctx.fillText(effValue.toFixed(0), leftMargin - 8, yPos)
                            }

                            // 右Y轴刻度（功率因数）
                            ctx.textAlign = "left"
                            ctx.textBaseline = "middle"
                            for (var l = 0; l <= 6; l++) {
                                var pfValue = maxPowerFactor * l / 6
                                var yPos = topMargin + chartHeight - (chartHeight * l / 6)
                                ctx.fillText(pfValue.toFixed(2), leftMargin + chartWidth + 8, yPos)
                            }
                        }

                        function drawEfficiencyCurve(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxEfficiency) {
                            ctx.strokeStyle = "#4CAF50"  // 绿色
                            ctx.lineWidth = 3
                            ctx.beginPath()

                            var peakEfficiency = motorData.efficiency || 90
                            var points = 30

                            for (var i = 0; i <= points; i++) {
                                var load = minLoad + (i * (maxLoad - minLoad) / points)

                                // 效率曲线（典型的电机效率特性）
                                var efficiency
                                if (load < 20) {
                                    efficiency = peakEfficiency * 0.7 * (load / 20)
                                } else if (load <= 75) {
                                    efficiency = peakEfficiency * (0.7 + 0.3 * (load - 20) / 55)
                                } else if (load <= 100) {
                                    efficiency = peakEfficiency * (1 - 0.02 * (load - 75) / 25)
                                } else {
                                    efficiency = peakEfficiency * (0.98 - 0.08 * (load - 100) / 20)
                                }

                                var x = leftMargin + ((load - minLoad) / (maxLoad - minLoad)) * chartWidth
                                var y = topMargin + chartHeight - (efficiency / maxEfficiency) * chartHeight

                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            // 绘制数据点
                            ctx.fillStyle = "#4CAF50"
                            for (var j = 0; j <= points; j += 5) {
                                var load2 = minLoad + (j * (maxLoad - minLoad) / points)

                                var efficiency2
                                if (load2 < 20) {
                                    efficiency2 = peakEfficiency * 0.7 * (load2 / 20)
                                } else if (load2 <= 75) {
                                    efficiency2 = peakEfficiency * (0.7 + 0.3 * (load2 - 20) / 55)
                                } else if (load2 <= 100) {
                                    efficiency2 = peakEfficiency * (1 - 0.02 * (load2 - 75) / 25)
                                } else {
                                    efficiency2 = peakEfficiency * (0.98 - 0.08 * (load2 - 100) / 20)
                                }

                                var x2 = leftMargin + ((load2 - minLoad) / (maxLoad - minLoad)) * chartWidth
                                var y2 = topMargin + chartHeight - (efficiency2 / maxEfficiency) * chartHeight

                                ctx.beginPath()
                                ctx.arc(x2, y2, 3, 0, 2 * Math.PI)
                                ctx.fill()
                            }
                        }

                        function drawPowerFactorCurve(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxPowerFactor) {
                            ctx.strokeStyle = "#2196F3"  // 蓝色
                            ctx.lineWidth = 2
                            ctx.beginPath()

                            var basePF = motorData.powerFactor || 0.85
                            var points = 30

                            for (var i = 0; i <= points; i++) {
                                var load = minLoad + (i * (maxLoad - minLoad) / points)

                                // 功率因数曲线
                                var pf
                                if (load < 25) {
                                    pf = basePF * 0.6 * (load / 25)
                                } else if (load <= 75) {
                                    pf = basePF * (0.6 + 0.4 * (load - 25) / 50)
                                } else {
                                    pf = basePF * (1 - 0.05 * (100 - load) / 25)
                                }

                                var x = leftMargin + ((load - minLoad) / (maxLoad - minLoad)) * chartWidth
                                var y = topMargin + chartHeight - (pf / maxPowerFactor) * chartHeight

                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            // 绘制数据点
                            ctx.fillStyle = "#2196F3"
                            for (var j = 0; j <= points; j += 5) {
                                var load2 = minLoad + (j * (maxLoad - minLoad) / points)

                                var pf2
                                if (load2 < 25) {
                                    pf2 = basePF * 0.6 * (load2 / 25)
                                } else if (load2 <= 75) {
                                    pf2 = basePF * (0.6 + 0.4 * (load2 - 25) / 50)
                                } else {
                                    pf2 = basePF * (1 - 0.05 * (100 - load2) / 25)
                                }

                                var x2 = leftMargin + ((load2 - minLoad) / (maxLoad - minLoad)) * chartWidth
                                var y2 = topMargin + chartHeight - (pf2 / maxPowerFactor) * chartHeight

                                ctx.beginPath()
                                ctx.arc(x2, y2, 2, 0, 2 * Math.PI)
                                ctx.fill()
                            }
                        }

                        function drawWorkingPoint(ctx, chartWidth, chartHeight, maxLoad, minLoad, maxEfficiency) {
                            if (!motorData || operatingPower <= 0) return

                            var loadPercent = (operatingPower / motorData.power) * 100

                            if (loadPercent < 0 || loadPercent > 120) return

                            // 计算该负载点的效率
                            var peakEfficiency = motorData.efficiency || 90
                            var efficiency
                            if (loadPercent < 20) {
                                efficiency = peakEfficiency * 0.7 * (loadPercent / 20)
                            } else if (loadPercent <= 75) {
                                efficiency = peakEfficiency * (0.7 + 0.3 * (loadPercent - 20) / 55)
                            } else if (loadPercent <= 100) {
                                efficiency = peakEfficiency * (1 - 0.02 * (loadPercent - 75) / 25)
                            } else {
                                efficiency = peakEfficiency * (0.98 - 0.08 * (loadPercent - 100) / 20)
                            }

                            var x = leftMargin + ((loadPercent - minLoad) / (maxLoad - minLoad)) * chartWidth
                            var y = topMargin + chartHeight - (efficiency / maxEfficiency) * chartHeight

                            // 参考线
                            ctx.strokeStyle = "#FF9800"
                            ctx.lineWidth = 2
                            ctx.setLineDash([5, 5])
                            ctx.beginPath()
                            ctx.moveTo(x, topMargin + chartHeight)
                            ctx.lineTo(x, y)
                            ctx.stroke()
                            ctx.setLineDash([])

                            // 工作点
                            ctx.fillStyle = "#F44336"
                            ctx.strokeStyle = "white"
                            ctx.lineWidth = 3
                            ctx.beginPath()
                            ctx.arc(x, y, 8, 0, 2 * Math.PI)
                            ctx.fill()
                            ctx.stroke()

                            // 标签
                            ctx.fillStyle = "#F44336"
                            ctx.font = "12px Arial"
                            ctx.textAlign = "left"
                            ctx.textBaseline = "bottom"
                            ctx.fillText(
                                (isChineseMode ? "工作点: " : "Operating Point: ") +
                                loadPercent.toFixed(1) + "%",
                                x + 12, y - 8
                            )
                        }

                        // 数据变化时重绘
                        Connections {
                            target: root
                            function onMotorDataChanged() {
                                motorCanvas.requestPaint()
                            }
                            function onOperatingPowerChanged() {
                                motorCanvas.requestPaint()
                            }
                            function onFrequencyChanged() {
                                motorCanvas.requestPaint()
                            }
                        }
                    }
                }

                // 数据信息栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: "#f8f9fa"
                    radius: 4
                    visible: motorData !== null

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        columns: 4
                        columnSpacing: 20
                        rowSpacing: 8

                        Text {
                            text: isChineseMode ? "额定功率: " : "Rated Power: "
                            font.pixelSize: 12
                            color: "#666"
                        }
                        Text {
                            text: motorData ? motorData.power + " HP" : "N/A"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#333"
                        }

                        Text {
                            text: isChineseMode ? "额定效率: " : "Rated Efficiency: "
                            font.pixelSize: 12
                            color: "#666"
                        }
                        Text {
                            text: motorData ? motorData.efficiency + "%" : "N/A"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#4CAF50"
                        }

                        Text {
                            text: isChineseMode ? "功率因数: " : "Power Factor: "
                            font.pixelSize: 12
                            color: "#666"
                        }
                        Text {
                            text: motorData ? motorData.powerFactor.toFixed(2) : "N/A"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#2196F3"
                        }

                        Text {
                            text: isChineseMode ? "工作负载: " : "Operating Load: "
                            font.pixelSize: 12
                            color: "#666"
                        }
                        Text {
                            text: motorData && operatingPower > 0 ?
                                  ((operatingPower / motorData.power) * 100).toFixed(1) + "%" : "N/A"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#F44336"
                        }
                    }
                }

                // 图例说明
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#f8f9fa"
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 30

                        // 效率曲线图例
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 20
                                height: 3
                                color: "#4CAF50"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: isChineseMode ? "效率曲线" : "Efficiency Curve"
                                font.pixelSize: 12
                                color: "#333"
                            }
                        }

                        // 功率因数曲线图例
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 20
                                height: 2
                                color: "#2196F3"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: isChineseMode ? "功率因数曲线" : "Power Factor Curve"
                                font.pixelSize: 12
                                color: "#333"
                            }
                        }

                        // 工作点图例
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "#F44336"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: isChineseMode ? "工作点" : "Operating Point"
                                font.pixelSize: 12
                                color: "#333"
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    // 公开接口
    function open() {
        if (motorData) {
            console.log("打开电机性能曲线图表")
            chartPopup.open()
            motorCanvas.requestPaint()
        }
    }

    function close() {
        chartPopup.close()
    }

    function updateChart(data, power, freq) {
        motorData = data
        operatingPower = power || 0
        frequency = freq || 60
    }
}
