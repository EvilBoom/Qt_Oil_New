// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step4_PumpSelection.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts
import "../Components" as LocalComponents

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})

    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 内部属性
    property string selectedLiftMethod: stepData.lift_method ? stepData.lift_method.selectedMethod : "esp"
    property var selectedPump: null
    property int selectedStages: 1
    property var availablePumps: []
    property bool loading: false

    // 第二阶段新增属性
    property int viewMode: 0  // 0: 基础选择, 1: 增强曲线, 2: 多工况对比, 3: 性能预测
    property var currentComparisonData: null
    property var currentPredictionData: null

    color: "transparent"

    Component.onCompleted: {
        console.log("=== Step4 组件加载完成 ===")
        console.log("controller:", controller)
        console.log("stepData:", JSON.stringify(stepData))
        console.log("constraints:", JSON.stringify(constraints))

        // 连接控制器信号
        if (controller) {
            controller.pumpsLoaded.connect(onPumpsLoaded)
            controller.error.connect(onError)
        }

        // 连接泵曲线控制器信号
        if (typeof pumpCurvesController !== 'undefined' && pumpCurvesController) {
            console.log("连接泵曲线控制器信号")
            pumpCurvesController.curvesDataLoaded.connect(onCurvesDataLoaded)
            pumpCurvesController.multiConditionComparisonReady.connect(onComparisonReady)
            pumpCurvesController.performancePredictionCompleted.connect(onPredictionCompleted)
            pumpCurvesController.systemCurveGenerated.connect(onSystemCurveGenerated)
            pumpCurvesController.error.connect(onPumpCurvesError)
        } else {
            console.warn("pumpCurvesController 未定义或为空")
        }

        // 🔥 更新约束条件以包含Step2的预测结果
        updateConstraintsFromPrediction()

        loadPumpsForMethod()
    }
    // 🔥 新增函数：从预测结果更新约束条件
    function updateConstraintsFromPrediction() {
        console.log("=== 更新约束条件从预测结果 ===")

        if (stepData.prediction && stepData.prediction.finalValues) {
            var finalValues = stepData.prediction.finalValues
            console.log("Step2预测结果:", JSON.stringify(finalValues))

            // 更新约束条件
            var updatedConstraints = {
                // 产量约束：基于预测结果的±10%范围
                minProduction: finalValues.production ? finalValues.production * 0.9 : (constraints.minProduction || 1000),
                maxProduction: finalValues.production ? finalValues.production * 1.1 : (constraints.maxProduction || 3000),

                // 扬程约束：使用预测的扬程值
                pumpDepth: finalValues.totalHead || constraints.pumpDepth || 2000,
                totalHead: finalValues.totalHead || constraints.totalHead || 2000,

                // 气液比约束
                gasRate: finalValues.gasRate || constraints.gasRate || 0.1,

                // 其他约束保持不变
                casingSize: constraints.casingSize || 5.5,
                maxOD: constraints.maxOD || 5.0
            }

            console.log("更新后的约束条件:", JSON.stringify(updatedConstraints))
            constraints = updatedConstraints
        } else {
            console.warn("没有Step2预测结果，使用默认约束条件")

            // 修正约束数据的单位问题
            if (constraints.minProduction && constraints.minProduction < 1) {
                console.log("检测到约束数据单位问题，进行修正")
                console.log("修正前:", constraints.minProduction, "-", constraints.maxProduction)

                var correctedConstraints = {
                    minProduction: constraints.minProduction * 1000,
                    maxProduction: constraints.maxProduction * 1000,
                    pumpDepth: constraints.pumpDepth || 2000
                }
                constraints = correctedConstraints
                console.log("修正后:", constraints.minProduction, "-", constraints.maxProduction, "bbl/d")
            }
        }
    }

    Timer {
        id: pumpLoadTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            availablePumps = generateMockPumpData()
            loading = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "泵型选择" : "Pump Selection"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }

            Text {
                text: " - " + getLiftMethodName()
                font.pixelSize: 18
                color: Material.secondaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 筛选条件
            ComboBox {
                id: manufacturerFilter
                Layout.preferredWidth: 150
                model: ["All Manufacturers", "Baker Hughes", "Schlumberger", "Weatherford", "Borets"]
                displayText: isChineseMode ? "制造商筛选" : currentText
                onCurrentIndexChanged: filterPumps()
            }

            ComboBox {
                id: seriesFilter
                Layout.preferredWidth: 120
                model: ["All Series", "400 Series", "500 Series", "600 Series", "700 Series"]
                displayText: isChineseMode ? "系列筛选" : currentText
                onCurrentIndexChanged: filterPumps()
            }
        }

        // 要求参数显示
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Material.dialogColor
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 24

                Column {
                    Text {
                        text: isChineseMode ? "要求产量" : "Required Flow"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    Text {
                        text: {
                            // 🔥 优先使用Step2的预测结果
                            if (stepData.prediction && stepData.prediction.finalValues) {
                                var production = stepData.prediction.finalValues.production
                                if (production && production > 0) {
                                    return production.toFixed(0) + " bbl/d"
                                }
                            }

                            // 🔥 备用：使用约束条件
                            if (constraints.minProduction && constraints.maxProduction) {
                                var minProd = constraints.minProduction
                                var maxProd = constraints.maxProduction

                                // 处理单位转换
                                if (minProd < 1) {
                                    minProd = minProd * 1000
                                    maxProd = maxProd * 1000
                                }

                                return minProd.toFixed(0) + " - " + maxProd.toFixed(0) + " bbl/d"
                            }

                            return "N/A"
                        }
                        font.pixelSize: 14
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                Column {
                    Text {
                        text: isChineseMode ? "要求扬程" : "Required Head"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    Text {
                        text: {
                            // 🔥 优先使用Step2的预测结果
                            if (stepData.prediction && stepData.prediction.finalValues) {
                                var totalHead = stepData.prediction.finalValues.totalHead
                                if (totalHead && totalHead > 0) {
                                    return totalHead.toFixed(0) + " ft"
                                }
                            }

                            // 🔥 备用：使用约束条件
                            if (constraints.pumpDepth && constraints.pumpDepth > 0) {
                                return constraints.pumpDepth.toFixed(0) + " ft"
                            }

                            return "N/A"
                        }
                        font.pixelSize: 14
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                Column {
                    Text {
                        text: isChineseMode ? "套管限制" : "Casing Limit"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    Text {
                        text: {
                            // 🔥 从井结构数据获取套管尺寸
                            if (stepData.well && stepData.well.casingSize) {
                                return stepData.well.casingSize + " in"
                            }

                            // 🔥 默认值
                            return "5.5 in"
                        }
                        font.pixelSize: 14
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                // 🔥 新增：气液比显示
                Column {
                    Text {
                        text: isChineseMode ? "气液比" : "Gas Rate"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    Text {
                        text: {
                            if (stepData.prediction && stepData.prediction.finalValues) {
                                var gasRate = stepData.prediction.finalValues.gasRate
                                if (gasRate !== undefined && gasRate !== null) {
                                    return gasRate.toFixed(4)
                                }
                            }
                            return "N/A"
                        }
                        font.pixelSize: 14
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                Item { Layout.fillWidth: true }

                // 实时状态指示 - 改进
                Rectangle {
                    width: 140
                    height: 36
                    radius: 18
                    color: {
                        if (selectedPump) {
                            return Material.color(Material.Green)
                        } else if (stepData.prediction && stepData.prediction.finalValues) {
                            return Material.color(Material.Orange)
                        } else {
                            return Material.color(Material.Red)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (selectedPump) {
                                return isChineseMode ? "✓ 已选择泵型" : "✓ Pump Selected"
                            } else if (stepData.prediction && stepData.prediction.finalValues) {
                                return isChineseMode ? "请选择泵型" : "Select Pump"
                            } else {
                                return isChineseMode ? "需要预测结果" : "Need Prediction"
                            }
                        }
                        color: "white"
                        font.pixelSize: 11
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // 主内容区域
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // 泵列表区域
            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 450  // 🔥 增加最小宽度
                SplitView.preferredWidth: parent.width * 0.6  // 🔥 设置泵列表占60%
                color: "transparent"

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 12
                    clip: true

                    GridLayout {
                        width: parent.width - 24
                        columns: width > 950 ? 2 : 1
                        columnSpacing: 20
                        rowSpacing: 16

                        Repeater {
                            model: getFilteredPumps()

                            LocalComponents.PumpSelectionCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 300

                                pumpData: modelData
                                isSelected: selectedPump && selectedPump.id === modelData.id
                                matchScore: calculatePumpMatchScore(modelData)
                                isChineseMode: root.isChineseMode

                                onClicked: {
                                    console.log("选择泵:", modelData.model)
                                    selectedPump = modelData

                                    // 🔥 自动计算并设置级数
                                    autoCalculateStages()

                                    updateStepData()

                                    // 加载泵的性能曲线数据
                                    if (typeof pumpCurvesController !== 'undefined' && pumpCurvesController && modelData) {
                                        pumpCurvesController.loadPumpCurves(
                                            modelData.id,
                                            modelData.displacement || 1000,
                                            selectedStages,
                                            60
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // 加载指示器和空状态保持不变...
                BusyIndicator {
                    anchors.centerIn: parent
                    running: loading
                    visible: running
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    visible: !loading && getFilteredPumps().length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🔍"
                        font.pixelSize: 48
                        color: Material.hintTextColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "没有找到符合条件的泵" : "No pumps found matching criteria"
                        color: Material.hintTextColor
                        font.pixelSize: 14
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "显示所有泵" : "Show All Pumps"
                        onClicked: {
                            manufacturerFilter.currentIndex = 0
                            seriesFilter.currentIndex = 0
                        }
                    }
                }
            }

            // 🔥 右侧详情面板 - 完全重新设计
            Rectangle {
                SplitView.fillHeight: true  // 🔥 填充高度
                SplitView.preferredWidth: parent.width * 0.4  // 🔥 占40%宽度
                SplitView.minimumWidth: 400  // 🔥 增加最小宽度
                SplitView.maximumWidth: 600  // 🔥 设置最大宽度防止过宽

                color: Material.dialogColor
                visible: selectedPump !== null

                // 🔥 使用ColumnLayout直接填充，而不是ScrollView
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20  // 🔥 增加边距
                    spacing: 20

                    // 🔥 标题栏
                    Text {
                        Layout.fillWidth: true
                        text: isChineseMode ? "泵型详情" : "Pump Details"
                        font.pixelSize: 18
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Material.dividerColor
                    }

                    // 🔥 可滚动的内容区域
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 20

                            // 泵基本信息 - 扩大
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120  // 🔥 增加高度
                                color: Material.backgroundColor
                                radius: 12  // 🔥 增加圆角

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20  // 🔥 增加内边距

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 8  // 🔥 增加间距

                                        Text {
                                            text: selectedPump ? selectedPump.manufacturer : ""
                                            font.pixelSize: 16  // 🔥 增大字体
                                            color: Material.secondaryTextColor
                                        }

                                        Text {
                                            text: selectedPump ? selectedPump.model : ""
                                            font.pixelSize: 22  // 🔥 增大字体
                                            font.bold: true
                                            color: Material.primaryTextColor
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: selectedPump ? selectedPump.series + " Series" : ""
                                            font.pixelSize: 14  // 🔥 增大字体
                                            color: Material.hintTextColor
                                        }
                                    }

                                    // 🔥 更大的匹配度圆形进度
                                    LocalComponents.CircularProgress {
                                        width: 80  // 🔥 增加尺寸
                                        height: 80
                                        value: selectedPump ? calculatePumpMatchScore(selectedPump) / 100 : 0
                                    }
                                }
                            }

                            // 级数选择 - 扩大
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180  // 🔥 增加高度以容纳更多信息
                                color: Material.backgroundColor
                                radius: 12

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: isChineseMode ? "级数设置" : "Stages Configuration"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }

                                        Item { Layout.fillWidth: true }

                                        // 🔥 自动计算按钮
                                        Button {
                                            text: isChineseMode ? "🔄 自动计算" : "🔄 Auto Calc"
                                            font.pixelSize: 11
                                            Layout.preferredHeight: 28
                                            Material.background: Material.color(Material.Blue)
                                            enabled: selectedPump !== null

                                            onClicked: {
                                                autoCalculateStages()
                                                updateStepData()
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 16

                                        Text {
                                            text: isChineseMode ? "级数:" : "Stages:"
                                            font.pixelSize: 14
                                            color: Material.secondaryTextColor
                                        }

                                        Slider {
                                            id: stagesSlider
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 40
                                            from: 1
                                            to: selectedPump ? selectedPump.maxStages : 100
                                            stepSize: 1
                                            value: selectedStages

                                            onValueChanged: {
                                                selectedStages = value
                                                updateStepData()

                                                if (typeof pumpCurvesController !== 'undefined' && pumpCurvesController && selectedPump) {
                                                    pumpCurvesController.updatePumpConfiguration(selectedStages, 60)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 80
                                            height: 32
                                            radius: 16
                                            color: Material.accent

                                            Text {
                                                anchors.centerIn: parent
                                                text: selectedStages + (isChineseMode ? " 级" : " stages")
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: "white"
                                            }
                                        }
                                    }

                                    // 🔥 扬程计算显示
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 60
                                        color: {
                                            var requiredHead = getRequiredTotalHead()
                                            var actualHead = selectedPump ? selectedStages * selectedPump.headPerStage : 0

                                            if (requiredHead > 0 && actualHead >= requiredHead) {
                                                return Material.color(Material.Green, Material.Shade50)
                                            } else if (requiredHead > 0 && actualHead < requiredHead) {
                                                return Material.color(Material.Red, Material.Shade50)
                                            } else {
                                                return Material.color(Material.Grey, Material.Shade50)
                                            }
                                        }
                                        radius: 8
                                        border.width: 1
                                        border.color: {
                                            var requiredHead = getRequiredTotalHead()
                                            var actualHead = selectedPump ? selectedStages * selectedPump.headPerStage : 0

                                            if (requiredHead > 0 && actualHead >= requiredHead) {
                                                return Material.color(Material.Green)
                                            } else if (requiredHead > 0 && actualHead < requiredHead) {
                                                return Material.color(Material.Red)
                                            } else {
                                                return Material.dividerColor
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 16

                                            Column {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: isChineseMode ? "需求扬程:" : "Required Head:"
                                                    font.pixelSize: 11
                                                    color: Material.secondaryTextColor
                                                }
                                                Text {
                                                    text: {
                                                        var requiredHead = getRequiredTotalHead()
                                                        return requiredHead > 0 ? requiredHead.toFixed(0) + " ft" : "N/A"
                                                    }
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: Material.primaryTextColor
                                                }
                                            }

                                            Text {
                                                text: "→"
                                                font.pixelSize: 16
                                                color: Material.hintTextColor
                                            }

                                            Column {
                                                Layout.fillWidth: true

                                                Text {
                                                    text: isChineseMode ? "实际扬程:" : "Actual Head:"
                                                    font.pixelSize: 11
                                                    color: Material.secondaryTextColor
                                                }
                                                Text {
                                                    text: selectedPump ? (selectedStages * selectedPump.headPerStage).toFixed(0) + " ft" : "N/A"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: {
                                                        var requiredHead = getRequiredTotalHead()
                                                        var actualHead = selectedPump ? selectedStages * selectedPump.headPerStage : 0

                                                        if (requiredHead > 0 && actualHead >= requiredHead) {
                                                            return Material.color(Material.Green)
                                                        } else if (requiredHead > 0 && actualHead < requiredHead) {
                                                            return Material.color(Material.Red)
                                                        } else {
                                                            return Material.primaryTextColor
                                                        }
                                                    }
                                                }
                                            }

                                            // 🔥 状态图标
                                            Text {
                                                text: {
                                                    var requiredHead = getRequiredTotalHead()
                                                    var actualHead = selectedPump ? selectedStages * selectedPump.headPerStage : 0

                                                    if (requiredHead > 0 && actualHead >= requiredHead) {
                                                        return "✓"
                                                    } else if (requiredHead > 0 && actualHead < requiredHead) {
                                                        return "✗"
                                                    } else {
                                                        return "?"
                                                    }
                                                }
                                                font.pixelSize: 18
                                                font.bold: true
                                                color: {
                                                    var requiredHead = getRequiredTotalHead()
                                                    var actualHead = selectedPump ? selectedStages * selectedPump.headPerStage : 0

                                                    if (requiredHead > 0 && actualHead >= requiredHead) {
                                                        return Material.color(Material.Green)
                                                    } else if (requiredHead > 0 && actualHead < requiredHead) {
                                                        return Material.color(Material.Red)
                                                    } else {
                                                        return Material.hintTextColor
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 关键参数预览 - 大幅扩展
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 240  // 🔥 大幅增加高度
                                color: Material.backgroundColor
                                radius: 12

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 16

                                    Text {
                                        text: isChineseMode ? "关键参数" : "Key Parameters"
                                        font.pixelSize: 16  // 🔥 增大字体
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: Material.dividerColor
                                    }

                                    // 🔥 使用更大的网格布局
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 30  // 🔥 增加列间距
                                        rowSpacing: 16    // 🔥 增加行间距

                                        Text {
                                            text: isChineseMode ? "流量范围:" : "Flow Range:"
                                            font.pixelSize: 13  // 🔥 增大字体
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedPump ?
                                                  selectedPump.minFlow + " - " + selectedPump.maxFlow + " bbl/d" : "N/A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            text: isChineseMode ? "单级扬程:" : "Head/Stage:"
                                            font.pixelSize: 13
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedPump ? selectedPump.headPerStage + " ft" : "N/A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            text: isChineseMode ? "最佳效率:" : "Best Efficiency:"
                                            font.pixelSize: 13
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedPump ? selectedPump.efficiency + "%" : "N/A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: "#4CAF50"
                                        }

                                        Text {
                                            text: isChineseMode ? "外径:" : "OD:"
                                            font.pixelSize: 13
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedPump ? selectedPump.outerDiameter + " in" : "N/A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            text: isChineseMode ? "单级功率:" : "Power/Stage:"
                                            font.pixelSize: 13
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedPump ? selectedPump.powerPerStage + " HP" : "N/A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            text: isChineseMode ? "最大级数:" : "Max Stages:"
                                            font.pixelSize: 13
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedPump ? selectedPump.maxStages + " stages" : "N/A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }
                                }
                            }

                            // 🔥 性能计算预览区域 - 新增
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                color: Material.color(Material.Blue, Material.Shade50)
                                radius: 12
                                border.width: 1
                                border.color: Material.color(Material.Blue, Material.Shade200)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 12

                                    Text {
                                        text: isChineseMode ? "📊 性能计算" : "📊 Performance Calculation"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: Material.color(Material.Blue, Material.Shade800)
                                    }

                                    Row {
                                        Layout.fillWidth: true
                                        spacing: 24

                                        Column {
                                            Text {
                                                text: isChineseMode ? "总功率" : "Total Power"
                                                font.pixelSize: 11
                                                color: Material.color(Material.Blue, Material.Shade600)
                                            }
                                            Text {
                                                text: selectedPump ? (selectedStages * selectedPump.powerPerStage).toFixed(1) + " HP" : "N/A"
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: Material.color(Material.Blue, Material.Shade800)
                                            }
                                        }

                                        Column {
                                            Text {
                                                text: isChineseMode ? "总长度估算" : "Est. Length"
                                                font.pixelSize: 11
                                                color: Material.color(Material.Blue, Material.Shade600)
                                            }
                                            Text {
                                                text: selectedPump ? (selectedStages * 12).toFixed(0) + " ft" : "N/A"
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: Material.color(Material.Blue, Material.Shade800)
                                            }
                                        }

                                        Column {
                                            Text {
                                                text: isChineseMode ? "工作点效率" : "Operating Eff."
                                                font.pixelSize: 11
                                                color: Material.color(Material.Blue, Material.Shade600)
                                            }
                                            Text {
                                                text: selectedPump ? (selectedPump.efficiency * 0.95).toFixed(1) + "%" : "N/A"
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: "#4CAF50"
                                            }
                                        }
                                    }
                                }
                            }

                            // 底部间距
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                            }
                        }
                    }

                    // 🔥 底部固定按钮区域
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "transparent"

                        Button {
                            anchors.fill: parent
                            anchors.margins: 4
                            text: isChineseMode ? "🔍 查看详细性能分析" : "🔍 View Detailed Performance Analysis"
                            Material.background: Material.accent
                            enabled: selectedPump !== null
                            font.pixelSize: 14  // 🔥 增大按钮字体
                            font.bold: true

                            onClicked: {
                                console.log("打开性能分析页面")
                                openPerformanceAnalysisPage()
                            }
                        }
                    }
                }
            }
        }
    }

    // 信号处理函数
    function onPumpsLoaded(pumps) {
        console.log("接收到泵数据:", pumps.length, "个")
        availablePumps = pumps
        loading = false
    }

    function onError(errorMessage) {
        console.error("加载泵数据错误:", errorMessage)
        loading = false
        availablePumps = generateMockPumpData()
    }

    function onCurvesDataLoaded(curvesData) {
        console.log("泵性能曲线数据加载完成")
    }

    function onComparisonReady(comparisonData) {
        console.log("多工况对比数据就绪")
        currentComparisonData = comparisonData
    }

    function onPredictionCompleted(predictionData) {
        console.log("性能预测完成")
        currentPredictionData = predictionData
    }

    function onSystemCurveGenerated(systemCurve) {
        console.log("系统曲线生成完成")
    }

    function onPumpCurvesError(errorMessage) {
        console.error("泵性能曲线错误:", errorMessage)
    }

    // 函数定义
    function getLiftMethodName() {
        var methodNames = {
            "esp": isChineseMode ? "潜油离心泵" : "ESP",
            "pcp": isChineseMode ? "潜油螺杆泵" : "PCP",
            "espcp": isChineseMode ? "潜油柱塞泵" : "ESPCP",
            "hpp": isChineseMode ? "水力柱塞泵" : "HPP",
            "jet": isChineseMode ? "射流泵" : "Jet Pump"
        }
        return methodNames[selectedLiftMethod] || ""
    }

    function loadPumpsForMethod() {
        loading = true
        console.log("开始加载泵数据，举升方式:", selectedLiftMethod)

        if (controller) {
            controller.getPumpsByLiftMethod(selectedLiftMethod)
        } else {
            console.warn("Controller未连接，使用模拟数据")
            pumpLoadTimer.start()
        }
    }

    // 在generateMockPumpData函数中，修正pump数据结构
    function generateMockPumpData() {
        if (selectedLiftMethod === "esp") {
            return [
                {
                    id: "FLEXPump_400",        // 🔥 修正：使用字符串模型名
                    manufacturer: "Baker Hughes",
                    model: "FLEXPump™ 400",
                    series: "400",
                    minFlow: 150,
                    maxFlow: 4000,
                    headPerStage: 25,
                    powerPerStage: 2.5,
                    efficiency: 68,
                    outerDiameter: 4.0,
                    shaftDiameter: 0.75,
                    maxStages: 400,
                    displacement: 1000
                },
                {
                    id: "FLEXPump_600",        // 🔥 修正：使用字符串模型名
                    manufacturer: "Schlumberger",
                    model: "REDA Maximus",
                    series: "500",
                    minFlow: 500,
                    maxFlow: 8000,
                    headPerStage: 30,
                    powerPerStage: 3.5,
                    efficiency: 72,
                    outerDiameter: 5.12,
                    shaftDiameter: 1.0,
                    maxStages: 350,
                    displacement: 1500
                },
                {
                    id: "Baker_Hughes_ESP",   // 🔥 修正：使用字符串模型名
                    manufacturer: "Weatherford",
                    model: "RCH-1000",
                    series: "600",
                    minFlow: 1000,
                    maxFlow: 12000,
                    headPerStage: 35,
                    powerPerStage: 4.5,
                    efficiency: 75,
                    outerDiameter: 5.62,
                    shaftDiameter: 1.25,
                    maxStages: 300,
                    displacement: 2000
                }
            ]
        }
        return []
    }

    function getFilteredPumps() {
        console.log('调用了getFilteredPumps，当前availablePumps长度:', availablePumps.length)

        var filtered = availablePumps
        var originalLength = filtered.length

        // 制造商筛选
        if (manufacturerFilter.currentIndex > 0) {
            var manufacturer = manufacturerFilter.currentText
            console.log("制造商筛选:", manufacturer)
            filtered = filtered.filter(function(pump) {
                return pump.manufacturer === manufacturer
            })
        }

        // 系列筛选
        if (seriesFilter.currentIndex > 0) {
            var series = seriesFilter.currentText.split(" ")[0]
            console.log("系列筛选:", series)
            filtered = filtered.filter(function(pump) {
                return pump.series === series
            })
        }

        // 🔥 基于Step2预测结果的约束筛选
        var requiredProduction = 0
        var requiredHead = 0

        if (stepData.prediction && stepData.prediction.finalValues) {
            requiredProduction = stepData.prediction.finalValues.production || 0
            requiredHead = stepData.prediction.finalValues.totalHead || 0
        } else if (constraints.minProduction && constraints.maxProduction) {
            var minProd = constraints.minProduction
            var maxProd = constraints.maxProduction

            if (minProd < 1) {
                minProd = minProd * 1000
                maxProd = maxProd * 1000
            }

            requiredProduction = (minProd + maxProd) / 2
            requiredHead = constraints.pumpDepth || constraints.totalHead || 0
        }

        if (requiredProduction > 0) {
            console.log("产量约束筛选:", requiredProduction, "bbl/d")
            filtered = filtered.filter(function(pump) {
                var pumpCanHandle = pump.minFlow <= requiredProduction * 1.2 && pump.maxFlow >= requiredProduction * 0.8
                console.log("泵", pump.model, "流量范围:", pump.minFlow, "-", pump.maxFlow, "匹配:", pumpCanHandle)
                return pumpCanHandle
            })
        }

        if (requiredHead > 0) {
            console.log("扬程约束筛选:", requiredHead, "ft")
            filtered = filtered.filter(function(pump) {
                var requiredStages = Math.ceil(requiredHead / pump.headPerStage)
                var canProvideHead = requiredStages <= pump.maxStages
                console.log("泵", pump.model, "所需级数:", requiredStages, "最大级数:", pump.maxStages, "匹配:", canProvideHead)
                return canProvideHead
            })
        }

        console.log(`筛选结果: ${originalLength} -> ${filtered.length}`)
        return filtered
    }

    function calculatePumpMatchScore(pump) {
        if (!pump) return 50

        var score = 100
        console.log("计算泵匹配度:", pump.model)

        // 🔥 使用Step2预测结果进行匹配评分
        var requiredProduction = 0
        var requiredHead = 0

        if (stepData.prediction && stepData.prediction.finalValues) {
            requiredProduction = stepData.prediction.finalValues.production || 0
            requiredHead = stepData.prediction.finalValues.totalHead || 0
            console.log("使用Step2预测结果:", requiredProduction, "bbl/d,", requiredHead, "ft")
        } else {
            // 备用：使用约束条件
            var minProd = constraints.minProduction || 1000
            var maxProd = constraints.maxProduction || 3000

            if (minProd < 1) {
                minProd = minProd * 1000
                maxProd = maxProd * 1000
            }

            requiredProduction = (minProd + maxProd) / 2
            requiredHead = constraints.pumpDepth || constraints.totalHead || 2000
            console.log("使用约束条件:", requiredProduction, "bbl/d,", requiredHead, "ft")
        }

        // 1. 流量匹配度 (权重: 40%)
        if (requiredProduction > 0) {
            if (requiredProduction < pump.minFlow || requiredProduction > pump.maxFlow) {
                score -= 30
                console.log("流量超出范围，减分30")
            } else {
                var bestEfficiencyFlow = (pump.minFlow + pump.maxFlow) / 2
                var flowDeviation = Math.abs(requiredProduction - bestEfficiencyFlow) / bestEfficiencyFlow
                var flowPenalty = flowDeviation * 20
                score -= flowPenalty
                console.log("流量偏差:", flowDeviation.toFixed(3), "减分:", flowPenalty.toFixed(1))
            }
        }

        // 2. 扬程匹配度 (权重: 35%)
        if (requiredHead > 0 && pump.headPerStage > 0) {
            var requiredStages = Math.ceil(requiredHead / pump.headPerStage)
            if (requiredStages > pump.maxStages) {
                score -= 40
                console.log("所需级数超过最大级数，减分40")
            } else {
                // 理想级数范围是最大级数的20%-80%
                var idealMinStages = pump.maxStages * 0.2
                var idealMaxStages = pump.maxStages * 0.8

                if (requiredStages < idealMinStages) {
                    score -= (idealMinStages - requiredStages) / idealMinStages * 15
                } else if (requiredStages > idealMaxStages) {
                    score -= (requiredStages - idealMaxStages) / (pump.maxStages - idealMaxStages) * 20
                }

                console.log("所需级数:", requiredStages, "理想范围:", idealMinStages.toFixed(0), "-", idealMaxStages.toFixed(0))
            }
        }

        // 3. 效率加分 (权重: 15%)
        var efficiencyBonus = (pump.efficiency - 65) * 0.5  // 效率超过65%的部分加分
        score += efficiencyBonus
        console.log("效率加分:", efficiencyBonus.toFixed(1))

        // 4. 外径限制 (权重: 10%)
        var casingSize = parseFloat(stepData.well?.casingSize || "5.5")
        var clearance = casingSize - pump.outerDiameter
        if (clearance < 0.5) {
            score -= 30  // 间隙不足
            console.log("外径过大，减分30")
        } else if (clearance < 1.0) {
            score -= 10  // 间隙紧张
            console.log("外径偏大，减分10")
        }

        var finalScore = Math.max(0, Math.min(100, Math.round(score)))
        console.log("最终匹配度:", finalScore)

        return finalScore
    }

    function updateStepData() {
        if (!selectedPump) return

        var totalHead = selectedStages * selectedPump.headPerStage
        var totalPower = selectedStages * selectedPump.powerPerStage

        var data = {
            selectedPump: selectedPump.id,
            manufacturer: selectedPump.manufacturer,
            model: selectedPump.model,
            stages: selectedStages,
            totalHead: totalHead,
            totalPower: totalPower,
            efficiency: selectedPump.efficiency,
            shaftDiameter: selectedPump.shaftDiameter,
            specifications: (isChineseMode ? "型号: " : "Model: ") + selectedPump.model +
                            ", " + selectedStages + (isChineseMode ? " 级" : " stages") +
                            ", " + totalHead + " ft @ " + selectedPump.efficiency + "%"
        }

        console.log("=== Step4 发射数据更新信号 ===")
        console.log("数据内容:", JSON.stringify(data))

        root.dataChanged(data)
    }

    function filterPumps() {
        console.log("触发筛选")
        // 强制触发Repeater重新计算model
        var newFiltered = getFilteredPumps()
        console.log("筛选后数据:", newFiltered.length, "个")
    }

    // 数据收集函数
    function collectStepData() {
        return {
            selectedPump: selectedPump ? selectedPump.id : null,
            manufacturer: selectedPump ? selectedPump.manufacturer : "",
            model: selectedPump ? selectedPump.model : "",
            stages: selectedStages,
            totalHead: selectedPump ? selectedStages * selectedPump.headPerStage : 0,
            totalPower: selectedPump ? selectedStages * selectedPump.powerPerStage : 0,
            efficiency: selectedPump ? selectedPump.efficiency : 0
        }
    }

    // 在 Step4 的函数定义部分添加：
    function openPerformanceAnalysisPage() {
        if (!selectedPump) {
            console.warn("未选择泵，无法打开性能分析页面")
            return
        }

        // 创建性能分析页面
        var component = Qt.createComponent("../PumpPerformanceAnalysisPage.qml")
        if (component.status === Component.Ready) {
            var analysisPage = component.createObject(root.parent, {
                pumpData: selectedPump,
                stages: selectedStages,
                frequency: 60,
                isChineseMode: root.isChineseMode
            })

            if (analysisPage) {
                // 连接返回信号
                analysisPage.backRequested.connect(function() {
                    analysisPage.destroy()
                })

                // 连接配置变化信号
                analysisPage.pumpConfigurationChanged.connect(function(stages, frequency) {
                    selectedStages = stages
                    updateStepData()
                    console.log("从性能分析页面更新配置:", stages, "级,", frequency, "Hz")
                })

                // 显示页面
                analysisPage.visible = true
                console.log("性能分析页面已打开")
            }
        } else if (component.status === Component.Error) {
            console.error("无法创建性能分析页面:", component.errorString())
        }
    }

    // 🔥 新增函数：自动计算级数
    function autoCalculateStages() {
        if (!selectedPump) return

        console.log("=== 自动计算级数 ===")

        // 获取需求扬程
        var requiredHead = getRequiredTotalHead()
        console.log("需求扬程:", requiredHead, "ft")

        if (requiredHead <= 0) {
            console.warn("需求扬程无效，使用默认级数")
            selectedStages = Math.min(50, selectedPump.maxStages)
            return
        }

        // 计算所需级数
        var calculatedStages = Math.ceil(requiredHead / selectedPump.headPerStage)
        console.log("计算得出级数:", calculatedStages)

        // 确保级数在有效范围内
        var minStages = 1
        var maxStages = selectedPump.maxStages || 100

        if (calculatedStages < minStages) {
            selectedStages = minStages
            console.log("级数过小，设置为最小值:", minStages)
        } else if (calculatedStages > maxStages) {
            selectedStages = maxStages
            console.log("级数超过最大值，设置为最大值:", maxStages)

            // 警告：级数不足
            var actualHead = selectedStages * selectedPump.headPerStage
            console.warn("警告：所选泵无法提供足够扬程")
            console.warn("需求扬程:", requiredHead, "ft, 实际能提供:", actualHead, "ft")
        } else {
            selectedStages = calculatedStages
            console.log("设置级数为:", calculatedStages)
        }

        // 验证计算结果
        var totalHead = selectedStages * selectedPump.headPerStage
        console.log("最终级数:", selectedStages, "总扬程:", totalHead, "ft")

        // 更新滑块值（触发UI更新）
        if (stagesSlider) {
            stagesSlider.value = selectedStages
        }
    }

    // 🔥 新增函数：获取需求扬程
    function getRequiredTotalHead() {
        // 优先使用Step2的预测结果
        if (stepData.prediction && stepData.prediction.finalValues && stepData.prediction.finalValues.totalHead) {
            var predictedHead = stepData.prediction.finalValues.totalHead
            console.log("使用Step2预测扬程:", predictedHead, "ft")
            return predictedHead
        }

        // 备用：使用约束条件
        if (constraints.totalHead && constraints.totalHead > 0) {
            console.log("使用约束条件扬程:", constraints.totalHead, "ft")
            return constraints.totalHead
        }

        if (constraints.pumpDepth && constraints.pumpDepth > 0) {
            console.log("使用泵挂深度:", constraints.pumpDepth, "ft")
            return constraints.pumpDepth
        }

        console.warn("无法获取需求扬程")
        return 0
    }
    // 监听选中泵的变化
    onSelectedPumpChanged: {
        if (selectedPump) {
            console.log("选中泵发生变化:", selectedPump.model)
            // 延迟执行，确保界面已更新
            autoCalculateTimer.start()
        }
    }

    // 🔥 自动计算定时器
    Timer {
        id: autoCalculateTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (selectedPump) {
                autoCalculateStages()
                updateStepData()
            }
        }
    }
}
