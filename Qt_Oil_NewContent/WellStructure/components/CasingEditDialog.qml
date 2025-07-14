import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Dialog {
    id: root

    property int wellId: -1
    property bool isChineseMode: true
    property bool isNewCasing: true
    property var editingCasing: null

    signal saved()

    title: isNewCasing ?
        (isChineseMode ? "添加套管" : "Add Casing") :
        (isChineseMode ? "编辑套管" : "Edit Casing")

    width: 600
    height: 550
    modal: true
    standardButtons: Dialog.NoButton

    // 数据属性
    property string casingType: ""
    property string casingSize: ""
    property string topDepth: ""
    property string bottomDepth: ""
    property string topTvd: ""
    property string bottomTvd: ""
    property string innerDiameter: ""
    property string outerDiameter: ""
    property string wallThickness: ""
    property string roughness: ""
    property string material: ""
    property string grade: ""
    property string weight: ""
    property string manufacturer: ""
    property string notes: ""

    contentItem: ScrollView {
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            // 基本信息
            GroupBox {
                Layout.fillWidth: true
                Layout.margins: 10
                title: isChineseMode ? "基本信息" : "Basic Information"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChineseMode ? "套管类型 *" : "Casing Type *"
                        Layout.alignment: Qt.AlignRight
                    }
                    ComboBox {
                        Layout.fillWidth: true
                        model: isChineseMode ?
                            ["", "表层套管", "技术套管", "生产套管"] :
                            ["", "Surface Casing", "Intermediate Casing", "Production Casing"]
                        currentIndex: {
                            var idx = model.indexOf(casingType)
                            return idx >= 0 ? idx : 0
                        }
                        onCurrentTextChanged: {
                            if (currentIndex > 0) {
                                casingType = currentText
                            }
                        }
                    }

                    Label {
                        text: isChineseMode ? "套管尺寸" : "Casing Size"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: casingSize
                        placeholderText: isChineseMode ? "例如: 9-5/8\"" : "e.g., 9-5/8\""
                        onTextChanged: casingSize = text
                    }
                }
            }

            // 深度信息
            GroupBox {
                Layout.fillWidth: true
                Layout.margins: 10
                title: isChineseMode ? "深度信息" : "Depth Information"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChineseMode ? "顶深 (ft) *" : "Top Depth (ft) *"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: topDepth
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: topDepth = text
                    }

                    Label {
                        text: isChineseMode ? "底深 (ft) *" : "Bottom Depth (ft) *"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: bottomDepth
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: bottomDepth = text
                    }

                    Label {
                        text: isChineseMode ? "顶部垂深 (ft)" : "Top TVD (ft)"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: topTvd
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: topTvd = text
                    }

                    Label {
                        text: isChineseMode ? "底部垂深 (ft)" : "Bottom TVD (ft)"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: bottomTvd
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: bottomTvd = text
                    }
                }
            }

            // 尺寸参数
            GroupBox {
                Layout.fillWidth: true
                Layout.margins: 10
                title: isChineseMode ? "尺寸参数" : "Dimension Parameters"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChineseMode ? "内径 (mm) *" : "Inner Diameter (mm) *"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: innerDiameter
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: innerDiameter = text
                    }

                    Label {
                        text: isChineseMode ? "外径 (mm) *" : "Outer Diameter (mm) *"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: outerDiameter
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: outerDiameter = text
                    }

                    Label {
                        text: isChineseMode ? "壁厚 (mm)" : "Wall Thickness (mm)"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: wallThickness
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: wallThickness = text
                    }

                    Label {
                        text: isChineseMode ? "粗糙度" : "Roughness"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: roughness
                        placeholderText: "0.0000"
                        validator: DoubleValidator { bottom: 0; decimals: 4 }
                        onTextChanged: roughness = text
                    }
                }
            }

            // 材质信息
            GroupBox {
                Layout.fillWidth: true
                Layout.margins: 10
                title: isChineseMode ? "材质信息" : "Material Information"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChineseMode ? "材质" : "Material"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: material
                        placeholderText: isChineseMode ? "例如: 碳钢" : "e.g., Carbon Steel"
                        onTextChanged: material = text
                    }

                    Label {
                        text: isChineseMode ? "钢级" : "Grade"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: grade
                        placeholderText: isChineseMode ? "例如: J55" : "e.g., J55"
                        onTextChanged: grade = text
                    }

                    Label {
                        text: isChineseMode ? "单位重量 (kg/m)" : "Weight (kg/m)"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: weight
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: weight = text
                    }

                    Label {
                        text: isChineseMode ? "制造商" : "Manufacturer"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: manufacturer
                        onTextChanged: manufacturer = text
                    }
                }
            }

            // 备注
            GroupBox {
                Layout.fillWidth: true
                Layout.margins: 10
                Layout.preferredHeight: 100
                title: isChineseMode ? "备注" : "Notes"

                ScrollView {
                    anchors.fill: parent
                    TextArea {
                        text: notes
                        placeholderText: isChineseMode ? "请输入备注信息..." : "Enter notes..."
                        wrapMode: TextArea.Wrap
                        onTextChanged: notes = text
                        selectByMouse: true
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
            }
        }
    }

    footer: DialogButtonBox {
        Button {
            text: isChineseMode ? "保存" : "Save"
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            highlighted: true
            enabled: validateInput()

            onClicked: saveCasingData()
        }

        Button {
            text: isChineseMode ? "取消" : "Cancel"
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole

            onClicked: root.reject()
        }
    }

    // 打开对话框 - 新建
    function openForNew() {
        isNewCasing = true
        editingCasing = null
        resetData()
        open()
    }

    // 打开对话框 - 编辑
    function openForEdit(casing) {
        isNewCasing = false
        editingCasing = casing
        loadCasingData(casing)
        open()
    }

    // 重置数据
    function resetData() {
        casingType = ""
        casingSize = ""
        topDepth = ""
        bottomDepth = ""
        topTvd = ""
        bottomTvd = ""
        innerDiameter = ""
        outerDiameter = ""
        wallThickness = ""
        roughness = ""
        material = ""
        grade = ""
        weight = ""
        manufacturer = ""
        notes = ""
    }

    // 加载套管数据
    function loadCasingData(casing) {
        casingType = casing.casing_type || ""
        casingSize = casing.casing_size || ""
        topDepth = casing.top_depth ? casing.top_depth.toString() : ""
        bottomDepth = casing.bottom_depth ? casing.bottom_depth.toString() : ""
        topTvd = casing.top_tvd ? casing.top_tvd.toString() : ""
        bottomTvd = casing.bottom_tvd ? casing.bottom_tvd.toString() : ""
        innerDiameter = casing.inner_diameter ? casing.inner_diameter.toString() : ""
        outerDiameter = casing.outer_diameter ? casing.outer_diameter.toString() : ""
        wallThickness = casing.wall_thickness ? casing.wall_thickness.toString() : ""
        roughness = casing.roughness ? casing.roughness.toString() : ""
        material = casing.material || ""
        grade = casing.grade || ""
        weight = casing.weight ? casing.weight.toString() : ""
        manufacturer = casing.manufacturer || ""
        notes = casing.notes || ""
    }

    // 验证输入
    function validateInput() {
        return casingType.length > 0 &&
               topDepth.length > 0 && !isNaN(parseFloat(topDepth)) &&
               bottomDepth.length > 0 && !isNaN(parseFloat(bottomDepth)) &&
               innerDiameter.length > 0 && !isNaN(parseFloat(innerDiameter)) &&
               outerDiameter.length > 0 && !isNaN(parseFloat(outerDiameter)) &&
               parseFloat(topDepth) < parseFloat(bottomDepth) &&
               parseFloat(innerDiameter) < parseFloat(outerDiameter)
    }

    // 保存套管数据
    function saveCasingData() {
        var dataToSave = {
            well_id: wellId,
            casing_type: casingType,
            casing_size: casingSize || null,
            top_depth: parseFloat(topDepth),
            bottom_depth: parseFloat(bottomDepth),
            top_tvd: topTvd ? parseFloat(topTvd) : null,
            bottom_tvd: bottomTvd ? parseFloat(bottomTvd) : null,
            inner_diameter: parseFloat(innerDiameter),
            outer_diameter: parseFloat(outerDiameter),
            wall_thickness: wallThickness ? parseFloat(wallThickness) : null,
            roughness: roughness ? parseFloat(roughness) : null,
            material: material || null,
            grade: grade || null,
            weight: weight ? parseFloat(weight) : null,
            manufacturer: manufacturer || null,
            notes: notes || null
        }

        if (!isNewCasing && editingCasing) {
            dataToSave.id = editingCasing.id
            wellStructureController.updateCasing(dataToSave)
        } else {
            wellStructureController.createCasing(dataToSave)
        }

        saved()
        accept()
    }
}
