// Qt_Oil_NewContent/DeviceRecommendation/Components/SeparatorCard.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material


Rectangle {
    id: root
    
    property var separatorData: null
    property bool isSelected: false
    property int matchScore: 50
    property bool isChineseMode: true
    // 🔥 添加单位制属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : false
    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            console.log("SeparatorCard中单位制切换为:", isMetric ? "公制" : "英制")
        }
    }
    signal clicked()
    color: isSelected ? '#F5F5DC' : Material.backgroundColor
    radius: 8
    border.width: isSelected ? 2 : 1
    border.color: isSelected ? Material.DeepPurple : Material.Brown
    
    // 推荐标识
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 1
        width: 60
        height: 20
        radius: 12
        color: Material.Green
        visible: matchScore >= 80 && !separatorData.isNoSeparator
        
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
                color: separatorData && separatorData.isNoSeparator 
                       ? Material.color(Material.Grey) 
                       : Material.color(Material.Blue)
                
                Text {
                    anchors.centerIn: parent
                    text: separatorData && separatorData.isNoSeparator ? "⊘" : "🔄"
                    font.pixelSize: 20
                }
            }
            
            // 标题
            Column {
                Layout.fillWidth: true
                
                Text {
                    text: separatorData ? separatorData.manufacturer : ""
                    font.pixelSize: 12
                    color: Material.hintTextColor
                }
                
                Text {
                    text: separatorData ? separatorData.model : ""
                    font.pixelSize: 15
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
            
            // 匹配度（不显示给"不使用"选项）
            CircularProgress {
                width: 40
                height: 40
                value: matchScore / 100
                visible: !separatorData.isNoSeparator
                
                Text {
                    anchors.centerIn: parent
                    text: matchScore + "%"
                    font.pixelSize: 11
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }
        
        // 描述
        Text {
            Layout.fillWidth: true
            text: separatorData ? separatorData.description : ""
            font.pixelSize: 12
            color: Material.secondaryTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        
        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Material.dividerColor
            visible: !separatorData.isNoSeparator
        }
        
        // 关键参数（不显示给"不使用"选项）
        Grid {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 8
            visible: !separatorData.isNoSeparator
            
            // 分离效率
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "分离效率" : "Efficiency"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Row {
                    spacing: 4
                    
                    Rectangle {
                        width: 24
                        height: 4
                        radius: 2
                        color: Material.color(Material.Green)
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: parent.width * (separatorData ? separatorData.separationEfficiency / 100 : 0)
                            height: parent.height
                            radius: parent.radius
                            color: Material.color(Material.LightGreen)
                        }
                    }
                    
                    Text {
                        text: (separatorData ? separatorData.separationEfficiency : 0) + "%"
                        font.pixelSize: 12
                        font.bold: true
                        color: Material.primaryTextColor
                    }
                }
            }
            
            // 气体处理能力
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "气体处理" : "Gas Capacity"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Text {
                    text: {
                        if (!separatorData) return "N/A"
                        return formatGasCapacity(separatorData.gasHandlingCapacity)
                    }
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
            
            // 液体处理能力
            Column {
                spacing: 2
                
                Text {
                    text: {
                        if (!separatorData) return "N/A"
                        return formatFlowRate(separatorData.liquidHandlingCapacity)
                    }
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Text {
                    text: (separatorData ? separatorData.liquidHandlingCapacity : 0) + " bbl/d"
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
            
            // 外径
            Column {
                spacing: 2
                
                Text {
                    text: isChineseMode ? "外径" : "OD"
                    font.pixelSize: 11
                    color: Material.hintTextColor
                }
                
                Text {
                    text: {
                        if (!separatorData) return "N/A"
                        return formatDiameter(separatorData.outerDiameter)
                    }
                    font.pixelSize: 12
                    font.bold: true
                    color: Material.primaryTextColor
                }
            }
        }
    }
    
    // 选中效果
    Rectangle {
        anchors.fill: parent
        color: Material.accent
        opacity: 0.1
        radius: parent.radius
        visible: isSelected
    }
    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatFlowRate(valueInBbl) {
        if (!valueInBbl || valueInBbl <= 0) return "N/A"

        if (isMetric) {
            // 转换为 m³/d
            var m3Value = valueInBbl * 0.159
            return m3Value.toFixed(1) + " m³/d"
        } else {
            // 保持 bbl/d
            return valueInBbl.toFixed(0) + " bbl/d"
        }
    }

    function formatGasCapacity(valueInMcf) {
        if (!valueInMcf || valueInMcf <= 0) return "N/A"

        if (isMetric) {
            // 转换为 m³/d (1 mcf = 28.317 m³)
            var m3Value = valueInMcf * 28.317
            return m3Value.toFixed(0) + " m³/d"
        } else {
            // 保持 mcf/d
            return valueInMcf.toFixed(1) + " mcf/d"
        }
    }

    function formatDiameter(valueInInches) {
        if (!valueInInches || valueInInches <= 0) return "N/A"

        if (isMetric) {
            // 转换为毫米
            var mmValue = valueInInches * 25.4
            return mmValue.toFixed(0) + " mm"
        } else {
            // 保持英寸
            return valueInInches.toFixed(1) + " in"
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

    function formatPressure(valueInPsi) {
        if (!valueInPsi || valueInPsi <= 0) return "N/A"

        if (isMetric) {
            // 转换为MPa
            var mpaValue = valueInPsi / 145.038
            return mpaValue.toFixed(1) + " MPa"
        } else {
            // 保持psi
            return valueInPsi.toFixed(0) + " psi"
        }
    }
}

