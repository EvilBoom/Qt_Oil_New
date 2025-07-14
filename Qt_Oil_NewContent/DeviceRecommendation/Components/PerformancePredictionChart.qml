// Qt_Oil_NewContent/DeviceRecommendation/Components/PerformancePredictionChart.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts

Rectangle {
    id: root

    property var controller: null
    property bool isChineseMode: true
    property var predictionData: null
    property int selectedYears: 5

    signal predictionYearsChanged(int years)
    signal wearSimulationRequested(real wearPercentage)

    color: Material.backgroundColor

    // 🔥 修复：将信号处理器放在根级别
    onPredictionDataChanged: {
        console.log("PerformancePredictionChart: 数据更新")
        if (predictionData) {
            console.log("PerformancePredictionChart: 数据详情", JSON.stringify(predictionData, null, 2))
            Qt.callLater(updatePredictionCharts)
        }
    }

    onSelectedYearsChanged: {
        Qt.callLater(updateAxisRanges)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // 控制栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "性能预测与趋势分析" : "Performance Prediction & Trend Analysis"
                font.pixelSize: 18
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 16

                Column {
                    Text {
                        text: isChineseMode ? "预测年限:" : "Prediction Years:"
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                    SpinBox {
                        id: yearsSpinBox
                        from: 1
                        to: 15
                        value: selectedYears
                        onValueChanged: {
                            if (value !== selectedYears) {
                                selectedYears = value
                                root.predictionYearsChanged(value)
                            }
                        }
                    }
                }

                Column {
                    Text {
                        text: isChineseMode ? "磨损仿真(%):" : "Wear Simulation(%):"
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                    Slider {
                        id: wearSlider
                        from: 0
                        to: 100
                        value: 0
                        stepSize: 5

                        onValueChanged: {
                            root.wearSimulationRequested(value)
                        }

                        background: Rectangle {
                            x: wearSlider.leftPadding
                            y: wearSlider.topPadding + wearSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: wearSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: Material.dividerColor

                            Rectangle {
                                width: wearSlider.visualPosition * parent.width
                                height: parent.height
                                color: getWearColor(wearSlider.value)
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: wearSlider.leftPadding + wearSlider.visualPosition * (wearSlider.availableWidth - width)
                            y: wearSlider.topPadding + wearSlider.availableHeight / 2 - height / 2
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 10
                            color: wearSlider.pressed ? Material.accent : "white"
                            border.color: Material.accent
                        }
                    }
                }
            }
        }

        // 预测图表区域
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                // 性能衰减趋势图
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
                            text: isChineseMode ? "性能衰减趋势" : "Performance Degradation Trend"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        ChartView {
                            id: degradationChart
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            legend.alignment: Qt.AlignBottom
                            legend.font.pixelSize: 10

                            ValuesAxis {
                                id: yearAxis
                                titleText: isChineseMode ? "年份" : "Years"
                                min: 0
                                max: selectedYears
                                tickCount: selectedYears + 1
                            }

                            ValuesAxis {
                                id: performanceAxis
                                titleText: isChineseMode ? "性能指标 (%)" : "Performance (%)"
                                min: 0
                                max: 110
                            }

                            LineSeries {
                                id: efficiencySeries
                                name: isChineseMode ? "效率" : "Efficiency"
                                axisX: yearAxis
                                axisY: performanceAxis
                                color: "#4CAF50"
                                width: 2
                            }

                            LineSeries {
                                id: flowSeries
                                name: isChineseMode ? "流量" : "Flow"
                                axisX: yearAxis
                                axisY: performanceAxis
                                color: "#2196F3"
                                width: 2
                            }

                            LineSeries {
                                id: headSeries
                                name: isChineseMode ? "扬程" : "Head"
                                axisX: yearAxis
                                axisY: performanceAxis
                                color: "#FF9800"
                                width: 2
                            }
                        }
                    }
                }

                // 成本分析图
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
                            text: isChineseMode ? "生命周期成本分析" : "Lifecycle Cost Analysis"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            // 年度成本曲线
                            ChartView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                title: isChineseMode ? "年度成本趋势" : "Annual Cost Trend"
                                titleFont.pixelSize: 12

                                legend.alignment: Qt.AlignRight
                                legend.font.pixelSize: 9

                                ValuesAxis {
                                    id: costYearAxis
                                    titleText: isChineseMode ? "年份" : "Years"
                                    min: 0
                                    max: selectedYears
                                }

                                ValuesAxis {
                                    id: costAxis
                                    titleText: isChineseMode ? "成本 (千元)" : "Cost (K$)"
                                    min: 0
                                    max: getCostAxisMax()
                                }

                                AreaSeries {
                                    id: energyCostSeries
                                    name: isChineseMode ? "能源成本" : "Energy Cost"
                                    axisX: costYearAxis
                                    axisY: costAxis
                                    color: "#FF5722"
                                    borderColor: "#FF5722"
                                    opacity: 0.7

                                    upperSeries: LineSeries {
                                        id: energyCostUpper
                                    }
                                    lowerSeries: LineSeries {
                                        id: energyCostLower
                                    }
                                }

                                AreaSeries {
                                    id: maintenanceCostSeries
                                    name: isChineseMode ? "维护成本" : "Maintenance Cost"
                                    axisX: costYearAxis
                                    axisY: costAxis
                                    color: "#9C27B0"
                                    borderColor: "#9C27B0"
                                    opacity: 0.7

                                    upperSeries: LineSeries {
                                        id: maintenanceCostUpper
                                    }
                                    lowerSeries: LineSeries {
                                        id: maintenanceCostLower
                                    }
                                }
                            }

                            // 成本饼图
                            ChartView {
                                Layout.preferredWidth: 250
                                Layout.fillHeight: true

                                title: isChineseMode ? "成本构成" : "Cost Breakdown"
                                titleFont.pixelSize: 12

                                legend.alignment: Qt.AlignBottom
                                legend.font.pixelSize: 9

                                PieSeries {
                                    id: costBreakdownSeries

                                    PieSlice {
                                        id: initialCostSlice
                                        label: isChineseMode ? "初始成本" : "Initial Cost"
                                        color: "#2196F3"
                                        value: 0
                                    }

                                    PieSlice {
                                        id: energyCostSlice
                                        label: isChineseMode ? "能源成本" : "Energy Cost"
                                        color: "#FF5722"
                                        value: 0
                                    }

                                    PieSlice {
                                        id: maintenanceCostSlice
                                        label: isChineseMode ? "维护成本" : "Maintenance Cost"
                                        color: "#9C27B0"
                                        value: 0
                                    }
                                }
                            }
                        }
                    }
                }

                // 磨损分析和维护计划
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
                            text: isChineseMode ? "磨损分析与维护计划" : "Wear Analysis & Maintenance Schedule"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16

                            // 磨损进程图
                            Rectangle {
                                Layout.preferredWidth: 300
                                Layout.fillHeight: true
                                color: Material.backgroundColor
                                radius: 4

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8

                                    Text {
                                        text: isChineseMode ? "磨损进程" : "Wear Progression"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    ListView {
                                        id: wearProgressionList
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        model: predictionData && predictionData.wear_progression ? predictionData.wear_progression : []

                                        delegate: Rectangle {
                                            width: wearProgressionList.width
                                            height: 40
                                            color: index % 2 === 0 ? "transparent" : Material.backgroundColor

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8

                                                Text {
                                                    text: isChineseMode ? `第${modelData.year}年` : `Year ${modelData.year}`
                                                    font.pixelSize: 11
                                                    color: Material.primaryTextColor
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 8
                                                    radius: 4
                                                    color: Material.dividerColor

                                                    Rectangle {
                                                        width: parent.width * (modelData.wear_factor || 0)
                                                        height: parent.height
                                                        radius: parent.radius
                                                        color: getWearLevelColor(modelData.wear_level || 'minimal')
                                                    }
                                                }

                                                Text {
                                                    text: `${((modelData.wear_factor || 0) * 100).toFixed(0)}%`
                                                    font.pixelSize: 10
                                                    color: Material.secondaryTextColor
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 维护计划表
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: Material.backgroundColor
                                radius: 4

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8

                                    Text {
                                        text: isChineseMode ? "建议维护计划" : "Recommended Maintenance Schedule"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    ListView {
                                        id: maintenanceScheduleList
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        model: predictionData && predictionData.maintenance_schedule ? predictionData.maintenance_schedule : []

                                        delegate: Rectangle {
                                            width: maintenanceScheduleList.width
                                            height: 60
                                            color: index % 2 === 0 ? "transparent" : Material.backgroundColor

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 8

                                                Rectangle {
                                                    width: 4
                                                    Layout.fillHeight: true
                                                    color: getMaintenancePriorityColor(modelData.priority || 'low')
                                                    radius: 2
                                                }

                                                Column {
                                                    Layout.fillWidth: true
                                                    spacing: 2

                                                    Text {
                                                        text: `${modelData.year || 0}年${modelData.month || 1}月 - ${modelData.description || ''}`
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: Material.primaryTextColor
                                                    }

                                                    Text {
                                                        text: isChineseMode
                                                              ? `预计成本: ¥${(modelData.estimated_cost || 0).toFixed(0)} | 停机时间: ${modelData.downtime_days || 0}天`
                                                              : `Est. Cost: $${(modelData.estimated_cost || 0).toFixed(0)} | Downtime: ${modelData.downtime_days || 0} days`
                                                        font.pixelSize: 10
                                                        color: Material.secondaryTextColor
                                                    }
                                                }

                                                Rectangle {
                                                    width: 60
                                                    height: 20
                                                    radius: 10
                                                    color: getMaintenancePriorityColor(modelData.priority || 'low')

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: getMaintenancePriorityText(modelData.priority || 'low')
                                                        font.pixelSize: 9
                                                        color: "white"
                                                        font.bold: true
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

                // 关键性能指标卡片
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    color: "white"
                    border.color: Material.dividerColor
                    border.width: 1
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: isChineseMode ? "关键性能指标预测" : "Key Performance Indicators Prediction"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 16

                            Repeater {
                                model: [
                                    {
                                        key: "efficiency_degradation",
                                        title: isChineseMode ? "效率衰减" : "Efficiency Loss",
                                        unit: "%",
                                        color: "#F44336"
                                    },
                                    {
                                        key: "power_increase",
                                        title: isChineseMode ? "功率增加" : "Power Increase",
                                        unit: "%",
                                        color: "#FF9800"
                                    },
                                    {
                                        key: "reliability_decrease",
                                        title: isChineseMode ? "可靠性下降" : "Reliability Drop",
                                        unit: "%",
                                        color: "#9C27B0"
                                    },
                                    {
                                        key: "total_lifecycle_cost",
                                        title: isChineseMode ? "生命周期成本" : "Lifecycle Cost",
                                        unit: isChineseMode ? "万元" : "K$",
                                        color: "#607D8B"
                                    }
                                ]

                                Rectangle {
                                    width: 160
                                    height: 80
                                    color: Material.dialogColor
                                    radius: 8
                                    border.color: modelData.color
                                    border.width: 2

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.title
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: getKPIValue(modelData.key) + " " + modelData.unit
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: modelData.color
                                        }

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 80
                                            height: 4
                                            radius: 2
                                            color: modelData.color
                                            opacity: 0.3
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 预测总结和建议
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
                            text: isChineseMode ? "预测总结与建议" : "Prediction Summary & Recommendations"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                width: parent.width
                                spacing: 8

                                // 设备更换建议
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 60
                                    color: Material.backgroundColor
                                    radius: 4
                                    visible: predictionData && predictionData.performance_degradation &&
                                            predictionData.performance_degradation.replacement_recommendation &&
                                            predictionData.performance_degradation.replacement_recommendation.recommended_year !== null

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12

                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: Material.color(Material.Orange)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "⚠"
                                                font.pixelSize: 20
                                                color: "white"
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: isChineseMode ? "设备更换建议" : "Equipment Replacement Recommendation"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }

                                            Text {
                                                text: predictionData && predictionData.performance_degradation && predictionData.performance_degradation.replacement_recommendation ?
                                                      `${isChineseMode ? "建议在第" : "Recommended in year "}${predictionData.performance_degradation.replacement_recommendation.recommended_year}${isChineseMode ? "年进行设备更换" : " for equipment replacement"}` : ""
                                                font.pixelSize: 11
                                                color: Material.secondaryTextColor
                                                wrapMode: Text.Wrap
                                            }
                                        }

                                        Button {
                                            text: isChineseMode ? "查看详情" : "View Details"
                                            Material.background: Material.accent
                                            onClicked: showReplacementDetails()
                                        }
                                    }
                                }

                                // 优化建议
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    color: Material.backgroundColor
                                    radius: 4

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12

                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: Material.color(Material.Green)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "💡"
                                                font.pixelSize: 16
                                                color: "white"
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: isChineseMode ? "性能优化建议" : "Performance Optimization Recommendations"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }

                                            Text {
                                                text: getOptimizationRecommendations()
                                                font.pixelSize: 11
                                                color: Material.secondaryTextColor
                                                wrapMode: Text.Wrap
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

    // 🔥 =============================================================================
    // 🔥 所有函数定义放在根级别
    // 🔥 =============================================================================

    function updatePredictionCharts() {
        console.log("PerformancePredictionChart: 开始更新图表")

        if (!predictionData || !predictionData.annual_predictions) {
            console.log("PerformancePredictionChart: 没有预测数据")
            return
        }

        console.log("PerformancePredictionChart: 更新性能衰减图表")

        // 更新性能衰减图
        efficiencySeries.clear()
        flowSeries.clear()
        headSeries.clear()

        var predictions = predictionData.annual_predictions
        if (predictions.length === 0) {
            console.log("PerformancePredictionChart: 预测数据为空")
            return
        }

        var baseEfficiency = predictions[0].efficiency || 75
        var baseFlow = predictions[0].flow || 1000
        var baseHead = predictions[0].head || 200

        for (var i = 0; i < predictions.length; i++) {
            var prediction = predictions[i]

            // 转换为百分比（相对于初始值）
            var efficiencyPercent = (prediction.efficiency / baseEfficiency) * 100
            var flowPercent = (prediction.flow / baseFlow) * 100
            var headPercent = (prediction.head / baseHead) * 100

            efficiencySeries.append(prediction.year, efficiencyPercent)
            flowSeries.append(prediction.year, flowPercent)
            headSeries.append(prediction.year, headPercent)
        }

        console.log("PerformancePredictionChart: 性能图表更新完成")

        // 更新成本图
        updateCostCharts()

        // 更新成本饼图
        updateCostBreakdown()
    }

    function updateCostCharts() {
        if (!predictionData || !predictionData.annual_predictions) return

        console.log("PerformancePredictionChart: 更新成本图表")

        energyCostUpper.clear()
        energyCostLower.clear()
        maintenanceCostUpper.clear()
        maintenanceCostLower.clear()

        var cumulativeEnergy = 0
        var cumulativeMaintenance = 0

        for (var i = 0; i < predictionData.annual_predictions.length; i++) {
            var prediction = predictionData.annual_predictions[i]

            cumulativeEnergy += (prediction.energy_cost || 0) / 1000  // 转换为千元
            cumulativeMaintenance += (prediction.maintenance_cost || 0) / 1000

            energyCostLower.append(prediction.year, 0)
            energyCostUpper.append(prediction.year, cumulativeEnergy)

            maintenanceCostLower.append(prediction.year, cumulativeEnergy)
            maintenanceCostUpper.append(prediction.year, cumulativeEnergy + cumulativeMaintenance)
        }

        console.log("PerformancePredictionChart: 成本图表更新完成")
    }

    function updateCostBreakdown() {
        if (!predictionData || !predictionData.lifecycle_cost) return

        console.log("PerformancePredictionChart: 更新成本分解")

        var lifecycle = predictionData.lifecycle_cost
        var breakdown = lifecycle.cost_breakdown || {}

        initialCostSlice.value = breakdown.initial_percentage || 0
        energyCostSlice.value = breakdown.energy_percentage || 0
        maintenanceCostSlice.value = breakdown.maintenance_percentage || 0

        console.log("PerformancePredictionChart: 成本饼图更新完成")
    }

    function updateAxisRanges() {
        yearAxis.max = selectedYears
        costYearAxis.max = selectedYears
    }

    function getCostAxisMax() {
        if (!predictionData || !predictionData.lifecycle_cost) return 100
        return (predictionData.lifecycle_cost.total_lifecycle_cost || 100000) / 1000 * 1.1
    }

    function getWearColor(wearValue) {
        if (wearValue < 25) return "#4CAF50"  // 绿色
        if (wearValue < 50) return "#FF9800"  // 橙色
        if (wearValue < 75) return "#F44336"  // 红色
        return "#9C27B0"  // 紫色
    }

    function getWearLevelColor(wearLevel) {
        switch (wearLevel) {
            case 'minimal': return "#4CAF50"
            case 'moderate': return "#FF9800"
            case 'significant': return "#F44336"
            case 'severe': return "#9C27B0"
            default: return Material.dividerColor
        }
    }

    function getMaintenancePriorityColor(priority) {
        switch (priority) {
            case 'high': return Material.color(Material.Red)
            case 'medium': return Material.color(Material.Orange)
            case 'low': return Material.color(Material.Green)
            default: return Material.color(Material.Grey)
        }
    }

    function getMaintenancePriorityText(priority) {
        if (!isChineseMode) {
            return priority.charAt(0).toUpperCase() + priority.slice(1)
        }

        switch (priority) {
            case 'high': return "高"
            case 'medium': return "中"
            case 'low': return "低"
            default: return "未知"
        }
    }

    function getKPIValue(key) {
        if (!predictionData) return "0"

        switch (key) {
            case "efficiency_degradation":
                if (predictionData.performance_degradation && predictionData.performance_degradation.efficiency_trend) {
                    return Math.abs(predictionData.performance_degradation.efficiency_trend.total_change_percent || 0).toFixed(1)
                }
                return "0"

            case "power_increase":
                if (predictionData.performance_degradation && predictionData.performance_degradation.power_trend) {
                    return (predictionData.performance_degradation.power_trend.total_change_percent || 0).toFixed(1)
                }
                return "0"

            case "reliability_decrease":
                if (predictionData.annual_predictions && predictionData.annual_predictions.length > 1) {
                    var firstYear = predictionData.annual_predictions[0].reliability || 1
                    var lastYear = predictionData.annual_predictions[predictionData.annual_predictions.length - 1].reliability || 1
                    return ((firstYear - lastYear) / firstYear * 100).toFixed(1)
                }
                return "0"

            case "total_lifecycle_cost":
                if (predictionData.lifecycle_cost) {
                    return ((predictionData.lifecycle_cost.total_lifecycle_cost || 0) / 10000).toFixed(0)
                }
                return "0"

            default:
                return "0"
        }
    }

    function getOptimizationRecommendations() {
        if (!predictionData) return ""

        var recommendations = []

        if (isChineseMode) {
            recommendations.push("定期监测关键性能指标")
            recommendations.push("按计划执行预防性维护")
            recommendations.push("优化运行参数以提高效率")
            recommendations.push("考虑在适当时机进行设备升级")
        } else {
            recommendations.push("Monitor key performance indicators regularly")
            recommendations.push("Execute preventive maintenance as scheduled")
            recommendations.push("Optimize operating parameters for efficiency")
            recommendations.push("Consider equipment upgrade at appropriate time")
        }

        return recommendations.join(" • ")
    }

    function showReplacementDetails() {
        console.log("显示设备更换详情")
        // TODO: 实现设备更换详情对话框
    }
}
