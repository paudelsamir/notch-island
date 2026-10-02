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
            precipMM: "", visibility: "", updatedAgo: "", forecast: []
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
                visibility: o.visibility || "",
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
            visibility: weather.visibility || "",
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

    // =========================================================================================
    // WEATHER CARD derived values
    // =========================================================================================
    // Everything the card needs that is not a straight copy out of weatherData.
    // Cached as properties rather than recomputed in each binding: the forecast
    // bar fractions run three times per frame otherwise.

    // 16-point compass label -> degrees, so the arrow can point the way the wind
    // is coming from. An unknown label falls back to north.
    function windBearing(dir) {
        var order = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        var idx = order.indexOf(String(dir || "").toUpperCase())
        return idx < 0 ? 0 : idx * 22.5
    }

    // "YYYY-MM-DD" is read as UTC by Date(), which slides the weekday over for
    // anyone west of Greenwich, so split it and build a local date instead.
    function localDate(s) {
        var m = String(s || "").match(/^(\d{4})-(\d{2})-(\d{2})$/)
        if (!m) return null
        return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
    }

    function forecastDayLabel(i, dateStr) {
        if (i === 0) return "TODAY"
        var d = localDate(dateStr)
        return d ? Qt.formatDate(d, "ddd").toUpperCase() : ""
    }

    // A flat week makes every bar identical and useless, so pin the bar to a
    // fixed 15-85% instead of collapsing it to nothing.
    function forecastFrac(value, isHigh) {
        if (!(weekMaxC > weekMinC)) return isHigh ? 0.85 : 0.15
        var f = (Number(value) - weekMinC) / (weekMaxC - weekMinC)
        return Math.max(0, Math.min(1, isNaN(f) ? 0.5 : f))
    }

    readonly property real todayRain: weatherHasData && weatherData.forecast.length > 0
        ? Number(weatherData.forecast[0].rainChance || 0) : 0

    // Feels-like only earns a line when it disagrees with the reading. Repeating
    // "20 degrees" twice, once in the hero and once in the grid, was noise.
    readonly property real feelsDelta: (weatherHasData && weatherData.feelsC !== "" && weatherData.tempC !== "")
        ? Number(weatherData.feelsC) - Number(weatherData.tempC) : 0
    readonly property bool feelsWorthShowing: Math.abs(feelsDelta) >= 2

    readonly property real weekMinC: {
        if (!weatherHasData) return 0
        var lo = []
        for (var i = 0; i < weatherData.forecast.length; i++) {
            var v = Number(weatherData.forecast[i].loC)
            if (!isNaN(v)) lo.push(v)
        }
        return lo.length > 0 ? Math.min.apply(null, lo) : 0
    }

    readonly property real weekMaxC: {
        if (!weatherHasData) return 0
        var hi = []
        for (var i = 0; i < weatherData.forecast.length; i++) {
            var v = Number(weatherData.forecast[i].hiC)
            if (!isNaN(v)) hi.push(v)
        }
        return hi.length > 0 ? Math.max.apply(null, hi) : 0
    }

    // One advisory line, first match wins, nothing when the day is unremarkable.
    // The stat row already carries the numbers; this carries the only thing
    // worth changing your behaviour over.
    readonly property var weatherAdvisory: {
        if (!weatherHasData) return null
        var d = weatherData
        var cond = String(d.condition || "").toLowerCase()
        var uv = Number(d.uv)
        var wind = Number(d.windKph)
        if (cond.indexOf("thunder") !== -1)
            return { icon: icons.storm, text: "Thunderstorm - worth staying in" }
        if (todayRain >= 60)
            return { icon: icons.rain, text: todayRain + "% rain - take an umbrella" }
        if (uv >= 8)
            return { icon: icons.sun, text: "UV " + d.uv + ", extreme - cover up" }
        if (uv >= 6)
            return { icon: icons.sun, text: "UV " + d.uv + ", high - sunscreen if you are out" }
        if (wind >= 31)
            return { icon: icons.wind, text: "Strong wind, " + d.windKph + " km/h" }
        if (Math.abs(feelsDelta) >= 5)
            return { icon: icons.thermometer, text: "Feels " + (feelsDelta > 0 ? "hotter" : "colder") + " than it reads" }
        return null
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

                // =====================================================================
                // WEATHER CARD
                // =====================================================================
                // Weather is one dense object rather than a list, so it gets the
                // only bordered box in the hub - the border is what tells it
                // apart from the news rows beside it.
                //
                // Width budget: the hub is 392 wide inside 16 margins, so the
                // card is 360 and its content is 332 after the 14 inset. Every
                // size below is measured against those two numbers.
                //
                // Type, four steps only: 34 hero / 13 value / 12 body / 10
                // tracked caps. 10px is captions ("HUMIDITY", "DETAILS") and
                // never anything you have to read as prose.
                //
                // Accent is rationed on purpose: today's row, the rain figures
                // and the advisory strip are the only things allowed to use it,
                // so the eye still has somewhere to land.
                Rectangle {
                    id: wxCard
                    anchors.fill: parent
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    clip: true

                    Item {
                        id: wxInner
                        anchors.fill: parent
                        anchors.margins: 14

                        // One flow, not a pinned top and bottom. The card shares
                        // its height with the news and notes tabs, and at the
                        // short end the two halves met and overlapped. A single
                        // scrolling column cannot collide with itself, and when
                        // the card is tall - the normal case - there is nothing to
                        // scroll. Same treatment as the news list.
                        Flickable {
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: wxFlow.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            visible: view.weatherHasData

                            Column {
                                id: wxFlow
                                width: parent.width
                                spacing: 12

                                // ---- header: place, freshness, refresh ----
                                // The refresh button stays put when there is no
                                // data. Hiding it on the empty state left no way
                                // back from a failed fetch.
                                Item {
                                    width: parent.width
                                    height: 18

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: wxFresh.left
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: view.weatherData.location !== "" ? view.weatherData.location.toUpperCase() : "WEATHER"
                                        color: view.mutedColor
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        font.family: view.fontFamily
                                        font.letterSpacing: 1.1
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: wxFresh
                                        anchors.right: wxRefresh.left
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: view.weatherData.updatedAgo !== ""
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
                                        opacity: view.weatherLoading ? 0.4 : 1

                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 * view.speed }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: wxRefreshArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                                        }

                                        NotchIcon {
                                            anchors.centerIn: parent
                                            name: icons.refresh
                                            size: 12
                                            color: view.textColor
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

                                // ---- now: reading on the left, today on the right ----
                                // Left is what you look at, right is what you plan
                                // around, so the two never share a line and the
                                // hero keeps a clean edge to read against.
                                Rectangle {
                                    id: wxNow
                                    width: parent.width
                                    height: 80
                                    radius: 14
                                    color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.09)
                                    border.width: 1
                                    border.color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.22)

                                    Item {
                                        id: wxHeroIconBox
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 38
                                        height: 38

                                        NotchIcon {
                                            anchors.centerIn: parent
                                            name: view.weatherIconName(view.weatherData.condition)
                                            size: 36
                                            color: view.textColor
                                        }
                                    }

                                    Column {
                                        id: wxHeroCol
                                        anchors.left: wxHeroIconBox.right
                                        anchors.leftMargin: 12
                                        // Bounded by the right-hand stack, so a long
                                        // condition elides instead of running under it.
                                        anchors.right: wxToday.left
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 0

                                        Item {
                                            width: parent.width
                                            height: 34

                                            Text {
                                                id: wxTempNum
                                                anchors.left: parent.left
                                                anchors.bottom: parent.bottom
                                                text: view.weatherData.tempC
                                                color: view.textColor
                                                font.pixelSize: 34
                                                font.weight: Font.DemiBold
                                                font.family: view.fontFamily
                                            }

                                            // The unit rides the hero only. Everything
                                            // below is a bare degree, which is the
                                            // same thing once the big number has
                                            // said it once.
                                            Text {
                                                anchors.left: wxTempNum.right
                                                anchors.leftMargin: 1
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 4
                                                visible: wxTempNum.text !== ""
                                                text: "\u00B0C"
                                                color: view.mutedColor
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                font.family: view.fontFamily
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: view.weatherData.condition
                                            color: view.mutedColor
                                            font.pixelSize: 12
                                            font.family: view.fontFamily
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Column {
                                        id: wxToday
                                        anchors.right: parent.right
                                        anchors.rightMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Text {
                                            anchors.right: parent.right
                                            visible: view.weatherData.forecast.length > 0
                                            text: view.weatherData.forecast.length > 0 ? "H " + view.weatherData.forecast[0].hiC + "\u00B0   L " + view.weatherData.forecast[0].loC + "\u00B0" : ""
                                            color: view.textColor
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            font.family: view.fontFamily
                                        }

                                        // Feels-like only appears when it disagrees
                                        // with the reading. Printing "20 degrees"
                                        // twice, here and in the grid below, was
                                        // noise pretending to be detail.
                                        Row {
                                            anchors.right: parent.right
                                            spacing: 4
                                            visible: view.feelsWorthShowing

                                            NotchIcon {
                                                name: icons.thermometer
                                                size: 12
                                                color: view.mutedColor
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Feels " + view.weatherData.feelsC + "\u00B0"
                                                color: view.mutedColor
                                                font.pixelSize: 11
                                                font.family: view.fontFamily
                                            }
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            spacing: 4
                                            visible: view.todayRain > 0

                                            NotchIcon {
                                                name: icons.rain
                                                size: 12
                                                color: view.accentColor
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: view.todayRain + "% rain"
                                                color: view.accentColor
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                font.family: view.fontFamily
                                            }
                                        }
                                    }
                                }

                                // ---- section label: caps plus a rule filling the rest ----
                                Item {
                                    width: parent.width
                                    height: 12

                                    Text {
                                        id: wxDetailsText
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        text: "DETAILS"
                                        color: view.mutedColor
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        font.family: view.fontFamily
                                        font.letterSpacing: 1.1
                                    }

                                    Rectangle {
                                        anchors.left: wxDetailsText.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 3
                                        height: 1
                                        color: view.textColor
                                        opacity: 0.08
                                    }
                                }

                                // ---- four stats, equal cells so the row reads as one ----
                                // The wind cell's icon is the compass arrow,
                                // rotated to the bearing, which reads faster than
                                // "WNW" and costs no horizontal space.
                                Row {
                                    id: wxStats
                                    width: parent.width
                                    height: 54

                                    Repeater {
                                        model: [
                                            { icon: icons.humidity, value: view.weatherData.humidity !== "" ? view.weatherData.humidity + "%" : "--", caption: "HUMIDITY", bearing: 0 },
                                            { icon: icons.bearing, value: view.weatherData.windKph !== "" ? view.weatherData.windKph : "--", caption: view.weatherData.windDir !== "" ? "KM/H " + view.weatherData.windDir : "KM/H", bearing: view.windBearing(view.weatherData.windDir) },
                                            { icon: icons.sun, value: view.weatherData.uv !== "" ? view.weatherData.uv : "--", caption: "UV INDEX", bearing: 0 },
                                            { icon: icons.eye, value: view.weatherData.visibility !== "" ? view.weatherData.visibility : "--", caption: "VISIBLE KM", bearing: 0 }
                                        ]

                                        delegate: Item {
                                            id: wxStat
                                            required property var modelData

                                            width: (wxStats.width - 24) / 4
                                            height: wxStats.height

                                            Item {
                                                id: wxStatIconBox
                                                anchors.top: parent.top
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 16
                                                height: 16

                                                NotchIcon {
                                                    anchors.centerIn: parent
                                                    name: wxStat.modelData.icon
                                                    size: 15
                                                    color: view.mutedColor
                                                    rotation: wxStat.modelData.bearing
                                                }
                                            }

                                            // The caption hangs off the value rather
                                            // than sitting at a fixed offset, so it
                                            // cannot collide when the font is scaled.
                                            Text {
                                                id: wxStatValue
                                                anchors.top: wxStatIconBox.bottom
                                                anchors.topMargin: 4
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: wxStat.modelData.value
                                                color: view.textColor
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                font.family: view.fontFamily
                                            }

                                            Text {
                                                anchors.top: wxStatValue.bottom
                                                anchors.topMargin: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: wxStat.width
                                                horizontalAlignment: Text.AlignHCenter
                                                text: wxStat.modelData.caption
                                                color: view.mutedColor
                                                font.pixelSize: 10
                                                font.family: view.fontFamily
                                                font.letterSpacing: 0.6
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // ---- one advisory line, only when the day is worth acting on ----
                                // The stat row already carries the numbers; this
                                // carries the one thing that should change what you
                                // do. First match wins, nothing when it is unremarkable.
                                Rectangle {
                                    id: wxAdvisory
                                    width: parent.width
                                    height: 26
                                    radius: 8
                                    visible: view.weatherAdvisory !== null
                                    color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.13)
                                    border.width: 1
                                    border.color: Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.24)

                                    NotchIcon {
                                        id: wxAdvisoryIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: view.weatherAdvisory ? view.weatherAdvisory.icon : ""
                                        size: 13
                                        color: view.accentColor
                                    }

                                    Text {
                                        anchors.left: wxAdvisoryIcon.right
                                        anchors.leftMargin: 7
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: view.weatherAdvisory ? view.weatherAdvisory.text : ""
                                        color: view.textColor
                                        font.pixelSize: 11
                                        font.family: view.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }

                                // ---- 3-day ----
                                // Rows rather than three columns: a 332 wide card
                                // gives each day a full line, and the range bar is
                                // scaled across the whole week, so the warmest day
                                // is visibly the longest bar instead of just the
                                // biggest number.
                                Item {
                                    width: parent.width
                                    height: 12

                                    Text {
                                        id: wxForecastText
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        text: "3-DAY"
                                        color: view.mutedColor
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        font.family: view.fontFamily
                                        font.letterSpacing: 1.1
                                    }

                                    Rectangle {
                                        anchors.left: wxForecastText.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 3
                                        height: 1
                                        color: view.textColor
                                        opacity: 0.08
                                    }
                                }

                                Repeater {
                                    model: view.weatherData.forecast

                                    delegate: Rectangle {
                                        id: wxDay
                                        required property var modelData
                                        required property int index

                                        readonly property real rain: Number(modelData.rainChance || 0)

                                        width: wxFlow.width
                                        height: 28
                                        radius: 8
                                        // Accent on today alone: it is the only row
                                        // you can still act on.
                                        color: index === 0 ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.12) : "transparent"

                                        Text {
                                            id: wxDayName
                                            anchors.left: parent.left
                                            anchors.leftMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 42
                                            text: view.forecastDayLabel(wxDay.index, wxDay.modelData.date)
                                            color: wxDay.index === 0 ? view.accentColor : view.textColor
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            font.family: view.fontFamily
                                            elide: Text.ElideRight
                                        }

                                        NotchIcon {
                                            id: wxDayIcon
                                            anchors.left: wxDayName.right
                                            anchors.leftMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: view.weatherIconName(wxDay.modelData.condition)
                                            size: 15
                                            color: view.mutedColor
                                        }

                                        Text {
                                            id: wxDayLo
                                            anchors.left: wxDayIcon.right
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 24
                                            horizontalAlignment: Text.AlignRight
                                            text: wxDay.modelData.loC + "\u00B0"
                                            color: view.mutedColor
                                            font.pixelSize: 12
                                            font.family: view.fontFamily
                                        }

                                        Item {
                                            id: wxDayTrack
                                            anchors.left: wxDayLo.right
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            // 188 is everything around the bar: 6 pad
                                            // + 42 day + 4 + 15 icon + 8 + 24 lo +
                                            // 8 + 8 + 24 hi + 8 + 34 rain + 6 pad.
                                            width: Math.max(60, wxDay.width - 188)
                                            height: 4

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 2
                                                color: view.textColor
                                                opacity: 0.10
                                            }

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: parent.height
                                                radius: 2
                                                color: view.accentColor
                                                opacity: 0.8
                                                x: parent.width * view.forecastFrac(wxDay.modelData.loC, false)
                                                width: Math.max(6, parent.width * (view.forecastFrac(wxDay.modelData.hiC, true) - view.forecastFrac(wxDay.modelData.loC, false)))
                                            }
                                        }

                                        Text {
                                            id: wxDayHi
                                            anchors.left: wxDayTrack.right
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 24
                                            text: wxDay.modelData.hiC + "\u00B0"
                                            color: view.textColor
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            font.family: view.fontFamily
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            visible: wxDay.rain > 0

                                            NotchIcon {
                                                name: icons.rain
                                                size: 11
                                                color: view.accentColor
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: wxDay.rain + "%"
                                                color: view.accentColor
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                font.family: view.fontFamily
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- first fetch: the real shapes, filled in ----
                        // A skeleton that mirrors the finished layout does not
                        // jump when the data lands, and unlike a spinner it can
                        // be static - the hub already honours motionScale and a
                        // looping pulse here would ignore it.
                        Item {
                            anchors.fill: parent
                            visible: !view.weatherHasData && view.weatherLoading

                            Column {
                                anchors.fill: parent
                                spacing: 14

                                Item {
                                    width: parent.width
                                    height: 38

                                    Rectangle {
                                        id: wxSkIcon
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 38
                                        height: 38
                                        radius: 10
                                        color: Qt.rgba(1, 1, 1, 0.07)
                                    }

                                    Column {
                                        anchors.left: wxSkIcon.right
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 7

                                        Rectangle {
                                            width: 88
                                            height: 22
                                            radius: 6
                                            color: Qt.rgba(1, 1, 1, 0.07)
                                        }

                                        Rectangle {
                                            width: 150
                                            height: 10
                                            radius: 5
                                            color: Qt.rgba(1, 1, 1, 0.05)
                                        }
                                    }
                                }

                                Row {
                                    id: wxSkStats
                                    width: parent.width
                                    height: 44

                                    Repeater {
                                        model: 4

                                        delegate: Item {
                                            width: (wxSkStats.width - 24) / 4
                                            height: wxSkStats.height

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 46
                                                height: 11
                                                radius: 5
                                                color: Qt.rgba(1, 1, 1, 0.05)
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 9

                                    Repeater {
                                        model: [1, 0.82, 0.64]

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: parent.width * Number(modelData)
                                            height: 11
                                            radius: 5
                                            color: Qt.rgba(1, 1, 1, 0.05)
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Fetching weather\u2026"
                                    color: view.mutedColor
                                    font.pixelSize: 11
                                    font.family: view.fontFamily
                                }
                            }
                        }

                        // ---- nothing to show: say why, and offer the way back ----
                        Item {
                            anchors.fill: parent
                            visible: !view.weatherHasData && !view.weatherLoading

                            Column {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, 240)
                                spacing: 8

                                NotchIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: icons.cloudy
                                    size: 26
                                    color: view.mutedColor
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "No weather data"
                                    color: view.textColor
                                    font.pixelSize: 12
                                    font.family: view.fontFamily
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "Check your connection, or set a city on the first line of ~/.config/omarchy/notch-island-location.txt"
                                    color: view.mutedColor
                                    font.pixelSize: 11
                                    font.family: view.fontFamily
                                    wrapMode: Text.Wrap
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: wxRetryLabel.implicitWidth + 26
                                    height: 24
                                    radius: 12
                                    color: wxRetryArea.containsMouse ? Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.85) : view.accentColor

                                    Behavior on color {
                                        ColorAnimation { duration: 120 * view.speed }
                                    }

                                    Text {
                                        id: wxRetryLabel
                                        anchors.centerIn: parent
                                        text: "Retry"
                                        color: view.accentText
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        font.family: view.fontFamily
                                    }

                                    MouseArea {
                                        id: wxRetryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.refreshWeather()
                                    }
                                }
                            }
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
