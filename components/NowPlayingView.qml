import QtQuick
import Quickshell.Widgets

// ---------------------------------------------------------------------------
// NowPlayingView.qml
//
// The expanded player popup, opened from the media pill or the menu.
//
//   Menu › Now Playing                                          ✕
//   ┌────────┐  Track title
//   │ cover  │  Artist
//   └────────┘  Album · Player
//   0:42  ━━━━━━━●━━━━━━━━━  3:07
//        [previous] [play/pause] [next]  [ player ] [reload]
//
// Everything is driven by the Media service so this file is only layout.
// ---------------------------------------------------------------------------
Item {
    id: view

    NotchIcons {
        id: icons
    }

    property var host: null
    property var media: null
    property bool active: false

    readonly property real islandWidth: 440
    readonly property real islandHeight: 330
    readonly property bool wantsKeyboard: true

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color tint: media ? media.tint : (host ? host.colorAccent : "#7aa2f7")
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    function coverRadiusFor(size) {
        var percent = host && host.settings ? Number(host.settings.coverRoundness) : NaN
        if (isNaN(percent)) percent = 28
        percent = Math.max(0, Math.min(50, percent))
        return size * percent / 100
    }

    width: islandWidth
    height: islandHeight

    // keyboard: space play/pause, arrows seek/skip, esc back
    focus: active
    Keys.onPressed: function(event) {
        if (!media) return
        if (event.key === Qt.Key_Space) { media.playPause(); event.accepted = true }
        else if (event.key === Qt.Key_Right) { media.skip(5); event.accepted = true }
        else if (event.key === Qt.Key_Left) { media.skip(-5); event.accepted = true }
        else if (event.key === Qt.Key_N) { media.next(); event.accepted = true }
        else if (event.key === Qt.Key_P) { media.previous(); event.accepted = true }
        else if (event.key === Qt.Key_Escape) { if (host) host.close(); event.accepted = true }
    }

    // soft glow of the cover colour behind everything
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(view.tint.r, view.tint.g, view.tint.b, 0.20) }
            GradientStop { position: 0.7; color: Qt.rgba(view.tint.r, view.tint.g, view.tint.b, 0.0) }
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
        crumbs: ["Menu", "Now Playing"]
        onCrumbClicked: function(i) { if (view.host) view.host.open("menu") }
        onCloseRequested: if (view.host) view.host.close()
    }

    // ---- header: cover + text -----------------------------------------------------
    Item {
        id: header
        anchors.top: crumbs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        height: 96

        ClippingRectangle {
            id: cover
            width: 96
            height: 96
            radius: view.coverRadiusFor(width)
            antialiasing: true
            color: "transparent"

            Image {
                anchors.fill: parent
                source: view.media ? view.media.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 260 * view.speed }
                }
            }

            NotchIcon {
                anchors.centerIn: parent
                visible: !view.media || view.media.art === ""
                name: icons.player
                size: 48
                color: view.tint
            }

            // the cover shrinks a little while paused, like a physical record sleeve
            scale: view.media && view.media.isPlaying ? 1 : 0.94
            Behavior on scale {
                NumberAnimation { duration: 320 * view.speed; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            }
        }

        Column {
            anchors.left: cover.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                text: view.media && view.media.title !== "" ? view.media.title : "Nothing playing"
                color: view.textColor
                font.pixelSize: 17
                font.weight: Font.DemiBold
                font.family: view.fontFamily
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: view.media ? view.media.artist : ""
                color: view.textColor
                opacity: 0.85
                font.pixelSize: 13
                font.family: view.fontFamily
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    if (!view.media) return ""
                    var parts = []
                    if (view.media.album !== "") parts.push(view.media.album)
                    parts.push(view.media.playerLabel)
                    return parts.join("  \u00B7  ")
                }
                color: view.mutedColor
                font.pixelSize: 11
                font.family: view.fontFamily
                elide: Text.ElideRight
            }
        }
    }

    // ---- progress -------------------------------------------------------------------
    Item {
        id: progress
        anchors.top: header.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        height: 24

        Text {
            id: elapsed
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: view.media ? view.media.formatTime(view.media.position) : "0:00"
            color: view.mutedColor
            font.pixelSize: 11
            font.family: view.fontFamily
        }

        Text {
            id: total
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: view.media && view.media.hasPosition ? view.media.formatTime(view.media.length) : "--:--"
            color: view.mutedColor
            font.pixelSize: 11
            font.family: view.fontFamily
        }

        GlassSlider {
            anchors.left: elapsed.right
            anchors.leftMargin: 10
            anchors.right: total.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 24
            host: view.host
            showValue: false
            enabled: !!(view.media && view.media.canSeek)
            fillColor: view.tint
            value: view.media ? view.media.progress : 0
            wheelStep: 0.02
            onMoved: function(v) { if (view.media) view.media.seekFraction(v) }
        }
    }

    // ---- transport controls -----------------------------------------------------------
    Row {
        id: controls
        anchors.top: progress.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 18

        // reusable round button drawn inline to keep this file self-contained
        Repeater {
            model: [
                { glyph: icons.previous, role: "prev", size: 40 },
                { glyph: "", role: "play", size: 54 },
                { glyph: icons.next, role: "next", size: 40 }
            ]

            delegate: Rectangle {
                id: btn
                required property var modelData

                readonly property bool isPlay: modelData.role === "play"
                readonly property bool enabledBtn: view.media
                    ? (isPlay ? view.media.canPlayPause : modelData.role === "next" ? view.media.canNext : view.media.canPrevious)
                    : false

                width: modelData.size
                height: modelData.size
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                opacity: enabledBtn ? 1 : 0.35
                color: isPlay
                       ? (btnArea.pressed ? Qt.darker(view.tint, 1.2) : btnArea.containsMouse ? Qt.lighter(view.tint, 1.1) : view.tint)
                       : (btnArea.pressed ? Qt.rgba(1, 1, 1, 0.20) : btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

                Behavior on color {
                    ColorAnimation { duration: 120 * view.speed }
                }

                scale: btnArea.pressed ? 0.92 : 1
                Behavior on scale {
                    NumberAnimation { duration: 110 * view.speed; easing.type: Easing.OutCubic }
                }

                NotchIcon {
                    anchors.centerIn: parent
                    name: btn.isPlay ? (view.media && view.media.isPlaying ? icons.pause : icons.play) : btn.modelData.glyph
                    size: btn.isPlay ? 26 : 22
                    color: btn.isPlay ? "#101010" : view.textColor
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: btn.enabledBtn
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!view.media) return
                        if (btn.isPlay) view.media.playPause()
                        else if (btn.modelData.role === "next") view.media.next()
                        else view.media.previous()
                    }
                }
            }
        }
    }

    // ---- player switcher (only when several players exist) ---------------------------------
    Rectangle {
        id: switcher
        visible: view.media && view.media.playerCount > 1
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: controls.verticalCenter
        height: 28
        width: switchContent.implicitWidth + 24
        radius: 14
        color: switchArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)

        Behavior on color {
            ColorAnimation { duration: 120 * view.speed }
        }

        Row {
            id: switchContent
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: view.media ? view.media.playerLabel : ""
                color: view.textColor
                font.pixelSize: 11
                font.family: view.fontFamily
            }

            NotchIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: icons.refreshPlayers
                size: 14
                color: view.textColor
            }
        }

        MouseArea {
            id: switchArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (view.media) view.media.cyclePlayer()
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
