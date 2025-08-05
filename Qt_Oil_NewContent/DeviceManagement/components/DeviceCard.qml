import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../Common/Components" as CommonComponents

Rectangle {
    id: root

    // 🔥 修复：使用单独的属性而不是 deviceData 对象
    property int deviceId: 0
    property string deviceType: "pump"
    property string manufacturer: ""
    property string deviceModel: ""  // 注意：不能使用 model 作为属性名
    property string serialNumber: ""
    property string status: "active"
    property string description: ""
    property string createdAt: ""
    property string details: "{}"

    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : true
    property bool selectionMode: false
    property bool isSelected: false

    signal clicked()
    signal editClicked()
    signal deleteClicked()

    width: parent.width
    height: 120
    radius: 8
    color: {
        if (isSelected) return "#E3F2FD"
        if (mouseArea.containsMouse) return "#F5F5F5"
        return "#FFFFFF"
    }
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? "#1976D2" : "#E0E0E0"

    Behavior on color {
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
        anchors.margins: 16
        spacing: 16

        // 🔥 批量选择模式的复选框
        CheckBox {
            visible: selectionMode
            checked: isSelected
            onCheckedChanged: {
                if (checked !== isSelected) {
                    root.clicked()
                }
            }
        }

        // 设备图标
        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 8
            color: getTypeColor()

            Text {
                anchors.centerIn: parent
                text: getTypeIcon()
                font.pixelSize: 24
                color: "white"
            }
        }

        // 设备信息
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: deviceModel || "Unknown Model"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#1976D2"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    text: getTypeLabel()
                    font.pixelSize: 12
                    color: "#666"
                    // background: Rectangle {
                    //     color: "#F0F0F0"
                    //     radius: 4
                    //     anchors.fill: parent
                    //     anchors.margins: -4
                    // }
                }
            }

            Text {
                text: manufacturer || "Unknown Manufacturer"
                font.pixelSize: 12
                color: "#666"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: getStatusColor()
                }

                Text {
                    text: getStatusText()
                    font.pixelSize: 12
                    color: "#666"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: serialNumber || "N/A"
                    font.pixelSize: 10
                    color: "#999"
                }
            }
        }

        // 操作按钮
        Row {
            visible: !selectionMode
            spacing: 8

            Button {
                text: "✏️"
                flat: true
                width: 36
                height: 36
                onClicked: root.editClicked()
                ToolTip.text: isChineseMode ? "编辑" : "Edit"
                ToolTip.visible: hovered

                background: Rectangle {
                    color: parent.hovered ? "#E0E0E0" : "transparent"
                    radius: 4
                }
            }

            Button {
                text: "🗑️"
                flat: true
                width: 36
                height: 36
                onClicked: root.deleteClicked()
                ToolTip.text: isChineseMode ? "删除" : "Delete"
                ToolTip.visible: hovered

                background: Rectangle {
                    color: parent.hovered ? "#FFEBEE" : "transparent"
                    radius: 4
                }
            }
        }
    }

    // 🔥 辅助函数
    function getTypeIcon() {
        switch(deviceType.toLowerCase()) {
            case 'pump': return "⚙️"
            case 'motor': return "⚡"
            case 'protector': return "🛡️"
            case 'separator': return "🔄"
            default: return "❓"
        }
    }

    function getTypeColor() {
        switch(deviceType.toLowerCase()) {
            case 'pump': return "#2196F3"
            case 'motor': return "#4CAF50"
            case 'protector': return "#FF9800"
            case 'separator': return "#9C27B0"
            default: return "#757575"
        }
    }

    function getTypeLabel() {
        if (isChineseMode) {
            switch(deviceType.toLowerCase()) {
                case 'pump': return "泵设备"
                case 'motor': return "电机"
                case 'protector': return "保护器"
                case 'separator': return "分离器"
                default: return "未知"
            }
        } else {
            switch(deviceType.toLowerCase()) {
                case 'pump': return "Pump"
                case 'motor': return "Motor"
                case 'protector': return "Protector"
                case 'separator': return "Separator"
                default: return "Unknown"
            }
        }
    }

    function getStatusColor() {
        switch(status.toLowerCase()) {
            case "active": return "#4CAF50"
            case "maintenance": return "#FF9800"
            case "inactive": return "#F44336"
            default: return "#999999"
        }
    }

    function getStatusText() {
        if (isChineseMode) {
            switch(status.toLowerCase()) {
                case "active": return "正常"
                case "maintenance": return "维护中"
                case "inactive": return "停用"
                default: return status
            }
        } else {
            return status.charAt(0).toUpperCase() + status.slice(1)
        }
    }
}
