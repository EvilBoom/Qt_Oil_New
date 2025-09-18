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

        // 🔥 组件加载时获取井身结构数据
        Component.onCompleted: {
            updateSketchFromController()
        }

        // 🔥 监听控制器数据变化
        Connections {
            target: wellStructureController
            enabled: wellStructureController !== null

            function onVisualizationReady(vizData) {
                if (vizData && vizData.type === 'sketch') {
                    console.log("📊 收到井身结构草图数据")
                    sketchData = vizData.data
                    canvas.requestPaint()
                }
            }

            function onCasingDataLoaded() {
                // 套管数据更新后重新生成草图
                updateSketchFromController()
            }

            function onTrajectoryDataLoaded() {
                // 轨迹数据更新后重新生成草图
                updateSketchFromController()
            }
        }

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

    // 🔥 修复drawCasingsImproved函数调用问题
    function drawWellSchematic() {
        console.log("🎨 开始绘制井身结构草图")

        if (!canvas) {
            console.log("❌ Canvas 不可用")
            return
        }

        var ctx = canvas.getContext("2d")
        if (!ctx) {
            console.log("❌ 无法获取 Canvas 上下文")
            return
        }

        // 清空画布
        ctx.clearRect(0, 0, canvas.width, canvas.height)

        // 如果没有数据，尝试获取
        if (!sketchData) {
            console.log("⚠️ 没有草图数据，尝试获取...")
            updateSketchFromController()
            if (!sketchData) {
                drawNoDataMessage(ctx)
                return
            }
        }

        try {
            // 设置坐标系统
            setupCoordinateSystem(ctx)

            // 绘制深度标尺
            drawDepthScale(ctx)

            // 绘制井口
            drawWellhead(ctx)

            // 绘制井眼轴线
            drawWellAxis(ctx)

            // 🔥 修复：调用正确的套管绘制函数
            drawCasingsImproved(ctx)

            // 绘制井底
            drawWellBottom(ctx)

            console.log("✅ 井身结构草图绘制完成")

        } catch (error) {
            console.log("❌ 绘制过程中出错:", error)
            drawErrorMessage(ctx, error.toString())
        }
    }

    // 🔥 修复：确保坐标系统计算正确包含所有套管
    function setupCoordinateSystem(ctx) {
        if (!sketchData || !sketchData.dimensions) {
            console.log("❌ 缺少尺寸数据")
            return
        }

        console.log("📐 设置坐标系统")

        // 计算绘图参数
        var margin = 60
        var drawingWidth = canvas.width - 2 * margin
        var drawingHeight = canvas.height - 2 * margin

        // 🔥 修复：确保最大深度包含所有套管
        var maxMDFromDimensions = sketchData.dimensions.max_md ||
                                 sketchData.dimensions.max_depth ||
                                 10000

        // 🔥 新增：检查套管数据中的最大深度
        var maxMDFromCasings = 0
        if (sketchData.casings && sketchData.casings.length > 0) {
            for (var i = 0; i < sketchData.casings.length; i++) {
                var casing = sketchData.casings[i]
                var bottomDepth = casing.bottom_md || casing.bottom_tvd || casing.bottom_depth || 0
                maxMDFromCasings = Math.max(maxMDFromCasings, bottomDepth)
            }
        }

        // 🔥 使用两者中的较大值，确保所有套管都能显示
        var maxMDOriginal = Math.max(maxMDFromDimensions, maxMDFromCasings)
        if (maxMDOriginal <= 0) {
            maxMDOriginal = 10000 // 默认值
        }

        var maxMD = formatDepthValue(maxMDOriginal, "ft")  // 假设原始数据是英尺

        var maxHorizontalOriginal = sketchData.dimensions.max_horizontal || 100
        var maxHorizontal = formatDiameterValue(maxHorizontalOriginal, "in")

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
            maxMD: maxMD,  // 🔥 使用计算后的最大深度
            maxMDOriginal: maxMDOriginal,
            maxHorizontal: maxHorizontal,
            centerX: canvas.width / 2
        }

        console.log("📐 坐标系统设置完成 - 最大深度:", maxMD, getDepthUnit())
        console.log("📐 套管最大深度:", maxMDFromCasings, "尺寸最大深度:", maxMDFromDimensions)
    }

    // 🔥 添加调试函数：检查套管数据完整性
    function debugCasingData() {
        if (!sketchData || !sketchData.casings) {
            console.log("❌ 调试：没有套管数据")
            return
        }

        console.log("🔍 调试：套管数据完整性检查")
        console.log("套管总数:", sketchData.casings.length)

        for (var i = 0; i < sketchData.casings.length; i++) {
            var casing = sketchData.casings[i]
            console.log(`套管 ${i + 1}:`)
            console.log(`  类型: ${casing.type}`)
            console.log(`  深度: ${casing.top_depth} - ${casing.bottom_depth}`)
            console.log(`  直径: ${casing.outer_diameter} / ${casing.inner_diameter}`)
            console.log(`  ID: ${casing.id}`)
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

    // 🔥 修复后的单个套管绘制函数
    function drawSingleCasing(ctx, casing, params, casingIndex, maxCasingOD, minCasingOD) {
        try {
            console.log(`🔧 绘制套管 ${casingIndex + 1}:`, casing.type || "未知类型")
            console.log(`   深度范围: ${casing.top_depth || 0} - ${casing.bottom_depth || 0}`)
            console.log(`   直径: 外径=${casing.outer_diameter}, 内径=${casing.inner_diameter}`)

            var maxMD = params.maxMD
            var centerX = params.centerX

            // 🔥 深度数据处理 - 优先使用MD，然后TVD，最后depth
            var topMD = casing.top_md !== undefined ? casing.top_md :
                       (casing.top_tvd !== undefined ? casing.top_tvd : casing.top_depth || 0)
            var bottomMD = casing.bottom_md !== undefined ? casing.bottom_md :
                          (casing.bottom_tvd !== undefined ? casing.bottom_tvd : casing.bottom_depth || 1000)

            topMD = formatDepthValue(topMD, "ft")
            bottomMD = formatDepthValue(bottomMD, "ft")

            // 🔥 修复：确保有效的深度范围，特别是对最后一个套管
            if (bottomMD <= topMD) {
                bottomMD = topMD + formatDepthValue(500, "ft") // 默认500英尺长度
                console.log(`⚠️ 套管 ${casingIndex + 1} 深度修正: ${topMD} -> ${bottomMD}`)
            }

            // 🔥 修复：确保套管在有效范围内
            if (bottomMD > maxMD) {
                console.log(`⚠️ 套管 ${casingIndex + 1} 底深超出最大深度，调整: ${bottomMD} -> ${maxMD}`)
                bottomMD = maxMD
            }

            var topY = params.margin + (topMD / maxMD) * (canvas.height - 2 * params.margin)
            var bottomY = params.margin + (bottomMD / maxMD) * (canvas.height - 2 * params.margin)

            console.log(`   Y坐标: ${topY.toFixed(1)} - ${bottomY.toFixed(1)} (高度: ${(bottomY - topY).toFixed(1)})`)

            // 🔥 修复：确保Y坐标有效且有足够的高度
            if (bottomY <= topY) {
                bottomY = topY + 20 // 最小20像素高度
                console.log(`⚠️ 套管 ${casingIndex + 1} Y坐标修正: ${topY} -> ${bottomY}`)
            }

            // 🔥 直径数据处理
            var outerDiameterConverted = formatDiameterValue(casing.outer_diameter || 7, "in")
            var innerDiameterConverted = formatDiameterValue(casing.inner_diameter || 6, "in")

            // 确保外径大于内径
            if (outerDiameterConverted <= innerDiameterConverted) {
                outerDiameterConverted = innerDiameterConverted + formatDiameterValue(1, "in")
                console.log(`⚠️ 套管 ${casingIndex + 1} 直径修正: 外径=${outerDiameterConverted}`)
            }

            // 🔥 计算显示宽度 - 使用线性比例而非复杂的非线性缩放
            var diameterRange = maxCasingOD - minCasingOD
            if (diameterRange <= 0) diameterRange = 1  // 避免除零

            // 基于画布高度的比例计算
            var baseWidth = Math.min(canvas.height * 0.08, 100)  // 基础宽度不超过画布高度的8%
            var maxDisplayWidth = baseWidth * 0.8
            var minDisplayWidth = baseWidth * 0.3

            var odRatio = (outerDiameterConverted - minCasingOD) / diameterRange
            var idRatio = (innerDiameterConverted - minCasingOD) / diameterRange

            var outerWidth = minDisplayWidth + (maxDisplayWidth - minDisplayWidth) * odRatio
            var innerWidth = minDisplayWidth + (maxDisplayWidth - minDisplayWidth) * idRatio

            // 🔥 确保最小管壁厚度
            var minWallThickness = 6  // 最小6像素壁厚
            if (outerWidth - innerWidth < minWallThickness) {
                innerWidth = outerWidth - minWallThickness
            }
            if (innerWidth < 10) {
                innerWidth = 10
                outerWidth = innerWidth + minWallThickness
            }

            var wallThickness = (outerWidth - innerWidth) / 2

            console.log(`   显示尺寸: 外宽=${outerWidth.toFixed(1)}, 内宽=${innerWidth.toFixed(1)}, 壁厚=${wallThickness.toFixed(1)}`)

            // 🔥 修复：绘制套管壁 - 确保绘制区域有效
            var casingHeight = bottomY - topY
            if (casingHeight <= 0) {
                console.log(`❌ 套管 ${casingIndex + 1} 高度无效: ${casingHeight}`)
                return
            }

            ctx.fillStyle = getCasingColor(casing.type)
            ctx.strokeStyle = getCasingBorderColor(casing.type)
            ctx.lineWidth = 1

            // 🔥 修复：左侧套管壁
            var leftWallX = centerX - outerWidth/2
            var leftWallWidth = wallThickness

            console.log(`   左壁: x=${leftWallX.toFixed(1)}, y=${topY.toFixed(1)}, w=${leftWallWidth.toFixed(1)}, h=${casingHeight.toFixed(1)}`)

            ctx.fillRect(leftWallX, topY, leftWallWidth, casingHeight)
            ctx.strokeRect(leftWallX, topY, leftWallWidth, casingHeight)

            // 🔥 修复：右侧套管壁
            var rightWallX = centerX + innerWidth/2
            var rightWallWidth = wallThickness

            console.log(`   右壁: x=${rightWallX.toFixed(1)}, y=${topY.toFixed(1)}, w=${rightWallWidth.toFixed(1)}, h=${casingHeight.toFixed(1)}`)

            ctx.fillRect(rightWallX, topY, rightWallWidth, casingHeight)
            ctx.strokeRect(rightWallX, topY, rightWallWidth, casingHeight)

            // 🔥 绘制套管鞋（除了导管）
            if (casing.type !== "conductor") {
                drawCasingShoe(ctx, centerX, bottomY, outerWidth)
            }

            // 绘制套管标签
            drawCasingLabelImproved(ctx, casing, centerX, topY + casingHeight / 2, outerWidth, casingIndex, bottomMD)

            console.log(`✅ 套管 ${casingIndex + 1} 绘制完成`)

        } catch (error) {
            console.log(`❌ 绘制套管 ${casingIndex + 1} 时出错:`, error)
            console.log("错误堆栈:", error.stack)
        }
    }

    // 🔥 修复后的套管绘制函数
    function drawCasingsImproved(ctx) {
        if (!sketchData || !sketchData.casings || !root.transformParams || Object.keys(root.transformParams).length === 0) {
            console.log("⚠️ 没有套管数据或坐标参数")
            return
        }

        var params = root.transformParams
        var maxMD = params.maxMD
        var centerX = params.centerX
        var casings = sketchData.casings

        console.log("🔧 开始绘制套管 - 数量:", casings.length)

        // 🔥 调试信息：显示所有套管的基本信息
        for (var i = 0; i < casings.length; i++) {
            console.log(`套管 ${i + 1}: 类型=${casings[i].type}, 顶深=${casings[i].top_depth}, 底深=${casings[i].bottom_depth}`)
        }

        if (casings.length === 0) {
            console.log("⚠️ 没有套管数据")
            return
        }

        // 按外径从大到小排序
        var sortedCasings = casings.slice().sort(function(a, b) {
            return (b.outer_diameter || 0) - (a.outer_diameter || 0)
        })

        // 🔥 改进的直径计算逻辑
        var maxCasingOD = 0
        var minCasingOD = Number.MAX_VALUE

        for (var i = 0; i < sortedCasings.length; i++) {
            var outerDiameter = formatDiameterValue(sortedCasings[i].outer_diameter || 7, "in")
            maxCasingOD = Math.max(maxCasingOD, outerDiameter)
            minCasingOD = Math.min(minCasingOD, outerDiameter)
        }

        console.log("📏 套管直径范围:", minCasingOD.toFixed(2), "-", maxCasingOD.toFixed(2), getDiameterUnit())

        // 🔥 修复：绘制所有套管，包括最后一个
        for (var i = 0; i < sortedCasings.length; i++) {
            var casing = sortedCasings[i]
            console.log(`🔧 正在绘制套管 ${i + 1}/${sortedCasings.length}: ${casing.type}`)
            drawSingleCasing(ctx, casing, params, i, maxCasingOD, minCasingOD)
        }

        console.log("✅ 所有套管绘制完成")
    }
    // 🔥 =====================================
    // 🔥 添加缺少的数据获取和错误显示函数
    // 🔥 =====================================

    function updateSketchFromController() {
        console.log("🔄 从控制器获取井身结构数据")
        if (wellStructureController) {
            try {
                // 直接获取草图数据
                var sketchDataString = wellStructureController.getWellSketchData()
                console.log("📊 获取到的原始数据:", sketchDataString ? "有数据" : "无数据")

                if (sketchDataString && sketchDataString.length > 0) {
                    console.log("✅ 获取到草图数据字符串，长度:", sketchDataString.length)

                    try {
                        var parsedData = JSON.parse(sketchDataString)
                        console.log("🔍 解析后的数据结构:")
                        console.log("  - 类型:", typeof parsedData)
                        console.log("  - 包含套管:", parsedData.casings ? parsedData.casings.length : 0)
                        console.log("  - 包含尺寸:", parsedData.dimensions ? "是" : "否")
                        console.log("  - has_data:", parsedData.has_data)

                        if (parsedData && parsedData.has_data) {
                            sketchData = parsedData
                            console.log("✅ 井身结构数据更新成功")
                            console.log("🔧 套管数量:", parsedData.casings ? parsedData.casings.length : 0)

                            // 🔥 调试：输出第一个套管的信息
                            if (parsedData.casings && parsedData.casings.length > 0) {
                                var firstCasing = parsedData.casings[0]
                                console.log("🔧 第一个套管:", firstCasing.type,
                                          "深度:", firstCasing.top_depth, "-", firstCasing.bottom_depth,
                                          "直径:", firstCasing.inner_diameter, "/", firstCasing.outer_diameter)
                            }

                            canvas.requestPaint()
                        } else {
                            console.log("⚠️ 解析的数据无效或为空")
                            generateDefaultSketchData()
                        }
                    } catch (parseError) {
                        console.log("❌ JSON解析失败:", parseError)
                        console.log("原始数据前100字符:", sketchDataString.substring(0, 100))
                        generateDefaultSketchData()
                    }
                } else {
                    console.log("⚠️ 未获取到草图数据，生成默认数据")
                    generateDefaultSketchData()
                }
            } catch (error) {
                console.log("❌ 获取井身结构数据失败:", error)
                generateDefaultSketchData()
            }
        } else {
            console.log("❌ wellStructureController 不可用")
        }
    }


    function drawNoDataMessage(ctx) {
        ctx.fillStyle = "#666666"
        ctx.font = "16px Arial"
        ctx.textAlign = "center"
        ctx.fillText(
            isChineseMode ? "暂无井身结构数据" : "No well structure data",
            canvas.width / 2,
            canvas.height / 2
        )
    }
    function drawErrorMessage(ctx, error) {
        ctx.fillStyle = "#FF0000"
        ctx.font = "14px Arial"
        ctx.textAlign = "center"
        ctx.fillText(
            isChineseMode ? "绘制错误: " + error : "Draw error: " + error,
            canvas.width / 2,
            canvas.height / 2
        )
    }
    // 🔥 修复套管标签函数缺少的参数问题
    function drawCasingLabelImproved(ctx, casing, centerX, midY, outerWidth, casingIndex, bottomMD) {
        var typeName = getCasingTypeName(casing.type)

        // 显示转换后的套管尺寸
        var outerDiameterConverted = formatDiameterValue(casing.outer_diameter || 7, "in")
        var innerDiameterConverted = formatDiameterValue(casing.inner_diameter || 6, "in")

        // 格式化尺寸文本
        var wallThickness = (outerDiameterConverted - innerDiameterConverted) / 2
        var sizeText = outerDiameterConverted.toFixed(isMetric ? 0 : 2) + "×" +
                      wallThickness.toFixed(isMetric ? 0 : 2) + getDiameterUnit()

        // 改进的标签位置计算 - 放在套管右侧中间
        var labelOffsetX = outerWidth/2 + 15
        var labelX = centerX + labelOffsetX
        var labelY = midY

        // 确保标签不超出画布边界
        var maxX = canvas.width - 120
        if (labelX > maxX) {
            labelX = maxX
        }

        // 绘制连接线
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 0.8
        ctx.setLineDash([2, 2])

        ctx.beginPath()
        ctx.moveTo(centerX + outerWidth/2, labelY)
        ctx.lineTo(labelX - 5, labelY)
        ctx.stroke()
        ctx.setLineDash([])

        // 绘制标签背景框
        ctx.font = "9px Arial"
        var typeTextWidth = ctx.measureText(typeName).width
        var sizeTextWidth = ctx.measureText(sizeText).width
        var maxTextWidth = Math.max(typeTextWidth, sizeTextWidth)

        var labelWidth = maxTextWidth + 12
        var labelHeight = 22

        // 背景框
        ctx.fillStyle = "rgba(255, 255, 255, 0.95)"
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 1
        ctx.fillRect(labelX, labelY - labelHeight/2, labelWidth, labelHeight)
        ctx.strokeRect(labelX, labelY - labelHeight/2, labelWidth, labelHeight)

        // 颜色条
        ctx.fillStyle = getCasingColor(casing.type)
        ctx.fillRect(labelX, labelY - labelHeight/2, 3, labelHeight)

        // 绘制标签文本
        ctx.fillStyle = textColor
        ctx.textAlign = "left"
        ctx.textBaseline = "middle"

        // 套管类型
        ctx.font = "bold 8px Arial"
        ctx.fillText(typeName, labelX + 6, labelY - 5)

        // 尺寸信息
        ctx.font = "7px Arial"
        ctx.fillText(sizeText, labelX + 6, labelY + 5)

        // 重置文本对齐
        ctx.textAlign = "left"
        ctx.textBaseline = "top"
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
