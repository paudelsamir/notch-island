import QtQuick
import Quickshell
import Quickshell.Io

// ---------------------------------------------------------------------------
// OpenCode.qml
//
// The only AI integration in the notch. It does four things:
//
//   1. sessions   - recent opencode sessions with per-session token totals,
//                   read straight from opencode's sqlite database
//   2. totals     - all-time and today's token usage / cost
//   3. notices    - the newest notification coming from the opencode agent
//                   (finished, needs permission, error ...)
//   4. ask        - run `opencode run` (optionally inside a chosen session)
//                   and stream the answer back
//
// All the heavy lifting lives in scripts/*.sh so it can be tested by hand.
// ---------------------------------------------------------------------------
Item {
    id: svc

    property string scriptsDir: ""
    property bool enabled: true
    property bool notifyEnabled: true
    property string model: ""            // "" = opencode default model

    // ---- sessions ---------------------------------------------------------
    property var sessions: []
    property string selectedSession: ""  // "" = start a new session
    readonly property var selected: {
        for (var i = 0; i < sessions.length; i++) {
            if (sessions[i].id === selectedSession) return sessions[i]
        }
        return null
    }

    Process {
        id: sessionsProc
        command: ["bash", svc.scriptsDir + "/opencode-sessions.sh", "14"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var rows = JSON.parse(String(text || "[]").trim() || "[]")
                    svc.sessions = Array.isArray(rows) ? rows : []
                } catch (e) {
                    svc.sessions = []
                }
            }
        }
    }

    function refreshSessions() {
        if (!enabled || sessionsProc.running) return
        sessionsProc.running = true
    }

    // ---- totals -----------------------------------------------------------
    property var totals: ({
        sessions: 0, messages: 0, input: 0, output: 0, reasoning: 0,
        cacheRead: 0, cacheWrite: 0, cost: 0,
        todayInput: 0, todayOutput: 0, todayCost: 0
    })

    Process {
        id: totalsProc
        command: ["bash", svc.scriptsDir + "/opencode-tokens.sh"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var t = JSON.parse(String(text || "{}").trim() || "{}")
                    svc.totals = t
                } catch (e) {
                    // keep the previous numbers
                }
            }
        }
    }

    function refreshTotals() {
        if (!enabled || totalsProc.running) return
        totalsProc.running = true
    }

    function refresh() {
        refreshSessions()
        refreshTotals()
    }

    // ---- notices from the agent -------------------------------------------
    property var notice: null            // newest notification object
    property string lastNoticeKey: ""
    property bool noticeSeeded: false    // ignore whatever existed at startup
    signal freshNotice(var row)

    Process {
        id: noticeProc
        command: ["bash", svc.scriptsDir + "/opencode-notify.sh"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = String(text || "").trim()
                if (raw === "") {
                    svc.noticeSeeded = true
                    return
                }
                try {
                    var row = JSON.parse(raw)
                    var key = String(row.timestamp) + ":" + String(row.originalId || "")
                    if (key === svc.lastNoticeKey) return
                    svc.lastNoticeKey = key
                    svc.notice = row
                    if (svc.noticeSeeded) svc.freshNotice(row)
                    svc.noticeSeeded = true
                } catch (e) {
                    console.warn("notch-island: bad opencode notice", e)
                }
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: svc.enabled && svc.notifyEnabled
        triggeredOnStart: true
        onTriggered: if (!noticeProc.running) noticeProc.running = true
    }

    // Keep session numbers reasonably fresh in the background.
    Timer {
        interval: 30000
        repeat: true
        running: svc.enabled
        triggeredOnStart: true
        onTriggered: svc.refresh()
    }

    // ---- ask ---------------------------------------------------------------
    property bool asking: false
    property string question: ""
    property string answer: ""
    property string error: ""

    Process {
        id: askProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                svc.answer = svc.answer === "" ? line : svc.answer + "\n" + line
            }
        }
        onExited: function(code) {
            svc.asking = false
            if (code !== 0 && svc.answer === "") svc.error = "opencode exited with code " + code
            // A new turn changes token counters.
            svc.refresh()
        }
    }

    function ask(text) {
        var q = String(text || "").trim()
        if (q === "" || asking || !enabled) return
        question = q
        answer = ""
        error = ""
        asking = true
        askProc.command = ["bash", scriptsDir + "/ask.sh", q, selectedSession, model]
        askProc.running = true
    }

    function cancel() {
        if (askProc.running) askProc.signal(15)
        asking = false
    }

    function clearAnswer() {
        answer = ""
        question = ""
        error = ""
    }

    // ---- launching the TUI -------------------------------------------------
    Process {
        id: openProc
    }

    // Open a terminal running opencode (continuing the selected session).
    function openTui() {
        var cmd = selectedSession !== "" ? "opencode --session " + selectedSession : "opencode"
        openProc.command = ["bash", "-c", "exec ${TERMINAL:-xdg-terminal-exec} -e " + cmd]
        openProc.startDetached()
    }

    // ---- formatting helpers ------------------------------------------------
    // 12345 -> "12.3k", 1500000 -> "1.5M"
    function compact(n) {
        var v = Number(n || 0)
        if (v >= 1000000) return (v / 1000000).toFixed(1) + "M"
        if (v >= 1000) return (v / 1000).toFixed(v >= 100000 ? 0 : 1) + "k"
        return String(Math.round(v))
    }

    function money(n) {
        var v = Number(n || 0)
        if (v <= 0) return "$0"
        return "$" + (v < 1 ? v.toFixed(3) : v.toFixed(2))
    }

    function ago(ms) {
        var d = Date.now() - Number(ms || 0)
        if (!ms || d < 60000) return "now"
        if (d < 3600000) return Math.floor(d / 60000) + "m ago"
        if (d < 86400000) return Math.floor(d / 3600000) + "h ago"
        return Math.floor(d / 86400000) + "d ago"
    }

    // Total tokens of a session row (input + output + reasoning).
    function sessionTokens(row) {
        if (!row) return 0
        return Number(row.input || 0) + Number(row.output || 0) + Number(row.reasoning || 0)
    }
}
