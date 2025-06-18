import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string value: "0"
    property string label: ""

    Layout.fillWidth: true
    height: 100
    radius: 12
    color: "white"

    // 简单阴影
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.leftMargin: 2
        radius: parent.radius
        color: "#10000000"
        z: -1
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.value
            font.pixelSize: 32
            font.bold: true
            color: "#2c3e50"
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            font.pixelSize: 14
            color: "#666"
        }
    }
}
