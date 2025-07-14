// Qt_Oil_NewContent/DeviceRecommendation/Components/PumpComparisonView.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    // 属性
    property var pumps: []
    property var constraints: ({})
    property bool isChineseMode: true
    
    // 信号
    signal pumpSelected(var pump)
    
    color: "transparent"
    
    ScrollView {
        anchors.fill: parent
        clip: true
        
        ColumnLayout {
            width: parent.width
            spacing: 16
            
            // 标题
            Text {
                text: isChineseMode ? "泵型对比" : "Pump Comparison"
                font.pixelSize: 18
                font.bold: true
                color: Material.primaryTextColor
                Layout.leftMargin: 16
                Layout.topMargin: 16
            }
            
            // 对比表格
            Rectangle {
                Layout.fillWidth: true
                Layout.margins: 16
                height: comparisonGrid.height + 32
                color: Material.dialogColor
                radius: 8
                
                GridLayout {
                    id: comparisonGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    
                    columns: Math.min(pumps.length + 1, 4) // 最多显示3个泵 + 1个参数列
                    columnSpacing: 16
                    rowSpacing: 12
                    
                    // 表头 - 参数名称
                    Text {
                        text: isChineseMode ? "参数" : "Parameter"
                        font.pixelSize: 14
                        font.bold: true
                        color: Material.primaryTextColor
                        Layout.preferredWidth: 120
                    }
                    
                    // 表头 - 泵型号
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: Material.backgroundColor
                            radius: 4
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                
                                Text {
                                    text: pumps[index] ? pumps[index].manufacturer : ""
                                    font.pixelSize: 12
                                    color: Material.secondaryTextColor
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: pumps[index] ? pumps[index].model : ""
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Material.primaryTextColor
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                
                                Button {
                                    text: isChineseMode ? "选择" : "Select"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    font.pixelSize: 12
                                    flat: false
                                    
                                    onClicked: {
                                        if (pumps[index]) {
                                            root.pumpSelected(pumps[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 分隔线
                    Rectangle {
                        Layout.columnSpan: comparisonGrid.columns
                        Layout.fillWidth: true
                        height: 1
                        color: Material.dividerColor
                    }
                    
                    // 匹配度
                    Text {
                        text: isChineseMode ? "匹配度" : "Match Score"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: "transparent"
                            
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                
                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 20
                                    color: getMatchColor(calculatePumpMatchScore(pumps[index]))
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: calculatePumpMatchScore(pumps[index]) + "%"
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "white"
                                    }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Text {
                                        text: getMatchText(calculatePumpMatchScore(pumps[index]))
                                        font.pixelSize: 11
                                        color: Material.secondaryTextColor
                                    }
                                }
                            }
                        }
                    }
                    
                    // 流量范围
                    Text {
                        text: isChineseMode ? "流量范围" : "Flow Range"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Text {
                            text: pumps[index] ? 
                                  pumps[index].minFlow + " - " + pumps[index].maxFlow + " bbl/d" : ""
                            font.pixelSize: 13
                            color: Material.primaryTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    // 单级扬程
                    Text {
                        text: isChineseMode ? "单级扬程" : "Head/Stage"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Text {
                            text: pumps[index] ? pumps[index].headPerStage + " ft" : ""
                            font.pixelSize: 13
                            color: Material.primaryTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    // 最大级数
                    Text {
                        text: isChineseMode ? "最大级数" : "Max Stages"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Text {
                            text: pumps[index] ? pumps[index].maxStages : ""
                            font.pixelSize: 13
                            color: Material.primaryTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    // 效率
                    Text {
                        text: isChineseMode ? "最佳效率" : "Best Efficiency"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Text {
                            text: pumps[index] ? pumps[index].efficiency + "%" : ""
                            font.pixelSize: 13
                            color: Material.primaryTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    // 轴功率
                    Text {
                        text: isChineseMode ? "轴功率/级" : "Power/Stage"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Text {
                            text: pumps[index] ? pumps[index].powerPerStage + " HP" : ""
                            font.pixelSize: 13
                            color: Material.primaryTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    // 外径
                    Text {
                        text: isChineseMode ? "外径" : "OD"
                        font.pixelSize: 13
                        color: Material.secondaryTextColor
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Text {
                            text: pumps[index] ? pumps[index].outerDiameter + " in" : ""
                            font.pixelSize: 13
                            color: Material.primaryTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    // 分隔线
                    Rectangle {
                        Layout.columnSpan: comparisonGrid.columns
                        Layout.fillWidth: true
                        height: 1
                        color: Material.dividerColor
                    }
                    
                    // 需求匹配情况
                    Text {
                        text: isChineseMode ? "需求匹配" : "Requirements"
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                        Layout.topMargin: 8
                    }
                    
                    Repeater {
                        model: Math.min(pumps.length, 3)
                        
                        Column {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            spacing: 4
                            
                            // 流量匹配
                            Row {
                                spacing: 4
                                
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: checkFlowMatch(pumps[index]) ? 
                                           Material.color(Material.Green) : 
                                           Material.color(Material.Red)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: isChineseMode ? "流量" : "Flow"
                                    font.pixelSize: 11
                                    color: Material.secondaryTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            // 扬程匹配
                            Row {
                                spacing: 4
                                
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: checkHeadMatch(pumps[index]) ? 
                                           Material.color(Material.Green) : 
                                           Material.color(Material.Red)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: isChineseMode ? "扬程" : "Head"
                                    font.pixelSize: 11
                                    color: Material.secondaryTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            // 尺寸匹配
                            Row {
                                spacing: 4
                                
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: checkSizeMatch(pumps[index]) ? 
                                           Material.color(Material.Green) : 
                                           Material.color(Material.Red)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: isChineseMode ? "尺寸" : "Size"
                                    font.pixelSize: 11
                                    color: Material.secondaryTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
            
            // 空状态
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                Layout.margins: 16
                color: Material.dialogColor
                radius: 8
                visible: pumps.length === 0
                
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📊"
                        font.pixelSize: 48
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "暂无可对比的泵型" : "No pumps to compare"
                        color: Material.hintTextColor
                        font.pixelSize: 14
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
        }
    }
    
    // 辅助函数
    function calculatePumpMatchScore(pump) {
        if (!pump || !constraints.minProduction) return 50

        var score = 100

        // 流量匹配度
        var requiredFlow = (constraints.minProduction + constraints.maxProduction) / 2
        if (requiredFlow < pump.minFlow || requiredFlow > pump.maxFlow) {
            score -= 30
        } else {
            // 在最佳效率点附近
            var bestEfficiencyFlow = (pump.minFlow + pump.maxFlow) / 2
            var flowDeviation = Math.abs(requiredFlow - bestEfficiencyFlow) / bestEfficiencyFlow
            score -= flowDeviation * 20
        }

        // 扬程匹配度
        if (constraints.pumpDepth) {
            var requiredStages = Math.ceil(constraints.pumpDepth / pump.headPerStage)
            if (requiredStages > pump.maxStages) {
                score -= 40
            }
        }

        // 效率考虑
        score += (pump.efficiency - 60) * 0.5

        return Math.max(0, Math.min(100, Math.round(score)))
    }
    
    function getMatchColor(score) {
        if (score >= 80) return Material.color(Material.Green)
        if (score >= 60) return Material.color(Material.Orange)
        return Material.color(Material.Red)
    }
    
    function getMatchText(score) {
        if (!isChineseMode) {
            if (score >= 80) return "Excellent"
            if (score >= 60) return "Good"
            return "Poor"
        } else {
            if (score >= 80) return "优秀"
            if (score >= 60) return "良好"
            return "较差"
        }
    }
    
    function checkFlowMatch(pump) {
        if (!pump || !constraints.minProduction) return false
        var requiredFlow = (constraints.minProduction + constraints.maxProduction) / 2
        return requiredFlow >= pump.minFlow && requiredFlow <= pump.maxFlow
    }
    
    function checkHeadMatch(pump) {
        if (!pump || !constraints.pumpDepth) return false
        var requiredStages = Math.ceil(constraints.pumpDepth / pump.headPerStage)
        return requiredStages <= pump.maxStages
    }
    
    function checkSizeMatch(pump) {
        if (!pump) return false
        // 假设套管尺寸为 5.5 英寸（如果没有提供具体值）
        var casingSize = 5.5
        return pump.outerDiameter <= casingSize - 0.5
    }
}