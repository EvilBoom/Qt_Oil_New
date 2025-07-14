import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    // 属性
    property int deviceId
    property string deviceType 
    property string manufacturer
    property string deviceModel
    property string serialNumber
    property string status
    property string description
    property string createdAt
    property string details

    property bool isChineseMode: true
    property bool selectionMode: false
    property bool isSelected: false

    // 信号
    signal clicked()
    signal editClicked()
    signal deleteClicked()

    height: 120
    radius: 8
    color: mouseArea.containsMouse ? "#f8f9fa" : "white"
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.color(Material.Blue) : "#e0e0e0"

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // 选择框（批量选择模式）
        CheckBox {
            visible: selectionMode
            checked: isSelected
            onToggled: root.clicked()
        }

        // 设备图标
        Rectangle {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 8
            color: getTypeColor(deviceType)

            Label {
                anchors.centerIn: parent
                text: getTypeIcon(deviceType)
                font.pixelSize: 28
                color: "white"
            }
        }

        // 设备信息
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            // 第一行：型号和状态
            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: deviceModel
                    font.pixelSize: 16
                    font.bold: true
                    color: "#333"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // 状态标签
                Rectangle {
                    width: statusLabel.width + 16
                    height: 24
                    radius: 12
                    color: getStatusColor(status)

                    Label {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: getStatusText(status)
                        font.pixelSize: 12
                        color: "white"
                    }
                }
            }

            // 第二行：制造商和序列号
            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Label {
                    text: manufacturer
                    font.pixelSize: 14
                    color: "#666"
                }

                Label {
                    text: serialNumber ? `SN: ${serialNumber}` : ""
                    font.pixelSize: 14
                    color: "#666"
                }

                Label {
                    text: getTypeText(deviceType)
                    font.pixelSize: 14
                    color: "#666"
                }
            }

            // 第三行：描述或详细参数
            Label {
                Layout.fillWidth: true
                text: getDeviceDetails()
                font.pixelSize: 12
                color: "#999"
                elide: Text.ElideRight
            }
        }

        // 操作按钮
        Row {
            spacing: 5
            visible: !selectionMode

            Button {
                width: 36
                height: 36
                flat: true

                contentItem: Label {
                    text: "✏️"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                ToolTip.text: isChineseMode ? "编辑" : "Edit"
                ToolTip.visible: hovered

                onClicked: {
                    root.editClicked()
                }
            }

            Button {
                width: 36
                height: 36
                flat: true

                contentItem: Label {
                    text: "🗑️"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                ToolTip.text: isChineseMode ? "删除" : "Delete"
                ToolTip.visible: hovered

                onClicked: {
                    root.deleteClicked()
                }
            }
        }
    }

    // 辅助函数
    function getTypeIcon(type) {
        switch(type) {
            case "pump": return "⚙️"
            case "motor": return "🔌"
            case "protector": return "🛡️"
            case "separator": return "🔧"
            default: return "📦"
        }
    }

    function getTypeColor(type) {
        switch(type) {
            case "pump": return "#4a90e2"
            case "motor": return "#f5a623"
            case "protector": return "#7ed321"
            case "separator": return "#bd10e0"
            default: return "#999"
        }
    }

    function getTypeText(type) {
        if (isChineseMode) {
            switch(type) {
                case "pump": return "潜油离心泵"
                case "motor": return "电机"
                case "protector": return "保护器"
                case "separator": return "分离器"
                default: return "未知类型"
            }
        } else {
            switch(type) {
                case "pump": return "Centrifugal Pump"
                case "motor": return "Motor"
                case "protector": return "Protector"
                case "separator": return "Separator"
                default: return "Unknown Type"
            }
        }
    }

    function getStatusColor(status) {
        switch(status) {
            case "active": return "#52c41a"
            case "inactive": return "#ff4d4f"
            case "maintenance": return "#faad14"
            default: return "#999"
        }
    }

    function getStatusText(status) {
        if (isChineseMode) {
            switch(status) {
                case "active": return "正常"
                case "inactive": return "停用"
                case "maintenance": return "维护中"
                default: return "未知"
            }
        } else {
            switch(status) {
                case "active": return "Active"
                case "inactive": return "Inactive"
                case "maintenance": return "Maintenance"
                default: return "Unknown"
            }
        }
    }
    //Component.onCompleted: {
        //console.log("DeviceCard model keys:", Object.keys(model))
       // console.log("DeviceCard model.deviceId:", deviceId)
   //}

    function getDeviceDetails() {
        if (!details || details === "{}") {
            return description || (isChineseMode ? "暂无描述" : "No description")
        }

        try {
            var detailsObj = JSON.parse(details)
            var info = []

            switch(deviceType) {
                case "pump":
                    if (detailsObj.displacement_min && detailsObj.displacement_max) {
                        info.push(`${isChineseMode ? "排量" : "Displacement"}: ${detailsObj.displacement_min}-${detailsObj.displacement_max} m³/d`)
                    }
                    if (detailsObj.single_stage_head) {
                        info.push(`${isChineseMode ? "扬程" : "Head"}: ${detailsObj.single_stage_head} m`)
                    }
                    break

                case "motor":
                    if (detailsObj.motor_type) {
                        info.push(`${isChineseMode ? "类型" : "Type"}: ${detailsObj.motor_type}`)
                    }
                    if (detailsObj.frequency_params && detailsObj.frequency_params.length > 0) {
                        var freqs = detailsObj.frequency_params.map(fp => fp.frequency + "Hz").join(", ")
                        info.push(`${isChineseMode ? "频率" : "Frequency"}: ${freqs}`)
                    }
                    break

                case "protector":
                    if (detailsObj.thrust_capacity) {
                        info.push(`${isChineseMode ? "推力" : "Thrust"}: ${detailsObj.thrust_capacity} kN`)
                    }
                    if (detailsObj.max_temperature) {
                        info.push(`${isChineseMode ? "最高温度" : "Max Temp"}: ${detailsObj.max_temperature}°C`)
                    }
                    break

                case "separator":
                    if (detailsObj.separation_efficiency) {
                        info.push(`${isChineseMode ? "效率" : "Efficiency"}: ${detailsObj.separation_efficiency}%`)
                    }
                    break
            }

            return info.length > 0 ? info.join(" | ") : (description || (isChineseMode ? "暂无详情" : "No details"))

        } catch(e) {
            return description || (isChineseMode ? "暂无描述" : "No description")
        }
    }
}
