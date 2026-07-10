#!/usr/bin/env python3
import argparse
import csv
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def parse_args():
    parser = argparse.ArgumentParser(description="Diff upstream web references against native Swift storybook captures.")
    parser.add_argument("--web-dir", default="Media/web-reference", help="Directory containing upstream reference PNGs.")
    parser.add_argument("--native-dir", default="Media/storybook-chart-only", help="Directory containing full native chart-only PNGs.")
    parser.add_argument("--out-dir", default="Media/storybook-diff", help="Directory for side-by-side diff PNGs and summary.csv.")
    parser.add_argument("--crop-x", type=int, default=48, help="Native screenshot crop origin x in device pixels.")
    parser.add_argument("--crop-y", type=int, default=234, help="Native screenshot crop origin y in device pixels.")
    parser.add_argument("--pixel-threshold", type=int, default=2, help="Per-channel delta treated as a changed pixel.")
    parser.add_argument(
        "--exclude-scenarios",
        default="",
        help="Comma-separated scenario IDs excluded from upstream parity thresholds.",
    )
    parser.add_argument("--fail-changed-pct", type=float, default=None, help="Fail when any scenario exceeds this changed-pixel percentage.")
    parser.add_argument("--fail-rms", type=float, default=None, help="Fail when any scenario exceeds this RGB RMS delta.")
    return parser.parse_args()


def changed_percent(diff, threshold):
    masks = []
    for channel in diff.split():
        masks.append(channel.point(lambda value: 255 if value > threshold else 0))
    mask = masks[0]
    for channel_mask in masks[1:]:
        mask = ImageChops.lighter(mask, channel_mask)
    histogram = mask.histogram()
    changed = sum(histogram[1:])
    return changed / (mask.width * mask.height) * 100


def diff_metrics(reference, native, threshold):
    diff = ImageChops.difference(reference, native)
    stat = ImageStat.Stat(diff)
    mean_abs = sum(stat.mean) / len(stat.mean)
    rms = math.sqrt(sum(value * value for value in stat.rms) / len(stat.rms))
    max_delta = max(channel[1] for channel in diff.getextrema())
    changed = changed_percent(diff, threshold)
    return diff, {
        "changed_pct": changed,
        "mean_abs": mean_abs,
        "rms": rms,
        "max_delta": max_delta,
    }


def heatmap(diff):
    return diff.point(lambda value: min(255, value * 8))


def save_panel(path, reference, native, diff):
    gap = 12
    width = reference.width * 3 + gap * 2
    height = reference.height
    panel = Image.new("RGB", (width, height), "white")
    panel.paste(reference, (0, 0))
    panel.paste(native, (reference.width + gap, 0))
    panel.paste(heatmap(diff), ((reference.width + gap) * 2, 0))
    panel.save(path)


def main():
    args = parse_args()
    web_dir = Path(args.web_dir)
    native_dir = Path(args.native_dir)
    out_dir = Path(args.out_dir)
    excluded_scenarios = {
        scenario.strip()
        for scenario in args.exclude_scenarios.split(",")
        if scenario.strip()
    }

    if not web_dir.exists():
        raise SystemExit(f"Missing web reference directory: {web_dir}")
    if not native_dir.exists():
        raise SystemExit(f"Missing native screenshot directory: {native_dir}")

    out_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for reference_path in sorted(web_dir.glob("*.png")):
        if reference_path.stem in excluded_scenarios:
            rows.append({
                "scenario": reference_path.stem,
                "status": "excluded-intentional-layout",
                "width": "",
                "height": "",
                "changed_pct": "",
                "mean_abs": "",
                "rms": "",
                "max_delta": "",
            })
            continue

        native_path = native_dir / reference_path.name
        if not native_path.exists():
            rows.append({
                "scenario": reference_path.stem,
                "status": "missing-native",
                "width": "",
                "height": "",
                "changed_pct": "",
                "mean_abs": "",
                "rms": "",
                "max_delta": "",
            })
            continue

        reference = Image.open(reference_path).convert("RGB")
        full_native = Image.open(native_path).convert("RGB")
        crop_box = (
            args.crop_x,
            args.crop_y,
            args.crop_x + reference.width,
            args.crop_y + reference.height,
        )
        if crop_box[2] > full_native.width or crop_box[3] > full_native.height:
            rows.append({
                "scenario": reference_path.stem,
                "status": "crop-out-of-bounds",
                "width": reference.width,
                "height": reference.height,
                "changed_pct": "",
                "mean_abs": "",
                "rms": "",
                "max_delta": "",
            })
            continue

        native = full_native.crop(crop_box)
        diff, metrics = diff_metrics(reference, native, args.pixel_threshold)
        save_panel(out_dir / reference_path.name, reference, native, diff)
        rows.append({
            "scenario": reference_path.stem,
            "status": "ok",
            "width": reference.width,
            "height": reference.height,
            "changed_pct": metrics["changed_pct"],
            "mean_abs": metrics["mean_abs"],
            "rms": metrics["rms"],
            "max_delta": metrics["max_delta"],
        })

    summary_path = out_dir / "summary.csv"
    with summary_path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["scenario", "status", "width", "height", "changed_pct", "mean_abs", "rms", "max_delta"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)

    sortable = [row for row in rows if row["status"] == "ok"]
    sortable.sort(key=lambda row: row["changed_pct"], reverse=True)

    print(f"Diff summary written to {summary_path}")
    print("scenario,status,changed_pct,mean_abs,rms,max_delta")
    for row in sortable[:12]:
        print(
            f"{row['scenario']},{row['status']},"
            f"{row['changed_pct']:.3f},{row['mean_abs']:.3f},"
            f"{row['rms']:.3f},{row['max_delta']}"
        )
    for row in rows:
        if row["status"] != "ok":
            print(f"{row['scenario']},{row['status']},,,,")

    failed = []
    for row in sortable:
        if args.fail_changed_pct is not None and row["changed_pct"] > args.fail_changed_pct:
            failed.append(row["scenario"])
        if args.fail_rms is not None and row["rms"] > args.fail_rms:
            failed.append(row["scenario"])

    if failed:
        unique = ", ".join(sorted(set(failed)))
        raise SystemExit(f"Diff thresholds exceeded for: {unique}")


if __name__ == "__main__":
    main()
