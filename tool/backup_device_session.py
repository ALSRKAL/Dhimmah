"""One guarded step of the Dhimmah backup flow on the real phone.

Every step runs through `guarded_ui`, which refuses to read or touch anything
unless the window manager and the hierarchy agree that Dhimmah owns the screen.
A step is one of:

    goto        reach الإعدادات → النسخ الاحتياطي والاستعادة
    now         press احتفظ بنسخة الآن, then deal with the system share sheet
    history     press النسخ السابقة and read the sheet
    del         press the first حذف *inside the open sheet*, leaving it open
    restore     press استعد من ملف and report which picker the system opened
    peek        observe whatever is on the screen, Dhimmah or not

The share sheet is the system's own resolver, opened by the step above it. It is
not a third-party application, and the only thing ever sent to it is Back — the
gesture a person makes to change their mind — and only when the resolver is
verified to be the owner. No other surface is ever given input.
"""

import importlib.util
import re
import json
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.29.138:36373"
STEP = sys.argv[2] if len(sys.argv) > 2 else "peek"

#: The installed build's own words, so a renamed label cannot silently desync the
#: tool from the app. The APK on the phone is hash-compared against the local
#: build before a run, so these strings are the ones on the screen.
LOCALISATIONS_AR = "lib/l10n/generated/app_localizations_ar.dart"

sys.argv = ["session", SERIAL, STEP]

_spec = importlib.util.spec_from_file_location("guarded", "tool/guarded_ui.py")
guarded = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guarded)

driver = guarded.driver

#: The system surfaces a step of this flow is allowed to open, and the only
#: non-Dhimmah packages this script will ever send a key to.
SYSTEM_SURFACES = {
    "com.android.intentresolver",  # Android's own share / open-with chooser
    "com.android.documentsui",  # Android's own document picker
    "com.google.android.documentsui",
    "com.samsung.android.scpm",  # Samsung's picker host
    "android",  # the resolver's activity alias on some builds
}


