#!/usr/bin/env bash
# usage: brightness.sh get            -> prints 0-100 (or -1 when unsupported)
#        brightness.sh set <0-100>
#        brightness.sh inc|dec <step>
if ! command -v brightnessctl >/dev/null 2>&1; then echo "-1"; exit 0; fi
case "$1" in
  get)
    cur="$(brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d '%')"
    echo "${cur:--1}"
    ;;
  set)
    v="${2:-50}"; [ "$v" -lt 1 ] && v=1; [ "$v" -gt 100 ] && v=100
    brightnessctl -q set "${v}%"
    ;;
  inc) brightnessctl -q set "+${2:-5}%" ;;
  dec) brightnessctl -q set "${2:-5}%-" ;;
esac
