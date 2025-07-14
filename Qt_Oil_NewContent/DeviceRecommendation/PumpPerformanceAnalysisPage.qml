// Qt_Oil_NewContent/DeviceRecommendation/PumpPerformanceAnalysisWindow.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Window
import "./Components" as LocalComponents

ApplicationWindow {
    id: root

    // 窗口属性
    width: 1400
    height: 900
    minimumWidth: 1200
    minimumHeight: 700
    title: isChineseMode ? "泵性能分析" : "Pump Performance Analysis"

    // 🔥 修改 flags 确保显示所有窗口控制按钮
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint |
           Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint |
           Qt.WindowCloseButtonHint

    // 设置为非模态窗口，允许与主窗口交互
    modality: Qt.NonModal

    // 外部属性
    property var pumpData: null
    property int stages: 50
    property real frequency: 60
    property bool isChineseMode: true
    // 🔥 修复：将systemParameters改为独立属性，避免绑定循环
    property real staticHead: 100
    property real frictionCoeff: 0.001
    property var flowRange: [0, 2000]

    // 内部状态
    property int currentViewMode: 0  // 0: 增强曲线, 1: 多工况对比, 2: 性能预测
    property var comparisonData: null
    property var predictionData: null
    // 内部状态属性（添加到现有属性中）
    property var currentCurvesData: null
    property var currentSystemCurveData: null
    property var currentOperatingPointData: null

    // 🔥 添加计算属性，避免直接绑定
    readonly property var systemParameters: ({
        staticHead: root.staticHead,
        frictionCoeff: root.frictionCoeff,
        flowRange: root.flowRange
    })

    // 信号
    signal backRequested()
    signal pumpConfigurationChanged(int stages, real frequency)

    Component.onCompleted: {
        console.log("性能分析窗口加载完成")
        console.log("泵数据:", pumpData ? pumpData.model : "无")

        // 连接控制器信号
        if (typeof pumpCurvesController !== 'undefined' && pumpCurvesController) {
            pumpCurvesController.curvesDataLoaded.connect(onCurvesDataLoaded)
            pumpCurvesController.multiConditionComparisonReady.connect(onComparisonReady)
            pumpCurvesController.performancePredictionCompleted.connect(onPredictionCompleted)
            pumpCurvesController.systemCurveGenerated.connect(onSystemCurveGenerated)
            pumpCurvesController.error.connect(onPumpCurvesError)

            // 初始加载数据
            if (pumpData) {
                loadInitialData()
            }
        }

        // 居中显示窗口
        x = (Screen.width - width) / 2
        y = (Screen.height - height) / 2

        // 显示窗口
        show()
        raise()
        requestActivate()
    }

    // 窗口关闭处理
    onClosing: {
        console.log("性能分析窗口正在关闭")
        root.backRequested()
    }

    // 页面头部工具栏
    header: ToolBar {
        Material.primary: Material.accent
        height: 60

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // 返回按钮
            ToolButton {
                text: isChineseMode ? "← 返回" : "← Back"
                font.pixelSize: 14
                onClicked: root.close()
            }

            // 分隔符
            Rectangle {
                width: 1
                height: 30
                color: Qt.rgba(1, 1, 1, 0.3)
            }

            Column {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.title
                    font.pixelSize: 18
                    font.bold: true
                    color: "white"
                }

                Text {
                    text: pumpData ?
                          `${pumpData.manufacturer} ${pumpData.model} - ${stages}${isChineseMode ? '级' : ' stages'}, ${frequency}Hz` :
                          (isChineseMode ? "未选择泵" : "No pump selected")
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.8)
                }
            }

            // 操作按钮
            RowLayout {
                spacing: 8

                ToolButton {
                    text: isChineseMode ? "导出" : "Export"
                    font.pixelSize: 12
                    onClicked: exportAnalysisData()
                }

                ToolButton {
                    text: isChineseMode ? "设置" : "Settings"
                    font.pixelSize: 12
                    onClicked: settingsDialog.open()
                }

                ToolButton {
                    text: isChineseMode ? "帮助" : "Help"
                    font.pixelSize: 12
                    onClicked: helpDialog.open()
                }
            }
        }
    }

    // 主内容区域
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0

        // 视图模式切换栏
        TabBar {
            id: viewModeTabBar
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            currentIndex: currentViewMode

            onCurrentIndexChanged: {
                currentViewMode = currentIndex
                handleViewModeChange()
            }

            TabButton {
                text: isChineseMode ? "📊 性能曲线" : "📊 Performance Curves"
                font.pixelSize: 14
                width: implicitWidth + 20
            }

            TabButton {
                text: isChineseMode ? "📈 多工况对比" : "📈 Multi-Condition"
                font.pixelSize: 14
                width: implicitWidth + 20
            }

            TabButton {
                text: isChineseMode ? "🔮 预测分析" : "🔮 Prediction"
                font.pixelSize: 14
                width: implicitWidth + 20
            }
        }

        // 内容区域
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentViewMode

            // 模式0: 增强性能曲线
            SplitView {
                orientation: Qt.Horizontal

                // 左侧：增强性能曲线图表
                LocalComponents.EnhancedPumpCurvesChart {
                    SplitView.fillWidth: true
                    SplitView.minimumWidth: 600

                    controller: pumpCurvesController
                    isChineseMode: root.isChineseMode

                    // 🔥 修复：避免绑定循环，使用函数调用
                    curvesData: root.currentCurvesData
                    systemCurve: root.currentSystemCurveData
                    currentOperatingPoint: root.currentOperatingPointData

                    onOperatingPointChanged: (flow, head) => {
                        console.log("工况点变化:", flow, head)
                        updateCurrentOperatingPoint(flow, head)
                        if (pumpCurvesController) {
                            pumpCurvesController.updateOperatingPoint(flow, head)
                        }
                    }

                    onConfigurationChanged: (newStages, newFrequency) => {
                        console.log("配置变化:", newStages, newFrequency)
                        root.stages = newStages
                        root.frequency = newFrequency
                        root.pumpConfigurationChanged(newStages, newFrequency)

                        if (pumpCurvesController) {
                            pumpCurvesController.updatePumpConfiguration(newStages, newFrequency)
                        }

                        // 重新生成曲线数据
                        refreshPumpCurves()
                    }
                }

                // 右侧：控制面板
                Rectangle {
                    SplitView.preferredWidth: 320
                    SplitView.minimumWidth: 300
                    SplitView.maximumWidth: 400
                    color: Material.backgroundColor

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 16

                            // 基本配置
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 160
                                color: Material.dialogColor
                                radius: 8

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    Text {
                                        text: isChineseMode ? "⚙️ 基本配置" : "⚙️ Basic Configuration"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    // 级数控制
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: isChineseMode ? "级数:" : "Stages:"
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 50
                                        }

                                        Slider {
                                            id: stagesSlider
                                            Layout.fillWidth: true
                                            from: 1
                                            to: pumpData ? pumpData.maxStages : 200
                                            stepSize: 1
                                            value: root.stages

                                            onValueChanged: {
                                                if (Math.round(value) !== root.stages) {
                                                    root.stages = Math.round(value)
                                                    updateConfiguration()
                                                }
                                            }
                                        }

                                        SpinBox {
                                            from: 1
                                            to: pumpData ? pumpData.maxStages : 200
                                            value: root.stages
                                            Layout.preferredWidth: 80
                                            onValueChanged: {
                                                if (value !== root.stages) {
                                                    root.stages = value
                                                    stagesSlider.value = value
                                                    updateConfiguration()
                                                }
                                            }
                                        }
                                    }

                                    // 频率控制
                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: isChineseMode ? "频率:" : "Frequency:"
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 50
                                        }

                                        Slider {
                                            id: frequencySlider
                                            Layout.fillWidth: true
                                            from: 30
                                            to: 80
                                            stepSize: 0.1
                                            value: root.frequency

                                            onValueChanged: {
                                                if (Math.abs(value - root.frequency) > 0.1) {
                                                    root.frequency = Math.round(value * 10) / 10
                                                    updateConfiguration()
                                                }
                                            }
                                        }

                                        SpinBox {
                                            from: 300
                                            to: 800
                                            value: root.frequency * 10
                                            Layout.preferredWidth: 80
                                            onValueChanged: {
                                                var newFreq = value / 10
                                                if (Math.abs(newFreq - root.frequency) > 0.1) {
                                                    root.frequency = newFreq
                                                    frequencySlider.value = newFreq
                                                    updateConfiguration()
                                                }
                                            }

                                            textFromValue: function(value) {
                                                return (value / 10).toFixed(1) + " Hz"
                                            }

                                            valueFromText: function(text) {
                                                return parseFloat(text) * 10
                                            }
                                        }
                                    }
                                }
                            }

                            // 系统参数
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 220
                                color: Material.dialogColor
                                radius: 8

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    Text {
                                        text: isChineseMode ? "🔧 系统参数" : "🔧 System Parameters"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 12
                                        rowSpacing: 8

                                        Text {
                                            text: isChineseMode ? "静扬程:" : "Static Head:"
                                            font.pixelSize: 12
                                        }

                                        RowLayout {
                                            SpinBox {
                                                id: staticHeadSpinBox
                                                from: 0
                                                to: 5000
                                                value: root.staticHead  // 🔥 修复：直接绑定到属性
                                                onValueChanged: {
                                                    if (root.staticHead !== value) {
                                                        root.staticHead = value
                                                        updateSystemCurve()
                                                    }
                                                }
                                            }
                                            Text {
                                                text: "m"
                                                font.pixelSize: 12
                                                color: Material.secondaryTextColor
                                            }
                                        }

                                        Text {
                                            text: isChineseMode ? "摩擦系数:" : "Friction:"
                                            font.pixelSize: 12
                                        }
                                        TextField {
                                            text: root.frictionCoeff.toFixed(6)  // 🔥 修复：直接绑定到属性
                                            validator: DoubleValidator {
                                                bottom: 0
                                                top: 1
                                                decimals: 6
                                            }
                                            onTextChanged: {
                                                var value = parseFloat(text)
                                                if (!isNaN(value) && root.frictionCoeff !== value) {
                                                    root.frictionCoeff = value
                                                    updateSystemCurve()
                                                }
                                            }
                                        }
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        text: isChineseMode ? "更新系统曲线" : "Update System Curve"
                                        onClicked: updateSystemCurve()
                                    }
                                }
                            }

                            // 快速操作
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 140
                                color: Material.dialogColor
                                radius: 8

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8

                                    Text {
                                        text: isChineseMode ? "⚡ 快速操作" : "⚡ Quick Actions"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        text: isChineseMode ? "重置为默认值" : "Reset to Default"
                                        onClicked: resetToDefault()
                                    }

                                    Button {
                                        Layout.fillWidth: true
                                        text: isChineseMode ? "优化配置" : "Optimize Configuration"
                                        Material.background: Material.accent
                                        onClicked: optimizeConfiguration()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 更新模式1和模式2使用新的完整组件

            // 模式1: 多工况对比
            LocalComponents.MultiConditionComparisonChart {
                controller: pumpCurvesController
                isChineseMode: root.isChineseMode
                comparisonData: root.comparisonData

                onConditionSelected: (index) => {
                    console.log("选择工况:", index)
                    if (comparisonData && comparisonData.conditions &&
                        index < comparisonData.conditions.length) {
                        var condition = comparisonData.conditions[index]
                        root.stages = condition.stages
                        root.frequency = condition.frequency
                        updateConfiguration()
                    }
                }

                onRequestDetailView: (index) => {
                    console.log("查看详情:", index)
                    // 切换到详细视图
                    currentViewMode = 0
                }
            }

            // 模式2: 性能预测和趋势分析
            LocalComponents.PerformancePredictionChart {
                controller: pumpCurvesController
                isChineseMode: root.isChineseMode
                predictionData: root.predictionData

                onPredictionYearsChanged: (years) => {
                    if (pumpCurvesController && pumpData) {
                        var currentCondition = {
                            pumpId: pumpData.id,
                            stages: root.stages,
                            frequency: root.frequency,
                            metrics: {
                                efficiency_stats: { max: pumpData.efficiency },
                                power_consumption: { at_bep: pumpData.powerPerStage * root.stages }
                            }
                        }
                        pumpCurvesController.generatePerformancePrediction(currentCondition, years)
                    }
                }

                onWearSimulationRequested: (wearPercentage) => {
                    if (pumpCurvesController) {
                        pumpCurvesController.updateWearSimulation(wearPercentage)
                    }
                }
            }
        }
    }

    // 状态栏
    footer: ToolBar {
        height: 30
        Material.background: Material.backgroundColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // 第581行附近，修复属性绑定问题
            Text {
                text: pumpData ?  // 🔥 确保pumpData存在
                      (isChineseMode ? "已选择: " + pumpData.model : "Selected: " + pumpData.model) :
                      (isChineseMode ? "请选择泵型以继续" : "Please select a pump to continue")
                font.pixelSize: 11
                color: pumpData ? Material.primaryTextColor : Material.hintTextColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: isChineseMode ?
                      "视图模式: " + getViewModeName(currentViewMode) :
                      "View Mode: " + getViewModeName(currentViewMode)
                font.pixelSize: 11
                color: Material.secondaryTextColor
            }

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: pumpCurvesController && !pumpCurvesController.busy ?
                       Material.color(Material.Green) : Material.color(Material.Orange)

                SequentialAnimation {
                    running: pumpCurvesController && pumpCurvesController.busy
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: parent
                        property: "opacity"
                        to: 0.3
                        duration: 500
                    }
                    NumberAnimation {
                        target: parent
                        property: "opacity"
                        to: 1.0
                        duration: 500
                    }
                }
            }
        }
    }

    // 设置对话框
    Dialog {
        id: settingsDialog
        title: isChineseMode ? "分析设置" : "Analysis Settings"
        width: 400
        height: 300
        modal: true
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            GroupBox {
                title: isChineseMode ? "显示选项" : "Display Options"
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent

                    CheckBox {
                        text: isChineseMode ? "显示网格线" : "Show Grid Lines"
                        checked: true
                    }

                    CheckBox {
                        text: isChineseMode ? "显示数据点" : "Show Data Points"
                        checked: true
                    }
                }
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel
    }

    // 帮助对话框
    Dialog {
        id: helpDialog
        title: isChineseMode ? "使用帮助" : "Help"
        width: 500
        height: 400
        modal: true
        anchors.centerIn: parent

        ScrollView {
            anchors.fill: parent

            Text {
                width: parent.width
                text: isChineseMode ?
                      "• 性能曲线：显示泵的扬程、效率等性能曲线\n" +
                      "• 多工况对比：对比不同参数下的性能表现\n" +
                      "• 预测分析：预测长期性能趋势和维护需求\n" +
                      "• 点击图表可以设置工况点\n" +
                      "• 调整右侧参数可以实时更新曲线" :
                      "• Performance Curves: Display head, efficiency curves\n" +
                      "• Multi-Condition: Compare performance under different parameters\n" +
                      "• Prediction: Predict long-term trends and maintenance\n" +
                      "• Click chart to set operating point\n" +
                      "• Adjust parameters to update curves in real-time"
                wrapMode: Text.Wrap
                font.pixelSize: 12
            }
        }

        standardButtons: Dialog.Ok
    }

    // 🔥 修复信号处理函数 - 更新 onCurvesDataLoaded
    function onCurvesDataLoaded(curvesData) {
        console.log("泵性能曲线数据加载完成", curvesData)

        // 🔥 关键修复：保存控制器返回的数据
        if (curvesData) {
            root.currentCurvesData = curvesData
            console.log("已保存曲线数据:", JSON.stringify(curvesData, null, 2))

            // 如果有baseCurves数据，检查数据结构
            if (curvesData.baseCurves) {
                console.log("扬程数据点数:", curvesData.baseCurves.head ? curvesData.baseCurves.head.length : 0)
                console.log("效率数据点数:", curvesData.baseCurves.efficiency ? curvesData.baseCurves.efficiency.length : 0)
                console.log("功率数据点数:", curvesData.baseCurves.power ? curvesData.baseCurves.power.length : 0)
            }
        }
    }

    function onComparisonReady(comparisonData) {
        console.log("多工况对比数据就绪")
        root.comparisonData = comparisonData
    }

    function onPredictionCompleted(predictionData) {
        console.log("性能预测完成")
        root.predictionData = predictionData
    }

    function onSystemCurveGenerated(systemCurve) {
        console.log("系统曲线生成完成", systemCurve)

        // 🔥 关键修复：保存系统曲线数据
        if (systemCurve) {
            root.currentSystemCurveData = systemCurve
            console.log("已保存系统曲线数据:", JSON.stringify(systemCurve, null, 2))
        }
    }

    function onPumpCurvesError(errorMessage) {
        console.error("泵性能曲线错误:", errorMessage)
    }

    // 🔥 修复loadInitialData函数
    function loadInitialData() {
        if (pumpCurvesController && pumpData) {
            console.log("开始加载初始数据，泵ID:", pumpData.id)

            // 先清理现有数据
            root.currentCurvesData = null
            root.currentSystemCurveData = null
            root.currentOperatingPointData = null

            // 加载泵曲线数据
            pumpCurvesController.loadPumpCurves(
                pumpData.id,
                pumpData.displacement || 1000,
                stages,
                frequency
            )

            // 生成系统曲线
            updateSystemCurve()

            // 设置默认工况点
            Qt.callLater(function() {
                if (root.currentCurvesData && root.currentCurvesData.baseCurves) {
                    var curves = root.currentCurvesData.baseCurves
                    if (curves.flow && curves.head && curves.flow.length > 10) {
                        var midIndex = Math.floor(curves.flow.length / 2)
                        updateCurrentOperatingPoint(curves.flow[midIndex], curves.head[midIndex])
                    }
                }
            })
        }
    }

    // 🔥 修复handleViewModeChange函数
    function handleViewModeChange() {
        console.log("视图模式切换到:", currentViewMode)

        if (!pumpCurvesController || !pumpData) return

        switch (currentViewMode) {
            case 0:
                // 确保数据已加载
                if (!root.currentCurvesData) {
                    console.log("重新加载曲线数据")
                    pumpCurvesController.loadPumpCurves(pumpData.id, pumpData.displacement || 1000, stages, frequency)
                }
                break
            case 1:
                var defaultConditions = [
                    { label: isChineseMode ? "当前工况" : "Current", stages: stages, frequency: frequency, color: "#2196F3" },
                    { label: isChineseMode ? "优化工况" : "Optimized", stages: Math.round(stages * 0.8), frequency: 55, color: "#4CAF50" },
                    { label: isChineseMode ? "高产工况" : "High Flow", stages: Math.round(stages * 1.2), frequency: 65, color: "#FF9800" }
                ]
                pumpCurvesController.generateMultiConditionComparison(defaultConditions)
                break
            case 2:
                var currentCondition = {
                    pumpId: pumpData.id,
                    stages: stages,
                    frequency: frequency,
                    metrics: {
                        efficiency_stats: { max: pumpData.efficiency },
                        power_consumption: { at_bep: pumpData.powerPerStage * stages }
                    }
                }
                pumpCurvesController.generatePerformancePrediction(currentCondition, 5)
                break
        }
    }


    function resetToDefault() {
        stages = 50
        frequency = 60
        root.staticHead = 100       // 🔥 修复：直接设置属性
        root.frictionCoeff = 0.001  // 🔥 修复：直接设置属性
        updateConfiguration()
        updateSystemCurve()
    }

    function optimizeConfiguration() {
        if (pumpData) {
            var optimalStages = Math.round(pumpData.maxStages * 0.7)
            var optimalFrequency = 55
            stages = optimalStages
            frequency = optimalFrequency
            updateConfiguration()
            console.log("配置已优化:", optimalStages, "级,", optimalFrequency, "Hz")
        }
    }

    function getViewModeName(mode) {
        var names = [
            isChineseMode ? "性能曲线" : "Performance Curves",
            isChineseMode ? "多工况对比" : "Multi-Condition",
            isChineseMode ? "预测分析" : "Prediction Analysis"
        ]
        return names[mode] || ""
    }

    function exportAnalysisData() {
        console.log("导出分析数据")
    }

    // 新增数据生成和管理函数
    function getCurvesDataForPump() {
        if (!pumpData || !currentCurvesData) {
            return generateMockCurvesData()
        }
        return currentCurvesData
    }

    function getSystemCurveData() {
        if (!currentSystemCurveData) {
            return generateSystemCurveData()
        }
        return currentSystemCurveData
    }

    function getCurrentOperatingPoint() {
        return currentOperatingPointData
    }

    function generateMockCurvesData() {
        if (!pumpData) return null

        console.log("生成泵曲线数据:", pumpData.model)

        var flowPoints = []
        var headPoints = []
        var efficiencyPoints = []
        var powerPoints = []

        var maxFlow = pumpData.maxFlow || 4000
        var headPerStage = pumpData.headPerStage || 25
        var totalHead = headPerStage * stages * (frequency / 60)
        var maxEfficiency = pumpData.efficiency || 70

        // 生成性能曲线数据点
        for (var i = 0; i <= 20; i++) {
            var flow = (maxFlow / 20) * i

            // 扬程曲线 (二次衰减)
            var flowRatio = flow / maxFlow
            var headRatio = 1 - Math.pow(flowRatio, 1.8) * 0.8
            var head = totalHead * headRatio

            // 效率曲线 (钟形曲线)
            var efficiency = maxEfficiency * Math.exp(-Math.pow((flowRatio - 0.6) / 0.3, 2))

            // 功率曲线
            var power = (flow * head * 1.2) / (3600 * efficiency / 100) // 简化功率计算

            flowPoints.push(flow)
            headPoints.push(Math.max(head, 0))
            efficiencyPoints.push(Math.max(efficiency, 0))
            powerPoints.push(Math.max(power, 0))
        }

        // 生成关键工况点
        var operatingPoints = [
            { flow: maxFlow * 0.6, head: totalHead * 0.8, label: isChineseMode ? "最佳效率点" : "BEP" },
            { flow: maxFlow * 0.4, head: totalHead * 0.9, label: isChineseMode ? "最小流量点" : "Min Flow" },
            { flow: maxFlow * 0.8, head: totalHead * 0.6, label: isChineseMode ? "最大流量点" : "Max Flow" }
        ]

        // 生成增强参数
        var enhancedParameters = {
            npsh_required: Array.from({length: 21}, (_, i) => 3 + i * 0.3),
            temperature_rise: Array.from({length: 21}, (_, i) => 5 + i * 0.2),
            vibration_level: Array.from({length: 21}, (_, i) => 2 + Math.random() * 3),
            noise_level: Array.from({length: 21}, (_, i) => 65 + i * 0.5),
            wear_rate: Array.from({length: 21}, (_, i) => 0.1 + i * 0.05)
        }

        var curvesData = {
            stages: stages,
            frequency: frequency,
            pumpModel: pumpData.model,
            baseCurves: {
                flow: flowPoints,
                head: headPoints,
                efficiency: efficiencyPoints,
                power: powerPoints
            },
            operatingPoints: operatingPoints,
            enhancedParameters: enhancedParameters,
            performanceZones: {
                optimal: { minFlow: maxFlow * 0.5, maxFlow: maxFlow * 0.7 },
                acceptable: { minFlow: maxFlow * 0.3, maxFlow: maxFlow * 0.9 },
                dangerous: { minFlow: 0, maxFlow: maxFlow * 0.2 }
            }
        }

        currentCurvesData = curvesData
        return curvesData
    }

    function generateSystemCurveData() {
        console.log("生成系统曲线数据")

        var staticHeadValue = root.staticHead    // 🔥 修复：使用属性
        var frictionCoeffValue = root.frictionCoeff  // 🔥 修复：使用属性
        var maxFlow = 5000

        var flowPoints = []
        var headPoints = []

        for (var i = 0; i <= 20; i++) {
            var flow = (maxFlow / 20) * i
            var frictionHead = frictionCoeffValue * Math.pow(flow, 2)
            var totalHead = staticHeadValue + frictionHead

            flowPoints.push(flow)
            headPoints.push(totalHead)
        }

        // 计算与泵曲线的交点
        var intersections = []
        if (currentCurvesData) {
            // 简化的交点计算
            var pumpFlow = currentCurvesData.baseCurves.flow
            var pumpHead = currentCurvesData.baseCurves.head

            for (var j = 0; j < pumpFlow.length - 1; j++) {
                var systemHead = staticHeadValue + frictionCoeffValue * Math.pow(pumpFlow[j], 2)
                if (Math.abs(pumpHead[j] - systemHead) < 5) { // 5m 误差范围
                    intersections.push({
                        flow: pumpFlow[j],
                        head: pumpHead[j],
                        efficiency: currentCurvesData.baseCurves.efficiency[j],
                        power: currentCurvesData.baseCurves.power[j]
                    })
                }
            }
        }

        var systemCurveData = {
            flow: flowPoints,
            head: headPoints,
            intersections: intersections,
            staticHead: staticHeadValue,      // 🔥 修复：使用属性
            frictionCoeff: frictionCoeffValue // 🔥 修复：使用属性
        }

        currentSystemCurveData = systemCurveData
        return systemCurveData
    }

    function updateCurrentOperatingPoint(flow, head) {
        console.log("更新当前工况点:", flow, head)

        // 🔥 确保单位一致性
        var flowM3d = flow * 0.158987  // bbl/d -> m³/d
        var headM = head * 0.3048      // ft -> m

       LocalComponents.EnhancedPumpCurvesChart.currentOperatingPoint = {
            flow: flowM3d,
            head: headM,
            efficiency: 0,  // 会在图表中插值计算
            power: 0,       // 会在图表中插值计算
            status: 'normal',
            statusText: isChineseMode ? '正常运行' : 'Normal Operation'
        }

        console.log("工况点已更新为:", flowM3d.toFixed(1), "m³/d,", headM.toFixed(1), "m")
    }

    function refreshPumpCurves() {
        console.log("刷新泵曲线数据")
        currentCurvesData = null
        currentSystemCurveData = null

        // 重新生成数据
        generateMockCurvesData()
        generateSystemCurveData()

        // 更新工况点
        if (currentOperatingPointData) {
            updateCurrentOperatingPoint(currentOperatingPointData.flow, currentOperatingPointData.head)
        }
    }

    // 更新现有的 updateSystemCurve 函数
    function updateSystemCurve() {
        if (pumpCurvesController) {
            pumpCurvesController.generateSystemCurve(systemParameters)
        }

        // 同时更新本地系统曲线数据
        currentSystemCurveData = null
        generateSystemCurveData()
    }

    // 🔥 修复updateConfiguration函数
    function updateConfiguration() {
        console.log("更新配置:", stages, "级,", frequency, "Hz")

        root.pumpConfigurationChanged(stages, frequency)

        if (pumpCurvesController && pumpData) {
            pumpCurvesController.updatePumpConfiguration(stages, frequency)

            // 延迟一点重新加载数据，确保控制器处理完毕
            Qt.callLater(function() {
                pumpCurvesController.loadPumpCurves(pumpData.id, pumpData.displacement || 1000, stages, frequency)
            })
        }
    }
}
