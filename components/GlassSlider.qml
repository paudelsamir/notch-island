import QtQuick

// ---------------------------------------------------------------------------
// GlassSlider.qml
//
// The slider used for volume, brightness and the settings pane.
//
//   * value is 0..1 (use `from`/`to` in the row wrapper if you need units)
//   * drag anywhere on the track, scroll the wheel, or use the arrow keys
//   * an icon button on the left (tap to toggle, e.g. mute)
//   * the percentage on the right, or a custom `valueText`
//   * a soft fill that follows the accent, with a handle that grows on hover
//
// Signals:
//   moved(real value)   while the user drags / scrolls
//   iconClicked()       when the left icon is tapped
// ---------------------------------------------------------------------------
Item {
    id: slider

    property var host: null

    property real value: 0
    property real maxValue: 1              // volume may go to 1.5 (150 %)
    property string icon: ""
    property string valueText: ""          // overrides the percent label
    property bool showValue: true
    property bool dimmed: false            // e.g. muted
    property bool enabled: true
    property real wheelStep: 0.05
    property color fillColor: host ? host.colorAccent : "#7aa2f7"

    signal moved(real value)
    signal iconClicked()

    implicitHeight: 40
    implicitWidth: 260
    opacity: enabled ? 1 : 0.4

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property real speed: host ? host.motionScale : 1

    // While dragging we show the live value, otherwise the bound one.
    property bool dragging: false
    property real liveValue: value
    onValueChanged: if (!dragging) liveValue = value

    readonly property real ratio: maxValue > 0 ? Math.max(0, Math.min(1, liveValue / maxValue)) : 0

    // ---- icon button -------------------------------------------------------
    Rectangle {
        id: iconButton
        visible: slider.icon !== ""
        width: visible ? 34 : 0
        height: 34
        radius: 17
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: iconArea.pressed ? Qt.rgba(1, 1, 1, 0.18)
             : iconArea.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)

        Behavior on color {
            ColorAnimation { duration: 120 * slider.speed }
        }

        NotchIcon {
            anchors.centerIn: parent
            name: slider.icon
            size: 18
            color: slider.dimmed ? slider.mutedColor : slider.textColor
        }

        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.iconClicked()
        }
    }

    // ---- value label -------------------------------------------------------
    Text {
        id: valueLabel
        visible: slider.showValue
        width: visible ? 44 : 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: slider.valueText !== "" ? slider.valueText : Math.round(slider.liveValue * 100) + "%"
        color: slider.mutedColor
        font.pixelSize: 12
        font.family: host ? host.fontFamily : "monospace"
    }

    // ---- track -------------------------------------------------------------
    Item {
        id: trackArea
        anchors.left: iconButton.visible ? iconButton.right : parent.left
        anchors.leftMargin: iconButton.visible ? 10 : 0
        anchors.right: valueLabel.visible ? valueLabel.left : parent.right
        anchors.rightMargin: valueLabel.visible ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        // the groove
        Rectangle {
            id: groove
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: hoverArea.containsMouse || slider.dragging ? 10 : 8
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.12)

            Behavior on height {
                NumberAnimation { duration: 120 * slider.speed; easing.type: Easing.OutCubic }
            }

            // the filled part
            Rectangle {
                id: fill
                height: parent.height
                width: Math.max(parent.height, parent.width * slider.ratio)
                radius: height / 2
                color: slider.dimmed ? Qt.rgba(1, 1, 1, 0.35) : slider.fillColor

                Behavior on width {
                    enabled: !slider.dragging
                    NumberAnimation { duration: 140 * slider.speed; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 180 * slider.speed }
                }
            }

            // marker at 100 % when the slider can go beyond it
            Rectangle {
                visible: slider.maxValue > 1.001
                x: parent.width / slider.maxValue - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.height + 4
                radius: 1
                color: slider.textColor
                opacity: 0.35
            }
        }

        // the handle
        Rectangle {
            id: handle
            width: hoverArea.containsMouse || slider.dragging ? 18 : 14
            height: width
            radius: width / 2
            color: "#ffffff"
            x: Math.max(0, Math.min(parent.width - width, parent.width * slider.ratio - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)

            Behavior on width {
                NumberAnimation { duration: 140 * slider.speed; easing.type: Easing.OutBack }
            }

            Behavior on x {
                enabled: !slider.dragging
                NumberAnimation { duration: 140 * slider.speed; easing.type: Easing.OutCubic }
            }
        }

        // little bubble with the value while dragging
        Rectangle {
            id: bubble
            visible: opacity > 0.01
            opacity: slider.dragging ? 1 : 0
            width: bubbleText.implicitWidth + 14
            height: 22
            radius: 11
            color: Qt.rgba(1, 1, 1, 0.92)
            x: Math.max(0, Math.min(trackArea.width - width, handle.x + handle.width / 2 - width / 2))
            y: -height - 2

            Behavior on opacity {
                NumberAnimation { duration: 120 * slider.speed }
            }

            Text {
                id: bubbleText
                anchors.centerIn: parent
                text: Math.round(slider.liveValue * 100) + "%"
                color: "#111111"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.family: host ? host.fontFamily : "monospace"
            }
        }

        // interaction
        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: slider.enabled
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function setFromX(px) {
                var r = Math.max(0, Math.min(1, px / width))
                slider.liveValue = r * slider.maxValue
                slider.moved(slider.liveValue)
            }

            onPressed: function(mouse) {
                slider.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: function(mouse) {
                if (pressed) setFromX(mouse.x)
            }
            onReleased: slider.dragging = false
            onCanceled: slider.dragging = false

            onWheel: function(wheel) {
                var dir = wheel.angleDelta.y > 0 ? 1 : -1
                var next = Math.max(0, Math.min(slider.maxValue, slider.liveValue + dir * slider.wheelStep))
                slider.liveValue = next
                slider.moved(next)
            }
        }
    }

    // keyboard: arrows nudge the value when the slider has focus
    Keys.onLeftPressed: {
        var v = Math.max(0, slider.liveValue - slider.wheelStep)
        slider.liveValue = v
        slider.moved(v)
    }
    Keys.onRightPressed: {
        var v = Math.min(slider.maxValue, slider.liveValue + slider.wheelStep)
        slider.liveValue = v
        slider.moved(v)
    }
}
