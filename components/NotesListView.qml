import QtQuick

// ---------------------------------------------------------------------------
// NotesListView.qml
//
// The Notes popup: a tiny notebook. Type, add, check off, delete. Everything
// is stored locally and watched live.
Item {
    id: view

    NotchIcons {
        id: icons
    }

    property var host: null
    property var notes: null
    property bool active: false

    readonly property real islandWidth: 460
    readonly property real islandHeight: 462
    readonly property bool wantsKeyboard: true

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    width: islandWidth
    height: islandHeight

    onActiveChanged: {
        if (active) Qt.callLater(function() { input.forceActiveFocus() })
    }

    focus: active
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (host) host.close()
            event.accepted = true
        } else {
            return
        }
    }

    function submit() {
        if (view.notes && input.text.trim() !== "") {
            view.notes.add(input.text)
            input.text = ""
        }
    }

    Breadcrumbs {
        id: crumbs
        host: view.host
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        crumbs: ["Menu", "Notes"]
        onCrumbClicked: function(i) { if (view.host) view.host.open("menu") }
        onCloseRequested: if (view.host) view.host.close()
    }

    // ---- add row -----------------------------------------------------------------
    Rectangle {
        id: addBox
        anchors.top: crumbs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        height: 42
        radius: 21
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: input.activeFocus ? 1 : 0
        border.color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.8)

        NotchIcon {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: icons.noteAdd
            size: 18
            color: view.accentColor
        }

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 44
            anchors.right: addButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: view.textColor
            font.pixelSize: 13
            font.family: view.fontFamily
            clip: true
            selectByMouse: true
            maximumLength: 140
            onAccepted: view.submit()

            Text {
                visible: !parent.text && !parent.activeFocus
                text: "Jot something down\u2026"
                color: view.mutedColor
                font: parent.font
            }
        }

        Rectangle {
            id: addButton
            width: 30
            height: 30
            radius: 15
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: view.accentColor

            NotchIcon {
                anchors.centerIn: parent
                name: icons.noteAdd
                size: 16
                color: view.host ? view.host.colorAccentText : "#000000"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: view.submit()
            }
        }
    }

    // ---- the list ------------------------------------------------------------------
    ListView {
        id: noteList
        anchors.top: addBox.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: footer.top
        anchors.bottomMargin: 14
        spacing: 4
        clip: true
        model: view.notes ? view.notes.notes : []
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: noteRow
            required property var modelData

            width: noteList.width
            height: 40
            radius: 12
            color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)

            Behavior on color {
                ColorAnimation { duration: 120 * view.speed }
            }

            NotchIcon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: noteRow.modelData.done ? icons.checked : icons.unchecked
                size: 18
                color: noteRow.modelData.done ? view.mutedColor : view.accentColor
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.right: delButton.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: String(noteRow.modelData.text || "")
                color: noteRow.modelData.done ? view.mutedColor : view.textColor
                font.pixelSize: 13
                font.family: view.fontFamily
                elide: Text.ElideRight
            }

            Rectangle {
                id: delButton
                width: 24
                height: 24
                radius: 12
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: rowArea.containsMouse
                color: delArea.containsMouse ? Qt.rgba(1, 0.3, 0.25, 0.35) : Qt.rgba(1, 1, 1, 0.08)

                NotchIcon {
                    anchors.centerIn: parent
                    name: icons.close
                    size: 12
                    color: view.textColor
                }

                MouseArea {
                    id: delArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (view.notes) view.notes.remove(noteRow.modelData.id)
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (view.notes) view.notes.toggle(noteRow.modelData.id)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: noteList.count === 0
            text: "Nothing here yet."
            color: view.mutedColor
            font.pixelSize: 12
            font.family: view.fontFamily
        }
    }

    // ---- footer ----------------------------------------------------------------------
    Item {
        id: footer
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: popupNav.top
        anchors.bottomMargin: 8
        height: 20

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: view.notes ? (view.notes.openCount + (view.notes.openCount === 1 ? " open" : " open")) : ""
            color: view.mutedColor
            font.pixelSize: 11
            font.family: view.fontFamily
        }

        Text {
            visible: view.notes && view.notes.notes.length > view.notes.openCount
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear done"
            color: clearArea.containsMouse ? view.textColor : view.mutedColor
            font.pixelSize: 11
            font.family: view.fontFamily

            MouseArea {
                id: clearArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (view.notes) view.notes.clearDone()
            }
        }
    }

    // ---- footer navbar: same shared chrome as every other popup ---------------------------
    PopupNav {
        id: popupNav
        host: view.host
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
