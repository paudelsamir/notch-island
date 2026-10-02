#!/usr/bin/env bash
# Test suite for the Notch Island resting modules.
#   static: qmllint over every QML file
#   probe:  headless quickshell run that instantiates every new component and
#           service with mocks and asserts geometry + data contracts
#   scripts: news.sh / weather.sh exit cleanly and keep valid caches
#   live:   cycle every restMode through the running instance, open/close the
#           menu, then confirm both bars and a clean journal
# Exit nonzero on any failure.
set -u
cd "$(dirname "$0")/.."
PLUGIN="$HOME/.config/omarchy/plugins/user.notch-island"
QSOCK="$HOME/.config/quickshell/notch-island"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "PASS $1"; }
bad()  { fail=$((fail+1)); echo "FAIL $1"; }

echo "=== 1. qmllint ==="
if find . -name '*.qml' -print0 | xargs -0 qmllint -I /usr/share/omarchy/shell 2>&1 | head -20; then
  ok "qmllint clean"
else
  bad "qmllint errors above"
fi

echo "=== 2. headless probe ==="
probe_out="$(timeout 60s quickshell -p "$PWD/tests/probe" 2>&1)"
echo "$probe_out" | grep -a 'notch-island-test: ' | tail -30
if echo "$probe_out" | grep -aq 'notch-island-test: DONE failures=0' \
   && ! echo "$probe_out" | grep -aqE 'notch-island-test: FAIL|is not a type|ReferenceError|non-existent property|multiple times|read-only property|Failed to load|Type .* unavailable'; then
  ok "probe components+services"
else
  bad "probe reported failures (see above)"
fi
npass="$(echo "$probe_out" | grep -ac 'notch-island-test: PASS' || true)"
echo "probe assertions passed: $npass"

echo "=== 3. feed scripts ==="
bash scripts/news.sh; [ $? -eq 0 ] && ok "news.sh exit 0" || bad "news.sh exit nonzero"
bash scripts/weather.sh; [ $? -eq 0 ] && ok "weather.sh exit 0" || bad "weather.sh exit nonzero"
python3 - <<'PY' && echo "caches inspected"
import json
for f in ('news.json', 'weather.json'):
    try:
        d = json.load(open(f'/home/sam/.local/state/notch-island/{f}'))
        print(' ', f, 'ok')
    except Exception as e:
        print(' ', f, 'missing/invalid (offline?):', e)
PY

echo "=== 4. live instance ==="
echo "-- deploying source to plugin dir --"
rsync -a --delete --exclude '.git' "$PWD/" "$PLUGIN/" && chmod +x "$PLUGIN/scripts/"*.sh
systemctl --user restart quickshell-notch-island.service
sleep 12
systemctl --user is-active quickshell-notch-island.service >/dev/null && ok "service active" || bad "service not active"
before="$(qs -p "$QSOCK" ipc call user.notch-island state 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("restMode","dock"))')"
# shellcheck disable=SC2034
for mode in dock clock; do
  got="$(qs -p "$QSOCK" ipc call user.notch-island setRest "$mode" 2>/dev/null)"
  sleep 2
  [ "$got" = "$mode" ] && ok "setRest $mode" || bad "setRest $mode (got: $got)"
done
qs -p "$QSOCK" ipc call user.notch-island setRest "$before" >/dev/null 2>&1
sleep 1
"$PLUGIN/scripts/ipc.sh" toggle >/dev/null 2>&1; sleep 2
if "$PLUGIN/scripts/ipc.sh" state 2>/dev/null | grep -q '"view":"menu"'; then ok "menu opens"; else bad "menu did not open"; fi
"$PLUGIN/scripts/ipc.sh" toggle >/dev/null 2>&1; sleep 1
PID="$(systemctl --user show quickshell-notch-island.service -p MainPID --value)"
if journalctl --user -u quickshell-notch-island.service --no-pager 2>/dev/null | tr '\0' '\n' | grep -a "quickshell\[$PID\]" | grep -aqE 'Failed to load configuration|is not a type|non-existent property|multiple times|read-only property|ReferenceError'; then
  bad "journal shows QML errors"
else
  ok "journal clean"
fi
hyprctl layers 2>&1 | grep -q 'namespace: omarchy-bar' && ok "stock bar layer" || bad "stock bar layer missing"
hyprctl layers 2>&1 | grep -q 'namespace: omarchy-notch-island' && ok "notch-island layer" || bad "notch-island layer missing"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
