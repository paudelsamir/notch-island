import QtQuick

// ---------------------------------------------------------------------------
// PowerMenuView.qml
//
// Menu › Power
//
//   [ Lock ] [ Sleep ] [ Log out ]
//   [ Restart ] [ Shut down ] [ Hibernate ]
//
// Destructive actions (log out, restart, shut down) need a second press:
// the tile turns red and shows "Press again" for three seconds. Lock and
// sleep run immediately.
//
// Keyboard: arrows move the selection, Enter runs, Esc goes back.
// Battery and uptime are shown in a footer line.
// ---------------------------------------------------------------------------
Item {
    id: view

    NotchIcons {
        id: icons
    }

    property var host: null
    property var sys: null           // SystemControls service
    property bool active: false

    readonly property real islandWidth: 420
    readonly property real islandHeight: 354
    readonly property bool wantsKeyboard: true

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property color urgentColor: host ? host.colorUrgent : "#ff5555"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    width: islandWidth
    height: islandHeight

    // ---- actions ----------------------------------------------------------------
    readonly property var actions: [
        { id: "lock",      label: "Lock",      glyph: icons.lock,      danger: false },
        { id: "suspend",   label: "Sleep",     glyph: icons.sleep,     danger: false },
        { id: "logout",    label: "Log out",   glyph: icons.logout,    danger: true },
        { id: "reboot",    label: "Restart",   glyph: icons.restart,   danger: true },
        { id: "shutdown",  label: "Shut down", glyph: icons.shutdown,  danger: true },
        { id: "hibernate", label: "Hibernate", glyph: icons.hibernate, danger: false }
    ]

    property int selected: 0
    property string armed: ""         // id of the action waiting for a second press

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: view.armed = ""
    }

    function run(index) {
        var a = actions[index]
        if (!a) return
        if (a.danger && armed !== a.id) {
            armed = a.id
            armTimer.restart()
            return
        }
        armed = ""
        armTimer.stop()
        if (sys) sys.power(a.id)
        if (host) host.close()
    }

    onActiveChanged: {
        armed = ""
        selected = 0
        if (active && sys) sys.refreshUptime()
    }

    // ---- keyboard --------------------------------------------------------------------
    focus: active
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right) selected = (selected + 1) % actions.length
        else if (event.key === Qt.Key_Left) selected = (selected + actions.length - 1) % actions.length
        else if (event.key === Qt.Key_Down) selected = (selected + 3) % actions.length
        else if (event.key === Qt.Key_Up) selected = (selected + actions.length - 3) % actions.length
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) run(selected)
        else if (event.key === Qt.Key_Escape) { if (host) host.close() }
        else return
        event.accepted = true
    }

    // ---- header -------------------------------------------------------------------------
    Breadcrumbs {
        id: crumbs
        host: view.host
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        crumbs: ["Menu", "Power"]
        onCrumbClicked: function(i) { if (view.host) view.host.open("menu") }
        onCloseRequested: if (view.host) view.host.close()
    }

    // ---- tile grid ------------------------------------------------------------------------
    Grid {
        id: grid
        anchors.top: crumbs.bottom
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 3
        spacing: 10

        Repeater {
            model: view.actions

            delegate: Rectangle {
                id: tile
                required property int index
                required property var modelData

                readonly property bool isSelected: view.selected === index
                readonly property bool isArmed: view.armed === modelData.id

                width: 122
                height: 80
                radius: 18

                color: isArmed ? view.urgentColor
                     : tileArea.pressed ? Qt.rgba(1, 1, 1, 0.18)
                     : (tileArea.containsMouse || isSelected) ? Qt.rgba(1, 1, 1, 0.12)
                     : Qt.rgba(1, 1, 1, 0.06)

                border.width: isSelected && !isArmed ? 1 : 0
                border.color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.7)

                Behavior on color {
                    ColorAnimation { duration: 140 * view.speed }
                }

                scale: tileArea.pressed ? 0.95 : 1
                Behavior on scale {
                    NumberAnimation { duration: 110 * view.speed; easing.type: Easing.OutCubic }
                }

                // shake a little when armed, to draw the eye
                SequentialAnimation on rotation {
                    running: tile.isArmed
                    loops: 2
                    NumberAnimation { to: -1.5; duration: 60 }
                    NumberAnimation { to: 1.5; duration: 60 }
                    NumberAnimation { to: 0; duration: 60 }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    NotchIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: tile.modelData.glyph
                        size: 30
                        color: tile.isArmed ? "#ffffff" : view.textColor
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.isArmed ? "Press again" : tile.modelData.label
                        color: tile.isArmed ? "#ffffff" : view.textColor
                        font.pixelSize: 12
                        font.weight: tile.isArmed ? Font.Bold : Font.Normal
                        font.family: view.fontFamily
                    }
                }

                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: view.selected = tile.index
                    onClicked: view.run(tile.index)
                }
            }
        }
    }

    // ---- footer: battery on the left, uptime on the right -------------------------------
    Item {
        id: footer
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: popupNav.top
        anchors.bottomMargin: 8
        height: 20

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: view.sys && view.sys.hasBattery

            NotchIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: icons.batteryName(view.sys ? view.sys.batteryPercent : 0, view.sys ? view.sys.charging : false)
                size: 16
                color: view.mutedColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(view.sys ? view.sys.batteryPercent : 0) + "%"
                color: view.mutedColor
                font.pixelSize: 11
                font.family: view.fontFamily
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: view.sys && view.sys.uptime !== ""
            text: "up " + (view.sys ? view.sys.uptime : "")
            color: view.mutedColor
            font.pixelSize: 11
            font.family: view.fontFamily
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
