import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../Common/Utils/UnitUtils.js" as UnitUtils

Item {
    id: root

    property int projectId: -1
    property bool isChineseMode: true
    property var editingWell: null
    property bool isNewWell: true

    // 🔥 新增：单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : true

    signal saved()

    // Dialog实例
    property alias dialog: wellDialog

    // 🔥 井数据模型 - 保留井的基本信息
    property string wellName: ""
    property string wellDepth: ""
    property string wellType: ""
    property string wellStatus: ""
    property string notes: ""

    // 🔥 新增项目数据模型
    property string companyName: ""
    property string oilFieldName: ""
    property string location: ""

    // 🔥 新增：监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("WellDataDialog中单位制切换为:", isMetric ? "公制" : "英制")
            
            // 🔥 转换当前输入的井深值
            if (depthField.text && !isNaN(parseFloat(depthField.text))) {
                var currentValue = parseFloat(depthField.text)
                var convertedValue
                
                if (isMetric) {
                    // 从英制转换为公制
                    convertedValue = UnitUtils.feetToMeters(currentValue)
                } else {
                    // 从公制转换为英制
                    convertedValue = UnitUtils.metersToFeet(currentValue)
                }
                
                depthField.text = convertedValue.toFixed(1)
                wellDepth = depthField.text
            }
        }
    }

    // 打开对话框 - 新建
    function openForNew() {
        isNewWell = true
        editingWell = null

        // 重置数据
        wellName = ""
        wellDepth = ""
        wellType = ""
        wellStatus = ""
        notes = ""
        
        // 🔥 重置项目数据
        companyName = ""
        oilFieldName = ""
        location = ""

        wellDialog.open()
    }

    // 打开对话框 - 编辑
    function openForEdit(well) {
        isNewWell = false
        editingWell = well

        // 加载现有井数据
        wellName = well.well_name || ""
        
        // 🔥 井深单位转换：数据库中是米，根据当前单位制显示
        var depthInMeters = parseFloat(well.well_md) || 0
        if (isMetric) {
            wellDepth = depthInMeters.toFixed(1)
        } else {
            var depthInFeet = UnitUtils.metersToFeet(depthInMeters)
            wellDepth = depthInFeet.toFixed(0)
        }
        
        wellType = well.well_type || ""
        wellStatus = well.well_status || ""
        notes = well.notes || ""

        // 🔥 加载项目数据（如果需要编辑项目信息）
        if (well.project) {
            companyName = well.project.company_name || ""
            oilFieldName = well.project.oil_name || ""
            location = well.project.location || ""
        }

        wellDialog.open()
    }

    Dialog {
        id: wellDialog

        parent: Overlay.overlay
        anchors.centerIn: parent

        title: isNewWell ? (isChineseMode ? "新建井和项目信息" : "New Well and Project Info") : (isChineseMode ? "编辑井信息" : "Edit Well Info")
        width: 650
        height: 650
        modal: true
        standardButtons: Dialog.NoButton

        contentItem: Item {
            implicitWidth: 600
            implicitHeight: 580

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

                    // 🔥 新增：单位制指示器
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "#f0f8ff"
                        border.color: "#4a90e2"
                        border.width: 1
                        radius: 5

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 12

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: isMetric ? "#4caf50" : "#ff9800"

                                Text {
                                    anchors.centerIn: parent
                                    text: isMetric ? "M" : "I"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: isChineseMode ? 
                                      `当前单位制: ${isMetric ? "公制" : "英制"} | 深度单位: ${getDepthUnitLabel()}` :
                                      `Current Units: ${isMetric ? "Metric" : "Imperial"} | Depth Unit: ${getDepthUnitLabel()}`
                                color: "#2c3e50"
                                font.pixelSize: 12
                                font.bold: true
                                wrapMode: Text.Wrap
                            }

                            // 🔥 单位切换按钮（可选）
                            Button {
                                text: isChineseMode ? "切换单位" : "Switch Units"
                                flat: true
                                font.pixelSize: 10
                                
                                onClicked: {
                                    if (unitSystemController) {
                                        unitSystemController.isMetric = !unitSystemController.isMetric
                                    }
                                }
                            }
                        }
                    }

                    // 🔥 项目基本信息组
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        title: isChineseMode ? "项目基本信息" : "Project Basic Information"
                        visible: isNewWell // 只在新建时显示

                        GridLayout {
                            width: parent.width
                            columns: 2
                            rowSpacing: 12
                            columnSpacing: 20

                            // 公司名称
                            Label {
                                text: isChineseMode ? "公司名称 *" : "Company Name *"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                id: companyNameField
                                Layout.fillWidth: true
                                text: companyName
                                placeholderText: isChineseMode ? "请输入公司名称" : "Enter company name"
                                onTextChanged: companyName = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 油田名称
                            Label {
                                text: isChineseMode ? "油田名称 *" : "Oil Field Name *"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                id: oilFieldNameField
                                Layout.fillWidth: true
                                text: oilFieldName
                                placeholderText: isChineseMode ? "请输入油田名称" : "Enter oil field name"
                                onTextChanged: oilFieldName = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }

                            // 地点
                            Label {
                                text: isChineseMode ? "地点 *" : "Location *"
                                Layout.alignment: Qt.AlignRight
                            }
                            TextField {
                                id: locationField
                                Layout.fillWidth: true
                                text: location
                                placeholderText: isChineseMode ? "请输入地点信息" : "Enter location"
                                onTextChanged: location = text

                                background: Rectangle {
                                    color: parent.activeFocus ? "#f0f8ff" : "#fafafa"
                                    border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                    radius: 4
                                }
                            }
                        }
                    }

                    // 🔥 井基本信息组（添加单位支持）
                    GroupBox {
                        Layout.fillWidth: true
                        Layout.leftMargin: 5
                        Layout.rightMargin: 5
                        title: isChineseMode ? "井基本信息" : "Well Basic Information"

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

                            // 🔥 井深（支持单位制）
                            Label {
                                text: {
                                    var unitLabel = getDepthUnitLabel()
                                    var unitDisplay = UnitUtils.getUnitDisplayText("depth", isMetric, isChineseMode)
                                    return isChineseMode ? 
                                           `井深 (${unitLabel}) *` : 
                                           `Well Depth (${unitLabel}) *`
                                }
                                Layout.alignment: Qt.AlignRight
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: depthField
                                    Layout.fillWidth: true
                                    text: wellDepth
                                    placeholderText: {
                                        var unitLabel = getDepthUnitLabel()
                                        return isChineseMode ? 
                                               `请输入井深 (${unitLabel})` : 
                                               `Enter well depth (${unitLabel})`
                                    }
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

                                // 🔥 单位标签
                                Rectangle {
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: depthField.height
                                    color: "#e8f0fe"
                                    border.color: "#4a90e2"
                                    border.width: 1
                                    radius: 4

                                    Text {
                                        anchors.centerIn: parent
                                        text: getDepthUnitLabel()
                                        color: "#4a90e2"
                                        font.bold: true
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            // 井型
                            Label {
                                text: isChineseMode ? "井型" : "Well Type"
                                Layout.alignment: Qt.AlignRight
                            }
                            ComboBox {
                                id: wellTypeCombo
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
                                id: wellStatusCombo
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

                    // 🔥 备注信息组（保留）
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

                    // 🔥 修改信息提示，包含单位信息
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#f0f8ff"
                        border.color: "#4682b4"
                        border.width: 1
                        radius: 5
                        visible: isNewWell

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                width: 20
                                height: 20
                                color: "#4682b4"
                                radius: 10

                                Text {
                                    anchors.centerIn: parent
                                    text: "i"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: isChineseMode ? 
                                      `项目信息将补充到项目档案中，井信息将创建新的井记录。\n井深将以米为单位存储在数据库中，当前输入单位为${getDepthUnitLabel()}。` : 
                                      `Project information will be added to project records, well information will create new well records.\nWell depth will be stored in meters in database, current input unit is ${getDepthUnitLabel()}.`
                                color: "#2c3e50"
                                font.pixelSize: 10
                                wrapMode: Text.Wrap
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
                enabled: {
                    var wellValid = wellName.trim().length > 0 && wellDepth.trim().length > 0 && !isNaN(parseFloat(wellDepth))
                    if (isNewWell) {
                        // 新建时需要验证项目信息
                        var projectValid = companyName.trim().length > 0 && oilFieldName.trim().length > 0 && location.trim().length > 0
                        return wellValid && projectValid
                    } else {
                        // 编辑时只需要验证井信息
                        return wellValid
                    }
                }

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

    // 🔥 新增：单位转换和格式化函数
    function getDepthUnitLabel() {
        return UnitUtils.getUnitLabel("depth", isMetric)
    }

    function convertDepthToMeters(inputValue) {
        var value = parseFloat(inputValue) || 0
        if (isMetric) {
            // 输入已经是米
            return value
        } else {
            // 输入是英尺，转换为米
            return UnitUtils.feetToMeters(value)
        }
    }

    function convertDepthFromMeters(metersValue) {
        var value = parseFloat(metersValue) || 0
        if (isMetric) {
            // 显示为米
            return value
        } else {
            // 显示为英尺
            return UnitUtils.metersToFeet(value)
        }
    }

    // 🔥 修改保存井数据函数，包含单位转换
    function saveWellData() {
        // 🔥 将井深转换为米（数据库存储单位）
        var depthInMeters = convertDepthToMeters(wellDepth)
        
        // 准备井数据
        var wellData = {
            project_id: projectId,
            well_name: wellName.trim(),
            well_md: depthInMeters,
            well_tvd: depthInMeters, // 暂时使用相同值
            well_type: getWellTypeValue(wellType),
            well_status: getWellStatusValue(wellStatus),
            notes: notes || null
        }

        console.log("保存井深: 输入值:", wellDepth, getDepthUnitLabel(), "-> 数据库值:", depthInMeters, "米")

        // 🔥 准备项目数据（仅在新建时）
        var projectData = null
        if (isNewWell) {
            projectData = {
                company_name: companyName.trim(),
                oil_name: oilFieldName.trim(),
                location: location.trim(),
                ps: notes || null
            }
        }

        if (isNewWell) {
            // 🔥 创建新井和更新项目信息
            wellController.createWellWithProjectInfo(wellData, projectData)
        } else {
            // 更新现有井
            wellData.id = editingWell.id
            wellController.updateWellData(wellData)
        }

        saved()
        wellDialog.accept()
    }

    // 🔥 井型值转换函数
    function getWellTypeValue(displayType) {
        if (isChineseMode) {
            switch(displayType) {
                case "直井": return "直井"
                case "定向井": return "定向井"
                case "水平井": return "水平井"
                default: return ""
            }
        } else {
            switch(displayType) {
                case "Vertical": return "vertical"
                case "Directional": return "directional"
                case "Horizontal": return "horizontal"
                default: return ""
            }
        }
    }

    // 🔥 井状态值转换函数
    function getWellStatusValue(displayStatus) {
        if (isChineseMode) {
            switch(displayStatus) {
                case "生产": return "生产"
                case "关停": return "关停"
                case "维修": return "维修"
                default: return ""
            }
        } else {
            switch(displayStatus) {
                case "Producing": return "production"
                case "Shut-in": return "shut-in"
                case "Maintenance": return "maintenance"
                default: return ""
            }
        }
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