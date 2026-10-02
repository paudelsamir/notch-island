import QtQuick

// ---------------------------------------------------------------------------
// OpenCodeBanner.qml
//
// The transient banner shown when the opencode agent sends a notification
// (finished, needs permission, error ...). It is the only notification this
// notch ever shows.
//
//   [ oc ]  opencode finished                            now
//           The agent is waiting for you
//   ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔  (countdown line)
//
//   left click    open the Ask opencode view
//   right click   dismiss
//   hover         pauses the auto-dismiss countdown
// ---------------------------------------------------------------------------
Item {
    id: banner

    NotchIcons {
        id: icons
    }

    property var host: null
    property var row: null            // notification object from the OpenCode service
    property bool active: false
    property int seconds: 6           // how long it stays

    readonly property real islandWidth: 432
    readonly property real islandHeight: 80

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property color accentText: host ? host.colorAccentText : "#000000"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    // OpenCode uses the active theme accent, including its logo background.
    readonly property color brand: host ? host.colorAccent : "#7aa2f7"

    width: islandWidth
    height: islandHeight

    signal openRequested()
    signal dismissed()

    // ---- text extraction ---------------------------------------------------------
    readonly property string title: row ? String(row.summary || row.title || "opencode") : "opencode"
    readonly property string body: row ? String(row.body || row.message || "") : ""

    // Classify the message so the badge colour matches what happened.
    readonly property string kind: {
        var t = (title + " " + body).toLowerCase()
        if (t.indexOf("error") !== -1 || t.indexOf("fail") !== -1) return "error"
        if (t.indexOf("permission") !== -1 || t.indexOf("approve") !== -1 || t.indexOf("confirm") !== -1) return "ask"
        if (t.indexOf("finish") !== -1 || t.indexOf("done") !== -1 || t.indexOf("complete") !== -1 || t.indexOf("idle") !== -1) return "done"
        return "info"
    }

    readonly property color kindColor: kind === "error" ? (host ? host.colorUrgent : "#ff5555")
                                     : kind === "ask" ? banner.brand
                                     : kind === "done" ? "#34c759"
                                     : "#8ab4f8"

    readonly property string kindIcon: kind === "error" ? "error" : kind === "ask" ? "help" : kind === "done" ? "check" : "info"

    function age(ts) {
        var d = Date.now() - Number(ts || 0)
        if (!ts || d < 60000) return "now"
        if (d < 3600000) return Math.floor(d / 60000) + "m"
        return Math.floor(d / 3600000) + "h"
    }

    // ---- countdown ---------------------------------------------------------------
    property real remaining: 1        // 1 -> 0
    Timer {
        id: tick
        interval: 50
        repeat: true
        running: banner.active && !hover.hovered
        onTriggered: {
            banner.remaining = Math.max(0, banner.remaining - 50 / (banner.seconds * 1000))
            if (banner.remaining <= 0) {
                tick.stop()
                banner.dismissed()
            }
        }
    }

    onActiveChanged: if (active) remaining = 1
    onRowChanged: remaining = 1

    // ---- brand tile -----------------------------------------------------------------
    Rectangle {
        id: tile
        width: 46
        height: 46
        radius: 14
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: banner.brand

        // the real opencode mark from the installed Omarchy icon face
        NotchIcon {
            anchors.centerIn: parent
            name: icons.openCode
            family: "brand"
            size: 26
            color: banner.accentText
        }

        // status badge in the corner
        Rectangle {
            width: 18
            height: 18
            radius: 9
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -5
            anchors.bottomMargin: -5
            color: banner.kindColor
            border.width: 2
            border.color: host ? host.colorBackground : "#000000"

            NotchIcon {
                anchors.centerIn: parent
                name: banner.kindIcon
                size: 12
                color: banner.kind === "ask" ? banner.accentText : "#ffffff"
                weight: Font.DemiBold
            }
        }

        // pulse ring for actions that need the user
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: banner.kindColor
            visible: banner.kind === "ask" || banner.kind === "error"
            opacity: 0

            ParallelAnimation {
                running: banner.active && (banner.kind === "ask" || banner.kind === "error")
                loops: Animation.Infinite
                NumberAnimation { target: pulse; property: "opacity"; from: 0.7; to: 0; duration: 1100 }
                NumberAnimation { target: pulse; property: "scale"; from: 1; to: 1.5; duration: 1100 }
            }

            id: pulse
        }
    }

    // ---- text -------------------------------------------------------------------------
    Column {
        anchors.left: tile.right
        anchors.leftMargin: 14
        anchors.right: stamp.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: banner.title
            color: banner.textColor
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.family: banner.fontFamily
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: banner.body
            color: banner.mutedColor
            font.pixelSize: 12
            font.family: banner.fontFamily
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    Text {
        id: stamp
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 16
        text: banner.age(banner.row ? banner.row.timestamp : 0)
        color: banner.mutedColor
        font.pixelSize: 11
        font.family: banner.fontFamily
    }

    // ---- countdown line ---------------------------------------------------------------------
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 7
        height: 2
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.07)

        Rectangle {
            height: parent.height
            width: parent.width * banner.remaining
            radius: 1
            color: banner.kindColor
        }
    }

    // ---- interaction ----------------------------------------------------------------------------
    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) banner.dismissed()
            else banner.openRequested()
        }
    }
}
