import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs
import "../../Common/Components" as CommonComponents

Window {
    id: rootWindow
    title: isChineseMode ? "导入设备数据" : "Import Device Data"
    width: 680
    height: 720
    modality: Qt.ApplicationModal
    flags: Qt.Dialog
    visible: false
    color: Material.backgroundColor

    // 多语言支持属性
    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性

    // 导入请求信号
    signal importRequested(string fileUrl, string deviceType, bool isMetric)  // 🔥 传递单位制信息
    signal templateDownloadRequested(string deviceType, string savePath, bool isMetric)  // 🔥 传递单位制信息

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            rootWindow.isMetric = isMetric
            console.log("DeviceImportDialog中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }
    Connections {
        target: deviceController
        enabled: deviceController !== undefined

        function onTemplateGenerated(filePath) {
            console.log("模板生成成功:", filePath)
            showMessage(isChineseMode ? "模板下载成功" : "Template downloaded successfully", false)
        }

        function onTemplateGenerationFailed(errorMsg) {
            console.error("模板生成失败:", errorMsg)
            showMessage(isChineseMode ? "模板生成失败: " + errorMsg : "Template generation failed: " + errorMsg, true)
        }
    }

    // 公开方法
    function open() {
        rootWindow.visible = true
        rootWindow.x = (Screen.width - rootWindow.width) / 2
        rootWindow.y = (Screen.height - rootWindow.height) / 2
    }

    function close() {
        rootWindow.visible = false
    }

    // 内部状态管理
    property string selectedFile: ""
    property string selectedType: "pump"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // 🔥 修改标题栏，添加单位切换器
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "导入设备数据" : "Import Device Data"
                font.pixelSize: 18
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 🔥 添加单位切换器
            CommonComponents.UnitSwitcher {
                isChinese: rootWindow.isChineseMode
                showLabel: true
                labelText: isChineseMode ? "单位制:" : "Units:"
            }

            Button {
                text: "✕"
                flat: true
                width: 32
                height: 32
                onClicked: rootWindow.close()
            }
        }

        // 🔥 修改步骤说明区域，添加单位制说明
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: Material.color(Material.Blue, Material.Shade50)
            radius: 8
            border.color: Material.color(Material.Blue, Material.Shade200)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    text: "ℹ️"
                    font.pixelSize: 24
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: isChineseMode ?
                            "请选择设备类型并上传对应的Excel文件，系统将自动解析并导入数据。" :
                            "Please select device type and upload the corresponding Excel file. The system will parse and import the data automatically."
                        wrapMode: Text.WordWrap
                        font.pixelSize: 14
                        color: Material.color(Material.Blue, Material.Shade800)
                    }

                    // 🔥 添加单位制说明
                    Text {
                        text: isChineseMode ?
                            `当前单位制: ${rootWindow.isMetric ? "公制" : "英制"}，导入的数据将按此单位制处理。` :
                            `Current unit system: ${rootWindow.isMetric ? "Metric" : "Imperial"}, imported data will be processed accordingly.`
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: Material.color(Material.Blue, Material.Shade600)
                        font.bold: true
                    }
                }
            }
        }

        // 设备类型选择区域（保持不变）
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 250
            color: Material.dialogColor
            radius: 8
            border.color: Material.dividerColor
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 2

                Text {
                    text: isChineseMode ? "1. 选择设备类型" : "1. Select Device Type"
                    font.pixelSize: 16
                    font.bold: true
                    color: Material.primaryTextColor
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 20
                    rowSpacing: 8

                    RadioButton {
                        Layout.fillWidth: true
                        text: isChineseMode ? "🔧 泵设备" : "🔧 Pump"
                        checked: rootWindow.selectedType === "pump"
                        onCheckedChanged: if (checked) rootWindow.selectedType = "pump"
                    }

                    RadioButton {
                        Layout.fillWidth: true
                        text: isChineseMode ? "⚡ 电机" : "⚡ Motor"
                        checked: rootWindow.selectedType === "motor"
                        onCheckedChanged: if (checked) rootWindow.selectedType = "motor"
                    }

                    RadioButton {
                        Layout.fillWidth: true
                        text: isChineseMode ? "🛡️ 保护器" : "🛡️ Protector"
                        checked: rootWindow.selectedType === "protector"
                        onCheckedChanged: if (checked) rootWindow.selectedType = "protector"
                    }

                    RadioButton {
                        Layout.fillWidth: true
                        text: isChineseMode ? "🔄 分离器" : "🔄 Separator"
                        checked: rootWindow.selectedType === "separator"
                        onCheckedChanged: if (checked) rootWindow.selectedType = "separator"
                    }
                }
            }
        }

        // 文件选择区域（保持不变）
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            color: Material.dialogColor
            radius: 8
            border.color: Material.dividerColor
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 2

                Text {
                    text: isChineseMode ? "2. 选择Excel文件" : "2. Select Excel File"
                    font.pixelSize: 16
                    font.bold: true
                    color: Material.primaryTextColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        color: Material.color(Material.Grey, Material.Shade100)
                        radius: 4
                        border.width: 1
                        border.color: Material.dividerColor

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 12

                            text: rootWindow.selectedFile ?
                                  rootWindow.selectedFile.split('/').pop() :
                                  (isChineseMode ? "请选择文件..." : "Please select file...")
                            color: rootWindow.selectedFile ?
                                   Material.primaryTextColor :
                                   Material.hintTextColor
                            elide: Text.ElideMiddle
                        }
                    }

                    Button {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 48
                        text: isChineseMode ? "浏览" : "Browse"
                        Material.background: Material.accent
                        Material.foreground: "white"
                        onClicked: fileDialog.open()
                    }
                }

                // 🔥 修改模板下载和格式提示行，添加单位制信息
                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: isChineseMode ?
                            `📥 下载模板 (${rootWindow.isMetric ? "公制" : "英制"})` :
                            `📥 Download Template (${rootWindow.isMetric ? "Metric" : "Imperial"})`
                        flat: true
                        Material.foreground: Material.color(Material.Blue)
                        onClicked: {
                            console.log("Download template for:", rootWindow.selectedType, "unit:", rootWindow.isMetric ? "Metric" : "Imperial")
                            templateSaveDialog.open()
                        }
                        ToolTip.text: isChineseMode ?
                            "下载当前单位制的模板文件" :
                            "Download template file for current unit system"
                        ToolTip.visible: hovered
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: isChineseMode ? "支持格式: .xlsx, .xls" : "Supported: .xlsx, .xls"
                        font.pixelSize: 11
                        color: Material.hintTextColor
                    }
                }
            }
        }

        // 填充剩余空间
        Item { Layout.fillHeight: true }

        // 底部按钮区域（保持不变）
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            spacing: 2

            Item { Layout.fillWidth: true }

            Button {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                text: isChineseMode ? "取消" : "Cancel"
                onClicked: rootWindow.close()
            }

            Button {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40
                text: isChineseMode ? "确定" : "Confirm"
                Material.background: Material.accent
                Material.foreground: "white"
                enabled: rootWindow.selectedFile !== ""

                onClicked: {
                    if (!rootWindow.selectedFile) {
                        errorDialog.open()
                        return
                    }
                    // 🔥 传递单位制信息
                    rootWindow.importRequested(rootWindow.selectedFile, rootWindow.selectedType, rootWindow.isMetric)
                    rootWindow.close()
                }
            }
        }
    }

    // 文件选择对话框（保持不变）
    FileDialog {
        id: fileDialog
        title: isChineseMode ? "选择Excel文件" : "Select Excel File"
        nameFilters: ["Excel files (*.xlsx *.xls)", "All files (*)"]

        onAccepted: {
            console.log("Selected file:", selectedFile)
            rootWindow.selectedFile = selectedFile.toString()
        }
    }

    // 🔥 修改模板保存对话框，包含单位制信息
    FileDialog {
        id: templateSaveDialog
        title: isChineseMode ? "保存模板文件" : "Save Template File"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel files (*.xlsx)"]
        defaultSuffix: "xlsx"

        // 🔥 根据设备类型和单位制设置默认文件名
        selectedFile: {
            var deviceNames = {
                "pump": isChineseMode ? "泵设备导入模板" : "pump_import_template",
                "motor": isChineseMode ? "电机导入模板" : "motor_import_template",
                "protector": isChineseMode ? "保护器导入模板" : "protector_import_template",
                "separator": isChineseMode ? "分离器导入模板" : "separator_import_template"
            }
            var unitSuffix = rootWindow.isMetric ? "_metric" : "_imperial"
            return (deviceNames[rootWindow.selectedType] || "template") + unitSuffix + ".xlsx"
        }

        onAccepted: {
            console.log("Save template to:", selectedFile)
            var savePath = selectedFile.toString()
            // 🔥 传递单位制信息
            // 🔥 调用DeviceController的模板生成方法
            if (typeof deviceController !== "undefined") {
                deviceController.generateTemplate(rootWindow.selectedType, savePath, rootWindow.isMetric)
            }
        }
    }

    // 错误提示对话框（保持不变）
    Dialog {
        id: errorDialog
        title: isChineseMode ? "提示" : "Notice"
        anchors.centerIn: parent
        width: 300
        height: 150
        modal: true

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: isChineseMode ? "请选择一个Excel文件" : "Please select an Excel file"
                Layout.alignment: Qt.AlignHCenter
                color: Material.primaryTextColor
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: isChineseMode ? "确定" : "OK"
                onClicked: errorDialog.close()
            }
        }
    }
}
