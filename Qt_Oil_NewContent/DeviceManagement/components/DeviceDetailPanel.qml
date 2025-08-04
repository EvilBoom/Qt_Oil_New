import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    // 属性
    property var deviceData: ({})
    property bool isChineseMode: true

    // 信号
    signal editRequested()
    signal deleteRequested()

    color: "white"
    radius: 8
    Component.onCompleted: {
    console.log("DeviceDetailPanel.deviceData:", JSON.stringify(deviceData))
   }
    // 阴影效果
    // layer.enabled: true
    // layer.effect: DropShadow {
    //     radius: 8
    //     samples: 16
    //     color: "#20000000"
    //     verticalOffset: 2
    // }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 0

            // 头部
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                color: getTypeColor(deviceData.device_type || "")

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20

                    // 设备图标
                    Rectangle {
                        Layout.preferredWidth: 50
                        Layout.preferredHeight: 50
                        radius: 25
                        color: Qt.darker(parent.parent.color, 1.2)

                        Label {
                            anchors.centerIn: parent
                            text: getTypeIcon(deviceData.device_type || "")
                            font.pixelSize: 24
                            color: "white"
                        }
                    }

                    // 设备型号
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label {
                            text: deviceData.model || ""
                            font.pixelSize: 18
                            font.bold: true
                            color: "white"
                        }

                        Label {
                            text: getTypeText(deviceData.device_type || "")
                            font.pixelSize: 14
                            color: Qt.rgba(255, 255, 255, 0.8)
                        }
                    }

                    // 操作按钮
                    Row {
                        spacing: 10

                        Button {
                            text: isChineseMode ? "编辑" : "Edit"
                            Material.background: "white"
                            Material.foreground: getTypeColor(deviceData.device_type || "")

                            onClicked: root.editRequested()
                        }

                        Button {
                            text: isChineseMode ? "删除" : "Delete"
                            flat: true
                            Material.foreground: "white"

                            onClicked: root.deleteRequested()
                        }
                    }
                }
            }

            // 基本信息区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: infoColumn.height + 40
                color: "#f8f9fa"

                Column {
                    id: infoColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 15

                    Label {
                        text: isChineseMode ? "基本信息" : "Basic Information"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#333"
                    }

                    Grid {
                        columns: 2
                        columnSpacing: 40
                        rowSpacing: 12
                        width: parent.width

                        // 制造商
                        Label {
                            text: isChineseMode ? "制造商：" : "Manufacturer:"
                            font.pixelSize: 14
                            color: "#666"
                        }
                        Label {
                            text: deviceData.manufacturer || "-"
                            font.pixelSize: 14
                            color: "#333"
                        }

                        // 序列号
                        Label {
                            text: isChineseMode ? "序列号：" : "Serial Number:"
                            font.pixelSize: 14
                            color: "#666"
                        }
                        Label {
                            text: deviceData.serial_number || "-"
                            font.pixelSize: 14
                            color: "#333"
                        }

                        // 状态
                        Label {
                            text: isChineseMode ? "状态：" : "Status:"
                            font.pixelSize: 14
                            color: "#666"
                        }
                        Rectangle {
                            width: statusText.width + 16
                            height: 24
                            radius: 12
                            color: getStatusColor(deviceData.status || "active")

                            Label {
                                id: statusText
                                anchors.centerIn: parent
                                text: getStatusText(deviceData.status || "active")
                                font.pixelSize: 12
                                color: "white"
                            }
                        }

                        // 创建时间
                        Label {
                            text: isChineseMode ? "创建时间：" : "Created At:"
                            font.pixelSize: 14
                            color: "#666"
                        }
                        Label {
                            text: formatDateTime(deviceData.created_at || "")
                            font.pixelSize: 14
                            color: "#333"
                        }
                    }

                    // 描述
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: deviceData.description

                        Label {
                            text: isChineseMode ? "描述：" : "Description:"
                            font.pixelSize: 14
                            color: "#666"
                        }
                        Label {
                            width: parent.width
                            text: deviceData.description || ""
                            font.pixelSize: 14
                            color: "#333"
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // 详细参数区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: detailsColumn.height + 40
                Layout.topMargin: 20
                color: "transparent"

                Column {
                    id: detailsColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 15

                    Label {
                        text: isChineseMode ? "技术参数" : "Technical Parameters"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#333"
                    }

                    // 根据设备类型显示不同参数
                    Loader {
                        width: parent.width
                        sourceComponent: {
                            switch(deviceData.device_type) {
                                case "pump": return pumpDetailsComponent
                                case "motor": return motorDetailsComponent
                                case "protector": return protectorDetailsComponent
                                case "separator": return separatorDetailsComponent
                                default: return null
                            }
                        }
                    }
                }
            }

            // 底部占位
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
            }
        }
    }

    // 潜油离心泵详情组件
    Component {
        id: pumpDetailsComponent

        Grid {
            columns: 2
            columnSpacing: 40
            rowSpacing: 12
            width: parent.width

            property var details: deviceData.pump_details || {}

            // 叶轮型号
            Label {
                text: isChineseMode ? "叶轮型号：" : "Impeller Model:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.impeller_model || "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 排量范围
            Label {
                text: isChineseMode ? "排量范围：" : "Displacement Range:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.displacement_min && details.displacement_max ?
                      `${details.displacement_min} - ${details.displacement_max} m³/d` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 单级扬程
            Label {
                text: isChineseMode ? "单级扬程：" : "Single Stage Head:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.single_stage_head ? `${details.single_stage_head} m` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 单级功率
            Label {
                text: isChineseMode ? "单级功率：" : "Single Stage Power:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.single_stage_power ? `${details.single_stage_power} kW` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 轴径
            Label {
                text: isChineseMode ? "轴径：" : "Shaft Diameter:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.shaft_diameter ? `${details.shaft_diameter} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 安装高度
            Label {
                text: isChineseMode ? "安装高度：" : "Mounting Height:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.mounting_height ? `${details.mounting_height} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 外径
            Label {
                text: isChineseMode ? "外径：" : "Outside Diameter:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.outside_diameter ? `${details.outside_diameter} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 最大级数
            Label {
                text: isChineseMode ? "最大级数：" : "Max Stages:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.max_stages || "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 效率
            Label {
                text: isChineseMode ? "效率：" : "Efficiency:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.efficiency ? `${details.efficiency}%` : "-"
                font.pixelSize: 14
                color: "#333"
            }
        }
    }

    // 电机详情组件
    Component {
        id: motorDetailsComponent

        Column {
            width: parent.width
            spacing: 20

            property var details: deviceData.motor_details || {}

            // 基本参数
            Grid {
                columns: 2
                columnSpacing: 40
                rowSpacing: 12
                width: parent.width

                // 电机类型
                Label {
                    text: isChineseMode ? "电机类型：" : "Motor Type:"
                    font.pixelSize: 14
                    color: "#666"
                }
                Label {
                    text: details.motor_type || "-"
                    font.pixelSize: 14
                    color: "#333"
                }

                // 外径
                Label {
                    text: isChineseMode ? "外径：" : "Outside Diameter:"
                    font.pixelSize: 14
                    color: "#666"
                }
                Label {
                    text: details.outside_diameter ? `${details.outside_diameter} mm` : "-"
                    font.pixelSize: 14
                    color: "#333"
                }

                // 长度
                Label {
                    text: isChineseMode ? "长度：" : "Length:"
                    font.pixelSize: 14
                    color: "#666"
                }
                Label {
                    text: details.length ? `${details.length} mm` : "-"
                    font.pixelSize: 14
                    color: "#333"
                }

                // 重量
                Label {
                    text: isChineseMode ? "重量：" : "Weight:"
                    font.pixelSize: 14
                    color: "#666"
                }
                Label {
                    text: details.weight ? `${details.weight} kg` : "-"
                    font.pixelSize: 14
                    color: "#333"
                }

                // 绝缘等级
                Label {
                    text: isChineseMode ? "绝缘等级：" : "Insulation Class:"
                    font.pixelSize: 14
                    color: "#666"
                }
                Label {
                    text: details.insulation_class || "-"
                    font.pixelSize: 14
                    color: "#333"
                }

                // 防护等级
                Label {
                    text: isChineseMode ? "防护等级：" : "Protection Class:"
                    font.pixelSize: 14
                    color: "#666"
                }
                Label {
                    text: details.protection_class || "-"
                    font.pixelSize: 14
                    color: "#333"
                }
            }

            // 频率参数
            Column {
                width: parent.width
                spacing: 10
                visible: details.frequency_params && details.frequency_params.length > 0

                Label {
                    text: isChineseMode ? "频率参数：" : "Frequency Parameters:"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#666"
                }

                Repeater {
                    model: details.frequency_params || []

                    Rectangle {
                        width: parent.width
                        height: freqGrid.height + 20
                        color: "#f8f9fa"
                        radius: 4

                        Grid {
                            id: freqGrid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            columns: 2
                            columnSpacing: 20
                            rowSpacing: 8

                            Label {
                                text: isChineseMode ? "频率：" : "Frequency:"
                                font.pixelSize: 13
                                color: "#666"
                            }
                            Label {
                                text: `${modelData.frequency} Hz`
                                font.pixelSize: 13
                                color: "#333"
                                font.bold: true
                            }

                            Label {
                                text: isChineseMode ? "功率：" : "Power:"
                                font.pixelSize: 13
                                color: "#666"
                            }
                            Label {
                                text: modelData.power ? `${modelData.power} kW` : "-"
                                font.pixelSize: 13
                                color: "#333"
                            }

                            Label {
                                text: isChineseMode ? "电压：" : "Voltage:"
                                font.pixelSize: 13
                                color: "#666"
                            }
                            Label {
                                text: modelData.voltage ? `${modelData.voltage} V` : "-"
                                font.pixelSize: 13
                                color: "#333"
                            }

                            Label {
                                text: isChineseMode ? "电流：" : "Current:"
                                font.pixelSize: 13
                                color: "#666"
                            }
                            Label {
                                text: modelData.current ? `${modelData.current} A` : "-"
                                font.pixelSize: 13
                                color: "#333"
                            }

                            Label {
                                text: isChineseMode ? "转速：" : "Speed:"
                                font.pixelSize: 13
                                color: "#666"
                            }
                            Label {
                                text: modelData.speed ? `${modelData.speed} rpm` : "-"
                                font.pixelSize: 13
                                color: "#333"
                            }
                        }
                    }
                }
            }
        }
    }

    // 保护器详情组件
    Component {
        id: protectorDetailsComponent

        Grid {
            columns: 2
            columnSpacing: 40
            rowSpacing: 12
            width: parent.width

            property var details: deviceData.protector_details || {}

            // 外径
            Label {
                text: isChineseMode ? "外径：" : "Outer Diameter:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.outer_diameter ? `${details.outer_diameter} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 长度
            Label {
                text: isChineseMode ? "长度：" : "Length:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.length ? `${details.length} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 重量
            Label {
                text: isChineseMode ? "重量：" : "Weight:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.weight ? `${details.weight} kg` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 推力承载能力
            Label {
                text: isChineseMode ? "推力承载：" : "Thrust Capacity:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.thrust_capacity ? `${details.thrust_capacity} kN` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 密封类型
            Label {
                text: isChineseMode ? "密封类型：" : "Seal Type:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.seal_type || "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 最高温度
            Label {
                text: isChineseMode ? "最高温度：" : "Max Temperature:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.max_temperature ? `${details.max_temperature}°C` : "-"
                font.pixelSize: 14
                color: "#333"
            }
        }
    }

    // 分离器详情组件
    Component {
        id: separatorDetailsComponent

        Grid {
            columns: 2
            columnSpacing: 40
            rowSpacing: 12
            width: parent.width

            property var details: deviceData.separator_details || {}

            // 外径
            Label {
                text: isChineseMode ? "外径：" : "Outer Diameter:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.outer_diameter ? `${details.outer_diameter} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 长度
            Label {
                text: isChineseMode ? "长度：" : "Length:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.length ? `${details.length} mm` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 重量
            Label {
                text: isChineseMode ? "重量：" : "Weight:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.weight ? `${details.weight} kg` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 分离效率
            Label {
                text: isChineseMode ? "分离效率：" : "Separation Efficiency:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.separation_efficiency ? `${details.separation_efficiency}%` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 气体处理能力
            Label {
                text: isChineseMode ? "气体处理能力：" : "Gas Handling Capacity:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.gas_handling_capacity ? `${details.gas_handling_capacity} m³/d` : "-"
                font.pixelSize: 14
                color: "#333"
            }

            // 液体处理能力
            Label {
                text: isChineseMode ? "液体处理能力：" : "Liquid Handling Capacity:"
                font.pixelSize: 14
                color: "#666"
            }
            Label {
                text: details.liquid_handling_capacity ? `${details.liquid_handling_capacity} m³/d` : "-"
                font.pixelSize: 14
                color: "#333"
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
                // 🔥 修改：从"潜油离心泵"改为"泵设备"
                case "pump": return "泵设备"
                case "motor": return "电机"
                case "protector": return "保护器"
                case "separator": return "分离器"
                default: return "未知类型"
            }
        } else {
            switch(type) {
                // 🔥 修改：从"Centrifugal Pump"改为"Pump"
                case "pump": return "Pump"
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

    function formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return "-"

        try {
            var date = new Date(dateTimeStr)
            return Qt.formatDateTime(date, "yyyy-MM-dd hh:mm:ss")
        } catch(e) {
            return dateTimeStr
        }
    }
}
