#!/usr/bin/env python3
"""Composes the store screenshots, the feature graphics and the store icons.

The screenshots are photographs of the real app (see
`integration_test/store_capture_test.dart`); nothing here redraws or alters the
interface. What this script does is what a store listing allows around a
screenshot: a background, a headline, a supporting line, margins, and a frame
with a soft shadow. The screenshot itself is only scaled — every pixel of it is
the app's own.

    python3 tool/store_capture/compose_assets.py

Reads  DHIMMAH_STORE_ASSETS/04_SOURCE_SCREENSHOTS/ANDROID/<LANG>/<key>.png
       tool/store_capture/store_story.json          (the copy, both languages)
       assets/icon/*.png, assets/fonts/*.ttf        (the brand, as shipped)
Writes DHIMMAH_STORE_ASSETS/01_GOOGLE_PLAY/PHONE_<LANG>/NN_*_1080x1920.png
       DHIMMAH_STORE_ASSETS/01_GOOGLE_PLAY/FEATURE_GRAPHIC_<LANG>/...
       DHIMMAH_STORE_ASSETS/03_ICONS/...
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# The folder the finished assets are written to. DH_OUT lets a second
# revision (a different currency, say) be produced beside the first without
# touching it.
OUT = os.path.join(ROOT, os.environ.get("DH_OUT", "DHIMMAH_STORE_ASSETS"))
SOURCE = os.path.join(OUT, "04_SOURCE_SCREENSHOTS", "ANDROID")
STORY = os.path.join(ROOT, "tool", "store_capture", "store_story.json")
FONTS = os.path.join(ROOT, "assets", "fonts")
ICONS = os.path.join(ROOT, "assets", "icon")

# The canvases, from the two stores' current published requirements — see
# 00_README/STORE_REQUIREMENTS.md for the pages and the date they were read.
PHONE_W, PHONE_H = 1080, 1920          # Google Play phone, 9:16
FEATURE_W, FEATURE_H = 1024, 500       # Google Play feature graphic
PLAY_ICON = 512                        # Google Play store icon
APPLE_ICON = 1024                      # Apple App Store icon master

# The palette the app itself is built on, so the listing looks like the product.
LIGHT = {
    "page": (247, 245, 242),
    "ink": (28, 25, 23),
    "secondary": (107, 101, 92),
    "border": (229, 225, 218),
    "shadow": (28, 25, 23, 46),
}
DARK = {
    "page": (19, 18, 17),
    "ink": (242, 239, 234),
    "secondary": (171, 164, 155),
    "border": (53, 49, 44),
    "shadow": (0, 0, 0, 130),
}

MARGIN = 76
MARK_H = 48
HEADLINE_SIZE = 62
SUPPORT_SIZE = 32
# The vertical rhythm of the text band: brand row, headline, supporting line,
# then the card. Kept tight so the screenshot — the actual subject — gets as
# much of the canvas as a whole, uncropped 1080x2400 frame can take.
BRAND_TOP = 40
HEADLINE_GAP = 22
SUPPORT_GAP = 12
CARD_GAP = 34
CARD_RADIUS = 40
CARD_BOTTOM = 60

# Google Play: "Taglines should not take up more than 20% of the image."
TAGLINE_MAX_FRACTION = 0.20
# The ladder the marketing type steps down, largest first. A fixed ladder, so the
# same copy always produces the same file.
TEXT_SCALES = (1.0, 0.94, 0.88, 0.82, 0.76, 0.70)


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(os.path.join(FONTS, f"IBMPlexSansArabic-{weight}.ttf"), size)


def mark_image(height: int) -> Image.Image:
    """The brand mark, cropped to its own edge and scaled to `height`.

    The shipped mark sits inside a transparent square tile, so using the file
    as-is would draw a small blob with a tile's worth of air around it.
    """
    mark = Image.open(os.path.join(ICONS, "icon_mark.png")).convert("RGBA")
    mark = mark.crop(mark.getchannel("A").getbbox())
    ratio = height / mark.height
    return mark.resize((max(1, round(mark.width * ratio)), height), Image.LANCZOS)


def wrap(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont,
         max_w: int, rtl: bool) -> list[str]:
    """Greedy wrap that measures with the same shaper that will draw it."""
    direction = "rtl" if rtl else "ltr"
    language = "ar" if rtl else "en"

    def width(s: str) -> float:
        return draw.textlength(s, font=f, direction=direction, language=language)

    lines: list[str] = []
    for paragraph in text.split("\n"):
        current = ""
        for word in paragraph.split(" "):
            candidate = word if not current else f"{current} {word}"
            if current and width(candidate) > max_w:
                lines.append(current)
                current = word
            else:
                current = candidate
        if current:
            lines.append(current)
    return lines


class Canvas:
    """A page: paper, a brand row, a headline, a supporting line, and a card."""

    def __init__(self, palette: dict, rtl: bool, size: tuple[int, int]):
        self.palette = palette
        self.rtl = rtl
        self.image = Image.new("RGB", size, palette["page"])
        self.draw = ImageDraw.Draw(self.image)
        self.width, self.height = size
        self.direction = "rtl" if rtl else "ltr"
        self.language = "ar" if rtl else "en"
        # Where the text lines are anchored: the reading side of the page.
        self.text_left = MARGIN
        self.text_right = self.width - MARGIN
        # Where the screenshot landed, for the source-fidelity check.
        self.card_box: tuple[int, int, int, int] | None = None

    def text_block(self, text: str, f: ImageFont.FreeTypeFont, colour: tuple[int, int, int],
                   top: int, leading: float = 1.24) -> int:
        """Draws wrapped, reading-side-aligned text and returns the next free y."""
        lines = wrap(self.draw, text, f, self.text_right - self.text_left, self.rtl)
        ascent, descent = f.getmetrics()
        line_h = round((ascent + descent) * leading)
        y = top
        for line in lines:
            baseline = y + ascent
            if self.rtl:
                self.draw.text((self.text_right, baseline), line, font=f, fill=colour,
                               anchor="rs", direction=self.direction, language=self.language)
            else:
                self.draw.text((self.text_left, baseline), line, font=f, fill=colour,
                               anchor="ls", direction=self.direction, language=self.language)
            y += line_h
        return y

    def brand_row(self, top: int) -> int:
        """The mark and the wordmark, on the reading side."""
        mark = mark_image(MARK_H)
        name_font = font("SemiBold", 46)
        name = "ذِمّة" if self.rtl else "Dhimmah"
        gap = 18
        ascent, _ = name_font.getmetrics()
        baseline = top + MARK_H // 2 + ascent // 2 - 4
        mark_y = round(top + (MARK_H - mark.height) / 2)
        # The mark leads, which in Arabic means the right edge with the wordmark
        # after it — the arrangement the app's own header uses.
        if self.rtl:
            mark_x = self.text_right - mark.width
            self.image.paste(mark, (round(mark_x), mark_y), mark)
            self.draw.text((mark_x - gap, baseline), name, font=name_font,
                           fill=self.palette["ink"], anchor="rs",
                           direction=self.direction, language=self.language)
        else:
            mark_x = self.text_left
            self.image.paste(mark, (round(mark_x), mark_y), mark)
            self.draw.text((mark_x + mark.width + gap, baseline), name, font=name_font,
                           fill=self.palette["ink"], anchor="ls",
                           direction=self.direction, language=self.language)
        return top + MARK_H

    def card(self, screenshot: Image.Image, top: int) -> None:
        """Places the screenshot whole — scaled to fit, never cropped."""
        avail_h = self.height - CARD_BOTTOM - top
        avail_w = self.width - 2 * MARGIN
        scale = min(avail_w / screenshot.width, avail_h / screenshot.height)
        w = round(screenshot.width * scale)
        h = round(screenshot.height * scale)
        shot = screenshot.convert("RGB").resize((w, h), Image.LANCZOS)
        x = (self.width - w) // 2
        y = top + (avail_h - h) // 2

        # A soft shadow under a rounded frame, so the page reads as paper with a
        # screen lying on it rather than as a screenshot pasted flat.
        pad = 90
        shadow = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (pad, pad, pad + w, pad + h), radius=CARD_RADIUS, fill=self.palette["shadow"])
        shadow = shadow.filter(ImageFilter.GaussianBlur(26))
        self.image.paste(shadow, (x - pad, y - pad + 16), shadow)

        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=CARD_RADIUS, fill=255)
        self.image.paste(shot, (x, y), mask)
        self.draw.rounded_rectangle(
            (x, y, x + w - 1, y + h - 1), radius=CARD_RADIUS,
            outline=self.palette["border"], width=2)
        self.card_box = (x, y, w, h)


def measure_band(headline: str, support: str, rtl: bool, palette: dict,
                 scale: float) -> int:
    """How tall the marketing band would be at `scale`, without drawing the card.

    Play caps the band at a fifth of the image, and the cap has to hold for the
    longest slide in a set — so the set is measured first and every slide is then
    drawn at the largest scale that fits all of them, which keeps the screenshot
    the same size from slide to slide.
    """
    canvas = Canvas(palette, rtl, (PHONE_W, PHONE_H))
    y = canvas.brand_row(BRAND_TOP)
    y = canvas.text_block(headline, font("SemiBold", max(40, round(HEADLINE_SIZE * scale))),
                          palette["ink"], y + HEADLINE_GAP)
    y = canvas.text_block(support, font("Regular", max(24, round(SUPPORT_SIZE * scale))),
                          palette["secondary"], y + SUPPORT_GAP)
    return y - BRAND_TOP


def fit_scale(copy_lines: list[tuple[str, str]], rtl: bool, palette: dict) -> float:
    """The largest type scale at which every slide's band fits the cap."""
    limit = PHONE_H * TAGLINE_MAX_FRACTION
    for scale in TEXT_SCALES:
        if all(measure_band(headline, support, rtl, palette, scale) <= limit
               for headline, support in copy_lines):
            return scale
    worst = max(measure_band(h, s, rtl, palette, TEXT_SCALES[-1]) for h, s in copy_lines)
    sys.exit(f"the marketing band is {worst}px of {PHONE_H} even at the smallest "
             f"type — the copy is too long for the canvas")


