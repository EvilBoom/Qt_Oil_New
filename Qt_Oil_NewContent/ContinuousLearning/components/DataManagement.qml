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
    property var availableTables: []
    property string selectedTable: ""
    property bool isFileUploaded: false
    property string userTableName: ""
    property bool isTrainingData: true
    
    // 预览数据
    property var previewData: ({
        "columns": [],
        "rows": [],
        "total_rows": 0
    })
    
    signal backRequested()
    
    ScrollView {
        anchors.fill: parent
        contentWidth: parent.width
        
        ColumnLayout {
            width: parent.width
            spacing: 20
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
                        font.pixelSize: 24
                        font.bold: true
                        color: "#212529"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    //Button {
                    //    text: root.isChinese ? "返回" : "Back"
                    //    onClicked: root.backRequested()
                    //}
                }
            }
            
            // 数据文件上传区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 340
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    Text {
                        text: root.isChinese ? "上传数据文件" : "Upload Data File"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#212529"
                    }
                    
                    Text {
                        text: root.isChinese ? "支持Excel(.xlsx/.xls)和CSV(.csv)文件格式" : "Support Excel(.xlsx/.xls) and CSV(.csv) file formats"
                        font.pixelSize: 12
                        color: "#6c757d"
                    }
                    
                    // 文件选择
                    RowLayout {
                        spacing: 12
                        
                        Button {
                            text: root.isChinese ? "选择文件" : "Select File"
                            highlighted: true
                            onClicked: dataFileDialog.open()
                        }
                        
                        Text {
                            id: dataFileStatus
                            text: root.isChinese ? "未选择文件" : "No file selected"
                            color: "#6c757d"
                            font.pixelSize: 12
                        }
                    }
                    
                    // 表名设置
                    ColumnLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        
                        Text {
                            text: root.isChinese ? "表名设置" : "Table Name Settings"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#212529"
                        }
                        
                        RowLayout {
                            spacing: 12
                            Layout.fillWidth: true
                            
                            // 数据类型选择
                            ColumnLayout {
                                spacing: 4
                                
                                Text {
                                    text: root.isChinese ? "数据类型：" : "Data Type:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                
                                RowLayout {
                                    spacing: 16
                                    
                                    RadioButton {
                                        id: trainingRadio
                                        text: root.isChinese ? "训练数据" : "Training Data"
                                        checked: root.isTrainingData
                                        onToggled: {
                                            if (checked) {
                                                root.isTrainingData = true
                                            }
                                        }
                                    }
                                    
                                    RadioButton {
                                        id: testRadio
                                        text: root.isChinese ? "测试数据" : "Test Data"
                                        checked: !root.isTrainingData
                                        onToggled: {
                                            if (checked) {
                                                root.isTrainingData = false
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 表名输入
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true
                                
                                Text {
                                    text: root.isChinese ? "表名：" : "Table Name:"
                                    font.pixelSize: 12
                                    color: "#495057"
                                }
                                
                                RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true
                                    
                                    Text {
                                        text: root.isTrainingData ? "data_" : "test_"
                                        font.pixelSize: 14
                                        color: "#007bff"
                                        font.bold: true
                                    }
                                    
                                    TextField {
                                        id: tableNameInput
                                        Layout.fillWidth: true
                                        placeholderText: root.isChinese ? "请输入表名" : "Enter table name"
                                        text: root.userTableName
                                        onTextChanged: {
                                            root.userTableName = text
                                        }
                                        
                                        background: Rectangle {
                                            color: tableNameInput.enabled ? "#ffffff" : "#f8f9fa"
                                            border.color: tableNameInput.activeFocus ? "#007bff" : "#ced4da"
                                            border.width: 1
                                            radius: 4
                                        }
                                    }
                                }
                                
                                Text {
                                    text: root.isChinese ? 
                                        `最终表名：${root.isTrainingData ? 'data_' : 'test_'}${root.userTableName}` :
                                        `Final table name: ${root.isTrainingData ? 'data_' : 'test_'}${root.userTableName}`
                                    font.pixelSize: 11
                                    color: "#6c757d"
                                    visible: root.userTableName !== ""
                                }
                            }
                        }
                    }
                    
                    Button {
                        text: root.isChinese ? "上传到数据库" : "Upload to Database"
                        enabled: root.isFileUploaded && root.userTableName.trim() !== ""
                        Layout.alignment: Qt.AlignLeft
                        
                        onClicked: {
                            if (!root.continuousLearningController) {
                                console.log("ERROR: continuousLearningController is undefined!")
                                return
                            }
                            
                            if (root.userTableName.trim() === "") {
                                dataFileStatus.text = root.isChinese ? "请输入表名" : "Please enter table name"
                                dataFileStatus.color = "#dc3545"
                                return
                            }
                            
                            try {
                                // 构建完整的表名
                                let fullTableName = (root.isTrainingData ? "data_" : "test_") + root.userTableName.trim()
                                
                                let result = root.continuousLearningController.uploadDataFileToDatabase(fullTableName)
                                if (result && result.success) {
                                    dataFileStatus.text = root.isChinese ? "上传成功" : "Upload successful"
                                    dataFileStatus.color = "#28a745"
                                    root.refreshTables()
                                    // 清空输入
                                    root.userTableName = ""
                                    tableNameInput.text = ""
                                } else {
                                    dataFileStatus.text = root.isChinese ? 
                                        "上传失败: " + (result.error || "未知错误") :
                                        "Upload failed: " + (result.error || "Unknown error")
                                    dataFileStatus.color = "#dc3545"
                                }
                            } catch (e) {
                                console.log("Error uploading file:", e)
                                dataFileStatus.text = root.isChinese ? "上传出错" : "Upload error"
                                dataFileStatus.color = "#dc3545"
                            }
                        }
                    }
                }
            }
            
            // 数据表管理区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16
                    
                    RowLayout {
                        Text {
                            text: root.isChinese ? "数据表管理" : "Data Tables Management"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#212529"
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: root.isChinese ? "刷新列表" : "Refresh List"
                            onClicked: root.refreshTables()
                        }
                    }
                    
                    // 表格列表
                    ListView {
                        id: tablesListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        model: root.availableTables
                        
                        delegate: Rectangle {
                            id: delegateItem
                            required property var modelData
                            required property int index
                            
                            width: tablesListView.width
                            height: 60
                            color: index % 2 === 0 ? "#f8f9fa" : "#ffffff"
                            border.width: root.selectedTable === modelData ? 2 : 1
                            border.color: root.selectedTable === modelData ? "#007bff" : "#dee2e6"
                            radius: 4
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 16
                                
                                Text {
                                    text: delegateItem.modelData
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#212529"
                                    Layout.fillWidth: true
                                }
                                
                                // 预览按钮
                                Button {
                                    text: root.isChinese ? "预览" : "Preview"
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: 32
                                    
                                    onClicked: {
                                        console.log("===== Preview Button Clicked =====")
                                        console.log("Button working! modelData:", delegateItem.modelData)
                                        
                                        try {
                                            root.selectedTable = delegateItem.modelData
                                            console.log("Set selectedTable to:", root.selectedTable)
                                            console.log("Calling root.previewTable...")
                                            root.previewTable(delegateItem.modelData)
                                        } catch (e) {
                                            console.log("ERROR in preview button click:", e)
                                        }
                                    }
                                }
                                
                                // 删除按钮
                                Button {
                                    id: deleteBtn
                                    text: root.isChinese ? "删除" : "Delete"
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: 32
                                    
                                    background: Rectangle {
                                        color: deleteBtn.pressed ? "#c82333" : (deleteBtn.hovered ? "#e74c3c" : "#dc3545")
                                        radius: 4
                                        border.color: "#dc3545"
                                        border.width: 1
                                    }
                                    
                                    contentItem: Text {
                                        text: deleteBtn.text
                                        font: deleteBtn.font
                                        color: "white"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: {
                                        console.log("===== Delete Button Clicked =====")
                                        console.log("Delete button working! modelData:", delegateItem.modelData)
                                        
                                        try {
                                            deleteConfirmDialog.tableName = delegateItem.modelData
                                            deleteConfirmDialog.open()
                                        } catch (e) {
                                            console.log("ERROR in delete button click:", e)
                                        }
                                    }
                                }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 170  // 为按钮留出空间
                                onClicked: {
                                    root.selectedTable = delegateItem.modelData
                                }
                            }
                        }
                    }
                }
            }
            
            // 数据预览区域
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 400
                color: "white"
                radius: 8
                border.width: 1
                border.color: "#dee2e6"
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    
                    Text {
                        text: root.isChinese ? "数据预览" : "Data Preview"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#212529"
                    }
                    
                    // 表格容器
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#f8f9fa"
                        border.width: 1
                        border.color: "#dee2e6"
                        radius: 4
                        
                        ScrollView {
                            id: tableScrollView
                            anchors.fill: parent
                            anchors.margins: 2
                            contentWidth: tableView.width
                            contentHeight: tableView.height
                            
                            // 表格视图
                            Column {
                                id: tableView
                                width: Math.max(tableScrollView.width - 4, headerRow.implicitWidth)
                                
                                // 表头
                                Row {
                                    id: headerRow
                                    visible: root.previewData.columns && root.previewData.columns.length > 0
                                    
                                    Repeater {
                                        model: root.previewData.columns || []
                                        
                                        Rectangle {
                                            required property var modelData
                                            
                                            width: Math.max(120, headerText.implicitWidth + 20)
                                            height: 40
                                            color: "#007bff"
                                            border.width: 1
                                            border.color: "#0056b3"
                                            
                                            Text {
                                                id: headerText
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: "#ffffff"
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                                
                                // 数据行
                                Repeater {
                                    model: root.previewData.rows || []
                                    
                                    Row {
                                        required property var modelData
                                        required property int index
                                        
                                        Repeater {
                                            model: parent.modelData || []
                                            
                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                
                                                width: Math.max(120, cellText.implicitWidth + 20)
                                                height: 35
                                                color: "#ffffff"
                                                border.width: 1
                                                border.color: "#dee2e6"
                                                
                                                Text {
                                                    id: cellText
                                                    anchors.centerIn: parent
                                                    text: parent.modelData || ""
                                                    font.pixelSize: 11
                                                    color: "#212529"
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // 空状态提示
                                Rectangle {
                                    width: parent.width
                                    height: 100
                                    color: "transparent"
                                    visible: !root.previewData.columns || root.previewData.columns.length === 0
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isChinese ? "选择表格进行预览..." : "Select a table to preview..."
                                        font.pixelSize: 14
                                        color: "#6c757d"
                                        font.italic: true
                                    }
                                }
                            }
                        }
                    }
                    
                    // 预览信息
                    Text {
                        id: previewInfo
                        text: root.previewData.total_rows > 0 ? 
                            (root.isChinese ? 
                                `显示前 ${root.previewData.rows.length} 行，共 ${root.previewData.total_rows} 行` :
                                `Showing first ${root.previewData.rows.length} rows of ${root.previewData.total_rows} total`) : ""
                        font.pixelSize: 11
                        color: "#6c757d"
                        visible: text !== ""
                    }
                }
            }
        }
    }
    
    // 文件选择对话框
    FileDialog {
        id: dataFileDialog
        title: root.isChinese ? "选择数据文件" : "Select Data File"
        nameFilters: [
            "Excel files (*.xlsx *.xls)", 
            "CSV files (*.csv)", 
            "All files (*)"
        ]
        onAccepted: {
            let filePath = selectedFile.toString().replace("file:///", "")
            dataFileStatus.text = filePath.split('/').pop()
            dataFileStatus.color = "#28a745"
            root.isFileUploaded = true
            
            if (root.continuousLearningController) {
                root.continuousLearningController.setDataFilePath(filePath)
            }
        }
        onRejected: {
            console.log("File selection cancelled")
        }
    }
    
    // 删除确认对话框
    Dialog {
        id: deleteConfirmDialog
        title: root.isChinese ? "确认删除" : "Confirm Delete"
        modal: true
        anchors.centerIn: parent
        
        property string tableName: ""
        
        background: Rectangle {
            color: "white"
            radius: 8
            border.width: 1
            border.color: "#dee2e6"
        }
        
        contentItem: ColumnLayout {
            spacing: 16
            
            Text {
                text: root.isChinese ? 
                    `确定要删除数据表 "${deleteConfirmDialog.tableName}" 吗？\n此操作不可撤销。` :
                    `Are you sure you want to delete table "${deleteConfirmDialog.tableName}"?\nThis action cannot be undone.`
                color: "#212529"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 12
                
                Button {
                    text: root.isChinese ? "取消" : "Cancel"
                    onClicked: deleteConfirmDialog.close()
                }
                
                Button {
                    id: dialogDeleteBtn
                    text: root.isChinese ? "删除" : "Delete"
                    
                    background: Rectangle {
                        color: dialogDeleteBtn.pressed ? "#c82333" : (dialogDeleteBtn.hovered ? "#e74c3c" : "#dc3545")
                        radius: 4
                        border.color: "#dc3545"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: dialogDeleteBtn.text
                        font: dialogDeleteBtn.font
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        root.deleteTable(deleteConfirmDialog.tableName)
                        deleteConfirmDialog.close()
                    }
                }
            }
        }
    }
    
    // 刷新表列表
    function refreshTables() {
        if (root.continuousLearningController) {
            try {
                root.availableTables = root.continuousLearningController.getAvailableTables()
            } catch (e) {
                console.log("Error refreshing tables:", e)
            }
        }
    }
    
    // 预览表数据
    function previewTable(tableName) {
        console.log("previewTable called with tableName:", tableName)
        
        if (root.continuousLearningController) {
            try {
                let preview = root.continuousLearningController.previewTableData(tableName)
                console.log("Preview result:", preview)
                if (preview && preview.success) {
                    root.previewData = {
                        "columns": preview.columns || [],
                        "rows": preview.rows || [],
                        "total_rows": preview.total_rows || 0
                    }
                } else {
                    root.previewData = {
                        "columns": [],
                        "rows": [],
                        "total_rows": 0
                    }
                    console.log("Preview failed:", preview.error || "未知错误")
                }
            } catch (e) {
                console.log("Error previewing table:", e)
                root.previewData = {
                    "columns": [],
                    "rows": [],
                    "total_rows": 0
                }
            }
        } else {
            console.log("ERROR: continuousLearningController is null/undefined")
            root.previewData = {
                "columns": [],
                "rows": [],
                "total_rows": 0
            }
        }
    }
    
    // 删除表
    function deleteTable(tableName) {
        if (root.continuousLearningController) {
            try {
                let result = root.continuousLearningController.deleteTable(tableName)
                if (result && result.success) {
                    // 刷新列表
                    refreshTables()
                    // 清空预览
                    if (root.selectedTable === tableName) {
                        root.selectedTable = ""
                        root.previewData = {
                            "columns": [],
                            "rows": [],
                            "total_rows": 0
                        }
                    }
                } else {
                    console.log("Delete failed:", result.error)
                }
            } catch (e) {
                console.log("Error deleting table:", e)
            }
        }
    }
    
    Connections {
        target: root.continuousLearningController
        
        function onDataLoaded(dataInfo) {
            if (dataInfo && !dataInfo.error) {
                root.refreshTables()
            }
        }
    }
    
    Component.onCompleted: {
        console.log("DataManagement Component.onCompleted")
        console.log("continuousLearningController:", root.continuousLearningController)
        
        // 初始化表列表
        refreshTables()
    }
}
