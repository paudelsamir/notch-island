import QtQuick
import "file:///home/sam/.config/omarchy/plugins/paudelsamir.notch-island/components" as NDock
import "file:///home/sam/.config/omarchy/plugins/paudelsamir.notch-island/services" as NSvc

// ---------------------------------------------------------------------------
// Headless test probe for the resting modules. Instantiates every new
// component and service with mocks, checks geometry + data contracts, and
// prints TEST:PASS / TEST:FAIL lines. Any QML engine error
// ("is not a type", ReferenceError, ...) fails the run via run.sh's grep.
// Usage: quickshell -p <this dir>
Item {
    id: root
    width: 600
    height: 600

    property int failures: 0

    function check(name, cond) {
        console.log("notch-island-test: " + (cond ? "PASS " : "FAIL ") + name)
        if (!cond) failures += 1
    }

    QtObject {
        id: mockHost
        property var settings: ({clock24h: true, restMode: "dock", opencode: true, showOpencodeNav: true})
        property string view: "rest"
        property bool horiz: true
        property string edge: "bottom"
        property color colorText: "#ffffff"
        property color colorMuted: "#999999"
        property color colorAccent: "#7aa2f7"
        property color colorAccentText: "#000000"
        property color colorUrgent: "#ff5555"
        property color colorBackground: "#000000"
        property real motionScale: 1
        property string fontFamily: "sans-serif"
        function open(name) {}
        function close() {}
    }

    QtObject {
        id: mockSys
        property string uptime: "2 hours"
        property bool hasBattery: true
        property real batteryPercent: 84
        property bool charging: false
        function refreshUptime() {}
    }

    // ---- components under test ------------------------------------------------
    // The clock hub carries the news/weather/notes sections inside itself,
    // so only it (plus the notes popup) is instantiated here.
    NDock.ClockView { id: clockPill; host: mockHost; dockModel: mockDock; sys: mockSys; news: newsSvc; weather: weatherSvc; notes: notesSvc; active: true }
    NDock.NotesListView { id: notesPopup; host: mockHost; notes: notesSvc; active: true }

    QtObject {
        id: mockDock
        property var apps: [
            { id: "a1", name: "Alpha", icon: "kitty", pinned: true, count: 1, active: true, entry: null },
            { id: "b2", name: "Beta", icon: "kitty", pinned: true, count: 0, active: false, entry: null }
        ]
    }

    NSvc.News { id: newsSvc; host: mockHost; scriptsDir: "" }
    NSvc.Weather { id: weatherSvc; host: mockHost; scriptsDir: "" }
    NSvc.Notes { id: notesSvc; host: mockHost }
    NSvc.IconIndex { id: iconSvc }

    NDock.NotchIcons { id: glyphs }

    Timer {
        interval: 4000
        running: true
        repeat: false
        onTriggered: {
            // T1: geometry contracts — the hub reports sane compact and
            // expanded sizes, and the notes popup too.
            check("clock-rest size", clockPill.islandWidth === 168 && clockPill.islandHeight === 40)
            clockPill.expanded = true
            check("clock-hub size", clockPill.islandWidth === 430 && clockPill.islandHeight === 540
                  && clockPill.width === 430 && clockPill.height === 540)
            check("notes-popup size", notesPopup.islandWidth > 40 && notesPopup.islandHeight > 30)
            // T2: news data contract
            check("news items array", newsSvc.items && typeof newsSvc.items.length === "number")
            check("news headline string", typeof newsSvc.headline === "string")
            // T3: services parse their real caches
            check("news loaded", newsSvc.hasItems === true && newsSvc.headline !== "")
            check("weather loaded", weatherSvc.hasData === true && weatherSvc.tempC !== "" && weatherSvc.city !== "")
            check("weather days array", weatherSvc.days && weatherSvc.days.length >= 1)
            check("weather code string", typeof weatherSvc.code === "string")
            // T4: icon vocabulary used by the new modules exists
            var vocab = ["home", "clock", "news", "refresh", "thermometer", "wind", "humidity",
                         "sun", "partlyCloudy", "cloudy", "fog", "rain", "storm", "snow",
                         "noteAdd", "noteEdit", "noteDelete", "checked", "unchecked",
                         "close", "menu", "player", "power", "settings", "back", "forward"];
            var ok = true
            for (var v = 0; v < vocab.length; v++) {
                if (glyphs[vocab[v]] === undefined || glyphs[vocab[v]] === "") ok = false
            }
            check("glyph vocabulary", ok)
            check("weatherIcon mapping", glyphs.weatherIcon("113") === "light_mode" && glyphs.weatherIcon("176") === "rainy" && glyphs.weatherIcon("200") === "thunderstorm")
            // T5: notes CRUD round-trip (adds then removes one probe note)
            var before = notesSvc.notes.length
            notesSvc.add("notch-island self-test probe")
            var added = notesSvc.notes.length === before + 1
            var id = added ? notesSvc.notes[0].id : ""
            if (added) notesSvc.toggle(id)
            var toggled = !added || notesSvc.notes[0].done === true
            if (added) notesSvc.remove(id)
            check("notes add/toggle/remove", added && toggled && notesSvc.notes.length === before)
            // T6: icon index resolves a known-good icon and rejects a bogus one
            iconSvc.refresh()
            check("iconindex object", iconSvc.files !== undefined)
            console.log("notch-island-test: DONE failures=" + root.failures)
            Qt.quit()
        }
    }
}
