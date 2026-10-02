import QtQuick

// ---------------------------------------------------------------------------
// SettingRow.qml
//
// One row in the settings pane. A single component covers every kind of
// control so the pages stay short and consistent:
//
//   kind: "toggle"   value is a bool
//   kind: "slider"   value is a number between `from` and `to`
//   kind: "choice"   value is one of `options` (array of {value,label} or strings)
//   kind: "action"   a button; emits activated()
//
// Emits changed(value) whenever the user changes something and reset() on a
// right click, so pages can restore the default.
// ---------------------------------------------------------------------------
Item {
    id: row

    property var host: null

    property string kind: "toggle"
    property string title: ""
    property string subtitle: ""
    property var value: null

    // slider options
    property real from: 0
    property real to: 100
    property real step: 1
    property string unit: ""

    // choice options
    property var options: []

    // action options
    property string actionLabel: "Run"

    signal changed(var value)
    signal reset()
    signal activated()

    implicitHeight: subtitle !== "" ? 52 : 44
    height: implicitHeight

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property color accentText: host ? host.colorAccentText : "#000000"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    // ---- helpers ---------------------------------------------------------
    function optionValue(o) {
        return (o !== null && typeof o === "object") ? o.value : o
    }

    function optionLabel(o) {
        return (o !== null && typeof o === "object") ? String(o.label) : String(o)
    }

    function clampStep(v) {
        var snapped = Math.round((v - from) / step) * step + from
        return Math.max(from, Math.min(to, snapped))
    }

    // hover background
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(1, 1, 1, rowHover.hovered ? 0.05 : 0)

        Behavior on color {
            ColorAnimation { duration: 120 * row.speed }
        }
    }

    HoverHandler {
        id: rowHover
    }

    // right click anywhere on the row resets it to the default
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: row.reset()
    }

    // ---- title block -------------------------------------------------------
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.42
        spacing: 1

        Text {
            width: parent.width
            text: row.title
            color: row.textColor
            font.pixelSize: 13
            font.family: row.fontFamily
            elide: Text.ElideRight
        }

        Text {
            visible: row.subtitle !== ""
            width: parent.width
            text: row.subtitle
            color: row.mutedColor
            font.pixelSize: 11
            font.family: row.fontFamily
            elide: Text.ElideRight
        }
    }

    // ---- toggle ------------------------------------------------------------
    Rectangle {
        id: toggle
        visible: row.kind === "toggle"
        width: 44
        height: 26
        radius: 13
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: row.value ? row.accentColor : Qt.rgba(1, 1, 1, 0.16)

        Behavior on color {
            ColorAnimation { duration: 160 * row.speed }
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            y: 3
            x: row.value ? parent.width - width - 3 : 3
            color: "#ffffff"

            Behavior on x {
                NumberAnimation { duration: 180 * row.speed; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: row.changed(!row.value)
        }
    }

    // ---- slider ------------------------------------------------------------
    GlassSlider {
        id: valueSlider
        visible: row.kind === "slider"
        host: row.host
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.52
        implicitHeight: 32
        height: 32
        maxValue: 1
        valueText: (row.value !== null ? Math.round(Number(row.value) * 10) / 10 : 0) + row.unit
        value: (Number(row.value) - row.from) / Math.max(0.0001, row.to - row.from)
        onMoved: function(v) {
            row.changed(row.clampStep(row.from + v * (row.to - row.from)))
        }
    }

    // ---- choice (segmented pills) ------------------------------------------
    Row {
        id: choiceRow
        visible: row.kind === "choice"
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: row.kind === "choice" ? row.options : []

            delegate: Rectangle {
                id: chip
                required property var modelData

                readonly property bool selected: row.optionValue(modelData) === row.value

                height: 26
                width: chipLabel.implicitWidth + 18
                radius: 13
                color: selected ? row.accentColor
                     : chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)

                Behavior on color {
                    ColorAnimation { duration: 140 * row.speed }
                }

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: row.optionLabel(chip.modelData)
                    color: chip.selected ? row.accentText : row.textColor
                    font.pixelSize: 12
                    font.family: row.fontFamily
                }

                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.changed(row.optionValue(chip.modelData))
                }
            }
        }
    }

    // ---- action button -----------------------------------------------------
    Rectangle {
        id: actionButton
        visible: row.kind === "action"
        height: 28
        width: actionText.implicitWidth + 24
        radius: 14
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: actionArea.pressed ? Qt.darker(row.accentColor, 1.2)
             : actionArea.containsMouse ? Qt.lighter(row.accentColor, 1.12) : row.accentColor

        Behavior on color {
            ColorAnimation { duration: 120 * row.speed }
        }

        Text {
            id: actionText
            anchors.centerIn: parent
            text: row.actionLabel
            color: row.accentText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.family: row.fontFamily
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }
}
