import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    property var continuousLearningController
    
    signal backRequested()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        
        // 页面标题和导航
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: root.isChinese ? "← 返回" : "← Back"
                onClicked: root.backRequested()
            }
            
            Text {
                text: root.isChinese ? "模型训练" : "Model Training"
                font.pixelSize: 24
                font.bold: true
                color: "#212529"
                Layout.fillWidth: true
            }
        }
        
        // 临时内容
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "white"
            radius: 8
            border.width: 1
            border.color: "#dee2e6"
            
            Text {
                anchors.centerIn: parent
                text: root.isChinese ? "模型训练功能开发中..." : "Model Training feature under development..."
                font.pixelSize: 18
                color: "#6c757d"
            }
        }
    }
}
