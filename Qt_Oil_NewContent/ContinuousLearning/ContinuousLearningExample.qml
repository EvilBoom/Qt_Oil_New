import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 持续学习主界面示例 - 可以集成到您的主窗口中
ApplicationWindow {
    id: window
    width: 1200
    height: 800
    title: "持续学习模块示例"
    
    property bool isChinese: true
    property int currentProjectId: 1
    
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        
        RowLayout {
            anchors.fill: parent
            spacing: 0
            
            // 左侧导航栏
            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                color: "#343a40"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    
                    Text {
                        Layout.fillWidth: true
                        text: window.isChinese ? "持续学习模块" : "Continuous Learning"
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#6c757d"
                        Layout.topMargin: 8
                        Layout.bottomMargin: 16
                    }
                    
                    // 导航按钮
                    NavigationButton {
                        Layout.fillWidth: true
                        text: window.isChinese ? "任务选择" : "Task Selection"
                        isActive: contentLoader.source.toString().includes("ContinuousLearningPage")
                        onClicked: {
                            contentLoader.source = "ContinuousLearning/ContinuousLearningPage.qml"
                        }
                    }
                    
                    NavigationButton {
                        Layout.fillWidth: true
                        text: window.isChinese ? "数据管理" : "Data Management"
                        isActive: false
                        onClicked: {
                            // 加载数据管理页面
                        }
                    }
                    
                    NavigationButton {
                        Layout.fillWidth: true
                        text: window.isChinese ? "模型监控" : "Model Monitoring"
                        isActive: false
                        onClicked: {
                            // 加载模型监控页面
                        }
                    }
                    
                    NavigationButton {
                        Layout.fillWidth: true
                        text: window.isChinese ? "历史记录" : "History"
                        isActive: false
                        onClicked: {
                            // 加载历史记录页面
                        }
                    }
                    
                    Item { Layout.fillHeight: true }
                    
                    // 底部信息
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        color: "#495057"
                        radius: 8
                        
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            
                            Text {
                                text: window.isChinese ? "当前项目" : "Current Project"
                                color: "#adb5bd"
                                font.pixelSize: 12
                            }
                            
                            Text {
                                text: window.isChinese ? "项目 #" + window.currentProjectId : "Project #" + window.currentProjectId
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }
                }
            }
            
            // 右侧内容区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#f8f9fa"
                
                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    source: "ContinuousLearning/ContinuousLearningPage.qml"
                    
                    onLoaded: {
                        if (item) {
                            item.isChinese = window.isChinese
                            item.currentProjectId = window.currentProjectId
                        }
                    }
                }
            }
        }
    }
    
    // 导航按钮组件
    component NavigationButton: Rectangle {
        property string text: ""
        property bool isActive: false
        signal clicked()
        
        height: 40
        color: isActive ? "#007bff" : (mouseArea.containsMouse ? "#495057" : "transparent")
        radius: 6
        
        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.isActive ? "white" : "#adb5bd"
            font.pixelSize: 14
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()
        }
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
    
    // 连接持续学习控制器的信号
    Connections {
        target: continuousLearningController
        
        function onPhaseChanged(phase) {
            console.log("阶段变化:", phase)
        }
        
        function onTaskSelectionChanged(taskId) {
            console.log("任务选择变化:", taskId)
            // 设置项目ID
            continuousLearningController.setProjectId(window.currentProjectId)
        }
        
        function onDataPreparationCompleted(taskType, result) {
            console.log("数据准备完成:", JSON.stringify(result))
        }
        
        function onTrainingCompleted(taskType, result) {
            console.log("训练完成:", JSON.stringify(result))
        }
        
        function onEvaluationCompleted(taskType, result) {
            console.log("评估完成:", JSON.stringify(result))
        }
    }
    
    Component.onCompleted: {
        console.log("持续学习模块已加载")
        if (typeof continuousLearningController !== 'undefined') {
            continuousLearningController.setProjectId(window.currentProjectId)
        }
    }
}
