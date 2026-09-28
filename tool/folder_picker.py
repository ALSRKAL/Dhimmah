"""Drives Android's own folder picker for the Dhimmah backup location.

The picker is a *system* surface, so it is treated as one: it is read for what it
is, with its own labels, and only points inside it are pressed. Dhimmah's own
screen is only ever reached through the guarded dump, which refuses to read
anything unless the window manager and the hierarchy agree that Dhimmah owns the
screen. Nothing here uses the app's semantic resolver against the system's UI —
the two are different programs and their labels only look alike.

    describe              what is on the screen now, whoever owns it
    open                  press the app's choose-folder row and report the picker
    tap <label>           press a label inside the picker, then describe
    list                  print the rows the picker is offering
    back                  press Back inside the picker, verified
    root                  report whether the picker is at its root
"""

import importlib.util
import json
import os
import re
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.0.4:5555"
ACTION = sys.argv[2] if len(sys.argv) > 2 else "describe"
TARGET = sys.argv[3] if len(sys.argv) > 3 else ""
MODE = sys.argv[4] if len(sys.argv) > 4 else "row"

#: Rows are in the list, controls are in the toolbar, and the picker gives the
#: same words to both. The mode says which one is meant.
ROW_MODE = MODE if MODE in ("row", "button") else "row"

sys.argv = ["folder_picker", SERIAL, ACTION]

_spec = importlib.util.spec_from_file_location("guarded", "tool/guarded_ui.py")
guarded = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guarded)

driver = guarded.driver

#: Android's own pickers, and the hosts that draw them. Anything else is a
#: foreign application and is never given input.
PICKER_PACKAGES = {
    "com.android.documentsui",
    "com.google.android.documentsui",
    "com.samsung.android.scpm",
    "com.android.intentresolver",
    "android",
}

#: The label the app's own row carries. Read from the build under test, because a
#: literal here goes stale the moment the screen is reworded and the failure is a
#: press that finds nothing rather than a crash.
LOCALISATIONS_AR = "lib/l10n/generated/app_localizations_ar.dart"


def label(name: str) -> str:
    """One of the app's own Arabic strings, read from the build under test.

    A getter whose text does not fit on one line is written with the string on
    the next, so the whitespace between `=>` and the quote is allowed to include
    a newline; insisting on a single line is how a run stopped with "the app has
    no Arabic string backupRestoreInvalid" about a string that was right there.
    """
    with open(LOCALISATIONS_AR, encoding="utf-8") as handle:
        text = handle.read()
    match = re.search(rf"String get {name} =>\s*'([^']+)'", text)
    if not match:
        raise SystemExit(f"the app has no Arabic string {name!r}")
    return match.group(1)


CHOOSE_ROW = label("backupFolderChoose")


def owner() -> str:
    return guarded.focus_package()


def snap(tag: str) -> str:
    """The hierarchy as it is, *whoever* owns the screen, with a screenshot.

    Deliberately not the guarded dump: the guard refuses to read a foreign
    surface, which is right for deciding whether to touch the app and wrong for
    reading a picker that this flow opened on purpose.
    """
    driver.shot(tag)
    driver.adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    driver.adb("pull", "/sdcard/window.xml",
               driver.evidence_path("logs", f"{tag}.xml"))
    xml = driver.read_text(("logs", f"{tag}.xml"))
    driver.write_text(
        ("logs", f"{tag}_state.json"),
        json.dumps(
            {"at": time.strftime("%Y-%m-%dT%H:%M:%S"), "owner": owner(),
             "tree_package": guarded.tree_package(xml), "bytes": len(xml)},
            ensure_ascii=False,
            indent=2,
        ),
    )
    print(f"[{tag}] owner={owner()!r} tree={guarded.tree_package(xml)!r} "
          f"xml={len(xml)}B")
    for node in driver.parse_nodes(xml):
        if node.lines:
            print("   ", " ⏎ ".join(node.lines)[:150])
    return xml


def act_choose() -> bool:
    """Presses the app's own choose-folder row, through the guard."""
    xml = guarded.guarded_dump("F0_app")
    if not xml:
        print("the app does not own the screen, so nothing was pressed")
        return False
    resolution = driver.resolve(xml, CHOOSE_ROW)
    if resolution is None:
        print(f"UNRESOLVED {CHOOSE_ROW!r} on the app's screen")
        return False
    if resolution.confidence == "LOW":
        print(f"REFUSING a low-confidence press of {CHOOSE_ROW!r}")
        return False
    driver.shot("F1_before_press")
    print(f"pressing the app's {CHOOSE_ROW!r} via {resolution.strategy} "
          f"-> ({resolution.x},{resolution.y})")
    driver.adb("shell", "input", "tap", str(resolution.x), str(resolution.y))
    time.sleep(3.5)
    driver.shot("F2_after_press")
    return True


