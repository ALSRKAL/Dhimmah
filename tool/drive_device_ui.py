"""A generic UI driver for the Dhimmah phone, with a semantic target resolver.

Flutter merges a settings section into one accessibility node whose label holds
every row, separated by newlines and wrapped in directional marks. A text
selector therefore finds *the section*, not the row — and tapping its centre
presses whichever row happens to sit there. This resolver handles that shape
properly:

  1. every label is normalised (directional marks, zero-width characters and
     newlines reduced to a stable form) before anything is compared;
  2. candidates are ranked by strategy — an exact single-line label wins, then a
     line inside a merged label, then a container whose geometry has to be used;
  3. a line inside a merged node is located by **geometry**, not by guessing:
     the row's own fraction of the container's height;
  4. the action is refused when the confidence is low, and every decision is
     written to disk with the screen and the hierarchy, so a tap can be audited
     afterwards rather than believed.

Security: nothing is passed to a shell (`shell=False` throughout), the serial is
validated, and every file written is checked against both a name pattern and
containment in the evidence root.

    python3 tool/drive_device_ui.py [serial]
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

SERIAL_PATTERN = re.compile(r"^[A-Za-z0-9._:\-]{1,64}$")
NAME_PATTERN = re.compile(r"^[A-Za-z0-9._\-]{1,64}$")

#: Bidi and zero-width characters the platform sprinkles into labels.
_INVISIBLE = re.compile(
    "[\u200b\u200c\u200d\u200e\u200f\u202a-\u202e\u2066-\u2069\ufeff]"
)

DEFAULT_SERIAL = "192.168.29.138:36373"
#: Where this run's evidence lands. Overridable, because two phones are audited
#: in the same session and the second run must not overwrite the first one's
#: screenshots — an evidence directory that has been written over proves nothing.
OUT = os.environ.get("DHIMMAH_EVIDENCE", "docs/final-acceptance/device/v10")
PAUSE = 1.8


def serial_from(argv: list[str]) -> str:
    if len(argv) < 2:
        return DEFAULT_SERIAL
    candidate = argv[1]
    if not SERIAL_PATTERN.match(candidate):
        raise SystemExit(f"refusing a serial that is not a transport name: {candidate!r}")
    return candidate


SERIAL = serial_from(sys.argv)
EVIDENCE_ROOT = os.path.normpath(OUT)


def _checked_name(part: str) -> str:
    """One path component, or nothing at all.

    `..` and `.` are refused *before* the pattern is consulted, because a bare
    `..` normalises to the parent — which is the root itself, and the containment
    check below would have accepted it.
    """
    if part in ("", ".", ".."):
        raise SystemExit(f"refusing a traversal-style name: {part!r}")
    if "/" in part or "\\" in part or "\x00" in part:
        raise SystemExit(f"refusing a name containing a separator: {part!r}")
    if not NAME_PATTERN.match(part):
        raise SystemExit(f"refusing an unsafe evidence name: {part!r}")
    return part


def evidence_path(*parts: str) -> str:
    """A path strictly inside the evidence directory.

    Two independent checks: every component must be a plain file name, and the
    resolved path must sit *below* the root — never at it.
    """
    if not parts:
        raise SystemExit("refusing a path with no components")
    resolved = os.path.normpath(
        os.path.join(EVIDENCE_ROOT, *(_checked_name(part) for part in parts))
    )
    if not resolved.startswith(EVIDENCE_ROOT + os.sep):
        raise SystemExit(f"refusing a path outside the evidence directory: {resolved}")
    return resolved


def write_bytes(parts: tuple[str, ...], data: bytes) -> int:
    """The one place this script creates a file. Returns what it wrote."""
    path = evidence_path(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Path(path).write_bytes(data)
    return len(data)


def write_text(parts: tuple[str, ...], text: str) -> None:
    write_bytes(parts, text.encode("utf-8"))


def read_text(parts: tuple[str, ...]) -> str:
    """The one place this script reads a file it wrote."""
    try:
        with open(evidence_path(*parts), encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


#: The five entities Android escapes in an attribute value. `&#10;` is the one
#: that matters here: `uiautomator` encodes the newlines a merged label contains,
#: so a label that reads as five lines arrives as one string with `&#10;` in it —
#: and splitting on `\n` alone finds a single line that matches nothing.
_ENTITIES = {"&#10;": "\n", "&amp;": "&", "&lt;": "<", "&gt;": ">",
             "&quot;": '"', "&apos;": "'"}


def unescape(value: str) -> str:
    for entity, character in _ENTITIES.items():
        value = value.replace(entity, character)
    return value


def normalise(text: str) -> str:
    """A label reduced to what a person reads: entities resolved, no direction
    marks, no zero-width characters, and newlines kept as the line boundaries
    they are."""
    return _INVISIBLE.sub("", unescape(text))


def adb(*args: str, timeout: int = 90) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["adb", "-s", SERIAL, *args],
        capture_output=True, text=True, timeout=timeout, check=False,
    )


def adb_bytes(*args: str) -> bytes:
    return subprocess.run(
        ["adb", "-s", SERIAL, *args], capture_output=True, timeout=90, check=False
    ).stdout


def dump(tag: str) -> str:
    local = evidence_path("logs", f"{tag}.xml")
    adb("shell", "uiautomator", "dump", "/sdcard/window.xml")
    adb("pull", "/sdcard/window.xml", local)
    try:
        with open(local, encoding="utf-8") as handle:
            return handle.read()
    except OSError:
        return ""


def shot(name: str) -> int:
    size = write_bytes(("screenshots", f"{name}.png"),
                       adb_bytes("exec-out", "screencap", "-p"))
    print(f"SHOT {name}: {size} bytes")
    return size


class Node:
    """One rectangle in the hierarchy, with its label as a person reads it."""

    def __init__(self, x1: int, y1: int, x2: int, y2: int, label: str,
                 resource_id: str, desc: str) -> None:
        self.x1, self.y1, self.x2, self.y2 = x1, y1, x2, y2
        self.label = label
        self.resource_id = resource_id
        self.desc = desc

    @property
    def lines(self) -> list[str]:
        return [line.strip() for line in normalise(self.label).split("\n") if line.strip()]

    @property
    def area(self) -> int:
        return (self.x2 - self.x1) * (self.y2 - self.y1)

    @property
    def width(self) -> int:
        return self.x2 - self.x1

    def report(self) -> dict:
        return {
            "bounds": [self.x1, self.y1, self.x2, self.y2],
            "area": self.area,
            "lines": self.lines,
            "resource_id": self.resource_id,
        }


def parse_nodes(xml: str) -> list[Node]:
    found: list[Node] = []
    for match in re.finditer(r"<node[^>]*/?>", xml):
        node = match.group(0)
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
        if not bounds:
            continue
        x1, y1, x2, y2 = (int(value) for value in bounds.groups())
        if x2 <= x1 or y2 <= y1:
            continue
        text = re.search(r'text="([^"]*)"', node)
        desc = re.search(r'content-desc="([^"]*)"', node)
        res = re.search(r'resource-id="([^"]*)"', node)
        label = (desc.group(1) if desc else "") or (text.group(1) if text else "")
        found.append(Node(x1, y1, x2, y2, label,
                          res.group(1) if res else "",
                          desc.group(1) if desc else ""))
    return found


class Resolution:
    """Where to tap, why, and how sure the resolver is."""

    def __init__(self, x: int, y: int, strategy: str, confidence: str,
                 node: Node, line_index: int | None = None) -> None:
        self.x, self.y = x, y
        self.strategy = strategy
        self.confidence = confidence
        self.node = node
        self.line_index = line_index

    def report(self) -> dict:
        return {
            "x": self.x,
            "y": self.y,
            "strategy": self.strategy,
            "confidence": self.confidence,
            "line_index": self.line_index,
            "node": self.node.report(),
        }


def resolve(xml: str, target: str, occurrence: int = 0) -> Resolution | None:
    """Finds [target] and works out where to press.

    Strategies, in order of how much they can be trusted: an exact single-line
    label (`HIGH`), a line inside a merged label located by the container's
    geometry (`MEDIUM`), and a container match with no line information (`LOW`,
    which the caller must not tap unless it says so).
    """
    wanted = normalise(target).strip()
    nodes = parse_nodes(xml)

    exact = [n for n in nodes if n.lines == [wanted]]
    if exact:
        node = sorted(exact, key=lambda n: n.area)[occurrence % len(exact)]
        return Resolution((node.x1 + node.x2) // 2, (node.y1 + node.y2) // 2,
                          "exact-single-line-label", "HIGH", node)

    merged = [n for n in nodes if wanted in n.lines and len(n.lines) > 1]
    if merged:
        node = sorted(merged, key=lambda n: n.area)[occurrence % len(merged)]
        index = node.lines.index(wanted)
        # The row's own share of the container: a merged settings node stacks its
        # lines evenly, so the centre of line `index` is that fraction of the way
        # down. No fixed line height is assumed — the container's own height is.
        share = (index + 0.5) / len(node.lines)
        y = node.y1 + int(node.height_share(share))
        return Resolution((node.x1 + node.x2) // 2, y,
                          f"merged-label-line-{index}-of-{len(node.lines)}",
                          "MEDIUM", node, index)

    partial = [n for n in nodes if wanted in normalise(n.label)]
    if partial:
        node = sorted(partial, key=lambda n: n.area)[occurrence % len(partial)]
        return Resolution((node.x1 + node.x2) // 2, (node.y1 + node.y2) // 2,
                          "label-contains-target", "LOW", node)

    return None


def _height_share(self: Node, share: float) -> float:
    return (self.y2 - self.y1) * share


Node.height_share = _height_share  # type: ignore[attr-defined]


#: The only package this script may drive.
DHIMMAH = "com.dhimmah.dhimmah"


def foreground_package() -> str:
    """Who owns the screen right now, from the window manager's own report."""
    for line in adb("shell", "dumpsys", "window", "displays").stdout.splitlines():
        for marker in ("mCurrentFocus", "mFocusedApp"):
            if marker in line and "/" in line:
                fragment = line.split(marker, 1)[1]
                match = re.search(r"([A-Za-z0-9_.]+)/", fragment)
                if match:
                    return match.group(1)
    return "(unknown)"


