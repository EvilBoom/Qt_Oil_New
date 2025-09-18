// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step8_ReportGeneration.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtWebEngine
import "../Components" as LocalComponents
import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性

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

    // 🔥 新增轨迹图相关属性
    property var trajectoryData: []
    property bool hasTrajectoryData: trajectoryData && trajectoryData.length > 0

    color: "transparent"

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("Step8中单位制切换为:", isMetric ? "公制" : "英制")
            // 重新生成报告以应用新的单位
            generateReport()
        }
    }

    // 🔥 修复：更新Component.onCompleted
    Component.onCompleted: {
        console.log("=== Step8 报告生成初始化 ===")
        //console.log("stepData:", JSON.stringify(stepData))
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
            // generateReport()
        } else {
            console.warn("⚠️ 井ID无效或控制器不可用，尝试从其他控制器获取井信息")
            // loadWellInformation()
            // extractProjectName()
            // generateReport()
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
        loadWellInformation()
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
            // generateReport()
        }
    }

    // LocalComponents.WellSelectionDialog {
    //     id: wellDialog
    //     visible: root.showWellDialog
    //     wellsList: root.wellsList
    //     onWellConfirmed: {
    //         root.selectedWell = well
    //         root.showWellDialog = false
    //         // 补充stepData
    //         if (!root.stepData.well) root.stepData.well = {}
    //         root.stepData.well.wellName = well.name
    //         root.stepData.well.totalDepth = well.totalDepth || 0
    //         root.stepData.well.verticalDepth = well.verticalDepth || well.totalDepth || 0
    //         root.stepData.well.wellType = well.wellType || "生产井"
    //         root.stepData.well.wellStatus = well.status || "Active"
    //         // 触发数据增强和报告生成
    //         if (controller && controller.prepareReportData) {
    //             controller.prepareReportData(root.stepData)
    //         }
    //     }
    //     onRejected: root.showWellDialog = false
    // }
    // 🔥 修复：统一的单位转换函数
    function getDisplayDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDisplayFlowUnit() {
        return isMetric ? "m³/d" : "bbl/d"
    }

    function getDisplayPressureUnit() {
        return isMetric ? "MPa" : "psi"
    }

    function getDisplayTemperatureUnit() {
        return isMetric ? "°C" : "°F"
    }

    function getDisplayDiameterUnit() {
        return isMetric ? "mm" : "in"
    }

    function getDisplayPowerUnit() {
        return isMetric ? "kW" : "HP"
    }

    function getDisplayForceUnit() {
        return isMetric ? "N" : "lbs"
    }

    // 🔥 修复：统一的数值转换函数（从存储单位转换为显示单位）
    function convertDepthForDisplay(value) {
        if (!value || value === 0) return 0
        // 假设存储单位是英尺，转换为显示单位
        if (isMetric) {
            return UnitUtils.feetToMeters(value)
        }
        return value
    }
    function convertFlowForDisplay(value) {
        if (!value || value === 0) return 0
        // 假设存储单位是bbl/d，转换为显示单位
        if (isMetric) {
            return UnitUtils.bblToM3(value)
        }
        return value
    }

    function convertPressureForDisplay(value) {
        if (!value || value === 0) return 0
        // 假设存储单位是psi，转换为显示单位
        if (isMetric) {
            return UnitUtils.psiToMPa(value)
        }
        return value
    }

    function convertTemperatureForDisplay(value) {
        if (!value || value === 0) return 0
        // 假设存储单位是华氏度，转换为显示单位
        if (isMetric) {
            return UnitUtils.fahrenheitToCelsius(value)
        }
        return value
    }

    function convertDiameterForDisplay(value) {
        if (!value || value === 0) return 0
        // 假设存储单位是英寸，转换为显示单位
        if (isMetric) {
            return UnitUtils.inchesToMm(value)
        }
        return value
    }

    function convertPowerForDisplay(value) {
        if (!value || value === 0) return 0
        // 假设存储单位是HP，转换为显示单位
        if (isMetric) {
            return UnitUtils.hpToKw(value)
        }
        return value
    }

    // 🔥 修复：格式化显示函数
    function formatDepthValue(value, showUnit = true) {
        var convertedValue = convertDepthForDisplay(value)
        var formatted = convertedValue.toFixed(isMetric ? 1 : 0)
        return showUnit ? `${formatted} ${getDisplayDepthUnit()}` : formatted
    }

    function formatFlowValue(value, showUnit = true) {
        var convertedValue = convertFlowForDisplay(value)
        var formatted = convertedValue.toFixed(1)
        return showUnit ? `${formatted} ${getDisplayFlowUnit()}` : formatted
    }

    function formatPressureValue(value, showUnit = true) {
        var convertedValue = convertPressureForDisplay(value)
        var formatted = convertedValue.toFixed(isMetric ? 2 : 0)
        return showUnit ? `${formatted} ${getDisplayPressureUnit()}` : formatted
    }

    function formatTemperatureValue(value, showUnit = true) {
        var convertedValue = convertTemperatureForDisplay(value)
        var formatted = convertedValue.toFixed(0)
        return showUnit ? `${formatted} ${getDisplayTemperatureUnit()}` : formatted
    }

    function formatDiameterValue(value, showUnit = true) {
        var convertedValue = convertDiameterForDisplay(value)
        var formatted = convertedValue.toFixed(isMetric ? 0 : 2)
        return showUnit ? `${formatted} ${getDisplayDiameterUnit()}` : formatted
    }

    function formatPowerValue(value, showUnit = true) {
        var convertedValue = convertPowerForDisplay(value)
        var formatted = convertedValue.toFixed(1)
        return showUnit ? `${formatted} ${getDisplayPowerUnit()}` : formatted
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
            // 🔥 添加单位切换器
            // CommonComponents.UnitSwitcher {
            //     isChinese: root.isChineseMode
            //     showLabel: false
            // }
            Button {
                text: "选择井信息"
                onClicked: root.showWellDialog = true
                visible: root.wellsList.length > 0
            }
            // 模板选择
            // ComboBox {
            //     id: templateSelector
            //     Layout.preferredWidth: 150
            //     model: [
            //         isChineseMode ? "标准报告" : "Standard Report",
            //         isChineseMode ? "详细报告" : "Detailed Report",
            //         isChineseMode ? "简要报告" : "Brief Report"
            //     ]
            //     onCurrentIndexChanged: {
            //         switch(currentIndex) {
            //             case 0: selectedTemplate = "standard"; break
            //             case 1: selectedTemplate = "detailed"; break
            //             case 2: selectedTemplate = "brief"; break
            //         }
            //         generateReport()
            //     }
            // }

            // 编辑按钮
            // Button {
            //     text: isEditing ? (isChineseMode ? "完成编辑" : "Done Editing")
            //                    : (isChineseMode ? "编辑报告" : "Edit Report")
            //     enabled: reportGenerated
            //     onClicked: {
            //         isEditing = !isEditing
            //         if (!isEditing) {
            //             saveEditedContent()
            //         }
            //     }
            // }

            // 导出按钮组
            Row {
                spacing: 8

                Button {
                    text: "Word"
                    // highlighted: true
                    enabled: reportGenerated
                    onClicked: exportToWord()
                    // 蓝色背景样式
                       background: Rectangle {
                           implicitWidth: 100
                           implicitHeight: 40
                           color: {
                               if (!control.enabled) return "#BBDEFB"; // 禁用时浅蓝
                               if (control.pressed) return "#0D47A1"; // 按下时深蓝
                               if (control.highlighted) return "#1976D2"; // 高亮时中蓝
                               return "#2196F3"; // 正常时亮蓝
                           }
                           border.color: "#0D47A1"
                           border.width: 1
                           radius: 4
                       }
                }

                Button {
                    text: "PDF"
                    enabled: reportGenerated
                    onClicked: exportToPDF()
                    // 蓝色背景样式
                       background: Rectangle {
                           implicitWidth: 100
                           implicitHeight: 40
                           color: {
                               if (!control.enabled) return "#BBDEFB"; // 禁用时浅蓝
                               if (control.pressed) return "#0D47A1"; // 按下时深蓝
                               if (control.highlighted) return "#1976D2"; // 高亮时中蓝
                               return "#2196F3"; // 正常时亮蓝
                           }
                           border.color: "#0D47A1"
                           border.width: 1
                           radius: 4
                       }
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
                        text: isChineseMode ? "提示" : "Notice"
                        font.bold: true
                        color: Material.primaryTextColor
                    }

                    Text {
                        // text: enhancedData.data_completeness ?
                        //       (isChineseMode ?
                        //        `当前数据完整性: ${enhancedData.data_completeness.overall_completeness.toFixed(1)}%，部分数据可能使用默认值` :
                        //        `Current data completeness: ${enhancedData.data_completeness.overall_completeness.toFixed(1)}%, some data may use default values`) :
                        //       ""
                        text: "这里为报告的简化预览，需要点击对应的Word或者PDF按钮来保存详细报告内容"
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

                    // Button {
                    //     text: isChineseMode ? "保存草稿" : "Save Draft"
                    //     flat: true
                    //     onClicked: saveDraft()
                    // }

                    // Button {
                    //     text: isChineseMode ? "打印预览" : "Print Preview"
                    //     onClicked: showPrintPreview()
                    // }

                    Button {
                        text: "完成"
                        // highlighted: true
                        enabled: reportGenerated
                        onClicked: finishReport()
                        // 蓝色背景样式
                           background: Rectangle {
                               implicitWidth: 100
                               implicitHeight: 40
                               color: {
                                   if (!control.enabled) return "#BBDEFB"; // 禁用时浅蓝
                                   if (control.pressed) return "#0D47A1"; // 按下时深蓝
                                   if (control.highlighted) return "#1976D2"; // 高亮时中蓝
                                   return "#2196F3"; // 正常时亮蓝
                               }
                               border.color: "#0D47A1"
                               border.width: 1
                               radius: 4
                           }
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
                    var wellData = wellController.getCompleteWellData(wellId)
                    console.log("✅ 从wellController获取到井数据:", JSON.stringify(wellData))

                    // 补充井信息到stepData
                    if (!stepData.well) {
                        stepData.well = {}
                    }

                    stepData.well.wellName = wellData.well_name || `Well-${wellId}`
                    stepData.well.totalDepth = wellData.well_md || 0
                    // stepData.well.verticalDepth = wellData.vertical_depth || stepData.well.totalDepth
                    stepData.well.wellType = wellData.well_type || 'Production'
                    stepData.well.wellStatus = wellData.well_status || 'Active'

                    console.log("✅ 井信息已补充到stepData")

                    var calcResult = wellController.getWellCalculationData(wellId)
                    console.log("✅ 从wellController获取到计算结果:", JSON.stringify(calcResult))

                    // 补充计算结果到stepData
                    if (!stepData.calculation) {
                        stepData.calculation = {}
                    }

                    stepData.calculation.perforation_depth = calcResult.perforation_depth || 0
                    stepData.calculation.pump_hanging_depth = calcResult.pump_hanging_depth || 0

                    console.log("✅ 计算结果已补充到stepData")
                }

            } catch (error) {
                console.warn("⚠️ 从wellController获取井信息失败:", error)
            }
        }

        // 🔥 方法2：从wellStructureController获取轨迹数据
        if (typeof wellStructureController !== "undefined" && wellStructureController !== null) {
            try {
                console.log("📞 使用wellStructureController获取轨迹数据...")

                // 🔥 直接获取轨迹数据
                if (wellStructureController.trajectoryData && wellStructureController.trajectoryData.length > 0) {
                    stepData.trajectory_data = wellStructureController.trajectoryData
                    console.log("✅ 从wellStructureController获取到轨迹数据:", stepData.trajectory_data.length, "个点")
                } else {
                    // 如果没有缓存数据，尝试加载
                    wellStructureController.setCurrentWellId(wellId)
                    wellStructureController.loadTrajectoryData(wellId)

                    // 稍等一下，让数据加载完成
                    Qt.callLater(function() {
                        if (wellStructureController.trajectoryData && wellStructureController.trajectoryData.length > 0) {
                            stepData.trajectory_data = wellStructureController.trajectoryData
                            console.log("✅ 延迟获取到轨迹数据:", stepData.trajectory_data.length, "个点")
                            generateReport() // 重新生成报告
                        }
                    })
                }
                // 🔥 新增：获取套管数据
                if (wellStructureController.casingData && wellStructureController.casingData.length > 0) {
                    stepData.casing_data = wellStructureController.casingData
                    console.log("从wellStructureController获取到套管数据:", stepData.casing_data.length, "个套管")
                    var well_sketchjsonStr = wellStructureController.getWellSketchData()
                    var sketchData = JSON.parse(well_sketchjsonStr)
                    stepData.well_sketch = sketchData
                    // console.log("从wellStructureController返回数据类型:", typeof sketchData)
                    // console.log("从wellStructureController获取到草图数据:", JSON.stringify(sketchData))
                } else {
                    // 如果没有缓存数据，尝试加载
                    wellStructureController.loadCasingData(wellId)

                    Qt.callLater(function() {
                        if (wellStructureController.casingData && wellStructureController.casingData.length > 0) {
                            stepData.casing_data = wellStructureController.casingData
                            console.log("✅ 延迟获取到套管数据:", stepData.casing_data.length, "个套管")
                            generateReport() // 重新生成报告
                        }
                    })
                }


                // 🔥 新增：生成井结构草图数据
                // wellStructureController.generateWellSketch()

            } catch (error) {
                console.warn("⚠️ 从wellStructureController获取数据失败:", error)
            }
        }

        // 🔥 修改：直接同步获取泵性能曲线数据，使用JSON字符串传递
        if (typeof deviceController !== "undefined" && deviceController !== null) {
            try {
                console.log("📞 使用deviceController获取泵性能曲线数据...")

                // 🔥 关键修复：将stepData转换为JSON字符串传递
                var stepDataJsonStr = JSON.stringify(stepData)
                console.log("传递给Python的stepData:", stepDataJsonStr.substring(0, 200) + "...")

                // 调用修改后的方法
                var pumpCurvesJsonStr = deviceController.getPumpCurvesFromStepDataString(stepDataJsonStr)

                if (pumpCurvesJsonStr && pumpCurvesJsonStr.length > 0) {
                    try {
                        var pumpCurvesData = JSON.parse(pumpCurvesJsonStr)

                        if (pumpCurvesData && pumpCurvesData.has_data) {
                            stepData.pump_curves = pumpCurvesData
                            console.log("✅ 同步获取到泵性能曲线数据，流量点数:", pumpCurvesData.baseCurves?.flow?.length || 0)
                            console.log("  泵型号:", pumpCurvesData.pump_info?.model || "未知")
                            console.log("  级数:", pumpCurvesData.pump_info?.stages || "未知")
                        } else {
                            console.warn("⚠️ 泵性能曲线数据无效:", pumpCurvesData.error || "unknown")
                            stepData.pump_curves = { has_data: false, error: pumpCurvesData.error || "no_data" }
                        }
                    } catch (parseError) {
                        console.error("❌ 解析泵性能曲线JSON失败:", parseError)
                        stepData.pump_curves = { has_data: false, error: "json_parse_error" }
                    }
                } else {
                    console.warn("⚠️ deviceController返回空的泵性能曲线数据")
                    stepData.pump_curves = { has_data: false, error: "empty_response" }
                }

            } catch (error) {
                console.warn("⚠️ 从deviceController获取泵性能曲线数据失败:", error)
                stepData.pump_curves = { has_data: false, error: error.toString() }
            }
        } else {
            console.warn("⚠️ deviceController不可用")
            stepData.pump_curves = { has_data: false, error: "controller_unavailable" }
        }
    }


    function generateReportHtml(template) {
        console.log("=== 生成报告HTML ===")
        // console.log("当前stepData:", JSON.stringify(stepData))

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
        /* 🔥 新增：Canvas图表样式 */
        canvas {
            display: block;
            margin: 0 auto;
            max-width: 100%;
            height: auto;
        }

        /* 🔥 新增：清除浮动样式 */
        .clearfix::after {
            content: "";
            display: table;
            clear: both;
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
        var projectName = currentProjectName || "-"

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
            <div class="header-company">渤海石油装备制造有限公司</div>
            <div class="header-date">${Qt.formatDateTime(new Date(), "yyyy-MM-dd")}</div>
            <h1>${projectName} 无杆举升系统选型设计 </h1>
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
            ${generateWellTrajectorySection()}
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

        // // 6. 设备性能曲线
        // content += `
        // <div class="page-break"></div>
        // <section id="performance-curves">
        //     <h2>6. 设备性能曲线</h2>

        //     <h3>6.1 泵设备性能曲线</h3>
        //     ${generatePumpPerformanceSection()}

        //     <div class="page-break"></div>
        //     <h3>6.2 工况点分析</h3>
        //     ${generateOperatingPointAnalysis()}
        // </section>
        // `

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
            case 'company': return '渤海石油装备制造有限公司'
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
    // 🔥 添加单位转换函数
    function getDepthUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("depth")
        }
        return isMetric ? "m" : "ft"
    }

    function getFlowUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("flow")
        }
        return isMetric ? "m³/d" : "bbl/d"
    }

    function getPressureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("pressure")
        }
        return isMetric ? "kPa" : "psi"
    }

    function getTemperatureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("temperature")
        }
        return isMetric ? "°C" : "°F"
    }

    function getDiameterUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("diameter")
        }
        return isMetric ? "mm" : "in"
    }

    function convertDepthValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.feetToMeters(value)  // ft → m
    }

    function convertFlowValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.bblToM3(value)  // bbl/d → m³/d
    }

    function convertPressureValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.psiToKpa(value)  // psi → kPa
    }

    function convertTemperatureValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.fahrenheitToCelsius(value)  // °F → °C
    }

    function convertDiameterValue(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.inchesToMm(value)  // in → mm
    }

    // 🔥 修改格式化函数，支持单位转换
    function formatByType(value, dataType) {
        try {
            var numValue = parseFloat(value)
            if (isNaN(numValue)) return value

            switch(dataType) {
                case 'number':
                    return numValue.toFixed(2)
                case 'pressure':
                    var convertedValue = convertPressureValue(numValue)
                    return convertedValue.toFixed(1) + ' ' + getPressureUnit()
                case 'production':
                    var convertedValue = convertFlowValue(numValue)
                    return convertedValue.toFixed(1) + ' ' + getFlowUnit()
                case 'temperature':
                    var convertedValue = convertTemperatureValue(numValue)
                    return convertedValue.toFixed(1) + ' ' + getTemperatureUnit()
                case 'depth':
                    var convertedValue = convertDepthValue(numValue)
                    return convertedValue.toFixed(0) + ' ' + getDepthUnit()
                case 'diameter':
                    var convertedValue = convertDiameterValue(numValue)
                    return convertedValue.toFixed(2) + ' ' + getDiameterUnit()
                case 'percentage':
                    return numValue.toFixed(1) + ' %'
                case 'length':
                    var convertedValue = convertDepthValue(numValue)
                    return convertedValue.toFixed(1) + ' ' + getDepthUnit()
                case 'power':
                    return numValue.toFixed(0) + ' HP'
                case 'efficiency':
                    return numValue.toFixed(1) + ' %'
                case 'voltage':
                    return numValue.toFixed(0) + ' V'
                case 'current':
                    return numValue.toFixed(1) + ' A'
                case 'weight':
                    return numValue.toFixed(0) + ' lbs'
                case 'speed':
                    return numValue.toFixed(0) + ' RPM'
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

    // 🔥 修复：generateProjectInfoTable函数
    function generateProjectInfoTable() {
        var wellInfo = stepData.well || {}
        var projectDetails = stepData.project_details || {}
        var wellNumber = stepData.well_number || wellInfo.wellName || "WELL-001"

        return `
        <table>
            <tr><td>公司</td><td>${projectDetails.company_name || '渤海石油装备制造有限公司'}</td></tr>
            <tr><td>井号</td><td>${wellNumber}</td></tr>
            <tr><td>项目名称</td><td>${projectDetails.project_name || currentProjectName}</td></tr>
            <tr><td>油田</td><td>${projectDetails.oil_field || '-'}</td></tr>
            <tr><td>地点</td><td>${projectDetails.location || '-'}</td></tr>
            <tr><td>井型</td><td>${wellInfo.wellType || '-'}</td></tr>
            <tr><td>井状态</td><td>${wellInfo.wellStatus || '-'}</td></tr>
            <tr><td>备注</td><td>ESP设备选型项目</td></tr>
        </table>
        `
    }

    // 🔥 修复：generateWellStructureTable函数
    function generateWellStructureTable() {
        console.log("🏗️ 生成井身结构表格")

        var wellInfo = stepData.well || {}
        var calcInfo = stepData.calculation || {}
        var productionCasing = stepData.production_casing || {}
        var wellNumber = stepData.well_number || wellInfo.wellName || "WELL-001"

        // 获取深度数据（假设存储为英尺）
        var totalDepth = wellInfo.totalDepth || calcInfo.total_depth_md || 0
        var verticalDepth = wellInfo.verticalDepth || calcInfo.total_depth_tvd || totalDepth
        var perforationDepth = calcInfo.perforation_depth || 0
        var pumpDepth = calcInfo.pump_hanging_depth || wellInfo.pumpDepth || 0

        var content = `
        <!-- 基本井信息 -->
        <h3>2.1 基本井信息</h3>
        <table>
            <tr><td>井号</td><td>${wellNumber}</td></tr>
            <tr><td>井深</td><td>${formatDepthValue(totalDepth)}</td></tr>
            <tr><td>井型</td><td>${wellInfo.wellType || '直井'}</td></tr>
            <tr><td>井状态</td><td>${wellInfo.wellStatus || '生产中'}</td></tr>
            <tr><td>粗糙度</td><td>${formatDiameterValue(wellInfo.roughness || 0.0018)}</td></tr>
            <tr><td>射孔垂深 (TVD)</td><td>${formatDepthValue(perforationDepth)}</td></tr>
            <tr><td>泵挂垂深 (TVD)</td><td>${formatDepthValue(pumpDepth)}</td></tr>
        </table>

        <!-- 套管信息表格 -->
        <h3>2.2 套管信息</h3>
        ${generateCasingInfoTable()}

        <!-- 井结构草图 -->
        <h3>2.3 井结构草图</h3>
        ${generateWellSketchSection()}
        `
        return content
    }

    // 🔥 修复：generateCasingInfoTable函数
    function generateCasingInfoTable() {
        var casingData = stepData.casing_data || []

        console.log("🔧 生成套管信息表格，套管数量:", casingData.length)

        if (casingData.length === 0) {
            return `
            <table>
                <tr>
                    <th>套管类型</th>
                    <th>外径</th>
                    <th>内径</th>
                    <th>顶深</th>
                    <th>底深</th>
                    <th>钢级</th>
                    <th>重量 (lb/ft)</th>
                </tr>
                <tr>
                    <td colspan="7" style="text-align: center; color: #999; font-style: italic;">暂无套管数据</td>
                </tr>
            </table>
            `
        }

        var tableContent = `
        <table>
            <tr style="background-color: #f5f7fa;">
                <th>套管类型</th>
                <th>外径</th>
                <th>内径</th>
                <th>顶深</th>
                <th>底深</th>
                <th>钢级</th>
                <th>重量 (lb/ft)</th>
                <th>状态</th>
            </tr>
        `

        // 按深度排序套管
        var sortedCasings = casingData.slice().sort(function(a, b) {
            var depthA = a.top_depth || a.top_tvd || 0
            var depthB = b.top_depth || b.top_tvd || 0
            return depthA - depthB
        })

        for (var i = 0; i < sortedCasings.length; i++) {
            var casing = sortedCasings[i]

            // 跳过已删除的套管
            if (casing.is_deleted) continue

            var casingType = casing.casing_type || '未知套管'
            var outerDiameter = formatDiameterValue(casing.outer_diameter || 0)
            var innerDiameter = formatDiameterValue(casing.inner_diameter || 0)
            var topDepth = formatDepthValue(casing.top_depth || casing.top_tvd || 0)
            var bottomDepth = formatDepthValue(casing.bottom_depth || casing.bottom_tvd || 0)
            var grade = casing.grade || casing.material || 'N/A'
            var weight = casing.weight ? casing.weight.toFixed(1) : 'N/A'
            var status = casing.status || 'Active'

            // 根据套管类型设置行样式
            var rowStyle = ""
            if (casingType.toLowerCase().includes('production') || casingType.includes('生产')) {
                rowStyle = 'background-color: #e8f5e8;'
            } else if (casingType.toLowerCase().includes('surface') || casingType.includes('表层')) {
                rowStyle = 'background-color: #fff3cd;'
            }

            tableContent += `
            <tr style="${rowStyle}">
                <td style="font-weight: ${casingType.includes('生产') || casingType.includes('production') ? 'bold' : 'normal'};">${casingType}</td>
                <td>${outerDiameter}</td>
                <td>${innerDiameter}</td>
                <td>${topDepth}</td>
                <td>${bottomDepth}</td>
                <td>${grade}</td>
                <td>${weight}</td>
                <td>${status}</td>
            </tr>
            `
        }

        tableContent += `</table>`
        return tableContent
    }

    // 🔥 修复：生成井结构草图部分
    function generateWellSketchSection() {
        var sketchData = stepData.well_sketch || {}

        console.log("🎨 生成井结构草图，数据:", JSON.stringify(sketchData))

        if (sketchData && sketchData.well_path && sketchData.casings) {
            return `
            <div style="width: 100%; text-align: center; margin: 20px 0; page-break-inside: avoid;">
                <canvas id="wellSketchChart" width="800" height="900"
                        style="border: 1px solid #ddd; background: #fff; display: block; margin: 0 auto; max-width: 100%; box-shadow: 0 2px 4px rgba(0,0,0,0.1);"></canvas>
                <div style="margin-top: 15px; text-align: center;">
                    <p style="font-size: 12px; color: #666; margin: 5px 0;">
                        井身结构示意图
                    </p>
                    <p style="font-size: 10px; color: #999; margin: 0;">
                        深度单位：英尺 (ft) | 直径单位：英寸 (in)
                    </p>
                </div>
            </div>
            <script>
                ${generateWellSketchScript(sketchData)}
            </script>
            `
        } else {
            return `
            <div style="background: #f8f9fa; border: 2px dashed #dee2e6; height: 400px; display: flex; align-items: center; justify-content: center; margin: 20px 0; color: #6c757d; font-style: italic; border-radius: 8px;">
                <div style="text-align: center;">
                    <p style="font-size: 18px; margin: 0;">🏗️ 井身结构草图</p>
                    <p style="font-size: 14px; margin: 8px 0 0 0;">暂无草图数据</p>
                    <p style="font-size: 12px; color: #999; margin: 4px 0 0 0;">需要轨迹和套管数据来生成井身结构草图</p>
                </div>
            </div>
            `
        }
    }

    // 🔥 修复：生成井结构草图绘制脚本
    function generateWellSketchScript(sketchData) {
        return `
        document.addEventListener('DOMContentLoaded', function() {
            try {
                var canvas = document.getElementById('wellSketchChart');
                if (!canvas) {
                    console.error('未找到井结构草图画布');
                    return;
                }

                var ctx = canvas.getContext('2d');
                drawWellSketch(ctx, ${JSON.stringify(sketchData)});

                console.log('井结构草图绘制完成');
            } catch (error) {
                console.error('绘制井结构草图失败:', error);
            }
        });

        function drawWellSketch(ctx, sketchData) {
            var width = ctx.canvas.width;
            var height = ctx.canvas.height;
            var padding = 80; // 🔥 增加边距为标签留出空间
            var chartWidth = width - 2 * padding;
            var chartHeight = height - 2 * padding;

            // 清空画布
            ctx.clearRect(0, 0, width, height);

            // 设置背景
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, width, height);

            if (!sketchData.well_path || !sketchData.casings) {
                // 绘制占位符
                ctx.fillStyle = '#666';
                ctx.font = '16px Arial';
                ctx.textAlign = 'center';
                ctx.fillText('暂无井结构数据', width / 2, height / 2);
                return;
            }

            var wellPath = sketchData.well_path;
            var casings = sketchData.casings;
            var dimensions = sketchData.dimensions || {};

            // 🔥 修复：重新计算比例和尺寸
            var maxDepth = dimensions.max_depth || 1000;
            var maxHorizontal = dimensions.max_horizontal || 100;

            // 确保合理的最小值
            maxDepth = Math.max(maxDepth, 500);
            maxHorizontal = Math.max(maxHorizontal, 50);

            var depthScale = chartHeight / maxDepth;

            // 🔥 关键修复：套管直径缩放
            // 找到最大外径用于缩放计算
            var maxOuterDiameter = 0;
            casings.forEach(function(casing) {
                var outerDiam = casing.outer_diameter || 7;
                if (outerDiam > maxOuterDiameter) {
                    maxOuterDiameter = outerDiam;
                }
            });

            // 套管直径应该占整个宽度的合理比例（约15-20%）
            var diameterScale = (chartWidth * 0.15) / maxOuterDiameter;

            function scaleY(depth) {
                return padding + (depth * depthScale);
            }

            function scaleX(horizontal) {
                return padding + chartWidth / 2 + (horizontal * depthScale * 0.1); // 水平位移比例缩小
            }

            function scaleDiameter(diameter) {
                return diameter * diameterScale;
            }

            // 🔥 修复：按深度从大到小排序套管，确保正确的绘制顺序
            var sortedCasings = casings.slice().sort(function(a, b) {
                var diamA = a.outer_diameter || 0;
                var diamB = b.outer_diameter || 0;
                return diamB - diamA; // 大直径先绘制
            });

            var centerX = padding + chartWidth / 2;

            // 🔥 修复：绘制套管 - 先绘制大直径，再绘制小直径
            sortedCasings.forEach(function(casing, index) {
                var topDepth = casing.top_depth || 0;
                var bottomDepth = casing.bottom_depth || maxDepth * 0.8;

                var topY = scaleY(topDepth);
                var bottomY = scaleY(bottomDepth);

                var outerRadius = scaleDiameter(casing.outer_diameter || 7) / 2;
                var innerRadius = scaleDiameter(casing.inner_diameter || 6) / 2;

                // 确保半径合理
                outerRadius = Math.max(outerRadius, 8);
                innerRadius = Math.max(innerRadius, 6);
                innerRadius = Math.min(innerRadius, outerRadius - 1);

                // 绘制套管外壁
                ctx.fillStyle = getCasingColor(casing.type);
                ctx.fillRect(centerX - outerRadius, topY, outerRadius * 2, bottomY - topY);

                // 绘制套管内壁（井眼）
                ctx.fillStyle = '#f0f8ff';
                ctx.fillRect(centerX - innerRadius, topY, innerRadius * 2, bottomY - topY);

                // 绘制套管边框
                ctx.strokeStyle = '#333';
                ctx.lineWidth = 1;
                ctx.strokeRect(centerX - outerRadius, topY, outerRadius * 2, bottomY - topY);
                ctx.strokeRect(centerX - innerRadius, topY, innerRadius * 2, bottomY - topY);
            });

            // 🔥 修复：绘制井轨迹 - 在套管内部
            if (wellPath.length > 1) {
                ctx.strokeStyle = '#0066cc';
                ctx.lineWidth = 3;
                ctx.beginPath();

                for (var i = 0; i < wellPath.length; i++) {
                    var point = wellPath[i];
                    var x = scaleX(point.x || 0);
                    var y = scaleY(point.y || 0);

                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.stroke();

                // 绘制轨迹点
                ctx.fillStyle = '#0066cc';
                for (var i = 0; i < wellPath.length; i++) {
                    var point = wellPath[i];
                    var x = scaleX(point.x || 0);
                    var y = scaleY(point.y || 0);

                    ctx.beginPath();
                    ctx.arc(x, y, 2, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }

            // 🔥 修复：绘制套管标签 - 避免重叠
            var labelOffsets = {}; // 记录已使用的Y位置
            sortedCasings.forEach(function(casing, index) {
                var topDepth = casing.top_depth || 0;
                var topY = scaleY(topDepth);
                var outerRadius = scaleDiameter(casing.outer_diameter || 7) / 2;

                // 🔥 防止标签重叠
                var labelY = topY + 15;
                while (labelOffsets[Math.floor(labelY / 20)]) {
                    labelY += 20; // 向下偏移
                }
                labelOffsets[Math.floor(labelY / 20)] = true;

                var labelText = (casing.label || casing.type || '套管') +
                               ' ' + (casing.outer_diameter ? casing.outer_diameter.toFixed(1) + '"' : '');

                // 绘制标签背景
                ctx.fillStyle = 'rgba(255, 255, 255, 0.8)';
                var textWidth = ctx.measureText(labelText).width;
                ctx.fillRect(centerX + outerRadius + 5, labelY - 12, textWidth + 8, 16);

                // 绘制标签文字
                ctx.fillStyle = '#333';
                ctx.font = '11px Arial';
                ctx.textAlign = 'left';
                ctx.fillText(labelText, centerX + outerRadius + 8, labelY);

                // 绘制指示线
                ctx.strokeStyle = '#666';
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(centerX + outerRadius, topY);
                ctx.lineTo(centerX + outerRadius + 5, labelY - 6);
                ctx.stroke();
            });

            // 🔥 修复：绘制深度标尺
            drawDepthScale(ctx, padding - 30, padding, chartHeight, maxDepth);

            // 绘制标题
            ctx.fillStyle = '#333';
            ctx.font = 'bold 16px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('井身结构示意图', width / 2, 30);

            // 🔥 新增：绘制比例说明
            ctx.font = '10px Arial';
            ctx.fillStyle = '#666';
            ctx.textAlign = 'center';
            ctx.fillText('注：套管直径已按比例放大以便清晰显示', width / 2, height - 10);
        }

        function getCasingColor(casingType) {
            var type = (casingType || '').toLowerCase();
            if (type.includes('conductor') || type.includes('导管')) {
                return '#D2691E'; // 沙褐色
            } else if (type.includes('surface') || type.includes('表层')) {
                return '#FFD700'; // 金色
            } else if (type.includes('intermediate') || type.includes('技术') || type.includes('中间')) {
                return '#32CD32'; // 酸橙绿
            } else if (type.includes('production') || type.includes('生产')) {
                return '#FF6347'; // 番茄红
            } else {
                return '#708090'; // 石板灰
            }
        }

        function drawDepthScale(ctx, x, y, height, maxDepth) {
            ctx.strokeStyle = '#666';
            ctx.lineWidth = 1;
            ctx.font = '10px Arial';
            ctx.textAlign = 'right';
            ctx.fillStyle = '#666';

            // 绘制标尺线
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x, y + height);
            ctx.stroke();

            // 🔥 修复：更合理的刻度间隔
            var steps = Math.min(10, Math.max(5, Math.floor(maxDepth / 100)));
            var stepSize = height / steps;
            var depthStep = maxDepth / steps;

            for (var i = 0; i <= steps; i++) {
                var tickY = y + i * stepSize;
                var depth = i * depthStep;

                // 绘制刻度线
                ctx.beginPath();
                ctx.moveTo(x - 5, tickY);
                ctx.lineTo(x, tickY);
                ctx.stroke();

                // 绘制深度标签
                if (i % 2 === 0 || steps <= 5) { // 避免标签过密
                    ctx.fillText(depth.toFixed(0) + ' ft', x - 8, tickY + 3);
                }
            }

            // 绘制标尺标题
            ctx.save();
            ctx.translate(x - 50, y + height / 2);
            ctx.rotate(-Math.PI / 2);
            ctx.textAlign = 'center';
            ctx.font = '12px Arial';
            ctx.fillText('深度 (ft)', 0, 0);
            ctx.restore();
        }
        `
    }


    // 🔥 修复：generateProductionParametersTable函数
    function generateProductionParametersTable() {
        var params = stepData.parameters && stepData.parameters.parameters ? stepData.parameters.parameters : {}
        var prediction = stepData.prediction || {}
        var finalValues = prediction.finalValues || {}
        var iprCurveData = prediction.iprCurve || []

        console.log("📊 生产参数数据:", JSON.stringify(params))

        // 智能数值格式化
        function formatParameterValue(value, type, defaultText = '待计算') {
            if (value === undefined || value === null || value === 0) {
                return defaultText
            }

            switch(type) {
                case 'pressure':
                    return formatPressureValue(value)
                case 'flow':
                    return formatFlowValue(value)
                case 'temperature':
                    return formatTemperatureValue(value)
                case 'depth':
                    return formatDepthValue(value)
                default:
                    if (typeof value === 'number') {
                        return value.toFixed(1)
                    }
                    return value.toString()
            }
        }

        var tableContent = `
        <h3>4.1 生产参数</h3>
        <table>
            <tr><td>地层压力</td><td>${params.geoPressure} Mpa</td></tr>
            <tr><td>期望产量</td><td>${params.expectedProduction} m³/d</td></tr>
            <tr><td>饱和压力</td><td>${params.saturationPressure} Mpa</td></tr>
            <tr><td>生产指数</td><td>${params.produceIndex} m³/d ${getDisplayPressureUnit()}</td></tr>
            <tr><td>井底温度</td><td>${params.bht}°C</td></tr>
            <tr><td>含水率</td><td>${params.bsw} %</td></tr>
            <tr><td>API重度</td><td>${params.api} °API</td></tr>
            <tr><td>油气比</td><td>${params.gasOilRatio} </td></tr>
            <tr><td>井口压力</td><td>${params.wellHeadPressure} Mpa</td></tr>
            <tr style="background-color: #f0f8ff;"><td colspan="2"><strong>预测结果</strong></td></tr>
            <tr><td>预测吸入口气液比</td><td>${finalValues.gasRate} </td></tr>
            <tr><td>预测所需扬程</td><td>${formatDepthValue(finalValues.totalHead)} </td></tr>
            <tr><td>预测产量</td><td>${formatPressureValue(finalValues.production)} </td></tr>
        </table>

        <h3>4.2 IPR曲线分析</h3>
        ${generateIPRSection(iprCurveData, finalValues, params)}
        `

        return tableContent
    }

    // 🔥 新增：生成IPR曲线部分
    function generateIPRSection(iprCurveData, finalValues, params) {
        if (!iprCurveData || iprCurveData.length === 0) {
            return `
            <div style="background: #f8f9fa; border: 2px dashed #dee2e6; height: 300px; display: flex; align-items: center; justify-content: center; margin: 20px 0; color: #6c757d; font-style: italic; border-radius: 8px;">
                <div style="text-align: center;">
                    <p style="font-size: 18px; margin: 0;">📈 IPR曲线图</p>
                    <p style="font-size: 14px; margin: 8px 0 0 0;">暂无IPR曲线数据</p>
                    <p style="font-size: 12px; color: #999; margin: 4px 0 0 0;">需要完成预测分析来生成IPR曲线</p>
                </div>
            </div>
            `
        }

        return `
        <div style="width: 100%; margin: 20px 0;">
            <!-- IPR曲线图表 -->
            <div style="text-align: center; margin-bottom: 20px;">
                <canvas id="iprChart" width="700" height="500"
                        style="border: 1px solid #ddd; background: #fff; display: block; margin: 0 auto; max-width: 100%; box-shadow: 0 2px 4px rgba(0,0,0,0.1);"></canvas>
                <p style="font-size: 12px; color: #666; margin-top: 10px;">
                    IPR曲线分析图（Inflow Performance Relationship）
                </p>
            </div>

            <!-- IPR分析表格 -->
            ${generateIPRAnalysisTable(iprCurveData, finalValues, params)}

            <script>
                ${generateIPRChartScript(iprCurveData, finalValues, params)}
            </script>
        </div>
        `
    }

    // 🔥 修复：生成IPR分析表格 - 使用正确的单位转换
    function generateIPRAnalysisTable(iprCurveData, finalValues, params) {
        // 计算关键指标
        var maxProduction = iprCurveData.length > 0 ? Math.max(...iprCurveData.map(p => p.production || p.flow_rate || 0)) : 0
        var reservoirPressure = params.geoPressure || 0
        var operatingPressure = 0
        var operatingProduction = finalValues.production || 0

        // 查找工作点对应的压力
        if (iprCurveData.length > 0 && operatingProduction > 0) {
            var closestPoint = iprCurveData.reduce((prev, curr) => {
                var prevDiff = Math.abs((prev.production || prev.flow_rate || 0) - operatingProduction)
                var currDiff = Math.abs((curr.production || curr.flow_rate || 0) - operatingProduction)
                return currDiff < prevDiff ? curr : prev
            })
            operatingPressure = closestPoint.pressure || closestPoint.wellhead_pressure || 0
        }

        // 🔥 使用单位转换函数格式化数值
        var formattedReservoirPressure = formatPressureValue(reservoirPressure)
        var formattedMaxProduction = formatFlowValue(maxProduction)
        var formattedOperatingProduction = formatFlowValue(operatingProduction)
        var formattedOperatingPressure = formatPressureValue(operatingPressure)

        // 🔥 计算产能指数时也要考虑单位
        var productivity = maxProduction > 0 && reservoirPressure > 0 ? (maxProduction / reservoirPressure).toFixed(3) : '0'
        var productivityUnit = `${getDisplayFlowUnit()}/${getDisplayPressureUnit()}`

        var operatingEfficiency = maxProduction > 0 ? ((operatingProduction / maxProduction) * 100).toFixed(1) : '0'

        return `
        <h4>IPR曲线关键指标</h4>
        <table style="margin-top: 15px;">
            <thead>
                <tr style="background-color: #f5f7fa;">
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">指标项</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">数值</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">指标项</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">数值</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">地层压力</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${formattedReservoirPressure}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最大产能</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${formattedMaxProduction}</td>
                </tr>
                <tr style="background-color: #fafafa;">
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">工作点产量</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #FF6B6B;">${formattedOperatingProduction}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">工作点压力</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #FF6B6B;">${formattedOperatingPressure}</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">产能指数</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${productivity} ${productivityUnit}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">工作效率</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: ${operatingEfficiency > 70 ? '#4ECDC4' : operatingEfficiency > 50 ? '#FFD700' : '#FF6B6B'};">${operatingEfficiency}%</td>
                </tr>
                <tr style="background-color: #f0f8ff;">
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">曲线类型</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">Vogel方程</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">数据点数</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${iprCurveData.length} 个</td>
                </tr>
            </tbody>
        </table>

        <div style="margin-top: 15px; padding: 12px; background-color: #e8f4fd; border-left: 4px solid #2196F3; border-radius: 4px;">
            <p style="margin: 0; font-size: 12px; color: #1976D2;">
                <strong>💡 分析说明：</strong>IPR曲线显示了井底流压与产量的关系。工作效率${operatingEfficiency}%表示当前工作点相对于最大产能的利用率。
                ${operatingEfficiency > 70 ? '当前工作效率良好。' : operatingEfficiency > 50 ? '建议优化生产参数以提高效率。' : '建议重新评估生产方案。'}
            </p>
        </div>
        `
    }

    // 🔥 新增：生成IPR曲线绘制脚本
    function generateIPRChartScript(iprCurveData, finalValues, params) {
        return `
        document.addEventListener('DOMContentLoaded', function() {
            try {
                var canvas = document.getElementById('iprChart');
                if (!canvas) {
                    console.error('未找到IPR曲线画布');
                    return;
                }

                var ctx = canvas.getContext('2d');
                drawIPRCurve(ctx, ${JSON.stringify(iprCurveData)}, ${JSON.stringify(finalValues)}, ${JSON.stringify(params)});

                console.log('IPR曲线绘制完成');
            } catch (error) {
                console.error('绘制IPR曲线失败:', error);
            }
        });

        function drawIPRCurve(ctx, iprData, finalValues, params) {
            var width = ctx.canvas.width;
            var height = ctx.canvas.height;
            var padding = 80;
            var chartWidth = width - 2 * padding;
            var chartHeight = height - 2 * padding;

            // 清空画布
            ctx.clearRect(0, 0, width, height);

            // 设置背景
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, width, height);

            if (!iprData || iprData.length === 0) {
                // 绘制占位符
                ctx.fillStyle = '#666';
                ctx.font = '16px Arial';
                ctx.textAlign = 'center';
                ctx.fillText('暂无IPR曲线数据', width / 2, height / 2);
                return;
            }

            // 🔥 数据预处理和缩放
            var productionValues = iprData.map(d => d.production || d.flow_rate || 0);
            var pressureValues = iprData.map(d => d.pressure || d.wellhead_pressure || 0);

            var maxProduction = Math.max(...productionValues);
            var maxPressure = Math.max(...pressureValues);
            var minProduction = Math.min(...productionValues);
            var minPressure = Math.min(...pressureValues);

            // 添加边距
            var productionRange = maxProduction - minProduction;
            var pressureRange = maxPressure - minPressure;

            maxProduction += productionRange * 0.1;
            maxPressure += pressureRange * 0.1;
            minProduction = Math.max(0, minProduction - productionRange * 0.1);
            minPressure = Math.max(0, minPressure - pressureRange * 0.1);

            // 坐标转换函数
            function scaleX(production) {
                return padding + (production - minProduction) / (maxProduction - minProduction) * chartWidth;
            }

            function scaleY(pressure) {
                return padding + chartHeight - (pressure - minPressure) / (maxPressure - minPressure) * chartHeight;
            }

            // 绘制网格
            ctx.strokeStyle = '#e0e0e0';
            ctx.lineWidth = 1;

            // 垂直网格线
            for (var i = 0; i <= 10; i++) {
                var x = padding + (chartWidth / 10) * i;
                ctx.beginPath();
                ctx.moveTo(x, padding);
                ctx.lineTo(x, height - padding);
                ctx.stroke();
            }

            // 水平网格线
            for (var i = 0; i <= 10; i++) {
                var y = padding + (chartHeight / 10) * i;
                ctx.beginPath();
                ctx.moveTo(padding, y);
                ctx.lineTo(width - padding, y);
                ctx.stroke();
            }

            // 绘制坐标轴
            ctx.strokeStyle = '#333';
            ctx.lineWidth = 2;

            // X轴
            ctx.beginPath();
            ctx.moveTo(padding, height - padding);
            ctx.lineTo(width - padding, height - padding);
            ctx.stroke();

            // Y轴
            ctx.beginPath();
            ctx.moveTo(padding, padding);
            ctx.lineTo(padding, height - padding);
            ctx.stroke();

            // 绘制坐标轴标签
            ctx.fillStyle = '#666';
            ctx.font = '12px Arial';
            ctx.textAlign = 'center';

            // X轴刻度标签
            for (var i = 0; i <= 5; i++) {
                var x = padding + (chartWidth / 5) * i;
                var value = minProduction + (maxProduction - minProduction) * i / 5;
                ctx.fillText(value.toFixed(0), x, height - padding + 20);
            }

            // Y轴刻度标签
            ctx.textAlign = 'right';
            for (var i = 0; i <= 5; i++) {
                var y = height - padding - (chartHeight / 5) * i;
                var value = minPressure + (maxPressure - minPressure) * i / 5;
                ctx.fillText(value.toFixed(0), padding - 10, y + 4);
            }

            // 🔥 绘制IPR曲线
            if (iprData.length > 1) {
                // 排序数据点
                var sortedData = iprData.slice().sort((a, b) => {
                    var prodA = a.production || a.flow_rate || 0;
                    var prodB = b.production || b.flow_rate || 0;
                    return prodA - prodB;
                });

                ctx.strokeStyle = '#2196F3';
                ctx.lineWidth = 3;
                ctx.beginPath();

                for (var i = 0; i < sortedData.length; i++) {
                    var point = sortedData[i];
                    var production = point.production || point.flow_rate || 0;
                    var pressure = point.pressure || point.wellhead_pressure || 0;

                    var x = scaleX(production);
                    var y = scaleY(pressure);

                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.stroke();

                // 绘制数据点
                ctx.fillStyle = '#2196F3';
                for (var i = 0; i < sortedData.length; i++) {
                    var point = sortedData[i];
                    var production = point.production || point.flow_rate || 0;
                    var pressure = point.pressure || point.wellhead_pressure || 0;

                    var x = scaleX(production);
                    var y = scaleY(pressure);

                    ctx.beginPath();
                    ctx.arc(x, y, 4, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }

            // 🔥 绘制工作点
            if (finalValues && finalValues.production > 0) {
                var operatingProduction = finalValues.production;

                // 查找对应的压力值
                var operatingPressure = 0;
                if (iprData.length > 0) {
                    var closestPoint = iprData.reduce((prev, curr) => {
                        var prevProd = prev.production || prev.flow_rate || 0;
                        var currProd = curr.production || curr.flow_rate || 0;
                        return Math.abs(currProd - operatingProduction) < Math.abs(prevProd - operatingProduction) ? curr : prev;
                    });
                    operatingPressure = closestPoint.pressure || closestPoint.wellhead_pressure || 0;
                }

                if (operatingPressure > 0) {
                    var opX = scaleX(operatingProduction);
                    var opY = scaleY(operatingPressure);

                    // 绘制工作点
                    ctx.fillStyle = '#FF6B6B';
                    ctx.beginPath();
                    ctx.arc(opX, opY, 8, 0, 2 * Math.PI);
                    ctx.fill();

                    // 绘制工作点标签
                    ctx.fillStyle = '#333';
                    ctx.font = 'bold 12px Arial';
                    ctx.textAlign = 'left';
                    ctx.fillText('工作点', opX + 12, opY - 8);
                    ctx.font = '10px Arial';
                    ctx.fillText(operatingProduction.toFixed(1) + ' bbl/d', opX + 12, opY + 5);
                    ctx.fillText(operatingPressure.toFixed(1) + ' psi', opX + 12, opY + 17);

                    // 绘制工作点辅助线
                    ctx.strokeStyle = '#FF6B6B';
                    ctx.lineWidth = 1;
                    ctx.setLineDash([5, 5]);

                    // 垂直辅助线
                    ctx.beginPath();
                    ctx.moveTo(opX, height - padding);
                    ctx.lineTo(opX, opY);
                    ctx.stroke();

                    // 水平辅助线
                    ctx.beginPath();
                    ctx.moveTo(padding, opY);
                    ctx.lineTo(opX, opY);
                    ctx.stroke();

                    ctx.setLineDash([]);
                }
            }

            // 🔥 绘制图表标题和坐标轴标签
            ctx.fillStyle = '#333';
            ctx.font = 'bold 16px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('IPR曲线分析图', width / 2, 30);

            // X轴标签
            ctx.font = '14px Arial';
            ctx.fillText('产量 (bbl/d)', width / 2, height - 15);

            // Y轴标签
            ctx.save();
            ctx.translate(25, height / 2);
            ctx.rotate(-Math.PI / 2);
            ctx.textAlign = 'center';
            ctx.fillText('井底流压 (psi)', 0, 0);
            ctx.restore();

            // 绘制图例
            var legendY = padding + 20;

            // IPR曲线图例
            ctx.fillStyle = '#2196F3';
            ctx.fillRect(width - 180, legendY, 20, 3);
            ctx.fillStyle = '#333';
            ctx.font = '12px Arial';
            ctx.textAlign = 'left';
            ctx.fillText('IPR曲线', width - 155, legendY + 8);

            // 工作点图例
            if (finalValues && finalValues.production > 0) {
                ctx.fillStyle = '#FF6B6B';
                ctx.beginPath();
                ctx.arc(width - 170, legendY + 25, 6, 0, 2 * Math.PI);
                ctx.fill();
                ctx.fillStyle = '#333';
                ctx.fillText('工作点', width - 155, legendY + 30);
            }
        }
        `
    }

    // 🔥 修复：generateEquipmentSelection函数
    function generateEquipmentSelection() {
        var content = ""

        console.log("🔧 设备选型数据:")

        // 5.1 泵选型
        content += `
        <h3>5.1 泵选型</h3>
        <table>
            <tr><td>制造商</td><td>${safeValue(stepData.pump, 'manufacturer', '未知制造商')}</td></tr>
            <tr><td>泵型</td><td>${safeValue(stepData.pump, 'model', '未选择')}</td></tr>
            <tr><td>选型代码</td><td>${safeValue(stepData.pump, 'selectedPump', 'N/A')}</td></tr>
            <tr><td>级数</td><td>${safeValue(stepData.pump, 'stages', '0')}</td></tr>
            <tr><td>需要扬程</td><td>${formatDepthValue(stepData.pump?.totalHead || 0)}</td></tr>
            <tr><td>泵功率</td><td>${formatPowerValue(stepData.pump?.totalPower || 0)}</td></tr>
            <tr><td>效率</td><td>${safeToFixed(stepData.pump?.efficiency, 1, '0')} %</td></tr>
            <tr><td>排量范围</td><td>${formatFlowValue(stepData.pump?.minFlow || 0, false)} - ${formatFlowValue(stepData.pump?.maxFlow || 0)}</td></tr>
        </table>
        `

        // 5.2 保护器选型
        content += `
        <h3>5.2 保护器选型</h3>
        <table>
            <tr><td>制造商</td><td>${safeValue(stepData.protector, 'manufacturer', '未知制造商')}</td></tr>
            <tr><td>保护器型号</td><td>${safeValue(stepData.protector, 'model', '未选择')}</td></tr>
            <tr><td>数量</td><td>${safeValue(stepData.protector, 'quantity', '0')}</td></tr>
            <tr><td>总推力容量</td><td>${safeToFixed(stepData.protector?.totalThrustCapacity, 0, '0')} ${getDisplayForceUnit()}</td></tr>
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
            content += `<p>未选择分离器（气液比较低，可选配置）</p>`
        }

        // 5.4 电机选型
        content += `
        <h3>5.4 电机选型</h3>
        <table>
            <tr><td>制造商</td><td>${safeValue(stepData.motor, 'manufacturer', '未知制造商')}</td></tr>
            <tr><td>电机型号</td><td>${safeValue(stepData.motor, 'model', '未选择')}</td></tr>
            <tr><td>功率</td><td>${formatPowerValue(stepData.motor?.power || 0)}</td></tr>
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


    function generateSummaryTable() {
        return `
        <table class="equipment-summary-table">
            <tr>
                <th>设备</th>
                <th>描述</th>
                <th>外径[英寸]</th>
                <th>长度[英尺]</th>
            </tr>
            <tr><td>降压变压器/发电机组</td><td>由公司提供</td><td>-</td><td>-</td></tr>
            <tr><td>变频驱动器（VSD）</td><td>变速驱动装置</td><td>-</td><td>-</td></tr>
            <tr><td>升压变压器</td><td>由公司提供</td><td>-</td><td>-</td></tr>
            <tr><td>电力电缆</td><td>潜油电泵专用电缆</td><td>-</td><td>-</td></tr>
            <tr><td>电机引线延长段（MLE）</td><td>电机引线延长组件</td><td>-</td><td>-</td></tr>
            <tr><td>传感器</td><td>井下监测传感器</td><td>-</td><td>-</td></tr>
            <tr><td>泵排出头</td><td>含止回阀组件</td><td>-</td><td>-</td></tr>
            <tr><td>上部泵</td><td>${safeValue(stepData.pump, 'model', '待定')}</td><td>-</td><td>-</td></tr>
            <tr><td>下部泵</td><td>${safeValue(stepData.pump, 'model', '待定')}</td><td>-</td><td>-</td></tr>
            <tr><td>分离器</td><td>${stepData.separator && !stepData.separator.skipped ? safeValue(stepData.separator, 'model', '待定') : '不适用'}</td><td>-</td><td>-</td></tr>
            <tr><td>上部保护器</td><td>${safeValue(stepData.protector, 'model', '待定')}</td><td>-</td><td>-</td></tr>
            <tr><td>下部保护器</td><td>${safeValue(stepData.protector, 'model', '待定')}</td><td>-</td><td>-</td></tr>
            <tr><td>电机</td><td>${safeValue(stepData.motor, 'model', '待定')}</td><td>-</td><td>-</td></tr>
            <tr><td>传感器</td><td>压力与温度监测</td><td>-</td><td>-</td></tr>
            <tr><td>扶正器</td><td>泵用扶正装置</td><td>-</td><td>-</td></tr>
            <tr><td colspan="2"><strong>整个系统</strong></td><td><strong>-</strong></td><td><strong>-</strong></td></tr>
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
                    // status: (stepData.well && stepData.casing_data) ? (isChineseMode ? "已完成" : "Complete") : (isChineseMode ? "部分完成" : "Partial"),
                    status: stepData.well ? (isChineseMode ? "已完成" : "Complete") : "",
                    complete: !!(stepData.well && stepData.casing_data)
                },
                {
                    id: "well-trajectory",
                    title: isChineseMode ? "井轨迹图" : "Well Trajectory",
                    icon: "📈",
                    level: 1,
                    status: stepData.trajectory_data ? (isChineseMode ? "已完成" : "Complete") : (isChineseMode ? "待完善" : "To be completed"),
                    complete: !!(stepData.trajectory_data && stepData.trajectory_data.length > 0)
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

    // 🔥 修复：其他函数保持原有逻辑，但使用新的格式化函数
    function getTotalPower() {
        var power = 0
        if (stepData.motor && stepData.motor.power) {
            power = parseFloat(stepData.motor.power) || 0
        } else if (stepData.pump && stepData.pump.totalPower) {
            power = parseFloat(stepData.pump.totalPower) || 0
        }

        // 转换为显示单位
        var convertedPower = convertPowerForDisplay(power)
        return convertedPower.toFixed(1)
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

        if (!dataEnhanced && (!stepData || Object.keys(stepData).length === 0)) {
            console.log("⏳ 等待数据增强完成...")
            return
        }

        reportGenerated = false

        var html = generateReportHtml(selectedTemplate)
        reportHtml = html

        console.log("✅ 报告HTML已生成，长度:", html.length)

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

    // function exportToExcel() {
    //     saveFileDialog.nameFilters = ["Excel files (*.xlsx)"]
    //     saveFileDialog.defaultSuffix = "xlsx"
    //     saveFileDialog.exportFormat = "xlsx"
    //     saveFileDialog.open()
    // }

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

        // console.log("最终传递给控制器的数据:", JSON.stringify(reportData, null, 2))

        // 调用控制器导出
        if (controller && controller.exportReport) {
            console.log("导出英制还是公制，传递",isMetric)
            controller.exportReport(reportData, isMetric)
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

    // 🔥 修改：生成井轨迹图部分
    function generateWellTrajectorySection() {
        var trajectoryData = stepData.trajectory_data || []
        var calcInfo = stepData.calculation || {}

        console.log("🎨 生成井轨迹图，数据点数:", trajectoryData.length)

        if (trajectoryData.length > 0) {
            // 有轨迹数据，生成实际图表
            return `
            <div style="width: 100%; clear: both; margin: 20px 0;">
                <div style="text-align: center; margin-bottom: 20px;">
                    <canvas id="trajectoryChart" width="700" height="500"
                            style="border: 1px solid #ddd; background: #fff; display: block; margin: 0 auto; max-width: 100%;"></canvas>
                </div>
                ${generateTrajectoryStatsTable(trajectoryData, calcInfo)}
                <script>
                    ${generateTrajectoryChartScript(trajectoryData, calcInfo)}
                </script>
            </div>
            `
        } else {
            // 没有数据，显示占位符
            return  `
            <div style="background: #f8f9fa; border: 2px dashed #dee2e6; height: 300px; display: flex; align-items: center; justify-content: center; margin: 20px 0; color: #6c757d; font-style: italic; clear: both;">
                <div style="text-align: center;">
                    <p style="font-size: 18px; margin: 0;">📈 井轨迹图</p>
                    <p style="font-size: 14px; margin: 8px 0 0 0;">暂无轨迹数据</p>
                    <p style="font-size: 12px; color: #999; margin: 4px 0 0 0;">需要上传井轨迹数据来生成完整的轨迹图</p>
                </div>
            </div>
            `
        }
    }


    // 🔥 修改：生成轨迹统计表格 - 显示最大狗腿度位置信息
    function generateTrajectoryStatsTable(trajectoryData, calcInfo) {
        var stats = calculateTrajectoryStats(trajectoryData)

        // 🔥 格式化最大狗腿度信息，包含位置
        var maxDlsInfo = `${stats.max_dls.toFixed(2)}°/30m`
        if (stats.max_dls > 0) {
            maxDlsInfo += `<br><span style="font-size: 10px; color: #666;">@ TVD:${formatDepthValue(stats.max_dls_tvd, false)}, MD:${formatDepthValue(stats.max_dls_md, false)}</span>`
        }

        return `
        <div style="width: 100%; margin-top: 30px; clear: both;">
            <h3 style="color: #1e3a5f; margin-bottom: 15px; font-size: 16px;">井轨迹统计信息</h3>
            <table style="width: 100%; border-collapse: collapse; margin: 0;">
                <thead>
                    <tr style="background-color: #f5f7fa;">
                        <th style="padding: 12px; border: 1px solid #e0e0e0; text-align: left; color: #1e3a5f; font-weight: 600;">统计项</th>
                        <th style="padding: 12px; border: 1px solid #e0e0e0; text-align: right; color: #1e3a5f; font-weight: 600;">数值</th>
                        <th style="padding: 12px; border: 1px solid #e0e0e0; text-align: left; color: #1e3a5f; font-weight: 600;">统计项</th>
                        <th style="padding: 12px; border: 1px solid #e0e0e0; text-align: right; color: #1e3a5f; font-weight: 600;">数值</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td style="padding: 10px; border: 1px solid #e0e0e0;">轨迹点数</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right;">${stats.total_points} 个</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0;">最大井斜角</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right;">${(stats.max_inclination || calcInfo.max_inclination || 0).toFixed(1)}°</td>
                    </tr>
                    <tr style="background-color: #fafafa;">
                        <td style="padding: 10px; border: 1px solid #e0e0e0;">最大垂深 (TVD)</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right;">${formatDepthValue(stats.max_tvd)}</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; vertical-align: top;">最大狗腿度</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right; vertical-align: top;">${maxDlsInfo}</td>
                    </tr>
                    <tr>
                        <td style="padding: 10px; border: 1px solid #e0e0e0;">最大测深 (MD)</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right;">${formatDepthValue(stats.max_md)}</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0;">水平位移</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right;">${formatDepthValue(stats.max_horizontal)}</td>
                    </tr>
                    <tr style="background-color: #f0f8ff;">
                        <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #FF6B6B;">泵挂垂深</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right; font-weight: bold; color: #FF6B6B;">${formatDepthValue(calcInfo.pump_hanging_depth || 0)}</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #4ECDC4;">射孔垂深</td>
                        <td style="padding: 10px; border: 1px solid #e0e0e0; text-align: right; font-weight: bold; color: #4ECDC4;">${formatDepthValue(calcInfo.perforation_depth || 0)}</td>
                    </tr>
                </tbody>
            </table>
        </div>
        `
    }

    // 🔥 修改：计算轨迹统计 - 增加最大狗腿度位置信息
    function calculateTrajectoryStats(trajectoryData) {
        if (!trajectoryData || trajectoryData.length === 0) {
            return {
                total_points: 0,
                max_tvd: 0,
                max_md: 0,
                max_inclination: 0,
                max_dls: 0,
                max_dls_tvd: 0,      // 🔥 新增：最大狗腿度对应的垂深
                max_dls_md: 0,       // 🔥 新增：最大狗腿度对应的测深
                max_horizontal: 0
            }
        }

        var tvdValues = trajectoryData.map(d => d.tvd || 0).filter(v => v > 0)
        var mdValues = trajectoryData.map(d => d.md || 0).filter(v => v > 0)
        var incValues = trajectoryData.map(d => d.inclination || 0)
        var dlsValues = trajectoryData.map(d => d.dls || 0)

        // 🔥 查找最大狗腿度及其对应的位置
        var maxDls = 0
        var maxDlsTvd = 0
        var maxDlsMd = 0
        var maxDlsIndex = -1

        for (var i = 0; i < trajectoryData.length; i++) {
            var currentDls = trajectoryData[i].dls || 0
            if (currentDls > maxDls) {
                maxDls = currentDls
                maxDlsTvd = trajectoryData[i].tvd || 0
                maxDlsMd = trajectoryData[i].md || 0
                maxDlsIndex = i
            }
        }

        // 计算最大水平位移
        var pathData = calculateTrajectoryPath(trajectoryData)
        var maxHorizontal = pathData.horizontal.length > 0 ? Math.max(...pathData.horizontal) : 0

        return {
            total_points: trajectoryData.length,
            max_tvd: tvdValues.length > 0 ? Math.max(...tvdValues) : 0,
            max_md: mdValues.length > 0 ? Math.max(...mdValues) : 0,
            max_inclination: incValues.length > 0 ? Math.max(...incValues) : 0,
            max_dls: maxDls,
            max_dls_tvd: maxDlsTvd,      // 🔥 最大狗腿度对应的垂深
            max_dls_md: maxDlsMd,        // 🔥 最大狗腿度对应的测深
            max_horizontal: maxHorizontal
        }
    }

    // 🔥 修改：生成轨迹图绘制脚本 - 修正坐标方向
    function generateTrajectoryChartScript(trajectoryData, calcInfo) {
        // 计算轨迹路径
        var pathData = calculateTrajectoryPath(trajectoryData)

        return `
        document.addEventListener('DOMContentLoaded', function() {
            try {
                var canvas = document.getElementById('trajectoryChart');
                if (!canvas) {
                    console.error('未找到轨迹图画布');
                    return;
                }

                var ctx = canvas.getContext('2d');
                drawWellTrajectory(ctx, ${JSON.stringify(pathData)}, ${JSON.stringify(calcInfo)});

                console.log('井轨迹图绘制完成');
            } catch (error) {
                console.error('绘制井轨迹图失败:', error);
            }
        });

        function drawWellTrajectory(ctx, pathData, calcInfo) {
            var width = ctx.canvas.width;
            var height = ctx.canvas.height;
            var padding = 60;
            var chartWidth = width - 2 * padding;
            var chartHeight = height - 2 * padding;

            // 清空画布
            ctx.clearRect(0, 0, width, height);

            // 🔥 修正：数据范围处理，确保Y轴从上到下递增
            var maxX = Math.max(...pathData.horizontal, 100);
            var maxY = Math.max(...pathData.tvd, 1000);
            var minX = Math.min(...pathData.horizontal, 0);
            var minY = Math.min(...pathData.tvd, 0);

            // 添加适当的边距
            var xPadding = (maxX - minX) * 0.1;
            var yPadding = (maxY - minY) * 0.1;
            maxX += xPadding;
            maxY += yPadding;
            minX -= xPadding;
            minY -= yPadding;

            // 🔥 修正：坐标转换函数 - Y轴方向修正为从上到下
            function scaleX(x) {
                return padding + (x - minX) / (maxX - minX) * chartWidth;
            }

            function scaleY(y) {
                // 修正：Y轴从上到下，深度增加向下
                return padding + (y - minY) / (maxY - minY) * chartHeight;
            }

            // 绘制网格
            ctx.strokeStyle = '#e0e0e0';
            ctx.lineWidth = 1;

            // 垂直网格线
            for (var i = 0; i <= 10; i++) {
                var x = padding + (chartWidth / 10) * i;
                ctx.beginPath();
                ctx.moveTo(x, padding);
                ctx.lineTo(x, height - padding);
                ctx.stroke();
            }

            // 水平网格线
            for (var i = 0; i <= 10; i++) {
                var y = padding + (chartHeight / 10) * i;
                ctx.beginPath();
                ctx.moveTo(padding, y);
                ctx.lineTo(width - padding, y);
                ctx.stroke();
            }

            // 绘制坐标轴
            ctx.strokeStyle = '#333';
            ctx.lineWidth = 2;

            // 🔥 修正：X轴在顶部
            ctx.beginPath();
            ctx.moveTo(padding, padding);
            ctx.lineTo(width - padding, padding);
            ctx.stroke();

            // 🔥 修正：Y轴在左侧
            ctx.beginPath();
            ctx.moveTo(padding, padding);
            ctx.lineTo(padding, height - padding);
            ctx.stroke();

            // 🔥 修正：绘制刻度标签
            ctx.fillStyle = '#666';
            ctx.font = '10px Arial';

            // X轴刻度标签（水平位移）
            for (var i = 0; i <= 5; i++) {
                var x = padding + (chartWidth / 5) * i;
                var value = minX + (maxX - minX) * i / 5;
                ctx.fillText(value.toFixed(0), x - 10, padding - 5);
            }

            // Y轴刻度标签（垂深）
            for (var i = 0; i <= 5; i++) {
                var y = padding + (chartHeight / 5) * i;
                var value = minY + (maxY - minY) * i / 5;
                ctx.fillText(value.toFixed(0), padding - 35, y + 3);
            }

            // 绘制轨迹线
            if (pathData.horizontal.length > 1) {
                ctx.strokeStyle = '#4ECDC4';
                ctx.lineWidth = 3;
                ctx.beginPath();

                for (var i = 0; i < pathData.horizontal.length; i++) {
                    var x = scaleX(pathData.horizontal[i]);
                    var y = scaleY(pathData.tvd[i]);

                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.stroke();

                // 🔥 新增：绘制轨迹点
                ctx.fillStyle = '#4ECDC4';
                for (var i = 0; i < pathData.horizontal.length; i++) {
                    var x = scaleX(pathData.horizontal[i]);
                    var y = scaleY(pathData.tvd[i]);

                    ctx.beginPath();
                    ctx.arc(x, y, 2, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }

            // 🔥 修正：绘制关键点标记
            if (calcInfo.pump_hanging_depth) {
                // 找到对应的水平位移
                var pumpHorizontal = findHorizontalDisplacement(pathData, calcInfo.pump_hanging_depth);
                var pumpX = scaleX(pumpHorizontal);
                var pumpY = scaleY(calcInfo.pump_hanging_depth);

                ctx.fillStyle = '#FF6B6B';
                ctx.beginPath();
                ctx.arc(pumpX, pumpY, 8, 0, 2 * Math.PI);
                ctx.fill();

                // 标签
                ctx.fillStyle = '#333';
                ctx.font = 'bold 12px Arial';
                ctx.fillText('泵挂', pumpX + 12, pumpY - 8);
                ctx.font = '10px Arial';
                ctx.fillText(calcInfo.pump_hanging_depth.toFixed(1) + 'm', pumpX + 12, pumpY + 5);
            }

            if (calcInfo.perforation_depth) {
                var perfHorizontal = findHorizontalDisplacement(pathData, calcInfo.perforation_depth);
                var perfX = scaleX(perfHorizontal);
                var perfY = scaleY(calcInfo.perforation_depth);

                ctx.fillStyle = '#4ECDC4';
                ctx.beginPath();
                ctx.arc(perfX, perfY, 8, 0, 2 * Math.PI);
                ctx.fill();

                ctx.fillStyle = '#333';
                ctx.font = 'bold 12px Arial';
                ctx.fillText('射孔', perfX + 12, perfY - 8);
                ctx.font = '10px Arial';
                ctx.fillText(calcInfo.perforation_depth.toFixed(1) + 'm', perfX + 12, perfY + 5);
            }

            // 🔥 修正：绘制标题和坐标轴标签
            ctx.fillStyle = '#333';
            ctx.font = 'bold 16px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('井轨迹剖面图', width / 2, 25);

            // X轴标签
            ctx.font = '14px Arial';
            ctx.fillText('水平位移 (m)', width / 2, height - 15);

            // Y轴标签
            ctx.save();
            ctx.translate(20, height / 2);
            ctx.rotate(-Math.PI / 2);
            ctx.textAlign = 'center';
            ctx.fillText('垂深 (m)', 0, 0);
            ctx.restore();

            // 重置文本对齐
            ctx.textAlign = 'left';
        }

        // 🔥 新增：根据垂深查找对应的水平位移
        function findHorizontalDisplacement(pathData, targetDepth) {
            if (!pathData.tvd || pathData.tvd.length === 0) return 0;

            // 找到最接近目标深度的点
            var closestIndex = 0;
            var minDiff = Math.abs(pathData.tvd[0] - targetDepth);

            for (var i = 1; i < pathData.tvd.length; i++) {
                var diff = Math.abs(pathData.tvd[i] - targetDepth);
                if (diff < minDiff) {
                    minDiff = diff;
                    closestIndex = i;
                }
            }

            return pathData.horizontal[closestIndex] || 0;
        }
        `
    }

    // 🔥 新增：计算轨迹路径
    function calculateTrajectoryPath(trajectoryData) {
        if (!trajectoryData || trajectoryData.length === 0) {
            return { horizontal: [], tvd: [] }
        }

        var horizontal = []
        var tvd = []
        var cumHorizontal = 0

        for (var i = 0; i < trajectoryData.length; i++) {
            var data = trajectoryData[i]
            var currentTvd = data.tvd || 0
            var currentMd = data.md || 0

            // 计算水平位移
            if (i > 0) {
                var prevTvd = trajectoryData[i-1].tvd || 0
                var prevMd = trajectoryData[i-1].md || 0

                var deltaMd = currentMd - prevMd
                var deltaTvd = currentTvd - prevTvd

                // 使用勾股定理计算水平增量
                var deltaHorizontal = Math.sqrt(Math.max(0, deltaMd * deltaMd - deltaTvd * deltaTvd))
                cumHorizontal += deltaHorizontal
            }

            horizontal.push(cumHorizontal)
            tvd.push(currentTvd)
        }

        return { horizontal: horizontal, tvd: tvd }
    }

    // 🔥 新增：生成泵性能曲线部分
    function generatePumpPerformanceSection() {
        var pumpCurvesData = stepData.pump_curves || {}
        var pumpInfo = stepData.pump || {}

        console.log("🔧 生成泵性能曲线，数据:", JSON.stringify(pumpCurvesData))

        if (!pumpCurvesData.has_data || !pumpCurvesData.baseCurves) {
            return `
            <div style="background: #f8f9fa; border: 2px dashed #dee2e6; height: 400px; display: flex; align-items: center; justify-content: center; margin: 20px 0; color: #6c757d; font-style: italic; border-radius: 8px;">
                <div style="text-align: center;">
                    <p style="font-size: 18px; margin: 0;">📈 泵性能曲线图</p>
                    <p style="font-size: 14px; margin: 8px 0 0 0;">暂无性能曲线数据</p>
                    <p style="font-size: 12px; color: #999; margin: 4px 0 0 0;">需要选择泵设备来生成性能曲线</p>
                </div>
            </div>
            `
        }

        return `
        <div style="width: 100%; margin: 20px 0;">
            <!-- 泵基本信息 -->
            <h4>泵设备信息</h4>
            <table style="margin-bottom: 20px;">
                <tr>
                    <td style="font-weight: bold;">制造商</td>
                    <td>${pumpCurvesData.pump_info?.manufacturer || pumpInfo.manufacturer || 'N/A'}</td>
                    <td style="font-weight: bold;">型号</td>
                    <td>${pumpCurvesData.pump_info?.model || pumpInfo.model || 'N/A'}</td>
                </tr>
                <tr>
                    <td style="font-weight: bold;">级数</td>
                    <td>${pumpCurvesData.pump_info?.stages || pumpInfo.stages || 'N/A'}</td>
                    <td style="font-weight: bold;">外径</td>
                    <td>${pumpCurvesData.pump_info?.outside_diameter || pumpInfo.outsideDiameter || 'N/A'} in</td>
                </tr>
            </table>

            <!-- 性能曲线图表 -->
            <div style="text-align: center; margin-bottom: 20px;">
                <canvas id="pumpPerformanceChart" width="800" height="600"
                        style="border: 1px solid #ddd; background: #fff; display: block; margin: 0 auto; max-width: 100%; box-shadow: 0 2px 4px rgba(0,0,0,0.1);"></canvas>
                <p style="font-size: 12px; color: #666; margin-top: 10px;">
                    泵性能特性曲线（扬程-效率-功率 vs 流量）
                </p>
            </div>

            <!-- 性能参数表格 -->
            ${generatePumpPerformanceTable(pumpCurvesData)}

            <script>
                ${generatePumpPerformanceChartScript(pumpCurvesData)}
            </script>
        </div>
        `
    }

    // 🔥 修复：生成泵性能参数表格 - 使用正确的单位转换
    function generatePumpPerformanceTable(curvesData) {
        if (!curvesData.baseCurves) return ''

        var curves = curvesData.baseCurves
        var operatingPoint = curvesData.operatingPoints?.[0] || {}

        // 计算关键性能指标
        var maxEfficiency = Math.max(...curves.efficiency)
        var maxHead = Math.max(...curves.head)
        var maxPower = Math.max(...curves.power)
        var minFlow = Math.min(...curves.flow)
        var maxFlow = Math.max(...curves.flow)

        // 🔥 使用单位转换函数格式化数值
        var formattedMinFlow = formatFlowValue(minFlow, false)
        var formattedMaxFlow = formatFlowValue(maxFlow)
        var formattedMaxHead = formatDepthValue(maxHead)  // 扬程使用深度单位
        var formattedMaxPower = formatPowerValue(maxPower, false)
        var formattedOperatingFlow = operatingPoint.flow ? formatFlowValue(operatingPoint.flow) : 'N/A'
        var formattedOperatingHead = operatingPoint.head ? formatDepthValue(operatingPoint.head) : 'N/A'
        var formattedOperatingPower = operatingPoint.power ? formatPowerValue(operatingPoint.power, false) : 'N/A'

        return `
        <h4>性能参数汇总</h4>
        <table style="margin-top: 15px;">
            <thead>
                <tr style="background-color: #f5f7fa;">
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">参数项目</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">数值</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">参数项目</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">数值</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">流量范围</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${formattedMinFlow} - ${formattedMaxFlow}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最大扬程</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${formattedMaxHead}</td>
                </tr>
                <tr style="background-color: #fafafa;">
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最高效率</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #4CAF50;">${maxEfficiency.toFixed(1)} %</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最大功率</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${formattedMaxPower} ${getDisplayPowerUnit()}</td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最优工况流量</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #FF6B6B;">${formattedOperatingFlow}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最优工况扬程</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #FF6B6B;">${formattedOperatingHead}</td>
                </tr>
                <tr style="background-color: #f0f8ff;">
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最优工况效率</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold; color: #4CAF50;">${operatingPoint.efficiency?.toFixed(1) || 'N/A'} %</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">最优工况功率</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">${formattedOperatingPower} ${getDisplayPowerUnit()}</td>
                </tr>
            </tbody>
        </table>

        <div style="margin-top: 15px; padding: 12px; background-color: #e8f4fd; border-left: 4px solid #2196F3; border-radius: 4px;">
            <p style="margin: 0; font-size: 12px; color: #1976D2;">
                <strong>💡 性能说明：</strong>本性能曲线基于${curvesData.pump_info?.stages || 87}级泵的设计参数生成。
                实际运行时应在最优效率点附近工作以获得最佳能耗比和设备寿命。
            </p>
        </div>
        `
    }

    // 🔥 新增：生成泵性能曲线绘制脚本
    function generatePumpPerformanceChartScript(curvesData) {
        return `
        document.addEventListener('DOMContentLoaded', function() {
            try {
                var canvas = document.getElementById('pumpPerformanceChart');
                if (!canvas) {
                    console.error('未找到泵性能曲线画布');
                    return;
                }

                var ctx = canvas.getContext('2d');
                drawPumpPerformanceCurves(ctx, ${JSON.stringify(curvesData)});

                console.log('泵性能曲线绘制完成');
            } catch (error) {
                console.error('绘制泵性能曲线失败:', error);
            }
        });

        function drawPumpPerformanceCurves(ctx, data) {
            var width = ctx.canvas.width;
            var height = ctx.canvas.height;
            var padding = 80;
            var chartWidth = width - 2 * padding;
            var chartHeight = height - 2 * padding;

            // 清空画布
            ctx.clearRect(0, 0, width, height);

            // 设置背景
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, width, height);

            if (!data.baseCurves) {
                ctx.fillStyle = '#666';
                ctx.font = '16px Arial';
                ctx.textAlign = 'center';
                ctx.fillText('暂无性能曲线数据', width / 2, height / 2);
                return;
            }

            var curves = data.baseCurves;
            var flows = curves.flow;
            var heads = curves.head;
            var efficiencies = curves.efficiency;
            var powers = curves.power;

            // 🔥 计算数据范围
            var minFlow = Math.min(...flows);
            var maxFlow = Math.max(...flows);
            var minHead = Math.min(...heads);
            var maxHead = Math.max(...heads);
            var maxEfficiency = Math.max(...efficiencies);
            var maxPower = Math.max(...powers);

            // 添加边距
            var flowRange = maxFlow - minFlow;
            var headRange = maxHead - minHead;

            minFlow = Math.max(0, minFlow - flowRange * 0.05);
            maxFlow = maxFlow + flowRange * 0.05;
            minHead = Math.max(0, minHead - headRange * 0.05);
            maxHead = maxHead + headRange * 0.05;

            // 坐标转换函数
            function scaleX(flow) {
                return padding + (flow - minFlow) / (maxFlow - minFlow) * chartWidth;
            }

            function scaleYHead(head) {
                return padding + chartHeight - (head - minHead) / (maxHead - minHead) * chartHeight;
            }

            function scaleYEfficiency(efficiency) {
                return padding + chartHeight - (efficiency / 100) * chartHeight;
            }

            function scaleYPower(power) {
                return padding + chartHeight - (power / maxPower) * chartHeight;
            }

            // 🔥 绘制网格
            ctx.strokeStyle = '#e0e0e0';
            ctx.lineWidth = 1;

            // 垂直网格线
            for (var i = 0; i <= 10; i++) {
                var x = padding + (chartWidth / 10) * i;
                ctx.beginPath();
                ctx.moveTo(x, padding);
                ctx.lineTo(x, height - padding);
                ctx.stroke();
            }

            // 水平网格线
            for (var i = 0; i <= 10; i++) {
                var y = padding + (chartHeight / 10) * i;
                ctx.beginPath();
                ctx.moveTo(padding, y);
                ctx.lineTo(width - padding, y);
                ctx.stroke();
            }

            // 🔥 绘制坐标轴
            ctx.strokeStyle = '#333';
            ctx.lineWidth = 2;

            // X轴
            ctx.beginPath();
            ctx.moveTo(padding, height - padding);
            ctx.lineTo(width - padding, height - padding);
            ctx.stroke();

            // Y轴
            ctx.beginPath();
            ctx.moveTo(padding, padding);
            ctx.lineTo(padding, height - padding);
            ctx.stroke();

            // 🔥 绘制扬程曲线
            ctx.strokeStyle = '#2196F3';
            ctx.lineWidth = 3;
            ctx.beginPath();
            for (var i = 0; i < flows.length; i++) {
                var x = scaleX(flows[i]);
                var y = scaleYHead(heads[i]);
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();

            // 🔥 绘制效率曲线
            ctx.strokeStyle = '#4CAF50';
            ctx.lineWidth = 3;
            ctx.beginPath();
            for (var i = 0; i < flows.length; i++) {
                var x = scaleX(flows[i]);
                var y = scaleYEfficiency(efficiencies[i]);
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();

            // 🔥 绘制功率曲线
            ctx.strokeStyle = '#FF9800';
            ctx.lineWidth = 3;
            ctx.beginPath();
            for (var i = 0; i < flows.length; i++) {
                var x = scaleX(flows[i]);
                var y = scaleYPower(powers[i]);
                if (i === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();

            // 🔥 绘制最优工况点
            if (data.operatingPoints && data.operatingPoints.length > 0) {
                var bep = data.operatingPoints[0];
                var bepX = scaleX(bep.flow);
                var bepYHead = scaleYHead(bep.head);

                ctx.fillStyle = '#E91E63';
                ctx.beginPath();
                ctx.arc(bepX, bepYHead, 8, 0, 2 * Math.PI);
                ctx.fill();

                // BEP标签
                ctx.fillStyle = '#333';
                ctx.font = 'bold 12px Arial';
                ctx.textAlign = 'left';
                ctx.fillText('BEP', bepX + 12, bepYHead - 8);
                ctx.font = '10px Arial';
                ctx.fillText(bep.flow.toFixed(0) + ' bbl/d', bepX + 12, bepYHead + 5);
                ctx.fillText(bep.head.toFixed(0) + ' ft', bepX + 12, bepYHead + 17);
            }

            // 🔥 绘制坐标轴标签
            ctx.fillStyle = '#666';
            ctx.font = '12px Arial';
            ctx.textAlign = 'center';

            // X轴刻度和标签
            for (var i = 0; i <= 5; i++) {
                var x = padding + (chartWidth / 5) * i;
                var value = minFlow + (maxFlow - minFlow) * i / 5;
                ctx.fillText(value.toFixed(0), x, height - padding + 20);
            }

            // Y轴刻度标签（扬程）
            ctx.textAlign = 'right';
            ctx.fillStyle = '#2196F3';
            for (var i = 0; i <= 5; i++) {
                var y = height - padding - (chartHeight / 5) * i;
                var value = minHead + (maxHead - minHead) * i / 5;
                ctx.fillText(value.toFixed(0), padding - 10, y + 4);
            }

            // Y轴右侧标签（效率）
            ctx.textAlign = 'left';
            ctx.fillStyle = '#4CAF50';
            for (var i = 0; i <= 5; i++) {
                var y = height - padding - (chartHeight / 5) * i;
                var value = (100 / 5) * i;
                ctx.fillText(value.toFixed(0) + '%', width - padding + 10, y + 4);
            }

            // 🔥 绘制标题和轴标签
            ctx.fillStyle = '#333';
            ctx.font = 'bold 16px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('泵性能特性曲线', width / 2, 30);

            // X轴标签
            ctx.font = '14px Arial';
            ctx.fillText('流量 (bbl/d)', width / 2, height - 15);

            // Y轴标签
            ctx.save();
            ctx.translate(25, height / 2);
            ctx.rotate(-Math.PI / 2);
            ctx.textAlign = 'center';
            ctx.fillStyle = '#2196F3';
            ctx.fillText('扬程 (ft)', 0, 0);
            ctx.restore();

            // 右Y轴标签
            ctx.save();
            ctx.translate(width - 25, height / 2);
            ctx.rotate(Math.PI / 2);
            ctx.textAlign = 'center';
            ctx.fillStyle = '#4CAF50';
            ctx.fillText('效率 (%)', 0, 0);
            ctx.restore();

            // 🔥 绘制图例
            var legendY = padding + 20;
            var legendSpacing = 120;

            // 扬程图例
            ctx.strokeStyle = '#2196F3';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(width - 200, legendY);
            ctx.lineTo(width - 170, legendY);
            ctx.stroke();
            ctx.fillStyle = '#333';
            ctx.font = '12px Arial';
            ctx.textAlign = 'left';
            ctx.fillText('扬程', width - 165, legendY + 4);

            // 效率图例
            ctx.strokeStyle = '#4CAF50';
            ctx.beginPath();
            ctx.moveTo(width - 200, legendY + 20);
            ctx.lineTo(width - 170, legendY + 20);
            ctx.stroke();
            ctx.fillText('效率', width - 165, legendY + 24);

            // 功率图例
            ctx.strokeStyle = '#FF9800';
            ctx.beginPath();
            ctx.moveTo(width - 200, legendY + 40);
            ctx.lineTo(width - 170, legendY + 40);
            ctx.stroke();
            ctx.fillText('功率', width - 165, legendY + 44);

            // BEP图例
            ctx.fillStyle = '#E91E63';
            ctx.beginPath();
            ctx.arc(width - 185, legendY + 60, 6, 0, 2 * Math.PI);
            ctx.fill();
            ctx.fillStyle = '#333';
            ctx.fillText('最优工况点', width - 165, legendY + 64);
        }
        `
    }

        // 🔥 修复：生成工况点分析 - 使用正确的单位转换
    function generateOperatingPointAnalysis() {
        var pumpCurvesData = stepData.pump_curves || {}
        var finalValues = stepData.prediction?.finalValues || {}

        if (!pumpCurvesData.has_data) {
            return `<p>暂无工况点分析数据</p>`
        }

        var operatingPoint = pumpCurvesData.operatingPoints?.[0] || {}
        var targetFlow = finalValues.production || 0
        var targetHead = finalValues.totalHead || 0

        // 🔥 使用单位转换函数格式化数值
        var formattedTargetFlow = formatFlowValue(targetFlow)
        var formattedTargetHead = formatDepthValue(targetHead)  // 扬程使用深度单位
        var formattedOperatingFlow = operatingPoint.flow ? formatFlowValue(operatingPoint.flow) : 'N/A'
        var formattedOperatingHead = operatingPoint.head ? formatDepthValue(operatingPoint.head) : 'N/A'

        return `
        <table style="margin-top: 15px;">
            <thead>
                <tr style="background-color: #f5f7fa;">
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">工况参数</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">设计值</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">最优值</th>
                    <th style="padding: 12px; border: 1px solid #e0e0e0; color: #1e3a5f; font-weight: 600;">匹配度</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">产量</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">${formattedTargetFlow}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">${formattedOperatingFlow}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; color: ${getMatchingColor(targetFlow, operatingPoint.flow)};">
                        ${getMatchingPercentage(targetFlow, operatingPoint.flow)}
                    </td>
                </tr>
                <tr style="background-color: #fafafa;">
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">扬程</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">${formattedTargetHead}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">${formattedOperatingHead}</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; color: ${getMatchingColor(targetHead, operatingPoint.head)};">
                        ${getMatchingPercentage(targetHead, operatingPoint.head)}
                    </td>
                </tr>
                <tr>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; font-weight: bold;">效率</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">预估 75%</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0;">${operatingPoint.efficiency?.toFixed(1) || 'N/A'} %</td>
                    <td style="padding: 10px; border: 1px solid #e0e0e0; color: #4CAF50;">良好</td>
                </tr>
            </tbody>
        </table>

        <div style="margin-top: 15px; padding: 12px; background-color: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px;">
            <p style="margin: 0; font-size: 12px; color: #856404;">
                <strong>⚠️ 工况匹配建议：</strong>
                ${generateMatchingRecommendation(targetFlow, operatingPoint.flow, targetHead, operatingPoint.head)}
            </p>
        </div>
        `
    }

    // 辅助函数
    function getMatchingColor(actual, optimal) {
        if (!actual || !optimal) return '#999'
        var ratio = Math.abs(actual - optimal) / optimal
        if (ratio < 0.1) return '#4CAF50'
        if (ratio < 0.2) return '#FF9800'
        return '#F44336'
    }

    function getMatchingPercentage(actual, optimal) {
        if (!actual || !optimal) return 'N/A'
        var ratio = Math.abs(actual - optimal) / optimal
        var percentage = Math.max(0, 100 - ratio * 100)
        return percentage.toFixed(0) + '%'
    }

    function generateMatchingRecommendation(actualFlow, optimalFlow, actualHead, optimalHead) {
        var flowMatch = actualFlow && optimalFlow ? Math.abs(actualFlow - optimalFlow) / optimalFlow : 1
        var headMatch = actualHead && optimalHead ? Math.abs(actualHead - optimalHead) / optimalHead : 1

        if (flowMatch < 0.1 && headMatch < 0.1) {
            return '当前泵选型与工况需求匹配度很高，建议采用。'
        } else if (flowMatch < 0.2 && headMatch < 0.2) {
            return '当前泵选型基本满足工况需求，可以采用但建议优化运行参数。'
        } else {
            return '当前泵选型与工况需求匹配度较低，建议重新选择更适合的泵型或调整级数。'
        }
    }

}
