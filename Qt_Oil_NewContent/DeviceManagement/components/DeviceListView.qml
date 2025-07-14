import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

ListView {
    id: listView

    // 属性
    property bool isChineseMode: true
    property bool batchSelectionMode: false
    property var selectedIds: []

    // 信号
    signal deviceClicked(int deviceId)
    signal editRequested(int deviceId)
    signal deleteRequested(int deviceId)

    clip: true
    spacing: 10
    
    Component.onCompleted: {
        // console.log("DeviceListView model type:", typeof model, model)
    }
    
    delegate: DeviceCard {
        width: ListView.view.width
            // 使用 model.roleName 访问数据
        deviceId: model.deviceId || 0
        deviceType: model.deviceType || "pump"
        manufacturer: model.manufacturer || ""
        deviceModel: model.modelDevice || ""  // 注意：model 是特殊属性
        serialNumber: model.serialNumber || ""
        status: model.status || "active"
        description: model.description || ""
        createdAt: model.createdAt || ""
        details: model.details || "{}"
        
        // deviceId: deviceId
        // deviceType: (typeof deviceType === "string") ? deviceType : "pump"
        // manufacturer: (typeof manufacturer === "string") ? manufacturer : ""
        // deviceModel: (typeof model === "string") ? model : ""
        // serialNumber: (typeof serialNumber === "string") ? serialNumber : ""
        // status: (typeof status === "string") ? status : "active"
        // description: (typeof description === "string") ? description : ""
        // createdAt: (typeof createdAt === "string") ? createdAt : ""
        // details: (typeof details === "string") ? details : "{}"

        isChineseMode: listView.isChineseMode
        selectionMode: listView.batchSelectionMode
        isSelected: listView.selectedIds.indexOf(deviceId) !== -1
        
        Component.onCompleted: {
            console.log("DeviceCard:", deviceId, deviceType, model)
        }

        onClicked: listView.deviceClicked(model.deviceId)
        onEditClicked: listView.editRequested(model.deviceId)
        onDeleteClicked: listView.deleteRequested(model.deviceId)
    }

    // 空状态提示
    Label {
        anchors.centerIn: parent
        visible: listView.count === 0
        text: isChineseMode ? "暂无设备数据" : "No device data"
        font.pixelSize: 16
        color: "#999"
    }
}
