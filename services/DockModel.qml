import QtQuick
import Quickshell
import Quickshell.Wayland

// ---------------------------------------------------------------------------
// DockModel.qml
//
// Builds the list of app slots the dock shows:
//
//     [ pinned apps, in the saved order ] [ running apps that are not pinned ]
//
// One slot per appId: several windows of the same app share a slot. Each slot
// is a plain object so the UI can bind to it without owning any state:
//
//   { id, name, icon, count, active, pinned, entry }
//
// Pinned ids are stored in the plugin settings (host.settings.pinned).
// ---------------------------------------------------------------------------
Item {
    id: model

    property var host: null

    // The list the dock renders.
    property var apps: []

    // Ids of apps that are pinned (lower-case desktop ids / appIds).
    readonly property var pinned: host && host.settings && host.settings.pinned ? host.settings.pinned : []

    // Remember the order in which unpinned apps first appeared, so slots do
    // not jump around every time focus changes.
    property var seenOrder: []

    // ---- helpers ------------------------------------------------------------
    function norm(id) {
        return String(id || "").toLowerCase()
    }

    // Look up the .desktop entry for an app id, tolerant to naming differences.
    function entryFor(id) {
        if (!id) return null
        var e = null
        try {
            e = DesktopEntries.heuristicLookup(id)
        } catch (err) {
            e = null
        }
        return e
    }

    function nameFor(id, entry) {
        if (entry && entry.name) return String(entry.name)
        var s = String(id || "")
        // "org.gnome.Nautilus" -> "Nautilus"
        var last = s.split(".").pop()
        return last.length ? last.charAt(0).toUpperCase() + last.slice(1) : s
    }

    // Toplevels that belong to an app id.
    function windowsOf(id) {
        var out = []
        var list = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
        var key = norm(id)
        for (var i = 0; i < list.length; i++) {
            if (norm(list[i].appId) === key) out.push(list[i])
        }
        return out
    }

    // ---- build --------------------------------------------------------------
    function rebuild() {
        var groups = ({})
        var order = []
        var list = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []

        for (var i = 0; i < list.length; i++) {
            var t = list[i]
            var key = norm(t.appId)
            if (key === "") continue
            if (!groups[key]) {
                groups[key] = { id: String(t.appId), count: 0, active: false }
                order.push(key)
            }
            groups[key].count += 1
            if (t.activated) groups[key].active = true
        }

        // Track first-seen order for running unpinned apps.
        var seen = seenOrder.slice()
        for (var o = 0; o < order.length; o++) {
            if (seen.indexOf(order[o]) === -1) seen.push(order[o])
        }
        // Forget apps that are gone.
        seen = seen.filter(function(k) { return groups[k] !== undefined })
        seenOrder = seen

        var result = []
        var used = ({})

        // 1) pinned, in saved order
        for (var p = 0; p < pinned.length; p++) {
            var pid = String(pinned[p])
            var pkey = norm(pid)
            if (used[pkey]) continue
            used[pkey] = true
            var g = groups[pkey]
            var e = entryFor(pid)
            result.push({
                id: pid,
                name: nameFor(pid, e),
                icon: e && e.icon ? String(e.icon) : pid,
                count: g ? g.count : 0,
                active: g ? g.active : false,
                pinned: true,
                entry: e
            })
        }

        // 2) running apps that are not pinned
        for (var s = 0; s < seen.length; s++) {
            var skey = seen[s]
            if (used[skey]) continue
            used[skey] = true
            var grp = groups[skey]
            var en = entryFor(grp.id)
            result.push({
                id: grp.id,
                name: nameFor(grp.id, en),
                icon: en && en.icon ? String(en.icon) : grp.id,
                count: grp.count,
                active: grp.active,
                pinned: false,
                entry: en
            })
        }

        apps = result
    }

    // Rebuild when windows come and go, and poll gently for focus changes
    // (Toplevel.activated has no aggregate signal).
    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { model.rebuild() }
    }

    Timer {
        interval: 700
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: model.rebuild()
    }

    onPinnedChanged: rebuild()

    // ---- actions ------------------------------------------------------------
    // Launch a new instance of an app.
    function launch(app) {
        if (!app) return
        if (app.entry) {
            app.entry.execute()
        } else {
            Quickshell.execDetached([String(app.id)])
        }
    }

    // Left click: focus, cycle through windows, or launch when closed.
    function activate(app) {
        if (!app) return
        var wins = windowsOf(app.id)
        if (wins.length === 0) {
            launch(app)
            return
        }
        if (wins.length === 1) {
            wins[0].activate()
            return
        }
        // several windows: go to the one after the focused one
        var idx = -1
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].activated) idx = i
        }
        wins[(idx + 1) % wins.length].activate()
    }

    // Close every window of an app.
    function closeWindows(app) {
        if (!app) return
        var wins = windowsOf(app.id)
        for (var i = 0; i < wins.length; i++) wins[i].close()
    }

    // ---- pinning ------------------------------------------------------------
    function isPinned(id) {
        var key = norm(id)
        for (var i = 0; i < pinned.length; i++) {
            if (norm(pinned[i]) === key) return true
        }
        return false
    }

    function writePinned(list) {
        if (host && host.settings) host.settings.pinned = list
    }

    function pin(id) {
        if (isPinned(id)) return
        writePinned(pinned.concat([String(id)]))
    }

    function unpin(id) {
        var key = norm(id)
        writePinned(pinned.filter(function(p) { return norm(p) !== key }))
    }

    function togglePin(id) {
        if (isPinned(id)) unpin(id)
        else pin(id)
    }

    // Move a pinned app up (-1) or down (+1) in the order.
    function movePinned(id, delta) {
        var key = norm(id)
        var list = pinned.slice()
        var idx = -1
        for (var i = 0; i < list.length; i++) {
            if (norm(list[i]) === key) idx = i
        }
        var to = idx + delta
        if (idx < 0 || to < 0 || to >= list.length) return
        var tmp = list[idx]
        list[idx] = list[to]
        list[to] = tmp
        writePinned(list)
    }

    // Running apps that could still be pinned (for the settings page).
    readonly property var pinCandidates: apps.filter(function(a) { return !a.pinned })
}
