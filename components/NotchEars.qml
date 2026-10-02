import QtQuick

// ---------------------------------------------------------------------------
// NotchEars.qml
//
// In notch mode the shell is flush with the screen edge and its two inner
// corners are square. Real hardware notches flare out where they meet the
// bezel, so this draws the two small concave "ears" that make the shell look
// like it grows out of the edge instead of being pasted on.
//
// It works for all four edges. The ear shape is described once in edge-local
// coordinates:
//
//     u = distance along the edge, measured away from the shell
//     v = depth away from the screen edge
//
// and mapped to canvas x/y for whichever edge and side we are on.
// ---------------------------------------------------------------------------
Item {
    id: ears

    // the shell rectangle (an Item inside the same coordinate space as `ears`)
    property Item shell: null
    property string edge: "top"
    property color color: "#000000"
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real radius: 12
    property bool active: true
    // Zoom of the shell (Settings > Shape > Size). 1 = unzoomed.
    property real zoom: 1

    // Ears never need input; the notch input mask only covers the shell.
    visible: ears.active && shell !== null

    readonly property bool horizontalEdge: edge === "top" || edge === "bottom"

    // The shell is zoomed with a transform, so its layout rect is not what is
    // drawn. Rebuild the visual rect here (origin pinned to the screen edge,
    // matching the shell's transformOrigin) to keep the ears welded to it.
    readonly property real shellW: shell ? shell.width * zoom : 0
    readonly property real shellH: shell ? shell.height * zoom : 0
    readonly property real shellX: shell ? (horizontalEdge
                                              ? shell.x + (shell.width - shellW) / 2
                                              : (edge === "left" ? shell.x : shell.x + (shell.width - shellW))) : 0
    readonly property real shellY: shell ? (horizontalEdge
                                              ? (edge === "top" ? shell.y : shell.y + (shell.height - shellH))
                                              : shell.y + (shell.height - shellH) / 2) : 0
    readonly property real earR: radius * zoom

    // ---- geometry helpers ---------------------------------------------------------
    // Position of the ear on the "start" side (left of / above the shell).
    function startX() {
        if (!shell) return 0
        if (horizontalEdge) return shellX - earR
        return edge === "left" ? shellX : shellX + shellW - earR
    }

    function startY() {
        if (!shell) return 0
        if (!horizontalEdge) return shellY - earR
        return edge === "top" ? shellY : shellY + shellH - earR
    }

    // Position of the ear on the "end" side (right of / below the shell).
    function endX() {
        if (!shell) return 0
        if (horizontalEdge) return shellX + shellW
        return edge === "left" ? shellX : shellX + shellW - earR
    }

    function endY() {
        if (!shell) return 0
        if (!horizontalEdge) return shellY + shellH
        return edge === "top" ? shellY : shellY + shellH - earR
    }

    // ---- one ear ---------------------------------------------------------------------
    // `sideEnd` false = ear on the start side, true = on the end side.
    component Ear: Canvas {
        id: ear

        property bool sideEnd: false
        property string edge: "top"
        property color fill: "#000000"
        property color stroke: "transparent"
        property real strokeWidth: 0
        property real r: 12

        width: r
        height: r
        renderTarget: Canvas.FramebufferObject
        antialiasing: true

        onFillChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onStrokeWidthChanged: requestPaint()
        onEdgeChanged: requestPaint()
        onRChanged: requestPaint()
        onSideEndChanged: requestPaint()
        onWidthChanged: requestPaint()

        // Map edge-local (u, v) to canvas x/y.
        function map(u, v) {
            var size = r
            if (edge === "top")
                return sideEnd ? { x: u, y: v } : { x: size - u, y: v }
            if (edge === "bottom")
                return sideEnd ? { x: u, y: size - v } : { x: size - u, y: size - v }
            if (edge === "left")
                return sideEnd ? { x: v, y: u } : { x: v, y: size - u }
            // right
            return sideEnd ? { x: size - v, y: u } : { x: size - v, y: size - u }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = fill

            ctx.beginPath()

            // start at the corner where shell and screen edge meet
            var p = map(0, 0)
            ctx.moveTo(p.x, p.y)

            // down the side of the shell
            p = map(0, r)
            ctx.lineTo(p.x, p.y)

            // concave arc back out to the screen edge (quarter circle centred at u=r, v=r)
            var steps = 20
            for (var i = 1; i <= steps; i++) {
                var theta = (Math.PI / 2) * (i / steps)
                var u = r - r * Math.cos(theta)
                var v = r - r * Math.sin(theta)
                p = map(u, v)
                ctx.lineTo(p.x, p.y)
            }

            ctx.closePath()
            ctx.fill()

            // optional outline that follows only the concave curve, so it
            // continues the border of the shell without outlining the edge
            if (strokeWidth > 0) {
                ctx.strokeStyle = stroke
                ctx.lineWidth = strokeWidth
                ctx.beginPath()
                p = map(0, r)
                ctx.moveTo(p.x, p.y)
                for (var j = 1; j <= steps; j++) {
                    var t2 = (Math.PI / 2) * (j / steps)
                    p = map(r - r * Math.cos(t2), r - r * Math.sin(t2))
                    ctx.lineTo(p.x, p.y)
                }
                ctx.stroke()
            }
        }

        Component.onCompleted: requestPaint()
    }

    Ear {
        id: startEar
        sideEnd: false
        edge: ears.edge
        fill: ears.color
        stroke: ears.strokeColor
        strokeWidth: ears.strokeWidth
        r: ears.earR
        x: ears.startX()
        y: ears.startY()
    }

    Ear {
        id: endEar
        sideEnd: true
        edge: ears.edge
        fill: ears.color
        stroke: ears.strokeColor
        strokeWidth: ears.strokeWidth
        r: ears.earR
        x: ears.endX()
        y: ears.endY()
    }

    // The shell moves and resizes every frame while animating, so the ears
    // re-evaluate their positions on those signals.
    Connections {
        target: ears.shell
        function onXChanged() { ears.reposition() }
        function onYChanged() { ears.reposition() }
        function onWidthChanged() { ears.reposition() }
        function onHeightChanged() { ears.reposition() }
    }

    function reposition() {
        startEar.x = startX()
        startEar.y = startY()
        endEar.x = endX()
        endEar.y = endY()
    }

    onEdgeChanged: reposition()
    onRadiusChanged: reposition()
    onZoomChanged: reposition()
    Component.onCompleted: reposition()

    // Re-evaluate when the shell first gets a real size (it starts at 0x0).
    Timer {
        interval: 50
        repeat: false
        running: true
        onTriggered: ears.reposition()
    }

    // Debug helper: `ears.debug = true` outlines both ears in red.
    property bool debug: false

    Rectangle {
        visible: ears.debug
        x: startEar.x
        y: startEar.y
        width: startEar.width
        height: startEar.height
        color: "transparent"
        border.color: "red"
        border.width: 1
    }

    Rectangle {
        visible: ears.debug
        x: endEar.x
        y: endEar.y
        width: endEar.width
        height: endEar.height
        color: "transparent"
        border.color: "red"
        border.width: 1
    }
}
