import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs

// 将根元素从Dialog改为Item
Item {
    id: rootItem
    
    // 属性和信号
    property bool isChineseMode: true
    signal importRequested(string fileUrl, string deviceType)
    
    // 添加公开方法
    function open() {
        dialog.open()
    }
    
    function close() {
        dialog.close()
    }

    // 内部状态属性
    property string selectedFile: ""
    property string selectedType: "pump"

    // 实际的Dialog作为子元素
    Dialog {
        id: dialog
        parent: rootItem.parent
        
        title: isChineseMode ? "导入设备数据" : "Import Device Data"
        width: 600
        height: 400
        modal: true
        
        // 居中显示
        anchors.centerIn: parent

        contentItem: ColumnLayout {
            spacing: 20

            // 步骤说明
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#e3f2fd"
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15

                    Label {
                        text: "ℹ️"
                        font.pixelSize: 20
                    }

                    Label {
                        Layout.fillWidth: true
                        text: isChineseMode ?
                            "请选择设备类型并上传对应的Excel文件，系统将自动解析并导入数据。" :
                            "Please select device type and upload the corresponding Excel file. The system will parse and import the data automatically."
                        wrapMode: Text.WordWrap
                        color: "#1976d2"
                    }
                }
            }

            // 设备类型选择
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "1. 选择设备类型" : "1. Select Device Type"

                ColumnLayout {
                    spacing: 10

                    RadioButton {
                        text: isChineseMode ? "潜油离心泵" : "Centrifugal Pump"
                        checked: rootItem.selectedType === "pump"
                        onCheckedChanged: if (checked) rootItem.selectedType = "pump"
                    }

                    RadioButton {
                        text: isChineseMode ? "电机" : "Motor"
                        checked: rootItem.selectedType === "motor"
                        onCheckedChanged: if (checked) rootItem.selectedType = "motor"
                    }

                    RadioButton {
                        text: isChineseMode ? "保护器" : "Protector"
                        checked: rootItem.selectedType === "protector"
                        onCheckedChanged: if (checked) rootItem.selectedType = "protector"
                    }

                    RadioButton {
                        text: isChineseMode ? "分离器" : "Separator"
                        checked: rootItem.selectedType === "separator"
                        onCheckedChanged: if (checked) rootItem.selectedType = "separator"
                    }
                }
            }

            // 文件选择
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "2. 选择Excel文件" : "2. Select Excel File"

                ColumnLayout {
                    width: parent.width
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            Layout.fillWidth: true
                            text: rootItem.selectedFile ? rootItem.selectedFile.split('/').pop() : ""
                            readOnly: true
                            placeholderText: isChineseMode ? "请选择文件..." : "Please select file..."
                        }

                        Button {
                            text: isChineseMode ? "浏览" : "Browse"
                            onClicked: fileDialog.open()
                        }
                    }

                    Button {
                        text: isChineseMode ? "下载模板" : "Download Template"
                        flat: true
                        Material.foreground: Material.Blue

                        onClicked: {
                            // TODO: 实现模板下载
                            console.log("Download template for:", rootItem.selectedType)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (!rootItem.selectedFile) {
                // TODO: 显示错误提示
                return
            }

            rootItem.importRequested(rootItem.selectedFile, rootItem.selectedType)
        }
    }

    FileDialog {
        id: fileDialog
        title: isChineseMode ? "选择Excel文件" : "Select Excel File"
        nameFilters: ["Excel files (*.xlsx *.xls)", "All files (*)"]

        onAccepted: {
            rootItem.selectedFile = selectedUrl.toString()
        }
    }
}