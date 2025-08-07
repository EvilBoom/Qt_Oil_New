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
    property string selectedModelPath: ""
    property string modelType: ""
    property var selectedDataTables: []
    property var selectedFeatures: []
    property string targetLabel: ""
    property var featureMapping: ({})
    
    signal backRequested()
    
    // 加载状态控制
    property bool isLoading: true
    property string loadingMessage: isChinese ? "正在加载模型测试页面..." : "Loading model testing page..."
    
    // 主要布局 - 使用StackView管理两个页面
    StackView {
        id: stackView
        anchors.fill: parent
        visible: !isLoading
        
        initialItem: configComponent
        
        Component.onCompleted: {
            console.log("=== StackView Component.onCompleted ===")
            console.log("StackView initial depth:", depth)
            console.log("StackView initial currentItem:", currentItem)
            console.log("StackView size:", width, "x", height)
            console.log("StackView visible:", visible)
        }
        
        onVisibleChanged: {
            console.log("=== StackView visible changed ===")
            console.log("New visible value:", visible)
            console.log("isLoading:", root.isLoading)
            console.log("StackView size:", width, "x", height)
        }
        
        onCurrentItemChanged: {
            console.log("=== StackView currentItem changed ===")
            console.log("New currentItem:", currentItem)
            console.log("Depth:", depth)
        }
        
        onDepthChanged: {
            console.log("=== StackView depth changed ===")
            console.log("New depth:", depth)
            console.log("Current item:", currentItem)
        }
        
        // 配置页面组件
        Component {
            id: configComponent
            
            Loader {
                id: configLoader
                source: "ModelTestingConfig.qml"
                
                property bool isChinese: root.isChinese
                property int currentProjectId: root.currentProjectId
                property var continuousLearningController: root.continuousLearningController
                
                Component.onCompleted: {
                    console.log("=== ModelTestingConfig Loader Component.onCompleted ===")
                    console.log("Loader source:", source)
                    console.log("Loader initial status:", status)
                    console.log("Loader initial item:", item)
                    console.log("Root controller at Loader creation:", root.continuousLearningController)
                    console.log("Loader property controller:", continuousLearningController)
                }
                
                onStatusChanged: {
                    console.log("=== ModelTestingConfig Loader status changed ===")
                    console.log("New status:", status)
                    console.log("Status meanings: 0=Null, 1=Ready, 2=Loading, 3=Error")
                    if (status === Loader.Error) {
                        console.log("ERROR: Failed to load ModelTestingConfig.qml")
                        console.log("Source URL:", source)
                        console.log("Source component:", sourceComponent)
                        // 强制停止加载状态
                        root.isLoading = false
                        root.loadingMessage = root.isChinese ? "配置页面加载失败" : "Failed to load configuration page"
                    } else if (status === Loader.Ready) {
                        console.log("SUCCESS: ModelTestingConfig.qml loaded successfully")
                        console.log("Loaded item:", item)
                    } else if (status === Loader.Loading) {
                        console.log("ModelTestingConfig.qml is loading...")
                    }
                }
                
                onLoaded: {
                    console.log("ModelTestingConfig onLoaded called, item:", item)
                    if (item) {
                        console.log("=== Setting properties on ModelTestingConfig ===")
                        
                        // 立即设置属性
                        item.isChinese = isChinese
                        item.currentProjectId = currentProjectId
                        
                        console.log("About to set continuousLearningController...")
                        console.log("Source controller:", continuousLearningController)
                        console.log("Root controller:", root.continuousLearningController)
                        console.log("Controller type:", typeof continuousLearningController)
                        console.log("Controller is null?", continuousLearningController === null)
                        console.log("Controller is undefined?", continuousLearningController === undefined)
                        
                        // 确保控制器被正确设置 - 优先使用root.continuousLearningController
                        let controllerToUse = continuousLearningController || root.continuousLearningController
                        if (controllerToUse) {
                            item.continuousLearningController = controllerToUse
                            console.log("Controller set on item. Verifying...")
                            console.log("item.continuousLearningController:", item.continuousLearningController)
                            console.log("Controller successfully set?", item.continuousLearningController === controllerToUse)
                        } else {
                            console.log("WARNING: continuousLearningController is not available yet")
                        }
                        
                        console.log("ModelTestingConfig loaded with controller:", controllerToUse)
                        
                        // 配置页面加载完成后隐藏加载指示器
                        root.isLoading = false
                    } else {
                        console.log("ERROR: ModelTestingConfig item is null")
                        root.loadingMessage = root.isChinese ? "配置页面加载失败" : "Failed to load configuration page"
                    }
                }
                
                // 监听控制器变化并同步到加载的组件
                onContinuousLearningControllerChanged: {
                    console.log("=== ModelTesting Loader: continuousLearningController changed ===")
                    console.log("New controller in Loader:", continuousLearningController)
                    if (item && continuousLearningController) {
                        console.log("Updating controller on loaded ModelTestingConfig item")
                        item.continuousLearningController = continuousLearningController
                        console.log("Controller updated on item:", item.continuousLearningController)
                    }
                }
                
                // 使用 Connections 组件来处理信号
                Connections {
                    target: item  // 直接指向加载的 ModelTestingConfig 实例
                    
                    function onBackRequested() {
                        console.log("Received backRequested signal from ModelTestingConfig")
                        root.backRequested()
                    }
                    
                    function onStartTestingRequested() {
                        console.log("=== startTestingRequested signal received ===")
                        console.log("Time:", new Date().toLocaleTimeString())
                        
                        try {
                            // 获取完整的配置（包括最终特征配置）
                            console.log("Calling getCompleteConfiguration()...")
                            let completeConfig = item.getCompleteConfiguration()
                            console.log("Got complete config:", JSON.stringify(completeConfig, null, 2))
                            
                            // 保存配置数据
                            root.selectedTask = completeConfig.task
                            root.selectedModel = completeConfig.model
                            root.selectedModelPath = completeConfig.modelPath || ""
                            root.modelType = completeConfig.modelType
                            root.selectedDataTables = completeConfig.dataTables
                            root.selectedFeatures = completeConfig.inputFeatures  // 使用最终的输入特征
                            root.targetLabel = completeConfig.targetLabel
                            root.featureMapping = completeConfig.featureMapping
                            
                            console.log("Configuration saved to root properties")
                            console.log("selectedTask:", root.selectedTask)
                            console.log("selectedModel:", root.selectedModel)
                            console.log("selectedFeatures:", root.selectedFeatures)
                            
                            // 切换到执行页面
                            console.log("Attempting to push execution page...")
                            root.currentPage = 1
                            
                            if (stackView) {
                                console.log("StackView available, pushing executionComponent...")
                                let success = stackView.push(executionComponent)
                                console.log("Push result:", success)
                                console.log("StackView depth after push:", stackView.depth)
                                console.log("StackView currentItem:", stackView.currentItem)
                            } else {
                                console.log("ERROR: stackView is null!")
                            }
                        } catch (error) {
                            console.log("ERROR in startTestingRequested handler:", error)
                            console.log("Error message:", error.message)
                        }
                    }
                }
            }
        }
        
        // 执行页面组件
        Component {
            id: executionComponent
            
            Loader {
                source: "ModelTestingExecution.qml"
                
                property bool isChinese: root.isChinese
                property int currentProjectId: root.currentProjectId
                property var continuousLearningController: root.continuousLearningController
                
                onStatusChanged: {
                    console.log("ModelTestingExecution Loader status:", status)
                    if (status === Loader.Error) {
                        console.log("ERROR: Failed to load ModelTestingExecution.qml")
                        console.log("Source URL:", source)
                        console.log("Source component:", sourceComponent)
                    } else if (status === Loader.Ready) {
                        console.log("SUCCESS: ModelTestingExecution.qml loaded successfully")
                    }
                }
                
                onLoaded: {
                    console.log("ModelTestingExecution onLoaded called, item:", item)
                    if (item) {
                        // 立即设置属性
                        item.isChinese = isChinese
                        item.currentProjectId = currentProjectId
                        item.continuousLearningController = continuousLearningController
                        
                        // 传递配置数据
                        item.selectedTask = root.selectedTask
                        item.selectedModel = root.selectedModel
                        item.selectedModelPath = root.selectedModelPath
                        item.modelType = root.modelType
                        item.selectedDataTables = root.selectedDataTables
                        item.selectedFeatures = root.selectedFeatures
                        item.targetLabel = root.targetLabel
                        item.featureMapping = root.featureMapping
                        
                        console.log("ModelTestingExecution loaded with controller:", continuousLearningController)
                        
                        // 连接信号 - 添加检查防止undefined错误
                        if (item.backRequested) {
                            item.backRequested.connect(root.backRequested)
                        } else {
                            console.log("WARNING: item.backRequested is undefined")
                        }
                        
                        if (item.backToConfigRequested) {
                            item.backToConfigRequested.connect(function() {
                                console.log("Received backToConfigRequested signal")
                                if (stackView) {
                                    stackView.pop()
                                    root.currentPage = 0
                                } else {
                                    console.log("ERROR: stackView is null")
                                }
                            })
                        } else {
                            console.log("WARNING: item.backToConfigRequested is undefined")
                        }
                    }
                }
                
                // 监听属性变化并同步到加载的组件
                onContinuousLearningControllerChanged: {
                    if (item) {
                        item.continuousLearningController = continuousLearningController
                        console.log("Controller updated in ModelTestingExecution:", continuousLearningController)
                    }
                }
            }
        }
    }
    
    // 加载指示器
    Rectangle {
        anchors.fill: parent
        color: "#f8f9fa"
        visible: isLoading
        
        Column {
            anchors.centerIn: parent
            spacing: 20
            
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: isLoading
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: loadingMessage
                font.pointSize: 12
                color: "#666666"
            }
        }
    }
    
    Component.onCompleted: {
        console.log("=== ModelTesting Component.onCompleted ===")
        console.log("ModelTesting main component loaded")
        console.log("ModelTesting isChinese:", isChinese)
        console.log("ModelTesting currentProjectId:", currentProjectId) 
        console.log("ModelTesting controller:", continuousLearningController)
        console.log("ModelTesting controller type:", typeof continuousLearningController)
        console.log("ModelTesting controller is null?", continuousLearningController === null)
        console.log("ModelTesting controller is undefined?", continuousLearningController === undefined)
        console.log("ModelTesting stackView:", stackView)
        console.log("ModelTesting configComponent:", configComponent)
        console.log("Initial isLoading:", isLoading)
        console.log("StackView visible:", stackView.visible)
        console.log("Root Rectangle size:", width, "x", height)
        console.log("Root Rectangle visible:", visible)
        console.log("Root Rectangle color:", color)
        
        // 临时：设置一个超时来强制停止加载状态
        var timer = Qt.createQmlObject("
            import QtQuick 2.15
            Timer {
                interval: 3000
                running: true
                repeat: false
                onTriggered: {
                    console.log('Timer triggered - forcing isLoading to false')
                    if (parent.isLoading) {
                        console.log('ModelTestingConfig did not load in time, forcing isLoading = false')
                        parent.isLoading = false
                    }
                }
            }", root, "ForceLoadingTimer")
    }
    
    // 监听关键属性变化
    onIsLoadingChanged: {
        console.log("=== ModelTesting isLoading changed ===")
        console.log("New isLoading value:", isLoading)
        console.log("StackView will be visible:", !isLoading)
        console.log("Loading indicator will be visible:", isLoading)
    }
    
    onVisibleChanged: {
        console.log("=== ModelTesting visible changed ===")
        console.log("New visible value:", visible)
        console.log("Size:", width, "x", height)
    }
    
    onWidthChanged: {
        console.log("ModelTesting width changed to:", width)
    }
    
    onHeightChanged: {
        console.log("ModelTesting height changed to:", height)
    }
    
    // 监听控制器变化并传递给加载的组件
    onContinuousLearningControllerChanged: {
        console.log("=== ModelTesting continuousLearningController changed ===")
        console.log("New controller in ModelTesting:", continuousLearningController)
        console.log("StackView current item:", stackView.currentItem)
        
        // 如果StackView中有当前项，尝试更新其控制器
        if (stackView && stackView.currentItem) {
            console.log("Updating controller on StackView current item")
            // StackView的当前项是Loader，我们需要更新Loader的属性
            if (stackView.currentItem.continuousLearningController !== undefined) {
                stackView.currentItem.continuousLearningController = continuousLearningController
                console.log("Controller updated on current StackView item")
            }
        }
    }
}
