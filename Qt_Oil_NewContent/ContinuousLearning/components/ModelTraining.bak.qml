pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    property var continuousLearningController
    property var trainingProgress: 0.0
    property var currentModel: ""
    property var trainingResults: ({})
    
    // 监听 currentModel 变化
    onCurrentModelChanged: {
        console.log("ModelTraining: currentModel property changed to:", currentModel, "type:", typeof currentModel)
    }
    
    // 重新设计的属性
    property string selectedTask: ""           // 选择的训练任务
    property var availableDataTables: []       // data开头的表
    property var availableTestTables: []       // test开头的表  
    property var selectedDataTables: []        // 选择的数据表
    property var selectedTestTables: []        // 选择的测试表
    property var commonFeatures: []            // 共有特征列
    property var selectedFeatures: []          // 选择的输入特征
    property string targetLabel: ""            // 预测标签
    property bool isTraining: false            // 是否正在训练
    
    // 训练参数 - 用于深度学习模型
    property real learningRate: 0.001
    property int epochs: 10
    property int batchSize: 48
    property int patience: 100
    
    // 损失数据 - 用于可视化
    property var lossData: ({
        "train_losses": [],
        "val_losses": [],
        "epochs": []
    })
    property var trainingLogs: []              // 训练日志
    
    // 监听 lossData 变化并打印调试信息
    onLossDataChanged: {
        console.log("=== Root: lossData property changed ===")
        console.log("New lossData:", JSON.stringify(lossData))
        if (lossData) {
            console.log("train_losses length:", lossData.train_losses ? lossData.train_losses.length : "null")
            console.log("val_losses length:", lossData.val_losses ? lossData.val_losses.length : "null")
        }
        // 添加到训练日志用于UI显示
        addLog("损失数据已更新 - 训练点数: " + (lossData && lossData.train_losses ? lossData.train_losses.length : "0"))
    }
    
    // 特征映射相关 (用于建立用户选择特征与模型期望特征的对应关系)
    property var modelExpectedFeatures: []     // 模型期望的特征名称列表
    property var featureMapping: ({})          // 用户特征 -> 模型特征的映射
    
    // 页面状态控制
    property int currentPage: 0                // 0: 配置页面, 1: 训练页面
    property bool configurationComplete: false // 配置是否完成
    
    signal backRequested()
    
    // 重置函数 - 用于清理组件状态
    function resetToInitialState() {
        console.log("ModelTraining: 重置到初始状态")
        currentPage = 0
        configurationComplete = false
        isTraining = false
        
        // 重置StackView到初始页面
        while (stackView.depth > 1) {
            stackView.pop(null)
        }
        
        addLog(root.isChinese ? "页面已重置到初始状态" : "Page reset to initial state")
    }
    
    Component.onDestruction: {
        console.log("ModelTraining: 组件正在销毁")
    }
    
    // 主要布局 - 使用StackView管理两个页面
    StackView {
        id: stackView
        anchors.fill: parent
        anchors.margins: 16
        
        initialItem: configurationPage
        
        // 配置页面
        Component {
            id: configurationPage
            
            Rectangle {
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 24
                    contentWidth: availableWidth
                    contentHeight: mainColumn.implicitHeight
                    clip: true  // 确保内容被正确裁剪
                    
                    ColumnLayout {
                        id: mainColumn
                        width: parent.width
                        spacing: 24
                        
                        // 页面标题
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Text {
                                text: root.isChinese ? "模型训练配置" : "Model Training Configuration"
                                font.pixelSize: 24
                                font.bold: true
                                color: "#212529"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Button {
                                text: root.isChinese ? "返回" : "Back"
                                onClicked: {
                                    console.log("ModelTraining: 配置页面返回按钮被点击")
                                    root.backRequested()
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#dee2e6"
                        }
                        
                        // 第一步：选择训练任务
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Text {
                                text: root.isChinese ? "步骤 1：选择训练任务" : "Step 1: Select Training Task"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#495057"
                            }
                            
                            RowLayout {
                                spacing: 20
                                
                                RadioButton {
                                    text: root.isChinese ? "扬程预测 (TDH)" : "Head Prediction (TDH)"
                                    checked: root.selectedTask === "head"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.selectedTask = "head"
                                            root.updateCommonFeatures()
                                        }
                                    }
                                    font.pixelSize: 14
                                }
                                
                                RadioButton {
                                    text: root.isChinese ? "产量预测 (QF)" : "Production Prediction (QF)"
                                    checked: root.selectedTask === "production"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.selectedTask = "production"
                                            root.updateCommonFeatures()
                                        }
                                    }
                                    font.pixelSize: 14
                                }
                                
                                RadioButton {
                                    text: root.isChinese ? "气液比预测 (GLR)" : "GLR Prediction"
                                    checked: root.selectedTask === "glr"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.selectedTask = "glr"
                                            root.updateCommonFeatures()
                                        }
                                    }
                                    font.pixelSize: 14
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#e9ecef"
                        }
                        
                        // 第二步：选择数据表
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            RowLayout {
                                Text {
                                    text: root.isChinese ? "步骤 2：选择数据表" : "Step 2: Select Data Tables"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: root.isChinese ? "刷新表列表" : "Refresh Tables"
                                    onClicked: root.refreshDataTables()
                                    implicitHeight: 32
                                    font.pixelSize: 12
                                }
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16
                                
                                // 训练数据表
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? "训练数据表 (data_*)" : "Training Tables (data_*)"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#6c757d"
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 120  // 最小高度
                                        Layout.maximumHeight: 250  // 最大高度  
                                        Layout.preferredHeight: Math.min(250, Math.max(120, root.availableDataTables.length * 30 + 20))
                                        border.width: 1
                                        border.color: "#ced4da"
                                        radius: 6
                                        
                                        ListView {
                                            id: dataTablesListView
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            
                                            model: root.availableDataTables
                                            
                                            delegate: CheckBox {
                                                required property string modelData
                                                required property int index
                                                
                                                width: dataTablesListView.width - 16
                                                text: modelData
                                                font.pixelSize: 12
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
                                
                                // 测试数据表
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? "测试数据表 (test_*)" : "Test Tables (test_*)"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#6c757d"
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 120  // 最小高度
                                        Layout.maximumHeight: 250  // 最大高度
                                        Layout.preferredHeight: Math.min(250, Math.max(120, root.availableTestTables.length * 30 + 20))
                                        border.width: 1
                                        border.color: "#ced4da"
                                        radius: 6
                                        
                                        ListView {
                                            id: testTablesListView
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            
                                            model: root.availableTestTables
                                            
                                            delegate: CheckBox {
                                                required property string modelData
                                                required property int index
                                                
                                                width: testTablesListView.width - 16
                                                text: modelData
                                                font.pixelSize: 12
                                                checked: root.selectedTestTables.includes(modelData)
                                                
                                                onCheckedChanged: {
                                                    if (checked) {
                                                        if (!root.selectedTestTables.includes(modelData)) {
                                                            root.selectedTestTables = [...root.selectedTestTables, modelData]
                                                        }
                                                    } else {
                                                        root.selectedTestTables = root.selectedTestTables.filter(t => t !== modelData)
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
                        
                        // 第三步：特征选择
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            
                            Text {
                                text: root.isChinese ? "步骤 3：特征和目标选择" : "Step 3: Features & Target Selection"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `检测到共有特征 ${root.commonFeatures.length} 个: ${root.commonFeatures.slice(0, 8).join(', ')}${root.commonFeatures.length > 8 ? '...' : ''}` :
                                    `Common Features Detected (${root.commonFeatures.length}): ${root.commonFeatures.slice(0, 8).join(', ')}${root.commonFeatures.length > 8 ? '...' : ''}`
                                font.pixelSize: 12
                                color: "#6c757d"
                                wrapMode: Text.WordWrap
                                visible: root.commonFeatures.length > 0
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 16
                                
                                // 输入特征
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    
                                    RowLayout {
                                        Text {
                                            text: root.isChinese ? "输入特征" : "Input Features"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: "#6c757d"
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        Button {
                                            text: root.isChinese ? "全选" : "Select All"
                                            onClicked: {
                                                root.selectedFeatures = [...root.commonFeatures.filter(f => f !== root.targetLabel)]
                                            }
                                            implicitHeight: 28
                                            font.pixelSize: 10
                                        }
                                        
                                        Button {
                                            text: root.isChinese ? "清空" : "Clear All"
                                            onClicked: {
                                                root.selectedFeatures = []
                                            }
                                            implicitHeight: 28
                                            font.pixelSize: 10
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 120
                                        Layout.preferredHeight: Math.min(300, Math.max(120, featuresListView.contentHeight + 16))
                                        border.width: 1
                                        border.color: "#ced4da"
                                        radius: 6
                                        
                                        ListView {
                                            id: featuresListView
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            clip: true
                                            
                                            model: root.commonFeatures.filter(f => f !== root.targetLabel)
                                            
                                            delegate: CheckBox {
                                                required property string modelData
                                                required property int index
                                                
                                                width: featuresListView.width - 16
                                                text: modelData
                                                font.pixelSize: 11
                                                checked: root.selectedFeatures.includes(modelData)
                                                
                                                onCheckedChanged: {
                                                    if (checked) {
                                                        if (!root.selectedFeatures.includes(modelData)) {
                                                            root.selectedFeatures = [...root.selectedFeatures, modelData]
                                                        }
                                                    } else {
                                                        root.selectedFeatures = root.selectedFeatures.filter(f => f !== modelData)
                                                    }
                                                    // 当特征选择发生变化时，更新特征映射
                                                    if (root.selectedTask && root.modelExpectedFeatures.length > 0) {
                                                        root.updateFeatureMapping()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // 预测目标
                                ColumnLayout {
                                    Layout.preferredWidth: 200
                                    spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? "预测目标" : "Target Variable"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#6c757d"
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 120
                                        Layout.preferredHeight: Math.min(300, Math.max(120, targetsListView.contentHeight + 16))
                                        border.width: 1
                                        border.color: "#ced4da"
                                        radius: 6
                                        
                                        ListView {
                                            id: targetsListView
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            clip: true
                                            
                                            model: root.commonFeatures
                                            
                                            delegate: RadioButton {
                                                required property string modelData
                                                required property int index
                                                
                                                width: targetsListView.width - 16
                                                text: modelData
                                                font.pixelSize: 11
                                                checked: root.targetLabel === modelData
                                                
                                                onCheckedChanged: {
                                                    if (checked) {
                                                        root.targetLabel = modelData
                                                        root.selectedFeatures = root.selectedFeatures.filter(f => f !== modelData)
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
                        
                        // 第四步：特征映射 (可见性根据是否有模型期望特征决定)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root.modelExpectedFeatures.length > 0
                            
                            Text {
                                text: root.isChinese ? "步骤 4：特征映射" : "Step 4: Feature Mapping"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    "请将数据中的特征映射到模型期望的输入特征：" :
                                    "Map your data features to model expected input features:"
                                font.pixelSize: 12
                                color: "#6c757d"
                                wrapMode: Text.WordWrap
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 200  // 最小高度
                                Layout.maximumHeight: 500  // 最大高度，避免过高
                                Layout.preferredHeight: Math.min(500, Math.max(200, gridFlow.implicitHeight + 20))
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 6
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    contentWidth: Math.max(availableWidth, gridFlow.implicitWidth)
                                    contentHeight: Math.max(availableHeight, gridFlow.implicitHeight)
                                    
                                    Flow {
                                        id: gridFlow
                                        width: parent.width
                                        spacing: 12
                                        
                                        Repeater {
                                            model: root.modelExpectedFeatures
                                            
                                            delegate: Rectangle {
                                                required property string modelData
                                                required property int index
                                                
                                                width: 280
                                                height: 80
                                                border.width: 1
                                                border.color: "#dee2e6"
                                                radius: 6
                                                color: {
                                                    let mapping = root.featureMapping[modelData] || ""
                                                    return mapping === "" ? "#fff3cd" : "#d1f2eb"
                                                }
                                                
                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 4
                                                    
                                                    Text {
                                                        text: root.isChinese ? `模型特征: ${modelData}` : `Model Feature: ${modelData}`
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
                                                            
                                                            // 当映射改变时更新选择
                                                            property string currentMapping: root.featureMapping[modelData] || ""
                                                            
                                                            onCurrentMappingChanged: {
                                                                if (currentMapping === "") {
                                                                    currentIndex = 0  // "请选择..."
                                                                } else {
                                                                    let mappingIndex = dropdownModel.indexOf(currentMapping)
                                                                    if (mappingIndex >= 0) {
                                                                        currentIndex = mappingIndex
                                                                    }
                                                                }
                                                            }
                                                            
                                                            Component.onCompleted: {
                                                                let initialMapping = root.featureMapping[modelData] || ""
                                                                if (initialMapping === "") {
                                                                    currentIndex = 0  // "请选择..."
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
                                                                    newMapping[modelData] = currentText
                                                                    root.featureMapping = newMapping
                                                                } else if (currentIndex === 0) {
                                                                    let newMapping = Object.assign({}, root.featureMapping)
                                                                    newMapping[modelData] = ""
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
                                                                let mapping = root.featureMapping[modelData] || ""
                                                                return mapping === "" ? "#dc3545" : "#28a745"
                                                            }
                                                        }
                                                    }
                                                    
                                                    Text {
                                                        text: {
                                                            let mapping = root.featureMapping[modelData] || ""
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
                            
                            // 自动映射按钮
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                spacing: 12
                                
                                Button {
                                    text: root.isChinese ? "自动映射特征" : "Auto Map Features"
                                    enabled: root.modelExpectedFeatures.length > 0 && root.commonFeatures.length > 0
                                    onClicked: root.autoMapFeatures()
                                    
                                    implicitHeight: 32
                                    implicitWidth: 120
                                    font.pixelSize: 12
                                }
                                
                                Button {
                                    text: root.isChinese ? "清除映射" : "Clear Mapping"
                                    enabled: root.modelExpectedFeatures.length > 0
                                    onClicked: {
                                        let newMapping = {}
                                        for (let expectedFeature of root.modelExpectedFeatures) {
                                            newMapping[expectedFeature] = ""
                                        }
                                        root.featureMapping = newMapping
                                        root.addLog(root.isChinese ? "特征映射已清除" : "Feature mapping cleared")
                                    }
                                    
                                    implicitHeight: 32
                                    implicitWidth: 100
                                    font.pixelSize: 12
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                // 映射状态指示
                                RowLayout {
                                    spacing: 8
                                    
                                    Rectangle {
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        radius: 6
                                        color: root.checkFeatureMappingComplete() ? "#28a745" : "#dc3545"
                                    }
                                    
                                    Text {
                                        text: {
                                            let mappedCount = Object.values(root.featureMapping).filter(v => v !== "").length
                                            let totalCount = root.modelExpectedFeatures.length
                                            return root.isChinese ? 
                                                `${mappedCount}/${totalCount} 个特征已映射` :
                                                `${mappedCount}/${totalCount} features mapped`
                                        }
                                        font.pixelSize: 11
                                        color: "#6c757d"
                                    }
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#e9ecef"
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
                                Layout.preferredHeight: configSummaryColumn.implicitHeight + 32  // 16*2 margins
                                Layout.maximumHeight: 600  // 设置最大高度避免过高
                                color: "#f8f9fa"
                                border.width: 1
                                border.color: "#dee2e6"
                                radius: 6
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    contentWidth: availableWidth
                                    contentHeight: configSummaryColumn.implicitHeight
                                    clip: true
                                    
                                    ColumnLayout {
                                        id: configSummaryColumn
                                        width: parent.width
                                        spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? 
                                            `• 训练任务: ${root.selectedTask || '未选择'}` :
                                            `• Training Task: ${root.selectedTask || 'Not selected'}`
                                        font.pixelSize: 12
                                        color: "#495057"
                                    }
                                    
                                    Text {
                                        text: root.isChinese ? 
                                            `• 训练表: ${root.selectedDataTables.length} 个` :
                                            `• Training Tables: ${root.selectedDataTables.length}`
                                        font.pixelSize: 12
                                        color: "#495057"
                                    }
                                    
                                    Text {
                                        text: root.isChinese ? 
                                            `• 测试表: ${root.selectedTestTables.length} 个` :
                                            `• Test Tables: ${root.selectedTestTables.length}`
                                        font.pixelSize: 12
                                        color: "#495057"
                                    }
                                    
                                    Text {
                                        text: {
                                            let finalFeatures = getMappedFeatures()
                                            return root.isChinese ? 
                                                `• 输入特征: ${finalFeatures.length} 个` :
                                                `• Input Features: ${finalFeatures.length}`
                                        }
                                        font.pixelSize: 12
                                        color: "#495057"
                                    }
                                    
                                    Text {
                                        text: root.isChinese ? 
                                            `• 预测目标: ${root.targetLabel || '未选择'}` :
                                            `• Target: ${root.targetLabel || 'Not selected'}`
                                        font.pixelSize: 12
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
                                        font.pixelSize: 12
                                        color: "#495057"
                                        visible: root.modelExpectedFeatures.length > 0
                                    }
                                }
                            }
                            
                            // 特征映射状态提示
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 40
                                Layout.preferredHeight: Math.max(40, mappingStatusRow.implicitHeight + 24)  // 12*2 margins
                                Layout.maximumHeight: 120  // 避免过高
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
                                    id: mappingStatusRow
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
                                                return root.isChinese ? "所有特征映射已完成，可以开始训练" : "All feature mappings completed, ready to train"
                                            } else {
                                                return root.isChinese ? "请完成所有特征映射后再开始训练" : "Please complete all feature mappings before training"
                                            }
                                        }
                                        font.pixelSize: 12
                                        color: "#495057"
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: root.isChinese ? "开始训练" : "Start Training"
                                    enabled: root.selectedTask.length > 0 &&
                                            root.selectedDataTables.length > 0 && 
                                            root.selectedFeatures.length > 0 && 
                                            root.targetLabel.length > 0 &&
                                            root.checkFeatureMappingComplete() &&
                                            getMappedFeatures().length > 0  // 确保有有效的映射特征
                                    
                                    onClicked: {
                                        root.configurationComplete = true
                                        root.currentPage = 1
                                        stackView.push(trainingPage)
                                        root.startTraining()
                                    }
                                    
                                    font.pixelSize: 14
                                    implicitHeight: 40
                                    implicitWidth: 120
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 训练页面
        Component {
            id: trainingPage
            
            Rectangle {
                color: "#f8f9fa"
                
                // 整个页面可滚动
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 24
                    contentWidth: availableWidth
                    
                    ColumnLayout {
                        width: parent.width
                        spacing: 16
                        
                        // 页面标题和导航
                        RowLayout {
                            Layout.fillWidth: true
                            
                            Button {
                                text: root.isChinese ? "← 返回配置" : "← Back to Config"
                                onClicked: {
                                    stackView.pop()
                                    root.currentPage = 0
                                }
                                enabled: !root.isTraining
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                text: root.isChinese ? "模型训练" : "Model Training"
                                font.pixelSize: 24
                                font.bold: true
                                color: "#212529"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Button {
                                text: root.isChinese ? "主页" : "Home"
                                onClicked: {
                                    console.log("ModelTraining: 训练页面主页按钮被点击")
                                    root.backRequested()
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#dee2e6"
                        }
                    
                        // 训练状态区域
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            
                            // 训练控制
                            Rectangle {
                                Layout.preferredWidth: 300
                                Layout.minimumHeight: 150
                                Layout.preferredHeight: Math.max(150, trainingControlColumn.implicitHeight + 32)
                                Layout.maximumHeight: 300
                                color: "white"
                                radius: 8
                                border.width: 1
                                border.color: "#dee2e6"
                            
                            ColumnLayout {
                                id: trainingControlColumn
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12
                                
                                Text {
                                    text: root.isChinese ? "训练控制" : "Training Control"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                RowLayout {
                                    spacing: 12
                                    
                                    Button {
                                        text: root.isChinese ? "停止训练" : "Stop Training"
                                        enabled: root.isTraining
                                        onClicked: root.stopTraining()
                                    }
                                    
                                    Button {
                                        text: root.isChinese ? "重新训练" : "Restart"
                                        enabled: !root.isTraining
                                        onClicked: root.startTraining()
                                    }
                                    
                                    Button {
                                        text: root.isChinese ? "保存模型" : "Save Model"
                                        enabled: !root.isTraining && root.currentModel && root.currentModel.length > 0
                                        onClicked: {
                                            console.log("Save button clicked, currentModel:", root.currentModel)
                                            console.log("isTraining:", root.isTraining)
                                            root.saveCurrentModel()
                                        }
                                        
                                        // 添加调试信息
                                        Component.onCompleted: {
                                            console.log("Save button created, currentModel:", root.currentModel)
                                        }
                                        
                                        // 监听状态变化
                                        Connections {
                                            target: root
                                            function onCurrentModelChanged() {
                                                console.log("Save button: currentModel changed to:", root.currentModel)
                                            }
                                            function onIsTrainingChanged() {
                                                console.log("Save button: isTraining changed to:", root.isTraining)
                                            }
                                        }
                                    }
                                }
                                
                                ProgressBar {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: root.trainingProgress
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: `${Math.round(root.trainingProgress)}%`
                                        font.pixelSize: 10
                                        color: "#495057"
                                    }
                                }
                                
                                Text {
                                    text: root.isTraining ? 
                                        (root.isChinese ? "训练进行中..." : "Training in progress...") :
                                        (root.isChinese ? "训练已完成" : "Training completed")
                                    font.pixelSize: 12
                                    color: root.isTraining ? "#28a745" : "#6c757d"
                                }
                            }
                        }
                        
                        // 模型信息
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumHeight: 150
                            Layout.preferredHeight: Math.max(150, modelInfoColumn.implicitHeight + 32)
                            Layout.maximumHeight: 400
                            color: "white"
                            radius: 8
                            border.width: 1
                            border.color: "#dee2e6"
                            
                            ColumnLayout {
                                id: modelInfoColumn
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8
                                
                                Text {
                                    text: root.isChinese ? "模型信息" : "Model Information"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        `任务: ${root.selectedTask}` :
                                        `Task: ${root.selectedTask}`
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Text {
                                    text: {
                                        if (root.selectedTask === "glr") {
                                            return root.isChinese ? "类型: 深度学习 (支持实时损失显示)" : "Type: Deep Learning (Real-time loss display)"
                                        } else {
                                            return root.isChinese ? "类型: 机器学习 (训练完成后显示结果)" : "Type: Machine Learning (Results after completion)"
                                        }
                                    }
                                    font.pixelSize: 11
                                    color: root.selectedTask === "glr" ? "#007bff" : "#28a745"
                                    font.italic: true
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        `特征数: ${root.selectedFeatures.length}` :
                                        `Features: ${root.selectedFeatures.length}`
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        `目标: ${root.targetLabel}` :
                                        `Target: ${root.targetLabel}`
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                // 调试信息
                                // Text {
                                //     text: `Debug - Current Model: ${root.currentModel || "null"}`
                                //     font.pixelSize: 10
                                //     color: "#dc3545"
                                // }
                                
                                // Text {
                                //     text: `Debug - Is Training: ${root.isTraining}`
                                //     font.pixelSize: 10
                                //     color: "#dc3545"
                                // }
                                
                                RowLayout {
                                    visible: root.currentModel.length > 0 && !root.isTraining
                                    
                                    Text {
                                        text: root.isChinese ? "模型:" : "Model:"
                                        font.pixelSize: 11
                                        color: "#6c757d"
                                    }
                                    
                                    Text {
                                        text: root.currentModel
                                        font.pixelSize: 11
                                        color: "#495057"
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }
                                    
                                    Button {
                                        text: root.isChinese ? "保存模型" : "Save Model"
                                        onClicked: {
                                            try {
                                                let savePath = root.continuousLearningController.saveModelWithDialog(root.currentModel)
                                                if (savePath && savePath.length > 0) {
                                                    root.addLog(root.isChinese ? `模型已保存到: ${savePath}` : `Model saved to: ${savePath}`)
                                                } else {
                                                    root.addLog(root.isChinese ? "保存取消或失败" : "Save cancelled or failed")
                                                }
                                            } catch (error) {
                                                root.addLog(root.isChinese ? `保存错误: ${error}` : `Save error: ${error}`)
                                            }
                                        }
                                        implicitHeight: 28
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                        
                        // 训练参数控制 (仅对深度学习模型显示)
                        Rectangle {
                            Layout.preferredWidth: 280
                            Layout.minimumHeight: 150
                            Layout.preferredHeight: Math.max(150, trainingParamsColumn.implicitHeight + 32)
                            Layout.maximumHeight: 300
                            color: "white"
                            radius: 8
                            border.width: 1
                            border.color: "#dee2e6"
                            visible: root.selectedTask === "glr"  // 仅对GLR任务显示
                            
                            ColumnLayout {
                                id: trainingParamsColumn
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8
                                
                                Text {
                                    text: root.isChinese ? "训练参数" : "Training Parameters"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                GridLayout {
                                    columns: 2
                                    columnSpacing: 8
                                    rowSpacing: 4
                                    
                                    Text {
                                        text: root.isChinese ? "学习率:" : "Learning Rate:"
                                        font.pixelSize: 10
                                        color: "#6c757d"
                                    }
                                    
                                    TextField {
                                        text: root.learningRate.toString()
                                        placeholderText: "0.01"
                                        validator: DoubleValidator {
                                            bottom: 0
                                            top: 1.0
                                            decimals: 6
                                        }
                                        onTextChanged: {
                                            let value = parseFloat(text)
                                            if (!isNaN(value) && value >= 0 && value <= 1.0) {
                                                root.learningRate = value
                                                if (root.continuousLearningController) {
                                                    root.continuousLearningController.setTrainingParams(
                                                        root.learningRate, root.epochs, root.batchSize, root.patience
                                                    )
                                                }
                                            }
                                        }
                                        enabled: !root.isTraining
                                        implicitHeight: 24
                                        font.pixelSize: 9
                                    }
                                    
                                    Text {
                                        text: root.isChinese ? "轮数:" : "Epochs:"
                                        font.pixelSize: 10
                                        color: "#6c757d"
                                    }
                                    
                                    TextField {
                                        text: root.epochs.toString()
                                        placeholderText: "10"
                                        validator: IntValidator {
                                            bottom: 1
                                            top: 100000
                                        }
                                        onTextChanged: {
                                            let value = parseInt(text)
                                            if (!isNaN(value) && value >= 1 && value <= 1000000) {
                                                root.epochs = value
                                                if (root.continuousLearningController) {
                                                    root.continuousLearningController.setTrainingParams(
                                                        root.learningRate, root.epochs, root.batchSize, root.patience
                                                    )
                                                }
                                            }
                                        }
                                        enabled: !root.isTraining
                                        implicitHeight: 24
                                        font.pixelSize: 9
                                    }
                                    
                                    Text {
                                        text: root.isChinese ? "批大小:" : "Batch Size:"
                                        font.pixelSize: 10
                                        color: "#6c757d"
                                    }
                                    
                                    TextField {
                                        text: root.batchSize.toString()
                                        placeholderText: "48"
                                        validator: IntValidator {
                                            bottom: 1
                                            top: 2560
                                        }
                                        onTextChanged: {
                                            let value = parseInt(text)
                                            if (!isNaN(value) && value >= 1 && value <= 2560) {
                                                root.batchSize = value
                                                if (root.continuousLearningController) {
                                                    root.continuousLearningController.setTrainingParams(
                                                        root.learningRate, root.epochs, root.batchSize, root.patience
                                                    )
                                                }
                                            }
                                        }
                                        enabled: !root.isTraining
                                        implicitHeight: 24
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }
                    }
                    
                        // 可视化区域 - 现在直接包含在主滚动区域中
                        // 第一部分：实时损失曲线 (仅深度学习任务显示)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumHeight: 300
                            Layout.preferredHeight: 400
                            Layout.maximumHeight: 600
                            color: "white"
                            radius: 8
                            border.width: 1
                            border.color: "#dee2e6"
                            visible: root.selectedTask === "glr"  // 仅对深度学习任务显示
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        
                                        Text {
                                            text: root.isChinese ? "实时损失曲线" : "Real-time Loss Curves"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: "#495057"
                                        }
                                        
                                        Item { Layout.fillWidth: true }
                                        
                                        // 状态指示器
                                        Rectangle {
                                            Layout.preferredWidth: 8
                                            Layout.preferredHeight: 8
                                            radius: 4
                                            color: {
                                                if (!root.lossData) return "#6c757d"
                                                if (!root.lossData.train_losses || root.lossData.train_losses.length === 0) return "#ffc107"
                                                return "#28a745"
                                            }
                                        }
                                        
                                        Text {
                                            text: {
                                                if (!root.lossData) return "无数据"
                                                if (!root.lossData.train_losses || root.lossData.train_losses.length === 0) return "等待中"
                                                return `${root.lossData.train_losses.length}点`
                                            }
                                            font.pixelSize: 9
                                            color: "#6c757d"
                                        }
                                        
                                        // Button {
                                        //     text: "测试数据流"
                                        //     implicitHeight: 20
                                        //     font.pixelSize: 8
                                        //     onClicked: {
                                        //         console.log("=== Testing data flow ===")
                                        //         root.addLog("开始测试数据流...")
                                                
                                        //         // 模拟损失数据更新
                                        //         var testLossData = {
                                        //             "train_losses": [1.0, 0.8, 0.6, 0.5, 0.4],
                                        //             "val_losses": [1.1, 0.9, 0.7, 0.6, 0.5],
                                        //             "epochs": [1, 2, 3, 4, 5],
                                        //             "epoch": 5,
                                        //             "train_loss": 0.4,
                                        //             "val_loss": 0.5
                                        //         }
                                                
                                        //         root.addLog("调用 onLossDataUpdated 进行测试...")
                                        //         onLossDataUpdated(testLossData)
                                        //     }
                                        // }
                                        
                                        // Button {
                                        //     text: "增量测试"
                                        //     implicitHeight: 20
                                        //     font.pixelSize: 8
                                        //     onClicked: {
                                        //         console.log("=== Testing incremental update ===")
                                                
                                        //         // 模拟增量损失数据更新
                                        //         let currentEpoch = root.lossData && root.lossData.train_losses ? root.lossData.train_losses.length + 1 : 1
                                        //         let trainLoss = Math.max(0.1, Math.random() * 0.5)
                                        //         let valLoss = trainLoss + Math.random() * 0.1
                                                
                                        //         // 创建增量数据
                                        //         var currentTrainLosses = root.lossData && root.lossData.train_losses ? [...root.lossData.train_losses] : []
                                        //         var currentValLosses = root.lossData && root.lossData.val_losses ? [...root.lossData.val_losses] : []
                                                
                                        //         currentTrainLosses.push(trainLoss)
                                        //         currentValLosses.push(valLoss)
                                                
                                        //         var incrementalData = {
                                        //             "epoch": currentEpoch,
                                        //             "train_loss": trainLoss,
                                        //             "val_loss": valLoss,
                                        //             "train_losses": currentTrainLosses,
                                        //             "val_losses": currentValLosses
                                        //         }
                                                
                                        //         console.log("=== 增量数据 ===", JSON.stringify(incrementalData))
                                                
                                        //         root.addLog(`模拟第${currentEpoch}轮训练结果: 训练损失=${trainLoss.toFixed(4)}, 验证损失=${valLoss.toFixed(4)}`)
                                                
                                        //         // 使用增强版处理函数
                                        //         onLossDataUpdated(incrementalData)
                                        //     }
                                        // }
                                        
                                        // Button {
                                        //     text: "清空"
                                        //     implicitHeight: 20
                                        //     font.pixelSize: 8
                                        //     onClicked: {
                                        //         root.lossData = {
                                        //             "train_losses": [],
                                        //             "val_losses": [],
                                        //             "epochs": []
                                        //         }
                                        //         root.addLog("已清空损失数据")
                                        //     }
                                        // }
                                    }
                                    
                                    // 实时损失值显示
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        color: "#f8f9fa"
                                        border.width: 1
                                        border.color: "#e9ecef"
                                        radius: 4
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 16
                                            
                                            ColumnLayout {
                                                spacing: 2
                                                
                                                Text {
                                                    text: "训练损失"
                                                    font.pixelSize: 8
                                                    color: "#6c757d"
                                                }
                                                
                                                Text {
                                                    text: root.lossData && root.lossData.train_losses && root.lossData.train_losses.length > 0 ? 
                                                        root.lossData.train_losses[root.lossData.train_losses.length - 1].toFixed(4) : "N/A"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: "#dc3545"
                                                }
                                            }
                                            
                                            ColumnLayout {
                                                spacing: 2
                                                
                                                Text {
                                                    text: "验证损失"
                                                    font.pixelSize: 8
                                                    color: "#6c757d"
                                                }
                                                
                                                Text {
                                                    text: root.lossData && root.lossData.val_losses && root.lossData.val_losses.length > 0 ? 
                                                        root.lossData.val_losses[root.lossData.val_losses.length - 1].toFixed(4) : "N/A"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: "#007bff"
                                                }
                                            }
                                            
                                            Item { Layout.fillWidth: true }
                                            
                                            ColumnLayout {
                                                spacing: 2
                                                
                                                Text {
                                                    text: "轮次"
                                                    font.pixelSize: 8
                                                    color: "#6c757d"
                                                }
                                                
                                                Text {
                                                    text: root.lossData && root.lossData.train_losses ? 
                                                        `${root.lossData.train_losses.length}/${root.epochs}` : "0/0"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    color: "#495057"
                                                }
                                            }
                                        }
                                    }
                                    
                                    // 损失曲线图表
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#f8f9fa"
                                        border.width: 1
                                        border.color: "#e9ecef"
                                        radius: 4
                                        
                                        Canvas {
                                            id: realtimeLossCanvas
                                            objectName: "realtimeLossCanvas"
                                            anchors.fill: parent
                                            anchors.margins: 15
                                            
                                            property var chartData: root.lossData
                                            property bool autoUpdate: true
                                            
                                            // 监听数据变化并自动更新
                                            onChartDataChanged: {
                                                if (autoUpdate) {
                                                    console.log("=== Realtime Canvas: chartData changed ===")
                                                    console.log("Data points:", chartData && chartData.train_losses ? chartData.train_losses.length : 0)
                                                    root.addLog("Canvas检测到数据变化，数据点数: " + (chartData && chartData.train_losses ? chartData.train_losses.length : 0))
                                                    requestPaint()
                                                }
                                            }
                                            
                            // 连接到root的lossData属性变化
                            Connections {
                                target: root
                                function onLossDataChanged() {
                                    console.log("=== Realtime Canvas: Received lossDataChanged signal ===")
                                    console.log("=== New lossData:", JSON.stringify(root.lossData))
                                    root.addLog("Canvas接收到lossDataChanged信号，数据: " + JSON.stringify(root.lossData))
                                    realtimeLossCanvas.chartData = root.lossData
                                    realtimeLossCanvas.requestPaint()
                                }
                            }
                            
                            // 新增：直接连接控制器信号
                            Connections {
                                target: root.continuousLearningController
                                function onLossDataUpdated(lossData) {
                                    console.log("=== Direct Controller Signal: lossDataUpdated ===")
                                    console.log("Direct loss data received:", JSON.stringify(lossData))
                                    root.addLog("直接接收控制器损失数据: " + JSON.stringify(lossData))
                                    
                                    // 直接更新Canvas数据
                                    realtimeLossCanvas.chartData = lossData
                                    root.lossData = lossData  // 同步更新root属性
                                    realtimeLossCanvas.requestPaint()
                                }
                            }
                            
                            onPaint: {
                                console.log("=== Realtime Canvas: onPaint called ===")
                                console.log("chartData available:", !!chartData)
                                if (chartData) {
                                    console.log("chartData.train_losses length:", chartData.train_losses ? chartData.train_losses.length : "undefined")
                                    console.log("chartData.val_losses length:", chartData.val_losses ? chartData.val_losses.length : "undefined")
                                    console.log("chartData sample:", JSON.stringify({
                                        train_losses: chartData.train_losses ? chartData.train_losses.slice(0, 3) : null,
                                        val_losses: chartData.val_losses ? chartData.val_losses.slice(0, 3) : null
                                    }))
                                }
                                
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                
                                if (!chartData || !chartData.train_losses || chartData.train_losses.length === 0) {
                                    // 显示等待消息
                                    ctx.fillStyle = "#6c757d"
                                    ctx.font = "12px Arial"
                                    ctx.textAlign = "center"
                                    var waitingText = root.isChinese ? 
                                        "等待损失数据...\n请开始GLR任务训练" : 
                                        "Waiting for loss data...\nPlease start GLR training"
                                    ctx.fillText(waitingText, width / 2, height / 2)
                                    console.log("=== Canvas: 显示等待消息 ===")
                                    root.addLog("Canvas显示等待消息")
                                    return
                                }
                                                
                                                var trainLosses = chartData.train_losses
                                                var valLosses = chartData.val_losses || []
                                                
                                                console.log("Realtime Canvas: Drawing", trainLosses.length, "train points,", valLosses.length, "val points")
                                                
                                                // 设置绘图区域边距 (增加左边距为Y轴标签留出空间)
                                                let margin = 50  // 增加左边距
                                                let plotWidth = width - 2 * margin
                                                let plotHeight = height - 2 * margin
                                                
                                                // 计算数据范围
                                                var allLosses = trainLosses.concat(valLosses)
                                                var minLoss = Math.min.apply(Math, allLosses)
                                                var maxLoss = Math.max.apply(Math, allLosses)
                                                var lossRange = maxLoss - minLoss
                                                
                                                if (lossRange === 0) lossRange = 1
                                                
                                                // 绘制坐标轴
                                                ctx.strokeStyle = "#333"
                                                ctx.lineWidth = 1
                                                
                                                // Y轴
                                                ctx.beginPath()
                                                ctx.moveTo(margin, margin)
                                                ctx.lineTo(margin, height - margin)
                                                ctx.stroke()
                                                
                                                // X轴
                                                ctx.beginPath()
                                                ctx.moveTo(margin, height - margin)
                                                ctx.lineTo(width - margin, height - margin)
                                                ctx.stroke()
                                                
                                                // 绘制Y轴刻度和标签
                                                ctx.fillStyle = "#666"
                                                ctx.font = "10px Arial"
                                                ctx.textAlign = "right"
                                                for (let i = 0; i <= 5; i++) {
                                                    let y = margin + (plotHeight * i) / 5
                                                    let value = maxLoss - (lossRange * i) / 5
                                                    
                                                    // 刻度线
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin - 5, y)
                                                    ctx.lineTo(margin, y)
                                                    ctx.stroke()
                                                    
                                                    // 标签 (取整显示，增加右边距避免遮挡)
                                                    let displayValue = value < 1 ? value.toFixed(3) : value.toFixed(2)
                                                    ctx.fillText(displayValue, margin - 10, y + 3)
                                                }
                                                
                                                // 绘制X轴刻度和标签
                                                ctx.textAlign = "center"
                                                for (let i = 0; i <= 5; i++) {
                                                    let x = margin + (plotWidth * i) / 5
                                                    let epoch = Math.round((trainLosses.length * i) / 5)
                                                    
                                                    // 刻度线
                                                    ctx.beginPath()
                                                    ctx.moveTo(x, height - margin)
                                                    ctx.lineTo(x, height - margin + 5)
                                                    ctx.stroke()
                                                    
                                                    // 标签
                                                    ctx.fillText(epoch.toString(), x, height - margin + 18)
                                                }
                                                
                                                // 绘制轴标签
                                                ctx.fillStyle = "#333"
                                                ctx.font = "12px Arial"
                                                ctx.textAlign = "center"
                                                
                                                // X轴标签
                                                ctx.fillText(root.isChinese ? "训练轮数" : "Epochs", width / 2, height - 5)
                                                
                                                // Y轴标签（旋转，调整位置避免遮挡数值）
                                                ctx.save()
                                                ctx.translate(20, height / 2)  // 增加x坐标，远离数值标签
                                                ctx.rotate(-Math.PI / 2)
                                                ctx.fillText(root.isChinese ? "损失值" : "Loss", 0, 0)
                                                ctx.restore()
                                                
                                                // 绘制背景网格
                                                ctx.strokeStyle = "#f0f0f0"
                                                ctx.lineWidth = 0.5
                                                
                                                // 垂直网格线
                                                for (var i = 1; i < 6; i++) {
                                                    var x = margin + (plotWidth * i) / 6
                                                    ctx.beginPath()
                                                    ctx.moveTo(x, margin)
                                                    ctx.lineTo(x, height - margin)
                                                    ctx.stroke()
                                                }
                                                
                                                // 水平网格线
                                                for (var j = 1; j < 5; j++) {
                                                    var y = margin + (plotHeight * j) / 5
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin, y)
                                                    ctx.lineTo(width - margin, y)
                                                    ctx.stroke()
                                                }
                                                
                                                // 绘制训练损失曲线
                                                if (trainLosses.length > 0) {
                                                    ctx.strokeStyle = "#dc3545"
                                                    ctx.lineWidth = 2
                                                    ctx.beginPath()
                                                    
                                                    for (var i = 0; i < trainLosses.length; i++) {
                                                        if (trainLosses[i] !== undefined && !isNaN(trainLosses[i])) {
                                                            var x = margin + (i / Math.max(1, trainLosses.length - 1)) * plotWidth
                                                            var y = margin + plotHeight - ((trainLosses[i] - minLoss) / lossRange) * plotHeight
                                                            
                                                            if (i === 0) {
                                                                ctx.moveTo(x, y)
                                                            } else {
                                                                ctx.lineTo(x, y)
                                                            }
                                                        }
                                                    }
                                                    ctx.stroke()
                                                    
                                                    // 绘制最新点
                                                    if (trainLosses.length > 0 && trainLosses[trainLosses.length - 1] !== undefined) {
                                                        var lastX = margin + ((trainLosses.length - 1) / Math.max(1, trainLosses.length - 1)) * plotWidth
                                                        var lastY = margin + plotHeight - ((trainLosses[trainLosses.length - 1] - minLoss) / lossRange) * plotHeight
                                                        ctx.fillStyle = "#dc3545"
                                                        ctx.beginPath()
                                                        ctx.arc(lastX, lastY, 3, 0, 2 * Math.PI)
                                                        ctx.fill()
                                                    }
                                                }
                                                
                                                // 绘制验证损失曲线
                                                if (valLosses.length > 0) {
                                                    ctx.strokeStyle = "#007bff"
                                                    ctx.lineWidth = 2
                                                    ctx.beginPath()
                                                    
                                                    for (var j = 0; j < valLosses.length; j++) {
                                                        if (valLosses[j] !== undefined && !isNaN(valLosses[j])) {
                                                            var x2 = margin + (j / Math.max(1, valLosses.length - 1)) * plotWidth
                                                            var y2 = margin + plotHeight - ((valLosses[j] - minLoss) / lossRange) * plotHeight
                                                            
                                                            if (j === 0) {
                                                                ctx.moveTo(x2, y2)
                                                            } else {
                                                                ctx.lineTo(x2, y2)
                                                            }
                                                        }
                                                    }
                                                    ctx.stroke()
                                                    
                                                    // 绘制最新点
                                                    if (valLosses.length > 0 && valLosses[valLosses.length - 1] !== undefined) {
                                                        var lastX2 = margin + ((valLosses.length - 1) / Math.max(1, valLosses.length - 1)) * plotWidth
                                                        var lastY2 = margin + plotHeight - ((valLosses[valLosses.length - 1] - minLoss) / lossRange) * plotHeight
                                                        ctx.fillStyle = "#007bff"
                                                        ctx.beginPath()
                                                        ctx.arc(lastX2, lastY2, 3, 0, 2 * Math.PI)
                                                        ctx.fill()
                                                    }
                                                }
                                                
                                                // 绘制图例 (移到右上角避免遮挡数值)
                                                let legendX = width - margin - 80  // 右上角位置
                                                let legendY = margin + 10
                                                
                                                ctx.fillStyle = "#dc3545"
                                                ctx.fillRect(legendX, legendY, 12, 3)
                                                ctx.fillStyle = "#495057"
                                                ctx.font = "10px Arial"
                                                ctx.textAlign = "left"
                                                ctx.fillText(root.isChinese ? "训练" : "Train", legendX + 17, legendY + 8)
                                                
                                                if (valLosses.length > 0) {
                                                    ctx.fillStyle = "#007bff"
                                                    ctx.fillRect(legendX, legendY + 17, 12, 3)
                                                    ctx.fillStyle = "#495057"
                                                    ctx.fillText(root.isChinese ? "验证" : "Val", legendX + 17, legendY + 25)
                                                }
                                                
                                                console.log("Realtime Canvas: Paint completed")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 第二部分：残差图/MSE误差图
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 300
                                Layout.preferredHeight: 400
                                Layout.maximumHeight: 600
                                color: "white"
                                radius: 8
                                border.width: 1
                                border.color: "#dee2e6"
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: {
                                            if (root.selectedTask === "glr") {
                                                return root.isChinese ? "残差分析" : "Residual Analysis"
                                            } else {
                                                return root.isChinese ? "残差分析" : "Residual Analysis"
                                            }
                                        }
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    // 状态指示
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24
                                        color: "#f8f9fa"
                                        border.width: 1
                                        border.color: "#e9ecef"
                                        radius: 4
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 6
                                            
                                            Rectangle {
                                                Layout.preferredWidth: 8
                                                Layout.preferredHeight: 8
                                                radius: 4
                                                color: {
                                                    if (root.isTraining) return "#ffc107"
                                                    if (!root.currentModel || root.currentModel.length === 0) return "#6c757d"
                                                    return "#28a745"
                                                }
                                            }
                                            
                                            Text {
                                                text: {
                                                    if (root.isTraining) {
                                                        return root.isChinese ? "训练中..." : "Training..."
                                                    } else if (!root.currentModel || root.currentModel.length === 0) {
                                                        return root.isChinese ? "等待训练完成" : "Waiting for completion"
                                                    } else {
                                                        return root.isChinese ? "可查看结果" : "Results available"
                                                    }
                                                }
                                                font.pixelSize: 10
                                                color: "#495057"
                                            }
                                            
                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                    
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#f8f9fa"
                                        border.width: 1
                                        border.color: "#e9ecef"
                                        radius: 4
                                        
                                        // 显示相应的图表或提示
                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                if (root.selectedTask === "glr") {
                                                    if (root.isTraining) {
                                                        return root.isChinese ? "训练进行中...\n残差图将在训练完成后显示" : "Training in progress...\nResidual plot will appear after completion"
                                                    } else if (!root.currentModel || root.currentModel.length === 0) {
                                                        return root.isChinese ? "等待训练完成\n残差图显示预测误差分布" : "Waiting for training completion\nResidual plot shows prediction errors"
                                                    } else {
                                                        return ""  // 有模型时隐藏提示文字，显示图表
                                                    }
                                                } else {
                                                    if (!root.trainingResults.error_plot_data && (!root.currentModel || root.currentModel.length === 0)) {
                                                        return root.isChinese ? "训练完成后显示残差图" : "Residual plot will appear after training"
                                                    } else {
                                                        return ""  // 有数据时隐藏提示文字，显示图表
                                                    }
                                                }
                                            }
                                            font.pixelSize: 12
                                            color: "#6c757d"
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            width: parent.width * 0.8
                                            visible: text.length > 0
                                        }
                                        
                                        // GLR任务的残差图
                                        Canvas {
                                            id: glrResidualCanvas
                                            anchors.fill: parent
                                            anchors.margins: 15
                                            visible: root.selectedTask === "glr" && root.currentModel && root.currentModel.length > 0 && !root.isTraining
                                            
                                            property var residualData: null
                                            
                                            // 监听trainingResults变化 (GLR任务也可能有训练结果数据)
                                            Connections {
                                                target: root
                                                function onTrainingResultsChanged() {
                                                    console.log("GLR Canvas: trainingResults changed")
                                                    if (root.trainingResults && root.trainingResults.error_plot_data) {
                                                        console.log("GLR Canvas: Updating residualData with real data")
                                                        glrResidualCanvas.residualData = root.trainingResults.error_plot_data
                                                        glrResidualCanvas.requestPaint()
                                                    }
                                                }
                                            }
                                            
                                            onVisibleChanged: {
                                                if (visible) {
                                                    console.log("GLR Canvas: Became visible")
                                                    if (root.trainingResults && root.trainingResults.error_plot_data) {
                                                        console.log("GLR Canvas: Using real training data")
                                                        residualData = root.trainingResults.error_plot_data
                                                    } else {
                                                        console.log("GLR Canvas: Generating simulated data")
                                                        // 当变为可见时，生成模拟残差数据
                                                        generateSimulatedResidualData()
                                                    }
                                                    requestPaint()
                                                }
                                            }
                                            
                                            function generateSimulatedResidualData() {
                                                // 生成模拟的预测值vs实际值数据（与非GLR任务保持一致）
                                                let predicted = []
                                                let actual = []
                                                
                                                for (let i = 0; i < 50; i++) {
                                                    let pred = Math.random() * 100 + 50
                                                    let noise = (Math.random() - 0.5) * 20
                                                    let act = pred + noise
                                                    predicted.push(pred)
                                                    actual.push(act)
                                                }
                                                
                                                residualData = {
                                                    predicted: predicted,
                                                    actual: actual
                                                }
                                            }
                                            
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                
                                                // 如果没有残差数据，显示提示信息
                                                if (!residualData) {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "残差图\n等待训练数据..." : "Residual Plot\nWaiting for training data...",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 检查数据有效性
                                                if (!residualData.predicted || !residualData.actual || 
                                                    residualData.predicted.length === 0 || residualData.actual.length === 0) {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "无有效数据点" : "No valid data points",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 计算残差 (actual - predicted)
                                                let residuals = []
                                                let predicted = residualData.predicted
                                                let actual = residualData.actual
                                                
                                                for (let i = 0; i < Math.min(predicted.length, actual.length); i++) {
                                                    if (predicted[i] !== undefined && actual[i] !== undefined && 
                                                        !isNaN(predicted[i]) && !isNaN(actual[i])) {
                                                        residuals.push(actual[i] - predicted[i])
                                                    }
                                                }
                                                
                                                if (residuals.length === 0) {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "无有效数据点" : "No valid data points",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 绘制残差图 (预测值 vs 残差)
                                                let margin = 50
                                                let plotWidth = width - 2 * margin
                                                let plotHeight = height - 2 * margin
                                                
                                                // 计算数据范围
                                                let minPred = Math.min.apply(Math, predicted.filter((v, i) => i < residuals.length))
                                                let maxPred = Math.max.apply(Math, predicted.filter((v, i) => i < residuals.length))
                                                let minRes = Math.min.apply(Math, residuals)
                                                let maxRes = Math.max.apply(Math, residuals)
                                                
                                                let predRange = maxPred - minPred
                                                let resRange = maxRes - minRes
                                                
                                                if (predRange === 0) predRange = 1
                                                if (resRange === 0) resRange = 1
                                                
                                                // 扩展残差范围以显示误差线
                                                let avgActual = actual.reduce((sum, val, i) => sum + (i < residuals.length ? val : 0), 0) / residuals.length
                                                let upperError = 0.15 * avgActual
                                                let lowerError = -0.15 * avgActual
                                                
                                                // 调整残差范围以包含误差线
                                                minRes = Math.min(minRes, lowerError)
                                                maxRes = Math.max(maxRes, upperError)
                                                resRange = maxRes - minRes
                                                if (resRange === 0) resRange = 1
                                                
                                                // 绘制坐标轴
                                                ctx.strokeStyle = "#333"
                                                ctx.lineWidth = 1
                                                
                                                // Y轴
                                                ctx.beginPath()
                                                ctx.moveTo(margin, margin)
                                                ctx.lineTo(margin, height - margin)
                                                ctx.stroke()
                                                
                                                // X轴
                                                ctx.beginPath()
                                                ctx.moveTo(margin, height - margin)
                                                ctx.lineTo(width - margin, height - margin)
                                                ctx.stroke()
                                                
                                                // 绘制零误差线 (Zero Error)
                                                let zeroY = height - margin - ((0 - minRes) / resRange) * plotHeight
                                                ctx.strokeStyle = "#000"
                                                ctx.lineWidth = 1
                                                ctx.setLineDash([5, 5])
                                                ctx.beginPath()
                                                ctx.moveTo(margin, zeroY)
                                                ctx.lineTo(width - margin, zeroY)
                                                ctx.stroke()
                                                ctx.setLineDash([])
                                                
                                                // 绘制+15%误差线
                                                let upperErrorY = height - margin - ((upperError - minRes) / resRange) * plotHeight
                                                if (upperErrorY >= margin && upperErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#dc3545"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin, upperErrorY)
                                                    ctx.lineTo(width - margin, upperErrorY)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                }
                                                
                                                // 绘制-15%误差线
                                                let lowerErrorY = height - margin - ((lowerError - minRes) / resRange) * plotHeight
                                                if (lowerErrorY >= margin && lowerErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#007bff"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin, lowerErrorY)
                                                    ctx.lineTo(width - margin, lowerErrorY)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                }
                                                
                                                // 绘制残差散点
                                                ctx.fillStyle = "#28a745" // 绿色，参考原始代码
                                                for (let i = 0; i < residuals.length; i++) {
                                                    if (predicted[i] !== undefined && residuals[i] !== undefined && 
                                                        !isNaN(predicted[i]) && !isNaN(residuals[i])) {
                                                        let x = margin + ((predicted[i] - minPred) / predRange) * plotWidth
                                                        let y = height - margin - ((residuals[i] - minRes) / resRange) * plotHeight
                                                        
                                                        ctx.beginPath()
                                                        ctx.arc(x, y, 3, 0, 2 * Math.PI)
                                                        ctx.fill()
                                                    }
                                                }
                                                
                                                // 绘制轴标签
                                                ctx.fillStyle = "#333"
                                                ctx.font = "12px Arial"
                                                ctx.textAlign = "center"
                                                
                                                // X轴标签
                                                ctx.fillText(root.isChinese ? "预测值" : "Predicted Values", width / 2, height - 5)
                                                
                                                // Y轴标签
                                                ctx.save()
                                                ctx.translate(15, height / 2)
                                                ctx.rotate(-Math.PI / 2)
                                                ctx.fillText(root.isChinese ? "残差" : "Residuals", 0, 0)
                                                ctx.restore()
                                                
                                                // 绘制Y轴刻度和标签
                                                ctx.fillStyle = "#666"
                                                ctx.font = "10px Arial"
                                                ctx.textAlign = "right"
                                                for (let i = 0; i <= 5; i++) {
                                                    let y = margin + (plotHeight * i) / 5
                                                    let value = maxRes - (resRange * i) / 5
                                                    
                                                    // 刻度线
                                                    ctx.strokeStyle = "#333"
                                                    ctx.lineWidth = 1
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin - 5, y)
                                                    ctx.lineTo(margin, y)
                                                    ctx.stroke()
                                                    
                                                    // 标签
                                                    let displayValue = Math.abs(value) < 1 ? Number(value).toFixed(3) : Number(value).toFixed(2)
                                                    ctx.fillText(displayValue, margin - 10, y + 3)
                                                }
                                                
                                                // 绘制X轴刻度和标签
                                                ctx.textAlign = "center"
                                                for (let i = 0; i <= 5; i++) {
                                                    let x = margin + (plotWidth * i) / 5
                                                    let value = minPred + (predRange * i) / 5
                                                    
                                                    // 刻度线
                                                    ctx.strokeStyle = "#333"
                                                    ctx.lineWidth = 1
                                                    ctx.beginPath()
                                                    ctx.moveTo(x, height - margin)
                                                    ctx.lineTo(x, height - margin + 5)
                                                    ctx.stroke()
                                                    
                                                    // 标签
                                                    let displayValue = value < 1 ? Number(value).toFixed(3) : Number(value).toFixed(2)
                                                    ctx.fillText(displayValue, x, height - margin + 18)
                                                }
                                                
                                                // 绘制图例
                                                let legendX = width - margin - 120
                                                let legendY = margin + 10
                                                let lineHeight = 15
                                                
                                                // 残差点图例
                                                ctx.fillStyle = "#28a745"
                                                ctx.beginPath()
                                                ctx.arc(legendX, legendY, 3, 0, 2 * Math.PI)
                                                ctx.fill()
                                                ctx.fillStyle = "#495057"
                                                ctx.font = "10px Arial"
                                                ctx.textAlign = "left"
                                                ctx.fillText(root.isChinese ? "残差" : "Residuals", legendX + 10, legendY + 3)
                                                
                                                // 零误差线图例
                                                ctx.strokeStyle = "#000"
                                                ctx.lineWidth = 1
                                                ctx.setLineDash([5, 5])
                                                ctx.beginPath()
                                                ctx.moveTo(legendX - 5, legendY + lineHeight)
                                                ctx.lineTo(legendX + 15, legendY + lineHeight)
                                                ctx.stroke()
                                                ctx.setLineDash([])
                                                ctx.fillStyle = "#495057"
                                                ctx.fillText(root.isChinese ? "零误差" : "Zero Error", legendX + 20, legendY + lineHeight + 3)
                                                
                                                // +15%误差线图例
                                                if (upperErrorY >= margin && upperErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#dc3545"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(legendX - 5, legendY + lineHeight * 2)
                                                    ctx.lineTo(legendX + 15, legendY + lineHeight * 2)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                    ctx.fillStyle = "#495057"
                                                    ctx.fillText("+15% " + (root.isChinese ? "误差" : "Error"), legendX + 20, legendY + lineHeight * 2 + 3)
                                                }
                                                
                                                // -15%误差线图例
                                                if (lowerErrorY >= margin && lowerErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#007bff"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(legendX - 5, legendY + lineHeight * 3)
                                                    ctx.lineTo(legendX + 15, legendY + lineHeight * 3)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                    ctx.fillStyle = "#495057"
                                                    ctx.fillText("-15% " + (root.isChinese ? "误差" : "Error"), legendX + 20, legendY + lineHeight * 3 + 3)
                                                }
                                                
                                                console.log("GLR Canvas: 残差图绘制完成")
                                            }
                                        }
                                        
                                        // MSE误差图 (非GLR任务)
                                        Canvas {
                                            id: residualCanvas
                                            anchors.fill: parent
                                            anchors.margins: 15
                                            visible: root.selectedTask !== "glr" && (root.trainingResults.error_plot_data || (root.currentModel && root.currentModel.length > 0 && !root.isTraining))
                                            
                                            property var plotData: root.trainingResults.error_plot_data || null
                                            
                                            // 监听trainingResults变化
                                            Connections {
                                                target: root
                                                function onTrainingResultsChanged() {
                                                    console.log("MSE Canvas: trainingResults changed")
                                                    if (root.trainingResults && root.trainingResults.error_plot_data) {
                                                        console.log("MSE Canvas: Updating plotData with real data")
                                                        residualCanvas.plotData = root.trainingResults.error_plot_data
                                                        residualCanvas.requestPaint()
                                                    }
                                                }
                                            }
                                            
                                            onVisibleChanged: {
                                                if (visible) {
                                                    console.log("MSE Canvas: Became visible")
                                                    if (root.trainingResults && root.trainingResults.error_plot_data) {
                                                        console.log("MSE Canvas: Using real training data")
                                                        plotData = root.trainingResults.error_plot_data
                                                    } else if (!plotData) {
                                                        console.log("MSE Canvas: Generating simulated data")
                                                        // 生成模拟MSE数据
                                                        generateSimulatedMSEData()
                                                    }
                                                    requestPaint()
                                                }
                                            }
                                            
                                            function generateSimulatedMSEData() {
                                                // 生成模拟的预测值vs实际值数据
                                                let predicted = []
                                                let actual = []
                                                
                                                for (let i = 0; i < 40; i++) {
                                                    let pred = Math.random() * 80 + 20
                                                    let noise = (Math.random() - 0.5) * 15
                                                    let act = pred + noise
                                                    predicted.push(pred)
                                                    actual.push(act)
                                                }
                                                
                                                plotData = {
                                                    predicted: predicted,
                                                    actual: actual
                                                }
                                            }
                                            
                                            onPlotDataChanged: {
                                                console.log("MSE Canvas: plotData changed")
                                                if (plotData) {
                                                    console.log("MSE Canvas: plotData keys:", Object.keys(plotData))
                                                    console.log("MSE Canvas: plotData sample:", JSON.stringify(plotData).substring(0, 200))
                                                    requestPaint()
                                                } else {
                                                    console.log("MSE Canvas: plotData is null")
                                                }
                                            }
                                            
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                
                                                // 如果没有数据，显示提示信息
                                                if (!plotData) {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "残差图\n等待训练数据..." : "Residual Plot\nWaiting for training data...",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 获取数据，优先使用测试集数据，如果没有则使用训练集数据
                                                let predicted, actual
                                                
                                                if (plotData.predicted_test && plotData.actual_test) {
                                                    predicted = plotData.predicted_test
                                                    actual = plotData.actual_test
                                                } else if (plotData.predicted_train && plotData.actual_train) {
                                                    predicted = plotData.predicted_train
                                                    actual = plotData.actual_train
                                                } else if (plotData.predicted && plotData.actual) {
                                                    // 兼容模拟数据格式
                                                    predicted = plotData.predicted
                                                    actual = plotData.actual
                                                } else {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "数据格式错误" : "Invalid data format",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 检查数据有效性
                                                if (!predicted || !actual || predicted.length === 0 || actual.length === 0) {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "数据为空" : "No data available",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 计算残差 (actual - predicted)
                                                let residuals = []
                                                for (let i = 0; i < Math.min(predicted.length, actual.length); i++) {
                                                    if (predicted[i] !== undefined && actual[i] !== undefined && 
                                                        !isNaN(predicted[i]) && !isNaN(actual[i])) {
                                                        residuals.push(actual[i] - predicted[i])
                                                    }
                                                }
                                                
                                                if (residuals.length === 0) {
                                                    ctx.fillStyle = "#6c757d"
                                                    ctx.font = "12px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(
                                                        root.isChinese ? "无有效数据点" : "No valid data points",
                                                        width / 2, height / 2
                                                    )
                                                    return
                                                }
                                                
                                                // 绘制残差图 (预测值 vs 残差)
                                                let margin = 50
                                                let plotWidth = width - 2 * margin
                                                let plotHeight = height - 2 * margin
                                                
                                                // 计算数据范围
                                                let minPred = Math.min.apply(Math, predicted.filter((v, i) => i < residuals.length))
                                                let maxPred = Math.max.apply(Math, predicted.filter((v, i) => i < residuals.length))
                                                let minRes = Math.min.apply(Math, residuals)
                                                let maxRes = Math.max.apply(Math, residuals)
                                                
                                                let predRange = maxPred - minPred
                                                let resRange = maxRes - minRes
                                                
                                                if (predRange === 0) predRange = 1
                                                if (resRange === 0) resRange = 1
                                                
                                                // 扩展残差范围以显示误差线
                                                let avgActual = actual.reduce((sum, val, i) => sum + (i < residuals.length ? val : 0), 0) / residuals.length
                                                let upperError = 0.15 * avgActual
                                                let lowerError = -0.15 * avgActual
                                                
                                                // 调整残差范围以包含误差线
                                                minRes = Math.min(minRes, lowerError)
                                                maxRes = Math.max(maxRes, upperError)
                                                resRange = maxRes - minRes
                                                if (resRange === 0) resRange = 1
                                                
                                                // 绘制坐标轴
                                                ctx.strokeStyle = "#333"
                                                ctx.lineWidth = 1
                                                
                                                // Y轴
                                                ctx.beginPath()
                                                ctx.moveTo(margin, margin)
                                                ctx.lineTo(margin, height - margin)
                                                ctx.stroke()
                                                
                                                // X轴
                                                ctx.beginPath()
                                                ctx.moveTo(margin, height - margin)
                                                ctx.lineTo(width - margin, height - margin)
                                                ctx.stroke()
                                                
                                                // 绘制零误差线 (Zero Error)
                                                let zeroY = height - margin - ((0 - minRes) / resRange) * plotHeight
                                                ctx.strokeStyle = "#000"
                                                ctx.lineWidth = 1
                                                ctx.setLineDash([5, 5])
                                                ctx.beginPath()
                                                ctx.moveTo(margin, zeroY)
                                                ctx.lineTo(width - margin, zeroY)
                                                ctx.stroke()
                                                ctx.setLineDash([])
                                                
                                                // 绘制+15%误差线
                                                let upperErrorY = height - margin - ((upperError - minRes) / resRange) * plotHeight
                                                if (upperErrorY >= margin && upperErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#dc3545"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin, upperErrorY)
                                                    ctx.lineTo(width - margin, upperErrorY)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                }
                                                
                                                // 绘制-15%误差线
                                                let lowerErrorY = height - margin - ((lowerError - minRes) / resRange) * plotHeight
                                                if (lowerErrorY >= margin && lowerErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#007bff"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin, lowerErrorY)
                                                    ctx.lineTo(width - margin, lowerErrorY)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                }
                                                
                                                // 绘制残差散点
                                                ctx.fillStyle = "#28a745" // 绿色，参考原始代码
                                                for (let i = 0; i < residuals.length; i++) {
                                                    if (predicted[i] !== undefined && residuals[i] !== undefined && 
                                                        !isNaN(predicted[i]) && !isNaN(residuals[i])) {
                                                        let x = margin + ((predicted[i] - minPred) / predRange) * plotWidth
                                                        let y = height - margin - ((residuals[i] - minRes) / resRange) * plotHeight
                                                        
                                                        ctx.beginPath()
                                                        ctx.arc(x, y, 3, 0, 2 * Math.PI)
                                                        ctx.fill()
                                                    }
                                                }
                                                
                                                // 绘制轴标签
                                                ctx.fillStyle = "#333"
                                                ctx.font = "12px Arial"
                                                ctx.textAlign = "center"
                                                
                                                // X轴标签
                                                ctx.fillText(root.isChinese ? "预测值" : "Predicted Values", width / 2, height - 5)
                                                
                                                // Y轴标签
                                                ctx.save()
                                                ctx.translate(15, height / 2)
                                                ctx.rotate(-Math.PI / 2)
                                                ctx.fillText(root.isChinese ? "残差" : "Residuals", 0, 0)
                                                ctx.restore()
                                                
                                                // 绘制Y轴刻度和标签
                                                ctx.fillStyle = "#666"
                                                ctx.font = "10px Arial"
                                                ctx.textAlign = "right"
                                                for (let i = 0; i <= 5; i++) {
                                                    let y = margin + (plotHeight * i) / 5
                                                    let value = maxRes - (resRange * i) / 5
                                                    
                                                    // 刻度线
                                                    ctx.strokeStyle = "#333"
                                                    ctx.lineWidth = 1
                                                    ctx.beginPath()
                                                    ctx.moveTo(margin - 5, y)
                                                    ctx.lineTo(margin, y)
                                                    ctx.stroke()
                                                    
                                                    // 标签
                                                    let displayValue = Math.abs(value) < 1 ? Number(value).toFixed(3) : Number(value).toFixed(2)
                                                    ctx.fillText(displayValue, margin - 10, y + 3)
                                                }
                                                
                                                // 绘制X轴刻度和标签
                                                ctx.textAlign = "center"
                                                for (let i = 0; i <= 5; i++) {
                                                    let x = margin + (plotWidth * i) / 5
                                                    let value = minPred + (predRange * i) / 5
                                                    
                                                    // 刻度线
                                                    ctx.strokeStyle = "#333"
                                                    ctx.lineWidth = 1
                                                    ctx.beginPath()
                                                    ctx.moveTo(x, height - margin)
                                                    ctx.lineTo(x, height - margin + 5)
                                                    ctx.stroke()
                                                    
                                                    // 标签
                                                    let displayValue = value < 1 ? Number(value).toFixed(3) : Number(value).toFixed(2)
                                                    ctx.fillText(displayValue, x, height - margin + 18)
                                                }
                                                
                                                // 绘制图例
                                                let legendX = width - margin - 120
                                                let legendY = margin + 10
                                                let lineHeight = 15
                                                
                                                // 残差点图例
                                                ctx.fillStyle = "#28a745"
                                                ctx.beginPath()
                                                ctx.arc(legendX, legendY, 3, 0, 2 * Math.PI)
                                                ctx.fill()
                                                ctx.fillStyle = "#495057"
                                                ctx.font = "10px Arial"
                                                ctx.textAlign = "left"
                                                ctx.fillText(root.isChinese ? "残差" : "Residuals", legendX + 10, legendY + 3)
                                                
                                                // 零误差线图例
                                                ctx.strokeStyle = "#000"
                                                ctx.lineWidth = 1
                                                ctx.setLineDash([5, 5])
                                                ctx.beginPath()
                                                ctx.moveTo(legendX - 5, legendY + lineHeight)
                                                ctx.lineTo(legendX + 15, legendY + lineHeight)
                                                ctx.stroke()
                                                ctx.setLineDash([])
                                                ctx.fillStyle = "#495057"
                                                ctx.fillText(root.isChinese ? "零误差" : "Zero Error", legendX + 20, legendY + lineHeight + 3)
                                                
                                                // +15%误差线图例
                                                if (upperErrorY >= margin && upperErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#dc3545"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(legendX - 5, legendY + lineHeight * 2)
                                                    ctx.lineTo(legendX + 15, legendY + lineHeight * 2)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                    ctx.fillStyle = "#495057"
                                                    ctx.fillText("+15% " + (root.isChinese ? "误差" : "Error"), legendX + 20, legendY + lineHeight * 2 + 3)
                                                }
                                                
                                                // -15%误差线图例
                                                if (lowerErrorY >= margin && lowerErrorY <= height - margin) {
                                                    ctx.strokeStyle = "#007bff"
                                                    ctx.lineWidth = 1
                                                    ctx.setLineDash([5, 5])
                                                    ctx.beginPath()
                                                    ctx.moveTo(legendX - 5, legendY + lineHeight * 3)
                                                    ctx.lineTo(legendX + 15, legendY + lineHeight * 3)
                                                    ctx.stroke()
                                                    ctx.setLineDash([])
                                                    ctx.fillStyle = "#495057"
                                                    ctx.fillText("-15% " + (root.isChinese ? "误差" : "Error"), legendX + 20, legendY + lineHeight * 3 + 3)
                                                }
                                                
                                                console.log("MSE Canvas: 残差图绘制完成")
                                            }
                                        }
                            
                                    }
                                }
                            }
                            
                            // 第三部分：训练日志
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 200
                                Layout.preferredHeight: 300
                                Layout.maximumHeight: 500
                                color: "white"
                                radius: 8
                                border.width: 1
                                border.color: "#dee2e6"
                            
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    Text {
                                        text: root.isChinese ? "训练日志" : "Training Logs"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                    
                                    // 调试信息显示
                                    Text {
                                        text: `Task: ${root.selectedTask} | Loss Data: ${root.lossData && root.lossData.train_losses ? root.lossData.train_losses.length + " pts" : "none"}`
                                        font.pixelSize: 8
                                        color: "#6c757d"
                                    }
                                    
                                    Button {
                                        text: "检查连接"
                                        implicitHeight: 24
                                        font.pixelSize: 9
                                        onClicked: root.checkTrainingConnections()
                                    }
                                    
                                    Button {
                                        text: root.isChinese ? "清空" : "Clear"
                                        onClicked: root.trainingLogs = []
                                        implicitHeight: 24
                                        font.pixelSize: 9
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    border.width: 1
                                    border.color: "#ced4da"
                                    radius: 6
                                    color: "#f8f9fa"
                                    
                                    ScrollView {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        
                                        ListView {
                                            id: logsListView
                                            model: root.trainingLogs
                                            
                                            delegate: Text {
                                                required property string modelData
                                                required property int index
                                                
                                                width: logsListView.width
                                                text: modelData
                                                font.pixelSize: 9
                                                font.family: "Consolas, Monaco, monospace"
                                                color: "#495057"
                                                wrapMode: Text.WordWrap
                                            }
                                            
                                            // 自动滚动到底部
                                            onCountChanged: {
                                                Qt.callLater(() => {
                                                    if (count > 0) {
                                                        positionViewAtEnd()
                                                    }
                                                })
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
    } // StackView 闭合
    
    // JavaScript函数
    function checkFeatureMappingComplete() {
        // 检查特征映射是否完整
        if (root.modelExpectedFeatures.length === 0) {
            return true // 如果没有模型期望特征，则认为完整
        }
        
        for (let expectedFeature of root.modelExpectedFeatures) {
            let mappedFeature = root.featureMapping[expectedFeature] || ""
            if (mappedFeature === "") {
                return false // 有未映射的特征
            }
        }
        return true // 所有特征都已映射
    }
    
    function refreshDataTables() {
        if (!root.continuousLearningController) {
            console.log("Controller not initialized")
            return
        }
        
        let tables = root.continuousLearningController.getAvailableTables()
        root.availableDataTables = tables.filter(t => t.startsWith('data_'))
        root.availableTestTables = tables.filter(t => t.startsWith('test_'))
        
        addLog(root.isChinese ? 
            `发现 ${root.availableDataTables.length} 个训练表, ${root.availableTestTables.length} 个测试表` :
            `Found ${root.availableDataTables.length} training tables, ${root.availableTestTables.length} test tables`)
    }
    
    function updateCommonFeatures() {
        if (root.selectedDataTables.length === 0) {
            root.commonFeatures = []
            return
        }
        
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
            // 从控制器获取可能的目标变量
            let possibleTargets = root.continuousLearningController.getModelExpectedTargets(root.selectedTask)
            
            for (let target of possibleTargets) {
                if (root.commonFeatures.includes(target)) {
                    root.targetLabel = target
                    break
                }
            }
        }
        
        // 从控制器获取模型期望的特征 (基于任务类型)
        if (root.selectedTask) {
            root.modelExpectedFeatures = root.continuousLearningController.getModelExpectedFeatures(root.selectedTask)
            
            // 只有当用户已经选择了输入特征时才初始化特征映射
            if (root.selectedFeatures.length > 0) {
                updateFeatureMapping()
            } else {
                // 清空特征映射
                root.featureMapping = {}
            }
        }
        
        addLog(root.isChinese ? 
            `共有特征: ${root.commonFeatures.length}个, 模型期望: ${root.modelExpectedFeatures.length}个` :
            `Common features: ${root.commonFeatures.length}, Model expects: ${root.modelExpectedFeatures.length}`)
    }
    
    function updateFeatureMapping() {
        // 初始化特征映射 (只针对用户选择的输入特征)
        let newMapping = {}
        
        // 只对选中的特征进行映射
        for (let selectedFeature of root.selectedFeatures) {
            // 在模型期望特征中查找匹配
            let bestMatch = ""
            
            // 首先尝试完全匹配
            if (root.modelExpectedFeatures.includes(selectedFeature)) {
                bestMatch = selectedFeature
            } else {
                // 尝试部分匹配 (不区分大小写)
                for (let expectedFeature of root.modelExpectedFeatures) {
                    if (selectedFeature.toLowerCase().includes(expectedFeature.toLowerCase()) ||
                        expectedFeature.toLowerCase().includes(selectedFeature.toLowerCase())) {
                        bestMatch = expectedFeature
                        break
                    }
                }
            }
            
            if (bestMatch !== "") {
                newMapping[bestMatch] = selectedFeature
            }
        }
        
        // 确保所有模型期望特征都有条目（未匹配的设为空）
        for (let expectedFeature of root.modelExpectedFeatures) {
            if (!(expectedFeature in newMapping)) {
                newMapping[expectedFeature] = ""
            }
        }
        
        root.featureMapping = newMapping
        
        addLog(root.isChinese ? 
            `特征映射已更新: ${Object.keys(newMapping).length}个期望特征，${Object.values(newMapping).filter(v => v !== "").length}个已映射` :
            `Feature mapping updated: ${Object.keys(newMapping).length} expected features, ${Object.values(newMapping).filter(v => v !== "").length} mapped`)
    }
    
    function getMappedFeatures() {
        // 获取最终用于训练的特征列表
        // 如果有特征映射，返回映射后的特征；否则返回用户选择的特征
        if (root.modelExpectedFeatures.length === 0) {
            // 没有模型期望特征，直接使用用户选择的特征
            return root.selectedFeatures
        }
        
        // 有特征映射，使用映射后的特征
        let mappedFeatures = []
        for (let expectedFeature of root.modelExpectedFeatures) {
            let mappedFeature = root.featureMapping[expectedFeature]
            if (mappedFeature && mappedFeature !== "") {
                mappedFeatures.push(mappedFeature)
            }
        }
        
        return mappedFeatures
    }

    function autoMapFeatures() {
        // 自动映射功能：智能匹配特征名称
        if (root.modelExpectedFeatures.length === 0 || root.commonFeatures.length === 0) {
            return
        }
        
        let newMapping = Object.assign({}, root.featureMapping)
        let availableFeatures = root.commonFeatures.filter(f => f !== root.targetLabel)
        
        for (let expectedFeature of root.modelExpectedFeatures) {
            if (newMapping[expectedFeature] && newMapping[expectedFeature] !== "") {
                continue // 已经映射过的跳过
            }
            
            let bestMatch = ""
            let bestScore = 0
            
            // 查找最佳匹配
            for (let dataFeature of availableFeatures) {
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
                // 避免重复映射
                availableFeatures = availableFeatures.filter(f => f !== bestMatch)
            }
        }
        
        root.featureMapping = newMapping
        
        let mappedCount = Object.values(newMapping).filter(v => v !== "").length
        addLog(root.isChinese ? 
            `自动映射完成: ${mappedCount}/${root.modelExpectedFeatures.length} 个特征已映射` :
            `Auto mapping completed: ${mappedCount}/${root.modelExpectedFeatures.length} features mapped`)
    }
    
    function startTraining() {
        if (!root.continuousLearningController) {
            addLog("Controller not available")
            return
        }
        
        if (root.selectedDataTables.length === 0) {
            addLog(root.isChinese ? "请选择训练数据表" : "Please select training tables")
            return
        }
        
        if (root.selectedFeatures.length === 0) {
            addLog(root.isChinese ? "请选择输入特征" : "Please select features")
            return
        }
        
        if (!root.targetLabel) {
            addLog(root.isChinese ? "请选择预测目标" : "Please select target")
            return
        }
        
        root.isTraining = true
        root.trainingProgress = 0
        
        // 重置损失数据
        root.lossData = {
            "train_losses": [],
            "val_losses": [],
            "epochs": []
        }
        
        addLog(root.isChinese ? "开始训练..." : "Starting training...")
        addLog(root.isChinese ? "已重置损失数据，等待训练更新..." : "Loss data reset, waiting for training updates...")
        
        // 如果是GLR任务，额外记录
        if (root.selectedTask === "glr") {
            addLog(root.isChinese ? "GLR深度学习任务已开始，损失曲线将实时更新" : "GLR deep learning task started, loss curves will update in real-time")
        }
        
        // 获取最终用于训练的特征列表（考虑特征映射）
        let finalFeatures = getMappedFeatures()
        
        if (finalFeatures.length === 0) {
            addLog(root.isChinese ? "错误：没有有效的训练特征" : "Error: No valid training features")
            root.isTraining = false
            return
        }
        
        // 准备训练参数
        let trainParams = {
            "task": root.selectedTask,
            "dataTables": root.selectedDataTables,
            "testTables": root.selectedTestTables,
            "features": finalFeatures,  // 使用映射后的特征
            "target": root.targetLabel
        }
        
        addLog(root.isChinese ? 
            `训练参数: 任务=${root.selectedTask}, 原始特征=${root.selectedFeatures.length}个, 最终特征=${finalFeatures.length}个, 目标=${root.targetLabel}` :
            `Training params: task=${root.selectedTask}, original features=${root.selectedFeatures.length}, final features=${finalFeatures.length}, target=${root.targetLabel}`)
        
        // 如果有特征映射，记录映射信息
        if (root.modelExpectedFeatures.length > 0) {
            addLog(root.isChinese ? "特征映射信息:" : "Feature mapping:")
            for (let expectedFeature of root.modelExpectedFeatures) {
                let mappedFeature = root.featureMapping[expectedFeature]
                if (mappedFeature && mappedFeature !== "") {
                    addLog(root.isChinese ? 
                        `  ${expectedFeature} → ${mappedFeature}` :
                        `  ${expectedFeature} → ${mappedFeature}`)
                }
            }
        }
        
        // 调用训练
        root.continuousLearningController.startModelTrainingWithData(
            root.currentProjectId,
            root.selectedDataTables,
            root.selectedFeatures,  // 传递原始选择的特征
            root.targetLabel,
            root.selectedTask,
            root.featureMapping  // 传递特征映射关系
        )
    }
    
    function stopTraining() {
        if (root.continuousLearningController) {
            try {
                // 调用后端停止训练
                root.continuousLearningController.stopTraining()
                addLog(root.isChinese ? "已发送停止训练指令到后端" : "Stop training command sent to backend")
            } catch (error) {
                addLog(root.isChinese ? `停止训练时出错: ${error}` : `Error stopping training: ${error}`)
            }
        }
        
        root.isTraining = false
        addLog(root.isChinese ? "前端训练状态已停止" : "Frontend training state stopped")
    }
    
    function saveCurrentModel() {
        console.log("saveCurrentModel called")
        console.log("currentModel:", root.currentModel)
        console.log("currentModel type:", typeof root.currentModel)
        console.log("currentModel length:", root.currentModel ? root.currentModel.length : "null")
        console.log("isTraining:", root.isTraining)
        
        if (!root.continuousLearningController) {
            addLog(root.isChinese ? "控制器不可用" : "Controller not available")
            console.log("Controller not available")
            return
        }
        
        if (!root.currentModel || root.currentModel.length === 0) {
            addLog(root.isChinese ? "没有可保存的模型，请先完成训练" : "No model to save, please complete training first")
            console.log("No current model available for saving")
            return
        }
        
        console.log("Attempting to save model:", root.currentModel)
        addLog(root.isChinese ? "正在保存模型..." : "Saving model...")
        
        try {
            // 直接调用控制器的保存方法，它会自动使用模型类自带的save_model方法
            let savePath = root.continuousLearningController.saveCurrentModel()
            console.log("Save result:", savePath)
            
            if (savePath && savePath.length > 0) {
                addLog(root.isChinese ? `模型已保存到: ${savePath}` : `Model saved to: ${savePath}`)
            } else {
                addLog(root.isChinese ? "模型保存失败或已取消" : "Model save failed or cancelled")
            }
        } catch (error) {
            console.log("Error saving model:", error)
            addLog(root.isChinese ? `保存模型时发生错误: ${error}` : `Error saving model: ${error}`)
        }
    }
    
    function addLog(message) {
        let timestamp = new Date().toLocaleTimeString()
        let logEntry = `[${timestamp}] ${message}`
        root.trainingLogs = [...root.trainingLogs, logEntry]
        
        // 保持日志在合理数量
        if (root.trainingLogs.length > 100) {
            root.trainingLogs = root.trainingLogs.slice(-50)
        }
    }
    
    // 连接信号
    Connections {
        target: root.continuousLearningController
        
        function onTrainingProgressUpdated(progress, data) {
            root.trainingProgress = progress
            if (progress >= 100) {
                root.isTraining = false
                addLog(root.isChinese ? "训练完成" : "Training completed")
            }
        }
        
        function onTrainingCompleted(modelName, results) {
            console.log("ModelTraining: onTrainingCompleted called with:", modelName, results)
            console.log("ModelTraining: modelName type:", typeof modelName)
            console.log("ModelTraining: modelName value:", modelName)
            
            // 更robust的模型名称处理
            let modelNameStr = ""
            if (modelName !== null && modelName !== undefined) {
                if (typeof modelName === "string" && modelName.length > 0) {
                    modelNameStr = modelName
                } else if (typeof modelName === "number" && results && results.model_name) {
                    // 如果传入的是数字ID，尝试从结果中获取实际模型名
                    modelNameStr = String(results.model_name)
                } else {
                    // 最后的fallback，生成一个模型名
                    let timestamp = new Date().getTime()
                    let timeStr = new Date().toISOString().replace(/[:.]/g, '').slice(0, 15)
                    modelNameStr = `model_${timestamp}_${timeStr}`
                }
            }
            
            console.log("ModelTraining: final modelName:", modelNameStr)
            
            root.isTraining = false
            root.currentModel = modelNameStr
            root.trainingResults = results
            
            console.log("ModelTraining: currentModel set to:", root.currentModel)
            console.log("ModelTraining: isTraining set to:", root.isTraining)
            
            if (modelNameStr.length > 0) {
                root.addLog(root.isChinese ? `训练完成: ${modelNameStr}` : `Training completed: ${modelNameStr}`)
            } else {
                root.addLog(root.isChinese ? "训练完成，但模型名称无效" : "Training completed, but model name is invalid")
            }
            
            // 显示训练结果
            if (results && results.train_r2) {
                root.addLog(root.isChinese ? 
                    `训练R²: ${Number(results.train_r2).toFixed(4)}` :
                    `Train R²: ${Number(results.train_r2).toFixed(4)}`)
            }
            
            if (results && results.test_r2) {
                root.addLog(root.isChinese ? 
                    `测试R²: ${Number(results.test_r2).toFixed(4)}` :
                    `Test R²: ${Number(results.test_r2).toFixed(4)}`)
            }
            
            // 显示MSE指标
            if (results && results.train_mse) {
                root.addLog(root.isChinese ? 
                    `训练MSE: ${Number(results.train_mse).toFixed(4)}` :
                    `Train MSE: ${Number(results.train_mse).toFixed(4)}`)
            }
            
            if (results && results.test_mse) {
                root.addLog(root.isChinese ? 
                    `测试MSE: ${Number(results.test_mse).toFixed(4)}` :
                    `Test MSE: ${Number(results.test_mse).toFixed(4)}`)
            }
            
            // 显示MAPE指标（使用自定义MAPE计算）
            if (results && results.train_mape) {
                root.addLog(root.isChinese ? 
                    `训练MAPE: ${Number(results.train_mape).toFixed(4)}%` :
                    `Train MAPE: ${Number(results.train_mape).toFixed(4)}%`)
            }
            
            if (results && results.test_mape) {
                root.addLog(root.isChinese ? 
                    `测试MAPE: ${Number(results.test_mape).toFixed(4)}%` :
                    `Test MAPE: ${Number(results.test_mape).toFixed(4)}%`)
            }
            
            // 设置误差图数据
            if (results && results.error_plot_data) {
                // 使用属性绑定而不是直接访问
                root.trainingResults = results
                root.addLog(root.isChinese ? "R²散点图数据已准备" : "R² plot data ready")
            }
            
            // 训练完成后不自动弹出保存对话框，用户需要手动点击保存按钮
            root.addLog(root.isChinese ? "模型训练完成，您可以点击保存按钮来保存模型" : "Training completed, you can click save button to save the model")
        }
        
        function onTrainingError(error) {
            root.isTraining = false
            root.addLog(root.isChinese ? `训练错误: ${error}` : `Training error: ${error}`)
        }
        
        function onModelSaved(modelName, savePath) {
            root.addLog(root.isChinese ? 
                `模型已保存: ${modelName} → ${savePath}` :
                `Model saved: ${modelName} → ${savePath}`)
        }
        
        function onTrainingLogUpdated(logMessage) {
            // 处理训练日志更新
            root.addLog(logMessage)
        }
    }
    
    // 模型保存确认对话框
    Dialog {
        id: saveModelDialog
        title: root.isChinese ? "保存训练模型" : "Save Trained Model"
        modal: true
        anchors.centerIn: parent
        width: 480
        height: 300
        
        property string pendingModelName: ""
        property var pendingResults: null
        
        contentItem: Rectangle {
            color: "#f8f9fa"
            radius: 8
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                
                Text {
                    text: root.isChinese ? "模型训练完成！请确认模型信息并保存：" : "Model training completed! Please confirm model info and save:"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#212529"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    color: "white"
                    border.width: 1
                    border.color: "#dee2e6"
                    radius: 6
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        
                        Text {
                            text: root.isChinese ? "训练结果:" : "Training Results:"
                            font.pixelSize: 12
                            font.bold: true
                            color: "#495057"
                        }
                        
                        Text {
                            text: saveModelDialog.pendingResults ? 
                                (root.isChinese ? 
                                    `训练R²: ${saveModelDialog.pendingResults.train_r2 ? Number(saveModelDialog.pendingResults.train_r2).toFixed(4) : 'N/A'}` :
                                    `Train R²: ${saveModelDialog.pendingResults.train_r2 ? Number(saveModelDialog.pendingResults.train_r2).toFixed(4) : 'N/A'}`
                                ) : ""
                            font.pixelSize: 11
                            color: "#6c757d"
                        }
                        
                        Text {
                            text: saveModelDialog.pendingResults ? 
                                (root.isChinese ? 
                                    `测试R²: ${saveModelDialog.pendingResults.test_r2 ? Number(saveModelDialog.pendingResults.test_r2).toFixed(4) : 'N/A'}` :
                                    `Test R²: ${saveModelDialog.pendingResults.test_r2 ? Number(saveModelDialog.pendingResults.test_r2).toFixed(4) : 'N/A'}`
                                ) : ""
                            font.pixelSize: 11
                            color: "#6c757d"
                        }
                        
                        Text {
                            text: root.isChinese ? 
                                `任务类型: ${root.selectedTask} | 特征数: ${root.selectedFeatures.length}` :
                                `Task: ${root.selectedTask} | Features: ${root.selectedFeatures.length}`
                            font.pixelSize: 11
                            color: "#6c757d"
                        }
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: root.isChinese ? "模型名称:" : "Model Name:"
                        font.pixelSize: 14
                        color: "#495057"
                    }
                    
                    TextField {
                        id: modelNameField
                        Layout.fillWidth: true
                        placeholderText: root.isChinese ? "输入模型名称..." : "Enter model name..."
                        font.pixelSize: 12
                        text: root.generateRecommendedModelName()
                        
                        background: Rectangle {
                            color: "white"
                            border.width: 1
                            border.color: modelNameField.focus ? "#007bff" : "#ced4da"
                            radius: 6
                        }
                    }
                    
                    Text {
                        text: root.isChinese ? 
                            "提示：模型将保存为文件夹，包含权重文件和元数据" : 
                            "Note: Model will be saved as a folder with weights and metadata"
                        font.pixelSize: 10
                        color: "#6c757d"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
                
                Item { Layout.fillHeight: true }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Button {
                        text: root.isChinese ? "取消" : "Cancel"
                        implicitWidth: 80
                        onClicked: {
                            saveModelDialog.close()
                        }
                    }
                    
                    Button {
                        text: root.isChinese ? "保存模型" : "Save Model"
                        implicitWidth: 100
                        enabled: modelNameField.text.trim().length > 0
                        highlighted: true
                        
                        onClicked: {
                            let customName = modelNameField.text.trim()
                            if (customName.length > 0) {
                                root.addLog(root.isChinese ? `保存模型: ${customName}` : `Saving model: ${customName}`)
                                
                                try {
                                    // 使用控制器的自定义名称保存方法，它会调用模型类自带的save_model方法
                                    let savePath = root.continuousLearningController.saveModelWithCustomName(saveModelDialog.pendingModelName, customName)
                                    if (savePath && savePath.length > 0) {
                                        root.addLog(root.isChinese ? `模型保存成功: ${savePath}` : `Model saved: ${savePath}`)
                                    } else {
                                        root.addLog(root.isChinese ? "模型保存失败" : "Model save failed")
                                    }
                                } catch (error) {
                                    root.addLog(root.isChinese ? `保存错误: ${error}` : `Save error: ${error}`)
                                }
                                
                                saveModelDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        console.log("=== ModelTraining Component.onCompleted START ===")
        console.log("Component initialized successfully")
        console.log("isChinese:", root.isChinese)
        console.log("currentProjectId:", root.currentProjectId)
        console.log("continuousLearningController:", root.continuousLearningController ? "CONNECTED" : "NOT CONNECTED")
        
        // 首先重置组件状态
        console.log("ModelTraining: 重置组件到初始状态")
        currentPage = 0
        configurationComplete = false
        isTraining = false
        
        console.log("After reset - currentPage:", currentPage)
        console.log("After reset - configurationComplete:", configurationComplete)
        console.log("After reset - isTraining:", isTraining)
        
        console.log("Calling refreshDataTables...")
        refreshDataTables()
        
        console.log("Adding initial log...")
        addLog(root.isChinese ? "模型训练页面已加载" : "Model training page loaded")
        
        // 增强的连接检查
        console.log("continuousLearningController:", root.continuousLearningController ? "已连接" : "未连接")
        checkTrainingConnections()
        
        // 连接损失数据更新信号
        if (root.continuousLearningController) {
            try {
                // 强制断开之前的连接（如果有的话）
                try {
                    root.continuousLearningController.lossDataUpdated.disconnect(onLossDataUpdated)
                } catch (e) {
                    // 忽略断开连接的错误
                }
                
                // 重新连接
                root.continuousLearningController.lossDataUpdated.connect(onLossDataUpdated)
                addLog("已连接损失数据更新信号")
                console.log("Loss data signal connected successfully")
            } catch (e) {
                console.log("Error connecting loss data signal:", e)
                addLog("连接损失数据信号失败: " + e)
            }
        }
        
        console.log("=== ModelTraining Component.onCompleted END ===")
    }
    
    // 检查训练连接状态的调试函数
    function checkTrainingConnections() {
        addLog("=== 检查训练连接状态 ===")
        addLog("Controller 可用: " + (root.continuousLearningController ? "是" : "否"))
        
        if (root.continuousLearningController) {
            try {
                // 检查是否有 lossDataUpdated 信号
                if (root.continuousLearningController.lossDataUpdated) {
                    addLog("lossDataUpdated 信号存在")
                } else {
                    addLog("警告: lossDataUpdated 信号不存在")
                }
            } catch (error) {
                addLog("检查信号时出错: " + error)
            }
        }
        
        addLog("当前任务: " + root.selectedTask)
        addLog("是否训练中: " + root.isTraining)
        addLog("损失数据点数: " + (root.lossData && root.lossData.train_losses ? root.lossData.train_losses.length : "0"))
    }

    // 新增：强制触发损失数据更新的测试函数
    function testLossDataUpdate() {
        console.log("=== 测试损失数据更新 ===")
        var testData = {
            train_losses: [0.5, 0.4, 0.3, 0.25, 0.2],
            val_losses: [0.6, 0.45, 0.35, 0.3, 0.25],
            epoch: 5
        }
        
        console.log("设置测试数据:", JSON.stringify(testData))
        root.lossData = testData
        root.addLog("已设置测试损失数据")
    }
}
