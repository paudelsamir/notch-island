import QtQuick

// ---------------------------------------------------------------------------
// NotchIcon.qml
//
// A small Material-style icon. `name` is normally a Material Symbols ligature
// such as "settings". `family` can be "material" or "brand"; the latter uses
// the installed Omarchy icon face for the real opencode mark.
Item {
    id: root

    property string name: ""
    property string family: "material"
    property color color: "#ffffff"
    property real size: 18
    property int weight: Font.Medium

    readonly property string resolvedFamily: root.family === "brand"
        ? "omarchy"
        : "Material Symbols Rounded"

    implicitWidth: Math.max(1, label.implicitWidth)
    implicitHeight: Math.max(1, label.implicitHeight)
    width: implicitWidth
    height: implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.name
        textFormat: Text.PlainText
        color: root.color
        font.family: root.resolvedFamily
        font.pixelSize: root.size
        font.weight: root.weight
        renderType: Text.CurveRendering
    }
}
