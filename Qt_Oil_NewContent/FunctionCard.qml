import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: ""
    property string description: ""
    property string iconText: ""
    property string gradientColor1: "#667eea"
    property string gradientColor2: "#764ba2"

    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 160
    radius: 12
    color: "white"

    // 阴影效果
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: cardMouseArea.containsMouse ? 8 : 2
        anchors.leftMargin: cardMouseArea.containsMouse ? 8 : 2
        radius: parent.radius
        color: cardMouseArea.containsMouse ? "#20000000" : "#10000000"
        z: -1

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 200 }
        }
        Behavior on anchors.leftMargin {
            NumberAnimation { duration: 200 }
        }
    }

    // 悬浮效果
    transform: Translate {
        y: cardMouseArea.containsMouse ? -4 : 0

        Behavior on y {
            NumberAnimation { duration: 200 }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Rectangle {
            width: 48
            height: 48
            radius: 12

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.gradientColor1 }
                GradientStop { position: 1.0; color: root.gradientColor2 }
            }

            Text {
                anchors.centerIn: parent
                text: root.iconText
                font.pixelSize: 24
                color: "white"
            }
        }

        Text {
            text: root.title
            font.pixelSize: 18
            font.bold: true
            color: "#2c3e50"
        }

        Text {
            Layout.fillWidth: true
            text: root.description
            font.pixelSize: 14
            color: "#666"
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }

        Item { Layout.fillHeight: true }
    }

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }
}
