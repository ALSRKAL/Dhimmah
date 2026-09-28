"""Drives the Dhimmah backup screen on the phone, refusing to act blind.

Every action goes through `guarded_ui`, which reads the window manager's owner
*and* the hierarchy's package and refuses to press anything unless both agree the
app owns the screen. That guard is not ceremony: an earlier pass at this used
plain `adb shell input tap` with coordinates copied from a previous dump, and the
taps landed on Samsung's Device Care app because Dhimmah had gone to the
background in between. The reading that followed described a screen that was not
the app.

    python3 tool/backup_screen_probe.py <serial> <what>

`what` is one of:

    open      reach the backup screen from wherever the app is
    state     read the switch, the headline and the details, and print them
    toggle    press the automatic-saving switch once, then read the state
    details   open the protection details, then read the state
"""

import importlib.util
import json
import re
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.0.3:5555"
WHAT = sys.argv[2] if len(sys.argv) > 2 else "state"

sys.argv = ["probe", SERIAL, WHAT]

_spec = importlib.util.spec_from_file_location("guarded", "tool/guarded_ui.py")
guarded = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guarded)

driver = guarded.driver

#: The switch's own words, read from the build under test.
LOCALISATIONS_AR = "lib/l10n/generated/app_localizations_ar.dart"


def label(name: str) -> str:
    with open(LOCALISATIONS_AR, encoding="utf-8") as handle:
        text = handle.read()
    match = re.search(rf"String get {name} =>\s*'([^']+)'", text)
    if not match:
        raise SystemExit(f"the app has no Arabic string {name!r}")
    return match.group(1)


def dump(tag: str) -> str:
    """The hierarchy, only when the guard agrees the app owns the screen."""
    return guarded.guarded_dump(tag)


def lines_of(xml: str) -> list[str]:
    return [" | ".join(n.lines) for n in driver.parse_nodes(xml) if n.lines]


def point_of(xml: str, needle: str, line_index: int | None = None):
    """Where to press for [needle], preferring a specific line of a merged label."""
    for node in driver.parse_nodes(xml):
        if needle in node.lines and node.area > 0:
            if line_index is not None and len(node.lines) > line_index:
                share = (line_index + 0.5) / len(node.lines)
                return (
                    (node.x1 + node.x2) // 2,
                    node.y1 + int((node.y2 - node.y1) * share),
                    node.report()["bounds"],
                )
            return (
                (node.x1 + node.x2) // 2,
                (node.y1 + node.y2) // 2,
                node.report()["bounds"],
            )
    return None


def switch_node(xml: str):
    for match in re.finditer(r"<node[^>]*class=\"android.widget.Switch\"[^>]*>", xml):
        node = match.group(0)
        bounds = re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", node)
        checked = re.search(r"checked=\"(\w+)\"", node)
        if not bounds:
            continue
        x1, y1, x2, y2 = (int(v) for v in bounds.groups())
        if x2 <= x1 or y2 <= y1:
            continue
        return (x1 + x2) // 2, (y1 + y2) // 2, checked.group(1) if checked else "?"
    return None


def on_backup_screen(xml: str) -> bool:
    """Whether the backup screen is the one on screen.

    Two markers, because one is not enough on a phone. The protection card's own
    control sits near the top and scrolls away — a walk that only knows it
    answers "not the backup screen" about the backup screen it is standing on as
    soon as the page is scrolled, and then presses at whatever else it can see
    (that is how it pressed the app bar title nine times). The two action rows
    below the fold carry the second marker: they exist on this screen and
    nowhere else, so they identify it from any scroll position.
    """
    text = " ".join(lines_of(xml))
    # Either word for the same control: it reads "hide the details" once they are
    # open, and an earlier version of this walk then failed to recognise the very
    # screen it was standing on and pressed the app bar title nine times.
    if label("backupProtectionDetails") in text or label("backupProtectionHideDetails") in text:
        return True
    return (
        label("backupPreviousAction") in text
        and label("backupRestoreAction") in text
    )


def to_top(tag: str) -> str:
    """The hierarchy with the list scrolled back to its first row.

    The protection card is what this probe reads and presses, and it is the
    first thing on the screen — so a page left scrolled (a previous run opened
    the history, or the list was simply flicked) hides exactly the controls the
    reading is about. Swiping down is how a person gets back up.
    """
    xml = dump(f"{tag}_top0")
    for attempt in range(3):
        if not xml:
            return xml
        if label("backupProtectionDetails") in " ".join(lines_of(xml)) or \
                label("backupProtectionHideDetails") in " ".join(lines_of(xml)):
            return xml
        driver.adb("shell", "input", "swipe", "360", "500", "360", "1300", "280")
        time.sleep(1.4)
        xml = dump(f"{tag}_top{attempt + 1}")
    return xml


