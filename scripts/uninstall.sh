#!/usr/bin/env bash
if command -v omarchy >/dev/null 2>&1; then
  omarchy bar use omarchy.bar || true
fi
rm -rf "$HOME/.config/omarchy/plugins/user.notch-island"
echo "Removed. Settings kept at ~/.config/omarchy/notch-island.json (delete it for a clean slate)."
command -v omarchy >/dev/null 2>&1 && omarchy restart shell
exit 0