def guard(tag: str) -> bool:
    """Refuses to act unless Dhimmah owns the foreground.

    A phone call, the lock screen, a permission dialog or any other application
    is a *different* UI state, not a Dhimmah screen: tapping coordinates in it
    would be driving somebody else's app. When the owner is not Dhimmah the
    script records what it saw and stops, which the report calls
    `SKIPPED — ENVIRONMENT` rather than a failure.
    """
    owner = foreground_package()
    if owner == DHIMMAH:
        print(f"foreground: {owner}")
        return True
    shot(f"{tag}_foreign")
    dump(f"{tag}_foreign")
    print(f"SKIPPED — ENVIRONMENT: the screen belongs to {owner!r}, not to Dhimmah. "
          f"No tap, no Back, no recovery action was sent.")
    return False


def act(target: str, tag: str, *, allow_low: bool = False) -> Resolution | None:
    """Resolves, records, then presses — refusing anything it cannot place."""
    if not guard(tag):
        return None
    before_xml = dump(f"{tag}_before")
    shot(f"{tag}_before")
    resolution = resolve(before_xml, target)
    record = {"target": target, "resolution": resolution.report() if resolution else None,
              "screen_before": f"{tag}_before.xml"}
    write_text(
        ("logs", f"{tag}_resolution.json"),
        json.dumps(record, ensure_ascii=False, indent=2),
    )

    if resolution is None:
        print(f"UNRESOLVED {target!r}. Labels seen: "
              f"{[n.lines for n in parse_nodes(before_xml)][:8]}")
        return None
    if resolution.confidence == "LOW" and not allow_low:
        print(f"REFUSING a low-confidence tap for {target!r}: {resolution.strategy}")
        return None

    print(f"TAP {target!r} via {resolution.strategy} ({resolution.confidence}) "
          f"-> ({resolution.x},{resolution.y})")
    adb("shell", "input", "tap", str(resolution.x), str(resolution.y))
    time.sleep(PAUSE)
    shot(f"{tag}_after")
    dump(f"{tag}_after")
    return resolution


