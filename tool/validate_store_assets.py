#!/usr/bin/env python3
"""Validates every store asset against the stores' published rules, and writes
the manifests and the contact sheets.

    python3 tool/validate_store_assets.py

Reads  DHIMMAH_STORE_ASSETS/  (what compose_assets.py wrote)
Writes DHIMMAH_STORE_ASSETS/00_README/ASSET_MANIFEST.{csv,json}
       DHIMMAH_STORE_ASSETS/06_VALIDATION/*.csv
       DHIMMAH_STORE_ASSETS/06_VALIDATION/contact_sheets/*.png

Exit code is non-zero when anything fails, so this is usable as a gate.
"""

from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, os.environ.get("DH_OUT", "DHIMMAH_STORE_ASSETS"))
STORY = os.path.join(ROOT, "tool", "store_capture", "store_story.json")
FONTS = os.path.join(ROOT, "assets", "fonts")

PHONE = (1080, 1920)
FEATURE = (1024, 500)
PLAY_ICON = (512, 512)
APPLE_ICON = (1024, 1024)

MB = 1024 * 1024
FIDELITY_THRESHOLD = 4.0  # mean absolute channel difference, 0-255
ALT_TEXT_LIMIT = 140      # characters, the store's alt-text field
TAGLINE_MAX_FRACTION = 0.20  # Play: "Taglines should not take up more than 20%"
# The store listing is never photographed in these, so none of them may appear
# in any file the package ships — not in a prompt, not in a manifest, not in a
# caption. The captures themselves are guarded on the device, where the app is
# asked whether any such string is on screen before a frame is written.
BANNED_MONEY = ("₹", "INR", "Indian Rupee", "روبية")

rows: list[dict[str, str]] = []
warnings: list[dict[str, str]] = []


def check(area: str, path: str, what: str, expected: str, actual: str) -> bool:
    ok = expected == actual
    rows.append({
        "area": area,
        "file": os.path.relpath(path, OUT) if path.startswith(OUT) else path,
        "check": what,
        "expected": expected,
        "actual": actual,
        "status": "PASS" if ok else "FAIL",
    })
    return ok


def sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def want(*parts: str) -> str:
    return os.path.join(OUT, *parts)


def validate_image(area: str, path: str, size: tuple[int, int], max_bytes: int,
                   allow_alpha: bool) -> None:
    if not os.path.exists(path):
        check(area, path, "exists", "yes", "no")
        return
    check(area, path, "exists", "yes", "yes")
    with Image.open(path) as image:
        check(area, path, "dimensions", f"{size[0]}x{size[1]}", f"{image.width}x{image.height}")
        check(area, path, "format", "PNG", image.format or "?")
        has_alpha = image.mode in ("RGBA", "LA") or (
            image.mode == "P" and "transparency" in image.info)
        if allow_alpha:
            rows.append({"area": area, "file": os.path.relpath(path, OUT),
                         "check": "alpha", "expected": "allowed", "actual":
                         "present" if has_alpha else "none",
                         "status": "PASS"})
        else:
            check(area, path, "alpha", "none", "present" if has_alpha else "none")
        w, h = image.size
        check(area, path, "within store bounds (320..3840)", "yes",
              "yes" if 320 <= w <= 3840 and 320 <= h <= 3840 else "no")
        if size == PHONE:
            nine_sixteen = abs(w / h - 9 / 16) < 1e-6
            check(area, path, "aspect ratio 9:16", "yes",
                  "yes" if nine_sixteen else f"no ({w}:{h})")
    size_bytes = os.path.getsize(path)
    check(area, path, "file size under limit", "yes",
          "yes" if size_bytes <= max_bytes
          else f"no ({size_bytes / MB:.2f}MB over the {max_bytes // MB}MB limit)")


