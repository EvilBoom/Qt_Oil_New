import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Common/Utils/UnitUtils.js" as UnitUtils

Item {
    id: root

    property bool isChineseMode: true
    property var sketchData: null
    property real drawingScale: 1.0
    property var transformParams: ({})
    // 🔥 添加单位制属性
    property bool isMetric: false
    // 🔥 监听单位制变化
    onIsMetricChanged: {
        console.log("WellSchematicView单位制切换为:", isMetric ? "公制" : "英制")
        updateDisplayUnits()
    }

    // 工程图风格的颜色定义
    readonly property color wellLineColor: "#2196F3"
    readonly property color backgroundColor: "#FFFFFF"
    readonly property color gridColor: "#E8E8E8"
    readonly property color textColor: "#333333"
    readonly property color depthTextColor: "#666666"
    readonly property color wellheadColor: "#DC3545"

    signal sketchClicked(var position)

    Rectangle {
        anchors.fill: parent
        color: backgroundColor

        // 纯粹的绘图区域
        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 10

            onPaint: {
                drawWellSchematic()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) {
                    root.sketchClicked({x: mouse.x, y: mouse.y})
                }
            }
        }

        // 右上角标题块
        Rectangle {
            id: titleBlock
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 180
            height: 80
            color: "white"
            border.color: "#333333"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2

                Text {
                    text: isChineseMode ? "井身结构草图" : "Well Schematic"
                    font.pixelSize: 12
                    font.bold: true
                    color: textColor
                }

                Text {
                    text: isChineseMode ?
                        `深度: ${getDepthUnitText()}` :
                        `Depth: ${getDepthUnitText()}`
                    font.pixelSize: 9
                    color: depthTextColor
                }

                Text {
                    text: isChineseMode ?
                        `直径: ${getDiameterUnitText()}` :
                        `Diameter: ${getDiameterUnitText()}`
                    font.pixelSize: 9
                    color: depthTextColor
                }

                Text {
                    text: (isChineseMode ? "比例: " : "Scale: ") + (drawingScale * 100).toFixed(0) + "%"
                    font.pixelSize: 9
                    color: depthTextColor
                }

                Text {
                    text: new Date().toLocaleDateString()
                    font.pixelSize: 8
                    color: depthTextColor
                }
            }
        }
    }

    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatDepthValue(value, sourceUnit) {
        if (!value || value <= 0) return 0

        var convertedValue = value

        if (sourceUnit === "ft") {
            // 源数据是英尺
            if (isMetric) {
                convertedValue = UnitUtils.feetToMeters(value)
            } else {
                convertedValue = value
            }
        } else if (sourceUnit === "m") {
            // 源数据是米
            if (isMetric) {
                convertedValue = value
            } else {
                convertedValue = UnitUtils.metersToFeet(value)
            }
        }

        return convertedValue
    }

    function formatDiameterValue(value, sourceUnit) {
        if (!value || value <= 0) return 0

        var convertedValue = value

        if (sourceUnit === "in") {
            // 源数据是英寸
            if (isMetric) {
                convertedValue = UnitUtils.inchesToMm(value)
            } else {
                convertedValue = value
            }
        } else if (sourceUnit === "mm") {
            // 源数据是毫米
            if (isMetric) {
                convertedValue = value
            } else {
                convertedValue = UnitUtils.mmToInches(value)
            }
        }

        return convertedValue
    }

    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDiameterUnit() {
        return isMetric ? "mm" : "in"
    }

    function getDepthUnitText() {
        if (isChineseMode) {
            return isMetric ? "米(m)" : "英尺(ft)"
        } else {
            return isMetric ? "meters(m)" : "feet(ft)"
        }
    }

    function getDiameterUnitText() {
        if (isChineseMode) {
            return isMetric ? "毫米(mm)" : "英寸(in)"
        } else {
            return isMetric ? "millimeters(mm)" : "inches(in)"
        }
    }

    function updateDisplayUnits() {
        console.log("更新井身示意图显示单位")
        if (canvas) {
            canvas.requestPaint()
        }
    }

    // 公共方法
    function updateSketch(data) {
        sketchData = data
        canvas.requestPaint()
    }

    function setDrawingScale(scale) {
        drawingScale = Math.max(0.5, Math.min(3.0, scale))
        canvas.requestPaint()
    }

    function drawWellSchematic() {
        if (!canvas || !sketchData) return

        var ctx = canvas.getContext("2d")
        if (!ctx) return

        // 清空画布
        ctx.clearRect(0, 0, canvas.width, canvas.height)

        // 设置坐标系统
        setupCoordinateSystem(ctx)

        // 绘制深度标尺
        drawDepthScale(ctx)

        // 绘制井口
        drawWellhead(ctx)

        // 绘制井眼轴线
        drawWellAxis(ctx)

        // 绘制套管
        drawCasingsClean(ctx)

        // 绘制井底
        drawWellBottom(ctx)
    }

    function setupCoordinateSystem(ctx) {
        if (!sketchData || !sketchData.dimensions) return

        // 计算绘图参数
        var margin = 60
        var drawingWidth = canvas.width - 2 * margin
        var drawingHeight = canvas.height - 2 * margin

        // 🔥 获取深度数据并进行单位转换
        var maxDepthOriginal = sketchData.dimensions.max_depth || 10000
        var maxDepth = formatDepthValue(maxDepthOriginal, "ft")  // 假设原始数据是英尺

        var maxHorizontalOriginal = sketchData.dimensions.max_horizontal || 100
        var maxHorizontal = formatDiameterValue(maxHorizontalOriginal, "in")  // 假设原始数据是英寸

        // 计算缩放比例
        var verticalScale = drawingHeight / (maxDepth * 1.1) // 增加10%边距
        var horizontalScale = Math.min(drawingWidth / 400, 1.0) // 限制水平缩放

        // 应用用户设置的绘图比例
        verticalScale *= drawingScale

        // 保存转换参数到root级别属性
        root.transformParams = {
            margin: margin,
            verticalScale: verticalScale,
            horizontalScale: horizontalScale,
            maxDepth: maxDepth,
            maxDepthOriginal: maxDepthOriginal,  // 🔥 保存原始值用于计算
            maxHorizontal: maxHorizontal,
            centerX: canvas.width / 2
        }
    }

    function drawDepthScale(ctx) {
        if (!root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var maxDepth = params.maxDepth
        var stepSize = calculateDepthStep(maxDepth)

        ctx.strokeStyle = gridColor
        ctx.fillStyle = depthTextColor
        ctx.font = "10px Arial"
        ctx.lineWidth = 0.5
        ctx.textAlign = "right"

        // 绘制深度标尺
        for (var depth = 0; depth <= maxDepth; depth += stepSize) {
            var y = params.margin + (depth / maxDepth) * (canvas.height - 2 * params.margin)

            // 刻度线
            ctx.beginPath()
            ctx.moveTo(params.margin - 20, y)
            ctx.lineTo(params.margin - 10, y)
            ctx.stroke()

            // 🔥 深度标签 - 显示转换后的数值和单位
            var depthText = depth.toFixed(0) + " " + getDepthUnit()
            ctx.fillText(depthText, params.margin - 25, y + 3)
        }

        ctx.textAlign = "left" // 重置对齐方式
    }

    function drawWellhead(ctx) {
        if (!root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var wellheadY = params.margin
        var centerX = params.centerX

        // 绘制井口设备（红色多层结构）
        ctx.fillStyle = wellheadColor
        ctx.strokeStyle = "#B71C1C"
        ctx.lineWidth = 1

        // 井口法兰
        var flangeWidth = 80
        var flangeHeight = 12

        // 底层法兰
        ctx.fillRect(centerX - flangeWidth/2, wellheadY - 5, flangeWidth, flangeHeight)
        ctx.strokeRect(centerX - flangeWidth/2, wellheadY - 5, flangeWidth, flangeHeight)

        // 中层法兰
        ctx.fillRect(centerX - 60/2, wellheadY - 5 - flangeHeight, 60, flangeHeight)
        ctx.strokeRect(centerX - 60/2, wellheadY - 5 - flangeHeight, 60, flangeHeight)

        // 顶层法兰
        ctx.fillRect(centerX - 50/2, wellheadY - 5 - 2*flangeHeight, 50, flangeHeight)
        ctx.strokeRect(centerX - 50/2, wellheadY - 5 - 2*flangeHeight, 50, flangeHeight)

        // 井口标注
        ctx.fillStyle = textColor
        ctx.font = "10px Arial"
        ctx.fillText("Wellhead", centerX + 50, wellheadY - 10)
    }

    function drawWellAxis(ctx) {
        if (!root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams

        // 绘制井眼中心线
        ctx.strokeStyle = wellLineColor
        ctx.lineWidth = 2
        ctx.setLineDash([])

        ctx.beginPath()
        ctx.moveTo(params.centerX, params.margin)
        ctx.lineTo(params.centerX, canvas.height - params.margin)
        ctx.stroke()
    }

    function drawCasingsClean(ctx) {
        if (!sketchData || !sketchData.casings || !root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var maxDepth = params.maxDepth
        var centerX = params.centerX

        // 按外径从大到小排序
        var casings = sketchData.casings.slice().sort(function(a, b) {
            return b.outer_diameter - a.outer_diameter
        })

        // 🔥 计算最大套管外径用于比例计算，进行单位转换
        var maxCasingODOriginal = Math.max.apply(Math, casings.map(function(c) { return c.outer_diameter }))
        var maxCasingOD = formatDiameterValue(maxCasingODOriginal, "in")  // 假设原始数据是英寸

        for (var i = 0; i < casings.length; i++) {
            var casing = casings[i]

            // 🔥 计算套管在画布上的位置 - 深度转换
            var topDepthConverted = formatDepthValue(casing.top_depth, "ft")  // 假设原始数据是英尺
            var bottomDepthConverted = formatDepthValue(casing.bottom_depth, "ft")

            var topY = params.margin + (topDepthConverted / maxDepth) * (canvas.height - 2 * params.margin)
            var bottomY = params.margin + (bottomDepthConverted / maxDepth) * (canvas.height - 2 * params.margin)

            // 🔥 计算套管宽度 - 直径转换
            var outerDiameterConverted = formatDiameterValue(casing.outer_diameter, "in")
            var innerDiameterConverted = formatDiameterValue(casing.inner_diameter, "in")

            var baseWidth = 100 // 基础宽度
            var outerWidth = Math.min(baseWidth * (outerDiameterConverted / maxCasingOD), 60)
            var innerWidth = Math.min(baseWidth * (innerDiameterConverted / maxCasingOD), 55)

            // 确保最小宽度
            outerWidth = Math.max(outerWidth, 20)
            innerWidth = Math.max(innerWidth, 15)
            if (innerWidth >= outerWidth) innerWidth = outerWidth - 3

            var wallThickness = (outerWidth - innerWidth) / 2

            // 绘制套管壁
            ctx.fillStyle = getCasingColor(casing.type)
            ctx.strokeStyle = getCasingBorderColor(casing.type)
            ctx.lineWidth = 1

            // 左侧套管壁
            ctx.fillRect(centerX - outerWidth/2, topY, wallThickness, bottomY - topY)
            ctx.strokeRect(centerX - outerWidth/2, topY, wallThickness, bottomY - topY)

            // 右侧套管壁
            ctx.fillRect(centerX + innerWidth/2, topY, wallThickness, bottomY - topY)
            ctx.strokeRect(centerX + innerWidth/2, topY, wallThickness, bottomY - topY)

            // 绘制套管鞋（除了导管）
            if (casing.type !== "conductor") {
                drawCasingShoe(ctx, centerX, bottomY, outerWidth)
            }

            // 🔥 修改：在套管中间位置绘制标注，显示转换后的尺寸
            var midY = topY + (bottomY - topY) / 2
            drawCasingLabelAtCenter(ctx, casing, centerX, midY, outerWidth)
        }
    }

    function drawCasingShoe(ctx, centerX, bottomY, width) {
        ctx.fillStyle = "#666666"
        ctx.strokeStyle = "#333333"
        ctx.lineWidth = 1

        // 绘制套管鞋的V形底部
        ctx.beginPath()
        ctx.moveTo(centerX - width/2, bottomY)
        ctx.lineTo(centerX, bottomY + 8)
        ctx.lineTo(centerX + width/2, bottomY)
        ctx.closePath()
        ctx.fill()
        ctx.stroke()
    }

    // 🔥 修改套管标签，显示转换后的尺寸
    function drawCasingLabelAtCenter(ctx, casing, centerX, midY, casingWidth) {
        var typeName = getCasingTypeName(casing.type)

        // 🔥 显示转换后的套管尺寸
        var outerDiameterConverted = formatDiameterValue(casing.outer_diameter, "in")
        var sizeText = outerDiameterConverted.toFixed(isMetric ? 0 : 1) + getDiameterUnit()

        // 计算标签位置（在套管右侧，避免重叠）
        var labelX = centerX + casingWidth/2 + 15
        var labelY = midY

        // 标签背景
        ctx.fillStyle = "rgba(255, 255, 255, 0.95)"
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 1

        ctx.font = "10px Arial"
        var maxTextWidth = Math.max(
            ctx.measureText(typeName).width,
            ctx.measureText(sizeText).width
        )
        var labelWidth = maxTextWidth + 8
        var labelHeight = 22

        // 绘制标签框
        ctx.fillRect(labelX, labelY - labelHeight/2, labelWidth, labelHeight)
        ctx.strokeRect(labelX, labelY - labelHeight/2, labelWidth, labelHeight)

        // 连接线（从套管到标签）
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 0.8
        ctx.setLineDash([2, 2])
        ctx.beginPath()
        ctx.moveTo(centerX + casingWidth/2, labelY)
        ctx.lineTo(labelX, labelY)
        ctx.stroke()
        ctx.setLineDash([])

        // 标签文本
        ctx.fillStyle = textColor
        ctx.font = "9px Arial"
        ctx.fillText(typeName, labelX + 4, labelY - 3)
        ctx.font = "8px Arial"
        ctx.fillText(sizeText, labelX + 4, labelY + 7)
    }

    // 🔥 修改井底绘制，显示转换后的深度
    function drawWellBottom(ctx) {
        if (!sketchData || !sketchData.dimensions || !root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var bottomY = canvas.height - params.margin
        var centerX = params.centerX

        // 绘制井底标记
        ctx.fillStyle = "#4CAF50"
        ctx.strokeStyle = "#2E7D32"
        ctx.lineWidth = 2

        ctx.beginPath()
        ctx.arc(centerX, bottomY, 6, 0, 2 * Math.PI)
        ctx.fill()
        ctx.stroke()

        // 🔥 井底深度标注 - 显示转换后的深度和单位
        ctx.fillStyle = textColor
        ctx.font = "10px Arial"

        var maxDepthConverted = formatDepthValue(sketchData.dimensions.max_depth, "ft")
        var maxTVDConverted = formatDepthValue(sketchData.dimensions.max_depth, "ft")  // 如果有TVD数据，应该使用真实TVD

        var depthText = `TD @ ${maxDepthConverted.toFixed(0)} ${getDepthUnit()} MD / ${maxTVDConverted.toFixed(0)} ${getDepthUnit()} TVD`
        ctx.fillText(depthText, centerX + 15, bottomY + 5)

        // 井斜角标注
        ctx.font = "9px Arial"
        var inclinationText = isChineseMode ? "井斜角 6.3°" : "6.3° Inclination"
        ctx.fillText(inclinationText, centerX + 15, bottomY + 18)
    }

    // 🔥 修改深度步长计算，适应不同单位制
    function calculateDepthStep(maxDepth) {
        if (isMetric) {
            // 公制步长
            if (maxDepth <= 300) return 30      // 30m
            if (maxDepth <= 1500) return 150    // 150m
            if (maxDepth <= 3000) return 300    // 300m
            return 600                          // 600m
        } else {
            // 英制步长
            if (maxDepth <= 1000) return 100    // 100ft
            if (maxDepth <= 5000) return 500    // 500ft
            if (maxDepth <= 10000) return 1000  // 1000ft
            return 2000                         // 2000ft
        }
    }

    function getCasingColor(type) {
        var colors = {
            "conductor": "#795548",    // 棕色
            "surface": "#4CAF50",      // 绿色
            "intermediate": "#2196F3", // 蓝色
            "production": "#FF9800"    // 橙色
        }
        return colors[type] || "#9E9E9E"
    }

    function getCasingBorderColor(type) {
        var colors = {
            "conductor": "#5D4037",
            "surface": "#2E7D32",
            "intermediate": "#1565C0",
            "production": "#E65100"
        }
        return colors[type] || "#616161"
    }

    function getCasingTypeName(type) {
        if (isChineseMode) {
            var names = {
                "conductor": "导管",
                "surface": "表层套管",
                "intermediate": "技术套管",
                "production": "生产套管"
            }
            return names[type] || "套管"
        } else {
            var names = {
                "conductor": "Conductor",
                "surface": "Surface",
                "intermediate": "Intermediate",
                "production": "Production"
            }
            return names[type] || "Casing"
        }
    }

    // 当数据更新时重新绘制
    onSketchDataChanged: {
        if (canvas) {
            canvas.requestPaint()
        }
    }

    onDrawingScaleChanged: {
        if (canvas) {
            canvas.requestPaint()
        }
    }
}
