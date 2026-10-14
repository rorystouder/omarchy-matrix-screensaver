#!/usr/bin/env python3
"""Patch a cloned Omarchy idle service (Service.qml) to:

  1. launch ~/.local/bin/matrix-screensaver instead of omarchy-launch-screensaver
  2. treat idle.lock = 0 / false / "never" as "never lock on idle"
  3. expose lockEnabled / firstIdle in `omarchy-shell idle status`

Idempotent: already-applied patches are skipped. Exits non-zero if the file
doesn't look like the expected Omarchy idle service, without writing anything.

Usage: patch-idle.py <path/to/Service.qml>
"""

import sys

PATCHES = [
    (
        "launch matrix screensaver",
        '|| omarchy-launch-screensaver")',
        '|| \\"$HOME/.local/bin/matrix-screensaver\\"")',
        "matrix-screensaver",
    ),
    (
        "lockEnabled property",
        "  readonly property int firstIdleTimeoutSeconds: Math.min(screensaverTimeoutSeconds, lockTimeoutSeconds)",
        """  // idle.lock of 0, false or "never" disables the idle lock (screensaver only).
  readonly property bool lockEnabled: {
    var v = idleConfig.lock
    return !(v === false || v === "never" || (v !== undefined && v !== null && Number(v) === 0))
  }
  readonly property int firstIdleTimeoutSeconds: lockEnabled ? Math.min(screensaverTimeoutSeconds, lockTimeoutSeconds) : screensaverTimeoutSeconds""",
        "readonly property bool lockEnabled",
    ),
    (
        "skip lock when disabled",
        '    if (root.lockDelaySeconds === 0) lockSystem("lock-timeout-immediate")',
        """    if (!root.lockEnabled) logEvent("idle-lock-disabled")
    else if (root.lockDelaySeconds === 0) lockSystem("lock-timeout-immediate")""",
        'logEvent("idle-lock-disabled")',
    ),
    (
        "lock timer guard",
        'onTriggered: if (root.idleEnabled && root.idledThisCycle) root.lockSystem("lock-timeout")',
        'onTriggered: if (root.lockEnabled && root.idleEnabled && root.idledThisCycle) root.lockSystem("lock-timeout")',
        "root.lockEnabled && root.idleEnabled",
    ),
    (
        "status fields",
        "      lock: root.lockTimeoutSeconds,\n",
        "      lock: root.lockTimeoutSeconds,\n      lockEnabled: root.lockEnabled,\n      firstIdle: root.firstIdleTimeoutSeconds,\n",
        "lockEnabled: root.lockEnabled,",
    ),
]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    with open(path) as f:
        src = f.read()

    failed = []
    for name, old, new, marker in PATCHES:
        if marker in src:
            print(f"  = {name} (already applied)")
        elif src.count(old) == 1:
            src = src.replace(old, new)
            print(f"  + {name}")
        else:
            failed.append(name)

    if failed:
        print(
            "error: Service.qml doesn't match what this installer expects "
            "(Omarchy may have changed it). Not modified. Failed patches:\n  - "
            + "\n  - ".join(failed),
            file=sys.stderr,
        )
        sys.exit(1)

    with open(path, "w") as f:
        f.write(src)


if __name__ == "__main__":
    main()
