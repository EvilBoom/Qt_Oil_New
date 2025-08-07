import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 800
    height: 600
    title: "Component Test"
    
    ModelTestingExecution {
        anchors.fill: parent
        isChinese: true
    }
}
