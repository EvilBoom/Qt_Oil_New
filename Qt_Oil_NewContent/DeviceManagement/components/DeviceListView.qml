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
        console.log("=== DeviceListView 初始化完成 ===")
        console.log("Model:", model)
        console.log("Count:", count)

        // 🔥 如果有数据，打印第一条的详细信息
        if (model && count > 0) {
            console.log("=== 第一条数据的角色访问测试 ===")
            console.log("deviceId:", model.data(model.index(0, 0), model.IdRole))
            console.log("deviceModel:", model.data(model.index(0, 0), model.ModelRole))
            console.log("manufacturer:", model.data(model.index(0, 0), model.ManufacturerRole))
            console.log("deviceType:", model.data(model.index(0, 0), model.TypeRole))
        }
    }

    delegate: DeviceCard {
        width: ListView.view.width

        // 🔥 添加详细的调试信息
        property var debugInfo: {
            console.log("=== DeviceCard 数据绑定调试 ===")
            console.log("原始 model.deviceId:", model.deviceId)
            console.log("原始 model.deviceModel:", model.deviceModel)
            console.log("原始 model.manufacturer:", model.manufacturer)
            console.log("原始 model.deviceType:", model.deviceType)
            console.log("原始 model.status:", model.status)
            console.log("原始 model.serialNumber:", model.serialNumber)
            console.log("===============================")
        }

        // 使用正确的角色名访问数据
        // 🔥 修复数据访问方式
        deviceId: {
            var id = model.deviceId
            return (typeof id === 'number') ? id : (parseInt(id) || 0)
        }

        deviceType: {
            var type = model.deviceType
            return (typeof type === 'string') ? type : (type ? type.toString() : "pump")
        }

        manufacturer: {
            var mfr = model.manufacturer
            return (typeof mfr === 'string') ? mfr : (mfr ? mfr.toString() : "")
        }

        deviceModel: {
            var mdl = model.deviceModel
            console.log("原始 deviceModel 值:", mdl, "类型:", typeof mdl)
            return (typeof mdl === 'string') ? mdl : (mdl ? mdl.toString() : "")
        }

        serialNumber: {
            var sn = model.serialNumber
            return (typeof sn === 'string') ? sn : (sn ? sn.toString() : "")
        }

        status: {
            var st = model.status
            return (typeof st === 'string') ? st : (st ? st.toString() : "active")
        }

        description: {
            var desc = model.description
            return (typeof desc === 'string') ? desc : (desc ? desc.toString() : "")
        }

        createdAt: {
            var ca = model.createdAt
            return (typeof ca === 'string') ? ca : (ca ? ca.toString() : "")
        }

        details: {
            var det = model.details
            return (typeof det === 'string') ? det : (det ? det.toString() : "{}")
        }

        isChineseMode: listView.isChineseMode
        selectionMode: listView.batchSelectionMode
        isSelected: listView.selectedIds.indexOf(model.deviceId) !== -1

        Component.onCompleted: {
            console.log("DeviceCard created - 最终属性值:")
            console.log("  deviceId:", deviceId)
            console.log("  deviceModel:", deviceModel)
            console.log("  manufacturer:", manufacturer)
            console.log("  deviceType:", deviceType)
        }

        onClicked: {
            console.log("DeviceCard clicked:", model.deviceId)
            listView.deviceClicked(model.deviceId)
        }
        onEditClicked: {
            console.log("DeviceCard edit clicked:", model.deviceId)
            listView.editRequested(model.deviceId)
        }
        onDeleteClicked: {
            console.log("DeviceCard delete clicked:", model.deviceId)
            listView.deleteRequested(model.deviceId)
        }
    }

    // 空状态提示
    Rectangle {
        anchors.fill: parent
        visible: listView.count === 0 && deviceController && !deviceController.loading
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "📦"
                font.pixelSize: 48
                color: "#ccc"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: isChineseMode ? "暂无设备数据" : "No device data"
                font.pixelSize: 16
                color: "#999"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Button {
                text: isChineseMode ? "重新加载" : "Reload"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    if (deviceController) {
                        deviceController.loadDevices()
                    }
                }
            }
        }
    }

    // 加载状态提示
    BusyIndicator {
        anchors.centerIn: parent
        visible: deviceController && deviceController.loading
        running: visible

        Text {
            anchors.top: parent.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            text: isChineseMode ? "正在加载..." : "Loading..."
            color: "#666"
            font.pixelSize: 12
        }
    }
}
