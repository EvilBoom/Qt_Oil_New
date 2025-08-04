import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

// 导入组件目录
import "./components"

Rectangle {
    id: root
    color: "#f5f7fa"

    // 属性
    property bool isChineseMode: true
    property var selectedDeviceIds: []  // 批量选择的设备ID列表
    property bool batchSelectionMode: false  // 批量选择模式

    // 组件加载时初始化
    Component.onCompleted: {

        console.log("========================================")
        console.log("=== DeviceManagementPage 初始化开始 ===")
        console.log("========================================")

        console.log("页面属性:")
        console.log("  - isChineseMode:", isChineseMode)
        console.log("  - root.width:", root.width)
        console.log("  - root.height:", root.height)

        // 检查 deviceController 是否存在
        console.log("控制器检查:")
        console.log("  - typeof deviceController:", typeof deviceController)
        console.log("  - deviceController 存在:", typeof deviceController !== 'undefined')

        if (typeof deviceController !== 'undefined') {
            console.log("deviceController 详细信息:")
            try {
                console.log("  - loading:", deviceController.loading)
                console.log("  - deviceListModel:", deviceController.deviceListModel)
                console.log("  - totalCount:", deviceController.totalCount)
                console.log("  - currentPage:", deviceController.currentPage)
                console.log("  - totalPages:", deviceController.totalPages)

                console.log("开始调用 loadDevices()...")
                deviceController.loadDevices()

                console.log("开始调用 loadStatistics()...")
                deviceController.loadStatistics()

                console.log("设备控制器初始化完成")
            } catch (e) {
                console.error("访问 deviceController 时出错:", e)
            }
        } else {
            console.error("❌ DeviceController 未在上下文中找到")
            showMessage(isChineseMode ? "设备控制器未初始化" : "Device controller not initialized", true)
        }

        console.log("=== DeviceManagementPage 初始化完成 ===")

    }
    // 🔥 添加错误边界
    Timer {
        id: initTimer
        interval: 1000
        running: true
        onTriggered: {
            console.log("=== 延迟检查（1秒后）===")
            console.log("页面是否可见:", root.visible)
            console.log("页面尺寸:", root.width, "x", root.height)

            if (typeof deviceController !== 'undefined' && deviceController.deviceListModel) {
                console.log("设备模型行数:", deviceController.deviceListModel.rowCount())
            }
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
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                // 标题
                Label {
                    text: isChineseMode ? "设备数据库管理" : "Equipment Database Management"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#333"
                }

                Item { Layout.fillWidth: true }

                // 操作按钮组
                Row {
                    spacing: 10

                    // 批量操作切换按钮
                    Button {
                        text: batchSelectionMode ?
                              (isChineseMode ? "取消批量" : "Cancel Batch") :
                              (isChineseMode ? "批量操作" : "Batch Operation")
                        flat: true

                        onClicked: {
                            batchSelectionMode = !batchSelectionMode
                            if (!batchSelectionMode) {
                                selectedDeviceIds = []
                            }
                        }
                    }

                    // 批量删除按钮
                    Button {
                        text: isChineseMode ? "批量删除" : "Batch Delete"
                        visible: batchSelectionMode && selectedDeviceIds.length > 0
                        flat: true
                        Material.foreground: Material.Red

                        onClicked: {
                            batchDeleteDialog.open()
                        }
                    }

                    // 导入按钮
                    Button {
                        text: isChineseMode ? "📥 导入" : "📥 Import"
                        flat: true

                        onClicked: {
                            importDialog.open()
                        }
                    }

                    // 导出按钮
                    Button {
                        text: isChineseMode ? "📤 导出" : "📤 Export"
                        flat: true

                        onClicked: {
                            exportDialog.show()
                        }
                    }

                    // 添加设备按钮
                    Button {
                        text: isChineseMode ? "➕ 添加设备" : "➕ Add Device"
                        highlighted: true
                        // 定制按钮背景为蓝色
                        background: Rectangle {

                                radius: 4 // 轻微圆角，增强视觉效果
                                // 可选：添加状态变化（悬停/按下时颜色加深）
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                                color: parent.pressed ? "#0A47CC" : // 按下时深色
                                       parent.hovered ? "#2A6FFF" : // 悬停时中色
                                       "blue" // 默认蓝色
                            }
                            // 定制文本颜色（白色更适配蓝色背景）
                        contentItem: Text {
                                    text: parent.text
                                    color: "white" // 白色文本
                                    font.pixelSize: 14
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                        onClicked: {
                            if (deviceController) {
                                deviceController.clearSelectedDevice()
                            }
                            addEditDialog.deviceData = null
                            addEditDialog.open()
                        }
                    }
                }
            }
        }

        // 主内容区域
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            spacing: 20

            // 左侧设备列表区域
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.65
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#e0e0e0"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 筛选栏
                    DeviceFilterBar {
                        id: filterBar
                        Layout.fillHeight: false
                        Layout.minimumWidth: 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        isChineseMode: root.isChineseMode

                        onTypeFilterChanged: function(type) {
                            if (deviceController) {
                                deviceController.filterByType(type)
                            }
                        }

                        onStatusFilterChanged: function(status) {
                            if (deviceController) {
                                deviceController.filterByStatus(status)
                            }
                        }

                        onSearchTextChanged: function(text) {
                            searchTimer.searchText = text
                            searchTimer.restart()
                        }
                    }

                    // 分隔线
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#e0e0e0"
                    }

                    // 设备列表
                    DeviceListView {
                        id: deviceListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 10

                        // model: deviceController ? deviceController.deviceListModel : null
                        model: deviceController.deviceListModel
                        isChineseMode: root.isChineseMode
                        batchSelectionMode: root.batchSelectionMode
                        selectedIds: root.selectedDeviceIds

                        onDeviceClicked: function(deviceId) {
                            // 查看model的状态
                            console.log("这里是onDeviceClicked的deviceId", deviceId)
                            if (batchSelectionMode) {
                                // 批量选择模式下，切换选中状态
                                var index = selectedDeviceIds.indexOf(deviceId)
                                console.log("ERROR 202 Toggling device selection:", deviceId, "Current selection:", selectedDeviceIds)
                                if (index === -1) {
                                    selectedDeviceIds.push(deviceId)
                                } else {
                                    selectedDeviceIds.splice(index, 1)
                                }
                                // 触发更新
                                selectedDeviceIds = selectedDeviceIds.slice()
                            } else {
                                // 普通模式下，查看详情
                                if (deviceController) {
                                    //console.log("MP213 check ID, onclicked id is error",deviceId)
                                    console.log("qml端正在调用deviceController.selectDevice",deviceId)
                                    //查看model传入的对不对
                                    console.log("QML deviceController.selectedDevice:", deviceController.deviceListModel)
                                    deviceController.selectDevice(deviceId)
                                }
                            }
                        }

                        onEditRequested: function(deviceId) {
                            if (deviceController) {
                                deviceController.selectDevice(deviceId)
                                addEditDialog.deviceData = deviceController.selectedDevice
                                addEditDialog.open()
                            }
                        }

                        onDeleteRequested: function(deviceId) {
                            deleteDialog.deviceId = deviceId
                            deleteDialog.open()
                        }
                    }

                    // 分页栏
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "#f8f9fa"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 20

                            Label {
                                text: isChineseMode ?
                                      `共 ${deviceController ? deviceController.totalCount : 0} 条记录` :
                                      `Total ${deviceController ? deviceController.totalCount : 0} records`
                                color: "#666"
                            }

                            Row {
                                spacing: 5

                                Button {
                                    text: "<"
                                    flat: true
                                    enabled: deviceController && deviceController.currentPage > 1
                                    onClicked: if (deviceController) deviceController.previousPage()
                                }

                                Label {
                                    text: deviceController ?
                                          `${deviceController.currentPage} / ${deviceController.totalPages}` :
                                          "1 / 1"
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    width: 80
                                }

                                Button {
                                    text: ">"
                                    flat: true
                                    enabled: deviceController && deviceController.currentPage < deviceController.totalPages
                                    onClicked: if (deviceController) deviceController.nextPage()
                                }
                            }
                        }
                    }
                }
            }

            // 右侧详情面板
            DeviceDetailPanel {
                id: detailPanel
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.35 - 20
                visible: !batchSelectionMode && deviceController && deviceController.selectedDevice && deviceController.selectedDevice.id

                deviceData: deviceController ? deviceController.selectedDevice : ({})
                isChineseMode: root.isChineseMode

                onEditRequested: {
                    if (deviceController && deviceController.selectedDevice) {
                        // 确保先设置数据，再打开对话框
                        addEditDialog.deviceData = deviceController.selectedDevice
                        addEditDialog.open()
                    }
                }

                onDeleteRequested: {
                    if (deviceController && deviceController.selectedDevice) {
                        deleteDialog.deviceId = deviceController.selectedDevice.id
                        deleteDialog.open()
                    }
                }
            }

            // 批量操作时的占位面板
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.35 - 20
                visible: batchSelectionMode
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#e0e0e0"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20

                    Label {
                        text: isChineseMode ? "批量操作模式" : "Batch Operation Mode"
                        font.pixelSize: 18
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Label {
                        text: isChineseMode ?
                              `已选择 ${selectedDeviceIds.length} 个设备` :
                              `${selectedDeviceIds.length} devices selected`
                        font.pixelSize: 14
                        color: "#666"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Button {
                        text: isChineseMode ? "清除选择" : "Clear Selection"
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: selectedDeviceIds = []
                    }
                }
            }
        }
    }

    // 加载状态遮罩
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
        visible: deviceController ? deviceController.loading : false
        z: 100

        BusyIndicator {
            anchors.centerIn: parent
            running: parent.visible
        }
    }

    // 搜索防抖定时器
    Timer {
        id: searchTimer
        interval: 500
        property string searchText: ""
        onTriggered: {
            if (deviceController) {
                deviceController.searchDevices(searchText)
            }
        }
    }

    // 对话框
    AddEditDeviceDialog {
        id: addEditDialog
        isChineseMode: root.isChineseMode

        onAccepted: {
            if (deviceController) {
                deviceController.saveDeviceFromJson(addEditDialog.formDataJson)
                deviceController.saveDevice(addEditDialog.formDataJson)
            }
        }
    }

    Dialog {
        id: deleteDialog
        property int deviceId: -1

        title: isChineseMode ? "确认删除" : "Confirm Delete"
        width: 400
        height: 200
        modal: true

        contentItem: Text {
            text: isChineseMode ?
                  "确定要删除这个设备吗？此操作无法撤销。" :
                  "Are you sure you want to delete this device? This action cannot be undone."
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
                    if (deviceController) {
                        deviceController.deleteDevice(deleteDialog.deviceId)
                    }
                    deleteDialog.accept()
                }
            }

            Button {
                text: isChineseMode ? "取消" : "Cancel"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                onClicked: deleteDialog.reject()
            }
        }
    }

    Dialog {
        id: batchDeleteDialog
        title: isChineseMode ? "批量删除确认" : "Batch Delete Confirmation"
        width: 400
        height: 200
        modal: true

        contentItem: Text {
            text: isChineseMode ?
                  `确定要删除选中的 ${selectedDeviceIds.length} 个设备吗？此操作无法撤销。` :
                  `Are you sure you want to delete ${selectedDeviceIds.length} selected devices? This action cannot be undone.`
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
                    if (deviceController) {
                        deviceController.batchDeleteDevices(selectedDeviceIds)
                    }
                    batchSelectionMode = false
                    selectedDeviceIds = []
                    batchDeleteDialog.accept()
                }
            }

            Button {
                text: isChineseMode ? "取消" : "Cancel"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
                onClicked: batchDeleteDialog.reject()
            }
        }
    }

    // 在DeviceImportDialog的信号连接部分
    DeviceImportDialog {
        id: importDialog

        onImportRequested: function(fileUrl, deviceType, isMetric) {
            console.log("Import requested:", fileUrl, deviceType, "Metric:", isMetric)
            if (typeof deviceController !== "undefined") {
                deviceController.importFromExcel(fileUrl, deviceType, isMetric)
            }
        }

        onTemplateDownloadRequested: function(deviceType, savePath, isMetric) {
            console.log("Template download requested:", deviceType, "Path:", savePath, "Metric:", isMetric)
            if (typeof deviceController !== "undefined") {
                deviceController.generateTemplate(deviceType, savePath, isMetric)
            }
        }
    }

    DeviceExportDialog {
        id: exportDialog
        isChineseMode: root.isChineseMode

        onExportRequested: function(fileUrl, deviceType) {
            console.log("Export requested:", fileUrl, deviceType)
            if (typeof deviceController !== "undefined") {
                deviceController.exportDevices(fileUrl, deviceType)
            }

            // 显示导出进度提示
            busyIndicator.visible = true
            statusText.text = isChineseMode ? "正在导出..." : "Exporting..."
        }
    }

    // 连接控制器信号
    Connections {
        target: deviceController
        enabled: deviceController !== undefined
        function onSelectedDeviceChanged() {
           console.log("QML收到selectedDevice:", JSON.stringify(deviceController.selectedDevice))
       }

        function onDeviceSaved(success, message) {
            showMessage(message, !success)
            if (success) {
                addEditDialog.close()
            }
        }

        function onDeviceDeleted(success, message) {
            showMessage(message, !success)
        }

        function onImportCompleted(success, message, successCount, errorCount) {
            showMessage(message, !success)
            if (success) {
                importDialog.close()
            }
        }

        function onExportCompleted(success, filePath) {
            if (success) {
                showMessage(isChineseMode ? "导出成功" : "Export successful", false)
                exportDialog.close()
            } else {
                showMessage(isChineseMode ? "导出失败" : "Export failed", true)
            }
        }

        function onErrorOccurred(errorMessage) {
            showMessage(errorMessage, true)
        }
        function onTemplateGenerated(filePath) {
            showMessage(isChineseMode ? "模板下载成功" : "Template downloaded successfully", false)
        }

        function onTemplateGenerationFailed(errorMsg) {
            showMessage(isChineseMode ? "模板生成失败: " + errorMsg : "Template generation failed: " + errorMsg, true)
        }
    }

    // 消息提示
    Rectangle {
        id: messageBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        width: Math.min(messageText.width + 40, 400)
        height: 40
        radius: 20
        color: "#333"
        visible: false
        z: 200

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

    // 辅助函数
    function showMessage(msg, isError) {
        messageText.text = msg
        messageBar.color = isError ? "#f44336" : "#4caf50"
        messageBar.visible = true
        messageTimer.restart()
    }
}
