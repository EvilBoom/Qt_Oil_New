import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: canvas
    
    property bool isChineseMode: true
    property bool isMetric: false
    property string currentStepId: ""
    property var stepData: ({})
    property var constraints: ({})
    
    // 信号定义
    signal nodeClicked(var nodeData)
    signal relationshipClicked(var relationData)
    
    color: "white"
    
    // 图谱数据模型
    property var graphNodes: []
    property var graphEdges: []
    property var nodePositions: ({})
    
    // 画布组件
    Canvas {
        id: graphCanvas
        anchors.fill: parent
        
        onPaint: {
            drawGraph()
        }
        
        function drawGraph() {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            // 绘制边（连接线）
            drawEdges(ctx)
            
            // 绘制节点
            drawNodes(ctx)
        }
        
        function drawNodes(ctx) {
            for (var i = 0; i < graphNodes.length; i++) {
                var node = graphNodes[i]
                var pos = nodePositions[node.id] || { x: 100 + i * 150, y: 100 + (i % 3) * 100 }
                
                // 节点样式
                var nodeColor = getNodeColor(node.type, node.status)
                var nodeRadius = getNodeRadius(node.importance)
                
                // 绘制节点圆圈
                ctx.beginPath()
                ctx.arc(pos.x, pos.y, nodeRadius, 0, 2 * Math.PI)
                ctx.fillStyle = nodeColor
                ctx.fill()
                ctx.strokeStyle = getNodeBorderColor(node.selected)
                ctx.lineWidth = node.selected ? 3 : 1
                ctx.stroke()
                
                // 绘制节点图标
                ctx.fillStyle = "white"
                ctx.font = (nodeRadius * 0.8) + "px Arial"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(node.icon || "⚙️", pos.x, pos.y)
                
                // 绘制节点标签
                ctx.fillStyle = "#333"
                ctx.font = "12px Arial"
                ctx.fillText(node.label, pos.x, pos.y + nodeRadius + 15)
            }
        }
        
        function drawEdges(ctx) {
            for (var i = 0; i < graphEdges.length; i++) {
                var edge = graphEdges[i]
                var fromPos = nodePositions[edge.from] || { x: 100, y: 100 }
                var toPos = nodePositions[edge.to] || { x: 200, y: 200 }
                
                // 绘制连接线
                ctx.beginPath()
                ctx.moveTo(fromPos.x, fromPos.y)
                ctx.lineTo(toPos.x, toPos.y)
                ctx.strokeStyle = getEdgeColor(edge.type, edge.strength)
                ctx.lineWidth = getEdgeWidth(edge.strength)
                ctx.stroke()
                
                // 绘制箭头
                drawArrow(ctx, fromPos, toPos, edge.type)
                
                // 绘制关系标签
                var midX = (fromPos.x + toPos.x) / 2
                var midY = (fromPos.y + toPos.y) / 2
                ctx.fillStyle = "#666"
                ctx.font = "10px Arial"
                ctx.textAlign = "center"
                ctx.fillText(edge.label, midX, midY - 10)
            }
        }
        
        function drawArrow(ctx, from, to, edgeType) {
            var angle = Math.atan2(to.y - from.y, to.x - from.x)
            var arrowLength = 10
            var arrowAngle = 0.3
            
            ctx.beginPath()
            ctx.moveTo(to.x - arrowLength * Math.cos(angle - arrowAngle), 
                      to.y - arrowLength * Math.sin(angle - arrowAngle))
            ctx.lineTo(to.x, to.y)
            ctx.lineTo(to.x - arrowLength * Math.cos(angle + arrowAngle), 
                      to.y - arrowLength * Math.sin(angle + arrowAngle))
            ctx.stroke()
        }
    }
    
    // 鼠标交互处理
    MouseArea {
        anchors.fill: parent
        
        onClicked: function(mouse) {
            var clickedNode = findNodeAtPosition(mouse.x, mouse.y)
            if (clickedNode) {
                handleNodeClick(clickedNode)
            }
        }
        
        onPositionChanged: function(mouse) {
            var hoveredNode = findNodeAtPosition(mouse.x, mouse.y)
            updateHoverState(hoveredNode)
        }
    }
    
    // // 节点交互层
    // Repeater {
    //     model: graphNodes
        
    //     Rectangle {
    //         id: nodeInteractionArea
    //         property var nodeData: modelData
            
    //         x: (nodePositions[nodeData.id] || { x: 100 }).x - width/2
    //         y: (nodePositions[nodeData.id] || { y: 100 }).y - height/2
    //         width: getNodeRadius(nodeData.importance) * 2
    //         height: width
            
    //         color: "transparent"
    //         radius: width / 2
            
    //         MouseArea {
    //             anchors.fill: parent
    //             hoverEnabled: true
                
    //             onClicked: {
    //                 console.log("节点被点击:", nodeData.label)
    //                 canvas.nodeClicked(nodeData)
    //             }
                
    //             onEntered: {
    //                 parent.color = "#e3f2fd"
    //                 showNodeTooltip(nodeData)
    //             }
                
    //             onExited: {
    //                 parent.color = "transparent"
    //                 hideNodeTooltip()
    //             }
    //         }
    //     }
    // }
    

    // 在graphCanvas内添加拖拽节点组件
    Repeater {
        model: graphCanvas.nodes

        Rectangle {
            id: draggableNode
            property var nodeData: modelData
            property bool isDragging: false

            x: (graphCanvas.layout[nodeData.id] ? graphCanvas.layout[nodeData.id].x : 0) - width/2
            y: (graphCanvas.layout[nodeData.id] ? graphCanvas.layout[nodeData.id].y : 0) - height/2

            width: (nodeData.size || 25) * 2
            height: width

            color: "transparent"
            radius: width / 2
            border.color: isDragging ? "#FF5722" : "transparent"
            border.width: isDragging ? 2 : 0

            // 🔥 节点内容
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 4
                height: parent.height - 4
                radius: width / 2
                color: nodeData.color || "#2196F3"
                border.color: graphCanvas.selectedNode && graphCanvas.selectedNode.id === nodeData.id ? "#FF5722" : "#666"
                border.width: graphCanvas.selectedNode && graphCanvas.selectedNode.id === nodeData.id ? 3 : 1

                // 阴影效果
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.leftMargin: 2
                    color: "#20000000"
                    radius: parent.radius
                    z: -1
                }

                Text {
                    anchors.centerIn: parent
                    text: nodeData.icon || "⚙️"
                    font.pixelSize: parent.width * 0.3
                    color: "white"
                }
            }

            // 节点标签
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 5
                text: nodeData.label ? nodeData.label.split('\n')[0] : ""
                font.pixelSize: 10
                color: "#333"
                horizontalAlignment: Text.AlignHCenter

                // 限制标签长度
                property string originalText: nodeData.label ? nodeData.label.split('\n')[0] : ""
                Component.onCompleted: {
                    if (originalText.length > 10) {
                        text = originalText.substring(0, 8) + "..."
                    }
                }
            }

            // 🔥 拖拽处理
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                property point startPoint
                property point nodeStartPoint

                onPressed: function(mouse) {
                    startPoint = Qt.point(mouse.x, mouse.y)
                    nodeStartPoint = Qt.point(parent.x, parent.y)
                    parent.isDragging = true
                    parent.z = 1000 // 拖拽时置顶
                }

                onPositionChanged: function(mouse) {
                    if (parent.isDragging) {
                        var dx = mouse.x - startPoint.x
                        var dy = mouse.y - startPoint.y

                        var newX = nodeStartPoint.x + dx
                        var newY = nodeStartPoint.y + dy

                        // 边界限制
                        var margin = parent.width / 2
                        newX = Math.max(margin, Math.min(graphCanvas.width - margin, newX))
                        newY = Math.max(margin, Math.min(graphCanvas.height - margin, newY))

                        parent.x = newX
                        parent.y = newY

                        // 更新布局数据
                        if (graphCanvas.layout[nodeData.id]) {
                            graphCanvas.layout[nodeData.id].x = newX + parent.width/2
                            graphCanvas.layout[nodeData.id].y = newY + parent.height/2
                        }

                        // 重绘连接线
                        canvas.requestPaint()
                    }
                }

                onReleased: function(mouse) {
                    parent.isDragging = false
                    parent.z = 0

                    // 检查是否为点击
                    var dx = Math.abs(mouse.x - startPoint.x)
                    var dy = Math.abs(mouse.y - startPoint.y)

                    if (dx < 5 && dy < 5) {
                        // 视为点击事件
                        graphCanvas.selectedNode = nodeData
                        graphCanvas.showNodeDetails(nodeData)
                        canvas.requestPaint()
                    }
                }

                onDoubleClicked: function(mouse) {
                    if (nodeData.deviceData) {
                        graphCanvas.showDeviceDetails(nodeData)
                    }
                }
            }

            // 悬停提示
            Rectangle {
                id: hoverTooltip
                visible: false
                z: 2000

                width: tooltipContent.width + 16
                height: tooltipContent.height + 12
                color: "#333"
                radius: 4

                anchors.bottom: parent.top
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    id: tooltipContent
                    anchors.centerIn: parent
                    text: getNodeTooltip(nodeData)
                    color: "white"
                    font.pixelSize: 11
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                onEntered: {
                    hoverTooltip.visible = true
                }

                onExited: {
                    hoverTooltip.visible = false
                }
            }
        }
    }
    // 工具提示
    Rectangle {
        id: tooltip
        visible: false
        z: 1000
        
        width: tooltipText.width + 20
        height: tooltipText.height + 16
        color: "#333"
        radius: 4
        
        Text {
            id: tooltipText
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 12
        }
    }
    
    // 图谱数据生成和更新
    function updateGraph() {
        console.log("更新知识图谱，当前步骤:", currentStepId)
        generateGraphData()
        layoutNodes()
        graphCanvas.requestPaint()
    }

    // 添加工具函数
    function getNodeTooltip(node) {
        if (!node) return ""

        var tooltip = node.label
        if (node.specs) {
            if (node.type === "pump") {
                tooltip += `\n流量: ${node.specs.maxFlow || 'N/A'} bbl/d`
                tooltip += `\n效率: ${node.specs.efficiency || 'N/A'}%`
            } else if (node.type === "motor") {
                tooltip += `\n功率: ${node.specs.power || 'N/A'} HP`
                tooltip += `\n电压: ${node.specs.voltage || 'N/A'} V`
            }
        }

        return tooltip
    }

    function generateGraphData() {
        var nodes = []
        var edges = []
        
        switch(currentStepId) {
            case "lift_method":
                nodes = generateLiftMethodNodes()
                edges = generateLiftMethodEdges()
                break
            case "pump":
                nodes = generatePumpSelectionNodes()
                edges = generatePumpSelectionEdges()
                break
            case "separator":
                nodes = generateSeparatorNodes()
                edges = generateSeparatorEdges()
                break
            case "protector":
                nodes = generateProtectorNodes()
                edges = generateProtectorEdges()
                break
            case "motor":
                nodes = generateMotorNodes()
                edges = generateMotorEdges()
                break
            default:
                nodes = generateDefaultNodes()
                edges = generateDefaultEdges()
        }
        
        graphNodes = nodes
        graphEdges = edges
        
        console.log("生成图谱节点:", nodes.length, "个，边:", edges.length, "条")
    }
    
    function generateLiftMethodNodes() {
        var nodes = [
            {
                id: "production_params",
                label: isChineseMode ? "生产参数" : "Production Params",
                type: "parameter",
                icon: "📊",
                importance: 3,
                status: "completed",
                selected: false
            },
            {
                id: "esp_method",
                label: isChineseMode ? "ESP举升" : "ESP Lift",
                type: "lift_method",
                icon: "⚡",
                importance: 3,
                status: stepData.lift_method?.selectedMethod === "esp" ? "selected" : "available",
                selected: stepData.lift_method?.selectedMethod === "esp"
            },
            {
                id: "pcp_method",
                label: isChineseMode ? "PCP举升" : "PCP Lift",
                type: "lift_method",
                icon: "🔄",
                importance: 2,
                status: stepData.lift_method?.selectedMethod === "pcp" ? "selected" : "available",
                selected: stepData.lift_method?.selectedMethod === "pcp"
            },
            {
                id: "jet_method",
                label: isChineseMode ? "JET举升" : "JET Lift",
                type: "lift_method",
                icon: "💨",
                importance: 1,
                status: stepData.lift_method?.selectedMethod === "jet" ? "selected" : "available",
                selected: stepData.lift_method?.selectedMethod === "jet"
            },
            {
                id: "well_conditions",
                label: isChineseMode ? "井况条件" : "Well Conditions",
                type: "condition",
                icon: "🛢️",
                importance: 2,
                status: "parameter",
                selected: false
            }
        ]
        
        return nodes
    }
    
    function generateLiftMethodEdges() {
        return [
            {
                from: "production_params",
                to: "esp_method",
                type: "influences",
                label: isChineseMode ? "适用条件" : "Suitable",
                strength: 0.8
            },
            {
                from: "production_params",
                to: "pcp_method",
                type: "influences",
                label: isChineseMode ? "适用条件" : "Suitable",
                strength: 0.6
            },
            {
                from: "well_conditions",
                to: "esp_method",
                type: "constraints",
                label: isChineseMode ? "约束" : "Constraints",
                strength: 0.7
            },
            {
                from: "well_conditions",
                to: "jet_method",
                type: "influences",
                label: isChineseMode ? "适用" : "Applies",
                strength: 0.5
            }
        ]
    }
    
    function generatePumpSelectionNodes() {
        var nodes = [
            {
                id: "lift_method_result",
                label: isChineseMode ? "已选举升方式" : "Selected Lift Method",
                type: "result",
                icon: "✅",
                importance: 3,
                status: "completed",
                selected: false
            },
            {
                id: "pump_performance",
                label: isChineseMode ? "泵性能要求" : "Pump Performance",
                type: "requirement",
                icon: "⚙️",
                importance: 3,
                status: "analyzing",
                selected: false
            },
            {
                id: "centrifugal_pump",
                label: isChineseMode ? "离心泵" : "Centrifugal Pump",
                type: "pump_type",
                icon: "🔄",
                importance: 2,
                status: "available",
                selected: stepData.pump?.type === "centrifugal"
            },
            {
                id: "multistage_pump",
                label: isChineseMode ? "多级泵" : "Multistage Pump",
                type: "pump_type",
                icon: "🔗",
                importance: 2,
                status: "available",
                selected: stepData.pump?.stages > 50
            },
            {
                id: "efficiency_factor",
                label: isChineseMode ? "效率要求" : "Efficiency Req",
                type: "constraint",
                icon: "📈",
                importance: 2,
                status: "constraint",
                selected: false
            }
        ]
        
        return nodes
    }
    
    function generatePumpSelectionEdges() {
        return [
            {
                from: "lift_method_result",
                to: "pump_performance",
                type: "determines",
                label: isChineseMode ? "决定" : "Determines",
                strength: 0.9
            },
            {
                from: "pump_performance",
                to: "centrifugal_pump",
                type: "suggests",
                label: isChineseMode ? "推荐" : "Suggests",
                strength: 0.8
            },
            {
                from: "pump_performance",
                to: "multistage_pump",
                type: "requires",
                label: isChineseMode ? "需要" : "Requires",
                strength: 0.7
            },
            {
                from: "efficiency_factor",
                to: "centrifugal_pump",
                type: "influences",
                label: isChineseMode ? "影响" : "Influences",
                strength: 0.6
            }
        ]
    }
    
    function generateDefaultNodes() {
        return [
            {
                id: "current_step",
                label: isChineseMode ? "当前步骤" : "Current Step",
                type: "current",
                icon: "📍",
                importance: 3,
                status: "active",
                selected: true
            }
        ]
    }
    
    function generateDefaultEdges() {
        return []
    }
    
    function layoutNodes() {
        var positions = {}
        var centerX = canvas.width / 2
        var centerY = canvas.height / 2
        var radius = Math.min(canvas.width, canvas.height) / 3
        
        for (var i = 0; i < graphNodes.length; i++) {
            var angle = (i / graphNodes.length) * 2 * Math.PI
            positions[graphNodes[i].id] = {
                x: centerX + radius * Math.cos(angle),
                y: centerY + radius * Math.sin(angle)
            }
        }
        
        nodePositions = positions
    }
    
    // 样式函数
    function getNodeColor(type, status) {
        switch(status) {
            case "selected": return "#2196F3"  // 蓝色
            case "completed": return "#4CAF50" // 绿色
            case "active": return "#FF9800"    // 橙色
            case "available": return "#9E9E9E" // 灰色
            case "constraint": return "#F44336" // 红色
            default: return "#607D8B"          // 蓝灰色
        }
    }
    
    function getNodeBorderColor(selected) {
        return selected ? "#1976D2" : "#BDBDBD"
    }
    
    function getNodeRadius(importance) {
        return 20 + importance * 8
    }
    
    function getEdgeColor(type, strength) {
        switch(type) {
            case "determines": return "#2196F3"
            case "influences": return "#FF9800"
            case "requires": return "#F44336"
            case "suggests": return "#4CAF50"
            case "constraints": return "#9C27B0"
            default: return "#757575"
        }
    }
    
    function getEdgeWidth(strength) {
        return 1 + strength * 3
    }
    
    // 交互函数
    function findNodeAtPosition(x, y) {
        for (var i = 0; i < graphNodes.length; i++) {
            var node = graphNodes[i]
            var pos = nodePositions[node.id] || { x: 100, y: 100 }
            var radius = getNodeRadius(node.importance)
            
            var distance = Math.sqrt(Math.pow(x - pos.x, 2) + Math.pow(y - pos.y, 2))
            if (distance <= radius) {
                return node
            }
        }
        return null
    }
    
    function handleNodeClick(node) {
        console.log("处理节点点击:", node.label)
        // 更新选中状态
        for (var i = 0; i < graphNodes.length; i++) {
            graphNodes[i].selected = (graphNodes[i].id === node.id)
        }
        graphCanvas.requestPaint()
        canvas.nodeClicked(node)
    }
    
    function showNodeTooltip(node) {
        tooltipText.text = node.label + "\n" + (isChineseMode ? "类型: " : "Type: ") + node.type
        tooltip.visible = true
    }
    
    function hideNodeTooltip() {
        tooltip.visible = false
    }
    
    function updateHoverState(hoveredNode) {
        // 实现悬停状态更新逻辑
    }
}
