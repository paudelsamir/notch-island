import QtQuick

// ---------------------------------------------------------------------------
// ClockPreview.qml
//
// Preview of the clock resting pill: the real ClockView, pinned shut and
// inert, so it shows exactly what the notch shows (current display mode).
Item {
    id: preview

    property var host: null

    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    width: parent.width
    implicitHeight: caption.y + caption.implicitHeight

    Rectangle {
        id: background
        width: parent.width
        height: 76
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        clip: true

        ClockView {
            anchors.centerIn: parent
            host: preview.host
            enabled: false
            expanded: false
            previewLock: true
            active: true
        }
    }

    Text {
        id: caption
        anchors.top: background.bottom
        anchors.topMargin: 8
        width: parent.width
        text: "This preview is the actual clock pill."
        color: preview.mutedColor
        font.pixelSize: 11
        font.family: preview.fontFamily
        wrapMode: Text.Wrap
    }
}
