import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15
import QtQuick.Dialogs
import "../../Common/Components" as CommonComponents

Window {
    id: root
    width: 520
    height: 750
    title: isChineseMode ? "导出设备数据" : "Export Device Data"
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint

    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性
    property string selectedType: "all"
    signal exportRequested(string fileUrl, string deviceType, bool isMetric)  // 🔥 传递单位制信息

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("DeviceExportDialog中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 24

        // 🔥 添加标题栏和单位切换器
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "导出设备数据" : "Export Device Data"
                font.pixelSize: 18
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }

            // 🔥 添加单位切换器
            CommonComponents.UnitSwitcher {
                isChinese: root.isChineseMode
                showLabel: true
                labelText: isChineseMode ? "导出单位:" : "Export Units:"
            }
        }

        GroupBox {
            title: isChineseMode ? "导出选项" : "Export Options"
            Layout.fillWidth: true

            ColumnLayout {
                anchors.margins: 8
                spacing: 8
                Layout.fillWidth: true

                Repeater {
                    model: [
                        { key: "all",        text: isChineseMode ? "全部设备"       : "All Devices" },
                        { key: "pump",       text: isChineseMode ? "仅潜油离心泵"   : "Centrifugal Pumps" },
                        { key: "motor",      text: isChineseMode ? "仅电机"         : "Motors" },
                        { key: "protector",  text: isChineseMode ? "仅保护器"       : "Protectors" },
                        { key: "separator",  text: isChineseMode ? "仅分离器"       : "Separators" }
                    ]
                    delegate: RadioButton {
                        Layout.fillWidth: true
                        text: modelData.text
                        checked: root.selectedType === modelData.key
                        ButtonGroup.group: deviceTypeGroup
                        onCheckedChanged: {
                            if (checked) {
                                root.selectedType = modelData.key
                            }
                        }
                    }
                }
            }
        }

        // 🔥 修改导出格式说明，添加单位制信息
        Frame {
            Layout.fillWidth: true
            background: Rectangle {
                color: Material.color(Material.Green, Material.Shade50)
                border.color: Material.color(Material.Green, Material.Shade200)
                radius: 8
            }
            RowLayout {
                anchors.margins: 12
                spacing: 12
                Layout.fillWidth: true

                Text { text: "📄"; font.pixelSize: 28 }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: isChineseMode
                              ? "导出格式：Excel (.xlsx)"
                              : "Export Format: Excel (.xlsx)"
                        font.pixelSize: 15
                        font.bold: true
                        color: Material.color(Material.Green, Material.Shade800)
                    }

                    Text {
                        text: isChineseMode
                              ? "文件将包含所选设备的所有详细信息和性能参数"
                              : "File will contain all detailed information and performance parameters"
                        font.pixelSize: 12
                        color: Material.color(Material.Green, Material.Shade700)
                        wrapMode: Text.WordWrap
                    }

                    // 🔥 添加单位制说明
                    Text {
                        text: isChineseMode
                              ? `数据将以${root.isMetric ? "公制" : "英制"}单位导出`
                              : `Data will be exported in ${root.isMetric ? "metric" : "imperial"} units`
                        font.pixelSize: 12
                        color: Material.color(Material.Green, Material.Shade800)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Frame {
            Layout.fillWidth: true
            background: Rectangle {
                color: Material.color(Material.Blue, Material.Shade50)
                border.color: Material.color(Material.Blue, Material.Shade200)
                radius: 8
            }
            ColumnLayout {
                anchors.margins: 12
                spacing: 8

                Text {
                    text: isChineseMode ? "📊 导出预览" : "📊 Export Preview"
                    font.pixelSize: 14
                    font.bold: true
                    color: Material.color(Material.Blue, Material.Shade800)
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 6

                    Label {
                        text: isChineseMode ? "设备类型:" : "Device Type:"
                        color: Material.color(Material.Blue, Material.Shade700)
                    }
                    Label {
                        text: getDeviceTypeName(root.selectedType)
                        font.bold: true
                    }

                    Label {
                        text: isChineseMode ? "预计数量:" : "Estimated Count:"
                        color: Material.color(Material.Blue, Material.Shade700)
                    }
                    Label {
                        text: getEstimatedCount(root.selectedType)
                        font.bold: true
                    }

                    // 🔥 添加单位制信息
                    Label {
                        text: isChineseMode ? "单位制:" : "Unit System:"
                        color: Material.color(Material.Blue, Material.Shade700)
                    }
                    Label {
                        text: root.isMetric ?
                            (isChineseMode ? "公制 (m, kPa, m³/d)" : "Metric (m, kPa, m³/d)") :
                            (isChineseMode ? "英制 (ft, psi, bbl/d)" : "Imperial (ft, psi, bbl/d)")
                        font.bold: true
                        color: Material.color(Material.Blue, Material.Shade800)
                    }
                }
            }
        }

        // 推挤剩余空间至按钮区
        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 16

            Button {
                text: isChineseMode ? "取消" : "Cancel"
                onClicked: root.close()
            }
            Button {
                text: isChineseMode ? "导出" : "Export"
                Material.accent: true
                onClicked: exportSaveDialog.open()
            }
        }
    }

    // 🔥 修改文件保存对话框，包含单位制信息
    FileDialog {
        id: exportSaveDialog
        title: isChineseMode ? "保存导出文件" : "Save Export File"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "xlsx"
        nameFilters: ["Excel files (*.xlsx)", "All files (*)"]

        selectedFile: {
            var ts = Qt.formatDateTime(new Date(), "yyyyMMdd_hhmmss")
            var unitSuffix = root.isMetric ? "_metric" : "_imperial"
            var prefix = ({
                all:       isChineseMode ? "全部设备导出_"   : "all_devices_export_",
                pump:      isChineseMode ? "泵设备导出_"     : "pump_devices_export_",
                motor:     isChineseMode ? "电机设备导出_"   : "motor_devices_export_",
                protector: isChineseMode ? "保护器设备导出_" : "protector_devices_export_",
                separator: isChineseMode ? "分离器设备导出_" : "separator_devices_export_"
            })[root.selectedType] || (isChineseMode ? "设备导出_" : "devices_export_")
            return prefix + ts + unitSuffix + ".xlsx"
        }

        onAccepted: {
            // 🔥 传递单位制信息
            root.exportRequested(selectedFile.toString(), root.selectedType, root.isMetric)
            root.close()
        }
    }

    // 按钮组
    ButtonGroup {
        id: deviceTypeGroup
    }

    function getDeviceTypeName(type) {
        var map = {
            all:       isChineseMode ? "全部设备"       : "All Devices",
            pump:      isChineseMode ? "潜油离心泵"     : "Centrifugal Pumps",
            motor:     isChineseMode ? "电机"           : "Motors",
            protector: isChineseMode ? "保护器"         : "Protectors",
            separator: isChineseMode ? "分离器"         : "Separators"
        }
        return map[type] || map.all
    }

    function getEstimatedCount(type) {
        var map = { all: "150+", pump: "60", motor: "45", protector: "30", separator: "15" }
        return map[type] || "0"
    }
}
