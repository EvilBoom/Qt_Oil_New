import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

pragma ComponentBehavior: Bound

Rectangle {
    id: root
    color: "#f8f9fa"
    
    property bool isChinese: true
    property int currentProjectId: -1
    
    // 控制器引用
    property var continuousLearningController
    
    // 状态管理
    property var selectedTables: []
    property var selectedFeatures: []
    property string targetLabel: ""
    property var availableTables: []
    property var availableFields: []
    property bool isExcelUploaded: false
    
    signal backRequested()
    
    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width
        
        ColumnLayout {
            width: parent.width
            spacing: 16
            anchors.margins: 24
            
            // 页面标题
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    
                    Text {
                        text: root.isChinese ? "数据管理" : "Data Management"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#212529"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Button {
                        text: root.isChinese ? "返回" : "Back"
                        onClicked: root.backRequested()
                    }
                }
            }
            

            
            // 数据文件上传区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "数据文件上传" : "Data File Upload"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Text {
                        text: root.isChinese ? "支持Excel(.xlsx/.xls)和CSV(.csv)文件格式" : "Support Excel(.xlsx/.xls) and CSV(.csv) file formats"
                        font.pixelSize: 12
                        color: "#6c757d"
                    }
                    
                    RowLayout {
                        Button {
                            text: root.isChinese ? "选择数据文件" : "Select Data File"
                            onClicked: dataFileDialog.open()
                        }
                        
                        Text {
                            id: dataFileStatus
                            text: root.isChinese ? "未选择文件" : "No file selected"
                            color: "#6c757d"
                            Layout.fillWidth: true
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: root.isChinese ? "上传到数据库" : "Upload to Database"
                            enabled: root.isExcelUploaded
                            onClicked: {
                                console.log("Upload button clicked")
                                console.log("root.continuousLearningController:", root.continuousLearningController)
                                console.log("typeof root.continuousLearningController:", typeof root.continuousLearningController)
                                
                                if (!root.continuousLearningController) {
                                    console.log("ERROR: continuousLearningController is undefined!")
                                    return
                                }
                                
                                let result = root.continuousLearningController.uploadDataFileToDatabase()
                                console.log("Upload result:", result)
                                if (result.success) {
                                    dataUploadStatus.text = root.isChinese ? 
                                        "上传成功！" : "Upload successful!"
                                    dataUploadStatus.color = "#28a745"
                                    root.availableTables = root.continuousLearningController.getAvailableTables()
                                } else {
                                    dataUploadStatus.text = root.isChinese ? 
                                        `上传失败: ${result.error}` : `Upload failed: ${result.error}`
                                    dataUploadStatus.color = "#dc3545"
                                }
                            }
                        }
                        
                        Text {
                            id: dataUploadStatus
                            text: ""
                            Layout.fillWidth: true
                        }
                    }
                }
            }
            
            // 数据表选择区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 350
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    RowLayout {
                        Text {
                            text: root.isChinese ? "选择数据表" : "Select Data Tables"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#495057"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // 表类型过滤
                        ButtonGroup {
                            id: tableTypeGroup
                        }
                        
                        RadioButton {
                            text: root.isChinese ? "训练数据(data)" : "Training Data(data)"
                            checked: true
                            ButtonGroup.group: tableTypeGroup
                            onCheckedChanged: {
                                if (checked) {
                                    root.filterTables("data")
                                }
                            }
                        }
                        
                        RadioButton {
                            text: root.isChinese ? "测试数据(test)" : "Test Data(test)"
                            ButtonGroup.group: tableTypeGroup
                            onCheckedChanged: {
                                if (checked) {
                                    root.filterTables("test")
                                }
                            }
                        }
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        border.width: 1
                        border.color: "#ced4da"
                        radius: 4
                        
                        ListView {
                            id: tablesListView
                            anchors.fill: parent
                            anchors.margins: 8
                            
                            property var filteredTables: []
                            model: filteredTables
                            
                            delegate: Rectangle {
                                id: tableDelegate
                                required property var modelData
                                required property int index
                                
                                property string tableData: modelData
                                
                                width: tablesListView.width
                                height: 40
                                color: tableMouseArea.containsMouse ? "#e9ecef" : "transparent"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    
                                    CheckBox {
                                        id: tableCheckBox
                                        checked: root.selectedTables.includes(tableDelegate.tableData)
                                        onCheckedChanged: {
                                            if (checked) {
                                                if (!root.selectedTables.includes(tableDelegate.tableData)) {
                                                    root.selectedTables = [...root.selectedTables, tableDelegate.tableData]
                                                }
                                            } else {
                                                root.selectedTables = root.selectedTables.filter(t => t !== tableDelegate.tableData)
                                            }
                                            root.continuousLearningController.setSelectedTables(root.selectedTables)
                                        }
                                    }
                                    
                                    Text {
                                        text: tableDelegate.tableData
                                        font.pixelSize: 14
                                        color: "#495057"
                                        Layout.fillWidth: true
                                    }
                                }
                                
                                MouseArea {
                                    id: tableMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: tableCheckBox.checked = !tableCheckBox.checked
                                }
                            }
                        }
                    }
                    
                    RowLayout {
                        Button {
                            text: root.isChinese ? "刷新表列表" : "Refresh Tables"
                            onClicked: {
                                root.availableTables = root.continuousLearningController.getAvailableTables()
                            }
                        }
                        
                        Button {
                            text: root.isChinese ? "加载数据" : "Load Data"
                            enabled: root.selectedTables.length > 0
                            onClicked: {
                                let result = root.continuousLearningController.loadDataFromTables()
                                if (result.error) {
                                    statusText.text = "错误: " + result.error
                                    statusText.color = "#dc3545"
                                } else {
                                    statusText.text = `已加载 ${result.total_records} 条记录，${result.feature_count} 个特征`
                                    statusText.color = "#28a745"
                                }
                            }
                        }
                    }
                }
            }
            
            // 特征选择区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "特征选择" : "Feature Selection"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    RowLayout {
                        spacing: 16
                        
                        // 输入特征选择
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 200
                            border.width: 1
                            border.color: "#ced4da"
                            radius: 4
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                Text {
                                    text: root.isChinese ? "输入特征" : "Input Features"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                
                                ListView {
                                    id: featuresListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    
                                    model: root.availableFields
                                    
                                    delegate: Rectangle {
                                        id: featureDelegate
                                        required property var modelData
                                        
                                        width: featuresListView.width
                                        height: 30
                                        color: featureMouseArea.containsMouse ? "#e9ecef" : "transparent"
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            
                                            CheckBox {
                                                id: featureCheckBox
                                                checked: root.selectedFeatures.includes(featureDelegate.modelData)
                                                onCheckedChanged: {
                                                    if (checked) {
                                                        if (!root.selectedFeatures.includes(featureDelegate.modelData)) {
                                                            root.selectedFeatures = [...root.selectedFeatures, featureDelegate.modelData]
                                                        }
                                                    } else {
                                                        root.selectedFeatures = root.selectedFeatures.filter(f => f !== featureDelegate.modelData)
                                                    }
                                                    root.continuousLearningController.setSelectedFeatures(root.selectedFeatures)
                                                }
                                            }
                                            
                                            Text {
                                                text: featureDelegate.modelData
                                                font.pixelSize: 12
                                                color: "#495057"
                                                Layout.fillWidth: true
                                            }
                                        }
                                        
                                        MouseArea {
                                            id: featureMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: featureCheckBox.checked = !featureCheckBox.checked
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 预测标签选择
                        Rectangle {
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 200
                            border.width: 1
                            border.color: "#ced4da"
                            radius: 4
                            
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                Text {
                                    text: root.isChinese ? "预测标签" : "Target Label"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                
                                ComboBox {
                                    id: targetComboBox
                                    Layout.fillWidth: true
                                    model: root.availableFields
                                    currentIndex: -1
                                    
                                    onCurrentTextChanged: {
                                        root.targetLabel = currentText
                                        root.continuousLearningController.setTargetLabel(currentText)
                                    }
                                }
                                
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                    
                    Button {
                        text: root.isChinese ? "获取字段列表" : "Get Fields"
                        enabled: root.selectedTables.length > 0
                        onClicked: {
                            if (root.selectedTables.length > 0) {
                                root.availableFields = root.continuousLearningController.getTableFields(root.selectedTables[0])
                            }
                        }
                    }
                }
            }
            
            // 数据预览区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "数据预览" : "Data Preview"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#495057"
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        border.width: 1
                        border.color: "#ced4da"
                        radius: 4
                        
                        ScrollView {
                            anchors.fill: parent
                            
                            Text {
                                id: dataPreviewText
                                text: root.isChinese ? "请先加载数据" : "Please load data first"
                                font.pixelSize: 12
                                color: "#6c757d"
                                padding: 8
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
            
            // 状态显示
            Text {
                id: statusText
                Layout.fillWidth: true
                text: root.isChinese ? "请选择数据表并配置特征" : "Please select tables and configure features"
                font.pixelSize: 14
                color: "#6c757d"
                wrapMode: Text.WordWrap
            }
        }
    }
    
    Component.onCompleted: {
        console.log("DataManagement.qml - Component.onCompleted")
        console.log("DataManagement.qml - continuousLearningController:", root.continuousLearningController)
        console.log("DataManagement.qml - typeof continuousLearningController:", typeof root.continuousLearningController)
        
        // 初始化数据表列表
        if (typeof root.continuousLearningController !== 'undefined' && root.continuousLearningController !== null) {
            console.log("DataManagement.qml - Controller is valid, getting tables...")
            root.availableTables = root.continuousLearningController.getAvailableTables()
            filterTables("data") // 默认显示data开头的表
        } else {
            console.log("DataManagement.qml - ERROR: Controller is undefined or null!")
        }
    }
    
    // 过滤表格的JavaScript函数
    function filterTables(prefix) {
        let filtered = root.availableTables.filter(table => table.startsWith(prefix))
        tablesListView.filteredTables = filtered
    }
    
    // 数据文件选择对话框
    FileDialog {
        id: dataFileDialog
        title: root.isChinese ? "选择数据文件" : "Select Data File"
        nameFilters: [
            "Excel files (*.xlsx *.xls)", 
            "CSV files (*.csv)", 
            "All files (*)"
        ]
        onAccepted: {
            console.log("File dialog accepted")
            console.log("root.continuousLearningController:", root.continuousLearningController)
            console.log("typeof root.continuousLearningController:", typeof root.continuousLearningController)
            
            let filePath = selectedFile.toString().replace("file:///", "")
            console.log("Selected file path:", filePath)
            
            dataFileStatus.text = filePath.split('/').pop()
            dataFileStatus.color = "#28a745"
            root.isExcelUploaded = true
            
            if (!root.continuousLearningController) {
                console.log("ERROR: continuousLearningController is undefined when setting file path!")
                return
            }
            
            root.continuousLearningController.setDataFilePath(filePath)
            console.log("File path set successfully")
        }
        onRejected: {
            console.log("Data file selection cancelled")
        }
    }
    
    Connections {
        target: root.continuousLearningController
        
        function onDataLoaded(dataInfo) {
            if (dataInfo && !dataInfo.error) {
                dataPreviewText.text = `数据记录: ${dataInfo.total_records}\n特征数量: ${dataInfo.feature_count}\n目标变量: ${dataInfo.target_label}\n数据维度: ${dataInfo.data_shape}`
            }
        }
    }
}
