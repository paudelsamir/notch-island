import QtQuick
import Quickshell
import Quickshell.Io

// ---------------------------------------------------------------------------
// Weather.qml
//
// Weather for the weather module, powered by wttr.in (no API key, location
// by IP). scripts/weather.sh caches the raw wttr.in JSON; this service reads
// that cache live. Offline or empty means hasData is false and the views show
// a calm hint instead of numbers.
Item {
    id: svc

    property var host: null
    property string scriptsDir: ""

    readonly property string cachePath: Quickshell.env("HOME") + "/.local/state/notch-island/weather.json"
    readonly property bool hasData: !!(parsed && parsed.current_condition && parsed.current_condition.length > 0)

    readonly property var current: hasData ? parsed.current_condition[0] : null
    readonly property string city: {
        try {
            var area = parsed.nearest_area[0].areaName[0].value
            return String(area || "")
        } catch (error) {
            return ""
        }
    }
    readonly property string tempC: current ? String(current.temp_C || "") : ""
    readonly property string feelsLikeC: current ? String(current.FeelsLikeC || "") : ""
    readonly property string humidity: current ? String(current.humidity || "") : ""
    readonly property string windKph: current ? String(current.windspeedKmph || "") : ""
    readonly property string description: {
        try { return String(current.weatherDesc[0].value || "") } catch (error) { return "" }
    }
    readonly property string code: current ? String(current.weatherCode || "") : ""
    readonly property real fetchedAt: Number(parsed._fetched || 0)

    readonly property string updatedAgo: {
        if (!fetchedAt) return ""
        var mins = Math.max(0, Math.round(Date.now() / 1000 / 60 - fetchedAt / 60))
        if (mins < 1) return "just now"
        if (mins < 60) return mins + "m ago"
        return Math.round(mins / 60) + "h ago"
    }

    // [{ date, maxC, minC, code, desc }] for today + next 2 days.
    readonly property var days: {
        var out = []
        try {
            var list = parsed.weather || []
            for (var i = 0; i < Math.min(3, list.length); i++) {
                var day = list[i]
                var noon = (day.hourly && day.hourly.length > 4) ? day.hourly[4] : (day.hourly ? day.hourly[0] : null)
                out.push({
                    date: String(day.date || ""),
                    maxC: String(day.maxtempC || ""),
                    minC: String(day.mintempC || ""),
                    code: noon ? String(noon.weatherCode || "") : "",
                    desc: noon ? String((noon.weatherDesc && noon.weatherDesc[0].value) || "") : ""
                })
            }
        } catch (error) {}
        return out
    }

    property var parsed: ({})

    function parseCache(raw) {
        try {
            var data = JSON.parse(String(raw || ""))
            svc.parsed = (data && typeof data === "object") ? data : ({})
        } catch (error) {
            svc.parsed = ({})
        }
    }

    function refresh() {
        if (scriptsDir === "" || fetchProc.running) return
        fetchProc.running = true
    }

    FileView {
        path: svc.cachePath
        watchChanges: true
        printErrors: false
        onLoaded: svc.parseCache(text())
        onFileChanged: reload()
        onLoadFailed: svc.parsed = ({})
    }

    Process {
        id: fetchProc
        command: ["bash", svc.scriptsDir + "/weather.sh"]
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: svc.refresh()
    }

    Component.onCompleted: {
        if (svc.scriptsDir !== "") Qt.callLater(svc.refresh)
    }
}
