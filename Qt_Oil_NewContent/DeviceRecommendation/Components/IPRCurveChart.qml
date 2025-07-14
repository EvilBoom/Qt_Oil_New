// Qt_Oil_NewContent/DeviceRecommendation/Components/IPRCurveDialog.qml
// 修复版 - 解决canvas引用和初始化问题

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var curveData: []
    property real currentProduction: 0
    property bool isChineseMode: true

    width: 900
    height: 700
    color: "transparent"

    // 使用Popup代替Dialog
    Popup {
        id: chartPopup

        anchors.centerIn: parent
        width: 900
        height: 700
        modal: true

        background: Rectangle {
            color: "white"
            border.color: "#e0e0e0"
            border.width: 1
            radius: 8
        }

        // 标题栏
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 50
            color: "#f5f5f5"
            radius: 8

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 8
                color: parent.color
            }

            Label {
                anchors.centerIn: parent
                text: isChineseMode ? "IPR曲线图表" : "IPR Curve Chart"
                font.pixelSize: 16
                font.bold: true
            }

            Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                text: "✕"
                flat: true
                onClicked: chartPopup.close()
            }
        }

        // 内容区域
        contentItem: Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 60
                anchors.bottomMargin: 60
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                // 图表信息栏
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Material.dialogColor
                    radius: 4

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        spacing: 20

                        Text {
                            text: isChineseMode ? "数据点: " : "Data Points: "
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }

                        Text {
                            text: root.curveData ? root.curveData.length : "0"
                            font.pixelSize: 12
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Rectangle {
                            width: 1
                            height: 20
                            color: Material.dividerColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: isChineseMode ? "当前产量: " : "Current Production: "
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }

                        Text {
                            text: root.currentProduction.toFixed(3) + " bbl/d"
                            font.pixelSize: 12
                            font.bold: true
                            color: Material.accent
                        }
                    }
                }

                // 图表画布区域
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    border.color: "#e0e0e0"
                    radius: 4

                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        anchors.margins: 20

                        property real leftMargin: 80
                        property real bottomMargin: 60
                        property real rightMargin: 30
                        property real topMargin: 30

                        // 添加数据变化监听
                        Connections {
                            target: root
                            function onCurveDataChanged() {
                                canvas.requestPaint()
                            }
                            function onCurrentProductionChanged() {
                                canvas.requestPaint()
                            }
                        }

                        onPaint: {
                            console.log("=== IPR Canvas onPaint 开始 ===")
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            if (!root.curveData || root.curveData.length === 0) {
                                drawEmptyState(ctx)
                                return
                            }

                            console.log("绘制IPR曲线，数据点:", root.curveData.length)

                            // 绘制坐标轴和网格
                            drawAxes(ctx)

                            // 绘制IPR曲线
                            drawIPRCurve(ctx)

                            // 绘制工作点
                            drawWorkingPoint(ctx)

                            console.log("=== IPR Canvas onPaint 完成 ===")
                        }

                        function drawEmptyState(ctx) {
                            ctx.fillStyle = "#999"
                            ctx.font = "16px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                root.isChineseMode ? "无IPR曲线数据" : "No IPR curve data",
                                width / 2, height / 2
                            )
                        }

                        function drawAxes(ctx) {
                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            ctx.strokeStyle = "#333"
                            ctx.lineWidth = 2

                            // Y轴
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, topMargin)
                            ctx.lineTo(leftMargin, topMargin + chartHeight)
                            ctx.stroke()

                            // X轴
                            ctx.beginPath()
                            ctx.moveTo(leftMargin, topMargin + chartHeight)
                            ctx.lineTo(leftMargin + chartWidth, topMargin + chartHeight)
                            ctx.stroke()

                            // 网格线
                            ctx.strokeStyle = "#f0f0f0"
                            ctx.lineWidth = 1

                            // 水平网格线
                            for (var i = 1; i < 10; i++) {
                                var y = topMargin + (chartHeight * i / 10)
                                ctx.beginPath()
                                ctx.moveTo(leftMargin, y)
                                ctx.lineTo(leftMargin + chartWidth, y)
                                ctx.stroke()
                            }

                            // 垂直网格线
                            for (var j = 1; j < 10; j++) {
                                var x = leftMargin + (chartWidth * j / 10)
                                ctx.beginPath()
                                ctx.moveTo(x, topMargin)
                                ctx.lineTo(x, topMargin + chartHeight)
                                ctx.stroke()
                            }

                            // 绘制轴标签和刻度
                            drawAxisLabels(ctx, chartWidth, chartHeight)
                        }

                        function drawIPRCurve(ctx) {
                            if (!root.curveData || root.curveData.length < 2) return

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 计算数据范围
                            var maxProduction = root.getMaxProduction()
                            var maxPressure = root.getMaxPressure()

                            if (maxProduction <= 0 || maxPressure <= 0) return

                            // 绘制IPR曲线
                            ctx.strokeStyle = Material.accent
                            ctx.lineWidth = 3
                            ctx.beginPath()

                            for (var i = 0; i < root.curveData.length; i++) {
                                var point = root.curveData[i]
                                if (point && 
                                    typeof point.production === 'number' && 
                                    typeof point.pressure === 'number' &&
                                    !isNaN(point.production) && 
                                    !isNaN(point.pressure)) {

                                    var x = leftMargin + (point.production / maxProduction) * chartWidth
                                    var y = topMargin + chartHeight - (point.pressure / maxPressure) * chartHeight

                                    if (i === 0) {
                                        ctx.moveTo(x, y)
                                    } else {
                                        ctx.lineTo(x, y)
                                    }
                                }
                            }
                            ctx.stroke()

                            // 绘制数据点
                            ctx.fillStyle = Material.accent
                            for (var j = 0; j < root.curveData.length; j++) {
                                var pt = root.curveData[j]
                                if (pt && !isNaN(pt.production) && !isNaN(pt.pressure)) {
                                    var ptX = leftMargin + (pt.production / maxProduction) * chartWidth
                                    var ptY = topMargin + chartHeight - (pt.pressure / maxPressure) * chartHeight

                                    ctx.beginPath()
                                    ctx.arc(ptX, ptY, 2, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                            }
                        }

                        function drawWorkingPoint(ctx) {
                            if (root.currentProduction <= 0) return

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin
                            var maxProduction = root.getMaxProduction()
                            var maxPressure = root.getMaxPressure()

                            if (maxProduction <= 0 || maxPressure <= 0) return

                            var workingPressure = root.interpolatePressure(root.currentProduction)
                            if (workingPressure <= 0) return

                            var x = leftMargin + (root.currentProduction / maxProduction) * chartWidth
                            var y = topMargin + chartHeight - (workingPressure / maxPressure) * chartHeight

                            // 绘制参考线
                            ctx.strokeStyle = Material.color(Material.Orange)
                            ctx.lineWidth = 2
                            ctx.setLineDash([5, 5])
                            ctx.beginPath()
                            ctx.moveTo(x, topMargin + chartHeight)
                            ctx.lineTo(x, y)
                            ctx.stroke()
                            ctx.setLineDash([])

                            // 绘制工作点
                            ctx.fillStyle = Material.color(Material.Red)
                            ctx.strokeStyle = "white"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            ctx.arc(x, y, 6, 0, 2 * Math.PI)
                            ctx.fill()
                            ctx.stroke()

                            // 绘制工作点标签
                            ctx.fillStyle = Material.color(Material.Red)
                            ctx.font = "12px sans-serif"
                            ctx.textAlign = "left"
                            ctx.textBaseline = "bottom"
                            ctx.fillText(
                                "工作点: " + root.currentProduction.toFixed(3) + " bbl/d, " + workingPressure.toFixed(0) + " psi",
                                x + 10, y - 10
                            )
                        }

                        function drawAxisLabels(ctx, chartWidth, chartHeight) {
                            var maxProduction = root.getMaxProduction()
                            var maxPressure = root.getMaxPressure()

                            if (maxProduction <= 0 || maxPressure <= 0) return

                            ctx.fillStyle = "#333"
                            ctx.font = "14px sans-serif"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText(
                                root.isChineseMode ? "产量 (bbl/d)" : "Production Rate (bbl/d)",
                                leftMargin + chartWidth / 2, 
                                topMargin + chartHeight + 40
                            )

                            // Y轴标签
                            ctx.save()
                            ctx.translate(30, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                root.isChineseMode ? "井底流压 (psi)" : "Bottom Hole Pressure (psi)", 
                                0, 0
                            )
                            ctx.restore()

                            // 绘制刻度
                            ctx.font = "12px sans-serif"
                            ctx.fillStyle = "#666"

                            // X轴刻度
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            for (var i = 0; i <= 10; i++) {
                                var xVal = (maxProduction * i / 10)
                                var xPos = leftMargin + (chartWidth * i / 10)
                                ctx.fillText(xVal.toFixed(3), xPos, topMargin + chartHeight + 5)
                            }

                            // Y轴刻度
                            ctx.textAlign = "right"
                            ctx.textBaseline = "middle"
                            for (var j = 0; j <= 10; j++) {
                                var yVal = (maxPressure * j / 10)
                                var yPos = topMargin + chartHeight - (chartHeight * j / 10)
                                ctx.fillText(yVal.toFixed(0), leftMargin - 10, yPos)
                            }
                        }
                    }
                }

                // 图例和数据摘要
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: Material.dialogColor
                    radius: 4

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        spacing: 30

                        // 图例
                        Row {
                            spacing: 20

                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 20
                                    height: 3
                                    color: Material.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: isChineseMode ? "IPR曲线" : "IPR Curve"
                                    font.pixelSize: 12
                                    color: Material.primaryTextColor
                                }
                            }

                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: Material.color(Material.Red)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: isChineseMode ? "工作点" : "Working Point"
                                    font.pixelSize: 12
                                    color: Material.primaryTextColor
                                }
                            }
                        }

                        // 数据摘要
                        Column {
                            spacing: 4
                            Text {
                                text: isChineseMode ? "数据摘要" : "Data Summary"
                                font.pixelSize: 12
                                font.bold: true
                                color: Material.primaryTextColor
                            }
                            Text {
                                text: (isChineseMode ? "最大产量: " : "Max Production: ") + 
                                      root.getMaxProduction().toFixed(3) + " bbl/d"
                                font.pixelSize: 11
                                color: Material.secondaryTextColor
                            }
                            Text {
                                text: (isChineseMode ? "最大压力: " : "Max Pressure: ") + 
                                      root.getMaxPressure().toFixed(0) + " psi"
                                font.pixelSize: 11
                                color: Material.secondaryTextColor
                            }
                        }
                    }
                }
            }
        }

        // 底部按钮栏
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            color: "#f5f5f5"

            Row {
                anchors.centerIn: parent
                spacing: 20

                Button {
                    text: isChineseMode ? "导出图表" : "Export Chart"
                    onClicked: exportChart()
                }

                Button {
                    text: isChineseMode ? "关闭" : "Close"
                    onClicked: chartPopup.close()
                }
            }
        }
    }

    // 公开的接口函数
    function open() {
        chartPopup.open()
    }

    function close() {
        chartPopup.close()
    }

    function updateChart(data, production) {
        curveData = data
        currentProduction = production || 0
        // Canvas会通过Connections自动更新
    }

    function exportChart() {
        console.log("导出IPR曲线图表")
        // TODO: 实现图表导出功能
    }

    // 工具函数
    function getMaxProduction() {
        if (!curveData || curveData.length === 0) return 0.001

        var max = 0
        for (var i = 0; i < curveData.length; i++) {
            if (curveData[i] && 
                typeof curveData[i].production === 'number' && 
                !isNaN(curveData[i].production) &&
                curveData[i].production > max) {
                max = curveData[i].production
            }
        }
        return Math.max(max, 0.001)
    }

    function getMaxPressure() {
        if (!curveData || curveData.length === 0) return 100

        var max = 0
        for (var i = 0; i < curveData.length; i++) {
            if (curveData[i] && 
                typeof curveData[i].pressure === 'number' && 
                !isNaN(curveData[i].pressure) &&
                curveData[i].pressure > max) {
                max = curveData[i].pressure
            }
        }
        return Math.max(max, 100)
    }

    function interpolatePressure(production) {
        if (!curveData || curveData.length < 2) return 0

        try {
            for (var i = curveData.length - 2; i >= 0; i--) {
                var curr = curveData[i]
                var next = curveData[i + 1]

                if (curr && next && 
                    production >= curr.production && 
                    production <= next.production) {

                    var x1 = curr.production
                    var y1 = curr.pressure
                    var x2 = next.production
                    var y2 = next.pressure

                    if (x2 !== x1) {
                        return y1 + (production - x1) * (y2 - y1) / (x2 - x1)
                    }
                }
            }
        } catch (error) {
            console.error("插值计算出错:", error)
        }

        return 0
    }
}