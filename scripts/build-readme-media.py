#!/usr/bin/env python3
"""Build README media with browser-rendered HTML/CSS layouts."""

from __future__ import annotations

import subprocess
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "Media" / "storybook-chart-only"
OUT_DIR = ROOT / "Media" / "readme"
BUILD_DIR = ROOT / ".build" / "readme-media"
RENDER_SCRIPT = ROOT / "scripts" / "render-readme-media.mjs"

PANEL_CROP = (46, 226, 1160, 1164)

EXAMPLES = [
    "line-basic-dark",
    "line-momentum-up",
    "line-orderbook",
    "candle-basic",
    "candle-mode-controls",
    "multi-basic",
]


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
    return panel if bbox is None else panel.crop(bbox)


def save_panel(slug: str) -> None:
    panel = crop_panel(slug)
    scale = 900 / panel.width
    resized = panel.resize((900, round(panel.height * scale)), Image.Resampling.LANCZOS)
    resized.save(OUT_DIR / f"{slug}.png")


def image_src(name: str) -> str:
    return (OUT_DIR / name).resolve().as_uri()


def write_html(filename: str, body: str) -> Path:
    html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root {{
      --ink: #101725;
      --muted: #5f6d7e;
      --paper: #ffffff;
      --canvas: #f3f6fb;
      --rail: #e7edf5;
      --rule: #d6dee9;
    }}

    * {{ box-sizing: border-box; }}

    body {{
      margin: 0;
      background: transparent;
      color: var(--ink);
      font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
    }}

    .cover {{
      width: 1600px;
      height: 900px;
      display: grid;
      grid-template-columns: 600px 1fr;
      gap: 58px;
      padding: 72px 92px;
      background: var(--canvas);
    }}

    .cover-copy {{
      display: flex;
      min-width: 0;
      flex-direction: column;
      justify-content: flex-start;
      padding: 24px 0 0;
    }}

    h1 {{
      margin: 0 0 22px;
      font-size: 74px;
      line-height: 0.98;
      font-weight: 650;
      letter-spacing: -0.032em;
    }}

    .dek {{
      max-width: 540px;
      margin: 0;
      color: #2d3746;
      font-size: 32px;
      line-height: 1.24;
      letter-spacing: -0.018em;
    }}

    .summary {{
      max-width: 550px;
      margin: 20px 0 0;
      color: var(--muted);
      font-size: 23px;
      line-height: 1.4;
    }}

    .facts {{
      display: grid;
      gap: 0;
      margin: 52px 0 0;
      border-top: 1px solid var(--rule);
    }}

    .fact {{
      display: grid;
      grid-template-columns: 142px 1fr;
      align-items: baseline;
      min-height: 72px;
      border-bottom: 1px solid var(--rule);
    }}

    .fact span {{
      color: #7a8798;
      font-family: ui-monospace, "SF Mono", Menlo, monospace;
      font-size: 18px;
      letter-spacing: 0.02em;
    }}

    .fact strong {{
      font-size: 27px;
      font-weight: 500;
      letter-spacing: -0.018em;
    }}

    .runtime {{
      display: grid;
      gap: 16px;
      margin-top: 50px;
      color: var(--muted);
      font-size: 23px;
    }}

    .runtime code {{
      display: inline-flex;
      align-items: center;
      width: max-content;
      height: 50px;
      padding: 0 20px;
      border-radius: 12px;
      background: var(--ink);
      color: #fff;
      font-family: ui-monospace, "SF Mono", Menlo, monospace;
      font-size: 19px;
      white-space: nowrap;
    }}

    .cover-visual {{
      min-width: 0;
      padding: 28px;
      border-radius: 30px;
      background: var(--rail);
    }}

    .cover-stage {{
      height: 100%;
      display: grid;
      grid-template-rows: 1fr 210px;
      gap: 24px;
      padding: 30px;
      border-radius: 24px;
      background: #fbfcfe;
    }}

    .hero-shot,
    .thumb {{
      overflow: hidden;
      display: grid;
      place-items: center;
      border-radius: 14px;
      background: #070707;
      box-shadow: 0 14px 28px rgba(16, 23, 37, 0.12);
    }}

    .hero-shot img,
    .thumb img {{
      display: block;
      width: 100%;
      height: 100%;
      object-fit: contain;
    }}

    .thumb-grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
      min-height: 0;
    }}

    .examples {{
      width: 1600px;
      height: 980px;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 30px;
      padding: 72px;
      background: var(--canvas);
    }}

    .example-card {{
      min-width: 0;
      min-height: 0;
      display: grid;
      place-items: center;
      padding: 28px;
      border-radius: 18px;
      background: var(--paper);
    }}

    .example-card img {{
      display: block;
      width: 100%;
      height: 100%;
      object-fit: contain;
    }}
  </style>
</head>
<body>
{body}
</body>
</html>
"""
    path = BUILD_DIR / filename
    path.write_text(html)
    return path


def render(html_path: Path, output: Path, selector: str) -> None:
    subprocess.run(
        ["node", str(RENDER_SCRIPT), str(html_path), str(output), selector],
        cwd=ROOT,
        check=True,
    )


def build_cover() -> None:
    body = f"""
<main class="cover capture">
  <section class="cover-copy">
    <div>
      <h1>Liveline Swift</h1>
      <p class="dek">Native SwiftUI charts for live data.</p>
      <p class="summary">Line, candlestick, and multi-series rendering captured from deterministic iOS Storybook scenarios.</p>
      <div class="facts" aria-label="Liveline capabilities">
        <div class="fact"><span>Renderer</span><strong>SwiftUI Canvas</strong></div>
        <div class="fact"><span>Modes</span><strong>Line / Candle / Multi-series</strong></div>
        <div class="fact"><span>States</span><strong>Scrub · live badge · loading · empty</strong></div>
      </div>
    </div>
    <div class="runtime"><code>iOS 16+ / Swift 5.9+</code><span>No WebView. No JavaScript bridge.</span></div>
  </section>
  <section class="cover-visual" aria-label="Liveline chart examples">
    <div class="cover-stage">
      <div class="hero-shot"><img src="{image_src('line-basic-dark.png')}" alt="" /></div>
      <div class="thumb-grid">
        <div class="thumb"><img src="{image_src('candle-basic.png')}" alt="" /></div>
        <div class="thumb"><img src="{image_src('multi-basic.png')}" alt="" /></div>
      </div>
    </div>
  </section>
</main>
"""
    html = write_html("cover.html", body)
    render(html, OUT_DIR / "cover.png", ".capture")


def build_examples() -> None:
    cards = "\n".join(
        f'<figure class="example-card"><img src="{image_src(slug + ".png")}" alt="" /></figure>'
        for slug in EXAMPLES
    )
    html = write_html("examples.html", f'<main class="examples capture">{cards}</main>')
    render(html, OUT_DIR / "examples.png", ".capture")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    for slug in EXAMPLES:
        save_panel(slug)
    build_cover()
    build_examples()


if __name__ == "__main__":
    main()
