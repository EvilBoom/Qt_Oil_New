// Qt_Oil_NewContent/OilWellManagement/components/WellDataDialogForm.ui.qml
// 这是Qt Design Studio友好的表单文件
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: 600
    height: 500
    color: "#ffffff"

    property alias wellNameField: wellNameField
    property alias depthField: depthField
    property alias wellTypeCombo: wellTypeCombo
    property alias wellStatusCombo: wellStatusCombo
    property alias innerDiameterField: innerDiameterField
    property alias outerDiameterField: outerDiameterField
    property alias pumpDepthField: pumpDepthField
    property alias tubingDiameterField: tubingDiameterField
    property alias notesArea: notesArea

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 20

            // 基本信息组
            GroupBox {
                Layout.fillWidth: true
                title: "基本信息"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: "井号 *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: wellNameField
                        Layout.fillWidth: true
                        placeholderText: "请输入井号"
                    }

                    Label {
                        text: "井深 (ft) *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: depthField
                        Layout.fillWidth: true
                        placeholderText: "请输入井深"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: "井型"
                        Layout.alignment: Qt.AlignRight
                    }

                    ComboBox {
                        id: wellTypeCombo
                        Layout.fillWidth: true
                        model: ["直井", "定向井", "水平井"]
                    }

                    Label {
                        text: "井状态"
                        Layout.alignment: Qt.AlignRight
                    }

                    ComboBox {
                        id: wellStatusCombo
                        Layout.fillWidth: true
                        model: ["生产", "关停", "维修"]
                    }
                }
            }

            // 结构参数组
            GroupBox {
                Layout.fillWidth: true
                title: "结构参数"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: "内径 (mm)"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: innerDiameterField
                        Layout.fillWidth: true
                        placeholderText: "请输入内径"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: "外径 (mm)"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: outerDiameterField
                        Layout.fillWidth: true
                        placeholderText: "请输入外径"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: "泵挂深度 (m)"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: pumpDepthField
                        Layout.fillWidth: true
                        placeholderText: "请输入泵挂深度"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: "管径 (mm)"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: tubingDiameterField
                        Layout.fillWidth: true
                        placeholderText: "请输入管径"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }
                }
            }

            // 备注
            GroupBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                title: "备注信息"

                ScrollView {
                    anchors.fill: parent

                    TextArea {
                        id: notesArea
                        placeholderText: "请输入备注信息..."
                        wrapMode: TextArea.Wrap
                    }
                }
            }
        }
    }
}
