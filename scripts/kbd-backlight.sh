#!/usr/bin/env bash
# usage: kbd-backlight.sh get            -> prints 0-100 (or -1 when unsupported)
#        kbd-backlight.sh set <0-100>
# Finds the first *kbd_backlight LED device (e.g. asus::kbd_backlight).
if ! command -v brightnessctl >/dev/null 2>&1; then echo "-1"; exit 0; fi
DEV="$(brightnessctl -l 2>/dev/null | grep -o "[^ ']*kbd_backlight[^ ']*" | head -1)"
if [[ -z "$DEV" ]]; then echo "-1"; exit 0; fi
case "$1" in
  get)
    cur="$(brightnessctl -d "$DEV" -m 2>/dev/null | cut -d, -f4 | tr -d '%')"
    echo "${cur:--1}"
    ;;
  set)
    v="${2:-50}"; [ "$v" -lt 0 ] && v=0; [ "$v" -gt 100 ] && v=100
    brightnessctl -q -d "$DEV" set "${v}%"
    ;;
  inc) brightnessctl -q -d "$DEV" set "+${2:-10}%" ;;
  dec) brightnessctl -q -d "$DEV" set "${2:-10}%-" ;;
esac
