// Qt_Oil_NewContent/DeviceRecommendation/Components/ParameterInputGroup.qml

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Rectangle {
    id: root
    
    property string groupTitle: ""
    property var parameters: []
    property var parametersData: ({})
    property bool isChineseMode: true
    
    signal parameterChanged(string key, string value)
    
    height: contentColumn.height + 24
    color: "transparent"
    border.width: 1
    border.color: Material.dividerColor
    radius: 8
    
    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 16
        
        // 组标题
        Text {
            text: groupTitle
            font.pixelSize: 16
            font.bold: true
            color: Material.primaryTextColor
        }
        
        // 参数输入网格
        GridLayout {
            width: parent.width
            columns: width > 600 ? 2 : 1
            rowSpacing: 12
            columnSpacing: 24
            
            Repeater {
                model: parameters
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    // 参数标签和提示
                    Column {
                        Layout.preferredWidth: 150
                        
                        RowLayout {
                            spacing: 4
                            
                            Text {
                                text: modelData.label + (modelData.required ? " *" : "")
                                color: Material.primaryTextColor
                                font.pixelSize: 14
                            }
                            
                            // 提示图标
                            ToolButton {
                                width: 20
                                height: 20
                                icon.source: "qrc:/images/help.png"
                                visible: modelData.tooltip && modelData.tooltip.length > 0
                                
                                ToolTip {
                                    text: modelData.tooltip || ""
                                    visible: parent.hovered
                                    delay: 500
                                }
                            }
                        }
                        
                        Text {
                            text: "(" + modelData.unit + ")"
                            color: Material.hintTextColor
                            font.pixelSize: 12
                        }
                    }
                    
                    // 输入框
                    TextField {
                        id: inputField
                        Layout.fillWidth: true
                        placeholderText: modelData.placeholder || ""
                        text: parametersData[modelData.key] || ""
                        
                        // 数值输入验证
                        validator: DoubleValidator {
                            bottom: modelData.min || 0
                            top: modelData.max || 999999
                            decimals: 4
                        }
                        
                        // 输入框状态
                        Material.accent: {
                            if (activeFocus) return Material.accent
                            if (text.length > 0) {
                                var value = parseFloat(text)
                                if (isNaN(value) || value < (modelData.min || 0) || value > (modelData.max || 999999)) {
                                    return Material.color(Material.Red)
                                }
                            }
                            return Material.accent
                        }
                        
                        onTextChanged: {
                            root.parameterChanged(modelData.key, text)
                        }
                        
                        // 右侧状态指示
                        rightPadding: statusIcon.width + 8
                        
                        Rectangle {
                            id: statusIcon
                            width: 20
                            height: 20
                            radius: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: parent.text.length > 0
                            
                            color: {
                                var value = parseFloat(parent.text)
                                if (isNaN(value)) return Material.color(Material.Red)
                                if (value < (modelData.min || 0) || value > (modelData.max || 999999)) {
                                    return Material.color(Material.Orange)
                                }
                                return Material.color(Material.Green)
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var value = parseFloat(inputField.text)
                                    if (isNaN(value)) return "!"
                                    if (value < (modelData.min || 0) || value > (modelData.max || 999999)) {
                                        return "!"
                                    }
                                    return "✓"
                                }
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                    
                    // 单位转换按钮（可选）
                    Button {
                        width: 32
                        height: 32
                        flat: true
                        icon.source: "qrc:/images/convert.png"
                        visible: modelData.unit === "psi" || modelData.unit === "°F"
                        
                        onClicked: {
                            // TODO: 打开单位转换对话框
                            console.log("单位转换:", modelData.key)
                        }
                        
                        ToolTip {
                            text: isChineseMode ? "单位转换" : "Unit conversion"
                            visible: parent.hovered
                        }
                    }
                }
            }
        }
    }
}