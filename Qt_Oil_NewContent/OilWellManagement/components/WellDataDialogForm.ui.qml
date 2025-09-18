// Qt_Oil_NewContent/OilWellManagement/components/WellDataDialogForm.ui.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: 600
    height: 500
    color: "#ffffff"

    // 🔥 添加单位制相关属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : true
    property bool isChinese: true

    // 🔥 保留井的基本信息属性
    property alias wellNameField: wellNameField
    property alias depthField: depthField
    property alias wellTypeCombo: wellTypeCombo
    property alias wellStatusCombo: wellStatusCombo
    property alias notesArea: notesArea

    // 🔥 新增项目信息属性
    property alias companyNameField: companyNameField
    property alias oilFieldNameField: oilFieldNameField
    property alias locationField: locationField

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            // 可以在这里触发数值转换
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 20

            // 🔥 项目基本信息组
            GroupBox {
                Layout.fillWidth: true
                title: isChinese ? "项目基本信息" : "Project Basic Information"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChinese ? "公司名称 *" : "Company Name *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: companyNameField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入公司名称" : "Enter company name"
                    }

                    Label {
                        text: isChinese ? "油田名称 *" : "Oil Field Name *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: oilFieldNameField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入油田名称" : "Enter oil field name"
                    }

                    Label {
                        text: isChinese ? "地点 *" : "Location *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: locationField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入地点信息" : "Enter location"
                    }
                }
            }

            // 🔥 保留井的基本信息组
            GroupBox {
                Layout.fillWidth: true
                title: isChinese ? "井基本信息" : "Well Basic Information"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChinese ? "井号 *" : "Well Name *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: wellNameField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入井号" : "Enter well name"
                    }

                    Label {
                        text: `${isChinese ? "井深" : "Depth"} (${getDepthUnit()}) *`
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: depthField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入井深" : "Enter depth"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: isChinese ? "井型" : "Well Type"
                        Layout.alignment: Qt.AlignRight
                    }

                    ComboBox {
                        id: wellTypeCombo
                        Layout.fillWidth: true
                        model: isChinese ? ["直井", "定向井", "水平井"] : ["Vertical", "Directional", "Horizontal"]
                    }

                    Label {
                        text: isChinese ? "井状态" : "Well Status"
                        Layout.alignment: Qt.AlignRight
                    }

                    ComboBox {
                        id: wellStatusCombo
                        Layout.fillWidth: true
                        model: isChinese ? ["生产", "关停", "维修"] : ["Production", "Shut-in", "Maintenance"]
                    }
                }
            }

            // 🔥 备注信息组
            GroupBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                title: isChinese ? "备注信息" : "Notes"

                ScrollView {
                    anchors.fill: parent

                    TextArea {
                        id: notesArea
                        placeholderText: isChinese ? "请输入备注信息..." : "Enter notes..."
                        wrapMode: TextArea.Wrap
                    }
                }
            }

            // 🔥 添加信息提示
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#f0f8ff"
                border.color: "#4682b4"
                border.width: 1
                radius: 5

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        width: 24
                        height: 24
                        color: "#4682b4"
                        radius: 12

                        Text {
                            anchors.centerIn: parent
                            text: "i"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: isChinese ? 
                              "项目信息将用于完善项目档案，井信息将创建新的井记录。标记 * 的字段为必填项。" : 
                              "Project information will be used to complete project records, and well information will create new well records. Fields marked with * are required."
                        color: "#2c3e50"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // 🔥 添加单位获取函数
    function getDepthUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("depth")
        }
        return isMetric ? "m" : "ft"
    }

    function getDiameterUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("diameter")
        }
        return isMetric ? "mm" : "in"
    }

    function getDepthUnitText() {
        if (unitSystemController) {
            return unitSystemController.getUnitDisplayText("depth", isChinese)
        }
        if (isMetric) {
            return isChinese ? "米" : "m"
        } else {
            return isChinese ? "英尺" : "ft"
        }
    }

    function getDiameterUnitText() {
        if (unitSystemController) {
            return unitSystemController.getUnitDisplayText("diameter", isChinese)
        }
        if (isMetric) {
            return isChinese ? "毫米" : "mm"
        } else {
            return isChinese ? "英寸" : "in"
        }
    }

    // 🔥 表单验证函数
    function validateForm() {
        var errors = []
        
        // 验证项目信息
        if (!companyNameField.text.trim()) {
            errors.push(isChinese ? "请输入公司名称" : "Company name is required")
        }
        
        if (!oilFieldNameField.text.trim()) {
            errors.push(isChinese ? "请输入油田名称" : "Oil field name is required")
        }
        
        if (!locationField.text.trim()) {
            errors.push(isChinese ? "请输入地点信息" : "Location is required")
        }

        // 验证井信息
        if (!wellNameField.text.trim()) {
            errors.push(isChinese ? "请输入井号" : "Well name is required")
        }
        
        if (!depthField.text.trim()) {
            errors.push(isChinese ? "请输入井深" : "Well depth is required")
        } else {
            var depth = parseFloat(depthField.text)
            if (isNaN(depth) || depth <= 0) {
                errors.push(isChinese ? "井深必须是大于0的数字" : "Well depth must be a number greater than 0")
            }
        }
        
        return {
            isValid: errors.length === 0,
            errors: errors
        }
    }

    // 🔥 获取项目数据
    function getProjectData() {
        return {
            company_name: companyNameField.text.trim(),
            oil_name: oilFieldNameField.text.trim(),
            location: locationField.text.trim(),
            ps: notesArea.text.trim()
        }
    }

    // 🔥 获取井数据
    function getWellData() {
        return {
            well_name: wellNameField.text.trim(),
            well_md: parseFloat(depthField.text) || 0,
            well_tvd: parseFloat(depthField.text) || 0, // 暂时使用相同值
            well_type: getWellTypeValue(),
            well_status: getWellStatusValue(),
            notes: notesArea.text.trim()
        }
    }

    // 🔥 获取完整表单数据
    function getFormData() {
        return {
            project: getProjectData(),
            well: getWellData()
        }
    }

    // 🔥 设置项目数据
    function setProjectData(data) {
        companyNameField.text = data.company_name || ""
        oilFieldNameField.text = data.oil_name || ""
        locationField.text = data.location || ""
        if (data.ps) {
            notesArea.text = data.ps
        }
    }

    // 🔥 设置井数据
    function setWellData(data) {
        wellNameField.text = data.well_name || ""
        depthField.text = data.well_md ? data.well_md.toString() : ""
        
        // 设置井型
        if (data.well_type) {
            setWellTypeValue(data.well_type)
        }
        
        // 设置井状态
        if (data.well_status) {
            setWellStatusValue(data.well_status)
        }
        
        if (data.notes && !notesArea.text) {
            notesArea.text = data.notes
        }
    }

    // 🔥 设置完整表单数据
    function setFormData(data) {
        if (data.project) {
            setProjectData(data.project)
        }
        if (data.well) {
            setWellData(data.well)
        }
    }

    // 🔥 清空表单
    function clearForm() {
        companyNameField.text = ""
        oilFieldNameField.text = ""
        locationField.text = ""
        wellNameField.text = ""
        depthField.text = ""
        wellTypeCombo.currentIndex = 0
        wellStatusCombo.currentIndex = 0
        notesArea.text = ""
    }

    // 🔥 井型值转换
    function getWellTypeValue() {
        var typeMap = {
            0: "vertical",
            1: "directional", 
            2: "horizontal"
        }
        return typeMap[wellTypeCombo.currentIndex] || "vertical"
    }

    function setWellTypeValue(type) {
        var indexMap = {
            "vertical": 0,
            "directional": 1,
            "horizontal": 2
        }
        wellTypeCombo.currentIndex = indexMap[type] || 0
    }

    // 🔥 井状态值转换
    function getWellStatusValue() {
        var statusMap = {
            0: "production",
            1: "shut-in",
            2: "maintenance"
        }
        return statusMap[wellStatusCombo.currentIndex] || "production"
    }

    function setWellStatusValue(status) {
        var indexMap = {
            "production": 0,
            "shut-in": 1,
            "maintenance": 2
        }
        wellStatusCombo.currentIndex = indexMap[status] || 0
    }

    // 🔥 设置焦点到第一个字段
    function focusFirstField() {
        companyNameField.forceActiveFocus()
    }
}