import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Item {
    id: root

    property int projectId: -1
    property bool isChineseMode: true
    property var editingWell: null
    property bool isNewWell: true

    signal saved()

    // Dialog实例
    property alias dialog: wellDialog

    // 井数据模型 - 使用独立的属性而不是对象
    property string wellName: ""
    property string wellDepth: ""
    property string innerDiameter: ""
    property string outerDiameter: ""
    property string pumpDepth: ""
    property string tubingDiameter: ""
    property string wellType: ""
    property string wellStatus: ""
    property string completionDate: ""
    property string notes: ""

    // 打开对话框 - 新建
    function openForNew() {
        isNewWell = true
        editingWell = null

        // 重置数据
        wellName = ""
        wellDepth = ""
        innerDiameter = ""
        outerDiameter = ""
        pumpDepth = ""
        tubingDiameter = ""
        wellType = ""
        wellStatus = ""
        completionDate = ""
        notes = ""

        wellDialog.open()
    }

    // 打开对话框 - 编辑
    function openForEdit(well) {
        isNewWell = false
        editingWell = well

        // 加载现有数据
        wellName = well.well_name || ""
        wellDepth = well.well_md ? well.well_md.toString() : ""
        innerDiameter = well.inner_diameter ? well.inner_diameter.toString() : ""
        outerDiameter = well.outer_diameter ? well.outer_diameter.toString() : ""
        pumpDepth = well.pump_depth ? well.pump_depth.toString() : ""
        tubingDiameter = well.tubing_diameter ? well.tubing_diameter.toString() : ""
        wellType = well.well_type || ""
        wellStatus = well.well_status || ""
        completionDate = well.completion_date || ""
        notes = well.notes || ""

        wellDialog.open()
    }

    Dialog {
        id: wellDialog

        parent: Overlay.overlay
        anchors.centerIn: parent

        title: isNewWell ? (isChineseMode ? "新建井" : "New Well") : (isChineseMode ? "编辑井信息" : "Edit Well Info")
        width: 650
        height: 600
        modal: true
        standardButtons: Dialog.NoButton

        contentItem: Item {
            implicitWidth: 600
            implicitHeight: 500

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: availableWidth
                contentHeight: contentColumn.height
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: contentColumn
                    width: parent.availableWidth
                    spacing: 16

                    // 基本信息组
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        title: isChineseMode ? "基本信息" : "Basic Information"

                        GridLayout {
                            width: parent.width
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 20

                            // 井号
                            Label {
                                text: isChineseMode ? "井号 *" : "Well Name *"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                id: wellNameField
                                Layout.fillWidth: true
                                text: wellName
                                placeholderText: isChineseMode ? "请输入井号" : "Enter well name"
                                onTextChanged: wellName = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 井深
                            Label {
                                text: isChineseMode ? "井深 (m) *" : "Well Depth (m) *"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                id: depthField
                                Layout.fillWidth: true
                                text: wellDepth
                                placeholderText: isChineseMode ? "请输入井深" : "Enter well depth"
                                validator: DoubleValidator {
                                    bottom: 0
                                    decimals: 2
                                }
                                onTextChanged: wellDepth = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 井型
                            Label {
                                text: isChineseMode ? "井型" : "Well Type"
                                Layout.alignment: Qt.AlignRight
                            }
                            ComboBox {
                                Layout.fillWidth: true
                                model: isChineseMode ? ["", "直井", "定向井", "水平井"] : ["", "Vertical", "Directional", "Horizontal"]
                                currentIndex: {
                                    if (!wellType) return 0
                                    var idx = model.indexOf(wellType)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentIndex > 0) {
                                        wellType = currentText
                                    } else {
                                        wellType = ""
                                    }
                                }
                            }

                            // 井状态
                            Label {
                                text: isChineseMode ? "井状态" : "Well Status"
                                Layout.alignment: Qt.AlignRight
                            }
                            ComboBox {
                                Layout.fillWidth: true
                                model: isChineseMode ? ["", "生产", "关停", "维修"] : ["", "Producing", "Shut-in", "Maintenance"]
                                currentIndex: {
                                    if (!wellStatus) return 0
                                    var idx = model.indexOf(wellStatus)
                                    return idx >= 0 ? idx : 0
                                }
                                onCurrentTextChanged: {
                                    if (currentIndex > 0) {
                                        wellStatus = currentText
                                    } else {
                                        wellStatus = ""
                                    }
                                }
                            }
                        }
                    }

                    // 结构参数组
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        title: isChineseMode ? "结构参数" : "Structure Parameters"

                        GridLayout {
                            width: parent.width
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 20

                            // 内径
                            Label {
                                text: isChineseMode ? "内径 (mm)" : "Inner Diameter (mm)"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: innerDiameter
                                placeholderText: isChineseMode ? "请输入内径" : "Enter inner diameter"
                                validator: DoubleValidator {
                                    bottom: 0
                                    decimals: 2
                                }
                                onTextChanged: innerDiameter = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 外径
                            Label {
                                text: isChineseMode ? "外径 (mm)" : "Outer Diameter (mm)"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: outerDiameter
                                placeholderText: isChineseMode ? "请输入外径" : "Enter outer diameter"
                                validator: DoubleValidator {
                                    bottom: 0
                                    decimals: 2
                                }
                                onTextChanged: outerDiameter = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 泵挂深度
                            Label {
                                text: isChineseMode ? "泵挂深度 (m)" : "Pump Depth (m)"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: pumpDepth
                                placeholderText: isChineseMode ? "请输入泵挂深度" : "Enter pump depth"
                                validator: DoubleValidator {
                                    bottom: 0
                                    decimals: 2
                                }
                                onTextChanged: pumpDepth = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 管径
                            Label {
                                text: isChineseMode ? "管径 (mm)" : "Tubing Diameter (mm)"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: tubingDiameter
                                placeholderText: isChineseMode ? "请输入管径" : "Enter tubing diameter"
                                validator: DoubleValidator {
                                    bottom: 0
                                    decimals: 2
                                }
                                onTextChanged: tubingDiameter = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }
                        }
                    }

                    // 备注
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        Layout.preferredHeight: 120
                        title: isChineseMode ? "备注信息" : "Notes"

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 5

                            TextArea {
                                id: notesArea
                                text: notes
                                placeholderText: isChineseMode ? "请输入备注信息..." : "Enter notes..."
                                wrapMode: TextArea.Wrap
                                onTextChanged: notes = text
                                selectByMouse: true

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }
                        }
                    }

                    // 添加一些底部空间
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                    }
                }
            }
        }

        footer: DialogButtonBox {
            Button {
                text: isChineseMode ? "保存" : "Save"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                highlighted: true
                enabled: wellName.trim().length > 0 && wellDepth.trim().length > 0 && !isNaN(parseFloat(wellDepth))

                onClicked: saveWellData()
            }

            Button {
                text: isChineseMode ? "取消" : "Cancel"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole

                onClicked: wellDialog.reject()
            }
        }

        onAccepted: {
            // 对话框接受时的处理
        }

        onRejected: {
            // 对话框拒绝时的处理
        }
    }

    // 保存井数据
    function saveWellData() {
        // 准备数据
        var dataToSave = {
            project_id: projectId,
            well_name: wellName.trim(),
            well_md: parseFloat(wellDepth) || null,
            inner_diameter: innerDiameter ? parseFloat(innerDiameter) : null,
            outer_diameter: outerDiameter ? parseFloat(outerDiameter) : null,
            pump_depth: pumpDepth ? parseFloat(pumpDepth) : null,
            tubing_diameter: tubingDiameter ? parseFloat(tubingDiameter) : null,
            well_type: wellType || null,
            well_status: wellStatus || null,
            notes: notes || null
        }

        if (isNewWell) {
            // 创建新井
            wellController.createWell(dataToSave)
        } else {
            // 更新现有井
            dataToSave.id = editingWell.id
            wellController.updateWellData(dataToSave)
        }

        saved()
        wellDialog.accept()
    }

    // 错误提示对话框
    Dialog {
        id: errorDialog
        title: isChineseMode ? "错误" : "Error"
        modal: true
        standardButtons: Dialog.Ok

        property string errorMessage: ""

        contentItem: Text {
            text: errorDialog.errorMessage
            wrapMode: Text.Wrap
            color: "#ff0000"
        }
    }

    // 错误提示
    function showError(message) {
        errorDialog.errorMessage = message
        errorDialog.open()
    }
}
