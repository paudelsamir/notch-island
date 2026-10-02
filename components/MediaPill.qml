import QtQuick
import Quickshell.Widgets

// ---------------------------------------------------------------------------
// MediaPill.qml
//
// What the notch shows instead of the dock while music is playing:
//
//   [ cover ]  Track title  ·  Artist                 ▂▅▇▃▆
//
//   * the cover and the bars open the full player (NowPlayingView)
//   * the title scrolls (marquee) when it does not fit
//   * the bars animate while the player plays and settle when it pauses
//   * a thin progress line runs along the side that faces into the screen
//
// Sizes: the pill asks for islandWidth x islandHeight, the notch animates to it.
// ---------------------------------------------------------------------------
Item {
    id: pill

    NotchIcons {
        id: icons
    }

    property var host: null
    property var media: null            // Media service
    property bool active: true

    readonly property bool notchMode: host ? host.notchMode : false
    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color tint: media ? media.tint : (host ? host.colorAccent : "#7aa2f7")
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"
    readonly property bool vertical: host ? !host.horiz : false

    readonly property real islandWidth: vertical ? 50 : 272
    readonly property real islandHeight: vertical ? 264 : (notchMode ? 42 : 46)

    // Keep short and long titles aligned predictably. The scrolling offset is
    // separate from the centering binding so a short title cannot inherit the
    // final position of a previous long-title marquee.
    property real scrollX: 0
    property real verticalScroll: 0
    readonly property bool needsScroll: lineText.implicitWidth > textBox.width
    readonly property bool needsVerticalScroll: verticalLineV.implicitWidth > titleBoxV.height
    readonly property string titleLine: {
        if (!pill.media) return ""
        var track = pill.media.title || "Unknown track"
        return pill.media.artist !== "" ? track + "  \u00B7  " + pill.media.artist : track
    }

    function coverRadiusFor(size) {
        var percent = host && host.settings ? Number(host.settings.coverRoundness) : NaN
        if (isNaN(percent)) percent = 28
        percent = Math.max(0, Math.min(50, percent))
        return size * percent / 100
    }

    function resetScrollers() {
        scrollX = 0
        verticalScroll = 0
        if (needsScroll) scroller.restart()
        if (needsVerticalScroll) verticalScroller.restart()
    }

    signal openPlayer()

    width: islandWidth
    height: islandHeight

    // ---- horizontal cover ------------------------------------------------------
    // ClippingRectangle (not a clipped Rectangle) masks the cover art to the
    // same rounded shape selected by Cover corners.
    ClippingRectangle {
        id: cover
        visible: !pill.vertical
        width: pill.height - 12
        height: width
        radius: pill.coverRadiusFor(width)
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        antialiasing: true
        color: "transparent"

        Image {
            id: art
            anchors.fill: parent
            source: pill.media ? pill.media.art : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 240 * pill.speed }
            }
        }

        // fallback note glyph when there is no cover
        NotchIcon {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            name: icons.player
            size: parent.height * 0.55
            color: pill.tint
        }

        // gentle breathing while playing
        scale: 1
        SequentialAnimation on scale {
            running: pill.active && pill.media && pill.media.isPlaying
            loops: Animation.Infinite
            NumberAnimation { to: 1.05; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) cover.scale = 1
        }
    }

    // ---- horizontal text -------------------------------------------------------
    Item {
        id: textBox
        visible: !pill.vertical
        anchors.left: cover.right
        anchors.leftMargin: 10
        anchors.right: bars.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        clip: true

        // Two copies side by side give a seamless marquee.
        Row {
            id: marquee
            spacing: 36
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: lineText
                text: pill.titleLine
                color: pill.textColor
                font.pixelSize: 13
                font.weight: Font.Medium
                font.family: pill.fontFamily
            }

            Text {
                visible: pill.needsScroll
                text: pill.titleLine
                color: pill.textColor
                font.pixelSize: 13
                font.weight: Font.Medium
                font.family: pill.fontFamily
            }

            // centre short text, scroll long text
            x: pill.needsScroll ? pill.scrollX : (textBox.width - lineText.implicitWidth) / 2

            NumberAnimation {
                id: scroller
                target: pill
                property: "scrollX"
                running: pill.active && pill.needsScroll
                from: 0
                to: -(lineText.implicitWidth + 36)
                duration: Math.max(4000, (lineText.implicitWidth + 36) * 28)
                loops: Animation.Infinite
            }
        }

        // fade the edges of the marquee
        Rectangle {
            visible: lineText.implicitWidth > textBox.width
            anchors.right: parent.right
            width: 18
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: host ? host.colorBackground : "#000000" }
            }
        }
    }

    // Restart the marquee whenever the title changes.
    Connections {
        target: pill
        function onTitleLineChanged() {
            pill.resetScrollers()
        }
    }

    // ---- horizontal equaliser bars -------------------------------------------------
    Row {
        id: bars
        visible: !pill.vertical
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        height: 18

        Repeater {
            model: 5

            delegate: Rectangle {
                id: bar
                required property int index

                width: 3
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                color: pill.tint
                height: 4

                Behavior on height {
                    NumberAnimation { duration: 180 * pill.speed; easing.type: Easing.InOutSine }
                }

                // each bar wobbles on its own timer so they do not move in lockstep
                Timer {
                    interval: 170 + bar.index * 47
                    repeat: true
                    running: pill.active && pill.media && pill.media.isPlaying
                    onTriggered: bar.height = 4 + Math.random() * 14
                }

                Connections {
                    target: pill.media
                    function onIsPlayingChanged() {
                        if (!pill.media.isPlaying) bar.height = 4
                    }
                }
            }
        }
    }

    // ---- vertical layout for left/right edges ------------------------------------
    // The hardware is rotated logically rather than visually: the cover stays
    // recognizable, while the title is rotated so it reads from bottom to top.
    Item {
        id: verticalContent
        anchors.fill: parent
        visible: pill.vertical

        ClippingRectangle {
            id: coverV
            width: 34
            height: width
            radius: pill.coverRadiusFor(width)
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            antialiasing: true
            color: "transparent"

            Image {
                id: artV
                anchors.fill: parent
                source: pill.media ? pill.media.art : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 240 * pill.speed }
                }
            }

            NotchIcon {
                anchors.centerIn: parent
                visible: artV.status !== Image.Ready
                name: icons.player
                size: parent.height * 0.55
                color: pill.tint
            }

            scale: 1
            SequentialAnimation on scale {
                running: pill.active && pill.media && pill.media.isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: 1.05; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) coverV.scale = 1
            }
        }

        Item {
            id: titleBoxV
            anchors.top: coverV.bottom
            anchors.topMargin: 8
            anchors.bottom: barsV.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            clip: true

            Row {
                id: verticalMarquee
                width: titleBoxV.height
                height: Math.max(1, verticalLineV.implicitHeight)
                rotation: -90
                spacing: 36

                // This Row is rotated -90, which swaps the axes: its own x axis
                // is the pill's vertical run, its y axis is the horizontal one.
                // Translating an item moves it in parent x, so a scroll driven
                // through x slides the title sideways out of the 22px pill
                // instead of along the run, and centring through x leaves a
                // short title pinned against one end. Both therefore go
                // through y, and the row height follows the text so the title
                // also sits centred across the pill.
                x: (titleBoxV.width - width) / 2
                y: pill.needsVerticalScroll ? pill.verticalScroll : (verticalLineV.implicitWidth - height) / 2

                Text {
                    id: verticalLineV
                    text: pill.titleLine
                    color: pill.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: pill.fontFamily
                }

                Text {
                    visible: pill.needsVerticalScroll
                    text: pill.titleLine
                    color: pill.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: pill.fontFamily
                }

                NumberAnimation {
                    id: verticalScroller
                    target: pill
                    property: "verticalScroll"
                    running: pill.active && pill.needsVerticalScroll
                    from: 0
                    // Positive: this Row is rotated -90, so translating it down
                    // in parent y is what carries the title up along the run.
                    // The period has to be exactly one copy plus the spacing,
                    // otherwise copy two does not land where copy one started
                    // and the pill empties out before the loop restarts.
                    to: verticalLineV.implicitWidth + 36
                    duration: Math.max(4000, (verticalLineV.implicitWidth + 36) * 28)
                    loops: Animation.Infinite
                }
            }

            Rectangle {
                visible: pill.needsVerticalScroll
                anchors.top: parent.top
                width: parent.width
                height: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: host ? host.colorBackground : "#000000" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                visible: pill.needsVerticalScroll
                anchors.bottom: parent.bottom
                width: parent.width
                height: 18
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: host ? host.colorBackground : "#000000" }
                }
            }
        }

        Row {
            id: barsV
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3
            height: 18

            Repeater {
                model: 5

                delegate: Rectangle {
                    id: verticalBar
                    required property int index

                    width: 3
                    radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: pill.tint
                    height: 4

                    Behavior on height {
                        NumberAnimation { duration: 180 * pill.speed; easing.type: Easing.InOutSine }
                    }

                    Timer {
                        interval: 170 + verticalBar.index * 47
                        repeat: true
                        running: pill.active && pill.media && pill.media.isPlaying
                        onTriggered: verticalBar.height = 4 + Math.random() * 14
                    }

                    Connections {
                        target: pill.media
                        function onIsPlayingChanged() {
                            if (!pill.media.isPlaying) verticalBar.height = 4
                        }
                    }
                }
            }
        }
    }

    // ---- progress line -------------------------------------------------------------------
    // The progress indicator always sits beneath the title and equaliser content.
    Rectangle {
        id: progressTrack
        visible: pill.media && pill.media.hasPosition
        height: 2
        radius: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: pill.vertical ? 8 : pill.height * 0.4
        anchors.rightMargin: pill.vertical ? 8 : pill.height * 0.4
        y: parent.height - 4
        color: Qt.rgba(1, 1, 1, 0.08)

        Rectangle {
            width: parent.width * (pill.media ? pill.media.progress : 0)
            height: parent.height
            radius: 1
            color: pill.tint

            Behavior on width {
                NumberAnimation { duration: 480 * pill.speed; easing.type: Easing.Linear }
            }
        }
    }

    // ---- interaction ----------------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) pill.openPlayer()
            else if (mouse.button === Qt.MiddleButton && pill.media) pill.media.playPause()
            else if (mouse.button === Qt.RightButton && host) host.open("menu")
        }
        onWheel: function(wheel) {
            if (!pill.media) return
            if (wheel.angleDelta.y > 0) pill.media.next()
            else pill.media.previous()
        }
    }
}
