import QtQuick
import Quickshell
import Quickshell.Io

// ---------------------------------------------------------------------------
// News.qml
//
// Headlines for the news module. scripts/news.sh fetches an RSS feed into
// ~/.local/state/notch-island/news.json; this service reads that cache live
// (FileView + watchChanges) so headlines update without restarting anything.
// When offline or empty, items is simply [] and the views show a calm hint.
Item {
    id: svc

    property var host: null
    property string scriptsDir: ""

    // World | Tech | Nepal | Custom, mirrored from settings (auto resolved).
    readonly property string topic: host && host.effectiveNewsTopic ? host.effectiveNewsTopic : "world"

    readonly property string cachePath: Quickshell.env("HOME") + "/.local/state/notch-island/news-" + svc.topic + ".json"
    readonly property var items: parsed.items || []
    readonly property real updatedAt: Number(parsed.updated || 0)
    readonly property bool hasItems: items.length > 0
    readonly property string headline: hasItems ? String(items[0].title || "") : ""
    readonly property string headlineSource: hasItems ? String(items[0].source || "") : ""

    readonly property string updatedAgo: {
        if (!updatedAt) return ""
        var mins = Math.max(0, Math.round((Date.now() / 1000 - updatedAt) / 60))
        if (mins < 1) return "just now"
        if (mins < 60) return mins + "m ago"
        var hours = Math.round(mins / 60)
        if (hours < 24) return hours + "h ago"
        return Math.round(hours / 24) + "d ago"
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

    function openLink(url) {
        var link = String(url || "").trim()
        if (link !== "") Quickshell.execDetached(["xdg-open", link])
    }

    FileView {
        id: fileView
        path: svc.cachePath
        watchChanges: true
        printErrors: false
        onLoaded: svc.parseCache(text())
        onFileChanged: reload()
        onLoadFailed: svc.parsed = ({})
    }

    Process {
        id: fetchProc
        command: ["bash", svc.scriptsDir + "/news.sh", svc.topic]
    }

    // Switching topics starts from that topic's cache at once.
    onTopicChanged: {
        svc.parsed = ({})
        fileView.reload()
        svc.refresh()
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
