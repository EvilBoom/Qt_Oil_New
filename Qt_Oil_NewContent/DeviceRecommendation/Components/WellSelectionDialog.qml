import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: wellDialog
    title: "请选择井信息"
    modal: true
    property var wellsList: []
    property var selectedWell: null

    signal wellConfirmed(var well)

    standardButtons: Dialog.Ok | Dialog.Cancel

    contentItem: Column {
        spacing: 10
        width: 300

        ComboBox {
            id: wellCombo
            width: parent.width
            model: wellDialog.wellsList
            textRole: "name"
            onCurrentIndexChanged: {
                wellDialog.selectedWell = wellDialog.wellsList[wellCombo.currentIndex]
            }
        }

        Text {
            text: wellDialog.selectedWell ? "已选井: " + wellDialog.selectedWell.name : "请选择井"
            color: "gray"
        }
    }

    onAccepted: {
        if (selectedWell) {
            wellConfirmed(selectedWell)
        }
    }
}