def sheet_close(xml: str):
    """Where to press to leave a sheet the app put up, or None if none is open.

    A sheet covers the screen it came from: the page behind is still there, but
    its nodes are gone from the hierarchy, so this walk cannot recognise the
    page it is standing on and starts pressing at whatever else it can see. The
    history sheet did exactly that to it — a toggle went to the sheet's list and
    the switch was never touched, while the reading afterwards looked like the
    app had ignored the press. The way out is the sheet's own button, never the
    system Back, which would leave the screen entirely.
    """
    closes = [
        node for node in driver.parse_nodes(xml)
        if node.area > 0 and node.lines == [label("actionClose")]
    ]
    if not closes:
        return None
    # The lowest one is the sheet's bottom control; a sheet may also carry a
    # corner close near its title, and both leave.
    node = sorted(closes, key=lambda item: item.y2)[-1]
    return (node.x1 + node.x2) // 2, (node.y1 + node.y2) // 2, node.report()["bounds"]


def read_state(tag: str, xml: str | None = None) -> dict:
    """Everything the phone is showing about automatic saving, in one reading."""
    xml = xml or dump(tag)
    if not xml:
        return {"error": "the app does not own the screen"}
    found = lines_of(xml)
    switch = switch_node(xml)
    report = {
        "switch_checked": switch[2] if switch else None,
        "headline": next(
            (
                line
                for line in found
                if any(
                    label(name) in line
                    for name in (
                        "backupProtectionProtected",
                        "backupProtectionPending",
                        "backupProtectionAutoOff",
                        "backupProtectionNoLocation",
                        "backupProtectionNever",
                        "backupProtectionAttention",
                        "backupProtectionStorage",
                        "backupProtectionRecoverable",
                    )
                )
            ),
            None,
        ),
        # The details panel's own row labels, matched as the *first* line of a
        # node. This filter used to name three strings the screen no longer
        # draws, so it silently matched the headline and a reading that said
        # "details" was showing the first line of the screen twice. Matching the
        # first line exactly also keeps the folder card out: its title
        # ("mجلد النسخ الاحتياطية") starts with the details row's label
        # ("مجلد النسخ") and a substring test cannot tell them apart.
        "details": [
            line
            for line in found
            if line
            and line[0]
            in (
                label("backupDetailAutomatic"),
                label("backupDetailLastCopy"),
                label("backupDetailRestorable"),
                label("backupDetailPending"),
                label("backupDetailFolder"),
                label("backupDetailAttempts"),
            )
        ],
    }
    driver.write_text(
        ("logs", f"PROBE_{tag}.json"),
        json.dumps({"state": report, "screen": found}, ensure_ascii=False, indent=2),
    )
    return report


def print_state(report: dict) -> None:
    print(f"   switch      : {report.get('switch_checked')}")
    print(f"   headline    : {report.get('headline')}")
    for line in report.get("details", []):
        print(f"   details     : {line[:110]}")


