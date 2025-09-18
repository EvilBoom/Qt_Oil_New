import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

// 登录窗口
Window {
    id: loginWindow
    width: 900
    height: 600
    visible: true
    color: "#f5f8fa"
    title: qsTr("系统登录")

    // 错误提示对话框
    Dialog {
        id: errorDialog
        title: isChinese ? "错误" : "Error"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok

        property string errorMessage: ""

        Label {
            text: errorDialog.errorMessage
            wrapMode: Text.Wrap
        }
    }

    // 连接LoginController的信号
    Connections {
        target: loginController

        function onLoginSuccess(projectName, userName) {
            console.log("登录成功信号接收到：", projectName, userName)
            // 登录成功后窗口会被main.py关闭并打开主窗口
        }

        function onLoginFailed(errorMessage) {
            console.log("登录失败：", errorMessage)
            errorDialog.errorMessage = errorMessage
            errorDialog.open()
        }

        function onLanguageChanged(isChinese) {
            loginWindow.isChinese = isChinese
        }
    }

    // 窗口居中
    Component.onCompleted: {
        x = Screen.width / 2 - width / 2
        y = Screen.height / 2 - height / 2

        // 同步语言设置
        isChinese = loginController.language

        // 更新项目列表
        if (loginController.projectList) {
            projectSelector.model = loginController.projectList
        }
    }

    // 定义全局颜色
    readonly property color primaryColor: "#1976D2"
    readonly property color primaryLightColor: "#42a5f5"
    readonly property color primaryDarkColor: "#0d47a1"
    readonly property color accentColor: "#64b5f6"
    readonly property color textColor: "#37474F"
    readonly property color lightTextColor: "#78909C"
    readonly property color backgroundColor: "#F5F8FA"

    // 中英文切换相关状态和函数
    property bool isChinese: true
    function toggleLanguage() {
        isChinese = !isChinese
        loginController.language = isChinese
    }

    // 主布局 - 采用左右分栏设计
    Rectangle {
        anchors.fill: parent
        color: backgroundColor

        RowLayout {
            anchors.fill: parent
            layoutDirection: Qt.LeftToRight
            spacing: 0

            // 左侧图像区域
            Rectangle {
                id: rectangle1
                width: 300
                color: "#2d4258"
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.4

                Rectangle {
                    id: logoContainer
                    width: parent.width * 0.8
                    height: width
                    radius: width / 2
                    border.color: "#1210d3"
                    border.width: 0
                    color: "#9dc8fd"
                    opacity: 0.7
                    anchors.centerIn: parent

                    Image {
                        id: image
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 41
                        anchors.rightMargin: 40
                        anchors.topMargin: 43
                        anchors.bottomMargin: 43
                        source: "images/oil-pump.png"
                        fillMode: Image.Stretch
                    }
                }

                // 应用名称
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: logoContainer.bottom
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 20
                    anchors.bottomMargin: 70
                    text: isChinese ? "渤海装备无杆举升系统选型设计软件" : "Bohai Equipment Rodless Lifting\n System Design Software"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                // 应用版本
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    text: "V1.1"
                    color: "white"
                    font.pixelSize: 14
                    font.styleName: "Bold"
                    opacity: 0.8
                }
            }

            // 右侧登录表单区域
            Rectangle {
                id: rectangle
                width: 600
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: backgroundColor
                Layout.columnSpan: 10
                Layout.rowSpan: 10

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 5
                    anchors.bottomMargin: 20
                    spacing: 10

                    // 语言选择区域 - 修复版本
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 30

                            Text {
                                text: isChinese ? "选择语言:" : "Language:"
                                font.pixelSize: 16
                                color: textColor
                            }

                            // 中文选项 - 修复点击区域
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 30
                                color: chineseMouseArea.containsMouse ? "#F0F0F0" : "transparent"
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    spacing: 8

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "transparent"
                                        border.width: 2
                                        border.color: primaryColor

                                        Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: primaryColor
                                            anchors.centerIn: parent
                                            visible: isChinese
                                        }
                                    }

                                    Text {
                                        text: "中文"
                                        font.pixelSize: 16
                                        color: textColor
                                    }
                                }

                                MouseArea {
                                    id: chineseMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("点击中文选项")
                                        if (!isChinese) {
                                            toggleLanguage()
                                        }
                                    }
                                }
                            }

                            // 英文选项 - 修复点击区域
                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 30
                                color: englishMouseArea.containsMouse ? "#F0F0F0" : "transparent"
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    spacing: 8

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "transparent"
                                        border.width: 2
                                        border.color: primaryColor

                                        Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: primaryColor
                                            anchors.centerIn: parent
                                            visible: !isChinese
                                        }
                                    }

                                    Text {
                                        text: "English"
                                        font.pixelSize: 16
                                        color: textColor
                                    }
                                }

                                MouseArea {
                                    id: englishMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("点击英文选项")
                                        if (isChinese) {
                                            toggleLanguage()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 单位制选择 - 修复版本
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        color: "transparent"

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 30

                            Text {
                                text: isChinese ? "选择单位制:" : "Unit System:"
                                font.pixelSize: 16
                                color: textColor
                            }

                            // 公制选项 - 修复点击区域和显示
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 35
                                color: metricMouseArea.containsMouse ? "#F0F0F0" : "transparent"
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "transparent"
                                        border.width: 2
                                        border.color: primaryColor

                                        Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: primaryColor
                                            anchors.centerIn: parent
                                            // 🔥 修复：正确绑定到unitSystemController
                                            visible: unitSystemController ? unitSystemController.isMetric : true
                                        }
                                    }

                                    Text {
                                        text: isChinese ? "公制" : "Metric"
                                        font.pixelSize: 16
                                        color: textColor
                                    }
                                }

                                MouseArea {
                                    id: metricMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("点击公制选项")
                                        if (unitSystemController) {
                                            unitSystemController.isMetric = true
                                            console.log("设置为公制:", unitSystemController.isMetric)
                                        }
                                    }
                                }
                            }

                            // 英制选项 - 修复点击区域和显示
                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 35
                                color: imperialMouseArea.containsMouse ? "#F0F0F0" : "transparent"
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: "transparent"
                                        border.width: 2
                                        border.color: primaryColor

                                        Rectangle {
                                            width: 12
                                            height: 12
                                            radius: 6
                                            color: primaryColor
                                            anchors.centerIn: parent
                                            // 🔥 修复：正确绑定到unitSystemController
                                            visible: unitSystemController ? !unitSystemController.isMetric : false
                                        }
                                    }

                                    Text {
                                        text: isChinese ? "英制" : "Imperial"
                                        font.pixelSize: 16
                                        color: textColor
                                    }
                                }

                                MouseArea {
                                    id: imperialMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("点击英制选项")
                                        if (unitSystemController) {
                                            unitSystemController.isMetric = false
                                            console.log("设置为英制:", unitSystemController.isMetric)
                                        }
                                    }
                                }
                            }
                        }

                        // 🔥 添加状态监听和调试信息
                        Connections {
                            target: unitSystemController
                            function onIsMetricChanged() {
                                console.log("单位制状态变化:", unitSystemController.isMetric ? "公制" : "英制")
                            }
                        }

                        // 🔥 组件完成时的初始化
                        Component.onCompleted: {
                            if (unitSystemController) {
                                console.log("单位制控制器初始状态:", unitSystemController.isMetric ? "公制" : "英制")
                            } else {
                                console.log("警告：unitSystemController 未找到")
                            }
                        }
                    }
                    // 项目操作区域
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 260
                        color: "white"
                        radius: 10
                        border.color: "#E0E0E0"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 20

                            Text {
                                text: isChinese ? "项目操作" : "Project Operation"
                                font.pixelSize: 18
                                font.bold: true
                                color: textColor
                            }

                            // 新建项目选项
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                color: newProjectArea.containsMouse ? "#F5F5F5" : "transparent"
                                radius: 6

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        color: "#080f15"
                                        radius: 15

                                        Text {
                                            anchors.centerIn: parent
                                            text: "+"
                                            font.pixelSize: 18
                                            font.bold: true
                                            color: "white"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: isChinese ? "新建项目" : "New Project"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: textColor
                                        }

                                        Text {
                                            text: isChinese ? "创建一个新的项目" : "Create a new project"
                                            font.pixelSize: 14
                                            color: lightTextColor
                                        }
                                    }
                                }

                                MouseArea {
                                    id: newProjectArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        projectType.currentIndex = 0
                                    }
                                }
                            }

                            // 打开项目选项
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                color: openProjectArea.containsMouse ? "#F5F5F5" : "transparent"
                                radius: 6

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        color: "#080b0e"
                                        radius: 15

                                        Text {
                                            anchors.centerIn: parent
                                            text: "↑"
                                            font.pixelSize: 18
                                            font.bold: true
                                            color: "white"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: isChinese ? "打开项目" : "Open Project"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: textColor
                                        }

                                        Text {
                                            text: isChinese ? "打开一个已有项目" : "Open an existing project"
                                            font.pixelSize: 14
                                            color: lightTextColor
                                        }
                                    }
                                }

                                MouseArea {
                                    id: openProjectArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        projectType.currentIndex = 1
                                    }
                                }
                            }
                        }
                    }

                    // 隐藏的类型标记
                    Item {
                        id: projectType
                        property int currentIndex: 0  // 0: 新建, 1: 打开
                        visible: false
                    }

                    // 用户信息输入
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        visible: projectType.currentIndex === 0

                        Text {
                            text: isChinese ? "用户名:" : "User Name:"
                            font.pixelSize: 14
                            color: textColor
                        }

                        TextField {
                            id: userNameInput
                            Layout.fillWidth: true
                            height: 44
                            placeholderText: isChinese ? "请输入用户名" : "Enter user name"
                            font.pixelSize: 14
                            background: Rectangle {
                                border.width: 1
                                border.color: parent.focus ? primaryColor : "#E0E0E0"
                                radius: 4
                            }
                        }
                    }

                    // 项目名称输入
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        visible: projectType.currentIndex === 0

                        Text {
                            text: isChinese ? "项目名称:" : "Project Name:"
                            font.pixelSize: 14
                            color: textColor
                        }

                        TextField {
                            id: projectNameInput
                            Layout.fillWidth: true
                            height: 44
                            placeholderText: isChinese ? "请输入项目名称" : "Enter project name"
                            font.pixelSize: 14
                            background: Rectangle {
                                border.width: 1
                                border.color: parent.focus ? primaryColor : "#E0E0E0"
                                radius: 4
                            }
                        }
                    }

                    // 项目选择下拉框
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        visible: projectType.currentIndex === 1

                        Text {
                            text: isChinese ? "选择项目:" : "Select Project:"
                            font.pixelSize: 14
                            color: textColor
                        }

                        ComboBox {
                            id: projectSelector
                            Layout.fillWidth: true
                            model: loginController.projectList
                            font.pixelSize: 14

                            background: Rectangle {
                                border.width: 1
                                border.color: parent.focus ? primaryColor : "#E0E0E0"
                                radius: 4
                            }

                            Connections {
                                target: loginController
                                function onProjectListChanged() {
                                    projectSelector.model = loginController.projectList
                                }
                            }
                        }
                    }

                    // 用户选择下拉框 (打开项目时)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        visible: projectType.currentIndex === 1

                        Text {
                            text: isChinese ? "用户名:" : "User Name:"
                            font.pixelSize: 14
                            color: textColor
                        }

                        TextField {
                            id: userNameForOpen
                            Layout.fillWidth: true
                            height: 44
                            placeholderText: isChinese ? "请输入用户名" : "Enter user name"
                            font.pixelSize: 14
                            background: Rectangle {
                                border.width: 1
                                border.color: parent.focus ? primaryColor : "#E0E0E0"
                                radius: 4
                            }
                        }
                    }

                    // 按钮区域
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        spacing: 20

                        // 退出按钮
                        Button {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 44
                            text: isChinese ? "退出" : "Exit"
                            font.pixelSize: 16

                            background: Rectangle {
                                radius: 4
                                color: parent.down ? "#E3F2FD" : "transparent"
                                border.width: 1
                                border.color: parent.down ? primaryColor : primaryDarkColor
                            }

                            onClicked: {
                                loginWindow.close()
                            }
                        }

                        // 确定按钮
                        Button {
                            id: confirmButton
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 44
                            text: isChinese ? "确定" : "Confirm"
                            font.pixelSize: 16
                            enabled: {
                                if (projectType.currentIndex === 0) {
                                    return projectNameInput.text.trim() !== "" && userNameInput.text.trim() !== ""
                                } else {
                                    return projectSelector.currentIndex >= 0 && userNameForOpen.text.trim() !== ""
                                }
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: 4
                                color: parent.enabled ? (parent.down ? primaryDarkColor : primaryColor) : "#cccccc"
                            }

                            onClicked: {
                                if (projectType.currentIndex === 0) {
                                    // 新建项目
                                    console.log("新建项目:", projectNameInput.text, "用户:", userNameInput.text)
                                    loginController.createProject(projectNameInput.text.trim(), userNameInput.text.trim())
                                } else {
                                    // 打开项目
                                    console.log("打开项目索引:", projectSelector.currentIndex, "项目名:", projectSelector.currentText, "用户:", userNameForOpen.text)
                                    loginController.openProject(projectSelector.currentIndex, userNameForOpen.text.trim())
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
