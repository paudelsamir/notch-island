import QtQuick

// size, spacing, padding and dots can be checked without leaving Settings.
//
// Protective on purpose: every value read off `host` / `dockModel` is guarded
// so a preview is never the thing that takes the shell down. The import above
// is not optional - without it Item/Rectangle/Row are anonymous and the whole
// config fails to load.
Item {
    id: preview

    property var host: null
    property var dockModel: null

    readonly property var settings: host && host.settings ? host.settings : null
    readonly property var apps: dockModel && dockModel.apps ? dockModel.apps : []
    readonly property real iconSize: settings && settings.iconSize !== undefined ? Number(settings.iconSize) : 30
    readonly property real spacing: settings && settings.dockSpacing !== undefined ? Number(settings.dockSpacing) : 6
    readonly property real pad: settings && settings.dockPadding !== undefined ? Number(settings.dockPadding) : 8
    readonly property bool showDots: settings ? settings.showDots !== false : true
    readonly property color textColor: host && host.colorText ? host.colorText : "#ffffff"
    readonly property color mutedColor: host && host.colorMuted ? host.colorMuted : "#999999"
    readonly property color accentColor: host && host.colorAccent ? host.colorAccent : "#7aa2f7"
    readonly property string fontFamily: host && host.fontFamily ? host.fontFamily : "monospace"

    width: parent ? parent.width : 0
    implicitHeight: caption.y + caption.implicitHeight

    Rectangle {
        id: background
        width: parent ? parent.width : 0
        // icon + dots lane + padding: the dots must fit inside the box,
        // never bleed into the caption below.
        height: preview.iconSize + preview.pad * 2 + 30
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        clip: true

        Row {
            id: icons
            anchors.centerIn: parent
            spacing: preview.spacing

            Repeater {
                model: preview.apps

                delegate: Column {
                    id: previewSlot
                    required property var modelData

                    spacing: 5

                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: preview.iconSize
                        iconName: previewSlot.modelData.icon
                        entry: previewSlot.modelData.entry
                        iconIndex: preview.host ? preview.host.iconIndex : null
                        label: previewSlot.modelData.name
                        monochrome: previewSlot.modelData.pinned && previewSlot.modelData.count === 0
                    }

                    Row {
                        visible: preview.showDots && previewSlot.modelData.count > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Repeater {
                            model: Math.min(2, previewSlot.modelData.count)

                            delegate: Rectangle {
                                required property int index

                                width: previewSlot.modelData.active && index === 0 ? 12 : 3
                                height: 3
                                radius: 1.5
                                color: previewSlot.modelData.active ? preview.accentColor : preview.mutedColor
                                opacity: previewSlot.modelData.active ? 1 : 0.85
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: preview.apps.length === 0
            anchors.centerIn: parent
            text: "No pinned or running apps"
            color: preview.mutedColor
            font.pixelSize: 12
            font.family: preview.fontFamily
        }
    }

    Text {
        id: caption
        anchors.top: background.bottom
        anchors.topMargin: 8
        width: parent ? parent.width : 0
        text: "This preview follows icon size, spacing, padding and dots."
        color: preview.mutedColor
        font.pixelSize: 11
        font.family: preview.fontFamily
        wrapMode: Text.Wrap
    }
}
