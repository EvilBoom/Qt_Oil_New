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
                        `深度: ${getDepthUnitText()} (MD)` :
                        `Depth: ${getDepthUnitText()} (MD)`
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

        // 🔥 修改：使用测深(MD)而不是垂深进行绘制
        var maxMDOriginal = sketchData.dimensions.max_md || sketchData.dimensions.max_depth || 10000
        var maxMD = formatDepthValue(maxMDOriginal, "ft")  // 假设原始数据是英尺
        // console.log(JSON.stringify(sketchData))

        var maxHorizontalOriginal = sketchData.dimensions.max_horizontal || 100
        var maxHorizontal = formatDiameterValue(maxHorizontalOriginal, "in")  // 假设原始数据是英寸

        // 计算缩放比例
        var verticalScale = drawingHeight / (maxMD * 1.1) // 增加10%边距
        var horizontalScale = Math.min(drawingWidth / 400, 1.0) // 限制水平缩放

        // 应用用户设置的绘图比例
        verticalScale *= drawingScale

        // 保存转换参数到root级别属性
        root.transformParams = {
            margin: margin,
            verticalScale: verticalScale,
            horizontalScale: horizontalScale,
            maxMD: maxMD,  // 🔥 修改：使用测深
            maxMDOriginal: maxMDOriginal,  // 🔥 保存原始值用于计算
            maxHorizontal: maxHorizontal,
            centerX: canvas.width / 2
        }
    }

    function drawDepthScale(ctx) {
        if (!root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var maxMD = params.maxMD  // 🔥 修改：使用测深
        var stepSize = calculateDepthStep(maxMD)

        ctx.strokeStyle = gridColor
        ctx.fillStyle = depthTextColor
        ctx.font = "10px Arial"
        ctx.lineWidth = 0.5
        ctx.textAlign = "right"

        // 绘制深度标尺
        for (var depth = 0; depth <= maxMD; depth += stepSize) {
            var y = params.margin + (depth / maxMD) * (canvas.height - 2 * params.margin)

            // 刻度线
            ctx.beginPath()
            ctx.moveTo(params.margin - 20, y)
            ctx.lineTo(params.margin - 10, y)
            ctx.stroke()

            // 🔥 深度标签 - 显示测深(MD)和单位
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
        var wellheadText = isChineseMode ? "井口" : "Wellhead"
        ctx.fillText(wellheadText, centerX + 50, wellheadY - 10)
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

    // 🔥 重要修改：套管绘制逻辑优化
    function drawCasingsClean(ctx) {
        if (!sketchData || !sketchData.casings || !root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var maxMD = params.maxMD  // 🔥 修改：使用测深
        var centerX = params.centerX

        // 按外径从大到小排序
        var casings = sketchData.casings.slice().sort(function(a, b) {
            return b.outer_diameter - a.outer_diameter
        })

        // 🔥 重要改进：计算套管直径比例，增强视觉差异
        var maxCasingODOriginal = Math.max.apply(Math, casings.map(function(c) { return c.outer_diameter }))
        var minCasingODOriginal = Math.min.apply(Math, casings.map(function(c) { return c.outer_diameter }))
        
        var maxCasingOD = formatDiameterValue(maxCasingODOriginal, "in")
        var minCasingOD = formatDiameterValue(minCasingODOriginal, "in")

        // 🔥 增强直径差异显示 - 使用非线性缩放
        var diameterRange = maxCasingOD - minCasingOD
        var baseWidth = 120  // 🔥 增加基础宽度
        var maxDisplayWidth = 80  // 🔥 增加最大显示宽度
        var minDisplayWidth = 30  // 🔥 设置最小显示宽度

        for (var i = 0; i < casings.length; i++) {
            var casing = casings[i]

            // 🔥 修改：使用测深计算位置，支持轨迹数据
            var topMD, bottomMD
            
            if (casing.top_md !== undefined && casing.bottom_md !== undefined) {
                // 如果有测深数据，直接使用
                topMD = formatDepthValue(casing.top_md, "ft")
                bottomMD = formatDepthValue(casing.bottom_md, "ft")
            } else {
                // 如果没有测深数据，使用垂深作为近似值
                topMD = formatDepthValue(casing.top_depth, "ft")
                bottomMD = formatDepthValue(casing.bottom_depth, "ft")
            }

            var topY = params.margin + (topMD / maxMD) * (canvas.height - 2 * params.margin)
            var bottomY = params.margin + (bottomMD / maxMD) * (canvas.height - 2 * params.margin)

            // 🔥 改进的套管宽度计算 - 非线性缩放增强差异
            var outerDiameterConverted = formatDiameterValue(casing.outer_diameter, "in")
            var innerDiameterConverted = formatDiameterValue(casing.inner_diameter, "in")
            
            // 🔥 使用指数函数增强直径差异
            var normalizedOD = (outerDiameterConverted - minCasingOD) / (diameterRange || 1)
            var normalizedID = (innerDiameterConverted - minCasingOD) / (diameterRange || 1)
            
            // 🔥 应用指数缩放增强视觉差异
            var scaleFactor = 1.5  // 指数因子，可调整
            var scaledOD = Math.pow(normalizedOD, 1/scaleFactor)
            var scaledID = Math.pow(normalizedID, 1/scaleFactor)
            
            var outerWidth = minDisplayWidth + (maxDisplayWidth - minDisplayWidth) * scaledOD
            var innerWidth = minDisplayWidth + (maxDisplayWidth - minDisplayWidth) * scaledID
            
            // 确保最小差值
            if (outerWidth - innerWidth < 8) {
                innerWidth = outerWidth - 8
            }
            if (innerWidth < 15) innerWidth = 15

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

            // 🔥 重要修改：将套管信息显示在右下方，传递bottomMD参数
            drawCasingLabelAtBottomRight(ctx, casing, centerX, bottomY, outerWidth, i, bottomMD)
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

    // 🔥 修复：在函数参数中添加bottomMD参数
    function drawCasingLabelAtBottomRight(ctx, casing, centerX, bottomY, casingWidth, casingIndex, bottomMD) {
        var typeName = getCasingTypeName(casing.type)

        // 🔥 显示转换后的套管尺寸
        var outerDiameterConverted = formatDiameterValue(casing.outer_diameter, "in")
        var innerDiameterConverted = formatDiameterValue(casing.inner_diameter, "in")
        
        // 🔥 格式化尺寸文本，显示外径x壁厚格式
        var wallThickness = (outerDiameterConverted - innerDiameterConverted) / 2
        var sizeText = outerDiameterConverted.toFixed(isMetric ? 0 : 1) + "×" + 
                      wallThickness.toFixed(isMetric ? 0 : 1) + getDiameterUnit()

        // 🔥 计算标签位置 - 位于套管右下方
        var labelOffsetX = casingWidth/2 + 20 + (casingIndex * 10)  // 🔥 错开标签避免重叠
        var labelOffsetY = 15 + (casingIndex * 25)  // 🔥 垂直错开
        
        var labelX = centerX + labelOffsetX
        var labelY = bottomY + labelOffsetY

        // 🔥 确保标签不超出画布边界
        var maxX = canvas.width - 150
        var maxY = canvas.height - 50
        if (labelX > maxX) labelX = maxX
        if (labelY > maxY) labelY = maxY - (casingIndex * 25)

        // 🔥 绘制引线（从套管底部右侧到标签）
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 1
        ctx.setLineDash([3, 3])
        
        var connectionX = centerX + casingWidth/2
        var connectionY = bottomY
        
        ctx.beginPath()
        ctx.moveTo(connectionX, connectionY)
        ctx.lineTo(connectionX + 10, connectionY + 5)  // 第一段
        ctx.lineTo(labelX - 5, labelY - 10)  // 第二段
        ctx.stroke()
        ctx.setLineDash([])

        // 🔥 绘制标签背景框
        ctx.font = "9px Arial"
        var typeTextWidth = ctx.measureText(typeName).width
        var sizeTextWidth = ctx.measureText(sizeText).width
        var maxTextWidth = Math.max(typeTextWidth, sizeTextWidth)
        
        var labelWidth = maxTextWidth + 12
        var labelHeight = 28

        // 背景框
        ctx.fillStyle = "rgba(255, 255, 255, 0.95)"
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 1
        ctx.fillRect(labelX, labelY - labelHeight, labelWidth, labelHeight)
        ctx.strokeRect(labelX, labelY - labelHeight, labelWidth, labelHeight)

        // 🔥 在背景框左侧添加颜色条
        ctx.fillStyle = getCasingColor(casing.type)
        ctx.fillRect(labelX, labelY - labelHeight, 4, labelHeight)

        // 🔥 绘制标签文本
        ctx.fillStyle = textColor
        ctx.textAlign = "left"
        ctx.textBaseline = "top"
        
        // 套管类型
        ctx.font = "bold 9px Arial"
        ctx.fillText(typeName, labelX + 8, labelY - labelHeight + 4)
        
        // 尺寸信息
        ctx.font = "8px Arial"
        ctx.fillText(sizeText, labelX + 8, labelY - labelHeight + 16)

        // 🔥 修复：现在bottomMD参数已正确传递
        var depthText = bottomMD.toFixed(0) + getDepthUnit()
        ctx.font = "7px Arial"
        ctx.fillStyle = "#666"
        ctx.fillText(depthText, labelX + 8, labelY - 6)
    }

    // 🔥 修改井底绘制，使用测深显示
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

        // 🔥 井底深度标注 - 显示测深和垂深
        ctx.fillStyle = textColor
        ctx.font = "10px Arial"
        ctx.textAlign = "left"
        
        var maxMDConverted = formatDepthValue(sketchData.dimensions.max_md || sketchData.dimensions.max_depth, "ft")
        var maxTVDConverted = formatDepthValue(sketchData.dimensions.max_tvd || sketchData.dimensions.max_depth, "ft")

        // 🔥 修改显示格式，明确标注MD和TVD
        var depthText = `TD @ ${maxMDConverted.toFixed(0)} ${getDepthUnit()} MD`
        ctx.fillText(depthText, centerX + 15, bottomY + 5)
        
        // 如果有垂深数据且与测深不同，则显示垂深
        if (Math.abs(maxMDConverted - maxTVDConverted) > 1) {
            var tvdText = `${maxTVDConverted.toFixed(0)} ${getDepthUnit()} TVD`
            ctx.font = "9px Arial"
            ctx.fillText(tvdText, centerX + 15, bottomY + 18)
        }

        // 井斜角标注
        ctx.font = "9px Arial"
        var inclinationText = isChineseMode ? "井斜角 6.3°" : "6.3° Inclination"
        ctx.fillText(inclinationText, centerX + 15, bottomY + 31)
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
