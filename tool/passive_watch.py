"""Passive availability watch for the Dhimmah phone session.

While a foreign application owns the screen this script only *observes* who owns
the focus. It launches Dhimmah only once the phone is genuinely idle — the
launcher, the lock screen, or a sleeping display — so it never takes the screen
away from a person who is using their phone, and it never sends any input to a
surface that is not Dhimmah.

    python3 tool/passive_watch.py [serial] [minutes]
"""

import re
import subprocess
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.29.138:36373"
MINUTES = float(sys.argv[2]) if len(sys.argv) > 2 else 25.0

DHIM = "com.dhimmah.dhimmah"
IDLE = {
    "com.sec.android.app.launcher",
    "com.samsung.android.app.launcher",
    "com.android.launcher3",
    "com.google.android.apps.nexuslauncher",
    "com.android.systemui",
}


def sh(*args: str) -> str:
    return subprocess.run(
        ["adb", "-s", SERIAL, *args],
        capture_output=True,
        text=True,
        shell=False,
        timeout=30,
    ).stdout


def focus() -> str:
    match = re.search(
        r"mCurrentFocus=Window\{\S+ u0 ([^/}\s]+)", sh("shell", "dumpsys", "window")
    )
    return match.group(1) if match else ""


def asleep() -> bool:
    match = re.search(r"mWakefulness=(\w+)", sh("shell", "dumpsys", "power"))
    return bool(match and match.group(1) != "Awake")


def main() -> int:
    deadline = time.time() + MINUTES * 60
    # The display has to be *off*. A phone sitting on the launcher is a phone
    # someone just put down and may pick straight back up, and launching into it
    # would take the screen from them mid-thought; a sleeping display is a phone
    # that is genuinely free.
    sustain = max(3, int(20 / 5))
    quiet = 0

    print(f"[watch] start {time.strftime('%H:%M:%S')}", flush=True)
    while time.time() < deadline:
        package = focus()
        sleeping = asleep()
        state = "asleep" if sleeping else (package or "unknown")

        if sleeping:
            quiet += 1
            if quiet < sustain:
                print(
                    f"[watch] {time.strftime('%H:%M:%S')} asleep "
                    f"{quiet}/{sustain} before taking the window",
                    flush=True,
                )
                time.sleep(5)
                continue

            # The display has been off long enough that the phone is not being
            # used. This is the only moment the run takes the screen.
            print(f"[watch] {time.strftime('%H:%M:%S')} free -> taking the window", flush=True)
            if package != DHIM:
                sh(
                    "shell",
                    "monkey",
                    "-p",
                    DHIM,
                    "-c",
                    "android.intent.category.LAUNCHER",
                    "1",
                )
            for _ in range(40):
                time.sleep(1)
                if focus() == DHIM:
                    print(
                        f"[watch] {time.strftime('%H:%M:%S')} Dhimmah is in front",
                        flush=True,
                    )
                    return 0
            print("[watch] launched, focus did not settle", flush=True)
            quiet = 0
        else:
            quiet = 0
            if package == DHIM:
                # In front, but awake: someone is holding the phone. Watching
                # continues rather than declaring a window that is not free.
                print(
                    f"[watch] {time.strftime('%H:%M:%S')} Dhimmah is in front, "
                    "but the display is awake",
                    flush=True,
                )
            else:
                print(f"[watch] {time.strftime('%H:%M:%S')} busy: {state}", flush=True)
        time.sleep(5)
    print("[watch] deadline reached", flush=True)
    return 2


if __name__ == "__main__":
    sys.exit(main())
