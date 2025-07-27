import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// 简单的嵌入式示例 - 可以直接放在您的现有页面中
Rectangle {
    id: root
    width: 800
    height: 500
    color: "#ffffff"
    
    property bool isChinese: true
    property int selectedTaskType: -1
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // 页面标题
        Text {
            Layout.fillWidth: true
            text: root.isChinese ? "模型持续学习" : "Model Continuous Learning"
            font.pixelSize: 24
            font.bold: true
            color: "#2c3e50"
            horizontalAlignment: Text.AlignHCenter
        }
        
        // 主要内容区域
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            
            // 左侧：任务选择器
            TaskSelector {
                id: taskSelector
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                isChinese: root.isChinese
                
                onTaskSelected: function(taskType) {
                    root.selectedTaskType = taskType
                    updateDescription()
                }
                
                onConfirmClicked: {
                    if (root.selectedTaskType >= 0) {
                        showSuccessMessage("任务确认成功！准备开始持续学习流程。")
                        // 这里可以触发下一步操作
                        startLearningProcess()
                    }
                }
                
                onCancelClicked: {
                    root.selectedTaskType = -1
                    taskDescription.text = getDefaultDescription()
                }
            }
            
            // 右侧：任务描述和状态
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#f8f9fa"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    Text {
                        text: root.isChinese ? "任务详情" : "Task Details"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#495057"
                    }
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        Text {
                            id: taskDescription
                            width: parent.width
                            text: getDefaultDescription()
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            color: "#6c757d"
                            lineHeight: 1.4
                        }
                    }
                    
                    // 状态指示器
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: getStatusColor()
                        radius: 6
                        visible: root.selectedTaskType >= 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: getStatusText()
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }
        }
        
        // 底部操作按钮
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: root.isChinese ? "重置" : "Reset"
                enabled: root.selectedTaskType >= 0
                
                background: Rectangle {
                    color: "#6c757d"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    taskSelector.resetSelection()
                    root.selectedTaskType = -1
                    taskDescription.text = getDefaultDescription()
                }
            }
            
            Button {
                text: root.isChinese ? "开始学习" : "Start Learning"
                enabled: root.selectedTaskType >= 0
                
                background: Rectangle {
                    color: parent.enabled ? "#28a745" : "#6c757d"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    startLearningProcess()
                }
            }
        }
    }
    
    // 成功消息提示
    Rectangle {
        id: successMessage
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        width: 300
        height: 50
        color: "#28a745"
        radius: 25
        opacity: 0
        visible: opacity > 0
        
        Text {
            id: messageText
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 14
            text: ""
        }
        
        Behavior on opacity {
            NumberAnimation { duration: 300 }
        }
        
        Timer {
            id: messageTimer
            interval: 3000
            onTriggered: successMessage.opacity = 0
        }
    }
    
    // 辅助函数
    function getDefaultDescription() {
        return root.isChinese ? 
            "请选择一个预测任务开始持续学习过程。\n\n持续学习可以帮助模型适应新数据，提高预测精度。选择合适的任务类型后，系统将引导您完成数据准备、模型训练和评估的完整流程。" :
            "Please select a prediction task to start the continuous learning process.\n\nContinuous learning helps models adapt to new data and improve prediction accuracy. After selecting the appropriate task type, the system will guide you through the complete process of data preparation, model training, and evaluation."
    }
    
    function updateDescription() {
        var descriptions = {
            0: root.isChinese ? 
                "扬程预测任务已选择\n\n该任务将训练模型预测ESP泵所需的扬程。通过分析井况参数、生产参数和设备参数，帮助优化泵的选型和运行。\n\n数据要求：井深、地层压力、产液量、流体性质等参数。" :
                "Head Prediction Task Selected\n\nThis task will train a model to predict the required head for ESP pumps. By analyzing well conditions, production parameters, and equipment parameters, it helps optimize pump selection and operation.\n\nData Requirements: Well depth, formation pressure, liquid rate, fluid properties, etc.",
            
            1: root.isChinese ?
                "产量预测任务已选择\n\n该任务将训练模型预测油井未来的产量变化趋势。基于地质条件、完井参数和生产历史，帮助制定合理的生产计划。\n\n数据要求：地层参数、流体性质、生产历史数据、设备运行参数等。" :
                "Production Prediction Task Selected\n\nThis task will train a model to predict future production trends. Based on geological conditions, completion parameters, and production history, it helps develop reasonable production plans.\n\nData Requirements: Formation parameters, fluid properties, production history, equipment operating parameters, etc.",
            
            2: root.isChinese ?
                "气液比预测任务已选择\n\n该任务将训练模型预测井下吸入口的气液比，这是ESP设计中的关键参数。准确的预测有助于避免气锁现象，提高泵效。\n\n数据要求：油气比、井底压力温度、流体组分、泵挂深度等参数。" :
                "Gas-Liquid Ratio Prediction Task Selected\n\nThis task will train a model to predict the gas-liquid ratio at the pump intake, a critical parameter in ESP design. Accurate prediction helps avoid gas lock and improve pump efficiency.\n\nData Requirements: GOR, bottomhole pressure and temperature, fluid composition, pump setting depth, etc."
        }
        
        if (root.selectedTaskType >= 0 && root.selectedTaskType in descriptions) {
            taskDescription.text = descriptions[root.selectedTaskType]
        }
    }
    
    function getStatusColor() {
        return "#007bff"
    }
    
    function getStatusText() {
        var taskNames = [
            root.isChinese ? "扬程预测任务已就绪" : "Head Prediction Task Ready",
            root.isChinese ? "产量预测任务已就绪" : "Production Prediction Task Ready",
            root.isChinese ? "气液比预测任务已就绪" : "Gas-Liquid Ratio Prediction Task Ready"
        ]
        
        return root.selectedTaskType >= 0 ? taskNames[root.selectedTaskType] : ""
    }
    
    function showSuccessMessage(message) {
        messageText.text = message
        successMessage.opacity = 1
        messageTimer.restart()
    }
    
    function startLearningProcess() {
        if (root.selectedTaskType >= 0) {
            console.log("开始持续学习流程，任务类型:", root.selectedTaskType)
            
            // 这里可以调用控制器开始学习流程
            if (typeof continuousLearningController !== 'undefined') {
                continuousLearningController.selectTask(root.selectedTaskType)
                continuousLearningController.setPhase("data_preparation")
                showSuccessMessage(root.isChinese ? "学习流程已启动！" : "Learning process started!")
            }
        }
    }
}
