import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: root

    property string icon: ""
    property bool isPrimary: false

    height: 40

    background: Rectangle {
        color: root.isPrimary ? "#4a90e2" : "#e8f0fe"
        radius: 8

        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.hovered ? "#000000" : "transparent"
            opacity: 0.1
        }
    }

    contentItem: RowLayout {
        spacing: 8

        Text {
            text: root.icon
            font.pixelSize: 16
            color: root.isPrimary ? "white" : "#4a90e2"
        }

        Text {
            text: root.text
            font.pixelSize: 14
            color: root.isPrimary ? "white" : "#4a90e2"
        }
    }
}
