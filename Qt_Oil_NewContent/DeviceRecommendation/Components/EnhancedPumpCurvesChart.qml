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

    width: 1400
    height: 900
    minimumWidth: 1000
    minimumHeight: 700
    title: (isChineseMode ? "泵性能分析 - " : "Pump Performance Analysis - ") +
           (pumpData ? pumpData.model : "Unknown")

    // 外部属性
    property var pumpData: null
    property int stages: 1
    property real frequency: 60
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    // 图表数据
    property var curvesData: null               // 来自控制器的完整数据包
    property var systemCurve: null
    property var currentOperatingPoint: null
    property bool showGrid: true
    property bool showPoints: true
    property bool showZones: true
    property bool showEnhancedParameters: true
    property bool enableSmoothing: true
    property real smoothingFactor: 0.8  // 平滑度因子 (0-1)
    property int interpolationPoints: 300  // 插值点数量

    // 🔥 修改默认平滑方法
    property string smoothingMethod: "lowess"  // 改为默认使用LOWESS
    // 🔥 新增属性：变频曲线显示控制


    // 信号
    signal backRequested()
    signal pumpConfigurationChanged(int stages, real frequency)
    signal windowClosed()
    signal operatingPointChanged(real flow, real head)

    onClosing: {
        console.log("性能分析窗口关闭")
        windowClosed()
    }

    // 监听配置变化：改为驱动控制器刷新
    // onStagesChanged: {
    //     console.log("窗口级数变化:", stages)
    //     pumpConfigurationChanged(stages, frequency)
    //     if (pumpData) {
    //         if (pumpCurvesController && pumpCurvesController.updatePumpConfiguration) {
    //             pumpCurvesController.updatePumpConfiguration(stages, frequency)
    //         } else {
    //             loadCurvesFromDB()
    //         }
    //     }
    // }
    // 监听配置变化：强制刷新两个图表
    onStagesChanged: {
        console.log("级数变化，强制刷新所有图表:", stages)
        pumpConfigurationChanged(stages, frequency)

        // 🔥 立即更新现有数据的显示（主图表）
        if (curvesData && curvesData.baseCurves) {
            Qt.callLater(function() {
                updateChartData()  // 主图表
                // 强制触发变频图表更新
                variableFreqChart.stages = stages  // 触发属性变化
            })
        }

        // 从控制器重新加载
        if (pumpData && pumpCurvesController) {
            pumpCurvesController.updatePumpConfiguration(stages, frequency)
        }
    }


    // 🔥 在频率变化时调用调试函数
    // onFrequencyChanged: {
    //     console.log("窗口频率变化:", frequency)
    //     debugFrequencyConversion()  // 🔥 调试频率换算
    //     pumpConfigurationChanged(stages, frequency)
    //     if (pumpData) {
    //         if (pumpCurvesController && pumpCurvesController.updatePumpConfiguration) {
    //             pumpCurvesController.updatePumpConfiguration(stages, frequency)
    //         } else {
    //             loadCurvesFromDB()
    //         }
    //     }
    // }
    onFrequencyChanged: {
        console.log("频率变化，强制刷新所有图表:", frequency)
        debugFrequencyConversion()
        pumpConfigurationChanged(stages, frequency)

        // 🔥 立即更新现有数据的显示
        if (curvesData && curvesData.baseCurves) {
            Qt.callLater(function() {
                updateChartData()  // 主图表
                // 强制触发变频图表更新
                variableFreqChart.currentFrequency = frequency  // 触发属性变化
            })
        }

        if (pumpData && pumpCurvesController) {
            pumpCurvesController.updatePumpConfiguration(stages, frequency)
        }
    }


    // 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null
        function onUnitSystemChanged(isMetricNew) {
            analysisWindow.isMetric = isMetricNew
            console.log("单位制切换:", isMetricNew ? "公制" : "英制")
            updateAxisTitles()
            if (curvesData) Qt.callLater(updateChartData)
        }
    }

    // 接收控制器返回的数据
    Connections {
        target: pumpCurvesController
        enabled: pumpCurvesController !== null
        function onCurvesDataLoaded(curvesPackage) {
            // curvesPackage 结构：
            // { pumpId, displacement, stages, frequency, baseCurves:{flow,head,power,efficiency, ...}, performanceZones: {...}, ... }
            curvesData = curvesPackage
            console.log("从数据库中传递的数据",JSON.stringify(curvesData))
            updateAxisTitles()
            Qt.callLater(updateChartData)
        }
        // 可选：如果需要，也可以监听 operatingPointUpdated 等
    }

    // 根据当前单位制返回显示单位
    function getFlowUnit() {
        if (unitSystemController) return unitSystemController.getUnitLabel("flow")
        return isMetric ? "m³/d" : "bbl/d"
    }
    function getHeadUnit() {
        if (unitSystemController) return unitSystemController.getUnitLabel("depth")
        return isMetric ? "m" : "ft"
    }
    function getPowerUnit() {
        if (unitSystemController) return unitSystemController.getUnitLabel("power")
        return isMetric ? "kW" : "HP"
    }

    // 🔥 修改轴标题，显示当前频率信息
    function getFlowAxisTitle() {
        var unit = getFlowUnit()
        var displayText = isChineseMode ? "流量" : "Flow Rate"
        var freqText = frequency !== 50 ? ` @${frequency}Hz` : ""
        return `${displayText}${freqText} (${unit})`
    }

    function getHeadAxisTitle() {
        var unit = getHeadUnit()
        var displayText = isChineseMode ? "扬程" : "Head"
        var freqText = frequency !== 50 ? ` @${frequency}Hz` : ""
        return `${displayText}${freqText} (${unit})`
    }

    function getPowerAxisTitle() {
        var unit = getPowerUnit()
        var displayText = isChineseMode ? "功率" : "Power"
        var freqText = frequency !== 50 ? ` @${frequency}Hz` : ""
        return `${displayText}${freqText} (${unit})`
    }

    function updateAxisTitles() {
        flowAxis.titleText = getFlowAxisTitle()
        headAxis.titleText = getHeadAxisTitle()
        powerAxis.titleText = getPowerAxisTitle()
    }

    // 🔥 修改显示转换函数，添加频率换算
    function toDisplayFlow(valueM3d) {
        // 🔥 首先应用频率换算：(50 / 当前频率) × 单级流量
        var frequencyFactor = frequency / 50  // 频率换算系数
        var adjustedFlow = valueM3d * frequencyFactor

        // 然后应用单位制转换
        var finalFlow = isMetric ? adjustedFlow : UnitUtils.m3ToBbl(adjustedFlow)

        // console.log(`流量换算: 原始=${valueM3d.toFixed(1)} -> 频率调整=${adjustedFlow.toFixed(1)} -> 最终显示=${finalFlow.toFixed(1)} ${getFlowUnit()}`)

        return finalFlow
    }
    // 🔥 修改扬程和功率转换函数，添加频率换算（如果需要）
    function toDisplayHead(valueM) {
        // 🔥 扬程也需要频率换算：扬程与频率的平方成正比
        var frequencyFactor = Math.pow(frequency/ 50, 2)  // 频率平方换算系数
        var adjustedHead = valueM * frequencyFactor * stages

        // 然后应用单位制转换
        var finalHead = isMetric ? adjustedHead : UnitUtils.metersToFeet(adjustedHead)

        // console.log(`扬程换算: 原始=${valueM.toFixed(1)} -> 频率调整=${adjustedHead.toFixed(1)} -> 最终显示=${finalHead.toFixed(1)} ${getHeadUnit()}`)

        return finalHead
    }

    function toDisplayPower(valueKW) {
        // 🔥 功率与频率的立方成正比
        var frequencyFactor = Math.pow(frequency / 50, 3)  // 频率立方换算系数
        var adjustedPower = valueKW * frequencyFactor * stages

        // 然后应用单位制转换
        var finalPower = isMetric ? adjustedPower : UnitUtils.kwToHp(adjustedPower)

        // console.log(`功率换算: 原始=${valueKW.toFixed(1)} -> 频率调整=${adjustedPower.toFixed(1)} -> 最终显示=${finalPower.toFixed(1)} ${getPowerUnit()}`)

        return finalPower
    }

    // 🔥 新增：反向流量转换函数（从显示值转换回数据库值）
    function fromDisplayFlow(displayValue) {
        // 先从显示单位转换到公制
        var metricValue = isMetric ? displayValue : UnitUtils.bblToM3(displayValue)

        // 反向换算：原始值 = 显示值 × (50/当前频率)
        var frequencyFactor = 50 / frequency
        var originalFlow = metricValue * frequencyFactor

        // console.log(`反向流量换算: 显示=${displayValue.toFixed(1)} -> 公制=${metricValue.toFixed(1)} -> 原始=${originalFlow.toFixed(1)}`)

        return originalFlow
    }

    // 🔥 新增：反向扬程转换函数
    function fromDisplayHead(displayValue) {
        var metricValue = isMetric ? displayValue : UnitUtils.feetToMeters(displayValue)
        var frequencyFactor = Math.pow(50 / frequency, 2)
        var originalHead = (metricValue / stages) * frequencyFactor
        return originalHead
    }

    // 🔥 新增：反向功率转换函数
    function fromDisplayPower(displayValue) {
        var metricValue = isMetric ? displayValue : UnitUtils.hpToKw(displayValue)
        var frequencyFactor = Math.pow(50 / frequency, 3)
        var originalPower = (metricValue / stages) * frequencyFactor
        return originalPower
    }

    // 触发从数据库加载曲线
    function loadCurvesFromDB() {
        if (!pumpData || !pumpData.model) {
            console.warn("缺少泵型号，无法加载曲线")
            return
        }
        var pumpId = pumpData.model
        // 尝试推断一个排量传给控制器（控制器当前只打包显示，不参与计算）
        var disp = 0
        if (pumpData.displacement_min && pumpData.displacement_max)
            disp = (pumpData.displacement_min + pumpData.displacement_max) / 2
        else if (pumpData.minFlow && pumpData.maxFlow)
            disp = (pumpData.minFlow + pumpData.maxFlow) / 2

        if (pumpCurvesController) {
            console.log(`从数据库加载曲线: pumpId=${pumpId}, stages=${stages}, freq=${frequency}`)
            pumpCurvesController.loadPumpCurves(pumpId, disp, stages, frequency)
        } else {
            console.warn("pumpCurvesController 不可用")
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

            ToolButton {
                icon.source: "qrc:/images/back.png"
                text: isChineseMode ? "返回" : "Back"
                onClicked: {
                    console.log("点击返回按钮")
                    analysisWindow.backRequested()
                }
            }

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

                    Column {
                        spacing: 2
                        Text { text: isChineseMode ? "级数" : "Stages"; font.pixelSize: 9; color: "white" }
                        SpinBox {
                            id: stagesSpinBox
                            width: 80
                            height: 24
                            font.pixelSize: 10
                            from: 1
                            to: pumpData ? (pumpData.maxStages || 200) : 200
                            value: analysisWindow.stages
                            onValueChanged: { if (value !== analysisWindow.stages) analysisWindow.stages = value }
                        }
                    }

                    Column {
                        spacing: 2
                        Text { text: isChineseMode ? "频率" : "Frequency"; font.pixelSize: 9; color: "white" }
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

            CommonComponents.UnitSwitcher {
                isChinese: analysisWindow.isChineseMode
                showLabel: false
            }

            ToolButton {
                text: "🔄"
                font.pixelSize: 16
                ToolTip.text: isChineseMode ? "刷新数据" : "Refresh Data"
                onClicked: loadCurvesFromDB()
            }

            ToolButton {
                text: "📊"
                font.pixelSize: 16
                ToolTip.text: isChineseMode ? "导出数据" : "Export Data"
                onClicked: exportAnalysisData()
            }

            ToolButton {
                text: "✕"
                font.pixelSize: 16
                ToolTip.text: isChineseMode ? "关闭" : "Close"
                onClicked: analysisWindow.close()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Material.backgroundColor


        // 🔥 将原有的 ColumnLayout 包装在 ScrollView 中
        ScrollView {
            id: mainScrollView
            anchors.fill: parent
            anchors.margins: 16

            // 🔥 滚动条设置
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            // 🔥 滚动设置
            contentWidth: availableWidth  // 防止水平滚动
            clip: true

        ColumnLayout {
            id: mainContentLayout
            width: mainScrollView.availableWidth
            spacing: 12


            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: isChineseMode ? "性能曲线图表" : "Performance Curves"
                    font.pixelSize: 16
                    font.bold: true
                    color: Material.primaryTextColor
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 80; height: 24; radius: 12
                    color: curvesData ? Material.color(Material.Green, Material.Shade200) : Material.color(Material.Red, Material.Shade200)
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Rectangle { width: 6; height: 6; radius: 3; color: curvesData ? Material.color(Material.Green) : Material.color(Material.Red) }
                        Text {
                            text: curvesData ? (isChineseMode ? "已载入" : "Loaded") : (isChineseMode ? "等待中" : "Waiting")
                            font.pixelSize: 9; color: Material.primaryTextColor
                        }
                    }
                }

                ToolButton {
                    text: "⚙️"
                    font.pixelSize: 14
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: settingsMenu.open()
                    Menu {
                        id: settingsMenu
                        width: 240
                        MenuItem {
                            text: isChineseMode ? "显示网格" : "Show Grid"
                            checkable: true; checked: showGrid
                            onCheckedChanged: { showGrid = checked; updateGridVisibility() }
                        }
                        MenuItem {
                            text: isChineseMode ? "显示数据点" : "Show Points"
                            checkable: true; checked: showPoints
                            onCheckedChanged: { showPoints = checked; updatePointsVisibility() }
                        }
                        MenuItem {
                            text: isChineseMode ? "显示性能区域" : "Show Zones"
                            checkable: true; checked: showZones
                            onCheckedChanged: { showZones = checked; updateZonesVisibility() }
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: isChineseMode ? "定位到BEP点" : "Focus on BEP"
                            enabled: curvesData !== null
                            onClicked: focusOnBepPoint()
                        }
                        MenuSeparator {}
                        // 🔥 新增：变频图表控制
                        MenuItem {
                            text: isChineseMode ? "显示变频图表" : "Show Variable Frequency Chart"
                            checkable: true; checked: variableFreqChart.visible
                            onCheckedChanged: {
                                variableFreqChart.visible = checked
                            }
                        }

                        MenuItem {
                            text: isChineseMode ? "变频图表设置" : "Frequency Chart Settings"
                            enabled: variableFreqChart.visible
                            onClicked: {
                                // 可以打开变频图表的详细设置对话框
                                console.log("打开变频图表设置")
                            }
                        }
                        MenuSeparator {}

                        Menu {
                            title: isChineseMode ? "曲线平滑方法" : "Curve Smoothing Method"

                            MenuItem {
                                text: isChineseMode ? "LOWESS回归 (推荐)" : "LOWESS Regression (Recommended)"
                                checkable: true
                                checked: smoothingMethod === "lowess"
                                onCheckedChanged: {
                                    if (checked) {
                                        smoothingMethod = "lowess"
                                        if (curvesData) updateChartData()
                                    }
                                }
                            }

                            MenuItem {
                                text: isChineseMode ? "多项式拟合" : "Polynomial Fitting"
                                checkable: true
                                checked: smoothingMethod === "polynomial"
                                onCheckedChanged: {
                                    if (checked) {
                                        smoothingMethod = "polynomial"
                                        if (curvesData) updateChartData()
                                    }
                                }
                            }

                            MenuItem {
                                text: isChineseMode ? "加权移动平均" : "Weighted Moving Average"
                                checkable: true
                                checked: smoothingMethod === "weighted_ma"
                                onCheckedChanged: {
                                    if (checked) {
                                        smoothingMethod = "weighted_ma"
                                        if (curvesData) updateChartData()
                                    }
                                }
                            }

                            MenuItem {
                                text: isChineseMode ? "样条插值 (原有)" : "Spline Interpolation (Original)"
                                checkable: true
                                checked: smoothingMethod === "spline"
                                onCheckedChanged: {
                                    if (checked) {
                                        smoothingMethod = "spline"
                                        if (curvesData) updateChartData()
                                    }
                                }
                            }
                        }

                        MenuItem {
                            text: isChineseMode ? "启用曲线平滑" : "Enable Curve Smoothing"
                            checkable: true
                            checked: enableSmoothing
                            onCheckedChanged: {
                                enableSmoothing = checked
                                if (curvesData) updateChartData()
                            }
                        }
                    }

                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 500
                // 🔥 新增：限制最大宽度，保持4:3的宽高比
                // Layout.maximumWidth: Math.min(parent.width, parent.height * 1.33)
                Layout.maximumWidth: Math.min(parent.width * 0.9, 900)  // 最大900px宽度
                Layout.alignment: Qt.AlignHCenter
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

                    ValuesAxis {
                        id: flowAxis
                        titleText: getFlowAxisTitle()
                        min: 0; max: 2000
                        tickCount: 6
                        gridVisible: showGrid
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#333333"

                        // 🔥 新增：强制整数显示
                        // tickType: ValuesAxis.TicksDynamic
                        // minorTickCount: 0
                        // labelFormat: "%.0f"  // 格式化
                    }
                    ValuesAxis {
                        id: headAxis
                        titleText: getHeadAxisTitle()
                        min: 0; max: 300
                        tickCount: 6
                        gridVisible: showGrid
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#2196F3"

                        // 🔥 新增：强制整数显示
                        // tickType: ValuesAxis.TicksDynamic
                        // minorTickCount: 0
                        // labelFormat: "%.0f"  // 格式化
                    }
                    ValuesAxis {
                        id: efficiencyAxis
                        titleText: isChineseMode ? "效率 (%)" : "Efficiency (%)"
                        min: 0; max: 100
                        tickCount: 6
                        gridVisible: false
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#4CAF50"
                        // 🔥 新增：强制整数显示
                        // tickType: ValuesAxis.TicksDynamic
                        // minorTickCount: 0
                        // labelFormat: "%.0f"  // 效率显示
                    }
                    ValuesAxis {
                        id: powerAxis
                        titleText: getPowerAxisTitle()
                        min: 0; max: 200
                        tickCount: 5
                        gridVisible: false
                        labelsFont.pixelSize: 10
                        titleFont.pixelSize: 12
                        color: "#FF9800"

                        // 🔥 新增：强制整数显示
                        // tickType: ValuesAxis.TicksDynamic
                        // minorTickCount: 0
                        // labelFormat: "%.0f"  // 功率显示为整数
                    }
                    // 🔥 新增：最佳效率点(BEP)范围区域
                    AreaSeries {
                        id: bepZoneArea
                        name: isChineseMode ? "最佳效率点范围" : "BEP Range"
                        axisX: flowAxis
                        axisY: headAxis
                        color: Qt.rgba(1.0, 1.0, 0.0, 0.2)  // 黄色半透明
                        borderColor: Qt.rgba(1.0, 0.8, 0.0, 0.6)  // 橙黄色边框
                        borderWidth: 2
                        visible: showZones && curvesData
                        upperSeries: LineSeries { id: bepZoneUpper }
                        lowerSeries: LineSeries { id: bepZoneLower }
                    }
                    // AreaSeries {
                    //     id: optimalZoneArea
                    //     name: isChineseMode ? "最佳区域" : "Optimal Zone"
                    //     axisX: flowAxis
                    //     axisY: headAxis
                    //     color: Qt.rgba(0.3, 0.8, 0.3, 0.15)
                    //     borderColor: Qt.rgba(0.3, 0.8, 0.3, 0.5)
                    //     borderWidth: 1
                    //     visible: showZones
                    //     upperSeries: LineSeries { id: optimalZoneUpper }
                    //     lowerSeries: LineSeries { id: optimalZoneLower }
                    // }
                    // AreaSeries {
                    //     id: acceptableZoneArea
                    //     name: isChineseMode ? "可接受区域" : "Acceptable Zone"
                    //     axisX: flowAxis
                    //     axisY: headAxis
                    //     color: Qt.rgba(1.0, 0.6, 0.0, 0.1)
                    //     borderColor: Qt.rgba(1.0, 0.6, 0.0, 0.3)
                    //     borderWidth: 1
                    //     visible: showZones
                    //     upperSeries: LineSeries { id: acceptableZoneUpper }
                    //     lowerSeries: LineSeries { id: acceptableZoneLower }
                    // }

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
                    // ScatterSeries {
                    //     id: keyPointsSeries
                    //     name: isChineseMode ? "关键点" : "Key Points"
                    //     axisX: flowAxis
                    //     axisY: headAxis
                    //     color: "#9C27B0"
                    //     markerSize: 10
                    //     markerShape: ScatterSeries.MarkerShapeRectangle
                    //     borderColor: "white"
                    //     borderWidth: 1
                    // }
                    // 🔥 新增：BEP点标记
                    ScatterSeries {
                        id: bepPointSeries
                        name: isChineseMode ? "BEP点" : "BEP Point"
                        axisX: flowAxis
                        axisY: headAxis
                        color: "#FFD700"  // 金黄色
                        markerSize: 20
                        borderColor: "#FF8C00"  // 深橙色边框
                        borderWidth: 3
                        markerShape: ScatterSeries.MarkerShapeCircle
                        visible: curvesData
                    }

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
                        onExited: { crosshairTooltip.visible = false }
                    }

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
                                color: "white"; font.pixelSize: 10
                            }
                            Text {
                                text: `${isChineseMode ? "扬程" : "Head"}: ${crosshairTooltip.headValue.toFixed(1)} ${getHeadUnit()}`
                                color: "white"; font.pixelSize: 10
                            }
                            Text {
                                text: `@${frequency}Hz`
                                color: "yellow"; font.pixelSize: 9; font.bold: true
                            }
                        }
                    }
                }

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
                        BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: !curvesData; width: 32; height: 32 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: isChineseMode ? "正在加载数据..." : "Loading data..."; font.pixelSize: 12; color: Material.secondaryTextColor }
                    }
                }
            }


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: currentOperatingPoint ? 80 : 0
                color: Material.dialogColor
                radius: 8
                visible: currentOperatingPoint !== null
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 24
                    visible: parent.visible

                    Column {
                        spacing: 4
                        Text { text: isChineseMode ? "当前工况点" : "Current Operating Point"; font.pixelSize: 14; font.bold: true; color: Material.primaryTextColor }
                        Text {
                            text: currentOperatingPoint && typeof currentOperatingPoint.flow === 'number' ?
                                  `${isChineseMode ? "流量" : "Flow"}: ${currentOperatingPoint.flow.toFixed(1)} ${getFlowUnit()}` :
                                  `${isChineseMode ? "流量" : "Flow"}: -- ${getFlowUnit()}`
                            font.pixelSize: 12; color: Material.secondaryTextColor
                        }
                        Text {
                            text: currentOperatingPoint && typeof currentOperatingPoint.head === 'number' ?
                                  `${isChineseMode ? "扬程" : "Head"}: ${currentOperatingPoint.head.toFixed(1)} ${getHeadUnit()}` :
                                  `${isChineseMode ? "扬程" : "Head"}: -- ${getHeadUnit()}`
                            font.pixelSize: 12; color: Material.secondaryTextColor
                        }
                    }

                    Column {
                        spacing: 4
                        Text { text: isChineseMode ? "性能参数" : "Performance"; font.pixelSize: 14; font.bold: true; color: Material.primaryTextColor }
                        Text {
                            text: currentOperatingPoint && typeof currentOperatingPoint.efficiency === 'number' ?
                                  `${isChineseMode ? "效率" : "Efficiency"}: ${currentOperatingPoint.efficiency.toFixed(1)}%` :
                                  `${isChineseMode ? "效率" : "Efficiency"}: --%`
                            font.pixelSize: 12; color: Material.secondaryTextColor
                        }
                        Text {
                            text: currentOperatingPoint && typeof currentOperatingPoint.power === 'number' ?
                                  `${isChineseMode ? "功率" : "Power"}: ${currentOperatingPoint.power.toFixed(1)} ${getPowerUnit()}` :
                                  `${isChineseMode ? "功率" : "Power"}: -- ${getPowerUnit()}`
                            font.pixelSize: 12; color: Material.secondaryTextColor
                        }
                    }

                    Rectangle {
                        width: 100; height: 30; radius: 15
                        color: currentOperatingPoint ? getStatusColor(currentOperatingPoint.status) : Material.backgroundColor
                        Text { anchors.centerIn: parent; text: currentOperatingPoint ? currentOperatingPoint.statusText : ""; font.pixelSize: 11; font.bold: true; color: "white" }
                    }

                    Item { Layout.fillWidth: true }
                    // Button { text: isChineseMode ? "设为BEP" : "Set as BEP"; font.pixelSize: 10; implicitHeight: 28; enabled: currentOperatingPoint !== null; onClicked: setBestEfficiencyPoint() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                // Layout.preferredHeight: 700  // 固定高度
                Layout.minimumHeight: 650
                // 🔥 新增：限制宽度，保持合适比例
                Layout.maximumWidth: Math.min(parent.width * 0.9, 900)  // 最大900px宽度
                Layout.alignment: Qt.AlignHCenter
                color: "transparent"
                visible: curvesData !== null  // 只有数据可用时才显示

                VariableFrequencyChart {
                    id: variableFreqChart
                    anchors.fill: parent

                    curvesData: analysisWindow.curvesData
                    isChineseMode: analysisWindow.isChineseMode
                    isMetric: analysisWindow.isMetric
                    stages: analysisWindow.stages
                    currentFrequency: analysisWindow.frequency

                    // 可以从设置中控制显示选项
                    showEfficiencyLines: true
                    showFrequencyLabels: true
                    showCurrentFrequencyHighlight: true
                }
            }

            // 🔥 底部间距，确保滚动到底部时有足够空间
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
            }
        }
        }
    }

    footer: Rectangle {
        height: 32
        color: Material.dialogColor
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            Text { text: isChineseMode ? "状态: 就绪" : "Status: Ready"; font.pixelSize: 10; color: Material.hintTextColor }
            Item { Layout.fillWidth: true }
            Text {
                text: {
                    if (pumpData) { return `${isChineseMode ? "数据:" : "Data:"} ${curvesData ? "已加载" : "等待中"}` }
                    return ""
                }
                font.pixelSize: 10; color: Material.hintTextColor
            }
            Rectangle { width: 8; height: 8; radius: 4; color: curvesData ? Material.color(Material.Green) : Material.color(Material.Red) }
        }
    }

    // ====== 图表更新 ======
    function updateChartData() {
        console.log("开始更新图表数据")
        if (!curvesData || !curvesData.baseCurves) {
            console.log("没有曲线数据")
            resetBepZone()  // 🔥 重置BEP区域
            return
        }
        if (!curvesData || !curvesData.baseCurves) { console.log("没有曲线数据"); return }
        var curves = curvesData.baseCurves
        updateAxisRanges(curves)
        updateHeadCurve(curves)
        updateEfficiencyCurve(curves)
        updatePowerCurve(curves)
        // updatePerformanceZones()
        updateBepZone(curves)  // 🔥 更新BEP区域
        console.log("图表数据更新完成")
    }

    // function updateAxisRanges(curves) {
    //     if (curves.flow && curves.flow.length > 0) {
    //         var dispFlows = curves.flow.map(f => toDisplayFlow(f))
    //         flowAxis.min = Math.max(0, Math.min.apply(null, dispFlows) * 0.9)
    //         flowAxis.max = Math.max.apply(null, dispFlows) * 1.1
    //     }
    //     if (curves.head && curves.head.length > 0) {
    //         var dispHeads = curves.head.map(h => toDisplayHead(h))
    //         headAxis.min = Math.max(0, Math.min.apply(null, dispHeads) * 0.9)
    //         headAxis.max = Math.max.apply(null, dispHeads) * 1.1
    //     }
    //     if (curves.power && curves.power.length > 0) {
    //         var dispPowers = curves.power.map(p => toDisplayPower(p))
    //         powerAxis.min = 0
    //         powerAxis.max = Math.max.apply(null, dispPowers) * 1.1
    //     }



    //     // 🔥 新增：效率轴动态范围
    //     if (curves.efficiency && curves.efficiency.length > 0) {
    //         var validEfficiencies = curves.efficiency.filter(e => !isNaN(e) && e > 0)
    //         if (validEfficiencies.length > 0) {
    //             var minEfficiency = Math.min.apply(null, validEfficiencies)
    //             var maxEfficiency = Math.max.apply(null, validEfficiencies)

    //             // 🔥 为效率轴添加合理的边距
    //             var efficiencyRange = maxEfficiency - minEfficiency
    //             var margin = Math.max(efficiencyRange * 0.1, 5) // 至少5%的边距

    //             efficiencyAxis.min = Math.max(0, minEfficiency - margin)
    //             efficiencyAxis.max = Math.min(100, maxEfficiency + margin) // 效率不超过100%

    //             console.log(`效率轴范围: ${efficiencyAxis.min.toFixed(1)} - ${efficiencyAxis.max.toFixed(1)}%`)
    //         } else {
    //             // 如果没有有效的效率数据，使用默认范围
    //             efficiencyAxis.min = 0
    //             efficiencyAxis.max = 100
    //             console.log("效率轴使用默认范围: 0 - 100%")
    //         }
    //     }
    // }
    function updateAxisRanges(curves) {
        if (curves.flow && curves.flow.length > 0) {
            var dispFlows = curves.flow.map(f => toDisplayFlow(f))
            flowAxis.min = Math.floor(Math.max(0, Math.min.apply(null, dispFlows) * 0.9))  // 🔥 使用 Math.floor
            flowAxis.max = Math.ceil(Math.max.apply(null, dispFlows) * 1.1)               // 🔥 使用 Math.ceil
        }
        if (curves.head && curves.head.length > 0) {
            var dispHeads = curves.head.map(h => toDisplayHead(h))
            headAxis.min = Math.floor(Math.max(0, Math.min.apply(null, dispHeads) * 0.9))  // 🔥 使用 Math.floor
            headAxis.max = Math.ceil(Math.max.apply(null, dispHeads) * 1.1)                // 🔥 使用 Math.ceil
        }
        if (curves.power && curves.power.length > 0) {
            var dispPowers = curves.power.map(p => toDisplayPower(p))
            powerAxis.min = 0
            powerAxis.max = Math.ceil(Math.max.apply(null, dispPowers) * 1.1)  // 🔥 使用 Math.ceil
        }

        // 效率轴整数范围
        if (curves.efficiency && curves.efficiency.length > 0) {
            var validEfficiencies = curves.efficiency.filter(e => !isNaN(e) && e > 0)
            if (validEfficiencies.length > 0) {
                var minEfficiency = Math.min.apply(null, validEfficiencies)
                var maxEfficiency = Math.max.apply(null, validEfficiencies)

                var efficiencyRange = maxEfficiency - minEfficiency
                var margin = Math.max(efficiencyRange * 0.1, 5)

                efficiencyAxis.min = Math.floor(Math.max(0, minEfficiency - margin))      // 🔥 使用 Math.floor
                efficiencyAxis.max = Math.ceil(Math.min(100, maxEfficiency + margin))    // 🔥 使用 Math.ceil

                console.log(`效率轴范围: ${efficiencyAxis.min} - ${efficiencyAxis.max}%`)
            } else {
                efficiencyAxis.min = 0
                efficiencyAxis.max = 100
            }
        }
    }

    // function updateHeadCurve(curves) {
    //     headCurve.clear()
    //     if (curves.flow && curves.head) {
    //         var n = Math.min(curves.flow.length, curves.head.length)
    //         for (var i = 0; i < n; i++) {
    //             var q = toDisplayFlow(curves.flow[i])
    //             var h = toDisplayHead(curves.head[i])
    //             if (!isNaN(q) && !isNaN(h)) headCurve.append(q, h)
    //         }
    //         console.log("扬程曲线已更新，点数:", headCurve.count)
    //     }
    // }
    // function updateEfficiencyCurve(curves) {
    //     efficiencyCurve.clear()
    //     if (curves.flow && curves.efficiency) {
    //         var n = Math.min(curves.flow.length, curves.efficiency.length)
    //         for (var i = 0; i < n; i++) {
    //             var q = toDisplayFlow(curves.flow[i])
    //             var e = curves.efficiency[i]
    //             if (!isNaN(q) && !isNaN(e)) efficiencyCurve.append(q, e)
    //         }
    //         console.log("效率曲线已更新，点数:", efficiencyCurve.count)
    //     }
    // }
    // function updatePowerCurve(curves) {
    //     powerCurve.clear()
    //     if (curves.flow && curves.power) {
    //         var n = Math.min(curves.flow.length, curves.power.length)
    //         for (var i = 0; i < n; i++) {
    //             var q = toDisplayFlow(curves.flow[i])
    //             var p = toDisplayPower(curves.power[i])
    //             if (!isNaN(q) && !isNaN(p)) powerCurve.append(q, p)
    //         }
    //         console.log("功率曲线已更新，点数:", powerCurve.count)
    //     }
    // }
    // 🔥 修改 updateHeadCurve 函数以应用平滑
    function updateHeadCurve(curves) {
        headCurve.clear()
        if (curves.flow && curves.head) {
            var originalFlows = []
            var originalHeads = []

            // 收集原始数据点
            var n = Math.min(curves.flow.length, curves.head.length)
            for (var i = 0; i < n; i++) {
                var q = toDisplayFlow(curves.flow[i])
                var h = toDisplayHead(curves.head[i])
                if (!isNaN(q) && !isNaN(h)) {
                    originalFlows.push(q)
                    originalHeads.push(h)
                }
            }

            // 🔥 应用平滑算法
            var smoothedData
            if (enableSmoothing && originalFlows.length >= 3) {
                switch (smoothingMethod) {
                    case "polynomial":
                        // 🔥 多项式拟合（推荐用于扬程曲线）
                        smoothedData = polynomialFit(originalFlows, originalHeads, 3)  // 3次多项式
                        break
                    case "lowess":
                        // 🔥 LOWESS局部回归（最佳选择）
                        smoothedData = lowessSmooth(originalFlows, originalHeads, 0.4)
                        break
                    case "weighted_ma":
                        // 🔥 加权移动平均
                        smoothedData = weightedMovingAverage(originalFlows, originalHeads, 5)
                        break
                    case "spline":
                        smoothedData = createSmoothCurve(originalFlows, originalHeads)
                        break
                    case "moving_average":
                        smoothedData = movingAverageSmooth(originalFlows, originalHeads, 3)
                        break
                    case "bezier":
                        smoothedData = bezierSmooth(originalFlows, originalHeads)
                        break
                    default:
                        // 🔥 默认使用LOWESS
                        smoothedData = lowessSmooth(originalFlows, originalHeads, 0.3)
                }

                // 使用平滑后的数据
                for (var j = 0; j < smoothedData.x.length; j++) {
                    headCurve.append(smoothedData.x[j], smoothedData.y[j])
                }
            } else {
                // 不平滑，直接使用原始数据
                for (var k = 0; k < originalFlows.length; k++) {
                    headCurve.append(originalFlows[k], originalHeads[k])
                }
            }

            console.log("扬程曲线已更新，点数:", headCurve.count, "平滑:", enableSmoothing)
        }
    }

    // 🔥 同样修改效率和功率曲线更新函数
    // function updateEfficiencyCurve(curves) {
    //     efficiencyCurve.clear()
    //     if (curves.flow && curves.efficiency) {
    //         var originalFlows = []
    //         var originalEfficiencies = []

    //         var n = Math.min(curves.flow.length, curves.efficiency.length)
    //         for (var i = 0; i < n; i++) {
    //             var q = toDisplayFlow(curves.flow[i])
    //             var e = curves.efficiency[i]
    //             if (!isNaN(q) && !isNaN(e) && e > 0) {
    //                 originalFlows.push(q)
    //                 originalEfficiencies.push(e)
    //             }
    //         }

    //         // 🔥 应用平滑算法
    //         var smoothedData
    //         if (enableSmoothing && originalFlows.length >= 3) {
    //             // smoothedData = createSmoothCurve(originalFlows, originalEfficiencies)
    //             smoothedData = polynomialFit(originalFlows, originalEfficiencies, 2)  // 2次多项式更适合效率曲线

    //             for (var j = 0; j < smoothedData.x.length; j++) {
    //                 efficiencyCurve.append(smoothedData.x[j], smoothedData.y[j])
    //             }
    //         } else {
    //             for (var k = 0; k < originalFlows.length; k++) {
    //                 efficiencyCurve.append(originalFlows[k], originalEfficiencies[k])
    //             }
    //         }

    //         console.log("效率曲线已更新，点数:", efficiencyCurve.count, "平滑:", enableSmoothing)
    //     }
    // }
    function updateEfficiencyCurve(curves) {
        efficiencyCurve.clear()
        if (curves.flow && curves.efficiency) {
            var originalFlows = []
            var originalEfficiencies = []

            var n = Math.min(curves.flow.length, curves.efficiency.length)
            console.log(`处理效率曲线数据：${n}个点`)

            for (var i = 0; i < n; i++) {
                var q = toDisplayFlow(curves.flow[i])
                var e = curves.efficiency[i]

                // 🔥 修复：放宽过滤条件，保留第一个点
                if (!isNaN(q) && !isNaN(e) && e >= 0) {  // 改为 >= 0，允许效率为0的点
                    originalFlows.push(q)
                    originalEfficiencies.push(e)

                    // 🔥 调试信息：记录第一个和最后几个点
                    if (i === 0) {
                        console.log(`效率曲线第一个点：流量=${q.toFixed(2)}, 效率=${e.toFixed(2)}%`)
                    }
                } else {
                    // 🔥 记录被过滤的点
                    console.log(`效率曲线第${i}个点被过滤：流量=${q}, 效率=${e}`)
                }
            }

            console.log(`效率曲线有效数据点：${originalFlows.length}/${n}`)

            // 🔥 应用平滑算法
            var smoothedData
            if (enableSmoothing && originalFlows.length >= 3) {
                // 🔥 对于效率曲线，使用较低次数的多项式拟合
                smoothedData = polynomialFit(originalFlows, originalEfficiencies, 2)

                for (var j = 0; j < smoothedData.x.length; j++) {
                    efficiencyCurve.append(smoothedData.x[j], smoothedData.y[j])
                }

                console.log(`效率曲线平滑后点数：${smoothedData.x.length}`)
            } else {
                // 不平滑，直接使用原始数据
                for (var k = 0; k < originalFlows.length; k++) {
                    efficiencyCurve.append(originalFlows[k], originalEfficiencies[k])
                }

                console.log(`效率曲线原始数据点数：${originalFlows.length}`)
            }

            console.log("效率曲线已更新，最终点数:", efficiencyCurve.count, "平滑:", enableSmoothing)
        }
    }

    function updatePowerCurve(curves) {
        powerCurve.clear()
        if (curves.flow && curves.power) {
            var originalFlows = []
            var originalPowers = []

            var n = Math.min(curves.flow.length, curves.power.length)
            for (var i = 0; i < n; i++) {
                var q = toDisplayFlow(curves.flow[i])
                var p = toDisplayPower(curves.power[i])
                if (!isNaN(q) && !isNaN(p)) {
                    originalFlows.push(q)
                    originalPowers.push(p)
                }
            }

            // 🔥 应用平滑算法
            var smoothedData
            if (enableSmoothing && originalFlows.length >= 3) {
                // smoothedData = createSmoothCurve(originalFlows, originalPowers)
                smoothedData = polynomialFit(originalFlows, originalPowers, 2)  // 2次多项式更适合效率曲线

                for (var j = 0; j < smoothedData.x.length; j++) {
                    powerCurve.append(smoothedData.x[j], smoothedData.y[j])
                }
            } else {
                for (var k = 0; k < originalFlows.length; k++) {
                    powerCurve.append(originalFlows[k], originalPowers[k])
                }
            }

            console.log("功率曲线已更新，点数:", powerCurve.count, "平滑:", enableSmoothing)
        }
    }

    // 🔥 修复 updatePerformanceZones 函数 - 移除对注释掉组件的引用
    function updatePerformanceZones() {
        // 🔥 移除对被注释掉的组件的引用
        // optimalZoneArea.visible = false
        // acceptableZoneArea.visible = false

        if (!curvesData || !curvesData.performanceZones || !showZones) {
            console.log("没有性能区域数据或显示已关闭")
            return
        }

        var zones = curvesData.performanceZones
        var curves = curvesData.baseCurves

        console.log("性能区域数据:", JSON.stringify(zones))
        console.log("性能区域更新完成（当前仅支持BEP区域）")
    }

    // 🔥 修改工况点操作，考虑频率换算
    function updateOperatingPointDisplay(flow, head) {
        if (flow !== undefined && head !== undefined && !isNaN(flow) && !isNaN(head)) {
            operatingPointSeries.clear()
            operatingPointSeries.append(flow, head)
            console.log(`工况点显示已更新 @${frequency}Hz:`, flow.toFixed(1), getFlowUnit() + ",", head.toFixed(1), getHeadUnit())

            if (!currentOperatingPoint) {
                currentOperatingPoint = {}
            }

            // 🔥 安全地设置数值，确保有默认值
            currentOperatingPoint.flow = isNaN(flow) ? 0 : flow
            currentOperatingPoint.head = isNaN(head) ? 0 : head
            
            // 🔥 安全地获取插值结果，提供默认值
            var efficiency = interpolateEfficiency(flow)
            var power = interpolatePower(flow)

            currentOperatingPoint.efficiency = isNaN(efficiency) ? 0 : efficiency
            currentOperatingPoint.power = isNaN(power) ? 0 : power

            console.log("当前工况点详细信息:")
            console.log(`  流量: ${currentOperatingPoint.flow}`)
            console.log(`  扬程: ${currentOperatingPoint.head}`)
            console.log(`  效率: ${currentOperatingPoint.efficiency}`)
            console.log(`  功率: ${currentOperatingPoint.power}`)


            // 🔥 评估工况点状态时考虑频率换算
            var bepInfo = getCurrentBepInfo()
            if (bepInfo) {
                var flowDiff = Math.abs(flow - bepInfo.flow) / bepInfo.flow
                var headDiff = Math.abs(head - bepInfo.head) / bepInfo.head

                if (flowDiff <= 0.1 && headDiff <= 0.05) {
                    currentOperatingPoint.status = 'optimal'
                    currentOperatingPoint.statusText = isChineseMode ? "最佳区域" : "Optimal"
                } else if (flowDiff <= 0.2 && headDiff <= 0.1) {
                    currentOperatingPoint.status = 'acceptable'
                    currentOperatingPoint.statusText = isChineseMode ? "可接受" : "Acceptable"
                } else {
                    currentOperatingPoint.status = 'warning'
                    currentOperatingPoint.statusText = isChineseMode ? "需要关注" : "Caution"
                }
            }
            // 🔥 强制触发QML更新
            currentOperatingPointChanged()
        }
    }

    // 🔥 添加调试信息函数
    function debugFrequencyConversion() {
        console.log("=== 频率换算调试信息 ===")
        console.log(`当前频率: ${frequency}Hz`)
        console.log(`流量换算系数: ${(50/frequency).toFixed(3)}`)
        console.log(`扬程换算系数: ${Math.pow(50/frequency, 2).toFixed(3)}`)
        console.log(`功率换算系数: ${Math.pow(50/frequency, 3).toFixed(3)}`)

        if (curvesData && curvesData.baseCurves && curvesData.baseCurves.flow.length > 0) {
            var originalFlow = curvesData.baseCurves.flow[0]
            var displayFlow = toDisplayFlow(originalFlow)
            var backToOriginal = fromDisplayFlow(displayFlow)

            console.log(`流量转换测试: 原始=${originalFlow.toFixed(1)} -> 显示=${displayFlow.toFixed(1)} -> 回转=${backToOriginal.toFixed(1)}`)
        }
    }

    // 🔥 修改插值函数，使用正确的换算
    function interpolateEfficiency(targetFlowDisplay) {
        if (!curvesData || !curvesData.baseCurves) return 75

        // 🔥 将目标流量转换回原始值进行插值
        var targetFlowOriginal = fromDisplayFlow(targetFlowDisplay)

        // 使用原始流量数据进行插值
        var flowsOriginal = curvesData.baseCurves.flow
        var efficiencies = curvesData.baseCurves.efficiency

        return interpolateValue(targetFlowOriginal, flowsOriginal, efficiencies)
    }

    function interpolatePower(targetFlowDisplay) {
        if (!curvesData || !curvesData.baseCurves) return 50

        // 🔥 将目标流量转换回原始值进行插值
        var targetFlowOriginal = fromDisplayFlow(targetFlowDisplay)

        // 使用原始数据进行插值，然后转换显示值
        var flowsOriginal = curvesData.baseCurves.flow
        var powersOriginal = curvesData.baseCurves.power

        var interpolatedPowerOriginal = interpolateValue(targetFlowOriginal, flowsOriginal, powersOriginal)
        return toDisplayPower(interpolatedPowerOriginal)
    }

    function interpolateValue(targetX, xArray, yArray) {
        if (!xArray || !yArray || xArray.length !== yArray.length || xArray.length === 0) return 0
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

    function updateGridVisibility() { flowAxis.gridVisible = showGrid; headAxis.gridVisible = showGrid }
    function updatePointsVisibility() { headCurve.pointsVisible = showPoints; efficiencyCurve.pointsVisible = showPoints }
    // 🔥 修复updateZonesVisibility函数
    function updateZonesVisibility() {
        var shouldShowZones = showZones && curvesData

        // 🔥 BEP区域控制
        if (bepZoneArea) {
            bepZoneArea.visible = shouldShowZones && bepZoneUpper.count > 0
        }
        if (bepPointSeries) {
            bepPointSeries.visible = shouldShowZones
        }

        console.log("区域可见性更新完成 - BEP区域:", shouldShowZones)
    }

    function getStatusColor(status) {
        switch (status) {
        case 'optimal': return Material.color(Material.Green)
        case 'acceptable': return Material.color(Material.Orange)
        case 'dangerous': return Material.color(Material.Red)
        default: return Material.color(Material.Grey)
        }
    }

    // 🔥 修改setBestEfficiencyPoint函数，添加实际功能
    function setBestEfficiencyPoint() {
        var bepInfo = getCurrentBepInfo()
        if (bepInfo) {
            console.log("设置BEP点为当前工况点:")
            console.log(`  流量: ${bepInfo.flow.toFixed(1)} ${bepInfo.flowUnit}`)
            console.log(`  扬程: ${bepInfo.head.toFixed(1)} ${bepInfo.headUnit}`)
            console.log(`  效率: ${bepInfo.efficiency.toFixed(1)}%`)
            console.log(`  功率: ${bepInfo.power.toFixed(1)} ${bepInfo.powerUnit}`)

            // 🔥 更新当前工况点为BEP点
            currentOperatingPoint = {
                flow: bepInfo.flow,
                head: bepInfo.head,
                efficiency: bepInfo.efficiency,
                power: bepInfo.power,
                status: 'optimal',
                statusText: isChineseMode ? "最佳效率点" : "Best Efficiency Point"
            }

            // 🔥 在图表上显示工况点
            updateOperatingPointDisplay(bepInfo.flow, bepInfo.head)

            // 🔥 发射信号通知外部
            operatingPointChanged(bepInfo.flow, bepInfo.head)
        } else {
            console.log("无法获取BEP信息")
        }
    }

    function exportAnalysisData() {
        console.log("=== 导出性能分析数据 ===")
        if (!pumpData) { console.warn("没有数据可导出"); return }
        var exportData = {
            pump: { manufacturer: pumpData.manufacturer, model: pumpData.model, stages: stages, frequency: frequency },
            curves: curvesData,
            operatingPoint: currentOperatingPoint,
            exportTime: new Date().toISOString()
        }
        console.log("导出数据:", JSON.stringify(exportData, null, 2))
    }
    // 🔥 新增：计算并更新BEP区域
    function updateBepZone(curves) {
        console.log("开始更新BEP区域")

        // 清空现有数据
        bepZoneUpper.clear()
        bepZoneLower.clear()
        bepPointSeries.clear()

        if (!curves.flow || !curves.efficiency || !curves.head) {
            console.log("缺少BEP计算所需的曲线数据")
            bepZoneArea.visible = false
            bepPointSeries.visible = false
            return
        }

        // 🔥 计算最佳效率点
        var bepData = calculateBestEfficiencyPoint(curves)
        if (!bepData) {
            console.log("无法计算BEP点")
            bepZoneArea.visible = false
            bepPointSeries.visible = false
            return
        }

        var bepFlowDisplay = toDisplayFlow(bepData.flow)
        var bepHeadDisplay = toDisplayHead(bepData.head)

        console.log(`BEP点: 流量=${bepFlowDisplay.toFixed(1)} ${getFlowUnit()}, 扬程=${bepHeadDisplay.toFixed(1)} ${getHeadUnit()}, 效率=${bepData.efficiency.toFixed(1)}%`)

        // 🔥 添加BEP点标记
        bepPointSeries.append(bepFlowDisplay, bepHeadDisplay)
        bepPointSeries.visible = true

        // 🔥 计算BEP范围（±10%流量范围）
        var flowRangePercent = 0.1  // 10%范围
        var minFlowDisplay = bepFlowDisplay * (1 - flowRangePercent)
        var maxFlowDisplay = bepFlowDisplay * (1 + flowRangePercent)

        // 确保范围在有效流量范围内
        minFlowDisplay = Math.max(minFlowDisplay, flowAxis.min)
        maxFlowDisplay = Math.min(maxFlowDisplay, flowAxis.max)

        console.log(`BEP范围: ${minFlowDisplay.toFixed(1)} - ${maxFlowDisplay.toFixed(1)} ${getFlowUnit()}`)

        // 🔥 生成BEP范围区域的边界线
        generateBepZoneBoundaries(curves, minFlowDisplay, maxFlowDisplay, bepHeadDisplay)

        // 设置区域可见
        bepZoneArea.visible = showZones && bepZoneUpper.count > 0
    }
    // 🔥 修改BEP计算，使用原始数据计算后再转换显示
    function calculateBestEfficiencyPoint(curves) {
        try {
            var maxEfficiency = 0
            var bepIndex = -1

            // 🔥 在原始数据中找到效率最高的点
            for (var i = 0; i < curves.efficiency.length; i++) {
                var eff = curves.efficiency[i]
                if (!isNaN(eff) && eff > maxEfficiency) {
                    maxEfficiency = eff
                    bepIndex = i
                }
            }

            if (bepIndex === -1 || bepIndex >= curves.flow.length || bepIndex >= curves.head.length) {
                console.log("无法找到有效的BEP点")
                return null
            }

            // 🔥 返回原始数据值，由调用者负责转换
            return {
                index: bepIndex,
                flow: curves.flow[bepIndex],        // 原始公制单位 m³/d（50Hz基准）
                head: curves.head[bepIndex],        // 原始公制单位 m（50Hz基准）
                efficiency: maxEfficiency,          // 百分比（不受频率影响）
                power: curves.power && curves.power[bepIndex] ? curves.power[bepIndex] : 0  // 原始公制单位 kW（50Hz基准）
            }

        } catch (error) {
            console.log("计算BEP点时出错:", error)
            return null
        }
    }

    // 🔥 新增：生成BEP范围区域的边界线
    function generateBepZoneBoundaries(curves, minFlowDisplay, maxFlowDisplay, bepHeadDisplay) {
        try {
            // 🔥 根据扬程曲线生成上下边界
            var headMarginPercent = 0.05  // 扬程±5%范围
            var headMargin = bepHeadDisplay * headMarginPercent

            // 🔥 在指定流量范围内，沿着扬程曲线生成边界点
            for (var i = 0; i < curves.flow.length; i++) {
                var flowDisplay = toDisplayFlow(curves.flow[i])
                var headDisplay = toDisplayHead(curves.head[i])

                if (flowDisplay >= minFlowDisplay && flowDisplay <= maxFlowDisplay && !isNaN(headDisplay)) {
                    // 上边界：扬程曲线 + 边距
                    bepZoneUpper.append(flowDisplay, headDisplay + headMargin)

                    // 下边界：扬程曲线 - 边距
                    bepZoneLower.append(flowDisplay, Math.max(0, headDisplay - headMargin))
                }
            }

            // 🔥 如果没有足够的点，至少在BEP点周围创建一个矩形区域
            if (bepZoneUpper.count === 0) {
                console.log("在扬程曲线上没找到足够的点，创建矩形BEP区域")
                createRectangularBepZone(minFlowDisplay, maxFlowDisplay, bepHeadDisplay, headMargin)
            }

            console.log(`BEP区域生成完成: 上边界${bepZoneUpper.count}点, 下边界${bepZoneLower.count}点`)

        } catch (error) {
            console.log("生成BEP边界时出错:", error)
        }
    }

    // 🔥 新增：创建矩形BEP区域（备用方案）
    function createRectangularBepZone(minFlowDisplay, maxFlowDisplay, bepHeadDisplay, headMargin) {
        // 创建矩形区域的四个角点
        var upperHead = bepHeadDisplay + headMargin
        var lowerHead = Math.max(0, bepHeadDisplay - headMargin)

        // 上边界线（水平线）
        bepZoneUpper.append(minFlowDisplay, upperHead)
        bepZoneUpper.append(maxFlowDisplay, upperHead)

        // 下边界线（水平线）
        bepZoneLower.append(minFlowDisplay, lowerHead)
        bepZoneLower.append(maxFlowDisplay, lowerHead)
    }

    // 🔥 新增：重置BEP区域
    function resetBepZone() {
        bepZoneUpper.clear()
        bepZoneLower.clear()
        bepPointSeries.clear()
        bepZoneArea.visible = false
        bepPointSeries.visible = false
    }

    // 🔥 新增：获取当前BEP信息（供外部调用）
    function getCurrentBepInfo() {
        if (!curvesData || !curvesData.baseCurves) {
            return null
        }

        var bepData = calculateBestEfficiencyPoint(curvesData.baseCurves)
        if (!bepData) {
            return null
        }

        return {
            flow: toDisplayFlow(bepData.flow),
            head: toDisplayHead(bepData.head),
            efficiency: bepData.efficiency,
            power: toDisplayPower(bepData.power),
            flowUnit: getFlowUnit(),
            headUnit: getHeadUnit(),
            powerUnit: getPowerUnit()
        }
    }
    // 🔥 新增：聚焦到BEP点
    function focusOnBepPoint() {
        var bepInfo = getCurrentBepInfo()
        if (bepInfo) {
            // 设置坐标轴范围以BEP点为中心
            var flowRange = (flowAxis.max - flowAxis.min) * 0.3
            var headRange = (headAxis.max - headAxis.min) * 0.3

            flowAxis.min = Math.max(0, bepInfo.flow - flowRange)
            flowAxis.max = bepInfo.flow + flowRange
            headAxis.min = Math.max(0, bepInfo.head - headRange)
            headAxis.max = bepInfo.head + headRange

            console.log(`已聚焦到BEP点: ${bepInfo.flow.toFixed(1)} ${bepInfo.flowUnit}, ${bepInfo.head.toFixed(1)} ${bepInfo.headUnit}`)
        }
    }
    // 🔥 新增：重置所有图表数据的函数
    function resetChartData() {
        console.log("重置所有图表数据")

        // 清空曲线数据
        if (headCurve) headCurve.clear()
        if (efficiencyCurve) efficiencyCurve.clear()
        if (powerCurve) powerCurve.clear()

        // 重置BEP区域
        resetBepZone()

        // 重置坐标轴范围
        flowAxis.min = 0
        flowAxis.max = 2000
        headAxis.min = 0
        headAxis.max = 300
        efficiencyAxis.min = 0
        efficiencyAxis.max = 100
        powerAxis.min = 0
        powerAxis.max = 200

        console.log("图表数据重置完成")
    }

    // 🔥 样条插值函数
    function createSmoothCurve(xPoints, yPoints) {
        if (!xPoints || !yPoints || xPoints.length < 3) {
            return { x: xPoints, y: yPoints }
        }

        var smoothX = []
        var smoothY = []

        var minX = Math.min.apply(null, xPoints)
        var maxX = Math.max.apply(null, xPoints)
        var step = (maxX - minX) / interpolationPoints

        // 生成更密集的X点
        for (var i = 0; i <= interpolationPoints; i++) {
            var x = minX + i * step
            var y = cubicSplineInterpolation(x, xPoints, yPoints)
            if (!isNaN(y)) {
                smoothX.push(x)
                smoothY.push(y)
            }
        }

        return { x: smoothX, y: smoothY }
    }

    // 🔥 三次样条插值实现
    function cubicSplineInterpolation(targetX, xPoints, yPoints) {
        var n = xPoints.length
        if (n < 2) return yPoints[0] || 0

        // 找到目标点在哪个区间
        var i = 0
        for (i = 0; i < n - 1; i++) {
            if (targetX <= xPoints[i + 1]) break
        }

        // 边界处理
        if (i >= n - 1) i = n - 2
        if (i < 0) i = 0

        var x0 = xPoints[i]
        var x1 = xPoints[i + 1]
        var y0 = yPoints[i]
        var y1 = yPoints[i + 1]

        // 计算斜率（简化版本）
        var m0 = i > 0 ? (yPoints[i] - yPoints[i - 1]) / (xPoints[i] - xPoints[i - 1]) : 0
        var m1 = i < n - 2 ? (yPoints[i + 2] - yPoints[i + 1]) / (xPoints[i + 2] - xPoints[i + 1]) : 0

        // Hermite插值
        var t = (targetX - x0) / (x1 - x0)
        var t2 = t * t
        var t3 = t2 * t

        var h00 = 2 * t3 - 3 * t2 + 1
        var h10 = t3 - 2 * t2 + t
        var h01 = -2 * t3 + 3 * t2
        var h11 = t3 - t2

        return h00 * y0 + h10 * (x1 - x0) * m0 + h01 * y1 + h11 * (x1 - x0) * m1
    }

    // 🔥 改进的移动平均平滑
    function movingAverageSmooth(xPoints, yPoints, windowSize) {
        if (!windowSize) windowSize = 3
        var smoothY = []

        for (var i = 0; i < yPoints.length; i++) {
            var sum = 0
            var count = 0
            var halfWindow = Math.floor(windowSize / 2)

            for (var j = Math.max(0, i - halfWindow); j <= Math.min(yPoints.length - 1, i + halfWindow); j++) {
                sum += yPoints[j]
                count++
            }

            smoothY.push(sum / count)
        }

        return { x: xPoints, y: smoothY }
    }

    // 🔥 贝塞尔曲线平滑
    function bezierSmooth(xPoints, yPoints) {
        if (xPoints.length < 4) return { x: xPoints, y: yPoints }

        var smoothX = []
        var smoothY = []
        var steps = 50  // 每段贝塞尔曲线的细分点数

        for (var i = 0; i < xPoints.length - 3; i += 2) {
            var p0x = xPoints[i], p0y = yPoints[i]
            var p1x = xPoints[i + 1], p1y = yPoints[i + 1]
            var p2x = xPoints[i + 2], p2y = yPoints[i + 2]
            var p3x = xPoints[i + 3], p3y = yPoints[i + 3]

            for (var t = 0; t <= 1; t += 1 / steps) {
                var x = Math.pow(1 - t, 3) * p0x + 3 * Math.pow(1 - t, 2) * t * p1x + 3 * (1 - t) * Math.pow(t, 2) * p2x + Math.pow(t, 3) * p3x
                var y = Math.pow(1 - t, 3) * p0y + 3 * Math.pow(1 - t, 2) * t * p1y + 3 * (1 - t) * Math.pow(t, 2) * p2y + Math.pow(t, 3) * p3y

                smoothX.push(x)
                smoothY.push(y)
            }
        }

        return { x: smoothX, y: smoothY }
    }

    // 🔥 新增：多项式拟合函数（不穿过所有点，符合趋势）
    function polynomialFit(xPoints, yPoints, degree) {
        if (!xPoints || !yPoints || xPoints.length < degree + 1) {
            return { x: xPoints, y: yPoints }
        }

        // 🔥 使用最小二乘法进行多项式拟合
        var coefficients = leastSquaresPolynomial(xPoints, yPoints, degree)

        // 生成拟合后的平滑曲线点
        var smoothX = []
        var smoothY = []

        var minX = Math.min.apply(null, xPoints)
        var maxX = Math.max.apply(null, xPoints)
        var step = (maxX - minX) / 100  // 生成100个点的光滑曲线

        for (var i = 0; i <= 100; i++) {
            var x = minX + i * step
            var y = evaluatePolynomial(coefficients, x)
            if (!isNaN(y) && y > 0) {  // 过滤无效值
                smoothX.push(x)
                smoothY.push(y)
            }
        }

        return { x: smoothX, y: smoothY }
    }

    // 🔥 最小二乘法多项式拟合
    function leastSquaresPolynomial(xPoints, yPoints, degree) {
        var n = xPoints.length
        var matrix = []
        var vector = []

        // 构建正规方程矩阵 (X^T * X)
        for (var i = 0; i <= degree; i++) {
            matrix[i] = []
            var sum = 0

            // 计算 X^T * y
            for (var k = 0; k < n; k++) {
                sum += Math.pow(xPoints[k], i) * yPoints[k]
            }
            vector[i] = sum

            // 计算 X^T * X
            for (var j = 0; j <= degree; j++) {
                var matrixSum = 0
                for (var k = 0; k < n; k++) {
                    matrixSum += Math.pow(xPoints[k], i + j)
                }
                matrix[i][j] = matrixSum
            }
        }

        // 高斯消元法解方程组
        return solveLinearSystem(matrix, vector)
    }

    // 🔥 高斯消元法解线性方程组
    function solveLinearSystem(matrix, vector) {
        var n = matrix.length
        var coefficients = new Array(n)

        // 前向消元
        for (var i = 0; i < n; i++) {
            // 寻找主元
            var maxRow = i
            for (var k = i + 1; k < n; k++) {
                if (Math.abs(matrix[k][i]) > Math.abs(matrix[maxRow][i])) {
                    maxRow = k
                }
            }

            // 交换行
            if (maxRow !== i) {
                var temp = matrix[i]
                matrix[i] = matrix[maxRow]
                matrix[maxRow] = temp

                var tempV = vector[i]
                vector[i] = vector[maxRow]
                vector[maxRow] = tempV
            }

            // 消元
            for (var k = i + 1; k < n; k++) {
                var factor = matrix[k][i] / matrix[i][i]
                for (var j = i; j < n; j++) {
                    matrix[k][j] -= factor * matrix[i][j]
                }
                vector[k] -= factor * vector[i]
            }
        }

        // 回代
        for (var i = n - 1; i >= 0; i--) {
            coefficients[i] = vector[i]
            for (var j = i + 1; j < n; j++) {
                coefficients[i] -= matrix[i][j] * coefficients[j]
            }
            coefficients[i] /= matrix[i][i]
        }

        return coefficients
    }

    // 🔥 计算多项式值
    function evaluatePolynomial(coefficients, x) {
        var result = 0
        for (var i = 0; i < coefficients.length; i++) {
            result += coefficients[i] * Math.pow(x, i)
        }
        return result
    }

    // 🔥 新增：加权移动平均（趋势拟合）
    function weightedMovingAverage(xPoints, yPoints, windowSize) {
        if (!windowSize) windowSize = 5

        var smoothX = []
        var smoothY = []

        for (var i = 0; i < xPoints.length; i++) {
            var weightSum = 0
            var valueSum = 0
            var halfWindow = Math.floor(windowSize / 2)

            for (var j = Math.max(0, i - halfWindow); j <= Math.min(xPoints.length - 1, i + halfWindow); j++) {
                // 🔥 使用高斯权重，中心点权重更高
                var distance = Math.abs(i - j)
                var weight = Math.exp(-distance * distance / (2 * (windowSize / 3) * (windowSize / 3)))

                weightSum += weight
                valueSum += yPoints[j] * weight
            }

            smoothX.push(xPoints[i])
            smoothY.push(valueSum / weightSum)
        }

        return { x: smoothX, y: smoothY }
    }

    // 🔥 新增：LOWESS局部回归平滑（最佳选择）
    function lowessSmooth(xPoints, yPoints, alpha) {
        if (!alpha) alpha = 0.3  // 平滑参数，0.1-0.5之间

        var n = xPoints.length
        var smoothX = []
        var smoothY = []
        var bandwidth = Math.max(3, Math.floor(alpha * n))

        for (var i = 0; i < n; i++) {
            // 🔥 计算每个点到当前点的距离
            var distances = []
            for (var j = 0; j < n; j++) {
                distances.push({
                    index: j,
                    distance: Math.abs(xPoints[j] - xPoints[i])
                })
            }

            // 🔥 按距离排序，取最近的points
            distances.sort(function(a, b) { return a.distance - b.distance })
            var nearestPoints = distances.slice(0, bandwidth)

            // 🔥 计算权重并进行加权线性回归
            var maxDistance = nearestPoints[nearestPoints.length - 1].distance
            if (maxDistance === 0) maxDistance = 1

            var sumW = 0, sumWX = 0, sumWY = 0, sumWX2 = 0, sumWXY = 0

            for (var k = 0; k < nearestPoints.length; k++) {
                var idx = nearestPoints[k].index
                var dist = nearestPoints[k].distance

                // 🔥 三次权重函数
                var u = dist / maxDistance
                var weight = u < 1 ? Math.pow(1 - u * u * u, 3) : 0

                sumW += weight
                sumWX += weight * xPoints[idx]
                sumWY += weight * yPoints[idx]
                sumWX2 += weight * xPoints[idx] * xPoints[idx]
                sumWXY += weight * xPoints[idx] * yPoints[idx]
            }

            // 🔥 计算局部线性回归参数
            var denominator = sumW * sumWX2 - sumWX * sumWX
            if (Math.abs(denominator) > 1e-10) {
                var slope = (sumW * sumWXY - sumWX * sumWY) / denominator
                var intercept = (sumWY - slope * sumWX) / sumW
                var smoothedY = slope * xPoints[i] + intercept
            } else {
                var smoothedY = sumWY / sumW  // 退化为加权平均
            }

            smoothX.push(xPoints[i])
            smoothY.push(smoothedY)
        }

        return { x: smoothX, y: smoothY }
    }

    // 初始化：加载数据库曲线
    Component.onCompleted: {
        console.log("=== 性能分析窗口初始化完成 ===")
        console.log("泵数据:", pumpData ? pumpData.model : "无")
        console.log("级数:", stages)
        console.log("频率:", frequency)
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2
        if (pumpData) Qt.callLater(loadCurvesFromDB)
        show()
    }
    Component.onDestruction: { console.log("性能分析窗口销毁") }
}
