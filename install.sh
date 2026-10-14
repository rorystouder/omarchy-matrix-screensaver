#!/bin/bash
#
# Install the Matrix rain screensaver on an Omarchy machine.
#
#   ./install.sh [--screensaver SECONDS] [--lock SECONDS|0] [--keep-timers]
#
# Defaults: screensaver after 1200s idle, lock after 3000s idle.
# --lock 0 means never lock on idle. --keep-timers leaves shell.json alone.
# Safe to re-run.

set -euo pipefail

SCREENSAVER=1200
LOCK=3000
SET_TIMERS=1

while (($#)); do
  case $1 in
  --screensaver) SCREENSAVER=$2; shift 2 ;;
  --lock) LOCK=$2; shift 2 ;;
  --keep-timers) SET_TIMERS=0; shift ;;
  -h | --help) sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ $SCREENSAVER =~ ^[0-9]+$ && $LOCK =~ ^[0-9]+$ ]] || { echo "Timers must be whole seconds" >&2; exit 1; }

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN="$HOME/.local/bin"
PLUGIN_ID="${USER:-$(id -un)}.idle"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
STAMP=$(date +%s)

step() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

for cmd in omarchy omarchy-shell python3 jq hyprctl socat; do
  command -v "$cmd" >/dev/null || die "'$cmd' not found -- is this an Omarchy machine?"
done

step "Installing matrix-rain and matrix-screensaver to $BIN"
mkdir -p "$BIN"
install -m 755 "$REPO/bin/matrix-rain" "$REPO/bin/matrix-screensaver" "$BIN/"

step "Setting up idle plugin $PLUGIN_ID"
if [[ ! -d $PLUGIN_DIR ]]; then
  omarchy plugin clone omarchy.idle
else
  echo "  already cloned"
  omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
fi
cp "$PLUGIN_DIR/Service.qml" "$PLUGIN_DIR/Service.qml.bak.$STAMP"
python3 "$REPO/lib/patch-idle.py" "$PLUGIN_DIR/Service.qml"
if cmp -s "$PLUGIN_DIR/Service.qml" "$PLUGIN_DIR/Service.qml.bak.$STAMP"; then
  rm "$PLUGIN_DIR/Service.qml.bak.$STAMP"
fi

if ((SET_TIMERS)); then
  step "Setting idle timers: screensaver=${SCREENSAVER}s lock=${LOCK}s$( ((LOCK == 0)) && echo ' (never)')"
  [[ -f $SHELL_JSON ]] || echo '{}' >"$SHELL_JSON"
  cp "$SHELL_JSON" "$SHELL_JSON.bak.$STAMP"
  jq --argjson s "$SCREENSAVER" --argjson l "$LOCK" '.idle.screensaver = $s | .idle.lock = $l' \
    "$SHELL_JSON" >"$SHELL_JSON.tmp"
  mv "$SHELL_JSON.tmp" "$SHELL_JSON"
fi

# The idle service stays loaded, so file changes only take effect after a
# full shell restart.
step "Restarting the Omarchy shell"
omarchy restart shell >/dev/null 2>&1 || true

step "Verifying"
status=""
for _ in $(seq 20); do
  status=$(omarchy-shell idle status 2>/dev/null) && [[ $status == *lockEnabled* ]] && break
  status=""
  sleep 0.5
done
[[ -n $status ]] || die "idle service didn't report the patched status -- check: journalctl --user -n 50 | grep idle"
jq '{stayAwake, screensaver, lock, lockEnabled}' <<<"$status"

if jq -e .stayAwake <<<"$status" >/dev/null; then
  echo
  echo "Note: 'Stay awake' is on, so idle is paused. Turn it off from the bar indicator."
fi

echo
echo "Done. Preview with: matrix-screensaver force"
