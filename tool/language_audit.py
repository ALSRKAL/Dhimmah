"""Puts the app into another language, audits the backup screen in it, and reports.

The acceptance asks for the screen in both directions on a real device: Arabic
from the right, English from the left. Both are the app's own states, reached
through the app's own controls — the Settings screen's Language row, and then one
of the two options it offers. Nothing here writes to the app's files and no locale
is forced on the process: the row is pressed, the app saves the setting, and the
app draws itself again.

    python3 tool/language_audit.py <serial> <ar|en>

`en` switches to English and audits the English screen; `ar` switches back and
audits the Arabic one. Two runs rather than one long one, because each direction
is then verified on its own: a run that switches and switches back can only prove
the state it ends in, and a tool that leaves the user's app in another language
has caused the defect it was sent to look for.
"""

import importlib.util
import json
import re
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.0.3:5555"
WANT = sys.argv[2] if len(sys.argv) > 2 else "en"
if WANT not in ("ar", "en"):
    raise SystemExit("the language must be 'ar' or 'en'")

sys.argv = ["audit", SERIAL, WANT]

_spec = importlib.util.spec_from_file_location("guarded", "tool/guarded_ui.py")
guarded = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guarded)
driver = guarded.driver

_spec2 = importlib.util.spec_from_file_location("session", "tool/backup_device_session.py")
session = importlib.util.module_from_spec(_spec2)
_spec2.loader.exec_module(session)


def label(name: str, language: str = "ar") -> str:
    """The build's own word for [name], read from the generated strings.

    Read rather than typed: a renamed label then breaks the run loudly instead of
    leaving it to press at nothing. Note that the *option* labels are the current
    language's words — an Arabic screen offers `الإنجليزية`, not `English`.
    """
    path = f"lib/l10n/generated/app_localizations_{language}.dart"
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    match = re.search(rf"String get {name} =>\s*'([^']+)'", text)
    if not match:
        raise SystemExit(f"{path} has no {name!r}")
    return match.group(1)


KEYS = (
    "settingsLanguage",
    "settingsTitle",
    "settingsNotifications",
    "settingsDangerZone",
    "settingsBackup",
    "navMore",
    "navSettings",
    "languageArabic",
    "languageEnglish",
    "backupRestoreAction",
    "backupProtectionDetails",
    "backupProtectionHideDetails",
    "backupProtectionProtected",
)
#: What each language calls the things this walk has to find.
LABELS = {
    language: {key: label(key, language) for key in KEYS} for language in ("ar", "en")
}

#: The language the app is expected to be in when the run starts: the one the
#: previous run did *not* leave it in.
OTHER = "ar" if WANT == "en" else "en"


def lines_of(tag: str) -> list[list[str]]:
    xml = guarded.guarded_dump(tag)
    if not xml:
        return []
    return [node.lines for node in driver.parse_nodes(xml) if node.lines]


def flat(lines: list[list[str]]) -> str:
    return " ".join(line for entry in lines for line in entry)


def show(tag: str, lines: list[list[str]], limit: int = 30) -> None:
    print(f"--- {tag} ---")
    for entry in lines[:limit]:
        print("   ", " ⏎ ".join(entry)[:110])


def detect(lines: list[list[str]]) -> str | None:
    """Which language the screen is in, by counting the words each one uses.

    Asked of the *screen* rather than of the app's settings file: the run is about
    what the user can see, and a reading that disagreed with the glass would be
    the defect this whole exercise exists to catch.

    Every label counts, not just the ones that name this flow: the app opens on
    the dashboard, which says none of the backup screen's words, and an earlier
    version quietly fell back to "the other language" there and then hunted for
    Arabic words on an English screen. Ties and total misses answer None, which
    the caller treats as "not known yet" rather than as a guess.
    """
    text = flat(lines)
    hits = {
        language: sum(1 for key in KEYS if LABELS[language][key] in text)
        for language in ("ar", "en")
    }
    if hits["ar"] == hits["en"]:
        return None
    return "ar" if hits["ar"] > hits["en"] else "en"


