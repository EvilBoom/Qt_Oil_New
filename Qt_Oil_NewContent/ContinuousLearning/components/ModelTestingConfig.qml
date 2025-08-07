import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

pragma ComponentBehavior: Bound

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    property var continuousLearningController
    property bool _initialized: false
    
    // 监听 continuousLearningController 的变化
    onContinuousLearningControllerChanged: {
        console.log("=== ModelTestingConfig: continuousLearningController changed ===")
        console.log("New controller:", continuousLearningController)
        console.log("Controller type:", typeof continuousLearningController)
        console.log("Controller is null?", continuousLearningController === null)
        console.log("Controller is undefined?", continuousLearningController === undefined)
        
        if (continuousLearningController && !_initialized) {
            _initialized = true
            console.log("Controller became available, initializing...")
            Qt.callLater(function() {
                refreshDataTables()
                updateFinalInputFeatures()
                addLog(isChinese ? "模型测试配置页面已加载，控制器已初始化" : "Model testing configuration page loaded, controller initialized")
            })
        }
    }
    
    // 配置相关属性
    property string selectedTask: ""           // 选择的测试任务
    property string selectedModel: ""          // 选择的模型
    property string selectedModelPath: ""      // 选择的模型文件路径
    property string modelType: ""              // 模型类型（local/file/folder）
    property var availableDataTables: []       // data开头的表
    property var availableTestTables: []       // test开头的表  
    property var selectedDataTables: []        // 选择的数据表
    property var commonFeatures: []            // 共有特征列
    property var selectedFeatures: []          // 选择的输入特征
    property string targetLabel: ""            // 预测标签
    property var modelExpectedFeatures: []     // 模型期望的特征名称列表
    property var featureMapping: ({})          // 模型特征 -> 用户特征的映射
    property var finalInputFeatures: []        // 最终传入模型的特征列表（按模型期望顺序）
    property bool configurationComplete: false // 配置是否完成
    
    signal backRequested()
    signal startTestingRequested()
    
    // 计算属性：获取最终的特征配置
    function getFinalFeatureConfiguration() {
        if (root.modelExpectedFeatures.length > 0) {
            // 如果模型有特定的特征要求，使用映射后的特征
            let finalFeatures = []
            for (let expectedFeature of root.modelExpectedFeatures) {
                let mappedFeature = root.featureMapping[expectedFeature]
                if (mappedFeature && mappedFeature !== "") {
                    finalFeatures.push(mappedFeature)
                }
            }
            return {
                inputFeatures: finalFeatures,
                featureOrder: root.modelExpectedFeatures,
                mappingRequired: true
            }
        } else {
            // 如果模型没有特定要求，使用用户选择的特征
            return {
                inputFeatures: root.selectedFeatures,
                featureOrder: root.selectedFeatures,
                mappingRequired: false
            }
        }
    }
    
    // 供外部调用的完整配置获取方法
    function getCompleteConfiguration() {
        let featureConfig = getFinalFeatureConfiguration()
        return {
            task: root.selectedTask,
            model: root.selectedModel,
            modelPath: root.selectedModelPath,
            modelType: root.modelType,
            dataTables: root.selectedDataTables,
            inputFeatures: featureConfig.inputFeatures,
            featureOrder: featureConfig.featureOrder,
            targetLabel: root.targetLabel,
            featureMapping: root.featureMapping,
            mappingRequired: featureConfig.mappingRequired,
            projectId: root.currentProjectId
        }
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: availableWidth
        contentHeight: mainColumn.implicitHeight
        clip: true
        
        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 24
            
            // 页面标题
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: root.isChinese ? "模型测试配置" : "Model Testing Configuration"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#212529"
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: root.isChinese ? "返回" : "Back"
                    onClicked: root.backRequested()
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#dee2e6"
            }
            
            // 第一步：选择测试任务
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Text {
                    text: root.isChinese ? "步骤 1：选择测试任务" : "Step 1: Select Testing Task"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#495057"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 80
                    implicitHeight: taskSelectionColumn.implicitHeight + 32
                    color: "white"
                    radius: 8
                    border.width: 1
                    border.color: "#dee2e6"
                    
                    ColumnLayout {
                        id: taskSelectionColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        Text {
                            text: root.isChinese ? "请选择要测试的任务类型：" : "Please select the task type to test:"
                            font.pixelSize: 14
                            color: "#6c757d"
                        }
                        
                        RowLayout {
                            spacing: 24
                            
                            RadioButton {
                                text: root.isChinese ? "扬程预测" : "Head Prediction"
                                checked: root.selectedTask === "扬程预测" || root.selectedTask === "Head Prediction"
                                onCheckedChanged: {
                                    if (checked) {
                                        root.selectedTask = root.isChinese ? "扬程预测" : "Head Prediction"
                                        console.log("Task selected:", root.selectedTask)
                                        if (root.continuousLearningController) {
                                            let taskKey = root.getTaskKey(root.selectedTask)
                                            console.log("Task key:", taskKey)
                                            let expectedFeatures = root.continuousLearningController.getModelExpectedFeatures(taskKey)
                                            console.log("Expected features for task:", expectedFeatures)
                                            root.modelExpectedFeatures = expectedFeatures
                                            root.updateFeatureMapping()
                                        } else {
                                            console.log("Controller not available")
                                        }
                                        root.addLog(root.isChinese ? "已选择扬程预测任务" : "Head prediction task selected")
                                        // 自动匹配预测标签
                                        root.autoMatchTargetLabel()
                                    }
                                }
                            }
                            
                            RadioButton {
                                text: root.isChinese ? "产量预测" : "Production Prediction"
                                checked: root.selectedTask === "产量预测" || root.selectedTask === "Production Prediction"
                                onCheckedChanged: {
                                    if (checked) {
                                        root.selectedTask = root.isChinese ? "产量预测" : "Production Prediction"
                                        console.log("Task selected:", root.selectedTask)
                                        if (root.continuousLearningController) {
                                            let taskKey = root.getTaskKey(root.selectedTask)
                                            console.log("Task key:", taskKey)
                                            let expectedFeatures = root.continuousLearningController.getModelExpectedFeatures(taskKey)
                                            console.log("Expected features for task:", expectedFeatures)
                                            root.modelExpectedFeatures = expectedFeatures
                                            root.updateFeatureMapping()
                                        } else {
                                            console.log("Controller not available")
                                        }
                                        root.addLog(root.isChinese ? "已选择产量预测任务" : "Production prediction task selected")
                                        // 自动匹配预测标签
                                        root.autoMatchTargetLabel()
                                    }
                                }
                            }
                            
                            RadioButton {
                                text: root.isChinese ? "气液比预测" : "GLR Prediction"
                                checked: root.selectedTask === "气液比预测" || root.selectedTask === "GLR Prediction"
                                onCheckedChanged: {
                                    if (checked) {
                                        root.selectedTask = root.isChinese ? "气液比预测" : "GLR Prediction"
                                        console.log("Task selected:", root.selectedTask)
                                        if (root.continuousLearningController) {
                                            let taskKey = root.getTaskKey(root.selectedTask)
                                            console.log("Task key:", taskKey)
                                            let expectedFeatures = root.continuousLearningController.getModelExpectedFeatures(taskKey)
                                            console.log("Expected features for task:", expectedFeatures)
                                            root.modelExpectedFeatures = expectedFeatures
                                            root.updateFeatureMapping()
                                        } else {
                                            console.log("Controller not available")
                                        }
                                        root.addLog(root.isChinese ? "已选择气液比预测任务" : "GLR prediction task selected")
                                        // 自动匹配预测标签
                                        root.autoMatchTargetLabel()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#e9ecef"
            }
            
            // 第二步：选择待测试的模型
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Text {
                    text: root.isChinese ? "步骤 2：选择待测试的模型" : "Step 2: Select Model to Test"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#495057"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 160
                    implicitHeight: modelSelectionColumn.implicitHeight + 32
                    color: "white"
                    radius: 8
                    border.width: 1
                    border.color: "#dee2e6"
                    
                    ColumnLayout {
                        id: modelSelectionColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        
                        Text {
                            text: root.isChinese ? "选择模型来源：" : "Select model source:"
                            font.pixelSize: 14
                            color: "#6c757d"
                        }
                        
                        RowLayout {
                            spacing: 16
                            
                            // 本地训练模型选择
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 80
                                implicitHeight: localModelColumn.implicitHeight + 24
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 6
                                
                                ColumnLayout {
                                    id: localModelColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? "本地训练模型" : "Local Trained Models"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    ComboBox {
                                        id: localModelComboBox
                                        Layout.fillWidth: true
                                        
                                        property var availableModels: []
                                        
                                        model: availableModels
                                        currentIndex: -1
                                        
                                        // 修复displayText问题
                                        displayText: {
                                            if (currentIndex >= 0 && currentIndex < availableModels.length) {
                                                return availableModels[currentIndex]
                                            }
                                            return root.isChinese ? "请选择本地模型..." : "Select local model..."
                                        }
                                        
                                        onCurrentIndexChanged: {
                                            if (currentIndex >= 0 && currentIndex < availableModels.length) {
                                                let selectedModelName = availableModels[currentIndex]
                                                root.selectedModel = selectedModelName
                                                root.modelType = "local"
                                                root.addLog(root.isChinese ? `已选择本地模型: ${selectedModelName}` : `Selected local model: ${selectedModelName}`)
                                                
                                                // 获取模型的完整文件路径
                                                if (root.continuousLearningController) {
                                                    let modelPath = root.continuousLearningController.getModelPath(selectedModelName)
                                                    if (modelPath && modelPath.length > 0) {
                                                        root.addLog(root.isChinese ? `模型路径: ${modelPath}` : `Model path: ${modelPath}`)
                                                        // 将完整路径保存到selectedModel中，以便后续使用
                                                        root.selectedModelPath = modelPath
                                                    } else {
                                                        root.addLog(root.isChinese ? `警告: 未找到模型 ${selectedModelName} 的文件路径` : `Warning: Could not find file path for model ${selectedModelName}`)
                                                    }
                                                }
                                                
                                                // 清除外部模型选择
                                                externalModelPath.text = root.getExternalModelHint()
                                                externalModelPath.color = "#6c757d"
                                                
                                                // 获取模型期望特征
                                                if (root.selectedTask && root.continuousLearningController) {
                                                    console.log("Getting expected features for task:", root.selectedTask)
                                                    let taskKey = root.getTaskKey(root.selectedTask)
                                                    console.log("Task key:", taskKey)
                                                    let expectedFeatures = root.continuousLearningController.getModelExpectedFeatures(taskKey)
                                                    console.log("Expected features:", expectedFeatures)
                                                    root.modelExpectedFeatures = expectedFeatures
                                                    root.updateFeatureMapping()
                                                } else {
                                                    console.log("Task not selected or controller not available")
                                                }
                                            }
                                        }
                                        
                                        Component.onCompleted: {
                                            refreshLocalModels()
                                        }
                                        
                                        function refreshLocalModels() {
                                            if (root.continuousLearningController) {
                                                try {
                                                    let models = root.continuousLearningController.getAvailableModels()
                                                    availableModels = models || []
                                                    console.log("Available models:", availableModels)
                                                    root.addLog(root.isChinese ? 
                                                        `发现 ${availableModels.length} 个本地模型` : 
                                                        `Found ${availableModels.length} local models`)
                                                } catch (error) {
                                                    console.log("Error loading models:", error)
                                                    availableModels = []
                                                    root.addLog(root.isChinese ? 
                                                        `加载本地模型失败: ${error}` : 
                                                        `Failed to load local models: ${error}`)
                                                }
                                            } else {
                                                availableModels = []
                                                root.addLog(root.isChinese ? "控制器未初始化" : "Controller not initialized")
                                            }
                                        }
                                    }
                                    
                                    Button {
                                        text: root.isChinese ? "刷新模型列表" : "Refresh Models"
                                        onClicked: localModelComboBox.refreshLocalModels()
                                    }
                                }
                            }
                            
                            // 外部模型选择（文件或文件夹）
                            Rectangle {
                                Layout.preferredWidth: 300
                                Layout.minimumHeight: 80
                                implicitHeight: externalModelColumn.implicitHeight + 24
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 6
                                
                                ColumnLayout {
                                    id: externalModelColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? "外部模型" : "External Model"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    Button {
                                        Layout.fillWidth: true
                                        text: root.getExternalModelButtonText()
                                        onClicked: {
                                            if (root.isTaskRequiringFolder()) {
                                                modelFolderDialog.open()
                                            } else {
                                                modelFolderDialog.open()
                                            }
                                        }
                                    }
                                    
                                    Text {
                                        id: externalModelPath
                                        Layout.fillWidth: true
                                        text: root.getExternalModelHint()
                                        font.pixelSize: 10
                                        color: "#6c757d"
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#e9ecef"
            }
            
            // 第三步：选择测试数据
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Text {
                    text: root.isChinese ? "步骤 3：选择测试数据" : "Step 3: Select Test Data"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#495057"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 250
                    implicitHeight: testDataRow.implicitHeight + 32
                    color: "white"
                    radius: 8
                    border.width: 1
                    border.color: "#dee2e6"
                    
                    RowLayout {
                        id: testDataRow
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        // 数据表选择
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            RowLayout {
                                Text {
                                    text: root.isChinese ? "选择测试数据表" : "Select Test Data Tables"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: root.isChinese ? "刷新" : "Refresh"
                                    onClicked: root.refreshDataTables()
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 150
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ListView {
                                    id: dataTablesListView
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    model: root.availableDataTables
                                    
                                    delegate: CheckBox {
                                        required property var modelData
                                        width: dataTablesListView.width
                                        text: modelData
                                        checked: root.selectedDataTables.includes(modelData)
                                        onCheckedChanged: {
                                            if (checked) {
                                                if (!root.selectedDataTables.includes(modelData)) {
                                                    root.selectedDataTables = [...root.selectedDataTables, modelData]
                                                }
                                            } else {
                                                root.selectedDataTables = root.selectedDataTables.filter(t => t !== modelData)
                                            }
                                            root.updateCommonFeatures()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 共有特征显示
                        ColumnLayout {
                            Layout.preferredWidth: 200
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "共有特征" : "Common Features"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Text {
                                text: root.isChinese ? `共 ${root.commonFeatures.length} 个特征` : `${root.commonFeatures.length} features total`
                                font.pixelSize: 14
                                color: "#6c757d"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 150
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    model: root.commonFeatures
                                    
                                    delegate: Text {
                                        required property string modelData
                                        width: parent.width
                                        text: modelData
                                        font.pixelSize: 11
                                        color: "#495057"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#e9ecef"
            }
            
            // 第四步：特征选择和对齐
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                Text {
                    text: root.isChinese ? "步骤 4：特征选择和对齐" : "Step 4: Feature Selection and Alignment"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#495057"
                }
                
                Text {
                    text: {
                        if (root.modelExpectedFeatures.length > 0) {
                            return root.isChinese ? 
                                "注意：您的模型有特定的特征要求。请在下方完成特征映射以确保特征顺序与模型期望一致。" :
                                "Note: Your model has specific feature requirements. Please complete the feature mapping below to ensure feature order matches model expectations."
                        } else {
                            return root.isChinese ? 
                                "请选择用于模型输入的特征。所选特征将直接传递给模型。" :
                                "Please select features for model input. Selected features will be passed directly to the model."
                        }
                    }
                    font.pixelSize: 14
                    color: "#6c757d"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 280
                    implicitHeight: featureSelectionRow.implicitHeight + 32
                    color: "white"
                    radius: 8
                    border.width: 1
                    border.color: "#dee2e6"
                    
                    RowLayout {
                        id: featureSelectionRow
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        // 输入特征选择
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "选择输入特征" : "Select Input Features"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 200
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ListView {
                                    id: inputFeaturesList
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    model: root.commonFeatures.filter(f => f !== root.targetLabel)
                                    
                                    delegate: CheckBox {
                                        required property var modelData
                                        width: inputFeaturesList.width
                                        text: modelData
                                        
                                        property bool isChecked: root.selectedFeatures.includes(modelData)
                                        checked: isChecked
                                        
                                        onCheckedChanged: {
                                            if (checked !== isChecked) {
                                                if (checked) {
                                                    if (!root.selectedFeatures.includes(modelData)) {
                                                        root.selectedFeatures = [...root.selectedFeatures, modelData]
                                                    }
                                                } else {
                                                    root.selectedFeatures = root.selectedFeatures.filter(f => f !== modelData)
                                                }
                                                root.updateFeatureMapping()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            RowLayout {
                                Button {
                                    text: root.isChinese ? "全选" : "Select All"
                                    onClicked: {
                                        root.selectedFeatures = root.commonFeatures.filter(f => f !== root.targetLabel)
                                        root.updateFeatureMapping()
                                    }
                                }
                                
                                Button {
                                    text: root.isChinese ? "清空" : "Clear All"
                                    onClicked: {
                                        root.selectedFeatures = []
                                        root.updateFeatureMapping()
                                    }
                                }
                            }
                        }
                        
                        // 目标标签选择
                        ColumnLayout {
                            Layout.preferredWidth: 180
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "选择预测标签" : "Select Prediction Label"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 200
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ListView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    model: root.commonFeatures
                                    
                                    delegate: RadioButton {
                                        required property string modelData
                                        width: parent.width
                                        text: modelData
                                        checked: root.targetLabel === modelData
                                        onCheckedChanged: {
                                            if (checked) {
                                                root.targetLabel = modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#e9ecef"
            }
            
            // 第五步：特征映射（如果需要）
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: root.modelExpectedFeatures.length > 0 && root.selectedDataTables.length > 0
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#e9ecef"
                }
                
                Text {
                    text: root.isChinese ? "步骤 5：特征映射" : "Step 5: Feature Mapping"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#495057"
                }
                
                // 调试信息显示
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 20
                    implicitHeight: debugText.implicitHeight + 16
                    color: "#f0f0f0"
                    border.width: 1
                    border.color: "#ccc"
                    visible: true  // 强制显示以便调试
                    
                    Text {
                        id: debugText
                        anchors.centerIn: parent
                        text: `调试: modelExpectedFeatures.length=${root.modelExpectedFeatures.length}, selectedDataTables.length=${root.selectedDataTables.length}`
                        font.pixelSize: 10
                        color: "#666"
                    }
                }
                
                Text {
                    text: root.isChinese ? 
                        "请将数据中的特征映射到模型期望的输入特征。这一步骤确保您的数据特征能正确对应到模型的输入要求：" :
                        "Map your data features to model expected input features. This step ensures your data features correctly correspond to the model's input requirements:"
                    font.pixelSize: 14
                    color: "#6c757d"
                    wrapMode: Text.WordWrap
                }
                
                // 映射状态提示
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 32
                    implicitHeight: mappingStatusRow.implicitHeight + 24
                    color: root.checkFeatureMappingComplete() ? "#d1f2eb" : "#fff3cd"
                    border.width: 1
                    border.color: root.checkFeatureMappingComplete() ? "#28a745" : "#ffc107"
                    radius: 6
                    
                    RowLayout {
                        id: mappingStatusRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        Rectangle {
                            Layout.preferredWidth: 12
                            Layout.preferredHeight: 12
                            radius: 6
                            color: root.checkFeatureMappingComplete() ? "#28a745" : "#ffc107"
                        }
                        
                        Text {
                            text: {
                                if (root.modelExpectedFeatures.length === 0) {
                                    return root.isChinese ? "模型无特征要求" : "Model has no feature requirements"
                                } else if (root.checkFeatureMappingComplete()) {
                                    return root.isChinese ? "特征映射完成" : "Feature mapping complete"
                                } else {
                                    let unmappedCount = root.modelExpectedFeatures.filter(f => !(root.featureMapping[f] && root.featureMapping[f] !== "")).length
                                    return root.isChinese ? 
                                        `还有 ${unmappedCount} 个特征需要映射` :
                                        `${unmappedCount} features still need mapping`
                                }
                            }
                            font.pixelSize: 14
                            font.bold: true
                            color: "#495057"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: root.isChinese ? "自动映射" : "Auto Map"
                            onClicked: root.autoMapFeatures()
                            visible: !root.checkFeatureMappingComplete()
                            implicitHeight: 28
                        }
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 200
                    implicitHeight: Math.max(200, featureMappingScrollView.contentHeight + 16)
                    color: "white"
                    radius: 8
                    border.width: 1
                    border.color: "#dee2e6"
                    
                    ScrollView {
                        id: featureMappingScrollView
                        anchors.fill: parent
                        anchors.margins: 8
                        contentWidth: Math.max(availableWidth, featureMappingFlow.implicitWidth)
                        contentHeight: Math.max(availableHeight, featureMappingFlow.implicitHeight)
                        
                        Flow {
                            id: featureMappingFlow
                            width: parent.width
                            spacing: 12
                            
                            Repeater {
                                model: root.modelExpectedFeatures
                                
                                delegate: Rectangle {
                                    id: mappingDelegate
                                    required property string modelData
                                    required property int index
                                    
                                    property string expectedFeature: modelData
                                    
                                    width: 280
                                    height: 80
                                    border.width: 1
                                    border.color: "#dee2e6"
                                    radius: 6
                                    color: {
                                        let mapping = root.featureMapping[mappingDelegate.expectedFeature] || ""
                                        return mapping === "" ? "#fff3cd" : "#d1f2eb"
                                    }
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4
                                        
                                        Text {
                                            text: root.isChinese ? `模型特征: ${mappingDelegate.expectedFeature}` : `Model Feature: ${mappingDelegate.expectedFeature}`
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#495057"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            
                                            Text {
                                                text: root.isChinese ? "映射到:" : "Maps to:"
                                                font.pixelSize: 10
                                                color: "#6c757d"
                                            }
                                            
                                            ComboBox {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 28
                                                
                                                property var dropdownModel: {
                                                    let baseList = [root.isChinese ? "请选择..." : "Select..."]
                                                    let filteredFeatures = root.commonFeatures.filter(f => f !== root.targetLabel)
                                                    return baseList.concat(filteredFeatures)
                                                }
                                                
                                                model: dropdownModel
                                                
                                                property string currentMapping: root.featureMapping[mappingDelegate.expectedFeature] || ""
                                                
                                                onCurrentMappingChanged: {
                                                    if (currentMapping === "") {
                                                        currentIndex = 0
                                                    } else {
                                                        let mappingIndex = dropdownModel.indexOf(currentMapping)
                                                        if (mappingIndex >= 0) {
                                                            currentIndex = mappingIndex
                                                        }
                                                    }
                                                }
                                                
                                                Component.onCompleted: {
                                                    let initialMapping = root.featureMapping[mappingDelegate.expectedFeature] || ""
                                                    if (initialMapping === "") {
                                                        currentIndex = 0
                                                    } else {
                                                        let mappingIndex = dropdownModel.indexOf(initialMapping)
                                                        if (mappingIndex >= 0) {
                                                            currentIndex = mappingIndex
                                                        }
                                                    }
                                                }
                                                
                                                onCurrentTextChanged: {
                                                    if (currentText !== undefined && currentIndex > 0) {
                                                        let newMapping = Object.assign({}, root.featureMapping)
                                                        newMapping[mappingDelegate.expectedFeature] = currentText
                                                        root.featureMapping = newMapping
                                                    } else if (currentIndex === 0) {
                                                        let newMapping = Object.assign({}, root.featureMapping)
                                                        newMapping[mappingDelegate.expectedFeature] = ""
                                                        root.featureMapping = newMapping
                                                    }
                                                }
                                                
                                                font.pixelSize: 10
                                            }
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 12
                                                Layout.preferredHeight: 12
                                                radius: 6
                                                color: {
                                                    let mapping = root.featureMapping[mappingDelegate.expectedFeature] || ""
                                                    return mapping === "" ? "#dc3545" : "#28a745"
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            text: {
                                                let mapping = root.featureMapping[mappingDelegate.expectedFeature] || ""
                                                if (mapping === "") {
                                                    return root.isChinese ? "状态: 未映射" : "Status: Not mapped"
                                                } else {
                                                    return root.isChinese ? `状态: 已映射到 ${mapping}` : `Status: Mapped to ${mapping}`
                                                }
                                            }
                                            font.pixelSize: 9
                                            color: "#6c757d"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 配置总结和导航
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16
                
                Text {
                    text: root.isChinese ? "配置总结" : "Configuration Summary"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#495057"
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 120
                    implicitHeight: configSummaryColumn.implicitHeight + 32
                    color: "#f8f9fa"
                    border.width: 1
                    border.color: "#dee2e6"
                    radius: 6
                    
                    ColumnLayout {
                        id: configSummaryColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        
                        Text {
                            text: root.isChinese ? 
                                `• 测试任务: ${root.selectedTask || '未选择'}` :
                                `• Test Task: ${root.selectedTask || 'Not selected'}`
                            font.pixelSize: 14
                            color: "#495057"
                        }
                        
                        Text {
                            text: root.isChinese ? 
                                `• 测试模型: ${root.selectedModel || '未选择'} (${root.modelType || 'N/A'})` :
                                `• Test Model: ${root.selectedModel || 'Not selected'} (${root.modelType || 'N/A'})`
                            font.pixelSize: 14
                            color: "#495057"
                        }
                        
                        Text {
                            text: root.isChinese ? 
                                `• 测试数据表: ${root.selectedDataTables.length} 个` :
                                `• Test Data Tables: ${root.selectedDataTables.length}`
                            font.pixelSize: 14
                            color: "#495057"
                        }
                        
                        Text {
                            text: {
                                let featureConfig = root.getFinalFeatureConfiguration()
                                return root.isChinese ? 
                                    `• 最终输入特征: ${featureConfig.inputFeatures.length} 个` :
                                    `• Final Input Features: ${featureConfig.inputFeatures.length}`
                            }
                            font.pixelSize: 14
                            color: "#495057"
                        }
                        
                        Text {
                            text: root.isChinese ? 
                                `• 预测目标: ${root.targetLabel || '未选择'}` :
                                `• Target: ${root.targetLabel || 'Not selected'}`
                            font.pixelSize: 14
                            color: "#495057"
                        }
                        
                        Text {
                            text: {
                                let mappedCount = 0
                                for (let key in root.featureMapping) {
                                    if (root.featureMapping[key] !== "") {
                                        mappedCount++
                                    }
                                }
                                return root.isChinese ? 
                                    `• 特征映射: ${mappedCount}/${root.modelExpectedFeatures.length} 个` :
                                    `• Feature Mapping: ${mappedCount}/${root.modelExpectedFeatures.length}`
                            }
                            font.pixelSize: 14
                            color: "#495057"
                            visible: root.modelExpectedFeatures.length > 0
                        }
                        
                        Text {
                            text: {
                                let featureConfig = root.getFinalFeatureConfiguration()
                                if (featureConfig.inputFeatures.length > 0) {
                                    let featureList = featureConfig.inputFeatures.slice(0, 5).join(', ')
                                    if (featureConfig.inputFeatures.length > 5) {
                                        featureList += '...'
                                    }
                                    return root.isChinese ? 
                                        `• 特征列表: [${featureList}]` :
                                        `• Feature List: [${featureList}]`
                                } else {
                                    return root.isChinese ? "• 特征列表: 未配置" : "• Feature List: Not configured"
                                }
                            }
                            font.pixelSize: 11
                            color: "#6c757d"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                
                // 特征映射状态提示
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 32
                    implicitHeight: finalMappingStatusRow.implicitHeight + 24
                    color: {
                        if (root.modelExpectedFeatures.length === 0) return "transparent"
                        return root.checkFeatureMappingComplete() ? "#d1f2eb" : "#fff3cd"
                    }
                    border.width: 1
                    border.color: {
                        if (root.modelExpectedFeatures.length === 0) return "transparent"
                        return root.checkFeatureMappingComplete() ? "#28a745" : "#ffc107"
                    }
                    radius: 6
                    visible: root.modelExpectedFeatures.length > 0
                    
                    RowLayout {
                        id: finalMappingStatusRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        
                        Rectangle {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            radius: 8
                            color: root.checkFeatureMappingComplete() ? "#28a745" : "#ffc107"
                            
                            Text {
                                anchors.centerIn: parent
                                text: root.checkFeatureMappingComplete() ? "✓" : "!"
                                font.pixelSize: 10
                                font.bold: true
                                color: "white"
                            }
                        }
                        
                        Text {
                            text: {
                                if (root.checkFeatureMappingComplete()) {
                                    return root.isChinese ? "所有特征映射已完成，可以开始测试" : "All feature mappings completed, ready to test"
                                } else {
                                    return root.isChinese ? "请完成所有特征映射后再开始测试" : "Please complete all feature mappings before testing"
                                }
                            }
                            font.pixelSize: 14
                            color: "#495057"
                            Layout.fillWidth: true
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: root.isChinese ? "开始测试" : "Start Testing"
                        enabled: root.isConfigurationComplete()
                        
                        // 监控按钮状态变化
                        onEnabledChanged: {
                            console.log("=== 开始测试按钮状态变化 ===")
                            console.log("Enabled:", enabled)
                            console.log("isConfigurationComplete():", root.isConfigurationComplete())
                        }
                        
                        onClicked: {
                            console.log("=== 开始测试按钮被点击 ===")
                            console.log("Time:", new Date().toLocaleTimeString())
                            console.log("isConfigurationComplete():", root.isConfigurationComplete())
                            console.log("About to call validateConfiguration()...")
                            
                            if (root.validateConfiguration()) {
                                console.log("Configuration validation passed!")
                                root.configurationComplete = true
                                console.log("Emitting startTestingRequested signal...")
                                root.startTestingRequested()
                                console.log("startTestingRequested signal emitted")
                            } else {
                                console.log("Configuration validation failed!")
                            }
                        }
                        
                        font.pixelSize: 14
                        implicitHeight: 40
                        implicitWidth: 120
                        
                        ToolTip.visible: !enabled && hovered
                        ToolTip.text: root.getConfigurationErrorMessage()
                    }
                }
            }
        }
    }
    
    // 对话框
    FileDialog {
        id: modelFileDialog
        title: root.isChinese ? "选择模型文件" : "Select Model File"
        nameFilters: {
            if (root.selectedTask === "气液比预测" || root.selectedTask === "GLR Prediction") {
                return ["PyTorch model files (*.pth *.pt)", "All files (*)"]
            } else {
                return ["Model files (*.joblib *.pkl)", "All files (*)"]
            }
        }
        onAccepted: {
            let filePath = selectedFile.toString().replace("file:///", "")
            root.selectedModel = filePath
            root.modelType = "file"
            externalModelPath.text = root.isChinese ? 
                `已选择: ${filePath.split('/').pop()}` : 
                `Selected: ${filePath.split('/').pop()}`
            externalModelPath.color = "#28a745"
            
            // 清除本地模型选择
            localModelComboBox.currentIndex = -1
            
            // 获取模型期望特征
            if (root.selectedTask && root.continuousLearningController) {
                let taskKey = root.getTaskKey(root.selectedTask)
                root.modelExpectedFeatures = root.continuousLearningController.getModelExpectedFeatures(taskKey)
                root.updateFeatureMapping()
            }
            
            root.addLog(root.isChinese ? `已选择模型文件: ${filePath}` : `Selected model file: ${filePath}`)
        }
    }
    
    FolderDialog {
        id: modelFolderDialog
        title: root.isChinese ? "选择SVR模型目录" : "Select SVR Model Folder"
        onAccepted: {
            let folderPath = selectedFolder.toString().replace("file:///", "")
            root.selectedModel = folderPath
            root.modelType = "folder"
            externalModelPath.text = root.isChinese ? 
                `已选择: ${folderPath.split('/').pop()}` : 
                `Selected: ${folderPath.split('/').pop()}`
            externalModelPath.color = "#28a745"
            
            // 清除本地模型选择
            localModelComboBox.currentIndex = -1
            
            // 获取模型期望特征
            if (root.selectedTask && root.continuousLearningController) {
                let taskKey = root.getTaskKey(root.selectedTask)
                root.modelExpectedFeatures = root.continuousLearningController.getModelExpectedFeatures(taskKey)
                root.updateFeatureMapping()
            }
            
            root.addLog(root.isChinese ? `已选择SVR模型目录: ${folderPath}` : `Selected SVR model folder: ${folderPath}`)
        }
    }
    
    // JavaScript函数
    function isTaskRequiringFolder() {
        // SVR模型（TDH和QF预测任务）需要选择文件夹
        // GLR任务需要选择模型权重文件
        if (root.selectedTask === "扬程预测" || root.selectedTask === "Head Prediction" ||
            root.selectedTask === "产量预测" || root.selectedTask === "Production Prediction") {
            return true  // SVR模型需要文件夹
        } else if (root.selectedTask === "气液比预测" || root.selectedTask === "GLR Prediction") {
            return false // GLR模型需要单个权重文件
        }
        return false // 默认使用文件选择
    }
    
    function getExternalModelButtonText() {
        if (root.isTaskRequiringFolder()) {
            return root.isChinese ? "选择SVR模型目录" : "Select SVR Model Folder"
        } else {
            return root.isChinese ? "选择GLR模型目录" : "Select GLR Model Folder"
        }
    }
    
    function getExternalModelHint() {
        if (root.isTaskRequiringFolder()) {
            return root.isChinese ? "用于SVR模型文件夹 (包含.joblib文件)" : "For SVR model folder (contains .joblib files)"
        } else {
            return root.isChinese ? "用于GLR模型权重文件 (.pth格式)" : "For GLR model weights (.pth format)"
        }
    }
    
    function checkFeatureMappingComplete() {
        if (root.modelExpectedFeatures.length === 0) {
            return true
        }
        
        for (let expectedFeature of root.modelExpectedFeatures) {
            let mappedFeature = root.featureMapping[expectedFeature] || ""
            if (mappedFeature === "") {
                return false
            }
        }
        return true
    }
    
    function refreshDataTables() {
        if (!root.continuousLearningController) {
            console.log("Controller not initialized, skipping table refresh")
            return
        }
        
        try {
            let tables = root.continuousLearningController.getAvailableTables()
            root.availableDataTables = tables.filter(t => t.startsWith('data_') || t.startsWith('test_'))
            
            addLog(root.isChinese ? 
                `发现 ${root.availableDataTables.length} 个测试数据表` :
                `Found ${root.availableDataTables.length} test data tables`)
        } catch (error) {
            console.log("Error refreshing data tables:", error)
            addLog(root.isChinese ? 
                `刷新数据表失败: ${error}` :
                `Failed to refresh data tables: ${error}`)
        }
    }
    
    function updateCommonFeatures() {
        if (root.selectedDataTables.length === 0) {
            root.commonFeatures = []
            root.featureMapping = {}
            return
        }
        
        if (!root.continuousLearningController) {
            console.log("Controller not initialized, skipping common features update")
            return
        }
        
        try {
            let common = null
            for (let table of root.selectedDataTables) {
                let columns = root.continuousLearningController.getTableFields(table)
                if (common === null) {
                    common = new Set(columns)
                } else {
                    common = new Set([...common].filter(col => columns.includes(col)))
                }
            }
            
            root.commonFeatures = common ? Array.from(common).sort() : []
            
            // 智能设置预测目标
            if (root.selectedTask && root.commonFeatures.length > 0) {
                let possibleTargets = root.continuousLearningController.getModelExpectedTargets(root.selectedTask)
                
                for (let target of possibleTargets) {
                    if (root.commonFeatures.includes(target)) {
                        root.targetLabel = target
                        break
                    }
                }
                
                // 如果没有找到预期目标，使用自动匹配
                if (!root.targetLabel || root.targetLabel.length === 0) {
                    root.autoMatchTargetLabel()
                }
            }
            
            // 当特征发生变化时，重新更新特征映射
            root.updateFeatureMapping()
            
            addLog(root.isChinese ? 
                `共有特征: ${root.commonFeatures.length}个` :
                `Common features: ${root.commonFeatures.length}`)
        } catch (error) {
            console.log("Error updating common features:", error)
            addLog(root.isChinese ? 
                `更新共有特征失败: ${error}` :
                `Failed to update common features: ${error}`)
        }
    }
    
    function updateFeatureMapping() {
        if (root.modelExpectedFeatures.length === 0) {
            root.featureMapping = {}
            root.finalInputFeatures = root.selectedFeatures
            return
        }
        
        let newMapping = {}
        
        // 保留现有的有效映射
        for (let expectedFeature of root.modelExpectedFeatures) {
            let currentMapping = root.featureMapping[expectedFeature] || ""
            if (currentMapping !== "" && root.commonFeatures.includes(currentMapping)) {
                newMapping[expectedFeature] = currentMapping
            } else {
                newMapping[expectedFeature] = ""
            }
        }
        
        // 自动映射未映射的特征
        let availableFeatures = root.commonFeatures.filter(f => f !== root.targetLabel)
        let usedFeatures = Object.values(newMapping).filter(v => v !== "")
        
        for (let expectedFeature of root.modelExpectedFeatures) {
            if (newMapping[expectedFeature] !== "") {
                continue // 已经映射过的跳过
            }
            
            // 寻找最佳匹配
            let bestMatch = ""
            
            // 首先尝试完全匹配
            for (let availableFeature of availableFeatures) {
                if (usedFeatures.includes(availableFeature)) {
                    continue // 已被使用的特征跳过
                }
                
                if (availableFeature.toLowerCase() === expectedFeature.toLowerCase()) {
                    bestMatch = availableFeature
                    break
                }
            }
            
            // 如果没有完全匹配，尝试部分匹配
            if (bestMatch === "") {
                for (let availableFeature of availableFeatures) {
                    if (usedFeatures.includes(availableFeature)) {
                        continue // 已被使用的特征跳过
                    }
                    
                    if (availableFeature.toLowerCase().includes(expectedFeature.toLowerCase()) ||
                        expectedFeature.toLowerCase().includes(availableFeature.toLowerCase())) {
                        bestMatch = availableFeature
                        break
                    }
                }
            }
            
            if (bestMatch !== "") {
                newMapping[expectedFeature] = bestMatch
                usedFeatures.push(bestMatch)
            }
        }
        
        root.featureMapping = newMapping
        
        // 更新最终输入特征列表
        root.updateFinalInputFeatures()
        
        addLog(root.isChinese ? 
            `特征映射已更新: ${Object.keys(newMapping).length}个期望特征，${Object.values(newMapping).filter(v => v !== "").length}个已映射` :
            `Feature mapping updated: ${Object.keys(newMapping).length} expected features, ${Object.values(newMapping).filter(v => v !== "").length} mapped`)
    }
    
    function updateFinalInputFeatures() {
        if (root.modelExpectedFeatures.length === 0) {
            root.finalInputFeatures = root.selectedFeatures
        } else {
            let finalFeatures = []
            for (let expectedFeature of root.modelExpectedFeatures) {
                let mappedFeature = root.featureMapping[expectedFeature]
                if (mappedFeature && mappedFeature !== "") {
                    finalFeatures.push(mappedFeature)
                }
            }
            root.finalInputFeatures = finalFeatures
        }
        
        addLog(root.isChinese ? 
            `最终输入特征列表: [${root.finalInputFeatures.join(', ')}]` :
            `Final input features: [${root.finalInputFeatures.join(', ')}]`)
    }
    
    function autoMapFeatures() {
        // 自动映射功能：智能匹配特征名称
        if (root.modelExpectedFeatures.length === 0 || root.commonFeatures.length === 0) {
            return
        }
        
        let newMapping = {}
        let availableFeatures = root.commonFeatures.filter(f => f !== root.targetLabel)
        let usedFeatures = []
        
        for (let expectedFeature of root.modelExpectedFeatures) {
            let bestMatch = ""
            let bestScore = 0
            
            // 查找最佳匹配（排除已使用的特征）
            for (let dataFeature of availableFeatures) {
                if (usedFeatures.includes(dataFeature)) {
                    continue // 跳过已使用的特征
                }
                
                let score = 0
                
                // 完全匹配得最高分
                if (dataFeature.toLowerCase() === expectedFeature.toLowerCase()) {
                    score = 100
                }
                // 包含关系匹配
                else if (dataFeature.toLowerCase().includes(expectedFeature.toLowerCase()) ||
                         expectedFeature.toLowerCase().includes(dataFeature.toLowerCase())) {
                    score = 80
                }
                // 相似度匹配（简单的字符重合度）
                else {
                    let commonChars = 0
                    let expectedLower = expectedFeature.toLowerCase()
                    let dataLower = dataFeature.toLowerCase()
                    for (let i = 0; i < expectedLower.length; i++) {
                        let currentChar = expectedLower.charAt(i)
                        if (dataLower.includes(currentChar)) {
                            commonChars++
                        }
                    }
                    score = (commonChars / expectedLower.length) * 60
                }
                
                if (score > bestScore && score > 30) { // 最低30分才考虑
                    bestScore = score
                    bestMatch = dataFeature
                }
            }
            
            if (bestMatch !== "") {
                newMapping[expectedFeature] = bestMatch
                usedFeatures.push(bestMatch)
            } else {
                newMapping[expectedFeature] = ""
            }
        }
        
        root.featureMapping = newMapping
        root.updateFinalInputFeatures()
        
        let mappedCount = Object.values(newMapping).filter(v => v !== "").length
        addLog(root.isChinese ? 
            `自动映射完成: ${mappedCount}/${root.modelExpectedFeatures.length} 个特征已映射` :
            `Auto mapping completed: ${mappedCount}/${root.modelExpectedFeatures.length} features mapped`)
    }
    
    function getTaskKey(taskName) {
        // 将显示名称转换为控制器期望的任务键
        if (taskName === "扬程预测" || taskName === "Head Prediction") {
            return "head"  // 或者 "TDH"，根据控制器的实际实现
        } else if (taskName === "产量预测" || taskName === "Production Prediction") {
            return "production"  // 或者 "QF"
        } else if (taskName === "气液比预测" || taskName === "GLR Prediction") {
            return "glr"  // 或者 "GLR"
        }
        return taskName
    }
    
    function autoMatchTargetLabel() {
        // 根据任务类型自动匹配合适的预测标签
        if (!root.commonFeatures || root.commonFeatures.length === 0) {
            return
        }
        
        if (!root.continuousLearningController) {
            console.log("Controller not initialized, skipping auto match target label")
            return
        }
        
        try {
            let autoSelectedLabel = ""
            
            // 根据选择的任务类型进行自动匹配
            if (root.selectedTask === "扬程预测" || root.selectedTask === "Head Prediction") {
                // 对于扬程预测，寻找包含 head、TDH、扬程 等关键词的特征
                const headPatterns = ["head", "tdh", "扬程", "举升高度", "lift"]
                autoSelectedLabel = findMatchingFeature(headPatterns)
            } else if (root.selectedTask === "产量预测" || root.selectedTask === "Production Prediction") {
                // 对于产量预测，寻找包含 production、QF、产量、流量 等关键词的特征
                const productionPatterns = ["production", "qf", "产量", "流量", "flow", "rate"]
                autoSelectedLabel = findMatchingFeature(productionPatterns)
            } else if (root.selectedTask === "气液比预测" || root.selectedTask === "GLR Prediction") {
                // 对于气液比预测，寻找包含 GLR、气液比、ratio 等关键词的特征
                const glrPatterns = ["glr", "气液比", "gas", "liquid", "ratio"]
                autoSelectedLabel = findMatchingFeature(glrPatterns)
            }
            
            // 如果找到了匹配的标签，自动设置
            if (autoSelectedLabel && autoSelectedLabel !== root.targetLabel) {
                root.targetLabel = autoSelectedLabel
                // 从已选特征中移除目标标签
                root.selectedFeatures = root.selectedFeatures.filter(f => f !== autoSelectedLabel)
                root.updateFeatureMapping()
                
                addLog(root.isChinese ? 
                    `自动匹配预测标签: ${autoSelectedLabel}` :
                    `Auto-matched prediction label: ${autoSelectedLabel}`)
            }
        } catch (error) {
            console.log("Error in autoMatchTargetLabel:", error)
            addLog(root.isChinese ? 
                `自动匹配预测标签失败: ${error}` :
                `Failed to auto-match prediction label: ${error}`)
        }
    }
    
    function findMatchingFeature(patterns) {
        // 在可用特征中查找匹配模式的特征
        for (let feature of root.commonFeatures) {
            const featureLower = feature.toLowerCase()
            for (let pattern of patterns) {
                if (featureLower.includes(pattern.toLowerCase())) {
                    return feature
                }
            }
        }
        return ""
    }
    
    function addLog(message) {
        let timestamp = new Date().toLocaleTimeString()
        console.log(`[${timestamp}] ${message}`)
    }
    
    function isConfigurationComplete() {
        let featureConfig = root.getFinalFeatureConfiguration()
        
        return root.selectedTask.length > 0 &&
               root.selectedModel.length > 0 &&
               root.selectedDataTables.length > 0 && 
               featureConfig.inputFeatures.length > 0 && 
               root.targetLabel.length > 0 &&
               root.checkFeatureMappingComplete()
    }
    
    function validateConfiguration() {
        // 详细配置验证
        if (!root.selectedTask || root.selectedTask.length === 0) {
            addLog(root.isChinese ? "错误：请选择测试任务" : "Error: Please select test task")
            return false
        }
        
        if (!root.selectedModel || root.selectedModel.length === 0) {
            addLog(root.isChinese ? "错误：请选择测试模型" : "Error: Please select test model")
            return false
        }
        
        if (!root.selectedDataTables || root.selectedDataTables.length === 0) {
            addLog(root.isChinese ? "错误：请选择测试数据表" : "Error: Please select test data tables")
            return false
        }
        
        let featureConfig = root.getFinalFeatureConfiguration()
        if (!featureConfig.inputFeatures || featureConfig.inputFeatures.length === 0) {
            if (featureConfig.mappingRequired) {
                addLog(root.isChinese ? "错误：请完成特征映射，确保所有模型特征都有对应的数据特征" : "Error: Please complete feature mapping, ensure all model features have corresponding data features")
            } else {
                addLog(root.isChinese ? "错误：请选择输入特征" : "Error: Please select input features")
            }
            return false
        }
        
        if (!root.targetLabel || root.targetLabel.length === 0) {
            addLog(root.isChinese ? "错误：请选择预测目标" : "Error: Please select target label")
            return false
        }
        
        if (root.modelExpectedFeatures.length > 0 && !root.checkFeatureMappingComplete()) {
            addLog(root.isChinese ? "错误：请完成所有特征映射" : "Error: Please complete all feature mappings")
            return false
        }
        
        // 输出最终的特征配置信息
        addLog(root.isChinese ? 
            `最终特征配置 - 输入特征: [${featureConfig.inputFeatures.join(', ')}], 预测目标: ${root.targetLabel}` :
            `Final feature configuration - Input features: [${featureConfig.inputFeatures.join(', ')}], Target: ${root.targetLabel}`)
        
        if (featureConfig.mappingRequired) {
            addLog(root.isChinese ? 
                `特征映射顺序: [${featureConfig.featureOrder.join(', ')}]` :
                `Feature mapping order: [${featureConfig.featureOrder.join(', ')}]`)
        }
        
        addLog(root.isChinese ? "配置验证通过，准备开始测试" : "Configuration validated, ready to start testing")
        return true
    }
    
    function getConfigurationErrorMessage() {
        if (!root.selectedTask || root.selectedTask.length === 0) {
            return root.isChinese ? "请选择测试任务" : "Please select test task"
        }
        
        if (!root.selectedModel || root.selectedModel.length === 0) {
            return root.isChinese ? "请选择测试模型" : "Please select test model"
        }
        
        if (!root.selectedDataTables || root.selectedDataTables.length === 0) {
            return root.isChinese ? "请选择测试数据表" : "Please select test data tables"
        }
        
        let featureConfig = root.getFinalFeatureConfiguration()
        if (!featureConfig.inputFeatures || featureConfig.inputFeatures.length === 0) {
            if (featureConfig.mappingRequired) {
                return root.isChinese ? "请完成特征映射" : "Please complete feature mapping"
            } else {
                return root.isChinese ? "请选择输入特征" : "Please select input features"
            }
        }
        
        if (!root.targetLabel || root.targetLabel.length === 0) {
            return root.isChinese ? "请选择预测目标" : "Please select target label"
        }
        
        if (root.modelExpectedFeatures.length > 0 && !root.checkFeatureMappingComplete()) {
            return root.isChinese ? "请完成所有特征映射" : "Please complete all feature mappings"
        }
        
        return root.isChinese ? "配置完整" : "Configuration complete"
    }
    
    Component.onCompleted: {
        // 延迟执行，确保 controller 已经初始化
        Qt.callLater(function() {
            if (root.continuousLearningController) {
                refreshDataTables()
                root.updateFinalInputFeatures()
                addLog(root.isChinese ? "模型测试配置页面已加载" : "Model testing configuration page loaded")
            } else {
                console.log("Controller not available at Component.onCompleted, will retry when controller is available")
            }
        })
        
        // 调试信息
        console.log("ModelTestingConfig loaded")
        console.log("Initial modelExpectedFeatures:", root.modelExpectedFeatures)
        console.log("Initial selectedDataTables:", root.selectedDataTables)
    }
    
    // 监听关键属性变化以便调试
    onModelExpectedFeaturesChanged: {
        console.log("ModelTestingConfig: modelExpectedFeatures changed to:", root.modelExpectedFeatures)
        console.log("Feature mapping section visible:", root.modelExpectedFeatures.length > 0 && root.selectedDataTables.length > 0)
        root.updateFinalInputFeatures()
    }
    
    onSelectedDataTablesChanged: {
        console.log("ModelTestingConfig: selectedDataTables changed to:", root.selectedDataTables)
        console.log("Feature mapping section visible:", root.modelExpectedFeatures.length > 0 && root.selectedDataTables.length > 0)
    }
    
    onFeatureMappingChanged: {
        console.log("ModelTestingConfig: featureMapping changed to:", root.featureMapping)
        root.updateFinalInputFeatures()
    }
    
    onSelectedFeaturesChanged: {
        console.log("ModelTestingConfig: selectedFeatures changed to:", root.selectedFeatures)
        if (root.modelExpectedFeatures.length === 0) {
            root.updateFinalInputFeatures()
        }
    }
}
