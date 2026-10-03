#!/usr/bin/env python3
"""Build legible contact sheets from full-resolution chart captures."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = (
    ROOT / "Examples" / "LivelineDemo" / "Resources" / "storybook-scenarios.json"
)
DEFAULT_DIRECTORIES = (
    ROOT / "Media" / "storybook-chart-only",
    ROOT / "Media" / "storybook-new-charts",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build chart visual-review contact sheets.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--directory", action="append", type=Path, dest="directories")
    parser.add_argument("--out-dir", type=Path, default=ROOT / ".build" / "chart-review-board")
    parser.add_argument("--scenarios", nargs="+")
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--crop-x", type=int, default=48)
    parser.add_argument("--crop-y", type=int, default=234)
    parser.add_argument("--crop-width", type=int, default=1110)
    parser.add_argument("--crop-height", type=int, default=864)
    return parser.parse_args()


def font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            pass
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    manifest_ids = [entry["id"] for entry in manifest]
    scenarios = args.scenarios or manifest_ids
    directories = args.directories or list(DEFAULT_DIRECTORIES)

    screenshots: dict[str, Path] = {}
    for directory in directories:
        for path in directory.glob("*.png"):
            if path.stem in screenshots:
                raise SystemExit(f"Duplicate screenshot owner for {path.stem}")
            screenshots[path.stem] = path
    missing = [scenario for scenario in scenarios if scenario not in screenshots]
    if missing:
        raise SystemExit(f"Missing screenshots: {missing}")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    columns = max(args.columns, 1)
    rows = max(args.rows, 1)
    per_page = columns * rows
    cell_width = 600
    image_width = 555
    image_height = round(args.crop_height * image_width / args.crop_width)
    label_height = 52
    cell_height = image_height + label_height
    page_count = math.ceil(len(scenarios) / per_page)
    label_font = font(24)

    for page_index in range(page_count):
        page = Image.new(
            "RGB",
            (columns * cell_width, rows * cell_height),
            (12, 12, 15),
        )
        draw = ImageDraw.Draw(page)
        page_scenarios = scenarios[
            page_index * per_page : (page_index + 1) * per_page
        ]
        for offset, scenario in enumerate(page_scenarios):
            row, column = divmod(offset, columns)
            source = Image.open(screenshots[scenario]).convert("RGB")
            crop = source.crop(
                (
                    args.crop_x,
                    args.crop_y,
                    args.crop_x + args.crop_width,
                    args.crop_y + args.crop_height,
                )
            )
            crop.thumbnail(
                (image_width, image_height),
                Image.Resampling.LANCZOS,
            )
            x = column * cell_width + (cell_width - crop.width) // 2
            y = row * cell_height + label_height
            page.paste(crop, (x, y))
            draw.text(
                (column * cell_width + 20, row * cell_height + 13),
                scenario,
                fill=(242, 242, 247),
                font=label_font,
            )
        page.save(args.out_dir / f"review-{page_index + 1:02d}.png")

    print(f"Built {page_count} review board(s) for {len(scenarios)} scenarios in {args.out_dir}")


if __name__ == "__main__":
    main()
