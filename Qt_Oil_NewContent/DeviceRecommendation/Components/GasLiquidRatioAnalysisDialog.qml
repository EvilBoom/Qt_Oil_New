import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtCharts
import QtQuick.Window
import "../../Common/Components" as CommonComponents
import "../../Common/Utils/UnitUtils.js" as UnitUtils

// Window {
ApplicationWindow{
    id: root
    title: isChineseMode ? "吸入口气液比分析" : "Gas-Liquid Ratio Analysis"
    width: 1200
    height: 650
    minimumWidth: 1000
    minimumHeight: 700
    // 🔥 修复 Window flags - 使用简单且兼容的组合
    // 添加可拖拽功能
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinMaxButtonsHint

    // 窗口图标和样式
    Material.theme: Material.Light
    Material.accent: Material.Blue

    modality: Qt.WindowModal
    color: Material.backgroundColor

    property bool isChineseMode: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false  // 🔥 添加单位制属性
    property var controller: null
    property var analysisData: null
    property var currentParameters: ({})

    // 当前选中点的数据
    property real selectedTemperature: 114 // °F (标准单位)
    property real selectedPressure: 21.25 // MPa (标准单位)
    property real currentGLR: 0

    // 控制参数
    property real fixedTemperature: 114
    property real fixedPressure: 21.25
    property real zFactor: 0.8
    property real gasDensity: 0.896
    property real oilDensity: 0.849

    property bool updateParam: false

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("GasLiquidRatioAnalysisDialog中单位制切换为:", isMetric ? "公制" : "英制")

            // 更新图表轴标题
            updateAxisTitles()

            // 重新加载分析数据以应用单位转换
            loadAnalysisData()
        }
    }

    onVisibleChanged: {
        if (visible) {
            loadAnalysisData()
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        contentHeight: mainContent.height
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            id: mainContent
            width: parent.width
            spacing: 5

            // 🔥 修改标题区域，添加单位切换器
            Rectangle {
                width: parent.width
                height: 80
                color: Material.color(Material.Blue, Material.Shade50)
                radius: 8
                border.color: Material.color(Material.Blue, Material.Shade200)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // 左侧标题信息
                    Column {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: isChineseMode ? "🔬 气液比敏感性分析" : "🔬 GLR Sensitivity Analysis"
                            font.pixelSize: 18
                            font.bold: true
                            color: Material.color(Material.Blue, Material.Shade800)
                        }

                        Text {
                            text: isChineseMode ? "分析温度和压力对吸入口气液比的影响" : "Analyze temperature and pressure effects on inlet GLR"
                            font.pixelSize: 13
                            color: Material.color(Material.Blue, Material.Shade600)
                            wrapMode: Text.Wrap
                        }
                    }

                    // 🔥 添加单位切换器
                    CommonComponents.UnitSwitcher {
                        isChinese: root.isChineseMode
                        showLabel: false
                    }

                    // 右侧当前值显示
                    Rectangle {
                        Layout.preferredWidth: 180
                        Layout.preferredHeight: 50
                        color: Material.color(Material.Orange, Material.Shade100)
                        radius: 6
                        border.color: Material.color(Material.Orange, Material.Shade300)
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "当前气液比" : "Current GLR"
                                font.pixelSize: 10
                                color: Material.color(Material.Orange, Material.Shade700)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: currentGLR.toFixed(2)
                                font.pixelSize: 16
                                font.bold: true
                                color: Material.color(Material.Orange, Material.Shade800)
                            }
                        }
                    }

                    // 导出按钮
                    Button {
                        Layout.preferredWidth: 120
                        text: isChineseMode ? "📊 导出" : "📊 Export"
                        Material.accent: Material.Blue
                        onClicked: exportAnalysisData()
                    }
                }
            }

            // 🔥 修改参数控制区域，添加单位转换
            // Rectangle {
            //     width: parent.width
            //     height: 190
            //     color: Material.dialogColor
            //     radius: 8
            //     border.color: Material.dividerColor
            //     border.width: 1

            //     Column {
            //         anchors.fill: parent
            //         anchors.margins: 5
            //         spacing: 15

            //         Text {
            //             text: isChineseMode ? "参数控制" : "Parameter Controls"
            //             font.pixelSize: 14
            //             font.bold: true
            //             color: Material.primaryTextColor
            //         }

            //         Grid {
            //             width: parent.width
            //             columns: 3
            //             columnSpacing: 40
            //             rowSpacing: 15

            //             // 🔥 修改固定温度控制，支持单位转换
            //             Column {
            //                 width: (parent.width - 80) / 3
            //                 spacing: 8

            //                 Text {
            //                     text: getTemperatureLabel()  // 🔥 动态标签
            //                     font.pixelSize: 11
            //                     color: Material.secondaryTextColor
            //                 }

            //                 Row {
            //                     spacing: 8

            //                     SpinBox {
            //                         id: fixedTempSpinBox
            //                         from: getTemperatureFrom()  // 🔥 动态范围
            //                         to: getTemperatureTo()      // 🔥 动态范围
            //                         value: getTemperatureValue() // 🔥 动态初值
            //                         width: 150

            //                         onValueChanged: {
            //                             // root.fixedTemperature = convertTemperatureToStandard(value)
            //                             root.fixedTemperature = value
            //                             root.updateParam = true
            //                             updateFixedTemperature()
            //                         }
            //                     }

            //                     Text {
            //                         anchors.verticalCenter: parent.verticalCenter
            //                         text: getTemperatureUnit()  // 🔥 动态单位
            //                         color: Material.secondaryTextColor
            //                         font.pixelSize: 11
            //                     }
            //                 }
            //             }

            //             // 🔥 修改固定压力控制，支持单位转换
            //             Column {
            //                 width: (parent.width - 80) / 3
            //                 spacing: 8

            //                 Text {
            //                     text: getPressureLabel()  // 🔥 动态标签
            //                     font.pixelSize: 11
            //                     color: Material.secondaryTextColor
            //                 }

            //                 Row {
            //                     spacing: 8

            //                     SpinBox {
            //                         id: fixedPressSpinBox
            //                         from: getPressureFrom() * 10     // 乘以10提供小数精度
            //                         to: getPressureTo() * 10         // 乘以10提供小数精度
            //                         value: getPressureValue()
            //                         stepSize: 10                     // 适当的步长
            //                         width: 150

            //                         property real realValue: value  // 实际值

            //                         textFromValue: function(value, locale) {
            //                             return (value/10.0).toFixed(1)  // 显示1位小数
            //                         }

            //                         valueFromText: function(text, locale) {
            //                             return parseFloat(text) * 10    // 转换回整数
            //                         }

            //                         onValueChanged: {
            //                             // root.fixedPressure = convertPressureToStandard(realValue)
            //                             root.fixedPressure = realValue
            //                             root.updateParam = true
            //                             updateFixedPressure()
            //                         }
            //                     }

            //                     Text {
            //                         anchors.verticalCenter: parent.verticalCenter
            //                         text: getPressureUnit()  // 🔥 动态单位
            //                         color: Material.secondaryTextColor
            //                         font.pixelSize: 11
            //                     }
            //                 }
            //             }

            //             // Z因子控制（保持不变）
            //             Column {
            //                 width: (parent.width - 80) / 3
            //                 spacing: 8

            //                 Text {
            //                     text: "Z因子"
            //                     font.pixelSize: 11
            //                     color: Material.secondaryTextColor
            //                 }

            //                 Row {
            //                     spacing: 8

            //                     SpinBox {
            //                         id: zFactorSpinBox
            //                         from: 60   // 0.6 * 100
            //                         to: 150    // 1.5 * 100
            //                         value: 80  // 0.8 * 100
            //                         width: 160

            //                         property real realValue: value / 100.0

            //                         textFromValue: function(value, locale) {
            //                             return (value/100.0).toFixed(2)
            //                         }

            //                         valueFromText: function(text, locale) {
            //                             return parseFloat(text) * 100
            //                         }

            //                         onValueChanged: {
            //                             root.zFactor = realValue
            //                             updateZFactor()
            //                         }
            //                     }
            //                 }
            //             }
            //         }

            //         // 刷新按钮区域（保持不变）
            //         Row {
            //             spacing: 12

            //             Button {
            //                 text: isChineseMode ? "🔄 刷新数据" : "🔄 Refresh Data"
            //                 Material.accent: Material.Green
            //                 onClicked: loadAnalysisData()
            //             }

            //             Button {
            //                 text: isChineseMode ? "↺ 重置参数" : "↺ Reset Parameters"
            //                 flat: true
            //                 onClicked: resetParameters()
            //             }
            //         }
            //     }
            // }

            // 🔥 修改图表区域，添加动态轴标题
            Rectangle {
                width: parent.width
                height: 450
                color: Material.dialogColor
                radius: 8
                border.color: Material.dividerColor
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 15

                    // 温度-气液比图
                    Rectangle {
                        width: (parent.width - 15) / 2
                        height: parent.height
                        color: "#f8f9fa"
                        radius: 6
                        border.color: Material.color(Material.Blue, Material.Shade200)
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "📈 温度 vs 气液比" : "📈 Temperature vs GLR"
                                font.pixelSize: 14
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            ChartView {
                                id: temperatureChart
                                width: parent.width
                                height: parent.height - 30
                                antialiasing: true
                                backgroundColor: "#ffffff"
                                margins.top: 10
                                margins.bottom: 10
                                margins.left: 10
                                margins.right: 10

                                ValuesAxis {
                                    id: tempXAxis
                                    min: getTemperatureAxisMin()  // 🔥 动态范围
                                    max: getTemperatureAxisMax()  // 🔥 动态范围
                                    titleText: getTemperatureAxisTitle()  // 🔥 动态标题
                                    labelFormat: "%.0f"
                                }

                                ValuesAxis {
                                    id: tempYAxis
                                    min: 0
                                    max: 200
                                    titleText: isChineseMode ? "气液比" : "GLR"
                                    labelFormat: "%.1f"
                                }

                                LineSeries {
                                    id: tempLineSeries
                                    name: isChineseMode ? "气液比变化" : "GLR Variation"
                                    axisX: tempXAxis
                                    axisY: tempYAxis
                                    color: Material.color(Material.Blue)
                                    width: 3
                                }

                                ScatterSeries {
                                    id: tempPointSeries
                                    name: isChineseMode ? "选中点" : "Selected Point"
                                    axisX: tempXAxis
                                    axisY: tempYAxis
                                    color: Material.color(Material.Red)
                                    markerSize: 10
                                    borderColor: Material.color(Material.Red, Material.Shade800)
                                    borderWidth: 2
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onPositionChanged: function(mouse) {
                                        var point = temperatureChart.mapToValue(Qt.point(mouse.x, mouse.y), tempLineSeries)
                                        updateSelectedTemperature(point.x)
                                    }

                                    onClicked: function(mouse) {
                                        var point = temperatureChart.mapToValue(Qt.point(mouse.x, mouse.y), tempLineSeries)
                                        updateSelectedTemperature(point.x)
                                    }
                                }
                            }
                        }
                    }

                    // 压力-气液比图
                    Rectangle {
                        width: (parent.width - 15) / 2
                        height: parent.height
                        color: "#f8f9fa"
                        radius: 6
                        border.color: Material.color(Material.Green, Material.Shade200)
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: isChineseMode ? "📈 压力 vs 气液比" : "📈 Pressure vs GLR"
                                font.pixelSize: 14
                                font.bold: true
                                color: Material.primaryTextColor
                            }

                            ChartView {
                                id: pressureChart
                                width: parent.width
                                height: parent.height - 30
                                antialiasing: true
                                backgroundColor: "#ffffff"
                                margins.top: 10
                                margins.bottom: 10
                                margins.left: 10
                                margins.right: 10

                                ValuesAxis {
                                    id: pressXAxis
                                    min: getPressureAxisMin()  // 🔥 动态范围
                                    max: getPressureAxisMax()  // 🔥 动态范围
                                    titleText: getPressureAxisTitle()  // 🔥 动态标题
                                    labelFormat: isMetric ? "%.0f" : "%.1f"  // 🔥 动态格式
                                }

                                ValuesAxis {
                                    id: pressYAxis
                                    min: 0
                                    max: 200
                                    titleText: isChineseMode ? "气液比" : "GLR"
                                    labelFormat: "%.1f"
                                }

                                LineSeries {
                                    id: pressLineSeries
                                    name: isChineseMode ? "气液比变化" : "GLR Variation"
                                    axisX: pressXAxis
                                    axisY: pressYAxis
                                    color: Material.color(Material.Green)
                                    width: 3
                                }

                                ScatterSeries {
                                    id: pressPointSeries
                                    name: isChineseMode ? "选中点" : "Selected Point"
                                    axisX: pressXAxis
                                    axisY: pressYAxis
                                    color: Material.color(Material.Red)
                                    markerSize: 10
                                    borderColor: Material.color(Material.Red, Material.Shade800)
                                    borderWidth: 2
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onPositionChanged: function(mouse) {
                                        var point = pressureChart.mapToValue(Qt.point(mouse.x, mouse.y), pressLineSeries)
                                        updateSelectedPressure(point.x)
                                    }

                                    onClicked: function(mouse) {
                                        var point = pressureChart.mapToValue(Qt.point(mouse.x, mouse.y), pressLineSeries)
                                        updateSelectedPressure(point.x)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 🔥 修改底部信息，显示转换后的单位
            Rectangle {
                width: parent.width
                height: 80
                color: Material.color(Material.Grey, Material.Shade100)
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Text {
                        text: "💡"
                        font.pixelSize: 20
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: isChineseMode ?
                                  `当前条件: T=${selectedTemperature.toFixed(1)}${getTemperatureUnit()}, P=${selectedPressure.toFixed(1)}${getPressureUnit()}, GLR=${currentGLR.toFixed(2)}` :
                                  `Current: T=${selectedTemperature.toFixed(1)}${getTemperatureUnit()}, P=${selectedPressure.toFixed(1)}${getPressureUnit()}, GLR=${currentGLR.toFixed(2)}`
                            font.pixelSize: 13
                            font.bold: true
                            color: Material.primaryTextColor
                        }

                        Text {
                            text: isChineseMode ?
                                  "点击或移动鼠标到图表上查看不同条件下的气液比值。调整上方参数可重新计算曲线。" :
                                  "Click or move mouse on charts to see GLR values. Adjust parameters above to recalculate curves."
                            font.pixelSize: 11
                            color: Material.secondaryTextColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Button {
                        Layout.preferredWidth: 100
                        text: isChineseMode ? "关闭" : "Close"
                        Material.accent: Material.Red
                        onClicked: root.close()
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

    // 🔥 =================================
    // 🔥 单位转换函数
    // 🔥 =================================

    function getTemperatureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("temperature")
        }
        return isMetric ? "°C" : "°F"
    }

    function getPressureUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("pressure")
        }
        return isMetric ? "MPa" : "psi"  // 🔥 改为 MPa，不是 kPa
    }

    function getTemperatureLabel() {
        var unit = getTemperatureUnit()
        var text = isChineseMode ? "固定温度" : "Fixed Temperature"
        return `${text} (${unit})`
    }

    function getPressureLabel() {
        var unit = getPressureUnit()
        var text = isChineseMode ? "固定压力" : "Fixed Pressure"
        return `${text} (${unit})`
    }

    function getTemperatureAxisTitle() {
        var unit = getTemperatureUnit()
        var text = isChineseMode ? "温度" : "Temperature"
        return `${text} (${unit})`
    }

    function getPressureAxisTitle() {
        var unit = getPressureUnit()
        var text = isChineseMode ? "压力" : "Pressure"
        return `${text} (${unit})`
    }

    function convertTemperatureFromStandard(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.fahrenheitToCelsius(value)  // °F → °C
    }

    function convertTemperatureToStandard(value) {
        if (!isMetric) return value  // 英制不需要转换
        return UnitUtils.celsiusToFahrenheit(value)  // °C → °F
    }

    function convertPressureFromStandard(value) {
        // 🔥 修复：Python中已经是MPa，不需要转换
        if (!isMetric) return value * 145.038  // MPa → psi
        return value  // 公制时直接使用MPa
    }

    function convertPressureToStandard(value) {
        // 🔥 修复：转换回标准单位
        if (!isMetric) return value / 145.038  // psi → MPa
        return value  // 公制时直接使用MPa
    }

    // 🔥 动态范围和数值函数
    function getTemperatureFrom() {
        var min_temp = 0
        min_temp = fixedTemperature * 0.7
        return min_temp
    }

    function getTemperatureTo() {
        var max_temp = 0
        max_temp = fixedTemperature * 1.3
        return max_temp
    }

    function getTemperatureValue() {
        return fixedTemperature
    }

    function getTemperatureAxisMin() {
        var min_temp = 0
        min_temp = fixedTemperature * 0.6
        return min_temp
    }

    function getTemperatureAxisMax() {
        var max_temp = 0
        max_temp = fixedTemperature * 1.4
        return max_temp
    }

    function getPressureFrom() {
        var min_temp = 0
        min_temp = fixedPressure * 0.7
        return min_temp
    }

    function getPressureTo() {
        var max_temp = 0
        max_temp = fixedPressure * 1.3
        return max_temp
    }

    function getPressureValue() {
        return fixedPressure
    }

    function getPressureAxisMin() {
        var min_temp = 0
        min_temp = fixedPressure * 0.6
        return min_temp
    }

    function getPressureAxisMax() {
        var max_temp = 0
        max_temp = fixedPressure * 1.4
        return max_temp
    }

    function updateAxisTitles() {
        tempXAxis.titleText = getTemperatureAxisTitle()
        pressXAxis.titleText = getPressureAxisTitle()

        // 更新轴范围
        tempXAxis.min = getTemperatureAxisMin()
        tempXAxis.max = getTemperatureAxisMax()
        pressXAxis.min = getPressureAxisMin()
        pressXAxis.max = getPressureAxisMax()

        // 更新压力轴格式
        pressXAxis.labelFormat = isMetric ? "%.0f" : "%.1f"
    }

    // 🔥 =================================
    // 🔥 修改原有函数，支持单位转换
    // 🔥 =================================

    function loadAnalysisData(updateParam) {
        if (!controller) {
            console.warn("Controller not available")
            return
        }
        // console.log("目前的参数值", JSON.stringify(currentParameters))
        fixedTemperature = currentParameters.parameters.bht
        fixedPressure = currentParameters.parameters.geoPressure

        var params = {
            waterRatio: 0,
            gasOilRatio: currentParameters.parameters.gasOilRatio,
            saturationPressure: currentParameters.parameters.saturationPressure,
            fixedTemperature: currentParameters.parameters.bht,
            fixedPressure: currentParameters.parameters.geoPressure,
            zFactor: zFactor,
            gasDensity: gasDensity,
            oilDensity: oilDensity
        }
        if(updateParam){
            params.fixedTemperature = fixedTemperature
            params.fixedPressure = fixedPressure
        }

        console.log("🔄 加载气液比分析数据，参数:", JSON.stringify(params))
        console.log("当前单位制:", isMetric ? "公制" : "英制")

        try {
            analysisData = controller.generateGasLiquidRatioAnalysis(params)

            if (analysisData && analysisData.temperatureData && analysisData.pressureData) {
                updateCharts()
                console.log("✅ 气液比分析数据加载成功")
            } else {
                console.warn("⚠️ 气液比分析数据为空或格式错误")
            }
        } catch (error) {
            console.error("❌ 加载气液比分析数据失败:", error)
        }
        updateParam = false
    }

    function updateCharts() {
        if (!analysisData) return

        console.log("🔄 更新图表数据（无限制版本）")

        // 🔥 温度图表更新
        tempLineSeries.clear()
        tempPointSeries.clear()

        var tempData = analysisData.temperatureData || []
        var minGLR = Number.MAX_VALUE, maxGLR = Number.MIN_VALUE

        console.log(`温度数据总数: ${tempData.length}`)

        for (var i = 0; i < tempData.length; i++) {
            var point = tempData[i]
            var convertedTemp = point.temperature
            var glr = point.glr

            console.log(`温度数据点 ${i}: T=${convertedTemp}°C, GLR=${glr}`)

            tempLineSeries.append(convertedTemp, glr)
            minGLR = Math.min(minGLR, glr)
            maxGLR = Math.max(maxGLR, glr)
        }

        // 🔥 动态调整温度图Y轴范围（不设置最小值）
        if (tempData.length > 0) {
            var tempRange = Math.max(maxGLR - minGLR, 0.1) // 确保有最小范围
            tempYAxis.min = minGLR - tempRange * 0.1
            tempYAxis.max = maxGLR + tempRange * 0.1
            console.log(`温度图Y轴范围: ${tempYAxis.min} - ${tempYAxis.max}`)
        }

        // 🔥 压力图表更新
        pressLineSeries.clear()
        pressPointSeries.clear()

        var pressData = analysisData.pressureData || []
        minGLR = Number.MAX_VALUE, maxGLR = Number.MIN_VALUE

        console.log(`压力数据总数: ${pressData.length}`)

        for (var i = 0; i < pressData.length; i++) {
            var point = pressData[i]
            var displayPressure = point.pressure
            var glr = point.glr

            console.log(`压力数据点 ${i}: P=${displayPressure}${isMetric ? 'MPa' : 'psi'}, GLR=${glr}`)

            pressLineSeries.append(displayPressure, glr)
            minGLR = Math.min(minGLR, glr)
            maxGLR = Math.max(maxGLR, glr)
        }

        // 🔥 动态调整压力图Y轴范围（不设置最小值）
        if (pressData.length > 0) {
            var pressRange = Math.max(maxGLR - minGLR, 0.1) // 确保有最小范围
            pressYAxis.min = minGLR - pressRange * 0.1
            pressYAxis.max = maxGLR + pressRange * 0.1
            console.log(`压力图Y轴范围: ${pressYAxis.min} - ${pressYAxis.max}`)
        }

        // 设置初始选中点
        updateSelectedTemperature(convertTemperatureFromStandard(selectedTemperature))
        updateSelectedPressure(isMetric ? selectedPressure : (selectedPressure * 145.038))

        console.log("✅ 图表更新完成（显示真实计算值）")
    }

    function updateSelectedTemperature(temp) {
        var minTemp = getTemperatureAxisMin()
        var maxTemp = getTemperatureAxisMax()
        var convertedTemp = Math.max(minTemp, Math.min(maxTemp, temp))

        selectedTemperature = convertTemperatureToStandard(convertedTemp)

        // 在温度图上显示选中点
        tempPointSeries.clear()
        var glr = interpolateGLRByTemperature(selectedTemperature)
        if (glr > 0) {
            tempPointSeries.append(convertedTemp, glr)
        }

        updateCurrentGLR()
    }

    function updateSelectedPressure(press) {
        var minPress = getPressureAxisMin()
        var maxPress = getPressureAxisMax()
        var convertedPress = Math.max(minPress, Math.min(maxPress, press))

        selectedPressure = convertPressureToStandard(convertedPress)

        // 在压力图上显示选中点
        pressPointSeries.clear()
        var glr = interpolateGLRByPressure(selectedPressure)
        if (glr > 0) {
            pressPointSeries.append(convertedPress, glr)
        }

        updateCurrentGLR()
    }

    function interpolateGLRByTemperature(temp) {
        if (!analysisData || !analysisData.temperatureData) return 0

        var data = analysisData.temperatureData
        if (data.length === 0) return 0

        // 简单的线性插值
        for (var i = 0; i < data.length - 1; i++) {
            if (temp >= data[i].temperature && temp <= data[i + 1].temperature) {
                var ratio = (temp - data[i].temperature) / (data[i + 1].temperature - data[i].temperature)
                return data[i].glr + ratio * (data[i + 1].glr - data[i].glr)
            }
        }

        // 边界情况处理
        if (temp <= data[0].temperature) return data[0].glr
        if (temp >= data[data.length - 1].temperature) return data[data.length - 1].glr

        return data[0].glr
    }

    function interpolateGLRByPressure(press) {
        if (!analysisData || !analysisData.pressureData) return 0

        var data = analysisData.pressureData
        if (data.length === 0) return 0

        for (var i = 0; i < data.length - 1; i++) {
            if (press >= data[i].pressure && press <= data[i + 1].pressure) {
                var ratio = (press - data[i].pressure) / (data[i + 1].pressure - data[i].pressure)
                return data[i].glr + ratio * (data[i + 1].glr - data[i].glr)
            }
        }

        // 边界情况处理
        if (press <= data[0].pressure) return data[0].glr
        if (press >= data[data.length - 1].pressure) return data[data.length - 1].glr

        return data[0].glr
    }

    function updateCurrentGLR() {
        // 使用温度图的插值结果作为当前GLR显示
        currentGLR = interpolateGLRByTemperature(selectedTemperature)
    }

    function updateFixedTemperature() {
        Qt.callLater(loadAnalysisData)
    }

    function updateFixedPressure() {
        Qt.callLater(loadAnalysisData)
    }

    function updateZFactor() {
        Qt.callLater(loadAnalysisData)
    }

    function resetParameters() {
        fixedTempSpinBox.value = getTemperatureValue()
        fixedPressSpinBox.value = getPressureValue()
        zFactorSpinBox.value = 80

        fixedTemperature = 114
        fixedPressure = 21.3
        zFactor = 0.8

        loadAnalysisData()
    }

    function exportAnalysisData() {
        if (!analysisData) {
            console.warn("无数据可导出")
            return
        }

        console.log("📊 导出气液比分析数据")
        console.log("温度数据点:", analysisData.temperatureData ? analysisData.temperatureData.length : 0)
        console.log("压力数据点:", analysisData.pressureData ? analysisData.pressureData.length : 0)
        console.log("当前单位制:", isMetric ? "公制" : "英制")

        // TODO: 实现实际的数据导出功能
        // 可以导出为CSV格式或调用文件保存对话框
    }
}
