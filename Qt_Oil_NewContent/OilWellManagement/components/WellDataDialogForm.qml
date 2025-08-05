// Qt_Oil_NewContent/OilWellManagement/components/WellDataDialogForm.ui.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: 600
    height: 500
    color: "#ffffff"

    // 🔥 添加单位制相关属性
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : true
    property bool isChinese: true

    property alias wellNameField: wellNameField
    property alias depthField: depthField
    property alias wellTypeCombo: wellTypeCombo
    property alias wellStatusCombo: wellStatusCombo
    property alias innerDiameterField: innerDiameterField
    property alias outerDiameterField: outerDiameterField
    property alias pumpDepthField: pumpDepthField
    property alias tubingDiameterField: tubingDiameterField
    property alias notesArea: notesArea

    // 🔥 监听单位制变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            // 可以在这里触发数值转换
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 20

            // 基本信息组
            GroupBox {
                Layout.fillWidth: true
                title: isChinese ? "基本信息" : "Basic Information"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: isChinese ? "井号 *" : "Well Name *"
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: wellNameField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入井号" : "Enter well name"
                    }

                    Label {
                        text: `${isChinese ? "井深" : "Depth"} (${getDepthUnit()}) *`
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: depthField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入井深" : "Enter depth"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: isChinese ? "井型" : "Well Type"
                        Layout.alignment: Qt.AlignRight
                    }

                    ComboBox {
                        id: wellTypeCombo
                        Layout.fillWidth: true
                        model: isChinese ? ["直井", "定向井", "水平井"] : ["Vertical", "Directional", "Horizontal"]
                    }

                    Label {
                        text: isChinese ? "井状态" : "Well Status"
                        Layout.alignment: Qt.AlignRight
                    }

                    ComboBox {
                        id: wellStatusCombo
                        Layout.fillWidth: true
                        model: isChinese ? ["生产", "关停", "维修"] : ["Production", "Shut-in", "Maintenance"]
                    }
                }
            }

            // 结构参数组
            GroupBox {
                Layout.fillWidth: true
                title: isChinese ? "结构参数" : "Structure Parameters"

                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20

                    Label {
                        text: `${isChinese ? "内径" : "Inner Diameter"} (${getDiameterUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: innerDiameterField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入内径" : "Enter inner diameter"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: `${isChinese ? "外径" : "Outer Diameter"} (${getDiameterUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: outerDiameterField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入外径" : "Enter outer diameter"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: `${isChinese ? "泵挂深度" : "Pump Depth"} (${getDepthUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: pumpDepthField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入泵挂深度" : "Enter pump depth"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }

                    Label {
                        text: `${isChinese ? "管径" : "Tubing Diameter"} (${getDiameterUnit()})`
                        Layout.alignment: Qt.AlignRight
                    }

                    TextField {
                        id: tubingDiameterField
                        Layout.fillWidth: true
                        placeholderText: isChinese ? "请输入管径" : "Enter tubing diameter"
                        validator: DoubleValidator {
                            bottom: 0
                        }
                    }
                }
            }

            // 备注
            GroupBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                title: isChinese ? "备注信息" : "Notes"

                ScrollView {
                    anchors.fill: parent

                    TextArea {
                        id: notesArea
                        placeholderText: isChinese ? "请输入备注信息..." : "Enter notes..."
                        wrapMode: TextArea.Wrap
                    }
                }
            }
        }
    }

    // 🔥 添加单位获取函数
    function getDepthUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("depth")
        }
        return isMetric ? "m" : "ft"
    }

    function getDiameterUnit() {
        if (unitSystemController) {
            return unitSystemController.getUnitLabel("diameter")
        }
        return isMetric ? "mm" : "in"
    }

    function getDepthUnitText() {
        if (unitSystemController) {
            return unitSystemController.getUnitDisplayText("depth", isChinese)
        }
        if (isMetric) {
            return isChinese ? "米" : "m"
        } else {
            return isChinese ? "英尺" : "ft"
        }
    }

    function getDiameterUnitText() {
        if (unitSystemController) {
            return unitSystemController.getUnitDisplayText("diameter", isChinese)
        }
        if (isMetric) {
            return isChinese ? "毫米" : "mm"
        } else {
            return isChinese ? "英寸" : "in"
        }
    }
}
