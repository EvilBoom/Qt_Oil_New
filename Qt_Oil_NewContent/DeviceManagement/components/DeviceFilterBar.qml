import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root

    // 属性
    property bool isChineseMode: true

    // 信号
    signal typeFilterChanged(string type)
    signal statusFilterChanged(string status)
    signal searchTextChanged(string text)

    color: "#f8f9fa"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 15
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        spacing: 20

        // 设备类型筛选
        Column {
            spacing: 5

            Label {
                text: isChineseMode ? "设备类型" : "Device Type"
                font.pixelSize: 12
                color: "#666"
            }

            ComboBox {
                id: typeCombo
                width: 150

                model: ListModel {
                    ListElement { value: "all"; label: "全部类型"; label_en: "All Types" }
                    ListElement { value: "pump"; label: "泵设备"; label_en: "Pump" }
                    ListElement { value: "motor"; label: "电机"; label_en: "Motor" }
                    ListElement { value: "protector"; label: "保护器"; label_en: "Protector" }
                    ListElement { value: "separator"; label: "分离器"; label_en: "Separator" }
                }

                textRole: isChineseMode ? "label" : "label_en"
                valueRole: "value"

                onCurrentValueChanged: {
                    root.typeFilterChanged(currentValue)
                }
            }
        }

        // 状态筛选
        Column {
            spacing: 5

            Label {
                text: isChineseMode ? "设备状态" : "Device Status"
                font.pixelSize: 12
                color: "#666"
            }

            ComboBox {
                id: statusCombo
                width: 120

                model: ListModel {
                    ListElement { value: "all"; label: "全部状态"; label_en: "All Status" }
                    ListElement { value: "active"; label: "正常"; label_en: "Active" }
                    ListElement { value: "inactive"; label: "停用"; label_en: "Inactive" }
                    ListElement { value: "maintenance"; label: "维护中"; label_en: "Maintenance" }
                }

                textRole: isChineseMode ? "label" : "label_en"
                valueRole: "value"

                onCurrentValueChanged: {
                    root.statusFilterChanged(currentValue)
                }
            }
        }

        Item { Layout.fillWidth: true }

        // 搜索框
        Column {
            spacing: 5

            Label {
                text: isChineseMode ? "搜索" : "Search"
                font.pixelSize: 12
                color: "#666"
            }

            TextField {
                id: searchField
                width: 250
                placeholderText: isChineseMode ?
                                "搜索型号、制造商、序列号..." :
                                "Search model, manufacturer, serial..."

                leftPadding: 40

                // 搜索图标
                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🔍"
                    font.pixelSize: 16
                    color: "#999"
                }

                // 清除按钮
                Button {
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    flat: true
                    visible: searchField.text.length > 0

                    text: "✕"
                    font.pixelSize: 14

                    onClicked: {
                        searchField.clear()
                        searchField.forceActiveFocus()
                    }
                }

                onTextChanged: {
                    root.searchTextChanged(text)
                }
            }
        }

        // 重置按钮
        Button {
            text: isChineseMode ? "重置" : "Reset"
            flat: true

            onClicked: {
                typeCombo.currentIndex = 0
                statusCombo.currentIndex = 0
                searchField.clear()
            }
        }
    }
}
