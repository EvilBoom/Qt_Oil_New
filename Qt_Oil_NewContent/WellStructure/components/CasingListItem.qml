import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

ItemDelegate {
    id: root

    property bool isChineseMode: true

    signal editClicked(var casingData)
    signal deleteClicked(int casingId)

    height: 80

    background: Rectangle {
        color: root.hovered ? "#f5f7fa" : "white"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#e0e0e0"
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // 套管图标
        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 8
            color: {
                switch(model.casing_type) {
                    case "表层套管":
                    case "Surface Casing":
                        return "#4CAF50"
                    case "技术套管":
                    case "Intermediate Casing":
                        return "#2196F3"
                    case "生产套管":
                    case "Production Casing":
                        return "#FF9800"
                    default:
                        return "#9E9E9E"
                }
            }

            Text {
                anchors.centerIn: parent
                text: "◉"
                font.pixelSize: 24
                color: "white"
            }
        }

        // 套管信息
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                spacing: 10

                Label {
                    text: model.casing_type || (isChineseMode ? "未知类型" : "Unknown Type")
                    font.pixelSize: 16
                    font.bold: true
                    color: "#333"
                }

                Label {
                    text: model.casing_size || ""
                    font.pixelSize: 14
                    color: "#666"
                }
            }

            RowLayout {
                spacing: 20

                Label {
                    text: isChineseMode ?
                        `深度: ${model.top_depth || 0} - ${model.bottom_depth || 0} ft` :
                        `Depth: ${model.top_depth || 0} - ${model.bottom_depth || 0} ft`
                    font.pixelSize: 13
                    color: "#666"
                }

                Label {
                    text: isChineseMode ?
                        `内径/外径: ${model.inner_diameter || 0}/${model.outer_diameter || 0} mm` :
                        `ID/OD: ${model.inner_diameter || 0}/${model.outer_diameter || 0} mm`
                    font.pixelSize: 13
                    color: "#666"
                }
            }
        }

        // 操作按钮
        RowLayout {
            spacing: 8

            Button {
                text: isChineseMode ? "编辑" : "Edit"
                flat: true

                onClicked: {
                    root.editClicked(model)
                }
            }

            Button {
                text: isChineseMode ? "删除" : "Delete"
                flat: true

                contentItem: Text {
                    text: parent.text
                    color: "#f44336"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    root.deleteClicked(model.id)
                }
            }
        }
    }
}
