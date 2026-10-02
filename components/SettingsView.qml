import QtQuick

// ---------------------------------------------------------------------------
// SettingsView.qml
//
// Menu › Settings › <page>
//
// A home list of pages, each page a short list of SettingRows:
//
//   Position   edge, position, distance from the edge, monitor
//   Shape      notch / pill, roundness, opacity
//   Dock       icon size, spacing, padding, magnification, dots, pinned apps
//   Animation  on/off, speed, style, smoothness
//   Media      show the media island, swap the dock while playing
//   opencode   enable, notifications, banner seconds, model
//
// Changes apply immediately and are saved by the host. Right click a row to
// reset it to its default. The breadcrumbs work like the rest of the popups:
// click "Settings" to return to this list, "Menu" to leave.
// ---------------------------------------------------------------------------
Item {
    id: view

    NotchIcons {
        id: icons
    }

    property var host: null
    property var dockModel: null
    property bool active: false

    readonly property var s: host ? host.settings : null
    readonly property var d: host ? host.defaults : ({})

    // the current page, "" = the list of pages
    property string page: ""

    readonly property real islandWidth: 500
    readonly property real islandHeight: page === "" ? 418 : 494
    readonly property bool wantsKeyboard: true

    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    width: islandWidth
    height: islandHeight

    onActiveChanged: if (active) page = host ? host.settingsPage : ""

    // The host can jump straight to a page (IPC, deep links).
    Connections {
        target: view.host
        function onSettingsPageChanged() {
            if (view.active) view.page = view.host.settingsPage
        }
    }

    readonly property var pages: [
        { id: "home",      title: "Home",      glyph: icons.home,      font: "material", hint: "What the notch shows at rest" },
        { id: "position",  title: "Position",  glyph: icons.position,  font: "material", hint: "Edge, position, distance" },
        { id: "shape",     title: "Shape",     glyph: icons.shape,     font: "material", hint: "Notch or pill, roundness" },
        { id: "dock",      title: "Dock",      glyph: icons.dock,      font: "material", hint: "Icons, magnification, apps" },
        { id: "animation", title: "Animation", glyph: icons.animation, font: "material", hint: "Speed, style, smoothness" },
        { id: "media",     title: "Media",     glyph: icons.media,     font: "material", hint: "Now playing island" },
        { id: "opencode",  title: "opencode",  glyph: icons.openCode,  font: "brand",    hint: "Sessions, tokens, notices" },
        { id: "behavior",  title: "Behavior",  glyph: icons.behavior,  font: "material", hint: "Outside click" }
    ]

    readonly property var pageTitle: {
        for (var i = 0; i < pages.length; i++) {
            if (pages[i].id === page) return pages[i].title
        }
        return ""
    }

    function setValue(key, value) {
        if (s) s[key] = value
    }

    function resetValue(key) {
        if (s && d[key] !== undefined) s[key] = d[key]
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (page !== "") page = ""
            else if (host) host.open("menu")
            event.accepted = true
        }
    }
    focus: active

    // ---- header ------------------------------------------------------------------------------
    Breadcrumbs {
        id: crumbs
        host: view.host
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        crumbs: view.page === "" ? ["Menu", "Settings"] : ["Menu", "Settings", view.pageTitle]
        onCrumbClicked: function(i) {
            if (i === 0) { if (view.host) view.host.open("menu") }
            else if (i === 1) view.page = ""
        }
        onCloseRequested: if (view.host) view.host.close()
    }

    // ---- page list ----------------------------------------------------------------------------
    ListView {
        id: pageList
        anchors.top: crumbs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: popupNav.top
        anchors.bottomMargin: 8
        visible: view.page === ""
        spacing: 4
        clip: true
        model: view.pages
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: pageRow
            required property var modelData

            width: pageList.width
            height: 46
            radius: 14
            color: pageArea.pressed ? Qt.rgba(1, 1, 1, 0.14)
                 : pageArea.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)

            Behavior on color {
                ColorAnimation { duration: 120 * view.speed }
            }

            Rectangle {
                id: glyphTile
                width: 30
                height: 30
                radius: 9
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.22)

                NotchIcon {
                    anchors.centerIn: parent
                    name: pageRow.modelData.glyph
                    family: pageRow.modelData.font === "brand" ? "brand" : "material"
                    size: 18
                    color: view.accentColor
                }
            }

            Column {
                anchors.left: glyphTile.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: pageRow.modelData.title
                    color: view.textColor
                    font.pixelSize: 13
                    font.family: view.fontFamily
                }

                Text {
                    text: pageRow.modelData.hint
                    color: view.mutedColor
                    font.pixelSize: 10
                    font.family: view.fontFamily
                }
            }

            NotchIcon {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: icons.forward
                size: 18
                color: view.mutedColor
            }

            MouseArea {
                id: pageArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.page = pageRow.modelData.id
            }
        }
    }

    // ---- page bodies -----------------------------------------------------------------------------
    Flickable {
        id: pageFlick
        anchors.top: crumbs.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: popupNav.top
        anchors.bottomMargin: 8
        visible: view.page !== ""
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // back to the top when the page changes
        Connections {
            target: view
            function onPageChanged() {
                pageFlick.contentY = 0
                if (view.page === "dock" && view.host && view.host.iconIndex) view.host.iconIndex.refresh()
            }
        }

        Column {
            id: pageColumn
            width: pageFlick.width
            spacing: 2

            // ------------------------------------------------------- home
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "home"

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Resting module"
                    subtitle: "Dock, or the clock hub with weather, news and notes"
                    options: [
                        { value: "dock", label: "Dock" },
                        { value: "clock", label: "Clock" }
                    ]
                    value: view.s ? view.s.restMode : "clock"
                    onChanged: function(v) { view.setValue("restMode", v) }
                    onReset: view.resetValue("restMode")
                }

                // Live preview of whichever resting module is picked.
                DockPreview {
                    width: parent.width
                    host: view.host
                    dockModel: view.dockModel
                    visible: (view.s ? view.s.restMode : "clock") === "dock"
                }

                ClockPreview {
                    width: parent.width
                    host: view.host
                    visible: (view.s ? view.s.restMode : "clock") !== "dock"
                }

                Text {
                    width: parent.width
                    topPadding: 10
                    leftPadding: 12
                    rightPadding: 12
                    text: "Media still takes over while music plays, whatever you pick here."
                    color: view.mutedColor
                    font.pixelSize: 11
                    font.family: view.fontFamily
                    wrapMode: Text.Wrap
                }
            }

            // ------------------------------------------------------- position
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "position"

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Edge"
                    subtitle: "Where the notch sits"
                    options: [
                        { value: "top", label: "Top" },
                        { value: "bottom", label: "Bottom" },
                        { value: "left", label: "Left" },
                        { value: "right", label: "Right" }
                    ]
                    value: view.s ? view.s.edge : "top"
                    onChanged: function(v) { view.setValue("edge", v) }
                    onReset: view.resetValue("edge")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Position"
                    subtitle: "Where it sits along the edge"
                    options: [
                        { value: "start", label: "Left" },
                        { value: "center", label: "Center" },
                        { value: "end", label: "Right" }
                    ]
                    value: view.s ? view.s.align : "center"
                    // Picking a position clears any leftover pixel offset, so the
                    // notch can never be stranded at a stale extreme (the old
                    // slider could leave `offset` pinned at -600).
                    onChanged: function(v) { view.setValue("align", v); view.setValue("offset", 0) }
                    onReset: { view.resetValue("align"); view.resetValue("offset") }
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Distance"
                    subtitle: "Gap to the screen edge (pill only)"
                    from: 0
                    to: 48
                    step: 1
                    unit: " px"
                    value: view.s ? view.s.gap : 8
                    onChanged: function(v) { view.setValue("gap", v) }
                    onReset: view.resetValue("gap")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "action"
                    title: "Monitor"
                    subtitle: view.s && view.s.monitor !== "" ? view.s.monitor : "Follows the focused monitor"
                    actionLabel: "Use this one"
                    onActivated: if (view.host) view.setValue("monitor", view.host.outputName)
                    onReset: view.resetValue("monitor")
                }
            }

            // ---------------------------------------------------------- shape
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "shape"

                // Bounded live preview: a miniature of the island that
                // follows style, roundness, opacity and ear curve.
                Rectangle {
                    width: parent.width
                    height: 118
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "PREVIEW"
                        color: view.mutedColor
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.family: view.fontFamily
                    }

                    Rectangle {
                        id: shapeMini
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 6
                        // Mirror the manual size sliders (scaled to fit);
                        // 0 means fit content, shown representatively.
                        readonly property real sizeScale: (view.s ? (Number(view.s.sizeScale) || 1) : 1)
                        readonly property real wantW: (((view.s && Number(view.s.notchWidth) > 0) ? Number(view.s.notchWidth) : ((view.s && view.s.mode === "pill") ? 220 : 300))) * sizeScale
                        readonly property real wantH: (((view.s && Number(view.s.notchHeight) > 0) ? Number(view.s.notchHeight) : 40)) * sizeScale
                        readonly property bool manual: (view.s && (Number(view.s.notchWidth) > 0 || Number(view.s.notchHeight) > 0)) || false
                        readonly property real fit: Math.min(1, (parent.width - 48) / Math.max(1, wantW), 56 / Math.max(1, wantH))
                        width: wantW * fit
                        height: wantH * fit
                        radius: (view.s ? view.s.roundness : 70) / 100 * 20
                        color: view.host ? view.host.colorShell : "#000000"
                        opacity: view.s ? view.s.opacity : 1
                        border.width: view.s && view.s.border ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.14)

                        Text {
                            anchors.centerIn: parent
                            text: shapeMini.manual ? (Math.round(shapeMini.wantW) + " × " + Math.round(shapeMini.wantH))
                                  : ((view.s && view.s.mode === "pill" ? "pill" : "notch")
                                     + " · " + Math.round(view.s ? view.s.roundness : 70) + "%")
                            color: view.mutedColor
                            font.pixelSize: 10
                            font.family: view.fontFamily
                        }
                    }
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Style"
                    subtitle: "Notch is flush, pill floats"
                    options: [
                        { value: "notch", label: "Notch" },
                        { value: "pill", label: "Pill" }
                    ]
                    value: view.s ? view.s.mode : "notch"
                    onChanged: function(v) { view.setValue("mode", v) }
                    onReset: view.resetValue("mode")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Roundness"
                    subtitle: "0 = square, 100 = fully round"
                    from: 0
                    to: 100
                    step: 1
                    value: view.s ? view.s.roundness : 70
                    onChanged: function(v) { view.setValue("roundness", v) }
                    onReset: view.resetValue("roundness")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Ear curve"
                    subtitle: "How the notch flares into the bar, 0 = square joint"
                    from: 0
                    to: 24
                    step: 1
                    value: view.s ? view.s.earRadius : 12
                    onChanged: function(v) { view.setValue("earRadius", v) }
                    onReset: view.resetValue("earRadius")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Size"
                    subtitle: "Zoom the resting notch and the media pill, everything inside scales too"
                    from: 50
                    to: 200
                    step: 5
                    unit: " %"
                    value: view.s ? Math.round((Number(view.s.sizeScale) || 1) * 100) : 100
                    onChanged: function(v) { view.setValue("sizeScale", v / 100) }
                    onReset: view.resetValue("sizeScale")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Notch width"
                    subtitle: "Resting width, 0 = fit content"
                    from: 0
                    to: 1000
                    step: 1
                    unit: " px"
                    value: view.s ? view.s.notchWidth : 0
                    onChanged: function(v) { view.setValue("notchWidth", v) }
                    onReset: view.resetValue("notchWidth")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Notch height"
                    subtitle: "Resting height, 0 = fit content"
                    from: 0
                    to: 500
                    step: 1
                    unit: " px"
                    value: view.s ? view.s.notchHeight : 0
                    onChanged: function(v) { view.setValue("notchHeight", v) }
                    onReset: view.resetValue("notchHeight")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "action"
                    title: "Fit to content"
                    subtitle: "Back to automatic notch size"
                    actionLabel: "Fit"
                    onActivated: { view.setValue("notchWidth", 0); view.setValue("notchHeight", 0) }
                    onReset: { view.resetValue("notchWidth"); view.resetValue("notchHeight") }
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Opacity"
                    subtitle: "Background transparency"
                    from: 40
                    to: 100
                    step: 1
                    unit: " %"
                    value: view.s ? Math.round(view.s.opacity * 100) : 100
                    onChanged: function(v) { view.setValue("opacity", v / 100) }
                    onReset: view.resetValue("opacity")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Border"
                    subtitle: "Thin outline around the shell"
                    value: view.s ? view.s.border : false
                    onChanged: function(v) { view.setValue("border", v) }
                    onReset: view.resetValue("border")
                }
            }

            // ------------------------------------------------------------ dock
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "dock"

                DockPreview {
                    width: parent.width
                    host: view.host
                    dockModel: view.dockModel
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Icon size"
                    from: 20
                    to: 56
                    step: 1
                    unit: " px"
                    value: view.s ? view.s.iconSize : 30
                    onChanged: function(v) { view.setValue("iconSize", v) }
                    onReset: view.resetValue("iconSize")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Spacing"
                    from: 0
                    to: 20
                    step: 1
                    unit: " px"
                    value: view.s ? view.s.dockSpacing : 6
                    onChanged: function(v) { view.setValue("dockSpacing", v) }
                    onReset: view.resetValue("dockSpacing")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Padding"
                    from: 2
                    to: 20
                    step: 1
                    unit: " px"
                    value: view.s ? view.s.dockPadding : 8
                    onChanged: function(v) { view.setValue("dockPadding", v) }
                    onReset: view.resetValue("dockPadding")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Magnification"
                    subtitle: "Icons grow under the pointer"
                    value: view.s ? view.s.magnify : true
                    onChanged: function(v) { view.setValue("magnify", v) }
                    onReset: view.resetValue("magnify")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    visible: view.s && view.s.magnify
                    title: "Magnify to"
                    from: 1.1
                    to: 1.8
                    step: 0.05
                    unit: "x"
                    value: view.s ? view.s.magnifyScale : 1.3
                    onChanged: function(v) { view.setValue("magnifyScale", v) }
                    onReset: view.resetValue("magnifyScale")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Running dots"
                    subtitle: "One or two dots under open apps"
                    value: view.s ? view.s.showDots : true
                    onChanged: function(v) { view.setValue("showDots", v) }
                    onReset: view.resetValue("showDots")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Dots position"
                    subtitle: "Auto follows the screen edge"
                    options: [
                        { value: "auto", label: "Auto" },
                        { value: "above", label: "Above" },
                        { value: "below", label: "Below" }
                    ]
                    value: view.s ? view.s.dotsSide : "auto"
                    onChanged: function(v) { view.setValue("dotsSide", v) }
                    onReset: view.resetValue("dotsSide")
                }

                // ---- pinned apps ---------------------------------------------------------
                Text {
                    width: parent.width
                    topPadding: 10
                    leftPadding: 12
                    text: "PINNED APPS"
                    color: view.mutedColor
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    font.family: view.fontFamily
                }

                Repeater {
                    model: view.s ? view.s.pinned : []

                    delegate: Rectangle {
                        id: pinRow
                        required property int index
                        required property var modelData
                        readonly property var pinEntry: view.dockModel ? view.dockModel.entryFor(pinRow.modelData) : null

                        width: pageColumn.width
                        height: 38
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.04)

                        AppIcon {
                            id: pinIcon
                            size: 22
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: pinRow.pinEntry ? pinRow.pinEntry.icon : String(pinRow.modelData)
                            entry: pinRow.pinEntry
                            iconIndex: view.host ? view.host.iconIndex : null
                            label: String(pinRow.modelData)
                        }


                        Text {
                            anchors.left: pinIcon.right
                            anchors.leftMargin: 10
                            anchors.right: pinButtons.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(pinRow.modelData)
                            color: view.textColor
                            font.pixelSize: 12
                            font.family: view.fontFamily
                            elide: Text.ElideRight
                        }

                        Row {
                            id: pinButtons
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Repeater {
                                model: [
                                    { glyph: icons.up, act: "up" },
                                    { glyph: icons.down, act: "down" },
                                    { glyph: icons.close, act: "remove" }
                                ]

                                delegate: Rectangle {
                                    id: miniButton
                                    required property var modelData
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: miniArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)

                                    NotchIcon {
                                        anchors.centerIn: parent
                                        name: miniButton.modelData.glyph
                                        size: 15
                                        color: view.textColor
                                    }

                                    MouseArea {
                                        id: miniArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!view.dockModel) return
                                            if (miniButton.modelData.act === "up") view.dockModel.movePinned(pinRow.modelData, -1)
                                            else if (miniButton.modelData.act === "down") view.dockModel.movePinned(pinRow.modelData, 1)
                                            else view.dockModel.unpin(pinRow.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    topPadding: 10
                    leftPadding: 12
                    visible: view.dockModel && view.dockModel.pinCandidates.length > 0
                    text: "RUNNING - TAP TO PIN"
                    color: view.mutedColor
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    font.family: view.fontFamily
                }

                Flow {
                    width: parent.width
                    leftPadding: 12
                    spacing: 6

                    Repeater {
                        model: view.dockModel ? view.dockModel.pinCandidates : []

                        delegate: Rectangle {
                            id: candidate
                            required property var modelData
                            height: 28
                            width: candText.implicitWidth + 30
                            radius: 14
                            color: candArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)

                            Text {
                                id: candText
                                anchors.centerIn: parent
                                text: "+ " + candidate.modelData.name
                                color: view.textColor
                                font.pixelSize: 11
                                font.family: view.fontFamily
                            }

                            MouseArea {
                                id: candArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (view.dockModel) view.dockModel.pin(candidate.modelData.id)
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------- animation
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "animation"

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Animations"
                    subtitle: "Off = instant resizing"
                    value: view.s ? view.s.animations : true
                    onChanged: function(v) { view.setValue("animations", v) }
                    onReset: view.resetValue("animations")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Style"
                    options: [
                        { value: "spring", label: "Spring" },
                        { value: "smooth", label: "Smooth" },
                        { value: "snappy", label: "Snappy" }
                    ]
                    value: view.s ? view.s.animStyle : "spring"
                    onChanged: function(v) { view.setValue("animStyle", v) }
                    onReset: view.resetValue("animStyle")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Speed"
                    subtitle: "Higher is slower"
                    from: 0.4
                    to: 2.5
                    step: 0.1
                    unit: "x"
                    value: view.s ? view.s.motionScale : 1
                    onChanged: function(v) { view.setValue("motionScale", v) }
                    onReset: view.resetValue("motionScale")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Smoothness"
                    subtitle: "Less overshoot when it is high"
                    from: 0
                    to: 100
                    step: 1
                    value: view.s ? view.s.smoothness : 60
                    onChanged: function(v) { view.setValue("smoothness", v) }
                    onReset: view.resetValue("smoothness")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Hover lift"
                    subtitle: "The pill nudges out when hovered"
                    value: view.s ? view.s.hoverLift : true
                    onChanged: function(v) { view.setValue("hoverLift", v) }
                    onReset: view.resetValue("hoverLift")
                }
            }

            // ----------------------------------------------------------- behavior
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "behavior"

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "choice"
                    title: "Open with"
                    subtitle: "Hover opens on hover, click only on click"
                    options: [
                        { value: "hover", label: "Hover" },
                        { value: "click", label: "Click" }
                    ]
                    value: view.s ? view.s.openMode : "hover"
                    onChanged: function(v) { view.setValue("openMode", v) }
                    onReset: view.resetValue("openMode")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Volume slider"
                    subtitle: "Show audio output in the hub controls"
                    value: view.s ? view.s.showVolume !== false : true
                    onChanged: function(v) { view.setValue("showVolume", v) }
                    onReset: view.resetValue("showVolume")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Brightness slider"
                    subtitle: "Show display brightness in the hub controls"
                    value: view.s ? view.s.showBrightness !== false : true
                    onChanged: function(v) { view.setValue("showBrightness", v) }
                    onReset: view.resetValue("showBrightness")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Keyboard slider"
                    subtitle: "Show keyboard backlight in the hub controls"
                    value: view.s ? view.s.showKbd !== false : true
                    onChanged: function(v) { view.setValue("showKbd", v) }
                    onReset: view.resetValue("showKbd")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Mic slider"
                    subtitle: "Show microphone input in the hub controls"
                    value: view.s ? view.s.showMic !== false : true
                    onChanged: function(v) { view.setValue("showMic", v) }
                    onReset: view.resetValue("showMic")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "OpenCode button"
                    subtitle: "Show the opencode shortcut in the footer nav"
                    value: view.s ? view.s.showOpencodeNav !== false : true
                    onChanged: function(v) { view.setValue("showOpencodeNav", v) }
                    onReset: view.resetValue("showOpencodeNav")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Click-outside close"
                    subtitle: "Clicking another window closes an open popup"
                    value: view.s ? view.s.clickOutsideClose !== false : true
                    onChanged: function(v) { view.setValue("clickOutsideClose", v) }
                    onReset: view.resetValue("clickOutsideClose")
                }
            }

            // ----------------------------------------------------------- media
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "media"

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Media island"
                    subtitle: "Replace the dock while music plays"
                    value: view.s ? view.s.mediaPill : true
                    onChanged: function(v) { view.setValue("mediaPill", v) }
                    onReset: view.resetValue("mediaPill")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Cover glow"
                    subtitle: "Tint the player with the cover colour"
                    value: view.s ? view.s.coverTint : true
                    onChanged: function(v) { view.setValue("coverTint", v) }
                    onReset: view.resetValue("coverTint")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Cover corners"
                    subtitle: "0 = square, 50 = round"
                    from: 0
                    to: 50
                    step: 1
                    unit: " %"
                    value: view.s ? view.s.coverRoundness : 28
                    onChanged: function(v) { view.setValue("coverRoundness", v) }
                    onReset: view.resetValue("coverRoundness")
                }

                Text {
                    width: parent.width
                    topPadding: 10
                    leftPadding: 12
                    text: "PLAYER SHORTCUTS"
                    color: view.mutedColor
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    font.family: view.fontFamily
                }

                Text {
                    width: parent.width
                    leftPadding: 12
                    rightPadding: 12
                    text: "Space plays or pauses. Left and Right seek five seconds. N and P change tracks."
                    color: view.mutedColor
                    font.pixelSize: 11
                    font.family: view.fontFamily
                    wrapMode: Text.Wrap
                }
            }

            // -------------------------------------------------------- opencode
            Column {
                width: parent.width
                spacing: 2
                visible: view.page === "opencode"

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Enable opencode"
                    subtitle: "Sessions, tokens and ask"
                    value: view.s ? view.s.opencode : true
                    onChanged: function(v) { view.setValue("opencode", v) }
                    onReset: view.resetValue("opencode")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "toggle"
                    title: "Agent notices"
                    subtitle: "Banner when the agent needs you"
                    value: view.s ? view.s.opencodeNotify : true
                    onChanged: function(v) { view.setValue("opencodeNotify", v) }
                    onReset: view.resetValue("opencodeNotify")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "slider"
                    title: "Banner time"
                    from: 2
                    to: 20
                    step: 1
                    unit: " s"
                    value: view.s ? view.s.bannerSeconds : 6
                    onChanged: function(v) { view.setValue("bannerSeconds", v) }
                    onReset: view.resetValue("bannerSeconds")
                }

                SettingRow {
                    width: parent.width
                    host: view.host
                    kind: "action"
                    title: "Model"
                    subtitle: view.s && view.s.aiModel !== "" ? view.s.aiModel : "opencode default (edit notch-island.json)"
                    actionLabel: "Use default"
                    onActivated: view.setValue("aiModel", "")
                }
            }
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
