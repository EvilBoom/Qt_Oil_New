import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
// 导入同级目录的组件
import "."

// 导入 Components 子目录的组件
import "Components"

Rectangle {
    id: root
    color: "#f5f7fa"

    // 属性定义
    property int projectId: -1
    property bool isChineseMode: true
    property int currentWellId: -1
    property string currentWellName: ""
    property var trajectoryData: []
    property var casingData: []
    property var calculationResult: null

    // 组件加载时初始化
    Component.onCompleted: {
        if (projectId > 0) {
            loadWellList()
        }else{
            console.error("项目ID未设置，无法加载井列表")}
    }

    // 连接控制器信号
    Connections {
        target: wellStructureController

        function onTrajectoryDataLoaded(data) {
            trajectoryData = data
            trajectoryView.updateData(data)
            sketchView.updateSketch(wellStructureController.getStatistics())
            updateButtonStates()
        }

        function onCasingDataLoaded(data) {
            casingData = data
            updateCasingList()
            if (wellStructureController.trajectoryData.length > 0) {
                wellStructureController.generateWellSketch()
            }
        }

        function onCalculationCompleted(result) {
            calculationResult = result
            calculationResultDialog.showResult(result)
        }

        function onVisualizationReady(vizData) {
            if (vizData.type === 'sketch') {
                sketchView.updateSketch(vizData.data)
            } else if (vizData.type === 'trajectory') {
                console.log('now show structure data')
                console.log(vizData.data.tvd_vs_md.x)
                console.log('now finish go update')
                trajectoryChartDialog.updateChart(vizData.data)
                trajectoryChartDialog.open()
            }
        }

        function onError(errorMsg) {
            showMessage(errorMsg, true)
        }

        function onCasingCreated(casingId) {
            showMessage(isChineseMode ? "套管创建成功" : "Casing created successfully")
            wellStructureController.loadCasingData(currentWellId)
        }

        function onCasingUpdated(casingId) {
            showMessage(isChineseMode ? "套管更新成功" : "Casing updated successfully")
            wellStructureController.loadCasingData(currentWellId)
        }

        function onCasingDeleted(casingId) {
            showMessage(isChineseMode ? "套管删除成功" : "Casing deleted successfully")
            wellStructureController.loadCasingData(currentWellId)
        }
    }

    Connections {
        target: excelImportController

        function onImportCompleted(wellId, rowCount) {
            showMessage(isChineseMode ?
                `成功导入 ${rowCount} 条轨迹数据` :
                `Successfully imported ${rowCount} trajectory records`)

            // 重新加载数据
            if (wellId === currentWellId) {
                wellStructureController.loadTrajectoryData(wellId)
            }
        }

        function onImportFailed(errorMsg) {
            showMessage(errorMsg, true)
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
                width: parent.width
                height: 1
                color: "#e0e0e0"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 5
                anchors.bottomMargin: 5
                spacing: 16

                // 井选择器
                ComboBox {
                    id: wellSelector
                    Layout.preferredWidth: 200
                    model: ListModel { id: wellListModel }
                    textRole: "wellName"
                    displayText: currentWellName || (isChineseMode ? "选择井" : "Select Well")

                    onActivated: function(index) {
                        var well = wellListModel.get(index)
                        if (well) {
                            currentWellId = well.wellId
                            currentWellName = well.wellName
                            loadWellData()
                        }
                    }
                }

                // 分隔符
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                    color: "#e0e0e0"
                }

                Item { Layout.fillWidth: true }

                // 功能按钮
                Button {
                    id: importBtn
                    text: isChineseMode ? "📥 导入Excel" : "📥 Import Excel"
                    enabled: currentWellId > 0
                    onClicked: excelImportDialog.open()
                }

                Button {
                    id: calculateBtn
                    text: isChineseMode ? "🧮 计算深度" : "🧮 Calculate Depths"
                    enabled: trajectoryData.length > 0
                    onClicked: {
                        // 使用默认参数进行计算
                        var params = {
                            method: 'default',
                            safety_factor: 1.1,
                            pump_safety_margin: 50,
                            perforation_ratio: 0.9,
                            min_distance_from_bottom: 20
                        }
                        wellStructureController.calculateDepths(params)
                    }
                }

                Button {
                    id: viewChartBtn
                    text: isChineseMode ? "📈 查看轨迹图" : "📈 View Trajectory"
                    enabled: trajectoryData.length > 0
                    onClicked: wellStructureController.generateTrajectoryChart()
                }

                Button {
                    text: isChineseMode ? "📊 导出数据" : "📊 Export Data"
                    enabled: trajectoryData.length > 0
                    flat: true
                    onClicked: exportMenu.open()

                    Menu {
                        id: exportMenu

                        MenuItem {
                            text: isChineseMode ? "导出轨迹数据" : "Export Trajectory Data"
                            onTriggered: exportTrajectoryData()
                        }

                        MenuItem {
                            text: isChineseMode ? "导出套管数据" : "Export Casing Data"
                            enabled: casingData.length > 0
                            onTriggered: exportCasingData()
                        }

                        MenuItem {
                            text: isChineseMode ? "导出完整报告" : "Export Full Report"
                            onTriggered: exportFullReport()
                        }
                    }
                }
            }
        }

        // 主内容区
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // 左侧数据面板
            Rectangle {
                SplitView.preferredWidth: 500
                SplitView.minimumWidth: 400
                color: "white"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 标签页
                    TabBar {
                        id: dataTabBar
                        Layout.fillWidth: true

                        TabButton {
                            text: isChineseMode ? "轨迹数据" : "Trajectory Data"
                        }

                        TabButton {
                            text: isChineseMode ? "套管信息" : "Casing Info"
                        }
                    }

                    // 标签内容
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: dataTabBar.currentIndex

                        // 轨迹数据视图
                        WellTrajectoryDataView {
                            id: trajectoryView
                            isChineseMode: root.isChineseMode
                        }

                        // 套管列表
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                // 添加套管按钮栏
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 50
                                    color: "#fafafa"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Button {
                                            text: isChineseMode ? "➕ 添加套管" : "➕ Add Casing"
                                            highlighted: true
                                            enabled: currentWellId > 0
                                            onClicked: {
                                                casingEditDialog.wellId = currentWellId
                                                casingEditDialog.openForNew()
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Label {
                                            text: isChineseMode ?
                                                `共 ${casingListModel.count} 个套管` :
                                                `Total ${casingListModel.count} casings`
                                            color: "#666"
                                        }
                                    }
                                }

                                // 套管列表
                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    ListView {
                                        id: casingListView
                                        model: ListModel { id: casingListModel }
                                        spacing: 0

                                        delegate: CasingListItem {
                                            width: casingListView.width
                                            isChineseMode: root.isChineseMode

                                            onEditClicked: function(casingData) {
                                                casingEditDialog.wellId = currentWellId
                                                casingEditDialog.openForEdit(casingData)
                                            }

                                            onDeleteClicked: function(casingId) {
                                                deleteCasingDialog.casingId = casingId
                                                deleteCasingDialog.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 底部信息栏
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "#f5f7fa"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Label {
                                text: {
                                    if (dataTabBar.currentIndex === 0) {
                                        return isChineseMode ?
                                            `数据点: ${trajectoryData.length}` :
                                            `Data points: ${trajectoryData.length}`
                                    } else {
                                        return ""
                                    }
                                }
                                color: "#666"
                                font.pixelSize: 12
                            }

                            Item { Layout.fillWidth: true }

                            Label {
                                text: {
                                    if (calculationResult) {
                                        return isChineseMode ?
                                            `泵挂: ${calculationResult.pump_hanging_depth}m | 射孔: ${calculationResult.perforation_depth}m` :
                                            `Pump: ${calculationResult.pump_hanging_depth}m | Perf: ${calculationResult.perforation_depth}m`
                                    }
                                    return ""
                                }
                                color: "#4a90e2"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // 右侧草图面板
            Rectangle {
                SplitView.fillWidth: true
                color: "white"

                WellSchematicView {
                    id: sketchView
                    anchors.fill: parent
                    isChineseMode: root.isChineseMode
                }
            }
        }
    }

    // Excel导入对话框
    ExcelImportDialog {
        id: excelImportDialog
        wellId: currentWellId
        wellName: currentWellName
        isChineseMode: root.isChineseMode
    }

    // 套管编辑对话框
    CasingEditDialog {
        id: casingEditDialog
        isChineseMode: root.isChineseMode
    }

    // 计算结果对话框
    CalculationResultDialog {
        id: calculationResultDialog
        isChineseMode: root.isChineseMode
    }

    // 轨迹图表对话框
    WellTrajectoryChart {
        id: trajectoryChartDialog
        isChineseMode: root.isChineseMode
    }

    // 删除确认对话框
    Dialog {
        id: deleteCasingDialog

        property int casingId: -1

        title: isChineseMode ? "确认删除" : "Confirm Delete"
        width: 400
        height: 200
        modal: true

        contentItem: Text {
            text: isChineseMode ?
                "确定要删除这个套管吗？此操作不可恢复。" :
                "Are you sure you want to delete this casing? This action cannot be undone."
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        footer: DialogButtonBox {
            Button {
                text: isChineseMode ? "删除" : "Delete"
                DialogButtonBox.buttonRole: DialogButtonBox.DestructiveRole
                highlighted: true

                onClicked: {
                    wellStructureController.deleteCasing(deleteCasingDialog.casingId)
                    deleteCasingDialog.accept()
                }
            }

            Button {
                text: isChineseMode ? "取消" : "Cancel"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole

                onClicked: deleteCasingDialog.reject()
            }
        }
    }

    // 消息提示
    Rectangle {
        id: messageBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
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

    // // 单位显示组
    // Rectangle {
    //     Layout.preferredWidth: 200
    //     Layout.preferredHeight: 35
    //     border.color: "#e0e0e0"
    //     border.width: 1
    //     radius: 4
    //     color: "#f8f9fa"

    //     Row {
    //         anchors.centerIn: parent
    //         spacing: 10

    //         Text {
    //             text: isChineseMode ? "单位:" : "Units:"
    //             font.pixelSize: 12
    //             color: "#666"
    //             anchors.verticalCenter: parent.verticalCenter
    //         }

    //         Text {
    //             text: isChineseMode ? "深度: 英尺(ft)" : "Depth: feet(ft)"
    //             font.pixelSize: 11
    //             color: "#2196F3"
    //             anchors.verticalCenter: parent.verticalCenter
    //         }

    //         Text {
    //             text: "|"
    //             color: "#ccc"
    //             anchors.verticalCenter: parent.verticalCenter
    //         }

    //         Text {
    //             text: isChineseMode ? "直径: 英寸(in)" : "Diameter: inches(in)"
    //             font.pixelSize: 11
    //             color: "#2196F3"
    //             anchors.verticalCenter: parent.verticalCenter
    //         }
    //     }
    // }

    // // 比例调整控制
    // Row {
    //     spacing: 5

    //     Label {
    //         text: isChineseMode ? "绘图比例:" : "Scale:"
    //         anchors.verticalCenter: parent.verticalCenter
    //         font.pixelSize: 12
    //     }

    //     SpinBox {
    //         id: scaleSpinBox
    //         from: 50
    //         to: 200
    //         value: 100
    //         stepSize: 10

    //         textFromValue: function(value, locale) {
    //             return value + "%"
    //         }

    //         onValueChanged: {
    //             // 通知草图视图更新比例
    //             if (sketchView) {
    //                 sketchView.setDrawingScale(value / 100.0)
    //             }
    //         }
    //     }
    // }

    // 辅助函数
    function loadWellList() {
        // 从井管理控制器获取井列表
        // 这里需要与井管理页面协调
        console.log("这里正在获取井列表，项目ID:", projectId)
        wellController.getWellList(projectId)
    }

    function loadWellData() {
        if (currentWellId > 0) {
            wellStructureController.loadTrajectoryData(currentWellId)
            wellStructureController.loadCasingData(currentWellId)
            wellStructureController.loadCalculationResult(currentWellId)
        }
    }

    function updateCasingList() {
        casingListModel.clear()
        for (var i = 0; i < casingData.length; i++) {
            casingListModel.append(casingData[i])
        }
    }

    function updateButtonStates() {
        importBtn.enabled = currentWellId > 0
        calculateBtn.enabled = trajectoryData.length > 0
        viewChartBtn.enabled = trajectoryData.length > 0
    }

    function showMessage(msg, isError) {
        messageText.text = msg
        messageBar.color = isError ? "#f44336" : "#4caf50"
        messageBar.visible = true
        messageTimer.restart()
    }

    function exportTrajectoryData() {
        // TODO: 实现轨迹数据导出
        showMessage(isChineseMode ? "功能开发中..." : "Function under development...")
    }

    function exportCasingData() {
        // TODO: 实现套管数据导出
        showMessage(isChineseMode ? "功能开发中..." : "Function under development...")
    }

    function exportFullReport() {
        // TODO: 实现完整报告导出
        showMessage(isChineseMode ? "功能开发中..." : "Function under development...")
    }

    // 连接井控制器获取井列表
    Connections {
        target: wellController
        function onWellListLoaded(wells) {
            wellListModel.clear()
            for (var i = 0; i < wells.length; i++) {
                wellListModel.append({
                    wellId: wells[i].id,
                    wellName: wells[i].well_name
                })
            }

            // 如果有井，默认选择第一个
            if (wells.length > 0 && currentWellId <= 0) {
                currentWellId = wells[0].id
                currentWellName = wells[0].well_name
                loadWellData()
            }
        }
    }
}
