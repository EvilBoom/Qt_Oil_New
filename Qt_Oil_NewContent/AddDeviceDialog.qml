import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // 添加语言属性
    property bool isChinese: parent && parent.parent ? parent.parent.isChinese : true

    Dialog {
        id: dialog
        width: 650
        height: 600
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
                    text: root.isChinese ? "添加新设备" : "Add New Equipment"
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

                    // 基本信息组
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: basicInfoLayout.implicitHeight + 40
                        color: "white"
                        radius: 8

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Text {
                                text: root.isChinese ? "基本信息" : "Basic Information"
                                color: "#666"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            GridLayout {
                                id: basicInfoLayout
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 16
                                columnSpacing: 20

                                // 设备类型
                                Label {
                                    text: (root.isChinese ? "设备类型" : "Equipment Type") + " *"
                                    color: "#666"
                                }
                                ComboBox {
                                    id: deviceTypeCombo
                                    Layout.fillWidth: true
                                    model: root.isChinese ?
                                        ["抽油机", "潜油电泵", "螺杆泵", "其他设备"] :
                                        ["Pumping Unit", "ESP", "PCP", "Other"]
                                    displayText: currentIndex === -1 ?
                                        (root.isChinese ? "请选择设备类型" : "Select equipment type") :
                                        currentText
                                }

                                // 设备型号
                                Label {
                                    text: (root.isChinese ? "设备型号" : "Model") + " *"
                                    color: "#666"
                                }
                                TextField {
                                    id: modelField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入设备型号" : "Enter model number"
                                }

                                // 生产厂家
                                Label {
                                    text: (root.isChinese ? "生产厂家" : "Manufacturer") + " *"
                                    color: "#666"
                                }
                                TextField {
                                    id: manufacturerField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入生产厂家" : "Enter manufacturer"
                                }

                                // 额定功率
                                Label {
                                    text: root.isChinese ? "额定功率 (kW)" : "Rated Power (kW)"
                                    color: "#666"
                                }
                                TextField {
                                    id: powerField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入额定功率" : "Enter rated power"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 2
                                    }
                                }
                            }
                        }
                    }

                    // 技术参数组
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: techParamsLayout.implicitHeight + 40
                        color: "white"
                        radius: 8

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Text {
                                text: root.isChinese ? "技术参数" : "Technical Parameters"
                                color: "#666"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            GridLayout {
                                id: techParamsLayout
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 16
                                columnSpacing: 20

                                // 最大载荷
                                Label {
                                    text: root.isChinese ? "最大载荷 (kN)" : "Max Load (kN)"
                                    color: "#666"
                                }
                                TextField {
                                    id: maxLoadField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入最大载荷" : "Enter max load"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 1
                                    }
                                }

                                // 冲程长度
                                Label {
                                    text: root.isChinese ? "冲程长度 (m)" : "Stroke Length (m)"
                                    color: "#666"
                                }
                                TextField {
                                    id: strokeLengthField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "请输入冲程长度" : "Enter stroke length"
                                    validator: DoubleValidator {
                                        bottom: 0
                                        decimals: 2
                                    }
                                }

                                // 冲次范围
                                Label {
                                    text: root.isChinese ? "冲次范围 (次/分)" : "Stroke Rate (spm)"
                                    color: "#666"
                                }
                                TextField {
                                    id: strokeRateField
                                    Layout.fillWidth: true
                                    placeholderText: root.isChinese ? "如: 1-10" : "e.g.: 1-10"
                                }
                            }
                        }
                    }

                    // 备注说明
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Label {
                            text: root.isChinese ? "备注说明" : "Remarks"
                            color: "#333"
                            font.pixelSize: 14
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100

                            TextArea {
                                id: remarksArea
                                placeholderText: root.isChinese ?
                                    "请输入设备的其他技术参数或说明（可选）" :
                                    "Enter other technical parameters or notes (optional)"
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
                        saveDevice()
                        dialog.close()
                    }
                }
            }
        }

        onOpened: {
            // 对话框打开时，聚焦到第一个输入框
            deviceTypeCombo.forceActiveFocus()
        }
    }

    // 表单验证
    function validateForm() {
        return deviceTypeCombo.currentIndex !== -1 &&
               modelField.text.trim().length > 0 &&
               manufacturerField.text.trim().length > 0
    }

    // 保存设备
    function saveDevice() {
        var device = {
            type: deviceTypeCombo.currentText,
            model: modelField.text.trim(),
            manufacturer: manufacturerField.text.trim(),
            power: parseFloat(powerField.text) || 0,
            maxLoad: parseFloat(maxLoadField.text) || 0,
            strokeLength: parseFloat(strokeLengthField.text) || 0,
            strokeRate: strokeRateField.text.trim(),
            remarks: remarksArea.text
        }

        console.log(root.isChinese ? "保存设备信息:" : "Save device information:", JSON.stringify(device))
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
