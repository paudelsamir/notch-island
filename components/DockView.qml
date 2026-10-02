import QtQuick

// ---------------------------------------------------------------------------
// DockView.qml
//
// The resting state of the notch: the app dock.
//
//   [ menu ] [ pinned apps ... ] | [ running, not pinned ... ]
//
// The dock runs horizontally on the top/bottom edges and vertically on the
// left/right edges. Magnification is computed from the pointer position along
// the dock axis, using the *unmagnified* slot centres so the result does not
// feed back into itself and jitter.
//
// The dock reports the size it wants through islandWidth / islandHeight; the
// notch animates its own shell to that size.
// ---------------------------------------------------------------------------
Item {
    id: dock

    property var host: null
    property var model: null          // DockModel service
    property bool active: true

    readonly property var s: host ? host.settings : null
    readonly property bool vertical: host ? !host.horiz : false
    readonly property string edge: host ? host.edge : "top"

    // ---- geometry ------------------------------------------------------------
    readonly property real iconSize: s ? s.iconSize : 30
    readonly property real spacing: s ? s.dockSpacing : 6
    readonly property real pad: s ? s.dockPadding : 8
    readonly property bool magnify: s ? s.magnify : true
    readonly property real magnifyScale: magnify ? (s ? s.magnifyScale : 1.3) : 1
    readonly property real reach: 2.2      // in slots

    readonly property var apps: model ? model.apps : []

    // The cross axis has room for the biggest possible icon.
    readonly property real crossSize: iconSize * magnifyScale
    readonly property real thickness: crossSize + pad * 2

    // the menu button counts as a slot at the start of the dock
    readonly property int slotCount: apps.length + 1
    readonly property real separatorSpace: separatorIndex > 0 ? spacing + 8 : 0

    // index (in apps) where the unpinned apps begin, -1 if none
    readonly property int separatorIndex: {
        var idx = -1
        for (var i = 0; i < apps.length; i++) {
            if (!apps[i].pinned) { idx = i; break }
        }
        return idx > 0 ? idx : -1
    }

    // Length along the dock axis. Magnified slots are wider than resting ones,
    // so this grows a little while you hover.
    property real lengthAlong: pad * 2 + row.implicitLength

    readonly property real islandWidth: vertical ? thickness : lengthAlong
    readonly property real islandHeight: vertical ? lengthAlong : thickness

    // ---- pointer tracking ----------------------------------------------------------
    property real pointer: -1000              // coordinate along the dock axis
    readonly property real step: iconSize + spacing

    // Centre of slot i (0 = menu button) at rest, in dock coordinates.
    function baseCenter(i) {
        var extra = separatorIndex >= 0 && i - 1 >= separatorIndex ? separatorSpace : 0
        return pad + i * step + iconSize / 2 + extra
    }

    // Gaussian falloff, like the macOS dock.
    function scaleFor(i) {
        if (!magnify || pointer < -500) return 1
        var d = Math.abs(pointer - baseCenter(i)) / step
        if (d > reach) return 1
        var t = Math.exp(-(d * d) / 1.6)
        return 1 + (magnifyScale - 1) * t
    }

    // ---- content -----------------------------------------------------------------
    // The row is centred in the stage; both axes use the same code path through
    // a Grid with `flow`, which keeps horizontal and vertical docks identical.
    Item {
        id: row
        anchors.centerIn: parent

        // total length the slots need right now
        readonly property real implicitLength: {
            var total = 0
            for (var i = 0; i < slotRepeater.count; i++) {
                total += (dock.iconSize * dock.scaleFor(i + 1))
            }
            total += dock.iconSize * dock.scaleFor(0)
            total += dock.spacing * Math.max(0, dock.slotCount - 1)
            total += dock.separatorSpace
            return total
        }

        width: dock.vertical ? dock.crossSize : implicitLength
        height: dock.vertical ? implicitLength : dock.crossSize

        // ---- menu button (first slot) --------------------------------------------
        Item {
            id: menuSlot
            property real magnification: dock.scaleFor(0)
            readonly property real cell: dock.iconSize * magnification
            width: dock.vertical ? dock.crossSize : cell
            height: dock.vertical ? cell : dock.crossSize
            x: 0
            y: 0

            Behavior on magnification {
                NumberAnimation { duration: 90 * (dock.host ? dock.host.motionScale : 1); easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: menuPlate
                width: menuSlot.cell
                height: menuSlot.cell
                x: dock.vertical ? (menuSlot.width - width) / 2 : 0
                y: dock.vertical ? 0 : (menuSlot.height - height) / 2
                radius: width * 0.3
                color: menuArea.pressed ? Qt.rgba(1, 1, 1, 0.24)
                     : menuArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)

                Behavior on color {
                    ColorAnimation { duration: 120 * (dock.host ? dock.host.motionScale : 1) }
                }

                // a little 2x2 grid glyph drawn with rectangles (no icon font needed)
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: parent.width * 0.09

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            width: menuPlate.width * 0.2
                            height: width
                            radius: width * 0.3
                            color: dock.host ? dock.host.colorText : "#ffffff"
                            opacity: 0.9
                        }
                    }
                }

                MouseArea {
                    id: menuArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (dock.host) dock.host.open("menu")
                }
            }
        }

        // ---- app slots ------------------------------------------------------------
        Repeater {
            id: slotRepeater
            model: dock.apps

            delegate: DockSlot {
                id: appSlot
                required property int index
                required property var modelData

                host: dock.host
                app: modelData
                iconSize: dock.iconSize
                crossSize: dock.crossSize
                vertical: dock.vertical
                edge: dock.edge
                showDots: dock.s ? dock.s.showDots : true
                magnification: dock.scaleFor(index + 1)

                // Position along the axis: sum of everything before this slot.
                readonly property real before: {
                    var pos = dock.iconSize * dock.scaleFor(0) + dock.spacing
                    for (var i = 0; i < index; i++) {
                        pos += dock.iconSize * dock.scaleFor(i + 1) + dock.spacing
                    }
                    if (dock.separatorIndex >= 0 && index >= dock.separatorIndex) pos += dock.separatorSpace
                    return pos
                }

                x: dock.vertical ? 0 : before
                y: dock.vertical ? before : 0

                onActivated: if (dock.model) dock.model.activate(modelData)
                onNewWindow: if (dock.model) dock.model.launch(modelData)
                onPinToggled: if (dock.model) dock.model.togglePin(modelData.id)
            }
        }

        // ---- separator between pinned and running apps ---------------------------------
        Rectangle {
            visible: dock.separatorIndex >= 0
            width: dock.vertical ? dock.iconSize * 0.6 : 1
            height: dock.vertical ? 1 : dock.iconSize * 0.6
            radius: 0.5
            color: dock.host ? dock.host.colorText : "#ffffff"
            opacity: 0.22
            x: dock.vertical ? (row.width - width) / 2 : dock.baseCenter(dock.separatorIndex) - dock.step / 2 - dock.pad + 1
            y: dock.vertical ? dock.baseCenter(dock.separatorIndex) - dock.step / 2 - dock.pad + 1 : (row.height - height) / 2
        }
    }

    // ---- pointer tracking over the whole dock ------------------------------------------
    // Uses a HoverHandler so clicks still reach the slots underneath.
    HoverHandler {
        id: hover
        enabled: dock.active && dock.magnify
        onPointChanged: {
            var p = hover.point.position
            dock.pointer = dock.vertical ? p.y - (dock.height - row.height) / 2 + dock.pad - dock.pad
                                          : p.x - (dock.width - row.width) / 2
        }
        onHoveredChanged: if (!hovered) dock.pointer = -1000
    }

}
