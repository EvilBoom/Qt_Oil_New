import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Dialog {
    id: root

    property int wellId: -1
    property bool isChineseMode: true
    property bool isNewCasing: true
    property var editingCasing: null
    // 🔥 添加单位制属性
    property bool isMetric: false

    signal saved()

    // 🔥 监听单位制变化
    onIsMetricChanged: {
        console.log("CasingEditDialog单位制切换为:", isMetric ? "公制" : "英制")
        updateFormUnits()
    }
    title: isNewCasing ?
        (isChineseMode ? "添加套管" : "Add Casing") :
        (isChineseMode ? "编辑套管" : "Edit Casing")

    width: 600
    height: 550
    modal: true
    standardButtons: Dialog.NoButton

    // 🔥 内部数据属性 - 始终以数据库原始单位存储
    property string casingType: ""
    property string casingSize: ""
    property real topDepthValue: 0      // 内部存储(ft)
    property real bottomDepthValue: 0   // 内部存储(ft)
    property real topTvdValue: 0        // 内部存储(ft)
    property real bottomTvdValue: 0     // 内部存储(ft)
    property real innerDiameterValue: 0 // 内部存储(mm)
    property real outerDiameterValue: 0 // 内部存储(mm)
    property real wallThicknessValue: 0 // 内部存储(mm)
    property real roughnessValue: 0
    property string material: ""
    property string grade: ""
    property real weightValue: 0        // 内部存储(kg/m)
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
                        id: casingTypeCombo
                        Layout.fillWidth: true
                        model: isChineseMode ?
                            ["", "表层套管", "技术套管", "生产套管"] :
                            ["", "Surface Casing", "Intermediate Casing", "Production Casing"]

                        Component.onCompleted: updateCasingTypeIndex()

                        onCurrentTextChanged: {
                            if (currentIndex > 0) {
                                casingType = getCurrentCasingTypeValue()
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
                        text: isChineseMode ?
                            `顶深 (${getDepthUnit()}) *` :
                            `Top Depth (${getDepthUnit()}) *`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: topDepthField
                        Layout.fillWidth: true
                        text: formatDepthForDisplay(topDepthValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            topDepthValue = convertDepthToInternal(text)
                        }
                    }

                    Label {
                        text: isChineseMode ?
                            `底深 (${getDepthUnit()}) *` :
                            `Bottom Depth (${getDepthUnit()}) *`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: bottomDepthField
                        Layout.fillWidth: true
                        text: formatDepthForDisplay(bottomDepthValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            bottomDepthValue = convertDepthToInternal(text)
                        }
                    }

                    Label {
                        text: isChineseMode ?
                            `顶部垂深 (${getDepthUnit()})` :
                            `Top TVD (${getDepthUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: topTvdField
                        Layout.fillWidth: true
                        text: formatDepthForDisplay(topTvdValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            topTvdValue = convertDepthToInternal(text)
                        }
                    }

                    Label {
                        text: isChineseMode ?
                            `底部垂深 (${getDepthUnit()})` :
                            `Bottom TVD (${getDepthUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: bottomTvdField
                        Layout.fillWidth: true
                        text: formatDepthForDisplay(bottomTvdValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            bottomTvdValue = convertDepthToInternal(text)
                        }
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
                        text: isChineseMode ?
                            `内径 (${getDiameterUnit()}) *` :
                            `Inner Diameter (${getDiameterUnit()}) *`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: innerDiameterField
                        Layout.fillWidth: true
                        text: formatDiameterForDisplay(innerDiameterValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            innerDiameterValue = convertDiameterToInternal(text)
                        }
                    }

                    Label {
                        text: isChineseMode ?
                            `外径 (${getDiameterUnit()}) *` :
                            `Outer Diameter (${getDiameterUnit()}) *`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: outerDiameterField
                        Layout.fillWidth: true
                        text: formatDiameterForDisplay(outerDiameterValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            outerDiameterValue = convertDiameterToInternal(text)
                        }
                    }

                    Label {
                        text: isChineseMode ?
                            `壁厚 (${getDiameterUnit()})` :
                            `Wall Thickness (${getDiameterUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: wallThicknessField
                        Layout.fillWidth: true
                        text: formatDiameterForDisplay(wallThicknessValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            wallThicknessValue = convertDiameterToInternal(text)
                        }
                    }

                    Label {
                        text: isChineseMode ? "粗糙度" : "Roughness"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: roughnessField
                        Layout.fillWidth: true
                        text: roughnessValue > 0 ? roughnessValue.toString() : ""
                        placeholderText: "0.0000"
                        validator: DoubleValidator { bottom: 0; decimals: 4 }
                        onTextChanged: {
                            roughnessValue = parseFloat(text) || 0
                        }
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
                    ComboBox {
                        id: gradeField
                        Layout.fillWidth: true
                        editable: true
                        model: ["J55", "K55", "N80", "L80", "P110", "Q125", "T95", "C90", "C95"]
                        editText: grade
                        onEditTextChanged: grade = editText
                        onCurrentTextChanged: if (currentIndex >= 0) grade = currentText
                    }

                    Label {
                        text: isChineseMode ?
                            `单位重量 (${getWeightUnit()}/m)` :
                            `Weight (${getWeightUnit()}/ft)`
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: weightField
                        Layout.fillWidth: true
                        text: formatWeightForDisplay(weightValue)
                        placeholderText: "0.00"
                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                        onTextChanged: {
                            weightValue = convertWeightToInternal(text)
                        }
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

    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDiameterUnit() {
        return isMetric ? "mm" : "in"
    }

    function getWeightUnit() {
        return isMetric ? "kg" : "lbs"
    }

    // 深度转换函数 (数据库存储为ft)
    function formatDepthForDisplay(valueInFt) {
        if (!valueInFt || valueInFt <= 0) return ""

        if (isMetric) {
            return UnitUtils.feetToMeters(valueInFt).toFixed(1)
        } else {
            return valueInFt.toFixed(1)
        }
    }

    function convertDepthToInternal(displayText) {
        var value = parseFloat(displayText)
        if (isNaN(value)) return 0

        if (isMetric) {
            return UnitUtils.metersToFeet(value)  // 转换为英尺存储
        } else {
            return value  // 直接存储英尺
        }
    }

    // 直径转换函数 (数据库存储为mm)
    function formatDiameterForDisplay(valueInMm) {
        if (!valueInMm || valueInMm <= 0) return ""

        if (isMetric) {
            return valueInMm.toFixed(1)
        } else {
            return UnitUtils.mmToInches(valueInMm).toFixed(2)
        }
    }

    function convertDiameterToInternal(displayText) {
        var value = parseFloat(displayText)
        if (isNaN(value)) return 0

        if (isMetric) {
            return value  // 直接存储毫米
        } else {
            return UnitUtils.inchesToMm(value)  // 转换为毫米存储
        }
    }

    // 重量转换函数 (数据库存储为kg/m)
    function formatWeightForDisplay(valueInKgPerM) {
        if (!valueInKgPerM || valueInKgPerM <= 0) return ""

        if (isMetric) {
            return valueInKgPerM.toFixed(2)
        } else {
            // 转换为 lbs/ft
            var lbsPerFt = valueInKgPerM * 2.20462 * 0.3048
            return lbsPerFt.toFixed(2)
        }
    }

    function convertWeightToInternal(displayText) {
        var value = parseFloat(displayText)
        if (isNaN(value)) return 0

        if (isMetric) {
            return value  // 直接存储 kg/m
        } else {
            // 从 lbs/ft 转换为 kg/m
            return value / 2.20462 / 0.3048
        }
    }

    // 套管类型处理
    function getCurrentCasingTypeValue() {
        var currentText = casingTypeCombo.currentText
        if (isChineseMode) {
            switch(currentText) {
                case "表层套管": return "surface"
                case "技术套管": return "intermediate"
                case "生产套管": return "production"
                default: return ""
            }
        } else {
            switch(currentText) {
                case "Surface Casing": return "surface"
                case "Intermediate Casing": return "intermediate"
                case "Production Casing": return "production"
                default: return ""
            }
        }
    }

    function updateCasingTypeIndex() {
        var targetIndex = 0
        if (isChineseMode) {
            switch(casingType) {
                case "surface": targetIndex = 1; break
                case "intermediate": targetIndex = 2; break
                case "production": targetIndex = 3; break
                default: targetIndex = 0; break
            }
        } else {
            switch(casingType) {
                case "surface": targetIndex = 1; break
                case "intermediate": targetIndex = 2; break
                case "production": targetIndex = 3; break
                default: targetIndex = 0; break
            }
        }
        casingTypeCombo.currentIndex = targetIndex
    }

    function updateFormUnits() {
        console.log("更新套管编辑表单单位显示")

        // 更新所有字段的显示值
        topDepthField.text = formatDepthForDisplay(topDepthValue)
        bottomDepthField.text = formatDepthForDisplay(bottomDepthValue)
        topTvdField.text = formatDepthForDisplay(topTvdValue)
        bottomTvdField.text = formatDepthForDisplay(bottomTvdValue)

        innerDiameterField.text = formatDiameterForDisplay(innerDiameterValue)
        outerDiameterField.text = formatDiameterForDisplay(outerDiameterValue)
        wallThicknessField.text = formatDiameterForDisplay(wallThicknessValue)

        weightField.text = formatWeightForDisplay(weightValue)
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
        topDepthValue = ""
        bottomDepthValue = ""
        topTvdValue = ""
        bottomTvdValue = ""
        innerDiameterValue = ""
        outerDiameterValue = ""
        wallThicknessValue = ""
        roughnessValue = ""
        material = ""
        grade = ""
        weightValue = ""
        manufacturer = ""
        notes = ""

        // 更新界面显示
        updateFormUnits()
        updateCasingTypeIndex()
    }

    // 🔥 修改加载套管数据函数，确保正确的单位转换
    function loadCasingData(casing) {
        casingType = casing.casing_type || ""
        casingSize = casing.casing_size || ""

        // 🔥 加载深度数据 (假设数据库存储为ft)
        topDepthValue = parseFloat(casing.top_depth) || 0
        bottomDepthValue = parseFloat(casing.bottom_depth) || 0
        topTvdValue = parseFloat(casing.top_tvd) || 0
        bottomTvdValue = parseFloat(casing.bottom_tvd) || 0

        // 🔥 加载直径数据 (假设数据库存储为mm)
        innerDiameterValue = parseFloat(casing.inner_diameter) || 0
        outerDiameterValue = parseFloat(casing.outer_diameter) || 0
        wallThicknessValue = parseFloat(casing.wall_thickness) || 0

        roughnessValue = parseFloat(casing.roughness) || 0
        material = casing.material || ""
        grade = casing.grade || ""

        // 🔥 加载重量数据 (假设数据库存储为kg/m)
        weightValue = parseFloat(casing.weight) || 0

        manufacturer = casing.manufacturer || ""
        notes = casing.notes || ""

        // 更新界面显示
        updateFormUnits()
        updateCasingTypeIndex()
    }

    // 🔥 修改验证输入函数
    function validateInput() {
        return casingType.length > 0 &&
               topDepthValue > 0 &&
               bottomDepthValue > 0 &&
               innerDiameterValue > 0 &&
               outerDiameterValue > 0 &&
               topDepthValue < bottomDepthValue &&
               innerDiameterValue < outerDiameterValue
    }

    // 🔥 修改保存套管数据函数，确保以正确单位保存
    function saveCasingData() {
        var dataToSave = {
            well_id: wellId,
            casing_type: casingType,
            casing_size: casingSize || null,
            // 🔥 深度数据以英尺保存
            top_depth: topDepthValue,
            bottom_depth: bottomDepthValue,
            top_tvd: topTvdValue > 0 ? topTvdValue : null,
            bottom_tvd: bottomTvdValue > 0 ? bottomTvdValue : null,
            // 🔥 直径数据以毫米保存
            inner_diameter: innerDiameterValue,
            outer_diameter: outerDiameterValue,
            wall_thickness: wallThicknessValue > 0 ? wallThicknessValue : null,
            roughness: roughnessValue > 0 ? roughnessValue : null,
            material: material || null,
            grade: grade || null,
            // 🔥 重量数据以kg/m保存
            weight: weightValue > 0 ? weightValue : null,
            manufacturer: manufacturer || null,
            notes: notes || null
        }

        console.log("保存套管数据:", JSON.stringify(dataToSave, null, 2))

        if (!isNewCasing && editingCasing) {
            dataToSave.id = editingCasing.id
            wellStructureController.updateCasing(dataToSave)
        } else {
            wellStructureController.createCasing(dataToSave)
        }

        saved()
        accept()
    }

    // 🔥 添加调试函数
    function debugUnitConversion() {
        console.log("=== 套管编辑器单位转换调试 ===")
        console.log("当前单位制:", isMetric ? "公制" : "英制")
        console.log("深度单位:", getDepthUnit())
        console.log("直径单位:", getDiameterUnit())
        console.log("重量单位:", getWeightUnit())
        console.log("顶深 - 内部值:", topDepthValue, "ft, 显示值:", formatDepthForDisplay(topDepthValue))
        console.log("外径 - 内部值:", outerDiameterValue, "mm, 显示值:", formatDiameterForDisplay(outerDiameterValue))
        console.log("重量 - 内部值:", weightValue, "kg/m, 显示值:", formatWeightForDisplay(weightValue))
    }
}
