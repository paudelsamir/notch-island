import QtQuick

// ---------------------------------------------------------------------------
// DockSlot.qml
//
// One app in the dock.
//
//   left click    focus / cycle windows / launch when closed
//   middle click  launch a new window of the app
//   right click   pin / unpin
//
// The slot is a square cell whose size is `iconSize * magnification`. The
// icon inside is drawn at the full cell size, so magnifying the cell magnifies
// the icon. Cells only ever grow along the dock axis; the cross axis is
// reserved by the dock so the island never changes thickness while you hover.
//
// A row of state dots sits on the side that faces into the screen:
//   one dot  = the app is open,   two dots = two or more windows
//   accent   = focused app,       muted    = open but not focused
// ---------------------------------------------------------------------------
Item {
    id: slot

    property var host: null
    property var app: null            // { id, name, icon, count, active, pinned, entry }
    property real iconSize: 32
    property real magnification: 1    // 1 .. magnifyScale, set by the dock
    property bool vertical: false     // dock runs along a side edge
    property string edge: "top"       // which screen edge the dock is on
    property bool showDots: true
    // auto = edge-aware (under the icon on top edges, over it on bottom),
    // above / below force one side in screen coordinates.
    property string dotsSide: "auto"
    property bool showName: true
    property int badge: 0

    signal activated()
    signal newWindow()
    signal pinToggled()

    readonly property real cell: iconSize * magnification
    readonly property bool hovered: mouse.containsMouse
    readonly property int windowCount: app ? app.count : 0
    readonly property bool isOpen: windowCount > 0
    readonly property bool isActive: app ? app.active : false

    // size along the dock axis follows the magnification; the other axis is
    // fixed by the dock (`crossSize`)
    property real crossSize: iconSize
    width: vertical ? crossSize : cell
    height: vertical ? cell : crossSize

    Behavior on magnification {
        NumberAnimation { duration: 90 * (host ? host.motionScale : 1); easing.type: Easing.OutCubic }
    }

    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property real speed: host ? host.motionScale : 1

    // ---- hover plate -------------------------------------------------------
    Rectangle {
        anchors.centerIn: icon
        width: icon.width + 10
        height: icon.height + 10
        radius: Math.min(width, height) * 0.28
        color: Qt.rgba(1, 1, 1, slot.hovered ? 0.09 : 0)

        Behavior on color {
            ColorAnimation { duration: 140 * slot.speed }
        }
    }

    // ---- the icon ---------------------------------------------------------------
    AppIcon {
        id: icon
        size: slot.cell
        iconName: slot.app ? slot.app.icon : ""
        entry: slot.app ? slot.app.entry : null
        iconIndex: slot.host ? slot.host.iconIndex : null
        label: slot.app ? slot.app.name : ""
        badge: slot.badge
        // closed pinned apps are slightly dimmed
        monochrome: slot.app && slot.app.pinned && !slot.isOpen && !slot.hovered

        // anchor to the middle of the cross axis
        x: slot.vertical ? (slot.width - width) / 2 : 0
        y: slot.vertical ? 0 : (slot.height - height) / 2

        Behavior on size {
            NumberAnimation { duration: 90 * slot.speed; easing.type: Easing.OutCubic }
        }
    }

    // ---- state dots ---------------------------------------------------------------
    // Drawn against the edge of the island that faces the screen centre so the
    // dots never sit between the icon and the screen border.
    // Horizontal docks stack them in a row under/over the icon; vertical
    // docks stack them in a column to the side, active dot elongated along
    // the dock axis either way.
    Grid {
        id: dots
        visible: slot.showDots && slot.isOpen
        flow: slot.vertical ? Grid.TopToBottom : Grid.LeftToRight
        rows: slot.vertical ? 2 : 1
        columns: slot.vertical ? 1 : 2
        spacing: 3
        z: 2

        x: slot.vertical
           ? (slot.edge === "left" ? slot.width - 4 : 1)
           : (slot.width - width) / 2
        // Auto keeps the edge-aware side; above/below pin it in screen
        // coordinates on horizontal docks.
        y: slot.vertical || slot.dotsSide === "auto"
           ? (slot.vertical
              ? (slot.height - height) / 2
              : (slot.edge === "top" ? slot.height - 4 : 1))
           : (slot.dotsSide === "above" ? 1 : slot.height - 4)

        Repeater {
            model: Math.min(2, slot.windowCount)

            delegate: Rectangle {
                width: slot.vertical ? 3 : (slot.isActive && index === 0 ? 12 : 3)
                height: slot.vertical ? (slot.isActive && index === 0 ? 12 : 3) : 3
                radius: 1.5
                color: slot.isActive ? slot.accentColor : slot.mutedColor
                opacity: slot.isActive ? 1 : 0.85

                Behavior on color {
                    ColorAnimation { duration: 160 * slot.speed }
                }
            }
        }
    }

    // ---- interaction ----------------------------------------------------------------
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: function(event) {
            if (event.button === Qt.LeftButton) {
                icon.bounce()
                slot.activated()
            } else if (event.button === Qt.MiddleButton) {
                icon.bounce()
                slot.newWindow()
            } else if (event.button === Qt.RightButton) {
                slot.pinToggled()
            }
        }
    }

    // ---- name tag ------------------------------------------------------------------------
    // The dock is clipped to the island, so instead of a floating tooltip the
    // hovered app name is reported to the host, which shows it in the dock's
    // label line when there is room.
    onHoveredChanged: {
        if (!host) return
        if (hovered && app) host.dockHoverName = app.name + (app.pinned ? "" : "  \u00B7  right-click to pin")
        else if (host.dockHoverName.indexOf(app ? app.name : "\u0000") === 0) host.dockHoverName = ""
    }


    // ---- launch feedback ------------------------------------------------------------------
    // After clicking a closed app the icon pulses until its first window shows
    // up (or four seconds pass, whichever comes first).
    property bool launching: false

    Timer {
        id: launchTimeout
        interval: 4000
        repeat: false
        onTriggered: slot.launching = false
    }

    onActivated: {
        if (!isOpen) {
            launching = true
            launchTimeout.restart()
        }
    }

    onNewWindow: {
        launching = true
        launchTimeout.restart()
    }

    onIsOpenChanged: {
        if (isOpen) {
            launching = false
            launchTimeout.stop()
        }
    }

    Binding {
        target: icon
        property: "loading"
        value: slot.launching
    }

    // The focused app gets a faint halo so it is easy to spot in a long dock.
    Binding {
        target: icon
        property: "glow"
        value: slot.isActive
    }

    Binding {
        target: icon
        property: "glowColor"
        value: slot.accentColor
    }

    // Press feedback: the whole slot dips a little while the button is down.
    scale: mouse.pressed ? 0.92 : 1

    Behavior on scale {
        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    // Accessibility: expose the app name and state to screen readers.
    Accessible.role: Accessible.Button
    Accessible.name: app ? app.name + (isOpen ? " (" + windowCount + " open)" : "") : ""
    Accessible.onPressAction: slot.activated()
}
