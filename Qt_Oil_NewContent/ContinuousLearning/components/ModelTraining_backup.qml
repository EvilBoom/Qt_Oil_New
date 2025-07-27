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
    property var trainingLogs: []              // 训练日志
    
    signal backRequested()
    
    // 主要布局 - 左右分栏
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // 左侧配置面板
        Rectangle {
            Layout.preferredWidth: 450
            Layout.fillHeight: true
            color: "white"
            radius: 8
            border.width: 1
            border.color: "#dee2e6"
            
            ScrollView {
                anchors.fill: parent
                anchors.margins: 16
                contentWidth: availableWidth
                
                ColumnLayout {
                    width: parent.width
                    spacing: 16
                    
                    // 页面标题
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: root.isChinese ? "模型训练配置" : "Model Training Configuration"
                            font.pixelSize: 18
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
                        height: 1
                        color: "#dee2e6"
                    }
                    
                    // 第一步：选择训练任务
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Text {
                            text: root.isChinese ? "1. 选择训练任务" : "1. Select Training Task"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#495057"
                        }
                        
                        RowLayout {
                            spacing: 12
                            
                            RadioButton {
                                text: root.isChinese ? "扬程预测" : "Head"
                                checked: root.selectedTask === "head"
                                onCheckedChanged: {
                                    if (checked) root.selectedTask = "head"
                                }
                            }
                            
                            RadioButton {
                                text: root.isChinese ? "产量预测" : "Production"
                                checked: root.selectedTask === "production"
                                onCheckedChanged: {
                                    if (checked) root.selectedTask = "production"
                                }
                            }
                            
                            RadioButton {
                                text: root.isChinese ? "气液比预测" : "GLR"
                                checked: root.selectedTask === "glr"
                                onCheckedChanged: {
                                    if (checked) root.selectedTask = "glr"
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#e9ecef"
                    }
                    
                    // 第二步：选择数据表
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        RowLayout {
                            Text {
                                text: root.isChinese ? "2. 选择数据表" : "2. Select Data Tables"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Button {
                                text: root.isChinese ? "刷新" : "Refresh"
                                onClicked: refreshDataTables()
                                implicitHeight: 24
                                font.pixelSize: 11
                            }
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            // 训练数据表
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "训练表 (data_*)" : "Training (data_*)"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 100
                                    border.width: 1
                                    border.color: "#ced4da"
                                    radius: 4
                                    
                                    ListView {
                                        id: dataTablesListView
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        
                                        model: root.availableDataTables
                                        
                                        delegate: CheckBox {
                                            required property string modelData
                                            required property int index
                                            
                                            width: dataTablesListView.width
                                            text: modelData
                                            font.pixelSize: 11
                                            checked: root.selectedDataTables.includes(modelData)
                                            
                                            onCheckedChanged: {
                                                if (checked) {
                                                    if (!root.selectedDataTables.includes(modelData)) {
                                                        root.selectedDataTables = [...root.selectedDataTables, modelData]
                                                    }
                                                } else {
                                                    root.selectedDataTables = root.selectedDataTables.filter(t => t !== modelData)
                                                }
                                                updateCommonFeatures()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 测试数据表
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "测试表 (test_*)" : "Test (test_*)"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 100
                                    border.width: 1
                                    border.color: "#ced4da"
                                    radius: 4
                                    
                                    ListView {
                                        id: testTablesListView
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        
                                        model: root.availableTestTables
                                        
                                        delegate: CheckBox {
                                            required property string modelData
                                            required property int index
                                            
                                            width: testTablesListView.width
                                            text: modelData
                                            font.pixelSize: 11
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
                        height: 1
                        color: "#e9ecef"
                    }
                    
                    // 第三步：特征选择
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Text {
                            text: root.isChinese ? "3. 特征和目标选择" : "3. Features & Target Selection"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#495057"
                        }
                        
                        Text {
                            text: root.isChinese ? 
                                `共有特征 (${root.commonFeatures.length}个): ${root.commonFeatures.slice(0, 5).join(', ')}${root.commonFeatures.length > 5 ? '...' : ''}` :
                                `Common Features (${root.commonFeatures.length}): ${root.commonFeatures.slice(0, 5).join(', ')}${root.commonFeatures.length > 5 ? '...' : ''}`
                            font.pixelSize: 10
                            color: "#6c757d"
                            wrapMode: Text.WordWrap
                            visible: root.commonFeatures.length > 0
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            // 输入特征
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                RowLayout {
                                    Text {
                                        text: root.isChinese ? "输入特征" : "Features"
                                        font.pixelSize: 12
                                        color: "#6c757d"
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                    
                                    Button {
                                        text: root.isChinese ? "全选" : "All"
                                        onClicked: {
                                            root.selectedFeatures = [...root.commonFeatures.filter(f => f !== root.targetLabel)]
                                        }
                                        implicitHeight: 20
                                        font.pixelSize: 9
                                    }
                                    
                                    Button {
                                        text: root.isChinese ? "清空" : "Clear"
                                        onClicked: {
                                            root.selectedFeatures = []
                                        }
                                        implicitHeight: 20
                                        font.pixelSize: 9
                                    }
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    border.width: 1
                                    border.color: "#ced4da"
                                    radius: 4
                                    
                                    ListView {
                                        id: featuresListView
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        
                                        model: root.commonFeatures.filter(f => f !== root.targetLabel)
                                        
                                        delegate: CheckBox {
                                            required property string modelData
                                            required property int index
                                            
                                            width: featuresListView.width
                                            text: modelData
                                            font.pixelSize: 10
                                            checked: root.selectedFeatures.includes(modelData)
                                            
                                            onCheckedChanged: {
                                                if (checked) {
                                                    if (!root.selectedFeatures.includes(modelData)) {
                                                        root.selectedFeatures = [...root.selectedFeatures, modelData]
                                                    }
                                                } else {
                                                    root.selectedFeatures = root.selectedFeatures.filter(f => f !== modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 预测目标
                            ColumnLayout {
                                Layout.preferredWidth: 120
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "预测目标" : "Target"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    border.width: 1
                                    border.color: "#ced4da"
                                    radius: 4
                                    
                                    ListView {
                                        id: targetsListView
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        
                                        model: root.commonFeatures
                                        
                                        delegate: RadioButton {
                                            required property string modelData
                                            required property int index
                                            
                                            width: targetsListView.width
                                            text: modelData
                                            font.pixelSize: 10
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
                        height: 1
                        color: "#e9ecef"
                    }
                    
                    // 第四步：训练控制
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        Text {
                            text: root.isChinese ? "4. 训练控制" : "4. Training Control"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#495057"
                        }
                        
                        RowLayout {
                            spacing: 8
                            
                            Button {
                                text: root.isChinese ? "开始训练" : "Start Training"
                                enabled: !root.isTraining && 
                                        root.selectedTask.length > 0 &&
                                        root.selectedDataTables.length > 0 && 
                                        root.selectedFeatures.length > 0 && 
                                        root.targetLabel.length > 0
                                
                                onClicked: startTraining()
                            }
                            
                            Button {
                                text: root.isChinese ? "停止训练" : "Stop"
                                enabled: root.isTraining
                                onClicked: stopTraining()
                            }
                        }
                        
                        ProgressBar {
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: root.trainingProgress
                            visible: root.isTraining
                        }
                        
                        // 模型保存
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
                                text: root.isChinese ? "保存" : "Save"
                                onClicked: {
                                    let savePath = root.continuousLearningController.saveModelWithDialog(root.currentModel)
                                    if (savePath.length > 0) {
                                        root.addLog(root.isChinese ? `模型已保存到: ${savePath}` : `Model saved to: ${savePath}`)
                                    } else {
                                        root.addLog(root.isChinese ? "保存取消或失败" : "Save cancelled or failed")
                                    }
                                }
                                implicitHeight: 24
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
        
        // 右侧结果面板
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            
            // 训练日志
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                visible: root.trainingLogs.length > 0 || root.isTraining
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    
                    Text {
                        text: root.isChinese ? "训练日志" : "Training Logs"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        border.width: 1
                        border.color: "#ced4da"
                        radius: 4
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
                                    font.pixelSize: 10
                                    font.family: "Consolas, Monaco, monospace"
                                    color: "#495057"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
            
            // R²散点图
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    
                    Text {
                        text: root.isChinese ? "R²散点图 (实际值 vs 预测值)" : "R² Scatter Plot (Actual vs Predicted)"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Canvas {
                        id: r2Canvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        property var plotData: null
                        
                        onPaint: {
                            drawR2Plot()
                        }
                        
                        function drawR2Plot() {
                            if (!plotData) return
                            
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            
                            let margin = 40
                            let plotWidth = width - 2 * margin
                            let plotHeight = height - 2 * margin
                            
                            // 计算数据范围
                            let allActual = [...plotData.actual_train, ...plotData.actual_test]
                            let allPredicted = [...plotData.predicted_train, ...plotData.predicted_test]
                            let minVal = Math.min(...allActual, ...allPredicted)
                            let maxVal = Math.max(...allActual, ...allPredicted)
                            let range = maxVal - minVal || 1
                            
                            // 绘制坐标轴
                            ctx.strokeStyle = "#666"
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.moveTo(margin, margin)
                            ctx.lineTo(margin, height - margin)
                            ctx.lineTo(width - margin, height - margin)
                            ctx.stroke()
                            
                            // 绘制理想线 (y=x)
                            ctx.strokeStyle = "#000"
                            ctx.lineWidth = 2
                            ctx.setLineDash([5, 5])
                            ctx.beginPath()
                            ctx.moveTo(margin, height - margin)
                            ctx.lineTo(width - margin, margin)
                            ctx.stroke()
                            ctx.setLineDash([])
                            
                            // 绘制±15%误差线
                            ctx.strokeStyle = "#dc3545"
                            ctx.lineWidth = 1
                            ctx.setLineDash([3, 3])
                            for (let errorPercent of [0.15, -0.15]) {
                                ctx.beginPath()
                                for (let i = 0; i <= plotWidth; i += 5) {
                                    let actualVal = minVal + (maxVal - minVal) * i / plotWidth
                                    let predictedVal = actualVal * (1 + errorPercent)
                                    
                                    let x = margin + i
                                    let y = height - margin - (predictedVal - minVal) / range * plotHeight
                                    
                                    if (y >= margin && y <= height - margin) {
                                        if (i === 0) {
                                            ctx.moveTo(x, y)
                                        } else {
                                            ctx.lineTo(x, y)
                                        }
                                    }
                                }
                                ctx.stroke()
                            }
                            ctx.setLineDash([])
                            
                            // 绘制训练数据点
                            ctx.fillStyle = "#007bff"
                            for (let i = 0; i < plotData.actual_train.length; i++) {
                                let x = margin + (plotData.actual_train[i] - minVal) / range * plotWidth
                                let y = height - margin - (plotData.predicted_train[i] - minVal) / range * plotHeight
                                ctx.beginPath()
                                ctx.arc(x, y, 2, 0, 2 * Math.PI)
                                ctx.fill()
                            }
                            
                            // 绘制测试数据点
                            ctx.fillStyle = "#28a745"
                            for (let i = 0; i < plotData.actual_test.length; i++) {
                                let x = margin + (plotData.actual_test[i] - minVal) / range * plotWidth
                                let y = height - margin - (plotData.predicted_test[i] - minVal) / range * plotHeight
                                ctx.beginPath()
                                ctx.arc(x, y, 2, 0, 2 * Math.PI)
                                ctx.fill()
                            }
                            
                            // 绘制图例
                            ctx.font = "12px Arial"
                            ctx.fillStyle = "#007bff"
                            ctx.fillRect(width - 140, 20, 10, 10)
                            ctx.fillStyle = "#000"
                            ctx.fillText(root.isChinese ? "训练集" : "Training", width - 125, 30)
                            
                            ctx.fillStyle = "#28a745"
                            ctx.fillRect(width - 140, 40, 10, 10)
                            ctx.fillStyle = "#000"
                            ctx.fillText(root.isChinese ? "测试集" : "Test", width - 125, 50)
                            
                            ctx.fillStyle = "#dc3545"
                            ctx.fillRect(width - 140, 60, 10, 10)
                            ctx.fillStyle = "#000"
                            ctx.fillText("±15%", width - 125, 70)
                        }
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignCenter
                        text: root.isChinese ? "训练完成后显示R²图" : "R² plot will appear after training"
                        font.pixelSize: 12
                        color: "#6c757d"
                        visible: !r2Canvas.plotData
                    }
                }
            }
        }
    }
            
            // 页面标题
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    
                    Text {
                        text: root.isChinese ? "模型训练" : "Model Training"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#212529"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: root.isChinese ? "返回" : "Back"
                        onClicked: root.backRequested()
                    }
                }
            }
            
            // 第一步：选择训练任务
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "第一步：选择训练任务" : "Step 1: Select Training Task"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    RowLayout {
                        spacing: 16
                        
                        RadioButton {
                            text: root.isChinese ? "扬程预测" : "Head Prediction"
                            checked: root.selectedTask === "head"
                            onCheckedChanged: {
                                if (checked) {
                                    root.selectedTask = "head"
                                }
                            }
                        }
                        
                        RadioButton {
                            text: root.isChinese ? "产量预测" : "Production Prediction"
                            checked: root.selectedTask === "production"
                            onCheckedChanged: {
                                if (checked) {
                                    root.selectedTask = "production"
                                }
                            }
                        }
                        
                        RadioButton {
                            text: root.isChinese ? "气液比预测" : "GLR Prediction"
                            checked: root.selectedTask === "glr"
                            onCheckedChanged: {
                                if (checked) {
                                    root.selectedTask = "glr"
                                }
                            }
                        }
                    }
                }
            }
            
            // 第二步：选择数据表
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 300
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "第二步：选择训练和测试数据表" : "Step 2: Select Training and Test Data Tables"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    RowLayout {
                        spacing: 16
                        
                        // 训练数据表选择
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            RowLayout {
                                Text {
                                    text: root.isChinese ? "训练数据表 (data_*)" : "Training Data Tables (data_*)"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: root.isChinese ? "刷新" : "Refresh"
                                    onClicked: refreshDataTables()
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    ListView {
                                        id: dataTablesListView
                                        model: root.availableDataTables
                                        
                                        delegate: CheckBox {
                                            required property string modelData
                                            required property int index
                                            
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
                                                updateCommonFeatures()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 测试数据表选择
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "测试数据表 (test_*)" : "Test Data Tables (test_*)"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    ListView {
                                        id: testTablesListView
                                        model: root.availableTestTables
                                        
                                        delegate: CheckBox {
                                            required property string modelData
                                            required property int index
                                            
                                            width: testTablesListView.width
                                            text: modelData
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
                }
            }
            
            // 第三步：特征选择
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 250
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "第三步：选择特征和预测目标" : "Step 3: Select Features and Target"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Text {
                        text: root.isChinese ? 
                            `共有特征列 (${root.commonFeatures.length}个): ${root.commonFeatures.join(', ')}` :
                            `Common Features (${root.commonFeatures.length}): ${root.commonFeatures.join(', ')}`
                        font.pixelSize: 12
                        color: "#6c757d"
                        wrapMode: Text.WordWrap
                        visible: root.commonFeatures.length > 0
                    }
                    
                    RowLayout {
                        spacing: 16
                        
                        // 输入特征选择
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            RowLayout {
                                Text {
                                    text: root.isChinese ? "输入特征" : "Input Features"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#495057"
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                Button {
                                    text: root.isChinese ? "全选" : "Select All"
                                    onClicked: {
                                        root.selectedFeatures = [...root.commonFeatures.filter(f => f !== root.targetLabel)]
                                    }
                                }
                                
                                Button {
                                    text: root.isChinese ? "清空" : "Clear"
                                    onClicked: {
                                        root.selectedFeatures = []
                                    }
                                }
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    ListView {
                                        id: featuresListView
                                        model: root.commonFeatures.filter(f => f !== root.targetLabel)
                                        
                                        delegate: CheckBox {
                                            required property string modelData
                                            required property int index
                                            
                                            width: featuresListView.width
                                            text: modelData
                                            checked: root.selectedFeatures.includes(modelData)
                                            
                                            onCheckedChanged: {
                                                if (checked) {
                                                    if (!root.selectedFeatures.includes(modelData)) {
                                                        root.selectedFeatures = [...root.selectedFeatures, modelData]
                                                    }
                                                } else {
                                                    root.selectedFeatures = root.selectedFeatures.filter(f => f !== modelData)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 预测标签选择
                        ColumnLayout {
                            Layout.preferredWidth: 200
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "预测目标" : "Prediction Target"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 120
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    ListView {
                                        id: targetsListView
                                        model: root.commonFeatures
                                        
                                        delegate: RadioButton {
                                            required property string modelData
                                            required property int index
                                            
                                            width: targetsListView.width
                                            text: modelData
                                            checked: root.targetLabel === modelData
                                            
                                            onCheckedChanged: {
                                                if (checked) {
                                                    root.targetLabel = modelData
                                                    // 如果目标在选择的特征中，移除它
                                                    root.selectedFeatures = root.selectedFeatures.filter(f => f !== modelData)
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
            
            // 第四步：开始训练
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "第四步：开始训练" : "Step 4: Start Training"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    RowLayout {
                        spacing: 16
                        
                        Button {
                            id: startTrainingBtn
                            text: root.isChinese ? "开始训练" : "Start Training"
                            enabled: !root.isTraining && 
                                    root.selectedTask.length > 0 &&
                                    root.selectedDataTables.length > 0 && 
                                    root.selectedFeatures.length > 0 && 
                                    root.targetLabel.length > 0
                            
                            onClicked: startTraining()
                        }
                        
                        Button {
                            text: root.isChinese ? "停止训练" : "Stop Training"
                            enabled: root.isTraining
                            
                            onClicked: stopTraining()
                        }
                        
                        ProgressBar {
                            id: trainingProgressBar
                            Layout.fillWidth: true
                            from: 0
                            to: 100
                            value: root.trainingProgress
                            visible: root.isTraining
                        }
                    }
                }
            }
            
            // 训练日志和结果显示
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 600
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                visible: root.trainingLogs.length > 0 || root.isTraining
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "训练日志和结果" : "Training Logs and Results"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16
                        
                        // 左侧：训练日志
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "训练日志" : "Training Logs"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 200
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
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
                                            font.pixelSize: 11
                                            font.family: "Consolas, Monaco, monospace"
                                            color: "#495057"
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                            
                            // 模型保存区域
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 80
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                color: "#f8f9fa"
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: root.isChinese ? "模型保存" : "Model Saving"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    RowLayout {
                                        Button {
                                            text: root.isChinese ? "保存模型" : "Save Model"
                                            enabled: root.currentModel.length > 0 && !root.isTraining
                                            
                                            onClicked: {
                                                let savePath = root.continuousLearningController.saveModel(root.currentModel)
                                                if (savePath.length > 0) {
                                                    root.addLog(root.isChinese ? `模型已保存到: ${savePath}` : `Model saved to: ${savePath}`)
                                                } else {
                                                    root.addLog(root.isChinese ? "模型保存失败" : "Failed to save model")
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            text: root.isChinese ? `当前模型: ${root.currentModel}` : `Current model: ${root.currentModel}`
                                            font.pixelSize: 11
                                            color: "#6c757d"
                                            visible: root.currentModel.length > 0
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 右侧：可视化图表
                        ColumnLayout {
                            Layout.preferredWidth: 400
                            Layout.fillHeight: true
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "结果可视化" : "Result Visualization"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#495057"
                            }
                            
                            // R²散点图
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                color: "white"
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4
                                    
                                    Text {
                                        text: root.isChinese ? "R²散点图 (实际值 vs 预测值)" : "R² Scatter Plot (Actual vs Predicted)"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    Canvas {
                                        id: r2Canvas
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        
                                        property var plotData: null
                                        
                                        onPaint: {
                                            drawR2Plot()
                                        }
                                        
                                        function drawR2Plot() {
                                            if (!plotData) return
                                            
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            
                                            let margin = 40
                                            let plotWidth = width - 2 * margin
                                            let plotHeight = height - 2 * margin
                                            
                                            // 计算数据范围
                                            let allActual = [...plotData.actual_train, ...plotData.actual_test]
                                            let allPredicted = [...plotData.predicted_train, ...plotData.predicted_test]
                                            let minVal = Math.min(...allActual, ...allPredicted)
                                            let maxVal = Math.max(...allActual, ...allPredicted)
                                            let range = maxVal - minVal || 1
                                            
                                            // 绘制坐标轴
                                            ctx.strokeStyle = "#666"
                                            ctx.lineWidth = 1
                                            ctx.beginPath()
                                            ctx.moveTo(margin, margin)
                                            ctx.lineTo(margin, height - margin)
                                            ctx.lineTo(width - margin, height - margin)
                                            ctx.stroke()
                                            
                                            // 绘制理想线 (y=x)
                                            ctx.strokeStyle = "#000"
                                            ctx.lineWidth = 2
                                            ctx.setLineDash([5, 5])
                                            ctx.beginPath()
                                            ctx.moveTo(margin, height - margin)
                                            ctx.lineTo(width - margin, margin)
                                            ctx.stroke()
                                            ctx.setLineDash([])
                                            
                                            // 绘制±15%误差线
                                            ctx.strokeStyle = "#dc3545"
                                            ctx.lineWidth = 1
                                            ctx.setLineDash([3, 3])
                                            for (let errorPercent of [0.15, -0.15]) {
                                                ctx.beginPath()
                                                for (let i = 0; i <= plotWidth; i += 5) {
                                                    let actualVal = minVal + (maxVal - minVal) * i / plotWidth
                                                    let predictedVal = actualVal * (1 + errorPercent)
                                                    
                                                    let x = margin + i
                                                    let y = height - margin - (predictedVal - minVal) / range * plotHeight
                                                    
                                                    if (y >= margin && y <= height - margin) {
                                                        if (i === 0) {
                                                            ctx.moveTo(x, y)
                                                        } else {
                                                            ctx.lineTo(x, y)
                                                        }
                                                    }
                                                }
                                                ctx.stroke()
                                            }
                                            ctx.setLineDash([])
                                            
                                            // 绘制训练数据点
                                            ctx.fillStyle = "#007bff"
                                            for (let i = 0; i < plotData.actual_train.length; i++) {
                                                let x = margin + (plotData.actual_train[i] - minVal) / range * plotWidth
                                                let y = height - margin - (plotData.predicted_train[i] - minVal) / range * plotHeight
                                                ctx.beginPath()
                                                ctx.arc(x, y, 2, 0, 2 * Math.PI)
                                                ctx.fill()
                                            }
                                            
                                            // 绘制测试数据点
                                            ctx.fillStyle = "#28a745"
                                            for (let i = 0; i < plotData.actual_test.length; i++) {
                                                let x = margin + (plotData.actual_test[i] - minVal) / range * plotWidth
                                                let y = height - margin - (plotData.predicted_test[i] - minVal) / range * plotHeight
                                                ctx.beginPath()
                                                ctx.arc(x, y, 2, 0, 2 * Math.PI)
                                                ctx.fill()
                                            }
                                            
                                            // 绘制图例
                                            ctx.font = "12px Arial"
                                            ctx.fillStyle = "#007bff"
                                            ctx.fillText(root.isChinese ? "训练集" : "Training", width - 100, 20)
                                            ctx.fillStyle = "#28a745"
                                            ctx.fillText(root.isChinese ? "测试集" : "Test", width - 100, 40)
                                            ctx.fillStyle = "#dc3545"
                                            ctx.fillText("±15%", width - 100, 60)
                                        }
                                    }
                                    
                                    Text {
                                        Layout.alignment: Qt.AlignCenter
                                        text: root.isChinese ? "训练完成后显示R²图" : "R² plot will appear after training"
                                        font.pixelSize: 12
                                        color: "#6c757d"
                                        visible: !r2Canvas.plotData
                                    }
                                }
                            }
                            
                            // 损失曲线（为深度学习模型准备）
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180
                                border.width: 1
                                border.color: "#ced4da"
                                radius: 4
                                color: "white"
                                
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4
                                    
                                    Text {
                                        text: root.isChinese ? "训练损失曲线" : "Training Loss Curve"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#495057"
                                    }
                                    
                                    Canvas {
                                        id: lossCanvas
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        
                                        property var trainLoss: []
                                        property var valLoss: []
                                        
                                        onPaint: {
                                            drawLossChart()
                                        }
                                        
                                        function drawLossChart() {
                                            if (trainLoss.length === 0) return
                                            
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            
                                            // 绘制坐标轴
                                            ctx.strokeStyle = "#dee2e6"
                                            ctx.lineWidth = 1
                                            ctx.beginPath()
                                            ctx.moveTo(40, height - 30)
                                            ctx.lineTo(width - 20, height - 30)
                                            ctx.moveTo(40, 20)
                                            ctx.lineTo(40, height - 30)
                                            ctx.stroke()
                                            
                                            // 绘制损失曲线
                                            if (trainLoss.length > 1) {
                                                drawLine(ctx, trainLoss, "#007bff")
                                            }
                                            if (valLoss.length > 1) {
                                                drawLine(ctx, valLoss, "#dc3545")
                                            }
                                        }
                                        
                                        function drawLine(ctx, data, color) {
                                            let maxVal = Math.max(...data)
                                            let minVal = Math.min(...data)
                                            let range = maxVal - minVal || 1
                                            
                                            ctx.strokeStyle = color
                                            ctx.lineWidth = 2
                                            ctx.beginPath()
                                            
                                            for (let i = 0; i < data.length; i++) {
                                                let x = 40 + (width - 60) * i / (data.length - 1)
                                                let y = 20 + (height - 50) * (1 - (data[i] - minVal) / range)
                                                
                                                if (i === 0) {
                                                    ctx.moveTo(x, y)
                                                } else {
                                                    ctx.lineTo(x, y)
                                                }
                                            }
                                            ctx.stroke()
                                        }
                                    }
                                    
                                    Text {
                                        Layout.alignment: Qt.AlignCenter
                                        text: root.isChinese ? "深度学习模型训练时显示" : "For deep learning models only"
                                        font.pixelSize: 11
                                        color: "#6c757d"
                                        visible: lossCanvas.trainLoss.length === 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // JavaScript 函数
    function refreshDataTables() {
        root.availableDataTables = root.continuousLearningController.getTrainingTables()
        root.availableTestTables = root.continuousLearningController.getTestTables()
    }
    
    function updateCommonFeatures() {
        if (root.selectedDataTables.length === 0) {
            root.commonFeatures = []
            return
        }
        
        // 获取所有选择表的共有字段
        let commonFields = null
        for (let table of root.selectedDataTables) {
            let fields = root.continuousLearningController.getTableFields(table)
            if (commonFields === null) {
                commonFields = fields.slice()
            } else {
                commonFields = commonFields.filter(field => fields.includes(field))
            }
        }
        root.commonFeatures = commonFields || []
    }
    
    function startTraining() {
        if (root.selectedTask.length === 0) {
            addLog(root.isChinese ? "错误：请选择训练任务" : "Error: Please select training task")
            return
        }
        
        if (root.selectedDataTables.length === 0) {
            addLog(root.isChinese ? "错误：请选择至少一个训练数据表" : "Error: Please select at least one training data table")
            return
        }
        
        if (root.selectedFeatures.length === 0) {
            addLog(root.isChinese ? "错误：请选择输入特征" : "Error: Please select input features")
            return
        }
        
        if (root.targetLabel.length === 0) {
            addLog(root.isChinese ? "错误：请选择预测目标" : "Error: Please select prediction target")
            return
        }
        
        root.isTraining = true
        root.trainingProgress = 0
        root.trainingLogs = []
        
        addLog(root.isChinese ? "开始训练模型..." : "Starting model training...")
        addLog(root.isChinese ? `任务类型: ${root.selectedTask}` : `Task type: ${root.selectedTask}`)
        addLog(root.isChinese ? `训练表: ${root.selectedDataTables.join(', ')}` : `Training tables: ${root.selectedDataTables.join(', ')}`)
        addLog(root.isChinese ? `测试表: ${root.selectedTestTables.join(', ')}` : `Test tables: ${root.selectedTestTables.join(', ')}`)
        addLog(root.isChinese ? `输入特征: ${root.selectedFeatures.join(', ')}` : `Input features: ${root.selectedFeatures.join(', ')}`)
        addLog(root.isChinese ? `预测目标: ${root.targetLabel}` : `Target: ${root.targetLabel}`)
        
        // 目前先使用第一个选择的表进行训练
        // TODO: 后续可以扩展为支持多表合并训练
        let primaryTable = root.selectedDataTables[0]
        let trainSize = 0.8  // 默认使用80%作为训练集
        
        // 调用现有的训练方法
        root.continuousLearningController.startModelTrainingWithData(
            primaryTable,
            root.selectedFeatures,
            root.targetLabel,
            trainSize
        )
    }
    
    function stopTraining() {
        root.isTraining = false
        addLog(root.isChinese ? "训练已停止" : "Training stopped")
    }
    
    function addLog(message) {
        let timestamp = new Date().toLocaleTimeString()
        let logEntry = `[${timestamp}] ${message}`
        root.trainingLogs = [...root.trainingLogs, logEntry]
    }
    
    Connections {
        target: root.continuousLearningController
        
        function onTrainingStarted(taskId) {
            root.isTraining = true
            root.addLog(root.isChinese ? "训练已开始..." : "Training started...")
        }
        
        function onTrainingCompleted(taskId, results) {
            root.isTraining = false
            root.trainingProgress = 100
            root.trainingResults = results
            
            if (results && results.model_name) {
                root.currentModel = results.model_name
            }
            
            root.addLog(root.isChinese ? "训练完成!" : "Training completed!")
            
            // 显示训练集指标
            if (results && typeof results.train_mse !== "undefined") {
                root.addLog(root.isChinese ? `训练集 MSE: ${results.train_mse.toFixed(4)}` : `Training MSE: ${results.train_mse.toFixed(4)}`)
            }
            if (results && typeof results.train_r2 !== "undefined") {
                root.addLog(root.isChinese ? `训练集 R²: ${results.train_r2.toFixed(4)}` : `Training R²: ${results.train_r2.toFixed(4)}`)
            }
            if (results && typeof results.train_mae !== "undefined") {
                root.addLog(root.isChinese ? `训练集 MAE: ${results.train_mae.toFixed(4)}` : `Training MAE: ${results.train_mae.toFixed(4)}`)
            }
            
            // 更新R²散点图
            if (results && results.r2_plot_data) {
                r2Canvas.plotData = results.r2_plot_data
                r2Canvas.requestPaint()
                
                // 记录数据情况
                let trainSize = results.r2_plot_data.actual_train.length
                let testSize = results.r2_plot_data.actual_test.length
                root.addLog(root.isChinese ? 
                    `数据分布 - 训练集: ${trainSize} 样本, 测试集: ${testSize} 样本` :
                    `Data distribution - Training: ${trainSize} samples, Test: ${testSize} samples`)
            }
            
            // 更新损失曲线（目前SVR没有损失曲线，这里为将来的神经网络模型准备）
            if (results && results.train_loss) {
                lossCanvas.trainLoss = results.train_loss
                lossCanvas.requestPaint()
            }
            if (results && results.val_loss) {
                lossCanvas.valLoss = results.val_loss
                lossCanvas.requestPaint()
            }
        }
        
        function onTrainingProgressUpdated(progress, info) {
            root.trainingProgress = progress * 100
            if (info && info.message) {
                root.addLog(info.message)
            }
        }
        
        function onTestResultsUpdated(results) {
            root.addLog(root.isChinese ? "=== 测试集结果 ===" : "=== Test Results ===")
            if (results && typeof results.test_mse !== "undefined") {
                root.addLog(root.isChinese ? `测试集 MSE: ${results.test_mse.toFixed(4)}` : `Test MSE: ${results.test_mse.toFixed(4)}`)
            }
            if (results && typeof results.test_r2 !== "undefined") {
                root.addLog(root.isChinese ? `测试集 R²: ${results.test_r2.toFixed(4)}` : `Test R²: ${results.test_r2.toFixed(4)}`)
            }
            if (results && typeof results.test_mae !== "undefined") {
                root.addLog(root.isChinese ? `测试集 MAE: ${results.test_mae.toFixed(4)}` : `Test MAE: ${results.test_mae.toFixed(4)}`)
            }
        }
        
        function onPredictionFailed(taskId, error) {
            root.isTraining = false
            root.addLog(root.isChinese ? `训练失败: ${error}` : `Training failed: ${error}`)
        }
    }
    
    Component.onCompleted: {
        // 初始化数据表列表
        refreshDataTables()
    }
}
