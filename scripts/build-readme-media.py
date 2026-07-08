#!/usr/bin/env python3
"""Build README media from deterministic Storybook screenshots."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "Media" / "storybook-chart-only"
OUT_DIR = ROOT / "Media" / "readme"

PANEL_CROP = (46, 226, 1160, 1100)
FONT_REGULAR = Path("/System/Library/Fonts/SFNS.ttf")
FONT_MONO = Path("/System/Library/Fonts/SFNSMono.ttf")

EXAMPLES = [
    ("line-basic-dark", "Line chart"),
    ("line-momentum-up", "Momentum"),
    ("line-orderbook", "Orderbook labels"),
    ("candle-basic", "Candlesticks"),
    ("candle-mode-controls", "Mode controls"),
    ("multi-basic", "Multi-series"),
]


def font(size: int, mono: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_MONO if mono else FONT_REGULAR), size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def add_shadow(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    blur: int,
    opacity: int,
    offset: tuple[int, int] = (0, 20),
) -> None:
    width = box[2] - box[0]
    height = box[3] - box[1]
    shadow = Image.new("RGBA", (width, height), (0, 0, 0, opacity))
    shadow.putalpha(rounded_mask((width, height), radius))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (box[0] + offset[0], box[1] + offset[1]))


def crop_panel(slug: str) -> Image.Image:
    source = Image.open(SOURCE_DIR / f"{slug}.png").convert("RGBA")
    return source.crop(PANEL_CROP)


def save_example_panels() -> dict[str, Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    paths: dict[str, Path] = {}
    for slug, _ in EXAMPLES:
        panel = crop_panel(slug)
        panel.thumbnail((900, 720), Image.Resampling.LANCZOS)
        output = OUT_DIR / f"{slug}.png"
        panel.save(output)
        paths[slug] = output
    return paths


def gradient_background(size: tuple[int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, "#07110f")
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            nx = x / width
            ny = y / height
            glow_left = max(0.0, 1.0 - ((nx - 0.18) ** 2 + (ny - 0.28) ** 2) / 0.22)
            glow_right = max(0.0, 1.0 - ((nx - 0.82) ** 2 + (ny - 0.42) ** 2) / 0.18)
            base = (
                int(7 + 18 * ny + 20 * glow_left),
                int(17 + 34 * glow_left + 24 * glow_right),
                int(15 + 48 * glow_right + 14 * glow_left),
            )
            pixels[x, y] = (*base, 255)
    return image


def paste_panel(
    canvas: Image.Image,
    panel: Image.Image,
    xy: tuple[int, int],
    width: int,
    radius: int = 38,
    border: tuple[int, int, int, int] = (255, 255, 255, 30),
) -> None:
    scale = width / panel.width
    resized = panel.resize((width, round(panel.height * scale)), Image.Resampling.LANCZOS)
    x, y = xy
    box = (x, y, x + resized.width, y + resized.height)
    add_shadow(canvas, box, radius, blur=26, opacity=120, offset=(0, 18))
    mask = rounded_mask(resized.size, radius)
    canvas.paste(resized, xy, mask)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x, y, x + resized.width - 1, y + resized.height - 1),
        radius=radius,
        outline=border,
        width=2,
    )


def build_cover() -> Path:
    canvas = gradient_background((1600, 900))
    draw = ImageDraw.Draw(canvas)

    grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    for x in range(0, 1600, 56):
        grid_draw.line((x, 0, x - 430, 900), fill=(255, 255, 255, 22), width=1)
    for x in range(120, 1600, 120):
        grid_draw.line((x, 0, x, 900), fill=(255, 255, 255, 16), width=1)
    for y in range(70, 900, 120):
        grid_draw.line((0, y, 1600, y), fill=(255, 255, 255, 16), width=1)
    canvas.alpha_composite(grid)

    draw.rounded_rectangle((96, 86, 308, 132), radius=23, fill=(38, 212, 119, 38), outline=(85, 255, 164, 80), width=1)
    draw.text((122, 98), "SwiftUI charts", fill=(174, 255, 211, 255), font=font(22, mono=True))

    draw.text((96, 180), "Liveline", fill=(246, 255, 251, 255), font=font(104))
    draw.text((96, 286), "Swift", fill=(96, 177, 255, 255), font=font(104))
    draw.text((102, 426), "Native real-time line, candle, and", fill=(213, 226, 220, 235), font=font(34))
    draw.text((102, 472), "multi-series charts for iOS apps.", fill=(213, 226, 220, 235), font=font(34))

    pill_specs = [
        ("Line", (102, 594), (73, 139, 255)),
        ("Candles", (232, 594), (255, 83, 83)),
        ("Multi-series", (410, 594), (39, 202, 113)),
    ]
    for label, (x, y), color in pill_specs:
        text_width = round(draw.textlength(label, font=font(24)))
        draw.rounded_rectangle((x, y, x + text_width + 54, y + 52), radius=26, fill=(*color, 42), outline=(*color, 130), width=1)
        draw.text((x + 27, y + 13), label, fill=(245, 255, 251, 255), font=font(24))

    draw.text((102, 730), "Canvas rendering / interpolation / scrubbing / live badges", fill=(193, 209, 203, 235), font=font(24))
    draw.text((102, 770), "iOS 16+ / Swift 5.9+", fill=(157, 178, 172, 235), font=font(22, mono=True))

    paste_panel(canvas, crop_panel("line-basic-dark"), (782, 92), 690, radius=34)
    paste_panel(canvas, crop_panel("candle-basic"), (980, 434), 458, radius=30)
    paste_panel(canvas, crop_panel("multi-basic"), (704, 508), 416, radius=30)

    output = OUT_DIR / "cover.png"
    canvas.convert("RGB").save(output, quality=94)
    return output


def main() -> None:
    save_example_panels()
    build_cover()


if __name__ == "__main__":
    main()
