import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs

Dialog {
    id: root

    property bool isChineseMode: true

    signal exportRequested(string fileUrl, string deviceType)

    title: isChineseMode ? "导出设备数据" : "Export Device Data"
    width: 500
    height: 350
    modal: true

    property string selectedType: "all"
    property string selectedFile: ""

    contentItem: ColumnLayout {
        spacing: 20

        // 导出选项
        GroupBox {
            Layout.fillWidth: true
            title: isChineseMode ? "导出选项" : "Export Options"

            ColumnLayout {
                spacing: 10

                RadioButton {
                    text: isChineseMode ? "全部设备" : "All Devices"
                    checked: selectedType === "all"
                    onCheckedChanged: if (checked) selectedType = "all"
                }

                RadioButton {
                    text: isChineseMode ? "仅潜油离心泵" : "Centrifugal Pumps Only"
                    checked: selectedType === "pump"
                    onCheckedChanged: if (checked) selectedType = "pump"
                }

                RadioButton {
                    text: isChineseMode ? "仅电机" : "Motors Only"
                    checked: selectedType === "motor"
                    onCheckedChanged: if (checked) selectedType = "motor"
                }

                RadioButton {
                    text: isChineseMode ? "仅保护器" : "Protectors Only"
                    checked: selectedType === "protector"
                    onCheckedChanged: if (checked) selectedType = "protector"
                }

                RadioButton {
                    text: isChineseMode ? "仅分离器" : "Separators Only"
                    checked: selectedType === "separator"
                    onCheckedChanged: if (checked) selectedType = "separator"
                }
            }
        }

        // 文件信息
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#f5f5f5"
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15

                Label {
                    text: "📄"
                    font.pixelSize: 24
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: isChineseMode ? "导出格式：Excel (.xlsx)" : "Export Format: Excel (.xlsx)"
                        font.pixelSize: 14
                        color: "#333"
                    }

                    Label {
                        text: isChineseMode ?
                              "文件将包含所选设备的所有信息" :
                              "File will contain all information of selected devices"
                        font.pixelSize: 12
                        color: "#666"
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    standardButtons: Dialog.Ok | Dialog.Cancel

    onAccepted: {
        fileDialog.open()
    }

    FileDialog {
        id: fileDialog
        title: isChineseMode ? "保存文件" : "Save File"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "xlsx"
        nameFilters: ["Excel files (*.xlsx)", "All files (*)"]

        onAccepted: {
            root.exportRequested(selectedUrl.toString(), selectedType)
        }
    }
}
