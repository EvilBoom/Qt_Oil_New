// Qt_Oil_NewContent/DeviceRecommendation/Components/MotorCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    property var motorData: null
    property bool isSelected: false
    property int matchScore: 50
    property real requiredPower: 100
    property int selectedVoltage: 3300
    property int selectedFrequency: 60
    property bool isChineseMode: true
    
    signal clicked()
    
    color: isSelected ? Material.dialogColor : Material.backgroundColor
    radius: 8
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.accent : Material.dividerColor
    
    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 60
        height: 24
        radius: 12
        color: Material.accent
        visible: matchScore >= 80
        
        Text {
            anchors.centerIn: parent
            text: isChineseMode ? "推荐" : "Best"
            color: "white"
            font.pixelSize: 11
            font.bold: true
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // 头部信息
        RowLayout {
            Layout.fillWidth: true
            
            // 图标和基本信息
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: Material.color(Material.DeepOrange)
                
                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    font.pixelSize: 20
                }
            }
            
            Column {
                Layout.fillWidth: true
                
                Text {
                    text: motorData ? motorData.manufacturer : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }
                
                Text {
                    text: motorData ? motorData.model : ""
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.primaryTextColor
                }
                
                Text {
                    text: motorData ? motorData.series + " Series" : ""
                    font.pixelSize: 11
                    color: Material.secondaryTextColor
                }
            }
            
            // 匹配度
            CircularProgress {
                width: 40
                height: 40
                value: matchScore / 100
                
                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }
        
        // 功率和负载率
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: getPowerUtilizationColor()
            radius: 6
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: isChineseMode ? "额定功率" : "Rated Power"
                        font.pixelSize: 11
                        color: Material.secondaryTextColor
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: (motorData ? motorData.power : 0) + " HP"
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
                
                // 负载率进度条
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(0, 0, 0, 0.1)
                    
                    Rectangle {
                        width: parent.width * Math.min(1.0, requiredPower / (motorData ? motorData.power : 1))
                        height: parent.height
                        radius: parent.radius
                        color: {
                            var ratio = requiredPower / (motorData ? motorData.power : 1)
                            if (ratio > 0.95) return Material.color(Material.Red)
                            if (ratio > 0.85) return Material.color(Material.Orange)
                            return Material.color(Material.Green)
                        }
                    }
                }
                
                Text {
                    text: {
                        var ratio = motorData ? (requiredPower / motorData.power * 100).toFixed(0) : 0
                        return (isChineseMode ? "负载率: " : "Load: ") + ratio + "%"
                    }
                    font.pixelSize: 11
                    color: Material.secondaryTextColor
                }
            }
        }
        
        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }
        
        // 关键参数
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 6
            
            // 效率
            Row {
                spacing: 6
                
                Rectangle {
                    width: 4
                    height: 14
                    color: Material.color(Material.Green)
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    
                    Text {
                        text: isChineseMode ? "效率" : "Efficiency"
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: (motorData ? motorData.efficiency : 0) + "%"
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
            
            // 功率因数
            Row {
                spacing: 6
                
                Rectangle {
                    width: 4
                    height: 14
                    color: Material.color(Material.Blue)
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    
                    Text {
                        text: isChineseMode ? "功率因数" : "PF"
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: motorData ? motorData.powerFactor : "0.85"
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
            
            // 绝缘等级
            Row {
                spacing: 6
                
                Rectangle {
                    width: 4
                    height: 14
                    color: Material.color(Material.Orange)
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    
                    Text {
                        text: isChineseMode ? "绝缘" : "Insulation"
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: (motorData ? motorData.insulationClass : "") + " " + (isChineseMode ? "级" : "Class")
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
            
            // 外径
            Row {
                spacing: 6
                
                Rectangle {
                    width: 4
                    height: 14
                    color: Material.color(Material.Purple)
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    
                    Text {
                        text: isChineseMode ? "外径" : "OD"
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: (motorData ? motorData.outerDiameter : 0) + " in"
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
        }
        
        // 电压/频率支持
        Flow {
            Layout.fillWidth: true
            spacing: 6
            
            // 支持的电压
            Repeater {
                model: motorData ? motorData.voltage : []
                
                Rectangle {
                    width: voltageText.width + 12
                    height: 20
                    radius: 10
                    color: modelData === selectedVoltage 
                           ? Material.accent 
                           : Qt.rgba(0, 0, 0, 0.05)
                    
                    Text {
                        id: voltageText
                        anchors.centerIn: parent
                        text: modelData + "V"
                        font.pixelSize: 10
                        color: modelData === selectedVoltage 
                               ? "white" 
                               : Material.secondaryTextColor
                    }
                }
            }
            
            // 分隔符
            Rectangle {
                width: 1
                height: 20
                color: Material.dividerColor
            }
            
            // 支持的频率
            Repeater {
                model: motorData ? motorData.frequency : []
                
                Rectangle {
                    width: freqText.width + 12
                    height: 20
                    radius: 10
                    color: modelData === selectedFrequency 
                           ? Material.accent 
                           : Qt.rgba(0, 0, 0, 0.05)
                    
                    Text {
                        id: freqText
                        anchors.centerIn: parent
                        text: modelData + "Hz"
                        font.pixelSize: 10
                        color: modelData === selectedFrequency 
                               ? "white" 
                               : Material.secondaryTextColor
                    }
                }
            }
        }
    }
    
    // 选中效果
    Rectangle {
        anchors.fill: parent
        color: Material.accent
        opacity: 0.1
        radius: parent.radius
        visible: isSelected
    }
    
    function getPowerUtilizationColor() {
        if (!motorData) return Material.backgroundColor
        
        var ratio = requiredPower / motorData.power
        if (ratio > 0.95) return Material.color(Material.Red, Material.Shade50)
        if (ratio > 0.85) return Material.color(Material.Orange, Material.Shade50)
        if (ratio < 0.5) return Material.color(Material.Orange, Material.Shade50)
        return Material.color(Material.Green, Material.Shade50)
    }

    Component.onCompleted: {
        console.log("尝试正常加载motorCard")
        console.log(motorData)
    }
}
