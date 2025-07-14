// Qt_Oil_NewContent/DeviceRecommendation/Components/PageManager.qml

import QtQuick
import QtQuick.Controls

StackView {
    id: pageManager
    
    property bool isChineseMode: true
    
    // 打开性能分析页面
    function openPerformanceAnalysis(pumpData, stages, frequency) {
        var analysisPage = Qt.createComponent("../PumpPerformanceAnalysisPage.qml")
        
        if (analysisPage.status === Component.Ready) {
            push(analysisPage, {
                pumpData: pumpData,
                stages: stages,
                frequency: frequency,
                isChineseMode: isChineseMode
            })
        } else {
            console.error("无法加载性能分析页面")
        }
    }
    
    // 返回上一页
    function goBack() {
        if (depth > 1) {
            pop()
        }
    }
    
    // 页面切换动画
    pushEnter: Transition {
        PropertyAnimation {
            property: "x"
            from: pageManager.width
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    
    pushExit: Transition {
        PropertyAnimation {
            property: "x"
            from: 0
            to: -pageManager.width
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    
    popEnter: Transition {
        PropertyAnimation {
            property: "x"
            from: -pageManager.width
            to: 0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
    
    popExit: Transition {
        PropertyAnimation {
            property: "x"
            from: 0
            to: pageManager.width
            duration: 300
            easing.type: Easing.OutCubic
        }
    }
}