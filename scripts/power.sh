#!/usr/bin/env bash
# usage: power.sh lock|suspend|hibernate|logout|reboot|shutdown
case "$1" in
  lock)
    if command -v omarchy-lock-screen >/dev/null; then omarchy-lock-screen
    elif command -v hyprlock >/dev/null; then hyprlock
    else loginctl lock-session; fi ;;
  suspend)   systemctl suspend ;;
  hibernate) systemctl hibernate ;;
  logout)
    if command -v omarchy-system-logout >/dev/null; then omarchy-system-logout
    else hyprctl dispatch exit; fi ;;
  reboot)
    if command -v omarchy-system-reboot >/dev/null; then omarchy-system-reboot
    else systemctl reboot; fi ;;
  shutdown)
    if command -v omarchy-system-shutdown >/dev/null; then omarchy-system-shutdown
    else systemctl poweroff; fi ;;
  *) echo "unknown action: $1" >&2; exit 2 ;;
esac