def contact_sheet(title: str, files: list[str], target: str) -> None:
    """One page showing a whole set, so the story can be read at a glance."""
    if not files:
        return
    thumb_w, thumb_h = 250, 444
    gutter, padding, label_h = 28, 36, 46
    cols = min(4, len(files))
    rows_n = (len(files) + cols - 1) // cols
    width = padding * 2 + cols * thumb_w + (cols - 1) * gutter
    height = padding * 2 + rows_n * (thumb_h + label_h) + (rows_n - 1) * gutter
    sheet = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(os.path.join(FONTS, "IBMPlexSansArabic-Regular.ttf"), 22)
    title_font = ImageFont.truetype(os.path.join(FONTS, "IBMPlexSansArabic-SemiBold.ttf"), 30)
    draw.text((padding, 6), title, font=title_font, fill=(28, 25, 23))

    for index, path in enumerate(files):
        col, row = index % cols, index // cols
        x = padding + col * (thumb_w + gutter)
        y = padding + row * (thumb_h + label_h + gutter)
        with Image.open(path) as image:
            sheet.paste(image.convert("RGB").resize((thumb_w, thumb_h), Image.LANCZOS), (x, y))
        draw.rectangle((x, y, x + thumb_w - 1, y + thumb_h - 1), outline=(229, 225, 218))
        # A label short enough for the column it sits under: the store suffix is
        # the same on every file and the platform is in the title.
        label = os.path.basename(path).removesuffix(".png")
        label = label.replace("_google_1080x1920", "").replace("_google_1024x500", "")
        while draw.textlength(label, font=label_font) > thumb_w and len(label) > 8:
            label = label[:-1]
        draw.text((x, y + thumb_h + 12), label, font=label_font, fill=(107, 101, 92))
    os.makedirs(os.path.dirname(target), exist_ok=True)
    sheet.save(target, "PNG", optimize=True)
    print(f"wrote {os.path.relpath(target, ROOT)} {sheet.width}x{sheet.height}")


