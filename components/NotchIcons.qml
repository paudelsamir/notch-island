import QtQuick

// ---------------------------------------------------------------------------
// NotchIcons.qml
//
// One place for every symbolic glyph used by the notch.
//
// The goal is to avoid emoji and one-off Unicode symbols. Most names resolve
// through Material Symbols Rounded, which is already installed on this system.
// The opencode brand mark comes from the installed Omarchy icon face. Both are
// available locally, so no webfont has to be downloaded or vendored here.
QtObject {
    id: symbols

    readonly property string materialFamily: "Material Symbols Rounded"
    readonly property string brandFamily: "omarchy"

    // Floating popup navigation.
    readonly property string menu: "menu"
    readonly property string player: "music_note"
    readonly property string ask: "terminal"
    readonly property string power: "power_settings_new"
    readonly property string settings: "settings"
    readonly property string openCode: "\uE902"

    // Menu sliders and status.
    readonly property string brightness: "brightness_6"
    readonly property string keyboard: "keyboard"
    readonly property string mic: "mic"
    readonly property string swapOutputs: "swap_horiz"
    readonly property string charging: "bolt"
    readonly property string add: "add"
    readonly property string search: "search"
    readonly property string refreshPlayers: "autorenew"

    // Transport controls.
    readonly property string previous: "skip_previous"
    readonly property string play: "play_arrow"
    readonly property string pause: "pause"
    readonly property string next: "skip_next"
    readonly property string stop: "stop"

    // Power actions.
    readonly property string lock: "lock"
    readonly property string sleep: "bedtime"
    readonly property string logout: "logout"
    readonly property string restart: "restart_alt"
    readonly property string shutdown: "power_off"
    readonly property string hibernate: "mode_night"

    // Navigation and small controls.
    readonly property string close: "close"
    readonly property string back: "chevron_left"
    readonly property string forward: "chevron_right"
    readonly property string up: "arrow_upward"
    readonly property string down: "arrow_downward"
    readonly property string send: "arrow_upward"
    readonly property string check: "check"

    // Settings pages.
    readonly property string position: "tune"
    readonly property string shape: "rounded_corner"
    readonly property string dock: "grid_view"
    readonly property string animation: "animation"
    readonly property string media: "music_note"
    readonly property string behavior: "bottom_navigation"

    // Resting modules.
    readonly property string home: "home"
    readonly property string clock: "schedule"
    readonly property string calendar: "event"
    readonly property string news: "newspaper"
    readonly property string refresh: "autorenew"
    readonly property string openLink: "open_in_new"

    // Weather.
    readonly property string thermometer: "thermostat"
    readonly property string wind: "air"
    readonly property string humidity: "water_drop"
    readonly property string sun: "light_mode"
    readonly property string partlyCloudy: "partly_cloudy_day"
    readonly property string cloudy: "cloudy"
    readonly property string fog: "foggy"
    readonly property string rain: "rainy"
    readonly property string storm: "thunderstorm"
    readonly property string snow: "ac_unit"

    // Notes.
    readonly property string noteAdd: "add"
    readonly property string noteEdit: "edit"
    readonly property string noteDelete: "delete"
    readonly property string checked: "check_circle"
    readonly property string unchecked: "radio_button_unchecked"

    // Map a wttr.in/Met Office weather code to a Material icon name.
    function weatherIcon(code) {
        var c = Number(code)
        if (c === 113) return sun
        if (c === 116) return partlyCloudy
        if (c === 119 || c === 122) return cloudy
        if (c === 143 || c === 248 || c === 260) return fog
        if (c === 200) return storm
        if (c === 227 || c === 230) return snow
        if ((c >= 176 && c <= 185) || (c >= 281 && c <= 299) || (c >= 353 && c <= 359)) return rain
        if ((c >= 302 && c <= 308) || (c >= 386 && c <= 389)) return storm
        if ((c >= 311 && c <= 350) || (c >= 362 && c <= 377)) return snow
        if (c >= 392 && c <= 395) return snow
        return cloudy
    }

    function volumeName(volume, muted) {
        if (muted || volume <= 0.001) return "volume_off"
        if (volume < 0.10) return "volume_mute"
        if (volume < 0.45) return "volume_down"
        return "volume_up"
    }

    function batteryName(percent, charging) {
        if (charging) return "bolt"
        var level = Math.max(0, Math.min(6, Math.round(Number(percent || 0) / 100 * 6)))
        return "battery_" + level + "_bar"
    }
}
