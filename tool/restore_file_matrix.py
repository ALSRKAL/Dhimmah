"""What the app says about each kind of file, chosen through Android's picker.

The widget tests already say what the *screen* does with a file that is not a
backup. This script asks the question on a phone instead, because two of the
things involved only exist there: Android's own document picker, and a real
provider handing over real bytes. It is also the only way to see the thing the
user first reported — a picker that appeared empty because the app had asked it
for one file type, and no file matched.

Every step is read from the app's own screen. The picker is a system surface and
is treated as one: it is read for what it is, and only rows inside its list are
pressed.

    python3 tool/restore_file_matrix.py <serial> <file> [<file> ...]

Each file is chosen from the folder the app's own picker opens in, or from
`Documents` if the file is not there; the app's screen is captured immediately
afterwards, because its answer is a message that fades.
"""

import importlib.util
import json
import os
import re
import sys
import time

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.0.4:5555"
FILES = sys.argv[2:] or ["damaged.dhimmah", "not-a-backup.txt"]

sys.argv = ["matrix", SERIAL, "list"]

_picker_spec = importlib.util.spec_from_file_location(
    "folder_picker", "tool/folder_picker.py"
)
picker = importlib.util.module_from_spec(_picker_spec)
_picker_spec.loader.exec_module(picker)

guarded = picker.guarded
driver = picker.driver


def app_screen(tag: str) -> str:
    """The app's own screen, only when the guard agrees it owns the display."""
    xml = guarded.guarded_dump(tag)
    if not xml:
        return ""
    return xml


def app_text(xml: str) -> str:
    return " ".join(
        line for node in driver.parse_nodes(xml) for line in node.lines
    )


def describe(tag: str) -> None:
    xml = picker.snap(tag)
    for node in driver.parse_nodes(xml):
        if node.lines:
            print("   ", " ⏎ ".join(node.lines)[:140])


def open_the_picker(tag: str) -> bool:
    """Presses the app's own restore row, after clearing any sheet."""
    xml = app_screen(f"{tag}_app")
    if not xml:
        print(f"{tag}: the app does not own the screen")
        return False
    marker = picker.label("backupRestoreAction")
    if marker not in app_text(xml):
        print(f"{tag}: the backup screen is not on top")
        describe(f"{tag}_not_backup")
        return False
    resolution = driver.resolve(xml, marker)
    if resolution is None or resolution.confidence == "LOW":
        print(f"{tag}: cannot find {marker!r}")
        return False
    print(f"{tag}: pressing {marker!r} at ({resolution.x},{resolution.y})")
    driver.adb("shell", "input", "tap", str(resolution.x), str(resolution.y))
    for _ in range(10):
        time.sleep(0.8)
        if picker.owner() in picker.PICKER_PACKAGES:
            return True
    print(f"{tag}: no picker appeared")
    return False


def choose(name: str, tag: str) -> bool:
    """Presses one file inside the picker, looking in both folders for it."""
    for folder in ("here", "up"):
        if folder == "up":
            print(f"{tag}: {name!r} is not in this folder; going up one")
            if not picker.act_back():
                return False
        for attempt in range(8):
            xml = picker.snap(f"{tag}_{folder}_{attempt}")
            if picker.owner() not in picker.PICKER_PACKAGES:
                print(f"{tag}: the picker closed")
                return False
            names = [words for words, *_ in picker.boxes(xml, in_list=True)]
            if name in names:
                print(f"{tag}: {name!r} is on screen")
                ok = picker.press(name, f"{tag}_{folder}_press", "row")
                return ok
            below = not names or name > max(names)
            if not picker.scroll_picker(
                f"{tag}_{folder}_scroll", "down" if below else "up"
            ):
                return False
        print(f"{tag}: {name!r} is not in this folder")
    return False


def maybe_label(name: str) -> str:
    """A string the app may have, or nothing.

    Some of the sentences worth looking for are plural methods rather than plain
    getters, so they are not readable this way. A missing one must not stop the
    run: the point of the matrix is to find out what the app said, and a runner
    that dies on its own vocabulary answers nothing.
    """
    try:
        return picker.label(name)
    except SystemExit:
        return ""


def verdict(tag: str) -> str:
    """The app's answer, captured while it is still on the glass.

    The refusal is a message that fades, so the reading happens within a second
    of the picker closing rather than after a comfortable pause.
    """
    sentences = [
        text for text in (
            maybe_label("backupRestoreTitle"),
            maybe_label("backupRestoreInvalid"),
            maybe_label("backupRestoreNotOurs"),
            maybe_label("backupRestoreTooNew"),
            maybe_label("backupRestoreFailed"),
        ) if text
    ]
    for attempt in range(14):
        time.sleep(0.5)
        if picker.owner() != guarded.EXPECTED:
            continue
        xml = guarded.guarded_dump(f"{tag}_v{attempt}")
        if not xml:
            continue
        text = app_text(xml)
        for sentence in sentences:
            if sentence in text:
                return sentence
    return ""


def main() -> None:
    results: list[dict] = []
    for name in FILES:
        print(f"\n########## {name} ##########")
        if not open_the_picker(name):
            results.append({"file": name, "outcome": "the picker did not open"})
            continue
        if not choose(name, name):
            results.append({"file": name, "outcome": "could not be chosen"})
            continue
        answer = verdict(name)
        xml = app_screen(f"{name}_final")
        detail = app_text(xml)
        results.append(
            {
                "file": name,
                "outcome": answer or "(no message captured)",
                "restoreSheetOffered": picker.label("backupRestoreConfirm") in detail,
                "ledgerUntouched": None,
            }
        )
        driver.write_text(
            ("logs", f"MATRIX_{name}.json"),
            json.dumps(results[-1], ensure_ascii=False, indent=2),
        )
        print(f"   -> {results[-1]['outcome']}")
        # Leave the app where the next file's picker can be opened from.
        sheet = app_screen(f"{name}_close")
        if sheet:
            closures = [
                n for n in driver.parse_nodes(sheet)
                if n.area > 0 and n.lines in (
                    [picker.label("actionClose")],
                    [picker.label("backupRestoreContinue")],
                )
            ]
            if closures:
                target = sorted(closures, key=lambda n: n.y2)[-1]
                print(f"   closing the app's sheet at {target.report()['bounds']}")
                driver.adb(
                    "shell", "input", "tap",
                    str((target.x1 + target.x2) // 2),
                    str((target.y1 + target.y2) // 2),
                )
                time.sleep(2.0)
    driver.write_text(
        ("logs", "MATRIX_summary.json"),
        json.dumps(results, ensure_ascii=False, indent=2),
    )
    print("\n=== summary ===")
    for row in results:
        print(f"   {row['file']:34} {row['outcome']}")


if __name__ == "__main__":
    main()
