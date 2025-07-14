// Qt_Oil_NewContent/DeviceRecommendation/DeviceRecommendationPage.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "./Components"

Page {
    id: root
    
    // 属性定义
    property int projectId: -1
    property int wellId: -1
    property bool isChineseMode: true
    property var controller: deviceRecommendationController
    
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
    property var stepData: ({})  // 存储每步的数据
    property var selectionConstraints: ({})  // 存储步骤间的约束
    
    // 修复第100行左右的onPredictionCompleted
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
            stepData["prediction"] = results
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
        
        // 顶部工具栏
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
                        // 如果当前步骤组件已加载，则直接更新其wellId
                        if (stepLoader.item) {
                            stepLoader.item.wellId = currentValue

                            // 如果是第一步，调用loadParameters方法
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
                
                // 保存草稿按钮
                Button {
                    text: isChineseMode ? "保存草稿" : "Save Draft"
                    flat: true
                    onClicked: saveDraft()
                }
                
                // 导出按钮（仅在最后一步显示）
                Button {
                    text: isChineseMode ? "导出报告" : "Export Report"
                    visible: currentStep === steps.length - 1
                    highlighted: true
                    onClicked: exportReport()
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
            Layout.preferredHeight: 100
            
            steps: root.steps
            currentStep: root.currentStep
            
            onStepClicked: function(index) {
                if (canNavigateToStep(index)) {
                    navigateToStep(index)
                }
            }
        }
        
        // 主内容区域
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#f5f7fa"
            // 使用 StackView 来管理页面
            StackView {
                id: pageStackView
                anchors.fill: parent

                initialItem: RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

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
                            anchors.margins: 24
                            source: steps[currentStep].component

                            onLoaded: {
                                if (item) {
                                    item.controller = controller
                                    item.isChineseMode = root.isChineseMode
                                    item.wellId = root.wellId
                                    item.stepData = root.stepData
                                    item.constraints = root.selectionConstraints

                                    // 如果是第一步且有参数加载方法，则调用它
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
                                    // 连接性能分析页面打开信号
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

                    // 右侧面板（选型方案摘要）
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

                            Text {
                                text: isChineseMode ? "选型方案摘要" : "Selection Summary"
                                font.pixelSize: 16
                                font.bold: true
                                color: Material.primaryTextColor
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
                                        //model: getSelectedDevices()
                                        model: {
                                            summaryPanel.dataUpdateTrigger  // 强制依赖这个属性
                                            return getSelectedDevices()     // 重新调用函数
                                        }

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
                                                    text: modelData.specs
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
        
        // 底部导航栏
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
                
                // 步骤进度文本
                Text {
                    text: (isChineseMode ? "步骤 " : "Step ") + (currentStep + 1) + " / " + steps.length
                    color: Material.hintTextColor
                    font.pixelSize: 14
                }
                
                Item { Layout.fillWidth: true }
                
                // 上一步按钮
                Button {
                    text: isChineseMode ? "上一步" : "Previous"
                    enabled: currentStep > 0
                    onClicked: previousStep()
                }
                
                // 下一步/完成按钮
                Button {
                    text: currentStep < steps.length - 1 
                          ? (isChineseMode ? "下一步" : "Next")
                          : (isChineseMode ? "完成" : "Finish")
                    highlighted: true
                    enabled: true
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
    
    // Connections
    Connections {
        target: controller
        enabled: controller !== null
        function onWellsListLoaded(wells) {
            wellsModel.clear()
            for (var i = 0; i < wells.length; i++) {
                wellsModel.append(wells[i])
            }
            
            // 自动选择第一个有参数的井
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
    
    // 函数定义
    function nextStep() {
        if (currentStep < steps.length - 1) {
            console.log("=== nextStep 被调用，当前步骤:", currentStep, "===")
            
            // 收集当前步骤数据
            if (stepLoader.item && typeof stepLoader.item.collectStepData === "function") {
                var currentStepId = steps[currentStep].id
                var currentData = stepLoader.item.collectStepData()
                console.log("收集的数据:", JSON.stringify(currentData))
                updateStepData(currentStepId, currentData)
            }
            
            // 添加延迟确保数据同步完成
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
        stepData[stepId] = data
        console.log("这里是选择举升方式后的updateStepData更新后:", JSON.stringify(stepData))

        // 触发右侧面板更新的条件
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
    }
    
    function getSelectedDevices() {
        var devices = []
        console.log("=== getSelectedDevices 被调用 ===")
        console.log("当前 stepData:", JSON.stringify(stepData))
    
        
        if (stepData["lift_method"]) {
            devices.push({
                type: isChineseMode ? "举升方式" : "Lift Method",
                name: stepData["lift_method"].methodName,
                specs: ""
            })
        }
        
        if (stepData["pump"]) {
            devices.push({
                type: isChineseMode ? "泵" : "Pump",
                name: stepData["pump"].model,
                specs: stepData["pump"].specifications
            })
        }
        
        if (stepData["separator"]) {
            devices.push({
                type: isChineseMode ? "分离器" : "Separator",
                name: stepData["separator"].model,
                specs: stepData["separator"].specifications
            })
        }
        
        if (stepData["protector"]) {
            devices.push({
                type: isChineseMode ? "保护器" : "Protector",
                name: stepData["protector"].model,
                specs: stepData["protector"].specifications
            })
        }
        
        if (stepData["motor"]) {
            devices.push({
                type: isChineseMode ? "电机" : "Motor",
                name: stepData["motor"].model,
                specs: stepData["motor"].specifications
            })
        }
        
        return devices
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
        messageLoader.setSource("../Components/MessageDialog.qml", {
            "message": text,
            "messageType": type,
            "autoClose": true,
            "duration": 3000
        })
    }
    // 修改 openPerformanceAnalysisPage 函数

    function openPerformanceAnalysisPage() {
        if (!selectedPump) {
            console.warn("未选择泵，无法打开性能分析页面")
            return
        }

        // 使用新的 Window 组件
        var component = Qt.createComponent("../PumpPerformanceAnalysisWindow.qml")
        if (component.status === Component.Ready) {
            var analysisWindow = component.createObject(null, {
                pumpData: selectedPump,
                stages: selectedStages,
                frequency: 60,
                isChineseMode: root.isChineseMode
            })

            if (analysisWindow) {
                // 连接返回信号
                analysisWindow.backRequested.connect(function() {
                    analysisWindow.close()
                    analysisWindow.destroy()
                })

                // 连接配置变化信号
                analysisWindow.pumpConfigurationChanged.connect(function(stages, frequency) {
                    selectedStages = stages
                    updateStepData()
                    console.log("从性能分析窗口更新配置:", stages, "级,", frequency, "Hz")
                })

                console.log("性能分析窗口已打开")
            }
        } else if (component.status === Component.Error) {
            console.error("无法创建性能分析窗口:", component.errorString())
        }
    }
}
