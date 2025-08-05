import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../Components" as LocalComponents
import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false
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
    property bool dataLoadError: false  // 🔥 添加缺失的属性定义

    // 🔥 采用Step3的安全数据访问模式 - 简化气液比计算
    property real gasLiquidRatio: {
        // 🔥 简单优先级：预测结果 > 参数计算 > 默认值
        if (stepData && stepData.prediction && stepData.prediction.finalValues) {
            var gasRate = stepData.prediction.finalValues.gasRate
            if (gasRate !== undefined && gasRate !== null) {
                var rate = parseFloat(gasRate)
                return rate > 1 ? rate : rate * 100  // 转换为百分比
            }
        }

        // 后备：从参数估算
        if (stepData && stepData.parameters) {
            var gor = parseFloat(stepData.parameters.gasOilRatio) || 0
            if (gor > 0) {
                return gor / 178.1  // 简化估算
            }
        }

        return 0  // 默认值
    }

    property real gasOilRatio: {
        if (stepData && stepData.parameters && stepData.parameters.gasOilRatio) {
            return parseFloat(stepData.parameters.gasOilRatio) || 0
        }
        return 0
    }

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("Step5中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }
    // 🔥 添加控制器信号连接 - 确保数据加载成功
    Connections {
        target: controller
        enabled: controller !== null

        function onSeparatorsLoaded(separators) {
            console.log("=== 接收到分离器数据 ===")
            console.log("分离器数量:", separators.length)

            availableSeparators = separators
            loading = false
            dataLoadError = false

            // 数据加载完成后自动推荐
            if (stepData.prediction && stepData.prediction.finalValues) {
                Qt.callLater(function() {
                    autoRecommendSeparator()
                })
            }

            console.log("✅ 分离器数据加载成功")
        }

        function onError(errorMessage) {
            console.log("=== 分离器数据加载失败 ===")
            console.log("错误:", errorMessage)

            loading = false
            dataLoadError = true
            availableSeparators = []

            console.log("❌ 分离器数据加载失败，不使用后备数据")
        }
    }

    color: "transparent"


    // 🔥 修改：初始化时只加载真实数据
    Component.onCompleted: {
        console.log("=== Step5 组件加载完成 ===")
        console.log("stepData:", JSON.stringify(stepData))
        debugDataStructure()

        checkSeparatorNeed()

        // 🔥 移除模拟数据，只加载真实数据
        loadSeparatorsFromDatabase()
    }

    // 🔥 采用Step3的stepData变化监听模式
    onStepDataChanged: {
        console.log("=== Step5: stepData 发生变化 ===")
        console.log("新的 stepData:", JSON.stringify(stepData))
        debugDataStructure()

        // 重新评估分离器需求
        checkSeparatorNeed()

        // 如果有预测结果但还没有选择分离器，进行智能推荐
        if (stepData.prediction && stepData.prediction.finalValues && !selectedSeparator && availableSeparators.length > 0) {
            console.log("=== Step5: 检测到预测结果，开始智能推荐 ===")
            Qt.callLater(function() {
                autoRecommendSeparator()
            })
        }
    }

    // // 🔥 添加像Step3一样的调试函数
    // function debugDataStructure() {
    //     console.log("=== Step5 调试数据结构 ===")

    //     if (stepData) {
    //         console.log("stepData exists")
    //         console.log("stepData keys:", Object.keys(stepData))

    //         if (stepData.prediction) {
    //             console.log("prediction exists")
    //             if (stepData.prediction.finalValues) {
    //                 console.log("finalValues exists:", JSON.stringify(stepData.prediction.finalValues, null, 2))
    //                 console.log("gasRate:", stepData.prediction.finalValues.gasRate)
    //             }
    //         } else {
    //             console.log("prediction 不存在")
    //         }

    //         if (stepData.parameters) {
    //             console.log("parameters exists")
    //             console.log("gasOilRatio:", stepData.parameters.gasOilRatio)
    //         } else {
    //             console.log("parameters 不存在")
    //         }
    //     } else {
    //         console.log("stepData 为空")
    //     }

    //     console.log("计算得到的气液比:", gasLiquidRatio)
    //     console.log("油气比:", gasOilRatio)
    // }

    // 🔥 添加像Step3一样的定期监控
    Timer {
        id: debugTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!stepData || !stepData.prediction || !stepData.parameters) {
                console.log("=== Step5 定期检查数据状态 ===")
                debugDataStructure()
            } else {
                running = false
                console.log("=== Step5 数据已完整，停止监控 ===")
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 🔥 修改标题栏，添加单位切换器
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

            // // 🔥 添加单位切换器
            // CommonComponents.UnitSwitcher {
            //     isChinese: root.isChineseMode
            //     showLabel: false
            // }

            // 🔥 修改当前条件显示，采用Step3的安全访问模式
            Rectangle {
                Layout.preferredWidth: childrenRect.width + 24
                Layout.preferredHeight: 36
                color: Material.dialogColor
                radius: 18

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: isChineseMode ? "当前条件：" : "Current Conditions:"
                        color: Material.hintTextColor
                        font.pixelSize: 12
                    }

                    Text {
                        text: {
                            var conditions = []

                            // 🔥 安全访问预测数据，添加单位转换
                            if (stepData && stepData.prediction && stepData.prediction.finalValues) {
                                var prod = stepData.prediction.finalValues.production
                                if (prod !== undefined && prod !== null) {
                                    conditions.push((isChineseMode ? "产量: " : "Prod: ") +
                                                  formatFlowRate(Number(prod)))
                                }

                                var gasRate = stepData.prediction.finalValues.gasRate
                                if (gasRate !== undefined && gasRate !== null) {
                                    conditions.push((isChineseMode ? "气液比: " : "GLR: ") +
                                                  gasLiquidRatio.toFixed(1) + "%")
                                }
                            }

                            // 🔥 安全访问参数数据，添加单位转换
                            if (stepData && stepData.parameters) {
                                var gor = stepData.parameters.gasOilRatio
                                if (gor !== undefined && gor !== null) {
                                    conditions.push("GOR: " + formatGasOilRatio(gor))
                                }
                            }

                            return conditions.length > 0 ? conditions.join(" | ") : (isChineseMode ? "数据加载中..." : "Loading data...")
                        }
                        color: Material.primaryTextColor
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            // 跳过按钮
            Button {
                text: isChineseMode ? "跳过此步" : "Skip This Step"
                flat: true
                onClicked: {
                    console.log("=== Step5 用户跳过此步 ===")
                    root.dataChanged({skipped: true})
                    root.nextStepRequested()
                }
            }
        }

        // 🔥 简化需求分析卡片，采用Step3的清晰逻辑
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

                // 🔥 简化关键参数显示
                Flow {
                    width: parent.width
                    spacing: 24

                    Row {
                        spacing: 8
                        Text {
                            text: isChineseMode ? "气液比:" : "GLR:"
                            color: Material.secondaryTextColor
                            font.pixelSize: 13
                        }
                        Text {
                            text: gasLiquidRatio.toFixed(2) + "%"
                            color: gasLiquidRatio >= 2.0 ? Material.color(Material.Orange) : Material.color(Material.Green)
                            font.pixelSize: 13
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
                                if (stepData && stepData.prediction && stepData.prediction.finalValues) {
                                    var production = stepData.prediction.finalValues.production || 0
                                    return formatFlowRate(Number(production))
                                }
                                return "N/A"
                            }
                            color: Material.primaryTextColor
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    // 🔥 添加推荐状态指示器
                    Rectangle {
                        width: childrenRect.width + 16
                        height: 24
                        radius: 12
                        color: needSeparator ? Material.color(Material.Orange, Material.Shade100) :
                                              Material.color(Material.Green, Material.Shade100)
                        border.width: 1
                        border.color: needSeparator ? Material.color(Material.Orange) :
                                                     Material.color(Material.Green)

                        Text {
                            anchors.centerIn: parent
                            text: needSeparator ? (isChineseMode ? "需要分离器" : "Need Separator") :
                                                 (isChineseMode ? "可选分离器" : "Optional")
                            color: needSeparator ? Material.color(Material.Orange, Material.Shade800) :
                                                  Material.color(Material.Green, Material.Shade800)
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }
            }
        }

        // 🔥 分离器选择区域（始终显示）
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // 🔥 数据加载错误状态
            Column {
                anchors.centerIn: parent
                spacing: 16
                visible: dataLoadError && !loading
                z: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⚠️"
                    font.pixelSize: 48
                    color: Material.color(Material.Red)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: isChineseMode ? "分离器数据加载失败" : "Failed to Load Separator Data"
                    color: Material.color(Material.Red)
                    font.pixelSize: 16
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: isChineseMode ? "请检查数据库连接或联系管理员" : "Please check database connection or contact administrator"
                    color: Material.hintTextColor
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: isChineseMode ? "重新加载" : "Retry"
                    onClicked: {
                        loadSeparatorsFromDatabase()
                    }
                }
            }

            ScrollView {
                id: separatorScroll
                anchors.fill: parent
                clip: true

                contentWidth: separatorGrid.implicitWidth
                contentHeight: separatorGrid.implicitHeight

                GridLayout {
                    id: separatorGrid
                    columns: separatorScroll.width > 1200 ? 3 : (separatorScroll.width > 800 ? 2 : 1)
                    columnSpacing: 16
                    rowSpacing: 16
                    width: separatorScroll.width

                    // 🔥 不使用分离器选项
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
                        matchScore: calculateSeparatorMatchScore({id: 0, isNoSeparator: true})
                        isChineseMode: root.isChineseMode
                        isMetric: root.isMetric  // 🔥 传递单位制属性

                        onClicked: {
                            console.log("选择不使用分离器")
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
                            isMetric: root.isMetric  // 🔥 传递单位制属性

                            onClicked: {
                                console.log("选择分离器:", modelData.model)
                                selectedSeparator = modelData
                                updateStepData()
                            }
                        }
                    }
                }

                // 🔥 修改空状态显示
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    visible: !loading && !dataLoadError && availableSeparators.length === 0
                    z: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📦"
                        font.pixelSize: 48
                        color: Material.hintTextColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "数据库中暂无分离器数据" : "No separators found in database"
                        color: Material.hintTextColor
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isChineseMode ? "请联系管理员添加设备数据" : "Please contact administrator to add device data"
                        color: Material.hintTextColor
                        font.pixelSize: 12
                    }
                }

            }

            // 加载指示器
            BusyIndicator {
                anchors.centerIn: parent
                running: loading
                visible: running
                z: 2
            }
        }

        // 选中的分离器详情
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: selectedSeparator && !selectedSeparator.isNoSeparator ? 160 : 0
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

                    // 匹配度指示
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

                // 🔥 简化技术参数显示
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 24
                    rowSpacing: 8

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

                    Column {
                        Text {
                            text: isChineseMode ? "气体处理能力" : "Gas Capacity"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: {
                                if (!selectedSeparator) return "N/A"
                                return formatGasCapacity(selectedSeparator.gasHandlingCapacity)
                            }
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                    }

                    Column {
                        Text {
                            text: isChineseMode ? "液体处理能力" : "Liquid Capacity"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: {
                                if (!selectedSeparator) return "N/A"
                                return formatFlowRate(selectedSeparator.liquidHandlingCapacity)
                            }
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                    }

                    Column {
                        Text {
                            text: isChineseMode ? "外径" : "OD"
                            font.pixelSize: 12
                            color: Material.hintTextColor
                        }
                        Text {
                            text: {
                                if (!selectedSeparator) return "N/A"
                                return formatDiameter(selectedSeparator.outerDiameter)
                            }
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

    // 🔥 =================================
    // 🔥 业务逻辑函数 - 采用Step3的简单模式
    // 🔥 =================================

    function checkSeparatorNeed() {
        console.log("=== 检查分离器需求 ===")
        console.log("气液比:", gasLiquidRatio, "%")
        console.log("油气比:", gasOilRatio, "scf/bbl")

        // 🔥 简化判断逻辑：主要看气液比
        needSeparator = gasLiquidRatio >= 2.0

        // 🔥 高油气比的额外判断
        if (gasOilRatio > 500) {
            needSeparator = true
        }

        console.log("是否需要分离器:", needSeparator)
    }

    function loadSeparators() {
        loading = true
        separatorTimer.start()

        console.log("=== 开始从数据库加载分离器数据 ===")

        // 🔥 从数据库加载分离器数据，而不是使用定时器模拟
        if (controller) {
            // 调用控制器方法获取分离器数据
            controller.getSeparatorsByType()
        } else {
            console.warn("控制器不可用，使用模拟数据")
            // 后备方案：使用模拟数据
            separatorTimer.start()
        }
    }

    Timer {
        id: separatorTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            availableSeparators = generateMockSeparatorData()
            loading = false

            // 🔥 数据加载完成后自动推荐
            if (stepData.prediction && stepData.prediction.finalValues) {
                autoRecommendSeparator()
            }
        }
    }


    // 🔥 采用Step3的计算模式：简化匹配度计算
    function calculateSeparatorMatchScore(separator) {
        if (!separator) return 50

        if (separator.isNoSeparator) {
            // 不使用分离器的评分
            return gasLiquidRatio < 2.0 ? 90 : 30
        }

        var score = 100

        try {
            // 气体处理能力匹配
            if (stepData && stepData.prediction && stepData.prediction.finalValues && gasOilRatio > 0) {
                var production = stepData.prediction.finalValues.production || 0
                var requiredGasCapacity = production * gasOilRatio / 1000  // mcf/d

                if (requiredGasCapacity > separator.gasHandlingCapacity) {
                    score -= 40  // 容量不足
                } else if (requiredGasCapacity < separator.gasHandlingCapacity * 0.3) {
                    score -= 20  // 容量过剩
                }
            }

            // 液体处理能力匹配
            if (stepData && stepData.prediction && stepData.prediction.finalValues) {
                var production = stepData.prediction.finalValues.production || 0
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

        } catch (error) {
            console.log("计算分离器匹配度时出错:", error)
            return 50
        }
    }

    // 🔥 新增：智能推荐分离器
    function autoRecommendSeparator() {
        console.log("=== 开始智能推荐分离器 ===")

        if (!stepData.prediction || !stepData.prediction.finalValues) {
            console.log("没有预测结果，无法推荐")
            return
        }

        if (selectedSeparator) {
            console.log("已有选择的分离器，跳过推荐")
            return
        }

        var bestSeparator = null
        var bestScore = 0

        // 评估不使用分离器的选项
        var noSeparatorScore = calculateSeparatorMatchScore({id: 0, isNoSeparator: true})
        if (noSeparatorScore > bestScore) {
            bestScore = noSeparatorScore
            bestSeparator = {id: 0, isNoSeparator: true}
        }

        // 评估可用分离器
        for (var i = 0; i < availableSeparators.length; i++) {
            var separator = availableSeparators[i]
            var score = calculateSeparatorMatchScore(separator)

            if (score > bestScore) {
                bestScore = score
                bestSeparator = separator
            }
        }

        if (bestSeparator && bestScore >= 60) {
            console.log("推荐分离器:", bestSeparator.id === 0 ? "不使用分离器" : bestSeparator.model, "分数:", bestScore)

            if (bestSeparator.id === 0) {
                selectedSeparator = {
                    id: 0,
                    name: isChineseMode ? "不使用分离器" : "No Separator",
                    manufacturer: isChineseMode ? "继续不使用" : "Continue Without",
                    model: isChineseMode ? "标准配置" : "Standard Configuration",
                    isNoSeparator: true
                }
            } else {
                selectedSeparator = bestSeparator
            }

            updateStepData()
        }
    }

    // 🔥 简化分析文本生成
    function getSeparatorAnalysis() {
        var analysis = ""
        var threshold = 2.0

        if (needSeparator) {
            analysis = isChineseMode
                     ? `基于当前井况分析：气液比为 ${gasLiquidRatio.toFixed(1)}% ≥ ${threshold}%，建议使用分离器以提高泵效率和延长设备寿命。`
                     : `Based on current conditions: GLR is ${gasLiquidRatio.toFixed(1)}% ≥ ${threshold}%, separator recommended to improve pump efficiency and equipment life.`

            if (gasOilRatio > 500) {
                analysis += isChineseMode
                          ? `\n油气比较高 (${gasOilRatio.toFixed(0)} scf/bbl)，分离器可显著改善系统性能。`
                          : `\nHigh GOR (${gasOilRatio.toFixed(0)} scf/bbl), separator will significantly improve system performance.`
            }
        } else {
            analysis = isChineseMode
                     ? `当前气液比较低 (${gasLiquidRatio.toFixed(1)}% < ${threshold}%)，可能不需要分离器。但如果井况可能变化或需要额外保障，仍可考虑使用。`
                     : `Current GLR is low (${gasLiquidRatio.toFixed(1)}% < ${threshold}%), separator may not be necessary. Consider if well conditions may change or extra security is needed.`
        }

        return analysis
    }

    function getPerformanceAnalysis() {
        if (!selectedSeparator || selectedSeparator.isNoSeparator) return ""

        var score = calculateSeparatorMatchScore(selectedSeparator)

        if (score >= 80) {
            return isChineseMode
                 ? "✓ 该分离器非常适合当前工况，容量匹配良好，可有效提升系统性能。"
                 : "✓ This separator is well-suited for current conditions with good capacity match."
        } else if (score >= 60) {
            return isChineseMode
                 ? "⚠ 该分离器基本满足要求，但需注意容量余量或尺寸限制。"
                 : "⚠ This separator meets basic requirements but check capacity margin or size constraints."
        } else {
            return isChineseMode
                 ? "✗ 该分离器可能不是最佳选择，建议选择更匹配的型号。"
                 : "✗ This separator may not be optimal, consider better matched models."
        }
    }
    // 🔥 修改updateStepData函数，确保数据结构完整
    function updateStepData() {
        if (!selectedSeparator) return

        var data = {
            selectedSeparator: selectedSeparator.id,
            manufacturer: selectedSeparator.manufacturer || "Unknown",
            model: selectedSeparator.model || selectedSeparator.name || "Unknown Model",
            separationEfficiency: selectedSeparator.separationEfficiency || 0,
            gasHandlingCapacity: selectedSeparator.gasHandlingCapacity || 0,
            liquidHandlingCapacity: selectedSeparator.liquidHandlingCapacity || 0,
            outerDiameter: selectedSeparator.outerDiameter || 0,
            specifications: selectedSeparator.isNoSeparator
                          ? (isChineseMode ? "不使用分离器" : "No separator")
                          : `${selectedSeparator.model || selectedSeparator.name} - ${selectedSeparator.separationEfficiency || 0}% ${isChineseMode ? "分离效率" : "efficiency"}`,
            skipped: selectedSeparator.isNoSeparator || selectedSeparator.id === 0,
            matchScore: calculateSeparatorMatchScore(selectedSeparator),
            // 🔥 添加完整的分离器详情到stepData
            separatorDetails: {
                id: selectedSeparator.id,
                name: selectedSeparator.name || selectedSeparator.model,
                manufacturer: selectedSeparator.manufacturer,
                model: selectedSeparator.model,
                series: selectedSeparator.series,
                separationEfficiency: selectedSeparator.separationEfficiency,
                gasHandlingCapacity: selectedSeparator.gasHandlingCapacity,
                liquidHandlingCapacity: selectedSeparator.liquidHandlingCapacity,
                outerDiameter: selectedSeparator.outerDiameter,
                length: selectedSeparator.length,
                weight: selectedSeparator.weight,
                maxPressure: selectedSeparator.maxPressure,
                description: selectedSeparator.description,
                isNoSeparator: selectedSeparator.isNoSeparator || false
            }
        }

        console.log("=== Step5 updateStepData ===")
        console.log("发送的数据:", JSON.stringify(data))

        root.dataChanged(data)
        function collectStepData() {
            return updateStepData()
        }
    }
    function debugDataStructure() {
        console.log("=== Step5 调试数据结构 ===")

        if (stepData) {
            console.log("stepData exists")
            console.log("stepData keys:", Object.keys(stepData))

            if (stepData.prediction) {
                console.log("prediction exists")
                if (stepData.prediction.finalValues) {
                    console.log("finalValues exists:", JSON.stringify(stepData.prediction.finalValues, null, 2))
                    console.log("gasRate:", stepData.prediction.finalValues.gasRate)
                }
            } else {
                console.log("prediction 不存在")
            }

            if (stepData.parameters) {
                console.log("parameters exists")
                console.log("gasOilRatio:", stepData.parameters.gasOilRatio)
            } else {
                console.log("parameters 不存在")
            }
        } else {
            console.log("stepData 为空")
        }

        console.log("计算得到的气液比:", gasLiquidRatio)
        console.log("油气比:", gasOilRatio)
    }
    // 🔥 移除Timer，直接调用控制器
    function loadSeparatorsFromDatabase() {
        console.log("=== 开始从数据库加载分离器数据 ===")

        if (!controller) {
            console.error("❌ 控制器不可用，无法加载分离器数据")
            dataLoadError = true
            return
        }

        loading = true
        dataLoadError = false

        // 🔥 直接调用控制器方法，不使用定时器模拟
        console.log("🔄 调用控制器加载分离器...")
        controller.getSeparatorsByType()
    }
    // 🔥 添加单位转换和格式化函数
    function formatFlowRate(valueInBbl) {
        if (!valueInBbl || valueInBbl <= 0) return "N/A"

        if (isMetric) {
            // 转换为 m³/d
            var m3Value = valueInBbl * 0.159
            return m3Value.toFixed(1) + " m³/d"
        } else {
            // 保持 bbl/d
            return valueInBbl.toFixed(0) + " bbl/d"
        }
    }

    function formatGasCapacity(valueInMcf) {
        if (!valueInMcf || valueInMcf <= 0) return "N/A"

        if (isMetric) {
            // 转换为 m³/d (1 mcf = 28.317 m³)
            var m3Value = valueInMcf * 28.317
            return m3Value.toFixed(0) + " m³/d"
        } else {
            // 保持 mcf/d
            return valueInMcf.toFixed(1) + " mcf/d"
        }
    }

    function formatGasOilRatio(value) {
        if (!value || value <= 0) return "N/A"

        if (isMetric) {
            // 转换为 m³/m³
            var m3Value = value / 5.615
            return m3Value.toFixed(0) + " m³/m³"
        } else {
            // 保持 scf/bbl
            return value.toFixed(0) + " scf/bbl"
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
            return valueInInches.toFixed(1) + " in"
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

    function formatPressure(valueInPsi) {
        if (!valueInPsi || valueInPsi <= 0) return "N/A"

        if (isMetric) {
            // 转换为MPa
            var mpaValue = valueInPsi / 145.038
            return mpaValue.toFixed(1) + " MPa"
        } else {
            // 保持psi
            return valueInPsi.toFixed(0) + " psi"
        }
    }

    // 🔥 强制更新显示的函数
    function updateParameterDisplays() {
        console.log("更新Step5参数显示，当前单位制:", isMetric ? "公制" : "英制")
    }
}
