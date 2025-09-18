// Qt_Oil_NewContent/DeviceRecommendation/Components/ProtectorCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Rectangle {
    id: root

    // 正确的保护器卡片属性
    property var protectorData: null
    property bool isSelected: false
    property int matchScore: 50
    property real requiredThrust: 0
    property bool isChineseMode: true

    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false
    signal clicked()

    color: isSelected ? '#F5F5DC' : Material.backgroundColor
    radius: 8
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.DeepPurple : Material.Brown

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("ProtectorCard中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }

    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        width: 50
        height: 20
        radius: 12
        color: Material.Green
        visible: matchScore >= 80

        Text {
            anchors.centerIn: parent
            text: isChineseMode ? "推荐" : "Best"
            color: "white"
            font.pixelSize: 11
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

            // 图标
            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: Material.color(Material.Blue)

                Text {
                    anchors.centerIn: parent
                    text: "🛡️"
                    font.pixelSize: 20
                }
            }

            // 标题信息
            Column {
                Layout.fillWidth: true

                Text {
                    text: protectorData ? protectorData.manufacturer : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }

                Text {
                    text: protectorData ? protectorData.model : ""
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.primaryTextColor
                }

                Text {
                    text: protectorData ? protectorData.type : ""
                    font.pixelSize: 12
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

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
        }

        // 关键参数
        Grid {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 8

            // 推力承载能力
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "推力承载" : "Thrust Capacity"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Row {
                    spacing: 4

                    Text {
                        text: formatForce(protectorData ? protectorData.thrustCapacity : 0)
                        font.pixelSize: 12
                        font.bold: true
                        color: getThrustColor()
                    }

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: getThrustColor()
                        anchors.verticalCenter: parent.verticalCenter
                        visible: requiredThrust > 0

                        Text {
                            anchors.centerIn: parent
                            text: getThrustIcon()
                            font.pixelSize: 8
                            color: "white"
                        }
                    }
                }
            }

            // 最高温度
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "最高温度" : "Max Temp"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Text {
                    text: (protectorData ? protectorData.maxTemperature : 0) + " °F"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }

            // 密封类型
            Column {
                spacing: 2

                Text {
                    text: isChineseMode ? "密封类型" : "Seal Type"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }

                Text {
                    text: formatTemperature(protectorData ? protectorData.maxTemperature : 0)
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }

            // 外径
            // Column {
            //     spacing: 2

            //     Text {
            //         text: isChineseMode ? "外径" : "OD"
            //         font.pixelSize: 11
            //         color: Material.hintTextColor
            //     }

            //     Text {
            //         // text: formatDiameter(protectorData ? protectorData.outerDiameter : 0)
            //         text:protectorData.outerDiameter
            //         font.pixelSize: 12
            //         font.bold: true
            //         color: Material.primaryTextColor
            //     }
            // }
        }

        // 特性描述
        Text {
            Layout.fillWidth: true
            text: protectorData ? protectorData.features : ""
            font.pixelSize: 11
            color: Material.secondaryTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // // 选中效果
    // Rectangle {
    //     anchors.fill: parent
    //     color: Material.accent
    //     opacity: 0.1
    //     radius: parent.radius
    //     visible: isSelected
    // }

    // 辅助函数
    function getThrustColor() {
        if (!protectorData || requiredThrust === 0) return Material.primaryTextColor

        if (protectorData.thrustCapacity >= requiredThrust) {
            return Material.color(Material.Green)
        } else {
            return Material.color(Material.Red)
        }
    }

    function getThrustIcon() {
        if (!protectorData || requiredThrust === 0) return ""

        if (protectorData.thrustCapacity >= requiredThrust) {
            return "✓"
        } else {
            return "✗"
        }
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatForce(valueInLbs) {
        if (!valueInLbs || valueInLbs <= 0) return "N/A"

        if (!isMetric) {
            // 转换为牛顿 (1 lbs = 4.448 N)
            var nValue = valueInLbs * 4.448
            if (nValue >= 1000) {
                // 显示为kN
                return (nValue / 1000).toFixed(1) + " kN"
            } else {
                return nValue.toFixed(0) + " N"
            }
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

    function formatDiameter(valueInInches) {
        if (!valueInInches || valueInInches <= 0) return "N/A"

        if (!isMetric) {
            // 转换为毫米
            var mmValue = valueInInches / 25.4
            return mmValue.toFixed(0) + " in"
        } else {
            // 保持英寸
            return valueInInches.toFixed(2) + " mm"
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
}