_NODE = re.compile(r"<node\b([^>]*?)(/?)>|(</node>)")
_BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def _attrs(blob: str) -> dict:
    return dict(re.findall(r'([\w-]+)="([^"]*)"', blob))


def boxes(xml: str, *, in_list: bool) -> list[tuple[str, int, int, int, int]]:
    """Every labelled box that is, or is not, inside a scrollable list."""
    stack: list[bool] = []
    found: list[tuple[str, int, int, int, int]] = []
    for match in _NODE.finditer(xml):
        if match.group(3) is not None:
            if stack:
                stack.pop()
            continue
        attrs = _attrs(match.group(1))
        box = _BOUNDS.search(attrs.get("bounds", ""))
        nested = any(stack)
        if box and nested == in_list:
            words = driver.normalise(attrs.get("text", "")).strip()
            if words:
                found.append((words, *(int(v) for v in box.groups())))
        if match.group(2) != "/":
            stack.append(attrs.get("scrollable") == "true")
    return found


def clear_band(xml: str) -> tuple[int, int]:
    """The vertical strip of the picker that is not covered by its own chrome.

    The list runs the full height of the window, *behind* the toolbar and the
    "use this folder" bar. A folder whose tile is scrolled half-way under the
    toolbar is still in the hierarchy, with real bounds — and its centre is the
    toolbar's New-folder button. Pressing there creates a folder instead of
    entering one, which looks like the picker ignoring the press. So a row is
    only pressable when it lies between the two bars.
    """
    top, bottom = 0, 10**9
    for match in _NODE.finditer(xml):
        if match.group(3) is not None:
            continue
        attrs = _attrs(match.group(1))
        box = _BOUNDS.search(attrs.get("bounds", ""))
        if not box:
            continue
        y1, y2 = int(box.group(2)), int(box.group(4))
        if y2 <= y1:
            # A node with no height is not on the glass, and a bar that is not
            # there must not shrink the band: one collapsed node reported as the
            # footer put the whole list "under the chrome" and stopped the run.
            continue
        name = attrs.get("resource-id", "").rsplit("/", 1)[-1]
        if name in ("toolbar", "collapsing_toolbar"):
            top = max(top, y2)
        if name == "container_save" and y1 > top:
            bottom = min(bottom, y1)
    return top, bottom


def press(label_text: str, tag: str, mode: str = "row") -> bool:
    """Presses a label inside the picker, verified to be a picker first.

    `row` reaches into the list; `button` reaches the toolbar. They are separate
    on purpose: a word can name both, and the two are in different places.
    """
    wanted = driver.normalise(label_text).strip()
    for attempt in range(4):
        xml = snap(f"{tag}_a{attempt}_before" if attempt else f"{tag}_before")
        current = owner()
        if current not in PICKER_PACKAGES:
            print(f"REFUSING to press {label_text!r}: the screen belongs to "
                  f"{current!r}, which is not a system picker this flow opened")
            return False

        if mode == "button":
            candidates = [
                (n.x1, n.y1, n.x2, n.y2)
                for n in driver.parse_nodes(xml)
                if n.lines == [wanted]
            ]
            where = "toolbar"
        else:
            candidates = [
                (x1, y1, x2, y2)
                for words, x1, y1, x2, y2 in boxes(xml, in_list=True)
                if words == wanted
            ]
            where = "list"

        if not candidates:
            print(f"the picker's {where} offers no {label_text!r}")
            print("   it does offer:")
            offered = (
                sorted({w for w, *_ in boxes(xml, in_list=True)})
                if mode == "row"
                else sorted({n.lines[0] for n in driver.parse_nodes(xml) if n.lines})
            )
            for word in offered:
                print(f"      {word!r}")
            return False

        top, bottom = clear_band(xml)
        clear = [c for c in candidates if c[1] >= top and c[3] <= bottom]
        if clear or mode == "button":
            x1, y1, x2, y2 = (clear or candidates)[0]
            x, y = (x1 + x2) // 2, (y1 + y2) // 2
            print(f"pressing the picker's {label_text!r} in the {where} "
                  f"-> ({x},{y}) of {len(candidates)} match(es); clear band is "
                  f"y>={top}..y<={bottom}")
            driver.adb("shell", "input", "tap", str(x), str(y))
            time.sleep(2.5)
            return True

        # The row is real but under the picker's chrome. Move the list until it
        # is not: rows above the band come down, rows below it go up.
        somewhere = "up" if candidates[0][1] < top else "down"
        print(f"{label_text!r} is at y={candidates[0][1]}..{candidates[0][3]}, "
              f"under the picker's own chrome (clear band y>={top}..y<={bottom}); "
              f"scrolling {somewhere} to bring it clear "
              f"(attempt {attempt} of 3)")
        if not scroll_picker(f"{tag}_a{attempt}_scroll", somewhere):
            return False
    print(f"gave up bringing {label_text!r} into the clear")
    return False


