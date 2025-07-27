import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: 400
    height: 240
    color: "#f8f9fa"
    radius: 8
    border.width: 1
    border.color: "#e9ecef"
    
    // 属性定义
    property bool isChinese: true
    property int selectedTask: -1  // 0: 扬程预测, 1: 产量预测, 2: 气液比预测
    
    // 信号定义
    signal taskSelected(int taskType)
    signal confirmClicked()
    signal cancelClicked()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16
        
        // 标题
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "transparent"
            border.width: 2
            border.color: "#495057"
            radius: 6
            
            Text {
                anchors.centerIn: parent
                text: root.isChinese ? "任务选择:" : "Task Selection:"
                font.pixelSize: 16
                font.bold: true
                color: "#495057"
            }
        }
        
        // 任务选项区域
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            
            // 扬程预测
            RadioButton {
                id: radioHead
                Layout.fillWidth: true
                text: root.isChinese ? "扬程预测" : "Head Prediction"
                font.pixelSize: 14
                
                indicator: Rectangle {
                    implicitWidth: 18
                    implicitHeight: 18
                    x: radioHead.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 9
                    border.color: radioHead.checked ? "#007bff" : "#6c757d"
                    border.width: 2
                    color: "white"
                    
                    Rectangle {
                        width: 8
                        height: 8
                        x: 5
                        y: 5
                        radius: 4
                        color: "#007bff"
                        visible: radioHead.checked
                    }
                }
                
                contentItem: Text {
                    text: radioHead.text
                    font: radioHead.font
                    color: "#495057"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: radioHead.indicator.width + radioHead.spacing
                }
                
                onCheckedChanged: {
                    if (checked) {
                        root.selectedTask = 0
                        root.taskSelected(0)
                    }
                }
                
                background: Rectangle {
                    color: "transparent"
                    radius: 4
                }
            }
            
            // 产量预测
            RadioButton {
                id: radioProduction
                Layout.fillWidth: true
                text: root.isChinese ? "产量预测" : "Production Prediction"
                font.pixelSize: 14
                
                indicator: Rectangle {
                    implicitWidth: 18
                    implicitHeight: 18
                    x: radioProduction.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 9
                    border.color: radioProduction.checked ? "#007bff" : "#6c757d"
                    border.width: 2
                    color: "white"
                    
                    Rectangle {
                        width: 8
                        height: 8
                        x: 5
                        y: 5
                        radius: 4
                        color: "#007bff"
                        visible: radioProduction.checked
                    }
                }
                
                contentItem: Text {
                    text: radioProduction.text
                    font: radioProduction.font
                    color: "#495057"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: radioProduction.indicator.width + radioProduction.spacing
                }
                
                onCheckedChanged: {
                    if (checked) {
                        root.selectedTask = 1
                        root.taskSelected(1)
                    }
                }
                
                background: Rectangle {
                    color: "transparent"
                    radius: 4
                }
            }
            
            // 气液比预测
            RadioButton {
                id: radioGasLiquid
                Layout.fillWidth: true
                text: root.isChinese ? "气液比预测" : "Gas-Liquid Ratio Prediction"
                font.pixelSize: 14
                
                indicator: Rectangle {
                    implicitWidth: 18
                    implicitHeight: 18
                    x: radioGasLiquid.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 9
                    border.color: radioGasLiquid.checked ? "#007bff" : "#6c757d"
                    border.width: 2
                    color: "white"
                    
                    Rectangle {
                        width: 8
                        height: 8
                        x: 5
                        y: 5
                        radius: 4
                        color: "#007bff"
                        visible: radioGasLiquid.checked
                    }
                }
                
                contentItem: Text {
                    text: radioGasLiquid.text
                    font: radioGasLiquid.font
                    color: "#495057"
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: radioGasLiquid.indicator.width + radioGasLiquid.spacing
                }
                
                onCheckedChanged: {
                    if (checked) {
                        root.selectedTask = 2
                        root.taskSelected(2)
                    }
                }
                
                background: Rectangle {
                    color: "transparent"
                    radius: 4
                }
            }
            
            Item { Layout.fillHeight: true }
        }
        
        // 底部按钮区域
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: root.isChinese ? "确定" : "Confirm"
                enabled: root.selectedTask >= 0
                
                background: Rectangle {
                    color: parent.enabled ? "#007bff" : "#6c757d"
                    radius: 6
                    border.width: 1
                    border.color: parent.enabled ? "#0056b3" : "#5a6268"
                }
                
                contentItem: Text {
                    text: "确定"
                    color: "white"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    root.confirmClicked()
                }
            }
            
            Button {
                text: root.isChinese ? "取消" : "Cancel"
                
                background: Rectangle {
                    color: "white"
                    radius: 6
                    border.width: 1
                    border.color: "#6c757d"
                }
                
                contentItem: Text {
                    text: "取消"
                    color: "#6c757d"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    root.cancelClicked()
                }
            }
        }
    }
    
    // 公共方法
    function resetSelection() {
        root.selectedTask = -1
        radioHead.checked = false
        radioProduction.checked = false
        radioGasLiquid.checked = false
    }
    
    function setTask(taskType) {
        root.selectedTask = taskType
        switch(taskType) {
            case 0:
                radioHead.checked = true
                break
            case 1:
                radioProduction.checked = true
                break
            case 2:
                radioGasLiquid.checked = true
                break
            default:
                resetSelection()
                break
        }
    }
    
    function getTaskName(taskType) {
        switch(taskType) {
            case 0: return root.isChinese ? "扬程预测" : "Head Prediction"
            case 1: return root.isChinese ? "产量预测" : "Production Prediction"
            case 2: return root.isChinese ? "气液比预测" : "Gas-Liquid Ratio Prediction"
            default: return ""
        }
    }
}
