// Qt_Oil_NewContent/DeviceRecommendation/Components/TempPredictionChart.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    property bool isChineseMode: true
    property var predictionData: null
    
    signal predictionYearsChanged(int years)
    signal wearSimulationRequested(real wearPercentage)
    
    color: "white"
    border.color: Material.dividerColor
    border.width: 1
    radius: 8
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.centerIn: parent
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "📈"
            font.pixelSize: 48
            color: Material.accent
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: isChineseMode ? "性能预测分析" : "Performance Prediction Analysis"
            font.pixelSize: 16
            font.bold: true
            color: Material.primaryTextColor
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: isChineseMode ? "功能开发中..." : "Feature in development..."
            font.pixelSize: 12
            color: Material.secondaryTextColor
        }
        
        // 临时控制
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            
            SpinBox {
                from: 1
                to: 15
                value: 5
                onValueChanged: root.predictionYearsChanged(value)
            }
            
            Text {
                text: isChineseMode ? "预测年限" : "Prediction Years"
                font.pixelSize: 12
            }
        }
        
        RowLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            
            Slider {
                from: 0
                to: 100
                value: 0
                onValueChanged: root.wearSimulationRequested(value)
            }
            
            Text {
                text: isChineseMode ? "磨损仿真 (%)" : "Wear Simulation (%)"
                font.pixelSize: 12
            }
        }
    }
}