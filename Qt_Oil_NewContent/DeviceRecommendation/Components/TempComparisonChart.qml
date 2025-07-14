// Qt_Oil_NewContent/DeviceRecommendation/Components/TempComparisonChart.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    property bool isChineseMode: true
    property var comparisonData: null
    
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
            text: "📊"
            font.pixelSize: 48
            color: Material.accent
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: isChineseMode ? "多工况对比图表" : "Multi-Condition Comparison Chart"
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
    }
}