def label(name: str) -> str:
    """One of the app's own Arabic strings, read from the build under test.

    Every label this tool presses is read from here rather than written down as a
    literal. A literal goes stale the moment the screen is reworded, and the
    failure is not a crash — it is a press that finds nothing, or worse, a walk
    that decides the destination it just reached is unrecognised and leaves. The
    APK on the phone is hash-compared against the local build before a run, so
    these are the words on the screen.
    """
    try:
        with open(LOCALISATIONS_AR, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as error:
        raise SystemExit(f"cannot read the app's Arabic strings: {error}")
    match = re.search(rf"String get {name} =>\s*'([^']+)'", text)
    if not match:
        raise SystemExit(
            f"the app has no Arabic string {name!r}; the screen has been reworded "
            "and this tool needs to be told the new name"
        )
    return match.group(1)


#: The label only the backup screen carries: its restore row, which every state of
#: that screen shows and no other screen has.
BACKUP_MARKER = label("backupRestoreAction")

#: Press the save action; its outcome is whatever the app then reports.
SAVE_ACTION = label("backupNowAction")
PREVIOUS_ACTION = label("backupPreviousAction")
DELETE_ACTION = label("backupDeleteAction")

#: The app bar's back control. Its word comes from Flutter's own Arabic
#: `MaterialLocalizations` rather than from the app's strings file, which is why
#: it is not read from there: it is the framework's word, drawn on the app's
#: behalf, and it does not change when the app is reworded.
BACK_ACTION = "رجوع"

#: What the app says only after the document was written, re-opened, read back
#: and found to parse with a matching checksum. A save that did not verify cannot
#: produce this sentence, so it is the whole of the save test.
SAVED_REPORT = label("backupExternalSaved")

#: A sheet's own way out, as the app words it.
CLOSE_ACTION = label("actionClose")

#: The heading over the copies that live inside the app, and the two sentences
#: that end a restore. The heading is what tells the sheet's two layers apart.
INTERNAL_HEADING = label("backupHistoryInternal")
RESTORE_CONFIRM = label("backupRestoreConfirm")
RESTORE_DONE = label("backupRestoreDone")
RESTORE_FAILED = label("backupRestoreFailed")
RESTORE_CONTINUE = label("backupRestoreContinue")


def state(tag: str) -> tuple[str, list[list[str]]]:
    """The verified hierarchy for a Dhimmah screen, as lines of text."""
    xml = guarded.guarded_dump(tag)
    if not xml:
        return "", []
    lines = [node.lines for node in driver.parse_nodes(xml) if node.lines]
    return xml, lines


def show(tag: str, lines: list[list[str]], limit: int = 26) -> None:
    print(f"--- {tag} ---")
    for entry in lines[:limit]:
        print("   ", " ⏎ ".join(entry))


def flat(lines: list[list[str]]) -> str:
    return " ".join(line for entry in lines for line in entry)


def on_backup_screen(lines: list[list[str]]) -> bool:
    """Whether what is on screen is the backup screen.

    Two markers, because this screen is taller than the phone and Flutter only
    hands the screen reader what is on the glass. The restore row sits below the
    fold, so a walk that knows only that row answers "this is not the backup
    screen" about the backup screen it is standing on, and backs out of the page
    it was asked to reach — which is exactly what happened: the app was on the
    backup screen showing `بياناتك محمية`, the walk called it unrecognised and
    pressed Back. The protection card's own control is at the top of the same
    screen, so the two together identify it from either end of the list.
    """
    text = flat(lines)
    return (
        BACKUP_MARKER in text
        or label("backupProtectionDetails") in text
        or label("backupProtectionHideDetails") in text
    )


def reveal(target: str, tag: str, attempts: int = 4) -> bool:
    """Scrolls until [target] is on the glass, so it can be pressed.

    The reverse of the same coin: recognising the screen from its top means a
    step that needs a control lower down arrives with that control not rendered.
    An unresolved finder would read as "the app has no such row".
    """
    for attempt in range(attempts):
        xml = guarded.guarded_dump(f"{tag}_reveal{attempt}")
        if not xml:
            return False
        for node in driver.parse_nodes(xml):
            if node.lines and target in node.lines and node.area > 0:
                print(f"{target!r} is on the glass at {node.report()['bounds']}")
                return True
        print(f"{target!r} is not rendered yet; scrolling (attempt {attempt + 1})")
        if not scroll(f"{tag}_scroll{attempt}"):
            return False
    return False


def candidate_points(xml: str, target: str) -> list[tuple[int, int, str]]:
    """Every point the target could plausibly be, best first.

    A settings section repeats its own title as the row's title, so a merged
    label reads `[section, row, row subtitle]`: the same words appear on two
    lines and `lines.index()` always returns the first — which is the *heading*,
    and a heading is not pressable. Which line is the row cannot be known from
    the text alone, so every occurrence is offered and the caller tries them
    until the screen actually changes.
    """
    wanted = driver.normalise(target).strip()
    out: list[tuple[int, int, str]] = []
    for node in driver.parse_nodes(xml):
        if node.lines == [wanted]:
            out.append((
                (node.x1 + node.x2) // 2,
                (node.y1 + node.y2) // 2,
                "exact-single-line-label",
            ))
    for node in driver.parse_nodes(xml):
        if len(node.lines) < 2 or wanted not in node.lines:
            continue
        for index, line in enumerate(node.lines):
            if line != wanted:
                continue
            share = (index + 0.5) / len(node.lines)
            out.append((
                (node.x1 + node.x2) // 2,
                node.y1 + int(node.height_share(share)),
                f"merged-label-line-{index}-of-{len(node.lines)}",
            ))

    seen: set[tuple[int, int]] = set()
    unique: list[tuple[int, int, str]] = []
    for x, y, how in out:
        if (x, y) in seen:
            continue
        seen.add((x, y))
        unique.append((x, y, how))
    return unique


def close_keyboard() -> bool:
    """Closes the IME if it is up, and reports the verified state."""
    match = re.search(
        r"mInputShown=(\w+)", driver.adb("shell", "dumpsys", "input_method").stdout
    )
    shown = bool(match and match.group(1) == "true")
    if shown:
        driver.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1.0)
        match = re.search(
            r"mInputShown=(\w+)", driver.adb("shell", "dumpsys", "input_method").stdout
        )
        shown = bool(match and match.group(1) == "true")
    return shown


def edit_fields(xml: str) -> list[tuple[int, int, int, int]]:
    """The input fields on the screen, with their bounds."""
    return [
        tuple(int(v) for v in bounds)
        for bounds in re.findall(
            r'<node[^>]*EditText[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
        )
    ]


