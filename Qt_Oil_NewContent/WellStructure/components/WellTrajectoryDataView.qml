import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Item {
    id: root

    property bool isChineseMode: true
    property bool hasData: trajectoryModel.count > 0

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
                    text: isChineseMode ? "垂深 (ft)" : "TVD (ft)"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "测深 (ft)" : "MD (ft)"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "狗腿度" : "DLS"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "井斜角" : "Inclination"
                    font.bold: true
                    horizontalAlignment: Text.AlignCenter
                }

                Label {
                    Layout.preferredWidth: 100
                    text: isChineseMode ? "方位角" : "Azimuth"
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
                            text: formatNumber(model.tvd)
                            horizontalAlignment: Text.AlignCenter
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatNumber(model.md)
                            horizontalAlignment: Text.AlignCenter
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatNumber(model.dls)
                            horizontalAlignment: Text.AlignCenter
                            color: model.dls > 10 ? "#ff9800" : "#333"
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatNumber(model.inclination)
                            horizontalAlignment: Text.AlignCenter
                        }

                        Label {
                            Layout.preferredWidth: 100
                            text: formatNumber(model.azimuth)
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
        console.log("Export trajectory data")
    }
}
