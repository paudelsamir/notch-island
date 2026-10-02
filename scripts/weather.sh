#!/usr/bin/env bash
# Fetch current + 3-day weather from wttr.in (no API key) and cache the raw
# JSON. Location defaults to wttr.in's geoip guess; override it by putting a
# city name on the first non-comment line of
# ~/.config/omarchy/notch-island-location.txt.
# Safe to run offline: failures keep the previous cache.
set -u
LOC_FILE="${HOME}/.config/omarchy/notch-island-location.txt"
CACHE="${HOME}/.local/state/notch-island/weather.json"
mkdir -p "$(dirname "$CACHE")"
loc=""
if [[ -f "$LOC_FILE" ]]; then
  loc="$(grep -v '^\s*#' "$LOC_FILE" | grep -v '^\s*$' | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/ /+/g')"
fi
if [[ -n "$loc" ]]; then
  url="https://wttr.in/${loc}?format=j1"
else
  url="https://wttr.in/?format=j1"
fi
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if curl -sS -m 20 -A "notch-island/1.0" "$url" -o "$tmp"; then
  python3 - "$tmp" "$CACHE" <<'PY'
import json, sys
src, dest = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(src))
except Exception:
    sys.exit(0)
if not isinstance(data, dict) or "current_condition" not in data:
    sys.exit(0)
data["_fetched"] = __import__("time").time()
with open(dest + ".new", "w") as f:
    json.dump(data, f)
import os
os.replace(dest + ".new", dest)
PY
fi
exit 0
