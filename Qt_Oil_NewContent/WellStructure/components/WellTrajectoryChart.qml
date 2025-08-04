import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    property bool isChineseMode: true
    property var chartData: null
    property string currentChartType: "tvd_md"
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    width: 900
    height: 700
    color: "transparent"

    // 🔥 监听单位制变化
    onIsMetricChanged: {
        console.log("WellTrajectoryChart单位制切换为:", isMetric ? "公制" : "英制")
        updateChartUnits()
    }

    // 🔥 连接单位制控制器
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("WellTrajectoryChart单位制切换为:", isMetric ? "公制" : "英制")
            updateChartUnits()
        }
    }

    // 使用Popup代替Dialog
    Popup {
        id: chartPopup

        anchors.centerIn: parent
        width: 900
        height: 700
        modal: true

        background: Rectangle {
            color: "white"
            border.color: "#e0e0e0"
            border.width: 1
            radius: 8
        }

        // 标题栏
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: "#f5f5f5"
            radius: 8

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                color: parent.color
            }

            Label {
                anchors.centerIn: parent
                text: isChineseMode ? "井轨迹图表" : "Well Trajectory Charts"
                font.pixelSize: 16
                font.bold: true
            }

            Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                text: "✕"
                flat: true
                onClicked: chartPopup.close()
            }
        }

        // 内容区域
        contentItem: Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 60
                anchors.bottomMargin: 60
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                // 🔥 修改图表类型选择，显示单位信息
                TabBar {
                    id: chartTabBar
                    Layout.fillWidth: true

                    TabButton {
                        text: isChineseMode ?
                            `TVD-MD (${getDepthUnit()})` :
                            `TVD-MD (${getDepthUnit()})`
                        property string chartType: "tvd_md"
                    }

                    TabButton {
                        text: isChineseMode ? "井斜角 (°)" : "Inclination (°)"
                        property string chartType: "inclination"
                        enabled: chartData && chartData.inclination_data
                    }

                    TabButton {
                        text: isChineseMode ? "方位角 (°)" : "Azimuth (°)"
                        property string chartType: "azimuth"
                        enabled: chartData && chartData.azimuth_data
                    }

                    TabButton {
                        text: isChineseMode ?
                            `狗腿度 (${getDoglegUnit()})` :
                            `DLS (${getDoglegUnit()})`
                        property string chartType: "dls"
                        enabled: chartData && chartData.dls_data
                    }

                    onCurrentIndexChanged: {
                        currentChartType = itemAt(currentIndex).chartType
                        canvas.requestPaint()
                    }
                }

                // 图表画布
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    border.color: "#e0e0e0"
                    radius: 4

                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        anchors.margins: 20

                        property real leftMargin: 70  // 🔥 增加左边距以容纳单位标签
                        property real bottomMargin: 60  // 🔥 增加底部边距
                        property real rightMargin: 20
                        property real topMargin: 30

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            if (!chartData) {
                                drawEmptyState(ctx)
                                return
                            }

                            // 绘制坐标轴
                            drawAxes(ctx)

                            // 根据类型绘制图表
                            switch(currentChartType) {
                                case "tvd_md":
                                    drawTvdMdChart(ctx,chartData.tvd_vs_md)
                                    break
                                case "inclination":
                                    drawLineChart(ctx, chartData.inclination_data, "#4CAF50", "Inclination (°)")
                                    break
                                case "azimuth":
                                    drawLineChart(ctx, chartData.azimuth_data, "#2196F3", "Azimuth (°)")
                                    break
                                case "dls":
                                    drawLineChart(ctx, chartData.dls_data, "#FF9800", "DLS (°/30m)")
                                    break
                                case "3d":
                                    draw3DProjection(ctx)
                                    break
                            }

                            // 绘制标记点
                            if (chartData.markers && currentChartType === "tvd_md") {
                                drawMarkers(ctx)
                            }
                        }

                        function drawEmptyState(ctx) {
                            ctx.fillStyle = "#999"
                            ctx.font = "16px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "无图表数据" : "No chart data",
                                width / 2, height / 2
                            )
                        }

                        function drawAxes(ctx) {
                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            ctx.strokeStyle = "#333"
                            ctx.lineWidth = 2

                            // Y轴
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, topMargin)
                            ctx.lineTo(leftMargin, topMargin + chartHeight)
                            ctx.stroke()

                            // X轴
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, topMargin + chartHeight)
                            ctx.lineTo(leftMargin + chartWidth, topMargin + chartHeight)
                            ctx.stroke()

                            // 网格线
                            ctx.strokeStyle = "#f0f0f0"
                            ctx.lineWidth = 1

                            // 水平网格线
                            for (var i = 1; i < 10; i++) {
                                var y = topMargin + (chartHeight * i / 10)
                                ctx.beginPath()
                                ctx.moveTo(leftMargin, y)
                                ctx.lineTo(leftMargin + chartWidth, y)
                                ctx.stroke()
                            }

                            // 垂直网格线
                            for (var j = 1; j < 10; j++) {
                                var x = leftMargin + (chartWidth * j / 10)
                                ctx.beginPath()
                                ctx.moveTo(x, topMargin)
                                ctx.lineTo(x, topMargin + chartHeight)
                                ctx.stroke()
                            }
                        }

                        // 🔥 修改TVD-MD图表绘制，支持单位转换
                        function drawTvdMdChart(ctx, data) {
                            if (!chartData.tvd_vs_md) {
                                console.error("没有井轨迹数据 (tvd_vs_md)")
                                return
                            }

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 🔥 转换数据单位
                            var convertedData = convertTrajectoryData(data)

                            // 调试数据
                            console.log("原始数据:", JSON.stringify(data))
                            console.log("转换后数据:", JSON.stringify(convertedData))
                            console.log("X_data:", convertedData.x.length)
                            console.log("Y_data:", convertedData.y.length)

                            var convertedX = convertedData.x
                            var convertedY = convertedData.y

                            // 找到数据范围
                            var maxHD = Math.max(...convertedX)
                            var minHD = Math.min(...convertedX)
                            var maxTVD = Math.max(...convertedY)
                            var minTVD = Math.min(...convertedY)

                            // 检查数据有效性
                            if (maxHD === 0 && minHD === 0) {
                                console.error("错误：水平位移数据全为0，请检查数据源")
                                ctx.fillStyle = "#FF0000"
                                ctx.font = "14px sans-serif"
                                ctx.textAlign = "center"
                                ctx.textBaseline = "middle"
                                ctx.fillText(isChineseMode ? "数据错误：水平位移全为0" : "Data error: Zero horizontal displacement", width / 2, height / 2)
                                return
                            }

                            // 添加边距以便更好地显示
                            var hdRange = maxHD - minHD
                            var tvdRange = maxTVD - minTVD

                            // 如果是垂直井（水平位移很小），需要特殊处理
                            var minDisplayRange = isMetric ? 10 : 33  // 10m 或 33ft
                            if (hdRange < minDisplayRange) {
                                var extraRange = Math.max(minDisplayRange, maxHD + minDisplayRange)
                                minHD = -extraRange * 0.1
                                maxHD = Math.max(maxHD + extraRange * 0.5, extraRange)
                            } else {
                                minHD = minHD - hdRange * 0.1
                                maxHD = maxHD + hdRange * 0.1
                            }

                            minTVD = 0
                            maxTVD = maxTVD + tvdRange * 0.05

                            // 重新计算范围
                            hdRange = maxHD - minHD
                            tvdRange = maxTVD - minTVD

                            // 绘制曲线
                            ctx.strokeStyle = "#2196F3"
                            ctx.lineWidth = 3
                            ctx.beginPath()

                            for (var i = 0; i < convertedX.length; i++) {
                                var x = leftMargin + ((convertedX[i] - minHD) / hdRange) * chartWidth
                                var y = topMargin + ((convertedY[i] - minTVD) / tvdRange) * chartHeight

                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            // 绘制数据点（可选）
                            if (convertedX.length <= 50) {
                                ctx.fillStyle = "#2196F3"
                                for (var j = 0; j < convertedX.length; j++) {
                                    var pointX = leftMargin + ((convertedX[j] - minHD) / hdRange) * chartWidth
                                    var pointY = topMargin + ((convertedY[j] - minTVD) / tvdRange) * chartHeight

                                    ctx.beginPath()
                                    ctx.arc(pointX, pointY, 2, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                            }

                            // 绘制起点和终点标记
                            ctx.fillStyle = "#00FF00"
                            var startX = leftMargin + ((convertedX[0] - minHD) / hdRange) * chartWidth
                            var startY = topMargin + ((convertedY[0] - minTVD) / tvdRange) * chartHeight
                            ctx.beginPath()
                            ctx.arc(startX, startY, 5, 0, 2 * Math.PI)
                            ctx.fill()

                            ctx.fillStyle = "#FF0000"
                            var endX = leftMargin + ((convertedX[convertedX.length-1] - minHD) / hdRange) * chartWidth
                            var endY = topMargin + ((convertedY[convertedY.length-1] - minTVD) / tvdRange) * chartHeight
                            ctx.beginPath()
                            ctx.arc(endX, endY, 5, 0, 2 * Math.PI)
                            ctx.fill()

                            // 🔥 绘制轴标签，显示当前单位
                            ctx.fillStyle = "#333"
                            ctx.font = "14px sans-serif"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            var xAxisLabel = isChineseMode ?
                                `水平位移 (${getDepthUnit()})` :
                                `Horizontal Displacement (${getDepthUnit()})`
                            ctx.fillText(xAxisLabel, leftMargin + chartWidth / 2, topMargin + chartHeight + 35)

                            // Y轴标签
                            ctx.save()
                            ctx.translate(25, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            var yAxisLabel = isChineseMode ?
                                `真实垂直深度 (${getDepthUnit()})` :
                                `True Vertical Depth (${getDepthUnit()})`
                            ctx.fillText(yAxisLabel, 0, 0)
                            ctx.restore()

                            // 🔥 绘制刻度，显示转换后的单位
                            ctx.font = "12px sans-serif"
                            ctx.fillStyle = "#666"

                            // Y轴刻度（深度）
                            ctx.textAlign = "right"
                            ctx.textBaseline = "middle"
                            for (var k = 0; k <= 10; k++) {
                                var yVal = minTVD + (tvdRange * k / 10)
                                var yPos = topMargin + (chartHeight * k / 10)
                                ctx.fillText(yVal.toFixed(0), leftMargin - 10, yPos)
                            }

                            // X轴刻度（水平位移）
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            for (var l = 0; l <= 10; l++) {
                                var xVal = minHD + (hdRange * l / 10)
                                var xPos = leftMargin + (chartWidth * l / 10)
                                ctx.fillText(xVal.toFixed(0), xPos, topMargin + chartHeight + 5)
                            }

                            // 🔥 绘制特殊深度标记线，支持单位转换
                            if (chartData.pumpHangingDepth) {
                                var pumpDepthConverted = convertDepthValue(chartData.pumpHangingDepth, "ft")
                                if (pumpDepthConverted >= minTVD && pumpDepthConverted <= maxTVD) {
                                    drawHorizontalMarker(ctx, pumpDepthConverted, minTVD, tvdRange,
                                                        chartWidth, chartHeight, "#FF6B6B",
                                                        isChineseMode ? "泵挂" : "Pump Hanging Depth")
                                }
                            }

                            if (chartData.perforationDepth) {
                                var perfDepthConverted = convertDepthValue(chartData.perforationDepth, "ft")
                                if (perfDepthConverted >= minTVD && perfDepthConverted <= maxTVD) {
                                    drawHorizontalMarker(ctx, perfDepthConverted, minTVD, tvdRange,
                                                        chartWidth, chartHeight, "#FFA500",
                                                        isChineseMode ? "射孔" : "Perforation Depth")
                                }
                            }
                        }

                        // 🔥 修改水平标记线函数，使用当前单位
                        function drawHorizontalMarker(ctx, depth, minDepth, depthRange, chartWidth, chartHeight, color, label) {
                            var y = topMargin + ((depth - minDepth) / depthRange) * chartHeight

                            ctx.strokeStyle = color
                            ctx.lineWidth = 2
                            ctx.setLineDash([8, 4])
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, y)
                            ctx.lineTo(leftMargin + chartWidth, y)
                            ctx.stroke()
                            ctx.setLineDash([])

                            // 添加标签背景
                            ctx.fillStyle = "rgba(255, 255, 255, 0.8)"
                            var labelText = `${label}: ${depth.toFixed(1)} ${getDepthUnit()}`
                            var textWidth = ctx.measureText(labelText).width
                            ctx.fillRect(leftMargin + 10, y - 18, textWidth + 10, 16)

                            // 添加标签文字
                            ctx.fillStyle = color
                            ctx.font = "bold 12px sans-serif"
                            ctx.textAlign = "left"
                            ctx.textBaseline = "bottom"
                            ctx.fillText(labelText, leftMargin + 15, y - 3)
                        }

                        // 🔥 修改线图绘制，支持单位转换
                        function drawLineChart(ctx, data, color, ylabel) {
                            if (!data) return

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 🔥 转换X轴数据（深度）
                            var convertedX = data.x.map(function(value) {
                                return convertDepthValue(value, "m")  // 假设原始数据是米
                            })

                            var convertedY = data.y

                            // 如果是狗腿度数据，需要转换Y轴
                            if (currentChartType === "dls") {
                                convertedY = data.y.map(function(value) {
                                    return convertDoglegSeverity(value)
                                })
                            }

                            // 找到数据范围
                            var maxX = Math.max(...convertedX)
                            var minY = Math.min(...convertedY)
                            var maxY = Math.max(...convertedY)
                            var rangeY = maxY - minY || 1

                            // 绘制曲线
                            ctx.strokeStyle = color
                            ctx.lineWidth = 2
                            ctx.beginPath()

                            for (var i = 0; i < convertedX.length; i++) {
                                var x = leftMargin + (convertedX[i] / maxX) * chartWidth
                                var y = topMargin + chartHeight - ((convertedY[i] - minY) / rangeY) * chartHeight

                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            // 🔥 绘制标签，显示当前单位
                            ctx.fillStyle = "#333"
                            ctx.font = "14px sans-serif"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            var xAxisLabel = isChineseMode ?
                                `测量深度 (${getDepthUnit()})` :
                                `MD (${getDepthUnit()})`
                            ctx.fillText(xAxisLabel, leftMargin + chartWidth / 2, topMargin + chartHeight + 35)

                            // Y轴标签
                            ctx.save()
                            ctx.translate(25, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(ylabel, 0, 0)
                            ctx.restore()

                            // 🔥 绘制刻度，显示转换后的单位
                            ctx.font = "12px sans-serif"
                            ctx.fillStyle = "#666"

                            // X轴刻度（深度）
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            for (var j = 0; j <= 10; j++) {
                                var xVal = (maxX * j / 10)
                                var xPos = leftMargin + (chartWidth * j / 10)
                                ctx.fillText(xVal.toFixed(0), xPos, topMargin + chartHeight + 5)
                            }

                            // Y轴刻度
                            ctx.textAlign = "right"
                            ctx.textBaseline = "middle"
                            for (var k = 0; k <= 10; k++) {
                                var yVal = minY + (rangeY * k / 10)
                                var yPos = topMargin + chartHeight - (chartHeight * k / 10)
                                ctx.fillText(yVal.toFixed(1), leftMargin - 10, yPos)
                            }
                        }

                        function drawMarkers(ctx) {
                            if (!chartData.markers || !chartData.tvd_vs_md) return

                            var data = chartData.tvd_vs_md
                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin
                            var maxMD = Math.max(...data.x)
                            var maxTVD = Math.max(...data.y)

                            chartData.markers.forEach(function(marker) {
                                // 找到对应的MD值（简化处理）
                                var markerMD = marker.tvd * (maxMD / maxTVD) // 近似值

                                var x = leftMargin + (markerMD / maxMD) * chartWidth
                                var y = topMargin + (marker.tvd / maxTVD) * chartHeight

                                // 绘制标记线
                                ctx.strokeStyle = marker.color
                                ctx.lineWidth = 2
                                ctx.setLineDash([5, 5])
                                ctx.beginPath()
                                ctx.moveTo(leftMargin, y)
                                ctx.lineTo(leftMargin + chartWidth, y)
                                ctx.stroke()
                                ctx.setLineDash([])

                                // 绘制标记点
                                ctx.fillStyle = marker.color
                                ctx.beginPath()
                                ctx.arc(x, y, 5, 0, 2 * Math.PI)
                                ctx.fill()

                                // 绘制标签
                                ctx.fillStyle = marker.color
                                ctx.font = "12px sans-serif"
                                ctx.textAlign = "left"
                                ctx.textBaseline = "bottom"
                                ctx.fillText(marker.label, x + 10, y - 5)
                            })
                        }

                        function draw3DProjection(ctx) {
                            // TODO: 实现3D轨迹的2D投影
                            ctx.fillStyle = "#666"
                            ctx.font = "16px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "3D视图开发中..." : "3D view under development...",
                                width / 2, height / 2
                            )
                        }
                    }
                }

                // 🔥 修改图例，显示单位信息
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20
                    visible: chartData && chartData.markers && currentChartType === "tvd_md"

                    Repeater {
                        model: chartData ? chartData.markers : []

                        Row {
                            spacing: 5

                            Rectangle {
                                width: 20
                                height: 3
                                color: modelData.color
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Label {
                                text: modelData.label
                                font.pixelSize: 12
                                color: "#666"
                            }
                        }
                    }

                    // 🔥 添加单位说明
                    Text {
                        text: isChineseMode ?
                            `单位: ${getDepthUnit()}` :
                            `Unit: ${getDepthUnit()}`
                        font.pixelSize: 10
                        color: "#999"
                        font.italic: true
                    }
                }
            }
        }

        // 底部按钮栏
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            color: "#f5f5f5"

            Row {
                anchors.centerIn: parent
                spacing: 20

                Button {
                    text: isChineseMode ? "导出图表" : "Export Chart"
                    onClicked: exportChart()
                }

                Button {
                    text: isChineseMode ? "关闭" : "Close"
                    onClicked: chartPopup.close()
                }
            }
        }
    }

    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDoglegUnit() {
        return isMetric ? "°/30m" : "°/100ft"
    }

    function convertDepthValue(value, sourceUnit) {
        if (!value || value <= 0) return 0

        if (sourceUnit === "ft") {
            // 源数据是英尺
            if (isMetric) {
                return UnitUtils.feetToMeters(value)
            } else {
                return value
            }
        } else if (sourceUnit === "m") {
            // 源数据是米
            if (isMetric) {
                return value
            } else {
                return UnitUtils.metersToFeet(value)
            }
        }

        return value
    }

    function convertDoglegSeverity(value) {
        if (!value || value <= 0) return 0

        if (isMetric) {
            // 转换为 °/30m
            return value * (30.48 / 30)
        }
        // 英制保持原值 (°/100ft)
        return value
    }

    function convertTrajectoryData(data) {
        if (!data || !data.x || !data.y) {
            return { x: [], y: [] }
        }

        // 🔥 转换轨迹数据 - 假设原始数据是米
        var convertedX = data.x.map(function(value) {
            return convertDepthValue(value, "m")
        })

        var convertedY = data.y.map(function(value) {
            return convertDepthValue(value, "m")
        })

        return {
            x: convertedX,
            y: convertedY
        }
    }

    function updateChartUnits() {
        console.log("更新井轨迹图表单位显示")
        if (canvas) {
            canvas.requestPaint()
        }
    }

    // 公开的接口函数
    function open() {
        chartPopup.open()
    }

    function close() {
        chartPopup.close()
    }

    // 🔥 修改更新图表数据函数
    function updateChart(data) {
        chartData = data
        console.log('井轨迹图表数据更新，当前单位制:', isMetric ? "公制" : "英制")
        console.log('原始数据:', data.tvd_vs_md ? data.tvd_vs_md.y : "无数据")

        // 转换数据用于显示
        if (data && data.tvd_vs_md) {
            var convertedData = convertTrajectoryData(data.tvd_vs_md)
            console.log('转换后数据范围 - X:', Math.min(...convertedData.x), "到", Math.max(...convertedData.x))
            console.log('转换后数据范围 - Y:', Math.min(...convertedData.y), "到", Math.max(...convertedData.y))
        }

        canvas.requestPaint()
    }

    // 🔥 修改导出图表函数，包含单位信息
    function exportChart() {
        if (!chartData) {
            console.log("没有可导出的图表数据")
            return
        }

        var exportData = {
            title: isChineseMode ? "井轨迹图表" : "Well Trajectory Chart",
            timestamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss"),
            unitSystem: isMetric ? "Metric" : "Imperial",
            depthUnit: getDepthUnit(),
            chartType: currentChartType,
            data: chartData,
            convertedData: chartData.tvd_vs_md ? convertTrajectoryData(chartData.tvd_vs_md) : null
        }

        console.log("导出井轨迹图表数据:", JSON.stringify(exportData, null, 2))
        console.log("导出功能开发中...")
    }

    // 🔥 添加调试函数
    function debugUnitConversion() {
        console.log("=== 井轨迹图表单位转换调试 ===")
        console.log("当前单位制:", isMetric ? "公制" : "英制")
        console.log("深度单位:", getDepthUnit())
        console.log("狗腿度单位:", getDoglegUnit())

        if (chartData && chartData.tvd_vs_md) {
            var original = chartData.tvd_vs_md
            var converted = convertTrajectoryData(original)
            console.log("原始数据点数:", original.x.length)
            console.log("转换后数据点数:", converted.x.length)
            console.log("原始X范围:", Math.min(...original.x), "-", Math.max(...original.x))
            console.log("转换后X范围:", Math.min(...converted.x), "-", Math.max(...converted.x))
        }
    }
}
