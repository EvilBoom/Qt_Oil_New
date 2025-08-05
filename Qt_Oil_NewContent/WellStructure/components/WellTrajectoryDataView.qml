import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material
import "../../Common/Utils/UnitUtils.js" as UnitUtils

Item {
    id: root

    property bool isChineseMode: true
    property bool hasData: trajectoryModel.count > 0
    // 🔥 添加单位制属性
    property bool isMetric: false

    // 🔥 监听单位制变化
    onIsMetricChanged: {
        console.log("WellTrajectoryDataView单位制切换为:", isMetric ? "公制" : "英制")
        updateDisplayUnits()
    }

    // 数据模型
    ListModel {
        id: trajectoryModel
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 表头
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#f5f7fa"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 0

                Label {
                    Layout.preferredWidth: 60
                    text: isChineseMode ? "序号" : "No."
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ?
                              `垂深 (${getDepthUnit()})` :
                              `TVD (${getDepthUnit()})`
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ?
                        `测深 (${getDepthUnit()})` :
                        `MD (${getDepthUnit()})`
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "狗腿度 (°/30m)" : "DLS (°/100ft)"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "井斜角 (°)" : "Inclination (°)"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "方位角 (°)" : "Azimuth (°)"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Item { Layout.fillWidth: true }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#e0e0e0"
            }
        }

        // 数据列表
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView
                anchors.fill: parent
                model: trajectoryModel
                clip: true

                delegate: Rectangle {
                    width: listView.width
                    height: 35
                    color: index % 2 === 0 ? "white" : "#fafafa"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: "#f0f0f0"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 0

                        Label {
                            Layout.preferredWidth: 60
                            text: model.sequence_number || (index + 1)
                            horizontalAlignment: Text.AlignCenter
                            color: "#666"
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatDepthValue(model.tvd, "ft")  // 假设原始数据是英尺
                            horizontalAlignment: Text.AlignCenter
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatDepthValue(model.md, "ft")  // 假设原始数据是英尺
                            horizontalAlignment: Text.AlignCenter
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatDoglegSeverity(model.dls)
                            horizontalAlignment: Text.AlignCenter
                            color: model.dls > 10 ? "#ff9800" : "#333"
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatAngleValue(model.inclination)
                            horizontalAlignment: Text.AlignCenter
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatAngleValue(model.azimuth)
                            horizontalAlignment: Text.AlignCenter
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // 空状态
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !hasData

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "📊"
                    font.pixelSize: 64
                    color: "#ccc"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: isChineseMode ?
                        "暂无轨迹数据\n请导入Excel文件" :
                        "No trajectory data\nPlease import Excel file"
                    horizontalAlignment: Text.AlignHCenter
                    color: "#999"
                    font.pixelSize: 16
                }
            }
        }
        // 🔥 添加数据统计行
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            color: "#f8f9fa"
            visible: hasData

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 16

                Text {
                    text: isChineseMode ?
                        `数据点: ${trajectoryModel.count}` :
                        `Data points: ${trajectoryModel.count}`
                    font.pixelSize: 12
                    color: "#666"
                }

                Text {
                    text: isChineseMode ?
                        `深度范围: ${getDepthRange()}` :
                        `Depth range: ${getDepthRange()}`
                    font.pixelSize: 12
                    color: "#666"
                }

                Text {
                    text: isChineseMode ?
                        `最大井斜: ${getMaxInclination()}°` :
                        `Max inclination: ${getMaxInclination()}°`
                    font.pixelSize: 12
                    color: "#666"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: isChineseMode ?
                        `单位: ${getDepthUnit()}` :
                        `Unit: ${getDepthUnit()}`
                    font.pixelSize: 12
                    color: "#4a90e2"
                    font.italic: true
                }
            }

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: "#e0e0e0"
            }
        }
    }

    // 🔥 =====================================
    // 🔥 单位转换和格式化函数
    // 🔥 =====================================

    function formatDepthValue(value, sourceUnit) {
        if (value === null || value === undefined || value === 0) {
            return "-"
        }

        var convertedValue = value

        if (sourceUnit === "ft") {
            // 源数据是英尺
            if (isMetric) {
                convertedValue = UnitUtils.feetToMeters(value)
            } else {
                convertedValue = value
            }
        } else if (sourceUnit === "m") {
            // 源数据是米
            if (isMetric) {
                convertedValue = value
            } else {
                convertedValue = UnitUtils.metersToFeet(value)
            }
        }

        return convertedValue.toFixed(1)
    }

    function formatDoglegSeverity(value) {
        if (value === null || value === undefined || value === 0) {
            return "-"
        }

        // 狗腿度转换：°/100ft ↔ °/30m
        var convertedValue = value

        if (isMetric) {
            // 转换为 °/30m
            // 100ft = 30.48m，所以需要调整比例
            convertedValue = value * (30.48 / 30)
        }
        // 英制保持原值 (°/100ft)

        return convertedValue.toFixed(2)
    }

    function formatAngleValue(value) {
        if (value === null || value === undefined) {
            return "-"
        }
        return value.toFixed(2)
    }

    function getDepthUnit() {
        return isMetric ? "m" : "ft"
    }

    function getDoglegColor(dls) {
        if (!dls || dls === 0) return "#333"

        // 根据狗腿度严重程度设置颜色
        var threshold = isMetric ? 10.16 : 10  // 调整公制阈值

        if (dls > threshold * 1.5) return "#f44336"      // 红色 - 严重
        if (dls > threshold) return "#ff9800"            // 橙色 - 警告
        return "#4caf50"                                 // 绿色 - 正常
    }

    function getDepthRange() {
        if (trajectoryModel.count === 0) return "-"

        var minDepth = Number.MAX_VALUE
        var maxDepth = 0

        for (var i = 0; i < trajectoryModel.count; i++) {
            var item = trajectoryModel.get(i)
            var depth = item.md || 0
            if (depth > 0) {
                minDepth = Math.min(minDepth, depth)
                maxDepth = Math.max(maxDepth, depth)
            }
        }

        if (minDepth === Number.MAX_VALUE) return "-"

        // 转换并格式化深度范围
        var minFormatted = formatDepthValue(minDepth, "ft")
        var maxFormatted = formatDepthValue(maxDepth, "ft")

        return `${minFormatted} - ${maxFormatted} ${getDepthUnit()}`
    }

    function getMaxInclination() {
        if (trajectoryModel.count === 0) return "0"

        var maxInclination = 0
        for (var i = 0; i < trajectoryModel.count; i++) {
            var item = trajectoryModel.get(i)
            var inclination = item.inclination || 0
            maxInclination = Math.max(maxInclination, inclination)
        }

        return maxInclination.toFixed(1)
    }

    function updateDisplayUnits() {
        console.log("更新轨迹数据显示单位")
        // 强制刷新列表显示
        if (trajectoryModel.count > 0) {
            listView.model = null
            listView.model = trajectoryModel
        }
    }

    // 更新数据
    function updateData(trajectoryData) {
        trajectoryModel.clear()

        for (var i = 0; i < trajectoryData.length; i++) {
            var data = trajectoryData[i]
            trajectoryModel.append({
                sequence_number: data.sequence_number || (i + 1),
                tvd: data.tvd || 0,
                md: data.md || 0,
                dls: data.dls || 0,
                inclination: data.inclination || 0,
                azimuth: data.azimuth || 0,
                north_south: data.north_south || 0,
                east_west: data.east_west || 0
            })
        }
    }

    // 格式化数字
    function formatNumber(value) {
        if (value === null || value === undefined || value === 0) {
            return "-"
        }
        return value.toFixed(2)
    }

    // 导出数据
    function exportData() {
        // TODO: 实现数据导出功能
        console.log("Export trajectory data with current unit system:", isMetric ? "Metric" : "Imperial")

        // 这里可以调用控制器的导出方法
        if (typeof wellStructureController !== "undefined") {
            var exportData = {
                trajectoryData: trajectoryModel,
                unitSystem: isMetric ? "metric" : "imperial",
                depthUnit: getDepthUnit()
            }
            // wellStructureController.exportTrajectoryData(exportData)
        }
    }

    // 🔥 添加数据验证函数
    function validateData() {
        var issues = []

        for (var i = 0; i < trajectoryModel.count; i++) {
            var item = trajectoryModel.get(i)

            // 检查数据完整性
            if (!item.md || item.md <= 0) {
                issues.push(`第 ${i+1} 行: 测深数据无效`)
            }

            // 检查狗腿度
            if (item.dls > (isMetric ? 15 : 15)) {
                issues.push(`第 ${i+1} 行: 狗腿度过高 (${item.dls.toFixed(2)})`)
            }

            // 检查井斜角范围
            if (item.inclination < 0 || item.inclination > 90) {
                issues.push(`第 ${i+1} 行: 井斜角超出正常范围 (${item.inclination.toFixed(2)}°)`)
            }
        }

        return issues
    }

    // 🔥 添加搜索/过滤功能
    function filterByDepthRange(minDepth, maxDepth) {
        // 实现深度范围过滤
        console.log(`过滤深度范围: ${minDepth} - ${maxDepth} ${getDepthUnit()}`)
    }

    function filterByInclination(maxInclination) {
        // 实现井斜角过滤
        console.log(`过滤井斜角: < ${maxInclination}°`)
    }
}
