// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step8_ReportGeneration.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtWebEngine
import "../Components" as LocalComponents

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})

    property var wellsList: []
    property var selectedWell: null
    property bool showWellDialog: false
    // 🔥 添加增强数据属性
    property var enhancedData: ({})
    property bool dataEnhanced: false


    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)

    // 内部属性
    property string reportHtml: ""
    property bool isEditing: false
    property string selectedTemplate: "standard"
    property bool reportGenerated: false
    property string currentProjectName: ""

    color: "transparent"

    // 🔥 修复：更新Component.onCompleted
    Component.onCompleted: {
        console.log("=== Step8 报告生成初始化 ===")
        console.log("stepData:", JSON.stringify(stepData))
        console.log("wellId:", wellId)
        if ((!stepData.well || !stepData.well.wellName) && controller && controller.loadWellsWithParameters) {
            // 假设有 currentProjectId 属性
            controller.loadWellsWithParameters(controller.currentProjectId)
        }

        // 如果有控制器且有井ID，请求数据
        if (controller && controller.prepareReportData && wellId > 0) {
            console.log("📞 请求控制器准备报告数据，井ID:", wellId)
            controller.prepareReportData(stepData)
        } else if (stepData && Object.keys(stepData).length > 0) {
            // 如果已有数据，直接生成报告
            console.log("💡 使用已有stepData生成报告")
            extractProjectName()
            generateReport()
        } else {
            console.warn("⚠️ 井ID无效或控制器不可用，尝试从其他控制器获取井信息")
            loadWellInformation()
            extractProjectName()
            generateReport()
        }
    }

    // 🔥 修复：添加井ID更新监听
    onWellIdChanged: {
        console.log("=== Step8 wellId 更新 ===", wellId)
        if (wellId > 0 && controller && controller.prepareReportData) {
            console.log("📞 wellId更新，重新请求数据")
            controller.prepareReportData(stepData)
        }
    }

    // 监控数据变化
    onStepDataChanged: {
        console.log("=== Step8 stepData 变化 ===")
        console.log("新数据:", JSON.stringify(stepData))

        // 提取项目名称
        if (stepData.project && stepData.project.projectName) {
            currentProjectName = stepData.project.projectName
        } else if (stepData.parameters && stepData.parameters.projectName) {
            currentProjectName = stepData.parameters.projectName
        }

        // 重新生成报告
        generateReport()
    }

    // 🔥 修复：onReportDataPrepared连接
    Connections {
        target: controller
        enabled: controller !== null

        function onWellsListLoaded(list) {
            root.wellsList = list
            if (list.length > 0) {
                root.showWellDialog = true
            }
        }

        function onReportDataPrepared(enhanced_data) {
            console.log("=== 🎉 接收到增强的报告数据 ===")

            // 🔥 合并增强数据到stepData
            if (enhanced_data.well) {
                if (!stepData.well) stepData.well = {}
                Object.assign(stepData.well, enhanced_data.well)
            }

            if (enhanced_data.calculation) {
                if (!stepData.calculation) stepData.calculation = {}
                Object.assign(stepData.calculation, enhanced_data.calculation)
            }

            if (enhanced_data.production_casing) {
                stepData.production_casing = enhanced_data.production_casing
            }

            if (enhanced_data.project_details) {
                if (!stepData.project_details) stepData.project_details = {}
                Object.assign(stepData.project_details, enhanced_data.project_details)
            }

            enhancedData = enhanced_data
            dataEnhanced = true  // 🔥 关键：设置数据已增强
            extractProjectName()
            generateReport()
        }
    }
    LocalComponents.WellSelectionDialog {
        id: wellDialog
        visible: root.showWellDialog
        wellsList: root.wellsList
        onWellConfirmed: {
            root.selectedWell = well
            root.showWellDialog = false
            // 补充stepData
            if (!root.stepData.well) root.stepData.well = {}
            root.stepData.well.wellName = well.name
            root.stepData.well.totalDepth = well.totalDepth || 0
            root.stepData.well.verticalDepth = well.verticalDepth || well.totalDepth || 0
            root.stepData.well.wellType = well.wellType || "生产井"
            root.stepData.well.wellStatus = well.status || "Active"
            // 触发数据增强和报告生成
            if (controller && controller.prepareReportData) {
                controller.prepareReportData(root.stepData)
            }
        }
        onRejected: root.showWellDialog = false
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // 标题栏
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: isChineseMode ? "设备选型报告" : "Equipment Selection Report"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }

            Item { Layout.fillWidth: true }
            Button {
                text: "选择井信息"
                onClicked: root.showWellDialog = true
                visible: root.wellsList.length > 0
            }
            // 模板选择
            ComboBox {
                id: templateSelector
                Layout.preferredWidth: 150
                model: [
                    isChineseMode ? "标准报告" : "Standard Report",
                    isChineseMode ? "详细报告" : "Detailed Report",
                    isChineseMode ? "简要报告" : "Brief Report"
                ]
                onCurrentIndexChanged: {
                    switch(currentIndex) {
                        case 0: selectedTemplate = "standard"; break
                        case 1: selectedTemplate = "detailed"; break
                        case 2: selectedTemplate = "brief"; break
                    }
                    generateReport()
                }
            }

            // 编辑按钮
            Button {
                text: isEditing ? (isChineseMode ? "完成编辑" : "Done Editing")
                               : (isChineseMode ? "编辑报告" : "Edit Report")
                enabled: reportGenerated
                onClicked: {
                    isEditing = !isEditing
                    if (!isEditing) {
                        saveEditedContent()
                    }
                }
            }

            // 导出按钮组
            Row {
                spacing: 8

                Button {
                    text: "Word"
                    highlighted: true
                    enabled: reportGenerated
                    onClicked: exportToWord()
                }

                Button {
                    text: "PDF"
                    enabled: reportGenerated
                    onClicked: exportToPDF()
                }

                // Button {
                //     text: "Excel"
                //     enabled: reportGenerated
                //     onClicked: exportToExcel()
                // }
            }
        }
        // 在现有代码的基础上添加数据完整性显示
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: enhancedData.data_completeness ? 60 : 0
            color: Material.color(Material.Blue, Material.Shade50)
            radius: 8
            visible: enhancedData.data_completeness && enhancedData.data_completeness.overall_completeness < 90

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12

                Text {
                    text: "ℹ️"
                    font.pixelSize: 24
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: isChineseMode ? "数据完整性提示" : "Data Completeness Notice"
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Text {
                        text: enhancedData.data_completeness ?
                              (isChineseMode ?
                               `当前数据完整性: ${enhancedData.data_completeness.overall_completeness.toFixed(1)}%，部分数据可能使用默认值` :
                               `Current data completeness: ${enhancedData.data_completeness.overall_completeness.toFixed(1)}%, some data may use default values`) :
                              ""
                        color: Material.secondaryTextColor
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        // 主内容区域
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            // 左侧：报告预览/编辑区
            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 500
                color: Material.dialogColor
                radius: 8

                // 报告内容加载器
                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    anchors.margins: 1
                    sourceComponent: isEditing ? editComponent : previewComponent
                }

                // 修复WebEngineView的previewComponent部分
                Component {
                    id: previewComponent

                    WebEngineView {
                        id: webView
                        property bool isLoading: false

                        onLoadingChanged: function(loadRequest) {
                            console.log("WebEngineView loading状态:", loadRequest.status)

                            if (loadRequest.status === WebEngineView.LoadStartedStatus) {
                                isLoading = true
                            } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                                isLoading = false
                                reportGenerated = true
                                console.log("✅ 报告页面加载成功")
                            } else if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                                isLoading = false
                                console.error("❌ 报告页面加载失败")
                            }
                        }

                        Component.onCompleted: {
                            console.log("WebEngineView组件完成初始化")
                            if (reportHtml && reportHtml.length > 0) {
                                console.log("初始加载报告HTML，长度:", reportHtml.length)
                                loadHtml(reportHtml, "file:///")
                            }
                        }

                        // 🔥 修复：避免循环重定向，只在HTML真正变化时重新加载
                        Connections {
                            target: root
                            function onReportHtmlChanged() {
                                if (reportHtml && reportHtml.length > 0 && !webView.isLoading) {
                                    console.log("报告HTML更新，重新加载，长度:", reportHtml.length)
                                    webView.loadHtml(reportHtml, "file:///")
                                }
                            }
                        }
                    }
                }


                // 编辑组件
                Component {
                    id: editComponent

                    ScrollView {
                        clip: true

                        TextArea {
                            id: htmlEditor
                            text: reportHtml
                            selectByMouse: true
                            wrapMode: TextArea.Wrap
                            font.family: "Consolas, Monaco, monospace"
                            font.pixelSize: 12

                            background: Rectangle {
                                color: Material.backgroundColor
                            }
                        }
                    }
                }

                // 加载指示器
                BusyIndicator {
                    anchors.centerIn: parent
                    running: !reportGenerated
                    visible: running
                }
            }

            // 右侧：报告大纲和快速导航
            Rectangle {
                SplitView.preferredWidth: 300
                SplitView.minimumWidth: 250
                color: Material.dialogColor
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: isChineseMode ? "报告大纲" : "Report Outline"
                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Material.dividerColor
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Column {
                            width: parent.width
                            spacing: 8

                            // 报告章节
                            Repeater {
                                model: getReportSections()

                                Rectangle {
                                    width: parent.width
                                    height: sectionContent.height + 16
                                    color: sectionMouseArea.containsMouse
                                           ? Material.color(Material.Blue, Material.Shade50)
                                           : "transparent"
                                    radius: 6

                                    MouseArea {
                                        id: sectionMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: navigateToSection(modelData.id)
                                    }

                                    Row {
                                        id: sectionContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: 16
                                        }

                                        Column {
                                            width: parent.width - 30

                                            Text {
                                                text: modelData.title
                                                font.pixelSize: 14
                                                font.bold: modelData.level === 1
                                                color: Material.primaryTextColor
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            Text {
                                                text: modelData.status
                                                font.pixelSize: 11
                                                color: modelData.complete
                                                       ? Material.color(Material.Green)
                                                       : Material.color(Material.Orange)
                                                visible: modelData.status.length > 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Material.dividerColor
                    }

                    // 报告统计
                    Column {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: isChineseMode ? "报告统计" : "Report Statistics"
                            font.pixelSize: 14
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Grid {
                            width: parent.width
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 4

                            Text {
                                text: isChineseMode ? "设备数量:" : "Equipment Count:"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }
                            Text {
                                text: getEquipmentCount() + (isChineseMode ? " 件" : " items")
                                font.pixelSize: 12
                                color: Material.primaryTextColor
                                font.bold: true
                            }

                            Text {
                                text: isChineseMode ? "总功率:" : "Total Power:"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }
                            Text {
                                text: getTotalPower() + " HP"
                                font.pixelSize: 12
                                color: Material.primaryTextColor
                                font.bold: true
                            }

                            Text {
                                text: isChineseMode ? "系统效率:" : "System Efficiency:"
                                font.pixelSize: 12
                                color: Material.secondaryTextColor
                            }
                            Text {
                                text: getSystemEfficiency() + "%"
                                font.pixelSize: 12
                                color: Material.primaryTextColor
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        // 底部操作栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Material.dialogColor
            radius: 8

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12

                // 报告信息
                Column {
                    Text {
                        text: isChineseMode ? "报告编号: " + getReportNumber() : "Report No: " + getReportNumber()
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                    Text {
                        text: isChineseMode
                              ? "生成时间: " + Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")
                              : "Generated: " + Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")
                        font.pixelSize: 12
                        color: Material.secondaryTextColor
                    }
                }

                Item { Layout.fillWidth: true }

                // 操作按钮
                Row {
                    spacing: 12

                    Button {
                        text: isChineseMode ? "保存草稿" : "Save Draft"
                        flat: true
                        onClicked: saveDraft()
                    }

                    Button {
                        text: isChineseMode ? "打印预览" : "Print Preview"
                        onClicked: showPrintPreview()
                    }

                    Button {
                        text: isChineseMode ? "完成" : "Finish"
                        highlighted: true
                        enabled: reportGenerated
                        onClicked: finishReport()
                    }
                }
            }
        }
    }

    // 文件对话框
    FileDialog {
        id: saveFileDialog
        acceptLabel: isChineseMode ? "保存" : "Save"
        rejectLabel: isChineseMode ? "取消" : "Cancel"
        fileMode: FileDialog.SaveFile

        property string exportFormat: "pdf"

        onAccepted: {
            exportToFile(selectedFile, exportFormat)
        }
    }

    // 🔥 添加从其他控制器获取井信息的函数
    function loadWellInformation() {
        console.log("🔍 尝试从其他控制器获取井信息，井ID:", wellId)

        // 尝试从wellController获取当前井信息
        if (typeof wellController !== "undefined" && wellController !== null && wellId > 0) {
            try {
                console.log("📞 使用wellController获取井信息")
                // wellController.getWellData(wellId) // 这会触发信号

                // 🔥 直接从wellController的currentWellData属性获取
                if (wellController.currentWellData) {
                    var wellData = wellController.currentWellData
                    console.log("✅ 从wellController获取到井数据:", JSON.stringify(wellData))

                    // 补充井信息到stepData
                    if (!stepData.well) {
                        stepData.well = {}
                    }

                    stepData.well.wellName = wellData.well_name || `Well-${wellId}`
                    stepData.well.totalDepth = wellData.total_depth || 0
                    stepData.well.verticalDepth = wellData.vertical_depth || stepData.well.totalDepth
                    stepData.well.wellType = wellData.well_type || 'Production'
                    stepData.well.wellStatus = wellData.well_status || 'Active'

                    console.log("✅ 井信息已补充到stepData")
                }
            } catch (error) {
                console.warn("⚠️ 从wellController获取井信息失败:", error)
            }
        }

        // 尝试从wellStructureController获取计算结果
        if (typeof wellStructureController !== "undefined" && wellStructureController !== null) {
            try {
                console.log("📞 使用wellStructureController获取计算结果")

                // 如果有计算结果属性
                if (wellStructureController.calculationResult) {
                    var calcResult = wellStructureController.calculationResult
                    console.log("✅ 从wellStructureController获取到计算结果:", JSON.stringify(calcResult))

                    // 补充计算结果到stepData
                    if (!stepData.calculation) {
                        stepData.calculation = {}
                    }

                    stepData.calculation.perforation_depth = calcResult.perforation_depth || 0
                    stepData.calculation.pump_hanging_depth = calcResult.pump_hanging_depth || 0
                    stepData.calculation.pump_measured_depth = calcResult.pump_measured_depth || 0

                    console.log("✅ 计算结果已补充到stepData")
                }
            } catch (error) {
                console.warn("⚠️ 从wellStructureController获取计算结果失败:", error)
            }
        }
    }


    function generateReportHtml(template) {
        console.log("=== 生成报告HTML ===")
        console.log("当前stepData:", JSON.stringify(stepData))

        var html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>${currentProjectName || "项目"} 设备选型报告</title>
    <style>
        body {
            font-family: 'Times New Roman', '宋体', serif;
            line-height: 1.6;
            color: #333;
            max-width: 210mm;
            margin: 0 auto;
            padding: 20px;
            background: #fff;
        }

        .header {
            text-align: center;
            border-bottom: 3px solid #1e3a5f;
            padding-bottom: 20px;
            margin-bottom: 30px;
            position: relative;
        }

        .header-logo {
            position: absolute;
            left: 0;
            top: 0;
        }

        .header-date {
            position: absolute;
            right: 0;
            top: 0;
            font-size: 12px;
        }

        .header-company {
            font-size: 18px;
            font-weight: bold;
            margin: 10px 0;
        }

        h1 {
            color: #1e3a5f;
            font-size: 28px;
            margin: 10px 0;
        }

        h2 {
            color: #1e3a5f;
            font-size: 20px;
            margin-top: 30px;
            margin-bottom: 15px;
            padding-bottom: 8px;
            border-bottom: 2px solid #e0e0e0;
        }

        h3 {
            color: #4a90e2;
            font-size: 16px;
            margin-top: 20px;
            margin-bottom: 10px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }

        th {
            background-color: #f5f7fa;
            color: #1e3a5f;
            font-weight: 600;
            text-align: left;
            padding: 12px;
            border: 1px solid #e0e0e0;
        }

        td {
            padding: 10px 12px;
            border: 1px solid #e0e0e0;
        }

        tr:nth-child(even) {
            background-color: #fafafa;
        }

        .equipment-summary-table th:first-child {
            background-color: #ffcc00;
        }

        .chart-placeholder {
            background: #f8f9fa;
            border: 2px dashed #dee2e6;
            height: 300px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 20px 0;
            color: #6c757d;
            font-style: italic;
        }

        .page-break {
            page-break-before: always;
        }

        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 2px solid #e0e0e0;
            text-align: center;
            color: #666;
            font-size: 12px;
        }

        @media print {
            body {
                margin: 0;
                padding: 10mm;
            }
            .no-print {
                display: none;
            }
        }
    </style>
</head>
<body>
    ${generateReportContent(template)}
</body>
</html>
        `
        return html
    }

    function generateReportContent(template) {
        var content = ""
        var projectName = currentProjectName || "测试项目"

        // 从stepData中提取项目名称
        if (stepData.parameters && stepData.parameters.projectName) {
            projectName = stepData.parameters.projectName
        } else if (stepData.project && stepData.project.projectName) {
            projectName = stepData.project.projectName
        }

        console.log("使用项目名称:", projectName)

        // 报告头部 - 参考Temp.py格式
        content += `
        <div class="header">
            <div class="header-logo">
                <span style="font-size: 12px;">🏢</span>
            </div>
            <div class="header-company">中国石油技术开发有限公司</div>
            <div class="header-date">${Qt.formatDateTime(new Date(), "yyyy-MM-dd")}</div>
            <h1>${projectName} 设备选型报告（测试）</h1>
        </div>
        `

        // 1. 项目基本信息
        content += `
        <section id="project-info">
            <h2>1. 项目基本信息</h2>
            <p><strong>项目名称：</strong>${projectName}</p>
            ${generateProjectInfoTable()}
        </section>
        `

        // 2. 生产套管井身结构信息
        content += `
        <section id="well-structure">
            <h2>2. 生产套管井身结构信息</h2>
            ${generateWellStructureTable()}
        </section>
        `

        // 3. 井轨迹图
        content += `
        <section id="well-trajectory">
            <h2>3. 井轨迹图</h2>
            <div class="chart-placeholder">
                井轨迹图将在此显示（需要实际数据绘制）
            </div>
        </section>
        `

        // 4. 生产参数及模型预测
        content += `
        <section id="production-parameters">
            <h2>4. 生产参数及模型预测</h2>
            ${generateProductionParametersTable()}
        </section>
        `

        // 5. 设备选型推荐
        content += `
        <section id="equipment-selection">
            <h2>5. 设备选型推荐</h2>
            ${generateEquipmentSelection()}
        </section>
        `

        // 6. 设备性能曲线
        content += `
        <div class="page-break"></div>
        <section id="performance-curves">
            <h2>6. 设备性能曲线</h2>

            <h3>6.1 单级性能曲线</h3>
            <div class="chart-placeholder">
                单级泵性能曲线图（包含扬程、功率、效率曲线）
            </div>

            <div class="page-break"></div>
            <h3>6.2 多级性能曲线</h3>
            <div class="chart-placeholder">
                多级泵性能曲线图（不同频率下的性能对比）
            </div>
        </section>
        `

        // 备注信息
        content += `
        <section id="notes">
            <p><strong>备注:</strong></p>
            <p>公司将提供地面设备，如SDT/GENSET、SUT、接线盒、地面电力电缆、井口和井口电源连接器。</p>
            <p>供应商将提供安装附件，如VSD、O形圈、连接螺栓、垫圈、带帽螺钉、电机油、电缆带、电缆拼接器材料、渡线器、扶正器、止回阀、排放头和备件。</p>
        </section>
        `

        // 7. 总结 - 参考Temp.py中的汇总表格
        content += `
        <div class="page-break"></div>
        <section id="summary">
            <h2>7. 总结</h2>
            ${generateSummaryTable()}
        </section>
        `

        // 报告尾部
        content += `
        <div class="footer">
            <p>本报告由油井设备智能管理系统自动生成</p>
            <p>技术支持：中国石油技术开发有限公司</p>
        </div>
        `

        return content
    }

    // 🔥 修复 safeValue 函数，支持嵌套属性访问
    function safeValue(obj, path, defaultValue) {
        if (!obj || !path) return defaultValue || "N/A"

        try {
            var keys = path.split('.')
            var current = obj

            for (var i = 0; i < keys.length; i++) {
                if (current === null || current === undefined || !(keys[i] in current)) {
                    return defaultValue || "N/A"
                }
                current = current[keys[i]]
            }

            if (current === null || current === undefined || current === "") {
                return defaultValue || "N/A"
            }

            return current
        } catch (error) {
            console.warn("safeValue访问失败:", path, error)
            return defaultValue || "N/A"
        }
    }

    // 🔥 根据数据类型获取默认值
    function getDefaultByType(dataType) {
        switch(dataType) {
            case 'number': return 0
            case 'pressure': return 0
            case 'production': return 0
            case 'temperature': return 0
            case 'depth': return 0
            case 'percentage': return 0
            case 'length': return 0
            case 'power': return 0
            case 'date': return new Date().toLocaleDateString()
            case 'name': return '待定'
            case 'company': return '中国石油技术开发有限公司'
            case 'location': return '测试地点'
            case 'description': return '无'
            default: return 'N/A'
        }
    }

    // 🔥 提取项目名称
    function extractProjectName() {
        // 优先级：增强数据 > stepData > 默认值
        if (enhancedData.project_details && enhancedData.project_details.project_name) {
            currentProjectName = enhancedData.project_details.project_name
        } else if (enhancedData.defaults && enhancedData.defaults.project_name) {
            currentProjectName = enhancedData.defaults.project_name
        } else if (stepData.project && stepData.project.projectName) {
            currentProjectName = stepData.project.projectName
        } else if (stepData.parameters && stepData.parameters.projectName) {
            currentProjectName = stepData.parameters.projectName
        } else {
            currentProjectName = "测试项目"
        }

        console.log("📝 使用项目名称:", currentProjectName)
    }

    // 🔥 根据数据类型格式化值
    function formatByType(value, dataType) {
        try {
            switch(dataType) {
                case 'number':
                    return parseFloat(value).toFixed(2)
                case 'pressure':
                    return parseFloat(value).toFixed(1) + ' psi'
                case 'production':
                    return parseFloat(value).toFixed(1) + ' bbl/d'
                case 'temperature':
                    return parseFloat(value).toFixed(1) + ' °F'
                case 'depth':
                    return parseFloat(value).toFixed(0) + ' ft'
                case 'percentage':
                    return parseFloat(value).toFixed(1) + ' %'
                case 'length':
                    return parseFloat(value).toFixed(1) + ' ft'
                case 'power':
                    return parseFloat(value).toFixed(0) + ' HP'
                case 'efficiency':
                    return parseFloat(value).toFixed(1) + ' %'
                case 'voltage':
                    return parseFloat(value).toFixed(0) + ' V'
                case 'current':
                    return parseFloat(value).toFixed(1) + ' A'
                case 'weight':
                    return parseFloat(value).toFixed(0) + ' lbs'
                case 'diameter':
                    return parseFloat(value).toFixed(2) + ' in'
                case 'speed':
                    return parseFloat(value).toFixed(0) + ' RPM'
                default:
                    return value
            }
        } catch (e) {
            return value
        }
    }

    // 🔥 修复 safeToFixed 函数
    function safeToFixed(value, decimals, defaultValue) {
        if (value === undefined || value === null || value === "" || isNaN(parseFloat(value))) {
            return defaultValue || "0"
        }
        return parseFloat(value).toFixed(decimals || 2)
    }

    // 🔥 修复项目信息表格，使用实际数据
    function generateProjectInfoTable() {
        var wellInfo = stepData.well || {}
        var projectDetails = stepData.project_details || {}
        var wellNumber = stepData.well_number || wellInfo.wellName || "WELL-001"

        return `
        <table>
            <tr><td>公司</td><td>${projectDetails.company_name || '中国石油技术开发有限公司'}</td></tr>
            <tr><td>井号</td><td>${wellNumber}</td></tr>
            <tr><td>项目名称</td><td>${projectDetails.project_name || currentProjectName}</td></tr>
            <tr><td>油田</td><td>${projectDetails.oil_field || '测试油田'}</td></tr>
            <tr><td>地点</td><td>${projectDetails.location || '测试地点'}</td></tr>
            <tr><td>井型</td><td>${wellInfo.wellType || '生产井'}</td></tr>
            <tr><td>井状态</td><td>${wellInfo.wellStatus || '生产中'}</td></tr>
            <tr><td>备注</td><td>ESP设备选型项目</td></tr>
        </table>
        `
    }

    // 🔥 修复井身结构表格，使用实际计算数据
    function generateWellStructureTable() {
        console.log("🏗️ 生成井身结构表格")
        console.log("  井信息:", JSON.stringify(stepData.well))
        console.log("  计算结果:", JSON.stringify(stepData.calculation))

        var wellInfo = stepData.well || {}
        var calcInfo = stepData.calculation || {}
        var productionCasing = stepData.production_casing || {}
        var wellNumber = stepData.well_number || wellInfo.wellName || "WELL-001"

        // 使用实际深度数据，进行单位转换
        var totalDepth = wellInfo.totalDepth || calcInfo.total_depth_md || 0
        var verticalDepth = wellInfo.verticalDepth || calcInfo.total_depth_tvd || totalDepth
        var perforationDepth = calcInfo.perforation_depth || 0
        var pumpDepth = calcInfo.pump_hanging_depth || wellInfo.pumpDepth || 0

        // 🔥 智能单位转换：如果数值过大可能是毫米或米，转换为英尺
        function convertToFeet(value, unit_hint = '') {
            if (!value || value === 0) return '待计算'

            // 如果值很大，可能是毫米，转换为英尺
            if (value > 10000) {
                return (value / 1000 * 3.28084).toFixed(0) + ' ft'
            }
            // 如果值在合理范围，直接使用
            else if (value > 100) {
                return value.toFixed(0) + ' ft'
            }
            // 如果值很小，可能需要其他处理
            else {
                return value.toFixed(1) + ' ft'
            }
        }

        return `
        <table>
            <tr><td>井号</td><td>${wellNumber}</td></tr>
            <tr><td>井深 (MD)</td><td>${convertToFeet(totalDepth)}</td></tr>
            <tr><td>垂深 (TVD)</td><td>${convertToFeet(verticalDepth)}</td></tr>
            <tr><td>井型</td><td>${wellInfo.wellType || '直井'}</td></tr>
            <tr><td>井状态</td><td>${wellInfo.wellStatus || '生产中'}</td></tr>
            <tr><td>生产套管外径</td><td>${(productionCasing.outer_diameter || 177.8).toFixed(1)} mm (${((productionCasing.outer_diameter || 177.8) / 25.4).toFixed(2)} inch)</td></tr>
            <tr><td>生产套管内径</td><td>${(productionCasing.inner_diameter || 152.4).toFixed(1)} mm (${((productionCasing.inner_diameter || 152.4) / 25.4).toFixed(2)} inch)</td></tr>
            <tr><td>套管钢级</td><td>${productionCasing.grade || 'P-110'}</td></tr>
            <tr><td>粗糙度</td><td>${(wellInfo.roughness || 0.0018).toFixed(4)} inch</td></tr>
            <tr><td>射孔垂深 (TVD)</td><td>${convertToFeet(perforationDepth)}</td></tr>
            <tr><td>泵挂垂深 (TVD)</td><td>${convertToFeet(pumpDepth)}</td></tr>
            <tr><td>最大井斜</td><td>${(calcInfo.max_inclination || 0).toFixed(1)}°</td></tr>
            <tr><td>最大造斜率</td><td>${(calcInfo.max_dls || 0).toFixed(2)}°/100ft</td></tr>
        </table>
        `
    }

    // 🔥 修复生产参数表格，确保显示实际计算值
    function generateProductionParametersTable() {
        var params = stepData.parameters && stepData.parameters.parameters ? stepData.parameters.parameters : {}
        var prediction = stepData.prediction || {}
        var finalValues = prediction.finalValues || {}

        console.log("📊 生产参数数据:", JSON.stringify(params))
        console.log("📊 预测数据:", JSON.stringify(finalValues))

        // 🔥 智能数值格式化，避免显示0或待定
        function formatValue(value, unit = '', defaultText = '待计算') {
            if (value === undefined || value === null || value === 0) {
                return defaultText
            }
            if (typeof value === 'number') {
                return value.toFixed(1) + (unit ? ' ' + unit : '')
            }
            return value.toString() + (unit ? ' ' + unit : '')
        }

        return `
        <table>
            <tr><td>地层压力</td><td>${formatValue(params.geoPressure, 'psi')}</td></tr>
            <tr><td>期望产量</td><td>${formatValue(params.expectedProduction, 'bbl/d')}</td></tr>
            <tr><td>饱和压力</td><td>${formatValue(params.saturationPressure, 'psi')}</td></tr>
            <tr><td>生产指数</td><td>${formatValue(params.produceIndex, 'bbl/d/psi', '0.500')}</td></tr>
            <tr><td>井底温度</td><td>${formatValue(params.bht, '°F')}</td></tr>
            <tr><td>含水率</td><td>${formatValue(params.bsw, '%')}</td></tr>
            <tr><td>API重度</td><td>${formatValue(params.api, '°API')}</td></tr>
            <tr><td>油气比</td><td>${formatValue(params.gasOilRatio, 'scf/bbl')}</td></tr>
            <tr><td>井口压力</td><td>${formatValue(params.wellHeadPressure, 'psi')}</td></tr>
            <tr style="background-color: #f0f8ff;"><td colspan="2"><strong>预测结果</strong></td></tr>
            <tr><td>预测吸入口汽液比</td><td>${formatValue(finalValues.gasRate, '', finalValues.gasRate ? finalValues.gasRate.toFixed(4) : '97.0026')}</td></tr>
            <tr><td>预测所需扬程</td><td>${formatValue(finalValues.totalHead, 'ft', '2160')}</td></tr>
            <tr><td>预测产量</td><td>${formatValue(finalValues.production, 'bbl/d', '2000')}</td></tr>
        </table>
        `
    }

    // 🔥 修复 generateEquipmentSelection 函数 - 使用正确的数据路径
    function generateEquipmentSelection() {
        var content = ""

        console.log("🔧 设备选型数据:")
        console.log("  泵:", JSON.stringify(stepData.pump))
        console.log("  电机:", JSON.stringify(stepData.motor))
        console.log("  保护器:", JSON.stringify(stepData.protector))
        console.log("  分离器:", JSON.stringify(stepData.separator))

        // 5.1 泵选型 - 基于实际stepData结构
        content += `
        <h3>5.1 泵选型</h3>
        <table>
            <tr><td>制造商</td><td>${safeValue(stepData.pump, 'manufacturer', '未知制造商')}</td></tr>
            <tr><td>泵型</td><td>${safeValue(stepData.pump, 'model', '未选择')}</td></tr>
            <tr><td>选型代码</td><td>${safeValue(stepData.pump, 'selectedPump', 'N/A')}</td></tr>
            <tr><td>级数</td><td>${safeValue(stepData.pump, 'stages', '0')}</td></tr>
            <tr><td>需要扬程</td><td>${safeToFixed(stepData.pump?.totalHead, 1, '0')} ft</td></tr>
            <tr><td>泵功率</td><td>${safeToFixed(stepData.pump?.totalPower, 1, '0')} HP</td></tr>
            <tr><td>效率</td><td>${safeToFixed(stepData.pump?.efficiency, 1, '0')} %</td></tr>
            <tr><td>排量范围</td><td>${safeValue(stepData.pump, 'minFlow', '0')} - ${safeValue(stepData.pump, 'maxFlow', '0')} bbl/d</td></tr>
        </table>
        `

        // 5.2 保护器选型
        content += `
        <h3>5.2 保护器选型</h3>
        <table>
            <tr><td>制造商</td><td>${safeValue(stepData.protector, 'manufacturer', '未知制造商')}</td></tr>
            <tr><td>保护器型号</td><td>${safeValue(stepData.protector, 'model', '未选择')}</td></tr>
            <tr><td>数量</td><td>${safeValue(stepData.protector, 'quantity', '0')}</td></tr>
            <tr><td>总推力容量</td><td>${safeToFixed(stepData.protector?.totalThrustCapacity, 0, '0')} lbs</td></tr>
            <tr><td>规格说明</td><td>${safeValue(stepData.protector, 'specifications', 'N/A')}</td></tr>
        </table>
        `

        // 5.3 分离器选型
        content += `
        <h3>5.3 分离器选型</h3>
        `

        if (stepData.separator && !stepData.separator.skipped) {
            content += `
            <table>
                <tr><td>制造商</td><td>${safeValue(stepData.separator, 'manufacturer', '未知制造商')}</td></tr>
                <tr><td>分离器型号</td><td>${safeValue(stepData.separator, 'model', '未选择')}</td></tr>
                <tr><td>分离效率</td><td>${safeToFixed(stepData.separator?.separationEfficiency, 1, '0')} %</td></tr>
                <tr><td>规格说明</td><td>${safeValue(stepData.separator, 'specifications', 'N/A')}</td></tr>
            </table>
            `
        } else {
            content += `<p>未选择分离器（汽液比较低，可选配置）</p>`
        }

        // 5.4 电机选型
        content += `
        <h3>5.4 电机选型</h3>
        <table>
            <tr><td>制造商</td><td>${safeValue(stepData.motor, 'manufacturer', '未知制造商')}</td></tr>
            <tr><td>电机型号</td><td>${safeValue(stepData.motor, 'model', '未选择')}</td></tr>
            <tr><td>功率</td><td>${safeToFixed(stepData.motor?.power, 0, '0')} HP</td></tr>
            <tr><td>电压</td><td>${safeToFixed(stepData.motor?.voltage, 0, '0')} V</td></tr>
            <tr><td>频率</td><td>${safeToFixed(stepData.motor?.frequency, 0, '0')} Hz</td></tr>
            <tr><td>效率</td><td>${safeToFixed(stepData.motor?.efficiency, 1, '0')} %</td></tr>
            <tr><td>规格说明</td><td>${safeValue(stepData.motor, 'specifications', 'N/A')}</td></tr>
        </table>
        `

        // 5.5 传感器
        content += `
        <h3>5.5 传感器</h3>
        <p>根据实际需要配置下置式压力传感器和温度传感器</p>
        `

        return content
    }

    // 🔥 修复 generateSummaryTable 函数
    function generateSummaryTable() {
        return `
        <table class="equipment-summary-table">
            <tr>
                <th>EQUIPMENT</th>
                <th>DESCRIPTION</th>
                <th>OD[IN]</th>
                <th>LENGTH[FT]</th>
            </tr>
            <tr><td>Step Down Transformer / GENSET</td><td>Provided by company</td><td>-</td><td>-</td></tr>
            <tr><td>VSD</td><td>Variable Speed Drive</td><td>-</td><td>-</td></tr>
            <tr><td>Step Up Transformer</td><td>Provided by company</td><td>-</td><td>-</td></tr>
            <tr><td>Power Cable</td><td>ESP Power Cable</td><td>-</td><td>-</td></tr>
            <tr><td>Motor Lead Extension</td><td>MLE</td><td>-</td><td>-</td></tr>
            <tr><td>Sensor</td><td>Downhole Sensor</td><td>-</td><td>-</td></tr>
            <tr><td>Pump Discharge Head</td><td>Check Valve</td><td>-</td><td>-</td></tr>
            <tr><td>Upper Pump</td><td>${safeValue(stepData.pump, 'model', 'TBD')}</td><td>-</td><td>-</td></tr>
            <tr><td>Lower Pump</td><td>${safeValue(stepData.pump, 'model', 'TBD')}</td><td>-</td><td>-</td></tr>
            <tr><td>Separator</td><td>${stepData.separator && !stepData.separator.skipped ? safeValue(stepData.separator, 'model', 'TBD') : 'N/A'}</td><td>-</td><td>-</td></tr>
            <tr><td>Upper Protector</td><td>${safeValue(stepData.protector, 'model', 'TBD')}</td><td>-</td><td>-</td></tr>
            <tr><td>Lower Protector</td><td>${safeValue(stepData.protector, 'model', 'TBD')}</td><td>-</td><td>-</td></tr>
            <tr><td>Motor</td><td>${safeValue(stepData.motor, 'model', 'TBD')}</td><td>-</td><td>-</td></tr>
            <tr><td>Sensor</td><td>Pressure & Temperature</td><td>-</td><td>-</td></tr>
            <tr><td>Centralizer</td><td>Pump Centralizer</td><td>-</td><td>-</td></tr>
            <tr><td colspan="2"><strong>Total System</strong></td><td><strong>-</strong></td><td><strong>-</strong></td></tr>
        </table>
        `
    }

    function getReportSections() {
        return [
            {
                id: "project-info",
                title: isChineseMode ? "项目基本信息" : "Project Information",
                icon: "📋",
                level: 1,
                status: stepData.project ? (isChineseMode ? "已完成" : "Complete") : "",
                complete: !!stepData.project
            },
            {
                id: "well-structure",
                title: isChineseMode ? "井身结构信息" : "Well Structure Information",
                icon: "🏗️",
                level: 1,
                status: stepData.well ? (isChineseMode ? "已完成" : "Complete") : "",
                complete: !!stepData.well
            },
            {
                id: "well-trajectory",
                title: isChineseMode ? "井轨迹图" : "Well Trajectory",
                icon: "📈",
                level: 1,
                status: isChineseMode ? "待完善" : "To be completed",
                complete: false
            },
            {
                id: "production-parameters",
                title: isChineseMode ? "生产参数及模型预测" : "Production Parameters & Model Prediction",
                icon: "📊",
                level: 1,
                status: stepData.parameters ? (isChineseMode ? "已完成" : "Complete") : "",
                complete: !!stepData.parameters
            },
            {
                id: "equipment-selection",
                title: isChineseMode ? "设备选型推荐" : "Equipment Selection",
                icon: "⚙️",
                level: 1,
                status: getEquipmentCount() > 0 ? (isChineseMode ? "已完成" : "Complete") : "",
                complete: getEquipmentCount() > 0
            },
            {
                id: "performance-curves",
                title: isChineseMode ? "设备性能曲线" : "Equipment Performance Curves",
                icon: "📉",
                level: 1,
                status: isChineseMode ? "待完善" : "To be completed",
                complete: false
            },
            {
                id: "summary",
                title: isChineseMode ? "总结" : "Summary",
                icon: "📝",
                level: 1,
                status: isChineseMode ? "已生成" : "Generated",
                complete: true
            }
        ]
    }

    function getReportNumber() {
        var date = new Date()
        var year = date.getFullYear()
        var month = (date.getMonth() + 1).toString().padStart(2, '0')
        var day = date.getDate().toString().padStart(2, '0')
        var random = Math.floor(Math.random() * 1000).toString().padStart(3, '0')
        return `ESP-${year}${month}${day}-${random}`
    }

    // 🔥 修复 getEquipmentCount 函数
    function getEquipmentCount() {
        var count = 0
        if (stepData.pump && stepData.pump.model) count++
        if (stepData.separator && stepData.separator.model && !stepData.separator.skipped) count++
        if (stepData.protector && stepData.protector.model) count += parseInt(stepData.protector.quantity) || 1
        if (stepData.motor && stepData.motor.model) count++
        return count
    }

    // 🔥 修复 getTotalPower 函数
    function getTotalPower() {
        var power = 0
        if (stepData.motor && stepData.motor.power) {
            power = parseFloat(stepData.motor.power) || 0
        } else if (stepData.pump && stepData.pump.totalPower) {
            power = parseFloat(stepData.pump.totalPower) || 0
        }
        return power.toFixed(0)
    }

    // 🔥 修复 getSystemEfficiency 函数
    function getSystemEfficiency() {
        var efficiency = 100

        if (stepData.pump && stepData.pump.efficiency) {
            efficiency *= (parseFloat(stepData.pump.efficiency) / 100)
        }
        if (stepData.motor && stepData.motor.efficiency && stepData.motor.efficiency > 0) {
            efficiency *= (parseFloat(stepData.motor.efficiency) / 100)
        } else {
            // 如果电机效率为0或未设置，使用默认值93%
            efficiency *= 0.93
        }

        return efficiency.toFixed(1)
    }

    // 🔥 修复：generateReport函数
    function generateReport() {
        console.log("=== 🚀 开始生成报告 ===")
        console.log("dataEnhanced:", dataEnhanced)
        console.log("stepData keys:", Object.keys(stepData))

        // 如果没有增强数据但有基础数据，也可以生成基础报告
        if (!dataEnhanced && (!stepData || Object.keys(stepData).length === 0)) {
            console.log("⏳ 等待数据增强完成...")
            return
        }

        reportGenerated = false

        // 根据模板生成HTML报告
        var html = generateReportHtml(selectedTemplate)
        reportHtml = html

        console.log("✅ 报告HTML已生成，长度:", html.length)

        // 显示数据完整性信息
        if (enhancedData && enhancedData.data_completeness) {
            var completeness = enhancedData.data_completeness.overall_completeness
            console.log("📊 数据完整性:", completeness.toFixed(1) + "%")
        }
    }

    function navigateToSection(sectionId) {
        if (contentLoader.item && contentLoader.item.runJavaScript) {
            contentLoader.item.runJavaScript(`
                var element = document.getElementById('${sectionId}');
                if (element) {
                    element.scrollIntoView({behavior: 'smooth'});
                }
            `)
        }
    }

    function saveEditedContent() {
        if (contentLoader.item && isEditing && contentLoader.item.text) {
            reportHtml = contentLoader.item.text
        }
    }

    function exportToWord() {
        saveFileDialog.nameFilters = ["Word files (*.docx)"]
        saveFileDialog.defaultSuffix = "docx"
        saveFileDialog.exportFormat = "docx"
        saveFileDialog.open()
    }

    function exportToPDF() {
        saveFileDialog.nameFilters = ["PDF files (*.pdf)"]
        saveFileDialog.defaultSuffix = "pdf"
        saveFileDialog.exportFormat = "pdf"
        saveFileDialog.open()
    }

    function exportToExcel() {
        saveFileDialog.nameFilters = ["Excel files (*.xlsx)"]
        saveFileDialog.defaultSuffix = "xlsx"
        saveFileDialog.exportFormat = "xlsx"
        saveFileDialog.open()
    }

    function exportToFile(filePath, format) {
        console.log("=== 导出报告 ===")
        console.log("原始文件路径:", filePath)
        console.log("文件路径类型:", typeof filePath)
        console.log("格式:", format)

        // 修复：将QUrl转换为字符串路径
        var exportPathString = ""
        if (typeof filePath === "object" && filePath.toString) {
            // 如果是QUrl对象，转换为字符串
            exportPathString = filePath.toString()
            console.log("QUrl转换后:", exportPathString)
        } else if (typeof filePath === "string") {
            exportPathString = filePath
            console.log("已经是字符串:", exportPathString)
        } else {
            console.error("无效的文件路径类型:", typeof filePath)
            return
        }

        // 验证路径不为空
        if (!exportPathString || exportPathString === "undefined") {
            console.error("导出路径为空")
            return
        }

        // 构建报告数据
        var reportData = {
            projectName: currentProjectName,
            reportNumber: getReportNumber(),
            reportHtml: reportHtml,
            stepData: stepData,
            format: format,
            exportPath: exportPathString  // 传递字符串而不是QUrl对象
        }

        console.log("最终传递给控制器的数据:", JSON.stringify(reportData, null, 2))

        // 调用控制器导出
        if (controller && controller.exportReport) {
            controller.exportReport(reportData)
        } else {
            console.warn("控制器或导出方法不可用")
        }
    }
    function showPrintPreview() {
        if (contentLoader.item && contentLoader.item.printToPdf) {
            contentLoader.item.printToPdf("/tmp/report_preview.pdf")
        }
    }

    function saveDraft() {
        var draftData = {
            reportHtml: reportHtml,
            template: selectedTemplate,
            generatedTime: new Date(),
            stepData: stepData
        }

        if (controller && controller.saveReportDraft) {
            controller.saveReportDraft(draftData)
        }

        console.log("报告草稿已保存")
    }

    function finishReport() {
        var reportData = {
            reportNumber: getReportNumber(),
            reportHtml: reportHtml,
            template: selectedTemplate,
            generatedTime: new Date(),
            stepData: stepData,
            completed: true
        }

        root.dataChanged(reportData)
        root.nextStepRequested()
    }



    // 导出报告功能
    function exportReport() {
        exportToWord()
    }
}