def press(target: str, tag: str, line_index: int | None = None) -> bool:
    """Presses a control, with the app's ownership of the screen verified either side."""
    xml = guarded.guarded_dump(f"{tag}_before")
    if not xml:
        return False
    for node in driver.parse_nodes(xml):
        if target in node.lines and node.area > 0:
            if line_index is not None and len(node.lines) > line_index:
                share = (line_index + 0.5) / len(node.lines)
                y = node.y1 + int((node.y2 - node.y1) * share)
            else:
                y = (node.y1 + node.y2) // 2
            x = (node.x1 + node.x2) // 2
            driver.shot(f"{tag}_before")
            print(f"pressing {target!r} at ({x},{y})")
            driver.adb("shell", "input", "tap", str(x), str(y))
            time.sleep(2.4)
            driver.shot(f"{tag}_after")
            return True
    print(f"{target!r} is not on the glass")
    return False


def scroll_to(target: str, tag: str, attempts: int = 5, direction: str = "down") -> bool:
    """Brings [target] onto the glass, scrolling as a person would.

    The direction matters: the settings list is longer than the phone and the app
    reopens it where it was left, so the Language row can be above the top of the
    glass — and a walk that only knows how to scroll down reads that as "the app
    has no such row", which is what the first attempt at this did.
    """
    for attempt in range(attempts):
        xml = guarded.guarded_dump(f"{tag}_look{attempt}")
        if not xml:
            return False
        for node in driver.parse_nodes(xml):
            if target in node.lines and node.area > 0:
                return True
        print(f"{target!r} is not rendered yet; scrolling {direction}")
        if not session.scroll(f"{tag}_scroll{attempt}", direction):
            return False
    return False


def on_backup_screen(who: str, lines: list[list[str]]) -> bool:
    text = flat(lines)
    return (
        LABELS[who]["backupRestoreAction"] in text
        or LABELS[who]["backupProtectionDetails"] in text
        or LABELS[who]["backupProtectionHideDetails"] in text
    )


def close_any_sheet(lines: list[list[str]], tag: str) -> bool:
    if any(line == [session.CLOSE_ACTION] for line in lines) or \
            any(line == [session.RESTORE_CONTINUE] for line in lines):
        print(f"{tag}: a sheet is on top; closing it")
        return press(session.CLOSE_ACTION, f"{tag}_close")
    return False


def on_settings_screen(who: str, lines: list[list[str]]) -> bool:
    """Whether the settings list is on screen — and not the More tab, which
    carries the same word as one of its rows.

    The section titles settle it: `Notifications` and the danger zone belong to
    this screen alone, and the More tab has neither.
    """
    text = flat(lines)
    return LABELS[who]["settingsTitle"] in text and (
        LABELS[who]["settingsNotifications"] in text
        or LABELS[who]["settingsDangerZone"] in text
        or LABELS[who]["settingsLanguage"] in text
    )


def reach_settings(who: str, tag: str) -> bool:
    """Walks to the settings list, in the language that is on screen.

    From the shell, the way there is the More tab and then the Settings row on
    it — the same two presses a person makes, found by the words that screen
    uses in this language rather than by remembered coordinates.
    """
    for attempt in range(6):
        step = f"{tag}{attempt}"
        lines = lines_of(step)
        if not lines:
            time.sleep(1.5)
            continue
        show(step, lines)
        if on_settings_screen(who, lines):
            print(f"on the settings list, in {who}")
            return True
        if close_any_sheet(lines, step):
            continue
        if on_backup_screen(who, lines):
            # Flutter draws the back control and names it in the framework's own
            # word for the language, which is not in the app's strings file.
            back = "رجوع" if who == "ar" else "Back"
            if not press(back, f"{step}_back"):
                return False
            continue
        if LABELS[who]["navMore"] in flat(lines):
            print(f"{step}: on the shell; going through More")
            if not press(LABELS[who]["navMore"], f"{step}_more"):
                return False
            more = lines_of(f"{step}_more_screen")
            show(f"{step}_more_screen", more)
            if not any(LABELS[who]["navSettings"] in entry
                       for line in more for entry in line):
                print(f"the More screen has no {LABELS[who]['navSettings']!r} row")
                return False
            if not press(LABELS[who]["navSettings"], f"{step}_settings"):
                return False
            continue
        print(f"{step}: not a screen this walk knows in {who}; stopping rather "
              f"than guessing. It says: {flat(lines)[:160]!r}")
        return False
    print("could not reach the settings list")
    return False


