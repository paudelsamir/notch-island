#!/usr/bin/env bash
# Ask opencode a question non-interactively and stream the cleaned answer.
# usage: ask.sh "question" [session-id] [model]
q="$1"; session="$2"; model="$3"
if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode is not installed or not in PATH."
  exit 127
fi
args=(run)
[ -n "$session" ] && args+=(--session "$session")
[ -n "$model" ] && args+=(--model "$model")
# strip ANSI escapes so the island shows plain text
opencode "${args[@]}" "$q" 2>&1 | sed -u -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\r$//'
