import QtQuick 2.15
import QtQuick.Controls 2.15

// 根元素替换为 Window，解决 "Dialog 不支持作为根元素" 问题
Window {
    id: wellWindow
    title: "请选择井信息"  // 保留原标题
    width: 350   // 适当调整宽度
    height: 180  // 适当调整高度
    visible: false  // 默认隐藏，通过 show() 显示

    // 保留原属性
    property var wellsList: []
    property var selectedWell: null

    // 保留原信号
    signal wellConfirmed(var well)
    signal rejected()

    // 内容区域（原 contentItem 内容）
    Column {
        spacing: 10
        width: 300
        anchors.centerIn: parent  // 居中显示

        ComboBox {
            id: wellCombo
            width: parent.width
            model: wellWindow.wellsList
            textRole: "name"
            onCurrentIndexChanged: {
                wellWindow.selectedWell = wellWindow.wellsList[wellCombo.currentIndex]
            }
        }

        Text {
            text: wellWindow.selectedWell ? "已选井: " + wellWindow.selectedWell.name : "请选择井"
            color: "gray"
        }
    }

    // 底部按钮区域（替代原 standardButtons）
    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 15
        spacing: 10

        Button {
            text: "取消"
            onClicked: {
                wellWindow.close()  // 取消时关闭窗口
            }
        }

        Button {
            text: "确定"
            onClicked: {
                if (selectedWell) {
                    wellConfirmed(selectedWell)  // 触发确认信号
                }
                wellWindow.close()  // 确定后关闭窗口
            }
        }
    }
}
