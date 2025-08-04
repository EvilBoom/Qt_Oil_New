import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// 单位制切换组件
Rectangle {
    id: root

    property bool isMetric: unitSystemController ? unitSystemController.isMetric : true
    property bool isChinese: true
    property bool showLabel: true
    property string labelText: isChinese ? "单位制:" : "Unit System:"
    property color textColor: "#37474F"
    property color accentColor: "#1976D2"

    signal unitSystemChanged(bool isMetric)

    width: layout.width
    height: layout.height
    color: "transparent"

    // 监听控制器变化
    Connections {
        target: unitSystemController
        enabled: unitSystemController !== null

        function onUnitSystemChanged(isMetric) {
            root.isMetric = isMetric
            root.unitSystemChanged(isMetric)
        }
    }

    RowLayout {
        id: layout
        spacing: 20

        // 标签
        Text {
            text: root.labelText
            font.pixelSize: 14
            color: root.textColor
            visible: root.showLabel
        }

        // 🔥 修复：公制选项 - 使用Rectangle包装而不是在Layout中直接放MouseArea
        Rectangle {
            Layout.preferredWidth: metricRow.width
            Layout.preferredHeight: metricRow.height
            color: "transparent"

            RowLayout {
                id: metricRow
                spacing: 8

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: root.accentColor

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: root.accentColor
                        anchors.centerIn: parent
                        visible: root.isMetric
                    }
                }

                Text {
                    text: root.isChinese ? "公制" : "Metric"
                    font.pixelSize: 14
                    color: root.textColor
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (unitSystemController && !root.isMetric) {
                        unitSystemController.isMetric = true
                    }
                }
            }
        }

        // 🔥 修复：英制选项 - 使用Rectangle包装而不是在Layout中直接放MouseArea
        Rectangle {
            Layout.preferredWidth: imperialRow.width
            Layout.preferredHeight: imperialRow.height
            color: "transparent"

            RowLayout {
                id: imperialRow
                spacing: 8

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.width: 2
                    border.color: root.accentColor

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: root.accentColor
                        anchors.centerIn: parent
                        visible: !root.isMetric
                    }
                }

                Text {
                    text: root.isChinese ? "英制" : "Imperial"
                    font.pixelSize: 14
                    color: root.textColor
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (unitSystemController && root.isMetric) {
                        unitSystemController.isMetric = false
                    }
                }
            }
        }
    }
}
