import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// ---------------------------------------------------------------------------
// SystemControls.qml
//
// Everything the popup menu needs from the machine, and nothing more:
//   * output volume and mute (PipeWire, direct property access)
//   * output device cycling
//   * screen brightness (scripts/brightness.sh -> brightnessctl)
//   * battery state (UPower)
//   * power actions (scripts/power.sh) and uptime
//
// The user said they only want volume and brightness in the menu, so this
// service deliberately has no other toggles.
// ---------------------------------------------------------------------------
Item {
    id: svc

    property string scriptsDir: ""

    // ---- volume -----------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool hasSink: !!(sink && sink.audio)
    readonly property real volume: hasSink ? Number(sink.audio.volume) : 0
    readonly property bool muted: hasSink ? !!sink.audio.muted : false
    readonly property string sinkName: sink ? String(sink.description || sink.nickname || sink.name || "Output") : "No output"

    // Keep the sink bound so its audio properties stay live.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function setVolume(value) {
        if (!hasSink) return
        var v = Math.max(0, Math.min(1.5, Number(value)))
        sink.audio.muted = false
        sink.audio.volume = v
    }

    function toggleMute() {
        if (hasSink) sink.audio.muted = !sink.audio.muted
    }

    // Material Symbols name for the current state of the speaker.
    readonly property string volumeGlyph: {
        if (!hasSink || muted || volume <= 0.001) return "volume_off"
        if (volume < 0.10) return "volume_mute"
        if (volume < 0.45) return "volume_down"
        return "volume_up"
    }

    // ---- output devices ----------------------------------------------------
    // Hardware sinks only (streams are also sinks in PipeWire's graph).
    readonly property var sinks: {
        var out = []
        var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isSink && !n.isStream && n.audio) out.push(n)
        }
        return out
    }

    function cycleOutput() {
        var list = sinks
        if (list.length < 2) return
        var idx = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] === sink) idx = i
        }
        Pipewire.preferredDefaultAudioSink = list[(idx + 1) % list.length]
    }

    // ---- microphone ---------------------------------------------------------
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool hasMic: !!(mic && mic.audio)
    readonly property real micVolume: hasMic ? Number(mic.audio.volume) : 0
    readonly property bool micMuted: hasMic ? !!mic.audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSource]
    }

    function setMicVolume(value) {
        if (!hasMic) return
        var v = Math.max(0, Math.min(1, Number(value)))
        mic.audio.muted = false
        mic.audio.volume = v
    }

    function toggleMicMute() {
        if (hasMic) mic.audio.muted = !mic.audio.muted
    }

    readonly property string micGlyph: {
        if (!hasMic || micMuted || micVolume <= 0.001) return "mic_off"
        return "mic"
    }

    // ---- brightness --------------------------------------------------------
    // -1 means "not supported on this machine" (no backlight / no brightnessctl).
    property real brightness: -1
    readonly property bool hasBrightness: brightness >= 0

    Process {
        id: brightnessRead
        command: ["bash", svc.scriptsDir + "/brightness.sh", "get"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var n = parseInt(String(text || "").trim())
                svc.brightness = isNaN(n) || n < 0 ? -1 : n / 100
            }
        }
    }

    Process {
        id: brightnessWrite
    }

    // Debounce so dragging the slider does not spawn a process per pixel.
    property real pendingBrightness: -1
    Timer {
        id: brightnessDebounce
        interval: 60
        repeat: false
        onTriggered: {
            if (svc.pendingBrightness < 0) return
            var pct = Math.round(svc.pendingBrightness * 100)
            brightnessWrite.command = ["bash", svc.scriptsDir + "/brightness.sh", "set", String(pct)]
            brightnessWrite.running = true
            svc.pendingBrightness = -1
        }
    }

    function setBrightness(fraction) {
        var f = Math.max(0.01, Math.min(1, Number(fraction)))
        brightness = f
        pendingBrightness = f
        brightnessDebounce.restart()
    }

    function refreshBrightness() {
        if (!brightnessRead.running) brightnessRead.running = true
    }

    Component.onCompleted: {
        refreshBrightness()
        refreshKbdBrightness()
    }

    // ---- keyboard backlight ---------------------------------------------------
    // -1 means unsupported (no kbd_backlight LED class device).
    property real kbdBrightness: -1
    readonly property bool hasKbdBrightness: kbdBrightness >= 0

    Process {
        id: kbdRead
        command: ["bash", svc.scriptsDir + "/kbd-backlight.sh", "get"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var n = parseInt(String(text || "").trim())
                svc.kbdBrightness = isNaN(n) || n < 0 ? -1 : n / 100
            }
        }
    }

    Process {
        id: kbdWrite
    }

    property real pendingKbd: -1
    Timer {
        id: kbdDebounce
        interval: 60
        repeat: false
        onTriggered: {
            if (svc.pendingKbd < 0) return
            var pct = Math.round(svc.pendingKbd * 100)
            kbdWrite.command = ["bash", svc.scriptsDir + "/kbd-backlight.sh", "set", String(pct)]
            kbdWrite.running = true
            svc.pendingKbd = -1
        }
    }

    function setKbdBrightness(fraction) {
        var f = Math.max(0, Math.min(1, Number(fraction)))
        kbdBrightness = f
        pendingKbd = f
        kbdDebounce.restart()
    }

    function refreshKbdBrightness() {
        if (!kbdRead.running) kbdRead.running = true
    }

    // External tools (Fn keys) also change the backlight, so re-read it
    // now and then while the shell is running.
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: svc.refreshKbdBrightness()
    }

    // ---- battery -----------------------------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!(battery && battery.isPresent)
    readonly property real batteryPercent: {
        if (!hasBattery) return 0
        var p = Number(battery.percentage)
        return p <= 1 ? p * 100 : p
    }
    readonly property bool charging: hasBattery && !UPower.onBattery

    // ---- uptime ------------------------------------------------------------
    property string uptime: ""

    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/^up //'"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: svc.uptime = String(text || "").trim()
        }
    }

    function refreshUptime() {
        if (!uptimeProc.running) uptimeProc.running = true
    }

    // ---- power actions -----------------------------------------------------
    Process {
        id: powerProc
    }

    function power(action) {
        powerProc.command = ["bash", svc.scriptsDir + "/power.sh", String(action)]
        powerProc.startDetached()
    }


    // ---- volume helpers -------------------------------------------------------------
    readonly property int volumePercent: Math.round(volume * 100)

    function stepVolume(delta) {
        setVolume(Math.max(0, Math.min(1.5, volume + delta)))
    }

    // ---- brightness helpers ---------------------------------------------------------
    readonly property int brightnessPercent: hasBrightness ? Math.round(brightness * 100) : -1

    function stepBrightness(delta) {
        if (!hasBrightness) return
        setBrightness(Math.max(0.01, Math.min(1, brightness + delta)))
    }

    // External tools (keybindings, other bars) also change the backlight, so
    // re-read it now and then while the shell is running.
    Timer {
        interval: 10000
        repeat: true
        running: svc.hasBrightness
        onTriggered: svc.refreshBrightness()
    }

    // ---- battery helpers --------------------------------------------------------------
    readonly property string batteryLabel: {
        if (!hasBattery) return ""
        var p = Math.round(batteryPercent)
        return (charging ? "Charging " : "") + p + "%"
    }

    // Time until empty / full as "1h 12m", or "" when unknown.
    readonly property string batteryTime: {
        if (!hasBattery) return ""
        var seconds = charging ? Number(battery.timeToFull) : Number(battery.timeToEmpty)
        if (!seconds || seconds <= 0) return ""
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        return (h > 0 ? h + "h " : "") + m + "m"
    }

    readonly property bool batteryLow: hasBattery && !charging && batteryPercent < 15
}