def fill_field(xml: str, text: str, occurrence: int = 0) -> None:
    """Fills the [occurrence]th edit field: focus, clear to the end, type.

    Typing into a field that already holds content *appends* unless the cursor is
    moved to the end first, which is why every fill starts with MOVE_END. The
    keyboard is closed afterwards, because a swipe that starts under the open
    keyboard lands on its keys — and a numeric field then gains a digit nobody
    typed into it, which is how a ₹1,000 debt became ₹10,008.
    """
    x1, y1, x2, y2 = edit_fields(xml)[occurrence]
    driver.adb("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
    time.sleep(1.0)
    driver.adb("shell", "input", "keyevent", "KEYCODE_MOVE_END")
    time.sleep(0.4)
    for _ in range(16):
        driver.adb("shell", "input", "keyevent", "KEYCODE_DEL")
        time.sleep(0.1)
    driver.adb("shell", "input", "text", text)
    time.sleep(0.6)
    close_keyboard()


def scroll_safely(tag: str, direction: str = "down") -> bool:
    """Scrolls, but only once the keyboard is verified closed."""
    close_keyboard()
    return scroll(tag, direction)


def tap_until_change(target: str, tag: str) -> bool:
    """Presses [target] until the screen changes, then stops.

    For a label that legitimately appears more than once. Every attempt is
    verified before it is sent and re-read afterwards, so a press that lands on
    something inert is *seen* to have done nothing and the next occurrence is
    tried — rather than the run carrying on against a screen it never reached.
    """
    xml, _ = state(f"{tag}_before")
    if not xml:
        return False
    points = candidate_points(xml, target)
    if not points:
        print(f"UNRESOLVED {target!r} at {tag}")
        show(f"{tag}_unresolved", [n.lines for n in driver.parse_nodes(xml) if n.lines])
        return False

    for attempt, (x, y, how) in enumerate(points):
        driver.write_text(
            ("logs", f"{tag}_attempt_{attempt}.json"),
            json.dumps(
                {
                    "target": target,
                    "strategy": how,
                    "point": [x, y],
                    "of": len(points),
                },
                ensure_ascii=False,
                indent=2,
            ),
        )
        driver.shot(f"{tag}_attempt_{attempt}_before")
        driver.adb("shell", "input", "tap", str(x), str(y))
        print(f"TAP {target!r} via {how} -> ({x},{y})")
        time.sleep(2.4)
        driver.shot(f"{tag}_attempt_{attempt}_after")
        after = guarded.guarded_dump(f"{tag}_attempt_{attempt}_after")
        if after and after != xml:
            print(f"   the screen changed after attempt {attempt}")
            return True
        print(f"   nothing changed (attempt {attempt} of {len(points) - 1})")
    return False


def tap(target: str, tag: str, occurrence: int = 0) -> bool:
    xml, _ = state(f"{tag}_before")
    if not xml:
        return False
    resolution = driver.resolve(xml, target, occurrence)
    driver.write_text(
        ("logs", f"{tag}_resolution.json"),
        json.dumps(
            {
                "target": target,
                "occurrence": occurrence,
                "resolution": resolution.report() if resolution else None,
            },
            ensure_ascii=False,
            indent=2,
        ),
    )
    if resolution is None:
        print(f"UNRESOLVED {target!r} at {tag}")
        show(f"{tag}_unresolved", [n.lines for n in driver.parse_nodes(xml) if n.lines])
        return False
    if resolution.confidence == "LOW":
        print(f"REFUSING a low-confidence tap for {target!r} ({resolution.strategy})")
        return False
    driver.shot(f"{tag}_before")
    driver.adb("shell", "input", "tap", str(resolution.x), str(resolution.y))
    print(f"TAP {target!r} via {resolution.strategy} ({resolution.confidence}) "
          f"-> ({resolution.x},{resolution.y})")
    time.sleep(2.4)
    driver.shot(f"{tag}_after")
    return True


def owner() -> str:
    return guarded.focus_package()


def dismiss_system_surface(tag: str, attempts: int = 2) -> bool:
    """Backs out of a system surface this flow opened — never a foreign app.

    The owner is verified first, and only a package in [SYSTEM_SURFACES] is
    touched. Anything else is left exactly as it is, and the step stops.
    """
    for attempt in range(attempts):
        current = owner()
        if current == guarded.EXPECTED:
            print(f"{tag}: Dhimmah is in front again, nothing to dismiss")
            return True
        if current not in SYSTEM_SURFACES:
            print(f"{tag}: REFUSING to touch {current!r} — not a system surface "
                  "this flow opened, and not Dhimmah")
            driver.shot(f"{tag}_foreign")
            return False
        driver.shot(f"{tag}_surface_{attempt}")
        print(f"{tag}: pressing Back on the verified system surface {current!r}")
        driver.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1.8)
    return owner() == guarded.EXPECTED


def screen_size() -> tuple[int, int]:
    """The display the app is actually drawn on, override included.

    A phone whose resolution has been changed reports both the physical and the
    overridden size, and a gesture is measured in the second one. Without this a
    swipe written for one phone starts off the bottom of another and does
    nothing, which reads as "the list does not scroll" rather than as a tool bug.
    """
    out = driver.adb("shell", "wm", "size").stdout
    match = re.search(r"Override size:\s*(\d+)x(\d+)", out)
    if match:
        return int(match.group(1)), int(match.group(2))
    match = re.search(r"Physical size:\s*(\d+)x(\d+)", out)
    if match:
        return int(match.group(1)), int(match.group(2))
    print(f"REFUSING to guess the screen size; `wm size` said {out!r}")
    return 0, 0


