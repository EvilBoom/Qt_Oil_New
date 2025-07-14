// Qt_Oil_NewContent/DeviceRecommendation/Components/StepIndicator.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    property var steps: []
    property int currentStep: 0
    property color activeColor: Material.accent
    property color inactiveColor: Material.hintTextColor
    property color completedColor: Material.primaryColor
    property int stepsPerRow: 4  // 每行显示的步骤数
    
    signal stepClicked(int index)
    
    color: Material.background
    
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Material.dividerColor
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 10  // 两行之间的间距
        
        // 第一行步骤
        Row {
            id: topRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            
            Repeater {
                model: Math.min(stepsPerRow, steps.length)
                
                Row {
                    spacing: 0
                    
                    // 步骤项
                    Rectangle {
                        width: stepContent.width + 32
                        height: 50  // 行高
                        color: "transparent"
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stepClicked(index)
                            enabled: index <= currentStep + 1
                        }
                        
                        Row {
                            id: stepContent
                            anchors.centerIn: parent
                            spacing: 8
                            
                            // 步骤圆圈
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: {
                                    if (index < currentStep) return completedColor
                                    if (index === currentStep) return activeColor
                                    return "transparent"
                                }
                                border.width: 2
                                border.color: {
                                    if (index <= currentStep) return "transparent"
                                    return inactiveColor
                                }
                                
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (index < currentStep) return "✓"
                                        return (index + 1).toString()
                                    }
                                    color: {
                                        if (index <= currentStep) return "white"
                                        return inactiveColor
                                    }
                                    font.pixelSize: 14
                                    font.bold: index === currentStep
                                }
                            }
                            
                            // 步骤文本
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: steps[index].icon + " " + steps[index].title
                                    color: {
                                        if (index <= currentStep) return Material.primaryTextColor
                                        return inactiveColor
                                    }
                                    font.pixelSize: 14
                                    font.bold: index === currentStep
                                }
                                
                                // 当前步骤显示下划线
                                Rectangle {
                                    width: parent.width
                                    height: 2
                                    color: activeColor
                                    visible: index === currentStep
                                }
                            }
                        }
                    }
                    
                    // 连接线（每行最后一个步骤后不显示）
                    Rectangle {
                        width: 20
                        height: 2
                        color: index < Math.min(stepsPerRow, steps.length) - 1 ? 
                               (index < currentStep ? completedColor : inactiveColor) : 
                               "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: index < Math.min(stepsPerRow, steps.length) - 1
                    }
                }
            }
        }
        
        // 第二行步骤（如果有）
        Row {
            id: bottomRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            visible: steps.length > stepsPerRow
            
            Repeater {
                model: Math.max(0, steps.length - stepsPerRow)
                
                Row {
                    spacing: 0
                    
                    // 步骤项
                    Rectangle {
                        width: stepContent2.width + 32
                        height: 50  // 行高
                        color: "transparent"
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.stepClicked(index + stepsPerRow)
                            enabled: index + stepsPerRow <= currentStep + 1
                        }
                        
                        Row {
                            id: stepContent2
                            anchors.centerIn: parent
                            spacing: 8
                            
                            // 步骤圆圈
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: {
                                    if (index + stepsPerRow < currentStep) return completedColor
                                    if (index + stepsPerRow === currentStep) return activeColor
                                    return "transparent"
                                }
                                border.width: 2
                                border.color: {
                                    if (index + stepsPerRow <= currentStep) return "transparent"
                                    return inactiveColor
                                }
                                
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (index + stepsPerRow < currentStep) return "✓"
                                        return (index + stepsPerRow + 1).toString()
                                    }
                                    color: {
                                        if (index + stepsPerRow <= currentStep) return "white"
                                        return inactiveColor
                                    }
                                    font.pixelSize: 14
                                    font.bold: index + stepsPerRow === currentStep
                                }
                            }
                            
                            // 步骤文本
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                
                                Text {
                                    text: steps[index + stepsPerRow].icon + " " + steps[index + stepsPerRow].title
                                    color: {
                                        if (index + stepsPerRow <= currentStep) return Material.primaryTextColor
                                        return inactiveColor
                                    }
                                    font.pixelSize: 14
                                    font.bold: index + stepsPerRow === currentStep
                                }
                                
                                // 当前步骤显示下划线
                                Rectangle {
                                    width: parent.width
                                    height: 2
                                    color: activeColor
                                    visible: index + stepsPerRow === currentStep
                                }
                            }
                        }
                    }
                    
                    // 连接线（每行最后一个步骤后不显示）
                    Rectangle {
                        width: 20
                        height: 2
                        color: index < steps.length - stepsPerRow - 1 ? 
                               (index + stepsPerRow < currentStep ? completedColor : inactiveColor) : 
                               "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: index < steps.length - stepsPerRow - 1
                    }
                }
            }
        }
        
        // 行间连接标记（只有在有两行时才显示）
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            height: 10
            visible: steps.length > stepsPerRow && currentStep >= stepsPerRow
            
            Rectangle {
                width: 2
                height: 10
                color: completedColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}