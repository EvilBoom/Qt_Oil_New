import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // 属性定义
    property string iconText: ""
    property string title: ""
    property bool collapsed: false
    property var subItemsList: []
    property bool expanded: false

    // 信号定义
    signal subItemClicked(string action)
    signal mainItemClicked()

    width: parent ? parent.width : 240
    height: expanded ? 48 + (subItemsList.length * 40) : 48
    color: "transparent"

    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 主菜单项
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: mainMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: collapsed ? 10 : 20
                anchors.rightMargin: 20
                spacing: 12

                Text {
                    text: iconText
                    font.pixelSize: 20
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: title
                    color: "white"
                    font.pixelSize: 14
                    visible: !collapsed
                    opacity: collapsed ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                Text {
                    text: expanded ? "▼" : "▶"
                    color: Qt.rgba(255, 255, 255, 0.6)
                    font.pixelSize: 12
                    visible: !collapsed && subItemsList.length > 0
                }
            }

            MouseArea {
                id: mainMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (subItemsList.length > 0) {
                        expanded = !expanded
                    } else {
                        // 如果没有子项，发出主项点击信号
                        mainItemClicked()
                    }
                }
                
                onDoubleClicked: {
                    // 双击主项时发出主项点击信号
                    mainItemClicked()
                }
            }
        }

        // 子菜单项
        Column {
            Layout.fillWidth: true
            visible: expanded && !collapsed

            Repeater {
                model: subItemsList

                Rectangle {
                    width: parent.width
                    height: 40
                    color: subMouseArea.containsMouse ? Qt.rgba(0, 0, 0, 0.2) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 56
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.title
                        color: Qt.rgba(255, 255, 255, 0.8)
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: subMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.subItemClicked(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
