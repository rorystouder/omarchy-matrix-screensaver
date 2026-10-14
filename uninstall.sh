#!/bin/bash
#
# Remove the Matrix screensaver and restore Omarchy's stock idle service.
# shell.json timers are left as-is (stock Omarchy treats lock=0 as "lock
# immediately", so this resets it to 300 if it is 0).

set -euo pipefail

PLUGIN_ID="${USER:-$(id -un)}.idle"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
omarchy plugin enable omarchy.idle >/dev/null 2>&1 || true
[[ -d $PLUGIN_DIR ]] && mv "$PLUGIN_DIR" "$PLUGIN_DIR.removed.$(date +%s)"

rm -f "$HOME/.local/bin/matrix-rain" "$HOME/.local/bin/matrix-screensaver"

if [[ -f $SHELL_JSON ]] && jq -e '.idle.lock == 0' "$SHELL_JSON" >/dev/null; then
  cp "$SHELL_JSON" "$SHELL_JSON.bak.$(date +%s)"
  jq '.idle.lock = 300' "$SHELL_JSON" >"$SHELL_JSON.tmp" && mv "$SHELL_JSON.tmp" "$SHELL_JSON"
  echo "idle.lock was 0; reset to 300 so stock Omarchy doesn't lock immediately."
fi

omarchy restart shell >/dev/null 2>&1 || true
echo "Removed. Stock omarchy.idle is back. Your old plugin copy was moved aside, not deleted."
