// VariableFrequencyChart.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts

Rectangle {
    id: root

    // 外部属性
    property var curvesData: null
    property bool isChineseMode: true
    property bool isMetric: true
    property int stages: 1
    property real currentFrequency: 60
    property bool showEfficiencyLines: true
    property bool showFrequencyLabels: true
    property bool showCurrentFrequencyHighlight: true

    // 🔥 新增：点击信息显示相关属性
    property var clickedPoint: null
    property bool showClickedPointInfo: false

    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "变频性能曲线" : "Variable Frequency Curves"
                font.pixelSize: 16
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: isChineseMode ?
                      `当前频率: ${currentFrequency}Hz` :
                      `Current: ${currentFrequency}Hz`
                font.pixelSize: 12
                color: Material.accentColor
                font.bold: true
            }
        }

        // 图表区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "white"
            border.color: Material.dividerColor
            border.width: 1
            radius: 8

            ChartView {
                id: variableFreqChartView
                anchors.fill: parent
                anchors.margins: 8

                title: isChineseMode ? "多频率性能对比" : "Multi-Frequency Performance"
                titleFont.pixelSize: 14
                titleFont.bold: true
                legend.alignment: Qt.AlignBottom
                legend.font.pixelSize: 9
                legend.visible: true
                antialiasing: true
                theme: ChartView.ChartThemeLight
                backgroundColor: "white"

                // 🔥 坐标轴定义
                ValuesAxis {
                    id: varFlowAxis
                    titleText: isChineseMode ? "流量" : "Flow Rate"
                    min: 0; max: 2000
                    tickCount: 6
                    gridVisible: true
                    labelsFont.pixelSize: 10
                    titleFont.pixelSize: 12
                    color: "#333333"
                    labelFormat: "%.0f"  // 🔥 整数显示
                }

                ValuesAxis {
                    id: varHeadAxis
                    titleText: isChineseMode ? "扬程" : "Head"
                    min: 0; max: 300
                    tickCount: 6
                    gridVisible: true
                    labelsFont.pixelSize: 10
                    titleFont.pixelSize: 12
                    color: "#2196F3"
                    labelFormat: "%.0f"  // 🔥 整数显示
                }

                // 🔥 不同频率的曲线系列
                LineSeries {
                    id: freq30Series
                    name: "30Hz"
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#FF6B6B"
                    width: 2
                    style: Qt.DashLine
                    pointsVisible: false
                }

                LineSeries {
                    id: freq40Series
                    name: "40Hz"
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#4ECDC4"
                    width: 2
                    style: Qt.DashLine
                    pointsVisible: false
                }

                LineSeries {
                    id: freq50Series
                    name: "50Hz"
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#45B7D1"
                    width: 3
                    style: Qt.SolidLine
                    pointsVisible: false
                }

                LineSeries {
                    id: freq60Series
                    name: "60Hz"
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#96CEB4"
                    width: 3
                    style: Qt.SolidLine
                    pointsVisible: false
                }

                LineSeries {
                    id: freq70Series
                    name: "70Hz"
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#FFEAA7"
                    width: 2
                    style: Qt.DotLine
                    pointsVisible: false
                }

                // 🔥 当前频率高亮系列
                LineSeries {
                    id: currentFreqHighlight
                    name: `${currentFrequency}Hz (当前)`
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#E17055"
                    width: 4
                    style: Qt.SolidLine
                    pointsVisible: true
                    visible: showCurrentFrequencyHighlight
                }

                // 🔥 点击点标记
                ScatterSeries {
                    id: clickedPointSeries
                    name: isChineseMode ? "选中点" : "Selected Point"
                    axisX: varFlowAxis
                    axisY: varHeadAxis
                    color: "#E74C3C"
                    markerSize: 16
                    borderColor: "white"
                    borderWidth: 3
                    markerShape: ScatterSeries.MarkerShapeCircle
                    visible: showClickedPointInfo
                }

                // 🔥 新增：鼠标交互区域
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: (mouse) => {
                        var chartPoint = variableFreqChartView.mapToValue(Qt.point(mouse.x, mouse.y), freq50Series)
                        if (chartPoint.x >= 0 && chartPoint.y >= 0 &&
                            chartPoint.x <= varFlowAxis.max && chartPoint.y <= varHeadAxis.max) {

                            console.log("变频图表点击:", chartPoint.x.toFixed(1), chartPoint.y.toFixed(1))
                            handleChartClick(chartPoint.x, chartPoint.y, mouse.x, mouse.y)
                        }
                    }

                    onPositionChanged: (mouse) => {
                        if (containsMouse && !showClickedPointInfo) {  // 只有在没有点击信息时才显示悬停信息
                            var chartPoint = variableFreqChartView.mapToValue(Qt.point(mouse.x, mouse.y), freq50Series)
                            hoverTooltip.visible = true
                            hoverTooltip.updatePosition(mouse.x, mouse.y, chartPoint.x, chartPoint.y)
                        }
                    }

                    onExited: {
                        if (!showClickedPointInfo) {
                            hoverTooltip.visible = false
                        }
                    }
                }

                // 🔥 悬停提示框
                Rectangle {
                    id: hoverTooltip
                    width: 160
                    height: 80
                    color: Qt.rgba(0, 0, 0, 0.85)
                    radius: 6
                    visible: false
                    z: 1000

                    property real flowValue: 0
                    property real headValue: 0

                    function updatePosition(mouseX, mouseY, flow, head) {
                        x = mouseX + 15
                        y = mouseY - height - 15

                        // 边界检查
                        if (x + width > parent.width) x = mouseX - width - 15
                        if (y < 0) y = mouseY + 15

                        flowValue = flow
                        headValue = head
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: isChineseMode ? "悬停信息" : "Hover Info"
                            color: "#FFF"; font.pixelSize: 10; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: `${isChineseMode ? "流量" : "Flow"}: ${hoverTooltip.flowValue.toFixed(1)} ${getFlowUnit()}`
                            color: "white"; font.pixelSize: 9
                        }

                        Text {
                            text: `${isChineseMode ? "扬程" : "Head"}: ${hoverTooltip.headValue.toFixed(1)} ${getHeadUnit()}`
                            color: "white"; font.pixelSize: 9
                        }

                        Text {
                            text: isChineseMode ? "点击查看详情" : "Click for details"
                            color: "#FFD700"; font.pixelSize: 8; font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // 🔥 无数据状态
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
                        width: 32; height: 32
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "正在生成变频曲线..." : "Generating variable frequency curves..."
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                }
            }
        }

        // 🔥 新增：点击信息显示面板
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: showClickedPointInfo ? 120 : 0
            color: Material.dialogColor
            radius: 8
            visible: showClickedPointInfo

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 20
                visible: parent.visible

                // 基本信息
                Column {
                    spacing: 6

                    Text {
                        text: isChineseMode ? "🎯 选中点信息" : "🎯 Selected Point Info"
                        font.pixelSize: 14; font.bold: true
                        color: Material.primaryTextColor
                    }

                    Text {
                        text: clickedPoint ?
                              `${isChineseMode ? "流量" : "Flow"}: ${clickedPoint.flow.toFixed(1)} ${getFlowUnit()}` :
                              `${isChineseMode ? "流量" : "Flow"}: -- ${getFlowUnit()}`
                        font.pixelSize: 12; color: Material.secondaryTextColor
                    }

                    Text {
                        text: clickedPoint ?
                              `${isChineseMode ? "扬程" : "Head"}: ${clickedPoint.head.toFixed(1)} ${getHeadUnit()}` :
                              `${isChineseMode ? "扬程" : "Head"}: -- ${getHeadUnit()}`
                        font.pixelSize: 12; color: Material.secondaryTextColor
                    }
                }

                // 不同频率下的性能
                Column {
                    spacing: 6

                    Text {
                        text: isChineseMode ? "🔧 多频性能" : "🔧 Multi-Frequency Performance"
                        font.pixelSize: 14; font.bold: true
                        color: Material.primaryTextColor
                    }

                    Row {
                        spacing: 15

                        Column {
                            spacing: 2
                            Text { text: "50Hz:"; font.pixelSize: 10; color: "#45B7D1"; font.bold: true }
                            Text {
                                text: clickedPoint && clickedPoint.freq50 ?
                                      `${clickedPoint.freq50.head.toFixed(0)} ${getHeadUnit()}` :
                                      "-- " + getHeadUnit()
                                font.pixelSize: 10; color: Material.secondaryTextColor
                            }
                        }

                        Column {
                            spacing: 2
                            Text { text: "60Hz:"; font.pixelSize: 10; color: "#96CEB4"; font.bold: true }
                            Text {
                                text: clickedPoint && clickedPoint.freq60 ?
                                      `${clickedPoint.freq60.head.toFixed(0)} ${getHeadUnit()}` :
                                      "-- " + getHeadUnit()
                                font.pixelSize: 10; color: Material.secondaryTextColor
                            }
                        }

                        Column {
                            spacing: 2
                            Text { text: "70Hz:"; font.pixelSize: 10; color: "#FFEAA7"; font.bold: true }
                            Text {
                                text: clickedPoint && clickedPoint.freq70 ?
                                      `${clickedPoint.freq70.head.toFixed(0)} ${getHeadUnit()}` :
                                      "-- " + getHeadUnit()
                                font.pixelSize: 10; color: Material.secondaryTextColor
                            }
                        }
                    }
                }

                // 效率信息
                Column {
                    spacing: 6

                    Text {
                        text: isChineseMode ? "📊 效率信息" : "📊 Efficiency Info"
                        font.pixelSize: 14; font.bold: true
                        color: Material.primaryTextColor
                    }

                    Text {
                        text: clickedPoint ?
                              `${isChineseMode ? "估算效率" : "Est. Efficiency"}: ${clickedPoint.efficiency.toFixed(1)}%` :
                              `${isChineseMode ? "效率" : "Efficiency"}: --%`
                        font.pixelSize: 12; color: Material.secondaryTextColor
                    }

                    Text {
                        text: clickedPoint ?
                              `${isChineseMode ? "级数" : "Stages"}: ${stages}` :
                              `${isChineseMode ? "级数" : "Stages"}: --`
                        font.pixelSize: 12; color: Material.secondaryTextColor
                    }
                }

                Item { Layout.fillWidth: true }

                // 操作按钮
                Column {
                    spacing: 8

                    Button {
                        text: isChineseMode ? "设为工况点" : "Set Operating Point"
                        font.pixelSize: 10
                        implicitHeight: 28
                        enabled: clickedPoint !== null
                        Material.background: Material.accent

                        onClicked: {
                            if (clickedPoint) {
                                console.log("设置变频图表工况点:", clickedPoint.flow, clickedPoint.head)
                                // 🔥 向父组件发射信号
                                if (root.parent && typeof root.parent.operatingPointChanged === "function") {
                                    root.parent.operatingPointChanged(clickedPoint.flow, clickedPoint.head)
                                }
                            }
                        }
                    }

                    Button {
                        text: "✕"
                        font.pixelSize: 12
                        implicitHeight: 28
                        implicitWidth: 28
                        flat: true

                        onClicked: {
                            clearClickedPoint()
                        }
                    }
                }
            }
        }
    }

    // ====== 🔥 新增：点击处理函数 ======
    function handleChartClick(flow, head, mouseX, mouseY) {
        console.log("处理变频图表点击:", flow.toFixed(1), head.toFixed(1))

        // 🔥 计算该点在不同频率下的性能
        var pointInfo = {
            flow: flow,
            head: head,
            efficiency: interpolateEfficiencyAtPoint(flow),
            freq30: calculateFrequencyPoint(flow, head, 30),
            freq40: calculateFrequencyPoint(flow, head, 40),
            freq50: calculateFrequencyPoint(flow, head, 50),
            freq60: calculateFrequencyPoint(flow, head, 60),
            freq70: calculateFrequencyPoint(flow, head, 70),
            clickPosition: {x: mouseX, y: mouseY}
        }

        clickedPoint = pointInfo
        showClickedPointInfo = true

        // 🔥 在图表上标记点击位置
        clickedPointSeries.clear()
        clickedPointSeries.append(flow, head)

        // 隐藏悬停提示
        hoverTooltip.visible = false
    }

    function clearClickedPoint() {
        clickedPoint = null
        showClickedPointInfo = false
        clickedPointSeries.clear()
    }

    // ====== 🔥 新增：频率计算函数 ======
    function calculateFrequencyPoint(baseFlow, baseHead, targetFreq) {
        // 假设基础频率为50Hz，根据相似定律计算其他频率下的性能
        var baseFreq = 50
        var freqRatio = targetFreq / baseFreq

        return {
            flow: baseFlow * freqRatio,
            head: baseHead * freqRatio * freqRatio,
            power: 0 * freqRatio * freqRatio * freqRatio  // 功率与频率立方成正比
        }
    }

    function interpolateEfficiencyAtPoint(flow) {
        // 简化的效率计算，实际应该基于真实的效率曲线数据
        if (!curvesData || !curvesData.baseCurves) return 75

        // 这里可以插值计算实际效率
        return 78  // 临时返回固定值
    }

    // ====== 🔥 辅助函数 ======
    function getFlowUnit() {
        return isMetric ? "m³/d" : "bbl/d"
    }

    function getHeadUnit() {
        return isMetric ? "m" : "ft"
    }

    function getPowerUnit() {
        return isMetric ? "kW" : "HP"
    }

    // ====== 🔥 数据更新函数 ======
    function updateVariableFreqData() {
        if (!curvesData || !curvesData.baseCurves) {
            console.log("变频图表：没有基础曲线数据")
            return
        }

        console.log("更新变频图表数据")

        // 生成不同频率下的曲线
        generateFrequencyCurves([30, 40, 50, 60, 70])

        // 更新当前频率高亮
        updateCurrentFrequencyHighlight()

        console.log("变频图表数据更新完成")
    }

    // 🔥 在现有的 generateFrequencyCurves 函数中替换计算逻辑：
    function generateFrequencyCurves(frequencies) {
        var seriesMap = {
            30: freq30Series,
            40: freq40Series,
            50: freq50Series,
            60: freq60Series,
            70: freq70Series
        }

        var baseCurves = curvesData.baseCurves
        console.log(`🔄 生成变频曲线，级数: ${stages}`)

        frequencies.forEach(function(freq) {
            var series = seriesMap[freq]
            if (!series) return

            series.clear()

            for (var i = 0; i < baseCurves.flow.length; i++) {
                var baseFlow = baseCurves.flow[i]
                var baseHead = baseCurves.head[i]

                if (!isNaN(baseFlow) && !isNaN(baseHead)) {
                    // 🔥 使用修复后的转换函数
                    var displayFlow = toDisplayFlow(baseFlow, freq)
                    var displayHead = toDisplayHead(baseHead, freq)  // 现在包含级数影响

                    series.append(displayFlow, displayHead)
                }
            }

            console.log(`${freq}Hz曲线生成完成：${series.count}个点，级数=${stages}`)
        })

        updateAxisRanges()
    }

    function updateCurrentFrequencyHighlight() {
        if (!showCurrentFrequencyHighlight) {
            currentFreqHighlight.visible = false
            return
        }

        // 找到对应的系列并复制其数据
        var sourceSeriesMap = {
            30: freq30Series,
            40: freq40Series,
            50: freq50Series,
            60: freq60Series,
            70: freq70Series
        }

        var sourceSeries = sourceSeriesMap[currentFrequency]
        if (!sourceSeries) {
            currentFreqHighlight.visible = false
            return
        }

        currentFreqHighlight.clear()
        currentFreqHighlight.name = `${currentFrequency}Hz (${isChineseMode ? "当前" : "Current"})`

        // 复制数据点
        for (var i = 0; i < sourceSeries.count; i++) {
            var point = sourceSeries.at(i)
            currentFreqHighlight.append(point.x, point.y)
        }

        currentFreqHighlight.visible = true
        console.log(`当前频率${currentFrequency}Hz高亮更新完成`)
    }

    function updateAxisRanges() {
        // 收集所有系列的数据范围
        var allSeries = [freq30Series, freq40Series, freq50Series, freq60Series, freq70Series]
        var minFlow = Number.MAX_VALUE, maxFlow = Number.MIN_VALUE
        var minHead = Number.MAX_VALUE, maxHead = Number.MIN_VALUE

        allSeries.forEach(function(series) {
            if (series.count === 0) return

            for (var i = 0; i < series.count; i++) {
                var point = series.at(i)
                minFlow = Math.min(minFlow, point.x)
                maxFlow = Math.max(maxFlow, point.x)
                minHead = Math.min(minHead, point.y)
                maxHead = Math.max(maxHead, point.y)
            }
        })

        if (minFlow !== Number.MAX_VALUE) {
            varFlowAxis.min = Math.floor(Math.max(0, minFlow * 0.9))
            varFlowAxis.max = Math.ceil(maxFlow * 1.1)
            varHeadAxis.min = Math.floor(Math.max(0, minHead * 0.9))
            varHeadAxis.max = Math.ceil(maxHead * 1.1)

            console.log(`变频图表坐标轴更新: 流量[${varFlowAxis.min}, ${varFlowAxis.max}], 扬程[${varHeadAxis.min}, ${varHeadAxis.max}]`)
        }
    }

    // ====== 🔥 修复：添加与级数联动的转换函数 ======
    function toDisplayFlow(valueM3d, targetFreq) {
        var frequencyFactor = targetFreq / 50
        var adjustedFlow = valueM3d * frequencyFactor
        var finalFlow = isMetric ? adjustedFlow : adjustedFlow * 6.2898
        return finalFlow
    }

    function toDisplayHead(valueM, targetFreq) {
        var frequencyFactor = Math.pow(targetFreq / 50, 2)
        var adjustedHead = valueM * frequencyFactor * stages  // 🔥 关键：乘以级数
        var finalHead = isMetric ? adjustedHead : adjustedHead * 3.2808
        return finalHead
    }

    // 🔥 添加轴标题更新函数
    function updateAxisTitles() {
        var flowUnit = getFlowUnit()
        var headUnit = getHeadUnit()

        varFlowAxis.titleText = isChineseMode ?
            `流量 (${flowUnit})` :
            `Flow Rate (${flowUnit})`

        varHeadAxis.titleText = isChineseMode ?
            `扬程 @ ${stages}级 (${headUnit})` :
            `Head @ ${stages} stages (${headUnit})`
    }

    // 🔥 修复级数变化监听
    onStagesChanged: {
        console.log("🔄 变频图表级数变化:", stages)
        updateAxisTitles()
        if (curvesData) {
            Qt.callLater(updateVariableFreqData)
        }
    }

    // 🔥 初始化轴标题
    Component.onCompleted: {
        updateAxisTitles()
    }


    // ====== 监听数据变化 ======
    onCurvesDataChanged: {
        if (curvesData) {
            console.log("变频图表接收到新数据")
            Qt.callLater(updateVariableFreqData)
        }
    }

    onCurrentFrequencyChanged: {
        console.log("变频图表当前频率变化:", currentFrequency)
        Qt.callLater(updateCurrentFrequencyHighlight)
    }

    // onStagesChanged: {
    //     console.log("变频图表级数变化:", stages)
    //     if (curvesData) {
    //         Qt.callLater(updateVariableFreqData)
    //     }
    // }
}
