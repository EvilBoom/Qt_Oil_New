// Qt_Oil_NewContent/DeviceRecommendation/Steps/Step7_MotorSelection.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts
import "../Components" as LocalComponents

Rectangle {
    id: root
    
    // 外部属性
    property var controller: null
    property bool isChineseMode: true
    property int wellId: -1
    property var stepData: ({})
    property var constraints: ({})
    
    // 信号
    signal nextStepRequested()
    signal dataChanged(var data)
    
    // 内部属性
    property var selectedMotor: null
    property var availableMotors: []
    property bool loading: false
    property int selectedVoltage: 3300  // 默认电压
    property int selectedFrequency: 60  // 默认频率 Hz
    // 🔥 添加井身结构数据属性
    property var wellStructureData: null
    property real productionCasingInnerDiameter: 0  // 生产套管内径

    
    // 添加计算属性 - 当依赖项变化时自动重新计算
    property var filteredMotors: {
        console.log("🔍 filteredMotors计算属性被触发")
        console.log("🔍 availableMotors:", availableMotors ? availableMotors.length : "null", "个")
        console.log("🔍 selectedVoltage:", selectedVoltage)
        console.log("🔍 selectedFrequency:", selectedFrequency)
        console.log("🔍 requiredPower:", requiredPower)

        var result = getFilteredMotorsInternal()
        console.log("🔍 filteredMotors计算结果:", result ? result.length : "null", "个")

        return result
    }
    // 同时添加一个监听器
    onFilteredMotorsChanged: {
        console.log("📢 filteredMotors发生变化，新长度:", filteredMotors ? filteredMotors.length : "null")
        if (filteredMotors && filteredMotors.length > 0) {
            console.log("📢 第一个过滤后的电机:", JSON.stringify(filteredMotors[0], null, 2))
        }
    }

    // 计算所需功率
    property real requiredPower: {
        if (stepData.pump) {
            var totalPower = stepData.pump.totalPower || 100
            // 考虑效率损失，预留20%余量
            return totalPower * 1.2
        }
        return 50  // 默认值 HP
    }
    
    // 轴径要求
    property real requiredShaftDiameter: stepData.pump ? stepData.pump.shaftDiameter : 1.0
    
    color: "transparent"
    
    // 🔥 修复重复加载问题
    Component.onCompleted: {
        console.log("Step7电机选择页面加载完成")
        console.log("Controller:", controller)

        // 🔥 加载井身结构数据
        loadWellStructureData()

        // 🔥 避免重复加载：先检查是否已有数据
        if (availableMotors && availableMotors.length > 0) {
            console.log("⚡ 已有电机数据，跳过重复加载")
            return
        }

        // 尝试直接使用全局控制器
        if (typeof deviceRecommendationController !== "undefined" && deviceRecommendationController !== null) {
            console.log("使用全局 deviceRecommendationController")
            controller = deviceRecommendationController
        }

        loadMotors()
    }
    // 🔥 添加加载井身结构数据的函数
    function loadWellStructureData() {
        console.log("🏗️ 开始加载井身结构数据，井ID:", wellId)

        if (wellId <= 0) {
            console.warn("⚠️ 井ID无效，使用默认套管尺寸")
            productionCasingInnerDiameter = 6.184  // 7" 套管内径默认值
            return
        }

        // 使用井身结构控制器加载套管数据
        if (typeof wellStructureController !== "undefined" && wellStructureController !== null) {
            try {
                console.log("✅ 找到井身结构控制器，加载套管数据")

                // 连接信号
                wellStructureController.casingDataLoaded.connect(onCasingDataLoaded)

                // 加载套管数据
                wellStructureController.loadCasingData(wellId)

            } catch (error) {
                console.error("❌ 加载井身结构数据失败:", error)
                productionCasingInnerDiameter = 6.184  // 使用默认值
            }
        } else {
            console.warn("⚠️ 井身结构控制器不可用，使用默认套管尺寸")
            productionCasingInnerDiameter = 6.184  // 使用默认值
        }
    }

    // 🔥 修复套管数据加载完成的处理函数
    function onCasingDataLoaded(casingData) {
        console.log("📦 套管数据加载完成:", casingData.length, "个套管")

        // 找到生产套管
        var productionCasing = null
        for (var i = 0; i < casingData.length; i++) {
            var casing = casingData[i]
            console.log(`套管 ${i+1}: 类型=${casing.casing_type}, 内径=${casing.inner_diameter} (原始数据)`)

            if (casing.casing_type === "production") {
                productionCasing = casing
                break
            }
        }

        if (productionCasing) {
            var innerDiameterMm = parseFloat(productionCasing.inner_diameter)
            // 🔥 检查数据单位并进行转换
            if (innerDiameterMm > 50) {
                // 数据看起来是毫米单位，需要转换为英寸
                productionCasingInnerDiameter = mmToInches(innerDiameterMm)
                console.log("✅ 找到生产套管，内径:", innerDiameterMm, "mm →", productionCasingInnerDiameter.toFixed(2), "英寸")
            } else {
                // 数据已经是英寸单位
                productionCasingInnerDiameter = innerDiameterMm
                console.log("✅ 找到生产套管，内径:", productionCasingInnerDiameter, "英寸 (已是英寸单位)")
            }
        } else {
            // 如果没有找到生产套管，使用最小的套管内径
            var minInnerDiameter = Number.MAX_VALUE
            var minInnerDiameterMm = Number.MAX_VALUE

            for (var j = 0; j < casingData.length; j++) {
                var diameterValue = parseFloat(casingData[j].inner_diameter)
                if (diameterValue > 0) {
                    if (diameterValue > 50) {
                        // 毫米单位
                        var diameterInches = mmToInches(diameterValue)
                        if (diameterInches < minInnerDiameter) {
                            minInnerDiameter = diameterInches
                            minInnerDiameterMm = diameterValue
                        }
                    } else {
                        // 英寸单位
                        if (diameterValue < minInnerDiameter) {
                            minInnerDiameter = diameterValue
                            minInnerDiameterMm = inchesToMm(diameterValue)
                        }
                    }
                }
            }

            if (minInnerDiameter < Number.MAX_VALUE) {
                productionCasingInnerDiameter = minInnerDiameter
                console.log("⚠️ 未找到生产套管，使用最小套管内径:", minInnerDiameterMm.toFixed(1), "mm →", productionCasingInnerDiameter.toFixed(2), "英寸")
            } else {
                productionCasingInnerDiameter = 6.184  // 7" 套管默认内径
                console.log("⚠️ 没有有效套管数据，使用默认内径:", productionCasingInnerDiameter, "英寸")
            }
        }

        // 🔥 套管数据更新后重新筛选电机
        console.log("🔄 套管数据更新，重新筛选电机")
        filterMotors()
    }

    // 添加延迟检查，等待控制器可能的延迟加载
    Timer {
        id: controllerCheckTimer
        interval: 100
        repeat: true
        running: true
        triggeredOnStart: false
        
        property int attempts: 0
        
        onTriggered: {
            attempts++
            console.log(`尝试 ${attempts}: Controller =`, controller)
            
            if (controller && controller !== null) {
                console.log("控制器已连接!")
                running = false
                
                // 检查方法
                if (typeof controller.getMotorsByType === "function") {
                    console.log("找到 getMotorsByType 方法")
                } else {
                    console.log("未找到 getMotorsByType 方法")
                    // 列出所有可用方法
                    for (var prop in controller) {
                        if (typeof controller[prop] === "function") {
                            console.log("  可用方法:", prop)
                        }
                    }
                }
                
                // 连接信号
                if (typeof controller.motorsLoaded !== "undefined") {
                    controller.motorsLoaded.connect(onMotorsLoaded)
                }
                if (typeof controller.error !== "undefined") {
                    controller.error.connect(onError)
                }
                
                // 重新加载电机数据
                loadMotors()
            } else if (attempts >= 50) { // 5秒后停止尝试
                console.error("控制器连接超时，使用模拟数据")
                running = false
                loadMotors()
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        
        // 标题栏
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: isChineseMode ? "电机选择" : "Motor Selection"
                font.pixelSize: 20
                font.bold: true
                color: Material.primaryTextColor
            }
            
            Item { Layout.fillWidth: true }
            
            // 电压选择
            ComboBox {
                id: voltageSelector
                Layout.preferredWidth: 120
                model: ["2300V", "3300V", "4160V", "6600V"]
                currentIndex: 1
                onCurrentTextChanged: {
                    selectedVoltage = parseInt(currentText)
                    filterMotors()
                }
            }
            
            // 频率选择
            ComboBox {
                id: frequencySelector
                Layout.preferredWidth: 100
                model: ["50 Hz", "60 Hz"]
                currentIndex: 1
                onCurrentTextChanged: {
                    selectedFrequency = parseInt(currentText)
                    filterMotors()
                }
            }
            // 🔥 添加调试按钮来验证单位转换
            Button {
                text: "🔍 调试套管数据"
                onClicked: {
                    console.log("=== 套管数据调试 ===")
                    console.log("生产套管内径 (英寸):", productionCasingInnerDiameter)
                    console.log("生产套管内径 (毫米):", inchesToMm(productionCasingInnerDiameter))

                    // 测试单位转换
                    console.log("=== 单位转换测试 ===")
                    console.log("157.07 mm →", mmToInches(157.07).toFixed(3), "英寸")
                    console.log("6.18 英寸 →", inchesToMm(6.18).toFixed(1), "mm")
                }
            }
        }
        
        // 电机要求卡片
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: Material.dialogColor
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 24
                
                // 功率要求
                Column {
                    spacing: 4
                    
                    Text {
                        text: isChineseMode ? "功率要求" : "Power Required"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    
                    Row {
                        spacing: 8
                        
                        Text {
                            text: requiredPower.toFixed(0) + " HP"
                            font.pixelSize: 18
                            font.bold: true
                            color: Material.primaryTextColor
                        }
                        
                        Text {
                            text: "(" + (requiredPower * 0.746).toFixed(0) + " kW)"
                            font.pixelSize: 14
                            color: Material.secondaryTextColor
                        }
                    }
                }
                
                Rectangle {
                    width: 1
                    height: 40
                    color: Material.dividerColor
                }
                
                // 温度要求
                Column {
                    spacing: 4
                    
                    Text {
                        text: isChineseMode ? "工作温度" : "Operating Temp"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: (stepData.parameters ? stepData.parameters.bht : "235") + " °F"
                        font.pixelSize: 18
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
                
                Rectangle {
                    width: 1
                    height: 40
                    color: Material.dividerColor
                }
                
                // 轴径匹配
                Column {
                    spacing: 4
                    
                    Text {
                        text: isChineseMode ? "轴径要求" : "Shaft Diameter"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: requiredShaftDiameter + " in"
                        font.pixelSize: 18
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
                
                Rectangle {
                    width: 1
                    height: 40
                    color: Material.dividerColor
                }
                
                // 🔥 更新电机要求卡片中的套管信息显示
                // 🔥 修改套管限制显示部分，显示原始数据和转换后的数据
                Column {
                    spacing: 4

                    Text {
                        text: isChineseMode ? "套管限制" : "Casing Limit"
                        font.pixelSize: 12
                        color: Material.hintTextColor
                    }

                    Text {
                        text: {
                            if (productionCasingInnerDiameter > 0) {
                                var originalMm = inchesToMm(productionCasingInnerDiameter)
                                return productionCasingInnerDiameter.toFixed(2) + " in"
                            } else {
                                return "6.18 in (默认)"
                            }
                        }
                        font.pixelSize: 18
                        font.bold: true
                        color: productionCasingInnerDiameter > 0 ? Material.primaryTextColor : Material.color(Material.Orange)
                    }

                    Text {
                        text: {
                            if (productionCasingInnerDiameter > 0) {
                                var originalMm = inchesToMm(productionCasingInnerDiameter)
                                return "(" + originalMm.toFixed(1) + " mm)"
                            } else {
                                return isChineseMode ? "使用默认" : "Using Default"
                            }
                        }
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                }


                Item { Layout.fillWidth: true }
                
                // 查看对比按钮
                Button {
                    text: isChineseMode ? "性能对比" : "Compare"
                    enabled: getFilteredMotors().length > 1
                    onClicked: showComparisonDialog()
                }
            }
        }
        
        // 主内容区域
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal
            
            // 电机列表
            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 400
                color: "transparent"
                
                ScrollView {
                    anchors.fill: parent
                    clip: true
                    
                    GridLayout {
                        width: parent.width
                        columns: width > 800 ? 2 : 1
                        columnSpacing: 16
                        rowSpacing: 16
                        
                        Repeater {
                            id: motorRepeater
                            // model: getFilteredMotors()
                            model: root.filteredMotors  // 使用计算属性而不是函数调用

                            // 移除调试信息，保留基本的onModelChanged
                            onModelChanged: {
                                console.log("Repeater model发生变化，新长度:", model ? model.length : "undefined")
                            }

                            onCountChanged: {
                                console.log("Repeater count发生变化:", count)
                            }

                            LocalComponents.MotorCard {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 260
                                
                                motorData: modelData
                                isSelected: selectedMotor && selectedMotor.id === modelData.id
                                matchScore: calculateMotorMatchScore(modelData)
                                requiredPower: root.requiredPower
                                selectedVoltage: root.selectedVoltage
                                selectedFrequency: root.selectedFrequency
                                isChineseMode: root.isChineseMode
                                
                                onClicked: {
                                    console.log("电机被选中:", modelData.model)
                                    selectedMotor = modelData
                                    updateStepData()
                                }
                                Component.onCompleted: {
                                    console.log("MotorCard创建完成:", motorData ? motorData.model : "null")
                                }
                            }
                        }
                    }
                    
                    // 空状态
                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        visible: !loading && getFilteredMotors().length === 0
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⚡"
                            font.pixelSize: 48
                            color: Material.hintTextColor
                        }
                        
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isChineseMode ? "没有找到符合条件的电机" : "No motors found matching criteria"
                            color: Material.hintTextColor
                            font.pixelSize: 14
                        }
                    }
                    // // 修改对比按钮
                    // Button {
                    //     text: isChineseMode ? "性能对比" : "Compare"
                    //     enabled: root.filteredMotors.length > 1  // 使用计算属性
                    //     onClicked: showComparisonDialog()
                    // }

                }
                
                // 加载指示器
                BusyIndicator {
                    anchors.centerIn: parent
                    running: loading
                    visible: running
                }
            }
            
            // 修改右侧详情面板，参照Step4的布局结构

            // 右侧详情面板 - 修复布局
            Rectangle {
                SplitView.preferredWidth: 450
                SplitView.minimumWidth: 400
                color: Material.dialogColor
                visible: selectedMotor !== null

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8  // 添加外边距
                    clip: true
                    contentWidth: width  // 确保内容宽度

                    Column {  // 改用Column而不是ColumnLayout
                        width: parent.width
                        spacing: 16
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 8

                        // 电机详情头部
                        Rectangle {
                            width: parent.width
                            height: 120  // 固定高度
                            color: Material.backgroundColor
                            radius: 8

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Row {
                                    width: parent.width
                                    spacing: 16

                                    Column {
                                        width: parent.width - 90
                                        spacing: 4

                                        Text {
                                            text: selectedMotor ? selectedMotor.manufacturer : ""
                                            font.pixelSize: 14
                                            color: Material.secondaryTextColor
                                            wrapMode: Text.Wrap
                                            width: parent.width
                                        }

                                        Text {
                                            text: selectedMotor ? selectedMotor.model : ""
                                            font.pixelSize: 18
                                            font.bold: true
                                            color: Material.primaryTextColor
                                            wrapMode: Text.Wrap
                                            width: parent.width
                                        }

                                        Text {
                                            text: selectedMotor ? selectedMotor.series + " Series" : ""
                                            font.pixelSize: 12
                                            color: Material.hintTextColor
                                            wrapMode: Text.Wrap
                                            width: parent.width
                                        }

                                        Row {
                                            spacing: 8

                                            Rectangle {
                                                width: 60
                                                height: 20
                                                radius: 10
                                                color: Material.color(Material.Blue)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: selectedMotor ? selectedMotor.power + " HP" : ""
                                                    color: "white"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }

                                            Rectangle {
                                                width: 60
                                                height: 20
                                                radius: 10
                                                color: Material.color(Material.Purple)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: selectedVoltage + "V"
                                                    color: "white"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }

                                    // 匹配度指示器
                                    LocalComponents.CircularProgress {
                                        width: 70
                                        height: 70
                                        value: selectedMotor ? calculateMotorMatchScore(selectedMotor) / 100 : 0

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 2

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: selectedMotor ? calculateMotorMatchScore(selectedMotor) + "%" : "0%"
                                                font.pixelSize: 16
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: isChineseMode ? "匹配度" : "Match"
                                                font.pixelSize: 10
                                                color: Material.hintTextColor
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 电气参数卡片
                        Rectangle {
                            width: parent.width
                            height: 180  // 固定高度
                            color: Material.backgroundColor
                            radius: 8

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    text: isChineseMode ? "电气参数" : "Electrical Parameters"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Material.dividerColor
                                }

                                Grid {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 20
                                    rowSpacing: 8
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    // 额定功率
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "额定功率" : "Rated Power"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? selectedMotor.power : 0) + " HP"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 额定电压
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "额定电压" : "Rated Voltage"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedVoltage + " V"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 额定电流
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "额定电流" : "Rated Current"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? getMotorCurrent() : 0) + " A"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 同步转速
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "同步转速" : "Sync Speed"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? getMotorSpeed() : 0) + " RPM"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }
                                }
                            }
                        }

                        // 性能指标卡片
                        Rectangle {
                            width: parent.width
                            height: 150  // 固定高度
                            color: Material.backgroundColor
                            radius: 8

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    text: isChineseMode ? "性能指标" : "Performance Metrics"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Material.dividerColor
                                }

                                Grid {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 20
                                    rowSpacing: 8

                                    // 效率
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "效率" : "Efficiency"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Row {
                                            spacing: 6
                                            Text {
                                                text: (selectedMotor ? selectedMotor.efficiency : 0) + "%"
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: Material.primaryTextColor
                                            }
                                            Text {
                                                text: getEfficiencyRating()
                                                font.pixelSize: 10
                                                color: Material.color(Material.Green)
                                            }
                                        }
                                    }

                                    // 功率因数
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "功率因数" : "Power Factor"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedMotor ? selectedMotor.powerFactor : "0.85"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 绝缘等级
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "绝缘等级" : "Insulation Class"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? selectedMotor.insulationClass : "") + " " + (isChineseMode ? "级" : "Class")
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 防护等级
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "防护等级" : "Protection"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: selectedMotor ? selectedMotor.protectionClass : ""
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }
                                }
                            }
                        }

                        // 物理参数卡片
                        Rectangle {
                            width: parent.width
                            height: 130  // 固定高度
                            color: Material.backgroundColor
                            radius: 8

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    text: isChineseMode ? "物理参数" : "Physical Parameters"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Material.primaryTextColor
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Material.dividerColor
                                }

                                Grid {
                                    width: parent.width
                                    columns: 2
                                    columnSpacing: 20
                                    rowSpacing: 8

                                    // 外径
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "外径" : "Outer Diameter"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? selectedMotor.outerDiameter : 0) + " in"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 长度
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "长度" : "Length"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? selectedMotor.length : 0) + " ft"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 重量
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "重量" : "Weight"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: (selectedMotor ? selectedMotor.weight : 0) + " lbs"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Material.primaryTextColor
                                        }
                                    }

                                    // 轴径兼容性
                                    Column {
                                        spacing: 2
                                        Text {
                                            text: isChineseMode ? "轴径兼容" : "Shaft Compatible"
                                            font.pixelSize: 11
                                            color: Material.secondaryTextColor
                                        }
                                        Text {
                                            text: checkShaftCompatibility()
                                                  ? (isChineseMode ? "✓ 兼容" : "✓ Compatible")
                                                  : (isChineseMode ? "✗ 不兼容" : "✗ Incompatible")
                                            color: checkShaftCompatibility()
                                                   ? Material.color(Material.Green)
                                                   : Material.color(Material.Red)
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }

                        // 性能曲线按钮
                        Rectangle {
                            width: parent.width
                            height: 60
                            color: Material.backgroundColor
                            radius: 8

                            Button {
                                anchors.centerIn: parent
                                text: isChineseMode ? "⚡ 查看效率曲线" : "⚡ View Efficiency Curve"
                                Material.background: "#FF9800"
                                Material.foreground: "white"
                                enabled: selectedMotor !== null

                                onClicked: {
                                    // 更新图表数据并打开
                                    motorEfficiencyChart.updateChart(selectedMotor, requiredPower, selectedFrequency)
                                    motorEfficiencyChart.open()
                                }
                            }
                        }

                        // 底部间距
                        Item {
                            width: parent.width
                            height: 20
                        }
                    }
                }
            }
        }
    }

    // 修复 loadMotors 函数
    function loadMotors() {
        // 🔥 防止重复加载
        if (loading) {
            console.log("⚠️ 正在加载中，跳过重复请求")
            return
        }

        loading = true
        console.log("🔄 开始加载电机数据")

        if (controller) {
            console.log("✅ 控制器已连接，尝试加载电机数据")

            // 检查控制器是否有 getMotorsByType 方法
            if (typeof controller.getMotorsByType === "function") {
                try {
                    var motors = controller.getMotorsByType()
                    if (motors && motors.length > 0) {
                        availableMotors = motors
                        console.log("✅ 从控制器加载电机数据成功:", motors.length, "个")
                    } else {
                        console.warn("⚠️ 控制器返回空数据，使用模拟数据")
                        availableMotors = generateMockMotorData()
                    }
                } catch (error) {
                    console.error("❌ 调用控制器失败:", error, "使用模拟数据")
                    availableMotors = generateMockMotorData()
                }
            } else {
                console.warn("⚠️ 控制器没有 getMotorsByType 方法，使用模拟数据")
                availableMotors = generateMockMotorData()
            }
        } else {
            console.warn("⚠️ Controller未连接，使用模拟数据")
            availableMotors = generateMockMotorData()
        }

        loading = false
        console.log("🎯 电机数据加载完成，共", availableMotors.length, "个")
    }

    // 添加信号处理函数
    function onMotorsLoaded(motors) {
        console.log("接收到电机数据:", motors.length, "个")
        availableMotors = motors
        loading = false
    }

    function onError(errorMessage) {
        console.error("加载电机数据错误:", errorMessage)
        loading = false
        // 使用备用数据
        availableMotors = generateMockMotorData()
    }

    
    function generateMockMotorData() {
        return [
            {
                id: 1,
                manufacturer: "Baker Hughes",
                model: "Electrospeed 3",
                series: "ES3",
                power: 150,
                voltage: [2300, 3300, 4160],
                frequency: [50, 60],
                efficiency: 93.5,
                powerFactor: 0.88,
                insulationClass: "H",
                protectionClass: "IP68",
                outerDiameter: 4.56,
                length: 25,
                weight: 850,
                speed_60hz: 3600,
                speed_50hz: 3000,
                current_3300v_60hz: 30,
                temperatureRise: 80
            },
            {
                id: 2,
                manufacturer: "Schlumberger",
                model: "REDA Hotline",
                series: "HT",
                power: 200,
                voltage: [3300, 4160, 6600],
                frequency: [50, 60],
                efficiency: 94.2,
                powerFactor: 0.89,
                insulationClass: "N",
                protectionClass: "IP68",
                outerDiameter: 5.12,
                length: 28,
                weight: 980,
                speed_60hz: 3600,
                speed_50hz: 3000,
                current_3300v_60hz: 38,
                temperatureRise: 75
            },
            {
                id: 3,
                manufacturer: "Weatherford",
                model: "Magnus ESP",
                series: "MG",
                power: 125,
                voltage: [2300, 3300],
                frequency: [50, 60],
                efficiency: 92.8,
                powerFactor: 0.87,
                insulationClass: "F",
                protectionClass: "IP68",
                outerDiameter: 4.0,
                length: 22,
                weight: 720,
                speed_60hz: 3600,
                speed_50hz: 3000,
                current_3300v_60hz: 25,
                temperatureRise: 85
            },
            {
                id: 4,
                manufacturer: "Borets",
                model: "PM-750",
                series: "PM",
                power: 100,
                voltage: [2300, 3300, 4160],
                frequency: [50, 60],
                efficiency: 91.5,
                powerFactor: 0.86,
                insulationClass: "H",
                protectionClass: "IP68",
                outerDiameter: 3.75,
                length: 20,
                weight: 650,
                speed_60hz: 3600,
                speed_50hz: 3000,
                current_3300v_60hz: 20,
                temperatureRise: 80
            }
        ]
    }
    
    // 🔥 监听井ID变化，重新加载井身结构数据
    onWellIdChanged: {
        if (wellId > 0) {
            console.log("🔄 井ID变化，重新加载井身结构数据:", wellId)
            loadWellStructureData()
        }
    }

    // 保留原函数名以兼容其他调用
    function getFilteredMotors() {
        return root.filteredMotors
    }

    // 🔥 在外径筛选逻辑中添加调试信息
    function getFilteredMotorsInternal() {
        console.log("=== 电机筛选（修复版）===")

        if (!availableMotors || availableMotors.length === 0) {
            console.log("⚠️ 没有可用电机数据")
            return []
        }

        // 创建电机数组的拷贝
        var motorList = []
        for (var i = 0; i < availableMotors.length; i++) {
            if (availableMotors[i]) {
                motorList.push(availableMotors[i])
            }
        }

        console.log("📊 初始电机数量:", motorList.length)

        // 1. 电压筛选
        var voltageFiltered = []
        for (var i = 0; i < motorList.length; i++) {
            var motor = motorList[i]
            if (!motor) continue

            var voltageSupported = false
            if (motor.voltage && motor.voltage.length > 0) {
                for (var j = 0; j < motor.voltage.length; j++) {
                    if (motor.voltage[j] === selectedVoltage) {
                        voltageSupported = true
                        break
                    }
                }
            }

            if (voltageSupported) {
                voltageFiltered.push(motor)
            }
        }

        console.log("⚡ 电压筛选后:", voltageFiltered.length, "个")

        // 2. 频率筛选
        var frequencyFiltered = []
        for (var i = 0; i < voltageFiltered.length; i++) {
            var motor = voltageFiltered[i]
            if (!motor) continue

            var frequencySupported = false
            if (motor.frequency && motor.frequency.length > 0) {
                for (var j = 0; j < motor.frequency.length; j++) {
                    if (motor.frequency[j] === selectedFrequency) {
                        frequencySupported = true
                        break
                    }
                }
            }

            if (frequencySupported) {
                frequencyFiltered.push(motor)
            }
        }

        console.log("🔄 频率筛选后:", frequencyFiltered.length, "个")

        // 3. 功率筛选
        var powerFiltered = []
        var requiredPowerValue = parseFloat(requiredPower)

        for (var i = 0; i < frequencyFiltered.length; i++) {
            var motor = frequencyFiltered[i]
            if (!motor) continue

            var powerOk = false
            if (motor.power !== undefined && motor.power !== null) {
                var motorPower = parseFloat(motor.power)

                if (motorPower >= requiredPowerValue) {
                    powerOk = true
                    console.log(`✅ 电机通过 - ${motor.model}: ${motorPower}HP >= ${requiredPowerValue}HP (大于需求)`)
                } else {
                    var minAcceptablePower = requiredPowerValue * 0.85
                    if (motorPower >= minAcceptablePower) {
                        powerOk = true
                        console.log(`⚠️ 电机通过 - ${motor.model}: ${motorPower}HP (${(motorPower/requiredPowerValue*100).toFixed(1)}% 需求功率)`)
                    } else {
                        console.log(`❌ 电机拒绝 - ${motor.model}: ${motorPower}HP < ${minAcceptablePower.toFixed(0)}HP (功率不足)`)
                    }
                }
            }

            if (powerOk) {
                powerFiltered.push(motor)
            }
        }

        console.log("💪 功率筛选后:", powerFiltered.length, "个")

        // 🔥 4. 修复外径筛选逻辑 - 使用生产套管内径（已转换为英寸）
        var sizeFiltered = []
        var casingInnerDiameter = productionCasingInnerDiameter || 6.184  // 使用生产套管内径（英寸）
        var originalMm = inchesToMm(casingInnerDiameter)

        console.log("📏 生产套管内径限制:", casingInnerDiameter.toFixed(2), "英寸 (", originalMm.toFixed(1), "mm)")

        for (var i = 0; i < powerFiltered.length; i++) {
            var motor = powerFiltered[i]
            if (!motor) continue

            var sizeOk = true
            if (motor.outerDiameter !== undefined && motor.outerDiameter !== null) {
                var motorDiameter = parseFloat(motor.outerDiameter)
                var maxDiameter = casingInnerDiameter - 0.25  // 🔥 预留0.25英寸间隙
                sizeOk = motorDiameter <= maxDiameter

                if (sizeOk) {
                    console.log(`✅ 尺寸合适 - ${motor.model}: ${motorDiameter}in <= ${maxDiameter.toFixed(2)}in (套管内径${casingInnerDiameter.toFixed(2)}in)`)
                } else {
                    console.log(`❌ 尺寸过大 - ${motor.model}: ${motorDiameter}in > ${maxDiameter.toFixed(2)}in (套管内径${casingInnerDiameter.toFixed(2)}in)`)
                }
            } else {
                // 如果没有尺寸数据，默认通过
                console.log(`⚠️ 尺寸数据缺失 - ${motor.model}: 默认通过`)
                sizeOk = true
            }

            if (sizeOk) {
                sizeFiltered.push(motor)
            }
        }

        console.log("📐 外径筛选后:", sizeFiltered.length, "个")

        // 5. 按功率排序（保持现有逻辑）
        if (sizeFiltered.length > 0) {
            sizeFiltered.sort(function(a, b) {
                var powerA = parseFloat(a.power)
                var powerB = parseFloat(b.power)
                var diffA = Math.abs(powerA - requiredPowerValue)
                var diffB = Math.abs(powerB - requiredPowerValue)

                var ratioA = powerA / requiredPowerValue
                var ratioB = powerB / requiredPowerValue

                var priorityA = getPowerPriority(ratioA)
                var priorityB = getPowerPriority(ratioB)

                if (priorityA !== priorityB) {
                    return priorityA - priorityB
                }

                return diffA - diffB
            })

            console.log("🏆 最终推荐电机:")
            for (var i = 0; i < Math.min(3, sizeFiltered.length); i++) {
                var motor = sizeFiltered[i]
                var ratio = (motor.power / requiredPowerValue * 100).toFixed(1)
                console.log(`  ${i+1}. ${motor.model}: ${motor.power}HP (${ratio}% 需求功率, OD:${motor.outerDiameter}in)`)
            }
        } else {
            console.log("❌ 没有找到符合条件的电机")
            console.log("💡 建议检查:")
            console.log("  - 生产套管内径:", casingInnerDiameter.toFixed(2), "英寸 (", originalMm.toFixed(1), "mm)")
            console.log("  - 电机功率需求:", requiredPowerValue, "HP")
            console.log("  - 电压/频率选择:", selectedVoltage + "V/" + selectedFrequency + "Hz")
        }

        return sizeFiltered
    }

    // 🔥 添加功率优先级函数
    function getPowerPriority(powerRatio) {
        // powerRatio = 电机功率 / 需求功率
        if (powerRatio >= 1.05 && powerRatio <= 1.20) {
            return 1  // 最高优先级：功率略大于需求（5%-20%）
        } else if (powerRatio >= 0.95 && powerRatio < 1.05) {
            return 2  // 第二优先级：功率接近需求（95%-105%）
        } else if (powerRatio >= 0.85 && powerRatio < 0.95) {
            return 3  // 第三优先级：功率略小于需求（85%-95%）
        } else if (powerRatio > 1.20 && powerRatio <= 1.50) {
            return 4  // 第四优先级：功率明显大于需求（20%-50%）
        } else {
            return 5  // 最低优先级：功率过大或其他情况
        }
    }

    // 🔥 修改 calculateMotorMatchScore() 函数

    function calculateMotorMatchScore(motor) {
        if (!motor) return 50

        var score = 70  // 基础分数提高到70
        var powerRatio = motor.power / requiredPower  // 电机功率/需求功率

        // 🔥 优化功率匹配评分
        if (powerRatio >= 1.05 && powerRatio <= 1.20) {
            score += 25  // 功率略大于需求（5%-20%）：最佳选择
        } else if (powerRatio >= 0.95 && powerRatio < 1.05) {
            score += 20  // 功率接近需求（95%-105%）：很好的选择
        } else if (powerRatio >= 0.90 && powerRatio < 0.95) {
            score += 10  // 功率略小（90%-95%）：可接受的选择
        } else if (powerRatio >= 0.85 && powerRatio < 0.90) {
            score += 5   // 功率偏小（85%-90%）：需要谨慎考虑
        } else if (powerRatio > 1.20 && powerRatio <= 1.30) {
            score += 15  // 功率偏大（20%-30%）：安全但可能浪费
        } else if (powerRatio > 1.30 && powerRatio <= 1.50) {
            score += 5   // 功率过大（30%-50%）：浪费明显
        } else if (powerRatio > 1.50) {
            score -= 10  // 功率严重过剩：不推荐
        } else {
            score -= 30  // 功率严重不足：不应该出现在筛选结果中
        }

        // 效率加分（保持原有逻辑）
        if (motor.efficiency && motor.efficiency >= 90) {
            score += (motor.efficiency - 90) * 2
        }

        // 功率因数加分（保持原有逻辑）
        if (motor.powerFactor && motor.powerFactor >= 0.85) {
            score += (motor.powerFactor - 0.85) * 50
        }

        // 温度适应性（保持原有逻辑）
        var temperature = stepData.parameters ? parseFloat(stepData.parameters.bht) : 235
        var maxTemp = getMaxTemperature(motor.insulationClass)
        var tempMargin = maxTemp - (motor.temperatureRise || 80) - temperature

        if (tempMargin < 20) {
            score -= 20  // 温度余量不足
        } else if (tempMargin > 150) {
            score -= 5   // 过度设计（轻微扣分）
        }

        // 🔥 添加电压匹配加分
        if (motor.voltage && motor.voltage.includes(selectedVoltage)) {
            score += 5  // 支持选定电压
        }

        // 🔥 添加频率匹配加分
        if (motor.frequency && motor.frequency.includes(selectedFrequency)) {
            score += 5  // 支持选定频率
        }

        return Math.max(0, Math.min(100, Math.round(score)))
    }
    
    function getMotorCurrent() {
        if (!selectedMotor) return 0
        
        // 简化计算：基于功率、电压和功率因数
        var current = (selectedMotor.power * 746) / (Math.sqrt(3) * selectedVoltage * selectedMotor.powerFactor * selectedMotor.efficiency / 100)
        return current.toFixed(1)
    }
    
    function getMotorSpeed() {
        if (!selectedMotor) return 0
        
        if (selectedFrequency === 60) {
            return selectedMotor.speed_60hz || 3600
        } else {
            return selectedMotor.speed_50hz || 3000
        }
    }
    
    function getEfficiencyRating() {
        if (!selectedMotor) return ""
        
        if (selectedMotor.efficiency >= 95) return "Premium+"
        if (selectedMotor.efficiency >= 93) return "Premium"
        if (selectedMotor.efficiency >= 90) return "High"
        return "Standard"
    }
    
    function getInsulationTemp() {
        if (!selectedMotor) return ""
        
        var temp = getMaxTemperature(selectedMotor.insulationClass)
        return temp + "°C " + (isChineseMode ? "最高" : "max")
    }
    
    function getMaxTemperature(insulationClass) {
        var temps = {
            "A": 105,
            "E": 120,
            "B": 130,
            "F": 155,
            "H": 180,
            "N": 200,
            "R": 220,
            "S": 240
        }
        return temps[insulationClass] || 155
    }
    
    function checkShaftCompatibility() {
        // 简化检查：实际应该有更详细的兼容性矩阵
        return true
    }
    
    function updateStepData() {
        if (!selectedMotor) return
        
        var data = {
            selectedMotor: selectedMotor.id,
            manufacturer: selectedMotor.manufacturer,
            model: selectedMotor.model,
            power: selectedMotor.power,
            voltage: selectedVoltage,
            frequency: selectedFrequency,
            efficiency: selectedMotor.efficiency,
            specifications: selectedMotor.model + " - " + 
                          selectedMotor.power + " HP @ " + 
                          selectedVoltage + "V/" + selectedFrequency + "Hz, " +
                          selectedMotor.efficiency + "% " + (isChineseMode ? "效率" : "efficiency")
        }
        
        root.dataChanged(data)
    }
    
    function showComparisonDialog() {
        // TODO: 显示电机对比对话框
        console.log("显示电机对比")
    }
    
    function filterMotors() {
        // 触发重新过滤
        console.log("触发电机重新过滤")
        //getFilteredMotors()
    }
    // 在文件末尾添加电机效率曲线组件
    LocalComponents.MotorEfficiencyCurve {
        id: motorEfficiencyChart
        isChineseMode: root.isChineseMode
    }
    // 🔥 添加单位转换函数
    function mmToInches(mm) {
        return mm / 25.4  // 1英寸 = 25.4毫米
    }
    function inchesToMm(inches) {
        return inches * 25.4
    }

}
