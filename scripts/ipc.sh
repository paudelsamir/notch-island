#!/usr/bin/env bash
# Control the notch from a keybind.  Examples:
#   ipc.sh toggle            open/close the menu
#   ipc.sh show player       open the now playing view
#   ipc.sh show settings
#   ipc.sh setEdge left      move the notch to another edge
#   ipc.sh setRest clock     rest on the clock module (dock|clock|news|weather|notes)
#   ipc.sh cycleRest         step to the next resting module
TARGET="paudelsamir.notch-island"

# `qs ipc call` exits 0 even when the target is absent, printing "Target not found."
# on stdout, so success has to be judged from the reply rather than the status.
try() {
  local out
  out="$("$@" 2>/dev/null)" || return 1
  case "$out" in
    "" | "Target not found."*) return 1 ;;
    *) printf '%s\n' "$out"; return 0 ;;
  esac
}

# Running inside the Omarchy shell (overlay mode): talk to the shell process,
# which hosts this plugin's IpcHandler.
if command -v qs >/dev/null 2>&1; then
  try qs -p /usr/share/omarchy/shell ipc call "$TARGET" "$@" && exit 0
fi
if command -v omarchy-shell >/dev/null 2>&1; then
  try omarchy-shell "$TARGET" toggle && exit 0
fi
# Running as a bar: the target lives in the Omarchy shell process (handled above).
# Running standalone: quickshell needs to be pointed at the config to find the
# target, because IPC is per-process and it is not in the shell's registry.
for cfg in "$HOME/.config/quickshell/notch-island" "$HOME/.config/omarchy/plugins/paudelsamir.notch-island"; do
  [ -d "$cfg" ] && { try qs -p "$cfg" ipc call "$TARGET" "$@" && exit 0; }
done
try qs ipc call "$TARGET" "$@"
