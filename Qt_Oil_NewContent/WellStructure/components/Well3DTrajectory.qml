import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// 🔥 修复：添加Qt Quick 3D导入
import QtQuick3D
import QtQuick3D.Helpers

import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    property bool isChineseMode: true
    property var trajectoryData: null
    property bool isMetric: true
    property real wellDepth: 1000
    property real maxHorizontalOffset: 500

    // 🔥 3D视图控制属性
    property real cameraDistance: 3500  // 🔥 调整相机距离
    property real cameraRotationX: -30
    property real cameraRotationY: 60
    property bool showWellbore: true
    property bool showCasing: false
    property bool showCoordinateSystem: true
    property bool showDepthLabels: true

    // 🔥 移除假数据相关属性
    property bool useRealData: true  // 🔥 强制使用真实数据

    // 🔥 数据状态属性
    property bool dataLoaded: false
    property bool isLoadingData: false
    property string dataSource: ""

    width: 800
    height: 600
    color: "#f0f0f0"

    // 🔥 改进的3D可用性检测
    property bool canUse3D: {
        try {
            return quick3DAvailable !== undefined && quick3DAvailable === true
        } catch (e) {
            console.log("3D检测错误:", e)
            return false
        }
    }

    // 🔥 连接真实数据源
    Connections {
        target: wellStructureController
        enabled: wellStructureController !== null

        function onTrajectoryDataLoaded(data) {
            console.log("🔥 接收到真实轨迹数据:", data ? data.length : 0, "个点")
            if (data && data.length > 0) {
                loadRealTrajectoryData(data)
            } else {
                console.warn("❌ 接收到的轨迹数据为空")
                trajectoryData = null
                dataLoaded = false
                dataSource = "数据库 - 无数据"
            }
        }

        function onError(errorMsg) {
            console.error("❌ 井结构控制器错误:", errorMsg)
            dataSource = "错误: " + errorMsg
            isLoadingData = false
        }

        function onOperationStarted() {
            isLoadingData = true
        }

        function onOperationFinished() {
            isLoadingData = false
        }
    }

    // 🔥 如果Qt Quick 3D不可用，显示替代内容
    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: canUse3D ? 260 : 0
        color: "#f0f0f0"
        visible: !canUse3D

        Column {
            anchors.centerIn: parent
            spacing: 25

            Text {
                text: "🔧"
                font.pixelSize: 72
                color: "#999"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: isChineseMode ?
                      `Qt Quick 3D 模块不可用\n请安装 Qt Quick 3D 模块以启用3D井轨迹显示` :
                      `Qt Quick 3D Module Unavailable\nPlease install Qt Quick 3D module for 3D well trajectory display`
                font.pixelSize: 14
                color: "#666"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                lineHeight: 1.3
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: isChineseMode ? "重新加载数据" : "Reload Data"
                onClicked: requestRealData()
            }

            // 🔥 2D替代显示
            Rectangle {
                width: 500
                height: 350
                color: "white"
                border.color: "#ddd"
                radius: 8
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 10
                    text: isChineseMode ? "2D 井轨迹显示 (俯视图)" : "2D Well Trajectory Display (Top View)"
                    font.pixelSize: 12
                    color: "#666"
                    font.bold: true
                }

                Canvas {
                    id: canvas2D
                    anchors.fill: parent
                    anchors.margins: 30
                    onPaint: draw2DTrajectory()
                }
            }
        }
    }

    // 🔥 3D场景 - 只显示真实数据
    View3D {
        id: view3d
        anchors.fill: parent
        anchors.rightMargin: 260
        visible: canUse3D

        environment: SceneEnvironment {
            clearColor: "#87CEEB"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        PerspectiveCamera {
            id: mainCamera
            position: calculateCameraPosition()
            lookAtNode: wellScene
            fieldOfView: 45
            clipFar: 50000
            clipNear: 1
        }

        // 照明系统
        DirectionalLight {
            position: Qt.vector3d(2000, 3000, 1000)
            rotation: Qt.vector3d(-30, -45, 0)
            brightness: 1.2
            castsShadow: true
        }

        DirectionalLight {
            position: Qt.vector3d(-1000, 2000, -1000)
            rotation: Qt.vector3d(-20, 135, 0)
            brightness: 0.8
        }

        DirectionalLight {
            brightness: 0.4
            ambientColor: Qt.rgba(0.4, 0.4, 0.5, 1.0)
        }

        // 🔥 井场景根节点
        Node {
            id: wellScene
            position: Qt.vector3d(0, 0, 0)

            // 🔥 地表 - 调整尺寸
            Model {
                id: ground
                source: "#Cube"
                scale: Qt.vector3d(30, 0.2, 30)  // 🔥 适中的地面尺寸
                position: Qt.vector3d(0, 10, 0)
                materials: DefaultMaterial {
                    diffuseColor: "#8FBC8F"
                }
            }

            // 🔥 坐标系统 - 调大
            Node {
                id: coordinateSystem
                visible: showCoordinateSystem

                // X轴（东向，红色）
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(2.0, 15, 2.0)  // 🔥 调大坐标轴
                    position: Qt.vector3d(500, 0, 0)  // 🔥 调远位置
                    rotation: Qt.vector3d(0, 0, 90)
                    materials: DefaultMaterial {
                        diffuseColor: "#FF0000"
                    }
                }

                // Y轴（向下，绿色）
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(2.0, 15, 2.0)
                    position: Qt.vector3d(0, -500, 0)
                    materials: DefaultMaterial {
                        diffuseColor: "#00FF00"
                    }
                }

                // Z轴（北向，蓝色）
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(2.0, 15, 2.0)
                    position: Qt.vector3d(0, 0, 500)
                    rotation: Qt.vector3d(90, 0, 0)
                    materials: DefaultMaterial {
                        diffuseColor: "#0000FF"
                    }
                }
            }

            // 🔥 井轨迹主体 - 只显示真实数据
            Node {
                id: wellTrajectoryNode
                visible: trajectoryData && trajectoryData.length > 0

                // 🔥 井口标记 - 调小尺寸
                Model {
                    id: wellhead
                    source: "#Sphere"
                    scale: Qt.vector3d(8, 8, 8)  // 🔥 减小井口标记
                    position: Qt.vector3d(0, 0, 0)
                    materials: DefaultMaterial {
                        diffuseColor: "#00FF00"
                    }
                }

                // 🔥 井轨迹路径点 - 调小尺寸
                Repeater3D {
                    id: trajectoryRepeater
                    model: trajectoryData ? trajectoryData.length : 0

                    delegate: Model {
                        required property int index
                        source: "#Sphere"
                        scale: Qt.vector3d(3, 3, 3)  // 🔥 减小轨迹点
                        position: safeGetTrajectoryPoint(index)
                        materials: DefaultMaterial {
                            diffuseColor: safeGetPointColor(index)
                        }
                    }
                }

                // 🔥 井筒管道 - 调小尺寸
                Repeater3D {
                    id: wellboreRepeater
                    model: trajectoryData && showWellbore ? Math.max(0, trajectoryData.length - 1) : 0

                    delegate: Model {
                        required property int index
                        source: "#Cylinder"
                        scale: safeGetEnhancedSegmentScale(index)
                        position: safeGetSegmentPosition(index)
                        rotation: safeGetSegmentRotation(index)
                        materials: DefaultMaterial {
                            diffuseColor: "#444444"
                        }
                    }
                }

                // 🔥 井底标记 - 调小尺寸
                Model {
                    id: wellbottom
                    source: "#Sphere"
                    scale: Qt.vector3d(6, 6, 6)  // 🔥 减小井底标记
                    position: trajectoryData && trajectoryData.length > 0 ?
                              safeGetTrajectoryPoint(trajectoryData.length - 1) :
                              Qt.vector3d(0, 0, 0)
                    materials: DefaultMaterial {
                        diffuseColor: "#FF0000"
                    }
                }
            }

            // 🔥 无数据状态显示
            Text {
                anchors.centerIn: parent
                text: isChineseMode ?
                      (isLoadingData ? "正在加载轨迹数据..." : "无轨迹数据") :
                      (isLoadingData ? "Loading trajectory data..." : "No trajectory data")
                font.pixelSize: 32
                color: "#666"
                visible: !trajectoryData || trajectoryData.length === 0
            }
        }
    }

    // 🔥 右侧控制面板 - 移除假数据生成
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 5
        width: 250
        color: "white"
        radius: 8
        border.color: "#ddd"

        ScrollView {
            anchors.fill: parent
            anchors.margins: 15

            ColumnLayout {
                width: parent.width - 30
                spacing: 15

                Text {
                    text: isChineseMode ? "3D井轨迹显示" : "3D Well Trajectory Display"
                    font.pixelSize: 16
                    font.bold: true
                }

                // 🔥 数据状态显示
                Rectangle {
                    Layout.fillWidth: true
                    height: 120
                    color: dataLoaded ? "#e8f5e8" : "#fee"
                    border.color: dataLoaded ? "#4CAF50" : "#f44336"
                    radius: 4

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dataLoaded ? "✅ 数据已加载" : "❌ 无数据"
                            font.pixelSize: 12
                            font.bold: true
                            color: dataLoaded ? "#2E7D32" : "#C62828"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `轨迹点: ${trajectoryData ? trajectoryData.length : 0}`
                            font.pixelSize: 10
                            color: "#666"
                            font.bold: trajectoryData && trajectoryData.length > 0
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `数据来源: ${dataSource}`
                            font.pixelSize: 9
                            color: "#666"
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isLoadingData ? "加载中..." : "就绪"
                            font.pixelSize: 9
                            color: isLoadingData ? "#FF9800" : "#4CAF50"
                        }
                    }
                }

                // 相机控制
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "视角控制" : "Camera Control"
                    enabled: canUse3D && dataLoaded

                    ColumnLayout {
                        width: parent.width
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: isChineseMode ? "水平:" : "Horizontal:"
                                Layout.preferredWidth: 60
                                font.pixelSize: 11
                            }
                            Slider {
                                Layout.fillWidth: true
                                from: 0; to: 360; value: cameraRotationY
                                onValueChanged: {
                                    cameraRotationY = value
                                    updateCameraPosition()
                                }
                            }
                            Text {
                                text: cameraRotationY.toFixed(0) + "°"
                                Layout.preferredWidth: 35
                                font.pixelSize: 10
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: isChineseMode ? "垂直:" : "Vertical:"
                                Layout.preferredWidth: 60
                                font.pixelSize: 11
                            }
                            Slider {
                                Layout.fillWidth: true
                                from: -80; to: 80; value: cameraRotationX
                                onValueChanged: {
                                    cameraRotationX = value
                                    updateCameraPosition()
                                }
                            }
                            Text {
                                text: cameraRotationX.toFixed(0) + "°"
                                Layout.preferredWidth: 35
                                font.pixelSize: 10
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: isChineseMode ? "距离:" : "Distance:"
                                Layout.preferredWidth: 60
                                font.pixelSize: 11
                            }
                            Slider {
                                Layout.fillWidth: true
                                from: 1000; to: 8000; value: cameraDistance
                                onValueChanged: {
                                    cameraDistance = value
                                    updateCameraPosition()
                                }
                            }
                            Text {
                                text: (cameraDistance/100).toFixed(0)
                                Layout.preferredWidth: 35
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                // 显示选项
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "显示选项" : "Display Options"
                    enabled: dataLoaded

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        CheckBox {
                            text: isChineseMode ? "显示井筒" : "Show Wellbore"
                            checked: showWellbore
                            onCheckedChanged: showWellbore = checked
                        }

                        CheckBox {
                            text: isChineseMode ? "显示坐标系" : "Show Coordinates"
                            checked: showCoordinateSystem
                            onCheckedChanged: showCoordinateSystem = checked
                        }
                    }
                }

                // 井信息显示
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "井信息" : "Well Information"
                    visible: dataLoaded

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: isChineseMode ?
                                  `轨迹点数: ${trajectoryData ? trajectoryData.length : 0}` :
                                  `Points: ${trajectoryData ? trajectoryData.length : 0}`
                            font.pixelSize: 11
                            font.bold: true
                            color: "#2E7D32"
                        }

                        Text {
                            text: isChineseMode ?
                                  `井深: ${wellDepth.toFixed(0)} ${isMetric ? "m" : "ft"}` :
                                  `Well Depth: ${wellDepth.toFixed(0)} ${isMetric ? "m" : "ft"}`
                            font.pixelSize: 11
                        }

                        Text {
                            text: isChineseMode ?
                                  `水平偏移: ${maxHorizontalOffset.toFixed(0)} ${isMetric ? "m" : "ft"}` :
                                  `Horizontal: ${maxHorizontalOffset.toFixed(0)} ${isMetric ? "m" : "ft"}`
                            font.pixelSize: 11
                        }
                    }
                }

                // 🔥 操作按钮 - 只保留真实数据相关操作
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        Layout.fillWidth: true
                        text: isChineseMode ? "重新加载数据" : "Reload Data"
                        enabled: !isLoadingData
                        onClicked: requestRealData()
                    }

                    Button {
                        Layout.fillWidth: true
                        text: isChineseMode ? "重置视角" : "Reset View"
                        enabled: canUse3D && dataLoaded
                        onClicked: setPresetView(-30, 60, 3500)
                    }

                    Button {
                        Layout.fillWidth: true
                        text: isChineseMode ? "适应视角" : "Fit to View"
                        enabled: canUse3D && dataLoaded
                        onClicked: fitCameraToData()
                    }
                }
            }
        }
    }

    // 🔥 =====================================
    // 🔥 JavaScript函数 - 只处理真实数据
    // 🔥 =====================================

    function calculateCameraPosition() {
        var radX = cameraRotationX * Math.PI / 180
        var radY = cameraRotationY * Math.PI / 180

        var x = cameraDistance * Math.sin(radY) * Math.cos(radX)
        var y = cameraDistance * Math.sin(radX)
        var z = cameraDistance * Math.cos(radY) * Math.cos(radX)

        return Qt.vector3d(x, y, z)
    }

    function updateCameraPosition() {
        if (mainCamera && canUse3D) {
            mainCamera.position = calculateCameraPosition()
        }
    }

    // 🔥 请求真实数据
    function requestRealData() {
        console.log("🔥 请求加载真实井轨迹数据...")
        if (typeof wellStructureController !== "undefined" && wellStructureController.currentWellId > 0) {
            dataSource = "请求中..."
            isLoadingData = true
            wellStructureController.loadTrajectoryData(wellStructureController.currentWellId)
        } else {
            console.warn("❌ 没有有效的井ID或控制器不可用")
            dataSource = "无有效井ID"
        }
    }

    // 🔥 加载真实轨迹数据
    function loadRealTrajectoryData(data) {
        if (!data || data.length === 0) {
            console.warn("❌ 真实数据为空")
            trajectoryData = null
            dataLoaded = false
            dataSource = "数据库 - 无数据"
            return
        }

        try {
            console.log("🔥 处理真实轨迹数据:", data.length, "个点")

            // 🔥 转换数据格式为3D显示需要的格式
            var processedData = []
            var maxDepth = 0
            var maxHorizontal = 0

            for (var i = 0; i < data.length; i++) {
                var point = data[i]

                // 🔥 确保数据字段存在并转换为数字
                var tvd = parseFloat(point.tvd || point.depth || 0)
                var md = parseFloat(point.md || point.measured_depth || 0)
                var east = parseFloat(point.east_west || point.east || point.x || 0)
                var north = parseFloat(point.north_south || point.north || point.z || 0)
                var inclination = parseFloat(point.inclination || 0)
                var azimuth = parseFloat(point.azimuth || 0)

                // 🔥 如果没有坐标数据，根据井斜和方位角计算
                if (east === 0 && north === 0 && inclination > 0) {
                    var horizontalDisp = md * Math.sin(inclination * Math.PI / 180)
                    east = horizontalDisp * Math.sin(azimuth * Math.PI / 180)
                    north = horizontalDisp * Math.cos(azimuth * Math.PI / 180)
                }

                var processedPoint = {
                    tvd: tvd,
                    md: md,
                    east: east,
                    north: north,
                    depth: tvd,  // 兼容字段
                    x: east,     // 兼容字段
                    y: tvd,      // 兼容字段
                    z: north,    // 兼容字段
                    inclination: inclination,
                    azimuth: azimuth,
                    sequence: i + 1
                }

                processedData.push(processedPoint)

                // 更新统计信息
                maxDepth = Math.max(maxDepth, tvd)
                var horizontal = Math.sqrt(east * east + north * north)
                maxHorizontal = Math.max(maxHorizontal, horizontal)
            }

            // 🔥 更新组件状态
            trajectoryData = processedData
            wellDepth = maxDepth
            maxHorizontalOffset = maxHorizontal
            dataLoaded = true
            dataSource = `数据库 - ${processedData.length}点`
            isLoadingData = false

            console.log(`✅ 真实数据加载完成: ${processedData.length}点, 深度=${wellDepth.toFixed(1)}, 水平偏移=${maxHorizontalOffset.toFixed(1)}`)

            // 🔥 自动调整相机视角
            fitCameraToData()

        } catch (e) {
            console.error("❌ 处理真实数据失败:", e)
            dataSource = "处理失败: " + e.toString()
            isLoadingData = false
        }
    }

    // 🔥 根据数据自动调整相机
    function fitCameraToData() {
        if (!trajectoryData || trajectoryData.length === 0) return

        try {
            // 计算数据范围
            var maxRange = Math.max(wellDepth, maxHorizontalOffset)

            // 根据数据范围调整相机距离
            if (maxRange < 500) {
                cameraDistance = 1500
            } else if (maxRange < 2000) {
                cameraDistance = maxRange * 2
            } else {
                cameraDistance = maxRange * 1.5
            }

            // 确保相机距离在合理范围内
            cameraDistance = Math.max(1000, Math.min(8000, cameraDistance))

            updateCameraPosition()
            console.log(`🔥 相机已调整: 距离=${cameraDistance.toFixed(0)}, 数据范围=${maxRange.toFixed(0)}`)

        } catch (e) {
            console.error("调整相机失败:", e)
        }
    }

    // 🔥 获取轨迹点的3D坐标（处理真实数据）
    function safeGetTrajectoryPoint(index) {
        if (!trajectoryData || index < 0 || index >= trajectoryData.length) {
            return Qt.vector3d(0, 0, 0)
        }

        try {
            var point = trajectoryData[index]
            var east = parseFloat(point.east || point.x || 0)
            var depth = parseFloat(point.tvd || point.y || point.depth || 0)
            var north = parseFloat(point.north || point.z || 0)

            return Qt.vector3d(
                east,        // X: 东向
                -depth,      // Y: 深度向下为负
                north        // Z: 北向
            )
        } catch (e) {
            console.log("获取轨迹点错误:", e, "index:", index)
            return Qt.vector3d(0, 0, 0)
        }
    }

    // 🔥 管段缩放（调小井筒）
    function safeGetEnhancedSegmentScale(index) {
        if (!trajectoryData || index < 0 || index >= trajectoryData.length - 1) {
            return Qt.vector3d(1, 1, 1)
        }

        try {
            var point1 = safeGetTrajectoryPoint(index)
            var point2 = safeGetTrajectoryPoint(index + 1)

            var dx = point2.x - point1.x
            var dy = point2.y - point1.y
            var dz = point2.z - point1.z

            var length = Math.sqrt(dx * dx + dy * dy + dz * dz)
            var radius = 1.5  // 🔥 减小井筒半径

            return Qt.vector3d(radius, Math.max(length, 0.1), radius)
        } catch (e) {
            console.log("获取管段缩放错误:", e, "index:", index)
            return Qt.vector3d(1.5, 10, 1.5)
        }
    }

    function safeGetSegmentPosition(index) {
        if (!trajectoryData || index < 0 || index >= trajectoryData.length - 1) {
            return Qt.vector3d(0, 0, 0)
        }

        try {
            var point1 = safeGetTrajectoryPoint(index)
            var point2 = safeGetTrajectoryPoint(index + 1)

            return Qt.vector3d(
                (point1.x + point2.x) / 2,
                (point1.y + point2.y) / 2,
                (point1.z + point2.z) / 2
            )
        } catch (e) {
            console.log("获取管段位置错误:", e, "index:", index)
            return Qt.vector3d(0, 0, 0)
        }
    }

    function safeGetSegmentRotation(index) {
        if (!trajectoryData || index < 0 || index >= trajectoryData.length - 1) {
            return Qt.vector3d(0, 0, 0)
        }

        try {
            var point1 = safeGetTrajectoryPoint(index)
            var point2 = safeGetTrajectoryPoint(index + 1)

            var dx = point2.x - point1.x
            var dy = point2.y - point1.y
            var dz = point2.z - point1.z

            var length = Math.sqrt(dx * dx + dy * dy + dz * dz)
            if (length < 0.001) return Qt.vector3d(0, 0, 0)

            dx /= length
            dy /= length
            dz /= length

            var rotX = Math.asin(dz) * 180 / Math.PI
            var rotZ = -Math.atan2(dx, dy) * 180 / Math.PI

            return Qt.vector3d(rotX, 0, rotZ)
        } catch (e) {
            console.log("获取管段旋转错误:", e, "index:", index)
            return Qt.vector3d(0, 0, 0)
        }
    }

    function safeGetPointColor(index) {
        if (!trajectoryData || index < 0 || index >= trajectoryData.length) {
            return "#2196F3"
        }

        try {
            var point = trajectoryData[index]
            var depth = parseFloat(point.tvd || point.y || point.depth || 0)
            var normalizedDepth = wellDepth > 0 ? depth / wellDepth : 0

            var r, g, b
            if (normalizedDepth < 0.5) {
                r = normalizedDepth * 2
                g = 1.0
                b = 0.2
            } else {
                r = 1.0
                g = 2 * (1 - normalizedDepth)
                b = 0.2
            }

            return Qt.rgba(r, g, b, 1.0)
        } catch (e) {
            console.log("获取点颜色错误:", e, "index:", index)
            return "#2196F3"
        }
    }

    function setPresetView(rotX, rotY, distance) {
        cameraRotationX = rotX
        cameraRotationY = rotY
        cameraDistance = distance
        updateCameraPosition()
    }

    function draw2DTrajectory() {
        if (!trajectoryData || trajectoryData.length === 0) return

        try {
            var ctx = canvas2D.getContext("2d")
            ctx.clearRect(0, 0, canvas2D.width, canvas2D.height)

            var minEast = Math.min(...trajectoryData.map(p => parseFloat(p.east || p.x || 0)))
            var maxEast = Math.max(...trajectoryData.map(p => parseFloat(p.east || p.x || 0)))
            var minNorth = Math.min(...trajectoryData.map(p => parseFloat(p.north || p.z || 0)))
            var maxNorth = Math.max(...trajectoryData.map(p => parseFloat(p.north || p.z || 0)))

            var rangeEast = Math.max(maxEast - minEast, 100)
            var rangeNorth = Math.max(maxNorth - minNorth, 100)
            var scale = Math.min(canvas2D.width / rangeEast, canvas2D.height / rangeNorth) * 0.8

            var centerX = canvas2D.width / 2
            var centerY = canvas2D.height / 2

            ctx.strokeStyle = "#2196F3"
            ctx.lineWidth = 2
            ctx.beginPath()

            for (var i = 0; i < trajectoryData.length; i++) {
                var point = trajectoryData[i]
                var east = parseFloat(point.east || point.x || 0)
                var north = parseFloat(point.north || point.z || 0)

                var x = centerX + east * scale
                var y = centerY - north * scale

                if (i === 0) {
                    ctx.moveTo(x, y)
                } else {
                    ctx.lineTo(x, y)
                }

                ctx.save()
                ctx.fillStyle = safeGetPointColor(i)
                ctx.beginPath()
                ctx.arc(x, y, 3, 0, 2 * Math.PI)
                ctx.fill()
                ctx.restore()
            }
            ctx.stroke()

            // 标记井口和井底
            ctx.fillStyle = "#00FF00"
            ctx.beginPath()
            ctx.arc(centerX, centerY, 8, 0, 2 * Math.PI)
            ctx.fill()

            if (trajectoryData.length > 0) {
                var lastPoint = trajectoryData[trajectoryData.length - 1]
                var lastEast = parseFloat(lastPoint.east || lastPoint.x || 0)
                var lastNorth = parseFloat(lastPoint.north || lastPoint.z || 0)
                var lastX = centerX + lastEast * scale
                var lastY = centerY - lastNorth * scale
                ctx.fillStyle = "#FF0000"
                ctx.beginPath()
                ctx.arc(lastX, lastY, 8, 0, 2 * Math.PI)
                ctx.fill()
            }
        } catch (e) {
            console.log("绘制2D轨迹错误:", e)
        }
    }

    onTrajectoryDataChanged: {
        if (trajectoryData && canvas2D) {
            canvas2D.requestPaint()
        }
    }

    Component.onCompleted: {
        console.log("🔥 3D井轨迹组件初始化 - 仅使用真实数据")
        console.log("Qt Quick 3D可用:", canUse3D)

        // 🔥 启动时尝试加载真实数据
        Qt.callLater(function() {
            requestRealData()
        })
    }
}


/*##^##
Designer {
    D{i:0}D{i:10;cameraSpeed3d:25;cameraSpeed3dMultiplier:1}
}
##^##*/
