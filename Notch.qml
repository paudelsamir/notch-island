import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "components"
import "services"

// ===========================================================================
// Notch.qml  -  Notch Island
//
// An edge-anchored shell that lives on any side of the screen and changes
// what it shows depending on what is going on:
//
//   rest, nothing playing   the restMode module: the app dock, or the clock
//                           hub (day/time, weather, headlines, quick notes;
//                           hover to expand, click for the menu)
//   rest, media playing     the rest module hides and a media island shows
//                           cover, title marquee and a live equaliser
//   menu                    volume + brightness sliders and shortcuts
//   player                  Now Playing
//   power                   lock / sleep / log out / restart / shut down
//   ask                     opencode: ask, sessions, token usage
//   settings                position, shape, dock, animation, behavior, media, opencode
//   notice                  a transient banner from the opencode agent
//
// ---------------------------------------------------------------------------
// ANIMATION MODEL (this is the fix for the "grows from the centre" bug)
//
// The first version positioned the shell in the middle of the window and
// animated x/y as well as width/height. On the bottom and right edges the
// shell therefore started at the centre, then slid to the edge while the
// popup appeared and moved. This version follows three rules:
//
//   1. The PanelWindow is a fixed, generous strip glued to the chosen edge.
//      It never resizes, so the compositor never has to re-place the surface.
//   2. The shell's x and y are pure bindings of (edge, gap, alignment, size).
//      They are NEVER animated. Only width and height animate, so the side
//      that faces the screen edge stays exactly where it belongs and the
//      shell grows away from it.
//   3. The content stage inside the shell is sized to the *target* size and
//      pinned to the same edge, so content does not slide while the shell
//      is still growing; the shell simply reveals it (clip).
// ===========================================================================
Item {
    id: root

    // ---- provided by the Omarchy shell ---------------------------------------------
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property var barWidgetRegistry: null
    property var barConfig: ({})
    property string omarchyPath: ""

    // Shared Material-style symbolic icons. Components reach these as host.icons.
    NotchIcons {
        id: iconSet
    }
    readonly property var icons: iconSet

    // ---- paths ------------------------------------------------------------------------
    readonly property string home: Quickshell.env("HOME")
    readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")
    readonly property string scriptsDir: pluginDir + "/scripts"
    readonly property string settingsPath: home + "/.config/omarchy/notch-island.json"

    // =======================================================================================
    // SETTINGS
    // Stored in ~/.config/omarchy/notch-island.json, edited live by the settings view.
    // Editing the file by hand works too (watchChanges).
    // =======================================================================================
    readonly property QtObject settings: settingsData

    // The defaults, used by "reset" (right click on a settings row).
    readonly property var defaults: ({
        edge: "top",
        align: "center",
        offset: 0,
        gap: 8,
        mode: "notch",
        roundness: 70,
        earRadius: 12,
        notchWidth: 0,
        notchHeight: 0,
        opacity: 1.0,
        border: false,
        iconSize: 30,
        dockSpacing: 6,
        dockPadding: 8,
        magnify: true,
        magnifyScale: 1.3,
        showDots: true,
        pinned: [],
        animations: true,
        stickyNav: true,
        showOpencodeNav: true,
        showVolume: true,
        showBrightness: true,
        showKbd: true,
        showMic: true,
        clickOutsideClose: true,
        openMode: "hover",
        dotsSide: "auto",
        restMode: "clock",
        displayMode: "clock",
        hubTab: "news",
        newsTopic: "auto",
        animStyle: "spring",
        motionScale: 1.0,
        smoothness: 60,
        hoverLift: true,
        mediaPill: true,
        coverTint: true,
        coverRoundness: 28,
        opencode: true,
        opencodeNotify: true,
        bannerSeconds: 6,
        aiModel: "",
        monitor: "",
        clock24h: true,
        fontFamily: "sans-serif"
    })

    FileView {
        path: root.settingsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: function(error) {
            if (error !== FileViewError.FileNotFound) return
            writeAdapter()
            Qt.callLater(reload)
        }

        JsonAdapter {
            id: settingsData

            // -- position --
            property string edge: "top"            // top | bottom | left | right
            property string align: "center"        // start | center | end
            property real offset: 0                // px along the edge
            property real gap: 8                   // px from the edge (pill mode)

            // -- shape --
            property string mode: "notch"          // notch | pill
            property real roundness: 70            // 0..100
            property real notchWidth: 0            // 0 = fit content, else minimum px
            property real notchHeight: 0           // 0 = fit content, else minimum px
            property real earRadius: 12           // 0..24, curve where the notch meets the bar
            property real opacity: 1.0             // 0.4..1
            property bool border: false

            // -- dock --
            property real iconSize: 30
            property real dockSpacing: 6
            property real dockPadding: 8
            property bool magnify: true
            property real magnifyScale: 1.3
            property bool showDots: true
            property var pinned: []
            property string openMode: "hover"       // hover | click
            property string dotsSide: "auto"        // auto | above | below

            // -- animation --
            property bool animations: true
            property bool stickyNav: true
            property bool showOpencodeNav: true
            property bool showVolume: true
            property bool showBrightness: true
            property bool showKbd: true
            property bool showMic: true
            property bool clickOutsideClose: true
            property string displayMode: "clock"    // clock | date | both | system | weather | none
            property string hubTab: "news"           // news | weather | notes
            property string newsTopic: "auto"         // auto | world | tech | nepal | custom
            property string restMode: "clock"    // dock | clock | news | weather | notes
            property string animStyle: "spring"    // spring | smooth | snappy
            property real motionScale: 1.0
            property real smoothness: 60           // 0..100
            property bool hoverLift: true

            // -- media --
            property bool mediaPill: true
            property bool coverTint: true
            property real coverRoundness: 28

            // -- opencode --
            property bool opencode: true
            property bool opencodeNotify: true
            property real bannerSeconds: 6
            property string aiModel: ""

            // -- misc --
            property string monitor: ""
            property bool clock24h: true
            property string fontFamily: "sans-serif"
        }
    }

    // =======================================================================================
    // THEME
    // Text and accent follow the current Omarchy theme; the shell itself stays
    // dark so it always looks like a notch.
    // =======================================================================================
    readonly property string fontFamily: settings.fontFamily !== "" ? settings.fontFamily : "sans-serif"
    readonly property color colorBackground: "#000000"
    readonly property bool themeTextIsLight: luminance(Color.foreground) > 0.5
    readonly property color colorText: themeTextIsLight ? Color.foreground : Color.background
    readonly property color colorMuted: themeTextIsLight ? Color.muted : withAlpha(colorText, 0.6)
    readonly property color colorAccent: Color.accent
    readonly property color colorAccentText: contrastOn(Color.accent)
    readonly property color colorUrgent: Color.urgent
    readonly property color colorSurface: Qt.tint(colorBackground, withAlpha(colorText, 0.07))

    // ---------------------------------------------------------------------------------------
    // Live theme reload.
    //
    // Color.qml loads colors.toml once at startup with watchChanges: false, because the
    // Omarchy shell pushes a palette over IPC on every theme switch. A standalone
    // `quickshell -p` instance is not on that socket, so it would keep painting the accent
    // that happened to be active when it started, which looks like the plugin is not
    // theme aware at all.
    //
    // omarchy-theme-set does `rm -rf` then `mv` on current/theme, so watching colors.toml
    // directly is unreliable: the inode it was watching is destroyed. It does, however,
    // rewrite current/theme.name in place with a plain redirect, after the new theme
    // directory is already in place, so that file is a dependable trigger. Reload through
    // reload() because text() is stale inside the change signal itself.
    // ---------------------------------------------------------------------------------------
    property FileView themeNameFile: FileView {
        id: themeNameFile
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
        watchChanges: true
        printErrors: false
        onFileChanged: themeColorsFile.reload()
    }

    property FileView themeColorsFile: FileView {
        id: themeColorsFile
        path: Color.currentThemePath + "/colors.toml"
        watchChanges: false
        printErrors: false
        onLoaded: {
            Color.loadColors(text())
            Color.loadShell(themeShellFile.text())
            Style.scheduleRefresh()
        }
        onLoadFailed: Color.loadShell("")
    }

    property FileView themeShellFile: FileView {
        id: themeShellFile
        path: Color.currentThemePath + "/shell.toml"
        watchChanges: false
        printErrors: false
    }

    // the shell fill including the user's opacity setting
    readonly property color colorShell: withAlpha(colorBackground, clampNumber(settings.opacity, 0.4, 1))

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function luminance(x) {
        return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b
    }

    function contrastOn(c) {
        var l = luminance(c)
        return Math.abs(l - luminance(colorBackground)) > Math.abs(l - luminance(colorText)) ? colorBackground : colorText
    }

    function clampNumber(v, lo, hi) {
        var n = Number(v)
        if (isNaN(n)) return lo
        return Math.max(lo, Math.min(hi, n))
    }

    // =======================================================================================
    // GEOMETRY DERIVED FROM SETTINGS
    // Every value is sanitised here so a hand-edited config can never break layout.
    // =======================================================================================
    readonly property string edge: ["top", "bottom", "left", "right"].indexOf(settings.edge) >= 0 ? settings.edge : "top"
    readonly property string align: ["start", "center", "end"].indexOf(settings.align) >= 0 ? settings.align : "center"
    readonly property bool horiz: edge === "top" || edge === "bottom"
    readonly property bool notchMode: settings.mode !== "pill"
    readonly property real gapPx: notchMode ? 0 : clampNumber(settings.gap, 0, 64)
    readonly property real alongOffset: clampNumber(settings.offset, -1200, 1200)
    readonly property real edgeMargin: 12          // keep clear of screen corners

    // motion
    readonly property bool animOn: settings.animations
    readonly property bool stickyNav: settings.stickyNav !== false
    readonly property bool closeOnOutsideClick: settings.closeOnOutsideClick !== false
    readonly property real motionScale: clampNumber(settings.motionScale, 0.3, 3)
    readonly property string animStyle: ["spring", "smooth", "snappy"].indexOf(settings.animStyle) >= 0 ? settings.animStyle : "spring"
    readonly property real smoothness: clampNumber(settings.smoothness, 0, 100) / 100

    // size of the strip the PanelWindow occupies across the edge (fixed on purpose)
    readonly property int windowThickness: 700

    // which monitor the notch is on
    readonly property string wantedOutput: settings.monitor !== "" ? String(settings.monitor) : String(barConfig.output || "")
    readonly property string outputName: {
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++) {
            if (wantedOutput !== "" && screens[i].name === wantedOutput) return wantedOutput
        }
        var focused = Hyprland.focusedMonitor
        if (focused && focused.name) return String(focused.name)
        return screens.length ? String(screens[0].name) : ""
    }

    // =======================================================================================
    // SERVICES
    // =======================================================================================
    Media {
        id: mediaSvc
        host: root
    }

    SystemControls {
        id: sysSvc
        scriptsDir: root.scriptsDir
    }

    OpenCode {
        id: ocSvc
        scriptsDir: root.scriptsDir
        enabled: root.settings.opencode
        notifyEnabled: root.settings.opencodeNotify
        model: root.settings.aiModel
        onFreshNotice: function(row) { root.showNotice(row) }
    }

    DockModel {
        id: dockSvc
        host: root
    }

    News {
        id: newsSvc
        host: root
        scriptsDir: root.scriptsDir
        // Follow the user's pick, resolved through the same "auto" rule the
        // chips show, so the service reads the cache news.sh actually writes.
        topic: root.effectiveNewsTopic
    }

    Weather {
        id: weatherSvc
        host: root
        scriptsDir: root.scriptsDir
    }

    Notes {
        id: notesSvc
        host: root
    }

    IconIndex {
        id: iconIndexSvc
    }

    // exposed so components can reach them through `host` if they ever need to
    readonly property var media: mediaSvc
    readonly property var sys: sysSvc
    readonly property var opencode: ocSvc
    readonly property var dockModel: dockSvc
    readonly property var news: newsSvc
    readonly property var weather: weatherSvc
    readonly property var notes: notesSvc
    readonly property var iconIndex: iconIndexSvc

    // =======================================================================================
    // VIEW STATE
    // =======================================================================================
    property string view: "rest"
    // Live refs for diagnostics (set by the island/clock on completion).
    property var islandRef: null
    property var clockRef: null
    property string settingsPage: ""
    property string dockHoverName: ""
    property var noticeRow: null
    property bool contentReady: true

    readonly property var popupNames: ["menu", "player", "power", "ask", "settings"]
    readonly property bool surfaceOpen: popupNames.indexOf(view) !== -1

    // The dock steps aside while a track plays. Resting is either the dock
    // or the clock hub (which itself carries news, weather and notes).
    // The pill lingers briefly after pausing so the cover does not vanish
    // the instant playback stops; the dock returns when the timer lapses
    // (browser players otherwise hold their last track forever).
    property bool pauseLinger: false
    Timer {
        id: lingerTimer
        interval: 45000
        repeat: false
        onTriggered: root.pauseLinger = false
    }
    Connections {
        target: mediaSvc
        function onIsPlayingChanged() {
            if (mediaSvc.isPlaying) {
                lingerTimer.stop()
                root.pauseLinger = false
            } else if (mediaSvc.hasTrack) {
                root.pauseLinger = true
                lingerTimer.restart()
            }
        }
    }
    readonly property bool mediaActive: settings.mediaPill
        && (mediaSvc.isPlaying || (pauseLinger && mediaSvc.hasTrack))
    readonly property string restMode: settings.restMode === "clock" ? "clock" : "dock"

    // "auto" is a real topic now, not a stand-in for world: news.sh pulls from
    // every pool at once and reshuffles, which is the whole point of the chip.
    // An explicit pick always wins and persists.
    readonly property string effectiveNewsTopic: settings.newsTopic || "auto"
    readonly property string restKind: mediaActive ? "media" : restMode

    // what is on screen right now: "dock", "media" or one of the view names
    readonly property string surfaceKey: view === "rest" ? restKind : view

    function open(name) {
        if (name === "rest" || name === "") {
            close()
            return
        }
        if (name === "settings" && view !== "settings") settingsPage = ""
        if (name === "ask" && ocSvc.enabled) ocSvc.refresh()
        view = name
    }

    // When an explicit close just happened, hover must not instantly
    // reopen under a stationary cursor (close-tap would look broken).
    // Kept short so a deliberate re-hover still feels instant.
    property double lastCloseStamp: 0
    readonly property bool freshClose: (Date.now() - lastCloseStamp) < 350

    function close() {
        lastCloseStamp = Date.now()
        view = "rest"
    }

    function toggleView(name) {
        if (view === name) close()
        else open(name)
        return view
    }

    // ---- opencode agent banner --------------------------------------------------------
    function showNotice(row) {
        // never interrupt a popup the user is working in
        if (surfaceOpen) return
        noticeRow = row
        view = "notice"
    }

    function dismissNotice() {
        if (view === "notice") view = "rest"
    }

    // reveal content shortly after the shell has started to grow
    onViewChanged: {
        if (view !== "rest" && view !== "notice") {
            contentReady = false
            revealTimer.restart()
        } else {
            contentReady = true
            revealTimer.stop()
        }
        if (view === "rest" || view === "notice") dockHoverName = ""
    }

    Timer {
        id: revealTimer
        interval: root.animOn ? 90 * root.motionScale : 0
        repeat: false
        onTriggered: root.contentReady = true
    }

    // Recreate the windows when the edge changes so the layer-shell anchors are
    // rebuilt cleanly instead of being mutated in place.
    property bool windowsEnabled: true

    onEdgeChanged: {
        windowsEnabled = false
        rebuildTimer.restart()
    }

    Timer {
        id: rebuildTimer
        interval: 80
        repeat: false
        onTriggered: root.windowsEnabled = true
    }

    // =======================================================================================
    // IPC   (scripts/ipc.sh wraps these for keybindings)
    // =======================================================================================
    IpcHandler {
        target: "paudelsamir.notch-island"

        function show(name: string): string {
            root.open(String(name))
            return root.view
        }

        function toggle(): string {
            return root.toggleView("menu")
        }

        function close(): string {
            root.close()
            return "rest"
        }

        function settingsPage(page: string): string {
            root.settingsPage = String(page)
            root.view = "settings"
            return root.view
        }

        function setEdge(edge: string): string {
            if (["top", "bottom", "left", "right"].indexOf(edge) >= 0) root.settings.edge = edge
            return root.settings.edge
        }

        function setMode(mode: string): string {
            if (mode === "notch" || mode === "pill") root.settings.mode = mode
            return root.settings.mode
        }

        function ask(question: string): string {
            root.open("ask")
            ocSvc.ask(String(question))
            return root.view
        }

        // Move to the next edge: top -> right -> bottom -> left -> top
        function cycleEdge(): string {
            return root.cycleEdge()
        }

        // Resting module: dock | clock (the clock hub carries news,
        // weather and notes sections inside itself)
        function setRest(mode: string): string {
            if (mode === "dock" || mode === "clock") root.settings.restMode = mode
            return root.settings.restMode
        }

        // Flip between the two resting modules
        function cycleRest(): string {
            var next = root.restMode === "clock" ? "dock" : "clock"
            root.settings.restMode = next
            return next
        }

        // Shift the notch along its edge by a number of pixels (negative = back)
        function nudge(pixels: string): string {
            root.nudge(Number(pixels))
            return String(root.settings.offset)
        }

        // Pin or unpin an app by its desktop / app id
        function pin(id: string): string {
            dockSvc.pin(String(id))
            return "pinned"
        }

        function unpin(id: string): string {
            dockSvc.unpin(String(id))
            return "unpinned"
        }

        // One-line JSON with the current state, handy for scripts and bug reports
        function state(): string {
            return root.stateJson()
        }

        // TEMPORARY diagnostic for the vertical-clock work.
        function clockDbg(): string {
            var c = root.clockRef
            if (!c) return "no-clock-ref"
            return JSON.stringify({
                horiz: root.horiz, edge: root.edge,
                vertical: c.vertical, expanded: c.expanded,
                islandW: c.islandWidth, islandH: c.islandHeight,
                w: c.width, h: c.height,
                active: c.active, op: c.opacity, vis: c.visible,
                label: c.compactLabel, mode: c.displayMode,
                tw: root.islandRef ? root.islandRef.targetW : -1,
                th: root.islandRef ? root.islandRef.targetH : -1,
                iw: root.islandRef ? root.islandRef.width : -1,
                ih: root.islandRef ? root.islandRef.height : -1
            })
        }

        // TEMPORARY diagnostic: what icon data does the dock have?
        function dockApps(): string {
            var out = []
            var apps = dockSvc.apps
            for (var i = 0; i < apps.length; i++) {
                var a = apps[i]
                out.push({id: a.id, name: a.name, icon: a.icon, hasEntry: !!(a.entry), entryIcon: a.entry ? a.entry.icon : null})
            }
            return JSON.stringify(out)
        }
    }

    // =======================================================================================
    // THE WINDOWS
    // One PanelWindow per screen, only visible on the chosen output.
    // =======================================================================================
    Variants {
        model: root.windowsEnabled ? Quickshell.screens : []

        delegate: Component {
            PanelWindow {
                id: window
                required property var modelData

                screen: modelData
                visible: modelData.name === root.outputName
                color: "transparent"
                surfaceFormat.opaque: false
                exclusionMode: ExclusionMode.Ignore

                // A fixed strip along the chosen edge. It never changes size
                // while animating, only when the edge itself changes.
                anchors {
                    top: !root.horiz || root.edge === "top"
                    bottom: !root.horiz || root.edge === "bottom"
                    left: root.horiz || root.edge === "left"
                    right: root.horiz || root.edge === "right"
                }

                implicitHeight: root.horiz ? root.windowThickness : 0
                implicitWidth: root.horiz ? 0 : root.windowThickness

                WlrLayershell.namespace: "omarchy-notch-island"
                WlrLayershell.layer: WlrLayer.Overlay
                // Keyboard focus for popups, plus the clock hub's notes input
                // at rest (it only asks while expanded).
                WlrLayershell.keyboardFocus: island.activeSurface && island.activeSurface.wantsKeyboard
                                              && (root.surfaceOpen || root.view === "rest")
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

                // only the shell itself takes pointer input at rest (the rest of
                // the strip is click-through); with a popup open or the hub
                // expanded, the mask widens to the whole strip so an outside
                // tap can minimize.
                mask: Region {
                    item: (root.closeOnOutsideClick && (root.surfaceOpen || clockView.expanded)) ? stripCatcher : island
                }

                // ---- click outside closes a popup ---------------------------------------
                // This grab is opt-out: disable "Click-outside close" in Settings
                // > Behavior to keep a popup open until Esc or navigation is used.
                HyprlandFocusGrab {
                    id: focusGrab
                    windows: [window]
                    property bool armed: false
                    active: root.closeOnOutsideClick && window.visible && root.surfaceOpen && armed
                    onCleared: if (root.surfaceOpen) root.close()
                }

                Timer {
                    interval: 120
                    running: root.surfaceOpen
                    onTriggered: focusGrab.armed = true
                }

                Connections {
                    target: root
                    function onSurfaceOpenChanged() {
                        if (!root.surfaceOpen) focusGrab.armed = false
                    }
                }

                // ---- inverted corners that make a notch grow out of the edge -----------
                NotchEars {
                    anchors.fill: parent
                    shell: island
                    edge: root.edge
                    color: root.colorShell
                    radius: root.clampNumber(root.settings.earRadius, 0, 24)
                    strokeColor: root.withAlpha(root.colorText, 0.14)
                    strokeWidth: root.settings.border ? 1 : 0
                    active: root.notchMode
                    z: 0
                }

                // =======================================================================
                // THE SHELL
                // =======================================================================
                Rectangle {
                    id: island
                    z: 1
                    Component.onCompleted: root.islandRef = this

                    // ---- what to show and how big it wants to be ----------------------
                    // The clock/news/weather rest pills are gone: the clock hub
                    // carries news, weather and notes sections inside itself.
                    // Only the notes editor opens a separate popup.
                    readonly property Item activeSurface: {
                        if (root.view === "rest") {
                            switch (root.restKind) {
                            case "media":    return mediaView
                            case "clock":    return clockView
                            default:         return dockView
                            }
                        }
                        switch (root.view) {
                        case "menu":     return clockView
                        case "player":   return playerView
                        case "power":    return powerView
                        case "ask":      return askView
                        case "settings": return settingsView
                        case "notes":    return notesListView
                        case "notice":   return noticeView
                        default:         return dockView
                        }
                    }

                    // Manual size from Settings > Shape. 0 = fit content.
                    // It applies to the collapsed resting pill only (dock or
                    // compact clock): hover expansion, the media island and
                    // popups always fit their content. Any positive value is
                    // honored exactly, even if content clips: your call.
                    readonly property real manualW: Number(root.settings.notchWidth) || 0
                    readonly property real manualH: Number(root.settings.notchHeight) || 0
                    readonly property bool collapsedRest: root.view === "rest" && root.restKind !== "media" && !clockView.expanded
                    readonly property real targetW: activeSurface ? (collapsedRest && manualW > 0 ? manualW : Math.max(48, activeSurface.islandWidth)) : 120
                    readonly property real targetH: activeSurface ? (collapsedRest && manualH > 0 ? manualH : Math.max(32, activeSurface.islandHeight + popupChromeH)) : 44
                    readonly property real popupChromeH: 0

                    // ---- animated size ---------------------------------------------------
                    // Two shadow properties, one per animation style. Exactly one of them
                    // is used at a time, so switching style in the settings applies at once.
                    readonly property real springStiffness: 4.6 / root.motionScale
                    readonly property real springDamping: 0.16 + root.smoothness * 0.44

                    property real springW: targetW
                    property real springH: targetH

                    Behavior on springW {
                        enabled: root.animOn && root.animStyle === "spring"
                        SpringAnimation {
                            spring: island.springStiffness
                            damping: island.springDamping
                            epsilon: 0.25
                        }
                    }

                    Behavior on springH {
                        enabled: root.animOn && root.animStyle === "spring"
                        SpringAnimation {
                            spring: island.springStiffness
                            damping: island.springDamping
                            epsilon: 0.25
                        }
                    }

                    readonly property int tweenMs: (root.animStyle === "snappy" ? 170 : 340) * root.motionScale
                    readonly property int tweenEase: root.animStyle === "snappy" ? Easing.OutQuart : Easing.InOutCubic

                    property real tweenW: targetW
                    property real tweenH: targetH

                    Behavior on tweenW {
                        enabled: root.animOn && root.animStyle !== "spring"
                        NumberAnimation {
                            duration: island.tweenMs
                            easing.type: island.tweenEase
                        }
                    }

                    Behavior on tweenH {
                        enabled: root.animOn && root.animStyle !== "spring"
                        NumberAnimation {
                            duration: island.tweenMs
                            easing.type: island.tweenEase
                        }
                    }

                    // Floors keep the auto-sized shell sane; an explicit manual
                    // size bypasses them (it can still clip content).
                    readonly property bool manualSize: collapsedRest && (manualW > 0 || manualH > 0)
                    width: root.animOn ? (manualSize ? (root.animStyle === "spring" ? springW : tweenW) : Math.max(40, root.animStyle === "spring" ? springW : tweenW)) : targetW
                    height: root.animOn ? (manualSize ? (root.animStyle === "spring" ? springH : tweenH) : Math.max(28, root.animStyle === "spring" ? springH : tweenH)) : targetH

                    // ---- position: bindings only, never animated ---------------------------
                    // Position along the edge from alignment + offset, clamped on screen.
                    function along(total, size) {
                        var base
                        if (root.align === "start") base = root.edgeMargin
                        else if (root.align === "end") base = total - size - root.edgeMargin
                        else base = (total - size) / 2
                        var p = base + root.alongOffset
                        return Math.max(root.edgeMargin, Math.min(total - size - root.edgeMargin, p))
                    }

                    x: root.horiz
                       ? along(parent.width, width)
                       : (root.edge === "left" ? root.gapPx : parent.width - width - root.gapPx)

                    y: root.horiz
                       ? (root.edge === "top" ? root.gapPx : parent.height - height - root.gapPx)
                       : along(parent.height, height)

                    // ---- look ---------------------------------------------------------------
                    color: root.colorShell
                    clip: true
                    border.width: root.settings.border ? 1 : 0
                    border.color: root.withAlpha(root.colorText, 0.14)

                    Behavior on color {
                        ColorAnimation { duration: 240 * root.motionScale }
                    }

                    // Corner radius: roundness slider scales a per-surface cap, and the
                    // corners that touch the screen edge stay square in notch mode.
                    readonly property real radiusCap: (root.surfaceOpen ? 34 : 26) * (root.clampNumber(root.settings.roundness, 0, 100) / 70)
                    property real animatedRadius: radiusCap

                    Behavior on animatedRadius {
                        enabled: root.animOn
                        NumberAnimation { duration: 300 * root.motionScale; easing.type: Easing.OutQuint }
                    }

                    readonly property real farRadius: Math.max(0, Math.min(Math.min(width, height) / 2, animatedRadius))
                    readonly property real nearRadius: root.notchMode ? 0 : farRadius

                    topLeftRadius: (root.edge === "top" || root.edge === "left") ? nearRadius : farRadius
                    topRightRadius: (root.edge === "top" || root.edge === "right") ? nearRadius : farRadius
                    bottomLeftRadius: (root.edge === "bottom" || root.edge === "left") ? nearRadius : farRadius
                    bottomRightRadius: (root.edge === "bottom" || root.edge === "right") ? nearRadius : farRadius

                    // ---- hover lift (pill mode only, at rest) -----------------------------------
                    transformOrigin: root.edge === "top" ? Item.Top
                                   : root.edge === "bottom" ? Item.Bottom
                                   : root.edge === "left" ? Item.Left : Item.Right

                    scale: root.view === "rest" && shellHover.hovered && root.settings.hoverLift && !root.notchMode ? 1.05 : 1

                    Behavior on scale {
                        NumberAnimation { duration: 220 * root.motionScale; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }

                    HoverHandler {
                        id: shellHover
                    }

                    // Hover mode: leaving the island minimizes an open
                    // popup, so hover works end to end with no clicks.
                    // Click mode never auto-closes; Esc, the X, a nav jump
                    // or an outside tap does that instead.
                    Timer {
                        id: hoverCloseTimer
                        interval: 2000
                        repeat: false
                        onTriggered: {
                            if (root.surfaceOpen && root.settings.openMode !== "click") root.close()
                        }
                    }

                    Connections {
                        target: shellHover
                        function onHoveredChanged() {
                            if (root.settings.openMode === "click" || !root.surfaceOpen) {
                                hoverCloseTimer.stop()
                                return
                            }
                            if (shellHover.hovered) hoverCloseTimer.stop()
                            else hoverCloseTimer.restart()
                        }
                    }

                    // =======================================================================
                    // THE STAGE
                    // Sized to the target and pinned to the same edge as the shell, so
                    // content stays put while the shell grows or shrinks around it.
                    // =======================================================================
                    Item {
                        id: stage
                        width: island.targetW
                        height: island.targetH - island.popupChromeH

                        x: root.horiz
                           ? (island.width - width) / 2
                           : (root.edge === "left" ? 0 : island.width - width)

                        y: root.horiz
                           ? (root.edge === "top" ? 0 : island.height - height - island.popupChromeH)
                           : (island.height - height - island.popupChromeH) / 2

                        // ---- dock ------------------------------------------------------------
                        DockView {
                            id: dockView
                            host: root
                            model: dockSvc
                            anchors.centerIn: parent
                            active: root.surfaceKey === "dock"
                            opacity: root.surfaceKey === "dock" ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: (root.surfaceKey === "dock" ? 200 : 100) * root.motionScale }
                            }
                        }

                        // ---- media island ------------------------------------------------------------
                        MediaPill {
                            id: mediaView
                            host: root
                            media: mediaSvc
                            anchors.centerIn: parent
                            active: root.surfaceKey === "media"
                            opacity: root.surfaceKey === "media" ? 1 : 0
                            visible: opacity > 0.01
                            onOpenPlayer: root.open("player")

                            Behavior on opacity {
                                NumberAnimation { duration: (root.surfaceKey === "media" ? 200 : 100) * root.motionScale }
                            }
                        }

                        // ---- resting modules ---------------------------------------------------
                        // Resting is the dock or the clock hub (which carries
                        // news, weather and notes sections inside itself).
                        // The clock hub IS the menu: opening "menu" lands here.
                        ClockView {
                            id: clockView
                            host: root
                            dockModel: dockSvc
                            sys: sysSvc
                            news: newsSvc
                            weather: weatherSvc
                            notes: notesSvc
                            anchors.centerIn: parent
                            active: (root.view === "rest" && root.restKind === "clock") || root.view === "menu"
                            opacity: active ? 1 : 0
                            visible: opacity > 0.01
                            Component.onCompleted: root.clockRef = this

                            Behavior on opacity {
                                NumberAnimation { duration: (clockView.active ? 200 : 100) * root.motionScale }
                            }
                        }
                    }

                    // ---- opencode banner ---------------------------------------------------------
                        OpenCodeBanner {
                            id: noticeView
                            host: root
                            row: root.noticeRow
                            anchors.centerIn: parent
                            active: root.view === "notice"
                            seconds: Math.round(root.settings.bannerSeconds)
                            opacity: root.view === "notice" ? 1 : 0
                            visible: opacity > 0.01
                            onOpenRequested: root.open("ask")
                            onDismissed: root.dismissNotice()

                            Behavior on opacity {
                                NumberAnimation { duration: (root.view === "notice" ? 200 : 100) * root.motionScale }
                            }
                        }

                        // ---- popups ------------------------------------------------------------------

                        NowPlayingView {
                            id: playerView
                            host: root
                            media: mediaSvc
                            anchors.centerIn: parent
                            active: root.view === "player"
                            opacity: root.view === "player" && root.contentReady ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: (root.view === "player" ? 200 : 90) * root.motionScale }
                            }
                        }

                        PowerMenuView {
                            id: powerView
                            host: root
                            sys: sysSvc
                            anchors.centerIn: parent
                            active: root.view === "power"
                            opacity: root.view === "power" && root.contentReady ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: (root.view === "power" ? 200 : 90) * root.motionScale }
                            }
                        }

                        AskAiView {
                            id: askView
                            host: root
                            oc: ocSvc
                            anchors.centerIn: parent
                            active: root.view === "ask"
                            opacity: root.view === "ask" && root.contentReady ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: (root.view === "ask" ? 200 : 90) * root.motionScale }
                            }
                        }

                        SettingsView {
                            id: settingsView
                            host: root
                            dockModel: dockSvc
                            anchors.centerIn: parent
                            active: root.view === "settings"
                            opacity: root.view === "settings" && root.contentReady ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: (root.view === "settings" ? 200 : 90) * root.motionScale }
                            }
                        }

                        // ---- module detail popups ------------------------------------------------
                        // Only notes opens a separate popup; clock/news/weather
                        // expand in place on hover.
                        NotesListView {
                            id: notesListView
                            host: root
                            notes: notesSvc
                            anchors.centerIn: parent
                            active: root.view === "notes"
                            opacity: root.view === "notes" && root.contentReady ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation { duration: (root.view === "notes" ? 200 : 90) * root.motionScale }
                            }
                        }

                    // ---- background click handling for the resting states ------------------------
                    // Middle click on the resting shell toggles the menu; the dock and the
                    // media pill handle their own left/right clicks above this.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        enabled: root.view === "rest"
                        acceptedButtons: Qt.MiddleButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) root.open("settings")
                            else root.toggleView("menu")
                        }
                    }

                    // ---- outside tap minimizes -------------------------------------------------
                    // The focus grab only fires when another window takes focus, so
                    // tapping the wallpaper would never close anything. While a
                    // popup is open - or the resting hub is expanded - the input
                    // mask widens to the whole strip and this catcher (behind
                    // the island) minimizes on any click.
                    // It honors the same "Click-outside close" setting as the grab.
                    MouseArea {
                        id: stripCatcher
                        anchors.fill: parent
                        z: -2
                        enabled: root.closeOnOutsideClick && (root.surfaceOpen || clockView.expanded)
                        onClicked: {
                            if (root.surfaceOpen) root.close()
                            else clockView.expanded = false
                        }
                    }
                }
            }
        }
    }

    // =======================================================================================
    // HELPERS
    // Small actions that are used by IPC, keybinds and the settings pane.
    // =======================================================================================

    // Human readable name for an edge, used in logs and the state dump.
    function edgeLabel(e) {
        switch (e) {
        case "top":    return "Top"
        case "bottom": return "Bottom"
        case "left":   return "Left"
        case "right":  return "Right"
        }
        return "Top"
    }

    // top -> right -> bottom -> left -> top
    function cycleEdge() {
        var order = ["top", "right", "bottom", "left"]
        var next = order[(order.indexOf(edge) + 1) % order.length]
        settings.edge = next
        return next
    }

    // Move along the edge without opening the settings pane.
    function nudge(pixels) {
        var n = Number(pixels)
        if (isNaN(n)) return
        settings.offset = clampNumber(Number(settings.offset) + n, -1200, 1200)
    }

    // Put every setting back to its default.
    function resetAll() {
        for (var key in defaults) {
            if (settings[key] !== undefined) settings[key] = defaults[key]
        }
    }

    // Snapshot of what the notch is doing, as one line of JSON.
    function stateJson() {
        var snapshot = {
            view: view,
            surface: surfaceKey,
            restMode: restMode,
            edge: edge,
            align: align,
            mode: settings.mode,
            output: outputName,
            playing: mediaSvc.isPlaying,
            track: mediaSvc.title,
            apps: dockSvc.apps.length,
            pinned: settings.pinned.length,
            opencode: ocSvc.enabled,
            sessions: ocSvc.sessions.length
        }
        return JSON.stringify(snapshot)
    }

    // Clamp values that were edited by hand to something the layout can survive.
    // Runs whenever the settings file is (re)loaded.
    function normalizeSettings() {
        if (["top", "bottom", "left", "right"].indexOf(settings.edge) < 0) settings.edge = defaults.edge
        if (["start", "center", "end"].indexOf(settings.align) < 0) settings.align = defaults.align
        if (["notch", "pill"].indexOf(settings.mode) < 0) settings.mode = defaults.mode
        if (["spring", "smooth", "snappy"].indexOf(settings.animStyle) < 0) settings.animStyle = defaults.animStyle
        if (settings.restMode !== "dock" && settings.restMode !== "clock") settings.restMode = defaults.restMode
        if (["clock", "date", "both", "system", "weather", "none"].indexOf(settings.displayMode) < 0) settings.displayMode = defaults.displayMode
        if (["news", "weather", "notes"].indexOf(settings.hubTab) < 0) settings.hubTab = defaults.hubTab
        if (["auto", "world", "tech", "nepal", "custom"].indexOf(settings.newsTopic) < 0) settings.newsTopic = defaults.newsTopic
        if (typeof settings.stickyNav !== "boolean") settings.stickyNav = defaults.stickyNav
        if (typeof settings.showOpencodeNav !== "boolean") settings.showOpencodeNav = defaults.showOpencodeNav
        if (typeof settings.showVolume !== "boolean") settings.showVolume = defaults.showVolume
        if (typeof settings.showBrightness !== "boolean") settings.showBrightness = defaults.showBrightness
        if (typeof settings.showKbd !== "boolean") settings.showKbd = defaults.showKbd
        if (typeof settings.showMic !== "boolean") settings.showMic = defaults.showMic
        if (typeof settings.clickOutsideClose !== "boolean") settings.clickOutsideClose = defaults.clickOutsideClose
        if (!Array.isArray(settings.pinned)) settings.pinned = defaults.pinned
        if (settings.openMode !== "hover" && settings.openMode !== "click") settings.openMode = defaults.openMode
        if (["auto", "above", "below"].indexOf(settings.dotsSide) < 0) settings.dotsSide = defaults.dotsSide

        var limits = {
            iconSize: [16, 64],
            dockSpacing: [0, 24],
            dockPadding: [2, 24],
            magnifyScale: [1.0, 2.0],
            roundness: [0, 100],
            earRadius: [0, 24],
            notchWidth: [0, 1000],
            notchHeight: [0, 500],
            smoothness: [0, 100],
            motionScale: [0.3, 3],
            bannerSeconds: [1, 60],
            coverRoundness: [0, 50],
            gap: [0, 64]
        }
        for (var key in limits) {
            var clamped = clampNumber(settings[key], limits[key][0], limits[key][1])
            if (clamped !== Number(settings[key])) settings[key] = clamped
        }
    }

    // While the pointer rests on the media island the track title is easier to
    // read with the dock name label cleared, so drop stale hover text when the
    // dock stops being the active surface.
    onSurfaceKeyChanged: {
        if (surfaceKey !== "dock") dockHoverName = ""
    }

    // Keep the media service's manual player choice from going stale when a
    // player closes: fall back to automatic selection.
    Connections {
        target: mediaSvc
        function onPlayerCountChanged() {
            if (mediaSvc.playerCount === 0) mediaSvc.manual = null
        }
    }

    // A new notice arrives while a popup is open: remember it so the dock can
    // show it after the popup closes instead of dropping it silently.
    property var pendingNotice: null

    Connections {
        target: ocSvc
        function onFreshNotice(row) {
            if (root.surfaceOpen) root.pendingNotice = row
        }
    }

    onSurfaceOpenChanged: {
        if (!surfaceOpen && pendingNotice !== null && settings.opencodeNotify) {
            var row = pendingNotice
            pendingNotice = null
            showNotice(row)
        }
    }

    // Validate the config whenever it is loaded from disk.
    Timer {
        id: normalizeTimer
        interval: 200
        repeat: false
        onTriggered: root.normalizeSettings()
    }

    Connections {
        target: settingsData
        function onEdgeChanged() { normalizeTimer.restart() }
        function onModeChanged() { normalizeTimer.restart() }
        function onAlignChanged() { normalizeTimer.restart() }
    }

    // =======================================================================================
    // DIAGNOSTICS
    // Printed once at startup so `journalctl --user -u omarchy-shell` shows what the
    // plugin resolved. Handy when something is not where you expect.
    // =======================================================================================
    Component.onCompleted: {
        console.log("notch-island: plugin dir", pluginDir)
        console.log("notch-island: edge", edge, "mode", settings.mode, "align", align, "output", outputName)
        console.log("notch-island: settings file", settingsPath)
        console.log("notch-island: scripts", scriptsDir)
        normalizeTimer.start()
        if (mediaSvc.hasTrack && !mediaSvc.isPlaying) {
            pauseLinger = true
            lingerTimer.restart()
        }
    }
}
