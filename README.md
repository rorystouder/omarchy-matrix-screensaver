# omarchy-matrix-screensaver

Matrix-style digital rain as the [Omarchy](https://omarchy.org) idle screensaver.

- Endless green katakana/digit rain, fullscreen on every monitor
- Any key or mouse movement dismisses it
- Configurable idle timers, including "screensaver but never lock"

## Install

```bash
git clone <this-repo> ~/omarchy-matrix-screensaver
cd ~/omarchy-matrix-screensaver
./install.sh                          # screensaver at 1200s, lock at 3000s
./install.sh --screensaver 600 --lock 0   # screensaver at 600s, never lock
./install.sh --keep-timers            # don't touch idle timers
```

Re-running is safe. Preview any time with `matrix-screensaver force`.

## What it does

| Piece | Location |
|---|---|
| `bin/matrix-rain` – the renderer (Python, stdlib only) | `~/.local/bin/` |
| `bin/matrix-screensaver` – opens it fullscreen on each monitor | `~/.local/bin/` |
| Idle service clone, patched by `lib/patch-idle.py` | `~/.config/omarchy/plugins/$USER.idle/` |
| Idle timers (`idle.screensaver`, `idle.lock`) | `~/.config/omarchy/shell.json` |

Omarchy's idle service launches `omarchy-launch-screensaver` by name, and
`/usr/share/omarchy/bin` comes first on its PATH, so it can't be shadowed.
Instead the installer runs `omarchy plugin clone omarchy.idle` and patches the
clone to:

1. launch `matrix-screensaver` instead of the stock screensaver
2. treat `idle.lock` = `0` / `false` / `"never"` as "never lock on idle"
   (stock Omarchy would lock *immediately*)
3. report `lockEnabled` in `omarchy-shell idle status`

The patch is applied to each machine's own copy of the idle service, so it
tracks that machine's Omarchy version. If Omarchy changes the service so the
patch no longer fits, the installer stops without modifying anything.

The clone won't receive future upstream changes to the idle service. Re-run
`./uninstall.sh && ./install.sh` after a big Omarchy update to pick them up.

## Tweaks

Set these in the `RAIN=` line of `~/.local/bin/matrix-screensaver`, e.g.
`RAIN="env MATRIX_COLOR=ff0040 $HOME/.local/bin/matrix-rain --screensaver"`:

- `MATRIX_COLOR` – hex rain color (default `00ff41`)
- `MATRIX_FPS` – frame rate (default `30`)

Fall speed: the `speed` tuple in the `Drop` class of `bin/matrix-rain`
(frames per row, higher is slower).

## Uninstall

```bash
./uninstall.sh
```

Restores the stock `omarchy.idle` service and removes the scripts.
