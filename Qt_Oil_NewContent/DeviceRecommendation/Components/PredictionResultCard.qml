// Qt_Oil_NewContent/DeviceRecommendation/Components/PredictionResultCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    property string title: ""
    property string unit: ""
    property string icon: ""
    property real mlValue: 0
    property real empiricalValue: 0
    property real confidence: 0
    property bool isAdjustable: true
    property real finalValue: mlValue
    
    // 删除重复的信号定义，使用属性自动生成的 finalValueChanged 信号
    
    color: Material.backgroundColor
    radius: 8
    border.width: 1
    border.color: Material.dividerColor
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // 标题栏
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: icon
                font.pixelSize: 24
            }
            
            Text {
                text: title
                font.pixelSize: 14
                font.bold: true
                color: Material.primaryTextColor
            }
            
            Item { Layout.fillWidth: true }
            
            // // 置信度指示器
            // Rectangle {
            //     width: 60
            //     height: 20
            //     radius: 10
            //     color: getConfidenceColor(confidence)
            //     visible: confidence > 0
                
            //     Text {
            //         anchors.centerIn: parent
            //         text: Math.round(confidence * 100) + "%"
            //         color: "white"
            //         font.pixelSize: 11
            //         font.bold: true
            //     }
            // }
        }
        
        // 预测值显示
        Column {
            Layout.fillWidth: true
            spacing: 8
            
            // ML预测值
            Row {
                width: parent.width
                spacing: 8
                
                Rectangle {
                    width: 4
                    height: 20
                    color: Material.accent
                    radius: 2
                }
                
                Text {
                    text: "ML: " + mlValue.toFixed(2) + " " + unit
                    color: Material.primaryTextColor
                    font.pixelSize: 16
                    font.bold: true
                }
            }
            
            // 经验值
            Row {
                width: parent.width
                spacing: 8
                
                Rectangle {
                    width: 4
                    height: 20
                    color: Material.color(Material.Orange)
                    radius: 2
                }
                
                Text {
                    text: "经验: " + empiricalValue.toFixed(2) + " " + unit
                    color: Material.secondaryTextColor
                    font.pixelSize: 14
                }
            }
            
            // 差异百分比
            // Text {
            //     text: {
            //         if (empiricalValue === 0) return ""
            //         var diff = ((mlValue - empiricalValue) / empiricalValue * 100).toFixed(1)
            //         return "差异: " + (diff > 0 ? "+" : "") + diff + "%"
            //     }
            //     color: Material.hintTextColor
            //     font.pixelSize: 12
            //     visible: text.length > 0
            // }
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }
        
        // 可调整区域
        Column {
            Layout.fillWidth: true
            spacing: 8
            visible: isAdjustable
            
            Text {
                text: "最终采用值:"
                color: Material.hintTextColor
                font.pixelSize: 12
            }
            
            RowLayout {
                width: parent.width
                spacing: 8
                
                SpinBox {
                    id: valueSpinBox
                    Layout.fillWidth: true
                    from: 0
                    to: Math.max(mlValue * 2 * 100, 1000)
                    stepSize: 1
                    editable: true
    
                    Component.onCompleted: {
                        value = Math.round(finalValue * 100)
                    }
    
                    onValueChanged: {
                        var newRealValue = value / 100.0
                        if (Math.abs(finalValue - newRealValue) > 0.01) {
                            finalValue = newRealValue
                        }
                    }
    
                    // 监听外部finalValue变化
                    Connections {
                        target: root
                        function onFinalValueChanged() {
                            var expectedValue = Math.round(finalValue * 100)
                            if (Math.abs(valueSpinBox.value - expectedValue) > 1) {
                                valueSpinBox.value = expectedValue
                            }
                        }
                    }
    
                    textFromValue: function(value, locale) {
                        return (value / 100.0).toFixed(2)
                    }
    
                    valueFromText: function(text, locale) {
                        return Math.round(parseFloat(text) * 100)
                    }
                }
                
                Text {
                    text: unit
                    color: Material.primaryTextColor
                    font.pixelSize: 14
                }
            }
            
            // 快速选择按钮
            Row {
                spacing: 8
                
                Button {
                    text: "ML值"
                    flat: true
                    onClicked: valueSpinBox.value = mlValue * 100
                }
                
                Button {
                    text: "经验值"
                    flat: true
                    onClicked: valueSpinBox.value = empiricalValue * 100
                }
                
                Button {
                    text: "平均值"
                    flat: true
                    onClicked: valueSpinBox.value = ((mlValue + empiricalValue) / 2) * 100
                }
            }
        }
    }
    
    function getConfidenceColor(confidence) {
        if (confidence >= 0.8) return Material.color(Material.Green)
        if (confidence >= 0.6) return Material.color(Material.Orange)
        return Material.color(Material.Red)
    }
}
