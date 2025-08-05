import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../Common/Components" as CommonComponents
import "../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root
    color: "#f5f7fa"

    // 属性定义
    property int projectId: -1
    property bool isChineseMode: true
    property var currentWell: null
    property var wellList: []
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    // 连接控制器信号
    Connections {
        target: projectController
        function onProjectDetailsLoaded(details) {
            if (details.id === root.projectId) {
                projectSelector.currentProjectName = details.project_name
            }
        }
    }
    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("OilWellManagement中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }

    Connections {
        target: wellController
        function onWellListLoaded(wells) {
            wellListModel.clear()
            for (var i = 0; i < wells.length; i++) {
                wellListModel.append({
                    wellId: wells[i].id,
                    wellName: wells[i].well_name,
                    depth: wells[i].well_md || "0",
                    status: wells[i].well_status || "未知"
                })
            }

            // 如果列表不为空且没有选中的井，选中第一个
            if (wells.length > 0 && !root.currentWell) {
                selectWell(wells[0].id)
            }
        }

        function onWellDataLoaded(wellData) {
            root.currentWell = wellData
        }

        function onWellDataSaved(success) {
            if (success) {
                showMessage(isChineseMode ? "保存成功" : "Saved successfully")
                wellController.getWellList(root.projectId)
            }
        }

        function onWellCreated(wellId, wellName) {
            showMessage(isChineseMode ? `井 ${wellName} 创建成功` : `Well ${wellName} created successfully`)
            wellController.getWellList(root.projectId)
            selectWell(wellId)
        }

        function onWellUpdated(wellId, wellName) {
            showMessage(isChineseMode ? `井 ${wellName} 更新成功` : `Well ${wellName} updated successfully`)
            if (wellId === root.currentWell?.id) {
                wellController.getWellById(wellId)
            }
        }

        function onWellDeleted(wellId, wellName) {
            showMessage(isChineseMode ? `井 ${wellName} 已删除` : `Well ${wellName} deleted`)
            if (wellId === root.currentWell?.id) {
                root.currentWell = null
            }
            wellController.getWellList(root.projectId)
        }

        function onError(errorMsg) {
            showMessage(errorMsg, true)
        }
    }

    Connections {
        target: reservoirController
        function onReservoirDataLoaded(data) {
            // 更新油藏数据显示
        }
    }

    // 组件加载时初始化
    Component.onCompleted: {
        if (root.projectId > 0) {
            projectController.getProjectSummary(root.projectId)
            wellController.getWellList(root.projectId)
            reservoirController.getReservoirData(root.projectId)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 顶部工具栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "white"

            // 底部分隔线
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#e0e0e0"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.leftMargin: 3
                anchors.rightMargin: 3
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                spacing: 16

                // 项目选择器
                ComboBox {
                    id: projectSelector
                    Layout.preferredWidth: 200
                    property string currentProjectName: ""
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop

                    model: ListModel {
                        id: projectModel
                    }

                    textRole: "name"
                    displayText: currentProjectName || (isChineseMode ? "选择项目" : "Select Project")

                    onActivated: function(index) {
                        var project = projectModel.get(index)
                        if (project) {
                            root.projectId = project.id
                            currentProjectName = project.name
                            root.currentWell = null  // 清空当前井
                            wellController.getWellList(project.id)
                            reservoirController.getReservoirData(project.id)
                        }
                    }

                    Component.onCompleted: {
                        projectController.loadProjects()
                    }

                    Connections {
                        target: projectController
                        function onProjectsLoaded(projects) {
                            projectModel.clear()
                            for (var i = 0; i < projects.length; i++) {
                                projectModel.append({
                                    id: projects[i].id,
                                    name: projects[i].project_name
                                })
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // 功能按钮
                Button {
                    text: isChineseMode ? "🔄 刷新" : "🔄 Refresh"
                    flat: true
                    onClicked: {
                        if (root.projectId > 0) {
                            wellController.getWellList(root.projectId)
                            if (root.currentWell) {
                                wellController.getWellById(root.currentWell.id)
                            }
                            reservoirController.getReservoirData(root.projectId)
                        }
                    }
                }

                Button {
                    text: isChineseMode ? "➕ 新建井" : "➕ New Well"
                    highlighted: true
                    onClicked: {
                        // 打开新建井对话框
                        wellDataDialog.openForNew()
                    }
                }

                Button {
                    text: isChineseMode ? "📥 导出" : "📥 Export"
                    flat: true
                    onClicked: {
                        // 导出功能
                    }
                }
            }
        }

        // 主内容区
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // 左侧井列表
            Rectangle {
                SplitView.preferredWidth: 300
                SplitView.minimumWidth: 250
                color: "white"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 搜索栏
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: "#fafafa"

                        TextField {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: 10
                            placeholderText: isChineseMode ? "搜索井号..." : "Search well..."

                            background: Rectangle {
                                color: "white"
                                border.color: parent.activeFocus ? "#4a90e2" : "#ddd"
                                radius: 4
                            }

                            onTextChanged: {
                                if (text.length === 0) {
                                    // 清空搜索时，重新加载所有井
                                    wellController.getWellList(root.projectId)
                                } else if (text.length >= 1) {
                                    // 搜索
                                    wellController.searchWells(root.projectId, text)
                                }
                            }
                        }

                        // 底部分隔线
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#e0e0e0"
                        }
                    }

                    // 井列表
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ListView {
                            id: wellListView
                            anchors.fill: parent
                            model: ListModel {
                                id: wellListModel
                            }

                            delegate: ItemDelegate {
                                width: wellListView.width
                                height: 80

                                background: Rectangle {
                                    color: hovered ? "#f5f7fa" : (selected ? "#e8f0fe" : "white")

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: "#eee"
                                    }
                                }

                                property bool selected: root.currentWell && root.currentWell.well_name === model.wellName

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    // 井图标
                                    Rectangle {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        radius: 24
                                        color: selected ? "#4a90e2" : "#e0e0e0"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "🛢️"
                                            font.pixelSize: 20
                                        }
                                    }

                                    // 井信息
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: model.wellName
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: "#333"
                                        }

                                        Text {
                                            text: {
                                                // 🔥 支持单位转换的深度显示
                                                var depthText = (isChineseMode ? "深度: " : "Depth: ") + formatDepth(parseFloat(model.depth || 0))
                                                var statusText = " | " + (isChineseMode ? "状态: " : "Status: ") + model.status
                                                return depthText + statusText
                                            }
                                            font.pixelSize: 14
                                            color: "#666"
                                        }
                                    }
                                }

                                onClicked: {
                                    selectWell(model.wellId)
                                }
                            }
                        }
                    }
                }
            }

            // 右侧详情区
            Rectangle {
                SplitView.fillWidth: true
                color: "white"

                // 详情内容
                Loader {
                    id: detailLoader
                    anchors.fill: parent
                    anchors.margins: 20

                    sourceComponent: root.currentWell ? wellDetailComponent : emptyComponent
                }

                // 空状态组件
                Component {
                    id: emptyComponent

                    Item {
                        Column {
                            anchors.centerIn: parent
                            spacing: 20

                            Text {
                                text: "🛢️"
                                font.pixelSize: 64
                                color: "#ccc"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: isChineseMode ? "请选择一个井查看详情" : "Please select a well to view details"
                                font.pixelSize: 18
                                color: "#999"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // 井详情组件
                Component {
                    id: wellDetailComponent

                    ColumnLayout {
                        spacing: 20

                        // 标题栏
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.currentWell.well_name || ""
                                font.pixelSize: 24
                                font.bold: true
                                color: "#333"
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: isChineseMode ? "编辑" : "Edit"
                                onClicked: {
                                    wellDataDialog.openForEdit(root.currentWell)
                                }
                            }

                            Button {
                                text: isChineseMode ? "删除" : "Delete"
                                flat: true
                                onClicked: {
                                    deleteConfirmDialog.open()
                                }
                            }
                        }

                        // 标签页
                        TabBar {
                            id: tabBar
                            Layout.fillWidth: true

                            TabButton {
                                text: isChineseMode ? "基本信息" : "Basic Info"
                            }

                            TabButton {
                                text: isChineseMode ? "油藏数据" : "Reservoir Data"
                            }
                        }

                        // 标签内容
                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: tabBar.currentIndex

                            // 基本信息
                            ScrollView {
                                contentWidth: availableWidth

                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    rowSpacing: 16
                                    columnSpacing: 20

                                    // 井基本信息字段
                                    Label {
                                        text: isChineseMode ? "井号:" : "Well Name:"
                                        font.bold: true
                                    }
                                    Label {
                                        text: root.currentWell.well_name || "-"
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `井深 (${getDepthUnit()}):` :
                                            `Well Depth (${getDepthUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatDepth(parseFloat(root.currentWell.well_md || 0))
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `内径 (${getDiameterUnit()}):` :
                                            `Inner Diameter (${getDiameterUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatDiameter(parseFloat(root.currentWell.inner_diameter || 0))
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `外径 (${getDiameterUnit()}):` :
                                            `Outer Diameter (${getDiameterUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatDiameter(parseFloat(root.currentWell.outer_diameter || 0))
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `泵挂深度 (${getDepthUnit()}):` :
                                            `Pump Depth (${getDepthUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatDepth(parseFloat(root.currentWell.pump_depth || 0))
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `管径 (${getDiameterUnit()}):` :
                                            `Tubing Diameter (${getDiameterUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatDiameter(parseFloat(root.currentWell.tubing_diameter || 0))
                                    }
                                }
                            }

                            // 油藏数据
                            ScrollView {
                                contentWidth: availableWidth

                                GridLayout {
                                    width: parent.width
                                    columns: 2
                                    rowSpacing: 16
                                    columnSpacing: 20

                                    property var reservoirData: reservoirController.currentReservoirData

                                    Label {
                                        text: isChineseMode ?
                                            `温度 (${getTemperatureUnit()}):` :
                                            `Temperature (${getTemperatureUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatTemperature(parseFloat(parent.reservoirData?.bht || 0))
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `压力 (${getPressureUnit()}):` :
                                            `Pressure (${getPressureUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatPressure(parseFloat(parent.reservoirData?.pr || 0))
                                    }

                                    Label {
                                        text: isChineseMode ? "API重度:" : "API Gravity:"
                                        font.bold: true
                                    }
                                    Label {
                                        text: parent.reservoirData?.api || "-"
                                    }

                                    Label {
                                        text: isChineseMode ? "含水率 (%):" : "Water Cut (%):"
                                        font.bold: true
                                    }
                                    Label {
                                        text: parent.reservoirData?.water_cut || "-"
                                    }

                                    Label {
                                        text: isChineseMode ?
                                            `产液量 (${getFlowUnit()}):` :
                                            `Liquid Rate (${getFlowUnit()}):`
                                        font.bold: true
                                    }
                                    Label {
                                        text: formatFlowRate(parseFloat(parent.reservoirData?.liquid_production || 0))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 井数据编辑对话框
    WellDataDialog {
        id: wellDataDialog
        projectId: root.projectId
        isChineseMode: root.isChineseMode

        onSaved: {
            // 保存成功后会通过信号自动刷新列表
        }
    }

    // 删除确认对话框
    Dialog {
        id: deleteConfirmDialog
        title: isChineseMode ? "确认删除" : "Confirm Delete"
        width: 400
        height: 200
        modal: true

        contentItem: Text {
            text: isChineseMode ?
                `确定要删除井 "${root.currentWell?.well_name}" 吗？此操作不可恢复。` :
                `Are you sure you want to delete well "${root.currentWell?.well_name}"? This action cannot be undone.`
            wrapMode: Text.Wrap
            font.pixelSize: 14
            color: "#333"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        footer: DialogButtonBox {
            Button {
                text: isChineseMode ? "删除" : "Delete"
                DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole
                highlighted: true

                onClicked: {
                    if (root.currentWell) {
                        wellController.deleteWell(root.currentWell.id)
                    }
                    deleteConfirmDialog.accept()
                }
            }

            Button {
                text: isChineseMode ? "取消" : "Cancel"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole

                onClicked: deleteConfirmDialog.reject()
            }
        }
    }

    // 消息提示
    Rectangle {
        id: messageBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 300
        height: 40
        radius: 20
        color: "#333"
        visible: false

        Text {
            id: messageText
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 14
        }

        Timer {
            id: messageTimer
            interval: 3000
            onTriggered: messageBar.visible = false
        }
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatDepth(valueInM) {
        if (!valueInM || valueInM <= 0) return "-"

        if (isMetric) {
            // 保持米
            return valueInM.toFixed(1) + " m"
        } else {
            // 转换为英尺
            var ftValue = UnitUtils.metersToFeet(valueInM)
            return ftValue.toFixed(0) + " ft"
        }
    }

    function formatDiameter(valueInMm) {
        if (!valueInMm || valueInMm <= 0) return "-"

        if (isMetric) {
            // 保持毫米
            return valueInMm.toFixed(1) + " mm"
        } else {
            // 转换为英寸
            var inValue = UnitUtils.mmToInches(valueInMm)
            return inValue.toFixed(2) + " in"
        }
    }

    function formatTemperature(valueInC) {
        if (!valueInC || valueInC <= 0) return "-"

        if (isMetric) {
            // 保持摄氏度
            return valueInC.toFixed(1) + " °C"
        } else {
            // 转换为华氏度
            var fValue = UnitUtils.celsiusToFahrenheit(valueInC)
            return fValue.toFixed(1) + " °F"
        }
    }

    function formatPressure(valueInMPa) {
        if (!valueInMPa || valueInMPa <= 0) return "-"

        if (isMetric) {
            // 保持MPa
            return valueInMPa.toFixed(2) + " MPa"
        } else {
            // 转换为psi
            var psiValue = UnitUtils.mpaToPsi(valueInMPa)
            return psiValue.toFixed(0) + " psi"
        }
    }

    function formatFlowRate(valueInM3d) {
        if (!valueInM3d || valueInM3d <= 0) return "-"

        if (isMetric) {
            // 保持m³/d
            return valueInM3d.toFixed(1) + " m³/d"
        } else {
            // 转换为bbl/d
            var bblValue = UnitUtils.m3ToBbl(valueInM3d)
            return bblValue.toFixed(0) + " bbl/d"
        }
    }

    // 🔥 获取单位标签函数
    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDiameterUnit() {
        return isMetric ? "mm" : "in"
    }

    function getTemperatureUnit() {
        return isMetric ? "°C" : "°F"
    }

    function getPressureUnit() {
        return isMetric ? "MPa" : "psi"
    }

    function getFlowUnit() {
        return isMetric ? "m³/d" : "bbl/d"
    }

    // 辅助函数
    function selectWell(wellId) {
        // 选择井并加载详情
        wellController.getWellById(wellId)
    }

    function showMessage(msg, isError) {
        messageText.text = msg
        messageBar.color = isError ? "#f44336" : "#4caf50"
        messageBar.visible = true
        messageTimer.restart()
    }
}
