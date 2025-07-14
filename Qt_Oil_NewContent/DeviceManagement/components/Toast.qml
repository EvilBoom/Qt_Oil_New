import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Rectangle {
    id: root

    property string type: "info"  // info, success, warning, error
    property int duration: 3000

    width: messageText.width + 60
    height: 48
    radius: 24

    color: {
        switch(type) {
            case "success": return "#52c41a"
            case "warning": return "#faad14"
            case "error": return "#ff4d4f"
            default: return "#1890ff"
        }
    }

    opacity: 0
    visible: opacity > 0

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 100

    // 图标
    Label {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        text: {
            switch(root.type) {
                case "success": return "✓"
                case "warning": return "!"
                case "error": return "✕"
                default: return "i"
            }
        }

        font.pixelSize: 18
        font.bold: true
        color: "white"
    }

    // 消息文本
    Label {
        id: messageText
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter

        color: "white"
        font.pixelSize: 14
    }

    // 显示动画
    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 200
        }

        NumberAnimation {
            target: root
            property: "anchors.bottomMargin"
            from: 50
            to: 100
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    // 隐藏动画
    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0
            duration: 200
        }

        NumberAnimation {
            target: root
            property: "anchors.bottomMargin"
            from: 100
            to: 50
            duration: 200
            easing.type: Easing.InQuad
        }
    }

    // 自动隐藏定时器
    Timer {
        id: hideTimer
        interval: root.duration
        onTriggered: hideAnimation.start()
    }

    // 公共方法
    function show(message) {
        messageText.text = message
        showAnimation.start()
        hideTimer.restart()
    }
}
