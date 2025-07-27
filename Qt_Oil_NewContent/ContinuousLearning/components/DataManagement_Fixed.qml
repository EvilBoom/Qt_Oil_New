import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls.Material

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
                        font.pixelSize: 20
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
                Layout.preferredHeight: 200
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
                        color: "#495057"
                    }
                    
                    Text {
                        text: root.isChinese ? "支持Excel(.xlsx/.xls)和CSV(.csv)文件格式" : "Support Excel(.xlsx/.xls) and CSV(.csv) file formats"
                        font.pixelSize: 12
                        color: "#6c757d"
                    }
                    
                    RowLayout {
                        spacing: 12
                        
                        Button {
                            text: root.isChinese ? "选择文件" : "Select File"
                            onClicked: dataFileDialog.open()
                        }
                        
                        Text {
                            id: dataFileStatus
                            text: root.isChinese ? "未选择文件" : "No file selected"
                            color: "#6c757d"
                            font.pixelSize: 12
                        }
                    }
                    
                    Button {
                        text: root.isChinese ? "上传到数据库" : "Upload to Database"
                        enabled: root.isFileUploaded
                        Layout.alignment: Qt.AlignLeft
                        
                        onClicked: {
                            if (!root.continuousLearningController) {
                                console.log("ERROR: continuousLearningController is undefined!")
                                return
                            }
                            
                            try {
                                let result = root.continuousLearningController.uploadDataFileToDatabase()
                                if (result && result.success) {
                                    dataFileStatus.text = root.isChinese ? "上传成功" : "Upload successful"
                                    dataFileStatus.color = "#28a745"
                                    root.refreshTables()
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
                            height: 50
                            color: index % 2 === 0 ? "#ffffff" : "#f8f9fa"
                            border.width: root.selectedTable === modelData ? 2 : 0
                            border.color: "#007bff"
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                Text {
                                    text: delegateItem.modelData
                                    font.pixelSize: 14
                                    color: "#212529"
                                    Layout.fillWidth: true
                                }
                                
                                Button {
                                    id: previewBtn
                                    text: root.isChinese ? "预览" : "Preview"
                                    implicitHeight: 32
                                    implicitWidth: 60
                                    font.pixelSize: 12
                                    
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
                                
                                Button {
                                    id: deleteBtn
                                    text: root.isChinese ? "删除" : "Delete"
                                    implicitHeight: 32
                                    implicitWidth: 60
                                    font.pixelSize: 12
                                    
                                    Material.background: "#dc3545"
                                    
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
                                anchors.rightMargin: 130  // 为按钮留出空间
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
                Layout.preferredHeight: 250
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
                    
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        TextArea {
                            id: dataPreviewText
                            text: root.isChinese ? "选择表格进行预览..." : "Select a table to preview..."
                            color: "#495057"
                            font.pixelSize: 12
                            font.family: "Consolas, Monaco, monospace"
                            readOnly: true
                            wrapMode: Text.WordWrap
                            selectByMouse: true
                        }
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
        
        contentItem: ColumnLayout {
            spacing: 16
            
            Text {
                text: root.isChinese ? 
                    `确定要删除数据表 "${deleteConfirmDialog.tableName}" 吗？\n此操作不可撤销。` :
                    `Are you sure you want to delete table "${deleteConfirmDialog.tableName}"?\nThis action cannot be undone.`
                color: "#495057"
                wrapMode: Text.WordWrap
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignRight
                
                Button {
                    text: root.isChinese ? "取消" : "Cancel"
                    onClicked: deleteConfirmDialog.close()
                }
                
                Button {
                    text: root.isChinese ? "删除" : "Delete"
                    Material.background: "#dc3545"
                    onClicked: {
                        deleteTable(deleteConfirmDialog.tableName)
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
                    dataPreviewText.text = preview.data
                } else {
                    dataPreviewText.text = root.isChinese ? 
                        "预览失败: " + (preview.error || "未知错误") :
                        "Preview failed: " + (preview.error || "Unknown error")
                }
            } catch (e) {
                console.log("Error previewing table:", e)
                dataPreviewText.text = root.isChinese ? 
                    "预览出错" : "Preview error"
            }
        } else {
            console.log("ERROR: continuousLearningController is null/undefined")
            dataPreviewText.text = root.isChinese ? 
                "控制器未初始化" : "Controller not initialized"
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
                        dataPreviewText.text = root.isChinese ? "选择表格进行预览..." : "Select a table to preview..."
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
                refreshTables()
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
