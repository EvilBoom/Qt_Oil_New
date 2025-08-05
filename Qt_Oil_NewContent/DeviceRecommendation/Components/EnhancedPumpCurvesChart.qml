import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Window
import QtCharts

import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

ApplicationWindow {
    id: analysisWindow

    // 🔥 窗口属性
    width: 1400
    height: 900
    minimumWidth: 1000
    minimumHeight: 700
    title: (isChineseMode ? "泵性能分析 - " : "Pump Performance Analysis - ") +
           (pumpData ? pumpData.model : "Unknown")

    // 🔥 外部属性
    property var pumpData: null
    property int stages: 1
    property real frequency: 60
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    // 🔥 内部图表属性
    property var curvesData: null
    property var systemCurve: null
    property var currentOperatingPoint: null
    property bool showGrid: true
    property bool showPoints: true
    property bool showZones: true
    property bool showEnhancedParameters: true

    // 🔥 信号定义
    signal backRequested()
    signal pumpConfigurationChanged(int stages, real frequency)
    signal windowClosed()
    signal operatingPointChanged(real flow, real head)

    // 🔥 窗口关闭处理
    onClosing: {
        console.log("性能分析窗口关闭")
        windowClosed()
    }

    // 🔥 监听配置变化
    onStagesChanged: {
        console.log("窗口级数变化:", stages)
        pumpConfigurationChanged(stages, frequency)
        // 重新生成曲线数据
        if (pumpData) {
            generateMockCurveData()
        }
    }

    onFrequencyChanged: {
        console.log("窗口频率变化:", frequency)
        pumpConfigurationChanged(stages, frequency)
        // 重新生成曲线数据
        if (pumpData) {
            generateMockCurveData()
        }
    }

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            analysisWindow.isMetric = isMetric
            console.log("性能分析窗口中单位制切换为:", isMetric ? "公制" : "英制")

            // 更新坐标轴标题
            updateAxisTitles()

            // 重新更新图表数据以应用单位转换
            if (curvesData) {
                Qt.callLater(updateChartData)
            }
        }
    }

    // 材质主题
    Material.theme: Material.Light
    Material.accent: Material.Blue

    header: ToolBar {
        height: 56
        Material.background: Material.primary

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // 返回按钮
            ToolButton {
                icon.source: "qrc:/images/back.png"
                text: isChineseMode ? "返回" : "Back"
                onClicked: {
                    console.log("点击返回按钮")
                    analysisWindow.backRequested()
                }
            }

            // 标题区域
            Column {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: isChineseMode ? "泵性能分析" : "Pump Performance Analysis"
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                }

                Text {
                    text: pumpData ?
                          `${pumpData.manufacturer} ${pumpData.model} - ${stages} ${isChineseMode ? "级" : "stages"} @ ${frequency}Hz` :
                          (isChineseMode ? "未选择泵" : "No pump selected")
                    font.pixelSize: 12
                    color: Material.color(Material.Grey, Material.Shade100)
                    visible: pumpData !== null
                }
            }

            // 配置控制区域
            Rectangle {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 40
                color: Qt.rgba(1, 1, 1, 0.1)
                radius: 8
                visible: pumpData !== null

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    // 级数控制
                    Column {
                        spacing: 2

                        Text {
                            text: isChineseMode ? "级数" : "Stages"
                            font.pixelSize: 9
                            color: "white"
                        }

                        SpinBox {
                            id: stagesSpinBox
                            width: 80
                            height: 24
                            font.pixelSize: 10
                            from: 1
                            to: pumpData ? (pumpData.maxStages || 200) : 200
                            value: analysisWindow.stages
                            onValueChanged: {
                                if (value !== analysisWindow.stages) {
                                    analysisWindow.stages = value
                                }
                            }
                        }
                    }

                    // 频率控制
                    Column {
                        spacing: 2

                        Text {
                            text: isChineseMode ? "频率" : "Frequency"
                            font.pixelSize: 9
                            color: "white"
                        }

                        ComboBox {
                            id: frequencyCombo
                            width: 100
                            height: 24
                            font.pixelSize: 10
                            model: [
                                {value: 50, text: "50Hz"},
                                {value: 60, text: "60Hz"}
                            ]
                            textRole: "text"
                            valueRole: "value"
                            currentIndex: analysisWindow.frequency === 60 ? 1 : 0
                            onCurrentValueChanged: {
                                if (currentValue !== analysisWindow.frequency) {
                                    analysisWindow.frequency = currentValue
                                }
                            }
                        }
                    }
                }
            }

            // 单位切换器
            CommonComponents.UnitSwitcher {
                isChinese: analysisWindow.isChineseMode
                showLabel: false
            }

            // 窗口控制按钮
            ToolButton {
                text: "🔄"
                font.pixelSize: 16
                ToolTip.text: isChineseMode ? "刷新数据" : "Refresh Data"
                onClicked: {
                    generateMockCurveData()
                }
            }

            ToolButton {
                text: "📊"
                font.pixelSize: 16
                ToolTip.text: isChineseMode ? "导出数据" : "Export Data"
                onClicked: {
                    exportAnalysisData()
                }
            }

            ToolButton {
                text: "✕"
                font.pixelSize: 16
                ToolTip.text: isChineseMode ? "关闭" : "Close"
                onClicked: {
                    analysisWindow.close()
                }
            }
        }
    }

    // 🔥 主内容区域 - 集成的性能曲线图表
    Rectangle {
        anchors.fill: parent
        color: Material.backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // 🔥 图表控制栏
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: isChineseMode ? "性能曲线图表" : "Performance Curves"
                    font.pixelSize: 16
                    font.bold: true
                    color: Material.primaryTextColor
                }

                Item { Layout.fillWidth: true }

                // 数据状态指示器
                Rectangle {
                    width: 80
                    height: 24
                    radius: 12
                    color: curvesData ? Material.color(Material.Green, Material.Shade200) : Material.color(Material.Red, Material.Shade200)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: curvesData ? Material.color(Material.Green) : Material.color(Material.Red)
                        }

                        Text {
                            text: curvesData ?
                                  (isChineseMode ? "已载入" : "Loaded") :
                                  (isChineseMode ? "等待中" : "Waiting")
                            font.pixelSize: 9
                            color: Material.primaryTextColor
                        }
                    }
                }

                // 视图控制按钮
                ToolButton {
                    text: "⚙️"
                    font.pixelSize: 14
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: settingsMenu.open()

                    Menu {
                        id: settingsMenu
                        width: 200

                        MenuItem {
                            text: isChineseMode ? "显示网格" : "Show Grid"
                            checkable: true
                            checked: showGrid
                            onCheckedChanged: {
                                showGrid = checked
                                updateGridVisibility()
                            }
                        }

                        MenuItem {
                            text: isChineseMode ? "显示数据点" : "Show Points"
                            checkable: true
                            checked: showPoints
                            onCheckedChanged: {
                                showPoints = checked
                                updatePointsVisibility()
                            }
                        }

                        MenuItem {
                            text: isChineseMode ? "显示性能区域" : "Show Zones"
                            checkable: true
                            checked: showZones
                            onCheckedChanged: {
                                showZones = checked
                                updateZonesVisibility()
                            }
                        }

                        MenuSeparator {}

                        MenuItem {
                            text: isChineseMode ? "生成模拟数据" : "Generate Mock Data"
                            enabled: pumpData !== null
                            onClicked: generateMockCurveData()
                        }
                    }
                }
            }

            // 🔥 主要图表区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 500
                color: "white"
                border.color: Material.dividerColor
                border.width: 1
                radius: 8

                ChartView {
                    id: mainChart
                    anchors.fill: parent
                    anchors.margins: 8

                    title: isChineseMode ? "泵性能特性曲线" : "Pump Performance Characteristics"
                    titleFont.pixelSize: 16
                    titleFont.bold: true

                    legend.alignment: Qt.AlignBottom
                    legend.font.pixelSize: 10
                    legend.visible: true

                    antialiasing: true
                    theme: ChartView.ChartThemeLight
                    backgroundColor: "white"

                    // 🔥 主X轴 - 流量（动态单位）
                    ValuesAxis {
                        id: flowAxis
                        titleText: getFlowAxisTitle()
                        min: 0
                        max: 2000
                        tickCount: 6
                        gridVisible: showGrid
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#333333"
                    }

                    // 🔥 左Y轴 - 扬程（动态单位）
                    ValuesAxis {
                        id: headAxis
                        titleText: getHeadAxisTitle()
                        min: 0
                        max: 300
                        tickCount: 6
                        gridVisible: showGrid
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#2196F3"
                    }

                    // 🔥 右Y轴1 - 效率
                    ValuesAxis {
                        id: efficiencyAxis
                        titleText: isChineseMode ? "效率 (%)" : "Efficiency (%)"
                        min: 0
                        max: 100
                        tickCount: 6
                        gridVisible: false
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#4CAF50"
                    }

                    // 🔥 右Y轴2 - 功率（动态单位）
                    ValuesAxis {
                        id: powerAxis
                        titleText: getPowerAxisTitle()
                        min: 0
                        max: 200
                        tickCount: 5
                        gridVisible: false
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#FF9800"
                    }

                    // 性能区域
                    AreaSeries {
                        id: optimalZoneArea
                        name: isChineseMode ? "最佳区域" : "Optimal Zone"
                        axisX: flowAxis
                        axisY: headAxis
                        color: Qt.rgba(0.3, 0.8, 0.3, 0.15)
                        borderColor: Qt.rgba(0.3, 0.8, 0.3, 0.5)
                        borderWidth: 1
                        visible: showZones

                        upperSeries: LineSeries {
                            id: optimalZoneUpper
                        }
                        lowerSeries: LineSeries {
                            id: optimalZoneLower
                        }
                    }

                    AreaSeries {
                        id: acceptableZoneArea
                        name: isChineseMode ? "可接受区域" : "Acceptable Zone"
                        axisX: flowAxis
                        axisY: headAxis
                        color: Qt.rgba(1.0, 0.6, 0.0, 0.1)
                        borderColor: Qt.rgba(1.0, 0.6, 0.0, 0.3)
                        borderWidth: 1
                        visible: showZones

                        upperSeries: LineSeries {
                            id: acceptableZoneUpper
                        }
                        lowerSeries: LineSeries {
                            id: acceptableZoneLower
                        }
                    }

                    // 性能曲线
                    LineSeries {
                        id: headCurve
                        name: isChineseMode ? "扬程" : "Head"
                        axisX: flowAxis
                        axisY: headAxis
                        color: "#2196F3"
                        width: 3
                        pointsVisible: showPoints
                        pointLabelsVisible: false
                    }

                    LineSeries {
                        id: efficiencyCurve
                        name: isChineseMode ? "效率" : "Efficiency"
                        axisX: flowAxis
                        axisY: efficiencyAxis
                        color: "#4CAF50"
                        width: 3
                        pointsVisible: showPoints
                        style: Qt.SolidLine
                    }

                    LineSeries {
                        id: powerCurve
                        name: isChineseMode ? "功率" : "Power"
                        axisX: flowAxis
                        axisY: powerAxis
                        color: "#FF9800"
                        width: 2
                        pointsVisible: false
                    }

                    // 工况点
                    ScatterSeries {
                        id: operatingPointSeries
                        name: isChineseMode ? "当前工况点" : "Operating Point"
                        axisX: flowAxis
                        axisY: headAxis
                        color: "#E91E63"
                        markerSize: 15
                        borderColor: "white"
                        borderWidth: 2
                        markerShape: ScatterSeries.MarkerShapeCircle
                    }

                    // 关键点
                    ScatterSeries {
                        id: keyPointsSeries
                        name: isChineseMode ? "关键点" : "Key Points"
                        axisX: flowAxis
                        axisY: headAxis
                        color: "#9C27B0"
                        markerSize: 10
                        markerShape: ScatterSeries.MarkerShapeRectangle
                        borderColor: "white"
                        borderWidth: 1
                    }

                    // 🔥 鼠标交互区域
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: (mouse) => {
                            var chartPoint = mainChart.mapToValue(Qt.point(mouse.x, mouse.y), headCurve)
                            if (chartPoint.x >= 0 && chartPoint.y >= 0 &&
                                chartPoint.x <= flowAxis.max && chartPoint.y <= headAxis.max) {
                                console.log("点击图表设置工况点:", chartPoint.x.toFixed(1), chartPoint.y.toFixed(1))
                                operatingPointChanged(chartPoint.x, chartPoint.y)
                                updateOperatingPointDisplay(chartPoint.x, chartPoint.y)
                            }
                        }

                        onPositionChanged: (mouse) => {
                            if (containsMouse) {
                                var chartPoint = mainChart.mapToValue(Qt.point(mouse.x, mouse.y), headCurve)
                                crosshairTooltip.visible = true
                                crosshairTooltip.updatePosition(mouse.x, mouse.y, chartPoint.x, chartPoint.y)
                            }
                        }

                        onExited: {
                            crosshairTooltip.visible = false
                        }
                    }

                    // 🔥 十字光标提示
                    Rectangle {
                        id: crosshairTooltip
                        width: 140
                        height: 60
                        color: Qt.rgba(0, 0, 0, 0.8)
                        radius: 4
                        visible: false
                        z: 1000

                        property real flowValue: 0
                        property real headValue: 0

                        function updatePosition(mouseX, mouseY, flow, head) {
                            x = mouseX + 10
                            y = mouseY - height - 10
                            flowValue = flow
                            headValue = head
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: `${isChineseMode ? "流量" : "Flow"}: ${crosshairTooltip.flowValue.toFixed(1)} ${getFlowUnit()}`
                                color: "white"
                                font.pixelSize: 10
                            }
                            Text {
                                text: `${isChineseMode ? "扬程" : "Head"}: ${crosshairTooltip.headValue.toFixed(1)} ${getHeadUnit()}`
                                color: "white"
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // 🔥 数据为空时的提示
                Rectangle {
                    anchors.centerIn: parent
                    width: 200
                    height: 80
                    color: Qt.rgba(0, 0, 0, 0.1)
                    radius: 8
                    visible: !curvesData

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        BusyIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            running: !curvesData
                            width: 32
                            height: 32
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isChineseMode ? "正在加载数据..." : "Loading data..."
                            font.pixelSize: 12
                            color: Material.secondaryTextColor
                        }
                    }
                }
            }

            // 🔥 工况点信息面板
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: currentOperatingPoint ? 80 : 0
                color: Material.dialogColor
                radius: 8
                visible: currentOperatingPoint !== null

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 24
                    visible: parent.visible

                    // 工况点基本信息
                    Column {
                        spacing: 4
                        Text {
                            text: isChineseMode ? "当前工况点" : "Current Operating Point"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                        Text {
                            text: currentOperatingPoint ?
                                  `${isChineseMode ? "流量" : "Flow"}: ${currentOperatingPoint.flow.toFixed(1)} ${getFlowUnit()}` : ""
                            font.pixelSize: 12
                            color: Material.secondaryTextColor
                        }
                        Text {
                            text: currentOperatingPoint ?
                                  `${isChineseMode ? "扬程" : "Head"}: ${currentOperatingPoint.head.toFixed(1)} ${getHeadUnit()}` : ""
                            font.pixelSize: 12
                            color: Material.secondaryTextColor
                        }
                    }

                    // 性能参数
                    Column {
                        spacing: 4
                        Text {
                            text: isChineseMode ? "性能参数" : "Performance"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                        Text {
                            text: currentOperatingPoint ?
                                  `${isChineseMode ? "效率" : "Efficiency"}: ${currentOperatingPoint.efficiency.toFixed(1)}%` : ""
                            font.pixelSize: 12
                            color: Material.secondaryTextColor
                        }
                        Text {
                            text: currentOperatingPoint ?
                                  `${isChineseMode ? "功率" : "Power"}: ${currentOperatingPoint.power.toFixed(1)} ${getPowerUnit()}` : ""
                            font.pixelSize: 12
                            color: Material.secondaryTextColor
                        }
                    }

                    // 状态指示
                    Rectangle {
                        width: 100
                        height: 30
                        radius: 15
                        color: currentOperatingPoint ? getStatusColor(currentOperatingPoint.status) : Material.backgroundColor

                        Text {
                            anchors.centerIn: parent
                            text: currentOperatingPoint ? currentOperatingPoint.statusText : ""
                            font.pixelSize: 11
                            font.bold: true
                            color: "white"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // 操作按钮
                    Button {
                        text: isChineseMode ? "设为BEP" : "Set as BEP"
                        font.pixelSize: 10
                        implicitHeight: 28
                        enabled: currentOperatingPoint !== null
                        onClicked: setBestEfficiencyPoint()
                    }
                }
            }
        }
    }

    // 🔥 状态栏
    footer: Rectangle {
        height: 32
        color: Material.dialogColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Text {
                text: isChineseMode ? "状态: 就绪" : "Status: Ready"
                font.pixelSize: 10
                color: Material.hintTextColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: {
                    if (pumpData) {
                        return `${isChineseMode ? "数据:" : "Data:"} ${curvesData ? "已加载" : "等待中"}`
                    }
                    return ""
                }
                font.pixelSize: 10
                color: Material.hintTextColor
            }

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: curvesData ? Material.color(Material.Green) : Material.color(Material.Red)
            }
        }
    }

    // 🔥 =================================
    // 🔥 单位转换函数
    // 🔥 =================================

    function getFlowUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("flow")
        }
        return isMetric ? "m³/d" : "bbl/d"
    }

    function getHeadUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("depth")
        }
        return isMetric ? "m" : "ft"
    }

    function getPowerUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("power")
        }
        return isMetric ? "kW" : "HP"
    }

    function getFlowAxisTitle() {
        var unit = getFlowUnit()
        var displayText = isChineseMode ? "流量" : "Flow Rate"
        return `${displayText} (${unit})`
    }

    function getHeadAxisTitle() {
        var unit = getHeadUnit()
        var displayText = isChineseMode ? "扬程" : "Head"
        return `${displayText} (${unit})`
    }

    function getPowerAxisTitle() {
        var unit = getPowerUnit()
        var displayText = isChineseMode ? "功率" : "Power"
        return `${displayText} (${unit})`
    }

    function convertFlowValue(value) {
        if (!isMetric) return value
        return UnitUtils.bblToM3(value)
    }

    function convertHeadValue(value) {
        if (!isMetric) return value
        return UnitUtils.feetToMeters(value)
    }

    function convertPowerValue(value) {
        if (!isMetric) return value
        return value * 0.7457
    }

    function updateAxisTitles() {
        flowAxis.titleText = getFlowAxisTitle()
        headAxis.titleText = getHeadAxisTitle()
        powerAxis.titleText = getPowerAxisTitle()
    }

    // 🔥 =================================
    // 🔥 数据生成和处理函数
    // 🔥 =================================

    function generateMockCurveData() {
        console.log("=== 为性能分析窗口生成模拟数据 ===")

        if (!pumpData) {
            console.warn("没有泵数据，无法生成模拟数据")
            return
        }

        var mockCurvesData = {
            pumpModel: pumpData.model,
            stages: stages,
            frequency: frequency,
            baseCurves: generateBaseCurves(),
            operatingPoints: [],
            performanceZones: generatePerformanceZones()
        }

        console.log("设置模拟曲线数据到图表组件")
        curvesData = mockCurvesData

        // 设置一个示例工况点
        var sampleOperatingPoint = {
            flow: (pumpData.minFlow + pumpData.maxFlow) / 2,
            head: pumpData.headPerStage * stages * 0.8,
            efficiency: pumpData.efficiency * 0.9,
            power: pumpData.powerPerStage * stages * 1.1,
            status: "optimal",
            statusText: isChineseMode ? "最佳区域" : "Optimal Zone"
        }

        // 单位转换
        if (isMetric) {
            sampleOperatingPoint.flow = convertFlowValue(sampleOperatingPoint.flow)
            sampleOperatingPoint.head = convertHeadValue(sampleOperatingPoint.head)
            sampleOperatingPoint.power = convertPowerValue(sampleOperatingPoint.power)
        }

        currentOperatingPoint = sampleOperatingPoint

        // 更新图表
        updateChartData()
    }

    function generateBaseCurves() {
        var curves = {
            flow: [],
            head: [],
            efficiency: [],
            power: []
        }

        var minFlow = pumpData.minFlow || 100
        var maxFlow = pumpData.maxFlow || 2000
        var headPerStage = pumpData.headPerStage || 15
        var maxEfficiency = pumpData.efficiency || 75

        // 生成20个数据点
        for (var i = 0; i < 20; i++) {
            var flowRatio = i / 19
            var flow = minFlow + flowRatio * (maxFlow - minFlow)

            // 扬程曲线：随流量增加而下降
            var head = headPerStage * stages * (1.1 - 0.3 * flowRatio)

            // 效率曲线：钟形曲线
            var efficiencyRatio = 1 - Math.pow((flowRatio - 0.75), 2) * 4
            var efficiency = maxEfficiency * Math.max(0.3, efficiencyRatio)

            // 功率曲线：随流量增加
            var hydraulicPower = flow * head * 0.000272
            var totalPower = hydraulicPower / (efficiency / 100) * 1.2

            // 频率修正
            var freqRatio = frequency / 60
            head *= Math.pow(freqRatio, 2)
            totalPower *= Math.pow(freqRatio, 3)

            // 单位转换（如果需要）
            if (isMetric) {
                flow = convertFlowValue(flow)
                head = convertHeadValue(head)
                totalPower = convertPowerValue(totalPower)
            }

            curves.flow.push(flow)
            curves.head.push(head)
            curves.efficiency.push(efficiency)
            curves.power.push(totalPower)
        }

        console.log("生成基础曲线数据:", curves.flow.length, "个点")
        return curves
    }

    function generatePerformanceZones() {
        var minFlow = pumpData.minFlow || 100
        var maxFlow = pumpData.maxFlow || 2000

        // 单位转换
        if (isMetric) {
            minFlow = convertFlowValue(minFlow)
            maxFlow = convertFlowValue(maxFlow)
        }

        return {
            optimal: {
                minFlow: maxFlow * 0.6,
                maxFlow: maxFlow * 0.9,
                description: isChineseMode ? "最佳效率区域" : "Best efficiency zone"
            },
            acceptable: {
                minFlow: maxFlow * 0.4,
                maxFlow: maxFlow * 1.0,
                description: isChineseMode ? "可接受运行区域" : "Acceptable operating zone"
            }
        }
    }

    // 🔥 =================================
    // 🔥 图表更新函数
    // 🔥 =================================

    function updateChartData() {
        console.log("开始更新图表数据")

        if (!curvesData) {
            console.log("没有曲线数据，跳过更新")
            return
        }

        var curves = curvesData.baseCurves
        if (!curves) {
            console.log("没有基础曲线数据，跳过更新")
            return
        }

        // 更新坐标轴范围
        updateAxisRanges(curves)

        // 更新各条曲线
        updateHeadCurve(curves)
        updateEfficiencyCurve(curves)
        updatePowerCurve(curves)
        updatePerformanceZones()

        console.log("图表数据更新完成")
    }

    function updateAxisRanges(curves) {
        if (curves.flow && curves.flow.length > 0) {
            var maxFlow = Math.max(...curves.flow)
            var minFlow = Math.min(...curves.flow)
            flowAxis.min = Math.max(0, minFlow * 0.9)
            flowAxis.max = maxFlow * 1.1
        }

        if (curves.head && curves.head.length > 0) {
            var maxHead = Math.max(...curves.head)
            var minHead = Math.min(...curves.head)
            headAxis.min = Math.max(0, minHead * 0.9)
            headAxis.max = maxHead * 1.1
        }

        if (curves.power && curves.power.length > 0) {
            var maxPower = Math.max(...curves.power)
            powerAxis.min = 0
            powerAxis.max = maxPower * 1.1
        }
    }

    function updateHeadCurve(curves) {
        headCurve.clear()
        if (curves.flow && curves.head) {
            var minLength = Math.min(curves.flow.length, curves.head.length)
            for (var i = 0; i < minLength; i++) {
                if (!isNaN(curves.flow[i]) && !isNaN(curves.head[i])) {
                    headCurve.append(curves.flow[i], curves.head[i])
                }
            }
            console.log("扬程曲线已更新，点数:", headCurve.count)
        }
    }

    function updateEfficiencyCurve(curves) {
        efficiencyCurve.clear()
        if (curves.flow && curves.efficiency) {
            var minLength = Math.min(curves.flow.length, curves.efficiency.length)
            for (var i = 0; i < minLength; i++) {
                if (!isNaN(curves.flow[i]) && !isNaN(curves.efficiency[i])) {
                    efficiencyCurve.append(curves.flow[i], curves.efficiency[i])
                }
            }
            console.log("效率曲线已更新，点数:", efficiencyCurve.count)
        }
    }

    function updatePowerCurve(curves) {
        powerCurve.clear()
        if (curves.flow && curves.power) {
            var minLength = Math.min(curves.flow.length, curves.power.length)
            for (var i = 0; i < minLength; i++) {
                if (!isNaN(curves.flow[i]) && !isNaN(curves.power[i])) {
                    powerCurve.append(curves.flow[i], curves.power[i])
                }
            }
            console.log("功率曲线已更新，点数:", powerCurve.count)
        }
    }

    function updatePerformanceZones() {
        if (!curvesData || !curvesData.performanceZones || !showZones) {
            optimalZoneArea.visible = false
            acceptableZoneArea.visible = false
            return
        }

        var zones = curvesData.performanceZones
        var curves = curvesData.baseCurves

        if (zones.optimal && curves.flow && curves.head) {
            optimalZoneUpper.clear()
            optimalZoneLower.clear()

            var minFlow = zones.optimal.minFlow || 0
            var maxFlow = zones.optimal.maxFlow || 1000

            for (var i = 0; i < curves.flow.length; i++) {
                var flow = curves.flow[i]
                if (flow >= minFlow && flow <= maxFlow) {
                    var head = curves.head[i]
                    if (!isNaN(head)) {
                        optimalZoneUpper.append(flow, head + 15)
                        optimalZoneLower.append(flow, Math.max(0, head - 15))
                    }
                }
            }
            optimalZoneArea.visible = true
        }

        if (zones.acceptable && curves.flow && curves.head) {
            acceptableZoneUpper.clear()
            acceptableZoneLower.clear()

            var minFlow = zones.acceptable.minFlow || 0
            var maxFlow = zones.acceptable.maxFlow || 1500

            for (var i = 0; i < curves.flow.length; i++) {
                var flow = curves.flow[i]
                if (flow >= minFlow && flow <= maxFlow) {
                    var head = curves.head[i]
                    if (!isNaN(head)) {
                        acceptableZoneUpper.append(flow, head + 25)
                        acceptableZoneLower.append(flow, Math.max(0, head - 25))
                    }
                }
            }
            acceptableZoneArea.visible = true
        }
    }

    function updateOperatingPointDisplay(flow, head) {
        if (flow !== undefined && head !== undefined && !isNaN(flow) && !isNaN(head)) {
            operatingPointSeries.clear()
            operatingPointSeries.append(flow, head)
            console.log("工况点显示已更新:", flow.toFixed(1), getFlowUnit() + ",", head.toFixed(1), getHeadUnit())

            if (currentOperatingPoint) {
                currentOperatingPoint.flow = flow
                currentOperatingPoint.head = head
                currentOperatingPoint.efficiency = interpolateEfficiency(flow)
                currentOperatingPoint.power = interpolatePower(flow)
            }
        }
    }

    function interpolateEfficiency(targetFlow) {
        if (!curvesData || !curvesData.baseCurves) return 75

        var flows = curvesData.baseCurves.flow
        var efficiencies = curvesData.baseCurves.efficiency

        return interpolateValue(targetFlow, flows, efficiencies)
    }

    function interpolatePower(targetFlow) {
        if (!curvesData || !curvesData.baseCurves) return 50

        var flows = curvesData.baseCurves.flow
        var powers = curvesData.baseCurves.power

        return interpolateValue(targetFlow, flows, powers)
    }

    function interpolateValue(targetX, xArray, yArray) {
        if (!xArray || !yArray || xArray.length !== yArray.length || xArray.length === 0) {
            return 0
        }

        for (var i = 0; i < xArray.length - 1; i++) {
            if (targetX >= xArray[i] && targetX <= xArray[i + 1]) {
                var ratio = (targetX - xArray[i]) / (xArray[i + 1] - xArray[i])
                return yArray[i] + ratio * (yArray[i + 1] - yArray[i])
            }
        }

        if (targetX <= xArray[0]) return yArray[0]
        if (targetX >= xArray[xArray.length - 1]) return yArray[yArray.length - 1]

        return 0
    }

    // 🔥 =================================
    // 🔥 界面控制函数
    // 🔥 =================================

    function updateGridVisibility() {
        flowAxis.gridVisible = showGrid
        headAxis.gridVisible = showGrid
    }

    function updatePointsVisibility() {
        headCurve.pointsVisible = showPoints
        efficiencyCurve.pointsVisible = showPoints
    }

    function updateZonesVisibility() {
        optimalZoneArea.visible = showZones && curvesData && curvesData.performanceZones
        acceptableZoneArea.visible = showZones && curvesData && curvesData.performanceZones
    }

    function getStatusColor(status) {
        switch (status) {
            case 'optimal': return Material.color(Material.Green)
            case 'acceptable': return Material.color(Material.Orange)
            case 'dangerous': return Material.color(Material.Red)
            default: return Material.color(Material.Grey)
        }
    }

    function setBestEfficiencyPoint() {
        if (currentOperatingPoint) {
            console.log("设置BEP点:", currentOperatingPoint.flow, currentOperatingPoint.head)
        }
    }

    function exportAnalysisData() {
        console.log("=== 导出性能分析数据 ===")

        if (!pumpData) {
            console.warn("没有数据可导出")
            return
        }

        var exportData = {
            pump: {
                manufacturer: pumpData.manufacturer,
                model: pumpData.model,
                stages: stages,
                frequency: frequency
            },
            curves: curvesData,
            operatingPoint: currentOperatingPoint,
            exportTime: new Date().toISOString()
        }

        console.log("导出数据:", JSON.stringify(exportData, null, 2))
    }

    // 🔥 =================================
    // 🔥 窗口初始化
    // 🔥 =================================

    Component.onCompleted: {
        console.log("=== 性能分析窗口初始化完成 ===")
        console.log("泵数据:", pumpData ? pumpData.model : "无")
        console.log("级数:", stages)
        console.log("频率:", frequency)

        // 窗口居中显示
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2

        // 如果有泵数据，生成模拟数据用于演示
        if (pumpData) {
            Qt.callLater(function() {
                generateMockCurveData()
            })
        }

        // 显示窗口
        show()
    }

    Component.onDestruction: {
        console.log("性能分析窗口销毁")
    }
}
