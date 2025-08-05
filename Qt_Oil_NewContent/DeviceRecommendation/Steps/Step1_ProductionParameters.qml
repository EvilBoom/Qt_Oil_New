import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../Components" as LocalComponents

Rectangle {
    id: root

    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false
    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})
    property bool parametersValid: false

    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("Step1中单位制切换为:", isMetric ? "公制" : "英制")
            // 重新定义参数单位
            updateParameterUnits()
        }
    }

    // 内部属性
    property bool hasExistingParams: false
    property int currentParamsId: -1
    property bool isModified: false
    property var parametersHistory: []

    color: "transparent"

    // 🔥 修复：参数定义 - 避免循环依赖
    property var baseParameterDefinitions: [
        {
            group: "pressure",
            params: [
                {
                    key: "geoPressure",
                    labelCN: "地层压力",
                    labelEN: "Geo Pressure",
                    required: true,
                    min: 0
                },
                {
                    key: "saturationPressure",
                    labelCN: "饱和压力",
                    labelEN: "Saturation Pressure",
                    required: false,
                    min: 0
                },
                {
                    key: "wellHeadPressure",
                    labelCN: "井口压力",
                    labelEN: "Well Head Pressure",
                    required: true,
                    min: 0
                }
            ]
        },
        {
            group: "production",
            params: [
                {
                    key: "expectedProduction",
                    labelCN: "期望产量",
                    labelEN: "Expected Production",
                    required: true,
                    min: 0
                },
                {
                    key: "produceIndex",
                    labelCN: "生产指数",
                    labelEN: "Production Index",
                    required: true,
                    min: 0,
                    max: 100
                },
                {
                    key: "bsw",
                    labelCN: "水和沉淀物",
                    labelEN: "Water Cut",
                    required: true,
                    min: 0,
                    max: 100,
                    isPercentage: true
                }
            ]
        },
        {
            group: "fluid",
            params: [
                {
                    key: "bht",
                    labelCN: "井底温度",
                    labelEN: "Bottom Hole Temperature",
                    required: true
                },
                {
                    key: "api",
                    labelCN: "原油API重度",
                    labelEN: "Oil API Gravity",
                    required: true,
                    min: 0,
                    max: 100
                },
                {
                    key: "gasOilRatio",
                    labelCN: "油气比",
                    labelEN: "Gas Oil Ratio",
                    required: true,
                    min: 0
                }
            ]
        }
    ]

    // 🔥 计算属性：动态生成参数定义
    property var parameterDefinitions: {
        var result = []

        for (var i = 0; i < baseParameterDefinitions.length; i++) {
            var baseGroup = baseParameterDefinitions[i]
            var group = {
                group: getGroupTitle(baseGroup.group),
                params: []
            }

            for (var j = 0; j < baseGroup.params.length; j++) {
                var baseParam = baseGroup.params[j]
                var param = {
                    key: baseParam.key,
                    label: isChineseMode ? baseParam.labelCN : baseParam.labelEN,
                    unit: getParameterUnit(baseParam.key),
                    placeholder: getParameterPlaceholder(baseParam.key),
                    tooltip: getParameterTooltip(baseParam.key),
                    required: baseParam.required,
                    min: getParameterMin(baseParam.key),
                    max: getParameterMax(baseParam.key),
                    isPercentage: baseParam.isPercentage || false
                }
                group.params.push(param)
            }

            result.push(group)
        }

        return result
    }

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
            // Button {
            //     text: isChineseMode ? "单位转换" : "Unit Conversion"
            //     flat: true
            //     onClicked: showUnitConversionDialog()
            // }
        }

        // 参数名称和描述
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: nameColumn.height + 10
            color: Material.dialogColor
            radius: 8

            Column {
                id: nameColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 0
                spacing: 2

                RowLayout {
                    width: parent.width

                    Text {
                        text: isChineseMode ? "参数集名称：" : "Parameter Set Name:"
                        color: Material.primaryTextColor
                        font.pixelSize: 12
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
                        font.pixelSize: 12
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
                    height: parametersHistory.length > 0 ? (historyContent.height + 10) : 0
                    color: Material.dialogColor
                    radius: 8
                    visible: parametersHistory.length > 0

                    Column {
                        id: historyContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 2
                        spacing: 2

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
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    spacing: 2

                                    // 版本信息
                                    Column {
                                        Layout.fillWidth: true
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
                                        spacing: 2

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
        console.log("=== Step1 组件加载完成 ===")
        console.log("wellId:", wellId)
        console.log("controller:", controller)

        if (wellId > 0 && controller) {
            controller.loadActiveParameters(wellId)
        }
    }

    // 修正后的Connections
    Connections {
        target: controller
        enabled: controller !== null

        function onParametersLoaded(params) {
            console.log("=== onParametersLoaded 收到数据 ===")
            console.log("params:", JSON.stringify(params))

            if (params && params.history) {
                parametersHistory = params.history
                return
            }

            if (params && params.id) {
                hasExistingParams = true
                currentParamsId = params.id
                isModified = false

                // 🔥 填充数据时进行单位转换
                for (var key in parametersData) {
                    if (params[toSnakeCase(key)] !== undefined) {
                        var dbValue = params[toSnakeCase(key)].toString()
                        // 从标准单位转换为当前显示单位
                        var displayValue = convertFromStandardUnits(key, dbValue)
                        parametersData[key] = displayValue.toString()
                    }
                }

                // 特殊处理百分比
                if (params.bsw !== undefined) {
                    parametersData.bsw = (params.bsw * 100).toString()
                }

                updateStepDataImmediately()
            } else {
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

            console.log("=== 参数保存成功，立即更新stepData ===")
            console.log("参数ID:", id)

            // 立即更新步骤数据
            updateStepDataImmediately()
        }

        function onParametersError(error) {
            showErrorMessage(error)
        }
    }

    // 🔥 =================================
    // 🔥 辅助函数：单位和标题获取
    // 🔥 =================================

    function getGroupTitle(groupKey) {
        var titles = {
            "pressure": isChineseMode ? "压力参数" : "Pressure Parameters",
            "production": isChineseMode ? "生产参数" : "Production Parameters",
            "fluid": isChineseMode ? "流体性质" : "Fluid Properties"
        }
        return titles[groupKey] || groupKey
    }

    function getParameterUnit(key) {
        switch(key) {
            case "geoPressure":
            case "saturationPressure":
            case "wellHeadPressure":
                return getPressureUnit()
            case "expectedProduction":
                return getFlowUnit()
            case "produceIndex":
                return getProductionIndexUnit()
            case "bht":
                return getTemperatureUnit()
            case "gasOilRatio":
                return getGasOilRatioUnit()
            case "bsw":
                return "%"
            case "api":
                return "°API"
            default:
                return ""
        }
    }

    function getParameterPlaceholder(key) {
        switch(key) {
            case "geoPressure":
                return getPressurePlaceholder("geoPressure")
            case "saturationPressure":
                return getPressurePlaceholder("saturationPressure")
            case "wellHeadPressure":
                return getPressurePlaceholder("wellHeadPressure")
            case "expectedProduction":
                return getFlowPlaceholder()
            case "produceIndex":
                return getProductionIndexPlaceholder()
            case "bht":
                return getTemperaturePlaceholder()
            case "gasOilRatio":
                return getGasOilRatioPlaceholder()
            case "bsw":
                return "例如: 0.5"
            case "api":
                return "例如: 19.4"
            default:
                return ""
        }
    }

    function getParameterTooltip(key) {
        if (isChineseMode) {
            var tooltipsCN = {
                "geoPressure": "储层的原始地层压力",
                "saturationPressure": "泡点压力，原油开始脱气的压力",
                "wellHeadPressure": "井口回压",
                "expectedProduction": "期望的日产液量",
                "produceIndex": "单位压差下的产量",
                "bht": "井底流体温度",
                "gasOilRatio": "溶解气油比",
                "bsw": "产出液中水的体积百分比",
                "api": "原油的API重度"
            }
            return tooltipsCN[key] || ""
        } else {
            var tooltipsEN = {
                "geoPressure": "Original reservoir pressure",
                "saturationPressure": "Bubble point pressure",
                "wellHeadPressure": "Well head back pressure",
                "expectedProduction": "Expected daily production rate",
                "produceIndex": "Production per unit pressure drawdown",
                "bht": "Temperature at bottom hole",
                "gasOilRatio": "Solution gas oil ratio",
                "bsw": "Water volume percentage in produced fluid",
                "api": "API gravity of crude oil"
            }
            return tooltipsEN[key] || ""
        }
    }

    function getParameterMin(key) {
        switch(key) {
            case "bht":
                return getTemperatureMin()
            default:
                return 0
        }
    }

    function getParameterMax(key) {
        switch(key) {
            case "geoPressure":
            case "saturationPressure":
            case "wellHeadPressure":
                return getPressureMax()
            case "expectedProduction":
                return getFlowMax()
            case "bht":
                return getTemperatureMax()
            case "gasOilRatio":
                return getGasOilRatioMax()
            case "bsw":
            case "api":
                return 100
            case "produceIndex":
                return 100
            default:
                return 999999
        }
    }

    // 🔥 =================================
    // 🔥 单位获取函数
    // 🔥 =================================

    function getPressureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("pressure")
        }
        return isMetric ? "MPa" : "psi"
    }

    function getFlowUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("flow")
        }
        return isMetric ? "m³/d" : "bbl/d"
    }

    function getTemperatureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("temperature")
        }
        return isMetric ? "°C" : "°F"
    }

    function getProductionIndexUnit() {
        var flowUnit = getFlowUnit()
        var pressureUnit = getPressureUnit()
        return `${flowUnit}/${pressureUnit}`
    }

    function getGasOilRatioUnit() {
        return isMetric ? "m³/m³" : "scf/bbl"
    }

    // 🔥 占位符和范围函数
    function getPressurePlaceholder(type) {
        if (isMetric) {
            switch(type) {
                case "geoPressure": return "例如: 11.82"        // 🔥 11820 kPa = 11.82 MPa
                case "saturationPressure": return "例如: 5.86"  // 🔥 5860 kPa = 5.86 MPa
                case "wellHeadPressure": return "例如: 2.41"    // 🔥 2413 kPa = 2.41 MPa
                default: return "输入压力值"
            }
        } else {
            switch(type) {
                case "geoPressure": return "例如: 1715"
                case "saturationPressure": return "例如: 850"
                case "wellHeadPressure": return "例如: 350"
                default: return "Enter pressure"
            }
        }
    }

    function getFlowPlaceholder() {
        return isMetric ? "例如: 0.029" : "例如: 0.185"
    }

    // 🔥 修正生产指数占位符
    function getProductionIndexPlaceholder() {
        if (isMetric) {
            return "例如: 14.30"  // 🔥 对应0.62 bbl/(d·psi)的公制值
        } else {
            return "例如: 0.62"   // 英制示例值
        }
    }

    function getTemperaturePlaceholder() {
        return isMetric ? "例如: 113" : "例如: 235"
    }

    function getGasOilRatioPlaceholder() {
        return isMetric ? "例如: 161" : "例如: 900"
    }

    function getPressureMax() {
        return isMetric ? 68.95 : 10000
    }

    function getFlowMax() {
        return isMetric ? 1590 : 10000
    }

    function getTemperatureMin() {
        return isMetric ? 0 : 32
    }

    function getTemperatureMax() {
        return isMetric ? 260 : 500
    }

    function getGasOilRatioMax() {
        return isMetric ? 1790 : 10000
    }

    // 🔥 =================================
    // 🔥 主要业务函数
    // 🔥 =================================

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

        var result = true
        if (controller) {
            result = controller.validateParameters(parametersData)
        } else {
            console.log("没有控制器，出错了")
            result = false
        }

        console.log("验证通过")
        parametersValid = result
        console.log("设置 parametersValid:", parametersValid)

        return parametersValid
    }

    // 🔥 修复：只保留一个saveParameters函数
    function saveParameters() {
        if (!parametersValid) {
            showErrorMessage(isChineseMode ? "请检查参数输入" : "Please check parameter input")
            return
        }

        // 准备数据
        var dataToSave = {}
        for (var key in parametersData) {
            if (parametersData[key]) {
                var value = parametersData[key]
                // 🔥 转换为标准单位（英制）存储
                if (key !== "parameterName" && key !== "description") {
                    dataToSave[key] = convertToStandardUnits(key, value)
                } else {
                    dataToSave[key] = value
                }
            }
        }

        // 特殊处理百分比
        if (dataToSave.bsw) {
            dataToSave.bsw = parseFloat(dataToSave.bsw)
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
        console.log("=== Step1 proceedToNext 开始 ===")

        var stepData = collectStepData()
        console.log("收集的步骤数据:", JSON.stringify(stepData))

        if (root.dataChanged) {
            root.dataChanged(stepData)

            Qt.callLater(function() {
                console.log("=== 数据传递完成，请求下一步 ===")
                root.nextStepRequested()
            })
        } else {
            console.error("dataChanged 信号未连接")
        }
    }

    function updateStepDataImmediately() {
        var data = collectStepData()
        console.log("=== Step1 立即更新stepData ===")
        console.log("收集的数据:", JSON.stringify(data))

        if (root.dataChanged) {
            root.dataChanged(data)
        }
    }

    function collectStepData() {
        var data = {
            parametersId: currentParamsId,
            parameters: {}
        }

        for (var key in parametersData) {
            var value = parametersData[key]
            if (value !== undefined && value !== "") {
                if (key !== "parameterName" && key !== "description") {
                    var numValue = parseFloat(value)
                    if (!isNaN(numValue)) {
                        data.parameters[key] = numValue
                    } else {
                        console.warn("参数", key, "的值", value, "不是有效数字")
                    }
                } else {
                    data.parameters[key] = value
                }
            }
        }

        console.log("Step1 收集的数据:", JSON.stringify(data))
        return data
    }

    function showHistoryDialog() {
        console.log("=== showHistoryDialog 被调用 ===")
        if (controller && wellId > 0) {
            console.log("=== 开始加载历史版本 ===")
            controller.loadParametersHistory(wellId, 10)
        } else {
            console.log("无法加载历史版本 - controller:", controller, "wellId:", wellId)
        }
    }

    function loadHistoryVersion(historyData) {
        console.log("加载历史版本:", JSON.stringify(historyData))

        // 🔥 加载时进行单位转换
        for (var key in parametersData) {
            var snakeKey = toSnakeCase(key)
            if (historyData[snakeKey] !== undefined) {
                var dbValue = historyData[snakeKey].toString()
                var displayValue = convertFromStandardUnits(key, dbValue)
                parametersData[key] = displayValue.toString()
            }
        }

        // 特殊处理百分比
        if (historyData.bsw !== undefined) {
            parametersData.bsw = (historyData.bsw * 100).toString()
        }

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
        console.log("显示单位转换")
    }

    function showSaveConfirmDialog() {
        saveParameters()
        proceedToNext()
    }

    function showErrorMessage(message) {
        console.error(message)
    }

    function toSnakeCase(str) {
        return str.replace(/[A-Z]/g, function(match) {
            return "_" + match.toLowerCase()
        }).replace(/^_/, "")
    }

    function loadParameters() {
        console.log("加载井 " + wellId + " 的生产参数")
        if (wellId > 0 && controller) {
            controller.loadActiveParameters(wellId)
        }
    }

    // 🔥 参数单位更新函数
    function updateParameterUnits() {
        // 触发参数定义重新计算
        // 强制刷新parameterDefinitions
        root.parameterDefinitions = null
        root.parameterDefinitions = Qt.binding(function() {
            var result = []

            for (var i = 0; i < baseParameterDefinitions.length; i++) {
                var baseGroup = baseParameterDefinitions[i]
                var group = {
                    group: getGroupTitle(baseGroup.group),
                    params: []
                }

                for (var j = 0; j < baseGroup.params.length; j++) {
                    var baseParam = baseGroup.params[j]
                    var param = {
                        key: baseParam.key,
                        label: isChineseMode ? baseParam.labelCN : baseParam.labelEN,
                        unit: getParameterUnit(baseParam.key),
                        placeholder: getParameterPlaceholder(baseParam.key),
                        tooltip: getParameterTooltip(baseParam.key),
                        required: baseParam.required,
                        min: getParameterMin(baseParam.key),
                        max: getParameterMax(baseParam.key),
                        isPercentage: baseParam.isPercentage || false
                    }
                    group.params.push(param)
                }

                result.push(group)
            }

            return result
        })
    }

    // 🔥 验证单位转换函数
    function convertToStandardUnits(key, value) {
        if (!isMetric || !unitSystemController) {
            return value  // 英制直接返回
        }

        var numValue = parseFloat(value)
        if (isNaN(numValue)) return value

        switch(key) {
            case "geoPressure":
            case "saturationPressure":
            case "wellHeadPressure":
                // ✅ 从 MPa 转换为 psi
                return numValue * 145.038
            case "expectedProduction":
                // ✅ 从 m³/d 转换为 bbl/d
                return numValue / 0.159
            case "bht":
                // ✅ 从 °C 转换为 °F
                return numValue * 9/5 + 32
            case "gasOilRatio":
                // ✅ 从 m³/m³ 转换为 scf/bbl
                return numValue * 5.615
            case "produceIndex":
                // ✅ 生产指数单位转换
                return numValue / 23.06
            default:
                return numValue
        }
    }

    function convertFromStandardUnits(key, value) {
        if (!isMetric || !unitSystemController) {
            return value  // 英制直接返回
        }

        var numValue = parseFloat(value)
        if (isNaN(numValue)) return value

        switch(key) {
            case "geoPressure":
            case "saturationPressure":
            case "wellHeadPressure":
                // ✅ 从 psi 转换为 MPa
                return numValue / 145.038
            case "expectedProduction":
                // ✅ 从 bbl/d 转换为 m³/d
                return numValue * 0.159
            case "bht":
                // ✅ 从 °F 转换为 °C
                return (numValue - 32) * 5/9
            case "gasOilRatio":
                // ✅ 从 scf/bbl 转换为 m³/m³
                return numValue / 5.615
            case "produceIndex":
                // ✅ 生产指数单位转换
                return numValue * 23.06
            default:
                return numValue
        }
    }
}
