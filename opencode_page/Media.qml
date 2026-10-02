import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// ---------------------------------------------------------------------------
// Media.qml
//
// A thin, friendly wrapper around Quickshell's MPRIS support.
//
//  * picks the "active" player: the one the user selected by hand, otherwise
//    the first one that is playing, otherwise the first one that exists
//  * keeps the last known cover art while a track title is unchanged (some
//    players drop the art url for a moment between updates)
//  * derives an accent tint from the cover so the island can glow with it
//  * exposes plain transport helpers so views never touch the player directly
// ---------------------------------------------------------------------------
Item {
    id: svc

    // The Notch root. Only used for the fallback accent colour.
    property var host: null

    // ---- player selection -------------------------------------------------
    readonly property var players: Mpris.players ? Mpris.players.values : []

    // A player the user picked manually (cycle button in the player view).
    property var manual: null

    readonly property var playingPlayer: {
        var list = players
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying) return list[i]
        }
        return null
    }

    readonly property var manualValid: {
        if (!manual) return null
        var list = players
        for (var i = 0; i < list.length; i++) {
            if (list[i] === manual) return manual
        }
        return null
    }

    readonly property var player: manualValid ? manualValid
                                : playingPlayer ? playingPlayer
                                : (players.length > 0 ? players[0] : null)

    // ---- track info -------------------------------------------------------
    readonly property bool isPlaying: !!(player && player.isPlaying)
    readonly property string title: player ? String(player.trackTitle || "") : ""
    readonly property string artist: player ? String(player.trackArtist || "") : ""
    readonly property string album: player ? String(player.trackAlbum || "") : ""
    readonly property string identity: player ? String(player.identity || "") : ""

    // "Has something to show": there is a player and it either plays or has a title.
    readonly property bool hasTrack: !!player && (isPlaying || title !== "")

    // ---- cover art with memory --------------------------------------------
    readonly property string reportedArt: player && player.trackArtUrl ? String(player.trackArtUrl) : ""
    property string keptArt: ""
    property string keptArtTitle: ""

    onReportedArtChanged: {
        if (reportedArt !== "") {
            keptArt = reportedArt
            keptArtTitle = title
        }
    }

    onTitleChanged: {
        // A new track arrived: forget the old art unless the player already reports one.
        if (title !== keptArtTitle) {
            keptArt = reportedArt
            keptArtTitle = title
        }
        // A new track also invalidates the cached playback position.
        position = player && player.positionSupported ? Number(player.position) : 0
    }

    readonly property string art: reportedArt !== "" ? reportedArt
                                 : (title === keptArtTitle ? keptArt : "")

    // ---- accent colour from the cover -------------------------------------
    ColorQuantizer {
        id: quantizer
        source: svc.art
        depth: 2
        rescaleSize: 64
    }

    // Picks the most vivid colour among the quantized cover colours.
    readonly property color tint: {
        var fallback = host ? host.colorAccent : "#7aa2f7"
        var colors = quantizer.colors || []
        var best = null
        var bestScore = -1
        for (var i = 0; i < colors.length; i++) {
            var c = colors[i]
            var score = c.hsvSaturation * 0.7 + c.hsvValue * 0.3
            if (score > bestScore) {
                bestScore = score
                best = c
            }
        }
        if (!best || best.hsvSaturation < 0.12) return fallback
        return Qt.hsva(best.hsvHue, Math.min(1, best.hsvSaturation), Math.max(0.75, best.hsvValue), 1)
    }

    // ---- position / length ------------------------------------------------
    readonly property bool hasPosition: !!(player && player.positionSupported && player.lengthSupported && player.length > 0)
    readonly property real length: hasPosition ? Number(player.length) : 0
    property real position: 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property bool canSeek: !!(player && player.canSeek && hasPosition)

    // MPRIS positions do not push updates, so poll while something plays.
    Timer {
        interval: 500
        repeat: true
        running: svc.isPlaying && svc.hasPosition
        triggeredOnStart: true
        onTriggered: {
            if (svc.player) {
                svc.player.positionChanged()
                svc.position = Number(svc.player.position)
            }
        }
    }

    // Reset the cached position when the player changes.
    // (Track changes are handled in the onTitleChanged handler above.)
    onPlayerChanged: position = player && player.positionSupported ? Number(player.position) : 0

    // ---- capabilities ------------------------------------------------------
    readonly property bool canPlayPause: !!(player && player.canTogglePlaying)
    readonly property bool canNext: !!(player && player.canGoNext)
    readonly property bool canPrevious: !!(player && player.canGoPrevious)
    readonly property int playerCount: players.length

    // ---- actions -----------------------------------------------------------
    function playPause() {
        if (player && player.canTogglePlaying) player.togglePlaying()
    }

    function next() {
        if (player && player.canGoNext) player.next()
    }

    function previous() {
        if (player && player.canGoPrevious) player.previous()
    }

    // Seek to a fraction (0..1) of the current track.
    function seekFraction(fraction) {
        if (!canSeek) return
        var target = Math.max(0, Math.min(1, fraction)) * length
        player.position = target
        position = target
    }

    // Jump relative seconds forward/back.
    function skip(seconds) {
        if (!canSeek) return
        var target = Math.max(0, Math.min(length, position + seconds))
        player.position = target
        position = target
    }

    // Select the next player in the list (wraps around).
    function cyclePlayer() {
        var list = players
        if (list.length < 2) return
        var idx = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] === player) idx = i
        }
        manual = list[(idx + 1) % list.length]
    }

    // 3:07 style time label for seconds.
    function formatTime(seconds) {
        var s = Math.max(0, Math.floor(seconds || 0))
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // Short label for the player, e.g. "Spotify" or "firefox".
    readonly property string playerLabel: identity !== "" ? identity : "Player"


    // ---- extra player controls ------------------------------------------------------
    // Player volume is separate from the system volume; not every player
    // supports it, so views check `hasVolume` first.
    readonly property bool hasVolume: !!(player && player.volumeSupported)
    readonly property real playerVolume: hasVolume ? Number(player.volume) : 1

    function setPlayerVolume(v) {
        if (hasVolume) player.volume = Math.max(0, Math.min(1, Number(v)))
    }

    // Stop playback entirely (drops the media island back to the dock).
    function stop() {
        if (player && player.canControl) {
            if (player.isPlaying) player.togglePlaying()
        }
    }

    // A short label used in logs and the state dump.
    readonly property string summary: hasTrack
        ? (artist !== "" ? artist + " - " + title : title)
        : "nothing playing"

    // True when the current art is a local file (no network fetch needed).
    readonly property bool artIsLocal: art.indexOf("file://") === 0 || art.charAt(0) === "/"
}