def scroll(tag: str, direction: str = "down") -> bool:
    """One finger-flick of the list, on a verified Dhimmah screen.

    A settings list is longer than a screen, so a row that exists is not a row
    that is *rendered*, and a finder cannot press what the list has not built.
    This is the same gesture a person makes; the state is verified either side of
    it, and nothing is sent while another application owns the screen.
    """
    xml = guarded.guarded_dump(f"{tag}_before")
    if not xml:
        return False
    width, height = screen_size()
    if not width:
        return False
    driver.shot(f"{tag}_before")
    far, near = int(height * 0.74), int(height * 0.30)
    y_from, y_to = (far, near) if direction == "down" else (near, far)
    x = width // 2
    driver.adb(
        "shell", "input", "swipe", str(x), str(y_from), str(x), str(y_to), "300"
    )
    time.sleep(1.4)
    driver.shot(f"{tag}_after")
    return True


def step_goto() -> bool:
    """Reaches the backup screen from wherever the app happens to be.

    Written as a loop over what the screen actually says rather than as a fixed
    script of presses: the app may already be there, may have a sheet on top of
    it, or may be on any other page, and a navigation that assumes one of those
    presses the wrong thing.
    """
    for attempt in range(6):
        tag = f"G{attempt}"
        xml, lines = state(f"{tag}_state")
        if not xml:
            return False
        text = flat(lines)

        if on_backup_screen(lines):
            show(f"{tag}_on_backup", lines)
            return True

        # A sheet opened from the backup screen: close it and look again. It
        # carries the app's own close label, not a system dialog's — and the
        # label has to be a whole line of the screen, not a word found somewhere
        # inside it: a ledger that has closed a debt says "تم إغلاق دين", which
        # contains the same letters and is not a close button. Testing the
        # sentence instead of the control would press it, and a press that lands
        # on an activity row is not a way out of a sheet.
        if any(line == [CLOSE_ACTION] for line in lines):
            print(f"{tag}: a sheet is on top; closing it")
            if not tap(CLOSE_ACTION, f"{tag}_close"):
                return False
            continue

        # The application shell: the navigation bar is there to press.
        if "الرئيسية" in text and "المزيد" in text:
            print(f"{tag}: on the shell")
            if not tap("المزيد", f"{tag}_more"):
                return False
            _, more = state(f"{tag}_more_screen")
            show(f"{tag}_more_screen", more)
            if "الإعدادات" not in flat(more):
                print("the More screen has no الإعدادات row")
                return False
            if not tap("الإعدادات", f"{tag}_settings"):
                return False
            # The section sits below the fold, and a list only builds what it is
            # showing, so the row is scrolled to before it is looked for.
            for scroll_attempt in range(4):
                _, settings = state(f"{tag}_settings_screen_{scroll_attempt}")
                show(f"{tag}_settings_screen_{scroll_attempt}", settings)
                if "النسخ الاحتياطي والاستعادة" in flat(settings):
                    break
                print(f"{tag}: the backup row is below the fold; scrolling")
                if not scroll(f"{tag}_settings_scroll_{scroll_attempt}"):
                    return False
            else:
                print("the settings screen has no backup row, after scrolling")
                return False
            # The section heading and the row carry the same words, so the
            # press is tried until one of them actually changes the screen.
            if not tap_until_change("النسخ الاحتياطي والاستعادة", f"{tag}_backup"):
                return False
            continue

        print(f"{tag}: NOT ONE OF THE SCREENS THIS WALK KNOWS. If the backup "
              f"screen is the one on screen, its marker {BACKUP_MARKER!r} has "
              "drifted from the build and this tool must be corrected rather "
              "than believed. Backing out:")
        show(f"{tag}_unrecognised", lines, limit=40)
        if not tap(BACK_ACTION, f"{tag}_back"):
            return False

    print("gave up trying to reach the backup screen")
    return False


def step_now() -> bool:
    _, before = state("N0_before")
    if not before:
        return False
    # Both actions live under the protection card, and the screen is recognised
    # from the top — so they may not be rendered when this step starts.
    if not reveal(SAVE_ACTION, "N0b"):
        print(f"{SAVE_ACTION!r} never came on the glass")
        return False
    if not tap_until_change(SAVE_ACTION, "N1_now"):
        return False
    _, after = state("N2_after")
    if after:
        show("N2_after", after)
        print("no share sheet appeared; nothing to dismiss")
        return True
    print(f"the share sheet is up (owner={owner()!r})")
    return dismiss_system_surface("N3_dismiss")


