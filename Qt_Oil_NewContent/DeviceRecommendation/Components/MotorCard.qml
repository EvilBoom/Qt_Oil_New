// Qt_Oil_NewContent/DeviceRecommendation/Components/MotorCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root
    
    property var motorData: null
    property bool isSelected: false
    property int matchScore: 50
    property real requiredPower: 100
    property int selectedVoltage: 3300
    property int selectedFrequency: 60
    property bool isChineseMode: true
    property var currentFrequencyPower: null
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false

    
    signal clicked()
    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("MotorCard中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }
    
    color: isSelected ? '#F5F5DC' : Material.backgroundColor
    radius: 8
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.DeepPurple : Material.Brown

    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 60
        height: 20
        radius: 12
        color: Material.Green
        visible: matchScore >= 80
        
        Text {
            anchors.centerIn: parent
            text: isChineseMode ? "推荐" : "Best"
            color: "white"
            font.pixelSize: 9
            font.bold: true
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        
        // 头部信息
        RowLayout {
            Layout.fillWidth: true
            
            // 图标和基本信息
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: Material.color(Material.Cyan)
                
                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    font.pixelSize: 20
                }
            }
            
            Column {
                Layout.fillWidth: true
                
                Text {
                    text: motorData ? motorData.manufacturer : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }
                
                Text {
                    text: motorData ? motorData.model : ""
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.primaryTextColor
                }
                
                Text {
                    text: motorData ? motorData.series + " Series" : ""
                    font.pixelSize: 11
                    color: Material.secondaryTextColor
                }
            }
            
            // 匹配度
            CircularProgress {
                width: 40
                height: 40
                value: matchScore / 100

                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }
        
        // 功率和负载率
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: getPowerUtilizationColor()
            radius: 6
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: isChineseMode ? "额定功率" : "Rated Power"
                        font.pixelSize: 11
                        color: Material.secondaryTextColor
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        // text: formatPower(motorData ? motorData.power : 0)  // 🔥 使用格式化函数
                        text: formatPower(currentFrequencyPower !== null ? currentFrequencyPower : (motorData ? motorData.power : 0))

                        font.pixelSize: 16
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
                
                // 负载率进度条
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.rgba(0, 0, 0, 0.1)
                    
                    Rectangle {
                        // width: parent.width * Math.min(1.0, requiredPower / (motorData ? motorData.power : 1))
                        width: {
                                   // 🔥 使用当前频率的功率计算负载率
                                   var motorPowerKw = currentFrequencyPower !== null ? currentFrequencyPower : (motorData ? motorData.power : 1)
                                   var requiredPowerKw = requiredPower * 0.746  // HP转kW
                                   return parent.width * Math.min(1.0, requiredPowerKw / motorPowerKw)
                               }
                        height: parent.height
                        radius: parent.radius
                        color: {
                            var motorPowerKw = currentFrequencyPower !== null ? currentFrequencyPower : (motorData ? motorData.power : 1)
                            var requiredPowerKw = requiredPower * 0.746  // HP转kW
                            var ratio = requiredPowerKw / motorPowerKw
                            if (ratio > 1) return Material.color(Material.Red)
                            if (ratio > 0.95) return Material.color(Material.Green)
                            if (ratio > 0.85) return Material.color(Material.Orange)
                            return Material.color(Material.Green)
                        }
                    }
                }
                
                Text {
                    text: {
                        // 🔥 使用当前频率的功率计算负载率
                        var motorPowerKw = currentFrequencyPower !== null ? currentFrequencyPower : (motorData ? motorData.power : 1)
                        var requiredPowerKw = requiredPower * 0.746  // HP转kW
                        var ratio = (requiredPowerKw / motorPowerKw * 100).toFixed(0)
                        return (isChineseMode ? "负载率: " : "Load: ") + ratio + "%"
                    }
                    font.pixelSize: 11
                    color: Material.secondaryTextColor
                }
            }
        }
        
        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }
        
        // 关键参数
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 6
            
            // 效率
            // Row {
            //     spacing: 6
                
            //     Rectangle {
            //         width: 4
            //         height: 14
            //         color: Material.color(Material.Green)
            //         radius: 2
            //         anchors.verticalCenter: parent.verticalCenter
            //     }
                
            //     Column {
            //         spacing: 0
                    
            //         Text {
            //             text: isChineseMode ? "效率" : "Efficiency"
            //             font.pixelSize: 10
            //             color: Material.hintTextColor
            //         }
                    
            //         Text {
            //             text: (motorData ? motorData.efficiency : 0) + "%"
            //             font.pixelSize: 13
            //             font.bold: true
            //             color: Material.primaryTextColor
            //         }
            //     }
            // }
            
            // // 功率因数
            // Row {
            //     spacing: 6
                
            //     Rectangle {
            //         width: 4
            //         height: 14
            //         color: Material.color(Material.Blue)
            //         radius: 2
            //         anchors.verticalCenter: parent.verticalCenter
            //     }
                
            //     Column {
            //         spacing: 0
                    
            //         Text {
            //             text: isChineseMode ? "功率因数" : "PF"
            //             font.pixelSize: 10
            //             color: Material.hintTextColor
            //         }
                    
            //         Text {
            //             text: motorData ? motorData.powerFactor : "0.85"
            //             font.pixelSize: 13
            //             font.bold: true
            //             color: Material.primaryTextColor
            //         }
            //     }
            // }
            
            // 绝缘等级
            Row {
                spacing: 6
                
                Rectangle {
                    width: 4
                    height: 14
                    color: Material.color(Material.Orange)
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    
                    Text {
                        text: isChineseMode ? "绝缘" : "Insulation"
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: (motorData ? motorData.insulationClass : "") + " " + (isChineseMode ? "级" : "Class")
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
            
            // 外径
            Row {
                spacing: 6
                
                Rectangle {
                    width: 4
                    height: 14
                    color: Material.color(Material.Purple)
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Column {
                    spacing: 0
                    
                    Text {
                        text: isChineseMode ? "外径" : "OD"
                        font.pixelSize: 10
                        color: Material.hintTextColor
                    }
                    
                    Text {
                        text: formatDiameter(motorData ? motorData.outerDiameter : 0)  // 🔥 使用格式化函数
                        //bug暂时去掉转换，因为存储的公制数据
                        // text: motorData.outerDiameter + "mm"
                        font.pixelSize: 13
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
        }
        
        // 🔥 修正电压/频率支持显示 - 直接显示数据库中的频率
        Flow {
            Layout.fillWidth: true
            spacing: 6

            // 🔥 支持的电压 - 直接显示motorData中的电压数组
            Repeater {
                model: motorData && motorData.voltage ? motorData.voltage : []

                Rectangle {
                    width: voltageText.width + 12
                    height: 20
                    radius: 10
                    color: modelData === selectedVoltage
                           ? Material.Green
                           : Qt.rgba(0, 0, 0, 0.05)

                    Text {
                        id: voltageText
                        anchors.centerIn: parent
                        text: modelData + "V"
                        font.pixelSize: 10
                        color: modelData === selectedVoltage
                               ? "white"
                               : Material.secondaryTextColor
                    }
                }
            }

            // 分隔符
            Rectangle {
                width: 1
                height: 20
                color: Material.dividerColor
                visible: (motorData && motorData.voltage && motorData.voltage.length > 0) &&
                        (motorData && motorData.frequency && motorData.frequency.length > 0)
            }

            // 🔥 支持的频率 - 直接显示motorData中的频率数组，不进行任何过滤
            Repeater {
                model: motorData && motorData.frequency ? motorData.frequency : []

                Rectangle {
                    width: freqText.width + 12
                    height: 20
                    radius: 10
                    color: modelData === selectedFrequency
                           ? Material.Green
                           : Qt.rgba(0, 0, 0, 0.05)

                    Text {
                        id: freqText
                        anchors.centerIn: parent
                        text: modelData + "Hz"
                        font.pixelSize: 10
                        color: modelData === selectedFrequency
                               ? "white"
                               : Material.secondaryTextColor
                    }
                }
            }
        }
    }
    
    // 选中效果
    Rectangle {
        anchors.fill: parent
        color: Material.Blue
        opacity: 0.1
        radius: parent.radius
        visible: isSelected
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    // function formatPower(valueInHP) {
    //     if (!valueInHP || valueInHP <= 0) return "N/A"

    //     if (isMetric) {
    //         // 转换为千瓦
    //         var kwValue = valueInHP * 0.746
    //         return kwValue.toFixed(1) + " kW"
    //     } else {
    //         // 保持马力
    //         return valueInHP.toFixed(0) + " HP"
    //     }
    // }
    function formatPower(valueInKW) {
        if (!valueInKW || valueInKW <= 0) return "N/A"

        if (isMetric) {
            // 显示千瓦
            return valueInKW.toFixed(1) + " kW"
        } else {
            // 转换为马力
            var hpValue = valueInKW / 0.746
            return hpValue.toFixed(0) + " HP"
        }
    }

    function formatDiameter(valueInInches) {
        if (!valueInInches || valueInInches <= 0) return "N/A"

        if (isMetric) {
            // 保持英寸
            return valueInInches.toFixed(1) + " mm"
        } else {

            // 转换为英寸
            var mmValue = valueInInches / 25.4
            return mmValue.toFixed(0) + " in"
        }
    }

    function formatLength(valueInFt) {
        if (!valueInFt || valueInFt <= 0) return "N/A"

        if (isMetric) {
            // 转换为米
            var mValue = valueInFt * 0.3048
            return mValue.toFixed(1) + " m"
        } else {
            // 保持英尺
            return valueInFt.toFixed(1) + " ft"
        }
    }

    function formatWeight(valueInLbs) {
        if (!valueInLbs || valueInLbs <= 0) return "N/A"

        if (isMetric) {
            // 转换为千克
            var kgValue = valueInLbs * 0.453592
            return kgValue.toFixed(0) + " kg"
        } else {
            // 保持磅
            return valueInLbs.toFixed(0) + " lbs"
        }
    }

    function formatTemperature(valueInF) {
        if (!valueInF || valueInF <= 0) return "N/A"

        if (isMetric) {
            // 转换为摄氏度
            var cValue = UnitUtils.fahrenheitToCelsius(valueInF)
            return cValue.toFixed(0) + " °C"
        } else {
            // 保持华氏度
            return valueInF.toFixed(0) + " °F"
        }
    }
    
    function getPowerUtilizationColor() {
        if (!motorData) return Material.backgroundColor
        
        var ratio = requiredPower / motorData.power
        if (ratio > 0.95) return Material.color(Material.Red, Material.Shade50)
        if (ratio > 0.85) return Material.color(Material.Orange, Material.Shade50)
        if (ratio < 0.5) return Material.color(Material.Orange, Material.Shade50)
        return Material.color(Material.Green, Material.Shade50)
    }

    Component.onCompleted: {
        console.log("尝试正常加载motorCard")
        // console.log(motorData)
    }
}
