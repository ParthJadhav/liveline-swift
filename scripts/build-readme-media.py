#!/usr/bin/env python3
"""Build consistently cropped chart tiles for the README gallery."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "Media" / "storybook-chart-only"
OUT_DIR = ROOT / "Media" / "readme" / "charts"

# Removes the simulator chrome and the unused lower portion of each Storybook
# capture while retaining the complete chart panel.
PANEL_CROP = (46, 226, 1160, 1164)
OUTPUT_WIDTH = 900

CHARTS = [
    ("line-basic-dark", "Line"),
    ("candle-basic", "Candlestick"),
    ("multi-basic", "Multi-series"),
    ("bar-basic", "Bar"),
    ("range-basic", "Range band"),
    ("scatter-basic", "Scatter"),
    ("step-basic", "Step"),
    ("lollipop-basic", "Lollipop"),
    ("bubble-basic", "Bubble"),
    ("boxplot-basic", "Box plot"),
    ("waterfall-basic", "Waterfall"),
    ("errorbar-basic", "Error bar"),
    ("dumbbell-basic", "Dumbbell"),
    ("stackedbar-basic", "Stacked bar"),
    ("stackedarea-basic", "Stacked area"),
    ("timeline-basic", "Timeline"),
    ("heatmap-basic", "Heatmap"),
    ("radar-basic", "Radar"),
    ("donut-basic", "Donut"),
    ("gauge-basic", "Gauge"),
    ("funnel-basic", "Funnel"),
]


def remove_edge_background(image: Image.Image) -> None:
    width, height = image.size
    pixels = image.load()
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        return alpha > 0 and red >= 242 and green >= 242 and blue >= 242

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


def build_tile(slug: str) -> None:
    source = Image.open(SOURCE_DIR / f"{slug}.png").convert("RGBA")
    panel = source.crop(PANEL_CROP)
    remove_edge_background(panel)
    bounds = panel.getbbox()
    if bounds is not None:
        panel = panel.crop(bounds)

    scale = OUTPUT_WIDTH / panel.width
    tile = panel.resize(
        (OUTPUT_WIDTH, round(panel.height * scale)),
        Image.Resampling.LANCZOS,
    )
    tile.save(OUT_DIR / f"{slug}.png", optimize=True)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for slug, _ in CHARTS:
        build_tile(slug)
    print(f"Wrote {len(CHARTS)} README chart tiles to {OUT_DIR}")


if __name__ == "__main__":
    main()
