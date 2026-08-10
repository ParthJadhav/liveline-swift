#!/usr/bin/env python3
"""Validate the deterministic screenshot contract for every Storybook chart."""

from __future__ import annotations

import argparse
import binascii
import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = (
    ROOT
    / "Examples"
    / "LivelineDemo"
    / "Resources"
    / "storybook-scenarios.json"
)
DEFAULT_DIRECTORIES = (
    ROOT / "Media" / "storybook-chart-only",
    ROOT / "Media" / "storybook-new-charts",
)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Validate exact scenario coverage, PNG integrity, dimensions, and "
            "minimum evidence size for deterministic chart screenshots."
        )
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument(
        "--directory",
        action="append",
        type=Path,
        dest="directories",
        help="Screenshot directory. Repeat to validate a split baseline set.",
    )
    parser.add_argument(
        "--scenarios",
        nargs="+",
        help="Optional scenario IDs for a partial capture; defaults to the full manifest.",
    )
    parser.add_argument("--width", type=int, default=1206)
    parser.add_argument("--height", type=int, default=2622)
    parser.add_argument(
        "--minimum-bytes",
        type=int,
        default=16_384,
        help="Reject suspiciously empty captures below this byte size.",
    )
    return parser.parse_args()


def manifest_ids(path: Path) -> list[str]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return [entry["id"] for entry in payload]


def validate_png(path: Path, expected_size: tuple[int, int], minimum_bytes: int) -> None:
    if path.stat().st_size < minimum_bytes:
        raise ValueError(
            f"{path} is only {path.stat().st_size} bytes; the capture is probably blank"
        )

    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path} does not have a PNG signature")

    offset = len(PNG_SIGNATURE)
    dimensions: tuple[int, int] | None = None
    saw_image_data = False
    saw_end = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError(f"{path} has a truncated PNG chunk")
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_end = offset + 12 + length
        if chunk_end > len(data):
            raise ValueError(f"{path} has a truncated {chunk_type!r} chunk")
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length : chunk_end])[0]
        actual_crc = binascii.crc32(chunk_type)
        actual_crc = binascii.crc32(payload, actual_crc) & 0xFFFF_FFFF
        if actual_crc != expected_crc:
            raise ValueError(f"{path} has a corrupt {chunk_type!r} chunk")

        if chunk_type == b"IHDR":
            if length != 13:
                raise ValueError(f"{path} has an invalid IHDR length")
            width, height, bit_depth, color_type, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", payload)
            )
            dimensions = (width, height)
            if bit_depth != 8 or color_type not in {2, 6}:
                raise ValueError(
                    f"{path} must be an 8-bit RGB/RGBA capture, got "
                    f"bit_depth={bit_depth} color_type={color_type}"
                )
            if compression != 0 or filtering != 0 or interlace != 0:
                raise ValueError(f"{path} uses an unsupported PNG encoding")
        elif chunk_type == b"IDAT":
            saw_image_data = saw_image_data or bool(payload)
        elif chunk_type == b"IEND":
            saw_end = True
            if length != 0 or chunk_end != len(data):
                raise ValueError(f"{path} has malformed data after IEND")
            break
        offset = chunk_end

    if dimensions != expected_size:
        raise ValueError(f"{path} is {dimensions}; expected {expected_size}")
    if not saw_image_data or not saw_end:
        raise ValueError(f"{path} is missing required PNG image data")


def main() -> None:
    args = parse_args()
    all_ids = manifest_ids(args.manifest)
    requested = args.scenarios or all_ids
    if len(requested) != len(set(requested)):
        raise SystemExit("Requested scenario IDs must be unique")
    unknown = sorted(set(requested) - set(all_ids))
    if unknown:
        raise SystemExit(f"Unknown scenario IDs: {unknown}")

    directories = args.directories or list(DEFAULT_DIRECTORIES)
    missing_directories = [str(path) for path in directories if not path.is_dir()]
    if missing_directories:
        raise SystemExit(f"Missing screenshot directories: {missing_directories}")

    screenshots: dict[str, Path] = {}
    duplicates: dict[str, list[Path]] = {}
    for directory in directories:
        for path in directory.glob("*.png"):
            if path.stem in screenshots:
                duplicates.setdefault(path.stem, [screenshots[path.stem]]).append(path)
            else:
                screenshots[path.stem] = path
    if duplicates:
        detail = {key: [str(path) for path in value] for key, value in duplicates.items()}
        raise SystemExit(f"Scenario screenshots must have one owner: {detail}")

    expected = set(requested)
    actual = set(screenshots)
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if missing or unexpected:
        raise SystemExit(
            f"Screenshot set mismatch; missing={missing}, unexpected={unexpected}"
        )

    errors: list[str] = []
    expected_size = (args.width, args.height)
    for scenario in requested:
        try:
            validate_png(screenshots[scenario], expected_size, args.minimum_bytes)
        except ValueError as error:
            errors.append(str(error))
    if errors:
        raise SystemExit("Invalid chart screenshots:\n- " + "\n- ".join(errors))

    joined = ", ".join(str(path) for path in directories)
    print(
        f"Validated {len(requested)} chart screenshots at "
        f"{args.width}x{args.height} across {joined}"
    )


if __name__ == "__main__":
    main()
