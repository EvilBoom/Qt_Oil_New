import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    // 公共属性
    property var deviceData: null
    property bool isChineseMode: true
    property string formDataJson: ""

    // 表单数据
    property string deviceType: "pump"
    property string manufacturer: ""
    property string model: ""
    property string serialNumber: ""
    property string status: "active"
    property string description: ""

    // 泵参数
    property string impellerModel: ""
    property real displacementMin: 0
    property real displacementMax: 0
    property real singleStageHead: 0
    property real singleStagePower: 0

    // 电机参数
    property string motorType: ""
    property real outsideDiameter: 0
    property real motorLength: 0
    property real hz50Power: 0
    property real hz50Voltage: 0
    property real hz60Power: 0
    property real hz60Voltage: 0

    // 保护器参数
    property real outerDiameter: 0
    property real thrustCapacity: 0
    property string sealType: ""

    // 分离器参数
    property real separationEfficiency: 0
    property real gasHandlingCapacity: 0

    // 对话框属性
    title: deviceData ?
           (isChineseMode ? "编辑设备" : "Edit Device") :
           (isChineseMode ? "添加设备" : "Add Device")

    width: 800
    height: 600
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel

    // 信号处理程序
    onAccepted: {
        if (!root.model || root.model.trim() === "") {
            console.log(root.isChineseMode ? "请输入设备型号" : "Please enter device model")
            root.open()
            return
        }

        root.formDataJson = createJsonData()
    }

    // 初始化数据
    Component.onCompleted: {
        if (deviceData) {
            loadDeviceData()
        }
    }

    // 主内容
    contentItem: ColumnLayout {
        spacing: 10

        // 设备类型选择
        GroupBox {
            Layout.fillWidth: true
            title: isChineseMode ? "设备类型" : "Device Type"
            enabled: !deviceData

            RowLayout {
                spacing: 20

                RadioButton {
                    text: isChineseMode ? "潜油离心泵" : "Centrifugal Pump"
                    checked: deviceType === "pump"
                    onCheckedChanged: if (checked) deviceType = "pump"
                }

                RadioButton {
                    text: isChineseMode ? "电机" : "Motor"
                    checked: deviceType === "motor"
                    onCheckedChanged: if (checked) deviceType = "motor"
                }

                RadioButton {
                    text: isChineseMode ? "保护器" : "Protector"
                    checked: deviceType === "protector"
                    onCheckedChanged: if (checked) deviceType = "protector"
                }

                RadioButton {
                    text: isChineseMode ? "分离器" : "Separator"
                    checked: deviceType === "separator"
                    onCheckedChanged: if (checked) deviceType = "separator"
                }
            }
        }

        // 基本信息
        GroupBox {
            Layout.fillWidth: true
            title: isChineseMode ? "基本信息" : "Basic Information"

            GridLayout {
                columns: 2
                columnSpacing: 20
                rowSpacing: 10
                anchors.fill: parent

                Label {
                    text: isChineseMode ? "制造商：" : "Manufacturer:"
                    Layout.alignment: Qt.AlignRight
                }
                TextField {
                    Layout.fillWidth: true
                    placeholderText: isChineseMode ? "请输入制造商" : "Enter manufacturer"
                    text: manufacturer
                    onTextChanged: manufacturer = text
                }

                Label {
                    text: isChineseMode ? "型号：" : "Model:"
                    Layout.alignment: Qt.AlignRight
                }
                TextField {
                    Layout.fillWidth: true
                    placeholderText: isChineseMode ? "请输入型号" : "Enter model"
                    text: model
                    onTextChanged: model = text
                }

                Label {
                    text: isChineseMode ? "序列号：" : "Serial Number:"
                    Layout.alignment: Qt.AlignRight
                }
                TextField {
                    Layout.fillWidth: true
                    placeholderText: isChineseMode ? "请输入序列号" : "Enter serial number"
                    text: serialNumber
                    onTextChanged: serialNumber = text
                }

                Label {
                    text: isChineseMode ? "状态：" : "Status:"
                    Layout.alignment: Qt.AlignRight
                }
                ComboBox {
                    Layout.fillWidth: true
                    model: ListModel {
                        ListElement { value: "active"; label: "正常"; labelEn: "Active" }
                        ListElement { value: "inactive"; label: "停用"; labelEn: "Inactive" }
                        ListElement { value: "maintenance"; label: "维护中"; labelEn: "Maintenance" }
                    }
                    textRole: isChineseMode ? "label" : "labelEn"
                    currentIndex: {
                        switch(status) {
                            case "active": return 0
                            case "inactive": return 1
                            case "maintenance": return 2
                            default: return 0
                        }
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && currentIndex < model.count) {
                            status = model.get(currentIndex).value
                        }
                    }
                }

                Label {
                    text: isChineseMode ? "描述：" : "Description:"
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    TextArea {
                        placeholderText: isChineseMode ? "请输入设备描述" : "Enter device description"
                        text: description
                        wrapMode: TextArea.Wrap
                        onTextChanged: description = text
                    }
                }
            }
        }

        // 技术参数
        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: isChineseMode ? "技术参数" : "Technical Parameters"

            ScrollView {
                anchors.fill: parent
                clip: true

                ColumnLayout {
                    id: paramContent
                    width: parent.parent.width
                    spacing: 10

                    // 泵参数
                    GridLayout {
                        visible: deviceType === "pump"
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 10
                        Layout.fillWidth: true

                        Label {
                            text: isChineseMode ? "叶轮型号：" : "Impeller Model:"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: impellerModel
                            onTextChanged: impellerModel = text
                        }

                        Label {
                            text: isChineseMode ? "最小排量 (m³/d)：" : "Min Displacement (m³/d):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: displacementMin > 0 ? displacementMin.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: displacementMin = parseFloat(text) || 0
                        }

                        Label {
                            text: isChineseMode ? "最大排量 (m³/d)：" : "Max Displacement (m³/d):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: displacementMax > 0 ? displacementMax.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: displacementMax = parseFloat(text) || 0
                        }

                        Label {
                            text: isChineseMode ? "单级扬程 (m)：" : "Single Stage Head (m):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: singleStageHead > 0 ? singleStageHead.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: singleStageHead = parseFloat(text) || 0
                        }

                        Label {
                            text: isChineseMode ? "单级功率 (kW)：" : "Single Stage Power (kW):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: singleStagePower > 0 ? singleStagePower.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: singleStagePower = parseFloat(text) || 0
                        }
                    }

                    // 电机参数
                    ColumnLayout {
                        visible: deviceType === "motor"
                        spacing: 10
                        Layout.fillWidth: true

                        GridLayout {
                            columns: 2
                            columnSpacing: 20
                            rowSpacing: 10
                            Layout.fillWidth: true

                            Label {
                                text: isChineseMode ? "电机类型：" : "Motor Type:"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: motorType
                                onTextChanged: motorType = text
                            }

                            Label {
                                text: isChineseMode ? "外径 (mm)：" : "Outside Diameter (mm):"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: outsideDiameter > 0 ? outsideDiameter.toString() : ""
                                validator: DoubleValidator { bottom: 0 }
                                onTextChanged: outsideDiameter = parseFloat(text) || 0
                            }

                            Label {
                                text: isChineseMode ? "长度 (mm)：" : "Length (mm):"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: motorLength > 0 ? motorLength.toString() : ""
                                validator: DoubleValidator { bottom: 0 }
                                onTextChanged: motorLength = parseFloat(text) || 0
                            }
                        }

                        GroupBox {
                            title: isChineseMode ? "频率参数" : "Frequency Parameters"
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 10
                                anchors.fill: parent

                                // 50Hz
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    color: "#f0f0f0"
                                    radius: 4

                                    GridLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        columns: 4

                                        Label {
                                            text: "50Hz"
                                            font.bold: true
                                        }

                                        Label { text: isChineseMode ? "功率(kW):" : "Power(kW):" }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: hz50Power > 0 ? hz50Power.toString() : ""
                                            validator: DoubleValidator { bottom: 0 }
                                            onTextChanged: hz50Power = parseFloat(text) || 0
                                        }

                                        Label { text: isChineseMode ? "电压(V):" : "Voltage(V):" }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: hz50Voltage > 0 ? hz50Voltage.toString() : ""
                                            validator: DoubleValidator { bottom: 0 }
                                            onTextChanged: hz50Voltage = parseFloat(text) || 0
                                        }
                                    }
                                }

                                // 60Hz
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 80
                                    color: "#f0f0f0"
                                    radius: 4

                                    GridLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        columns: 4

                                        Label {
                                            text: "60Hz"
                                            font.bold: true
                                        }

                                        Label { text: isChineseMode ? "功率(kW):" : "Power(kW):" }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: hz60Power > 0 ? hz60Power.toString() : ""
                                            validator: DoubleValidator { bottom: 0 }
                                            onTextChanged: hz60Power = parseFloat(text) || 0
                                        }

                                        Label { text: isChineseMode ? "电压(V):" : "Voltage(V):" }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: hz60Voltage > 0 ? hz60Voltage.toString() : ""
                                            validator: DoubleValidator { bottom: 0 }
                                            onTextChanged: hz60Voltage = parseFloat(text) || 0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 保护器参数
                    GridLayout {
                        visible: deviceType === "protector"
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 10
                        Layout.fillWidth: true

                        Label {
                            text: isChineseMode ? "外径 (mm)：" : "Outer Diameter (mm):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: outerDiameter > 0 ? outerDiameter.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: outerDiameter = parseFloat(text) || 0
                        }

                        Label {
                            text: isChineseMode ? "推力承载 (kN)：" : "Thrust Capacity (kN):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: thrustCapacity > 0 ? thrustCapacity.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: thrustCapacity = parseFloat(text) || 0
                        }

                        Label {
                            text: isChineseMode ? "密封类型：" : "Seal Type:"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: sealType
                            onTextChanged: sealType = text
                        }
                    }

                    // 分离器参数
                    GridLayout {
                        visible: deviceType === "separator"
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 10
                        Layout.fillWidth: true

                        Label {
                            text: isChineseMode ? "分离效率 (%)：" : "Separation Efficiency (%):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: separationEfficiency > 0 ? separationEfficiency.toString() : ""
                            validator: DoubleValidator { bottom: 0; top: 100 }
                            onTextChanged: separationEfficiency = parseFloat(text) || 0
                        }

                        Label {
                            text: isChineseMode ? "气体处理能力 (m³/d)：" : "Gas Handling (m³/d):"
                            Layout.alignment: Qt.AlignRight
                        }
                        TextField {
                            Layout.fillWidth: true
                            text: gasHandlingCapacity > 0 ? gasHandlingCapacity.toString() : ""
                            validator: DoubleValidator { bottom: 0 }
                            onTextChanged: gasHandlingCapacity = parseFloat(text) || 0
                        }
                    }
                }
            }
        }
    } // contentItem 结束

    // 辅助函数
    function loadDeviceData() {
        if (!deviceData) return

        deviceType = deviceData.device_type || "pump"
        manufacturer = deviceData.manufacturer || ""
        model = deviceData.model || ""
        serialNumber = deviceData.serial_number || ""
        status = deviceData.status || "active"
        description = deviceData.description || ""

        if (deviceData.pump_details) {
            impellerModel = deviceData.pump_details.impeller_model || ""
            displacementMin = deviceData.pump_details.displacement_min || 0
            displacementMax = deviceData.pump_details.displacement_max || 0
            singleStageHead = deviceData.pump_details.single_stage_head || 0
            singleStagePower = deviceData.pump_details.single_stage_power || 0
        }

        if (deviceData.motor_details) {
            motorType = deviceData.motor_details.motor_type || ""
            outsideDiameter = deviceData.motor_details.outside_diameter || 0
            motorLength = deviceData.motor_details.length || 0

            if (deviceData.motor_details.frequency_params) {
                deviceData.motor_details.frequency_params.forEach(function(param) {
                    if (param.frequency === 50) {
                        hz50Power = param.power || 0
                        hz50Voltage = param.voltage || 0
                    } else if (param.frequency === 60) {
                        hz60Power = param.power || 0
                        hz60Voltage = param.voltage || 0
                    }
                })
            }
        }

        if (deviceData.protector_details) {
            outerDiameter = deviceData.protector_details.outer_diameter || 0
            thrustCapacity = deviceData.protector_details.thrust_capacity || 0
            sealType = deviceData.protector_details.seal_type || ""
        }

        if (deviceData.separator_details) {
            separationEfficiency = deviceData.separator_details.separation_efficiency || 0
            gasHandlingCapacity = deviceData.separator_details.gas_handling_capacity || 0
        }
    }

    // 监听 deviceData 变化
    onDeviceDataChanged: {
        if (deviceData) {
            loadDeviceData()
        } else {
            resetForm()
        }
    }
    // 对话框打开时加载数据
    onOpened: {
        if (deviceData) {
            loadDeviceData()
        }
    }


    function createJsonData() {
        var data = {
            id: deviceData ? deviceData.id : -1,
            device_type: deviceType,
            manufacturer: manufacturer,
            model: model,
            serial_number: serialNumber,
            status: status,
            description: description
        }

        switch(deviceType) {
            case "pump":
                data.pump_details = {
                    impeller_model: impellerModel,
                    displacement_min: displacementMin,
                    displacement_max: displacementMax,
                    single_stage_head: singleStageHead,
                    single_stage_power: singleStagePower
                }
                break

            case "motor":
                data.motor_details = {
                    motor_type: motorType,
                    outside_diameter: outsideDiameter,
                    length: motorLength,
                    frequency_params: []
                }

                if (hz50Power > 0 || hz50Voltage > 0) {
                    data.motor_details.frequency_params.push({
                        frequency: 50,
                        power: hz50Power,
                        voltage: hz50Voltage
                    })
                }

                if (hz60Power > 0 || hz60Voltage > 0) {
                    data.motor_details.frequency_params.push({
                        frequency: 60,
                        power: hz60Power,
                        voltage: hz60Voltage
                    })
                }
                break

            case "protector":
                data.protector_details = {
                    outer_diameter: outerDiameter,
                    thrust_capacity: thrustCapacity,
                    seal_type: sealType
                }
                break

            case "separator":
                data.separator_details = {
                    separation_efficiency: separationEfficiency,
                    gas_handling_capacity: gasHandlingCapacity
                }
                break
        }

        return JSON.stringify(data)
    }

    function resetForm() {
        deviceType = "pump"
        manufacturer = ""
        model = ""
        serialNumber = ""
        status = "active"
        description = ""
        
        // 重置泵参数
        impellerModel = ""
        displacementMin = 0
        displacementMax = 0
        singleStageHead = 0
        singleStagePower = 0
        
        // 重置电机参数
        motorType = ""
        outsideDiameter = 0
        motorLength = 0
        hz50Power = 0
        hz50Voltage = 0
        hz60Power = 0
        hz60Voltage = 0
        
        // 重置保护器参数
        outerDiameter = 0
        thrustCapacity = 0
        sealType = ""
        
        // 重置分离器参数
        separationEfficiency = 0
        gasHandlingCapacity = 0
    }
}
