"""Atomic state verification for the Dhimmah phone driver.

The resolver in `drive_device_ui.py` is audited and is used unchanged. What this
module adds is the one thing that was missing: a UI state is never *observed*
without the screen it came from being verified at the same moment.

The previous version read the focused window, and dumped the hierarchy later.
A system surface can appear between those two reads — a lock-screen clock did —
and a conditional then made a decision about a screen that was no longer there.

Here the two observations are taken back to back and checked against each other:
the window manager says who owns the focus, the hierarchy says whose nodes it
contains, and the state counts as verified only when both name the application.
An unverified state yields an empty hierarchy, so no resolver can find a target
in it and no tap can be sent — and nothing is ever sent to the foreign surface:
no Back, no Home, no tap, no swipe, no attempt to recover it.

When another application legitimately owns the screen, this module **waits
passively** for it to go away. Waiting is observation only: it polls who owns the
focus and sends nothing, which is the difference between coexisting with a phone
in use and fighting it.

    python3 tool/guarded_ui.py [serial] where
    python3 tool/guarded_ui.py [serial] chain
"""

import importlib.util
import json
import re
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.29.138:36373"
COMMAND = sys.argv[2] if len(sys.argv) > 2 else "where"

EXPECTED = "com.dhimmah.dhimmah"
WAIT_TIMEOUT_SECONDS = 60.0
POLL_SECONDS = 0.7


