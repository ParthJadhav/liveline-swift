#!/usr/bin/env python3
"""Build polished README media from deterministic Storybook screenshots."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "Media" / "storybook-chart-only"
OUT_DIR = ROOT / "Media" / "readme"

PANEL_CROP = (46, 226, 1160, 1164)
FONT_REGULAR = Path("/System/Library/Fonts/SFNS.ttf")
FONT_MONO = Path("/System/Library/Fonts/SFNSMono.ttf")

INK = "#111827"
MUTED = "#657282"
SURFACE = "#f4f7fb"
PAPER = "#ffffff"

EXAMPLES = [
    ("line-basic-dark", "Line", "Live badge, scrub dot, eased range"),
    ("line-momentum-up", "Momentum", "Value-aware color and arrows"),
    ("line-orderbook", "Orderbook", "Streaming labels beside the plot"),
    ("candle-basic", "Candles", "OHLC bodies with live-candle glow"),
    ("candle-mode-controls", "Modes", "Line/candle control states"),
    ("multi-basic", "Multi-series", "Labeled comparison series"),
]


def font(size: int, weight: str = "regular", mono: bool = False) -> ImageFont.FreeTypeFont:
    # SFNS.ttc exposes regular/bold faces inconsistently through Pillow, so use
    # the same family with size/contrast doing the hierarchy work.
    del weight
    return ImageFont.truetype(str(FONT_MONO if mono else FONT_REGULAR), size)


def draw_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    size: int,
    fill: str | tuple[int, int, int, int] = INK,
    mono: bool = False,
) -> None:
    draw.text(xy, text, fill=fill, font=font(size, mono=mono))


def draw_wrapped_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    size: int,
    max_width: int,
    fill: str | tuple[int, int, int, int] = MUTED,
    line_gap: int = 8,
) -> int:
    words = text.split()
    lines: list[str] = []
    current = ""
    typeface = font(size)
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=typeface) <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)

    x, y = xy
    for line in lines:
        draw.text((x, y), line, fill=fill, font=typeface)
        y += size + line_gap
    return y


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def remove_edge_background(image: Image.Image) -> None:
    width, height = image.size
    pixels = image.load()
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        r, g, b, a = pixels[x, y]
        return a > 0 and r >= 242 and g >= 242 and b >= 242

    for x in range(width):
        if is_background(x, 0):
            queue.append((x, 0))
        if is_background(x, height - 1):
            queue.append((x, height - 1))

    for y in range(height):
        if is_background(0, y):
            queue.append((0, y))
        if is_background(width - 1, y):
            queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or not is_background(x, y):
            continue
        visited.add((x, y))
        pixels[x, y] = (255, 255, 255, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))


def crop_panel(slug: str) -> Image.Image:
    source = Image.open(SOURCE_DIR / f"{slug}.png").convert("RGBA")
    panel = source.crop(PANEL_CROP)
    remove_edge_background(panel)
    bbox = panel.getbbox()
    if bbox is None:
        return panel
    return panel.crop(bbox)


def resize_to_width(image: Image.Image, width: int) -> Image.Image:
    scale = width / image.width
    return image.resize((width, round(image.height * scale)), Image.Resampling.LANCZOS)


def soft_shadow(size: tuple[int, int], radius: int, opacity: int = 26, blur: int = 18) -> Image.Image:
    shadow = Image.new("RGBA", size, (17, 24, 39, opacity))
    shadow.putalpha(rounded_mask(size, radius))
    return shadow.filter(ImageFilter.GaussianBlur(blur))


def paste_panel(canvas: Image.Image, panel: Image.Image, xy: tuple[int, int], width: int) -> tuple[int, int]:
    image = resize_to_width(panel, width)
    x, y = xy
    canvas.alpha_composite(soft_shadow(image.size, 18), (x, y + 12))
    canvas.alpha_composite(image, xy)
    return image.size


def save_example_panels() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for slug, _, _ in EXAMPLES:
        panel = resize_to_width(crop_panel(slug), 900)
        panel.save(OUT_DIR / f"{slug}.png")


def build_cover() -> Path:
    canvas = Image.new("RGBA", (1600, 900), SURFACE)
    draw = ImageDraw.Draw(canvas)

    # Large quiet backdrop gives the screenshots a native-docs feel without a
    # decorative pattern.
    draw.rounded_rectangle((760, 54, 1526, 846), radius=28, fill="#e8eef6")
    draw.rounded_rectangle((792, 86, 1494, 814), radius=22, fill="#f9fbfd")

    draw_text(draw, (104, 96), "Liveline Swift", 82)
    draw_text(draw, (108, 206), "Native SwiftUI charts for live data.", 36, fill="#2b3442")
    draw_wrapped_text(
        draw,
        (108, 262),
        "Line, candlestick, and multi-series rendering captured from deterministic iOS Storybook scenarios.",
        25,
        max_width=560,
    )

    facts = [
        ("Renderer", "SwiftUI Canvas"),
        ("Modes", "Line / Candle / Multi-series"),
        ("States", "Scrub, live badge, loading, empty"),
    ]
    y = 388
    for label, value in facts:
        draw.line((108, y - 22, 620, y - 22), fill="#d7dee8", width=1)
        draw_text(draw, (108, y), label, 20, fill="#7b8796", mono=True)
        draw_text(draw, (264, y - 3), value, 28, fill=INK)
        y += 86

    draw.rounded_rectangle((108, 730, 482, 784), radius=12, fill=INK)
    draw_text(draw, (132, 758), "iOS 16+ / Swift 5.9+", 22, fill="#ffffff", mono=True)
    draw_text(draw, (108, 814), "No WebView. No JavaScript bridge.", 24, fill=MUTED)

    paste_panel(canvas, crop_panel("line-basic-dark"), (834, 126), 600)
    paste_panel(canvas, crop_panel("candle-basic"), (844, 598), 292)
    paste_panel(canvas, crop_panel("multi-basic"), (1172, 598), 292)

    output = OUT_DIR / "cover.png"
    canvas.convert("RGB").save(output, quality=95)
    return output


def draw_example_card(
    canvas: Image.Image,
    slug: str,
    title: str,
    caption: str,
    box: tuple[int, int, int, int],
) -> None:
    draw = ImageDraw.Draw(canvas)
    x, y, width, height = box
    draw.rounded_rectangle((x, y, x + width, y + height), radius=18, fill=PAPER)
    draw_text(draw, (x + 28, y + 24), title, 32, fill=INK)
    draw_text(draw, (x + 28, y + 66), caption, 20, fill=MUTED)
    panel = crop_panel(slug)
    target_width = width - 56
    image = resize_to_width(panel, target_width)
    max_height = height - 126
    if image.height > max_height:
        scale = max_height / image.height
        image = image.resize((round(image.width * scale), max_height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(image, (x + 28, y + height - image.height - 28))


def build_examples_sheet() -> Path:
    canvas = Image.new("RGBA", (1600, 1180), SURFACE)
    draw = ImageDraw.Draw(canvas)

    draw_text(draw, (80, 68), "Storybook captures", 58)
    draw_text(draw, (84, 142), "Deterministic iOS screenshots showing the renderer's main chart modes and UI states.", 27, fill=MUTED)

    card_width = 460
    card_height = 454
    gap = 30
    start_x = 80
    start_y = 238
    for index, (slug, title, caption) in enumerate(EXAMPLES):
        col = index % 3
        row = index // 3
        x = start_x + col * (card_width + gap)
        y = start_y + row * (card_height + gap)
        draw_example_card(canvas, slug, title, caption, (x, y, card_width, card_height))

    output = OUT_DIR / "examples.png"
    canvas.convert("RGB").save(output, quality=95)
    return output


def main() -> None:
    save_example_panels()
    build_cover()
    build_examples_sheet()


if __name__ == "__main__":
    main()
