// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step6_ProtectorSelection.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 内部属性
    property var selectedProtector: null
    property var availableProtectors: []
    property bool loading: false
    property int protectorCount: 1  // 保护器数量

    // 计算所需推力承载能力
    property real requiredThrustCapacity: {
        if (stepData.pump) {
            // 简化计算：基于泵的级数和单级推力估算
            var stages = stepData.pump.stages || 100
            var thrustPerStage = 50  // lbs/stage (估算值)
            return stages * thrustPerStage
        }
        return 5000  // 默认值
    }

    color: "transparent"

    Component.onCompleted: {
        console.log("=== Step6 保护器选择初始化 ===")
        console.log("stepData:", JSON.stringify(stepData))
        loadProtectors()
    }
    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("Step6中单位制切换为:", isMetric ? "公制" : "英制")
            // 强制更新显示
            updateParameterDisplays()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "保护器选择" : "Protector Selection"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 配置选项
            ComboBox {
                id: protectorTypeFilter
                Layout.preferredWidth: 150
                model: [
                    isChineseMode ? "所有类型" : "All Types",
                    isChineseMode ? "标准型" : "Standard",
                    isChineseMode ? "高温型" : "High Temp",
                    isChineseMode ? "大推力型" : "High Thrust"
                ]
                onCurrentIndexChanged: filterProtectors()
            }
        }

        // 技术要求卡片
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: Material.dialogColor
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 32

                // 推力要求
                Column {
                    spacing: 4

                    Text {
                        text: isChineseMode ? "推力要求" : "Thrust Requirement"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }

                    Text {
                        text: formatForce(requiredThrustCapacity)
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                // 工作温度
                Column {
                    spacing: 4

                    Text {
                        text: isChineseMode ? "工作温度" : "Operating Temp"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }

                    Text {
                        text: {
                            var temp = stepData.parameters ? stepData.parameters.bht : "undefined"
                            if (temp === "undefined" || temp === undefined || temp === null || isNaN(parseFloat(temp))) {
                                return "undefined " + getTemperatureUnit()
                            }
                            return formatTemperature(parseFloat(temp))
                        }
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                // 轴径匹配
                Column {
                    spacing: 4

                    Text {
                        text: isChineseMode ? "轴径要求" : "Shaft Size"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }

                    Text {
                        text: {
                            var shaft = stepData.pump ? stepData.pump.shaftDiameter : "undefined"
                            if (shaft === "undefined" || shaft === undefined || shaft === null || isNaN(parseFloat(shaft))) {
                                return "undefined " + getDiameterUnit()
                            }
                            return formatDiameter(parseFloat(shaft))
                        }
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                // 套管限制
                Column {
                    spacing: 4

                    Text {
                        text: isChineseMode ? "套管限制" : "Casing Limit"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }

                    Text {
                        text: {
                            var casingSize = stepData.well && stepData.well.casingSize ? stepData.well.casingSize : "5.5"
                            return formatDiameter(parseFloat(casingSize))
                        }
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
        }

        // 主内容区域 - 使用简化布局
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3

            // 左侧：保护器列表
            Rectangle {
                id: protectorListRect
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 400
                color: "transparent"

                ScrollView {
                    id: protectorScroll
                    anchors.fill: parent
                    clip: true

                    // 关键：让滚动区域宽度/高度跟随内容实际大小
                    contentWidth: protectorGrid.implicitWidth
                    contentHeight: protectorGrid.implicitHeight

                    GridLayout {
                        id: protectorGrid
                        // 强制 GridLayout 宽度与视口匹配，避免内容过宽
                        width: protectorScroll.width
                        // 基于 ScrollView 视口宽度计算列数（稳定可靠）
                        columns: protectorScroll.width > 800 ? 2 : 1
                        columnSpacing: 16
                        rowSpacing: 16

                        Repeater {
                            model: getFilteredProtectors()

                            // 使用内联的保护器卡片，避免外部组件问题
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 220

                                property var protectorData: modelData
                                property bool isSelected: selectedProtector && selectedProtector.id === modelData.id
                                property int matchScore: calculateProtectorMatchScore(modelData)

                                color: isSelected ? '#F5F5DC' : Material.backgroundColor
                                radius: 8
                                border.width: isSelected ? 2 : 1
                                border.color: isSelected ? Material.DeepPurple : Material.Brown
                                // 推荐标识
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 2
                                    width: 60
                                    height: 20
                                    radius: 12
                                    color: Material.Green
                                    visible: matchScore >= 80

                                    Text {
                                        anchors.centerIn: parent
                                        text: isChineseMode ? "推荐" : "Best"
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selectedProtector = protectorData
                                        updateStepData()
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 12

                                    // 头部信息
                                    RowLayout {
                                        Layout.fillWidth: true

                                        // 图标
                                        Rectangle {
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: Material.color(Material.Blue)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🛡️"
                                                font.pixelSize: 20
                                            }
                                        }

                                        // 标题信息
                                        Column {
                                            Layout.fillWidth: true

                                            Text {
                                                text: protectorData ? protectorData.manufacturer : ""
                                                font.pixelSize: 12
                                                color: Material.hintTextColor
                                            }

                                            Text {
                                                text: protectorData ? protectorData.model : ""
                                                font.pixelSize: 15
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }

                                            Text {
                                                text: protectorData ? protectorData.type : ""
                                                font.pixelSize: 12
                                                color: Material.secondaryTextColor
                                            }
                                        }

                                        // 简化的匹配度显示
                                        Rectangle {
                                            width: 50
                                            height: 50
                                            radius: 25
                                            color: "transparent"
                                            border.width: 3
                                            border.color: {
                                                if (matchScore >= 80) return Material.color(Material.Green)
                                                if (matchScore >= 60) return Material.color(Material.Orange)
                                                return Material.color(Material.Red)
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: matchScore + "%"
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }
                                        }
                                    }

                                    // 分隔线
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: Material.dividerColor
                                    }

                                    // 关键参数
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 16
                                        rowSpacing: 8

                                        // 推力承载能力
                                        Column {
                                            spacing: 2

                                            Text {
                                                text: isChineseMode ? "推力承载" : "Thrust Capacity"
                                                font.pixelSize: 11
                                                color: Material.hintTextColor
                                            }

                                            Text {
                                                text: formatForce(protectorData ? protectorData.thrustCapacity : 0)
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: {
                                                    if (!protectorData || requiredThrustCapacity === 0) return Material.primaryTextColor
                                                    return protectorData.thrustCapacity >= requiredThrustCapacity ?
                                                           Material.color(Material.Green) : Material.color(Material.Red)
                                                }
                                            }
                                        }

                                        // 最高温度
                                        Column {
                                            spacing: 2

                                            Text {
                                                text: isChineseMode ? "最高温度" : "Max Temp"
                                                font.pixelSize: 11
                                                color: Material.hintTextColor
                                            }

                                            Text {
                                                text: formatTemperature(protectorData ? protectorData.maxTemperature : 0)
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }
                                        }

                                        // 密封类型
                                        Column {
                                            spacing: 2

                                            Text {
                                                text: isChineseMode ? "密封类型" : "Seal Type"
                                                font.pixelSize: 11
                                                color: Material.hintTextColor
                                            }

                                            Text {
                                                text: protectorData ? protectorData.sealType : ""
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }
                                        }

                                        // 外径
                                        Column {
                                            spacing: 2

                                            Text {
                                                text: isChineseMode ? "外径" : "OD"
                                                font.pixelSize: 11
                                                color: Material.hintTextColor
                                            }

                                            Text {
                                                text: formatDiameter(protectorData ? protectorData.outerDiameter : 0)
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }
                                        }
                                    }

                                    // 特性描述
                                    Text {
                                        Layout.fillWidth: true
                                        text: protectorData ? protectorData.features : ""
                                        font.pixelSize: 11
                                        color: Material.secondaryTextColor
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // 空状态
                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        visible: !loading && getFilteredProtectors().length === 0
                        z: 1  // 确保在GridLayout之上

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "🛡️"
                            font.pixelSize: 48
                            color: Material.hintTextColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isChineseMode ? "没有找到符合条件的保护器" : "No protectors found matching criteria"
                            color: Material.hintTextColor
                            font.pixelSize: 14
                        }
                    }
                }

                // 加载指示器
                BusyIndicator {
                    anchors.centerIn: parent
                    running: loading
                    visible: running
                    z: 2  // 确保在所有内容之上（包括ScrollView）
                }
            }

            // 右侧：详情面板
            Rectangle {
                Layout.preferredWidth: 400
                Layout.fillHeight: true
                Layout.minimumWidth: 350
                color: Material.dialogColor
                radius: 8
                visible: selectedProtector !== null

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 16
                    clip: true

                    ColumnLayout {
                        width: parent.width - 32
                        spacing: 16

                        // 保护器详情头部
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            color: Material.backgroundColor
                            radius: 8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                // 图标
                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 20
                                    color: Material.color(Material.Blue)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🛡️"
                                        font.pixelSize: 20
                                    }
                                }

                                // 详情信息
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: selectedProtector ? selectedProtector.manufacturer : ""
                                        font.pixelSize: 12
                                        color: Material.secondaryTextColor
                                    }

                                    Text {
                                        text: selectedProtector ? selectedProtector.model : ""
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    Text {
                                        text: selectedProtector ? selectedProtector.type : ""
                                        font.pixelSize: 11
                                        color: Material.hintTextColor
                                    }
                                }

                                // 匹配度
                                Rectangle {
                                    width: 60
                                    height: 60
                                    radius: 30
                                    color: "transparent"
                                    border.width: 3
                                    border.color: {
                                        var score = selectedProtector ? calculateProtectorMatchScore(selectedProtector) : 0
                                        if (score >= 80) return Material.color(Material.Green)
                                        if (score >= 60) return Material.color(Material.Orange)
                                        return Material.color(Material.Red)
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: selectedProtector ? calculateProtectorMatchScore(selectedProtector) + "%" : "0%"
                                            font.pixelSize: 14
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: isChineseMode ? "匹配度" : "Match"
                                            font.pixelSize: 9
                                            color: Material.hintTextColor
                                        }
                                    }
                                }
                            }
                        }

                        // 保护器数量选择
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            color: Material.backgroundColor
                            radius: 8

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    text: isChineseMode ? "保护器配置" : "Protector Configuration"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                RowLayout {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                    spacing: 16

                                    Text {
                                        text: isChineseMode ? "数量：" : "Quantity:"
                                        color: Material.primaryTextColor
                                        font.pixelSize: 13
                                        Layout.alignment: Qt.AlignVCenter  // 垂直居中对齐
                                    }



                                    Repeater {

                                        // model: [1, 2, 3]
                                        model: ["单", "双"] // 一般是单级或着双极

                                        RadioButton {
                                            id: radioButton
                                            Layout.preferredHeight: 40
                                            text: modelData + (isChineseMode ? "级" : "")
                                            checked: protectorCount === modelData
                                            ButtonGroup.group: protectorCountGroup
                                            Layout.alignment: Qt.AlignVCenter  // 垂直居中对齐
                                            // 文本颜色（根据选中状态变化）

                                            // 自定义圆形指示器样式
                                            indicator: Rectangle {
                                                    implicitWidth: 15
                                                    implicitHeight: 15
                                                    radius: 12 // 圆形
                                                    border.width: 2
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom

                                                    anchors.topMargin: 9
                                                    anchors.bottomMargin: 9
                                                    // 边框颜色（选中/未选中状态）
                                                    border.color: checked ? "#2196F3" : "#CCCCCC"
                                                    // 内部填充颜色（选中状态）
                                                    color: checked ? "#2196F3" : "transparent"

                                                    // 选中时的内部小点
                                                    Rectangle {
                                                        visible: checked
                                                        width: 8
                                                        height: 8
                                                        radius: 4
                                                        color: "white"
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                            onCheckedChanged: {
                                                if (checked) {
                                                    protectorCount = modelData
                                                    updateStepData()
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                                ButtonGroup {
                                    id: protectorCountGroup
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        var totalCapacity = selectedProtector ? (selectedProtector.thrustCapacity * protectorCount) : 0
                                        return (isChineseMode ? "总推力承载: " : "Total Thrust: ") + formatForce(totalCapacity)
                                    }
                                    color: Material.secondaryTextColor
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // 技术参数
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            color: Material.backgroundColor
                            radius: 8

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    text: isChineseMode ? "技术参数" : "Technical Specifications"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Material.dividerColor
                                }

                                // 参数网格
                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 16
                                    rowSpacing: 8

                                    // 推力承载能力
                                    Text {
                                        text: isChineseMode ? "推力承载能力:" : "Thrust Capacity:"
                                        color: Material.secondaryTextColor
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: formatForce(selectedProtector ? selectedProtector.thrustCapacity : 0)
                                        color: Material.primaryTextColor
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    // 密封类型
                                    Text {
                                        text: isChineseMode ? "密封类型:" : "Seal Type:"
                                        color: Material.secondaryTextColor
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: selectedProtector ? selectedProtector.sealType : ""
                                        color: Material.primaryTextColor
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    // 最高温度
                                    Text {
                                        text: isChineseMode ? "最高温度:" : "Max Temperature:"
                                        color: Material.secondaryTextColor
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: formatTemperature(selectedProtector ? selectedProtector.maxTemperature : 0)
                                        color: Material.primaryTextColor
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    // 外径
                                    Text {
                                        text: isChineseMode ? "外径:" : "OD:"
                                        color: Material.secondaryTextColor
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: formatDiameter(selectedProtector ? selectedProtector.outerDiameter : 0)
                                        color: Material.primaryTextColor
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    // 长度
                                    Text {
                                        text: isChineseMode ? "长度:" : "Length:"
                                        color: Material.secondaryTextColor
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: formatLength(selectedProtector ? selectedProtector.length : 0)
                                        color: Material.primaryTextColor
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                // 特性描述
                                Text {
                                    width: parent.width
                                    text: selectedProtector ? selectedProtector.features : ""
                                    color: Material.secondaryTextColor
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // 推力分析
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            color: getThrustAnalysisColor()
                            radius: 8

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: getThrustAnalysisIcon() + " " + (isChineseMode ? "推力分析" : "Thrust Analysis")
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: {
                                            var totalCapacity = selectedProtector ? selectedProtector.thrustCapacity * protectorCount : 0
                                            var utilization = totalCapacity > 0 ? (requiredThrustCapacity / totalCapacity * 100).toFixed(1) : "0"
                                            return (isChineseMode ? "利用率: " : "Utilization: ") + utilization + "%"
                                        }
                                        color: Material.primaryTextColor
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: getThrustAnalysisText()
                                    color: Material.primaryTextColor
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // 底部间距
                        Item { Layout.preferredHeight: 16 }
                    }
                }
            }
        }
    }

    // 模拟加载保护器数据
    Timer {
        id: protectorTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            availableProtectors = generateMockProtectorData()
            loading = false
            console.log("=== 保护器数据加载完成 ===")
            console.log("可用保护器数量:", availableProtectors.length)
        }
    }

    // 函数定义
    function loadProtectors() {
        console.log("=== 开始加载保护器数据 ===")
        loading = true
        protectorTimer.start()
    }

    function generateMockProtectorData() {
        console.log("=== 生成模拟保护器数据 ===")
        return [
            {
                id: 1,
                manufacturer: "Baker Hughes",
                model: "CENesis FORCE",
                type: isChineseMode ? "标准型" : "Standard",
                thrustCapacity: 12000,
                sealType: isChineseMode ? "机械密封" : "Mechanical Seal",
                maxTemperature: 350,
                outerDiameter: 4.56,
                length: 15,
                weight: 485,
                features: isChineseMode
                        ? "高可靠性机械密封，适用于标准工况，推力承载能力强"
                        : "High reliability mechanical seal for standard conditions with strong thrust capacity"
            },
            {
                id: 2,
                manufacturer: "Schlumberger",
                model: "REDA HT Protector",
                type: isChineseMode ? "高温型" : "High Temp",
                thrustCapacity: 10000,
                sealType: isChineseMode ? "高温密封" : "High Temp Seal",
                maxTemperature: 450,
                outerDiameter: 4.62,
                length: 16,
                weight: 510,
                features: isChineseMode
                        ? "专为高温井设计，采用特殊密封材料，可在450°F下可靠工作"
                        : "Designed for high temperature wells with special seal materials, reliable up to 450°F"
            },
            {
                id: 3,
                manufacturer: "Weatherford",
                model: "HT-8000",
                type: isChineseMode ? "大推力型" : "High Thrust",
                thrustCapacity: 20000,
                sealType: isChineseMode ? "迷宫密封" : "Labyrinth Seal",
                maxTemperature: 400,
                outerDiameter: 5.12,
                length: 18,
                weight: 650,
                features: isChineseMode
                        ? "超大推力承载能力，采用迷宫密封设计，适用于大功率系统"
                        : "Ultra-high thrust capacity with labyrinth seal design for high power systems"
            },
            {
                id: 4,
                manufacturer: "Borets",
                model: "P-450S",
                type: isChineseMode ? "标准型" : "Standard",
                thrustCapacity: 8000,
                sealType: isChineseMode ? "组合密封" : "Combined Seal",
                maxTemperature: 300,
                outerDiameter: 4.0,
                length: 12,
                weight: 380,
                features: isChineseMode
                        ? "紧凑型设计，适用于小套管井，密封性能优异"
                        : "Compact design for small casing wells with excellent sealing performance"
            }
        ]
    }

    function getFilteredProtectors() {
        console.log("=== 筛选保护器数据 ===")
        console.log("可用保护器:", availableProtectors.length)

        var filtered = availableProtectors

        // 类型筛选
        if (protectorTypeFilter.currentIndex > 0) {
            var typeMap = {
                1: isChineseMode ? "标准型" : "Standard",
                2: isChineseMode ? "高温型" : "High Temp",
                3: isChineseMode ? "大推力型" : "High Thrust"
            }
            var selectedType = typeMap[protectorTypeFilter.currentIndex]
            filtered = filtered.filter(function(p) {
                return p.type === selectedType
            })
        }

        // 基本筛选：外径限制
        var casingSize = stepData.well && stepData.well.casingSize ? parseFloat(stepData.well.casingSize) : 5.5
        filtered = filtered.filter(function(p) {
            return p.outerDiameter <= casingSize - 0.5
        })

        console.log("筛选后保护器数量:", filtered.length)
        return filtered
    }

    function calculateProtectorMatchScore(protector) {
        if (!protector) return 50

        var score = 100

        // 推力匹配度（最重要）
        var totalCapacity = protector.thrustCapacity * protectorCount
        if (totalCapacity < requiredThrustCapacity) {
            score -= 50  // 推力不足，严重扣分
        } else if (totalCapacity > requiredThrustCapacity * 3) {
            score -= 20  // 推力过剩
        }

        // 温度匹配度
        var temperature = stepData.parameters ? parseFloat(stepData.parameters.bht) : 235
        if (!isNaN(temperature)) {
            if (temperature > protector.maxTemperature) {
                score -= 40  // 温度超限
            } else if (protector.maxTemperature > temperature + 200) {
                score -= 10  // 过度设计
            }
        }

        // 类型加分
        if (temperature > 350 && protector.type === (isChineseMode ? "高温型" : "High Temp")) {
            score += 10
        }
        if (requiredThrustCapacity > 15000 && protector.type === (isChineseMode ? "大推力型" : "High Thrust")) {
            score += 10
        }

        return Math.max(0, Math.min(100, Math.round(score)))
    }

    function getThrustAnalysisColor() {
        if (!selectedProtector) return Material.backgroundColor

        var totalCapacity = selectedProtector.thrustCapacity * protectorCount
        var utilization = requiredThrustCapacity / totalCapacity

        if (utilization > 1.0) return Material.color(Material.Red, Material.Shade100)
        if (utilization > 0.9) return Material.color(Material.Orange, Material.Shade100)
        if (utilization < 0.3) return Material.color(Material.Orange, Material.Shade100)
        return Material.color(Material.Green, Material.Shade100)
    }

    function getThrustAnalysisIcon() {
        if (!selectedProtector) return ""

        var totalCapacity = selectedProtector.thrustCapacity * protectorCount
        var utilization = requiredThrustCapacity / totalCapacity

        if (utilization > 1.0) return "❌"
        if (utilization > 0.9) return "⚠️"
        if (utilization < 0.3) return "⚠️"
        return "✓"
    }

    function getThrustAnalysisText() {
        if (!selectedProtector) return ""

        var totalCapacity = selectedProtector.thrustCapacity * protectorCount
        var utilization = requiredThrustCapacity / totalCapacity

        if (utilization > 1.0) {
            return isChineseMode
                   ? "推力承载能力不足！建议增加保护器数量或选择更大推力的型号。"
                   : "Insufficient thrust capacity! Consider adding more protectors or selecting a higher capacity model."
        }
        if (utilization > 0.9) {
            return isChineseMode
                   ? "推力利用率较高，建议留有一定安全余量。"
                   : "High thrust utilization, recommend maintaining safety margin."
        }
        if (utilization < 0.3) {
            return isChineseMode
                   ? "推力承载能力过剩，可以考虑选择较小型号以优化成本。"
                   : "Excess thrust capacity, consider smaller model for cost optimization."
        }
        return isChineseMode
               ? "推力承载能力匹配良好，满足系统要求并有适当余量。"
               : "Thrust capacity well matched, meets system requirements with proper margin."
    }

    function updateStepData() {
        if (!selectedProtector) return

        var totalCapacity = selectedProtector.thrustCapacity * protectorCount

        var data = {
            selectedProtector: selectedProtector.id,
            manufacturer: selectedProtector.manufacturer,
            model: selectedProtector.model,
            quantity: protectorCount,
            totalThrustCapacity: totalCapacity,
            specifications: selectedProtector.model + " × " + protectorCount +
                          " - " + totalCapacity + " lbs " + (isChineseMode ? "总推力" : "total thrust")
        }

        console.log("=== 更新Step6数据 ===")
        console.log("选择的保护器:", data)
        root.dataChanged(data)
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatForce(valueInLbs) {
        if (!valueInLbs || valueInLbs <= 0) return "N/A"

        if (isMetric) {
            // 转换为牛顿 (1 lbs = 4.448 N)
            var nValue = valueInLbs * 4.448
            if (nValue >= 1000) {
                // 显示为kN
                return (nValue / 1000).toFixed(1) + " kN"
            } else {
                return nValue.toFixed(0) + " N"
            }
        } else {
            // 保持磅
            return valueInLbs.toFixed(0) + " lbs"
        }
    }

    function formatTemperature(valueInF) {
        if (!valueInF || valueInF <= 0) return "N/A"

        if (isMetric) {
            // 转换为摄氏度
            var cValue = UnitUtils.fahrenheitToCelsius(valueInF)
            return cValue.toFixed(0) + " °C"
        } else {
            // 保持华氏度
            return valueInF.toFixed(0) + " °F"
        }
    }

    function formatDiameter(valueInInches) {
        if (!valueInInches || valueInInches <= 0) return "N/A"

        if (isMetric) {
            // 转换为毫米
            var mmValue = valueInInches * 25.4
            return mmValue.toFixed(0) + " mm"
        } else {
            // 保持英寸
            return valueInInches.toFixed(2) + " in"
        }
    }

    function formatLength(valueInFt) {
        if (!valueInFt || valueInFt <= 0) return "N/A"

        if (isMetric) {
            // 转换为米
            var mValue = valueInFt * 0.3048
            return mValue.toFixed(1) + " m"
        } else {
            // 保持英尺
            return valueInFt.toFixed(1) + " ft"
        }
    }

    function formatWeight(valueInLbs) {
        if (!valueInLbs || valueInLbs <= 0) return "N/A"

        if (isMetric) {
            // 转换为千克
            var kgValue = valueInLbs * 0.453592
            return kgValue.toFixed(0) + " kg"
        } else {
            // 保持磅
            return valueInLbs.toFixed(0) + " lbs"
        }
    }

    // 🔥 获取单位函数
    function getTemperatureUnit() {
        return isMetric ? "°C" : "°F"
    }

    function getDiameterUnit() {
        return isMetric ? "mm" : "in"
    }

    function getForceUnit() {
        return isMetric ? "kN" : "lbs"
    }

    function getLengthUnit() {
        return isMetric ? "m" : "ft"
    }

    // 🔥 强制更新显示的函数
    function updateParameterDisplays() {
        console.log("更新Step6参数显示，当前单位制:", isMetric ? "公制" : "英制")
    }

    function filterProtectors() {
        // 强制重新计算筛选结果
        console.log("=== 触发保护器筛选 ===")
        // 不需要额外操作，getFilteredProtectors() 会自动重新计算
    }

    // 监控数据变化
    onStepDataChanged: {
        console.log("=== Step6 stepData 变化 ===")
        console.log("新数据:", JSON.stringify(stepData))
    }
}
