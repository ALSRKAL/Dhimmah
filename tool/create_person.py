"""Creates one person through the real Dhimmah UI, guarded at every step.

The screen it starts from is the People tab, which offers `شخص جديد`. It opens
the form, finds the text field by the class the platform reports rather than by a
guessed coordinate, types a Latin name (the only script `adb shell input text`
can inject), presses save, and then checks that the name appears in the list.

Nothing here is a Dhimmah change: it drives the application the way a person
would, and every action passes through the guard in `guarded_ui.py` — which
verifies the foreground owner and the hierarchy together before anything is sent.

    python3 tool/create_person.py <serial> <name>
"""

import json
import re
import sys
import time

sys.path.insert(0, "tool")
import importlib.util  # noqa: E402

SERIAL = sys.argv[1] if len(sys.argv) > 1 else "192.168.29.138:36373"
NAME = sys.argv[2] if len(sys.argv) > 2 else "Ahmed"

spec = importlib.util.spec_from_file_location("guard", "tool/guarded_ui.py")
guard = importlib.util.module_from_spec(spec)
sys.argv = ["guard", SERIAL, "where"]
spec.loader.exec_module(guard)
driver = guard.driver

SAVE_LABELS = ("حفظ", "إضافة", "تم", "موافق", "خزن")


def ime_shown() -> bool:
    """Whether the soft keyboard is on screen, from the input method's own report."""
    out = driver.adb("shell", "dumpsys", "input_method").stdout
    match = re.search(r"mInputShown=(\w+)", out)
    return bool(match and match.group(1) == "true")


def editable_nodes(xml: str):
    """The input fields, found by class — the one attribute a form cannot hide."""
    found = []
    for match in re.finditer(r"<node[^>]*/?>", xml):
        node = match.group(0)
        if "EditText" not in node and 'class="android.widget.EditText"' not in node:
            continue
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
        if not bounds:
            continue
        x1, y1, x2, y2 = (int(value) for value in bounds.groups())
        if x2 <= x1 or y2 <= y1:
            continue
        text = re.search(r'text="([^"]*)"', node)
        hint = re.search(r'content-desc="([^"]*)"', node)
        found.append({
            "x": (x1 + x2) // 2, "y": (y1 + y2) // 2,
            "bounds": [x1, y1, x2, y2],
            "text": driver.unescape(text.group(1)) if text else "",
            "desc": driver.unescape(hint.group(1)) if hint else "",
        })
    return found


def guarded_tap_xy(x: int, y: int, why: str, tag: str) -> bool:
    """A tap at a coordinate, but only after the state is verified."""
    xml = guard.guarded_dump(f"{tag}_verify")
    if not xml:
        return False
    driver.shot(f"{tag}_before")
    driver.adb("shell", "input", "tap", str(x), str(y))
    print(f"TAP {why} -> ({x},{y})")
    time.sleep(1.8)
    driver.shot(f"{tag}_after")
    return True


def main() -> None:
    print(f"=== 1. verified People screen? ===")
    state = guard.describe("P1_people")
    if state not in ("people", "home", "other"):
        print(f"stopping: state is {state!r}")
        return

    print("=== 2. open the form ===")
    # An empty People screen offers a full-width شخص جديد tile; once someone
    # exists the same action becomes the إضافة button — which opens the quick-add
    # chooser rather than the form, so the first option on it is the next press.
    # This tool used to stop here, reporting "no form", because it had been
    # written when إضافة went straight to the person form. The screen is read
    # after each press and the walk continues through whatever it finds.
    opened = any(guard.guarded_act(label, "P2_new") for label in ("شخص جديد", "إضافة"))
    if not opened:
        print("neither شخص جديد nor إضافة is on this screen")
        return
    form = guard.guarded_dump("P3_form")
    if not form:
        return
    if not editable_nodes(form):
        chooser = guard.guarded_dump("P3b_chooser")
        if not chooser:
            return
        if any("شخص جديد" in node.lines for node in driver.parse_nodes(chooser)):
            print("the add button opened the quick-add chooser; choosing شخص جديد")
            if not guard.guarded_act("شخص جديد", "P3c_person"):
                return
            form = guard.guarded_dump("P3d_form")
            if not form:
                return
    for node in driver.parse_nodes(form):
        if node.lines:
            print(f"   {node.report()}")

    fields = editable_nodes(form)
    driver.write_text(("logs", "P4_form_fields.json"),
                      json.dumps({"name": NAME, "fields": fields},
                                 ensure_ascii=False, indent=2))
    print(f"=== 3. text fields found: {len(fields)} ===")
    for field in fields:
        print(f"   {field}")

    if not fields:
        print("no text field on this screen — the form may be elsewhere")
        return

    first = fields[0]
    if not guarded_tap_xy(first["x"], first["y"], "name field", "P5_focus"):
        return
    driver.adb("shell", "input", "text", NAME)
    print(f"TYPED {NAME!r} into the first field")
    time.sleep(1.2)
    driver.shot("P6_typed")
    after_typing = guard.guarded_dump("P7_typed")
    print(f"   field now reads: "
          f"{[f['text'] for f in editable_nodes(after_typing)]}")

    print("=== 4. save ===")
    saved = False

    # The keyboard is still up, and it covers the save button: a hierarchy node
    # reports its own bounds without knowing that the IME is drawn over them, so
    # pressing the button's centre would press the keyboard instead. Android's
    # own gesture for this is Back, which the input method consumes before the
    # application ever sees it — and it is only sent once the screen has been
    # verified as Dhimmah's, and only while the IME really is shown.
    if ime_shown():
        print("the keyboard is covering the form; dismissing it with Back")
        guard.guarded_dump("P7b_before_ime_dismiss")
        driver.adb("shell", "input", "keyevent", "KEYCODE_BACK")
        time.sleep(1.5)
        print(f"   keyboard shown now: {ime_shown()}")
        driver.shot("P7c_after_ime_dismiss")

    for label in SAVE_LABELS:
        if guard.guarded_act(label, f"P8_save"):
            saved = True
            print(f"pressed {label!r}")
            break
    if not saved:
        print("no save control found among "
              f"{SAVE_LABELS} — the form is still open")

    print("=== 5. does the person appear? ===")
    listing = guard.describe("P9_after_save")
    xml = driver.read_text(("logs", "P9_after_save.xml"))
    present = NAME.lower() in driver.normalise(xml).lower()
    print(f"{NAME!r} present in the People screen: {present}")
    print(f"state after save: {listing}")


if __name__ == "__main__":
    main()
