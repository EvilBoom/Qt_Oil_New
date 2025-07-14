import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Material

Dialog {
    id: root

    property int wellId: -1
    property string wellName: ""
    property bool isChineseMode: true

    title: isChineseMode ? "导入Excel轨迹数据" : "Import Excel Trajectory Data"
    width: 800
    height: 600
    modal: true

    // 连接控制器信号
    Connections {
        target: excelImportController

        function onFileLoaded(filePath) {
            fileNameLabel.text = filePath.split('/').pop()
            stepStack.currentIndex = 1
        }

        function onColumnsIdentified(columns) {
            updateColumnMapping(columns)
        }

        function onPreviewDataReady(data) {
            updatePreviewTable(data)
        }

        function onSheetsLoaded(sheets) {
            sheetComboBox.model = sheets
            if (sheets.length > 0) {
                sheetComboBox.currentIndex = 0
            }
        }

        function onValidationCompleted(summary) {
            updateValidationSummary(summary)
        }

        function onImportProgress(current, total) {
            importProgress.value = current / total
            importProgressText.text = `${current} / ${total}`
        }

        function onImportFailed(errorMsg) {
            errorDialog.errorMessage = errorMsg
            errorDialog.open()
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

                Label {
                    text: isChineseMode ?
                        "支持格式：.xls, .xlsx\n文件应包含TVD、MD列，可选DLS列, Azim Grid
和Incl列" :
                        "Supported formats: .xls, .xlsx\nFile should contain TVD, MD columns, optional DLS, Azim Grid and Incl column"
                    color: "#666"
                    font.pixelSize: 12
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
                }

                // 列映射显示
                GroupBox {
                    Layout.fillWidth: true
                    title: isChineseMode ? "列映射" : "Column Mapping"

                    GridLayout {
                        anchors.fill: parent
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 20

                        Label {
                            text: "TVD → "
                            font.bold: true
                        }
                        Label {
                            id: tvdColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }

                        Label {
                            text: "MD → "
                            font.bold: true
                        }
                        Label {
                            id: mdColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }

                        Label {
                            text: "DLS → "
                            font.bold: true
                        }
                        Label {
                            id: dlsColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }

                        // 新增：井斜角
                        Label {
                            text: isChineseMode ? "井斜角 → " : "Inclination → "
                            font.bold: true
                        }
                        Label {
                            id: inclinationColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }

                        // 新增：方位角
                        Label {
                            text: isChineseMode ? "方位角 → " : "Azimuth → "
                            font.bold: true
                        }
                        Label {
                            id: azimuthColumnLabel
                            text: "-"
                            color: "#4a90e2"
                        }
                    }
                }

                // 数据预览
                GroupBox {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: isChineseMode ? "数据预览" : "Data Preview"

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
                            excelImportController.validateData()
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

                // 验证摘要
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

                    Button {
                        text: isChineseMode ? "开始导入" : "Start Import"
                        highlighted: true
                        enabled: !importProgress.visible || importProgress.value >= 1

                        onClicked: {
                            importProgress.value = 0
                            excelImportController.importToWell(wellId)
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

    // 辅助函数
    // 修改updateColumnMapping函数
    function updateColumnMapping(mapping) {
        tvdColumnLabel.text = mapping.TVD || "-"
        mdColumnLabel.text = mapping.MD || "-"
        dlsColumnLabel.text = mapping.DLS || "-"
        inclinationColumnLabel.text = mapping.INCLINATION || "-"  // 新增
        azimuthColumnLabel.text = mapping.AZIMUTH || "-"          // 新增
    }

    function updatePreviewTable(data) {
        previewModel.clear()
        // TODO: 实现表格预览数据更新
    }

    function updateValidationSummary(summary) {
        dataCountLabel.text = isChineseMode ?
            `数据行数: ${summary.data_count || 0}` :
            `Data Rows: ${summary.data_count || 0}`

        if (summary.statistics) {
            var stats = summary.statistics
            depthRangeLabel.text = isChineseMode ?
                `深度范围: ${stats.min_tvd}m - ${stats.max_tvd}m` :
                `Depth Range: ${stats.min_tvd}m - ${stats.max_tvd}m`
        }

        // 更新警告列表
        warningListModel.clear()
        if (summary.warnings) {
            for (var i = 0; i < summary.warnings.length && i < 5; i++) {
                warningListModel.append({modelData: summary.warnings[i]})
            }
        }
    }

    onOpened: {
        // 重置状态
        stepStack.currentIndex = 0
        importProgress.value = 0
        excelImportController.clearData()
    }
}
