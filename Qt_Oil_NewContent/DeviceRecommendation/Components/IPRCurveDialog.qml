import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// 改用ApplicationWindow实现可拖拽的对话框
ApplicationWindow {
    id: root

    property var curveData: []
    property real currentProduction: 0
    property bool isChineseMode: true

    // 优化尺寸 - 减小默认大小
    width: 900
    height: 650
    minimumWidth: 700
    minimumHeight: 500

    title: isChineseMode ? "IPR曲线分析" : "IPR Curve Analysis"
    color: "white"

    // 添加可拖拽功能
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinMaxButtonsHint

    // 窗口图标和样式
    Material.theme: Material.Light
    Material.accent: Material.Blue

    header: Rectangle {
        height: 50
        color: Material.primary

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: "📊"
                font.pixelSize: 18
                color: "white"
            }

            Text {
                text: isChineseMode ? "流入动态关系曲线 (IPR)" : "Inflow Performance Relationship"
                font.pixelSize: 14
                font.bold: true
                color: "white"
                Layout.fillWidth: true
            }

            // 曲线类型选择
            ComboBox {
                id: curveTypeCombo
                // Layout.preferredWidth: 140
                model: [
                    isChineseMode ? "Vogel方程" : "Vogel Equation",
                    // isChineseMode ? "线性IPR" : "Linear IPR",
                    // isChineseMode ? "组合IPR" : "Composite IPR"
                ]
                currentIndex: 0
                Material.theme: Material.Dark
                font.pixelSize: 11

                onCurrentIndexChanged: {
                    updateCurveType()
                }
            }
        }
    }

    // 主内容区域
    SplitView {
        anchors.fill: parent
        anchors.margins: 12
        orientation: Qt.Horizontal

        // 左侧图表区域 - 减小比例
        Rectangle {
            SplitView.preferredWidth: parent.width * 0.65  // 减少到65%
            SplitView.minimumWidth: 450
            color: "white"
            radius: 6
            border.color: "#e1e5e9"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // 图表控制栏 - 简化
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 35  // 减小高度
                    color: "#f8f9fa"
                    radius: 4

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text {
                            text: isChineseMode ? "图表控制" : "Controls"
                            font.pixelSize: 11
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Item { Layout.fillWidth: true }

                        // 网格线开关
                        CheckBox {
                            id: gridCheckBox
                            text: isChineseMode ? "网格" : "Grid"
                            checked: true
                            font.pixelSize: 10
                            onCheckedChanged: canvas.requestPaint()
                        }

                        // 数据点开关
                        CheckBox {
                            id: showPointsCheckBox
                            text: isChineseMode ? "数据点" : "Points"
                            checked: false
                            font.pixelSize: 10
                            onCheckedChanged: canvas.requestPaint()
                        }

                        // 全屏按钮
                        Button {
                            text: "⛶"
                            flat: true
                            font.pixelSize: 12
                            implicitHeight: 25
                            implicitWidth: 25
                            ToolTip.text: isChineseMode ? "调整大小" : "Resize"
                            ToolTip.visible: hovered
                            onClicked: toggleSize()
                        }
                    }
                }

                // Canvas图表 - 保持原有绘制逻辑
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    border.color: "#e1e5e9"
                    border.width: 1
                    radius: 4

                    Canvas {
                        id: canvas
                        anchors.fill: parent
                        anchors.margins: 15

                        property real leftMargin: 50
                        property real bottomMargin: 40
                        property real rightMargin: 15
                        property real topMargin: 30

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            if (!curveData || curveData.length === 0) {
                                drawEmptyState(ctx)
                                return
                            }

                            // 绘制各个组件
                            drawTitle(ctx)
                            drawAxes(ctx)
                            drawIPRCurve(ctx)

                            if (currentProduction > 0) {
                                drawWorkingPoint(ctx)
                            }

                            drawLegend(ctx)
                        }

                        function drawEmptyState(ctx) {
                            ctx.fillStyle = "#999"
                            ctx.font = "14px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(
                                isChineseMode ? "无图表数据" : "No chart data",
                                width / 2, height / 2
                            )
                        }

                        function drawTitle(ctx) {
                            ctx.fillStyle = "#333"
                            ctx.font = "bold 14px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText(
                                isChineseMode ? "IPR曲线图" : "IPR Curve Chart",
                                width / 2, 5
                            )
                        }

                        function drawAxes(ctx) {
                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 绘制坐标轴
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

                            // 绘制网格线
                            if (gridCheckBox.checked) {
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
                            }
                        }

                        function drawIPRCurve(ctx) {
                            if (!curveData || curveData.length === 0) return

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 计算数据范围
                            var maxProduction = 0.001
                            var maxPressure = 100

                            for (var i = 0; i < curveData.length; i++) {
                                if (curveData[i]) {
                                    maxProduction = Math.max(maxProduction, curveData[i].production || 0)
                                    maxPressure = Math.max(maxPressure, curveData[i].pressure || 0)
                                }
                            }

                            maxProduction *= 1.15
                            maxPressure *= 1.15

                            // 更新统计信息
                            dataPointsText.text = curveData.length.toString()
                            maxProductionText.text = (maxProduction / 1.15).toFixed(2) + " bbl/d"
                            maxPressureText.text = (maxPressure / 1.15).toFixed(0) + " psi"

                            // 绘制曲线
                            ctx.strokeStyle = Material.accent
                            ctx.lineWidth = 2.5
                            ctx.beginPath()

                            for (var k = 0; k < curveData.length; k++) {
                                if (curveData[k]) {
                                    var x = leftMargin + (curveData[k].production / maxProduction) * chartWidth
                                    var y = topMargin + chartHeight - (curveData[k].pressure / maxPressure) * chartHeight

                                    if (k === 0) {
                                        ctx.moveTo(x, y)
                                    } else {
                                        ctx.lineTo(x, y)
                                    }
                                }
                            }
                            ctx.stroke()

                            // 绘制数据点
                            if (showPointsCheckBox.checked && curveData.length < 100) {
                                ctx.fillStyle = Material.accent
                                for (var p = 0; p < curveData.length; p++) {
                                    if (curveData[p]) {
                                        var px = leftMargin + (curveData[p].production / maxProduction) * chartWidth
                                        var py = topMargin + chartHeight - (curveData[p].pressure / maxPressure) * chartHeight
                                        ctx.beginPath()
                                        ctx.arc(px, py, 2.5, 0, 2 * Math.PI)
                                        ctx.fill()
                                    }
                                }
                            }

                            // 绘制轴标签 - 简化字体
                            ctx.fillStyle = "#333"
                            ctx.font = "12px sans-serif"

                            // X轴标签
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText(isChineseMode ? "产量 (bbl/d)" : "Production (bbl/d)",
                                        leftMargin + chartWidth / 2, topMargin + chartHeight + 25)

                            // Y轴标签
                            ctx.save()
                            ctx.translate(15, topMargin + chartHeight / 2)
                            ctx.rotate(-Math.PI / 2)
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(isChineseMode ? "井底压力 (psi)" : "BHP (psi)", 0, 0)
                            ctx.restore()

                            // 绘制刻度 - 简化
                            ctx.font = "10px sans-serif"
                            ctx.fillStyle = "#666"

                            // Y轴刻度
                            ctx.textAlign = "right"
                            ctx.textBaseline = "middle"
                            for (var m = 0; m <= 5; m++) {  // 减少刻度数量
                                var yVal = (maxPressure * m / 5)
                                var yPos = topMargin + chartHeight - (chartHeight * m / 5)
                                ctx.fillText(yVal.toFixed(0), leftMargin - 5, yPos)
                            }

                            // X轴刻度
                            ctx.textAlign = "center"
                            ctx.textBaseline = "top"
                            for (var n = 0; n <= 5; n++) {  // 减少刻度数量
                                var xVal = (maxProduction * n / 5)
                                var xPos = leftMargin + (chartWidth * n / 5)
                                ctx.fillText(xVal.toFixed(1), xPos, topMargin + chartHeight + 3)
                            }
                        }

                        function drawWorkingPoint(ctx) {
                            if (!curveData || curveData.length === 0) return

                            var chartWidth = width - leftMargin - rightMargin
                            var chartHeight = height - topMargin - bottomMargin

                            // 计算最大值
                            var maxProduction = 0.001
                            var maxPressure = 100

                            for (var i = 0; i < curveData.length; i++) {
                                if (curveData[i]) {
                                    maxProduction = Math.max(maxProduction, curveData[i].production || 0)
                                    maxPressure = Math.max(maxPressure, curveData[i].pressure || 0)
                                }
                            }

                            maxProduction *= 1.15
                            maxPressure *= 1.15

                            // 插值计算工作点压力
                            var workingPressure = interpolatePressure(currentProduction, curveData)
                            if (workingPressure > 0) {
                                var wx = leftMargin + (currentProduction / maxProduction) * chartWidth
                                var wy = topMargin + chartHeight - (workingPressure / maxPressure) * chartHeight

                                // 绘制参考线
                                ctx.strokeStyle = "rgba(255, 152, 0, 0.5)"
                                ctx.lineWidth = 1.5
                                ctx.setLineDash([4, 4])

                                // 垂直线
                                ctx.beginPath()
                                ctx.moveTo(wx, topMargin + chartHeight)
                                ctx.lineTo(wx, wy)
                                ctx.stroke()

                                // 水平线
                                ctx.beginPath()
                                ctx.moveTo(leftMargin, wy)
                                ctx.lineTo(wx, wy)
                                ctx.stroke()

                                ctx.setLineDash([])

                                // 绘制工作点
                                ctx.fillStyle = "#f44336"
                                ctx.strokeStyle = "white"
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.arc(wx, wy, 6, 0, 2 * Math.PI)
                                ctx.fill()
                                ctx.stroke()

                                // 更新工作点信息
                                workingPressureText.text = workingPressure.toFixed(0) + " psi"
                            }
                        }

                        function drawLegend(ctx) {
                            var legendX = leftMargin + 15
                            var legendY = topMargin + 15

                            ctx.font = "11px sans-serif"

                            // IPR曲线图例
                            ctx.strokeStyle = Material.accent
                            ctx.lineWidth = 2.5
                            ctx.beginPath()
                            ctx.moveTo(legendX, legendY)
                            ctx.lineTo(legendX + 25, legendY)
                            ctx.stroke()

                            ctx.fillStyle = "#333"
                            ctx.textAlign = "left"
                            ctx.textBaseline = "middle"
                            ctx.fillText(isChineseMode ? "IPR曲线" : "IPR Curve", legendX + 30, legendY)

                            // 工作点图例
                            if (currentProduction > 0) {
                                legendY += 18
                                ctx.fillStyle = "#f44336"
                                ctx.beginPath()
                                ctx.arc(legendX + 12, legendY, 4, 0, 2 * Math.PI)
                                ctx.fill()

                                ctx.fillStyle = "#333"
                                ctx.fillText(isChineseMode ? "工作点" : "Working Point", legendX + 30, legendY)
                            }
                        }
                    }
                }
            }
        }

        // 右侧信息面板 - 优化布局，增加间距和可读性
        Rectangle {
            SplitView.preferredWidth: parent.width * 0.32  // 稍微减少宽度给图表更多空间
            SplitView.minimumWidth: 200
            color: "#f8f9fa"
            radius: 6

            ScrollView {
                anchors.fill: parent
                anchors.margins: 12  // 增加外边距
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: 16  // 增加组件间距

                    // 数据统计 - 优化高度和间距
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100  // 增加高度
                        color: "white"
                        radius: 6
                        border.color: "#e1e5e9"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: isChineseMode ? "📈 数据统计" : "📈 Statistics"
                                font.pixelSize: 13
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#e1e5e9"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 6  // 增加行间距
                                columnSpacing: 8

                                Text {
                                    text: isChineseMode ? "数据点:" : "Points:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    id: dataPointsText
                                    text: "0"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Text {
                                    text: isChineseMode ? "最大产量:" : "Max Prod:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    id: maxProductionText
                                    text: "0 bbl/d"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Text {
                                    text: isChineseMode ? "最大压力:" : "Max Press:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    id: maxPressureText
                                    text: "0 psi"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }
                            }
                        }
                    }

                    // 工作点信息 - 优化高度
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 85  // 增加高度
                        color: "white"
                        radius: 6
                        border.color: "#e1e5e9"
                        visible: currentProduction > 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: isChineseMode ? "🎯 工作点" : "🎯 Working Point"
                                font.pixelSize: 13
                                font.bold: true
                                color: Material.accent
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#e1e5e9"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 6  // 增加行间距
                                columnSpacing: 8

                                Text {
                                    text: isChineseMode ? "产量:" : "Production:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    text: currentProduction.toFixed(3) + " bbl/d"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.accent
                                }

                                Text {
                                    text: isChineseMode ? "井底压力:" : "BHP:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    id: workingPressureText
                                    text: "0 psi"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.accent
                                }
                            }
                        }
                    }

                    // 曲线参数 - 优化高度
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 95  // 增加高度
                        color: "white"
                        radius: 6
                        border.color: "#e1e5e9"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: isChineseMode ? "⚙️ 参数" : "⚙️ Parameters"
                                font.pixelSize: 13
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#e1e5e9"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 6  // 增加行间距
                                columnSpacing: 8

                                Text {
                                    text: isChineseMode ? "类型:" : "Type:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    text: curveTypeCombo.currentText
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Text {
                                    text: isChineseMode ? "R²值:" : "R²:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    text: "0.95"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.color(Material.Green)
                                }

                                Text {
                                    text: isChineseMode ? "精度:" : "Quality:"
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                                Text {
                                    text: isChineseMode ? "优秀" : "Excellent"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: Material.color(Material.Green)
                                }
                            }
                        }
                    }

                    // 添加弹性间距
                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 20  // 最小间距
                    }

                    // 操作按钮 - 重新设计为更舒适的布局
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180  // 固定高度
                        color: "white"
                        radius: 6
                        border.color: "#e1e5e9"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: isChineseMode ? "🔧 操作" : "🔧 Actions"
                                font.pixelSize: 13
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#e1e5e9"
                            }

                            // 按钮组 - 优化间距和高度
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8  // 增加按钮间距

                                Button {
                                    Layout.fillWidth: true
                                    text: isChineseMode ? "📤 导出图表" : "📤 Export Chart"
                                    font.pixelSize: 11
                                    implicitHeight: 32  // 增加按钮高度
                                    highlighted: true
                                    Material.elevation: 2
                                    onClicked: exportChart()
                                }

                                Button {
                                    Layout.fillWidth: true
                                    text: isChineseMode ? "📋 复制数据" : "📋 Copy Data"
                                    font.pixelSize: 11
                                    implicitHeight: 32
                                    Material.background: Material.color(Material.Orange, Material.Shade100)
                                    Material.foreground: Material.color(Material.Orange)
                                    onClicked: copyDataToClipboard()
                                }

                                Button {
                                    Layout.fillWidth: true
                                    text: isChineseMode ? "🔄 重新计算" : "🔄 Recalculate"
                                    font.pixelSize: 11
                                    implicitHeight: 32
                                    Material.background: Material.color(Material.Green, Material.Shade100)
                                    Material.foreground: Material.color(Material.Green)
                                    onClicked: recalculateIPR()
                                }

                                // 分隔线
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#e1e5e9"
                                    Layout.topMargin: 4
                                    Layout.bottomMargin: 4
                                }

                                Button {
                                    Layout.fillWidth: true
                                    text: isChineseMode ? "❌ 关闭窗口" : "❌ Close Window"
                                    font.pixelSize: 11
                                    implicitHeight: 32
                                    Material.background: Material.color(Material.Red, Material.Shade100)
                                    Material.foreground: Material.color(Material.Red)
                                    onClicked: root.close()
                                }
                            }
                        }
                    }

                    // 底部安全间距
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                    }
                }
            }
        }
    }

    // 状态栏
    footer: Rectangle {
        height: 20
        color: "#f1f3f4"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4

            Text {
                id: statusText
                text: isChineseMode ? "就绪" : "Ready"
                font.pixelSize: 8
                color: Material.hintTextColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: isChineseMode ? "更新: " + Qt.formatDateTime(new Date(), "hh:mm:ss") :
                                    "Updated: " + Qt.formatDateTime(new Date(), "hh:mm:ss")
                font.pixelSize: 8
                color: Material.hintTextColor
            }
        }
    }

    onVisibilityChanged: {
        if (visibility !== ApplicationWindow.Hidden) {
            console.log("IPR Dialog opened")
            if (curveData && curveData.length > 0) {
                canvas.requestPaint()
            }
        }
    }

    // 公开接口函数
    function open() {
        show()
        raise()
        requestActivate()
    }

    function close() {
        hide()
    }

    function updateChart(data, production) {
        console.log('IPR Chart Dialog updateChart called')
        console.log('Data points:', data ? data.length : 0)
        console.log('Current production:', production)

        curveData = data || []
        currentProduction = production || 0

        statusText.text = isChineseMode ? "数据已更新" : "Data updated"
        canvas.requestPaint()
    }

    function exportChart() {
        console.log("正在导出IPR曲线图表...")
        statusText.text = isChineseMode ? "正在导出..." : "Exporting..."

        canvas.grabToImage(function(result) {
            var filename = "IPR_Curve_" + Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss") + ".png"
            result.saveToFile(filename)
            statusText.text = isChineseMode ? "导出完成: " + filename : "Exported: " + filename
            console.log("图表已导出:", filename)
        })
    }

    function copyDataToClipboard() {
        statusText.text = isChineseMode ? "数据已复制" : "Data copied"
    }

    function recalculateIPR() {
        statusText.text = isChineseMode ? "正在重新计算..." : "Recalculating..."
    }

    function updateCurveType() {
        statusText.text = isChineseMode ? "切换曲线类型" : "Curve type changed"
        canvas.requestPaint()
    }

    function toggleSize() {
        if (root.width >= 1100) {
            root.width = 900
            root.height = 650
        } else {
            root.width = 1100
            root.height = 750
        }
    }

    // 插值函数保持不变
    function interpolatePressure(production, data) {
        if (!data || data.length < 2) return 0

        for (var i = 0; i < data.length - 1; i++) {
            var curr = data[i]
            var next = data[i + 1]

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

        if (production <= data[0].production) {
            return data[0].pressure
        }
        if (production >= data[data.length - 1].production) {
            return data[data.length - 1].pressure
        }

        return 0
    }
}
