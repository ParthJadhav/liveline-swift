#!/usr/bin/env python3
"""Generate the reproducible upbeat music bed for the advanced-chart PR demo."""

from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
import torch
from transformers import AutoProcessor, MusicgenForConditionalGeneration


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
OUTPUT = REPOSITORY_ROOT / "remotion/public/audio/advanced-pr-upbeat.m4a"
MODEL = "facebook/musicgen-small"
PROMPT = (
    "Bright upbeat kinetic technology launch music, 126 BPM, crisp electronic drums, "
    "playful marimba-like synth plucks, warm bass, optimistic clean arpeggios, polished "
    "product demo energy, instrumental, no vocals, no cinematic ambience"
)
SEED = 20_260_811


def main() -> None:
    torch.manual_seed(SEED)
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    processor = AutoProcessor.from_pretrained(MODEL, local_files_only=True)
    model = MusicgenForConditionalGeneration.from_pretrained(MODEL, local_files_only=True)
    model = model.to(device)

    inputs = processor(text=[PROMPT], padding=True, return_tensors="pt")
    inputs = {key: value.to(device) for key, value in inputs.items()}
    with torch.inference_mode():
        audio = model.generate(
            **inputs,
            do_sample=True,
            guidance_scale=3.2,
            max_new_tokens=1_500,
        )

    waveform = audio[0, 0].detach().float().cpu().numpy()
    waveform = waveform / max(float(np.max(np.abs(waveform))), 1e-6)
    sample_rate = model.config.audio_encoder.sampling_rate

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="liveline-advanced-pr-bgm-") as temporary_directory:
        wav_path = Path(temporary_directory) / "musicgen.wav"
        pcm = (waveform * 32_767).astype(np.int16)
        with wave.open(str(wav_path), "wb") as wav_output:
            wav_output.setnchannels(1)
            wav_output.setsampwidth(2)
            wav_output.setframerate(sample_rate)
            wav_output.writeframes(pcm.tobytes())
        subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                str(wav_path),
                "-af",
                "loudnorm=I=-18:LRA=7:TP=-1.5,afade=t=in:st=0:d=0.25,afade=t=out:st=29:d=0.8",
                "-ar",
                "48000",
                "-ac",
                "2",
                "-c:a",
                "aac",
                "-b:a",
                "192k",
                str(OUTPUT),
            ],
            check=True,
        )

    print(f"Generated {OUTPUT.relative_to(REPOSITORY_ROOT)}")


if __name__ == "__main__":
    main()