def compose_phone(source: Image.Image, headline: str, support: str, rtl: bool,
                  palette: dict, scale: float, card_top: int) -> tuple[Image.Image, tuple[int, int, int, int], int]:
    """One page. Returns the image, where the screenshot landed, and how tall the
    marketing band is.

    `card_top` is given rather than derived from the text: a set whose screenshots
    sit at a different height on every slide looks assembled, and one where they
    line up looks designed. The caller measures the tallest band in the set and
    places every card below it.
    """
    canvas = Canvas(palette, rtl, (PHONE_W, PHONE_H))
    y = canvas.brand_row(BRAND_TOP)
    y = canvas.text_block(headline, font("SemiBold", max(40, round(HEADLINE_SIZE * scale))),
                          palette["ink"], y + HEADLINE_GAP)
    y = canvas.text_block(support, font("Regular", max(24, round(SUPPORT_SIZE * scale))),
                          palette["secondary"], y + SUPPORT_GAP)
    canvas.card(source, card_top)
    return canvas.image, canvas.card_box, y - BRAND_TOP


def compose_feature(name: str, tagline: str, rtl: bool) -> Image.Image:
    """The 1024×500 banner: the mark, the wordmark, one line.

    The mark and the text are measured first and centred as one unit, and the
    tagline is wrapped and, if it still does not fit, set smaller — a banner
    that runs off the edge is the one thing a feature graphic must never do.
    """
    image = Image.new("RGB", (FEATURE_W, FEATURE_H), LIGHT["page"])
    draw = ImageDraw.Draw(image)
    direction = "rtl" if rtl else "ltr"
    language = "ar" if rtl else "en"

    mark = mark_image(206)
    gap_mark = 52
    max_text_w = FEATURE_W - 2 * 96 - mark.width - gap_mark

    name_font = font("SemiBold", 92)
    tagline_size = 36
    while tagline_size > 24:
        tagline_font = font("Regular", tagline_size)
        if draw.textlength(tagline, font=tagline_font, direction=direction,
                           language=language) <= max_text_w:
            break
        tagline_size -= 2
    tagline_font = font("Regular", tagline_size)

    name_w = draw.textlength(name, font=name_font, direction=direction, language=language)
    tag_w = draw.textlength(tagline, font=tagline_font, direction=direction, language=language)
    text_w = max(name_w, tag_w)
    unit_w = mark.width + gap_mark + text_w
    x0 = int((FEATURE_W - unit_w) // 2)

    name_ascent, name_descent = name_font.getmetrics()
    tag_ascent, tag_descent = tagline_font.getmetrics()
    gap = 22
    block_h = name_ascent + name_descent + gap + tag_ascent + tag_descent
    top = (FEATURE_H - block_h) // 2

    mark_x = int(x0 + unit_w - mark.width) if rtl else x0
    image.paste(mark, (mark_x, (FEATURE_H - mark.height) // 2), mark)

    if rtl:
        # The mark leads on the reading side; the text sits to its left, flush
        # to the mark's edge.
        text_edge = int(x0 + text_w)
        anchor = "rs"
    else:
        text_edge = int(x0 + mark.width + gap_mark)
        anchor = "ls"
    draw.text((text_edge, top + name_ascent), name, font=name_font, fill=LIGHT["ink"],
              anchor=anchor, direction=direction, language=language)
    draw.text((text_edge, top + name_ascent + name_descent + gap + tag_ascent), tagline,
              font=tagline_font, fill=LIGHT["secondary"], anchor=anchor,
              direction=direction, language=language)
    return image


def write(image: Image.Image, *parts: str) -> str:
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "PNG", optimize=True)
    print(f"wrote {os.path.relpath(path, ROOT)} {image.size[0]}x{image.size[1]}")
    return path


def main() -> None:
    with open(STORY, encoding="utf-8") as fh:
        story = json.load(fh)
    screens = story["screens"]
    dark_extra = story.get("dark_extra")

    # Where each composed screenshot came from and where its pixels sit on the
    # canvas — the fidelity check in validate_store_assets.py reads this.
    source_map: dict[str, dict] = {}

    for lang in ("ar", "en"):
        rtl = lang == "ar"
        source_dir = os.path.join(SOURCE, lang.upper())
        if not os.path.isdir(source_dir):
            sys.exit(f"no captures for {lang} at {source_dir} — run the capture first")

        # One type scale for the whole set: the largest that keeps every slide's
        # band inside the cap, so the screenshot is the same size on all eight.
        copy_lines = [(s[f"headline_{lang}"], s[f"support_{lang}"]) for s in screens]
        scale = fit_scale(copy_lines, rtl, LIGHT)
        band = max(measure_band(h, s, rtl, LIGHT, scale) for h, s in copy_lines)
        card_top = BRAND_TOP + band + CARD_GAP

        for index, screen in enumerate(screens, start=1):
            src = os.path.join(source_dir, f"{screen['source']}_{lang}.png")
            if not os.path.exists(src):
                sys.exit(f"missing capture {src}")
            shot = Image.open(src)
            headline = screen[f"headline_{lang}"]
            support = screen[f"support_{lang}"]
            composed, box, band = compose_phone(shot, headline, support, rtl, LIGHT,
                                                scale, card_top)
            rel = f"01_GOOGLE_PLAY/PHONE_{lang.upper()}/{index:02d}_{screen['source'][3:]}_{lang}_google_{PHONE_W}x{PHONE_H}.png"
            write(composed, rel)
            source_map[rel] = {
                "source": f"04_SOURCE_SCREENSHOTS/ANDROID/{lang.upper()}/{screen['source']}_{lang}.png",
                "box": list(box),
                "source_size": [shot.width, shot.height],
                "text_band_px": band,
            }

        # The dark dashboard, as a possible first slide. Kept as an alternate
        # rather than in the set: one dark frame among seven light ones reads as
        # a mistake unless the whole listing is dark.
        if dark_extra:
            src = os.path.join(source_dir, f"01_dashboard_dark_{lang}.png")
            if os.path.exists(src):
                shot = Image.open(src)
                composed, box, band = compose_phone(shot, dark_extra[f"headline_{lang}"],
                                                    dark_extra[f"support_{lang}"], rtl, DARK,
                                                    scale, card_top)
                rel = f"01_GOOGLE_PLAY/PHONE_{lang.upper()}/ALTERNATES/01_dashboard_dark_{lang}_google_{PHONE_W}x{PHONE_H}.png"
                write(composed, rel)
                source_map[rel] = {
                    "source": f"04_SOURCE_SCREENSHOTS/ANDROID/{lang.upper()}/01_dashboard_dark_{lang}.png",
                    "box": list(box),
                    "source_size": [shot.width, shot.height],
                    "text_band_px": band,
                }

        name = "ذِمّة" if rtl else "Dhimmah"
        tagline = "اعرف ما لك وما عليك" if rtl else "Know what you owe. Know what you're owed."
        write(compose_feature(name, tagline, rtl), "01_GOOGLE_PLAY",
              f"FEATURE_GRAPHIC_{lang.upper()}", f"feature_graphic_{lang}_{FEATURE_W}x{FEATURE_H}.png")

    validation_dir = os.path.join(OUT, "06_VALIDATION")
    os.makedirs(validation_dir, exist_ok=True)
    Path(validation_dir, "source_map.json").write_text(
        json.dumps(source_map, ensure_ascii=False, indent=2), encoding="utf-8")

    # What this build is: the ledger each listing was photographed in, the
    # canvases, and where the frames came from. The validator reads this rather
    # than guessing, and the report quotes it.
    Path(validation_dir, "build_info.json").write_text(
        json.dumps({
            "built_from": "tool/store_capture/compose_assets.py",
            "story": "tool/store_capture/store_story.json",
            "checked": story.get("checked"),
            "currency": story.get("currency", {}),
            "source_captures": "04_SOURCE_SCREENSHOTS/ANDROID/<LANG>/<key>.png, "
                               "captured by integration_test/store_capture_test.dart",
            "canvases": {
                "google_play_phone": f"{PHONE_W}x{PHONE_H}",
                "google_play_feature_graphic": f"{FEATURE_W}x{FEATURE_H}",
                "google_play_icon": f"{PLAY_ICON}x{PLAY_ICON}",
                "apple_icon": f"{APPLE_ICON}x{APPLE_ICON}",
            },
            "assets": len(source_map),
        }, ensure_ascii=False, indent=2), encoding="utf-8")

    # The icons are the shipped brand artwork at the size each store asks for —
    # not redrawn, not re-tinted. Play asks for a 32-bit PNG with alpha; Apple
    # asks for one with no transparency at all, so the two are not the same file.
    master = Image.open(os.path.join(ICONS, "icon.png")).convert("RGBA")
    write(master.resize((PLAY_ICON, PLAY_ICON), Image.LANCZOS),
          "03_ICONS", "GOOGLE_PLAY", f"icon_{PLAY_ICON}x{PLAY_ICON}.png")

    square = Image.open(os.path.join(ICONS, "icon_square.png")).convert("RGB")
    write(square.resize((APPLE_ICON, APPLE_ICON), Image.LANCZOS),
          "03_ICONS", "APPLE", f"icon_{APPLE_ICON}x{APPLE_ICON}.png")


if __name__ == "__main__":
    main()
