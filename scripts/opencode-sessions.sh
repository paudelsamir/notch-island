#!/usr/bin/env bash
# Prints a JSON array of the most recent opencode sessions with token totals.
# usage: opencode-sessions.sh [limit]
# Reads the opencode sqlite database read-only. Prints [] if anything is missing.
DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
LIMIT="${1:-12}"

if [ ! -f "$DB" ] || ! command -v sqlite3 >/dev/null 2>&1; then
  echo "[]"
  exit 0
fi

read -r -d '' SQL <<SQL_END
SELECT
  s.id AS id,
  COALESCE(s.title, 'Untitled') AS title,
  COALESCE(s.directory, '') AS directory,
  s.time_updated AS updated,
  (SELECT COUNT(*) FROM message m WHERE m.session_id = s.id) AS messages,
  COALESCE((SELECT SUM(json_extract(m.data, '\$.tokens.input')) FROM message m WHERE m.session_id = s.id), 0) AS input,
  COALESCE((SELECT SUM(json_extract(m.data, '\$.tokens.output')) FROM message m WHERE m.session_id = s.id), 0) AS output,
  COALESCE((SELECT SUM(json_extract(m.data, '\$.tokens.reasoning')) FROM message m WHERE m.session_id = s.id), 0) AS reasoning,
  COALESCE((SELECT SUM(json_extract(m.data, '\$.tokens.cache.read')) FROM message m WHERE m.session_id = s.id), 0) AS cacheRead,
  COALESCE((SELECT SUM(json_extract(m.data, '\$.tokens.cache.write')) FROM message m WHERE m.session_id = s.id), 0) AS cacheWrite,
  COALESCE((SELECT SUM(json_extract(m.data, '\$.cost')) FROM message m WHERE m.session_id = s.id), 0) AS cost
FROM session s
ORDER BY s.time_updated DESC
LIMIT $LIMIT;
SQL_END

out="$(sqlite3 -readonly -json "$DB" "$SQL" 2>/dev/null)"
echo "${out:-[]}"