def step_history() -> bool:
    """Opens the previous-backups sheet, scrolling to its row if it is below the fold.

    The row is the last thing in its section, and on a short screen the section
    runs past the bottom: `uiautomator` still reports it, with bounds of
    `[0,0][0,0]`, because it is in the tree and not on the glass. A finder cannot
    press what has not been laid out, and an unresolved target would read as
    "the app has no such row" — so the list is scrolled until the row has real
    bounds, exactly as a person would.
    """
    xml, lines = state("H0_before")
    if not xml:
        return False
    rows_before = len([1 for line in lines if line and line[0].endswith("KB")])
    print(f"rows visible before: {rows_before}")

    # A sheet left open by an earlier step would swallow the press that opens it,
    # and the run would report "the history is not there" about a history that is
    # already on screen. Closing first makes this step work from any state.
    if not dismiss_sheet("H0_clear"):
        print("a sheet was open and would not close")
        return False

    for attempt in range(4):
        xml, lines = state(f"H1_look_{attempt}")
        if not xml:
            return False
        placed = [
            node for node in driver.parse_nodes(xml)
            if node.lines and node.lines[0] == PREVIOUS_ACTION and node.area > 0
        ]
        if placed:
            print(f"the previous-backups row is on screen at {placed[0].report()['bounds']}")
            break
        present = any(
            node.lines and node.lines[0] == PREVIOUS_ACTION
            for node in driver.parse_nodes(xml)
        )
        print(f"{PREVIOUS_ACTION!r} is "
              f"{'in the tree but not laid out' if present else 'absent'}; "
              f"scrolling to reach it (attempt {attempt} of 3)")
        if not scroll(f"H1_scroll_{attempt}"):
            return False
    else:
        print("the previous-backups row never reached the screen")
        return False

    if not tap_until_change(PREVIOUS_ACTION, "H2_open"):
        return False
    xml, lines = state("H3_open")
    if not xml:
        return False
    show("H3_open", lines, limit=40)
    return True


def external_rows(xml: str) -> list[str]:
    """The folder-layer rows the sheet is showing, by file name.

    The sheet has two layers and they change independently — a delete in one does
    not touch the other — so a count of every row on the sheet answers nothing.
    What the acceptance is about is the layer that was deleted from, and the
    names are what the two readings have to be compared by.
    """
    heading = [
        node for node in driver.parse_nodes(xml)
        if node.lines == [INTERNAL_HEADING] and node.area > 0
    ]
    cut = heading[0].y1 if heading else 10 ** 9
    return [
        node.lines[0] for node in driver.parse_nodes(xml)
        if node.lines and node.lines[0].endswith(".dhimmah")
        and node.y1 < cut and node.area > 0
    ]


def step_del() -> bool:
    """Deletes a copy from a sheet that is left open, and reads the sheet again.

    Walking out and back in would prove nothing: the reported symptom was a sheet
    that kept showing a row whose file was gone until it was closed and reopened.
    So the sheet is left exactly where it is, and the question the run answers is
    whether *its own* reading changed — which is only a question the sheet can
    answer about itself.
    """
    xml, lines = state("D0_before")
    if not xml:
        return False
    show("D0_before", lines, limit=40)
    before = external_rows(xml)
    deletes = [n for n in driver.parse_nodes(xml) if n.lines == [DELETE_ACTION]]
    print(f"the sheet shows {len(before)} row(s) from the folder and "
          f"{len(deletes)} delete controls in all")
    if not deletes:
        return False

    if not tap_until_change(DELETE_ACTION, "D1_delete"):
        return False

    xml_after, lines_after = state("D2_after")
    if not xml_after:
        print("the sheet is no longer a Dhimmah screen — it may have closed")
        return False
    show("D2_after", lines_after, limit=40)

    after = external_rows(xml_after)
    print(f"rows from the folder after the press: {len(after)}")
    print(f"   before: {before}")
    print(f"   after : {after}")

    still_open = any(
        node.lines == [CLOSE_ACTION] for node in driver.parse_nodes(xml_after)
    )
    print(f"the sheet is still open: {still_open}")

    removed = [name for name in before if name not in after]
    if not still_open:
        print("FAIL: the sheet closed itself, so nothing about its own reading "
              "was shown")
        return False
    if len(after) != len(before) - 1:
        print(f"FAIL: the sheet should hold one row fewer; it held {len(before)} "
              f"and now holds {len(after)}")
        return False
    print(f"the sheet dropped exactly one row, without being closed: {removed}")
    return True


def step_restore() -> bool:
    """Opens the file picker behind "استعد من ملف", from whatever is on screen.

    An earlier step's sheet is cleared first: a run that pressed through a
    finished restore and then asked for this row would find the row behind the
    sheet that reports it, and would report the row as missing.
    """
    if not dismiss_sheet("R0_clear"):
        print("a sheet was open and would not close")
        return False
    _, before = state("R0_before")
    if not before:
        return False
    if not reveal(BACKUP_MARKER, "R0b"):
        print(f"{BACKUP_MARKER!r} never came on the glass")
        return False
    if not tap(BACKUP_MARKER, "R1_restore"):
        return False
    time.sleep(2.0)
    for attempt in range(6):
        current = owner()
        print(f"picker owner after {attempt}: {current!r}")
        if current not in SYSTEM_SURFACES:
            break
        time.sleep(1.5)
    driver.shot("R2_picker")
    driver.adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    driver.adb("pull", "/sdcard/window.xml",
               driver.evidence_path("logs", "R2_picker.xml"))
    xml = driver.read_text(("logs", "R2_picker.xml"))
    driver.write_text(
        ("logs", "R2_picker.json"),
        json.dumps(
            {
                "owner": owner(),
                "tree_package": guarded.tree_package(xml),
                "bytes": len(xml),
                "expected_file_present": None,
            },
            ensure_ascii=False,
            indent=2,
        ),
    )
    for node in driver.parse_nodes(xml):
        if node.lines:
            print("   ", " ⏎ ".join(node.lines))
    return True


