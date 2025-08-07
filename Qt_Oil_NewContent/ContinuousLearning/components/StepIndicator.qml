import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 60
    color: "transparent"
    
    property int stepNumber: 1
    property string stepTitle: ""
    property bool isActive: false
    property bool isCompleted: false
    property bool isChinese: true
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // 步骤圆圈
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: root.getStepColor()
            border.width: 2
            border.color: root.getStepBorderColor()
            
            Text {
                anchors.centerIn: parent
                text: root.isCompleted ? "✓" : root.stepNumber.toString()
                color: root.getStepTextColor()
                font.pixelSize: 14
                font.bold: true
            }
        }
        
        // 步骤标题
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.stepTitle
            color: root.getTextColor()
            font.pixelSize: 14
            font.bold: root.isActive
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
    
    function getStepColor() {
        if (root.isCompleted) return "#28a745"
        if (root.isActive) return "#007bff"
        return "white"
    }
    
    function getStepBorderColor() {
        if (root.isCompleted) return "#28a745"
        if (root.isActive) return "#007bff"
        return "#dee2e6"
    }
    
    function getStepTextColor() {
        if (root.isCompleted || root.isActive) return "white"
        return "#6c757d"
    }
    
    function getTextColor() {
        if (root.isActive) return "#007bff"
        if (root.isCompleted) return "#28a745"
        return "#6c757d"
    }
}
