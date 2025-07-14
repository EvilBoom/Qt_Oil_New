import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool isChineseMode: true
    property alias model: listView.model

    signal addCasingClicked()
    signal editCasingClicked(var casingData)
    signal deleteCasingClicked(int casingId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 工具栏
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#fafafa"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                Button {
                    text: isChineseMode ? "➕ 添加套管" : "➕ Add Casing"
                    highlighted: true
                    onClicked: root.addCasingClicked()
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: isChineseMode ?
                        `共 ${listView.count} 个套管` :
                        `Total ${listView.count} casings`
                    color: "#666"
                }
            }
        }

        // 列表
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView
                spacing: 0

                delegate: CasingListItem {
                    width: listView.width
                    isChineseMode: root.isChineseMode

                    onEditClicked: function(casingData) {
                        root.editCasingClicked(casingData)
                    }

                    onDeleteClicked: function(casingId) {
                        root.deleteCasingClicked(casingId)
                    }
                }

                // 空状态
                Item {
                    anchors.fill: parent
                    visible: listView.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 20

                        Text {
                            text: "🚧"
                            font.pixelSize: 64
                            color: "#ccc"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: isChineseMode ?
                                "暂无套管数据\n点击上方按钮添加套管" :
                                "No casing data\nClick button above to add casing"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#999"
                            font.pixelSize: 16
                        }
                    }
                }
            }
        }
    }
}
