#!/usr/bin/env bash
# Copies this folder into the Omarchy plugin directory and restarts the shell.
set -e
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$HOME/.config/omarchy/plugins/user.notch-island"
mkdir -p "$DEST"
rsync -a --delete --exclude '.git' "$SRC"/ "$DEST"/
chmod +x "$DEST"/scripts/*.sh
mkdir -p "$HOME/.local/state/notch-island"
echo "Installed to $DEST"
if command -v omarchy >/dev/null 2>&1; then
  omarchy bar use user.notch-island || true
  omarchy restart shell || true
fi
echo "Optional: copy opencode-plugin/notch-island.js to ~/.config/opencode/plugin/ for instant agent notifications."
