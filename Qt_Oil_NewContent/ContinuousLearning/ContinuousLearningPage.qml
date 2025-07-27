import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    
    // 控制器引用
    property var continuousLearningController
    
    // 状态管理
    property string currentModule: "main"  // main, data_management, model_training, model_testing
    property int selectedTaskType: -1
    
    // 监听currentModule变化
    onCurrentModuleChanged: {
        console.log("=== ContinuousLearningPage: currentModule changed ===")
        console.log("Previous currentModule:", "unknown")  // QML没有直接获取旧值的方法
        console.log("New currentModule:", currentModule)
        console.log("StackLayout children count:", moduleStack.children.length)
        console.log("Current StackLayout index:", moduleStack.currentIndex)
        console.log("Time:", new Date().toLocaleTimeString())
        
        // 强制更新StackLayout的currentIndex
        updateStackIndex()
    }
    
    function updateStackIndex() {
        console.log("=== updateStackIndex called ===")
        console.log("Current module:", root.currentModule)
        console.log("Time:", new Date().toLocaleTimeString())
        
        var newIndex = 0
        switch(root.currentModule) {
            case "data_management": 
                newIndex = 1
                console.log("Setting index to 1 for data_management")
                break
            case "model_training": 
                newIndex = 2
                console.log("Setting index to 2 for model_training")
                break
            case "model_testing": 
                newIndex = 3
                console.log("Setting index to 3 for model_testing")
                break
            default: 
                newIndex = 0
                console.log("Setting index to 0 for main/default")
                break
        }
        
        console.log("StackLayout currentIndex changing from", moduleStack.currentIndex, "to", newIndex)
        var oldIndex = moduleStack.currentIndex
        moduleStack.currentIndex = newIndex
        console.log("StackLayout currentIndex after change:", moduleStack.currentIndex)
        console.log("Index change successful:", (moduleStack.currentIndex === newIndex))
        
        // 检查对应的Item是否处于活动状态
        Qt.callLater(function() {
            console.log("=== Post-update check ===")
            console.log("Final StackLayout currentIndex:", moduleStack.currentIndex)
            console.log("Expected index:", newIndex)
            console.log("StackLayout children count:", moduleStack.children.length)
            
            if (moduleStack.children.length > newIndex) {
                var targetItem = moduleStack.children[newIndex]
                console.log("Target item at index", newIndex, ":", targetItem)
                console.log("Target item visible:", targetItem.visible)
                console.log("Target item enabled:", targetItem.enabled)
                
                if (targetItem.children && targetItem.children.length > 0) {
                    var loader = targetItem.children[0]
                    console.log("Loader in target item:", loader)
                    if (loader.hasOwnProperty("active")) {
                        console.log("Loader active:", loader.active)
                        console.log("Loader source:", loader.source)
                        console.log("Loader status:", loader.status)
                        if (loader.item) {
                            console.log("Loader item exists:", !!loader.item)
                        } else {
                            console.log("Loader item is null/undefined")
                        }
                    }
                }
            } else {
                console.log("ERROR: Not enough children in StackLayout for index", newIndex)
            }
        })
    }
    
    StackLayout {
        id: moduleStack
        anchors.fill: parent
        currentIndex: 0  // 初始值
        
        onCurrentIndexChanged: {
            console.log("=== StackLayout currentIndexChanged ===")
            console.log("New currentIndex:", currentIndex)
            console.log("Total children:", children.length)
            console.log("Module mapping: 0=main, 1=data_management, 2=model_training, 3=model_testing")
            
            // 检查当前激活的Item
            if (currentIndex >= 0 && currentIndex < children.length) {
                var currentItem = children[currentIndex]
                console.log("Current item at index", currentIndex, ":", currentItem)
                console.log("Current item visible:", currentItem.visible)
                
                // 如果是包含Loader的Item，检查Loader状态
                if (currentItem.children.length > 0) {
                    var loader = currentItem.children[0]
                    if (loader.hasOwnProperty("active")) {
                        console.log("Loader active:", loader.active)
                        console.log("Loader source:", loader.source)
                        console.log("Loader status:", loader.status)
                    }
                }
            }
        }
        
        // 主界面 - 功能选择
        Rectangle {
            color: "#f8f9fa"
            
            ScrollView {
                anchors.fill: parent
                contentWidth: parent.width
                
                ColumnLayout {
                    width: parent.width
                    spacing: 24
                    anchors.margins: 32
                    
                    // 页面标题
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        color: "white"
                        radius: 12
                        border.width: 1
                        border.color: "#dee2e6"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "模型持续学习" : "Model Continuous Learning"
                                    font.pixelSize: 24
                                    font.bold: true
                                    color: "#212529"
                                }
                                
                                Text {
                                    text: root.isChinese ? "智能化机器学习工作流程管理" : "Intelligent Machine Learning Workflow Management"
                                    font.pixelSize: 14
                                    color: "#6c757d"
                                }
                            }
                        }
                    }
                    
                    // 功能模块卡片
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 24
                        rowSpacing: 24
                        
                        // 数据管理模块
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            color: "white"
                            radius: 12
                            border.width: 1
                            border.color: "#dee2e6"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 12
                                
                                Rectangle {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    color: "#e3f2fd"
                                    radius: 24
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "📊"
                                        font.pixelSize: 24
                                    }
                                }
                                
                                Text {
                                    text: root.isChinese ? "数据管理" : "Data Management"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#212529"
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        "管理训练和测试数据\n包括数据增删改查\n多表数据选择与特征配置" :
                                        "Manage training and test data\nIncluding CRUD operations\nMulti-table selection and feature configuration"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                
                                Item { Layout.fillHeight: true }
                                
                                Button {
                                    Layout.fillWidth: true
                                    text: root.isChinese ? "进入数据管理" : "Enter Data Management"
                                    
                                    onClicked: {
                                        console.log("=== 数据管理按钮被点击 ===")
                                        console.log("点击时间:", new Date().toLocaleTimeString())
                                        console.log("当前 currentModule:", root.currentModule)
                                        console.log("即将设置 currentModule 为: data_management")
                                        root.currentModule = "data_management"
                                        console.log("设置后 currentModule:", root.currentModule)
                                        console.log("设置成功:", root.currentModule === "data_management")
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onEntered: parent.color = "#f8f9fa"
                                onExited: parent.color = "white"
                            }
                        }
                        
                        // 模型训练模块
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            color: "white"
                            radius: 12
                            border.width: 1
                            border.color: "#dee2e6"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 12
                                
                                Rectangle {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    color: "#fff3e0"
                                    radius: 24
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🚀"
                                        font.pixelSize: 24
                                    }
                                }
                                
                                Text {
                                    text: root.isChinese ? "模型训练" : "Model Training"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#212529"
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        "智能模型训练流程\n可视化训练过程\n自动超参数优化" :
                                        "Intelligent model training process\nVisualized training progress\nAutomatic hyperparameter optimization"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                
                                Item { Layout.fillHeight: true }
                                
                                Button {
                                    Layout.fillWidth: true
                                    text: root.isChinese ? "开始训练" : "Start Training"
                                    
                                    onClicked: {
                                        console.log("=== 模型训练按钮被点击 ===")
                                        console.log("点击时间:", new Date().toLocaleTimeString())
                                        console.log("当前 currentModule:", root.currentModule)
                                        console.log("即将设置 currentModule 为: model_training")
                                        root.currentModule = "model_training"
                                        console.log("设置后 currentModule:", root.currentModule)
                                        console.log("设置成功:", root.currentModule === "model_training")
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onEntered: parent.color = "#f8f9fa"
                                onExited: parent.color = "white"
                            }
                        }
                        
                        // 模型测试模块
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            color: "white"
                            radius: 12
                            border.width: 1
                            border.color: "#dee2e6"
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 12
                                
                                Rectangle {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    color: "#e8f5e8"
                                    radius: 24
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🔬"
                                        font.pixelSize: 24
                                    }
                                }
                                
                                Text {
                                    text: root.isChinese ? "模型测试" : "Model Testing"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: "#212529"
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        "模型性能评估\n支持外部模型导入\n可视化测试结果" :
                                        "Model performance evaluation\nSupport external model import\nVisualized test results"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                
                                Item { Layout.fillHeight: true }
                                
                                Button {
                                    Layout.fillWidth: true
                                    text: root.isChinese ? "模型测试" : "Model Testing"
                                    
                                    onClicked: {
                                    onClicked: {
                                        console.log("=== 模型测试按钮被点击 ===")
                                        console.log("点击时间:", new Date().toLocaleTimeString())
                                        console.log("当前 currentModule:", root.currentModule)
                                        console.log("即将设置 currentModule 为: model_testing")
                                        root.currentModule = "model_testing"
                                        console.log("设置后 currentModule:", root.currentModule)
                                        console.log("设置成功:", root.currentModule === "model_testing")
                                    }
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onEntered: parent.color = "#f8f9fa"
                                onExited: parent.color = "white"
                            }
                        }
                    }
                    
                    // 快速统计信息
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        color: "white"
                        radius: 12
                        border.width: 1
                        border.color: "#dee2e6"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 32
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "已训练模型" : "Trained Models"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Text {
                                    id: trainedModelsCount
                                    text: "0"
                                    font.pixelSize: 28
                                    font.bold: true
                                    color: "#007bff"
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 40
                                color: "#dee2e6"
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "数据记录" : "Data Records"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Text {
                                    id: dataRecordsCount
                                    text: "0"
                                    font.pixelSize: 28
                                    font.bold: true
                                    color: "#28a745"
                                }
                            }
                            
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 40
                                color: "#dee2e6"
                            }
                            
                            ColumnLayout {
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "最佳精度" : "Best Accuracy"
                                    font.pixelSize: 12
                                    color: "#6c757d"
                                }
                                
                                Text {
                                    id: bestAccuracy
                                    text: "N/A"
                                    font.pixelSize: 28
                                    font.bold: true
                                    color: "#dc3545"
                                }
                            }
                            
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
        
        // 数据管理页面
        Item {
            Loader {
                id: dataManagementLoader
                anchors.fill: parent
                source: root.currentModule === "data_management" ? "components/DataManagement.qml" : ""
                active: root.currentModule === "data_management"
                
                onActiveChanged: {
                    console.log("DataManagement Loader active changed to:", active)
                }
                
                onLoaded: {
                    console.log("DataManagement Loader onLoaded called")
                    if (item) {
                        item.isChinese = root.isChinese
                        item.currentProjectId = root.currentProjectId
                        item.continuousLearningController = root.continuousLearningController
                        console.log("DataManagement page loaded with controller:", root.continuousLearningController)
                    } else {
                        console.log("DataManagement Loader item is null")
                    }
                }
                
                onStatusChanged: {
                    console.log("DataManagement Loader status changed to:", status)
                    if (status === Loader.Error) {
                        console.log("DataManagement Loader error:", sourceComponent)
                    } else if (status === Loader.Ready) {
                        console.log("DataManagement Loader ready")
                    }
                }
                
                Connections {
                    target: dataManagementLoader.item
                    function onBackRequested() {
                        console.log("DataManagement: 收到返回请求")
                        root.currentModule = "main"
                    }
                }
            }
        }
        
        // 模型训练页面
        Item {
            Loader {
                id: modelTrainingLoader
                anchors.fill: parent
                source: ""
                active: root.currentModule === "model_training"
                
                // 监听active属性变化
                onActiveChanged: {
                    console.log("=== ModelTraining Loader activeChanged ===")
                    console.log("Active:", active)
                    console.log("root.currentModule:", root.currentModule)
                    console.log("Current source:", source)
                    
                    if (active && source === "") {
                        console.log("ModelTraining: 首次激活，准备加载组件")
                        Qt.callLater(function() {
                            console.log("ModelTraining: 延迟加载组件")
                            source = "components/ModelTraining.qml"
                        })
                    } else if (!active) {
                        console.log("ModelTraining Loader: 组件变为非活跃，清理source")
                        source = ""
                    }
                }
                
                // 监听currentModule变化，确保每次进入都重新加载
                Connections {
                    target: root
                    function onCurrentModuleChanged() {
                        console.log("=== ModelTraining Loader: currentModule changed ===")
                        console.log("New module:", root.currentModule)
                        console.log("Loader active:", modelTrainingLoader.active)
                        console.log("Current source:", modelTrainingLoader.source)
                        
                        if (root.currentModule === "model_training") {
                            console.log("ModelTraining: 准备重新加载组件")
                            modelTrainingLoader.source = ""
                            Qt.callLater(function() {
                                console.log("ModelTraining: 执行重新加载")
                                modelTrainingLoader.source = "components/ModelTraining.qml"
                            })
                        } else {
                            console.log("ModelTraining: 清理组件")
                            modelTrainingLoader.source = ""
                        }
                    }
                }
                
                onLoaded: {
                    console.log("=== ModelTraining Loader onLoaded ===")
                    console.log("Item created:", !!item)
                    if (item) {
                        console.log("Setting properties on ModelTraining item")
                        item.isChinese = root.isChinese
                        item.currentProjectId = root.currentProjectId
                        item.continuousLearningController = root.continuousLearningController
                        console.log("ModelTraining page loaded with controller:", root.continuousLearningController)
                    } else {
                        console.log("ERROR: ModelTraining Loader item is null!")
                    }
                }
                
                onStatusChanged: {
                    console.log("=== ModelTraining Loader statusChanged ===")
                    console.log("Status:", status)
                    console.log("Source:", source)
                    if (status === Loader.Error) {
                        console.log("ERROR: ModelTraining Loader failed to load!")
                        console.log("Error details:", sourceComponent)
                    } else if (status === Loader.Ready) {
                        console.log("SUCCESS: ModelTraining Loader ready")
                    } else if (status === Loader.Loading) {
                        console.log("INFO: ModelTraining Loader loading...")
                    } else if (status === Loader.Null) {
                        console.log("INFO: ModelTraining Loader null (no source)")
                    }
                }
                
                Connections {
                    target: modelTrainingLoader.item
                    function onBackRequested() {
                        console.log("ModelTraining: 收到返回请求")
                        root.currentModule = "main"
                    }
                }
            }
        }
        
        // 模型测试页面
        Item {
            Loader {
                id: modelTestingLoader
                anchors.fill: parent
                source: root.currentModule === "model_testing" ? "components/ModelTesting.qml" : ""
                active: root.currentModule === "model_testing"
                
                onLoaded: {
                    if (item) {
                        item.isChinese = root.isChinese
                        item.currentProjectId = root.currentProjectId
                        item.continuousLearningController = root.continuousLearningController
                        console.log("ModelTesting page loaded with controller:", root.continuousLearningController)
                    }
                }
                
                Connections {
                    target: modelTestingLoader.item
                    function onBackRequested() {
                        console.log("ModelTesting: 收到返回请求")
                        root.currentModule = "main"
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        console.log("=== ContinuousLearningPage Component.onCompleted ===")
        console.log("Time:", new Date().toLocaleTimeString())
        console.log("continuousLearningController:", root.continuousLearningController)
        console.log("typeof continuousLearningController:", typeof root.continuousLearningController)
        console.log("currentProjectId:", root.currentProjectId)
        console.log("isChinese:", root.isChinese)
        console.log("初始 currentModule:", root.currentModule)
        console.log("StackLayout children count:", moduleStack.children.length)
        console.log("StackLayout initial currentIndex:", moduleStack.currentIndex)
        
        updateStatistics()
        updateStackIndex()  // 确保初始状态正确
        
        console.log("=== Component.onCompleted finished ===")
    }
    
    function updateStatistics() {
        // 更新统计信息
        if (typeof root.continuousLearningController !== 'undefined') {
            let models = root.continuousLearningController.getAvailableModels()
            trainedModelsCount.text = models.length.toString()
            
            let dataList = root.continuousLearningController.getTrainingDataList()
            dataRecordsCount.text = dataList.length.toString()
            
            // 计算最佳精度（这里使用模拟数据）
            if (models.length > 0) {
                bestAccuracy.text = "92.5%"
                bestAccuracy.color = "#28a745"
            } else {
                bestAccuracy.text = "N/A"
                bestAccuracy.color = "#dc3545"
            }
        }
    }
    
    Connections {
        target: typeof root.continuousLearningController !== 'undefined' ? root.continuousLearningController : null
        
        function onModelListUpdated(models) {
            trainedModelsCount.text = models.length.toString()
        }
        
        function onDataListUpdated(dataList) {
            dataRecordsCount.text = dataList.length.toString()
        }
        
        function onTrainingCompleted(modelName, results) {
            root.updateStatistics()
            // Update best accuracy if training results contain R² score
            if (results) {
                console.log("Training completed with results:", JSON.stringify(results))
                console.log("Model name:", modelName)
            }
        }
        
        function onModelSaved(modelName, savePath) {
            console.log("Model saved:", modelName, "to", savePath)
            root.updateStatistics()  // 更新统计信息
        }
    }
}
