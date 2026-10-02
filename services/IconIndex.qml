import QtQuick
import Quickshell.Io

// ---------------------------------------------------------------------------
// IconIndex.qml
//
// The same trick the Super+Alt+Space app menu uses: instead of trusting the
// icon image provider (which reports success even for names it cannot find),
// scan the icon theme directories for real app/device icon files and resolve
// names to file:// URLs. Anything not found resolves to "", so callers show
// their letter tile instead of a misleading generic icon.
//
// SVG files are scanned before PNGs so scalable icons win, exactly like the
// launcher does.
Item {
    id: index

    property var files: ({})

    // Rebuild the index. Safe to call often; a running scan is never doubled.
    function refresh() {
        if (scan.running) return
        pending = ({})
        scan.running = true
    }

    // File path for an icon name, or "" when no icon file exists.
    function resolve(name) {
        var key = String(name || "").trim()
        if (key === "") return ""
        if (files[key] !== undefined) return String(files[key])
        var lower = key.toLowerCase()
        if (files[lower] !== undefined) return String(files[lower])
        if (lower.slice(-8) === ".desktop") {
            var stripped = lower.slice(0, -8)
            if (files[stripped] !== undefined) return String(files[stripped])
        }
        var dot = lower.lastIndexOf(".")
        if (dot > 0) {
            var stemmed = lower.slice(0, dot)
            if (files[stemmed] !== undefined) return String(files[stemmed])
        }
        return ""
    }

    // Mirror of the launcher menu's iconSource(), minus its generic fallback:
    // file:// and image:// URLs and absolute paths pass through, theme names
    // must exist in the index, otherwise "" (caller shows its fallback tile).
    function iconSource(value) {
        var name = String(value || "").trim()
        if (name === "") return ""
        if (name.indexOf("file://") === 0 || name.indexOf("image://") === 0) return name
        if (name.charAt(0) === "/") return "file://" + name
        var path = resolve(name)
        return path !== "" ? "file://" + path : ""
    }

    property var pending: ({})

    function scanCommand() {
        return [
            'dirs="$HOME/.icons $HOME/.local/share/icons";',
            'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
            'for ext in svg png; do',
            '  for base in $dirs; do',
            '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null;',
            '  done;',
            '  find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null;',
            'done'
        ].join(' ')
    }

    function indexIconLine(path) {
        var value = String(path || "").trim()
        if (value === "") return
        var slash = value.lastIndexOf("/")
        var file = slash >= 0 ? value.slice(slash + 1) : value
        var dot = file.lastIndexOf(".")
        var name = dot > 0 ? file.slice(0, dot) : file
        if (name !== "" && pending[name] === undefined) pending[name] = value
    }

    Process {
        id: scan
        command: ["bash", "-c", index.scanCommand()]
        stdout: SplitParser {
            onRead: function(line) { index.indexIconLine(line) }
        }
        onExited: function(exitCode) {
            if (exitCode === 0) index.files = index.pending
        }
    }

    Component.onCompleted: refresh()
}
