// Qt_Oil_NewContent/DeviceRecommendation/Components/SeparatorCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material


Rectangle {
    id: root
    
    property var separatorData: null
    property bool isSelected: false
    property int matchScore: 50
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
        visible: matchScore >= 80 && !separatorData.isNoSeparator
        
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
            
            // 图标
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: separatorData && separatorData.isNoSeparator 
                       ? Material.color(Material.Grey) 
                       : Material.color(Material.Blue)
                
                Text {
                    anchors.centerIn: parent
                    text: separatorData && separatorData.isNoSeparator ? "⊘" : "🔄"
                    font.pixelSize: 20
                }
            }
            
            // 标题
            Column {
                Layout.fillWidth: true
                
                Text {
                    text: separatorData ? separatorData.manufacturer : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }
                
                Text {
                    text: separatorData ? separatorData.model : ""
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
            
            // 匹配度（不显示给"不使用"选项）
            CircularProgress {
                width: 40
                height: 40
                value: matchScore / 100
                visible: !separatorData.isNoSeparator
                
                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }
        
        // 描述
        Text {
            Layout.fillWidth: true
            text: separatorData ? separatorData.description : ""
            font.pixelSize: 12
            color: Material.secondaryTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        
        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
            visible: !separatorData.isNoSeparator
        }
        
        // 关键参数（不显示给"不使用"选项）
        Grid {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 8
            visible: !separatorData.isNoSeparator
            
            // 分离效率
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "分离效率" : "Efficiency"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Row {
                    spacing: 4
                    
                    Rectangle {
                        width: 24
                        height: 4
                        radius: 2
                        color: Material.color(Material.Green)
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (separatorData ? separatorData.separationEfficiency / 100 : 0)
                            height: parent.height
                            radius: parent.radius
                            color: Material.color(Material.LightGreen)
                        }
                    }
                    
                    Text {
                        text: (separatorData ? separatorData.separationEfficiency : 0) + "%"
                        font.pixelSize: 12
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
            
            // 气体处理能力
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "气体处理" : "Gas Capacity"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Text {
                    text: (separatorData ? separatorData.gasHandlingCapacity : 0) + " mcf/d"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
            
            // 液体处理能力
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "液体处理" : "Liquid Capacity"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Text {
                    text: (separatorData ? separatorData.liquidHandlingCapacity : 0) + " bbl/d"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
            
            // 外径
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "外径" : "OD"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Text {
                    text: (separatorData ? separatorData.outerDiameter : 0) + " in"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
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
}

