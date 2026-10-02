import QtQuick

// ---------------------------------------------------------------------------
// PopupNavBar.qml
//
// A small floating navigation bar pinned to the bottom of every popup. It is
// the sticky way to move between Now Playing, opencode, Power and Settings
// without returning to the menu first.
Item {
    id: nav

    property var host: null
    property string current: ""

    readonly property real speed: host ? host.motionScale : 1
    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"

    NotchIcons {
        id: icons
    }

    readonly property var entries: {
        var items = [
            { id: "menu",     name: icons.menu,     family: "material", tint: nav.accentColor, label: "Menu" },
            { id: "player",   name: icons.player,   family: "material", tint: nav.accentColor, label: "Now Playing" },
            { id: "ask",      name: icons.openCode, family: "brand",    tint: nav.accentColor, label: "opencode" },
            { id: "power",     name: icons.power,    family: "material", tint: nav.accentColor, label: "Power" },
            { id: "settings",  name: icons.settings, family: "material", tint: nav.accentColor, label: "Settings" }
        ]
        var showAsk = true
        if (nav.host && nav.host.settings) {
            showAsk = nav.host.settings.opencode !== false && nav.host.settings.showOpencodeNav !== false
        }
        if (!showAsk) {
            return items.filter(function(item) { return item.id !== "ask" })
        }
        return items
    }

    implicitWidth: buttons.implicitWidth + 28
    implicitHeight: 56
    width: implicitWidth
    height: implicitHeight

    // A floating pill so the navigation reads separately from popup content.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.52)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        Behavior on color {
            ColorAnimation { duration: 160 * nav.speed }
        }
    }

    Row {
        id: buttons
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: nav.entries

            delegate: Item {
                id: button
                required property var modelData

                readonly property bool isCurrent: nav.current === modelData.id

                width: 52
                height: 46

                Rectangle {
                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    radius: 21
                    color: button.isCurrent ? Qt.rgba(1, 1, 1, 0.16)
                         : buttonArea.pressed ? Qt.rgba(1, 1, 1, 0.18)
                         : buttonArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10)
                         : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 130 * nav.speed }
                    }
                }

                NotchIcon {
                    anchors.centerIn: parent
                    name: button.modelData.name
                    family: button.modelData.family
                    size: 23
                    color: button.isCurrent ? button.modelData.tint : nav.textColor
                }

                MouseArea {
                    id: buttonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!nav.host) return
                        if (button.modelData.id === "settings" && nav.host.view === "settings") {
                            nav.host.settingsPage = ""
                        } else {
                            nav.host.open(button.modelData.id)
                        }
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: button.modelData.label + (button.isCurrent ? ", current" : "")
            }
        }
    }
}