def main() -> int:
    with open(STORY, encoding="utf-8") as fh:
        story = json.load(fh)
    screens = story["screens"]
    dark = story.get("dark_extra")

    manifest: list[dict] = []
    seen_hashes: dict[str, str] = {}
    duplicates: list[dict[str, str]] = []

    def remember(path: str) -> None:
        digest = sha256(path)
        if digest in seen_hashes:
            duplicates.append({"file": os.path.relpath(path, OUT),
                               "identical_to": os.path.relpath(seen_hashes[digest], OUT)})
        else:
            seen_hashes[digest] = path

    # --- Google Play phone screenshots ------------------------------------
    for lang in ("ar", "en"):
        folder = want(f"01_GOOGLE_PLAY/PHONE_{lang.upper()}")
        expected_names = []
        for index, screen in enumerate(screens, start=1):
            slug = screen["source"][3:]
            name = f"{index:02d}_{slug}_{lang}_google_1080x1920.png"
            expected_names.append(name)
            path = os.path.join(folder, name)
            validate_image("google_phone", path, PHONE, 8 * MB, allow_alpha=False)
            if os.path.exists(path):
                remember(path)
                alt = screen[f"alt_{lang}"]
                check("alt_text", path, "alt text within 140 characters", "yes",
                      "yes" if len(alt) <= ALT_TEXT_LIMIT
                      else f"no ({len(alt)} characters)")
                manifest.append({
                    "number": f"{index:02d}",
                    "platform": "Google Play",
                    "device": "Phone",
                    "language": lang,
                    "screen": screen["screen"],
                    "filename": f"01_GOOGLE_PLAY/PHONE_{lang.upper()}/{name}",
                    "width": PHONE[0], "height": PHONE[1], "format": "PNG",
                    "alpha": "none", "file_size": os.path.getsize(path),
                    "source": f"04_SOURCE_SCREENSHOTS/ANDROID/{lang.upper()}/{screen['source']}_{lang}.png",
                    "headline": screen[f"headline_{lang}"],
                    "alt_text": screen[f"alt_{lang}"],
                    "upload_destination":
                        f"Google Play Console > Main store listing > Phone screenshots > "
                        f"{'Arabic' if lang == 'ar' else 'English'} ({lang})",
                    "prompt_file":
                        f"05_NANO_BANANA_PROMPTS/GOOGLE_PLAY/{index:02d}_{slug}_{lang}_google_nano_banana_prompt.md",
                    "validation": "06_VALIDATION/dimension_report.csv",
                })

        on_disk = sorted(f for f in os.listdir(folder) if f.endswith(".png")) \
            if os.path.isdir(folder) else []
        check("google_phone", folder, "set has exactly 8 screenshots", "8", str(len(on_disk)))
        check("google_phone", folder, "names match the manifest", "yes",
              "yes" if on_disk == expected_names else f"no: {on_disk}")

        # The dark dashboard, as an alternate.
        alt = os.path.join(folder, "ALTERNATES", f"01_dashboard_dark_{lang}_google_1080x1920.png")
        if os.path.exists(alt):
            validate_image("google_phone (alternate)", alt, PHONE, 8 * MB, allow_alpha=False)
            remember(alt)
            check("alt_text", alt, "alt text within 140 characters", "yes",
                  "yes" if len(dark["alt_" + lang]) <= ALT_TEXT_LIMIT
                  else f"no ({len(dark['alt_' + lang])} characters)")
            manifest.append({
                "number": "01-alt",
                "platform": "Google Play",
                "device": "Phone",
                "language": lang,
                "screen": dark["screen"],
                "filename": f"01_GOOGLE_PLAY/PHONE_{lang.upper()}/ALTERNATES/"
                            f"01_dashboard_dark_{lang}_google_1080x1920.png",
                "width": PHONE[0], "height": PHONE[1], "format": "PNG",
                "alpha": "none", "file_size": os.path.getsize(alt),
                "source": f"04_SOURCE_SCREENSHOTS/ANDROID/{lang.upper()}/01_dashboard_dark_{lang}.png",
                "headline": dark[f"headline_{lang}"],
                "alt_text": dark[f"alt_{lang}"],
                "upload_destination":
                    f"Google Play Console > Main store listing > Phone screenshots > "
                    f"{'Arabic' if lang == 'ar' else 'English'} ({lang}) — alternate, "
                    f"not part of the numbered set",
                "prompt_file": f"05_NANO_BANANA_PROMPTS/GOOGLE_PLAY/"
                               f"01_dashboard_dark_{lang}_google_nano_banana_prompt.md",
                "validation": "06_VALIDATION/dimension_report.csv",
            })

        # Prompt coverage for this set.
        prompt_dir = want("05_NANO_BANANA_PROMPTS/GOOGLE_PLAY")
        for index, screen in enumerate(screens, start=1):
            slug = screen["source"][3:]
            prompt = os.path.join(
                prompt_dir, f"{index:02d}_{slug}_{lang}_google_nano_banana_prompt.md")
            check("prompts", prompt, "prompt exists for asset", "yes",
                  "yes" if os.path.exists(prompt) else "no")

        # Contact sheet.
        sheet_files = [os.path.join(folder, n) for n in expected_names]
        contact_sheet(
            f"Google Play — Phone — {'Arabic' if lang == 'ar' else 'English'}",
            [f for f in sheet_files if os.path.exists(f)],
            want("06_VALIDATION", "contact_sheets",
                 f"GOOGLE_PHONE_{lang.upper()}_CONTACT_SHEET.png"))

    # --- Source captures --------------------------------------------------
    for lang in ("ar", "en"):
        folder = want("04_SOURCE_SCREENSHOTS/ANDROID", lang.upper())
        if not os.path.isdir(folder):
            check("source", folder, "capture folder exists", "yes", "no")
            continue
        files = sorted(f for f in os.listdir(folder)
                       if f.endswith(".png") and "_dark_" not in f)
        check("source", folder, "has the 8 screens", "8", str(len(files)))
        dark_capture = os.path.join(folder, f"01_dashboard_dark_{lang}.png")
        check("source", dark_capture, "dark capture exists", "yes",
              "yes" if os.path.exists(dark_capture) else "no")
        for name in files:
            path = os.path.join(folder, name)
            with Image.open(path) as image:
                check("source", path, "native capture size", "1080x2400",
                      f"{image.width}x{image.height}")

    # --- Feature graphics -------------------------------------------------
    for lang in ("ar", "en"):
        path = want("01_GOOGLE_PLAY", f"FEATURE_GRAPHIC_{lang.upper()}",
                    f"feature_graphic_{lang}_1024x500.png")
        validate_image("google_feature", path, FEATURE, 15 * MB, allow_alpha=False)
        if os.path.exists(path):
            remember(path)
            manifest.append({
                "number": "feature",
                "platform": "Google Play",
                "device": "All",
                "language": lang,
                "screen": "Feature graphic",
                "filename": f"01_GOOGLE_PLAY/FEATURE_GRAPHIC_{lang.upper()}/"
                            f"feature_graphic_{lang}_1024x500.png",
                "width": FEATURE[0], "height": FEATURE[1], "format": "PNG",
                "alpha": "none", "file_size": os.path.getsize(path),
                "source": "assets/icon/icon_mark.png",
                "headline": "ذِمّة" if lang == "ar" else "Dhimmah",
                "alt_text": "شعار ذِمّة واسمها على خلفية ورقية دافئة." if lang == "ar"
                            else "The Dhimmah mark and wordmark on a warm paper background.",
                "upload_destination":
                    f"Google Play Console > Main store listing > Feature graphic > "
                    f"{'Arabic' if lang == 'ar' else 'English'} ({lang})",
                "prompt_file": f"05_NANO_BANANA_PROMPTS/GOOGLE_PLAY/"
                               f"feature_graphic_{lang}_google_nano_banana_prompt.md",
                "validation": "06_VALIDATION/dimension_report.csv",
            })
        prompt = want("05_NANO_BANANA_PROMPTS/GOOGLE_PLAY",
                      f"feature_graphic_{lang}_google_nano_banana_prompt.md")
        check("prompts", prompt, "prompt exists for asset", "yes",
              "yes" if os.path.exists(prompt) else "no")

    # --- Icons ------------------------------------------------------------
    play_icon_path = want("03_ICONS", "GOOGLE_PLAY", "icon_512x512.png")
    validate_image("play_icon", play_icon_path, PLAY_ICON, 1 * MB, allow_alpha=True)
    if os.path.exists(play_icon_path):
        remember(play_icon_path)
        manifest.append({
            "number": "icon", "platform": "Google Play", "device": "All",
            "language": "—", "screen": "Store icon",
            "filename": "03_ICONS/GOOGLE_PLAY/icon_512x512.png",
            "width": 512, "height": 512, "format": "PNG",
            "alpha": "allowed",
            "file_size": os.path.getsize(play_icon_path),
            "source": "assets/icon/icon.png",
            "headline": "—",
            "alt_text": "The Dhimmah app icon: a green wallet holding a receipt and a coin.",
            "upload_destination": "Google Play Console > Main store listing > App icon",
            "prompt_file": "—", "validation": "06_VALIDATION/dimension_report.csv",
        })

    apple_icon_path = want("03_ICONS", "APPLE", "icon_1024x1024.png")
    validate_image("apple_icon", apple_icon_path, APPLE_ICON, 15 * MB, allow_alpha=False)
    if os.path.exists(apple_icon_path):
        remember(apple_icon_path)
        manifest.append({
            "number": "icon", "platform": "Apple App Store", "device": "iPhone / iPad",
            "language": "—", "screen": "App icon",
            "filename": "03_ICONS/APPLE/icon_1024x1024.png",
            "width": 1024, "height": 1024, "format": "PNG", "alpha": "none",
            "file_size": os.path.getsize(apple_icon_path),
            "source": "assets/icon/icon_square.png",
            "headline": "—", "alt_text": "—",
            "upload_destination": "App Store Connect > App icon (1024×1024)",
            "prompt_file": "—", "validation": "06_VALIDATION/dimension_report.csv",
        })

    # --- Source fidelity --------------------------------------------------
    source_map_path = want("06_VALIDATION", "source_map.json")
    fidelity_rows: list[dict[str, str]] = []
    if os.path.exists(source_map_path):
        with open(source_map_path, encoding="utf-8") as fh:
            source_map = json.load(fh)
        for asset_rel, entry in sorted(source_map.items()):
            asset_path = want(asset_rel)
            source_path = want(entry["source"])
            # Play's tagline rule, measured on the canvas rather than eyeballed.
            band = entry.get("text_band_px")
            if band is not None:
                check("tagline_area", asset_path,
                      "marketing band within 20% of the canvas height", "yes",
                      "yes" if band <= PHONE[1] * TAGLINE_MAX_FRACTION
                      else f"no ({band}px of {PHONE[1]})")
            if not (os.path.exists(asset_path) and os.path.exists(source_path)):
                fidelity_rows.append({"asset": asset_rel, "source": entry["source"],
                                      "mean_abs_diff": "-", "threshold":
                                      f"{FIDELITY_THRESHOLD}", "status": "FAIL"})
                continue
            x, y, w, h = entry["box"]
            # Both sides of the comparison are the same scale: the composed
            # card is the source resized to (w, h) and pasted whole, so the
            # interior of that box must equal the source resized to (w, h).
            # The 6px inset steps over the 2px border ring and the rounded
            # corners, which are composition, not screenshot.
            inset = 6
            with Image.open(asset_path) as asset_image:
                crop = asset_image.convert("RGB").crop(
                    (x + inset, y + inset, x + w - inset, y + h - inset))
            with Image.open(source_path) as source_image:
                expected = source_image.convert("RGB").resize((w, h), Image.LANCZOS).crop(
                    (inset, inset, w - inset, h - inset))
            a = crop.tobytes()
            b = expected.tobytes()
            samples = range(0, len(a), 997)  # stride sample: fast, and honest
            total = 0
            count = 0
            for i in samples:
                total += abs(a[i] - b[i])
                count += 1
            mean = total / count if count else 0
            status = "PASS" if mean <= FIDELITY_THRESHOLD else "FAIL"
            fidelity_rows.append({"asset": asset_rel, "source": entry["source"],
                                  "mean_abs_diff": f"{mean:.2f}",
                                  "threshold": f"{FIDELITY_THRESHOLD}", "status": status})
    _buffer = io.StringIO(newline="")
    _writer = csv.DictWriter(_buffer, fieldnames=["asset", "source", "mean_abs_diff", "threshold", "status"])
    _writer.writeheader()
    _writer.writerows(fidelity_rows)
    Path(want("06_VALIDATION", "source_fidelity_report.csv")).write_text(_buffer.getvalue(),
                                  encoding="utf-8", newline="")


    # --- The money the package is allowed to show ---------------------------
    #
    # The captures were checked on the device before each frame was written. What
    # is checked here is the rest of the package: no prompt, manifest, caption or
    # document may carry a currency the listing must never show, and the currency
    # the build record declares has to be one of the two the listing was
    # photographed in.
    currency_report: list[dict[str, str]] = []
    build_info: dict = {}
    info_path = want("06_VALIDATION", "build_info.json")
    if os.path.exists(info_path):
        with open(info_path, encoding="utf-8") as fh:
            build_info = json.load(fh)
    declared = build_info.get("currency", {})
    for lang in ("ar", "en"):
        code = declared.get(lang, "")
        ok = code in ("USD", "YER")
        currency_report.append({
            "area": "currency",
            "check": f"declared currency, {lang}", "file": "06_VALIDATION/build_info.json",
            "expected": "USD or YER", "actual": code or "not declared",
            "status": "PASS" if ok else "FAIL",
        })

    # Everything the package ships as text, except this check's own reports:
    # they are the result of the check, not copy, and a report that quotes a hit
    # would otherwise be read back as one on the next run.
    own_reports = {
        "06_VALIDATION/dimension_report.csv", "06_VALIDATION/format_report.csv",
        "06_VALIDATION/alpha_report.csv", "06_VALIDATION/file_size_report.csv",
        "06_VALIDATION/localization_report.csv", "06_VALIDATION/prompt_coverage.csv",
        "06_VALIDATION/duplicate_report.csv", "06_VALIDATION/source_fidelity_report.csv",
        "06_VALIDATION/currency_report.csv", "06_VALIDATION/coverage.csv",
    }
    text_files: list[str] = []
    for root, dirs, files in os.walk(OUT):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for name in sorted(files):
            if not name.endswith((".md", ".json", ".csv", ".txt")):
                continue
            rel = os.path.relpath(os.path.join(root, name), OUT)
            if rel in own_reports or os.path.basename(rel).startswith("."):
                continue
            text_files.append(os.path.join(root, name))
    for path in text_files:
        rel = os.path.relpath(path, OUT)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        hits = [token for token in BANNED_MONEY if token in text]
        currency_report.append({
            "area": "currency",
            "check": "no currency the listing must not show", "file": rel,
            "expected": "no banned currency",
            "actual": "none" if not hits else ", ".join(hits),
            "status": "PASS" if not hits else "FAIL",
        })
    _buffer = io.StringIO(newline="")
    _writer = csv.DictWriter(_buffer, fieldnames=["check", "file", "expected", "actual", "status"])
    _writer.writeheader()
    _writer.writerows(({k: row[k] for k in ("check", "file", "expected", "actual", "status")}
                          for row in currency_report))
    Path(want("06_VALIDATION", "currency_report.csv")).write_text(_buffer.getvalue(),
                                  encoding="utf-8", newline="")

    rows.extend(currency_report)

    # Every asset the compositor produced has a prompt beside it. The store
    # icons are the exception by design: they are the shipped brand artwork
    # resized, so there is nothing for an image model to be asked for.
    for row in manifest:
        if not row["filename"].startswith("01_GOOGLE_PLAY/"):
            continue
        prompt = want(*row["prompt_file"].split("/"))
        check("prompts", prompt, "prompt exists for the asset it describes", "yes",
              "yes" if os.path.exists(prompt) else "no")

    # --- Coverage: what this package has, and what it does not ---------------
    coverage: list[dict[str, str]] = []
    for lang in ("ar", "en"):
        phone = want(f"01_GOOGLE_PLAY/PHONE_{lang.upper()}")
        count = len([f for f in os.listdir(phone) if f.endswith(".png")]) \
            if os.path.isdir(phone) else 0
        coverage.append({"area": f"google_play_phone_{lang}", "produced": str(count),
                         "note": "8 of 8" if count == 8 else f"{count} of 8"})
    for area, folder in (("apple_iphone", "02_APP_STORE/IPHONE_AR"),
                         ("apple_ipad", "02_APP_STORE/IPAD_AR")):
        path = want(folder)
        count = len([f for f in os.listdir(path) if f.endswith(".png")]) \
            if os.path.isdir(path) else 0
        coverage.append({"area": area, "produced": str(count),
                         "note": "NOT PROVEN — no iOS runtime on this machine"
                                 if count == 0 else "produced"})
    # Anything the manifest does not know about, so no file can be shipped
    # without having been looked at.
    known = {row["filename"] for row in manifest if row["filename"] != "—"}
    known |= {os.path.relpath(os.path.join(root, name), OUT)
              for root, _dirs, files in os.walk(want("04_SOURCE_SCREENSHOTS"))
              for name in files if name.endswith(".png")}
    known |= {os.path.relpath(os.path.join(root, name), OUT)
              for root, _dirs, files in os.walk(want("06_VALIDATION", "contact_sheets"))
              for name in files if name.endswith(".png")}
    orphans = [os.path.relpath(os.path.join(root, name), OUT)
               for root, _dirs, files in os.walk(OUT)
               for name in files if name.endswith(".png")
               and os.path.relpath(os.path.join(root, name), OUT) not in known]
    check("package", want("00_README", "ASSET_MANIFEST.csv"),
          "every PNG in the package is in the manifest", "none missing",
          "none missing" if not orphans else f"{len(orphans)}: {orphans[:3]}")

    stray: list[str] = []
    for root, dirs, files in os.walk(OUT):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for name in files:
            rel = os.path.relpath(os.path.join(root, name), OUT)
            if name.startswith(".") or not name.endswith((".png", ".md", ".csv", ".json")):
                stray.append(rel)
    check("package", want("README.md"), "no stray files in the package",
          "no stray files", "no stray files" if not stray else f"{len(stray)}: {stray[:3]}")

    _buffer = io.StringIO(newline="")
    _writer = csv.DictWriter(_buffer, fieldnames=["area", "produced", "note"])
    _writer.writeheader()
    _writer.writerows(coverage)
    Path(want("06_VALIDATION", "coverage.csv")).write_text(_buffer.getvalue(),
                                  encoding="utf-8", newline="")

    for row in coverage:
        if "NOT PROVEN" in row["note"]:
            warnings.append({"what": row["area"], "why": row["note"]})

    # --- Reports ----------------------------------------------------------
    def report(name: str, keys: list[str], filter_area: tuple[str, ...] | None = None) -> None:
        selected = [r for r in rows
                    if filter_area is None or r.get("area") in filter_area]
        path = want("06_VALIDATION", name)
        buffer = io.StringIO(newline="")
        writer = csv.DictWriter(buffer, fieldnames=keys)
        writer.writeheader()
        for row in selected:
            writer.writerow({k: row[k] for k in keys})
        if not selected:
            buffer = io.StringIO(newline="")
            csv.DictWriter(buffer, fieldnames=keys).writeheader()
        Path(path).write_text(buffer.getvalue(), encoding="utf-8", newline="")

    report("dimension_report.csv", ["file", "check", "expected", "actual", "status"])
    report("format_report.csv", ["file", "check", "expected", "actual", "status"])
    report("alpha_report.csv", ["file", "check", "expected", "actual", "status"],
           filter_area=("google_phone", "google_phone (alternate)", "google_feature",
                        "play_icon", "apple_icon"))
    report("file_size_report.csv", ["file", "check", "expected", "actual", "status"])
    report("localization_report.csv", ["file", "check", "expected", "actual", "status"],
           filter_area=("google_phone", "prompts", "source"))
    report("prompt_coverage.csv", ["file", "check", "expected", "actual", "status"],
           filter_area=("prompts",))

    duplicates_buffer = io.StringIO(newline="")
    duplicates_writer = csv.DictWriter(duplicates_buffer,
                                       fieldnames=["file", "identical_to"])
    duplicates_writer.writeheader()
    duplicates_writer.writerows(duplicates)
    Path(want("06_VALIDATION", "duplicate_report.csv")).write_text(
        duplicates_buffer.getvalue(), encoding="utf-8", newline="")

    # --- Manifests --------------------------------------------------------
    os.makedirs(want("00_README"), exist_ok=True)
    Path(want("00_README", "ASSET_MANIFEST.json")).write_text(
        json.dumps({"checked": story.get("checked"), "assets": manifest},
                   ensure_ascii=False, indent=2),
        encoding="utf-8")
    manifest_buffer = io.StringIO(newline="")
    manifest_writer = csv.DictWriter(manifest_buffer,
                                     fieldnames=list(manifest[0].keys()))
    manifest_writer.writeheader()
    manifest_writer.writerows(manifest)
    Path(want("00_README", "ASSET_MANIFEST.csv")).write_text(
        manifest_buffer.getvalue(), encoding="utf-8", newline="")

    # --- Summary ----------------------------------------------------------
    failures = [r for r in rows if r["status"] == "FAIL"]
    fidelity_failures = [r for r in fidelity_rows if r["status"] == "FAIL"]
    print()
    print(f"assets:    {len(manifest)} in the manifest")
    print(f"checks:    {len(rows)}")
    print(f"passing:   {len(rows) - len(failures)}")
    print(f"failing:   {len(failures)}")
    print(f"fidelity:  {len(fidelity_rows) - len(fidelity_failures)}/{len(fidelity_rows)} pass")
    print(f"duplicates:{len(duplicates)}")
    print(f"warnings:  {len(warnings)}")
    for row in warnings:
        print(f"  WARN {row['what']} — {row['why']}")
    for row in failures:
        print(f"  FAIL {row['file']} — {row['check']}: expected {row['expected']}, got {row['actual']}")
    for row in fidelity_failures:
        print(f"  FAIL {row['asset']} — source fidelity {row['mean_abs_diff']}")
    return 1 if (failures or fidelity_failures) else 0


if __name__ == "__main__":
    sys.exit(main())
