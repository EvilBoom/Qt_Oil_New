// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step5_SeparatorSelection.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../Components" as LocalComponents

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})

    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 内部属性
    property bool needSeparator: true
    property var selectedSeparator: null
    property var availableSeparators: []
    property bool loading: false

    // 修复汽液比计算 - 使用预测结果
    property real gasLiquidRatio: {
        // 优先使用Step2的预测结果
        if (stepData.prediction && stepData.prediction.finalValues && stepData.prediction.finalValues.gasRate) {
            var gasRate = parseFloat(stepData.prediction.finalValues.gasRate)
            // 如果gasRate是小数形式（如0.15），转换为百分比
            return gasRate > 1 ? gasRate : gasRate * 100
        }

        // 后备方案：使用原始参数计算
        if (stepData.parameters) {
            var gor = parseFloat(stepData.parameters.gasOilRatio) || 0
            var bsw = parseFloat(stepData.parameters.bsw) || 0
            // 简化估算：GOR转换为体积气液比
            var estimatedGLR = gor / 178.1  // 1 bbl油 ≈ 178.1 scf在标准条件下
            return estimatedGLR * (1 - bsw/100)
        }

        return 0
    }

    // 实际的油气比数值（用于显示）
    property real gasOilRatio: {
        if (stepData.parameters && stepData.parameters.gasOilRatio) {
            return parseFloat(stepData.parameters.gasOilRatio) || 0
        }
        return 0
    }

    color: "transparent"

    Component.onCompleted: {
        console.log("=== Step5 初始化 ===")
        console.log("stepData:", JSON.stringify(stepData))
        console.log("预测结果:", stepData.prediction ? "存在" : "不存在")
        if (stepData.prediction) {
            console.log("finalValues:", JSON.stringify(stepData.prediction.finalValues))
        }

        checkSeparatorNeed()
        if (needSeparator) {
            loadSeparators()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "分离器选择" : "Separator Selection"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }

            Text {
                text: isChineseMode ? "（可选）" : "(Optional)"
                font.pixelSize: 16
                color: Material.hintTextColor
            }

            Item { Layout.fillWidth: true }

            // 跳过按钮
            Button {
                text: isChineseMode ? "跳过此步" : "Skip This Step"
                flat: true
                visible: !needSeparator || selectedSeparator === null
                onClicked: {
                    root.dataChanged({skipped: true})
                    root.nextStepRequested()
                }
            }
        }

        // 需求分析卡片
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: analysisColumn.height + 24
            color: needSeparator ? Material.color(Material.Orange, Material.Shade100) : Material.color(Material.Green, Material.Shade100)
            radius: 8
            border.width: 1
            border.color: needSeparator ? Material.color(Material.Orange) : Material.color(Material.Green)

            Column {
                id: analysisColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    width: parent.width

                    Text {
                        text: needSeparator ? "⚠️" : "✓"
                        font.pixelSize: 24
                    }

                    Text {
                        Layout.fillWidth: true
                        text: needSeparator
                              ? (isChineseMode ? "建议使用分离器" : "Separator Recommended")
                              : (isChineseMode ? "可能不需要分离器" : "Separator May Not Be Needed")
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }

                Text {
                    width: parent.width
                    text: getSeparatorAnalysis()
                    font.pixelSize: 14
                    color: Material.primaryTextColor
                    wrapMode: Text.Wrap
                }

                // 关键参数显示 - 修复数据显示
                Flow {
                    width: parent.width
                    spacing: 24

                    Row {
                        spacing: 8
                        Text {
                            text: isChineseMode ? "汽液比:" : "GLR:"
                            color: Material.secondaryTextColor
                            font.pixelSize: 13
                        }
                        Text {
                            text: {
                                if (gasLiquidRatio > 0) {
                                    var threshold = 2.0
                                    var comparison = gasLiquidRatio >= threshold ? " ≥ " : " < "
                                    return gasLiquidRatio.toFixed(2) + "%" + comparison + threshold.toFixed(1) + "%"
                                } else {
                                    return "NaN %"
                                }
                            }
                            color: {
                                if (gasLiquidRatio > 0) {
                                    return gasLiquidRatio >= 2.0 ? Material.color(Material.Orange) : Material.color(Material.Green)
                                } else {
                                    return Material.color(Material.Red)
                                }
                            }
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    // 添加一个更明显的状态指示器
                    Rectangle {
                        width: childrenRect.width + 16
                        height: 24
                        radius: 12
                        color: {
                            if (gasLiquidRatio >= 2.0) {
                                return Material.color(Material.Orange, Material.Shade100)
                            } else {
                                return Material.color(Material.Green, Material.Shade100)
                            }
                        }
                        border.width: 1
                        border.color: {
                            if (gasLiquidRatio >= 2.0) {
                                return Material.color(Material.Orange)
                            } else {
                                return Material.color(Material.Green)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (gasLiquidRatio >= 2.0) {
                                    return isChineseMode ? "需要分离器" : "Need Separator"
                                } else {
                                    return isChineseMode ? "可选分离器" : "Optional Separator"
                                }
                            }
                            color: {
                                if (gasLiquidRatio >= 2.0) {
                                    return Material.color(Material.Orange, Material.Shade800)
                                } else {
                                    return Material.color(Material.Green, Material.Shade800)
                                }
                            }
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    Row {
                        spacing: 8
                        Text {
                            text: isChineseMode ? "产量:" : "Production:"
                            color: Material.secondaryTextColor
                            font.pixelSize: 13
                        }
                        Text {
                            text: {
                                if (stepData.prediction && stepData.prediction.finalValues) {
                                    return stepData.prediction.finalValues.production.toFixed(0) + " bbl/d"
                                }
                                return "0 bbl/d"
                            }
                            color: Material.primaryTextColor
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }
            }
        }

        // 🔥 始终显示分离器选择区域，不管是否需要
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            // 🔥 移除 visible: needSeparator 条件

            ScrollView {
                anchors.fill: parent
                clip: true

                GridLayout {
                    width: parent.width
                    columns: width > 900 ? 3 : (width > 600 ? 2 : 1)
                    columnSpacing: 16
                    rowSpacing: 16

                    // 不使用分离器选项
                    LocalComponents.SeparatorCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 240

                        separatorData: {
                            "id": 0,
                            "name": isChineseMode ? "不使用分离器" : "No Separator",
                            "manufacturer": isChineseMode ? "继续不使用" : "Continue Without",
                            "model": isChineseMode ? "标准配置" : "Standard Configuration",
                            "description": isChineseMode
                                         ? "在气液比较低的情况下，可以不使用分离器，但可能会影响泵的效率和寿命。"
                                         : "For low GLR conditions, separator may be omitted, but this may affect pump efficiency and life.",
                            "gasHandlingCapacity": 0,
                            "separationEfficiency": 0,
                            "isNoSeparator": true
                        }

                        isSelected: selectedSeparator && selectedSeparator.id === 0
                        matchScore: needSeparator ? 30 : 90
                        isChineseMode: root.isChineseMode

                        onClicked: {
                            selectedSeparator = separatorData
                            updateStepData()
                        }
                    }

                    // 可用分离器列表
                    Repeater {
                        model: availableSeparators

                        LocalComponents.SeparatorCard {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 240

                            separatorData: modelData
                            isSelected: selectedSeparator && selectedSeparator.id === modelData.id
                            matchScore: calculateSeparatorMatchScore(modelData)
                            isChineseMode: root.isChineseMode

                            onClicked: {
                                selectedSeparator = modelData
                                updateStepData()
                            }
                        }
                    }
                }

                // 空状态
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    visible: !loading && availableSeparators.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📦"
                        font.pixelSize: 48
                        color: Material.hintTextColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "暂无可用的分离器" : "No separators available"
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
            }
        }

        // 选中的分离器详情
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: selectedSeparator && !selectedSeparator.isNoSeparator ? 200 : 0
            color: Material.dialogColor
            radius: 8
            visible: selectedSeparator && !selectedSeparator.isNoSeparator

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                visible: parent.visible

                // 标题
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: (isChineseMode ? "已选择: " : "Selected: ") +
                              (selectedSeparator ? selectedSeparator.manufacturer + " " + selectedSeparator.model : "")
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Item { Layout.fillWidth: true }

                    // 匹配度
                    Rectangle {
                        width: 100
                        height: 28
                        radius: 14
                        color: {
                            var score = selectedSeparator ? calculateSeparatorMatchScore(selectedSeparator) : 0
                            if (score >= 80) return Material.color(Material.Green)
                            if (score >= 60) return Material.color(Material.Orange)
                            return Material.color(Material.Red)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: (isChineseMode ? "匹配度: " : "Match: ") +
                                  (selectedSeparator ? calculateSeparatorMatchScore(selectedSeparator) : 0) + "%"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Material.dividerColor
                }

                // 技术参数
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 24
                    rowSpacing: 8

                    // 分离效率
                    Column {
                        Text {
                            text: isChineseMode ? "分离效率" : "Separation Efficiency"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: (selectedSeparator ? selectedSeparator.separationEfficiency : 0) + "%"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                    }

                    // 气体处理能力
                    Column {
                        Text {
                            text: isChineseMode ? "气体处理能力" : "Gas Capacity"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: (selectedSeparator ? selectedSeparator.gasHandlingCapacity : 0) + " mcf/d"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                    }

                    // 液体处理能力
                    Column {
                        Text {
                            text: isChineseMode ? "液体处理能力" : "Liquid Capacity"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: (selectedSeparator ? selectedSeparator.liquidHandlingCapacity : 0) + " bbl/d"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                    }

                    // 外径
                    Column {
                        Text {
                            text: isChineseMode ? "外径" : "OD"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: (selectedSeparator ? selectedSeparator.outerDiameter : 0) + " in"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                    }
                }

                // 性能分析
                Text {
                    Layout.fillWidth: true
                    text: getPerformanceAnalysis()
                    font.pixelSize: 13
                    color: Material.secondaryTextColor
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // 函数定义
    function checkSeparatorNeed() {
        console.log("=== 检查分离器需求（修改后的逻辑）===")
        console.log("计算的汽液比:", gasLiquidRatio)
        console.log("原始油气比:", gasOilRatio)

        // 🔥 修改判断逻辑：只有汽液比小于2%时才不需要分离器
        needSeparator = gasLiquidRatio >= 2.0  // 汽液比大于等于2%建议使用分离器

        // 🔥 如果汽液比小于2%，则不需要分离器
        if (gasLiquidRatio < 2.0) {
            needSeparator = false
        }

        // 其他影响因素 - 高油气比仍然建议使用分离器
        if (gasOilRatio > 500) {  // GOR > 500 scf/bbl 强烈建议使用
            needSeparator = true
        }

        console.log("是否需要分离器:", needSeparator)
        console.log("判断依据: 汽液比", gasLiquidRatio, "% >= 2.0% ?", gasLiquidRatio >= 2.0)
    }

    function loadSeparators() {
        loading = true
        separatorTimer.start()
    }

    // 🔥 修改为总是加载分离器数据，不管是否需要
    Timer {
        id: separatorTimer
        interval: 500
        running: true  // 总是运行
        repeat: false
        onTriggered: {
            availableSeparators = generateMockSeparatorData()
            loading = false
        }
    }

    function generateMockSeparatorData() {
        return [
            {
                id: 1,
                manufacturer: "Baker Hughes",
                model: "CENesis PHASE",
                series: "Advanced",
                separationEfficiency: 95,
                gasHandlingCapacity: 500,
                liquidHandlingCapacity: 5000,
                outerDiameter: 4.5,
                length: 15,
                weight: 450,
                maxPressure: 5000,
                description: isChineseMode
                           ? "高效气液分离器，适用于高含气井，分离效率高达95%"
                           : "High-efficiency gas-liquid separator for high GOR wells with up to 95% separation efficiency"
            },
            {
                id: 2,
                manufacturer: "Schlumberger",
                model: "Vortex SEP",
                series: "Standard",
                separationEfficiency: 92,
                gasHandlingCapacity: 400,
                liquidHandlingCapacity: 4000,
                outerDiameter: 4.0,
                length: 12,
                weight: 380,
                maxPressure: 4500,
                description: isChineseMode
                           ? "涡流式分离器，结构紧凑，适用于中等含气量"
                           : "Vortex separator with compact design for moderate gas content"
            },
            {
                id: 3,
                manufacturer: "Weatherford",
                model: "DualFlow GS",
                series: "Premium",
                separationEfficiency: 98,
                gasHandlingCapacity: 600,
                liquidHandlingCapacity: 6000,
                outerDiameter: 5.0,
                length: 18,
                weight: 520,
                maxPressure: 5500,
                description: isChineseMode
                           ? "双流道设计，超高分离效率，适用于极高含气工况"
                           : "Dual-flow design with ultra-high separation efficiency for extreme gas conditions"
            }
        ]
    }

    function calculateSeparatorMatchScore(separator) {
        if (!separator || separator.isNoSeparator) {
            // 🔥 修改评分逻辑：汽液比小于2%时，不使用分离器得高分
            return gasLiquidRatio < 2.0 ? 90 : 30
        }

        var score = 100

        // 气体处理能力匹配 - 修复计算
        if (stepData.prediction && stepData.prediction.finalValues && gasOilRatio > 0) {
            var production = stepData.prediction.finalValues.production
            var requiredGasCapacity = production * gasOilRatio / 1000  // mcf/d

            if (requiredGasCapacity > separator.gasHandlingCapacity) {
                score -= 40  // 容量不足
            } else if (requiredGasCapacity < separator.gasHandlingCapacity * 0.3) {
                score -= 20  // 容量过剩
            }
        }

        // 液体处理能力匹配
        if (stepData.prediction && stepData.prediction.finalValues) {
            var production = stepData.prediction.finalValues.production
            if (production > separator.liquidHandlingCapacity) {
                score -= 40
            }
        }

        // 外径限制
        var casingSize = stepData.well && stepData.well.casingSize ? parseFloat(stepData.well.casingSize) : 5.5
        if (separator.outerDiameter > casingSize - 0.5) {
            score -= 50
        }

        // 分离效率加分
        score += (separator.separationEfficiency - 90) * 2

        return Math.max(0, Math.min(100, Math.round(score)))
    }

    // 在 getSeparatorAnalysis() 函数中修改显示格式

    function getSeparatorAnalysis() {
        var analysis = ""
        var threshold = 2.0  // 阈值

        if (needSeparator) {
            analysis = isChineseMode
                     ? "基于当前井况分析：\n"
                     : "Based on current well conditions:\n"

            // 🔥 修改显示格式，显示比较关系
            analysis += isChineseMode
                      ? "• 汽液比为 " + gasLiquidRatio.toFixed(1) + "% > " + threshold.toFixed(1) + "%，建议使用分离器以提高泵效率\n"
                      : "• GLR is " + gasLiquidRatio.toFixed(1) + "% > " + threshold.toFixed(1) + "%, separator recommended to improve pump efficiency\n"

            if (gasOilRatio > 500) {
                analysis += isChineseMode
                          ? "• 油气比较高 (" + gasOilRatio.toFixed(0) + " scf/bbl)，分离器可显著改善泵性能\n"
                          : "• High GOR (" + gasOilRatio.toFixed(0) + " scf/bbl), separator will significantly improve pump performance\n"
            }

            analysis += isChineseMode
                      ? "• 使用分离器可以减少气锁、提高泵效率并延长设备寿命"
                      : "• Separator can reduce gas lock, improve pump efficiency and extend equipment life"
        } else {
            // 🔥 修改分析文本，显示比较格式
            analysis = isChineseMode
                     ? "当前汽液比较低 (" + gasLiquidRatio.toFixed(1) + "% < " + threshold.toFixed(1) + "%)，可能不需要分离器。但如果存在以下情况仍建议考虑：\n"
                     : "Current GLR is low (" + gasLiquidRatio.toFixed(1) + "% < " + threshold.toFixed(1) + "%), separator may not be necessary. Consider if:\n"

            analysis += isChineseMode
                      ? "• 井况可能发生变化\n• 需要额外的运行保障\n• 有段塞流或间歇产气"
                      : "• Well conditions may change\n• Extra operational security needed\n• Slug flow or intermittent gas production"
        }

        return analysis
    }

    function getPerformanceAnalysis() {
        if (!selectedSeparator || selectedSeparator.isNoSeparator) return ""

        var analysis = ""
        var score = calculateSeparatorMatchScore(selectedSeparator)

        if (score >= 80) {
            analysis = isChineseMode
                     ? "✓ 该分离器非常适合当前工况，容量匹配良好，可有效提升系统性能。"
                     : "✓ This separator is well-suited for current conditions with good capacity match."
        } else if (score >= 60) {
            analysis = isChineseMode
                     ? "⚠ 该分离器基本满足要求，但需注意容量余量或尺寸限制。"
                     : "⚠ This separator meets basic requirements but check capacity margin or size constraints."
        } else {
            analysis = isChineseMode
                     ? "✗ 该分离器可能不是最佳选择，建议选择更匹配的型号。"
                     : "✗ This separator may not be optimal, consider better matched models."
        }

        return analysis
    }

    function updateStepData() {
        if (!selectedSeparator) return

        var data = {
            selectedSeparator: selectedSeparator.id,
            manufacturer: selectedSeparator.manufacturer,
            model: selectedSeparator.model,
            separationEfficiency: selectedSeparator.separationEfficiency,
            specifications: selectedSeparator.isNoSeparator
                          ? (isChineseMode ? "不使用分离器" : "No separator")
                          : selectedSeparator.model + " - " +
                            selectedSeparator.separationEfficiency + "% " +
                            (isChineseMode ? "分离效率" : "efficiency"),
            skipped: selectedSeparator.isNoSeparator || selectedSeparator.id === 0
        }

        root.dataChanged(data)
    }

    // 添加数据监控函数用于调试
    onStepDataChanged: {
        console.log("=== Step5 stepData 变化 ===")
        console.log("新数据:", JSON.stringify(stepData))
        checkSeparatorNeed()
    }
}
