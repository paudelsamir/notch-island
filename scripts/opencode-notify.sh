#!/usr/bin/env bash
# Prints the newest opencode agent notification as ONE line of JSON, or nothing.
# Sources, newest wins:
#   1. ~/.local/state/notch-island/opencode-feed.json (written by opencode-hook.sh / the opencode plugin)
#   2. Omarchy notification history (any notification whose text mentions opencode)
FEED="$HOME/.local/state/notch-island/opencode-feed.json"
HIST="${OMARCHY_NOTIFY_HISTORY:-$HOME/.local/state/omarchy/notifications/history}"

best=""
best_ts=0

if [ -f "$FEED" ]; then
  line="$(tr -d '\n' < "$FEED")"
  ts="$(printf '%s' "$line" | grep -o '"timestamp":[ ]*[0-9]*' | head -1 | grep -o '[0-9]*$')"
  if [ -n "$ts" ]; then best="$line"; best_ts="$ts"; fi
fi

if [ -d "$HIST" ]; then
  while IFS= read -r f; do
    if grep -qi 'opencode' "$f" 2>/dev/null; then
      line="$(tr -d '\n' < "$f")"
      ts="$(printf '%s' "$line" | grep -o '"timestamp":[ ]*[0-9]*' | head -1 | grep -o '[0-9]*$')"
      if [ -n "$ts" ] && [ "$ts" -gt "$best_ts" ]; then best="$line"; best_ts="$ts"; fi
      break
    fi
  done < <(ls -t "$HIST"/*.json 2>/dev/null | head -25)
fi

[ -n "$best" ] && printf '%s\n' "$best"
exit 0