def switch_language(who: str, tag: str) -> bool:
    """Presses the Language row, then the wanted option in the sheet it opens."""
    # The list reopens where it was left, so the row can be above the glass.
    if not (scroll_to(LABELS[who]["settingsLanguage"], f"{tag}_find")
            or scroll_to(LABELS[who]["settingsLanguage"], f"{tag}_findup",
                         direction="up")):
        print("the Language row never came up")
        return False
    if not press(LABELS[who]["settingsLanguage"], f"{tag}_row"):
        return False
    time.sleep(1.5)
    sheet = lines_of(f"{tag}_sheet")
    show(f"{tag}_sheet", sheet)
    option = LABELS[who]["languageEnglish" if WANT == "en" else "languageArabic"]
    if not any(option in entry for line in sheet for entry in line):
        print(f"the sheet offers no {option!r}")
        return False
    if not press(option, f"{tag}_option"):
        return False
    time.sleep(2.5)
    return True


def reach_backup_screen(who: str, tag: str) -> bool:
    """Walks from the settings list to the backup screen, in [who]'s language."""
    for attempt in range(5):
        step = f"{tag}{attempt}"
        lines = lines_of(step)
        if not lines:
            time.sleep(1.5)
            continue
        show(step, lines)
        if on_backup_screen(who, lines):
            print(f"on the backup screen, in {who}")
            return True
        if close_any_sheet(lines, step):
            continue
        if not on_settings_screen(who, lines):
            print(f"{step}: not on the settings list either; stopping")
            return False
        if not scroll_to(LABELS[who]["settingsBackup"], f"{step}_row"):
            print(f"the {LABELS[who]['settingsBackup']!r} row never came up")
            return False
        # The section heading carries the same words as the row under it, so the
        # press is aimed at the row's own line of the merged label.
        if not press(LABELS[who]["settingsBackup"], f"{step}_open", line_index=1):
            return False
    print("could not reach the backup screen")
    return False


def main() -> None:
    print(f"=== language audit: asking for {WANT} ===")
    start = lines_of("A0_start")
    show("A0_start", start)
    who = detect(start)
    if who is None:
        # The app opens on the dashboard, which may carry none of these words —
        # a blank start screen, for instance. Looking again is honest; guessing
        # is not, so the run reads the screen once more before deciding.
        time.sleep(2.0)
        start = lines_of("A0b_start")
        show("A0b_start", start)
        who = detect(start)
    if who is None:
        print("the screen's language could not be read; stopping rather than "
              "pressing at words in the wrong language")
        raise SystemExit(1)
    print(f"the screen reads as {who}")
    if who != OTHER:
        print(f"note: the app is in {who}, not {OTHER}")

    if not reach_settings(who, "A1"):
        print("could not reach the settings list")
        raise SystemExit(1)

    if who == WANT:
        print(f"the app is already in {WANT}; nothing to switch")
    elif not switch_language(who, "A2"):
        print("the language was not switched")
        raise SystemExit(1)

    after = lines_of("A3_after_switch")
    show("A3_after_switch", after)
    now = detect(after)
    print(f"the screen now reads as {now}")
    if now != WANT:
        print(f"the app did not switch to {WANT}")
        raise SystemExit(1)

    if not reach_backup_screen(WANT, "A4"):
        print(f"the backup screen was not reached in {WANT}")
        raise SystemExit(1)

    final = lines_of("A5_backup")
    show("A5_backup", final)
    driver.shot(f"A6_backup_{WANT}")
    driver.write_text(
        ("logs", f"LANGUAGE_{WANT}.json"),
        json.dumps({"language": WANT, "screen": final}, ensure_ascii=False, indent=2),
    )

    ok = on_backup_screen(WANT, final) and detect(final) == WANT
    print(f"the backup screen is on the glass in {WANT}: {ok}")
    print(f"the app is left in {WANT}")
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
