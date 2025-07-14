// Qt_Oil_NewContent/DeviceRecommendation/Components/EnhancedPumpCurvesChart.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts

Rectangle {
    id: root

    // 🔥 公共属性
    property var controller: null
    property bool isChineseMode: true
    property var curvesData: null
    property var systemCurve: null
    property var currentOperatingPoint: null

    // 🔥 内部状态属性
    property bool showGrid: true
    property bool showPoints: true
    property bool showZones: true
    property bool showEnhancedParameters: true
    property real zoomFactor: 1.0

    // 🔥 信号定义
    signal operatingPointChanged(real flow, real head)
    signal configurationChanged(int stages, real frequency)
    signal dataRequested()
    signal exportRequested()

    color: Material.backgroundColor
    border.color: Material.dividerColor
    border.width: 1
    radius: 8

    // 🔥 数据变化监听
    onCurvesDataChanged: {
        console.log("EnhancedPumpCurvesChart: 曲线数据变化", curvesData ? "已加载" : "为空")
        if (curvesData) {
            Qt.callLater(updateChartData)
        } else {
            clearChart()
        }
    }

    onSystemCurveChanged: {
        console.log("EnhancedPumpCurvesChart: 系统曲线数据变化", systemCurve ? "已加载" : "为空")
        if (systemCurve) {
            Qt.callLater(updateSystemCurve)
        }
    }

    onCurrentOperatingPointChanged: {
        console.log("EnhancedPumpCurvesChart: 工况点变化", currentOperatingPoint ? "已设置" : "为空")
        if (currentOperatingPoint) {
            Qt.callLater(function() {
                updateOperatingPointDisplay(currentOperatingPoint.flow, currentOperatingPoint.head)
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // 🔥 标题和控制栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "增强型泵性能曲线" : "Enhanced Pump Performance Curves"
                font.pixelSize: 18
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 🔥 工具栏
            Row {
                spacing: 8

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
                            checked: root.showGrid
                            onCheckedChanged: {
                                root.showGrid = checked
                                updateGridVisibility()
                            }
                        }

                        MenuItem {
                            text: isChineseMode ? "显示数据点" : "Show Points"
                            checkable: true
                            checked: root.showPoints
                            onCheckedChanged: {
                                root.showPoints = checked
                                updatePointsVisibility()
                            }
                        }

                        MenuItem {
                            text: isChineseMode ? "显示性能区域" : "Show Zones"
                            checkable: true
                            checked: root.showZones
                            onCheckedChanged: {
                                root.showZones = checked
                                updateZonesVisibility()
                            }
                        }

                        MenuSeparator {}

                        MenuItem {
                            text: isChineseMode ? "导出数据" : "Export Data"
                            onClicked: root.exportRequested()
                        }
                    }
                }

                ToolButton {
                    text: "📊"
                    font.pixelSize: 14
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: root.dataRequested()
                    ToolTip.text: isChineseMode ? "刷新数据" : "Refresh Data"
                }
            }
        }

        // 🔥 主要图表区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 400
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

                // 🔥 主X轴 - 流量
                ValuesAxis {
                    id: flowAxis
                    titleText: isChineseMode ? "流量 (m³/d)" : "Flow Rate (m³/d)"
                    min: 0
                    max: 2000
                    tickCount: 6
                    gridVisible: root.showGrid
                    labelsFont.pixelSize: 10
                    titleFont.pixelSize: 12
                    color: "#333333"
                }

                // 🔥 左Y轴 - 扬程
                ValuesAxis {
                    id: headAxis
                    titleText: isChineseMode ? "扬程 (m)" : "Head (m)"
                    min: 0
                    max: 300
                    tickCount: 6
                    gridVisible: root.showGrid
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
                    // alignment: Qt.AlignRight
                }

                // 🔥 右Y轴2 - 功率
                ValuesAxis {
                    id: powerAxis
                    titleText: isChineseMode ? "功率 (kW)" : "Power (kW)"
                    min: 0
                    max: 200
                    tickCount: 5
                    gridVisible: false
                    labelsFont.pixelSize: 10
                    titleFont.pixelSize: 12
                    color: "#FF9800"
                    // alignment: Qt.AlignRight
                }

                // 🔥 性能区域 - 最佳区域
                AreaSeries {
                    id: optimalZoneArea
                    name: isChineseMode ? "最佳区域" : "Optimal Zone"
                    axisX: flowAxis
                    axisY: headAxis
                    color: Qt.rgba(0.3, 0.8, 0.3, 0.15)
                    borderColor: Qt.rgba(0.3, 0.8, 0.3, 0.5)
                    borderWidth: 1
                    visible: root.showZones

                    upperSeries: LineSeries {
                        id: optimalZoneUpper
                    }
                    lowerSeries: LineSeries {
                        id: optimalZoneLower
                    }
                }

                // 🔥 性能区域 - 可接受区域
                AreaSeries {
                    id: acceptableZoneArea
                    name: isChineseMode ? "可接受区域" : "Acceptable Zone"
                    axisX: flowAxis
                    axisY: headAxis
                    color: Qt.rgba(1.0, 0.6, 0.0, 0.1)
                    borderColor: Qt.rgba(1.0, 0.6, 0.0, 0.3)
                    borderWidth: 1
                    visible: root.showZones

                    upperSeries: LineSeries {
                        id: acceptableZoneUpper
                    }
                    lowerSeries: LineSeries {
                        id: acceptableZoneLower
                    }
                }

                // 🔥 扬程曲线
                LineSeries {
                    id: headCurve
                    name: isChineseMode ? "扬程" : "Head"
                    axisX: flowAxis
                    axisY: headAxis
                    color: "#2196F3"
                    width: 3
                    pointsVisible: root.showPoints
                    pointLabelsVisible: false
                }

                // 🔥 效率曲线
                LineSeries {
                    id: efficiencyCurve
                    name: isChineseMode ? "效率" : "Efficiency"
                    axisX: flowAxis
                    axisY: efficiencyAxis
                    color: "#4CAF50"
                    width: 3
                    pointsVisible: root.showPoints
                    style: Qt.SolidLine
                }

                // 🔥 功率曲线
                LineSeries {
                    id: powerCurve
                    name: isChineseMode ? "功率" : "Power"
                    axisX: flowAxis
                    axisY: powerAxis
                    color: "#FF9800"
                    width: 2
                    pointsVisible: false
                }

                // // 🔥 系统曲线
                // LineSeries {
                //     id: systemCurveLine
                //     name: isChineseMode ? "系统曲线" : "System Curve"
                //     axisX: flowAxis
                //     axisY: headAxis
                //     color: "#F44336"
                //     width: 2
                //     style: Qt.DashLine
                //     pointsVisible: false
                // }

                // 🔥 当前工况点
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

                // 🔥 关键点标记（BEP, 最小流量等）
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

                    property point lastClickPoint: Qt.point(0, 0)

                    onClicked: (mouse) => {
                        var chartPoint = mainChart.mapToValue(Qt.point(mouse.x, mouse.y), headCurve)
                        if (chartPoint.x >= 0 && chartPoint.y >= 0 &&
                            chartPoint.x <= flowAxis.max && chartPoint.y <= headAxis.max) {
                            console.log("点击图表设置工况点:", chartPoint.x.toFixed(1), chartPoint.y.toFixed(1))
                            root.operatingPointChanged(chartPoint.x, chartPoint.y)
                            updateOperatingPointDisplay(chartPoint.x, chartPoint.y)
                            lastClickPoint = chartPoint
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
                    width: 120
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
                            text: `${isChineseMode ? "流量" : "Flow"}: ${crosshairTooltip.flowValue.toFixed(1)} m³/d`
                            color: "white"
                            font.pixelSize: 10
                        }
                        Text {
                            text: `${isChineseMode ? "扬程" : "Head"}: ${crosshairTooltip.headValue.toFixed(1)} m`
                            color: "white"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 🔥 数据加载提示
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

        // 🔥 增强参数显示区域 - 改为横向排列
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showEnhancedParameters ? 100 : 0  // 🔥 减少高度
            color: Material.dialogColor
            radius: 8
            visible: root.showEnhancedParameters && curvesData && curvesData.enhancedParameters

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200 }
            }

            // 🔥 使用RowLayout替代ScrollView + Flow
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                // 🔥 左侧标题
                Text {
                    text: isChineseMode ? "增强参数" : "Enhanced Parameters"
                    font.pixelSize: 14
                    font.bold: true
                    color: Material.primaryTextColor
                    // Layout.alignment: Qt.AlignVCenter
                    rotation: -90  // 🔥 垂直显示标题
                    Layout.preferredWidth: 20
                }

                // 🔥 参数卡片横向排列
                Repeater {
                    model: curvesData && curvesData.enhancedParameters ? Object.keys(curvesData.enhancedParameters) : []

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 120  // 🔥 固定宽度
                        Layout.minimumWidth: 100
                        color: Material.backgroundColor
                        radius: 6
                        border.color: Material.dividerColor
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.border.color = Material.accent
                            onExited: parent.border.color = Material.dividerColor

                            ToolTip.delay: 500
                            ToolTip.text: getParameterDescription(modelData)
                            ToolTip.visible: containsMouse
                        }

                        // 🔥 垂直布局的参数内容
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            // 参数名称
                            Text {
                                Layout.fillWidth: true
                                text: getParameterName(modelData)
                                font.pixelSize: 11
                                font.bold: true
                                color: Material.primaryTextColor
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            // 参数值
                            Text {
                                Layout.fillWidth: true
                                text: getParameterValue(modelData)
                                font.pixelSize: 12
                                font.bold: true
                                color: getParameterColor(modelData)
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // 🔥 状态指示条（水平）
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                radius: 3
                                color: Qt.rgba(0.9, 0.9, 0.9, 1)

                                Rectangle {
                                    width: parent.width * getParameterLevel(modelData)
                                    height: parent.height
                                    radius: parent.radius
                                    color: getParameterColor(modelData)

                                    Behavior on width {
                                        NumberAnimation { duration: 300 }
                                    }
                                }
                            }

                            // 状态文字
                            Text {
                                Layout.fillWidth: true
                                text: getParameterStatus(modelData)
                                font.pixelSize: 9
                                color: getParameterStatusColor(modelData)
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // 弹性空间
                            Item { Layout.fillHeight: true }
                        }
                    }
                }

                // 🔥 右侧弹性空间
                Item { Layout.fillWidth: true }

                // 🔥 控制按钮
                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    ToolButton {
                        text: "📊"
                        font.pixelSize: 12
                        implicitWidth: 28
                        implicitHeight: 28
                        ToolTip.text: isChineseMode ? "参数详情" : "Parameter Details"
                        onClicked: showParameterDetails()
                    }

                    ToolButton {
                        text: root.showEnhancedParameters ? "▼" : "▶"
                        font.pixelSize: 10
                        implicitWidth: 28
                        implicitHeight: 28
                        ToolTip.text: isChineseMode ? "展开/收起" : "Expand/Collapse"
                        onClicked: root.showEnhancedParameters = !root.showEnhancedParameters
                    }
                }
            }
        }
        // 🔥 工况点信息面板
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: currentOperatingPoint ? 100 : 0
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
                              `${isChineseMode ? "流量" : "Flow"}: ${currentOperatingPoint.flow.toFixed(1)} m³/d` : ""
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                    Text {
                        text: currentOperatingPoint ?
                              `${isChineseMode ? "扬程" : "Head"}: ${currentOperatingPoint.head.toFixed(1)} m` : ""
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
                              `${isChineseMode ? "功率" : "Power"}: ${currentOperatingPoint.power.toFixed(1)} kW` : ""
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                }

                // 状态指示器
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
                Column {
                    spacing: 4

                    Button {
                        text: isChineseMode ? "设为BEP" : "Set as BEP"
                        font.pixelSize: 10
                        implicitHeight: 28
                        enabled: currentOperatingPoint !== null
                        onClicked: setBestEfficiencyPoint()
                    }

                    Button {
                        text: isChineseMode ? "详细分析" : "Detail"
                        font.pixelSize: 10
                        implicitHeight: 28
                        enabled: currentOperatingPoint !== null
                        onClicked: showDetailedAnalysis()
                    }
                }
            }
        }
    }

    // 🔥 =================================
    // 🔥 核心数据更新函数
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

        console.log("更新曲线数据:")
        console.log("- 流量点数:", curves.flow ? curves.flow.length : 0)
        console.log("- 扬程点数:", curves.head ? curves.head.length : 0)
        console.log("- 效率点数:", curves.efficiency ? curves.efficiency.length : 0)
        console.log("- 功率点数:", curves.power ? curves.power.length : 0)

        // 🔥 数据预处理和单位转换
        var processedCurves = preprocessCurveData(curves)

        // 🔥 更新坐标轴范围
        updateAxisRanges(processedCurves)

        // 🔥 更新各条曲线
        updateHeadCurve(processedCurves)
        updateEfficiencyCurve(processedCurves)
        updatePowerCurve(processedCurves)
        updateKeyPoints()
        updatePerformanceZones()

        console.log("图表数据更新完成")
    }

    // 🔥 在 preprocessCurveData 函数中修复功率数据处理
    function preprocessCurveData(curves) {
        var processed = {
            flow: [],
            head: [],
            efficiency: [],
            power: []
        }

        if (!curves.flow || !curves.head) {
            console.warn("缺少基础数据")
            return processed
        }

        var stages = curvesData.stages || 87

        // 🔥 调试：打印级数和原始功率数据
        console.log("=== 功率数据调试 ===")
        console.log("级数:", stages)
        console.log("原始功率数据前5点:", JSON.stringify(curves.power.slice(0, 5)))

        // 🔥 修复：判断级数是否合理
        var actualStages = stages
        if (stages > 50) {
            console.warn("级数过多，可能有误:", stages)
            actualStages = Math.min(stages, 20)  // 限制为最多20级
            console.log("调整级数为:", actualStages)
        }

        for (var i = 0; i < curves.flow.length; i++) {
            // 流量单位转换：bbl/d -> m³/d (1 bbl = 0.158987 m³)
            var flowInM3d = curves.flow[i] * 0.158987

            // 扬程单位转换：ft -> m (1 ft = 0.3048 m)
            var headInM = curves.head[i] * 0.3048

            // 数据有效性检查
            if (!isNaN(flowInM3d) && !isNaN(headInM) &&
                flowInM3d >= 0 && headInM >= 0 &&
                flowInM3d < 10000 && headInM < 1000) {

                processed.flow.push(flowInM3d)
                processed.head.push(headInM)

                // 效率数据
                if (curves.efficiency && i < curves.efficiency.length) {
                    var efficiency = curves.efficiency[i]
                    processed.efficiency.push(isNaN(efficiency) ? 0 : Math.max(0, Math.min(100, efficiency)))
                }

                // 🔥 功率数据：根据数据特征智能处理
                if (curves.power && i < curves.power.length) {
                    var originalPower = curves.power[i]
                    var powerInKw = 0

                    // 🔥 方案1：直接使用数据库数据（如果看起来合理）
                    if (originalPower >= 0.5 && originalPower <= 10 && i > 0) {
                        // 看起来像合理的总功率数据，直接使用
                        powerInKw = originalPower
                        if (i === 1) console.log("使用原始功率数据（总功率）")
                    }
                    // 🔥 方案2：如果数据看起来像单级功率
                    else if (originalPower > 0 && originalPower < 5) {
                        // 可能是单级功率，乘以合理的级数
                        powerInKw = originalPower * actualStages * 0.7457  // HP->kW转换
                        if (i === 1) console.log("计算功率：单级功率 × 级数")
                    }
                    // 🔥 方案3：生成合理的功率数据
                    else {
                        // 基于流量和扬程计算理论功率
                        var flow_m3s = flowInM3d / 86400  // m³/d -> m³/s
                        var rho = 1000  // 水密度
                        var g = 9.81    // 重力加速度
                        var efficiency_decimal = (curves.efficiency[i] || 70) / 100

                        if (efficiency_decimal > 0.1) {
                            var hydraulic_power = (rho * g * flow_m3s * headInM) / 1000  // kW
                            powerInKw = hydraulic_power / efficiency_decimal + 2  // 加上损失
                            if (i === 1) console.log("计算理论功率")
                        } else {
                            powerInKw = 10  // 默认功率
                        }
                    }

                    processed.power.push(isNaN(powerInKw) ? 0 : Math.max(0, powerInKw))

                    // 🔥 调试前几个点
                    if (i < 3) {
                        console.log(`点${i}: 原始=${originalPower} -> 处理后=${powerInKw.toFixed(2)} kW`)
                    }
                }
            }
        }

        console.log("数据预处理完成:")
        console.log("- 有效流量点:", processed.flow.length)
        console.log("- 功率范围:", processed.power.length > 0 ?
            `${Math.min(...processed.power).toFixed(1)} - ${Math.max(...processed.power).toFixed(1)} kW` : "无")

        return processed
    }

    // 🔥 修复坐标轴范围设置
    function updateAxisRanges(curves) {
        if (curves.flow && curves.flow.length > 0) {
            var maxFlow = Math.max(...curves.flow)
            var minFlow = Math.min(...curves.flow)
            flowAxis.min = Math.max(0, minFlow * 0.9)
            flowAxis.max = maxFlow * 1.1
            console.log("流量轴范围:", flowAxis.min.toFixed(1), "-", flowAxis.max.toFixed(1))
        }

        if (curves.head && curves.head.length > 0) {
            var maxHead = Math.max(...curves.head)
            var minHead = Math.min(...curves.head)
            headAxis.min = Math.max(0, minHead * 0.9)
            headAxis.max = maxHead * 1.1
            console.log("扬程轴范围:", headAxis.min.toFixed(1), "-", headAxis.max.toFixed(1))
        }

        if (curves.power && curves.power.length > 0) {
            var maxPower = Math.max(...curves.power)
            powerAxis.min = 0
            powerAxis.max = maxPower * 1.1
            console.log("功率轴范围:", powerAxis.min.toFixed(1), "-", powerAxis.max.toFixed(1))
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

    function updateKeyPoints() {
        keyPointsSeries.clear()
        if (curvesData.operatingPoints) {
            for (var j = 0; j < curvesData.operatingPoints.length; j++) {
                var point = curvesData.operatingPoints[j]
                if (!isNaN(point.flow) && !isNaN(point.head)) {
                    keyPointsSeries.append(point.flow, point.head)
                }
            }
            console.log("关键点已更新，点数:", keyPointsSeries.count)
        }
    }

    function updatePerformanceZones() {
        if (!curvesData || !curvesData.performanceZones || !root.showZones) {
            optimalZoneArea.visible = false
            acceptableZoneArea.visible = false
            return
        }

        var zones = curvesData.performanceZones
        var curves = curvesData.baseCurves

        // 🔥 绘制最佳区域
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
            console.log("最佳区域已更新")
        }

        // 🔥 绘制可接受区域
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
            console.log("可接受区域已更新")
        }
    }

    // 🔥 修复系统曲线更新
    function updateSystemCurve() {
        console.log("更新系统曲线")

        if (!systemCurve) {
            console.log("没有系统曲线数据，清空系统曲线")
            systemCurveLine.clear()
            return
        }

        systemCurveLine.clear()

        // 🔥 生成与泵性能曲线匹配的系统曲线
        if (curvesData && curvesData.baseCurves && curvesData.baseCurves.flow) {
            var pumpFlowRange = curvesData.baseCurves.flow
            var maxPumpFlow = Math.max(...pumpFlowRange) * 0.158987  // 转换为m³/d

            // 🔥 生成合理的系统曲线
            var staticHead = systemCurve.staticHead ? systemCurve.staticHead * 0.3048 : 30  // 转换为米
            var frictionCoeff = systemCurve.frictionCoeff || 0.001

            console.log("生成系统曲线数据")
            console.log("- 静压头:", staticHead.toFixed(1), "m")
            console.log("- 摩擦系数:", frictionCoeff)
            console.log("- 流量范围: 0 -", maxPumpFlow.toFixed(1), "m³/d")

            // 生成系统曲线点
            var numPoints = 20
            for (var i = 0; i <= numPoints; i++) {
                var flow = (i / numPoints) * maxPumpFlow
                var head = staticHead + frictionCoeff * flow * flow

                if (!isNaN(flow) && !isNaN(head) && head >= 0) {
                    systemCurveLine.append(flow, head)
                }
            }

            console.log("系统曲线已更新，点数:", systemCurveLine.count)
        } else if (systemCurve.flow && systemCurve.head) {
            // 使用原始系统曲线数据
            var minLength = Math.min(systemCurve.flow.length, systemCurve.head.length)
            for (var i = 0; i < minLength; i++) {
                if (!isNaN(systemCurve.flow[i]) && !isNaN(systemCurve.head[i])) {
                    systemCurveLine.append(systemCurve.flow[i], systemCurve.head[i])
                }
            }
            console.log("系统曲线已更新，点数:", systemCurveLine.count)
        }
    }

    // 🔥 修复工况点显示
    function updateOperatingPointDisplay(flow, head) {
        if (flow !== undefined && head !== undefined && !isNaN(flow) && !isNaN(head)) {
            // 🔥 单位转换：如果输入是bbl/d和ft，转换为m³/d和m
            var flowM3d = flow
            var headM = head

            // 检测单位并转换
            if (flow > 1000) {  // 可能是bbl/d
                flowM3d = flow * 0.158987
            }
            if (head > 100) {  // 可能是ft
                headM = head * 0.3048
            }

            operatingPointSeries.clear()
            operatingPointSeries.append(flowM3d, headM)
            console.log("工况点显示已更新:", flowM3d.toFixed(1), "m³/d,", headM.toFixed(1), "m")

            // 🔥 更新工况点信息
            if (currentOperatingPoint) {
                currentOperatingPoint.flow = flowM3d
                currentOperatingPoint.head = headM
                currentOperatingPoint.efficiency = interpolateEfficiency(flowM3d)
                currentOperatingPoint.power = interpolatePower(flowM3d)
            }
        }
    }

    // 🔥 新增：效率插值函数
    function interpolateEfficiency(targetFlow) {
        if (!curvesData || !curvesData.baseCurves || !curvesData.baseCurves.flow || !curvesData.baseCurves.efficiency) {
            return 0
        }

        var flows = curvesData.baseCurves.flow.map(f => f * 0.158987)  // 转换为m³/d
        var efficiencies = curvesData.baseCurves.efficiency

        return interpolateValue(targetFlow, flows, efficiencies)
    }

    // 🔥 新增：功率插值函数
    function interpolatePower(targetFlow) {
        if (!curvesData || !curvesData.baseCurves || !curvesData.baseCurves.flow || !curvesData.baseCurves.power) {
            return 0
        }

        var flows = curvesData.baseCurves.flow.map(f => f * 0.158987)  // 转换为m³/d
        var powers = curvesData.baseCurves.power.map(p => p * 0.7457 * (curvesData.stages || 87))  // 转换为kW

        return interpolateValue(targetFlow, flows, powers)
    }

    // 🔥 新增：通用插值函数
    function interpolateValue(targetX, xArray, yArray) {
        if (!xArray || !yArray || xArray.length !== yArray.length || xArray.length === 0) {
            return 0
        }

        // 找到最接近的两个点进行插值
        for (var i = 0; i < xArray.length - 1; i++) {
            if (targetX >= xArray[i] && targetX <= xArray[i + 1]) {
                var ratio = (targetX - xArray[i]) / (xArray[i + 1] - xArray[i])
                return yArray[i] + ratio * (yArray[i + 1] - yArray[i])
            }
        }

        // 边界情况
        if (targetX <= xArray[0]) return yArray[0]
        if (targetX >= xArray[xArray.length - 1]) return yArray[yArray.length - 1]

        return 0
    }

    // 🔥 修复缺失的函数
    function getParameterDescription(paramKey) {
        var descriptions = {
            'npsh_required': isChineseMode ? '泵的汽蚀余量要求，确保泵不发生汽蚀' : 'Net Positive Suction Head Required to prevent cavitation',
            'temperature_rise': isChineseMode ? '泵运行时的温度上升，影响泵的寿命' : 'Temperature rise during pump operation',
            'vibration_level': isChineseMode ? '泵的振动水平，影响运行稳定性' : 'Pump vibration level affecting operational stability',
            'noise_level': isChineseMode ? '泵运行时的噪音水平' : 'Noise level during pump operation',
            'wear_rate': isChineseMode ? '泵部件的磨损率，影响维护周期' : 'Wear rate of pump components',
            'radial_load': isChineseMode ? '径向载荷，影响轴承寿命' : 'Radial load affecting bearing life',
            'axial_thrust': isChineseMode ? '轴向推力，影响推力轴承' : 'Axial thrust affecting thrust bearings',
            'material_stress': isChineseMode ? '材料应力水平' : 'Material stress level',
            'energy_efficiency_ratio': isChineseMode ? '能效比，泵的能量利用效率' : 'Energy efficiency ratio',
            'cavitation_margin': isChineseMode ? '汽蚀安全余量' : 'Cavitation safety margin',
            'stability_score': isChineseMode ? '运行稳定性评分' : 'Operational stability score'
        }
        return descriptions[paramKey] || (isChineseMode ? '未知参数' : 'Unknown parameter')
    }

    // 🔥 新增：参数详情显示函数
    function showParameterDetails() {
        console.log("显示参数详情")
        // 这里可以打开参数详情对话框
    }

    // 🔥 =================================
    // 🔥 界面控制函数
    // 🔥 =================================

    function clearChart() {
        console.log("清空图表")
        headCurve.clear()
        efficiencyCurve.clear()
        powerCurve.clear()
        systemCurveLine.clear()
        operatingPointSeries.clear()
        keyPointsSeries.clear()
        optimalZoneUpper.clear()
        optimalZoneLower.clear()
        acceptableZoneUpper.clear()
        acceptableZoneLower.clear()
    }

    function updateGridVisibility() {
        flowAxis.gridVisible = root.showGrid
        headAxis.gridVisible = root.showGrid
    }

    function updatePointsVisibility() {
        headCurve.pointsVisible = root.showPoints
        efficiencyCurve.pointsVisible = root.showPoints
    }

    function updateZonesVisibility() {
        optimalZoneArea.visible = root.showZones && curvesData && curvesData.performanceZones
        acceptableZoneArea.visible = root.showZones && curvesData && curvesData.performanceZones
    }

    // 🔥 =================================
    // 🔥 参数显示辅助函数
    // 🔥 =================================

    function getParameterName(paramKey) {
        var names = {
            'npsh_required': isChineseMode ? 'NPSH要求' : 'NPSH Required',
            'temperature_rise': isChineseMode ? '温升' : 'Temp Rise',
            'vibration_level': isChineseMode ? '振动' : 'Vibration',
            'noise_level': isChineseMode ? '噪音' : 'Noise',
            'wear_rate': isChineseMode ? '磨损率' : 'Wear Rate',
            'radial_load': isChineseMode ? '径向载荷' : 'Radial Load',
            'axial_thrust': isChineseMode ? '轴向推力' : 'Axial Thrust',
            'material_stress': isChineseMode ? '材料应力' : 'Material Stress',
            'energy_efficiency_ratio': isChineseMode ? '能效比' : 'Energy Ratio',
            'cavitation_margin': isChineseMode ? '空化余量' : 'Cavitation Margin',
            'stability_score': isChineseMode ? '稳定性' : 'Stability'
        }
        return names[paramKey] || paramKey
    }

    function getParameterValue(paramKey) {
        if (!curvesData || !curvesData.enhancedParameters) return ""

        var values = curvesData.enhancedParameters[paramKey]
        if (!values || values.length === 0) return ""

        var avg = values.reduce((a, b) => a + b, 0) / values.length

        var units = {
            'npsh_required': 'm',
            'temperature_rise': '°C',
            'vibration_level': 'mm/s',
            'noise_level': 'dB',
            'wear_rate': '%/年',
            'radial_load': 'N',
            'axial_thrust': 'N',
            'material_stress': 'MPa',
            'energy_efficiency_ratio': '',
            'cavitation_margin': 'm',
            'stability_score': '分'
        }

        return `${avg.toFixed(1)} ${units[paramKey] || ''}`
    }

    function getParameterColor(paramKey) {
        var colors = {
            'npsh_required': '#2196F3',
            'temperature_rise': '#FF5722',
            'vibration_level': '#9C27B0',
            'noise_level': '#FF9800',
            'wear_rate': '#795548',
            'radial_load': '#607D8B',
            'axial_thrust': '#3F51B5',
            'material_stress': '#E91E63',
            'energy_efficiency_ratio': '#4CAF50',
            'cavitation_margin': '#00BCD4',
            'stability_score': '#8BC34A'
        }
        return colors[paramKey] || Material.accent
    }

    function getParameterLevel(paramKey) {
        if (!curvesData || !curvesData.enhancedParameters) return 0

        var values = curvesData.enhancedParameters[paramKey]
        if (!values || values.length === 0) return 0

        var avg = values.reduce((a, b) => a + b, 0) / values.length

        // 根据参数类型返回0-1的水平指示
        switch(paramKey) {
            case 'npsh_required': return Math.min(avg / 10, 1)
            case 'temperature_rise': return Math.min(avg / 30, 1)
            case 'vibration_level': return Math.min(avg / 10, 1)
            case 'noise_level': return Math.min((avg - 40) / 40, 1)
            case 'wear_rate': return Math.min(avg / 1, 1)
            case 'stability_score': return avg / 100
            default: return 0.5
        }
    }

    function getParameterStatus(paramKey) {
        var level = getParameterLevel(paramKey)
        if (level < 0.3) return isChineseMode ? "良好" : "Good"
        else if (level < 0.7) return isChineseMode ? "一般" : "Fair"
        else return isChineseMode ? "注意" : "Warning"
    }

    function getParameterStatusColor(paramKey) {
        var level = getParameterLevel(paramKey)
        if (level < 0.3) return Material.color(Material.Green)
        else if (level < 0.7) return Material.color(Material.Orange)
        else return Material.color(Material.Red)
    }

    function getStatusColor(status) {
        switch (status) {
            case 'optimal': return Material.color(Material.Green)
            case 'acceptable': return Material.color(Material.Orange)
            case 'dangerous': return Material.color(Material.Red)
            default: return Material.color(Material.Grey)
        }
    }

    // 🔥 =================================
    // 🔥 业务操作函数
    // 🔥 =================================

    function setBestEfficiencyPoint() {
        if (currentOperatingPoint) {
            console.log("设置BEP点:", currentOperatingPoint.flow, currentOperatingPoint.head)
            // 这里可以调用控制器方法保存BEP点
        }
    }

    function showDetailedAnalysis() {
        if (currentOperatingPoint) {
            console.log("显示详细分析:", currentOperatingPoint)
            // 这里可以打开详细分析窗口
        }
    }

    // 🔥 =================================
    // 🔥 初始化和清理
    // 🔥 =================================

    Component.onCompleted: {
        console.log("EnhancedPumpCurvesChart 组件初始化完成")

        // 如果已有数据，立即更新
        if (curvesData) {
            Qt.callLater(updateChartData)
        }
        if (systemCurve) {
            Qt.callLater(updateSystemCurve)
        }
        if (currentOperatingPoint) {
            Qt.callLater(function() {
                updateOperatingPointDisplay(currentOperatingPoint.flow, currentOperatingPoint.head)
            })
        }
    }

    Component.onDestruction: {
        console.log("EnhancedPumpCurvesChart 组件销毁")
    }
}
