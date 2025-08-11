import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Window

ApplicationWindow {
    id: knowledgeGraphWindow

    title: isChineseMode ? "设备选型知识图谱辅助" : "Knowledge Graph Assistant"
    width: 1400
    height: 900
    minimumWidth: 1000
    minimumHeight: 700

    property bool isChineseMode: true
    property bool isMetric: false
    property var currentStepData: ({})
    property string currentStepId: ""
    property var selectionConstraints: ({})

    // 图谱数据
    property var graphData: null
    property var recommendations: []

    // 🔥 新增：图谱配置选项
    property bool showEdgeLabels: true
    property bool showNodeDetails: true
    property string layoutMode: "force"  // "force", "circle", "grid", "tree"
    property real zoomLevel: 1.0
    property var selectedNode: null
    property var hoveredNode: null

    // 🔥 新增：实时节点位置跟踪
    property var nodePositions: ({})  // 实时节点位置映射

    // 信号定义
    signal windowClosed()
    signal recommendationAccepted(var recommendation)
    signal nodeDetailsRequested(var nodeData)
    signal layoutChanged(string newLayout)

    Material.theme: Material.Light
    Material.primary: Material.BlueGrey

    onClosing: {
        console.log("知识图谱窗口正在关闭")
        windowClosed()
    }

    // 🔥 监听nodePositions变化
    onNodePositionsChanged: {
        console.log("节点位置发生变化，触发连接线重绘")
        edgeCanvas.requestPaint()
    }

    // 连接知识图谱控制器信号
    Connections {
        target: knowledgeGraphController
        enabled: knowledgeGraphController !== undefined

        function onKnowledgeGraphDataReady(data) {
            console.log("知识图谱数据就绪, 节点数:", data.nodes ? data.nodes.length : 0)
            graphData = data
            if (data && data.nodes) {
                // 🔥 初始化节点位置映射
                initializeNodePositions(data)
                updateGraphView(data)
            }
        }

        function onRecommendationsGenerated(recs) {
            console.log("推荐生成完成:", recs.length, "条")
            recommendations = recs || []
            updateRecommendationsList(recs || [])
        }

        function onError(errorMsg) {
            console.error("知识图谱错误:", errorMsg)
            showErrorMessage(errorMsg)
        }
    }

    // 主布局
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 🔥 增强的顶部工具栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Material.primary

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Text {
                    text: "🧠 " + (isChineseMode ? "知识图谱辅助系统" : "Knowledge Graph Assistant")
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                }

                Item { Layout.fillWidth: true }

                // 🔥 布局选择器
                Row {
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: isChineseMode ? "布局:" : "Layout:"
                        font.pixelSize: 11
                        color: "white"
                    }

                    ComboBox {
                        id: layoutSelector
                        width: 100
                        height: 28
                        model: [
                            { text: isChineseMode ? "力导向" : "Force", value: "force" },
                            { text: isChineseMode ? "环形" : "Circle", value: "circle" },
                            { text: isChineseMode ? "网格" : "Grid", value: "grid" },
                            { text: isChineseMode ? "树形" : "Tree", value: "tree" }
                        ]
                        textRole: "text"
                        valueRole: "value"

                        onActivated: {
                            layoutMode = currentValue
                            layoutChanged(currentValue)
                            refreshGraphLayout()
                        }

                        delegate: ItemDelegate {
                            width: layoutSelector.width
                            text: modelData.text
                            highlighted: layoutSelector.highlightedIndex === index
                        }
                    }
                }

                // 🔥 视图控制
                Row {
                    spacing: 4

                    Button {
                        text: "🔍+"
                        flat: true
                        width: 32
                        height: 28
                        Material.foreground: "white"
                        onClicked: zoomIn()

                        ToolTip.visible: hovered
                        ToolTip.text: isChineseMode ? "放大" : "Zoom In"
                    }

                    Button {
                        text: "🔍-"
                        flat: true
                        width: 32
                        height: 28
                        Material.foreground: "white"
                        onClicked: zoomOut()

                        ToolTip.visible: hovered
                        ToolTip.text: isChineseMode ? "缩小" : "Zoom Out"
                    }

                    Button {
                        text: "⌂"
                        flat: true
                        width: 32
                        height: 28
                        Material.foreground: "white"
                        onClicked: resetView()

                        ToolTip.visible: hovered
                        ToolTip.text: isChineseMode ? "重置视图" : "Reset View"
                    }
                }

                // 当前步骤
                Rectangle {
                    width: 120
                    height: 28
                    radius: 14
                    color: Material.accent

                    Text {
                        anchors.centerIn: parent
                        text: getStepDisplayName()
                        font.pixelSize: 11
                        color: "white"
                    }
                }

                // 刷新按钮
                Button {
                    text: "🔄"
                    flat: true
                    Material.foreground: "white"
                    onClicked: refreshGraphData()
                }

                // 关闭按钮
                Button {
                    text: "✕"
                    flat: true
                    Material.foreground: "white"
                    onClicked: knowledgeGraphWindow.close()
                }
            }
        }

        // 主内容区域
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // 左侧：图谱显示区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                border.color: Material.dividerColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // 🔥 增强的图例和控制面板
                    Row {
                        Layout.fillWidth: true
                        spacing: 16

                        Text {
                            text: isChineseMode ? "图例:" : "Legend:"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Repeater {
                            model: [
                                { color: "#2196F3", label: isChineseMode ? "当前步骤" : "Current Step" },
                                { color: "#4CAF50", label: isChineseMode ? "泵设备" : "Pumps" },
                                { color: "#FF9800", label: isChineseMode ? "电机" : "Motors" },
                                { color: "#9C27B0", label: isChineseMode ? "保护器" : "Protectors" },
                                { color: "#00BCD4", label: isChineseMode ? "分离器" : "Separators" },
                                { color: "#F44336", label: isChineseMode ? "约束条件" : "Constraints" }
                            ]

                            Row {
                                spacing: 4

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: modelData.color
                                }

                                Text {
                                    text: modelData.label
                                    font.pixelSize: 10
                                    color: Material.hintTextColor
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // 🔥 显示选项
                        Row {
                            spacing: 8

                            CheckBox {
                                id: showLabelsCheck
                                text: isChineseMode ? "标签" : "Labels"
                                checked: showEdgeLabels
                                font.pixelSize: 10
                                onCheckedChanged: {
                                    showEdgeLabels = checked
                                    updateGraphDisplay()
                                }
                            }

                            CheckBox {
                                id: showDetailsCheck
                                text: isChineseMode ? "详情" : "Details"
                                checked: showNodeDetails
                                font.pixelSize: 10
                                onCheckedChanged: {
                                    showNodeDetails = checked
                                    updateGraphDisplay()
                                }
                            }
                        }
                    }

                    // 🔥 增强的图谱显示区域
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#f8f9fa"
                        border.color: Material.dividerColor
                        border.width: 1
                        radius: 4

                        // 图谱画布容器
                        Item {
                            id: graphContainer
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            // 🔥 可缩放滚动的图谱视图
                            Flickable {
                                id: graphFlickable
                                anchors.fill: parent
                                contentWidth: graphContent.width * zoomLevel
                                contentHeight: graphContent.height * zoomLevel
                                boundsBehavior: Flickable.StopAtBounds

                                // 图谱内容
                                Item {
                                    id: graphContent
                                    width: graphContainer.width
                                    height: graphContainer.height
                                    scale: zoomLevel
                                    transformOrigin: Item.TopLeft

                                    // 🔥 连接线层 - 修复为动态跟随节点位置
                                    Canvas {
                                        id: edgeCanvas
                                        anchors.fill: parent
                                        z: 1

                                        property var edges: graphData && graphData.edges ? graphData.edges : []

                                        onPaint: {
                                            drawEdges()
                                        }

                                        function drawEdges() {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)

                                            if (!edges || Object.keys(nodePositions).length === 0) return

                                            for (var i = 0; i < edges.length; i++) {
                                                var edge = edges[i]
                                                // 🔥 使用实时节点位置而不是静态布局
                                                var sourcePos = nodePositions[edge.source]
                                                var targetPos = nodePositions[edge.target]

                                                if (!sourcePos || !targetPos) continue

                                                // 绘制连接线
                                                ctx.beginPath()
                                                ctx.moveTo(sourcePos.x, sourcePos.y)
                                                ctx.lineTo(targetPos.x, targetPos.y)
                                                ctx.strokeStyle = edge.color || "#999"
                                                ctx.lineWidth = Math.max(1, (edge.strength || 0.5) * 3)
                                                ctx.setLineDash(edge.type === "influences" ? [5, 5] : [])
                                                ctx.stroke()
                                                ctx.setLineDash([])

                                                // 绘制箭头
                                                drawArrow(ctx, sourcePos, targetPos, edge.color || "#999")

                                                // 绘制标签
                                                if (showEdgeLabels && edge.label && edge.strength > 0.6) {
                                                    var midX = (sourcePos.x + targetPos.x) / 2
                                                    var midY = (sourcePos.y + targetPos.y) / 2

                                                    ctx.fillStyle = "#ffffffe6"
                                                    ctx.fillRect(midX - 25, midY - 8, 50, 16)

                                                    ctx.fillStyle = "#555"
                                                    ctx.font = "10px Arial"
                                                    ctx.textAlign = "center"
                                                    ctx.fillText(edge.label, midX, midY + 3)
                                                }
                                            }
                                        }

                                        function drawArrow(ctx, from, to, color) {
                                            var angle = Math.atan2(to.y - from.y, to.x - from.x)
                                            var arrowLength = 8
                                            var arrowAngle = 0.4

                                            // 计算箭头位置（在目标节点边缘而不是中心）
                                            var targetRadius = 30 // 节点半径估值
                                            var adjustedToX = to.x - targetRadius * Math.cos(angle)
                                            var adjustedToY = to.y - targetRadius * Math.sin(angle)

                                            ctx.beginPath()
                                            ctx.moveTo(adjustedToX - arrowLength * Math.cos(angle - arrowAngle),
                                                      adjustedToY - arrowLength * Math.sin(angle - arrowAngle))
                                            ctx.lineTo(adjustedToX, adjustedToY)
                                            ctx.lineTo(adjustedToX - arrowLength * Math.cos(angle + arrowAngle),
                                                      adjustedToY - arrowLength * Math.sin(angle + arrowAngle))
                                            ctx.strokeStyle = color
                                            ctx.lineWidth = 2
                                            ctx.stroke()
                                        }
                                    }

                                    // 🔥 增强的节点层 - 修复拖拽时的连接线更新
                                    Repeater {
                                        id: nodeRepeater
                                        model: graphData && graphData.nodes ? graphData.nodes : []
                                        z: 2

                                        // 节点项
                                        Rectangle {
                                            id: nodeRect
                                            property var nodeData: modelData
                                            property var nodePos: graphData && graphData.layout && graphData.layout[nodeData.id] ?
                                                                 graphData.layout[nodeData.id] : { x: 100, y: 100 }
                                            property bool isSelected: selectedNode && selectedNode.id === nodeData.id
                                            property bool isHovered: hoveredNode && hoveredNode.id === nodeData.id

                                            x: nodePos.x - width/2
                                            y: nodePos.y - height/2
                                            width: getNodeSize(nodeData)
                                            height: width
                                            radius: width / 2
                                            color: getNodeColor(nodeData)
                                            border.color: isSelected ? "#FF5722" : (isHovered ? "#2196F3" : Material.dividerColor)
                                            border.width: isSelected ? 3 : (isHovered ? 2 : 1)

                                            // 🔥 初始化和更新节点位置映射
                                            Component.onCompleted: {
                                                updateNodePosition()
                                            }

                                            onXChanged: updateNodePosition()
                                            onYChanged: updateNodePosition()

                                            function updateNodePosition() {
                                                if (nodeData && nodeData.id) {
                                                    var newPositions = Object.assign({}, nodePositions)
                                                    newPositions[nodeData.id] = {
                                                        x: x + width/2,
                                                        y: y + height/2
                                                    }
                                                    // 🔥 通过调用专门的更新函数来触发属性变化
                                                    knowledgeGraphWindow.updateNodePositions(newPositions)
                                                }
                                            }

                                            // 🔥 节点动画效果
                                            scale: isHovered ? 1.1 : (isSelected ? 1.05 : 1.0)
                                            Behavior on scale {
                                                NumberAnimation { duration: 150 }
                                            }
                                            Behavior on border.width {
                                                NumberAnimation { duration: 150 }
                                            }

                                            // 阴影效果
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.topMargin: 2
                                                anchors.leftMargin: 2
                                                color: "#20000000"
                                                radius: parent.radius
                                                z: -1
                                            }

                                            // 🔥 节点重要性指示器
                                            Rectangle {
                                                visible: nodeData.importance >= 4
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: "#FF5722"
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.rightMargin: 2
                                                anchors.topMargin: 2
                                                z: 10

                                                // 重要性脉冲动画
                                                SequentialAnimation on scale {
                                                    loops: Animation.Infinite
                                                    NumberAnimation { to: 1.3; duration: 800 }
                                                    NumberAnimation { to: 1.0; duration: 800 }
                                                }
                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 2

                                                // 图标
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    text: nodeData && nodeData.icon ? nodeData.icon : "⚙️"
                                                    font.pixelSize: parent.parent.width * 0.3
                                                    color: "white"
                                                }

                                                // 🔥 节点状态指示器
                                                Rectangle {
                                                    visible: nodeData && nodeData.selected
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: 16
                                                    height: 4
                                                    radius: 2
                                                    color: "#4CAF50"
                                                }
                                            }

                                            // 🔥 节点标签 - 可选显示
                                            Rectangle {
                                                visible: showNodeDetails
                                                anchors.top: parent.bottom
                                                anchors.topMargin: 8
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: labelText.width + 8
                                                height: labelText.height + 4
                                                radius: 4
                                                color: "#ffffffe6"  // 🔥 修复：十六进制格式
                                                border.color: "#0000001a"  // 🔥 修复：十六进制格式
                                                border.width: 1

                                                Text {
                                                    id: labelText
                                                    anchors.centerIn: parent
                                                    text: getDisplayLabel(nodeData)
                                                    font.pixelSize: 9
                                                    color: "#333"
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }

                                            // 🔥 鼠标交互 - 改进的拖拽逻辑
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        selectNode(nodeData)
                                                    } else if (mouse.button === Qt.RightButton) {
                                                        showNodeContextMenu(nodeData, mouse.x, mouse.y)
                                                    }
                                                }

                                                onDoubleClicked: {
                                                    if (nodeData.deviceData) {
                                                        showDeviceDetails(nodeData)
                                                    }
                                                }

                                                onEntered: {
                                                    hoveredNode = nodeData
                                                    showNodeTooltip(nodeData, nodeRect)
                                                }

                                                onExited: {
                                                    hoveredNode = null
                                                    hideNodeTooltip()
                                                }

                                                // 🔥 改进的拖拽支持 - 实时更新连接线
                                                property point startPoint
                                                property point nodeStartPoint
                                                property bool isDragging: false

                                                onPressed: function(mouse) {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        startPoint = Qt.point(mouse.x, mouse.y)
                                                        nodeStartPoint = Qt.point(nodeRect.x, nodeRect.y)
                                                        isDragging = false
                                                    }
                                                }

                                                onPositionChanged: function(mouse) {
                                                    if (pressed && mouse.buttons & Qt.LeftButton) {
                                                        var dx = mouse.x - startPoint.x
                                                        var dy = mouse.y - startPoint.y

                                                        // 检测是否开始拖拽
                                                        if (!isDragging && (Math.abs(dx) > 5 || Math.abs(dy) > 5)) {
                                                            isDragging = true
                                                        }

                                                        if (isDragging) {
                                                            var newX = nodeStartPoint.x + dx
                                                            var newY = nodeStartPoint.y + dy

                                                            // 边界限制
                                                            var margin = nodeRect.width / 2
                                                            newX = Math.max(margin, Math.min(graphContent.width - margin, newX))
                                                            newY = Math.max(margin, Math.min(graphContent.height - margin, newY))

                                                            nodeRect.x = newX
                                                            nodeRect.y = newY

                                                            // 🔥 位置更新会自动通过onXChanged/onYChanged触发
                                                        }
                                                    }
                                                }

                                                onReleased: function(mouse) {
                                                    if (!isDragging) {
                                                        // 如果没有拖拽，则视为点击
                                                        selectNode(nodeData)
                                                    }
                                                    isDragging = false
                                                }
                                            }

                                            // 🔥 匹配度指示器
                                            Rectangle {
                                                visible: nodeData && nodeData.matchScore !== undefined
                                                anchors.bottom: parent.bottom
                                                anchors.right: parent.right
                                                anchors.rightMargin: -4
                                                anchors.bottomMargin: -4
                                                width: 20
                                                height: 12
                                                radius: 6
                                                color: getMatchScoreColor(nodeData.matchScore)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: nodeData.matchScore ? (nodeData.matchScore * 100).toFixed(0) + "%" : ""
                                                    font.pixelSize: 7
                                                    font.bold: true
                                                    color: "white"
                                                }
                                            }
                                        }
                                    }
                                }

                                // 🔥 鼠标滚轮缩放
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton

                                    onWheel: function(wheel) {
                                        var delta = wheel.angleDelta.y / 120
                                        var scaleFactor = delta > 0 ? 1.1 : 0.9
                                        var newZoom = zoomLevel * scaleFactor

                                        if (newZoom >= 0.5 && newZoom <= 3.0) {
                                            zoomLevel = newZoom
                                            updateGraphDisplay()
                                        }
                                    }
                                }
                            }
                        }

                        // 空状态显示
                        Column {
                            anchors.centerIn: parent
                            spacing: 16
                            visible: !graphData || !graphData.nodes || graphData.nodes.length === 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🔍"
                                font.pixelSize: 48
                                color: Material.primary

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 1000 }
                                    NumberAnimation { to: 1.0; duration: 1000 }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "正在加载知识图谱..." : "Loading Knowledge Graph..."
                                font.pixelSize: 16
                                color: Material.primaryTextColor
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "分析设备关系和兼容性..." : "Analyzing device relationships..."
                                font.pixelSize: 12
                                color: Material.hintTextColor
                            }
                        }

                        // 🔥 缩放级别指示器
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 80
                            height: 20
                            radius: 10
                            color: "#0000001a"  // 🔥 修复：十六进制格式
                            visible: zoomLevel !== 1.0

                            Text {
                                anchors.centerIn: parent
                                text: (zoomLevel * 100).toFixed(0) + "%"
                                font.pixelSize: 10
                                color: "#333"
                            }
                        }
                    }
                }
            }

            // 右侧推荐面板 - 保持现有实现
            Rectangle {
                Layout.preferredWidth: 350
                Layout.fillHeight: true
                color: Material.background
                border.color: Material.dividerColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // 标题
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: isChineseMode ? "智能推荐建议" : "AI Recommendations"
                            font.pixelSize: 16
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 60
                            height: 20
                            radius: 10
                            color: recommendations.length > 0 ? "#4CAF50" : "#FF9800"

                            Text {
                                anchors.centerIn: parent
                                text: recommendations.length + ""
                                font.pixelSize: 10
                                font.bold: true
                                color: "white"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Material.dividerColor
                    }

                    // 选中节点详情面板
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: selectedNode ? 120 : 0
                        visible: selectedNode !== null
                        color: Material.dialogColor
                        radius: 6

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Row {
                                spacing: 8

                                Text {
                                    text: selectedNode ? selectedNode.icon : ""
                                    font.pixelSize: 24
                                }

                                Column {
                                    Text {
                                        text: isChineseMode ? "选中设备" : "Selected Device"
                                        font.pixelSize: 10
                                        color: Material.hintTextColor
                                    }

                                    Text {
                                        text: selectedNode ? selectedNode.label : ""
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Material.primaryTextColor
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: selectedNode ? getNodeDescription(selectedNode) : ""
                                font.pixelSize: 11
                                color: Material.secondaryTextColor
                                wrapMode: Text.WordWrap
                            }

                            // 节点操作按钮
                            Row {
                                spacing: 8

                                Button {
                                    text: isChineseMode ? "查看详情" : "View Details"
                                    flat: true
                                    onClicked: {
                                        if (selectedNode) {
                                            nodeDetailsRequested(selectedNode)
                                        }
                                    }
                                }

                                Button {
                                    visible: selectedNode && selectedNode.deviceData
                                    text: isChineseMode ? "设备信息" : "Device Info"
                                    flat: true
                                    onClicked: {
                                        if (selectedNode) {
                                            showDeviceDetails(selectedNode)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 推荐列表
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Column {
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: recommendations

                                Rectangle {
                                    width: parent.width
                                    height: cardContent.height + 20
                                    color: getCardColor(modelData)
                                    radius: 6
                                    border.color: getBorderColor(modelData)
                                    border.width: 1

                                    Column {
                                        id: cardContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8

                                        Row {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                text: modelData && modelData.icon ? modelData.icon : "💡"
                                                font.pixelSize: 20
                                            }

                                            Text {
                                                width: parent.width - 60
                                                text: modelData && modelData.title ? modelData.title : "推荐建议"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: getBorderColor(modelData)
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData && modelData.description ? modelData.description : ""
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                            wrapMode: Text.WordWrap
                                            visible: text !== ""
                                        }

                                        Button {
                                            visible: modelData && modelData.actionText
                                            text: modelData && modelData.actionText ? modelData.actionText : ""
                                            width: parent.width

                                            Material.background: getBorderColor(modelData)
                                            Material.foreground: "white"

                                            onClicked: {
                                                if (modelData && modelData.data) {
                                                    console.log("推荐被接受:", modelData.title)
                                                    knowledgeGraphWindow.recommendationAccepted(modelData.data)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 100
                                visible: recommendations.length === 0
                                color: "transparent"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "🤔"
                                        font.pixelSize: 32
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: isChineseMode ? "暂无推荐建议" : "No recommendations"
                                        font.pixelSize: 12
                                        color: Material.hintTextColor
                                    }
                                }
                            }
                        }
                    }

                    // 底部操作
                    Row {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            text: isChineseMode ? "🔄 刷新" : "🔄 Refresh"
                            flat: true
                            onClicked: refreshRecommendations()
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: isChineseMode ? "💡 重新分析" : "💡 Re-analyze"
                            Material.background: Material.primary
                            Material.foreground: "white"
                            onClicked: refreshGraphData()
                        }
                    }
                }
            }
        }

        // 底部状态栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            color: Material.dialogColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12

                Text {
                    text: "💡 " + (isChineseMode ? "提示: 左键选择节点，右键显示菜单，滚轮缩放，拖拽移动" :
                                              "Tip: Left click to select, right click for menu, scroll to zoom, drag to move")
                    font.pixelSize: 10
                    color: Material.hintTextColor
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 12

                    Text {
                        text: (isChineseMode ? "布局: " : "Layout: ") + getLayoutDisplayName()
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }

                    Text {
                        text: (isChineseMode ? "节点: " : "Nodes: ") +
                              (graphData && graphData.nodes ? graphData.nodes.length : 0)
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }

                    Text {
                        text: (isChineseMode ? "连接: " : "Edges: ") +
                              (graphData && graphData.edges ? graphData.edges.length : 0)
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                }
            }
        }
    }

    // 工具提示
    Rectangle {
        id: nodeTooltip
        visible: false
        z: 3000

        width: tooltipText.width + 16
        height: tooltipText.height + 12
        color: "#333"
        radius: 4

        Text {
            id: tooltipText
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 11
        }

        Behavior on x { NumberAnimation { duration: 100 } }
        Behavior on y { NumberAnimation { duration: 100 } }
    }

    // 右键菜单
    Menu {
        id: nodeContextMenu
        property var targetNode: null

        MenuItem {
            text: isChineseMode ? "查看详情" : "View Details"
            onTriggered: {
                if (nodeContextMenu.targetNode) {
                    showNodeDetails(nodeContextMenu.targetNode)
                }
            }
        }

        MenuItem {
            text: isChineseMode ? "设为焦点" : "Set as Focus"
            onTriggered: {
                if (nodeContextMenu.targetNode) {
                    focusOnNode(nodeContextMenu.targetNode)
                }
            }
        }

        MenuSeparator {}

        MenuItem {
            text: isChineseMode ? "隐藏节点" : "Hide Node"
            onTriggered: {
                if (nodeContextMenu.targetNode) {
                    hideNode(nodeContextMenu.targetNode)
                }
            }
        }
    }

    // 函数定义
    Component.onCompleted: {
        console.log("知识图谱窗口已创建")
        Qt.callLater(refreshGraphData)
    }

    // 🔥 新增：初始化节点位置映射
    function initializeNodePositions(data) {
        if (!data || !data.nodes || !data.layout) return

        var positions = {}
        for (var i = 0; i < data.nodes.length; i++) {
            var node = data.nodes[i]
            if (node.id && data.layout[node.id]) {
                positions[node.id] = {
                    x: data.layout[node.id].x,
                    y: data.layout[node.id].y
                }
            }
        }
        nodePositions = positions
        console.log("初始化节点位置映射，共", Object.keys(positions).length, "个节点")
    }

    // 🔥 新增：更新节点位置的专门函数
    function updateNodePositions(newPositions) {
        nodePositions = newPositions
        // 这会触发onNodePositionsChanged，进而触发连接线重绘
    }

    function refreshGraphData() {
        console.log("刷新知识图谱数据")
        if (knowledgeGraphController && currentStepId !== "") {
            knowledgeGraphController.generateKnowledgeGraph(currentStepId, currentStepData, selectionConstraints)
            knowledgeGraphController.generateRecommendations(currentStepId, selectionConstraints)
        }
    }

    function refreshRecommendations() {
        console.log("刷新推荐建议")
        if (knowledgeGraphController && currentStepId !== "") {
            knowledgeGraphController.generateRecommendations(currentStepId, selectionConstraints)
        }
    }

    function updateGraphView(data) {
        console.log("更新图谱视图")
        edgeCanvas.requestPaint()
    }

    function updateRecommendationsList(recs) {
        console.log("更新推荐列表")
    }

    function selectNode(node) {
        selectedNode = node
        console.log("选中节点:", node.label)
    }

    function showNodeContextMenu(node, x, y) {
        nodeContextMenu.targetNode = node
        nodeContextMenu.popup()
    }

    function showNodeTooltip(node, parentItem) {
        if (!node) return

        tooltipText.text = getDetailedTooltip(node)
        nodeTooltip.x = parentItem.x + parentItem.width + 10
        nodeTooltip.y = parentItem.y

        // 边界检查
        if (nodeTooltip.x + nodeTooltip.width > knowledgeGraphWindow.width) {
            nodeTooltip.x = parentItem.x - nodeTooltip.width - 10
        }

        nodeTooltip.visible = true
    }

    function hideNodeTooltip() {
        nodeTooltip.visible = false
    }

    function showNodeDetails(node) {
        console.log("显示节点详情:", node ? node.label : "未知节点")
    }

    function showDeviceDetails(node) {
        console.log("显示设备详情:", node ? node.label : "未知设备")
    }

    function focusOnNode(node) {
        console.log("聚焦到节点:", node.label)
    }

    function hideNode(node) {
        console.log("隐藏节点:", node.label)
    }

    function zoomIn() {
        var newZoom = Math.min(zoomLevel * 1.2, 3.0)
        zoomLevel = newZoom
        updateGraphDisplay()
    }

    function zoomOut() {
        var newZoom = Math.max(zoomLevel * 0.8, 0.5)
        zoomLevel = newZoom
        updateGraphDisplay()
    }

    function resetView() {
        zoomLevel = 1.0
        graphFlickable.contentX = 0
        graphFlickable.contentY = 0
        updateGraphDisplay()
    }

    function refreshGraphLayout() {
        console.log("刷新图谱布局:", layoutMode)
        if (knowledgeGraphController && currentStepId !== "") {
            knowledgeGraphController.generateKnowledgeGraph(currentStepId, currentStepData, selectionConstraints)
        }
    }

    function updateGraphDisplay() {
        edgeCanvas.requestPaint()
    }

    function showErrorMessage(message) {
        console.error("知识图谱错误:", message)
    }

    // 工具函数
    function getStepDisplayName() {
        switch(currentStepId) {
            case "lift_method": return isChineseMode ? "举升方式" : "Lift Method"
            case "pump": return isChineseMode ? "泵选型" : "Pump Selection"
            case "separator": return isChineseMode ? "分离器" : "Separator"
            case "protector": return isChineseMode ? "保护器" : "Protector"
            case "motor": return isChineseMode ? "电机" : "Motor"
            case "report": return isChineseMode ? "报告" : "Report"
            default: return isChineseMode ? "未知" : "Unknown"
        }
    }

    function getLayoutDisplayName() {
        switch(layoutMode) {
            case "force": return isChineseMode ? "力导向" : "Force"
            case "circle": return isChineseMode ? "环形" : "Circle"
            case "grid": return isChineseMode ? "网格" : "Grid"
            case "tree": return isChineseMode ? "树形" : "Tree"
            default: return layoutMode
        }
    }

    function getNodeSize(nodeData) {
        if (!nodeData) return 60

        var baseSize = 60
        var importanceBonus = (nodeData.importance || 1) * 8
        var selectedBonus = selectedNode && selectedNode.id === nodeData.id ? 10 : 0

        return baseSize + importanceBonus + selectedBonus
    }

    function getNodeColor(nodeData) {
        if (!nodeData || !nodeData.type) return "#2196F3"

        switch(nodeData.type) {
            case "pump_candidate":
            case "pump": return "#4CAF50"
            case "motor_option":
            case "motor": return "#FF9800"
            case "protector_option":
            case "protector": return "#9C27B0"
            case "separator_option":
            case "separator": return "#00BCD4"
            case "current_step":
            case "decision": return "#2196F3"
            case "constraint": return "#F44336"
            case "requirement": return "#03A9F4"
            case "lift_option": return "#795548"
            case "input": return "#607D8B"
            default: return "#9E9E9E"
        }
    }

    function getDisplayLabel(nodeData) {
        if (!nodeData || !nodeData.label) return "未知"

        var lines = nodeData.label.split('\n')
        var result = ""
        for (var i = 0; i < Math.min(lines.length, 2); i++) {
            var line = lines[i]
            if (line.length > 10) {
                line = line.substring(0, 8) + "..."
            }
            result += line
            if (i < Math.min(lines.length, 2) - 1) result += "\n"
        }
        return result
    }

    function getDetailedTooltip(node) {
        if (!node) return ""

        var tooltip = node.label || "未知节点"

        if (node.type) {
            tooltip += "\n" + (isChineseMode ? "类型: " : "Type: ") + node.type
        }

        if (node.importance) {
            tooltip += "\n" + (isChineseMode ? "重要性: " : "Importance: ") + node.importance
        }

        if (node.matchScore !== undefined) {
            tooltip += "\n" + (isChineseMode ? "匹配度: " : "Match: ") + (node.matchScore * 100).toFixed(0) + "%"
        }

        if (node.specs) {
            if (node.type === "pump") {
                tooltip += "\n" + (isChineseMode ? "流量: " : "Flow: ") + (node.specs.maxFlow || 'N/A') + " bbl/d"
                tooltip += "\n" + (isChineseMode ? "效率: " : "Efficiency: ") + (node.specs.efficiency || 'N/A') + "%"
            } else if (node.type === "motor") {
                tooltip += "\n" + (isChineseMode ? "功率: " : "Power: ") + (node.specs.power || 'N/A') + " HP"
                tooltip += "\n" + (isChineseMode ? "电压: " : "Voltage: ") + (node.specs.voltage || 'N/A') + " V"
            }
        }

        return tooltip
    }

    function getNodeDescription(node) {
        if (!node) return ""

        switch(node.type) {
            case "pump":
                var specs = node.specs || {}
                return isChineseMode ?
                    `最大流量: ${specs.maxFlow || 'N/A'} bbl/d\n效率: ${specs.efficiency || 'N/A'}%\n级数: ${specs.stages || 'N/A'}` :
                    `Max Flow: ${specs.maxFlow || 'N/A'} bbl/d\nEfficiency: ${specs.efficiency || 'N/A'}%\nStages: ${specs.stages || 'N/A'}`
            case "motor":
                var specs = node.specs || {}
                return isChineseMode ?
                    `功率: ${specs.power || 'N/A'} HP\n电压: ${specs.voltage || 'N/A'} V\n频率: ${specs.frequency || 60} Hz` :
                    `Power: ${specs.power || 'N/A'} HP\nVoltage: ${specs.voltage || 'N/A'} V\nFrequency: ${specs.frequency || 60} Hz`
            case "protector":
                var specs = node.specs || {}
                return isChineseMode ?
                    `推力容量: ${specs.thrustCapacity || 'N/A'} lbs\n扭矩容量: ${specs.torqueCapacity || 'N/A'} ft-lbs` :
                    `Thrust Capacity: ${specs.thrustCapacity || 'N/A'} lbs\nTorque Capacity: ${specs.torqueCapacity || 'N/A'} ft-lbs`
            case "separator":
                var specs = node.specs || {}
                return isChineseMode ?
                    `分离效率: ${specs.efficiency || 'N/A'}%\n气体处理能力: ${specs.gasCapacity || 'N/A'} scfm` :
                    `Separation Efficiency: ${specs.efficiency || 'N/A'}%\nGas Capacity: ${specs.gasCapacity || 'N/A'} scfm`
            default:
                return isChineseMode ? "点击查看详细信息" : "Click for detailed information"
        }
    }

    function getMatchScoreColor(score) {
        if (!score) return "#9E9E9E"

        if (score >= 0.8) return "#4CAF50"
        else if (score >= 0.6) return "#FF9800"
        else if (score >= 0.4) return "#FFC107"
        else return "#F44336"
    }

    function getCardColor(cardData) {
        if (!cardData || !cardData.type) return "#FFFFFF"

        switch(cardData.type) {
            case "primary": return "#E3F2FD"
            case "secondary": return "#F3E5F5"
            case "info": return "#E8F5E8"
            case "warning": return "#FFF3E0"
            default: return "#FFFFFF"
        }
    }

    function getBorderColor(cardData) {
        if (!cardData || !cardData.type) return "#E0E0E0"

        switch(cardData.type) {
            case "primary": return "#2196F3"
            case "secondary": return "#9C27B0"
            case "info": return "#4CAF50"
            case "warning": return "#FF9800"
            default: return "#E0E0E0"
        }
    }

    function updateStepData(stepId, stepData, constraints) {
        console.log("知识图谱窗口接收步骤数据更新:", stepId)
        currentStepId = stepId
        currentStepData = stepData
        selectionConstraints = constraints
        refreshGraphData()
    }
}
