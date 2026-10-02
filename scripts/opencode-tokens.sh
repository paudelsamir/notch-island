#!/usr/bin/env bash
# Prints one JSON object with all-time and today's opencode token usage.
DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"

EMPTY='{"sessions":0,"messages":0,"input":0,"output":0,"reasoning":0,"cacheRead":0,"cacheWrite":0,"cost":0,"todayInput":0,"todayOutput":0,"todayCost":0}'

if [ ! -f "$DB" ] || ! command -v sqlite3 >/dev/null 2>&1; then
  echo "$EMPTY"
  exit 0
fi

# Start of today in epoch milliseconds (opencode stores ms timestamps)
TODAY_MS="$(( $(date -d 'today 00:00' +%s) * 1000 ))"

read -r -d '' SQL <<SQL_END
SELECT
  (SELECT COUNT(*) FROM session) AS sessions,
  COUNT(*) AS messages,
  COALESCE(SUM(json_extract(data, '\$.tokens.input')), 0) AS input,
  COALESCE(SUM(json_extract(data, '\$.tokens.output')), 0) AS output,
  COALESCE(SUM(json_extract(data, '\$.tokens.reasoning')), 0) AS reasoning,
  COALESCE(SUM(json_extract(data, '\$.tokens.cache.read')), 0) AS cacheRead,
  COALESCE(SUM(json_extract(data, '\$.tokens.cache.write')), 0) AS cacheWrite,
  COALESCE(SUM(json_extract(data, '\$.cost')), 0) AS cost,
  COALESCE(SUM(CASE WHEN time_created >= $TODAY_MS THEN json_extract(data, '\$.tokens.input') END), 0) AS todayInput,
  COALESCE(SUM(CASE WHEN time_created >= $TODAY_MS THEN json_extract(data, '\$.tokens.output') END), 0) AS todayOutput,
  COALESCE(SUM(CASE WHEN time_created >= $TODAY_MS THEN json_extract(data, '\$.cost') END), 0) AS todayCost
FROM message;
SQL_END

out="$(sqlite3 -readonly -json "$DB" "$SQL" 2>/dev/null)"
if [ -z "$out" ]; then
  echo "$EMPTY"
else
  # sqlite3 -json wraps the row in an array; strip it
  echo "$out" | sed -e 's/^\[//' -e 's/\]$//'
fi