def load_driver():
    """The audited driver, imported rather than copied."""
    saved = sys.argv
    sys.argv = ["driver", SERIAL]
    try:
        spec = importlib.util.spec_from_file_location("driver", "tool/drive_device_ui.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.argv = saved


driver = load_driver()


def focus_package() -> str:
    for line in driver.adb("shell", "dumpsys", "window").stdout.splitlines():
        if "mCurrentFocus=" in line or "mFocusedApp=" in line:
            found = re.findall(r"\b[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+\b", line)
            if found:
                return found[0]
    return "(no focus reported)"


def tree_package(xml: str) -> str:
    """Whose screen the hierarchy describes, from the nodes themselves — so both
    observations describe one moment rather than two."""
    counts: dict[str, int] = {}
    for match in re.finditer(r'package="([^"]+)"', xml):
        counts[match.group(1)] = counts.get(match.group(1), 0) + 1
    if not counts:
        return "(no package in the tree)"
    return max(counts.items(), key=lambda item: item[1])[0]


def guarded_dump(tag: str, attempts: int = 3) -> str:
    """The hierarchy, only when the state is verified as the application's."""
    focus = focus_package()
    driver.adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    driver.adb("pull", "/sdcard/window.xml",
               driver.evidence_path("logs", f"{tag}.xml"))
    xml = driver.read_text(("logs", f"{tag}.xml"))
    tree = tree_package(xml)
    verified = focus == EXPECTED and tree == EXPECTED

    driver.write_text(
        ("logs", f"{tag}_state.json"),
        json.dumps(
            {
                "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "focus_package": focus,
                "tree_package": tree,
                "expected": EXPECTED,
                "verified": verified,
                "classification": "PASS" if verified else "SKIPPED — ENVIRONMENT",
            },
            ensure_ascii=False,
            indent=2,
        ),
    )

    if not verified and focus == EXPECTED and attempts > 1:
        # A system overlay — the status bar's, a shade peeking in, a frame of an
        # animation — can dominate one dump while the focused window is still the
        # application's. Re-reading tolerates that blip; it does not relax what
        # counts as verified, because the retry still has to agree with itself.
        print(f"   [{tag}] focus={focus!r} but tree={tree!r}; re-reading "
              f"({attempts - 1} left)")
        time.sleep(1.0)
        return guarded_dump(tag, attempts - 1)

    if not verified:
        driver.shot(f"{tag}_foreign")
        print(f"SKIPPED — ENVIRONMENT at {tag}: focus={focus!r} tree={tree!r}; "
              "nothing was sent to that surface")
        return ""
    return xml


def wait_for_dhimmah(tag: str) -> bool:
    """Waits, without touching anything, for Dhimmah to own the screen.

    Polling the owner is observation only — no tap, no Back, no Home, no key, no
    text, and nothing at all sent to whatever currently has the screen. If the
    application does not come forward within the bound, the run classifies the
    moment and stops rather than fighting another app for the display.
    """
    started = time.time()
    seen: list[str] = []
    while time.time() - started < WAIT_TIMEOUT_SECONDS:
        owner = focus_package()
        if not seen or seen[-1] != owner:
            seen.append(owner)
            print(f"   [{time.time() - started:5.1f}s] foreground: {owner}")
        if owner == EXPECTED:
            # The owner is right; the tree is checked by the caller's first dump.
            print(f"Dhimmah returned after {time.time() - started:.1f}s "
                  f"(seen: {' → '.join(seen)})")
            return True
        time.sleep(POLL_SECONDS)

    driver.shot(f"{tag}_timeout")
    driver.adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    driver.adb("pull", "/sdcard/window.xml",
               driver.evidence_path("logs", f"{tag}_timeout.xml"))
    driver.write_text(
        ("logs", f"{tag}_timeout.json"),
        json.dumps(
            {
                "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "waited_seconds": round(time.time() - started, 1),
                "owners_seen": seen,
                "expected": EXPECTED,
                "classification": "SKIPPED — ENVIRONMENT",
                "note": "no input was sent to any application while waiting",
            },
            ensure_ascii=False,
            indent=2,
        ),
    )
    print(f"ENVIRONMENT_STOP — Dhimmah did not return within "
          f"{WAIT_TIMEOUT_SECONDS:.0f}s (owners seen: {seen}); nothing was sent")
    return False


def guarded_act(target: str, tag: str) -> bool:
    """Presses [target], but only through a verified state."""
    xml = guarded_dump(f"{tag}_before")
    if not xml:
        return False
    resolution = driver.resolve(xml, target)
    driver.write_text(
        ("logs", f"{tag}_resolution.json"),
        json.dumps(
            {"target": target,
             "resolution": resolution.report() if resolution else None},
            ensure_ascii=False, indent=2,
        ),
    )
    if resolution is None:
        print(f"UNRESOLVED {target!r}: {[n.lines for n in driver.parse_nodes(xml)][:8]}")
        return False
    if resolution.confidence == "LOW":
        print(f"REFUSING a low-confidence tap for {target!r}: {resolution.strategy}")
        return False

    driver.shot(f"{tag}_before")
    driver.adb("shell", "input", "tap", str(resolution.x), str(resolution.y))
    print(f"TAP {target!r} via {resolution.strategy} ({resolution.confidence}) "
          f"-> ({resolution.x},{resolution.y})")
    time.sleep(2.0)
    driver.shot(f"{tag}_after")
    guarded_dump(f"{tag}_after")
    return True


def describe(tag: str) -> str:
    """Reads the screen and names what kind of Dhimmah screen it is."""
    xml = guarded_dump(tag)
    if not xml:
        return "unverified"
    lines = [n.lines for n in driver.parse_nodes(xml) if n.lines]
    print(f"--- {tag} ---")
    for entry in lines[:8]:
        print("   ", entry)
    flat = " ".join(line for entry in lines for line in entry)
    if "احتفظ بنسخة" in flat:
        return "backup"
    if "الرئيسية" in flat and "الأشخاص" in flat:
        return "home"
    if "الأشخاص" in flat:
        return "people"
    if "الإعدادات" in flat:
        return "settings"
    return "other"


def main() -> None:
    print("=== passive wait for a verified Dhimmah foreground ===")
    if not wait_for_dhimmah("B0_wait"):
        return

    print("=== where are we, exactly? ===")
    state = describe("B1_start")

    # Only a verified Dhimmah screen is ever navigated, and only the screen that
    # was actually read decides what the next step is.
    for attempt in range(3):
        if state in ("home", "people"):
            break
        if state in ("unverified",):
            return
        print(f"leaving a pushed route ({state}) with a verified رجوع")
        if not guarded_act("رجوع", f"B2_back_{attempt}"):
            return
        state = describe(f"B3_after_{attempt}")

    if state != "people":
        print("=== opening the People tab ===")
        if not guarded_act("الأشخاص", "B4_people"):
            return
        state = describe("B5_people")

    print(f"=== reached: {state} ===")


if __name__ == "__main__":
    if COMMAND == "where":
        describe("W0_where")
    elif COMMAND == "wait":
        wait_for_dhimmah("W1_wait")
    else:
        main()
