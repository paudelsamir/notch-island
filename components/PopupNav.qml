import QtQuick

// ---------------------------------------------------------------------------
// PopupNav.qml
//
// The shared footer pill: quick jumps to the other popups. Identical in
// every popup (Menu, Music, Power, Settings, Clock) so the chrome matches
// everywhere: 36px pill, 44x30 buttons, 14px Material glyphs.
Item {
    id: nav

    property var host: null

    // Roomy adds breathing room between the buttons and the pill edge.
    // The home (clock hub) keeps the tight original.
    property bool roomy: true

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property real speed: host ? host.motionScale : 1

    NotchIcons {
        id: icons
    }

    // opencode stays one tap away, gated by the same setting the old
    // sticky bar used.
    readonly property bool showAsk: {
        if (!nav.host || !nav.host.settings) return true
        return nav.host.settings.opencode !== false && nav.host.settings.showOpencodeNav !== false
    }

    // Highlight the section we're in, like the tab chips do. Rest surfaces
    // map onto it too: media lights up Music, anything else resting lights
    // up Menu (the hub is the menu).
    readonly property string current: {
        if (!nav.host || !nav.host.view) return ""
        if (nav.host.view !== "rest") return String(nav.host.view)
        if (nav.host.restKind === "media") return "player"
        return "menu"
    }
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"

    implicitWidth: pill.width
    implicitHeight: nav.roomy ? 44 : 36
    width: implicitWidth
    height: implicitHeight
    // Daylight below the pill in popups; the home hub keeps flush chrome.
    anchors.bottomMargin: nav.roomy ? 10 : 0

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: navRow.implicitWidth + (nav.roomy ? 36 : 20)
        height: nav.roomy ? 44 : 36
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.05)

        Row {
            id: navRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: {
                    var items = [
                        { id: "menu", glyph: icons.menu, label: "Menu", brand: false },
                        { id: "player", glyph: icons.player, label: "Music", brand: false },
                        { id: "power", glyph: icons.power, label: "Power", brand: false },
                        { id: "settings", glyph: icons.settings, label: "Settings", brand: false }
                    ]
                    if (nav.showAsk) items.splice(3, 0, { id: "ask", glyph: icons.openCode, label: "opencode", brand: true })
                    return items
                }

                delegate: Item {
                    id: navButton
                    required property var modelData

                    readonly property bool selected: nav.current === navButton.modelData.id

                    width: 44
                    height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 38
                        height: 26
                        radius: 13
                        color: navButton.selected
                               ? Qt.rgba(nav.accentColor.r, nav.accentColor.g, nav.accentColor.b, 0.22)
                               : navArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 120 * nav.speed }
                        }
                    }

                    NotchIcon {
                        anchors.centerIn: parent
                        name: navButton.modelData.glyph
                        family: navButton.modelData.brand ? "brand" : "material"
                        size: 14
                        color: navButton.selected ? nav.accentColor : nav.textColor
                    }

                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (nav.host) nav.host.open(navButton.modelData.id)
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: navButton.modelData.label
                }
            }
        }
    }
}
