import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // 添加语言属性
    property bool isChinese: parent && parent.parent ? parent.parent.isChinese : true

    Dialog {
        id: dialog
        width: 600
        height: 550
        modal: true
        anchors.centerIn: parent

        // 自定义标题栏
        header: Rectangle {
            height: 60
            color: "#1e3a5f"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 16

                Text {
                    text: root.isChinese ? "录入油井生产参数" : "Input Production Parameters"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                RoundButton {
                    width: 32
                    height: 32

                    background: Rectangle {
                        radius: width / 2
                        color: parent.hovered ? Qt.rgba(255, 255, 255, 0.2) : "transparent"
                    }

                    contentItem: Text {
                        text: "✕"
                        color: "white"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: dialog.close()
                }
            }
        }

        // 内容区域
        contentItem: Rectangle {
            color: "#f5f7fa"

            ScrollView {
                anchors.fill: parent
                anchors.margins: 24
                contentWidth: width - 48

                ColumnLayout {
                    width: parent.width
                    spacing: 20

                    // 油井编号
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: (root.isChinese ? "油井编号" : "Well ID") + " *"
                            color: "#333"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        ComboBox {
                            id: wellIdCombo
                            Layout.fillWidth: true
                            model: ["W-001", "W-002", "W-003", "W-004", "W-005"]
                            displayText: currentIndex === -1 ?
                                (root.isChinese ? "请选择油井" : "Select Well") : currentText
                        }
                    }

                    // 生产参数区域
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: paramLayout.implicitHeight + 40
                        color: "white"
                        radius: 8

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Text {
                                text: root.isChinese ? "生产参数" : "Production Parameters"
                                color: "#666"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            GridLayout {
                                id: paramLayout
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 16
                                columnSpacing: 20

                                // 日产液量
                                Label {
                                    text: root.isChinese ? "日产液量 (m³/d)" : "Daily Liquid Production (m³/d)"
                                    color: "#666"
                                }
                                TextField {
                                    id: dailyLiquidField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入日产液量" : "Enter daily liquid production"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 2
                                    }
                                }

                                // 含水率
                                Label {
                                    text: root.isChinese ? "含水率 (%)" : "Water Cut (%)"
                                    color: "#666"
                                }
                                TextField {
                                    id: waterCutField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入含水率" : "Enter water cut"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        top: 100
                                        decimals: 1
                                    }
                                }

                                // 泵挂深度
                                Label {
                                    text: root.isChinese ? "泵挂深度 (m)" : "Pump Setting Depth (m)"
                                    color: "#666"
                                }
                                TextField {
                                    id: pumpDepthField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入泵挂深度" : "Enter pump setting depth"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 1
                                    }
                                }

                                // 动液面
                                Label {
                                    text: root.isChinese ? "动液面 (m)" : "Dynamic Liquid Level (m)"
                                    color: "#666"
                                }
                                TextField {
                                    id: dynamicLevelField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入动液面深度" : "Enter dynamic liquid level"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 1
                                    }
                                }

                                // 油压
                                Label {
                                    text: root.isChinese ? "油压 (MPa)" : "Oil Pressure (MPa)"
                                    color: "#666"
                                }
                                TextField {
                                    id: oilPressureField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入油压" : "Enter oil pressure"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 2
                                    }
                                }

                                // 套压
                                Label {
                                    text: root.isChinese ? "套压 (MPa)" : "Casing Pressure (MPa)"
                                    color: "#666"
                                }
                                TextField {
                                    id: casingPressureField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入套压" : "Enter casing pressure"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 2
                                    }
                                }
                            }
                        }
                    }

                    // 备注
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: root.isChinese ? "备注" : "Remarks"
                            color: "#333"
                            font.pixelSize: 14
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80

                            TextArea {
                                id: remarksArea
                                placeholderText: root.isChinese ?
                                    "请输入备注信息（可选）" :
                                    "Enter remarks (optional)"
                                wrapMode: TextArea.Wrap
                                selectByMouse: true
                                background: Rectangle {
                                    color: "white"
                                    border.color: "#ddd"
                                    radius: 4
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // 底部按钮
        footer: Rectangle {
            height: 60
            color: "white"

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#e0e0e0"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Item { Layout.fillWidth: true }

                Button {
                    text: root.isChinese ? "取消" : "Cancel"
                    flat: true

                    contentItem: Text {
                        text: parent.text
                        color: "#666"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.hovered ? "#f5f5f5" : "transparent"
                        border.color: "#ddd"
                        border.width: 1
                        radius: 6
                    }

                    onClicked: dialog.close()
                }

                Button {
                    text: root.isChinese ? "保存" : "Save"
                    enabled: validateForm()

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? "#357abd" : "#4a90e2") : "#cccccc"
                        radius: 6
                    }

                    onClicked: {
                        saveProductionParams()
                        dialog.close()
                    }
                }
            }
        }

        onOpened: {
            // 对话框打开时，聚焦到第一个输入框
            wellIdCombo.forceActiveFocus()
        }
    }

    // 表单验证
    function validateForm() {
        return wellIdCombo.currentIndex !== -1 &&
               dailyLiquidField.text.length > 0 &&
               waterCutField.text.length > 0 &&
               pumpDepthField.text.length > 0
    }

    // 保存生产参数
    function saveProductionParams() {
        var params = {
            wellId: wellIdCombo.currentText,
            dailyLiquid: parseFloat(dailyLiquidField.text),
            waterCut: parseFloat(waterCutField.text),
            pumpDepth: parseFloat(pumpDepthField.text),
            dynamicLevel: parseFloat(dynamicLevelField.text) || 0,
            oilPressure: parseFloat(oilPressureField.text) || 0,
            casingPressure: parseFloat(casingPressureField.text) || 0,
            remarks: remarksArea.text
        }

        console.log(root.isChinese ? "保存生产参数:" : "Save production parameters:", JSON.stringify(params))
        // 这里调用后端API保存数据
    }

    // 打开对话框
    function open() {
        dialog.open()
    }

    // 关闭对话框
    function close() {
        dialog.close()
    }
}