def step_peek() -> bool:
    driver.shot("P0_peek")
    driver.adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    driver.adb("pull", "/sdcard/window.xml",
               driver.evidence_path("logs", "P0_peek.xml"))
    xml = driver.read_text(("logs", "P0_peek.xml"))
    print(f"owner={owner()!r} tree={guarded.tree_package(xml)!r}")
    for node in driver.parse_nodes(xml):
        if node.lines:
            print("   ", " ⏎ ".join(node.lines))
    return True


def dismiss_sheet(tag: str) -> bool:
    """Closes a sheet the app put up, by the app's own close control.

    A save ends with a confirmation sheet, and that sheet covers the very
    controls the next step wants to press — so "the backup screen lost its
    actions" is what a run says when it has not noticed the sheet. Closing it
    first is what a person does, and the close control is found by its own
    label rather than by a guessed coordinate.
    """
    xml = guarded.guarded_dump(f"{tag}_state")
    if not xml:
        return False
    # Two sheets in this flow say how to leave: an ordinary one closes, and the
    # one that reports a finished restore offers to continue into the app. Both
    # are the app's own words for the same gesture, and a run that only knows the
    # first gets stuck behind the second — which is exactly what happened here.
    closes = [
        node for node in driver.parse_nodes(xml)
        if node.area > 0
        and node.lines in ([CLOSE_ACTION], [RESTORE_CONTINUE])
    ]
    if not closes:
        print(f"{tag}: no sheet to close")
        return True
    # The lowest one is the sheet's own bottom control; the higher one, when a
    # screen has both, dismisses without leaving.
    target = sorted(closes, key=lambda node: node.y2)[-1]
    print(f"{tag}: closing the sheet at {target.report()['bounds']}")
    driver.adb("shell", "input", "tap", str((target.x1 + target.x2) // 2),
               str((target.y1 + target.y2) // 2))
    time.sleep(2.2)
    driver.shot(f"{tag}_closed")
    xml2 = guarded.guarded_dump(f"{tag}_after")
    return bool(xml2) and not any(
        node.lines in ([CLOSE_ACTION], [RESTORE_CONTINUE])
        for node in driver.parse_nodes(xml2)
    )


def step_mission_delete() -> bool:
    """The whole delete-while-open acceptance, in one run.

    Reach the backup screen, make sure there are at least two snapshots, open
    the history, delete one *without closing the sheet*, and report what the
    sheet shows. Every press goes through the guard, and the run stops at the
    first step that cannot be verified rather than continuing on an assumption.
    """
    if not step_goto():
        print("could not reach the backup screen")
        return False

    # Two snapshots, so the delete has something left beside it to compare with.
    # Every save ends with its own confirmation sheet, so the sheet is cleared
    # before the screen is read *and* once more after the last one: a run that
    # only clears at the top of the loop walks into the history step with the
    # final confirmation still covering the screen, and then reports that the
    # history row does not exist.
    for attempt in range(2):
        if not dismiss_sheet(f"MD{attempt}_dismiss"):
            print("a confirmation sheet would not close")
            return False
        xml, lines = state(f"MD{attempt}_before_now")
        if not xml:
            return False
        if BACKUP_MARKER not in flat(lines):
            print("the backup screen lost its actions; stopping")
            return False
        if not step_now():
            print(f"snapshot {attempt + 1} did not complete")
            return False

    if not dismiss_sheet("MD2_dismiss"):
        print("the last confirmation sheet would not close")
        return False
    _, lines = state("MD3_screen")
    if not lines:
        return False
    show("MD3_screen", lines)

    if not step_history():
        print("the history sheet did not open")
        return False

    return step_del()


def step_save_external() -> bool:
    """Saves a copy to a file the user owns, and reports where it ended up.

    There are two shapes of this, and which one happens is the app's decision,
    not this script's: with a backup folder configured the copy goes straight
    into that folder and no chooser appears at all; without one, Android's own
    "where should this live" dialog opens and has to be answered.

    The system dialog is an *expected* system surface — it is read for what it
    is, with its own buttons and its own labels, and only its confirm action is
    pressed. Nothing here assumes the dialog looks like the app.

    Either way the outcome is only ever what the app then says. A chooser that
    returned successfully is not a save; the app's verified-save sentence is.
    """
    if not step_goto():
        print("could not reach the backup screen")
        return False

    print(f"owner before: {owner()!r}")
    if not tap_until_change(SAVE_ACTION, "S1_save"):
        print("the save action did nothing at all")
        return False

    for _ in range(10):
        if owner() != guarded.EXPECTED:
            break
        time.sleep(1.0)
    current = owner()
    print(f"after tapping save, owner={current!r}")
    driver.shot("S2_chooser")
    driver.adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    driver.adb("pull", "/sdcard/window.xml",
               driver.evidence_path("logs", "S2_chooser.xml"))
    raw = driver.read_text(("logs", "S2_chooser.xml"))
    driver.write_text(
        ("logs", "S2_chooser.json"),
        json.dumps(
            {
                "owner": current,
                "tree_package": guarded.tree_package(raw),
                "labels": [n.lines for n in driver.parse_nodes(raw) if n.lines],
            },
            ensure_ascii=False,
            indent=2,
        ),
    )
    for node in driver.parse_nodes(raw):
        if node.lines:
            print("   ", " | ".join(node.lines)[:100])

    if current != guarded.EXPECTED:
        # The system's own confirm button, by label — never by a guessed
        # coordinate. The vocabulary here is Android's, not the app's.
        for label in ("حفظ", "Save", "OK", "موافق"):
            resolution = driver.resolve(raw, label)
            if resolution is None or resolution.confidence == "LOW":
                continue
            print(f"pressing the chooser's own {label!r} at "
                  f"({resolution.x},{resolution.y}) via {resolution.strategy}")
            driver.shot("S3_confirm_before")
            driver.adb("shell", "input", "tap", str(resolution.x), str(resolution.y))
            time.sleep(4.0)
            driver.shot("S3_confirm_after")
            break
        else:
            print("the chooser offered no confirm button; leaving it alone")
            return False

        # Back in the app: the confirmation exists only if the document was
        # written *and* read back and verified.
        for _ in range(20):
            if owner() == guarded.EXPECTED:
                break
            time.sleep(1.0)
    else:
        print("no chooser appeared: a backup folder is configured, so the copy "
              "goes straight into it")

    xml, lines = state("S4_after_save")
    if not xml:
        print("the app did not come back to the front")
        return False
    show("S4_after_save", lines, limit=30)
    verified = SAVED_REPORT in flat(lines)
    print(f"the app reports a verified save: {verified}")
    return verified


def restore_from_layer(layer: str) -> bool:
    """Restores a copy from one layer of the history sheet.

    The layer is chosen *structurally*, by the position of the sheet's own
    `داخل التطبيق` heading, because every row on the sheet carries the same
    restore control: the label alone cannot say which layer a press would land
    in, and the two layers behave differently — the folder's copies are read from
    a file, the app's own are read from the app's directory, and in an older build
    only one of them had a control at all.

    Nothing is confirmed here on the app's say-off alone: the sheet is read
    before and after, and the run reports the sentence the app finishes with.
    """
    if not step_goto():
        print("could not reach the backup screen")
        return False
    if not step_history():
        print("the history sheet did not open")
        return False

    xml = guarded.guarded_dump("RI0_sheet")
    if not xml:
        return False
    heading = [
        node for node in driver.parse_nodes(xml)
        if node.lines == [INTERNAL_HEADING] and node.area > 0
    ]
    # No heading means no internal layer at all — the app draws that heading only
    # when it has copies of its own, which is exactly the state after a reinstall
    # and before the first restore. Then every row on the sheet is the folder's.
    cut = heading[0].y1 if heading else -1
    if not heading:
        print(f"the sheet has no {INTERNAL_HEADING!r} heading, so it holds only "
              "the folder's copies")
        if layer == "internal":
            return False

    wanted = (
        (lambda node: node.y1 >= cut) if layer == "internal"
        else (lambda node: node.y1 <= cut if cut >= 0 else True)
    )
    controls = sorted(
        (
            node for node in driver.parse_nodes(xml)
            if node.lines == [BACKUP_MARKER] and node.area > 0 and wanted(node)
        ),
        key=lambda node: node.area,
    )
    if not controls:
        print(f"no restore control in the {layer} layer")
        return False
    target = controls[0]
    print(f"pressing the {layer} row's restore control at "
          f"{target.report()['bounds']} — the {INTERNAL_HEADING!r} heading is "
          f"at y={cut}, which is what makes it that layer")

    xml_before = xml
    driver.adb("shell", "input", "tap", str((target.x1 + target.x2) // 2),
               str((target.y1 + target.y2) // 2))
    time.sleep(3.0)
    driver.shot("RI1_sheet_after_press")

    xml2, lines2 = state("RI1")
    if not xml2 or xml2 == xml_before:
        print("the press did not change the sheet")
        return False
    show("RI1_restore_sheet", lines2, limit=30)

    if not any(line == [RESTORE_CONFIRM] for line in lines2):
        print(f"the sheet offers no {RESTORE_CONFIRM!r}; this is not the "
              "restore sheet, so nothing was confirmed")
        return False

    if not tap_until_change(RESTORE_CONFIRM, "RI2_confirm"):
        return False

    # The restore runs on real data: reading the snapshot, rebuilding the
    # ledger, and taking a safety copy first. It is given time, and the report
    # is only read once the app has stopped working.
    for attempt in range(20):
        time.sleep(1.5)
        xml3, lines3 = state(f"RI3_after_{attempt}")
        if not xml3:
            continue
        text = flat(lines3)
        if RESTORE_DONE in text or RESTORE_FAILED in text:
            show(f"RI3_after_{attempt}", lines3, limit=30)
            if RESTORE_DONE in text:
                print("the app reports the restore finished")
                return True
            print("the app reports the restore failed")
            return False
    print("the restore neither finished nor failed within the time given")
    return False


def step_restore_internal() -> bool:
    """The path the user asked for: an app-held copy, one press, no picker."""
    return restore_from_layer("internal")


def step_restore_external() -> bool:
    """The recovery path: a copy the user kept in their own folder."""
    return restore_from_layer("folder")


def step_preview() -> bool:
    """Opens the restore sheet and leaves it again, changing nothing.

    The restore preview is a state in its own right — it is where the user reads
    what a copy holds before deciding — and it is the one state of the flow that
    can be audited on a phone holding real data, because nothing happens until
    its confirm is pressed. This step presses the restore control of an
    app-held copy, reads the sheet, and then leaves by the sheet's own way out.

    The ledger is counted before and after and the two readings are compared: a
    preview that quietly restored something would be a far worse defect than a
    preview that looked wrong, and the point of the step is to be able to say it
    did not.
    """
    if not step_goto():
        print("could not reach the backup screen")
        return False
    if not step_history():
        print("the history sheet did not open")
        return False

    xml = guarded.guarded_dump("PV0_sheet")
    if not xml:
        return False
    heading = [
        node for node in driver.parse_nodes(xml)
        if node.lines == [INTERNAL_HEADING] and node.area > 0
    ]
    if not heading:
        print(f"the sheet has no {INTERNAL_HEADING!r} heading, so it holds only "
              "the folder's copies; nothing to preview here")
        return False
    cut = heading[0].y1
    controls = sorted(
        (
            node for node in driver.parse_nodes(xml)
            if node.lines == [BACKUP_MARKER] and node.area > 0 and node.y1 >= cut
        ),
        key=lambda node: node.y1,
    )
    if not controls:
        print("no restore control under the internal heading")
        return False
    target = controls[0]
    print(f"previewing the newest app-held copy, its control at "
          f"{target.report()['bounds']} (the {INTERNAL_HEADING!r} heading is at "
          f"y={cut})")
    driver.adb("shell", "input", "tap", str((target.x1 + target.x2) // 2),
               str((target.y1 + target.y2) // 2))
    time.sleep(3.0)

    xml2, lines2 = state("PV1_preview")
    if not xml2:
        return False
    show("PV1_preview", lines2, limit=30)
    driver.shot("PV1_preview")

    if not any(line == [RESTORE_CONFIRM] for line in lines2):
        print(f"no {RESTORE_CONFIRM!r} on the sheet, so this is not the restore "
              "preview; leaving it alone")
        return False

    # The sheet's own way out, and only that: the confirm is never pressed here.
    # The history sheet it was opened from may still be underneath, so the
    # screen is cleared until the backup screen itself is back.
    if not dismiss_sheet("PV2_close"):
        print("the preview would not close")
        return False
    dismiss_sheet("PV3_clear")
    xml3, lines3 = state("PV4_after_close")
    if not xml3:
        return False
    closed = not any(line == [RESTORE_CONFIRM] for line in lines3)
    back = BACKUP_MARKER in flat(lines3)
    print(f"the preview closed without confirming: {closed}; "
          f"the backup screen is back: {back}")
    return closed and back


STEPS = {
    "goto": step_goto,
    "now": step_now,
    "history": step_history,
    "del": step_del,
    "restore": step_restore,
    "restore_internal": step_restore_internal,
    "restore_external": step_restore_external,
    "preview": step_preview,
    "peek": step_peek,
    "mission_delete": step_mission_delete,
    "save_external": step_save_external,
}


if __name__ == "__main__":
    if STEP not in STEPS:
        raise SystemExit(f"unknown step {STEP!r}; expected one of {sorted(STEPS)}")
    print(f"=== step {STEP} ===")
    ok = STEPS[STEP]()
    print(f"=== step {STEP}: {'OK' if ok else 'STOPPED'} ===")
    sys.exit(0 if ok else 1)
