import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Effects

Dialog {
    id: messageDialog

    // 🔥 修复：使用标准的属性名称，兼容不同的调用方式
    property string messageText: ""
    property string message: messageText  // 兼容属性
    property string messageType: "info"  // "info", "warning", "error", "success"
    property bool autoClose: true
    property int autoCloseDelay: 3000
    property int duration: autoCloseDelay  // 兼容属性

    // 🔥 新增：美化属性
    property bool showCloseButton: true
    property bool enableAnimation: true
    property string actionText: ""
    property var actionCallback: null

    // 🔥 监听兼容属性的变化
    onMessageChanged: messageText = message
    onDurationChanged: autoCloseDelay = duration

    // 🔥 美化：移除默认标题和按钮，自定义样式
    title: ""
    modal: true
    anchors.centerIn: parent
    standardButtons: Dialog.NoButton

    // 🔥 动态调整尺寸
    width: Math.min(420, parent ? parent.width * 0.85 : 420)
    height: Math.min(messageContent.implicitHeight + 60, parent ? parent.height * 0.7 : 300)

    Material.theme: Material.Light

    // 🔥 移除默认背景，使用自定义背景
    background: Rectangle {
        color: "transparent"
    }

    // 🔥 完全自定义的内容区域
    contentItem: Rectangle {
        id: messageContent
        color: "white"
        radius: 16
        border.width: 0

        // 🔥 添加阴影效果（如果支持）
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 4
            radius: 16
            samples: 33
            color: "#40000000"
            transparentBorder: true
        }

        // 🔥 渐变背景
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { 
                    position: 0.0
                    color: getBackgroundGradientTop()
                }
                GradientStop { 
                    position: 1.0
                    color: getBackgroundGradientBottom()
                }
            }
            opacity: 0.03
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            // 🔥 头部区域（图标+关闭按钮）
            RowLayout {
                Layout.fillWidth: true

                // 🔥 增强的图标容器
                Rectangle {
                    width: 64
                    height: 64
                    radius: 32
                    color: getIconBackgroundColor()

                    // 🔥 图标脉冲动画
                    SequentialAnimation on scale {
                        running: messageDialog.visible && enableAnimation
                        loops: 1
                        NumberAnimation { to: 1.1; duration: 300; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 1.0; duration: 300; easing.type: Easing.InCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: getMessageIcon()
                        font.pixelSize: 28
                        color: getMessageColor()
                    }

                    // 🔥 图标外圆环
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: getMessageColor()
                        opacity: 0.2
                    }
                }

                Item { Layout.fillWidth: true }

                // 🔥 美化的关闭按钮
                Button {
                    visible: showCloseButton
                    width: 32
                    height: 32
                    background: Rectangle {
                        radius: 16
                        color: parent.hovered ? "#f5f5f5" : "transparent"
                        border.width: 1
                        border.color: parent.hovered ? "#e0e0e0" : "transparent"
                    }

                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: 14
                        color: "#666"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: messageDialog.close()

                    // 🔥 悬停动画
                    Behavior on scale {
                        NumberAnimation { duration: 150 }
                    }

                    onHoveredChanged: {
                        scale = hovered ? 1.1 : 1.0
                    }
                }
            }

            // 🔥 标题区域
            Text {
                Layout.fillWidth: true
                text: getDialogTitle()
                font.pixelSize: 20
                font.bold: true
                color: getMessageColor()
                horizontalAlignment: Text.AlignHCenter

                // 🔥 标题淡入动画
                opacity: 0
                NumberAnimation on opacity {
                    running: messageDialog.visible && enableAnimation
                    to: 1.0
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            // 🔥 消息内容区域
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumHeight: 200
                clip: true
                
                Text {
                    width: parent.width
                    text: messageDialog.messageText
                    font.pixelSize: 15
                    lineHeight: 1.4
                    color: "#444"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter

                    // 🔥 内容滑入动画
                    transform: Translate {
                        id: messageTransform
                        y: enableAnimation ? 20 : 0
                    }

                    NumberAnimation {
                        target: messageTransform
                        property: "y"
                        running: messageDialog.visible && enableAnimation
                        to: 0
                        duration: 500
                        easing.type: Easing.OutCubic
                    }

                    opacity: 0
                    NumberAnimation on opacity {
                        running: messageDialog.visible && enableAnimation
                        to: 1.0
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // 🔥 操作按钮区域
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                visible: actionText !== "" || !autoClose

                Item { Layout.fillWidth: true }

                // 🔥 自定义操作按钮
                Button {
                    visible: actionText !== ""
                    text: actionText
                    highlighted: true
                    Material.background: getMessageColor()
                    Material.foreground: "white"
                    
                    background: Rectangle {
                        radius: 8
                        color: parent.pressed ? Qt.darker(getMessageColor(), 1.2) : 
                               parent.hovered ? Qt.lighter(getMessageColor(), 1.1) : getMessageColor()
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    onClicked: {
                        if (actionCallback) {
                            actionCallback()
                        }
                        messageDialog.close()
                    }
                }

                // 🔥 确定按钮
                Button {
                    text: "确定"
                    flat: actionText !== ""
                    Material.foreground: getMessageColor()
                    
                    background: Rectangle {
                        radius: 8
                        color: parent.pressed ? "#f0f0f0" : 
                               parent.hovered ? "#f8f8f8" : "transparent"
                        border.width: actionText === "" ? 1 : 0
                        border.color: getMessageColor()
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    onClicked: messageDialog.close()
                }

                Item { Layout.fillWidth: true }
            }

            // 🔥 进度条（自动关闭时显示）
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                Layout.topMargin: 8
                radius: 1.5
                color: "#f0f0f0"
                visible: autoClose

                Rectangle {
                    id: progressBar
                    height: parent.height
                    radius: parent.radius
                    color: getMessageColor()
                    width: 0

                    NumberAnimation on width {
                        running: messageDialog.visible && autoClose
                        to: parent.width
                        duration: messageDialog.autoCloseDelay
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    // 🔥 自动关闭定时器
    Timer {
        id: autoCloseTimer
        interval: messageDialog.autoCloseDelay
        running: false
        repeat: false
        onTriggered: {
            if (messageDialog.visible) {
                closeWithAnimation()
            }
        }
    }

    // 🔥 入场动画
    NumberAnimation {
        id: openAnimation
        target: messageDialog
        property: "scale"
        from: 0.7
        to: 1.0
        duration: 300
        easing.type: Easing.OutBack
        running: false
    }

    // 🔥 出场动画
    NumberAnimation {
        id: closeAnimation
        target: messageDialog
        property: "scale"
        from: 1.0
        to: 0.7
        duration: 200
        easing.type: Easing.InBack
        running: false
        onFinished: messageDialog.close()
    }

    // 当对话框打开时启动定时器和动画
    onOpened: {
        if (enableAnimation) {
            openAnimation.start()
        }
        if (autoClose) {
            autoCloseTimer.start()
        }
    }

    onClosed: {
        autoCloseTimer.stop()
    }

    // 当组件创建完成时自动打开
    Component.onCompleted: {
        Qt.callLater(function() {
            open()
        })
    }

    // 🔥 美化的工具函数
    function getDialogTitle() {
        switch(messageType) {
            case "error": return "操作失败"
            case "warning": return "注意"
            case "success": return "操作成功"
            case "info":
            default: return "提示信息"
        }
    }

    function getMessageIcon() {
        switch(messageType) {
            case "error": return "✕"
            case "warning": return "⚠"
            case "success": return "✓"
            case "info":
            default: return "ⓘ"
        }
    }

    function getMessageColor() {
        switch(messageType) {
            case "error": return "#F44336"
            case "warning": return "#FF9800"
            case "success": return "#4CAF50"
            case "info":
            default: return "#2196F3"
        }
    }

    function getIconBackgroundColor() {
        switch(messageType) {
            case "error": return "#ffebee"
            case "warning": return "#fff3e0"
            case "success": return "#e8f5e8"
            case "info":
            default: return "#e3f2fd"
        }
    }

    function getBackgroundGradientTop() {
        switch(messageType) {
            case "error": return "#ffcdd2"
            case "warning": return "#ffe0b2"
            case "success": return "#c8e6c9"
            case "info":
            default: return "#bbdefb"
        }
    }

    function getBackgroundGradientBottom() {
        switch(messageType) {
            case "error": return "#ffebee"
            case "warning": return "#fff3e0"
            case "success": return "#e8f5e8"
            case "info":
            default: return "#e3f2fd"
        }
    }

    // 🔥 增强的便捷显示方法
    function showMessage(text, type, autoClose, actionText, actionCallback) {
        messageText = text || ""
        messageType = type || "info"
        if (autoClose !== undefined) {
            messageDialog.autoClose = autoClose
        }
        if (actionText !== undefined) {
            messageDialog.actionText = actionText
        }
        if (actionCallback !== undefined) {
            messageDialog.actionCallback = actionCallback
        }
        open()
    }

    function showError(text, actionText, actionCallback) {
        showMessage(text, "error", false, actionText, actionCallback)
    }

    function showWarning(text, actionText, actionCallback) {
        showMessage(text, "warning", true, actionText, actionCallback)
    }

    function showInfo(text, actionText, actionCallback) {
        showMessage(text, "info", true, actionText, actionCallback)
    }

    function showSuccess(text, actionText, actionCallback) {
        showMessage(text, "success", true, actionText, actionCallback)
    }

    // 🔥 带动画的关闭方法
    function closeWithAnimation() {
        if (enableAnimation) {
            closeAnimation.start()
        } else {
            close()
        }
    }

    // 🔥 快速消息提示（Toast风格）
    function showToast(text, type) {
        messageDialog.autoClose = true
        messageDialog.autoCloseDelay = 2000
        messageDialog.showCloseButton = false
        messageDialog.enableAnimation = true
        showMessage(text, type || "info", true)
    }
}