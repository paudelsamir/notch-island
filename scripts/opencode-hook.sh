#!/usr/bin/env bash
# Push an opencode agent event to the notch.
# usage: opencode-hook.sh "Title" "Body text" [session-id]
DIR="$HOME/.local/state/notch-island"
mkdir -p "$DIR"
title="${1:-opencode}"
body="${2:-}"
session="${3:-}"
now="$(( $(date +%s) * 1000 ))"
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n' ' '; }
cat > "$DIR/opencode-feed.json.tmp" <<JSON
{"app":"opencode","summary":"$(esc "$title")","body":"$(esc "$body")","session":"$(esc "$session")","timestamp":$now,"originalId":$now}
JSON
mv "$DIR/opencode-feed.json.tmp" "$DIR/opencode-feed.json"
