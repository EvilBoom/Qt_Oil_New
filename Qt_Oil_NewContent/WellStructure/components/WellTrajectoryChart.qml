import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property bool isChineseMode: true
    property var chartData: null
    property string currentChartType: "tvd_md"

    width: 900
    height: 700
    color: "transparent"

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

                // 图表类型选择
                TabBar {
                    id: chartTabBar
                    Layout.fillWidth: true

                    TabButton {
                        text: isChineseMode ? "TVD-MD" : "TVD-MD"
                        property string chartType: "tvd_md"
                    }

                    TabButton {
                        text: isChineseMode ? "井斜角" : "Inclination"
                        property string chartType: "inclination"
                        enabled: chartData && chartData.inclination_data
                    }

                    TabButton {
                        text: isChineseMode ? "方位角" : "Azimuth"
                        property string chartType: "azimuth"
                        enabled: chartData && chartData.azimuth_data
                    }

                    TabButton {
                        text: isChineseMode ? "狗腿度" : "DLS"
                        property string chartType: "dls"
                        enabled: chartData && chartData.dls_data
                    }

                    // TabButton {
                    //     text: isChineseMode ? "3D轨迹" : "3D Trajectory"
                    //     property string chartType: "3d"
                    //     enabled: chartData && chartData.trajectory_3d
                    // }

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

                        property real leftMargin: 60
                        property real bottomMargin: 50
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

                        // 修正后的 drawTvdMdChart 函数
                        function drawTvdMdChart(ctx,data) {
                            if (!chartData.tvd_vs_md) {
                                console.error("没有井轨迹数据 (tvd_vs_md)")
                                return
                            }


                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 调试数据
                            console.log("Origindata:", JSON.stringify(data))
                            console.log("X_data:", data.x.length)
                            console.log("Y_data:", data.y.length)
                            console.log("X_range:", Math.min(...data.x), "到", Math.max(...data.x))
                            console.log("Y_range:", Math.min(...data.y), "到", Math.max(...data.y))

                            // 找到数据范围
                            var maxHD = Math.max(...data.x)
                            var minHD = Math.min(...data.x)
                            var maxTVD = Math.max(...data.y)
                            var minTVD = Math.min(...data.y)

                            // 检查数据有效性
                            if (maxHD === 0 && minHD === 0) {
                                console.error("错误：水平位移数据全为0，请检查数据源")
                                // 绘制错误信息
                                ctx.fillStyle = "#FF0000"
                                ctx.font = "14px sans-serif"
                                ctx.textAlign = "center"
                                ctx.textBaseline = "middle"
                                // ctx.fillText("数据错误：水平位移全为0", width / 2, height / 2)
                                ctx.fillText(isChineseMode ? "数据错误：水平位移全为0" : "True Vertical Depth (m)", 0, 0)

                                return
                            }

                            // 添加10%的边距以便更好地显示
                            var hdRange = maxHD - minHD
                            var tvdRange = maxTVD - minTVD

                            // 如果是垂直井（水平位移很小），需要特殊处理
                            if (hdRange < 10) {  // 假设单位是米，如果水平位移小于10米
                                minHD = -10  // 给一些负值空间
                                maxHD = Math.max(maxHD + 50, 100)  // 确保有足够的显示空间
                            } else {
                                minHD = minHD - hdRange * 0.1
                                maxHD = maxHD + hdRange * 0.1
                            }

                            // minTVD = minTVD - tvdRange * 0.05
                            minTVD = 0
                            maxTVD = maxTVD + tvdRange * 0.05

                            // 重新计算范围
                            hdRange = maxHD - minHD
                            tvdRange = maxTVD - minTVD

                            // 绘制曲线
                            ctx.strokeStyle = "#2196F3"
                            ctx.lineWidth = 3
                            ctx.beginPath()

                            for (var i = 0; i < data.x.length; i++) {
                                // 计算屏幕坐标
                                var x = leftMargin + ((data.x[i] - minHD) / hdRange) * chartWidth
                                // Y轴反转，深度向下增加
                                var y = topMargin + ((data.y[i] - minTVD) / tvdRange) * chartHeight

                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            // 绘制数据点（可选，数据点多时可以跳过）
                            if (data.x.length <= 50) {  // 只在数据点较少时绘制
                                ctx.fillStyle = "#2196F3"
                                for (var j = 0; j < data.x.length; j++) {
                                    var pointX = leftMargin + ((data.x[j] - minHD) / hdRange) * chartWidth
                                    var pointY = topMargin + ((data.y[j] - minTVD) / tvdRange) * chartHeight

                                    ctx.beginPath()
                                    ctx.arc(pointX, pointY, 2, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                            }

                            // 绘制起点和终点标记
                            ctx.fillStyle = "#00FF00"
                            var startX = leftMargin + ((data.x[0] - minHD) / hdRange) * chartWidth
                            var startY = topMargin + ((data.y[0] - minTVD) / tvdRange) * chartHeight
                            ctx.beginPath()
                            ctx.arc(startX, startY, 5, 0, 2 * Math.PI)
                            ctx.fill()

                            ctx.fillStyle = "#FF0000"
                            var endX = leftMargin + ((data.x[data.x.length-1] - minHD) / hdRange) * chartWidth
                            var endY = topMargin + ((data.y[data.y.length-1] - minTVD) / tvdRange) * chartHeight
                            ctx.beginPath()
                            ctx.arc(endX, endY, 5, 0, 2 * Math.PI)
                            ctx.fill()

                            // 绘制轴标签
                            ctx.fillStyle = "#333"
                            ctx.font = "14px sans-serif"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText(isChineseMode ? "水平位移 (m)" : "Horizontal Displacement (m)",
                                        leftMargin + chartWidth / 2, topMargin + chartHeight + 30)

                            // Y轴标签
                            ctx.save()
                            ctx.translate(20, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(isChineseMode ? "真实垂直深度 (m)" : "True Vertical Depth (m)", 0, 0)
                            ctx.restore()

                            // 绘制刻度
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

                            // 绘制特殊深度标记线
                            if (chartData.pumpHangingDepth && chartData.pumpHangingDepth >= minTVD && chartData.pumpHangingDepth <= maxTVD) {
                                drawHorizontalMarker(ctx, chartData.pumpHangingDepth, minTVD, tvdRange,
                                                    chartWidth, chartHeight, "#FF6B6B",
                                                    isChineseMode ? "泵挂" : "Pump Hanging Depth")
                            }

                            if (chartData.perforationDepth && chartData.perforationDepth >= minTVD && chartData.perforationDepth <= maxTVD) {
                                drawHorizontalMarker(ctx, chartData.perforationDepth, minTVD, tvdRange,
                                                    chartWidth, chartHeight, "#FFA500",
                                                    isChineseMode ? "射孔" : "Perforation Depth")
                            }

                            // if (chartData.topDepth && chartData.topDepth >= minTVD && chartData.topDepth <= maxTVD) {
                            //     drawHorizontalMarker(ctx, chartData.topDepth, minTVD, tvdRange,
                            //                         chartWidth, chartHeight, "#32CD32",
                            //                         isChineseMode ? "顶深" : "Top Depth")
                            // }
                        }

                        // 修正水平标记线函数
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
                            var textWidth = ctx.measureText(label + ": " + depth.toFixed(1) + "m").width
                            ctx.fillRect(leftMargin + 10, y - 18, textWidth + 10, 16)

                            // 添加标签文字
                            ctx.fillStyle = color
                            ctx.font = "bold 12px sans-serif"
                            ctx.textAlign = "left"
                            ctx.textBaseline = "bottom"
                            ctx.fillText(label + ": " + depth.toFixed(1) + "m", leftMargin + 15, y - 3)
                        }




                        function drawLineChart(ctx, data, color, ylabel) {
                            if (!data) return

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 找到数据范围
                            var maxX = Math.max(...data.x)
                            var minY = Math.min(...data.y)
                            var maxY = Math.max(...data.y)
                            var rangeY = maxY - minY || 1

                            // 绘制曲线
                            ctx.strokeStyle = color
                            ctx.lineWidth = 2
                            ctx.beginPath()

                            for (var i = 0; i < data.x.length; i++) {
                                var x = leftMargin + (data.x[i] / maxX) * chartWidth
                                var y = topMargin + chartHeight - ((data.y[i] - minY) / rangeY) * chartHeight

                                if (i === 0) {
                                    ctx.moveTo(x, y)
                                } else {
                                    ctx.lineTo(x, y)
                                }
                            }
                            ctx.stroke()

                            // 绘制标签
                            ctx.fillStyle = "#333"
                            ctx.font = "14px sans-serif"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText("MD (m)", leftMargin + chartWidth / 2, topMargin + chartHeight + 30)

                            // Y轴标签
                            ctx.save()
                            ctx.translate(20, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(ylabel, 0, 0)
                            ctx.restore()
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

                // 图例
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

    // 公开的接口函数
    function open() {
        chartPopup.open()
    }

    function close() {
        chartPopup.close()
    }

    // 更新图表数据
    function updateChart(data) {
        chartData = data
        console.log('now is updateCHart')
        console.log(data.tvd_vs_md.y)
        console.log('now finish update')
        canvas.requestPaint()
    }

    // 导出图表
    function exportChart() {
        // TODO: 实现图表导出功能
        console.log("Export chart")
    }
}
