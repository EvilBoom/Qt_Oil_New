import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#f5f7fa"
    
    property bool isChineseMode: true
    
    Component.onCompleted: {
        console.log("Minimal DeviceManagement page loaded")
        console.log("isChineseMode:", isChineseMode)
        
        // 测试deviceController
        if (typeof deviceController !== 'undefined') {
            console.log("DeviceController found:", typeof deviceController)
            console.log("DeviceController methods:", Object.getOwnPropertyNames(deviceController))
        } else {
            console.log("DeviceController NOT found")
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        
        Text {
            text: root.isChineseMode ? "设备数据库管理 - 最小版本" : "Equipment Database Management - Minimal Version"
            font.pixelSize: 24
            font.bold: true
            color: "#333"
        }
        
        Button {
            text: "测试DeviceController"
            onClicked: {
                if (typeof deviceController !== 'undefined') {
                    console.log("Testing deviceController...")
                    try {
                        deviceController.loadDevices()
                        console.log("loadDevices() called successfully")
                    } catch (error) {
                        console.error("Error calling loadDevices():", error)
                    }
                } else {
                    console.log("deviceController not available")
                }
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
                text: "设备列表区域\n(这里应该显示设备列表)"
                color: "#666"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
