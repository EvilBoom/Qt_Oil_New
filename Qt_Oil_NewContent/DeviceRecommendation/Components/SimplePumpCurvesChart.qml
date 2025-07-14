// Qt_Oil_NewContent/DeviceRecommendation/Components/SimplePumpPerformanceChart.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts

Rectangle {
    id: root
    
    property var controller: null
    property bool isChineseMode: true
    property var pumpData: null
    property int stages: 50
    property real frequency: 60
    
    signal operatingPointChanged(real flow, real head)
    signal configurationChanged(int stages, real frequency)
    
    color: "white"
    border.color: Material.dividerColor
    border.width: 1
    radius: 8
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // 标题
        Text {
            text: isChineseMode ? "泵性能曲线" : "Pump Performance Curves"
            font.pixelSize: 16
            font.bold: true
            color: Material.primaryTextColor
        }
        
        // 图表区域
        ChartView {
            id: chartView
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            title: pumpData ? `${pumpData.manufacturer} ${pumpData.model}` : ""
            legend.alignment: Qt.AlignBottom
            antialiasing: true
            
            ValueAxis {
                id: flowAxis
                titleText: isChineseMode ? "流量 (bbl/d)" : "Flow Rate (bbl/d)"
                min: 0
                max: 5000
                tickCount: 6
            }
            
            ValueAxis {
                id: headAxis
                titleText: isChineseMode ? "扬程 (ft)" : "Head (ft)"
                min: 0
                max: 150
                tickCount: 6
            }
            
            // 扬程曲线
            LineSeries {
                id: headSeries
                name: isChineseMode ? "扬程曲线" : "Head Curve"
                axisX: flowAxis
                axisY: headAxis
                color: "#2196F3"
                width: 3
                
                Component.onCompleted: {
                    generateMockHeadCurve()
                }
            }
            
            // 效率曲线 (使用右侧Y轴)
            ValueAxis {
                id: efficiencyAxis
                titleText: isChineseMode ? "效率 (%)" : "Efficiency (%)"
                min: 0
                max: 100
                tickCount: 6
            }
            
            LineSeries {
                id: efficiencySeries
                name: isChineseMode ? "效率曲线" : "Efficiency Curve"
                axisX: flowAxis
                axisYRight: efficiencyAxis
                color: "#4CAF50"
                width: 3
                
                Component.onCompleted: {
                    generateMockEfficiencyCurve()
                }
            }
            
            // 工况点
            ScatterSeries {
                id: operatingPoint
                name: isChineseMode ? "工况点" : "Operating Point"
                axisX: flowAxis
                axisY: headAxis
                color: "#F44336"
                markerSize: 12
                borderWidth: 2
                borderColor: "white"
                
                Component.onCompleted: {
                    // 默认工况点
                    append(1500, 75)
                }
            }
        }
        
        // 控制按钮
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: isChineseMode ? "重新生成曲线" : "Regenerate Curves"
                onClicked: {
                    generateCurves()
                }
            }
            
            Button {
                text: isChineseMode ? "导出图表" : "Export Chart"
                onClicked: {
                    exportChart()
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Text {
                text: isChineseMode ? 
                      `当前配置: ${stages}级, ${frequency}Hz` :
                      `Current: ${stages} stages, ${frequency}Hz`
                font.pixelSize: 12
                color: Material.secondaryTextColor
            }
        }
    }
    
    // 监听配置变化
    onStagesChanged: generateCurves()
    onFrequencyChanged: generateCurves()
    onPumpDataChanged: generateCurves()
    
    function generateCurves() {
        if (!pumpData) return
        
        console.log("生成性能曲线:", pumpData.model, stages, "级,", frequency, "Hz")
        
        generateMockHeadCurve()
        generateMockEfficiencyCurve()
        updateOperatingPoint()
    }
    
    function generateMockHeadCurve() {
        headSeries.clear()
        
        if (!pumpData) return
        
        // 基于泵数据生成扬程曲线
        var maxFlow = pumpData.maxFlow || 4000
        var headPerStage = pumpData.headPerStage || 25
        var totalHead = headPerStage * stages * (frequency / 60)
        
        // 生成典型的泵扬程曲线（二次曲线）
        for (var i = 0; i <= 10; i++) {
            var flow = (maxFlow / 10) * i
            var headRatio = 1 - Math.pow(flow / maxFlow, 1.8) * 0.8  // 扬程衰减
            var head = totalHead * headRatio
            
            headSeries.append(flow, Math.max(head, 0))
        }
        
        console.log("扬程曲线生成完成，总扬程:", totalHead)
    }
    
    function generateMockEfficiencyCurve() {
        efficiencySeries.clear()
        
        if (!pumpData) return
        
        var maxFlow = pumpData.maxFlow || 4000
        var maxEfficiency = pumpData.efficiency || 70
        
        // 生成典型的效率曲线（钟形曲线）
        for (var i = 0; i <= 10; i++) {
            var flow = (maxFlow / 10) * i
            var flowRatio = flow / maxFlow
            
            // 钟形效率曲线，在60%流量处达到最高效率
            var efficiency = maxEfficiency * Math.exp(-Math.pow((flowRatio - 0.6) / 0.3, 2))
            
            efficiencySeries.append(flow, Math.max(efficiency, 0))
        }
        
        console.log("效率曲线生成完成，最高效率:", maxEfficiency)
    }
    
    function updateOperatingPoint() {
        operatingPoint.clear()
        
        if (!pumpData) return
        
        // 计算工况点（假设在最佳效率点附近）
        var optimalFlow = (pumpData.maxFlow || 4000) * 0.6
        var headPerStage = pumpData.headPerStage || 25
        var operatingHead = headPerStage * stages * (frequency / 60) * 0.8
        
        operatingPoint.append(optimalFlow, operatingHead)
        
        console.log("工况点更新:", optimalFlow, "bbl/d,", operatingHead, "ft")
        
        // 发射信号
        root.operatingPointChanged(optimalFlow, operatingHead)
    }
    
    function exportChart() {
        console.log("导出图表功能")
        // TODO: 实现图表导出
    }
    
    // 图表点击处理
    Connections {
        target: chartView
        function onClicked(point) {
            console.log("图表点击:", point.x, point.y)
            // 更新工况点
            operatingPoint.clear()
            operatingPoint.append(point.x, point.y)
            root.operatingPointChanged(point.x, point.y)
        }
    }
}
