import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts
import "../Components" as LocalComponents
import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})

    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 内部属性
    property bool predictionCompleted: false
    property var mlResults: null
    property var empiricalResults: null
    property var iprCurveData: []
    property real predictionProgress: 0

    // 修正：将 finalPumpDepth 改为 finalTotalHead
    property real finalProduction: 0
    property real finalTotalHead: 0      // 修正：扬程而不是泵挂深度
    property real finalGasRate: 0

    color: "transparent"

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("Step2中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题栏 - 固定在顶部
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            Text {
                text: isChineseMode ? "预测结果与IPR曲线" : "Prediction Results & IPR Curve"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 🔥 添加单位切换器
            // CommonComponents.UnitSwitcher {
            //     isChinese: root.isChineseMode
            //     showLabel: false
            //     labelText: ""
            // }

            // 重新计算按钮
            Button {
                text: isChineseMode ? "重新计算" : "Recalculate"
                enabled: !(controller && controller.busy) && stepData.parameters
                onClicked: runPrediction()
            }
        }

        // 主内容区域 - 修改为滚动布局
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 滚动条策略
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            // 允许触摸滚动
            contentHeight: scrollContent.height
            clip: true

            Column {
                id: scrollContent
                width: parent.width
                spacing: 16

                // 预测结果区域
                Rectangle {
                    width: parent.width
                    height: 320
                    color: Material.dialogColor
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 3

                        // 标题行
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: isChineseMode ? "预测结果" : "Prediction Results"
                                font.pixelSize: 16
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            Item { Layout.fillWidth: true }

                            // 预测进度条
                            ProgressBar {
                                Layout.preferredWidth: 200
                                value: predictionProgress
                                visible: controller && controller.busy

                                Label {
                                    anchors.right: parent.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Math.round(parent.value * 100) + "%"
                                    color: Material.primaryTextColor
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Material.dividerColor
                        }

                        // 预测结果卡片
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: predictionCompleted && !(controller && controller.busy)

                            GridLayout {
                                anchors.fill: parent
                                columns: 3
                                columnSpacing: 24
                                rowSpacing: 2

                                // 🔥 修改推荐产量卡片，添加单位转换
                                LocalComponents.PredictionResultCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: 200

                                    title: isChineseMode ? "推荐产量" : "Recommended Production"
                                    unit: getFlowUnit()  // 🔥 动态单位
                                    icon: "💧"

                                    mlValue: mlResults ? convertFlowValue(mlResults.production) : 0  // 🔥 转换数值
                                    empiricalValue: {
                                        if (!stepData || !stepData.parameters) return 0
                                        var value = stepData.prediction.empiricalResults.production
                                        if (value === undefined || value === null || isNaN(parseFloat(value))) return 0
                                        console.log(value)
                                        return convertFlowValue(parseFloat(value))  // 🔥 转换数值
                                    }
                                    // confidence: mlResults ? mlResults.confidence : 0

                                    isAdjustable: true
                                    finalValue: convertFlowValue(finalProduction)  // 🔥 转换显示值

                                    onFinalValueChanged: {
                                        finalProduction = convertFlowValueToStandard(finalValue)  // 🔥 转换回标准单位存储
                                        updateStepData()
                                    }
                                }

                                // 🔥 修改所需扬程卡片，添加单位转换
                                LocalComponents.PredictionResultCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: 200

                                    title: isChineseMode ? "所需扬程" : "Required Total Head"
                                    unit: getDepthUnit()  // 🔥 动态单位
                                    icon: "⬆️"

                                    mlValue: mlResults ? convertDepthValue(mlResults.total_head) : 0  // 🔥 转换数值
                                    empiricalValue: {
                                        if (!empiricalResults) return 0
                                        var value = empiricalResults.total_head
                                        if (value === undefined || value === null || isNaN(parseFloat(value))) return 0
                                        return convertDepthValue(parseFloat(value))  // 🔥 转换数值
                                    }
                                    confidence: mlResults ? mlResults.confidence : 0

                                    isAdjustable: true
                                    finalValue: convertDepthValue(finalTotalHead)  // 🔥 转换显示值

                                    onFinalValueChanged: {
                                        finalTotalHead = convertDepthValueToStandard(finalValue)  // 🔥 转换回标准单位存储
                                        updateStepData()
                                    }
                                }

                                // 吸入口气液比 (这个通常无单位，保持不变)
                                LocalComponents.PredictionResultCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: 200

                                    title: isChineseMode ? "吸入口气液比" : "Gas Rate at Intake"
                                    unit: " "
                                    icon: "💨"

                                    mlValue: mlResults ? mlResults.gas_rate : 0
                                    empiricalValue: {
                                        if (!empiricalResults) return 0
                                        var value = empiricalResults.gas_rate
                                        if (value === undefined || value === null || isNaN(parseFloat(value))) return 0
                                        return parseFloat(value)
                                    }
                                    confidence: mlResults ? mlResults.confidence : 0

                                    isAdjustable: true
                                    finalValue: finalGasRate

                                    onFinalValueChanged: {
                                        finalGasRate = finalValue
                                        updateStepData()
                                    }
                                }
                            }
                        }

                        // 空状态提示
                        Column {
                            Layout.alignment: Qt.AlignCenter
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 16
                            visible: !predictionCompleted && !(controller && controller.busy)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "📊"
                                font.pixelSize: 48
                                color: Material.hintTextColor
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "点击'开始预测'按钮进行计算" : "Click 'Start Prediction' to calculate"
                                color: Material.hintTextColor
                                font.pixelSize: 14
                            }

                            Button {
                                id: startPredictionButton
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "开始预测" : "Start Prediction"
                                background: Rectangle {
                                        color: startPredictionButton.pressed ? "#2a5cad" :
                                               startPredictionButton.hovered ? "#3a7cdb" :
                                               "#3465a4"
                                        radius: 6
                                        border.color: startPredictionButton.hovered ? "#81a2be" : "#5c85b6"
                                        border.width: 1
                                }
                                highlighted: true
                                enabled: stepData.parameters && !(controller && controller.busy)
                                onClicked: runPrediction()
                            }
                        }
                    }
                }

                // 经验公式对比区域 - 🔥 修改显示的数值，添加单位转换
                Rectangle {
                    width: parent.width
                    height: 320
                    color: Material.dialogColor
                    radius: 8
                    visible: predictionCompleted && mlResults && empiricalResults

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12

                        // 标题行
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: isChineseMode ? "📊 预测方法对比分析" : "📊 Prediction Method Comparison"
                                font.pixelSize: 16
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            Item { Layout.fillWidth: true }

                            // 方法标识
                            Row {
                                spacing: 16

                                Rectangle {
                                    width: childrenRect.width + 16
                                    height: 24
                                    radius: 12
                                    color: Material.color(Material.Blue, Material.Shade100)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: Material.color(Material.Blue)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isChineseMode ? "机器学习" : "Machine Learning"
                                            color: Material.color(Material.Blue)
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }
                                }

                                Rectangle {
                                    width: childrenRect.width + 16
                                    height: 24
                                    radius: 12
                                    color: Material.color(Material.Green, Material.Shade100)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: Material.color(Material.Green)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isChineseMode ? "经验公式" : "Empirical Formula"
                                            color: Material.color(Material.Green)
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }
                                }

                                Rectangle {
                                    width: childrenRect.width + 16
                                    height: 24
                                    radius: 12
                                    color: Material.color(Material.Orange, Material.Shade100)

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: Material.color(Material.Orange)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: isChineseMode ? "智能选择" : "Smart Selection"
                                            color: Material.color(Material.Orange)
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Material.dividerColor
                        }

                        // 🔥 对比表格标题栏 - 修改为动态单位
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            color: Material.color(Material.Grey, Material.Shade100)
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8

                                Text {
                                    Layout.preferredWidth: parent.width * 0.25
                                    text: isChineseMode ? "指标" : "Metric"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Material.primaryTextColor
                                }

                                Text {
                                    Layout.preferredWidth: parent.width * 0.2
                                    text: isChineseMode ? "机器学习" : "ML"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Material.color(Material.Blue)
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.preferredWidth: parent.width * 0.2
                                    text: isChineseMode ? "经验公式" : "Empirical"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Material.color(Material.Green)
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.preferredWidth: parent.width * 0.15
                                    text: isChineseMode ? "误差" : "Error"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Material.primaryTextColor
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: isChineseMode ? "最终值" : "Final"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Material.color(Material.Orange)
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // 对比表格 - 🔥 修改为显示转换后的数值
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 156

                            Column {
                                anchors.fill: parent
                                spacing: 6

                                // 🔥 对比项目1：推荐产量 - 添加单位转换
                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    color: Material.color(Material.Grey, Material.Shade50)
                                    radius: 6
                                    border.width: 1
                                    border.color: Material.dividerColor

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.25
                                            text: isChineseMode ? "推荐产量" : "Production"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.2
                                            text: mlResults ? convertFlowValue(mlResults.production).toFixed(2) + " " + getFlowUnit() : "N/A"
                                            color: Material.color(Material.Blue)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.2
                                            text: empiricalResults ? convertFlowValue(empiricalResults.production).toFixed(2) + " " + getFlowUnit() : "N/A"
                                            color: Material.color(Material.Green)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.15
                                            text: {
                                                if (mlResults && empiricalResults && empiricalResults.production > 0) {
                                                    var error = Math.abs(mlResults.production - empiricalResults.production) / empiricalResults.production * 100
                                                    return error.toFixed(1) + "%"
                                                }
                                                return "N/A"
                                            }
                                            color: {
                                                if (mlResults && empiricalResults && empiricalResults.production > 0) {
                                                    var error = Math.abs(mlResults.production - empiricalResults.production) / empiricalResults.production * 100
                                                    return error < 10 ? Material.color(Material.Green) :
                                                           error < 20 ? Material.color(Material.Orange) : Material.color(Material.Red)
                                                }
                                                return Material.secondaryTextColor
                                            }
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: convertFlowValue(finalProduction).toFixed(2) + " " + getFlowUnit()
                                            color: Material.color(Material.Orange)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }

                                // 🔥 对比项目2：所需扬程 - 添加单位转换
                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    color: Material.color(Material.Grey, Material.Shade50)
                                    radius: 6
                                    border.width: 1
                                    border.color: Material.dividerColor

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.25
                                            text: isChineseMode ? "所需扬程" : "Total Head"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.2
                                            text: mlResults ? convertDepthValue(mlResults.total_head).toFixed(0) + " " + getDepthUnit() : "N/A"
                                            color: Material.color(Material.Blue)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.2
                                            text: empiricalResults ? convertDepthValue(empiricalResults.total_head).toFixed(0) + " " + getDepthUnit() : "N/A"
                                            color: Material.color(Material.Green)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.15
                                            text: {
                                                if (mlResults && empiricalResults && empiricalResults.total_head > 0) {
                                                    var error = Math.abs(mlResults.total_head - empiricalResults.total_head) / empiricalResults.total_head * 100
                                                    return error.toFixed(1) + "%"
                                                }
                                                return "N/A"
                                            }
                                            color: {
                                                if (mlResults && empiricalResults && empiricalResults.total_head > 0) {
                                                    var error = Math.abs(mlResults.total_head - empiricalResults.total_head) / empiricalResults.total_head * 100
                                                    return error < 10 ? Material.color(Material.Green) :
                                                           error < 20 ? Material.color(Material.Orange) : Material.color(Material.Red)
                                                }
                                                return Material.secondaryTextColor
                                            }
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: convertDepthValue(finalTotalHead).toFixed(0) + " " + getDepthUnit()
                                            color: Material.color(Material.Orange)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }

                                // 对比项目3：气液比 (保持不变，通常无单位)
                                Rectangle {
                                    width: parent.width
                                    height: 48
                                    color: Material.color(Material.Grey, Material.Shade50)
                                    radius: 6
                                    border.width: 1
                                    border.color: Material.dividerColor

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.25
                                            text: isChineseMode ? "气液比" : "Gas Rate"
                                            font.bold: true
                                            font.pixelSize: 12
                                            color: Material.primaryTextColor
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.2
                                            text: mlResults ? mlResults.gas_rate.toFixed(4) : "N/A"
                                            color: Material.color(Material.Blue)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.2
                                            text: empiricalResults ? empiricalResults.gas_rate.toFixed(4) : "N/A"
                                            color: Material.color(Material.Green)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.preferredWidth: parent.width * 0.15
                                            text: {
                                                if (mlResults && empiricalResults && empiricalResults.gas_rate > 0) {
                                                    var error = Math.abs(mlResults.gas_rate - empiricalResults.gas_rate) / Math.max(mlResults.gas_rate, empiricalResults.gas_rate) * 100
                                                    return error.toFixed(1) + "%"
                                                }
                                                return "N/A"
                                            }
                                            color: {
                                                if (mlResults && empiricalResults && empiricalResults.gas_rate > 0) {
                                                    var error = Math.abs(mlResults.gas_rate - empiricalResults.gas_rate) / Math.max(mlResults.gas_rate, empiricalResults.gas_rate) * 100
                                                    return error < 15 ? Material.color(Material.Green) :
                                                           error < 30 ? Material.color(Material.Orange) : Material.color(Material.Red)
                                                }
                                                return Material.secondaryTextColor
                                            }
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: finalGasRate.toFixed(4)
                                            color: Material.color(Material.Orange)
                                            font.bold: true
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }

                        // 智能选择说明
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: Material.color(Material.Blue, Material.Shade50)
                            radius: 6
                            border.width: 1
                            border.color: Material.color(Material.Blue, Material.Shade200)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12

                                Text {
                                    text: "💡"
                                    font.pixelSize: 16
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: isChineseMode ?
                                        "智能选择算法基于机器学习和经验公式的误差分析，自动选择最可靠的预测结果。误差小于15%时优先选择机器学习结果。" :
                                        "Smart selection algorithm automatically chooses the most reliable prediction based on error analysis between ML and empirical methods. ML results are preferred when error < 15%."
                                    color: Material.color(Material.Blue, Material.Shade800)
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                }
                            }
                        }
                    }
                }

                // IPR曲线区域 - 🔥 修改关键信息显示，添加单位转换
                Rectangle {
                    width: parent.width
                    height: 400
                    color: Material.dialogColor
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16

                        // IPR曲线标题行
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: isChineseMode ? "IPR曲线分析" : "IPR Curve Analysis"
                                font.pixelSize: 16
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            Item { Layout.fillWidth: true }

                            // 数据统计 - 🔥 添加单位转换
                            Row {
                                spacing: 16
                                visible: predictionCompleted

                                Rectangle {
                                    width: childrenRect.width + 16
                                    height: 24
                                    radius: 12
                                    color: Material.color(Material.Blue, Material.Shade100)

                                    Text {
                                        anchors.centerIn: parent
                                        text: isChineseMode ? "数据点: " + iprCurveData.length : "Points: " + iprCurveData.length
                                        color: Material.color(Material.Blue)
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                Rectangle {
                                    width: childrenRect.width + 16
                                    height: 24
                                    radius: 12
                                    color: Material.color(Material.Green, Material.Shade100)

                                    Text {
                                        anchors.centerIn: parent
                                        text: isChineseMode ?
                                              "工作点: " + convertFlowValue(finalProduction).toFixed(1) + " " + getFlowUnit() :
                                              "Operating: " + convertFlowValue(finalProduction).toFixed(1) + " " + getFlowUnit()
                                        color: Material.color(Material.Green)
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }

                            // 查看完整IPR曲线按钮
                            Button {
                                text: isChineseMode ? "📈 查看完整IPR曲线" : "📈 View Full IPR Curve"
                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "white"
                                }
                                highlighted: true
                                enabled: predictionCompleted
                                onClicked: {
                                    if (controller && finalProduction > 0) {
                                        controller.generateIPRCurve(finalProduction)
                                    } else {
                                        openIPRDialog()
                                    }
                                }
                                background: Rectangle {
                                        color: startPredictionButton.pressed ? "#2a5cad" :
                                               startPredictionButton.hovered ? "#3a7cdb" :
                                               "#3465a4"
                                        radius: 6
                                        border.color: startPredictionButton.hovered ? "#81a2be" : "#5c85b6"
                                        border.width: 1
                                }
                            }

                            // 气液比分析按钮
                            Button {
                                text: isChineseMode ? "🔬 气液比分析" : "🔬 GLR Analysis"
                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "white"
                                }
                                flat: true
                                // Material.accent: Material.Purple
                                enabled: predictionCompleted
                                onClicked: openGLRAnalysisDialog()
                                background: Rectangle {
                                        color: startPredictionButton.pressed ? "#2a5cad" :
                                               startPredictionButton.hovered ? "#3a7cdb" :
                                               "#3465a4"
                                        radius: 6
                                        border.color: startPredictionButton.hovered ? "#81a2be" : "#5c85b6"
                                        border.width: 1
                                }

                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Material.dividerColor
                        }

                        // IPR曲线预览区域 - 🔥 修改关键信息显示单位
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#f8f9fa"
                            radius: 8
                            border.color: "#e1e5e9"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 24
                                spacing: 32

                                // 左侧：图表预览
                                Column {
                                    Layout.preferredWidth: parent.width * 0.4
                                    Layout.fillHeight: true
                                    spacing: 16

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "📊"
                                        font.pixelSize: 64
                                        color: Material.color(Material.Blue, Material.Shade300)
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: predictionCompleted ?
                                              (isChineseMode ? "IPR曲线已生成" : "IPR Curve Generated") :
                                              (isChineseMode ? "等待预测完成" : "Waiting for Prediction")
                                        color: predictionCompleted ? Material.color(Material.Green) : Material.hintTextColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: predictionCompleted ?
                                              (isChineseMode ? "点击右侧按钮查看详细分析" : "Click button to view detailed analysis") :
                                              (isChineseMode ? "预测完成后将显示IPR曲线" : "IPR curve will be available after prediction")
                                        color: Material.secondaryTextColor
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        width: parent.width
                                    }
                                }

                                // 分隔线
                                Rectangle {
                                    width: 1
                                    Layout.fillHeight: true
                                    color: Material.dividerColor
                                    visible: predictionCompleted
                                }

                                // 右侧：关键信息 - 🔥 修改为显示转换后的单位
                                Column {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 16
                                    visible: predictionCompleted

                                    Text {
                                        text: isChineseMode ? "关键信息" : "Key Information"
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    Grid {
                                        width: parent.width
                                        columns: 2
                                        columnSpacing: 20
                                        rowSpacing: 12

                                        // 🔥 最大产量 - 添加单位转换
                                        Text {
                                            text: isChineseMode ? "最大产量:" : "Max Production:"
                                            color: Material.secondaryTextColor
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: iprCurveData.length > 0 ?
                                                  convertFlowValue(Math.max(...iprCurveData.map(p => p.production))).toFixed(1) + " " + getFlowUnit() :
                                                  "N/A"
                                            color: Material.primaryTextColor
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        // 🔥 地层压力 - 添加单位转换
                                        Text {
                                            text: isChineseMode ? "地层压力:" : "Reservoir Pressure:"
                                            color: Material.secondaryTextColor
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: iprCurveData.length > 0 ?
                                                  convertPressureValue(Math.max(...iprCurveData.map(p => p.pressure))).toFixed(0) + " " + getPressureUnit() :
                                                  "N/A"
                                            color: Material.primaryTextColor
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        // 曲线类型 (保持不变)
                                        Text {
                                            text: isChineseMode ? "曲线类型:" : "Curve Type:"
                                            color: Material.secondaryTextColor
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: isChineseMode ? "Vogel方程" : "Vogel Equation"
                                            color: Material.primaryTextColor
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        // 工作点效率 (保持不变)
                                        Text {
                                            text: isChineseMode ? "工作点效率:" : "Operating Efficiency:"
                                            color: Material.secondaryTextColor
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: finalProduction > 0 && iprCurveData.length > 0 ?
                                                  "85%" : "N/A"
                                            color: Material.color(Material.Green)
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 底部间距
                Item {
                    width: parent.width
                    height: 20
                }
            }
        }
    }

    // 🔥 添加单位转换函数
    function getFlowUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("flow")
        }
        return isMetric ? "m³/d" : "bbl/d"
    }

    function getDepthUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("depth")
        }
        return isMetric ? "m" : "ft"
    }

    function getPressureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("pressure")
        }
        return isMetric ? "kPa" : "psi"
    }

    function convertFlowValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.bblToM3(value)  // bbl/d → m³/d
    }

    function convertFlowValueToStandard(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.m3ToBbl(value)  // m³/d → bbl/d
    }

    function convertDepthValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.feetToMeters(value)  // ft → m
    }

    function convertDepthValueToStandard(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.metersToFeet(value)  // m → ft
    }

    function convertPressureValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.psiToMPa(value)  // psi → MPa
    }

    // 其余函数保持不变...
    Component.onCompleted: {
        console.log("=== Step2 组件加载完成 ===")
        console.log("stepData:", JSON.stringify(stepData))

        if (!stepData || !stepData.parameters) {
            console.log("=== Step2 数据为空，尝试重新获取 ===")
            retryTimer.start()
        } else {
            console.log("=== Step2 接收到有效数据 ===")
            initializeWithData()
        }
    }

    Timer {
        id: retryTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("=== Step2 重试获取数据 ===")
            if (stepData && stepData.parameters) {
                console.log("=== 重试成功，获得数据 ===")
                initializeWithData()
            } else {
                console.log("=== 重试失败，数据仍为空 ===")
            }
        }
    }

    Timer {
        id: startupTimer
        interval: 500
        onTriggered: runPrediction()
    }

    function initializeWithData() {
        console.log("=== Step2 使用数据初始化 ===")
        if (stepData.parameters && stepData.parameters.parametersId > 0) {
            console.log("=== 检测到有效参数，准备启动预测 ===")
            startupTimer.start()
        } else {
            console.log("=== 没有检测到有效参数，等待用户操作 ===")
        }
    }

    // 连接Controller信号
    Connections {
        target: controller
        enabled: controller !== null

        function onPredictionCompleted(results) {
            console.log("=== 预测完成，接收到结果 ===")
            console.log("mlResults:", results.mlResults ? "存在" : "不存在")
            console.log("empiricalResults:", results.empiricalResults ? "存在" : "不存在")
            console.log("iprCurve 长度:", results.iprCurve ? results.iprCurve.length : "未定义")

            predictionCompleted = true
            mlResults = results.mlResults
            empiricalResults = results.empiricalResults
            iprCurveData = results.iprCurve

            // 设置初始值
            if (mlResults) {
                finalProduction = mlResults.production || 0
                finalTotalHead = mlResults.total_head || 0
                finalGasRate = mlResults.gas_rate || 0
            }

            updateStepData()
        }

        function onPredictionProgress(progress) {
            predictionProgress = progress
            updateProgress(progress)
        }

        function onPredictionError(error) {
            showErrorMessage(error)
            predictionProgress = 0
        }

        function onIprCurveGenerated(data) {
           console.log("=== 接收到IPR曲线数据 ===")
            console.log("数据长度:", data ? data.length : 0)
            if (data && data.length > 0) {
                console.log("数据样本:", JSON.stringify(data.slice(0, 2)))
                iprCurveData = data
                iprDialog.updateChart(iprCurveData, finalProduction)
                iprDialog.open()
            }
        }
    }

    // 函数定义
    function runPrediction() {
        if (!controller || !stepData.parameters) {
            showErrorMessage(isChineseMode ? "缺少生产参数" : "Missing production parameters")
            return
        }

        predictionCompleted = false
        predictionProgress = 0
        controller.runPrediction()
    }

    function updateProgress(progress) {
        predictionProgress = progress
    }

    function updateStepData() {
        var data = {
            mlResults: mlResults,
            empiricalResults: empiricalResults,
            finalValues: {
                production: finalProduction,
                totalHead: finalTotalHead,
                gasRate: finalGasRate
            },
            iprCurve: iprCurveData
        }

        root.dataChanged(data)
    }

    function showErrorMessage(message) {
        console.error(message)
    }

    function openIPRDialog() {
        console.log("=== 直接打开IPR对话框 ===")
        console.log("IPR数据点数量:", iprCurveData ? iprCurveData.length : 0)

        if (iprCurveData && iprCurveData.length > 0) {
            iprDialog.updateChart(iprCurveData, finalProduction)
            iprDialog.open()
        } else {
            console.warn("=== IPR数据为空 ===")
            showErrorMessage(isChineseMode ? "暂无IPR曲线数据" : "No IPR curve data available")
        }
    }

    function openGLRAnalysisDialog() {
        console.log("=== 打开气液比分析对话框 ===")
        console.log("当前参数:", JSON.stringify(stepData.parameters))

        if (stepData.parameters) {
            glrAnalysisDialog.currentParameters = stepData.parameters
            glrAnalysisDialog.show()
            glrAnalysisDialog.raise()
            glrAnalysisDialog.requestActivate()
        } else {
            showErrorMessage(isChineseMode ? "缺少生产参数数据" : "Missing production parameters")
        }
    }

    // IPR曲线对话框
    LocalComponents.IPRCurveDialog {
        id: iprDialog
        isChineseMode: root.isChineseMode
        // 🔥 新增：连接参数同步信号
        Component.onCompleted: {
            if (typeof deviceRecommendationController !== 'undefined') {
                deviceRecommendationController.currentParametersReady.connect(iprDialog.updateParametersFromData)
            }
        }
    }

    // 气液比分析对话框
    LocalComponents.GasLiquidRatioAnalysisDialog {
        id: glrAnalysisDialog
        isChineseMode: root.isChineseMode
        controller: root.controller
        currentParameters: stepData.parameters || {}
    }
}
