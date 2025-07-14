// Qt_Oil_NewContent/DeviceRecommendation/Components/CircularProgress.qml

import QtQuick
import QtQuick.Controls.Material

Item {
    id: root

    property real value: 0.0  // 0.0 to 1.0
    property color primaryColor: {
        if (value >= 0.8) return Material.color(Material.Green)
        if (value >= 0.6) return Material.color(Material.Orange)
        return Material.color(Material.Red)
    }
    property color backgroundColor: Material.dividerColor
    property int lineWidth: 3
    property bool showPercentage: true

    width: 50
    height: 50

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            var centerX = width / 2
            var centerY = height / 2
            var radius = Math.min(width, height) / 2 - lineWidth / 2

            ctx.clearRect(0, 0, width, height)

            // 背景圆环
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI)
            ctx.lineWidth = lineWidth
            ctx.strokeStyle = backgroundColor
            ctx.stroke()

            // 进度圆环
            if (value > 0) {
                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * value)
                ctx.lineWidth = lineWidth
                ctx.strokeStyle = primaryColor
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }

        Connections {
            target: root
            function onValueChanged() { canvas.requestPaint() }
            function onPrimaryColorChanged() { canvas.requestPaint() }
            function onBackgroundColorChanged() { canvas.requestPaint() }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: Math.min(root.width, root.height) * 0.25
        font.bold: true
        color: root.primaryColor
        visible: root.showPercentage
    }
}
