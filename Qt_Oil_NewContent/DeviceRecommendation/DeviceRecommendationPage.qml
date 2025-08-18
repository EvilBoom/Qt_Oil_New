import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "./Components"
import "../Common/Components" as CommonComponents

Page {
    id: root

    // 属性定义
    property int projectId: -1
    property int wellId: -1
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性
    property var controller: deviceRecommendationController

    // 🔥 新增：全局设备列表，持久保存选择的设备
    property var selectedDevices: []

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("DeviceRecommendationPage中单位制切换为:", isMetric ? "公制" : "英制")

            // 通知当前步骤组件单位制发生变化
            if (stepLoader.item) {
                stepLoader.item.isMetric = isMetric
            }
        }
    }

    // 🔥 监听stepData变化，实时更新当前步骤组件
    onStepDataChanged: {
        console.log("=== stepData 发生变化 ===")
        // console.log("新的 stepData:", JSON.stringify(stepData))
        // 🔥 stepData变化时更新设备列表
        updateSelectedDevices()

        // 更新当前加载的步骤组件的stepData
        if (stepLoader.item) {
            console.log("=== 更新当前步骤组件的stepData ===")
            stepLoader.item.stepData = stepData
        }
    }

    onProjectIdChanged: {
        console.log("DeviceRecommendationPage - projectId 变更为:", projectId)
        if (projectId > 0 && controller) {
            console.log("加载井列表数据...")
            controller.loadWellsWithParameters(projectId)
        }
    }

    // 步骤定义
    property var steps: [
        {
            "id": "parameters",
            "title": isChineseMode ? "生产参数录入" : "Production Parameters",
            "icon": "📝",
            "component": "Steps/Step1_ProductionParameters.qml"
        },
        {
            "id": "prediction",
            "title": isChineseMode ? "预测与IPR曲线" : "Prediction & IPR Curve",
            "icon": "📊",
            "component": "Steps/Step2_PredictionResults.qml"
        },
        {
            "id": "lift_method",
            "title": isChineseMode ? "举升方式选择" : "Lift Method Selection",
            "icon": "🔧",
            "component": "Steps/Step3_LiftMethodSelection.qml"
        },
        {
            "id": "pump",
            "title": isChineseMode ? "泵型选择" : "Pump Selection",
            "icon": "⚙️",
            "component": "Steps/Step4_PumpSelection.qml"
        },
        {
            "id": "separator",
            "title": isChineseMode ? "分离器选择" : "Separator Selection",
            "icon": "🔄",
            "component": "Steps/Step5_SeparatorSelection.qml"
        },
        {
            "id": "protector",
            "title": isChineseMode ? "保护器选择" : "Protector Selection",
            "icon": "🛡️",
            "component": "Steps/Step6_ProtectorSelection.qml"
        },
        {
            "id": "motor",
            "title": isChineseMode ? "电机选择" : "Motor Selection",
            "icon": "⚡",
            "component": "Steps/Step7_MotorSelection.qml"
        },
        {
            "id": "report",
            "title": isChineseMode ? "选型报告" : "Selection Report",
            "icon": "📄",
            "component": "Steps/Step8_ReportGeneration.qml"
        }
    ]

    property int currentStep: 0
    property var stepData: ({})
    property var selectionConstraints: ({})

    // 其他 Connections 保持不变...
    Connections {
        target: deviceRecommendationController
        enabled: deviceRecommendationController !== undefined

        onParametersLoaded: {
            console.log("生产参数加载完成")
        }

        onParametersSaved: function(id) {
            console.log("生产参数保存成功，ID:", id)
            showMessage(isChineseMode ? "保存成功" : "Saved successfully", "success")
        }

        onParametersError: function(error) {
            showMessage(error, "error")
        }

        onPredictionCompleted: function(results) {
            console.log("=== 主页面收到预测完成信号 ===")
            console.log("results:", JSON.stringify(results))
            // 🔥 修复：触发stepData变化
            var newStepData = {}
            for (var key in stepData) {
                newStepData[key] = stepData[key]
            }
            newStepData["prediction"] = results
            stepData = newStepData  // 这样会触发onStepDataChanged

            // stepData["prediction"] = results
            updateConstraints("prediction", results)
        }

        onPredictionProgress: function(progress) {
            if (stepLoader.item && stepLoader.item.updateProgress) {
                stepLoader.item.updateProgress(progress)
            }
        }
    }

    // 页面布局
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 🔥 修改顶部工具栏，添加单位切换器
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Material.background

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                // 返回按钮
                Button {
                    icon.source: "qrc:/images/back.png"
                    text: isChineseMode ? "返回" : "Back"
                    flat: true
                    onClicked: {
                        if (currentStep > 0) {
                            previousStep()
                        }
                    }
                    enabled: currentStep > 0
                }

                Item { Layout.fillWidth: true }

                // 🔥 添加单位切换器
                // CommonComponents.UnitSwitcher {
                //     isChinese: root.isChineseMode
                //     showLabel: true
                //     labelText: isChineseMode ? "单位:" : "Units:"
                // }

                // 井选择下拉框
                ComboBox {
                    id: wellSelector
                    Layout.preferredWidth: 200
                    model: ListModel { id: wellsModel }
                    textRole: "name"
                    valueRole: "id"

                    displayText: currentIndex >= 0 ? model.get(currentIndex).name
                                                   : (isChineseMode ? "请选择井" : "Select Well")

                    onActivated: {
                        root.wellId = currentValue
                        controller.currentWellId = currentValue
                        console.log("DeviceRecommendationPage initialized, projectId:", projectId)
                        console.log("Loading wells for project:", projectId)
                        controller.loadWellsWithParameters(projectId)

                        console.log("currentValue",currentValue)
                        if (stepLoader.item) {
                            stepLoader.item.wellId = currentValue

                            if (currentStep === 0 && typeof stepLoader.item.loadParameters === "function") {
                                stepLoader.item.loadParameters()
                            }
                        }
                    }

                    Component.onCompleted: {
                        console.log("DeviceRecommendationPage initialized, projectId:", projectId)

                        if (projectId > 0) {
                            console.log("Loading wells for project:", projectId)
                            controller.loadWellsWithParameters(projectId)
                        } else {
                            console.warn("Invalid projectId:", projectId)
                        }
                    }
                }

                // 刷新井列表按钮
                Button {
                    text: isChineseMode ? "🔄 刷新井列表" : "🔄 Refresh Wells"
                    flat: true
                    onClicked: {
                        if (typeof wellController !== 'undefined' && typeof projectId !== 'undefined') {
                            controller.loadWellsWithParameters(projectId)
                            showMessage(isChineseMode ? "正在刷新井列表..." : "Refreshing well list...", false)
                        } else {
                            showMessage(isChineseMode ? "无法刷新井列表" : "Cannot refresh well list", true)
                        }
                    }
                }

                // 导出按钮（仅在最后一步显示）
                // Button {
                //     id: exportReportButton
                //     text: isChineseMode ? "导出报告" : "Export Report"
                //     background: Rectangle {
                //             color: exportReportButton.pressed ? "#2a5cad" :
                //                    exportReportButton.hovered ? "#3a7cdb" :
                //                    "#3465a4"
                //             radius: 6
                //             border.color: exportReportButton.hovered ? "#81a2be" : "#5c85b6"
                //             border.width: 1
                //     }
                //     visible: currentStep === steps.length - 1
                //     highlighted: true
                //     onClicked: exportReport()
                // }
                // 知识图谱按钮（从Step3开始显示）
                Button {
                    id: knowledgeGraphButton
                    text: "🧠 " + (isChineseMode ? "知识图谱" : "Knowledge Graph")
                    flat: true
                    visible: currentStep >= 2  // 从Step3开始显示
                    Material.foreground: Material.primary

                    background: Rectangle {
                        color: knowledgeGraphButton.pressed ? Material.color(Material.Blue, Material.Shade100) :
                               knowledgeGraphButton.hovered ? Material.color(Material.Blue, Material.Shade50) :
                               "transparent"
                        radius: 6
                        border.color: Material.primary
                        border.width: 1
                    }

                    onClicked: openKnowledgeGraphWindow()
                }
            }

            // 底部分隔线
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Material.dividerColor
            }
        }

        // 步骤指示器
        StepIndicator {
            id: stepIndicator
            Layout.fillWidth: true
            Layout.preferredHeight: 60

            steps: root.steps
            currentStep: root.currentStep

            onStepClicked: function(index) {
                if (canNavigateToStep(index)) {
                    navigateToStep(index)
                }
            }
        }

        // 主内容区域 - 🔥 修改选型方案摘要，添加单位显示
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#f5f7fa"

            StackView {
                id: pageStackView
                anchors.fill: parent

                initialItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 2

                    // 步骤内容加载器
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Material.background
                        radius: 8

                        layer.enabled: true

                        Loader {
                            id: stepLoader
                            anchors.fill: parent
                            anchors.margins: 4
                            source: steps[currentStep].component

                            onLoaded: {
                                if (item) {
                                    console.log("=== stepLoader 组件加载完成 ===")
                                    // console.log("当前步骤:", currentStep, "组件:", steps[currentStep].component)
                                    // console.log("当前 stepData:", JSON.stringify(stepData))
                                    // console.log("传递的 controller:", controller)
                                    // console.log("controller 类型:", typeof controller)
                                    // console.log("controller 是否为null:", controller === null)

                                    // 🔥 确保控制器存在再传递
                                    if (controller !== null && controller !== undefined) {
                                        item.controller = controller
                                        console.log("✅ 控制器传递成功")
                                    } else {
                                        console.error("❌ 控制器为空，无法传递")
                                        // 🔥 尝试直接使用全局控制器
                                        if (typeof deviceRecommendationController !== 'undefined' && deviceRecommendationController !== null) {
                                            console.log("🔄 尝试使用全局控制器")
                                            item.controller = deviceRecommendationController
                                        }
                                    }

                                    item.controller = controller
                                    item.isChineseMode = root.isChineseMode
                                    item.isMetric = root.isMetric  // 🔥 传递单位制信息
                                    item.wellId = root.wellId
                                    item.stepData = root.stepData
                                    item.constraints = root.selectionConstraints

                                    // 🔥 步骤加载完成后立即打印传递的数据
                                    // console.log("=== 传递给步骤组件的数据 ===")
                                    // console.log("wellId:", root.wellId)
                                    // console.log("stepData:", JSON.stringify(root.stepData))
                                    // console.log("constraints:", JSON.stringify(root.selectionConstraints))
                                    // console.log("最终传递的controller:", item.controller)

                                    if (currentStep === 0 && item.loadParameters && root.wellId > 0) {
                                        item.loadParameters()
                                    }

                                    // 连接信号
                                    if (item.nextStepRequested) {
                                        item.nextStepRequested.connect(nextStep)
                                    }
                                    if (item.dataChanged) {
                                        item.dataChanged.connect(function(data) {
                                            updateStepData(steps[currentStep].id, data)
                                        })
                                    }
                                    if (item.openPerformanceAnalysis) {
                                        item.openPerformanceAnalysis.connect(function(pumpData, stages, frequency) {
                                            openPerformanceAnalysisPage(pumpData, stages, frequency)
                                        })
                                    }
                                }
                            }
                        }

                        // 加载指示器
                        BusyIndicator {
                            anchors.centerIn: parent
                            running: controller.busy
                            visible: running
                        }
                    }

                    // 🔥 修改右侧面板，添加单位显示支持
                    Rectangle {
                        id: summaryPanel
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        color: Material.background
                        radius: 8
                        visible: currentStep > 1

                        property int dataUpdateTrigger: 0

                        layer.enabled: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: isChineseMode ? "选型方案摘要" : "Selection Summary"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Item { Layout.fillWidth: true }

                                // 🔥 添加单位制显示标识
                                Rectangle {
                                    width: 60
                                    height: 20
                                    radius: 10
                                    color: root.isMetric ? Material.color(Material.Green, Material.Shade100) :
                                                          Material.color(Material.Blue, Material.Shade100)

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isMetric ? (isChineseMode ? "公制" : "Metric") :
                                                            (isChineseMode ? "英制" : "Imperial")
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: root.isMetric ? Material.color(Material.Green) :
                                                              Material.color(Material.Blue)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Material.dividerColor
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Column {
                                    width: parent.width
                                    spacing: 12

                                    Repeater {
                                        model: root.selectedDevices
                                        // {
                                            // summaryPanel.dataUpdateTrigger
                                            // return getSelectedDevices()
                                        // }

                                        Rectangle {
                                            width: parent.width
                                            height: childrenRect.height + 16
                                            color: Material.dialogColor
                                            radius: 4

                                            Column {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Text {
                                                    text: modelData.type
                                                    font.pixelSize: 12
                                                    color: Material.hintTextColor
                                                }

                                                Text {
                                                    text: modelData.name
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: Material.primaryTextColor
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }

                                                Text {
                                                    text: convertSpecsToCurrentUnit(modelData.specs)  // 🔥 转换规格中的单位
                                                    font.pixelSize: 12
                                                    color: Material.secondaryTextColor
                                                    wrapMode: Text.Wrap
                                                    width: parent.width
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

        // 底部导航栏 - 保持不变
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Material.background

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: Material.dividerColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24

                Text {
                    text: (isChineseMode ? "步骤 " : "Step ") + (currentStep + 1) + " / " + steps.length
                    color: Material.hintTextColor
                    font.pixelSize: 14
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: isChineseMode ? "上一步" : "Previous"
                    enabled: currentStep > 0
                    onClicked: previousStep()
                }

                Button {
                    text: currentStep < steps.length - 1
                          ? (isChineseMode ? "下一步" : "Next")
                          : (isChineseMode ? "完成" : "Finish")
                    enabled: true
                    background: Rectangle {
                            color: exportReportButton.pressed ? "#2a5cad" :
                                   exportReportButton.hovered ? "#3a7cdb" :
                                   "#3465a4"
                            radius: 6
                            border.color: exportReportButton.hovered ? "#81a2be" : "#5c85b6"
                            border.width: 1
                    }
                    onClicked: {
                        if (currentStep < steps.length - 1) {
                            nextStep()
                        } else {
                            finishSelection()
                        }
                    }
                }
            }
        }
    }

    // 消息提示组件
    Loader {
        id: messageLoader
        anchors.centerIn: parent
        z: 1000
    }

    // Connections - 井列表加载（保持不变）
    Connections {
        target: controller
        enabled: controller !== null
        function onWellsListLoaded(wells) {
            wellsModel.clear()
            for (var i = 0; i < wells.length; i++) {
                wellsModel.append(wells[i])
            }

            for (var j = 0; j < wells.length; j++) {
                if (wells[j].hasParameters) {
                    wellSelector.currentIndex = j
                    root.wellId = wells[j].id
                    controller.currentWellId = wells[j].id
                    break
                }
            }
        }
    }

    // 🔥 添加单位转换函数
    function convertSpecsToCurrentUnit(specs) {
        if (!specs || typeof specs !== "string") return specs

        var convertedSpecs = specs

        // 使用正则表达式查找并转换常见的单位
        if (root.isMetric) {
            // 英制 → 公制转换
            // 流量: bbl/d → m³/d
            convertedSpecs = convertedSpecs.replace(/(\d+(?:\.\d+)?)\s*bbl\/d/g, function(match, value) {
                var converted = (parseFloat(value) * 0.159).toFixed(2)
                return converted + " m³/d"
            })

            // 扬程: ft → m
            convertedSpecs = convertedSpecs.replace(/(\d+(?:\.\d+)?)\s*ft/g, function(match, value) {
                var converted = (parseFloat(value) * 0.3048).toFixed(1)
                return converted + " m"
            })

            // 压力: psi → kPa
            convertedSpecs = convertedSpecs.replace(/(\d+(?:\.\d+)?)\s*psi/g, function(match, value) {
                var converted = (parseFloat(value) * 6.895).toFixed(0)
                return converted + " kPa"
            })

            // 直径: in → mm
            convertedSpecs = convertedSpecs.replace(/(\d+(?:\.\d+)?)\s*in/g, function(match, value) {
                var converted = (parseFloat(value) * 25.4).toFixed(1)
                return converted + " mm"
            })
        }
        // 如果当前是英制，数据库中本来就是英制，不需要转换

        return convertedSpecs
    }

    // 其他函数保持不变...
    function nextStep() {
        if (currentStep < steps.length - 1) {
            console.log("=== nextStep 被调用，当前步骤:", currentStep, "===")

            if (stepLoader.item && typeof stepLoader.item.collectStepData === "function") {
                var currentStepId = steps[currentStep].id
                var currentData = stepLoader.item.collectStepData()
                console.log("收集的数据:", JSON.stringify(currentData))
                updateStepData(currentStepId, currentData)
            }

            Qt.callLater(function() {
                if (validateCurrentStep()) {
                    currentStep++
                    console.log("=== 步骤已切换到:", currentStep, "===")
                }
            })
        }
    }

    function previousStep() {
        if (currentStep > 0) {
            currentStep--
        }
    }

    function navigateToStep(index) {
        if (index >= 0 && index < steps.length && index !== currentStep) {
            currentStep = index
        }
    }

    function canNavigateToStep(index) {
        if (index <= currentStep + 1) {
            return true
        }

        for (var i = 0; i <= index; i++) {
            if (!stepData[steps[i].id]) {
                return false
            }
        }

        return true
    }

    function canProceedToNext() {
        var currentStepId = steps[currentStep].id

        if (currentStepId === "separator" || currentStepId === "protector") {
            return true
        }

        return stepData[currentStepId] !== undefined
    }

    function validateCurrentStep() {
        return true
    }

    function updateStepData(stepId, data) {
        console.log("=== updateStepData ===", stepId)
        // console.log("更新前的 stepData:", JSON.stringify(stepData))

        // 🔥 修复：正确的对象复制和更新逻辑
        var newStepData = {}

        // 复制现有数据
        for (var key in stepData) {
            newStepData[key] = stepData[key]
        }


        // 🔥 关键修复：在新对象中更新数据
        newStepData[stepId] = data

        // 🔥 重新赋值触发属性变化
        stepData = newStepData  // 这样会触发onStepDataChanged

        console.log("这里是选择举升方式后的updateStepData更新后:", JSON.stringify(stepData))

        if (stepId === "lift_method" || stepId === "pump" || stepId === "separator" ||
            stepId === "protector" || stepId === "motor"){
            summaryPanel.dataUpdateTrigger++
            console.log("=== 触发右侧面板更新 ===", stepId, summaryPanel.dataUpdateTrigger)
        }

        if (stepLoader.item) {
            stepLoader.item.stepData = stepData
        }
    }

    function updateConstraints(stepId, data) {
        if (stepId === "prediction") {
            selectionConstraints["minProduction"] = data.mlResults.production * 0.8
            selectionConstraints["maxProduction"] = data.mlResults.production * 1.2
            selectionConstraints["pumpDepth"] = data.mlResults.pump_depth

            selectionConstraints["totalHead"] = data.mlResults.total_head  // 🔥 使用total_head
            console.log("=== 约束条件已更新 ===")
            console.log("产量范围:", selectionConstraints["minProduction"], "-", selectionConstraints["maxProduction"])
            console.log("扬程:", selectionConstraints["totalHead"])

        } else if (stepId === "lift_method") {
            selectionConstraints["liftMethod"] = data.selectedMethod
        } else if (stepId === "pump") {
            selectionConstraints["pumpModel"] = data.selectedPump
            selectionConstraints["shaftDiameter"] = data.shaftDiameter
            selectionConstraints["totalPower"] = data.totalPower
            selectionConstraints["pumpEfficiency"] = data.efficiency
        } else if (stepId === "separator") {
            selectionConstraints["separatorModel"] = data.selectedSeparator
        } else if (stepId === "protector") {
            selectionConstraints["protectorModel"] = data.selectedProtector
        } else if (stepId === "motor") {
            selectionConstraints["motorModel"] = data.selectedMotor
            selectionConstraints["motorPower"] = data.power
            selectionConstraints["motorVoltage"] = data.voltage
            selectionConstraints["motorFrequency"] = data.frequency
        }
        console.log("最终约束条件:", JSON.stringify(selectionConstraints))
    }

    function getSelectedDevices() {
        return selectedDevices  // 🔥 直接返回全局设备列表
        // var devices = []
        // console.log("=== getSelectedDevices 被调用 ===")
        // console.log("当前 stepData:", JSON.stringify(stepData))

        // if (stepData["lift_method"]) {
        //     devices.push({
        //         type: isChineseMode ? "举升方式" : "Lift Method",
        //         name: stepData["lift_method"].methodName,
        //         specs: ""
        //     })
        // }

        // if (stepData["pump"]) {
        //     devices.push({
        //         type: isChineseMode ? "泵" : "Pump",
        //         name: stepData["pump"].model,
        //         stages: stepData["pump"].stages

        //     })
        // }

        // if (stepData["separator"]) {
        //     devices.push({
        //         type: isChineseMode ? "分离器" : "Separator",
        //         name: stepData["separator"].model,
        //         specs: stepData["separator"].specifications
        //     })
        // }

        // if (stepData["protector"]) {
        //     devices.push({
        //         type: isChineseMode ? "保护器" : "Protector",
        //         name: stepData["protector"].model,
        //         specs: stepData["protector"].specifications
        //     })
        // }

        // if (stepData["motor"]) {
        //     devices.push({
        //         type: isChineseMode ? "电机" : "Motor",
        //         name: stepData["motor"].model,
        //         specs: stepData["motor"].specifications
        //     })
        // }

        // return devices
    }

    function saveDraft() {
        console.log("保存草稿:", JSON.stringify(stepData))
        showMessage(isChineseMode ? "草稿已保存" : "Draft saved", "info")
    }

    function exportReport() {
        console.log("导出报告")
        if (stepLoader.item && stepLoader.item.exportReport) {
            stepLoader.item.exportReport()
        }
    }

    function finishSelection() {
        console.log("完成选型")
        showMessage(isChineseMode ? "选型方案已生成" : "Selection completed", "success")
    }

    function showMessage(text, type) {
        messageLoader.setSource("../Common/Components/MessageDialog.qml", {
            "messageText": text,        // 🔥 修复：使用正确的属性名
            "messageType": type,
            "autoClose": true,
            "autoCloseDelay": 3000     // 🔥 修复：使用正确的属性名
            })
    
            // 🔥 确保组件加载完成后显示
            if (messageLoader.item) {
                messageLoader.item.open()
            }
    }

    // 🔥 修复：正确的性能分析页面函数，创建独立窗口
    function openPerformanceAnalysisPage(pumpData, stages, frequency) {
        console.log("=== 打开性能分析窗口 ===")
        console.log("泵数据:", JSON.stringify(pumpData))
        console.log("级数:", stages)
        console.log("频率:", frequency)

        if (!pumpData) {
            console.warn("未选择泵，无法打开性能分析页面")
            showMessage(isChineseMode ? "请先选择泵型" : "Please select a pump first", "warning")
            return
        }

        // 🔥 直接创建性能分析窗口
        var windowComponent = Qt.createComponent("./Components/EnhancedPumpCurvesChart.qml")

        if (windowComponent.status === Component.Loading) {
            console.log("窗口组件正在加载...")
            windowComponent.statusChanged.connect(function() {
                if (windowComponent.status === Component.Ready) {
                    createAnalysisWindow(windowComponent, pumpData, stages, frequency)
                } else if (windowComponent.status === Component.Error) {
                    console.error("窗口组件加载失败:", windowComponent.errorString())
                    showMessage(isChineseMode ? "无法打开性能分析窗口" : "Cannot open performance analysis window", "error")
                }
            })
        } else if (windowComponent.status === Component.Ready) {
            createAnalysisWindow(windowComponent, pumpData, stages, frequency)
        } else if (windowComponent.status === Component.Error) {
            console.error("无法创建性能分析窗口组件:", windowComponent.errorString())
            showMessage(isChineseMode ? "性能分析功能暂时不可用" : "Performance analysis temporarily unavailable", "error")
        }
    }

    function createAnalysisWindow(component, pumpData, stages, frequency) {
        try {
            var analysisWindow = component.createObject(null, {
                pumpData: pumpData,
                stages: stages || 1,
                frequency: frequency || 60,
                isChineseMode: root.isChineseMode,
                isMetric: root.isMetric
            })

            if (analysisWindow) {
                console.log("✅ 性能分析窗口创建成功")

                // 连接返回信号
                analysisWindow.backRequested.connect(function() {
                    console.log("接收到返回信号，关闭窗口")
                    analysisWindow.close()
                    analysisWindow.destroy()
                })

                // 连接配置变化信号
                analysisWindow.pumpConfigurationChanged.connect(function(newStages, newFrequency) {
                    console.log("从性能分析窗口更新配置:", newStages, "级,", newFrequency, "Hz")

                    // 🔥 更新当前Step4的配置
                    if (stepLoader.item && stepLoader.item.updatePumpConfiguration) {
                        stepLoader.item.updatePumpConfiguration(newStages, newFrequency)
                    }

                    // 更新stepData
                    if (stepData.pump) {
                        var updatedPumpData = Object.assign({}, stepData.pump)
                        updatedPumpData.stages = newStages
                        updatedPumpData.frequency = newFrequency
                        updateStepData("pump", updatedPumpData)
                    }
                })

                // 连接窗口关闭信号
                analysisWindow.windowClosed.connect(function() {
                    console.log("性能分析窗口已关闭")
                    analysisWindow.destroy()
                })

                console.log("性能分析窗口已显示")
            } else {
                console.error("性能分析窗口创建失败")
                showMessage(isChineseMode ? "无法创建性能分析窗口" : "Cannot create performance analysis window", "error")
            }
        } catch (error) {
            console.error("创建性能分析窗口时出错:", error)
            showMessage(isChineseMode ? "性能分析页面打开失败" : "Failed to open performance analysis", "error")
        }
    }
    // 🔥 新增：模态对话框替代方案
    function showPerformanceAnalysisDialog(pumpData, stages, frequency) {
        console.log("=== 显示性能分析对话框（替代方案）===")

        var dialogComponent = Qt.createComponent("Components/PerformanceAnalysisDialog.qml")
        if (dialogComponent.status === Component.Ready) {
            var dialog = dialogComponent.createObject(root, {
                pumpData: pumpData,
                stages: stages,
                frequency: frequency,
                isChineseMode: root.isChineseMode,
                isMetric: root.isMetric
            })

            if (dialog) {
                dialog.open()
                console.log("性能分析对话框已打开")
            }
        } else {
            // 最终后备方案：显示基本信息
            showBasicPumpInfo(pumpData, stages, frequency)
        }
    }

    // 🔥 新增：基本信息显示后备方案
    function showBasicPumpInfo(pumpData, stages, frequency) {
        var infoText = (isChineseMode ? "泵型信息\n" : "Pump Information\n") +
                       (isChineseMode ? "制造商: " : "Manufacturer: ") + (pumpData.manufacturer || "N/A") + "\n" +
                       (isChineseMode ? "型号: " : "Model: ") + (pumpData.model || "N/A") + "\n" +
                       (isChineseMode ? "级数: " : "Stages: ") + (stages || "N/A") + "\n" +
                       (isChineseMode ? "频率: " : "Frequency: ") + (frequency || 60) + " Hz\n" +
                       (isChineseMode ? "详细性能分析功能暂时不可用" : "Detailed performance analysis temporarily unavailable")

        showMessage(infoText, "info")
    }
    // 🔥 新增：更新全局设备列表的函数
    function updateSelectedDevices() {
        console.log("=== updateSelectedDevices 被调用 ===")

        var devices = []

        // 🔥 检查并添加各种设备
        if (stepData["lift_method"]) {
            var existing = findDeviceByType("lift_method")
            if (!existing) {
                devices.push({
                    type: isChineseMode ? "举升方式" : "Lift Method",
                    name: stepData["lift_method"].methodName,
                    specs: "",
                    stepId: "lift_method"
                })
            } else {
                existing.name = stepData["lift_method"].methodName
                devices.push(existing)
            }
        }

        if (stepData["pump"]) {
            var existing = findDeviceByType("pump")
            if (!existing) {
                devices.push({
                    type: isChineseMode ? "泵" : "Pump",
                    name: stepData["pump"].model,
                    specs: stepData["pump"].specifications || "",
                    stepId: "pump"
                })
            } else {
                existing.name = stepData["pump"].model
                existing.specs = stepData["pump"].specifications || ""
                devices.push(existing)
            }
        }

        if (stepData["separator"]) {
            var existing = findDeviceByType("separator")
            if (!existing) {
                devices.push({
                    type: isChineseMode ? "分离器" : "Separator",
                    name: stepData["separator"].model,
                    specs: stepData["separator"].specifications || "",
                    stepId: "separator"
                })
            } else {
                existing.name = stepData["separator"].model
                existing.specs = stepData["separator"].specifications || ""
                devices.push(existing)
            }
        }

        if (stepData["protector"]) {
            var existing = findDeviceByType("protector")
            if (!existing) {
                devices.push({
                    type: isChineseMode ? "保护器" : "Protector",
                    name: stepData["protector"].model,
                    specs: stepData["protector"].specifications || "",
                    stepId: "protector"
                })
            } else {
                existing.name = stepData["protector"].model
                existing.specs = stepData["protector"].specifications || ""
                devices.push(existing)
            }
        }

        if (stepData["motor"]) {
            var existing = findDeviceByType("motor")
            if (!existing) {
                devices.push({
                    type: isChineseMode ? "电机" : "Motor",
                    name: stepData["motor"].model,
                    specs: stepData["motor"].specifications || "",
                    stepId: "motor"
                })
            } else {
                existing.name = stepData["motor"].model
                existing.specs = stepData["motor"].specifications || ""
                devices.push(existing)
            }
        }

        // 🔥 更新全局设备列表
        selectedDevices = devices

        console.log("设备列表已更新，共", devices.length, "个设备")
    }
    // 🔥 辅助函数：查找已存在的设备
    function findDeviceByType(stepId) {
        for (var i = 0; i < selectedDevices.length; i++) {
            if (selectedDevices[i].stepId === stepId) {
                return selectedDevices[i]
            }
        }
        return null
    }
    // 🔥 新增：打开知识图谱窗口（修复版本）
    function openKnowledgeGraphWindow() {
        console.log("=== 打开知识图谱窗口 ===")
        console.log("当前步骤:", currentStep, "步骤ID:", steps[currentStep].id)

        // 🔥 使用相对路径，确保文件能被找到
        var windowComponent = Qt.createComponent("Components/KnowledgeGraphWindow.qml")

        if (windowComponent.status === Component.Loading) {
            console.log("知识图谱窗口组件正在加载...")
            windowComponent.statusChanged.connect(function() {
                if (windowComponent.status === Component.Ready) {
                    createKnowledgeGraphWindow(windowComponent)
                } else if (windowComponent.status === Component.Error) {
                    console.error("知识图谱窗口组件加载失败:", windowComponent.errorString())
                    showMessage(isChineseMode ? "无法打开知识图谱窗口: " + windowComponent.errorString() : "Cannot open knowledge graph window: " + windowComponent.errorString(), "error")
                }
            })
        } else if (windowComponent.status === Component.Ready) {
            createKnowledgeGraphWindow(windowComponent)
        } else if (windowComponent.status === Component.Error) {
            console.error("无法创建知识图谱窗口组件:", windowComponent.errorString())
            showMessage(isChineseMode ? "知识图谱功能暂时不可用: " + windowComponent.errorString() : "Knowledge graph temporarily unavailable: " + windowComponent.errorString(), "error")
        }
    }

    function createKnowledgeGraphWindow(component) {
        try {
            var knowledgeWindow = component.createObject(null, {
                isChineseMode: root.isChineseMode,
                isMetric: root.isMetric,
                currentStepData: root.stepData,
                currentStepId: steps[currentStep].id,
                selectionConstraints: root.selectionConstraints
            })

            if (knowledgeWindow) {
                console.log("✅ 知识图谱窗口创建成功")

                // 连接窗口关闭信号
                knowledgeWindow.windowClosed.connect(function() {
                    console.log("知识图谱窗口已关闭")
                    knowledgeWindow.destroy()
                })

                // 连接推荐接受信号
                knowledgeWindow.recommendationAccepted.connect(function(recommendation) {
                    console.log("接收到知识图谱推荐:", JSON.stringify(recommendation))
                    handleKnowledgeGraphRecommendation(recommendation)
                })

                // 显示窗口
                knowledgeWindow.show()
                knowledgeWindow.raise()
                knowledgeWindow.requestActivate()

                console.log("知识图谱窗口已显示")
            } else {
                console.error("知识图谱窗口创建失败")
                showMessage(isChineseMode ? "无法创建知识图谱窗口" : "Cannot create knowledge graph window", "error")
            }
        } catch (error) {
            console.error("创建知识图谱窗口时出错:", error)
            showMessage(isChineseMode ? "知识图谱窗口打开失败: " + error : "Failed to open knowledge graph window: " + error, "error")
        }
    }
    // 🔥 新增：处理知识图谱推荐
    function handleKnowledgeGraphRecommendation(recommendation) {
        console.log("处理知识图谱推荐:", JSON.stringify(recommendation))

        try {
            // 根据推荐类型执行相应操作
            if (recommendation.method) {
                // 举升方式推荐
                if (stepLoader.item && typeof stepLoader.item.applyRecommendation === "function") {
                    stepLoader.item.applyRecommendation(recommendation)
                }
            } else if (recommendation.pumpType) {
                // 泵型推荐
                if (stepLoader.item && typeof stepLoader.item.applyPumpRecommendation === "function") {
                    stepLoader.item.applyPumpRecommendation(recommendation)
                }
            } else if (recommendation.optimizationType) {
                // 优化建议
                applyOptimizationRecommendation(recommendation)
            }

            showMessage(isChineseMode ? "推荐建议已应用" : "Recommendation applied", "success")

        } catch (error) {
            console.error("应用推荐建议时出错:", error)
            showMessage(isChineseMode ? "应用推荐失败" : "Failed to apply recommendation", "error")
        }
    }

    function applyOptimizationRecommendation(recommendation) {
        console.log("应用优化建议:", recommendation.optimizationType)

        // 更新约束条件
        if (recommendation.optimizationType === "efficiency") {
            selectionConstraints["minEfficiency"] = recommendation.minEfficiency
            console.log("更新效率约束:", recommendation.minEfficiency)
        }

        // 通知当前步骤组件约束条件已更新
        if (stepLoader.item) {
            stepLoader.item.constraints = selectionConstraints
        }
    }
}
