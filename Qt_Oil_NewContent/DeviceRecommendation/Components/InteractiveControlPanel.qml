// Qt_Oil_NewContent/DeviceRecommendation/Components/InteractiveControlPanel.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    property var controller: null
    property bool isChineseMode: true
    property var currentPumpData: null
    property var systemParameters: ({
        staticHead: 100,
        frictionCoeff: 0.001,
        flowRange: [0, 2000]
    })

    // 控制参数
    property int stages: 50
    property real frequency: 60
    property real wearLevel: 0
    property bool realTimeMode: false

    signal parametersChanged(var params)
    signal comparisonRequested(var conditions)
    signal predictionRequested(var params)
    signal exportRequested(string format)

    color: Material.backgroundColor

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            width: parent.width
            spacing: 16

            // 实时控制面板
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                color: "white"
                border.color: Material.dividerColor
                border.width: 1
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: isChineseMode ? "实时参数控制" : "Real-time Parameter Control"
                            font.pixelSize: 16
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            id: realTimeModeSwitch
                            text: isChineseMode ? "实时模式" : "Real-time Mode"
                            checked: realTimeMode
                            onCheckedChanged: {
                                realTimeMode = checked
                                if (checked) {
                                    updateTimer.start()
                                } else {
                                    updateTimer.stop()
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 12
                        columnSpacing: 16

                        // 级数控制
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "级数" : "Stages"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            RowLayout {
                                width: parent.width

                                Slider {
                                    id: stagesSlider
                                    Layout.fillWidth: true
                                    from: 1
                                    to: 200
                                    value: stages
                                    stepSize: 1

                                    onValueChanged: {
                                        if (Math.round(value) !== stages) {
                                            stages = Math.round(value)
                                            if (realTimeMode) {
                                                emitParametersChanged()
                                            }
                                        }
                                    }

                                    background: Rectangle {
                                        x: stagesSlider.leftPadding
                                        y: stagesSlider.topPadding + stagesSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 4
                                        width: stagesSlider.availableWidth
                                        height: implicitHeight
                                        radius: 2
                                        color: Material.dividerColor

                                        Rectangle {
                                            width: stagesSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: Material.accent
                                            radius: 2
                                        }
                                    }
                                }

                                SpinBox {
                                    from: 1
                                    to: 200
                                    value: stages
                                    onValueChanged: {
                                        if (value !== stages) {
                                            stages = value
                                            stagesSlider.value = value
                                            if (realTimeMode) {
                                                emitParametersChanged()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 频率控制
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "频率 (Hz)" : "Frequency (Hz)"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            RowLayout {
                                width: parent.width

                                Slider {
                                    id: frequencySlider
                                    Layout.fillWidth: true
                                    from: 30
                                    to: 80
                                    value: frequency
                                    stepSize: 0.1

                                    onValueChanged: {
                                        if (Math.abs(value - frequency) > 0.1) {
                                            frequency = Math.round(value * 10) / 10
                                            if (realTimeMode) {
                                                emitParametersChanged()
                                            }
                                        }
                                    }
                                }

                                SpinBox {
                                    from: 300
                                    to: 800
                                    value: frequency * 10
                                    onValueChanged: {
                                        var newFreq = value / 10
                                        if (Math.abs(newFreq - frequency) > 0.1) {
                                            frequency = newFreq
                                            frequencySlider.value = newFreq
                                            if (realTimeMode) {
                                                emitParametersChanged()
                                            }
                                        }
                                    }

                                    textFromValue: function(value) {
                                        return (value / 10).toFixed(1)
                                    }

                                    valueFromText: function(text) {
                                        return parseFloat(text) * 10
                                    }
                                }
                            }
                        }

                        // 磨损模拟
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "磨损模拟 (%)" : "Wear Simulation (%)"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            RowLayout {
                                width: parent.width

                                Slider {
                                    id: wearSlider
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 100
                                    value: wearLevel
                                    stepSize: 1

                                    onValueChanged: {
                                        if (Math.round(value) !== wearLevel) {
                                            wearLevel = Math.round(value)
                                            if (realTimeMode) {
                                                emitParametersChanged()
                                            }
                                        }
                                    }

                                    background: Rectangle {
                                        x: wearSlider.leftPadding
                                        y: wearSlider.topPadding + wearSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 200
                                        implicitHeight: 4
                                        width: wearSlider.availableWidth
                                        height: implicitHeight
                                        radius: 2
                                        color: Material.dividerColor

                                        Rectangle {
                                            width: wearSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: getWearColor(wearSlider.value)
                                            radius: 2
                                        }
                                    }
                                }

                                Text {
                                    text: wearLevel + "%"
                                    font.pixelSize: 12
                                    color: getWearColor(wearLevel)
                                    font.bold: true
                                    Layout.preferredWidth: 40
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Button {
                            text: isChineseMode ? "应用更改" : "Apply Changes"
                            Material.background: Material.primary
                            enabled: !realTimeMode
                            onClicked: emitParametersChanged()
                        }

                        Button {
                            text: isChineseMode ? "重置" : "Reset"
                            Material.background: Material.accent
                            onClicked: resetParameters()
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: isChineseMode ? "保存配置" : "Save Config"
                            onClicked: saveConfiguration()
                        }
                    }
                }
            }

            // 系统参数设置
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                color: "white"
                border.color: Material.dividerColor
                border.width: 1
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Text {
                        text: isChineseMode ? "系统参数设置" : "System Parameters"
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 20

                        // 静扬程
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "静扬程 (m)" : "Static Head (m)"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            SpinBox {
                                id: staticHeadSpinBox
                                Layout.fillWidth: true
                                from: 0
                                to: 5000
                                value: systemParameters.staticHead
                                onValueChanged: {
                                    systemParameters.staticHead = value
                                    updateSystemCurve()
                                }
                            }
                        }

                        // 摩擦系数
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "摩擦系数" : "Friction Coefficient"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            TextField {
                                id: frictionCoeffField
                                Layout.fillWidth: true
                                text: systemParameters.frictionCoeff.toFixed(6)
                                validator: DoubleValidator {
                                    bottom: 0
                                    top: 1
                                    decimals: 6
                                }
                                onTextChanged: {
                                    var value = parseFloat(text)
                                    if (!isNaN(value)) {
                                        systemParameters.frictionCoeff = value
                                        updateSystemCurve()
                                    }
                                }
                            }
                        }

                        // 流量范围
                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "最小流量 (m³/d)" : "Min Flow (m³/d)"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            SpinBox {
                                Layout.fillWidth: true
                                from: 0
                                to: 10000
                                value: systemParameters.flowRange[0]
                                onValueChanged: {
                                    systemParameters.flowRange[0] = value
                                    updateSystemCurve()
                                }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: isChineseMode ? "最大流量 (m³/d)" : "Max Flow (m³/d)"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }

                            SpinBox {
                                Layout.fillWidth: true
                                from: 100
                                to: 50000
                                value: systemParameters.flowRange[1]
                                onValueChanged: {
                                    systemParameters.flowRange[1] = value
                                    updateSystemCurve()
                                }
                            }
                        }
                    }
                }
            }

            // 多工况对比设置
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                color: "white"
                border.color: Material.dividerColor
                border.width: 1
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: isChineseMode ? "多工况对比" : "Multi-Condition Comparison"
                            font.pixelSize: 16
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: isChineseMode ? "添加工况" : "Add Condition"
                            Material.background: Material.accent
                            onClicked: addCondition()
                        }

                        Button {
                            text: isChineseMode ? "开始对比" : "Start Comparison"
                            Material.background: Material.primary
                            enabled: conditionsList.count > 1
                            onClicked: startComparison()
                        }
                    }

                    ListView {
                        id: conditionsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: ListModel {
                            id: conditionsModel
                        }

                        delegate: Rectangle {
                            width: conditionsList.width
                            height: 60
                            color: index % 2 === 0 ? "transparent" : Material.backgroundColor
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 12

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: model.color
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: model.label
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Material.primaryTextColor
                                    }

                                    Text {
                                        text: `${model.stages}级 | ${model.frequency}Hz`
                                        font.pixelSize: 11
                                        color: Material.secondaryTextColor
                                    }
                                }

                                Button {
                                    text: isChineseMode ? "编辑" : "Edit"
                                    Material.background: Material.accent
                                    onClicked: editCondition(index)
                                }

                                Button {
                                    text: isChineseMode ? "删除" : "Delete"
                                    Material.background: Material.color(Material.Red)
                                    onClicked: removeCondition(index)
                                }
                            }
                        }
                    }
                }
            }

            // 导出和报告功能
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: "white"
                border.color: Material.dividerColor
                border.width: 1
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Text {
                        text: isChineseMode ? "导出和报告" : "Export & Reports"
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 12

                        Button {
                            text: isChineseMode ? "导出PDF报告" : "Export PDF Report"
                            Material.background: Material.color(Material.Red)
                            onClicked: root.exportRequested("pdf")
                        }

                        Button {
                            text: isChineseMode ? "导出Excel数据" : "Export Excel Data"
                            Material.background: Material.color(Material.Green)
                            onClicked: root.exportRequested("excel")
                        }

                        Button {
                            text: isChineseMode ? "导出图片" : "Export Images"
                            Material.background: Material.color(Material.Blue)
                            onClicked: root.exportRequested("images")
                        }

                        Button {
                            text: isChineseMode ? "生成预测报告" : "Generate Prediction Report"
                            Material.background: Material.color(Material.Purple)
                            onClicked: generatePredictionReport()
                        }
                    }
                }
            }
        }
    }

    // 定时器用于实时更新
    Timer {
        id: updateTimer
        interval: 200
        repeat: true
        onTriggered: {
            if (realTimeMode) {
                emitParametersChanged()
            }
        }
    }

    // 工况编辑对话框
    Dialog {
        id: conditionEditDialog
        title: isChineseMode ? "编辑工况" : "Edit Condition"
        width: 400
        height: 300

        property int editIndex: -1

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            TextField {
                id: labelField
                Layout.fillWidth: true
                placeholderText: isChineseMode ? "工况名称" : "Condition Name"
            }

            Row {
                spacing: 16

                Column {
                    Text {
                        text: isChineseMode ? "级数:" : "Stages:"
                        font.pixelSize: 12
                    }
                    SpinBox {
                        id: editStagesSpinBox
                        from: 1
                        to: 200
                        value: 50
                    }
                }

                Column {
                    Text {
                        text: isChineseMode ? "频率:" : "Frequency:"
                        font.pixelSize: 12
                    }
                    SpinBox {
                        id: editFrequencySpinBox
                        from: 300
                        to: 800
                        value: 600
                        textFromValue: function(value) { return (value/10).toFixed(1) }
                        valueFromText: function(text) { return parseFloat(text) * 10 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: colorPicker.selectedColor
                radius: 4
                border.color: Material.dividerColor
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: isChineseMode ? "点击选择颜色" : "Click to select color"
                    color: "white"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: colorPicker.open()
                }
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (editIndex >= 0) {
                conditionsModel.setProperty(editIndex, "label", labelField.text)
                conditionsModel.setProperty(editIndex, "stages", editStagesSpinBox.value)
                conditionsModel.setProperty(editIndex, "frequency", editFrequencySpinBox.value / 10)
                conditionsModel.setProperty(editIndex, "color", colorPicker.selectedColor)
            } else {
                conditionsModel.append({
                    label: labelField.text,
                    stages: editStagesSpinBox.value,
                    frequency: editFrequencySpinBox.value / 10,
                    color: colorPicker.selectedColor
                })
            }
        }
    }

    // 颜色选择器（简化版）
    QtObject {
        id: colorPicker
        property color selectedColor: "#2196F3"
        property var colors: ["#2196F3", "#4CAF50", "#FF9800", "#F44336", "#9C27B0", "#607D8B"]
        property int currentIndex: 0

        function open() {
            currentIndex = (currentIndex + 1) % colors.length
            selectedColor = colors[currentIndex]
        }
    }

    // 函数定义
    function emitParametersChanged() {
        var params = {
            stages: stages,
            frequency: frequency,
            wearLevel: wearLevel,
            systemParameters: systemParameters
        }
        root.parametersChanged(params)
    }

    function resetParameters() {
        stages = 50
        frequency = 60
        wearLevel = 0
        stagesSlider.value = stages
        frequencySlider.value = frequency
        wearSlider.value = wearLevel
        emitParametersChanged()
    }

    function updateSystemCurve() {
        if (controller) {
            controller.generateSystemCurve(systemParameters)
        }
    }

    function addCondition() {
        conditionEditDialog.editIndex = -1
        conditionEditDialog.labelField.text = `工况${conditionsModel.count + 1}`
        conditionEditDialog.editStagesSpinBox.value = stages
        conditionEditDialog.editFrequencySpinBox.value = frequency * 10
        conditionEditDialog.open()
    }

    function editCondition(index) {
        var condition = conditionsModel.get(index)
        conditionEditDialog.editIndex = index
        conditionEditDialog.labelField.text = condition.label
        conditionEditDialog.editStagesSpinBox.value = condition.stages
        conditionEditDialog.editFrequencySpinBox.value = condition.frequency * 10
        conditionEditDialog.colorPicker.selectedColor = condition.color
        conditionEditDialog.open()
    }

    function removeCondition(index) {
        conditionsModel.remove(index)
    }

    function startComparison() {
        var conditions = []
        for (var i = 0; i < conditionsModel.count; i++) {
            var condition = conditionsModel.get(i)
            conditions.push({
                label: condition.label,
                stages: condition.stages,
                frequency: condition.frequency,
                color: condition.color
            })
        }
        root.comparisonRequested(conditions)
    }

    function generatePredictionReport() {
        var params = {
            stages: stages,
            frequency: frequency,
            systemParameters: systemParameters,
            predictionYears: 5
        }
        root.predictionRequested(params)
    }

    function saveConfiguration() {
        var config = {
            stages: stages,
            frequency: frequency,
            wearLevel: wearLevel,
            systemParameters: systemParameters,
            conditions: []
        }

        for (var i = 0; i < conditionsModel.count; i++) {
            var condition = conditionsModel.get(i)
            config.conditions.push({
                label: condition.label,
                stages: condition.stages,
                frequency: condition.frequency,
                color: condition.color
            })
        }

        // TODO: 实现配置保存功能
        console.log("保存配置:", JSON.stringify(config))
    }

    function getWearColor(value) {
        if (value < 25) return "#4CAF50"
        if (value < 50) return "#FF9800"
        if (value < 75) return "#F44336"
        return "#9C27B0"
    }

    Component.onCompleted: {
        // 添加默认工况
        conditionsModel.append({
            label: isChineseMode ? "当前工况" : "Current Condition",
            stages: stages,
            frequency: frequency,
            color: "#2196F3"
        })
    }
}