def open_backup(tag: str) -> bool:
    """Walks to the backup screen, verifying the screen after every press.

    Written as a loop over what each screen actually says rather than as a script
    of presses: the app opens on whatever route it was left on, the settings list
    has to be scrolled before its rows exist at all, and a heading carries the
    same words as the row under it. Each of those broke a simpler version of
    this.
    """
    for attempt in range(10):
        xml = dump(f"{tag}{attempt}")
        if not xml:
            time.sleep(1.5)
            continue
        found = lines_of(xml)
        text = " ".join(found)
        if on_backup_screen(xml):
            print(f"on the backup screen (after {attempt} press(es))")
            return True

        covered = sheet_close(xml)
        if covered:
            print(f"a sheet is covering the screen; closing it at {covered[2]}")
            driver.adb("shell", "input", "tap", str(covered[0]), str(covered[1]))
            time.sleep(2.2)
            continue

        row_label = "النسخ الاحتياطي والاستعادة"
        # The settings list is a pushed route: it has a back control and no tab
        # bar under it. Identifying it by its section words instead ("اللغة",
        # "الوضع") worked only while the top of the list was on the glass — at a
        # larger text scale the list is long enough that scrolling to the backup
        # row takes those words away, and this walk then read the screen as the
        # More tab (whose own heuristic matched, because the bottom of the
        # settings list also says "حول التطبيق") and pressed the wrong things.
        on_settings = (
            "رجوع" in text
            and "الإعدادات" in text
            and "علامة التبويب" not in text
        )
        on_more = "المزيد" in text and "علامة التبويب 5" in text

        # The row first: once the list is scrolled to it, the words that identify
        # the screen it belongs to have gone off the top, so asking what screen
        # this is would answer "none of them" about the one row that matters.
        if on_settings or row_label in text:
            target = point_of(xml, row_label, line_index=1)
            if target:
                print(f"pressing the backup row at {target[2]}")
                driver.adb("shell", "input", "tap", str(target[0]), str(target[1]))
                time.sleep(3.0)
                continue
            print("the backup row is below the fold; scrolling")
            driver.adb("shell", "input", "swipe", "540", "1150", "540", "500", "300")
            time.sleep(1.8)
            continue

        if on_more:
            target = point_of(xml, "الإعدادات", line_index=1) or point_of(xml, "الإعدادات")
            if target:
                print(f"pressing the settings row at {target[2]}")
                driver.adb("shell", "input", "tap", str(target[0]), str(target[1]))
                time.sleep(3.0)
                continue

        # Anything else — the dashboard, a record screen, About — is left by
        # pressing the More tab, which is identified by carrying the tab
        # announcement as well as its name. The bare label is not enough: several
        # screens say "المزيد" in a sentence.
        tab = None
        for node in driver.parse_nodes(xml):
            if node.area > 0 and "المزيد" in node.lines and any(
                "علامة التبويب" in line for line in node.lines
            ):
                tab = node
                break
        if tab is not None:
            target = ((tab.x1 + tab.x2) // 2, (tab.y1 + tab.y2) // 2, tab.report()["bounds"])
            print(f"pressing the More tab at {target[2]}")
            driver.adb("shell", "input", "tap", str(target[0]), str(target[1]))
            time.sleep(3.0)
            continue

        # A pushed route with no tab bar — About, a record, the statement
        # screen. Its own Back is the way out, and it is the app's control, not
        # the system's.
        target = point_of(xml, "رجوع")
        if target:
            print(f"leaving a pushed route via its own back control at {target[2]}")
            driver.adb("shell", "input", "tap", str(target[0]), str(target[1]))
            time.sleep(2.4)
            continue

        print("not sure where this is; screen says:")
        for line in found[:8]:
            print("     ", line[:100])
        return False
    print("could not reach the backup screen")
    return False


def main() -> None:
    if WHAT == "open":
        print("reached:", open_backup("open"))
        return

    if not open_backup("nav"):
        raise SystemExit(1)

    if WHAT == "state":
        print("=== the phone's own reading ===")
        print_state(read_state("state", to_top("state")))

    elif WHAT == "toggle":
        xml = to_top("toggle")
        switch = switch_node(xml)
        if not switch:
            print("no switch on screen")
            raise SystemExit(1)
        print(f"pressing the switch at ({switch[0]},{switch[1]}); was {switch[2]}")
        driver.adb("shell", "input", "tap", str(switch[0]), str(switch[1]))
        time.sleep(3.0)
        print("=== after the press ===")
        print_state(read_state("toggle_after", to_top("toggle_after")))

    elif WHAT == "details":
        xml = to_top("details")
        target = point_of(xml, label("backupProtectionDetails"))
        if not target:
            print("no details control on screen")
            raise SystemExit(1)
        driver.adb("shell", "input", "tap", str(target[0]), str(target[1]))
        time.sleep(2.5)
        print("=== with the details open ===")
        print_state(read_state("details_after"))

    elif WHAT == "check":
        # The folder card's own control, pressed the way the user presses it.
        # This is the way back from a folder that moved or lost its grant, so a
        # run that can reach this screen but cannot press this button cannot
        # show that the recovery works.
        xml = to_top("check")
        target = point_of(xml, label("backupFolderCheck"))
        if not target:
            print(f"no {label('backupFolderCheck')!r} control on screen")
            raise SystemExit(1)
        print(f"pressing the folder check at {target[2]}")
        driver.adb("shell", "input", "tap", str(target[0]), str(target[1]))
        time.sleep(4.0)
        print("=== after checking the folder ===")
        print_state(read_state("check_after", to_top("check_after")))

    else:
        raise SystemExit(f"unknown action {WHAT!r}")


if __name__ == "__main__":
    main()
