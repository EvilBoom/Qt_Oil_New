import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Dialog {
    id: root

    property int wellId: -1
    property string wellName: ""
    property bool isChineseMode: true
    // 🔥 添加单位制属性
    property bool isMetric: false

    // 🔥 监听单位制变化
    onIsMetricChanged: {
        console.log("ExcelImportDialog单位制切换为:", isMetric ? "公制" : "英制")
        updateUnitDisplays()
    }
    // 🔥 添加wellId变化监听，用于调试
    onWellIdChanged: {
        console.log("ExcelImportDialog wellId 变化为:", wellId)
        if (wellId <= 0) {
            console.warn("⚠️ ExcelImportDialog接收到无效的wellId:", wellId)
        }
    }

    title: isChineseMode ? "导入Excel轨迹数据" : "Import Excel Trajectory Data"
    width: 800
    height: 600
    modal: true

    // 在Connections中添加更详细的错误处理
    Connections {
        target: excelImportController

        function onFileLoaded(filePath) {
            console.log("✅ 文件加载完成:", filePath)
            fileNameLabel.text = filePath.split('/').pop()
            stepStack.currentIndex = 1
        }

        function onColumnsIdentified(columns) {
            console.log("✅ 列识别完成:", JSON.stringify(columns))
            updateColumnMapping(columns)
        }

        function onPreviewDataReady(data) {
            console.log("✅ 预览数据准备完成，数据条数:", data ? data.length : 0)
            updatePreviewTable(data)
        }

        function onSheetsLoaded(sheets) {
            console.log("✅ 工作表加载完成:", sheets)
            sheetComboBox.model = sheets
            if (sheets.length > 0) {
                sheetComboBox.currentIndex = 0
            }
        }

        function onValidationCompleted(summary) {
            console.log("✅ 验证完成:", JSON.stringify(summary))
            updateValidationSummary(summary)
        }

        function onImportProgress(current, total) {
            importProgress.value = current / total
            importProgressText.text = `${current} / ${total}`
            console.log(`📊 导入进度: ${current}/${total} (${(current/total*100).toFixed(1)}%)`)
        }

        function onImportFailed(errorMsg) {
            console.error("❌ 导入失败:", errorMsg)
            importProgress.value = 0
            errorDialog.errorMessage = errorMsg
            errorDialog.open()
        }

        // 🔥 添加导入完成信号处理
        function onImportCompleted(wellId, rowCount) {
            console.log(`✅ 导入完成: 井ID=${wellId}, 数据行数=${rowCount}`)
            importProgress.value = 1.0
            completedDialog.dataCount = rowCount
            completedDialog.open()
        }
    }

    contentItem: StackLayout {
        id: stepStack
        currentIndex: 0

        // 步骤1：选择文件
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Label {
                    text: isChineseMode ? "步骤 1: 选择Excel文件" : "Step 1: Select Excel File"
                    font.pixelSize: 18
                    font.bold: true
                }
                // 🔥 添加单位制说明卡片
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    color: "#e3f2fd"
                    radius: 8
                    border.color: "#2196f3"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        RowLayout {
                            Text {
                                text: "📏"
                                font.pixelSize: 20
                            }

                            Text {
                                text: isChineseMode ? "数据单位要求" : "Data Unit Requirements"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#1976d2"
                            }

                            Item { Layout.fillWidth: true }

                            // 🔥 当前单位制指示器
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 24
                                radius: 12
                                color: isMetric ? "#4caf50" : "#ff9800"

                                Text {
                                    anchors.centerIn: parent
                                    text: isMetric ?
                                        (isChineseMode ? "公制" : "Metric") :
                                        (isChineseMode ? "英制" : "Imperial")
                                    color: "white"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: isChineseMode ?
                                `深度数据应为 ${getDepthUnit()}，角度数据为度(°)。导入时将自动进行单位转换。` :
                                `Depth data should be in ${getDepthUnit()}, angle data in degrees(°). Unit conversion will be performed automatically during import.`
                            font.pixelSize: 12
                            color: "#424242"
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#f5f7fa"
                    border.color: "#ddd"
                    border.width: 2
                    radius: 8

                    DropArea {
                        id: dropArea
                        anchors.fill: parent

                        onDropped: function(drop) {
                            if (drop.hasUrls && drop.urls.length > 0) {
                                var url = drop.urls[0]
                                excelImportController.loadExcelFile(url)
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 20

                        Text {
                            text: "📁"
                            font.pixelSize: 64
                            color: "#999"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: isChineseMode ?
                                "拖拽Excel文件到此处\n或" :
                                "Drag Excel file here\nor"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#666"
                            font.pixelSize: 16
                        }

                        Button {
                            text: isChineseMode ? "选择文件" : "Choose File"
                            Layout.alignment: Qt.AlignHCenter
                            highlighted: true

                            onClicked: fileDialog.open()
                        }

                        Label {
                            id: fileNameLabel
                            Layout.alignment: Qt.AlignHCenter
                            color: "#333"
                            font.pixelSize: 14
                        }
                    }
                }

//                 Label {
//                     text: isChineseMode ?
//                         "支持格式：.xls, .xlsx\n文件应包含TVD、MD列，可选DLS列, Azim Grid
// 和Incl列" :
//                         "Supported formats: .xls, .xlsx\nFile should contain TVD, MD columns, optional DLS, Azim Grid and Incl column"
//                     color: "#666"
//                     font.pixelSize: 12
//                 }
                // 🔥 修改文件格式说明，包含单位信息
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "文件格式要求" : "File Format Requirements"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        Text {
                            text: isChineseMode ?
                                "• 支持格式：.xls, .xlsx" :
                                "• Supported formats: .xls, .xlsx"
                            font.pixelSize: 12
                            color: "#666"
                        }

                        Text {
                            text: isChineseMode ?
                                `• 必需列：TVD (${getDepthUnit()}), MD (${getDepthUnit()})` :
                                `• Required columns: TVD (${getDepthUnit()}), MD (${getDepthUnit()})`
                            font.pixelSize: 12
                            color: "#666"
                        }

                        Text {
                            text: isChineseMode ?
                                "• 可选列：DLS, 井斜角(°), 方位角(°)" :
                                "• Optional columns: DLS, Inclination(°), Azimuth(°)"
                            font.pixelSize: 12
                            color: "#666"
                        }

                        Text {
                            text: isChineseMode ?
                                "• 导入时将根据当前单位制自动转换数据" :
                                "• Data will be automatically converted based on current unit system"
                            font.pixelSize: 12
                            color: "#4a90e2"
                            font.italic: true
                        }
                    }
                }
            }
        }

        // 步骤2：列映射和预览
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Label {
                    text: isChineseMode ? "步骤 2: 确认数据映射" : "Step 2: Confirm Data Mapping"
                    font.pixelSize: 18
                    font.bold: true
                }

                // 工作表选择
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: isChineseMode ? "工作表:" : "Sheet:"
                    }

                    ComboBox {
                        id: sheetComboBox
                        Layout.preferredWidth: 200

                        onCurrentTextChanged: {
                            if (currentText) {
                                excelImportController.loadSheet(currentText)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // 🔥 添加数据单位设置
                    GroupBox {
                        title: isChineseMode ? "数据单位设置" : "Data Unit Settings"
                        Layout.preferredWidth: 250

                        GridLayout {
                            anchors.fill: parent
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 4

                            Label {
                                text: isChineseMode ? "深度单位:" : "Depth Unit:"
                                font.pixelSize: 10
                            }

                            ComboBox {
                                id: sourceDepthUnitCombo
                                Layout.fillWidth: true
                                model: isChineseMode ?
                                    ["自动检测", "英尺 (ft)", "米 (m)"] :
                                    ["Auto Detect", "Feet (ft)", "Meters (m)"]
                                currentIndex: 0
                                font.pixelSize: 10
                            }

                            Label {
                                text: isChineseMode ? "目标单位:" : "Target Unit:"
                                font.pixelSize: 10
                            }

                            Label {
                                text: getDepthUnit()
                                font.pixelSize: 10
                                color: "#4a90e2"
                                font.bold: true
                            }
                        }
                    }
                }

                // 🔥 修改列映射显示，包含单位信息
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "列映射" : "Column Mapping"

                    GridLayout {
                        anchors.fill: parent
                        columns: 3
                        rowSpacing: 10
                        columnSpacing: 20

                        // 表头
                        Label {
                            text: isChineseMode ? "数据类型" : "Data Type"
                            font.bold: true
                            color: "#666"
                        }
                        Label {
                            text: isChineseMode ? "Excel列" : "Excel Column"
                            font.bold: true
                            color: "#666"
                        }
                        Label {
                            text: isChineseMode ? "单位" : "Unit"
                            font.bold: true
                            color: "#666"
                        }

                        // TVD
                        Label {
                            text: isChineseMode ? "垂直深度 (TVD)" : "True Vertical Depth (TVD)"
                            font.bold: true
                        }
                        Label {
                            id: tvdColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }
                        Label {
                            text: getDepthUnit()
                            color: "#666"
                            font.italic: true
                        }

                        // MD
                        Label {
                            text: isChineseMode ? "测量深度 (MD)" : "Measured Depth (MD)"
                            font.bold: true
                        }
                        Label {
                            id: mdColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }
                        Label {
                            text: getDepthUnit()
                            color: "#666"
                            font.italic: true
                        }

                        // DLS
                        Label {
                            text: isChineseMode ? "狗腿度 (DLS)" : "Dogleg Severity (DLS)"
                            font.bold: true
                        }
                        Label {
                            id: dlsColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }
                        Label {
                            text: getDoglegUnit()
                            color: "#666"
                            font.italic: true
                        }

                        // 井斜角
                        Label {
                            text: isChineseMode ? "井斜角" : "Inclination"
                            font.bold: true
                        }
                        Label {
                            id: inclinationColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }
                        Label {
                            text: "°"
                            color: "#666"
                            font.italic: true
                        }

                        // 方位角
                        Label {
                            text: isChineseMode ? "方位角" : "Azimuth"
                            font.bold: true
                        }
                        Label {
                            id: azimuthColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }
                        Label {
                            text: "°"
                            color: "#666"
                            font.italic: true
                        }
                    }
                }

                // 数据预览
                GroupBox {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: isChineseMode ?
                        `数据预览 (显示单位: ${getDepthUnit()})` :
                        `Data Preview (Display Unit: ${getDepthUnit()})`

                    ScrollView {
                        anchors.fill: parent

                        TableView {
                            id: previewTable
                            model: ListModel { id: previewModel }

                            delegate: Rectangle {
                                implicitWidth: 100
                                implicitHeight: 30
                                border.color: "#ddd"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData || ""
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // 按钮
                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: isChineseMode ? "上一步" : "Previous"
                        onClicked: stepStack.currentIndex = 0
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: isChineseMode ? "下一步" : "Next"
                        highlighted: true
                        enabled: tvdColumnLabel.text !== "-" && mdColumnLabel.text !== "-"
                        onClicked: {
                            // 🔥 传递单位信息给验证器
                            var unitSettings = {
                                sourceDepthUnit: getSourceDepthUnit(),
                                targetDepthUnit: getDepthUnit(),
                                isMetric: isMetric
                            }
                            excelImportController.validateData(unitSettings)
                            stepStack.currentIndex = 2
                        }
                    }
                }
            }
        }

        // 步骤3：验证和导入
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Label {
                    text: isChineseMode ? "步骤 3: 验证和导入" : "Step 3: Validate and Import"
                    font.pixelSize: 18
                    font.bold: true
                }

                // 🔥 修改验证摘要，包含单位转换信息
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "数据验证摘要" : "Data Validation Summary"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        RowLayout {
                            Label {
                                text: isChineseMode ? "目标井:" : "Target Well:"
                                font.bold: true
                            }
                            Label {
                                text: wellName
                                color: "#4a90e2"
                            }
                        }

                        RowLayout {
                            Label {
                                id: dataCountLabel
                                text: isChineseMode ? "数据行数: 0" : "Data Rows: 0"
                            }
                        }

                        RowLayout {
                            Label {
                                id: depthRangeLabel
                                text: isChineseMode ? "深度范围: -" : "Depth Range: -"
                            }
                        }

                        // 🔥 添加单位转换信息
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: "#f3e5f5"
                            radius: 6
                            border.color: "#9c27b0"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 4

                                Text {
                                    text: isChineseMode ? "📊 单位转换信息" : "📊 Unit Conversion Info"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#7b1fa2"
                                }

                                Text {
                                    text: isChineseMode ?
                                        `源数据单位: ${getSourceDepthUnit()} → 目标单位: ${getDepthUnit()}` :
                                        `Source Unit: ${getSourceDepthUnit()} → Target Unit: ${getDepthUnit()}`
                                    font.pixelSize: 11
                                    color: "#424242"
                                }

                                Text {
                                    id: conversionInfoLabel
                                    text: getConversionInfo()
                                    font.pixelSize: 10
                                    color: "#666"
                                    font.italic: true
                                }
                            }
                        }

                        // 警告信息
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            visible: warningListModel.count > 0

                            ListView {
                                model: ListModel { id: warningListModel }
                                delegate: Text {
                                    text: "⚠️ " + modelData
                                    color: "#ff9800"
                                    wrapMode: Text.Wrap
                                    width: parent.width
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                // 导入进度
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "导入进度" : "Import Progress"
                    visible: importProgress.value > 0

                    ColumnLayout {
                        anchors.fill: parent

                        ProgressBar {
                            id: importProgress
                            Layout.fillWidth: true
                            from: 0
                            to: 1
                            value: 0
                        }

                        Text {
                            id: importProgressText
                            Layout.alignment: Qt.AlignHCenter
                            text: "0 / 0"
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: isChineseMode ? "正在进行单位转换..." : "Performing unit conversion..."
                            font.pixelSize: 10
                            color: "#666"
                            visible: importProgress.value > 0 && importProgress.value < 1
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // 按钮
                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: isChineseMode ? "上一步" : "Previous"
                        onClicked: stepStack.currentIndex = 1
                    }

                    Item { Layout.fillWidth: true }

                    // 在"开始导入"按钮的onClicked中修改
                    Button {
                        text: isChineseMode ? "开始导入" : "Start Import"
                        highlighted: true
                        enabled: (!importProgress.visible || importProgress.value >= 1) && wellId > 0

                        onClicked: {
                            // 🔥 最终验证井ID
                            if (wellId <= 0) {
                                console.error("❌ 导入失败：井ID无效:", wellId)
                                errorDialog.errorMessage = isChineseMode ?
                                    "导入失败：井ID无效，请重新选择井" :
                                    "Import failed: Invalid well ID, please select a well again"
                                errorDialog.open()
                                return
                            }

                            console.log("🚀 开始导入数据到井ID:", wellId)
                            importProgress.value = 0.01  // 开始进度

                            // 🔥 传递完整的导入参数对象
                            var importParams = {
                                "wellId": wellId,                           // 🔥 使用字符串键名
                                "sourceDepthUnit": getSourceDepthUnit(),
                                "targetDepthUnit": getDepthUnit(),
                                "isMetric": isMetric,
                                "performUnitConversion": true
                            }

                            console.log("导入参数:", JSON.stringify(importParams))

                            // 🔥 确保传递的是JavaScript对象
                            excelImportController.importToWell(importParams)
                        }
                    }
                }
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            text: isChineseMode ? "关闭" : "Close"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
    }

    // 文件选择对话框
    FileDialog {
        id: fileDialog
        title: isChineseMode ? "选择Excel文件" : "Select Excel File"
        nameFilters: ["Excel files (*.xlsx *.xls)", "All files (*)"]

        onAccepted: {
            excelImportController.loadExcelFile(selectedFile)
        }
    }

    // 错误对话框
    Dialog {
        id: errorDialog
        title: isChineseMode ? "错误" : "Error"
        modal: true
        standardButtons: Dialog.Ok

        property string errorMessage: ""

        contentItem: Text {
            text: errorDialog.errorMessage
            wrapMode: Text.Wrap
            color: "#f44336"
        }
    }
    // 🔥 添加导入完成对话框
    Dialog {
        id: completedDialog
        title: isChineseMode ? "导入完成" : "Import Completed"
        modal: true
        standardButtons: Dialog.Ok

        property int dataCount: 0

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                text: "✅"
                font.pixelSize: 48
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: isChineseMode ?
                    `成功导入 ${completedDialog.dataCount} 条轨迹数据` :
                    `Successfully imported ${completedDialog.dataCount} trajectory records`
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: isChineseMode ?
                    `数据已转换为 ${getDepthUnit()} 单位并保存到数据库` :
                    `Data has been converted to ${getDepthUnit()} and saved to database`
                font.pixelSize: 12
                color: "#666"
                Layout.alignment: Qt.AlignHCenter
            }
        }

        onAccepted: {
            root.accept()
        }
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDoglegUnit() {
        return isMetric ? "°/30m" : "°/100ft"
    }

    function getSourceDepthUnit() {
        switch(sourceDepthUnitCombo.currentIndex) {
            case 0: return "auto"  // 自动检测
            case 1: return "ft"    // 英尺
            case 2: return "m"     // 米
            default: return "auto"
        }
    }

    function getConversionInfo() {
        var sourceUnit = getSourceDepthUnit()
        var targetUnit = getDepthUnit()

        if (sourceUnit === "auto") {
            return isChineseMode ?
                "将自动检测数据单位并进行转换" :
                "Unit will be auto-detected and converted"
        }

        if (sourceUnit === targetUnit) {
            return isChineseMode ?
                "无需单位转换" :
                "No unit conversion needed"
        }

        var conversionFactor = ""
        if (sourceUnit === "ft" && targetUnit === "m") {
            conversionFactor = "1 ft = 0.3048 m"
        } else if (sourceUnit === "m" && targetUnit === "ft") {
            conversionFactor = "1 m = 3.2808 ft"
        }

        return isChineseMode ?
            `转换系数: ${conversionFactor}` :
            `Conversion factor: ${conversionFactor}`
    }

    function updateUnitDisplays() {
        console.log("更新Excel导入对话框单位显示")
        // 更新深度范围显示
        if (depthRangeLabel.text !== "-") {
            // 重新格式化深度范围显示
            updateValidationSummary(lastValidationSummary)
        }
    }

    // 🔥 保存最后的验证摘要以便单位切换时更新
    property var lastValidationSummary: null

    // 辅助函数
    // 修改updateColumnMapping函数
    function updateColumnMapping(mapping) {
        tvdColumnLabel.text = mapping.TVD || "-"
        mdColumnLabel.text = mapping.MD || "-"
        dlsColumnLabel.text = mapping.DLS || "-"
        inclinationColumnLabel.text = mapping.INCLINATION || "-"
        azimuthColumnLabel.text = mapping.AZIMUTH || "-"
    }

    function updatePreviewTable(data) {
        previewModel.clear()

        if (!data || data.length === 0) return

        // 🔥 添加表头，显示单位信息
        var headers = []
        if (data.length > 0) {
            for (var key in data[0]) {
                var header = key
                if (key.toLowerCase().includes('tvd') || key.toLowerCase().includes('md')) {
                    header += ` (${getDepthUnit()})`
                } else if (key.toLowerCase().includes('dls')) {
                    header += ` (${getDoglegUnit()})`
                } else if (key.toLowerCase().includes('inc') || key.toLowerCase().includes('azi')) {
                    header += " (°)"
                }
                headers.push(header)
            }
        }

        // 添加表头行
        previewModel.append({modelData: headers.join(" | ")})

        // 添加数据行（最多显示10行）
        for (var i = 0; i < Math.min(data.length, 10); i++) {
            var row = []
            for (var key in data[i]) {
                var value = data[i][key]
                // 🔥 对深度数据进行预览转换显示
                if (key.toLowerCase().includes('tvd') || key.toLowerCase().includes('md')) {
                    value = formatDepthForPreview(value)
                }
                row.push(value)
            }
            previewModel.append({modelData: row.join(" | ")})
        }
    }
    function formatDepthForPreview(value) {
        if (!value || isNaN(value)) return value

        var numValue = parseFloat(value)
        var sourceUnit = getSourceDepthUnit()
        var targetUnit = getDepthUnit()

        if (sourceUnit !== "auto" && sourceUnit !== targetUnit) {
            if (sourceUnit === "ft" && targetUnit === "m") {
                numValue = UnitUtils.feetToMeters(numValue)
            } else if (sourceUnit === "m" && targetUnit === "ft") {
                numValue = UnitUtils.metersToFeet(numValue)
            }
        }

        return numValue.toFixed(1)
    }

    function updateValidationSummary(summary) {
        lastValidationSummary = summary  // 🔥 保存用于单位切换

        dataCountLabel.text = isChineseMode ?
            `数据行数: ${summary.data_count || 0}` :
            `Data Rows: ${summary.data_count || 0}`

        if (summary.statistics) {
            var stats = summary.statistics
            // 🔥 深度范围显示考虑单位转换
            var minDepth = formatDepthValue(stats.min_tvd || 0)
            var maxDepth = formatDepthValue(stats.max_tvd || 0)

            depthRangeLabel.text = isChineseMode ?
                `深度范围: ${minDepth} - ${maxDepth} ${getDepthUnit()}` :
                `Depth Range: ${minDepth} - ${maxDepth} ${getDepthUnit()}`
        }

        // 更新警告列表
        warningListModel.clear()
        if (summary.warnings) {
            for (var i = 0; i < summary.warnings.length && i < 5; i++) {
                warningListModel.append({modelData: summary.warnings[i]})
            }
        }

        // 🔥 添加单位转换相关的警告
        if (getSourceDepthUnit() !== getDepthUnit() && getSourceDepthUnit() !== "auto") {
            var unitWarning = isChineseMode ?
                `注意：数据将从 ${getSourceDepthUnit()} 转换为 ${getDepthUnit()}` :
                `Note: Data will be converted from ${getSourceDepthUnit()} to ${getDepthUnit()}`
            warningListModel.append({modelData: unitWarning})
        }
    }
    function formatDepthValue(value) {
        if (!value || isNaN(value)) return "0"

        var numValue = parseFloat(value)
        var sourceUnit = getSourceDepthUnit()
        var targetUnit = getDepthUnit()

        // 进行单位转换用于显示
        if (sourceUnit !== "auto" && sourceUnit !== targetUnit) {
            if (sourceUnit === "ft" && targetUnit === "m") {
                numValue = UnitUtils.feetToMeters(numValue)
            } else if (sourceUnit === "m" && targetUnit === "ft") {
                numValue = UnitUtils.metersToFeet(numValue)
            }
        }

        return numValue.toFixed(1)
    }

    // 🔥 在对话框打开时添加更详细的调试信息
    onOpened: {
        // 重置状态
        stepStack.currentIndex = 0
        importProgress.value = 0
        lastValidationSummary = null
        excelImportController.clearData()

        console.log("📋 Excel导入对话框打开详情:")
        console.log("  - 当前单位制:", isMetric ? "公制" : "英制")
        console.log("  - 井ID:", wellId)
        console.log("  - 井名:", wellName)
        console.log("  - 深度单位:", getDepthUnit())
        console.log("  - 狗腿度单位:", getDoglegUnit())

        // 🔥 验证井ID
        if (wellId <= 0) {
            console.warn("⚠️ Excel导入对话框打开时井ID无效:", wellId)
            console.warn("⚠️ 请确保在WellStructurePage中正确设置了currentWellId")
        }
    }
}
