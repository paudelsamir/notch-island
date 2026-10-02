import QtQuick

// ---------------------------------------------------------------------------
// Breadcrumbs.qml
//
// The header of every popup. It is the thing you click to move around, the
// same idea as the island's control centre:
//
//     ‹  Menu  ›  Settings  ›  Position                       ✕
//
//   * every crumb except the last is clickable and emits crumbClicked(index)
//   * the back chevron goes to the previous crumb
//   * the close button emits closeRequested()
//   * `trailing` lets a view drop a little extra content on the right
//
// `crumbs` is an array of strings. Colours come from the host.
// ---------------------------------------------------------------------------
Item {
    id: bar

    NotchIcons {
        id: icons
    }

    property var host: null
    property var crumbs: []
    property bool showClose: true

    signal crumbClicked(int index)
    signal closeRequested()

    // Anything placed here is shown left of the close button.
    default property alias trailing: trailingSlot.data

    implicitHeight: 34
    height: implicitHeight

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property real speed: host ? host.motionScale : 1

    // ---- back chevron ------------------------------------------------------
    Rectangle {
        id: backButton
        visible: bar.crumbs.length > 1
        width: visible ? 28 : 0
        height: 28
        radius: 14
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: backArea.pressed ? Qt.rgba(1, 1, 1, 0.16)
             : backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 * bar.speed }
        }

        NotchIcon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            name: icons.back
            size: 18
            color: bar.textColor
        }

        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.crumbClicked(bar.crumbs.length - 2)
        }
    }

    // ---- crumb trail -------------------------------------------------------
    Row {
        id: trail
        anchors.left: backButton.visible ? backButton.right : parent.left
        anchors.leftMargin: backButton.visible ? 6 : 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: bar.crumbs

            delegate: Row {
                id: crumbRow
                required property int index
                required property var modelData

                readonly property bool isLast: index === bar.crumbs.length - 1

                spacing: 2
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                // The clickable label
                Rectangle {
                    id: chip
                    height: 26
                    width: label.implicitWidth + 16
                    radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: crumbRow.isLast ? "transparent"
                         : chipArea.pressed ? Qt.rgba(1, 1, 1, 0.16)
                         : chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 * bar.speed }
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: String(crumbRow.modelData)
                        color: crumbRow.isLast ? bar.textColor : bar.mutedColor
                        font.pixelSize: 13
                        font.weight: crumbRow.isLast ? Font.DemiBold : Font.Normal
                        font.family: host ? host.fontFamily : "monospace"

                        Behavior on color {
                            ColorAnimation { duration: 140 * bar.speed }
                        }
                    }

                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        enabled: !crumbRow.isLast
                        hoverEnabled: true
                        cursorShape: crumbRow.isLast ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: bar.crumbClicked(crumbRow.index)
                    }
                }

                // The separator after every crumb except the last
                NotchIcon {
                    visible: !crumbRow.isLast
                    anchors.verticalCenter: parent.verticalCenter
                    name: icons.forward
                    size: 14
                    color: bar.mutedColor
                    opacity: 0.7
                }
            }
        }
    }

    // ---- right side --------------------------------------------------------
    Row {
        id: trailingSlot
        anchors.right: closeButton.visible ? closeButton.left : parent.right
        anchors.rightMargin: closeButton.visible ? 6 : 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }

    Rectangle {
        id: closeButton
        visible: bar.showClose
        width: 28
        height: 28
        radius: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: closeArea.pressed ? Qt.rgba(1, 1, 1, 0.16)
             : closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 * bar.speed }
        }

        NotchIcon {
            anchors.centerIn: parent
            name: icons.close
            size: 15
            color: closeArea.containsMouse ? bar.textColor : bar.mutedColor
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.closeRequested()
        }
    }

    // Hairline under the header so the body reads as a separate area.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4
        height: 1
        color: bar.textColor
        opacity: 0.08
    }

    // ---- helpers for views -------------------------------------------------------
    // "Menu > Settings > Position" as one string (logs, accessibility).
    readonly property string path: crumbs.join("  >  ")
    readonly property int depth: crumbs.length

    Accessible.role: Accessible.PageTabList
    Accessible.name: path

    // Alt+Left / Backspace style navigation: emit the same signal as the chevron.
    function goBack() {
        if (crumbs.length > 1) crumbClicked(crumbs.length - 2)
        else closeRequested()
    }

    // Fade the whole header in when a view becomes active so the crumbs feel
    // like they belong to the popup rather than being pasted on top of it.
    opacity: 1
    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }
}
