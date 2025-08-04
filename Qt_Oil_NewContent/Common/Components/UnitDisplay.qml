import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 带单位的数值显示组件
Rectangle {
    id: root

    property real value: 0
    property string unitType: "depth" // depth, diameter, pressure, temperature, flow, density
    property bool isChinese: true
    property bool isMetric: unitSystemController ? unitSystemController.isMetric : true
    property int decimals: 2
    property bool showUnit: true
    property bool convertValue: true
    property color textColor: "#37474F"
    property color unitColor: "#666666"
    property int fontSize: 14
    property bool bold: false

    width: displayLayout.width
    height: displayLayout.height
    color: "transparent"

    RowLayout {
        id: displayLayout
        spacing: 4

        Text {
            text: getDisplayValue()
            font.pixelSize: root.fontSize
            font.bold: root.bold
            color: root.textColor
        }

        Text {
            text: getUnitText()
            font.pixelSize: root.fontSize - 2
            color: root.unitColor
            visible: root.showUnit
        }
    }

    function getDisplayValue() {
        if (!root.convertValue || !unitSystemController) {
            return root.value.toFixed(root.decimals)
        }

        var convertedValue = unitSystemController.convertValue(root.value, root.unitType)
        return convertedValue.toFixed(root.decimals)
    }

    function getUnitText() {
        if (unitSystemController) {
            return unitSystemController.getUnitDisplayText(root.unitType, root.isChinese)
        }

        // 备用显示
        if (root.isMetric) {
            var metricUnits = {
                "depth": root.isChinese ? "米" : "m",
                "diameter": root.isChinese ? "毫米" : "mm",
                "pressure": root.isChinese ? "千帕" : "kPa",
                "temperature": root.isChinese ? "摄氏度" : "°C",
                "flow": root.isChinese ? "立方米/天" : "m³/d",
                "density": root.isChinese ? "千克/立方米" : "kg/m³"
            }
            return metricUnits[root.unitType] || ""
        } else {
            var imperialUnits = {
                "depth": root.isChinese ? "英尺" : "ft",
                "diameter": root.isChinese ? "英寸" : "in",
                "pressure": root.isChinese ? "磅/平方英寸" : "psi",
                "temperature": root.isChinese ? "华氏度" : "°F",
                "flow": root.isChinese ? "桶/天" : "bbl/d",
                "density": root.isChinese ? "磅/立方英尺" : "lb/ft³"
            }
            return imperialUnits[root.unitType] || ""
        }
    }
}
