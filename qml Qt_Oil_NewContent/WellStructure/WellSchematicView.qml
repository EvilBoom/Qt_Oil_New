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

        // 🔥 状态显示
        Rectangle {
            id: statusIndicator
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 10
            width: statusText.width + 20
            height: 30
            color: sketchData ? "#4CAF50" : "#FF9800"
            radius: 15
            opacity: 0.8

            Text {
                id: statusText
                anchors.centerIn: parent
                text: sketchData ? 
                    (isChineseMode ? "数据已加载" : "Data Loaded") : 
                    (isChineseMode ? "正在加载..." : "Loading...")
                color: "white"
                font.pixelSize: 10
                font.bold: true
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

    // 🔥 =====================================
    // 🔥 数据获取和更新函数
    // 🔥 =====================================

    function updateSketchFromController() {
        console.log("🔄 从控制器获取井身结构数据")
        if (wellStructureController) {
            try {
                // 直接获取草图数据
                var sketchDataString = wellStructureController.getWellSketchData()
                if (sketchDataString && sketchDataString.length > 0) {
                    console.log("✅ 获取到草图数据字符串")
                    var parsedData = JSON.parse(sketchDataString)
                    if (parsedData && parsedData.has_data) {
                        sketchData = parsedData
                        console.log("✅ 井身结构数据更新成功")
                        canvas.requestPaint()
                    } else {
                        console.log("⚠️ 解析的数据无效或为空")
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
            generateDefaultSketchData()
        }
    }

    function generateDefaultSketchData() {
        console.log("🔧 生成默认井身结构数据")
        sketchData = {
            "casings": [
                {
                    "type": "surface",
                    "top_depth": 0,
                    "bottom_depth": 1000,
                    "top_md": 0,
                    "bottom_md": 1000,
                    "inner_diameter": 8.681,
                    "outer_diameter": 9.625,
                    "id": 1,
                    "label": "表层套管 9-5/8\""
                },
                {
                    "type": "production", 
                    "top_depth": 0,
                    "bottom_depth": 2000,
                    "top_md": 0,
                    "bottom_md": 2000,
                    "inner_diameter": 6.184,
                    "outer_diameter": 7.000,
                    "id": 2,
                    "label": "生产套管 7\""
                }
            ],
            "dimensions": {
                "max_depth": 2000,
                "max_md": 2000,
                "max_tvd": 2000,
                "max_horizontal": 100,
                "depth_unit": "ft",
                "diameter_unit": "in"
            },
            "well_path": [
                {x: 0, y: 0, md: 0, index: 0},
                {x: 0, y: 2000, md: 2000, index: 1}
            ],
            "unit_system": "imperial",
            "has_data": true
        }
        canvas.requestPaint()
    }

    // 公共方法
    function updateSketch(data) {
        if (data && typeof data === 'object') {
            sketchData = data
        } else {
            updateSketchFromController()
        }
        canvas.requestPaint()
    }

    function setDrawingScale(scale) {
        drawingScale = Math.max(0.5, Math.min(3.0, scale))
        canvas.requestPaint()
    }

    // 🔥 =====================================
    // 🔥 主绘制函数
    // 🔥 =====================================

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

            // 绘制套管
            drawCasingsImproved(ctx)

            // 绘制井底
            drawWellBottom(ctx)

            console.log("✅ 井身结构草图绘制完成")

        } catch (error) {
            console.log("❌ 绘制过程中出错:", error)
            drawErrorMessage(ctx, error.toString())
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

        // 🔥 优先使用测深(MD)，其次使用最大深度
        var maxMDOriginal = sketchData.dimensions.max_md || 
                           sketchData.dimensions.max_depth || 
                           10000
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
            maxMD: maxMD,  // 🔥 使用测深
            maxMDOriginal: maxMDOriginal,
            maxHorizontal: maxHorizontal,
            centerX: canvas.width / 2
        }

        console.log("📐 坐标系统设置完成 - 最大深度:", maxMD, getDepthUnit())
    }

    function drawDepthScale(ctx) {
        if (!root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var maxMD = params.maxMD
        var stepSize = calculateDepthStep(maxMD)

        ctx.strokeStyle = gridColor
        ctx.fillStyle = depthTextColor
        ctx.font = "10px Arial"
        ctx.lineWidth = 0.5
        ctx.textAlign = "right"

        console.log("📏 绘制深度标尺 - 步长:", stepSize)

        // 绘制深度标尺
        for (var depth = 0; depth <= maxMD; depth += stepSize) {
            var y = params.margin + (depth / maxMD) * (canvas.height - 2 * params.margin)

            // 刻度线
            ctx.beginPath()
            ctx.moveTo(params.margin - 20, y)
            ctx.lineTo(params.margin - 10, y)
            ctx.stroke()

            // 深度标签
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

        console.log("🔴 绘制井口")

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

        console.log("🔵 绘制井眼轴线")

        // 🔥 确保蓝色线延伸到正确的最大测深位置
        var maxMD = params.maxMD
        var actualBottomY = params.margin + (maxMD / maxMD) * (canvas.height - 2 * params.margin)

        // 绘制井眼中心线 - 确保延伸到实际的最大测深位置
        ctx.strokeStyle = wellLineColor
        ctx.lineWidth = 2
        ctx.setLineDash([])

        ctx.beginPath()
        ctx.moveTo(params.centerX, params.margin)
        ctx.lineTo(params.centerX, actualBottomY)  // 🔥 使用实际计算的底部位置
        ctx.stroke()

        console.log("🔵 井眼轴线绘制完成 - 从", params.margin, "到", actualBottomY)
    }

    // 🔥 =====================================
    // 🔥 改进的套管绘制函数
    // 🔥 =====================================

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

        for (var i = 0; i < sortedCasings.length; i++) {
            var casing = sortedCasings[i]
            drawSingleCasing(ctx, casing, params, i, maxCasingOD, minCasingOD)
        }

        console.log("✅ 所有套管绘制完成")
    }

    function drawSingleCasing(ctx, casing, params, casingIndex, maxCasingOD, minCasingOD) {
        try {
            console.log(`🔧 绘制套管 ${casingIndex + 1}:`, casing.type || "未知类型")

            var maxMD = params.maxMD
            var centerX = params.centerX

            // 🔥 深度数据处理 - 优先使用MD，然后TVD，最后depth
            var topMD = casing.top_md !== undefined ? casing.top_md : 
                       (casing.top_tvd !== undefined ? casing.top_tvd : casing.top_depth || 0)
            var bottomMD = casing.bottom_md !== undefined ? casing.bottom_md :
                          (casing.bottom_tvd !== undefined ? casing.bottom_tvd : casing.bottom_depth || 1000)

            topMD = formatDepthValue(topMD, "ft")
            bottomMD = formatDepthValue(bottomMD, "ft")

            // 确保有效的深度范围
            if (bottomMD <= topMD) {
                bottomMD = topMD + formatDepthValue(500, "ft") // 默认500英尺长度
            }

            var topY = params.margin + (topMD / maxMD) * (canvas.height - 2 * params.margin)
            var bottomY = params.margin + (bottomMD / maxMD) * (canvas.height - 2 * params.margin)

            // 🔥 直径数据处理
            var outerDiameterConverted = formatDiameterValue(casing.outer_diameter || 7, "in")
            var innerDiameterConverted = formatDiameterValue(casing.inner_diameter || 6, "in")

            // 确保外径大于内径
            if (outerDiameterConverted <= innerDiameterConverted) {
                outerDiameterConverted = innerDiameterConverted + formatDiameterValue(1, "in")
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

            console.log(`套管 ${casingIndex + 1} 尺寸: 外径 ${outerDiameterConverted.toFixed(2)}, 内径 ${innerDiameterConverted.toFixed(2)}, 显示宽度 ${outerWidth.toFixed(1)}`)

            // 🔥 绘制套管壁
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

            // 绘制套管标签
            drawCasingLabelImproved(ctx, casing, centerX, topY + (bottomY - topY) / 2, outerWidth, casingIndex, bottomMD)

        } catch (error) {
            console.log(`❌ 绘制套管 ${casingIndex + 1} 时出错:`, error)
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

    // 🔥 改进的套管标签绘制
    function drawCasingLabelImproved(ctx, casing, centerX, midY, casingWidth, casingIndex, bottomMD) {
        var typeName = getCasingTypeName(casing.type)

        // 🔥 显示转换后的套管尺寸
        var outerDiameterConverted = formatDiameterValue(casing.outer_diameter || 7, "in")
        var innerDiameterConverted = formatDiameterValue(casing.inner_diameter || 6, "in")
        
        // 格式化尺寸文本
        var wallThickness = (outerDiameterConverted - innerDiameterConverted) / 2
        var sizeText = outerDiameterConverted.toFixed(isMetric ? 0 : 2) + "×" + 
                      wallThickness.toFixed(isMetric ? 0 : 2) + getDiameterUnit()

        // 🔥 改进的标签位置计算 - 放在套管右侧中间
        var labelOffsetX = casingWidth/2 + 15
        var labelX = centerX + labelOffsetX
        var labelY = midY

        // 确保标签不超出画布边界
        var maxX = canvas.width - 120
        if (labelX > maxX) {
            labelX = maxX
        }

        // 🔥 绘制连接线
        ctx.strokeStyle = getCasingBorderColor(casing.type)
        ctx.lineWidth = 0.8
        ctx.setLineDash([2, 2])
        
        ctx.beginPath()
        ctx.moveTo(centerX + casingWidth/2, labelY)
        ctx.lineTo(labelX - 5, labelY)
        ctx.stroke()
        ctx.setLineDash([])

        // 🔥 绘制标签背景框
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

        // 🔥 绘制标签文本
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

    // 🔥 修复的井底绘制函数
    function drawWellBottom(ctx) {
        if (!sketchData || !sketchData.dimensions || !root.transformParams || Object.keys(root.transformParams).length === 0) return

        var params = root.transformParams
        var centerX = params.centerX
        
        // 🔥 计算井底位置 - 使用最大测深
        var maxMD = params.maxMD
        var bottomY = params.margin + (maxMD / maxMD) * (canvas.height - 2 * params.margin)

        console.log("🟢 绘制井底 - 位置:", bottomY)

        // 绘制井底标记
        ctx.fillStyle = "#4CAF50"
        ctx.strokeStyle = "#2E7D32"
        ctx.lineWidth = 2

        ctx.beginPath()
        ctx.arc(centerX, bottomY, 6, 0, 2 * Math.PI)
        ctx.fill()
        ctx.stroke()

        // 🔥 井底深度标注
        ctx.fillStyle = textColor
        ctx.font = "10px Arial"
        ctx.textAlign = "left"
        
        var maxMDConverted = formatDepthValue(sketchData.dimensions.max_md || sketchData.dimensions.max_depth, "ft")
        var maxTVDConverted = formatDepthValue(sketchData.dimensions.max_tvd || sketchData.dimensions.max_depth, "ft")

        // 显示格式
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

    // 🔥 其他保留的函数
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
        console.log("📊 sketchData 发生变化")
        if (canvas) {
            canvas.requestPaint()
        }
    }

    onDrawingScaleChanged: {
        console.log("🔍 绘图比例变化:", drawingScale)
        if (canvas) {
            canvas.requestPaint()
        }
    }
}