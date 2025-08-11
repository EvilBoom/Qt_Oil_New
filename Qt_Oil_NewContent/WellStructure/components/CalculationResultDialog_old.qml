import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Window {
    id: root
    // 添加显示控制属性
    property bool autoShow: false  // 控制是否自动显示

    property bool isChineseMode: true
    property var calculationResult: null
    property var wellStructureController: null
    property var wellController: null
    property bool resultSaved: false
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    title: isChineseMode ? "计算结果" : "Calculation Results"
    width: 600
    height: 500
    modality: Qt.ApplicationModal
    flags: Qt.Dialog

    // 🔥 监听单位制变化
    onIsMetricChanged: {
        console.log("CalculationResultDialog单位制切换为:", isMetric ? "公制" : "英制")
        updateDisplayUnits()
    }
    // 🔥 连接单位制控制器
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("CalculationResultDialog单位制切换为:", isMetric ? "公制" : "英制")
            updateDisplayUnits()
        }
    }
    // 🔥 新增：连接WellStructureController的信号
    Connections {
        target: wellStructureController
        enabled: wellStructureController !== null

        function onCalculationCompleted(result) {
            console.log("=== 接收到计算完成信号 ===")
            console.log("计算结果:", JSON.stringify(result))

            // 更新计算结果
            calculationResult = result
            resultSaved = false

            // 只有在需要自动显示时才显示对话框
            if (autoShow) {
                show()
            }
            // 自动尝试保存
            Qt.callLater(saveCalculationResult)
        }

        // 添加显示方法，供外部调用
        function showCalculationResult(result, shouldAutoShow = true) {
            calculationResult = result
            autoShow = shouldAutoShow
            show()
        }

        function onOperationStarted() {
            console.log("井身结构控制器操作开始")
            // 可以显示loading状态
        }

        function onOperationFinished() {
            console.log("井身结构控制器操作完成")
            // 可以隐藏loading状态
        }

        function onError(errorMessage) {
            console.error("井身结构控制器错误:", errorMessage)
            showMessage(errorMessage, true)
            resultSaved = false
        }
    }

    // 🔥 新增：连接WellController的信号
    Connections {
        target: wellController
        enabled: wellController !== null

        function onWellDataSaved(success) {
            if (success) {
                console.log("✅ 井数据保存成功")
                resultSaved = true
                showMessage(isChineseMode ? "计算结果已保存到井数据" : "Calculation results saved to well data", false)
            } else {
                console.log("❌ 井数据保存失败")
                showMessage(isChineseMode ? "井数据保存失败" : "Failed to save well data", true)
            }
        }

        function onCurrentWellChanged() {
            console.log("当前井发生变化")
            // 如果井发生变化，重置保存状态
            resultSaved = false
        }

        function onOperationStarted() {
            console.log("井数据控制器操作开始")
        }

        function onOperationFinished() {
            console.log("井数据控制器操作完成")
        }

        function onError(errorMessage) {
            console.error("井数据控制器错误:", errorMessage)
            showMessage(errorMessage, true)
        }
    }

    // 🔥 新增：连接全局wellStructureController信号（备用）
    Connections {
        target: typeof wellStructureController !== "undefined" ? wellStructureController : null
        enabled: target !== null && !root.wellStructureController

        function onCalculationCompleted(result) {
            console.log("=== 从全局控制器接收到计算完成信号 ===")
            calculationResult = result
            resultSaved = false
            Qt.callLater(saveCalculationResult)
        }
    }

    // 🔥 新增：连接全局wellController信号（备用）
    Connections {
        target: typeof wellController !== "undefined" ? wellController : null
        enabled: target !== null && !root.wellController

        function onWellDataSaved(success) {
            if (success && calculationResult) {
                resultSaved = true
                showMessage(isChineseMode ? "计算结果已保存" : "Calculation results saved", false)
            }
        }
    }
    // 在现有的 Connections 后添加单位制监听
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("单位制切换为:", isMetric ? "公制" : "英制")
        }
    }

    // 监听计算结果变化，但不自动保存（通过信号触发）
    onCalculationResultChanged: {
        if (calculationResult) {
            console.log("=== 计算结果已更新 ===")
            console.log("新结果:", JSON.stringify(calculationResult))
        }
    }

    // 主要内容区域
    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 20

            // 保存状态指示器
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: resultSaved ? "#e8f5e8" : "#fff3cd"
                border.color: resultSaved ? "#28a745" : "#ffc107"
                radius: 4
                visible: calculationResult

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: resultSaved ? "✅" : "⏳"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: resultSaved ?
                              (isChineseMode ? "计算结果已保存到数据库" : "Calculation results saved to database") :
                              (isChineseMode ? "等待保存计算结果..." : "Waiting to save calculation results...")
                        font.pixelSize: 14
                        color: resultSaved ? "#155724" : "#856404"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // 重新保存按钮
                    Button {
                        text: isChineseMode ? "重新保存" : "Save Again"
                        flat: true
                        visible: !resultSaved && calculationResult
                        onClicked: saveCalculationResult()
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 主要结果
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "计算结果" : "Calculation Results"

                background: Rectangle {
                    color: "#f0f8ff"
                    border.color: "#4a90e2"
                    radius: 4
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 16
                    columnSpacing: 30

                    // 🔥 泵挂垂深 - 支持单位转换
                    Label {
                        text: isChineseMode ? "泵挂垂深:" : "Pump Hanging Depth:"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    Label {
                        text: calculationResult ?
                            formatDepthValue(calculationResult.pump_hanging_depth, "ft") :
                            "-"
                        font.pixelSize: 18
                        color: "#4a90e2"
                        font.bold: true
                    }

                    // 🔥 射孔垂深 - 支持单位转换
                    Label {
                        text: isChineseMode ? "射孔垂深:" : "Perforation Depth:"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    Label {
                        text: calculationResult ?
                            formatDepthValue(calculationResult.perforation_depth, "ft") :
                            "-"
                        font.pixelSize: 18
                        color: "#4a90e2"
                        font.bold: true
                    }

                    // 🔥 泵挂测量深度 - 支持单位转换
                    Label {
                        text: isChineseMode ? "泵挂测量深度:" : "Pump Measured Depth:"
                        font.pixelSize: 14
                        visible: calculationResult && calculationResult.pump_measured_depth
                    }
                    Label {
                        text: calculationResult && calculationResult.pump_measured_depth ?
                            formatDepthValue(calculationResult.pump_measured_depth, "ft") :
                            "-"
                        font.pixelSize: 14
                        color: "#666"
                        visible: calculationResult && calculationResult.pump_measured_depth
                    }

                    // 计算时间
                    Label {
                        text: isChineseMode ? "计算时间:" : "Calculation Time:"
                        font.pixelSize: 14
                    }
                    Label {
                        text: calculationResult && calculationResult.calculation_date ?
                            formatDateTime(calculationResult.calculation_date) :
                            Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
                        font.pixelSize: 14
                        color: "#666"
                    }

                    // 计算方法
                    Label {
                        text: isChineseMode ? "计算方法:" : "Calculation Method:"
                        font.pixelSize: 14
                    }
                    Label {
                        text: calculationResult ?
                            (calculationResult.calculation_method || "default") : "-"
                        font.pixelSize: 14
                        color: "#666"
                    }
                }
            }

            // 轨迹统计
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "轨迹统计" : "Trajectory Statistics"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 30

                    Label {
                        text: isChineseMode ?
                            `总垂深 (${getDepthUnit()}):` :
                            `Total TVD (${getDepthUnit()}):`
                    }
                    Label {
                        text: calculationResult ?
                            formatDepthValue(calculationResult.total_depth_tvd, "m") :
                            "-"
                        color: "#333"
                    }

                    Label {
                        text: isChineseMode ?
                            `总测深 (${getDepthUnit()}):` :
                            `Total MD (${getDepthUnit()}):`
                    }
                    Label {
                        text: calculationResult ?
                            formatDepthValue(calculationResult.total_depth_md, "m") :
                            "-"
                        color: "#333"
                    }

                    Label {
                        text: isChineseMode ? "最大井斜角 (°):" : "Max Inclination (°):"
                    }
                    Label {
                        text: calculationResult && calculationResult.max_inclination ?
                            `${calculationResult.max_inclination.toFixed(1)}°` : "-"
                        color: calculationResult && calculationResult.max_inclination > 45 ?
                            "#ff9800" : "#333"
                    }

                    Label {
                        text: isChineseMode ?
                            `最大狗腿度 (${getDoglegUnit()}):` :
                            `Max DLS (${getDoglegUnit()}):`
                    }
                    Label {
                        text: calculationResult && calculationResult.max_dls ?
                            formatDoglegSeverity(calculationResult.max_dls) :
                            "-"
                        color: calculationResult && calculationResult.max_dls > (isMetric ? 10.16 : 10) ?
                            "#f44336" : "#333"
                    }
                }
            }
            // 🔥 添加单位转换详情卡片
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "单位转换信息" : "Unit Conversion Info"
                visible: calculationResult

                background: Rectangle {
                    color: "#f3e5f5"
                    border.color: "#9c27b0"
                    radius: 4
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        text: isChineseMode ?
                            `当前显示单位: ${getDepthUnitText()}` :
                            `Current Display Unit: ${getDepthUnitText()}`
                        font.pixelSize: 12
                        color: "#7b1fa2"
                        font.bold: true
                    }

                    Text {
                        text: isChineseMode ?
                            "说明：计算结果已根据当前单位制自动转换显示" :
                            "Note: Results are automatically converted based on current unit system"
                        font.pixelSize: 11
                        color: "#424242"
                        font.italic: true
                    }

                    // 🔥 显示原始值和转换值对比
                    Text {
                        text: getConversionDetails()
                        font.pixelSize: 10
                        color: "#666"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            // 计算参数
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "计算参数" : "Calculation Parameters"
                visible: calculationResult && calculationResult.parameters

                ScrollView {
                    anchors.fill: parent
                    height: 100

                    TextArea {
                        text: formatParameters(calculationResult ? calculationResult.parameters : "{}")
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextArea.Wrap
                        font.family: "Consolas, Monaco, monospace"
                        font.pixelSize: 12

                        background: Rectangle {
                            color: "#f5f5f5"
                            radius: 4
                        }
                    }
                }
            }

            // 建议
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "建议" : "Recommendations"

                background: Rectangle {
                    color: "#fff8e1"
                    border.color: "#ffc107"
                    radius: 4
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Row {
                        spacing: 5

                        Text {
                            text: "💡"
                            font.pixelSize: 16
                        }

                        Label {
                            text: getRecommendation()
                            wrapMode: Text.Wrap
                            color: "#795548"
                        }
                    }
                }
            }

            // 按钮区域
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    text: isChineseMode ? "查看历史记录" : "View History"
                    flat: true
                    onClicked: showHistory()
                }

                // 手动保存按钮
                Button {
                    text: isChineseMode ? "保存结果" : "Save Results"
                    enabled: calculationResult && !resultSaved
                    onClicked: saveCalculationResult()
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: isChineseMode ? "导出结果" : "Export Results"
                    onClicked: exportResults()
                }

                Button {
                    text: isChineseMode ? "关闭" : "Close"
                    onClicked: close()
                }
            }
        }
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatDepthValue(value, sourceUnit) {
        if (!value || value <= 0) return "0 " + getDepthUnit()

        var convertedValue = value
        var targetUnit = getDepthUnit()

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

        return convertedValue.toFixed(1) + " " + targetUnit
    }

    function formatDoglegSeverity(value) {
        if (!value || value <= 0) return "0 " + getDoglegUnit()

        var convertedValue = value

        if (isMetric) {
            // 转换为 °/30m
            convertedValue = value * (30.48 / 30)
        }
        // 英制保持原值 (°/100ft)

        return convertedValue.toFixed(2) + " " + getDoglegUnit()
    }

    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDoglegUnit() {
        return isMetric ? "°/30m" : "°/100ft"
    }

    function getDepthUnitText() {
        if (isChineseMode) {
            return isMetric ? "米" : "英尺"
        } else {
            return isMetric ? "meters" : "feet"
        }
    }

    function getConversionDetails() {
        if (!calculationResult) return ""

        var details = []

        if (calculationResult.pump_hanging_depth) {
            var pumpDepthFt = parseFloat(calculationResult.pump_hanging_depth)
            var pumpDepthM = UnitUtils.feetToMeters(pumpDepthFt)

            if (isMetric) {
                details.push(`泵挂深度: ${pumpDepthM.toFixed(1)} m (原始: ${pumpDepthFt.toFixed(1)} ft)`)
            } else {
                details.push(`Pump depth: ${pumpDepthFt.toFixed(1)} ft (${pumpDepthM.toFixed(1)} m)`)
            }
        }

        if (calculationResult.perforation_depth) {
            var perfDepthFt = parseFloat(calculationResult.perforation_depth)
            var perfDepthM = UnitUtils.feetToMeters(perfDepthFt)

            if (isMetric) {
                details.push(`射孔深度: ${perfDepthM.toFixed(1)} m (原始: ${perfDepthFt.toFixed(1)} ft)`)
            } else {
                details.push(`Perforation depth: ${perfDepthFt.toFixed(1)} ft (${perfDepthM.toFixed(1)} m)`)
            }
        }

        return details.join("\n")
    }

    function updateDisplayUnits() {
        console.log("更新计算结果对话框显示单位")
        // 强制刷新显示，如果需要的话可以触发重新绘制
    }

    // 🔥 改进的保存计算结果函数
    function saveCalculationResult() {
        if (!calculationResult) {
            console.warn("没有计算结果可保存")
            showMessage(isChineseMode ? "没有计算结果可保存" : "No calculation results to save", true)
            return
        }

        console.log("=== 开始保存计算结果到数据库 ===")
        console.log("计算结果:", JSON.stringify(calculationResult))

        var saveAttempted = false

        // 优先通过传入的控制器保存
        if (wellStructureController && wellStructureController.saveCalculationResult) {
            try {
                console.log("📞 通过传入的wellStructureController保存...")
                wellStructureController.saveCalculationResult(calculationResult)
                saveAttempted = true
                console.log("✅ wellStructureController调用成功，等待信号确认...")
            } catch (error) {
                console.error("❌ wellStructureController调用失败:", error)
            }
        }

        // 同时尝试通过wellController保存关键深度
        if (wellController && wellController.saveCalculatedDepths) {
            try {
                console.log("📞 通过wellController保存关键深度...")
                var pumpDepth = calculationResult.pump_hanging_depth || 0
                var perforationDepth = calculationResult.perforation_depth || 0

                if (pumpDepth > 0 || perforationDepth > 0) {
                    wellController.saveCalculatedDepths(pumpDepth, perforationDepth)
                    saveAttempted = true
                    console.log("✅ wellController关键深度调用成功，等待信号确认...")
                }
            } catch (error) {
                console.error("❌ wellController调用失败:", error)
            }
        }

        // 备用：尝试全局控制器
        if (!saveAttempted) {
            console.log("🔄 尝试全局控制器...")
            try {
                if (typeof wellStructureController !== "undefined" && wellStructureController && wellStructureController.saveCalculationResult) {
                    wellStructureController.saveCalculationResult(calculationResult)
                    saveAttempted = true
                    console.log("✅ 全局wellStructureController调用成功")
                }
            } catch (error) {
                console.error("❌ 全局控制器调用失败:", error)
            }
        }

        if (!saveAttempted) {
            console.error("❌ 所有保存方法都不可用")
            showMessage(isChineseMode ? "保存失败：无法访问数据库控制器" : "Save failed: Cannot access database controller", true)
        } else {
            console.log("⏳ 保存请求已发送，等待控制器信号确认...")
            showMessage(isChineseMode ? "正在保存计算结果..." : "Saving calculation results...", false)
        }
    }

    // 显示消息提示
    function showMessage(message, isError) {
        console.log(isError ? "❌" : "✅", message)
        // 这里可以集成Toast组件或其他UI提示
    }

    // 显示计算结果
    function showResult(result) {
        console.log("=== 显示计算结果 ===")
        console.log("result:", JSON.stringify(result))

        calculationResult = result
        resultSaved = false
        show()
    }

    // 设置控制器引用
    function setControllers(wellStructController, wellDataController) {
        console.log("=== 设置控制器引用 ===")
        wellStructureController = wellStructController
        wellController = wellDataController

        console.log("WellStructureController:", wellStructureController ? "已设置" : "未设置")
        console.log("WellController:", wellController ? "已设置" : "未设置")
    }

    // 格式化日期时间
    function formatDateTime(dateStr) {
        try {
            var date = new Date(dateStr)
            return Qt.formatDateTime(date, "yyyy-MM-dd hh:mm:ss")
        } catch (e) {
            return dateStr
        }
    }

    // 格式化参数
    function formatParameters(paramsStr) {
        try {
            var params = JSON.parse(paramsStr)
            return JSON.stringify(params, null, 2)
        } catch (e) {
            return paramsStr
        }
    }

    // 🔥 修改获取建议函数，考虑单位制
    function getRecommendation() {
        if (!calculationResult) {
            return ""
        }

        var recommendations = []

        // 基于最大井斜角的建议
        if (calculationResult.max_inclination > 60) {
            recommendations.push(isChineseMode ?
                "井斜角较大，建议使用特殊的泵挂工具" :
                "High inclination angle, special pump hanging tools recommended")
        }

        // 基于狗腿度的建议 (考虑单位制)
        var dlsThreshold = isMetric ? 15.24 : 15  // 公制需要调整阈值
        if (calculationResult.max_dls > dlsThreshold) {
            recommendations.push(isChineseMode ?
                "狗腿度过大，可能影响设备下入，建议进行详细评估" :
                "High DLS may affect equipment running, detailed evaluation recommended")
        }

        // 基于深度的建议 (考虑单位制)
        var depthThresholdM = 3000
        var depthThresholdFt = 9842  // 约3000m
        var totalDepth = calculationResult.total_depth_tvd || 0

        var isDeepWell = false
        if (isMetric) {
            isDeepWell = totalDepth > depthThresholdM
        } else {
            // 如果数据是英尺存储，需要转换比较
            var totalDepthM = UnitUtils.feetToMeters(totalDepth)
            isDeepWell = totalDepthM > depthThresholdM
        }

        if (isDeepWell) {
            recommendations.push(isChineseMode ?
                "井深较大，建议考虑温度和压力对设备的影响" :
                "Deep well, consider temperature and pressure effects on equipment")
        }

        // 基于保存状态的建议
        if (!resultSaved && calculationResult) {
            recommendations.push(isChineseMode ?
                "⚠️ 建议保存计算结果以便后续使用" :
                "⚠️ Recommend saving calculation results for future use")
        }

        // 🔥 添加单位制相关建议
        recommendations.push(isChineseMode ?
            `📏 当前以${getDepthUnitText()}为单位显示深度数据` :
            `📏 Depth data is currently displayed in ${getDepthUnitText()}`)

        if (recommendations.length === 1) {  // 只有单位制提示
            recommendations.push(isChineseMode ?
                "计算结果在正常范围内，可按常规工艺进行施工" :
                "Results are within normal range, standard procedures can be followed")
        }

        return recommendations.join("\n")
    }

    // 显示历史记录
    function showHistory() {
        if (wellStructureController && wellStructureController.getCalculationHistory) {
            wellStructureController.getCalculationHistory(calculationResult.well_id)
        } else {
            console.log("Show calculation history - controller not available")
        }
    }

    // 🔥 修改导出结果函数，包含单位信息
    function exportResults() {
        if (!calculationResult) {
            showMessage(isChineseMode ? "没有可导出的结果" : "No results to export", true)
            return
        }

        var exportData = {
            title: isChineseMode ? "井身结构计算结果" : "Well Structure Calculation Results",
            timestamp: Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss"),
            unitSystem: isMetric ? "Metric" : "Imperial",
            depthUnit: getDepthUnit(),
            results: calculationResult,
            formattedResults: {
                pump_hanging_depth: formatDepthValue(calculationResult.pump_hanging_depth, "ft"),
                perforation_depth: formatDepthValue(calculationResult.perforation_depth, "ft"),
                total_depth_tvd: formatDepthValue(calculationResult.total_depth_tvd, "m"),
                total_depth_md: formatDepthValue(calculationResult.total_depth_md, "m"),
                max_dls: formatDoglegSeverity(calculationResult.max_dls)
            },
            recommendations: getRecommendation(),
            conversionDetails: getConversionDetails()
        }

        console.log("导出计算结果:", JSON.stringify(exportData, null, 2))
        showMessage(isChineseMode ? "导出功能开发中..." : "Export feature in development...", false)
    }

}
