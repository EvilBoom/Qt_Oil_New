// Qt_Oil_NewContent/DeviceRecommendation/Components/MultiConditionComparisonChart.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts

Rectangle {
    id: root

    property var controller: null
    property bool isChineseMode: true
    property var comparisonData: null

    signal conditionSelected(int index)
    signal requestDetailView(int index)

    color: Material.backgroundColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "多工况性能对比" : "Multi-Condition Performance Comparison"
                font.pixelSize: 18
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            Button {
                text: isChineseMode ? "导出报告" : "Export Report"
                Material.background: Material.accent
                onClicked: exportComparisonReport()
            }
        }

        // 对比图表区域
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                // 性能曲线对比
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 400
                    color: "white"
                    border.color: Material.dividerColor
                    border.width: 1
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: isChineseMode ? "性能曲线对比" : "Performance Curves Comparison"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        ChartView {
                            id: comparisonChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            legend.alignment: Qt.AlignBottom
                            legend.font.pixelSize: 10

                            ValueAxis {
                                id: flowAxis
                                titleText: isChineseMode ? "流量 (m³/d)" : "Flow Rate (m³/d)"
                                min: 0
                                max: getMaxFlow()
                            }

                            ValueAxis {
                                id: headAxis
                                titleText: isChineseMode ? "扬程 (m)" : "Head (m)"
                                min: 0
                                max: getMaxHead()
                            }

                            // 动态添加的曲线将在这里显示
                        }
                    }
                }

                // 性能指标对比表
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    color: "white"
                    border.color: Material.dividerColor
                    border.width: 1
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: isChineseMode ? "关键指标对比" : "Key Metrics Comparison"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            GridLayout {
                                id: metricsGrid
                                columns: 4
                                rowSpacing: 8
                                columnSpacing: 16

                                // 表头
                                Text {
                                    text: isChineseMode ? "工况" : "Condition"
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }
                                Text {
                                    text: isChineseMode ? "最高效率" : "Max Efficiency"
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }
                                Text {
                                    text: isChineseMode ? "BEP功率" : "BEP Power"
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }
                                Text {
                                    text: isChineseMode ? "综合评分" : "Overall Score"
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                // 动态添加的行将在这里显示
                            }
                        }
                    }
                }

                // 效率对比雷达图
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 350
                    color: "white"
                    border.color: Material.dividerColor
                    border.width: 1
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: isChineseMode ? "综合性能雷达图" : "Performance Radar Chart"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Canvas {
                                id: radarCanvas
                                anchors.fill: parent

                                onPaint: {
                                    drawRadarChart()
                                }
                            }
                        }
                    }
                }

                // 推荐工况卡片
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: "white"
                    border.color: Material.dividerColor
                    border.width: 1
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: isChineseMode ? "推荐方案" : "Recommendations"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 12

                            Repeater {
                                id: recommendationsRepeater
                                model: comparisonData ? comparisonData.recommendations : []

                                Rectangle {
                                    width: 180
                                    height: 120
                                    color: getRecommendationColor(modelData.priority)
                                    radius: 8
                                    border.color: Material.dividerColor
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        Text {
                                            text: modelData.title
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: "white"
                                            wrapMode: Text.Wrap
                                        }

                                        Text {
                                            text: modelData.condition
                                            font.pixelSize: 11
                                            color: "white"
                                            wrapMode: Text.Wrap
                                        }

                                        Text {
                                            text: modelData.value
                                            font.pixelSize: 10
                                            color: "white"
                                            font.bold: true
                                        }

                                        Text {
                                            text: modelData.description
                                            font.pixelSize: 9
                                            color: "white"
                                            wrapMode: Text.Wrap
                                            Layout.fillHeight: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            // 查找并选择对应工况
                                            if (comparisonData && comparisonData.conditions) {
                                                for (var i = 0; i < comparisonData.conditions.length; i++) {
                                                    if (comparisonData.conditions[i].label === modelData.condition) {
                                                        root.conditionSelected(i)
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 数据更新处理
    onComparisonDataChanged: {
        if (comparisonData) {
            updateComparisonChart()
            updateMetricsGrid()
            radarCanvas.requestPaint()
        }
    }

    // 函数定义
    function updateComparisonChart() {
        if (!comparisonData || !comparisonData.conditions) return

        // 清除现有曲线
        comparisonChart.removeAllSeries()

        // 为每个工况添加曲线
        for (var i = 0; i < comparisonData.conditions.length; i++) {
            var condition = comparisonData.conditions[i]
            var curves = condition.curves

            // 扬程曲线
            var headSeries = comparisonChart.createSeries(ChartView.SeriesTypeLine,
                                                        condition.label + " - Head",
                                                        flowAxis, headAxis)
            headSeries.color = condition.color
            headSeries.width = 2

            for (var j = 0; j < curves.flow.length; j++) {
                headSeries.append(curves.flow[j], curves.head[j])
            }
        }
    }

    function updateMetricsGrid() {
        if (!comparisonData || !comparisonData.conditions) return

        // 清除现有行（保留表头）
        for (var i = metricsGrid.children.length - 1; i >= 4; i--) {
            metricsGrid.children[i].destroy()
        }

        // 添加数据行
        for (var i = 0; i < comparisonData.conditions.length; i++) {
            var condition = comparisonData.conditions[i]
            var metrics = condition.metrics
            var evaluation = condition.evaluation

            // 工况名称
            var conditionLabel = Qt.createQmlObject(`
                import QtQuick
                import QtQuick.Controls.Material
                Text {
                    text: "${condition.label}"
                    color: "${condition.color}"
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.conditionSelected(${i})
                    }
                }
            `, metricsGrid)

            // 最高效率
            var efficiencyLabel = Qt.createQmlObject(`
                import QtQuick
                import QtQuick.Controls.Material
                Text {
                    text: "${metrics.efficiency_stats.max.toFixed(1)}%"
                    color: Material.secondaryTextColor
                }
            `, metricsGrid)

            // BEP功率
            var powerLabel = Qt.createQmlObject(`
                import QtQuick
                import QtQuick.Controls.Material
                Text {
                    text: "${metrics.power_consumption.at_bep.toFixed(1)} kW"
                    color: Material.secondaryTextColor
                }
            `, metricsGrid)

            // 综合评分
            var scoreLabel = Qt.createQmlObject(`
                import QtQuick
                import QtQuick.Controls.Material
                Text {
                    text: "${evaluation.overall_score.toFixed(0)}分"
                    color: "${getScoreColor(evaluation.overall_score)}"
                    font.bold: true
                }
            `, metricsGrid)
        }
    }

    function drawRadarChart() {
        if (!comparisonData || !comparisonData.conditions) return

        var ctx = radarCanvas.getContext("2d")
        ctx.clearRect(0, 0, radarCanvas.width, radarCanvas.height)

        var centerX = radarCanvas.width / 2
        var centerY = radarCanvas.height / 2
        var radius = Math.min(centerX, centerY) * 0.8

        // 绘制雷达图网格
        drawRadarGrid(ctx, centerX, centerY, radius)

        // 绘制各工况的性能多边形
        for (var i = 0; i < comparisonData.conditions.length; i++) {
            var condition = comparisonData.conditions[i]
            drawConditionPolygon(ctx, centerX, centerY, radius, condition)
        }

        // 绘制图例
        drawRadarLegend(ctx)
    }

    function drawRadarGrid(ctx, centerX, centerY, radius) {
        var metrics = ["效率", "可靠性", "能耗", "维护", "成本"]
        var angleStep = 2 * Math.PI / metrics.length

        ctx.strokeStyle = "#E0E0E0"
        ctx.lineWidth = 1

        // 绘制同心圆
        for (var i = 1; i <= 5; i++) {
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius * i / 5, 0, 2 * Math.PI)
            ctx.stroke()
        }

        // 绘制轴线和标签
        ctx.strokeStyle = "#BDBDBD"
        ctx.fillStyle = "#424242"
        ctx.font = "12px Arial"

        for (var i = 0; i < metrics.length; i++) {
            var angle = i * angleStep - Math.PI / 2
            var x = centerX + radius * Math.cos(angle)
            var y = centerY + radius * Math.sin(angle)

            // 轴线
            ctx.beginPath()
            ctx.moveTo(centerX, centerY)
            ctx.lineTo(x, y)
            ctx.stroke()

            // 标签
            var labelX = centerX + (radius + 20) * Math.cos(angle)
            var labelY = centerY + (radius + 20) * Math.sin(angle)
            ctx.fillText(metrics[i], labelX - 15, labelY + 5)
        }
    }

    function drawConditionPolygon(ctx, centerX, centerY, radius, condition) {
        var evaluation = condition.evaluation
        var values = [
            evaluation.efficiency_score / 100,
            evaluation.reliability_score / 100,
            evaluation.energy_score / 100,
            evaluation.maintenance_score / 100,
            (100 - evaluation.overall_score) / 100  // 成本（分数越高成本越低）
        ]

        var angleStep = 2 * Math.PI / values.length

        ctx.strokeStyle = condition.color
        ctx.fillStyle = condition.color + "40"  // 40% 透明度
        ctx.lineWidth = 2

        ctx.beginPath()
        for (var i = 0; i < values.length; i++) {
            var angle = i * angleStep - Math.PI / 2
            var r = radius * values[i]
            var x = centerX + r * Math.cos(angle)
            var y = centerY + r * Math.sin(angle)

            if (i === 0) {
                ctx.moveTo(x, y)
            } else {
                ctx.lineTo(x, y)
            }
        }
        ctx.closePath()
        ctx.fill()
        ctx.stroke()
    }

    function drawRadarLegend(ctx) {
        if (!comparisonData || !comparisonData.conditions) return

        var legendX = 20
        var legendY = 20

        ctx.font = "12px Arial"

        for (var i = 0; i < comparisonData.conditions.length; i++) {
            var condition = comparisonData.conditions[i]
            var y = legendY + i * 20

            // 颜色方块
            ctx.fillStyle = condition.color
            ctx.fillRect(legendX, y, 15, 15)

            // 标签
            ctx.fillStyle = "#424242"
            ctx.fillText(condition.label, legendX + 20, y + 12)
        }
    }

    function getMaxFlow() {
        if (!comparisonData || !comparisonData.conditions) return 2000

        var maxFlow = 0
        for (var i = 0; i < comparisonData.conditions.length; i++) {
            var flow = comparisonData.conditions[i].curves.flow
            maxFlow = Math.max(maxFlow, Math.max(...flow))
        }
        return maxFlow * 1.1
    }

    function getMaxHead() {
        if (!comparisonData || !comparisonData.conditions) return 100

        var maxHead = 0
        for (var i = 0; i < comparisonData.conditions.length; i++) {
            var head = comparisonData.conditions[i].curves.head
            maxHead = Math.max(maxHead, Math.max(...head))
        }
        return maxHead * 1.1
    }

    function getScoreColor(score) {
        if (score >= 80) return Material.color(Material.Green)
        if (score >= 60) return Material.color(Material.Orange)
        return Material.color(Material.Red)
    }

    function getRecommendationColor(priority) {
        switch (priority) {
            case 'high': return Material.color(Material.Green)
            case 'medium': return Material.color(Material.Orange)
            case 'low': return Material.color(Material.Blue)
            default: return Material.color(Material.Grey)
        }
    }

    function exportComparisonReport() {
        console.log("导出对比报告功能待实现")
        // TODO: 实现报告导出功能
    }
}