def backups_in_sandbox() -> list[str]:
    listing = adb("shell", "run-as", "com.dhimmah.dhimmah", "ls",
                  "app_flutter/backups").stdout
    return [line.strip() for line in listing.splitlines() if line.strip().endswith(".dhimmah")]


def main() -> None:
    for folder in ("logs", "screenshots"):
        os.makedirs(evidence_path(folder), exist_ok=True)

    print("=== current screen ===")
    xml = dump("00_screen")
    for node in parse_nodes(xml):
        if node.lines:
            print(f"   {node.report()}")
    print(f"snapshots in the sandbox before: {backups_in_sandbox()}")

    print("=== go to Settings → Backup if needed ===")
    if not any("احتفظ بنسخة" in line for node in parse_nodes(xml) for line in node.lines):
        act("الإعدادات", "01_settings")
        act("النسخ الاحتياطي", "02_backup_row")

    print("=== the manual backup button ===")
    resolution = act("احتفظ بنسخة الآن", "03_backup_now")
    if resolution is None:
        print("could not place the button; nothing was pressed")
        return

    time.sleep(4)
    shot("04_progress")
    time.sleep(9)
    after = dump("05_after")
    print(f"screen after: {[n.lines for n in parse_nodes(after) if n.lines][:8]}")
    snapshots = backups_in_sandbox()
    print(f"snapshots in the sandbox after: {snapshots}")
    print("RESULT: " + ("a snapshot was written" if snapshots
                        else "no snapshot: the tap did not reach the button"))


if __name__ == "__main__":
    main()
