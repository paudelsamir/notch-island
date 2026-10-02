import QtQuick
import Quickshell
import Quickshell.Io

// ---------------------------------------------------------------------------
// Notes.qml
//
// A tiny local notebook for the notes module. Notes live in
// ~/.local/state/notch-island/notes.json as { notes: [{id, text, done, ts}] },
// watched live so hand-edits appear instantly. No network, no accounts.
Item {
    id: svc

    property var host: null

    readonly property string filePath: Quickshell.env("HOME") + "/.local/state/notch-island/notes.json"
    readonly property var notes: Array.isArray(store.notes) ? store.notes : []
    readonly property int openCount: notes.filter(function(n) { return !n.done }).length

    property var store: ({ notes: [] })
    property int serial: 0

    function save() {
        adapter.notes = notes.slice()
    }

    function add(text) {
        var value = String(text || "").trim()
        if (value === "") return
        serial += 1
        var next = notes.slice()
        next.unshift({ id: "n" + Date.now() + "-" + serial, text: value, done: false, ts: Date.now() })
        store = { notes: next }
        save()
    }

    function toggle(id) {
        var next = notes.map(function(n) {
            if (String(n.id) !== String(id)) return n
            return { id: n.id, text: n.text, done: !n.done, ts: n.ts }
        })
        store = { notes: next }
        save()
    }

    function remove(id) {
        store = { notes: notes.filter(function(n) { return String(n.id) !== String(id) }) }
        save()
    }

    function clearDone() {
        store = { notes: notes.filter(function(n) { return !n.done }) }
        save()
    }

    FileView {
        path: svc.filePath
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
            id: adapter
            property var notes: []

            onNotesChanged: {
                // A partial read (e.g. our own write racing the file watcher)
                // can surface a non-array here; adopting it would wipe the
                // in-memory notes, so only ever adopt real arrays. The next
                // clean reload heals automatically.
                if (!Array.isArray(notes)) return
                if (svc.store.notes !== notes) svc.store = { notes: notes.slice() }
            }
        }
    }

    // Seed the in-memory copy once the adapter has loaded.
    Component.onCompleted: Qt.callLater(function() {
        if (Array.isArray(adapter.notes)) svc.store = { notes: adapter.notes.slice() }
    })
}
