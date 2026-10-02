import QtQuick
import Quickshell

// ---------------------------------------------------------------------------
// AppIcon.qml
//
// Draws an application icon from the current icon theme. When the theme has
// no icon for the app, a rounded tile with the first letter of the name is
// drawn instead, tinted by a colour derived from the name so different apps
// look different but the same app always looks the same.
//
// Optional decorations:
//   * `badge`      a small red disc with a number (e.g. notification count)
//   * `loading`    a subtle breathing animation while an app launches
//   * `monochrome` dims the icon (closed pinned apps can use this)
// ---------------------------------------------------------------------------
Item {
    id: icon

    // theme icon name, an absolute path, or a desktop entry
    property string iconName: ""
    property var entry: null
    // Filesystem icon index (see services/IconIndex.qml). Names must exist in
    // the index to be used; the image provider cannot be trusted here because
    // it reports success for names it cannot actually find.
    property var iconIndex: null
    // used for the fallback letter and its colour
    property string label: ""
    property real size: 32
    property int badge: 0
    property bool loading: false
    property bool monochrome: false
    property real cornerRadius: size * 0.24

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // ---- icon source resolution --------------------------------------------
    // Everything resolves through the filesystem index, exactly like the
    // Super+Alt+Space app menu does. The image provider is deliberately not
    // used: it reports success for icon names that have no icon file.
    function themePath(name) {
        if (!iconIndex || typeof iconIndex.iconSource !== "function") return ""
        try {
            return String(iconIndex.iconSource(name) || "")
        } catch (error) {
            return ""
        }
    }

    function candidateNames() {
        var names = []
        var raw = String(iconName || "").trim()
        var text = String(label || "").trim()

        function add(value) {
            var candidate = String(value || "").trim()
            if (candidate !== "" && names.indexOf(candidate) === -1) names.push(candidate)
        }

        add(raw)
        add(raw.toLowerCase())
        if (raw.slice(-8).toLowerCase() === ".desktop") add(raw.slice(0, -8))
        if (raw.charAt(0) === "/") {
            var file = raw.split("/").pop().split(".")[0]
            add(file)
        }
        add(text)
        add(text.toLowerCase().replace(/[^a-z0-9]+/g, ""))
        var pieces = text.split(/[^A-Za-z0-9]+/)
        for (var i = 0; i < pieces.length; i++) {
            if (pieces[i].length > 1) add(pieces[i].toLowerCase())
        }
        if (raw.indexOf(".") !== -1) add(raw.split(".").pop())
        return names
    }

    readonly property string resolvedSource: {
        var entryIcon = icon.entry ? String(icon.entry.icon || "") : ""
        if (entryIcon.indexOf("file://") === 0 || entryIcon.indexOf("image://") === 0) return entryIcon
        if (entryIcon.charAt(0) === "/") return "file://" + entryIcon
        if (entryIcon !== "") {
            var entryNames = [entryIcon, entryIcon.toLowerCase()]
            for (var e = 0; e < entryNames.length; e++) {
                var entryPath = themePath(entryNames[e])
                if (entryPath !== "") return entryPath
            }
        }

        var name = String(iconName || "")
        if (name === "") return ""
        if (name.indexOf("file://") === 0 || name.indexOf("image://") === 0) return name
        if (name.charAt(0) === "/") return "file://" + name

        var names = candidateNames()
        for (var i = 0; i < names.length; i++) {
            var path = themePath(names[i])
            if (path !== "") return path
        }

        // Same source the alt-tab switcher uses: the system theme lookup.
        // Only real app/pixmap hits count, so panel action glyphs and places
        // icons never sneak in as app icons.
        for (var j = 0; j < names.length; j++) {
            var probe = ""
            try { probe = String(Quickshell.iconPath(names[j], true) || "") } catch (error) { probe = "" }
            if (probe === "") continue
            if (probe.indexOf("image://") === 0) return probe
            if (probe.indexOf("/apps/") >= 0 || probe.indexOf("/pixmaps/") >= 0) {
                return probe.charAt(0) === "/" ? "file://" + probe : probe
            }
        }
        return ""
    }

    readonly property bool hasImage: resolvedSource !== "" && image.status === Image.Ready

    // ---- deterministic colour from the label --------------------------------
    function hashHue(text) {
        var h = 0
        var s = String(text || "?")
        for (var i = 0; i < s.length; i++) {
            h = (h * 31 + s.charCodeAt(i)) % 360
        }
        return h / 360
    }

    readonly property color tileColor: Qt.hsla(hashHue(label !== "" ? label : iconName), 0.45, 0.42, 1)

    // ---- the real icon -------------------------------------------------------
    Image {
        id: image
        anchors.fill: parent
        visible: icon.resolvedSource !== "" && status !== Image.Error
        source: icon.resolvedSource
        sourceSize.width: Math.ceil(icon.size * 2)
        sourceSize.height: Math.ceil(icon.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        opacity: icon.monochrome ? 0.55 : 1

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }
    }

    // ---- fallback tile --------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        visible: !icon.hasImage
        radius: icon.cornerRadius
        color: icon.tileColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        opacity: icon.monochrome ? 0.55 : 1

        // soft top highlight so the tile does not look flat
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        Text {
            anchors.centerIn: parent
            text: icon.label !== "" ? icon.label.charAt(0).toUpperCase() : "?"
            color: "#ffffff"
            font.pixelSize: icon.size * 0.5
            font.weight: Font.DemiBold
        }
    }

    // ---- launching pulse -------------------------------------------------------
    SequentialAnimation on scale {
        running: icon.loading
        loops: Animation.Infinite
        NumberAnimation { to: 0.9; duration: 380; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 380; easing.type: Easing.InOutQuad }
        onRunningChanged: if (!running) icon.scale = 1
    }

    // ---- badge ----------------------------------------------------------------
    Rectangle {
        id: badgeDisc
        visible: icon.badge > 0
        width: Math.max(16, badgeText.implicitWidth + 8)
        height: 16
        radius: 8
        color: "#ff453a"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)

        // pop in when it appears
        scale: icon.badge > 0 ? 1 : 0
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: icon.badge > 99 ? "99+" : String(icon.badge)
            color: "#ffffff"
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    // ---- state helpers ---------------------------------------------------------
    // Called by the dock when the icon should "bounce" (e.g. after a click).
    function bounce() {
        bounceAnim.restart()
    }

    SequentialAnimation {
        id: bounceAnim
        NumberAnimation { target: icon; property: "scale"; to: 1.18; duration: 110; easing.type: Easing.OutCubic }
        NumberAnimation { target: icon; property: "scale"; to: 0.94; duration: 110; easing.type: Easing.InOutQuad }
        NumberAnimation { target: icon; property: "scale"; to: 1.0; duration: 160; easing.type: Easing.OutBack }
    }


    // ---- selection ring ------------------------------------------------------------
    // Draws a thin ring around the icon, used by the settings pane and by
    // keyboard navigation to show which icon is focused.
    property bool selected: false
    property color ringColor: "#7aa2f7"

    Rectangle {
        anchors.centerIn: parent
        width: icon.size + 6
        height: icon.size + 6
        radius: icon.cornerRadius + 3
        color: "transparent"
        border.width: 2
        border.color: icon.ringColor
        opacity: icon.selected ? 0.9 : 0
        scale: icon.selected ? 1 : 0.9
        z: -1

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }
    }

    // ---- glow -----------------------------------------------------------------------
    // A soft coloured halo behind the icon (used for the focused app).
    property bool glow: false
    property color glowColor: "#7aa2f7"

    Rectangle {
        anchors.centerIn: parent
        width: icon.size * 1.35
        height: width
        radius: width / 2
        color: icon.glowColor
        opacity: icon.glow ? 0.16 : 0
        z: -2

        Behavior on opacity {
            NumberAnimation { duration: 220 }
        }
    }

    // ---- accessibility ---------------------------------------------------------------
    Accessible.role: Accessible.Graphic
    Accessible.name: icon.label !== "" ? icon.label : icon.iconName

    // Convenience: is the icon theme able to resolve this name at all?
    // Views use it to decide whether to offer "no icon found" hints.
    readonly property bool themeHasIcon: resolvedSource !== ""
}
