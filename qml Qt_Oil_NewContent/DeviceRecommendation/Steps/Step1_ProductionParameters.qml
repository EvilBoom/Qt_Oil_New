// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step1_ProductionParameters.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../Components" as LocalComponents

Rectangle {
    id: root
    
    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})
    // 添加新属性
    property bool parametersValid: false
    
    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)
    
    // 内部属性
    property bool hasExistingParams: false
    property int currentParamsId: -1
    property bool isModified: false
    property var parametersHistory: []
    
    color: "transparent"
    
    // 参数定义
    property var parameterDefinitions: [
        {
            group: isChineseMode ? "压力参数" : "Pressure Parameters",
            params: [
                {
                    key: "geoPressure",
                    label: isChineseMode ? "地层压力" : "Geo Pressure",
                    unit: "psi",
                    placeholder: "例如: 1715",
                    tooltip: isChineseMode ? "储层的原始地层压力" : "Original reservoir pressure",
                    required: true,
                    min: 0,
                    max: 10000
                },
                {
                    key: "saturationPressure",
                    label: isChineseMode ? "饱和压力" : "Saturation Pressure",
                    unit: "psi",
                    placeholder: "例如: 850",
                    tooltip: isChineseMode ? "泡点压力，原油开始脱气的压力" : "Bubble point pressure",
                    required: false,
                    min: 0,
                    max: 10000
                },
                {
                    key: "wellHeadPressure",
                    label: isChineseMode ? "井口压力" : "Well Head Pressure",
                    unit: "psi",
                    placeholder: "例如: 350",
                    tooltip: isChineseMode ? "井口回压" : "Well head back pressure",
                    required: true,
                    min: 0,
                    max: 5000
                }
            ]
        },
        {
            group: isChineseMode ? "生产参数" : "Production Parameters",
            params: [
                {
                    key: "expectedProduction",
                    label: isChineseMode ? "期望产量" : "Expected Production",
                    unit: "bbl/d",
                    placeholder: "例如: 0.185",
                    tooltip: isChineseMode ? "期望的日产液量" : "Expected daily production rate",
                    required: true,
                    min: 0,
                    max: 10000
                },
                {
                    key: "produceIndex",
                    label: isChineseMode ? "生产指数" : "Production Index",
                    unit: "bbl/d/psi",
                    placeholder: "例如: 0.5",
                    tooltip: isChineseMode ? "单位压差下的产量" : "Production per unit pressure drawdown",
                    required: true,
                    min: 0,
                    max: 100
                },
                {
                    key: "bsw",
                    label: isChineseMode ? "含水率" : "Water Cut",
                    unit: "%",
                    placeholder: "例如: 3",
                    tooltip: isChineseMode ? "产出液中水的体积百分比" : "Water volume percentage in produced fluid",
                    required: true,
                    min: 0,
                    max: 100,
                    isPercentage: true
                }
            ]
        },
        {
            group: isChineseMode ? "流体性质" : "Fluid Properties",
            params: [
                {
                    key: "bht",
                    label: isChineseMode ? "井底温度" : "Bottom Hole Temperature",
                    unit: "°F",
                    placeholder: "例如: 235",
                    tooltip: isChineseMode ? "井底流体温度" : "Temperature at bottom hole",
                    required: true,
                    min: 32,
                    max: 500
                },
                {
                    key: "api",
                    label: isChineseMode ? "原油API重度" : "Oil API Gravity",
                    unit: "°API",
                    placeholder: "例如: 19.4",
                    tooltip: isChineseMode ? "原油的API重度" : "API gravity of crude oil",
                    required: true,
                    min: 0,
                    max: 100
                },
                {
                    key: "gasOilRatio",
                    label: isChineseMode ? "油气比" : "Gas Oil Ratio",
                    unit: "scf/bbl",
                    placeholder: "例如: 900",
                    tooltip: isChineseMode ? "溶解气油比" : "Solution gas oil ratio",
                    required: true,
                    min: 0,
                    max: 10000
                }
            ]
        }
    ]
    
    // 参数数据模型
    property var parametersData: ({
        geoPressure: "",
        expectedProduction: "",
        saturationPressure: "",
        produceIndex: "",
        bht: "",
        bsw: "",
        api: "",
        gasOilRatio: "",
        wellHeadPressure: "",
        parameterName: "",
        description: ""
    })
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        
        // 标题栏
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: isChineseMode ? "生产参数录入" : "Production Parameters Input"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }
            
            Item { Layout.fillWidth: true }
            
            // 历史版本按钮
            Button {
                text: isChineseMode ? "历史版本" : "History"
                flat: true
                onClicked: showHistoryDialog()
            }
            
            // 单位转换按钮
            Button {
                text: isChineseMode ? "单位转换" : "Unit Conversion"
                flat: true
                onClicked: showUnitConversionDialog()
            }
        }
        
        // 参数名称和描述
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: nameColumn.height + 24
            color: Material.dialogColor
            radius: 8
            
            Column {
                id: nameColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12
                
                RowLayout {
                    width: parent.width
                    
                    Text {
                        text: isChineseMode ? "参数集名称：" : "Parameter Set Name:"
                        color: Material.primaryTextColor
                        font.pixelSize: 14
                    }
                    
                    TextField {
                        id: parameterNameField
                        Layout.fillWidth: true
                        placeholderText: isChineseMode ? "输入参数集名称（可选）" : "Enter parameter set name (optional)"
                        text: parametersData.parameterName
                        onTextChanged: {
                            parametersData.parameterName = text
                            isModified = true
                        }
                    }
                }
                
                RowLayout {
                    width: parent.width
                    
                    Text {
                        text: isChineseMode ? "备注说明：" : "Description:"
                        color: Material.primaryTextColor
                        font.pixelSize: 14
                    }
                    
                    TextField {
                        id: descriptionField
                        Layout.fillWidth: true
                        placeholderText: isChineseMode ? "输入备注信息（可选）" : "Enter description (optional)"
                        text: parametersData.description
                        onTextChanged: {
                            parametersData.description = text
                            isModified = true
                        }
                    }
                }
            }
        }
        
        // 参数输入区域
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            Column {
                width: parent.width
                spacing: 24
                
                // 历史数据显示区域
                Rectangle {
                    width: parent.width
                    height: parametersHistory.length > 0 ? (historyContent.height + 24) : 0
                    color: Material.dialogColor
                    radius: 8
                    visible: parametersHistory.length > 0
                    
                    Column {
                        id: historyContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 12
                        
                        Text {
                            text: isChineseMode ? "📜 历史参数版本" : "📜 Historical Parameter Versions"
                            font.pixelSize: 16
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                        
                        // 历史版本列表
                        Repeater {
                            model: parametersHistory
                            
                            Rectangle {
                                width: parent.width
                                height: 60
                                color: index % 2 === 0 ? "transparent" : Material.backgroundColor
                                radius: 4
                                border.width: 1
                                border.color: Material.dividerColor
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 16
                                    
                                    // 版本信息
                                    Column {
                                        Layout.preferredWidth: 120
                                        Text {
                                            text: modelData.parameter_name || ("参数集 " + modelData.id)
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        Text {
                                            text: modelData.created_at || ""
                                            font.pixelSize: 11
                                            color: Material.hintTextColor
                                        }
                                    }
                                    
                                    // 关键参数预览
                                    Grid {
                                        Layout.fillWidth: true
                                        columns: 3
                                        spacing: 8
                                        
                                        Text {
                                            text: "地层压力: " + (modelData.geo_pressure || "N/A")
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: "产量: " + (modelData.expected_production || "N/A")
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: "温度: " + (modelData.bht || "N/A")
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                    }
                                    
                                    // 加载按钮
                                    Button {
                                        text: isChineseMode ? "加载" : "Load"
                                        flat: true
                                        Layout.preferredWidth: 60
                                        onClicked: loadHistoryVersion(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 参数分组
                Repeater {
                    model: parameterDefinitions
                    
                    LocalComponents.ParameterInputGroup {
                        width: parent.width
                        groupTitle: modelData.group
                        parameters: modelData.params
                        parametersData: root.parametersData
                        isChineseMode: root.isChineseMode
                        
                        onParameterChanged: function(key, value) {
                            root.parametersData[key] = value
                            root.isModified = true
                            validateParameters()
                        }
                    }
                }
            }
        }
        
        // 底部操作栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Material.dialogColor
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                
                // 状态提示
                Row {
                    spacing: 8
                    visible: hasExistingParams
                    
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: isModified ? Material.color(Material.Orange) : Material.color(Material.Green)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: isModified 
                              ? (isChineseMode ? "参数已修改" : "Parameters modified")
                              : (isChineseMode ? "参数已保存" : "Parameters saved")
                        color: Material.secondaryTextColor
                        font.pixelSize: 12
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                // 创建新版本复选框
                CheckBox {
                    id: createNewVersionCheck
                    text: isChineseMode ? "创建新版本" : "Create new version"
                    checked: false
                    visible: hasExistingParams
                }
                
                // 重置按钮
                Button {
                    text: isChineseMode ? "重置" : "Reset"
                    flat: true
                    onClicked: resetParameters()
                }
                
                // 保存按钮
                Button {
                    text: isChineseMode ? "保存参数" : "Save Parameters"
                    highlighted: true
                    enabled: isModified && parametersValid
                    onClicked: saveParameters()
                }
                
                // 下一步按钮
                Button {
                    text: isChineseMode ? "开始预测" : "Start Prediction"
                    enabled: parametersValid
                    onClicked: {
                        if (isModified) {
                            // 提示保存
                            showSaveConfirmDialog()
                        } else {
                            proceedToNext()
                        }
                    }
                }
            }
        }
    }
    
    // 加载指示器
    BusyIndicator {
        anchors.centerIn: parent
        running: controller ? controller.busy : false
        visible: running
    }
    
    // 组件加载完成
    Component.onCompleted: {
        if (wellId > 0 && controller) {
            controller.loadActiveParameters(wellId)
        }
    }
    
    // 连接Controller信号
    Connections {
        target: controller
        enabled: controller !== null
        
        function onParametersLoaded(params) {
            if (params && params.history) {
                // 这里处理历史数据
                parametersHistory = params.history
                return
            }
            if (params && params.id) {
                // 加载现有参数
                hasExistingParams = true
                currentParamsId = params.id
                isModified = false
                
                // 填充数据
                for (var key in parametersData) {
                    if (params[toSnakeCase(key)] !== undefined) {
                        parametersData[key] = params[toSnakeCase(key)].toString()
                    }
                }
                
                // 特殊处理百分比
                if (params.bsw !== undefined) {
                    parametersData.bsw = (params.bsw * 100).toString()
                }
            } else {
                // 无参数
                hasExistingParams = false
                currentParamsId = -1
                resetParameters()
            }
            validateParameters()
        }
        
        function onParametersSaved(id) {
            hasExistingParams = true
            currentParamsId = id
            isModified = false
            
            // 更新步骤数据
            root.dataChanged(collectStepData())
        }
        
        function onParametersError(error) {
            showErrorMessage(error)
        }
    }
    
    // 函数定义
    function validateParameters() {
        for (var i = 0; i < parameterDefinitions.length; i++) {
            var group = parameterDefinitions[i]
            for (var j = 0; j < group.params.length; j++) {
                var param = group.params[j]
                if (param.required) {
                    var value = parametersData[param.key]
                    if (!value || value.length === 0) {
                        parametersValid = false
                        return false
                    }
                    
                    // 数值范围验证
                    var numValue = parseFloat(value)
                    if (isNaN(numValue)) {
                        console.log("参数" + param.key + "的值 '" + value + "' 不是有效数字")
                        parametersValid = false
                        return false
                    }
                    if (numValue < param.min || numValue > param.max) {
                        console.log("参数" + param.key + "的值 " + numValue + " 超出范围 [" + param.min + ", " + param.max + "]")
                        parametersValid = false
                        return false
                    }
                }
            }
        }
        
        // 调用Controller的验证
        var result = true
        if (controller) {
            result = controller.validateParameters(parametersData)
        } else {
            console.log("没有控制器，出错了")
            result = false
        }
        
        console.log("验证通过")
        parametersValid = result
        return parametersValid
    }
    
    function saveParameters() {
        if (!parametersValid) {
            showErrorMessage(isChineseMode ? "请检查参数输入" : "Please check parameter input")
            return
        }
        
        // 准备数据
        var dataToSave = {}
        for (var key in parametersData) {
            if (parametersData[key]) {
                dataToSave[key] = parametersData[key]
            }
        }
        
        // 特殊处理百分比
        if (dataToSave.bsw) {
            dataToSave.bsw = parseFloat(dataToSave.bsw) / 100.0
        }
        
        // 调用Controller保存
        if (controller) {
            controller.saveProductionParameters(dataToSave, createNewVersionCheck.checked)
        }
    }
    
    function resetParameters() {
        for (var key in parametersData) {
            if (key !== "parameterName" && key !== "description") {
                parametersData[key] = ""
            }
        }
        isModified = false
        parametersValid = false
    }
    
    function proceedToNext() {
        // 收集数据
        root.dataChanged(collectStepData())
        // 请求下一步
        root.nextStepRequested()
    }
    
    function collectStepData() {
        var data = {
            parametersId: currentParamsId,
            parameters: {}
        }
        
        // 复制参数数据
        for (var key in parametersData) {
            if (parametersData[key]) {
                data.parameters[key] = parametersData[key]
            }
        }
        
        return data
    }
    
    function showHistoryDialog() {
        if (controller && wellId > 0) {
            console.log("加载历史版本")
            controller.loadParametersHistory(wellId, 10)
        }
    }
    
    function loadHistoryVersion(historyData) {
        console.log("加载历史版本:", JSON.stringify(historyData))
        
        // 加载选中的历史版本到当前参数
        for (var key in parametersData) {
            var snakeKey = toSnakeCase(key)
            if (historyData[snakeKey] !== undefined) {
                parametersData[key] = historyData[snakeKey].toString()
            }
        }
        
        // 特殊处理百分比
        if (historyData.bsw !== undefined) {
            parametersData.bsw = (historyData.bsw * 100).toString()
        }
        
        // 加载名称和描述
        if (historyData.parameter_name) {
            parametersData.parameterName = historyData.parameter_name
        }
        if (historyData.description) {
            parametersData.description = historyData.description
        }
        
        isModified = true
        validateParameters()
    }
    
    function showUnitConversionDialog() {
        // TODO: 显示单位转换对话框
        console.log("显示单位转换")
    }
    
    function showSaveConfirmDialog() {
        // TODO: 显示保存确认对话框
        // 临时处理
        saveParameters()
        proceedToNext()
    }
    
    function showErrorMessage(message) {
        // TODO: 显示错误消息
        console.error(message)
    }
    
    function toSnakeCase(str) {
        return str.replace(/[A-Z]/g, function(match) {
            return "_" + match.toLowerCase()
        }).replace(/^_/, "")
    }
    
    // 在 Step1_ProductionParameters.qml 中添加
    function loadParameters() {
        console.log("加载井 " + wellId + " 的生产参数")
        if (wellId > 0 && controller) {
            controller.loadActiveParameters(wellId)
        }
    }
}