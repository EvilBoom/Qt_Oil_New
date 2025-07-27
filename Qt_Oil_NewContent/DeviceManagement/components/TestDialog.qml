import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    property var deviceData: null
    property bool isChineseMode: true
    property string formDataJson: ""
    property string model: ""

    title: "Test Dialog"
    width: 400
    height: 300
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel

    onAccepted: {
        if (!root.model || root.model.trim() === "") {
            console.log("Please enter model")
            return
        }
        console.log("Dialog accepted")
    }

    contentItem: ColumnLayout {
        Label {
            text: "Test Dialog Content"
        }
        TextField {
            id: modelField
            placeholderText: "Enter model"
            text: root.model
            onTextChanged: root.model = text
        }
    }
}
