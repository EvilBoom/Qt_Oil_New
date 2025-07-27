import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

pragma ComponentBehavior: Bound

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    property var continuousLearningController
    
    // 测试配置（从配置页面传入）
    property string selectedTask: ""
    property string selectedModel: ""
    property string modelType: ""
    property var selectedDataTables: []
    property var selectedFeatures: []
    property string targetLabel: ""
    property var featureMapping: ({})
    
    // 测试状态
    property bool isTesting: false
    property var testProgress: 0.0
    property var testResults: ({})
    property var testingLogs: []
    
    signal backRequested()
    signal backToConfigRequested()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        
        // 页面标题和导航
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: root.isChinese ? "← 返回配置" : "← Back to Config"
                onClicked: root.backToConfigRequested()
                enabled: !root.isTesting
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: root.isChinese ? "模型测试" : "Model Testing"
                font.pixelSize: 24
                font.bold: true
                color: "#212529"
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: root.isChinese ? "主页" : "Home"
                onClicked: root.backRequested()
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#dee2e6"
        }
        
        // 测试状态区域
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            // 测试控制
            Rectangle {
                Layout.preferredWidth: 300
                Layout.preferredHeight: 150
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "测试控制" : "Testing Control"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    RowLayout {
                        spacing: 12
                        
                        Button {
                            text: root.isChinese ? "开始测试" : "Start Testing"
                            enabled: !root.isTesting
                            onClicked: root.startTesting()
                        }
                        
                        Button {
                            text: root.isChinese ? "停止测试" : "Stop Testing"
                            enabled: root.isTesting
                            onClicked: root.stopTesting()
                        }
                        
                        Button {
                            text: root.isChinese ? "保存结果" : "Save Results"
                            enabled: !root.isTesting && Object.keys(root.testResults).length > 0
                            onClicked: root.saveTestResults()
                        }
                    }
                    
                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: root.testProgress
                        
                        Text {
                            anchors.centerIn: parent
                            text: `${Math.round(root.testProgress)}%`
                            font.pixelSize: 10
                            color: "#495057"
                        }
                    }
                    
                    Text {
                        text: root.isTesting ? 
                            (root.isChinese ? "测试进行中..." : "Testing in progress...") :
                            (root.isChinese ? "测试已完成" : "Testing completed")
                        font.pixelSize: 12
                        color: root.isTesting ? "#28a745" : "#6c757d"
                    }
                }
            }
            
            // 测试信息
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    
                    Text {
                        text: root.isChinese ? "测试信息" : "Testing Information"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Text {
                        text: root.isChinese ? 
                            `测试任务: ${root.selectedTask}` :
                            `Test Task: ${root.selectedTask}`
                        font.pixelSize: 12
                        color: "#6c757d"
                    }
                    
                    Text {
                        text: root.isChinese ? 
                            `测试模型: ${root.selectedModel.split('/').pop() || root.selectedModel} (${root.modelType})` :
                            `Test Model: ${root.selectedModel.split('/').pop() || root.selectedModel} (${root.modelType})`
                        font.pixelSize: 12
                        color: "#6c757d"
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
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
                    
                    // 测试结果摘要
                    RowLayout {
                        visible: Object.keys(root.testResults).length > 0 && !root.isTesting
                        
                        Text {
                            text: root.isChinese ? "结果:" : "Results:"
                            font.pixelSize: 11
                            color: "#6c757d"
                        }
                        
                        Text {
                            text: {
                                if (root.testResults.mape !== undefined) {
                                    return `MAPE: ${root.testResults.mape.toFixed(2)}%`
                                }
                                return "N/A"
                            }
                            font.pixelSize: 11
                            color: "#495057"
                            font.bold: true
                        }
                        
                        Text {
                            text: {
                                if (root.testResults.r2 !== undefined) {
                                    return `R²: ${root.testResults.r2.toFixed(4)}`
                                }
                                return ""
                            }
                            font.pixelSize: 11
                            color: "#495057"
                            font.bold: true
                        }
                    }
                }
            }
        }
        
        // 主要可视化区域
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            
            // 测试日志
            Rectangle {
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "测试日志" : "Testing Logs"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
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
                            anchors.margins: 12
                            
                            ListView {
                                id: logsListView
                                model: root.testingLogs
                                
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
                }
            }
            
            // 残差图
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "残差图 (预测值 vs 残差)" : "Residuals Plot (Predicted vs Residuals)"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Canvas {
                        id: testErrorCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        property var plotData: root.testResults.error_plot_data || null
                        
                        onPlotDataChanged: {
                            if (plotData) {
                                requestPaint()
                            }
                        }
                        
                        onPaint: {
                            drawResidualsPlot()
                        }
                        
                        function drawResidualsPlot() {
                            if (!plotData) return
                            
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            
                            let margin = 60
                            let plotWidth = width - 2 * margin
                            let plotHeight = height - 2 * margin
                            
                            let actualValues = plotData.actual || []
                            let predictedValues = plotData.predicted || []
                            
                            if (actualValues.length === 0 || predictedValues.length === 0) return
                            
                            // 计算残差 (实际值 - 预测值)
                            let residuals = []
                            for (let i = 0; i < Math.min(actualValues.length, predictedValues.length); i++) {
                                let residual = actualValues[i] - predictedValues[i]
                                residuals.push(residual)
                            }
                            
                            if (residuals.length === 0) return
                            
                            // 计算数据范围
                            let minPredicted = Math.min(...predictedValues)
                            let maxPredicted = Math.max(...predictedValues)
                            let predictedRange = maxPredicted - minPredicted || 1
                            
                            let minResidual = Math.min(...residuals)
                            let maxResidual = Math.max(...residuals)
                            let residualRange = Math.max(Math.abs(minResidual), Math.abs(maxResidual)) * 2 || 1
                            let residualCenter = height / 2
                            
                            // 计算15%误差限制线的位置
                            let meanActual = actualValues.reduce((sum, val) => sum + val, 0) / actualValues.length
                            let upperLimit15 = 0.15 * meanActual
                            let lowerLimit15 = -0.15 * meanActual
                            
                            // 绘制坐标轴
                            ctx.strokeStyle = "#666"
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            // Y轴
                            ctx.moveTo(margin, margin)
                            ctx.lineTo(margin, height - margin)
                            // X轴
                            ctx.moveTo(margin, height - margin)
                            ctx.lineTo(width - margin, height - margin)
                            ctx.stroke()
                            
                            // 绘制零误差线 (y=0)
                            ctx.strokeStyle = "#000"
                            ctx.lineWidth = 2
                            ctx.setLineDash([5, 5])
                            let zeroY = height - margin - (0 + residualRange/2) / residualRange * plotHeight
                            ctx.beginPath()
                            ctx.moveTo(margin, zeroY)
                            ctx.lineTo(width - margin, zeroY)
                            ctx.stroke()
                            
                            // 绘制+15%误差线
                            ctx.strokeStyle = "#dc3545"
                            ctx.lineWidth = 1
                            ctx.setLineDash([3, 3])
                            let upper15Y = height - margin - (upperLimit15 + residualRange/2) / residualRange * plotHeight
                            if (upper15Y >= margin && upper15Y <= height - margin) {
                                ctx.beginPath()
                                ctx.moveTo(margin, upper15Y)
                                ctx.lineTo(width - margin, upper15Y)
                                ctx.stroke()
                            }
                            
                            // 绘制-15%误差线
                            ctx.strokeStyle = "#007bff"
                            ctx.lineWidth = 1
                            ctx.setLineDash([3, 3])
                            let lower15Y = height - margin - (lowerLimit15 + residualRange/2) / residualRange * plotHeight
                            if (lower15Y >= margin && lower15Y <= height - margin) {
                                ctx.beginPath()
                                ctx.moveTo(margin, lower15Y)
                                ctx.lineTo(width - margin, lower15Y)
                                ctx.stroke()
                            }
                            ctx.setLineDash([])
                            
                            // 绘制残差散点
                            ctx.fillStyle = "#28a745"
                            for (let i = 0; i < predictedValues.length; i++) {
                                let x = margin + (predictedValues[i] - minPredicted) / predictedRange * plotWidth
                                let y = height - margin - (residuals[i] + residualRange/2) / residualRange * plotHeight
                                
                                if (x >= margin && x <= width - margin && y >= margin && y <= height - margin) {
                                    ctx.beginPath()
                                    ctx.arc(x, y, 3, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                            }
                            
                            // 绘制图例
                            ctx.font = "14px Arial"
                            let legendY = 30
                            
                            // 残差点
                            ctx.fillStyle = "#28a745"
                            ctx.beginPath()
                            ctx.arc(width - 150, legendY + 6, 3, 0, 2 * Math.PI)
                            ctx.fill()
                            ctx.fillStyle = "#000"
                            ctx.fillText(root.isChinese ? "残差" : "Residuals", width - 135, legendY + 10)
                            
                            // 零误差线
                            legendY += 20
                            ctx.strokeStyle = "#000"
                            ctx.lineWidth = 2
                            ctx.setLineDash([5, 5])
                            ctx.beginPath()
                            ctx.moveTo(width - 155, legendY + 6)
                            ctx.lineTo(width - 135, legendY + 6)
                            ctx.stroke()
                            ctx.setLineDash([])
                            ctx.fillStyle = "#000"
                            ctx.fillText(root.isChinese ? "零误差" : "Zero Error", width - 125, legendY + 10)
                            
                            // +15%误差线
                            legendY += 20
                            ctx.strokeStyle = "#dc3545"
                            ctx.lineWidth = 1
                            ctx.setLineDash([3, 3])
                            ctx.beginPath()
                            ctx.moveTo(width - 155, legendY + 6)
                            ctx.lineTo(width - 135, legendY + 6)
                            ctx.stroke()
                            ctx.setLineDash([])
                            ctx.fillStyle = "#000"
                            ctx.fillText("+15% " + (root.isChinese ? "误差" : "Error"), width - 125, legendY + 10)
                            
                            // -15%误差线
                            legendY += 20
                            ctx.strokeStyle = "#007bff"
                            ctx.lineWidth = 1
                            ctx.setLineDash([3, 3])
                            ctx.beginPath()
                            ctx.moveTo(width - 155, legendY + 6)
                            ctx.lineTo(width - 135, legendY + 6)
                            ctx.stroke()
                            ctx.setLineDash([])
                            ctx.fillStyle = "#000"
                            ctx.fillText("-15% " + (root.isChinese ? "误差" : "Error"), width - 125, legendY + 10)
                            
                            // 绘制轴标签
                            ctx.fillStyle = "#000"
                            ctx.font = "16px Arial"
                            ctx.fillText(root.isChinese ? "预测值" : "Predicted Values", width/2 - 40, height - 15)
                            
                            ctx.save()
                            ctx.translate(20, height/2)
                            ctx.rotate(-Math.PI/2)
                            ctx.fillText(root.isChinese ? "残差" : "Residuals", -30, 0)
                            ctx.restore()
                            
                            // 绘制Y轴刻度（残差）
                            ctx.fillStyle = "#666"
                            ctx.font = "12px Arial"
                            for (let i = 0; i <= 5; i++) {
                                let residualValue = -residualRange/2 + (residualRange * i / 5)
                                let y = height - margin - (residualValue + residualRange/2) / residualRange * plotHeight
                                if (y >= margin && y <= height - margin) {
                                    ctx.fillText(Number(residualValue).toFixed(2), 5, y + 4)
                                    
                                    // 绘制刻度线
                                    ctx.strokeStyle = "#ddd"
                                    ctx.lineWidth = 1
                                    ctx.beginPath()
                                    ctx.moveTo(margin - 5, y)
                                    ctx.lineTo(margin, y)
                                    ctx.stroke()
                                }
                            }
                            
                            // 绘制X轴刻度（预测值）
                            for (let i = 0; i <= 5; i++) {
                                let predictedValue = minPredicted + (predictedRange * i / 5)
                                let x = margin + (predictedValue - minPredicted) / predictedRange * plotWidth
                                if (x >= margin && x <= width - margin) {
                                    ctx.fillText(Number(predictedValue).toFixed(1), x - 15, height - margin + 20)
                                    
                                    // 绘制刻度线
                                    ctx.strokeStyle = "#ddd"
                                    ctx.lineWidth = 1
                                    ctx.beginPath()
                                    ctx.moveTo(x, height - margin)
                                    ctx.lineTo(x, height - margin + 5)
                                    ctx.stroke()
                                }
                            }
                        }
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignCenter
                        text: root.isChinese ? "测试完成后显示残差图" : "Residuals plot will appear after testing"
                        font.pixelSize: 14
                        color: "#6c757d"
                        visible: !testErrorCanvas.plotData
                    }
                }
            }
        }
        
        // 测试结果详情（可折叠）
        Rectangle {
            id: resultsSection
            Layout.fillWidth: true
            Layout.preferredHeight: resultsSection.resultsExpanded ? 200 : 50
            color: "white"
            radius: 8
            border.width: 1
            border.color: "#dee2e6"
            
            property bool resultsExpanded: false
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: root.isChinese ? "详细测试结果" : "Detailed Test Results"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: resultsSection.resultsExpanded ? "▲" : "▼"
                        flat: true
                        onClicked: resultsSection.resultsExpanded = !resultsSection.resultsExpanded
                    }
                }
                
                // 详细结果（可展开）
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: resultsSection.resultsExpanded
                    
                    // 评估指标
                    Rectangle {
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        border.width: 1
                        border.color: "#ced4da"
                        radius: 4
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "评估指标" : "Evaluation Metrics"
                                font.pixelSize: 14
                                font.bold: true
                            }
                            
                            GridLayout {
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 6
                                
                                Text {
                                    text: "MAPE:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                Text {
                                    text: root.testResults.mape ? `${root.testResults.mape.toFixed(2)}%` : "N/A"
                                    font.pixelSize: 12
                                    color: "#007bff"
                                    font.bold: true
                                }
                                
                                Text {
                                    text: "MSE:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                Text {
                                    text: root.testResults.mse ? root.testResults.mse.toFixed(4) : "N/A"
                                    font.pixelSize: 12
                                    color: "#007bff"
                                    font.bold: true
                                }
                                
                                Text {
                                    text: "MAE:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                Text {
                                    text: root.testResults.mae ? root.testResults.mae.toFixed(4) : "N/A"
                                    font.pixelSize: 12
                                    color: "#007bff"
                                    font.bold: true
                                }
                                
                                Text {
                                    text: "R²:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                Text {
                                    text: root.testResults.r2 ? root.testResults.r2.toFixed(4) : "N/A"
                                    font.pixelSize: 12
                                    color: "#007bff"
                                    font.bold: true
                                }
                                
                                Text {
                                    text: root.isChinese ? "测试样本:" : "Test Samples:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                Text {
                                    text: root.testResults.test_samples || "N/A"
                                    font.pixelSize: 12
                                    color: "#007bff"
                                    font.bold: true
                                }
                            }
                        }
                    }
                    
                    // 模型信息
                    Rectangle {
                        Layout.preferredWidth: 250
                        Layout.fillHeight: true
                        border.width: 1
                        border.color: "#ced4da"
                        radius: 4
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "模型信息" : "Model Information"
                                font.pixelSize: 14
                                font.bold: true
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `类型: ${root.modelType}` :
                                    `Type: ${root.modelType}`
                                font.pixelSize: 11
                                color: "#6c757d"
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `路径: ${root.selectedModel}` :
                                    `Path: ${root.selectedModel}`
                                font.pixelSize: 11
                                color: "#6c757d"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                elide: Text.ElideMiddle
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `输入特征: ${root.selectedFeatures.join(', ')}` :
                                    `Input Features: ${root.selectedFeatures.join(', ')}`
                                font.pixelSize: 11
                                color: "#6c757d"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `预测目标: ${root.targetLabel}` :
                                    `Target: ${root.targetLabel}`
                                font.pixelSize: 11
                                color: "#6c757d"
                            }
                        }
                    }
                    
                    // 测试配置
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        border.width: 1
                        border.color: "#ced4da"
                        radius: 4
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            
                            Text {
                                text: root.isChinese ? "测试配置" : "Test Configuration"
                                font.pixelSize: 14
                                font.bold: true
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `数据表: ${root.selectedDataTables.join(', ')}` :
                                    `Data Tables: ${root.selectedDataTables.join(', ')}`
                                font.pixelSize: 11
                                color: "#6c757d"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                            
                            Text {
                                text: root.isChinese ? 
                                    `特征映射: ${Object.keys(root.featureMapping).length > 0 ? '是' : '否'}` :
                                    `Feature Mapping: ${Object.keys(root.featureMapping).length > 0 ? 'Yes' : 'No'}`
                                font.pixelSize: 11
                                color: "#6c757d"
                            }
                            
                            // 显示特征映射详情（如果有）
                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: Object.keys(root.featureMapping).length > 0
                                
                                Text {
                                    text: {
                                        let mappingText = ""
                                        for (let key in root.featureMapping) {
                                            if (root.featureMapping[key] !== "") {
                                                mappingText += `${key} → ${root.featureMapping[key]}\n`
                                            }
                                        }
                                        return mappingText || (root.isChinese ? "无映射" : "No mappings")
                                    }
                                    font.pixelSize: 10
                                    color: "#6c757d"
                                    wrapMode: Text.WordWrap
                                    font.family: "Consolas, Monaco, monospace"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // JavaScript函数
    function startTesting() {
        if (!root.continuousLearningController) {
            addLog(root.isChinese ? "控制器不可用" : "Controller not available")
            return
        }
        
        root.isTesting = true
        root.testProgress = 0
        root.testResults = {}
        addLog(root.isChinese ? "开始模型测试..." : "Starting model testing...")
        
        // 准备测试参数
        let testParams = {
            "task": root.selectedTask,
            "model": root.selectedModel,
            "modelType": root.modelType,
            "dataTables": root.selectedDataTables,
            "features": root.selectedFeatures,
            "target": root.targetLabel,
            "featureMapping": root.featureMapping
        }
        
        addLog(root.isChinese ? 
            `测试参数: 模型=${root.selectedModel.split('/').pop()}, 特征=${root.selectedFeatures.length}个, 目标=${root.targetLabel}` :
            `Test params: model=${root.selectedModel.split('/').pop()}, features=${root.selectedFeatures.length}, target=${root.targetLabel}`)
        
        // 调用测试
        root.continuousLearningController.startModelTestingWithConfiguration(
            root.selectedModel,
            root.modelType,
            root.selectedDataTables,
            root.selectedFeatures,
            root.targetLabel,
            root.featureMapping
        )
    }
    
    function stopTesting() {
        root.isTesting = false
        addLog(root.isChinese ? "测试已停止" : "Testing stopped")
    }
    
    function saveTestResults() {
        if (!root.continuousLearningController || Object.keys(root.testResults).length === 0) {
            addLog(root.isChinese ? "没有可保存的测试结果" : "No test results to save")
            return
        }
        
        try {
            let savePath = root.continuousLearningController.saveTestResultsWithDialog(root.testResults)
            if (savePath && savePath.length > 0) {
                addLog(root.isChinese ? `测试结果已保存到: ${savePath}` : `Test results saved to: ${savePath}`)
            } else {
                addLog(root.isChinese ? "保存取消或失败" : "Save cancelled or failed")
            }
        } catch (error) {
            addLog(root.isChinese ? `保存错误: ${error}` : `Save error: ${error}`)
        }
    }
    
    function addLog(message) {
        let timestamp = new Date().toLocaleTimeString()
        let logMessage = `[${timestamp}] ${message}`
        root.testingLogs = [...root.testingLogs, logMessage]
        console.log(logMessage)
    }
    
    // 连接控制器信号
    Connections {
        target: root.continuousLearningController
        
        function onTestProgressUpdated(progress) {
            root.testProgress = progress
        }
        
        function onTestResultsUpdated(results) {
            root.testResults = results
            root.isTesting = false
            
            let mapeText = results.mape ? `${results.mape.toFixed(2)}%` : "N/A"
            let r2Text = results.r2 ? results.r2.toFixed(4) : "N/A"
            
            root.addLog(root.isChinese ? 
                `测试完成! MAPE: ${mapeText}, R²: ${r2Text}` :
                `Testing completed! MAPE: ${mapeText}, R²: ${r2Text}`)
        }
        
        function onTestLogUpdated(logMessage) {
            root.addLog(logMessage)
        }
    }
    
    Component.onCompleted: {
        addLog(root.isChinese ? "模型测试页面已加载" : "Model testing page loaded")
        addLog(root.isChinese ? 
            `配置信息: 任务=${root.selectedTask}, 模型=${root.selectedModel.split('/').pop()}` :
            `Configuration: task=${root.selectedTask}, model=${root.selectedModel.split('/').pop()}`)
    }
}
