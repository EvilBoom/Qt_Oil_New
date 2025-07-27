import QtQuick
import QtQuick.Controls

// 测试文件 - 验证持续学习模块集成
ApplicationWindow {
    id: testWindow
    width: 1000
    height: 700
    visible: true
    title: "持续学习模块测试"
    
    property bool isChinese: true
    property int currentProjectId: 1
    
    ContinuousLearningPage {
        id: learningPage
        anchors.fill: parent
        isChinese: testWindow.isChinese
        currentProjectId: testWindow.currentProjectId
        
        Component.onCompleted: {
            console.log("持续学习页面加载完成")
        }
    }
    
    // 在窗口右上角添加一个按钮来切换语言
    Button {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        text: testWindow.isChinese ? "English" : "中文"
        
        onClicked: {
            testWindow.isChinese = !testWindow.isChinese
        }
    }
    
    Component.onCompleted: {
        console.log("测试窗口启动完成")
    }
}