def act_list() -> bool:
    xml = snap("L_picker")
    rows = boxes(xml, in_list=True)
    print(f"rows the list is offering: {len(rows)}")
    for words, x1, y1, x2, y2 in rows:
        print(f"   [{x1},{y1}][{x2},{y2}]  {words[:60]}")
    return True


def act_back() -> bool:
    xml = snap("B_before")
    current = owner()
    if current not in PICKER_PACKAGES:
        print(f"REFUSING to press Back: the screen belongs to {current!r}")
        return False
    print("pressing Back inside the picker")
    driver.adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(2.5)
    snap("B_after")
    return True


def act_find() -> bool:
    """Brings a row into view by scrolling, then presses it.

    A picker shows a window of a long list, and a file the test put in the folder
    is very often not in that window: the dump then contains no such row at all,
    and `tap` reports "the picker offers no …" about a file that is plainly
    there. Scrolling is the gesture a person makes to reach it.
    """
    wanted = driver.normalise(TARGET).strip()
    for attempt in range(8):
        xml = snap(f"FIND{attempt}")
        current = owner()
        if current not in PICKER_PACKAGES:
            print(f"REFUSING to search: the screen belongs to {current!r}")
            return False
        names = [words for words, *_ in boxes(xml, in_list=True)]
        if wanted in names:
            print(f"{wanted!r} is in view after {attempt} scroll(s)")
            return press(TARGET, f"FIND{attempt}_press", "row")
        below = not names or wanted > max(names)
        direction = "down" if below else "up"
        print(f"{wanted!r} is not in view (window shows {names[:3]}…{names[-3:]}); "
              f"scrolling {direction} (attempt {attempt} of 7)")
        if not scroll_picker(f"FIND{attempt}_scroll", direction):
            return False
    print(f"gave up looking for {wanted!r}")
    return False


def act_root() -> bool:
    """Reports whether the picker is showing its own root, and what it offers."""
    xml = snap("R_picker")
    text = " ".join(
        line for node in driver.parse_nodes(xml) for line in node.lines
    )
    print(f"---- picker text ----\n{text}\n")
    return True


def scroll_picker(tag: str, direction: str = "down") -> bool:
    """One flick of the picker's list, sized to the display it is drawn on."""
    xml = snap(f"{tag}_before")
    current = owner()
    if current not in PICKER_PACKAGES:
        print(f"REFUSING to scroll: the screen belongs to {current!r}")
        return False
    out = driver.adb("shell", "wm", "size").stdout
    match = re.search(r"Override size:\s*(\d+)x(\d+)", out) or re.search(
        r"Physical size:\s*(\d+)x(\d+)", out
    )
    width, height = (int(match.group(1)), int(match.group(2))) if match else (0, 0)
    if not width:
        print(f"REFUSING to guess the screen size from {out!r}")
        return False
    far, near = int(height * 0.75), int(height * 0.30)
    y_from, y_to = (far, near) if direction == "down" else (near, far)
    x = width // 2
    driver.adb("shell", "input", "swipe", str(x), str(y_from), str(x), str(y_to),
               "300")
    time.sleep(1.5)
    snap(f"{tag}_after")
    return True


if __name__ == "__main__":
    print(f"=== folder picker: {ACTION} ===")
    actions = {
        "describe": lambda: bool(snap("D_screen")),
        "open": act_choose,
        "tap": lambda: press(TARGET, "T_press", ROW_MODE),
        "find": act_find,
        "list": act_list,
        "back": act_back,
        "root": act_root,
        "scroll": lambda: scroll_picker("S_scroll", TARGET or "down"),
    }
    if ACTION not in actions:
        raise SystemExit(f"unknown action {ACTION!r}; expected {sorted(actions)}")
    ok = actions[ACTION]()
    print(f"=== folder picker: {'OK' if ok else 'STOPPED'} ===")
    sys.exit(0 if ok else 1)
