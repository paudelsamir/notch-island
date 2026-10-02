import QtQuick
import Quickshell.Io

// ---------------------------------------------------------------------------
// ClockView.qml
//
// The home surface for people who do not want an app dock. At rest it is
// a centered text pill that sizes to its content, like a phone status pill,
// showing whatever you have chosen to display there. Hovering grows it into
// a hub:
//
//   compact (resting)
//     18:23 · Tue 30                      <- or date, both, system
//                                              nothing at all: your choice
//
//   expanded (hover)
//     Good evening                    Notch shows:  Clock  Date  Greet  Off
//     18:23:07
//     Tuesday, 30 September
//     ------------------------------------------------------------------
//     [ News ]  [ Weather ]                          <- click to switch
//     ...content for the selected section...
//     ------------------------------------------------------------------
//     Menu   Music   Power   Settings
//
// Design notes
//   * displayModes is the editable bit: pick what the compact pill displays
//     without opening anything. Clock / Date / Greeting / Off (dot only).
//     Add more modes in `displayModes` below if you want something else -
//     deliberately NOT a timer or a pomodoro, per how this is meant to be used.
//   * News and Weather are their own clickable tabs rather than cramming
//     both into the resting view. They fetch through scripts/news.sh and
//     scripts/weather.sh (already part of this plugin) using whatever
//     `host.scriptsDir` resolves to, so this file has no hard dependency on
//     any other service existing - it works standalone.
//   * Every external property (host, dockModel, sys, news, weather, notes)
//     is optional and null-guarded throughout, so wiring this up with more
//     or fewer services never breaks the view - only ever changes what it
//     is able to show.
//   * Hover, not click, drives the expansion, with short grace periods so
//     passing the mouse over it on the way elsewhere does not flash it open.
//     Clicking the compact pill still opens the full menu, like the dock does.
// ---------------------------------------------------------------------------
Item {
    id: view

    NotchIcons {
        id: icons
    }

    // ---- external wiring, all optional --------------------------------------------------
    property var host: null
    property var dockModel: null      // DockModel, for the quick-launch row
    property var sys: null            // SystemControls, for battery / uptime
    property var news: null           // optional external news service (duck-typed)
    property var weather: null        // optional external weather service (duck-typed)
    property var notes: null          // optional external Notes service (duck-typed)
    property bool active: true

    property bool expanded: false
    property bool wantsKeyboard: expanded
    // Pinned shut for settings previews: hover and menu-open never expand it.
    property bool previewLock: false

    // ---- what the compact pill shows -----------------------------------------------------
    // clock | date | both | system. System polls live system state (uptime,
    // battery) instead of the clock.
    readonly property var displayModes: ["clock", "date", "both", "system", "weather", "none"]
    // Persisted: survives shell restarts via the settings file.
    // One-way mirror: the binding carries settings -> view. Everything that
    // changes the mode (chips, cycleDisplayMode) writes host.settings, never
    // this property, so the binding is never severed and settings-page edits
    // keep applying live.
    property string displayMode: host && host.settings && host.settings.displayMode ? host.settings.displayMode : "clock"

    function cycleDisplayMode() {
        if (!host || !host.settings) return
        var idx = displayModes.indexOf(displayMode)
        host.settings.displayMode = displayModes[(idx + 1) % displayModes.length]
    }

    // ---- geometry --------------------------------------------------------------------------
    // On side edges the compact pill stands upright: dims swap and the label
    // rotates, mirroring the dock and the media pill. Width fits the text.
    readonly property bool vertical: host ? !host.horiz : false
    readonly property real compactHeight: 40
    readonly property real compactWidth: compactLabelText.implicitWidth + 36

    readonly property real expandedWidth: 392
    // Height of the whole expanded hub. Both the News and Weather tabs fill
    // this area, so this is what makes them taller - it is NOT a per-row size.
    // Capped by the panel strip thickness (Notch.qml windowThickness = 700) so
    // the hub never spills past the surface and gets clipped.
    readonly property real expandedHeight: Math.max(320, Math.min(660, ((host && host.windowThickness) ? host.windowThickness : 700) - 40))

    readonly property real islandWidth: expanded ? expandedWidth : (vertical ? compactHeight : compactWidth)
    readonly property real islandHeight: expanded ? expandedHeight : (vertical ? animatedWidth : compactHeight)

    width: expanded ? expandedWidth : (vertical ? compactHeight : animatedWidth)
    height: islandHeight

    // Behavior only works on writable properties, so mirror the readonly
    // compactWidth into animatedWidth and glide that instead.
    property real animatedWidth: compactWidth
    onCompactWidthChanged: animatedWidth = compactWidth
    Behavior on animatedWidth {
        NumberAnimation { duration: 160 * view.speed; easing.type: Easing.OutCubic }
    }

    // ---- theme -------------------------------------------------------------------------------
    readonly property color textColor: host ? host.colorText : "#ffffff"
    readonly property color mutedColor: host ? host.colorMuted : "#999999"
    readonly property color accentColor: host ? host.colorAccent : "#7aa2f7"
    readonly property color accentText: host ? host.colorAccentText : "#000000"
    readonly property color urgentColor: host ? host.colorUrgent : "#ff5555"
    readonly property real speed: host ? host.motionScale : 1
    readonly property string fontFamily: host ? host.fontFamily : "monospace"

    // Global open mode: "hover" expands on hover, "click" only opens on click.
    readonly property string openMode: host && host.settings && host.settings.openMode === "click" ? "click" : "hover"
    readonly property bool use24h: host && host.settings ? host.settings.clock24h !== false : true
    readonly property string scriptsDir: host ? host.scriptsDir : ""

    focus: expanded
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            view.expanded = false
            if (view.host) view.host.lastCloseStamp = Date.now()
            event.accepted = true
        }
    }

    // System mode polls live system state instead of the clock.
    Timer {
        interval: 60000
        repeat: true
        running: view.active && view.displayMode === "system"
        triggeredOnStart: true
        onTriggered: if (view.sys) view.sys.refreshUptime()
    }
    // =========================================================================================
    // CLOCK
    // =========================================================================================
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: view.active
        triggeredOnStart: true
        onTriggered: view.now = new Date()
    }

    readonly property string compactTime: Qt.formatTime(now, use24h ? "HH:mm" : "h:mm AP")
    readonly property string compactDate: Qt.formatDate(now, "ddd d")
    readonly property string bigTime: Qt.formatTime(now, use24h ? "HH:mm:ss" : "h:mm:ss AP")
    readonly property string fullDate: Qt.formatDate(now, "dddd, d MMMM")

    readonly property string greeting: {
        var h = now.getHours()
        if (h < 5) return "Still up"
        if (h < 12) return "Good morning"
        if (h < 17) return "Good afternoon"
        if (h < 21) return "Good evening"
        return "Good night"
    }

    // What the compact label reads, driven by displayMode.
    readonly property string compactLabel: {
        if (displayMode === "date") return compactDate
        if (displayMode === "both") return compactTime + " · " + compactDate
        if (displayMode === "system") return systemLine
        if (displayMode === "weather") return weatherLine
        if (displayMode === "none") return ""
        return compactTime
    }

    // Short weather line for the weather mode: "21° Partly cloudy".
    // Falls back to the clock when there is nothing to show yet.
    readonly property string weatherLine: {
        if (!weatherHasData || weatherData.tempC === "") return compactTime
        var c = String(weatherData.condition || "").split(",")[0]
        if (c.length > 18) c = c.slice(0, 17) + "…"
        return weatherData.tempC + "°" + (c !== "" ? " " + c : "")
    }

    // Short system line for the system mode, polled from the system service:
    // "up 3h 12m · 84%". Falls back to the clock when no service is wired.
    readonly property string systemLine: {
        if (!sys) return compactTime
        var bits = []
        var up = shortUptime(sys.uptime)
        if (up !== "") bits.push("up " + up)
        if (sys.hasBattery) bits.push(Math.round(sys.batteryPercent) + "%")
        if (bits.length === 0) return compactTime
        return bits.join(" · ")
    }

    function shortUptime(text) {
        var s = String(text || "")
        var h = 0, m = 0
        var hm = s.match(/(\d+)\s*hour/)
        var mm = s.match(/(\d+)\s*minute/)
        if (hm) h = Number(hm[1])
        if (mm) m = Number(mm[1])
        if (h > 0 && m > 0) return h + "h " + m + "m"
        if (h > 0) return h + "h"
        if (m > 0) return m + "m"
        return ""
    }

    // =========================================================================================
    // NEWS  (own fetch, works with or without an external `news` service)
    // =========================================================================================
    // The shipped News service names things differently (items vs headlines),
    // so accept either shape here instead of at every use site.
    readonly property bool hasExternalNews: !!(news && (news.headlines !== undefined || news.items !== undefined))
    property var ownNewsItems: []
    property bool ownNewsLoading: false
    property string ownNewsUpdated: ""

    readonly property var newsItems: hasExternalNews ? (news.headlines || news.items || []) : ownNewsItems
    readonly property bool newsLoading: hasExternalNews ? !!news.loading : ownNewsLoading
    readonly property string newsUpdated: hasExternalNews ? (news.updatedAgo || news.lastFetched || "") : ownNewsUpdated
    readonly property string newsTopic: host && host.effectiveNewsTopic ? host.effectiveNewsTopic : "world"
    readonly property string newsTopicRaw: host && host.settings && host.settings.newsTopic ? host.settings.newsTopic : "auto"

    Process {
        id: newsProc
        command: ["bash", view.scriptsDir + "/news.sh", view.newsTopic]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                view.ownNewsLoading = false
                try {
                    var rows = JSON.parse(String(text || "[]").trim() || "[]")
                    view.ownNewsItems = Array.isArray(rows) ? rows : []
                    view.ownNewsUpdated = Qt.formatTime(new Date(), "h:mm AP")
                } catch (e) {
                    // keep whatever we already had
                }
            }
        }
    }

    function refreshNews() {
        if (hasExternalNews) {
            if (news.refresh) news.refresh()
            return
        }
        if (newsProc.running) return
        ownNewsLoading = true
        newsProc.running = true
    }

    // =========================================================================================
    // WEATHER  (own fetch, works with or without an external `weather` service)
    // =========================================================================================
    readonly property bool hasExternalWeather: !!(weather && weather.hasData !== undefined)
    property var ownWeatherData: ({})
    property bool ownWeatherLoading: false

    // The shipped Weather service names things differently (description vs
    // condition, feelsLikeC vs feelsC, city vs location, days vs forecast),
    // so normalize the external shape once here instead of at every use site.
    // The own-fetch shape is normalized the same way, so the card can always
    // rely on forecast/updatedAgo existing (possibly empty).
    readonly property var weatherData: {
        var empty = {
            tempC: "", condition: "", feelsC: "", humidity: "",
            location: "", windKph: "", windDir: "", uv: "",
            precipMM: "", updatedAgo: "", forecast: []
        }
        if (!hasExternalWeather) {
            var o = ownWeatherData || {}
            var of = []
            var odays = o.forecast || o.days || []
            for (var k = 0; k < odays.length; k++) {
                var od = odays[k] || {}
                of.push({
                    date: od.date || "",
                    condition: od.desc || od.condition || "",
                    hiC: od.maxC || od.hiC || "",
                    loC: od.minC || od.loC || "",
                    rainChance: od.rainChance || ""
                })
            }
            return {
                tempC: o.tempC || "",
                condition: o.description || o.condition || "",
                feelsC: o.feelsLikeC || o.feelsC || "",
                humidity: o.humidity || "",
                location: o.city || o.location || "",
                windKph: o.windKph || "",
                windDir: o.windDir || "",
                uv: o.uvIndex || o.uv || "",
                precipMM: o.precipMM || "",
                updatedAgo: o.updatedAgo || "",
                forecast: of
            }
        }
        if (!weather) return empty
        var days = weather.days || weather.forecast || []
        var forecast = []
        for (var i = 0; i < days.length; i++) {
            var d = days[i] || {}
            forecast.push({
                date: d.date || "",
                condition: d.desc || d.condition || "",
                hiC: d.maxC || d.hiC || "",
                loC: d.minC || d.loC || "",
                rainChance: d.rainChance || ""
            })
        }
        return {
            tempC: weather.tempC || "",
            condition: weather.description || weather.condition || "",
            feelsC: weather.feelsLikeC || weather.feelsC || "",
            humidity: weather.humidity || "",
            location: weather.city || weather.location || "",
            windKph: weather.windKph || "",
            windDir: weather.windDir || "",
            uv: weather.uvIndex || weather.uv || "",
            precipMM: weather.precipMM || "",
            updatedAgo: weather.updatedAgo || "",
            forecast: forecast
        }
    }
    readonly property bool weatherHasData: hasExternalWeather ? !!weather.hasData : (ownWeatherData && ownWeatherData.tempC !== undefined)
    readonly property bool weatherLoading: hasExternalWeather ? !!weather.loading : ownWeatherLoading

    Process {
        id: weatherProc
        command: ["bash", view.scriptsDir + "/weather.sh"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                view.ownWeatherLoading = false
                try {
                    var d = JSON.parse(String(text || "{}").trim() || "{}")
                    if (d && d.tempC !== undefined) view.ownWeatherData = d
                } catch (e) {
                    // keep the previous reading
                }
            }
        }
    }

    function refreshWeather() {
        if (hasExternalWeather) {
            if (weather.refresh) weather.refresh()
            return
        }
        if (weatherProc.running) return
        ownWeatherLoading = true
        weatherProc.running = true
    }

    // Material icon name for a condition string. Same matching as the old
    // unicode glyphs, but rendered through NotchIcon: no emoji, and it
    // matches every other icon in the notch.
    function weatherIconName(condition) {
        var c = String(condition || "").toLowerCase()
        if (c.indexOf("thunder") !== -1) return icons.storm
        if (c.indexOf("snow") !== -1 || c.indexOf("sleet") !== -1 || c.indexOf("ice") !== -1) return icons.snow
        if (c.indexOf("rain") !== -1 || c.indexOf("drizzle") !== -1 || c.indexOf("shower") !== -1) return icons.rain
        if (c.indexOf("fog") !== -1 || c.indexOf("mist") !== -1 || c.indexOf("haze") !== -1) return icons.fog
        if (c.indexOf("overcast") !== -1 || c.indexOf("cloud") !== -1 || c.indexOf("partly") !== -1) return icons.partlyCloudy
        if (c.indexOf("clear") !== -1 || c.indexOf("sunny") !== -1) return icons.sun
        return icons.cloudy
    }

    // Refresh on first expand, then keep news/weather quietly current.
    property bool everExpanded: false
    onExpandedChanged: {
        if (expanded && !everExpanded) {
            everExpanded = true
            refreshNews()
            refreshWeather()
        }
    }

    Timer {
        interval: 12 * 60 * 1000
        repeat: true
        running: view.active && view.everExpanded
        onTriggered: view.refreshNews()
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: view.active && view.everExpanded
        onTriggered: view.refreshWeather()
    }

    Process {
        id: openLinkProc
    }

    function openLink(url) {
        if (!url) return
        openLinkProc.command = ["xdg-open", url]
        openLinkProc.startDetached()
    }

    // =========================================================================================
    // HOVER: expand / collapse with grace periods
    // =========================================================================================
    HoverHandler {
        id: hover
    }

    Timer {
        id: openDelay
        interval: 110
        repeat: false
        // Confirm the pointer is still here: without this, brushing past
        // the notch expands it, then the leave collapses it right away.
        // A fresh explicit close also suppresses reopen underfoot.
        onTriggered: {
            if (hover.hovered && view.openMode !== "click"
                && !(view.host && view.host.freshClose)) view.expanded = true
        }
    }

    // Watchdog: content swaps (tab clicks, feed loads) resize the island
    // under a stationary cursor, which can strand us collapsed while still
    // hovered with no fresh hover event to re-arm openDelay. Reconcile.
    Timer {
        interval: 400
        repeat: true
        running: view.active && view.openMode !== "click"
        onTriggered: {
            if (!(view.host && (view.host.view === "rest" || view.host.view === "menu"))) return
            if (view.host.freshClose) return
            if (hover.hovered && !view.expanded) {
                openDelay.stop()
                view.expanded = true
            } else if (!hover.hovered && view.expanded && view.host.view === "rest") {
                view.expanded = false
            }
        }
    }

    // No delay: leaving snaps back on the same animation.
    Timer {
        id: closeDelay
        interval: 2000
        repeat: false
        onTriggered: view.expanded = false
    }

    Connections {
        target: hover
        function onHoveredChanged() {
            if (view.openMode === "click") {
                openDelay.stop()
                closeDelay.stop()
                return
            }
            if (hover.hovered) {
                closeDelay.stop()
                openDelay.restart()
            } else {
                openDelay.stop()
                closeDelay.restart()
            }
        }
    }

    // The clock hub IS the menu: opening "menu" pins it open even without
    // hover (dock users get here via the dock menu button); closing it
    // collapses unless the pointer is still hovering.
    Connections {
        target: view.host
        function onViewChanged() {
            if (!view.host || view.previewLock) return
            if (view.host.view === "menu") {
                openDelay.stop()
                closeDelay.stop()
                view.expanded = true
            } else if (!hover.hovered) {
                openDelay.stop()
                view.expanded = false
            }
        }
    }

    onActiveChanged: {
        if (!active) {
            expanded = false
            openDelay.stop()
            closeDelay.stop()
        } else if (sys) {
            sys.refreshUptime()
            sys.refreshBrightness()
            sys.refreshKbdBrightness()
        }
    }

    // =========================================================================================
    // COMPACT: centered time text, no logo. The pill sizes to the text:
    // longer text, longer notch.
    // =========================================================================================
        Text {
            id: compactLabelText
            anchors.centerIn: parent
            opacity: view.expanded ? 0 : 1
            // Upright on side edges so the time reads bottom to top.
            rotation: view.vertical ? -90 : 0
            text: view.compactLabel
            color: view.textColor
            font.pixelSize: 13
            font.weight: Font.Medium
            font.family: view.fontFamily
            font.letterSpacing: 0.2

            Behavior on opacity {
                NumberAnimation { duration: 140 * view.speed }
            }
        }

    // =========================================================================================
    // EXPANDED HUB
    // =========================================================================================
    Item {
        id: hub
        anchors.fill: parent
        anchors.margins: 16
        opacity: view.expanded ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 200 * view.speed; easing.type: Easing.OutCubic }
        }

        // soft vignette so the hub does not look like a flat sheet of text
        Rectangle {
            anchors.fill: parent
            anchors.margins: -16
            z: -1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.10) }
                GradientStop { position: 0.5; color: "transparent" }
            }
        }

        // ---- header: greeting + display-mode chips ------------------------------------------
        Row {
            id: headerRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: view.greeting
                color: view.mutedColor
                font.pixelSize: 11
                font.family: view.fontFamily
            }

            Item { width: parent.width - greetingWidth.width - modeChips.implicitWidth; height: 1 }

            Row {
                id: modeChips
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: [
                        { id: "clock", icon: "schedule" },
                        { id: "date", icon: "calendar_month" },
                        { id: "both", icon: "date_range" },
                        { id: "system", icon: "memory" },
                        { id: "weather", icon: "thermostat" },
                        { id: "none", icon: "visibility_off" }
                    ]

                    delegate: Rectangle {
                        id: modeChip
                        required property var modelData

                        readonly property bool selected: view.displayMode === modelData.id

                        height: 22
                        width: 32
                        radius: 11
                        color: selected ? view.accentColor
                             : modeChipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)

                        Behavior on color {
                            ColorAnimation { duration: 120 * view.speed }
                        }

                        NotchIcon {
                            anchors.centerIn: parent
                            name: modeChip.modelData.icon
                            size: 13
                            color: modeChip.selected ? view.accentText : view.textColor
                        }

                        MouseArea {
                            id: modeChipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Same binding rule as the hub tabs: write the
                                // setting so the mirror binding stays live and
                                // settings-page changes keep working.
                                if (view.host && view.host.settings) view.host.settings.displayMode = modeChip.modelData.id
                            }
                        }
                    }
                }
            }
        }

        // invisible measuring helper for the spacer above
        Text {
            id: greetingWidth
            visible: false
            text: view.greeting
            font.pixelSize: 11
        }

        // ---- big clock + date -------------------------------------------------------------------
        Text {
            id: bigClock
            anchors.top: headerRow.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            text: view.bigTime
            color: view.textColor
            font.pixelSize: 30
            font.weight: Font.DemiBold
            font.family: view.fontFamily
        }

        Text {
            id: dateLine
            anchors.top: bigClock.bottom
            anchors.left: parent.left
            text: view.fullDate
            color: view.mutedColor
            font.pixelSize: 12
            font.family: view.fontFamily
        }

        Rectangle {
            id: divider1
            anchors.top: dateLine.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: view.textColor
            opacity: 0.08
        }

        // ---- controls: volume / brightness / output (merged in from the menu) -----------
        Column {
            id: controls
            anchors.top: divider1.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 10

            GlassSlider {
                visible: !view.host || !view.host.settings || view.host.settings.showVolume !== false
                width: parent.width
                host: view.host
                icon: view.sys ? view.sys.volumeGlyph : "volume_up"
                enabled: !!(view.sys && view.sys.hasSink)
                dimmed: !!(view.sys && view.sys.muted)
                maxValue: 1.5
                value: view.sys ? view.sys.volume : 0
                valueText: view.sys && view.sys.muted ? "muted" : ""
                wheelStep: 0.03
                onMoved: function(v) { if (view.sys) view.sys.setVolume(v) }
                onIconClicked: if (view.sys) view.sys.toggleMute()
            }

            GlassSlider {
                visible: !view.host || !view.host.settings || view.host.settings.showBrightness !== false
                width: parent.width
                host: view.host
                icon: icons.brightness
                enabled: !!(view.sys && view.sys.hasBrightness)
                value: view.sys && view.sys.hasBrightness ? view.sys.brightness : 0
                valueText: view.sys && !view.sys.hasBrightness ? "n/a" : ""
                wheelStep: 0.04
                onMoved: function(v) { if (view.sys) view.sys.setBrightness(v) }
            }

            GlassSlider {
                // Same guard as the mic row: keyboard backlight is optional.
                readonly property bool kbdReady: !!(view.sys && view.sys.hasKbdBrightness)

                visible: !view.host || !view.host.settings || view.host.settings.showKbd !== false
                width: parent.width
                host: view.host
                icon: icons.keyboard
                enabled: kbdReady
                value: kbdReady ? view.sys.kbdBrightness : 0
                valueText: view.sys && !kbdReady ? "n/a" : ""
                wheelStep: 0.1
                onMoved: function(v) { if (kbdReady) view.sys.setKbdBrightness(v) }
            }

            GlassSlider {
                // This service may not carry a mic at all (no source, or an
                // older build), so every read is guarded on hasMic. Assigning
                // the missing properties straight through handed `undefined`
                // to a string and a double, which QML logs on every frame.
                readonly property bool micReady: !!(view.sys && view.sys.hasMic)

                visible: micReady && (!view.host || !view.host.settings || view.host.settings.showMic !== false)
                width: parent.width
                host: view.host
                icon: micReady ? view.sys.micGlyph : icons.mic
                enabled: micReady
                dimmed: micReady && !!view.sys.micMuted
                maxValue: 1.0
                value: micReady ? view.sys.micVolume : 0
                valueText: micReady && view.sys.micMuted ? "muted" : ""
                wheelStep: 0.05
                onMoved: function(v) { if (micReady) view.sys.setMicVolume(v) }
                onIconClicked: if (micReady) view.sys.toggleMicMute()
            }

            Item {
                width: parent.width
                height: 22
                visible: view.sys && view.sys.sinks.length > 1

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    NotchIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: icons.swapOutputs
                        size: 14
                        color: sinkArea.containsMouse ? view.textColor : view.mutedColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22
                        text: view.sys ? view.sys.sinkName : ""
                        color: sinkArea.containsMouse ? view.textColor : view.mutedColor
                        font.pixelSize: 11
                        font.family: view.fontFamily
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: sinkArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (view.sys) view.sys.cycleOutput()
                }
            }
        }

        // ---- section switcher: one sliding glass pill over three labels -------------------
        // A single indicator glides between sections instead of each chip
        // highlighting itself, so the row reads as one control. Persisted like
        // the display mode. One-way mirror, same rule: chips write
        // host.settings.hubTab, never this property.
        property string tab: host && host.settings && host.settings.hubTab ? host.settings.hubTab : "news"

        // Persisting is a synchronous settings write, so doing it inside
        // onTabChanged lands disk I/O on the first frame of the glide and the
        // switch stutters. Wait for the animation to land first.
        onTabChanged: tabSave.restart()

        Timer {
            id: tabSave
            interval: 320
            onTriggered: if (host && host.settings) host.settings.hubTab = hub.tab
        }

        // Refresh after the glide finishes, so the network/process work never
        // lands on the frames the pill is animating across.
        Timer {
            id: hubTabFetch
            interval: 240
            repeat: false
            onTriggered: {
                if (hub.tab === "news") view.refreshNews()
                else if (hub.tab === "weather") view.refreshWeather()
            }
        }

        readonly property var sectionIds: ["news", "weather", "notes"]
        readonly property int sectionCount: sectionIds.length

        // One clock for the whole switch: the pill glide, the label colour and
        // the body crossfade all finish together, so it reads as a single
        // movement rather than three staggered tweens.
        readonly property int tabMoveMs: 220 * view.speed
        readonly property int tabFadeMs: 140 * view.speed

        function sectionIndex(id) {
            var idx = sectionIds.indexOf(id)
            return idx < 0 ? 0 : idx
        }

        Item {
            id: tabStrip
            anchors.top: controls.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }

            // the sliding pill, exactly one segment wide
            Rectangle {
                id: tabPill
                height: parent.height - 6
                width: tabStrip.width / hub.sectionCount
                y: 3
                // Derive x from the same segment width the labels use, so the
                // pill lands dead centre on its slot instead of near it.
                x: hub.sectionIndex(hub.tab) * width
                radius: height / 2
                color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.26)
                border.width: 1
                border.color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.45)

                Behavior on x {
                    NumberAnimation {
                        duration: hub.tabMoveMs
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: [
                        { id: "news", label: "News" },
                        { id: "weather", label: "Weather" },
                        { id: "notes", label: "Notes" }
                    ]

                    delegate: Item {
                        id: tabChip
                        required property var modelData

                        readonly property bool selected: hub.tab === modelData.id

                        width: tabStrip.width / hub.sectionCount
                        height: tabStrip.height

                        Text {
                            anchors.centerIn: parent
                            text: tabChip.modelData.label
                            // dim whatever the pill is not sitting on
                            color: tabChip.selected ? view.accentColor
                                 : tabChipArea.containsMouse ? view.textColor
                                 : view.mutedColor
                            font.pixelSize: 11
                            font.weight: tabChip.selected ? Font.DemiBold : Font.Normal
                            font.family: view.fontFamily

                            Behavior on color {
                                ColorAnimation { duration: hub.tabFadeMs }
                            }
                        }

                        MouseArea {
                            id: tabChipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Write the setting, not the local mirror: hub.tab
                                // is bound to settings.hubTab, so assigning it
                                // here would sever the binding and later settings
                                // changes would stop reaching the hub.
                                if (view.host && view.host.settings) view.host.settings.hubTab = tabChip.modelData.id
                                // Spawning the fetcher on the click frame makes
                                // the fork compete with the first frames of the
                                // glide. Let the pill land, then fetch.
                                hubTabFetch.restart()
                            }
                        }
                    }
                }
            }
        }

        // ---- tab content area ----------------------------------------------------------------------
        Item {
            id: tabBody
            anchors.top: tabStrip.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: navbar.top
            anchors.bottomMargin: 8
            clip: true

            // ---------------------------------------------------------------------- news
            Item {
                id: newsPane
                anchors.fill: parent
                // Drop the outgoing body immediately and only fade the incoming
                // one in. Crossfading all three together kept the whole news
                // list, the weather card and the notes list live for the length
                // of the glide, which is what made the switch feel like it
                // stuttered. Now at most two bodies ever render, and the pill
                // is the only thing visibly travelling.
                visible: hub.tab === "news"
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: visible ? hub.tabFadeMs : 0
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: newsHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 20

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: view.newsLoading ? "Refreshing\u2026" : (view.newsUpdated !== "" ? "Updated " + view.newsUpdated : "Latest headlines")
                        color: view.mutedColor
                        font.pixelSize: 10
                        font.family: view.fontFamily
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: newsRefreshArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)

                        NotchIcon {
                            anchors.centerIn: parent
                            name: icons.refresh
                            size: 11
                            color: view.textColor
                        }

                        MouseArea {
                            id: newsRefreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.refreshNews()
                        }
                    }
                }

                // ---- topic chips: World / Tech / Nepal / Custom ---------------------------
                // Custom reads ~/.config/omarchy/notch-island-feeds.txt (one URL per line).
                Row {
                    id: topicChips
                    anchors.top: newsHeader.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "auto", label: "Auto" },
                            { id: "world", label: "World" },
                            { id: "tech", label: "Tech" },
                            { id: "nepal", label: "Nepal" },
                            { id: "custom", label: "Custom" }
                        ]

                        delegate: Rectangle {
                            id: topicChip
                            required property var modelData

                            readonly property bool selected: view.newsTopicRaw === modelData.id

                            height: 24
                            width: topicChipText.implicitWidth + 18
                            radius: 12
                            color: selected ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.22)
                                 : topicChipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)

                            Behavior on color {
                                ColorAnimation { duration: 130 * view.speed }
                            }

                            Text {
                                id: topicChipText
                                anchors.centerIn: parent
                                text: topicChip.modelData.label
                                color: topicChip.selected ? view.accentColor : view.textColor
                                font.pixelSize: 11
                                font.weight: topicChip.selected ? Font.DemiBold : Font.Normal
                                font.family: view.fontFamily
                            }

                            MouseArea {
                                id: topicChipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (view.host && view.host.settings) view.host.settings.newsTopic = topicChip.modelData.id
                                    view.refreshNews()
                                }
                            }
                        }
                    }
                }

                Flickable {
                    anchors.top: topicChips.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: newsList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: newsList
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: view.newsItems

                            delegate: Rectangle {
                                id: newsRow
                                required property var modelData
                                width: newsList.width
                                height: 50
                                radius: 12
                                color: newsRowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 110 * view.speed }
                                }

                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: newsRow.modelData.title
                                        color: view.textColor
                                        font.pixelSize: 13
                                        font.family: view.fontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: text !== ""
                                        text: newsRow.modelData.source
                                        color: view.accentColor
                                        font.pixelSize: 10
                                        font.family: view.fontFamily
                                    }
                                }

                                MouseArea {
                                    id: newsRowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.openLink(newsRow.modelData.link)
                                }
                            }
                        }

                        Text {
                            visible: view.newsItems.length === 0 && !view.newsLoading
                            width: newsList.width
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 12
                            text: view.newsTopic === "custom"
                                  ? "Add RSS URLs (one per line) to ~/.config/omarchy/notch-island-feeds.txt"
                                  : "No headlines yet. Check your network."
                            color: view.mutedColor
                            font.pixelSize: 11
                            font.family: view.fontFamily
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // ------------------------------------------------------------------- weather
            Item {
                id: weatherPane
                anchors.fill: parent
                visible: hub.tab === "weather"
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: visible ? hub.tabFadeMs : 0
                        easing.type: Easing.OutCubic
                    }
                }

                // Minimal bounded weather card: hero, meta strip, divider,
                // 3-day forecast in one bordered box.
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "#ff00ff" // TEMP bisect
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    clip: true

                Column {
                    // ---- top row: place left, freshness + refresh right ----
                    Item {
                        width: parent.width
                        height: 18
                        visible: view.weatherHasData || view.weatherLoading

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: view.weatherHasData ? String(view.weatherData.location || "Current conditions").toUpperCase() : "WEATHER"
                            color: view.mutedColor
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.family: view.fontFamily
                            font.letterSpacing: 1.2
                        }

                        Text {
                            anchors.right: wxRefresh.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: view.weatherHasData && !!view.weatherData.updatedAgo
                            text: view.weatherData.updatedAgo
                            color: view.mutedColor
                            font.pixelSize: 10
                            font.family: view.fontFamily
                        }

                        Item {
                            id: wxRefresh
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20

                            NotchIcon {
                                anchors.centerIn: parent
                                name: icons.refresh
                                size: 13
                                color: wxRefreshArea.containsMouse ? view.textColor : view.mutedColor
                            }

                            MouseArea {
                                id: wxRefreshArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.refreshWeather()
                            }
                        }
                    }

                    // ---- hero: icon, big temp, condition + feels ----
                    Item {
                        width: parent.width
                        height: 56
                        visible: view.weatherHasData

                        NotchIcon {
                            id: wxHeroIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            name: view.weatherIconName(view.weatherData.condition)
                            size: 44
                            color: view.textColor
                        }

                        Column {
                            anchors.left: wxHeroIcon.right
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                text: view.weatherData.tempC + "\u00B0"
                                color: view.textColor
                                font.pixelSize: 30
                                font.weight: Font.DemiBold
                                font.family: view.fontFamily
                            }

                            Text {
                                text: view.weatherData.condition + (view.weatherData.feelsC !== "" ? " · Feels " + view.weatherData.feelsC + "\u00B0" : "")
                                color: view.mutedColor
                                font.pixelSize: 11
                                font.family: view.fontFamily
                            }
                        }

                        Column {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            visible: view.weatherData.forecast.length > 0

                            Text {
                                anchors.right: parent.right
                                text: view.weatherData.forecast.length > 0 ? view.weatherData.forecast[0].hiC + "\u00B0 / " + view.weatherData.forecast[0].loC + "\u00B0" : ""
                                color: view.textColor
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                font.family: view.fontFamily
                            }

                            Text {
                                anchors.right: parent.right
                                visible: view.weatherData.forecast.length > 0 && view.weatherData.forecast[0].rainChance !== "" && Number(view.weatherData.forecast[0].rainChance) > 0
                                text: view.weatherData.forecast.length > 0 ? view.weatherData.forecast[0].rainChance + "% rain" : ""
                                color: view.accentColor
                                font.pixelSize: 10
                                font.family: view.fontFamily
                            }
                        }
                    }

                    // ---- meta grid: feels / humidity / wind / uv ----
                    Grid {
                        width: parent.width
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8
                        visible: view.weatherHasData

                        Item {
                            width: (parent.width - 8) / 2
                            height: 32

                            NotchIcon {
                                id: wxFeelsIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: icons.thermometer
                                size: 14
                                color: view.mutedColor
                            }

                            Column {
                                anchors.left: wxFeelsIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: view.weatherData.feelsC !== "" ? view.weatherData.feelsC + "\u00B0C" : "--"
                                    color: view.textColor
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: view.fontFamily
                                }

                                Text {
                                    text: "FEELS LIKE"
                                    color: view.mutedColor
                                    font.pixelSize: 8
                                    font.family: view.fontFamily
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        Item {
                            width: (parent.width - 8) / 2
                            height: 32

                            NotchIcon {
                                id: wxHumIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: icons.humidity
                                size: 14
                                color: view.mutedColor
                            }

                            Column {
                                anchors.left: wxHumIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: view.weatherData.humidity !== "" ? view.weatherData.humidity + "%" : "--"
                                    color: view.textColor
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: view.fontFamily
                                }

                                Text {
                                    text: "HUMIDITY"
                                    color: view.mutedColor
                                    font.pixelSize: 8
                                    font.family: view.fontFamily
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        Item {
                            width: (parent.width - 8) / 2
                            height: 32

                            NotchIcon {
                                id: wxWindIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: icons.wind
                                size: 14
                                color: view.mutedColor
                            }

                            Column {
                                anchors.left: wxWindIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: view.weatherData.windKph !== "" ? view.weatherData.windKph + " km/h" + (view.weatherData.windDir !== "" ? " " + view.weatherData.windDir : "") : "--"
                                    color: view.textColor
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: view.fontFamily
                                }

                                Text {
                                    text: "WIND"
                                    color: view.mutedColor
                                    font.pixelSize: 8
                                    font.family: view.fontFamily
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        Item {
                            width: (parent.width - 8) / 2
                            height: 32

                            NotchIcon {
                                id: wxUvIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                name: icons.sun
                                size: 14
                                color: view.mutedColor
                            }

                            Column {
                                anchors.left: wxUvIcon.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Text {
                                    text: view.weatherData.uv !== "" ? "UV " + view.weatherData.uv : "--"
                                    color: view.textColor
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: view.fontFamily
                                }

                                Text {
                                    text: "UV INDEX"
                                    color: view.mutedColor
                                    font.pixelSize: 8
                                    font.family: view.fontFamily
                                    font.letterSpacing: 0.8
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: view.textColor
                        opacity: 0.07
                        visible: view.weatherHasData && view.weatherData.forecast.length > 0
                    }

                    // ---- 3-day forecast ----
                    Row {
                        width: parent.width
                        spacing: 10
                        visible: view.weatherHasData && view.weatherData.forecast.length > 0

                        Repeater {
                            model: view.weatherData.forecast

                            delegate: Column {
                                id: wxDayCol
                                required property var modelData
                                required property int index
                                width: (parent.width - 20) / 3
                                spacing: 3

                                Text {
                                    text: wxDayCol.index === 0 ? "Today" : wxDayCol.index === 1 ? "Tmrw" : Qt.formatDate(new Date(wxDayCol.modelData.date), "ddd")
                                    color: wxDayCol.index === 0 ? view.accentColor : view.mutedColor
                                    font.pixelSize: 10
                                    font.weight: wxDayCol.index === 0 ? Font.Medium : Font.Normal
                                    font.family: view.fontFamily
                                }

                                NotchIcon {
                                    name: view.weatherIconName(wxDayCol.modelData.condition)
                                    size: 18
                                    color: view.textColor
                                }

                                Text {
                                    text: wxDayCol.modelData.hiC + "\u00B0/" + wxDayCol.modelData.loC + "\u00B0"
                                    color: view.textColor
                                    font.pixelSize: 10
                                    font.family: view.fontFamily
                                }

                                Text {
                                    visible: wxDayCol.modelData.rainChance !== "" && Number(wxDayCol.modelData.rainChance) > 0
                                    text: wxDayCol.modelData.rainChance + "%"
                                    color: view.accentColor
                                    font.pixelSize: 9
                                    font.family: view.fontFamily
                                }
                            }
                        }
                    }

                    // ---- empty / loading states ----
                    Text {
                        visible: !view.weatherHasData && !view.weatherLoading
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 40
                        text: "No weather data. Check your network or location file."
                        color: view.mutedColor
                        font.pixelSize: 11
                        font.family: view.fontFamily
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: !view.weatherHasData && view.weatherLoading
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 40
                        text: "Fetching weather\u2026"
                        color: view.mutedColor
                        font.pixelSize: 11
                        font.family: view.fontFamily
                    }
                }

                }
            }

            // ------------------------------------------------------------------- notes
            // Same tab treatment as news and weather. The notes service is
            // optional, so this pane stands down to a hint when it is absent
            // rather than showing an empty list that looks broken.
            Item {
                id: notesPane
                anchors.fill: parent
                visible: hub.tab === "notes"
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: visible ? hub.tabFadeMs : 0
                        easing.type: Easing.OutCubic
                    }
                }

                readonly property var list: view.notes && Array.isArray(view.notes.notes) ? view.notes.notes : []

                // ---- add row -------------------------------------------------------
                Item {
                    id: noteAddRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: noteInput.activeFocus ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.5)
                                                             : Qt.rgba(1, 1, 1, 0.08)

                        Behavior on border.color {
                            ColorAnimation { duration: 140 * view.speed }
                        }
                    }

                    Text {
                        id: notePlaceholder
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: noteInput.text === "" && !noteInput.activeFocus
                        text: "Add a note\u2026"
                        color: view.mutedColor
                        font.pixelSize: 12
                        font.family: view.fontFamily
                    }

                    TextInput {
                        id: noteInput
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: addNoteBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: view.textColor
                        font.pixelSize: 12
                        font.family: view.fontFamily
                        selectByMouse: true
                        clip: true

                        onAccepted: {
                            if (view.notes) view.notes.add(text)
                            text = ""
                        }
                    }

                    Rectangle {
                        id: addNoteBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 13
                        opacity: noteInput.text.trim() === "" ? 0.35 : 1
                        color: addNoteArea.containsMouse ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.32)
                                                         : Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.2)

                        Behavior on opacity {
                            NumberAnimation { duration: 130 * view.speed }
                        }

                        NotchIcon {
                            anchors.centerIn: parent
                            name: icons.add
                            size: 13
                            color: view.accentColor
                        }

                        MouseArea {
                            id: addNoteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.notes) view.notes.add(noteInput.text)
                                noteInput.text = ""
                            }
                        }
                    }
                }

                // ---- list ---------------------------------------------------------
                Flickable {
                    id: noteFlick
                    anchors.top: noteAddRow.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    contentWidth: width
                    contentHeight: noteList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: noteList
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: notesPane.list

                            delegate: Rectangle {
                                id: noteRow
                                required property var modelData

                                readonly property bool done: modelData.done === true

                                width: noteList.width
                                height: 38
                                radius: 12
                                color: noteRowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: 110 * view.speed }
                                }

                                // checkbox
                                Rectangle {
                                    id: noteCheck
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15
                                    height: 15
                                    radius: 4
                                    color: noteRow.done ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.28)
                                                         : Qt.rgba(1, 1, 1, 0.07)
                                    border.width: 1
                                    border.color: noteRow.done ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.55)
                                                               : Qt.rgba(1, 1, 1, 0.14)

                                    Behavior on color {
                                        ColorAnimation { duration: 140 * view.speed }
                                    }

                                    NotchIcon {
                                        anchors.centerIn: parent
                                        name: icons.check
                                        size: 10
                                        visible: noteRow.done
                                        color: view.accentColor
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (view.notes) view.notes.toggle(noteRow.modelData.id)
                                    }
                                }

                                Text {
                                    anchors.left: noteCheck.right
                                    anchors.leftMargin: 11
                                    anchors.right: noteDelete.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: noteRow.modelData.text
                                    color: noteRow.done ? view.mutedColor : view.textColor
                                    font.pixelSize: 12
                                    font.family: view.fontFamily
                                    elide: Text.ElideRight

                                    Behavior on color {
                                        ColorAnimation { duration: 140 * view.speed }
                                    }
                                }

                                // delete, only on hover so the row stays calm
                                Rectangle {
                                    id: noteDelete
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    radius: 9
                                    opacity: noteRowArea.containsMouse ? 1 : 0
                                    color: Qt.rgba(1, 1, 1, 0.10)

                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 * view.speed }
                                    }

                                    NotchIcon {
                                        anchors.centerIn: parent
                                        name: icons.close
                                        size: 9
                                        color: view.mutedColor
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (view.notes) view.notes.remove(noteRow.modelData.id)
                                    }
                                }

                                MouseArea {
                                    id: noteRowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }

                        Text {
                            visible: notesPane.list.length === 0
                            width: noteList.width
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 16
                            text: view.notes ? "No notes yet. Add one above." : "Notes are not wired up here."
                            color: view.mutedColor
                            font.pixelSize: 11
                            font.family: view.fontFamily
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        // ---- footer navbar: quick jumps to the other popups -----------------------------------------
        // Shared PopupNav component: identical chrome in every popup.
        // The hub keeps the tight original; the popups get the roomier cut.
        PopupNav {
            id: navbar
            host: view.host
            roomy: false
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ---- click on the compact pill toggles it inline, exactly what hovering
    // does (right click still jumps to settings, like the dock does) ------------
    MouseArea {
        anchors.fill: parent
        enabled: !view.expanded
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (!view.host) return
            if (mouse.button === Qt.RightButton) view.host.open("settings")
            else {
                openDelay.stop()
                closeDelay.stop()
                view.expanded = true
            }
        }
    }
}
