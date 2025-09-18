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
    // property var wellStructureController: null
    // property var wellController: null
    property bool resultSaved: false
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    // 🔥 新增：用户手动输入的深度值
    property real userPumpDepth: 0
    property real userPerforationDepth: 0
    property bool hasUserInput: false

    title: isChineseMode ? "计算结果" : "Calculation Results"
    width: 700
    height: 650
    modality: Qt.ApplicationModal
    flags: Qt.Dialog

    // 🔥 监听单位制变化，更新SpinBox显示
    onIsMetricChanged: {
        console.log("CalculationResultDialog单位制切换为:", isMetric ? "公制" : "英制")
        updateDisplayUnits()

        // 🔥 更新SpinBox显示值（不触发onValueChanged）
        if (pumpDepthInput) {
            pumpDepthInput.value = getDisplayDepthValue(userPumpDepth)
        }
        if (perforationDepthInput) {
            perforationDepthInput.value = getDisplayDepthValue(userPerforationDepth)
        }
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

    // 🔥 保留WellController的信号连接，用于保存结果的反馈
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

    // 监听计算结果变化
    onCalculationResultChanged: {
        if (calculationResult) {
            console.log("=== 计算结果已更新 ===")
            console.log("新结果:", JSON.stringify(calculationResult))

            // 🔥 初始化用户输入值为推荐值（存储为英尺）
            if (calculationResult.pump_hanging_depth) {
                userPumpDepth = parseFloat(calculationResult.pump_hanging_depth)
            }
            if (calculationResult.perforation_depth) {
                userPerforationDepth = parseFloat(calculationResult.perforation_depth)
            }
            hasUserInput = false

            // 🔥 强制更新SpinBox显示值
            if (pumpDepthInput) {
                pumpDepthInput.value = getDisplayDepthValue(userPumpDepth)
            }
            if (perforationDepthInput) {
                perforationDepthInput.value = getDisplayDepthValue(userPerforationDepth)
            }
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

            // 🔥 修改：关键深度输入区（推荐值）
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "关键深度设置 (推荐值)" : "Key Depths Settings (Recommended)"

                background: Rectangle {
                    color: "#f0f8ff"
                    border.color: "#4a90e2"
                    radius: 4
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 3
                    rowSpacing: 16
                    columnSpacing: 20

                    // 泵挂垂深标签
                    Label {
                        text: isChineseMode ? "泵挂垂深:" : "Pump Hanging Depth:"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    // 泵挂垂深输入框 - 🔥 修复单位转换
                    SpinBox {
                        id: pumpDepthInput
                        Layout.preferredWidth: 150
                        from: 0
                        to: 99999
                        value: getDisplayDepthValue(userPumpDepth)
                        stepSize: 1
                        editable: true

                        onValueChanged: {
                            // 🔥 将显示值转换回存储值（英尺）
                            userPumpDepth = getStorageDepthValue(value)
                            hasUserInput = true
                        }

                        background: Rectangle {
                            color: hasUserInput ? "#fff3cd" : "#ffffff"
                            border.color: hasUserInput ? "#ffc107" : "#cccccc"
                            border.width: 1
                            radius: 4
                        }
                    }

                    // 泵挂垂深单位
                    Label {
                        text: getDepthUnit()
                        color: "#666"
                        font.pixelSize: 14
                    }

                    // 射孔垂深标签
                    Label {
                        text: isChineseMode ? "射孔垂深:" : "Perforation Depth:"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    // 射孔垂深输入框 - 🔥 修复单位转换
                    SpinBox {
                        id: perforationDepthInput
                        Layout.preferredWidth: 150
                        from: 0
                        to: 99999
                        value: getDisplayDepthValue(userPerforationDepth)
                        stepSize: 1
                        editable: true

                        onValueChanged: {
                            // 🔥 将显示值转换回存储值（英尺）
                            userPerforationDepth = getStorageDepthValue(value)
                            hasUserInput = true
                        }

                        background: Rectangle {
                            color: hasUserInput ? "#fff3cd" : "#ffffff"
                            border.color: hasUserInput ? "#ffc107" : "#cccccc"
                            border.width: 1
                            radius: 4
                        }
                    }

                    // 射孔垂深单位
                    Label {
                        text: getDepthUnit()
                        color: "#666"
                        font.pixelSize: 14
                    }

                    // 🔥 推荐值提示
                    Label {
                        Layout.columnSpan: 3
                        text: isChineseMode ?
                            "💡 以上显示为系统推荐值，您可以根据实际情况进行调整" :
                            "💡 Above values are system recommendations, adjust as needed"
                        font.pixelSize: 12
                        color: "#856404"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            // 🔥 新增：轨迹分析统计
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "轨迹分析" : "Trajectory Analysis"

                background: Rectangle {
                    color: "#fff8e1"
                    border.color: "#ff9800"
                    radius: 4
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 30

                    // 🔥 狗腿度>3.5°的数量
                    Label {
                        text: isChineseMode ? "狗腿度>3.5°点数:" : "DLS >3.5° Points:"
                        font.bold: true
                    }
                    Label {
                        text: getHighDoglegCount() + (isChineseMode ? " 个" : " points")
                        color: getHighDoglegCount() > 0 ? "#f44336" : "#4caf50"
                        font.bold: true
                    }

                    // 🔥 最大狗腿度及位置
                    Label {
                        text: isChineseMode ? "最大狗腿度:" : "Max DLS:"
                        font.bold: true
                    }
                    Column {
                        spacing: 4
                        
                        Label {
                            text: getMaxDoglegInfo().value
                            color: "#f44336"
                            font.bold: true
                        }
                        
                        Label {
                            text: isChineseMode ? 
                                `位置: ${getMaxDoglegInfo().location}` :
                                `At: ${getMaxDoglegInfo().location}`
                            font.pixelSize: 12
                            color: "#666"
                            visible: getMaxDoglegInfo().location !== ""
                        }
                    }

                    // 🔥 最大井斜角及位置
                    Label {
                        text: isChineseMode ? "最大井斜角:" : "Max Inclination:"
                        font.bold: true
                    }
                    Column {
                        spacing: 4
                        
                        Label {
                            text: getMaxInclinationInfo().value
                            color: getMaxInclinationInfo().isHigh ? "#ff9800" : "#4caf50"
                            font.bold: true
                        }
                        
                        Label {
                            text: isChineseMode ? 
                                `位置: ${getMaxInclinationInfo().location}` :
                                `At: ${getMaxInclinationInfo().location}`
                            font.pixelSize: 12
                            color: "#666"
                            visible: getMaxInclinationInfo().location !== ""
                        }
                    }

                    // 🔥 轨迹质量评估
                    Label {
                        text: isChineseMode ? "轨迹质量:" : "Trajectory Quality:"
                        font.bold: true
                    }
                    Label {
                        text: getTrajectoryQuality()
                        color: getTrajectoryQualityColor()
                        font.bold: true
                    }
                }
            }

            // 轨迹统计
            // GroupBox {
            //     Layout.fillWidth: true
            //     title: isChineseMode ? "轨迹统计" : "Trajectory Statistics"

            //     GridLayout {
            //         anchors.fill: parent
            //         columns: 2
            //         rowSpacing: 12
            //         columnSpacing: 30

            //         Label {
            //             text: isChineseMode ?
            //                 `总垂深 (${getDepthUnit()}):` :
            //                 `Total TVD (${getDepthUnit()}):`
            //         }
            //         Label {
            //             text: calculationResult ?
            //                 formatDepthValue(calculationResult.total_depth_tvd, "m") :
            //                 "-"
            //             color: "#333"
            //         }

            //         Label {
            //             text: isChineseMode ?
            //                 `总测深 (${getDepthUnit()}):` :
            //                 `Total MD (${getDepthUnit()}):`
            //         }
            //         Label {
            //             text: calculationResult ?
            //                 formatDepthValue(calculationResult.total_depth_md, "m") :
            //                 "-"
            //             color: "#333"
            //         }

            //         Label {
            //             text: isChineseMode ? "最大井斜角 (°):" : "Max Inclination (°):"
            //         }
            //         Label {
            //             text: calculationResult && calculationResult.max_inclination ?
            //                 `${calculationResult.max_inclination.toFixed(1)}°` : "-"
            //             color: calculationResult && calculationResult.max_inclination > 45 ?
            //                 "#ff9800" : "#333"
            //         }

            //         Label {
            //             text: isChineseMode ?
            //                 `最大狗腿度 (${getDoglegUnit()}):` :
            //                 `Max DLS (${getDoglegUnit()}):`
            //         }
            //         Label {
            //             text: calculationResult && calculationResult.max_dls ?
            //                 formatDoglegSeverity(calculationResult.max_dls) :
            //                 "-"
            //             color: calculationResult && calculationResult.max_dls > (isMetric ? 10.16 : 10) ?
            //                 "#f44336" : "#333"
            //         }
            //     }
            // }
            
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
            // GroupBox {
            //     Layout.fillWidth: true
            //     title: isChineseMode ? "计算参数" : "Calculation Parameters"
            //     visible: calculationResult && calculationResult.parameters

            //     ScrollView {
            //         anchors.fill: parent
            //         height: 100

            //         TextArea {
            //             text: formatParameters(calculationResult ? calculationResult.parameters : "{}")
            //             readOnly: true
            //             selectByMouse: true
            //             wrapMode: TextArea.Wrap
            //             font.family: "Consolas, Monaco, monospace"
            //             font.pixelSize: 12

            //             background: Rectangle {
            //                 color: "#f5f5f5"
            //                 radius: 4
            //             }
            //         }
            //     }
            // }

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
                    enabled: calculationResult && (!resultSaved || hasUserInput)
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
    // 🔥 新增：轨迹分析函数
    // 🔥 =====================================

    function getHighDoglegCount() {
        console.log(calculationResult)
        if (!calculationResult || !calculationResult.trajectory_analysis) {
            return 0
        }
        return calculationResult.trajectory_analysis.high_dogleg_count || 0
    }

    function getMaxDoglegInfo() {
        if (!calculationResult || !calculationResult.trajectory_analysis) {
            return {
                value: "-",
                location: ""
            }
        }

        var analysis = calculationResult.trajectory_analysis
        var maxDls = analysis.max_dls_value || 0
        var location = analysis.max_dls_depth || 0

        return {
            value: formatDoglegSeverity(maxDls),
            location: location > 0 ? formatDepthValue(location, "ft") : ""
        }
    }

    function getMaxInclinationInfo() {
        if (!calculationResult || !calculationResult.trajectory_analysis) {
            return {
                value: "-",
                location: "",
                isHigh: false
            }
        }

        var analysis = calculationResult.trajectory_analysis
        var maxInc = analysis.max_inclination_value || 0
        var location = analysis.max_inclination_depth || 0

        return {
            value: `${maxInc.toFixed(1)}°`,
            location: location > 0 ? formatDepthValue(location, "ft") : "",
            isHigh: maxInc > 45
        }
    }

    function getTrajectoryQuality() {
        var highDoglegCount = getHighDoglegCount()
        var maxDls = calculationResult?.trajectory_analysis?.max_dls_value || 0
        var maxInc = calculationResult?.trajectory_analysis?.max_inclination_value || 0

        if (highDoglegCount === 0 && maxDls < 6 && maxInc < 30) {
            return isChineseMode ? "优秀" : "Excellent"
        } else if (highDoglegCount < 3 && maxDls < 10 && maxInc < 60) {
            return isChineseMode ? "良好" : "Good"
        } else if (highDoglegCount < 8 && maxDls < 15) {
            return isChineseMode ? "一般" : "Fair"
        } else {
            return isChineseMode ? "需要改进" : "Needs Improvement"
        }
    }

    function getTrajectoryQualityColor() {
        var quality = getTrajectoryQuality()
        if (quality === "优秀" || quality === "Excellent") {
            return "#4caf50"
        } else if (quality === "良好" || quality === "Good") {
            return "#8bc34a"
        } else if (quality === "一般" || quality === "Fair") {
            return "#ff9800"
        } else {
            return "#f44336"
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

        // 🔥 使用用户输入的值或推荐值
        var pumpDepth = hasUserInput ? userPumpDepth : (calculationResult.pump_hanging_depth || 0)
        var perfDepth = hasUserInput ? userPerforationDepth : (calculationResult.perforation_depth || 0)

        if (pumpDepth > 0) {
            var pumpDepthM = UnitUtils.feetToMeters(pumpDepth)

            if (isMetric) {
                details.push(`泵挂深度: ${pumpDepthM.toFixed(1)} m (原始: ${pumpDepth.toFixed(1)} ft)`)
            } else {
                details.push(`Pump depth: ${pumpDepth.toFixed(1)} ft (${pumpDepthM.toFixed(1)} m)`)
            }
        }

        if (perfDepth > 0) {
            var perfDepthM = UnitUtils.feetToMeters(perfDepth)

            if (isMetric) {
                details.push(`射孔深度: ${perfDepthM.toFixed(1)} m (原始: ${perfDepth.toFixed(1)} ft)`)
            } else {
                details.push(`Perforation depth: ${perfDepth.toFixed(1)} ft (${perfDepthM.toFixed(1)} m)`)
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
        
        // 🔥 使用用户输入的值更新计算结果
        // var updatedResult = JSON.parse(JSON.stringify(calculationResult))
        var updatedResult = {
            well_id: calculationResult.well_id || -1,
            pump_hanging_depth: hasUserInput ? userPumpDepth : (calculationResult.pump_hanging_depth || 0),
            perforation_depth: hasUserInput ? userPerforationDepth : (calculationResult.perforation_depth || 0),
            total_depth_tvd: calculationResult.total_depth_tvd || 0,
            total_depth_md: calculationResult.total_depth_md || 0,
            max_inclination: calculationResult.max_inclination || 0,
            max_dls: calculationResult.max_dls || 0,
            calculation_method: calculationResult.calculation_method || "default",
            parameters: calculationResult.parameters || "{}",
            user_modified: hasUserInput,
            modification_date: hasUserInput ? new Date().toISOString() : (calculationResult.modification_date || "")
        }

        if (hasUserInput) {
            updatedResult.pump_hanging_depth = userPumpDepth
            updatedResult.perforation_depth = userPerforationDepth
            updatedResult.user_modified = true
            updatedResult.modification_date = new Date().toISOString()
        }

        console.log("保存的计算结果:", JSON.stringify(updatedResult))

        var saveAttempted = false

        // 🔥 直接使用全局上下文注入的对象（不再被遮蔽）
        if (typeof wellStructureController !== "undefined" && 
            wellStructureController && 
            wellStructureController.saveCalculationResult) {
            try {
                console.log("📞 调用 wellStructureController.saveCalculationResult ...")
                wellStructureController.saveCalculationResult(JSON.stringify(updatedResult))
                
                //wellStructureController.saveCalculationResult(updatedResult)
                saveAttempted = true
                console.log("✅ wellStructureController调用成功")
            } catch(e) {
                console.error("调用 wellStructureController 失败:", e)
            }
        } else {
            console.error("❌ wellStructureController 不可用")
            console.log("wellStructureController 类型:", typeof wellStructureController)
            console.log("wellStructureController 值:", wellStructureController)
        }

        if (typeof wellController !== "undefined" && 
            wellController && 
            wellController.saveCalculatedDepths) {
            try {
                var pumpDepth = hasUserInput ? userPumpDepth : (updatedResult.pump_hanging_depth || 0)
                var perforationDepth = hasUserInput ? userPerforationDepth : (updatedResult.perforation_depth || 0)
                if (pumpDepth > 0 || perforationDepth > 0) {
                    console.log("📞 调用 wellController.saveCalculatedDepths ...")
                    wellController.saveCalculatedDepths(pumpDepth, perforationDepth)
                    saveAttempted = true
                    console.log("✅ wellController调用成功")
                }
            } catch(e) {
                console.error("调用 wellController 失败:", e)
            }
        }

        if (!saveAttempted) {
            console.error("❌ 保存失败：没有可用控制器")
            showMessage(isChineseMode ? "保存失败：无法访问数据库控制器" : "Save failed: Cannot access database controller", true)
        } else {
            showMessage(isChineseMode ? "正在保存计算结果..." : "Saving calculation results...", false)
            hasUserInput = false
        }
    }

    // 显示消息提示
    function showMessage(message, isError) {
        console.log(isError ? "❌" : "✅", message)
        // 这里可以集成Toast组件或其他UI提示
    }

    // 🔥 修改显示计算结果函数，确保只有手动调用才显示
    function showResult(result) {
        console.log("=== 手动显示计算结果 ===")
        console.log("result:", JSON.stringify(result))
        
        // 🔥 如果result是简单的数字对象，转换为标准格式
        if (result && typeof result === "object") {
            // 检查是否有pump_hanging_depth属性，如果没有则可能是简化的数据格式
            if (!result.pump_hanging_depth && result.pumpDepth) {
                // 转换简化格式到标准格式
                var standardResult = {
                    pump_hanging_depth: result.pumpDepth || result.pump_hanging_depth,
                    perforation_depth: result.perforationDepth || result.perforation_depth,
                    pump_measured_depth: result.pumpMeasuredDepth || result.pump_measured_depth,
                    total_depth_tvd: result.totalDepthTvd || result.total_depth_tvd,
                    total_depth_md: result.totalDepthMd || result.total_depth_md,
                    max_inclination: result.maxInclination || result.max_inclination,
                    max_dls: result.maxDls || result.max_dls,
                    calculation_date: result.calculationDate || result.calculation_date || new Date().toISOString(),
                    calculation_method: result.calculationMethod || result.calculation_method || "default",
                    parameters: result.parameters || "{}",
                    // 🔥 添加轨迹分析数据
                    trajectory_analysis: result.trajectory_analysis || {
                        high_dogleg_count: result.highDoglegCount || 0,
                        max_dls_value: result.maxDls || 0,
                        max_dls_depth: result.maxDlsDepth || 0,
                        max_inclination_value: result.maxInclination || 0,
                        max_inclination_depth: result.maxInclinationDepth || 0
                    }
                }
                calculationResult = standardResult
            } else {
                calculationResult = result
            }
        } else {
            console.warn("无效的计算结果格式:", result)
            calculationResult = null
        }

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

    // 🔥 修改获取建议函数，考虑单位制和轨迹分析
    function getRecommendation() {
        if (!calculationResult) {
            return ""
        }

        var recommendations = []

        // 🔥 基于用户输入的建议
        if (hasUserInput) {
            recommendations.push(isChineseMode ?
                "您已修改推荐深度值，请确认设置正确" :
                "You have modified recommended depth values, please confirm settings")
        }

        // 🔥 基于狗腿度分析的建议
        var highDoglegCount = getHighDoglegCount()
        if (highDoglegCount > 0) {
            recommendations.push(isChineseMode ?
                `检测到${highDoglegCount}个高狗腿度点，建议详细评估井况` :
                `${highDoglegCount} high DLS points detected, detailed wellbore evaluation recommended`)
        }

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

    // 🔥 修改导出结果函数，包含单位信息和用户输入
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
            userModified: hasUserInput,
            userInputs: hasUserInput ? {
                pump_hanging_depth: userPumpDepth,
                perforation_depth: userPerforationDepth
            } : null,
            formattedResults: {
                pump_hanging_depth: formatDepthValue(hasUserInput ? userPumpDepth : calculationResult.pump_hanging_depth, "ft"),
                perforation_depth: formatDepthValue(hasUserInput ? userPerforationDepth : calculationResult.perforation_depth, "ft"),
                total_depth_tvd: formatDepthValue(calculationResult.total_depth_tvd, "m"),
                total_depth_md: formatDepthValue(calculationResult.total_depth_md, "m"),
                max_dls: formatDoglegSeverity(calculationResult.max_dls)
            },
            trajectoryAnalysis: {
                highDoglegCount: getHighDoglegCount(),
                maxDoglegInfo: getMaxDoglegInfo(),
                maxInclinationInfo: getMaxInclinationInfo(),
                trajectoryQuality: getTrajectoryQuality()
            },
            recommendations: getRecommendation(),
            conversionDetails: getConversionDetails()
        }

        console.log("导出计算结果:", JSON.stringify(exportData, null, 2))
        showMessage(isChineseMode ? "导出功能开发中..." : "Export feature in development...", false)
    }
    // 🔥 新增：深度值转换函数
    function getDisplayDepthValue(storageFeetValue) {
        // 存储值总是英尺，显示值根据单位制转换
        if (isMetric) {
            return Math.round(UnitUtils.feetToMeters(storageFeetValue))
        } else {
            return Math.round(storageFeetValue)
        }
    }

    function getStorageDepthValue(displayValue) {
        // 显示值转换为存储值（英尺）
        if (isMetric) {
            return UnitUtils.metersToFeet(displayValue)
        } else {
            return displayValue
        }
    }
}
