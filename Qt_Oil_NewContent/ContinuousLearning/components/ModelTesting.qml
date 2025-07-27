import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

pragma ComponentBehavior: Bound

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    property var continuousLearningController
    
    // 页面状态控制
    property int currentPage: 0  // 0: 配置页面, 1: 执行页面
    
    // 配置数据（在页面间传递）
    property string selectedTask: ""
    property string selectedModel: ""
    property string modelType: ""
    property var selectedDataTables: []
    property var selectedFeatures: []
    property string targetLabel: ""
    property var featureMapping: ({})
    
    signal backRequested()
    
    // 主要布局 - 使用StackView管理两个页面
    StackView {
        id: stackView
        anchors.fill: parent
        
        initialItem: configComponent
        
        // 配置页面组件
        Component {
            id: configComponent
            
            ModelTestingConfig {
                isChinese: root.isChinese
                currentProjectId: root.currentProjectId
                continuousLearningController: root.continuousLearningController
                
                onBackRequested: root.backRequested()
                
                onStartTestingRequested: {
                    // 保存配置数据
                    root.selectedTask = selectedTask
                    root.selectedModel = selectedModel
                    root.modelType = modelType
                    root.selectedDataTables = selectedDataTables
                    root.selectedFeatures = selectedFeatures
                    root.targetLabel = targetLabel
                    root.featureMapping = featureMapping
                    
                    // 切换到执行页面
                    root.currentPage = 1
                    stackView.push(executionComponent)
                }
            }
        }
        
        // 执行页面组件
        Component {
            id: executionComponent
            
            ModelTestingExecution {
                isChinese: root.isChinese
                currentProjectId: root.currentProjectId
                continuousLearningController: root.continuousLearningController
                
                // 传递配置数据
                selectedTask: root.selectedTask
                selectedModel: root.selectedModel
                modelType: root.modelType
                selectedDataTables: root.selectedDataTables
                selectedFeatures: root.selectedFeatures
                targetLabel: root.targetLabel
                featureMapping: root.featureMapping
                
                onBackRequested: root.backRequested()
                
                onBackToConfigRequested: {
                    stackView.pop()
                    root.currentPage = 0
                }
            }
        }
    }
    
    Component.onCompleted: {
        console.log("ModelTesting main component loaded")
    }
}
