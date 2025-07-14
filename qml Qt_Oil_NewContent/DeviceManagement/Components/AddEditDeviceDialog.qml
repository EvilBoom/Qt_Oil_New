import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs

// 使用Item作为根元素，而不是直接使用Dialog
Item {
    id: rootItem
    
    // 暴露给外部的属性和信号
    property var deviceData: null  // null表示新建，否则为编辑
    property bool isChineseMode: true
    
    // 将formData属性移到根元素上
    property var formData: ({})
    
    // 添加必要的信号
    signal accepted()
    signal rejected()
    
    // 添加公共方法
    function open() {
        dialog.open()
    }
    
    function close() {
        dialog.close()
    }
    
    // 实际的Dialog组件作为子元素
    Dialog {
        id: dialog
        parent: rootItem.parent
        
        // 居中显示
        anchors.centerIn: parent
        
        title: deviceData ?
               (isChineseMode ? "编辑设备" : "Edit Device") :
               (isChineseMode ? "添加设备" : "Add Device")
        
        width: 800
        height: 600
        modal: true
        
        // 当对话框打开时
        onOpened: {
            // 初始化表单数据
            if (deviceData) {
                rootItem.formData = JSON.parse(JSON.stringify(deviceData))  // 深拷贝
                selectedType = deviceData.device_type
            } else {
                rootItem.formData = {
                    device_type: "pump",
                    manufacturer: "",
                    model: "",
                    serial_number: "",
                    status: "active",
                    description: ""
                }
            }
            updateFormFields()
        }
        
        contentItem: ColumnLayout {
            spacing: 20
            
            // 设备类型选择（新建时可选）
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "设备类型" : "Device Type"
                enabled: !deviceData  // 编辑时不可改变类型
                
                RowLayout {
                    spacing: 20
                    
                    RadioButton {
                        text: isChineseMode ? "潜油离心泵" : "Centrifugal Pump"
                        checked: selectedType === "pump"
                        onCheckedChanged: if (checked) {
                            selectedType = "pump"
                            rootItem.formData.device_type = "pump"
                            updateFormFields()
                        }
                    }
                    
                    RadioButton {
                        text: isChineseMode ? "电机" : "Motor"
                        checked: selectedType === "motor"
                        onCheckedChanged: if (checked) {
                            selectedType = "motor"
                            rootItem.formData.device_type = "motor"
                            updateFormFields()
                        }
                    }
                    
                    RadioButton {
                        text: isChineseMode ? "保护器" : "Protector"
                        checked: selectedType === "protector"
                        onCheckedChanged: if (checked) {
                            selectedType = "protector"
                            rootItem.formData.device_type = "protector"
                            updateFormFields()
                        }
                    }
                    
                    RadioButton {
                        text: isChineseMode ? "分离器" : "Separator"
                        checked: selectedType === "separator"
                        onCheckedChanged: if (checked) {
                            selectedType = "separator"
                            rootItem.formData.device_type = "separator"
                            updateFormFields()
                        }
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
                    rowSpacing: 15
                    anchors.fill: parent
                    
                    // 制造商
                    Label {
                        text: isChineseMode ? "制造商：" : "Manufacturer:"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: manufacturerField
                        Layout.fillWidth: true
                        placeholderText: isChineseMode ? "请输入制造商" : "Enter manufacturer"
                        text: rootItem.formData.manufacturer || ""
                        onTextChanged: rootItem.formData.manufacturer = text
                    }
                    
                    // 型号
                    Label {
                        text: isChineseMode ? "型号：" : "Model:"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: modelField
                        Layout.fillWidth: true
                        placeholderText: isChineseMode ? "请输入型号" : "Enter model"
                        text: rootItem.formData.model || ""
                        onTextChanged: rootItem.formData.model = text
                    }
                    
                    // 序列号
                    Label {
                        text: isChineseMode ? "序列号：" : "Serial Number:"
                        Layout.alignment: Qt.AlignRight
                    }
                    TextField {
                        id: serialNumberField
                        Layout.fillWidth: true
                        placeholderText: isChineseMode ? "请输入序列号" : "Enter serial number"
                        text: rootItem.formData.serial_number || ""
                        onTextChanged: rootItem.formData.serial_number = text
                    }
                    
                    // 状态
                    Label {
                        text: isChineseMode ? "状态：" : "Status:"
                        Layout.alignment: Qt.AlignRight
                    }
                    ComboBox {
                        id: statusCombo
                        Layout.fillWidth: true
                        model: ListModel {
                            ListElement { value: "active"; label: "正常"; label_en: "Active" }
                            ListElement { value: "inactive"; label: "停用"; label_en: "Inactive" }
                            ListElement { value: "maintenance"; label: "维护中"; label_en: "Maintenance" }
                        }
                        textRole: isChineseMode ? "label" : "label_en"
                        valueRole: "value"
                        currentIndex: {
                            switch(rootItem.formData.status) {
                                case "active": return 0
                                case "inactive": return 1
                                case "maintenance": return 2
                                default: return 0
                            }
                        }
                        onCurrentValueChanged: rootItem.formData.status = currentValue
                    }
                    
                    // 描述
                    Label {
                        text: isChineseMode ? "描述：" : "Description:"
                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        TextArea {
                            id: descriptionField
                            placeholderText: isChineseMode ? "请输入设备描述" : "Enter device description"
                            text: rootItem.formData.description || ""
                            wrapMode: TextArea.Wrap
                            onTextChanged: rootItem.formData.description = text
                        }
                    }
                }
            }
            
            // 技术参数（根据设备类型动态加载）
            GroupBox {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: isChineseMode ? "技术参数" : "Technical Parameters"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    Loader {
                        id: parametersLoader
                        width: parent.width
                        sourceComponent: {
                            switch(selectedType) {
                                case "pump": return pumpParametersComponent
                                case "motor": return motorParametersComponent
                                case "protector": return protectorParametersComponent
                                case "separator": return separatorParametersComponent
                                default: return null
                            }
                        }
                    }
                }
            }
        }
        
        standardButtons: Dialog.Ok | Dialog.Cancel
        
        onAccepted: {
            // 验证必填字段
            if (!rootItem.formData.model || rootItem.formData.model.trim() === "") {
                // errorDialog.show(isChineseMode ? "请输入设备型号" : "Please enter device model")
                return
            }
            
            // 将对话框的接受信号向上转发
            rootItem.accepted()
        }
        
        onRejected: {
            // 将对话框的拒绝信号向上转发
            rootItem.rejected()
        }
    }
    
    // 内部状态
    property string selectedType: deviceData ? deviceData.device_type : "pump"
    
    // 潜油离心泵参数组件
    Component {
        id: pumpParametersComponent
        
        GridLayout {
            columns: 2
            columnSpacing: 20
            rowSpacing: 15
            
            property var details: rootItem.formData.pump_details || {}
            
            Component.onCompleted: {
                if (!rootItem.formData.pump_details) {
                    rootItem.formData.pump_details = {}
                }
            }
            
            // 叶轮型号
            Label {
                text: isChineseMode ? "叶轮型号：" : "Impeller Model:"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.impeller_model || ""
                onTextChanged: rootItem.formData.pump_details.impeller_model = text
            }
            
            // 最小排量
            Label {
                text: isChineseMode ? "最小排量 (m³/d)：" : "Min Displacement (m³/d):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.displacement_min || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.pump_details.displacement_min = parseFloat(text) || 0
            }
            
            // 最大排量
            Label {
                text: isChineseMode ? "最大排量 (m³/d)：" : "Max Displacement (m³/d):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.displacement_max || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.pump_details.displacement_max = parseFloat(text) || 0
            }
            
            // 单级扬程
            Label {
                text: isChineseMode ? "单级扬程 (m)：" : "Single Stage Head (m):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.single_stage_head || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.pump_details.single_stage_head = parseFloat(text) || 0
            }
            
            // 单级功率
            Label {
                text: isChineseMode ? "单级功率 (kW)：" : "Single Stage Power (kW):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.single_stage_power || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.pump_details.single_stage_power = parseFloat(text) || 0
            }
        }
    }
    
    // 电机参数组件
    Component {
        id: motorParametersComponent
        
        ColumnLayout {
            spacing: 20
            
            property var details: rootItem.formData.motor_details || {}
            
            Component.onCompleted: {
                if (!rootItem.formData.motor_details) {
                    rootItem.formData.motor_details = {
                        frequency_params: []
                    }
                }
            }
            
            GridLayout {
                columns: 2
                columnSpacing: 20
                rowSpacing: 15
                
                // 电机类型
                Label {
                    text: isChineseMode ? "电机类型：" : "Motor Type:"
                    Layout.alignment: Qt.AlignRight
                }
                TextField {
                    Layout.fillWidth: true
                    text: details.motor_type || ""
                    onTextChanged: rootItem.formData.motor_details.motor_type = text
                }
                
                // 外径
                Label {
                    text: isChineseMode ? "外径 (mm)：" : "Outside Diameter (mm):"
                    Layout.alignment: Qt.AlignRight
                }
                TextField {
                    Layout.fillWidth: true
                    text: details.outside_diameter || ""
                    validator: DoubleValidator { bottom: 0 }
                    onTextChanged: rootItem.formData.motor_details.outside_diameter = parseFloat(text) || 0
                }
                
                // 长度
                Label {
                    text: isChineseMode ? "长度 (mm)：" : "Length (mm):"
                    Layout.alignment: Qt.AlignRight
                }
                TextField {
                    Layout.fillWidth: true
                    text: details.length || ""
                    validator: DoubleValidator { bottom: 0 }
                    onTextChanged: rootItem.formData.motor_details.length = parseFloat(text) || 0
                }
            }
            
            // 频率参数
            GroupBox {
                Layout.fillWidth: true
                title: isChineseMode ? "频率参数" : "Frequency Parameters"
                
                ColumnLayout {
                    spacing: 10
                    
                    // 50Hz参数
                    Rectangle {
                        Layout.fillWidth: true
                        height: hz50Grid.height + 20
                        color: "#f8f9fa"
                        radius: 4
                        
                        GridLayout {
                            id: hz50Grid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            columns: 4
                            columnSpacing: 15
                            rowSpacing: 10
                            
                            Label {
                                text: "50Hz"
                                font.bold: true
                                Layout.columnSpan: 4
                            }
                            
                            Label { text: isChineseMode ? "功率(kW):" : "Power(kW):" }
                            TextField {
                                Layout.fillWidth: true
                                validator: DoubleValidator { bottom: 0 }
                                onTextChanged: updateFrequencyParam(50, "power", parseFloat(text))
                            }
                            
                            Label { text: isChineseMode ? "电压(V):" : "Voltage(V):" }
                            TextField {
                                Layout.fillWidth: true
                                validator: DoubleValidator { bottom: 0 }
                                onTextChanged: updateFrequencyParam(50, "voltage", parseFloat(text))
                            }
                        }
                    }
                    
                    // 60Hz参数
                    Rectangle {
                        Layout.fillWidth: true
                        height: hz60Grid.height + 20
                        color: "#f8f9fa"
                        radius: 4
                        
                        GridLayout {
                            id: hz60Grid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            columns: 4
                            columnSpacing: 15
                            rowSpacing: 10
                            
                            Label {
                                text: "60Hz"
                                font.bold: true
                                Layout.columnSpan: 4
                            }
                            
                            Label { text: isChineseMode ? "功率(kW):" : "Power(kW):" }
                            TextField {
                                Layout.fillWidth: true
                                validator: DoubleValidator { bottom: 0 }
                                onTextChanged: updateFrequencyParam(60, "power", parseFloat(text))
                            }
                            
                            Label { text: isChineseMode ? "电压(V):" : "Voltage(V):" }
                            TextField {
                                Layout.fillWidth: true
                                validator: DoubleValidator { bottom: 0 }
                                onTextChanged: updateFrequencyParam(60, "voltage", parseFloat(text))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 保护器参数组件
    Component {
        id: protectorParametersComponent
        
        GridLayout {
            columns: 2
            columnSpacing: 20
            rowSpacing: 15
            
            property var details: rootItem.formData.protector_details || {}
            
            Component.onCompleted: {
                if (!rootItem.formData.protector_details) {
                    rootItem.formData.protector_details = {}
                }
            }
            
            // 外径
            Label {
                text: isChineseMode ? "外径 (mm)：" : "Outer Diameter (mm):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.outer_diameter || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.protector_details.outer_diameter = parseFloat(text) || 0
            }
            
            // 推力承载能力
            Label {
                text: isChineseMode ? "推力承载 (kN)：" : "Thrust Capacity (kN):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.thrust_capacity || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.protector_details.thrust_capacity = parseFloat(text) || 0
            }
            
            // 密封类型
            Label {
                text: isChineseMode ? "密封类型：" : "Seal Type:"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.seal_type || ""
                onTextChanged: rootItem.formData.protector_details.seal_type = text
            }
        }
    }
    
    // 分离器参数组件
    Component {
        id: separatorParametersComponent
        
        GridLayout {
            columns: 2
            columnSpacing: 20
            rowSpacing: 15
            
            property var details: rootItem.formData.separator_details || {}
            
            Component.onCompleted: {
                if (!rootItem.formData.separator_details) {
                    rootItem.formData.separator_details = {}
                }
            }
            
            // 分离效率
            Label {
                text: isChineseMode ? "分离效率 (%)：" : "Separation Efficiency (%):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.separation_efficiency || ""
                validator: DoubleValidator { bottom: 0; top: 100 }
                onTextChanged: rootItem.formData.separator_details.separation_efficiency = parseFloat(text) || 0
            }
            
            // 气体处理能力
            Label {
                text: isChineseMode ? "气体处理能力 (m³/d)：" : "Gas Handling (m³/d):"
                Layout.alignment: Qt.AlignRight
            }
            TextField {
                Layout.fillWidth: true
                text: details.gas_handling_capacity || ""
                validator: DoubleValidator { bottom: 0 }
                onTextChanged: rootItem.formData.separator_details.gas_handling_capacity = parseFloat(text) || 0
            }
        }
    }
    
    // 辅助函数
    function updateFormFields() {
        // 根据设备类型初始化相应的详情字段
        switch(selectedType) {
            case "pump":
                if (!rootItem.formData.pump_details) rootItem.formData.pump_details = {}
                break
            case "motor":
                if (!rootItem.formData.motor_details) rootItem.formData.motor_details = { frequency_params: [] }
                break
            case "protector":
                if (!rootItem.formData.protector_details) rootItem.formData.protector_details = {}
                break
            case "separator":
                if (!rootItem.formData.separator_details) rootItem.formData.separator_details = {}
                break
        }
    }
    
    function updateFrequencyParam(frequency, field, value) {
        if (!rootItem.formData.motor_details.frequency_params) {
            rootItem.formData.motor_details.frequency_params = []
        }
        
        var param = rootItem.formData.motor_details.frequency_params.find(p => p.frequency === frequency)
        if (!param) {
            param = { frequency: frequency }
            rootItem.formData.motor_details.frequency_params.push(param)
        }
        
        param[field] = value
    }
}