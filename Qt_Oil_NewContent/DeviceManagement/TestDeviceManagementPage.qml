import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#f5f7fa"
    
    property bool isChineseMode: true
    
    Component.onCompleted: {
        console.log("Simple DeviceManagement test page loaded")
        console.log("isChineseMode:", isChineseMode)
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        Text {
            text: root.isChineseMode ? "设备数据库管理 - 测试页面" : "Equipment Database Management - Test Page"
            font.pixelSize: 24
            font.bold: true
            color: "#333"
        }
        
        Button {
            text: "测试按钮 / Test Button"
            onClicked: {
                console.log("Test button clicked")
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "white"
            border.color: "#e0e0e0"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "这里是设备列表区域\nThis is the device list area"
                color: "#666"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
