import React from 'react';
import {Img, staticFile, useCurrentFrame} from 'remotion';

// Frame sequences exported by the scratch ShotGen package through Liveline's
// own public `LivelineChartImageExporter` — one PNG per video frame, with the
// chart's data advanced by one sample between frames. This is authentic
// library output, not a recreation: every pixel came out of the renderer that
// ships in the package.
//
// Every clip is rendered in the LIGHT theme (`theme: .automatic` resolved
// against `colorScheme: .light`) to match this cut's chrome. `line-dark` is the
// single exception: the theming scene cross-dissolves it over `line-live` to
// show `.automatic` following the system, and both are the same stream at the
// same elapsed time, so only the palette moves across the dissolve.
//
// Regenerate with:
//   cd remotion/tools/shotgen
//   SHOTGEN_MODE=frames \
//     SHOTGEN_CLIPS_OUT="$PWD/../../public/clips" \
//     swift run ShotGen
//
// Pass SHOTGEN_CLIPS_OUT explicitly: the tool's default output path is derived
// from `#filePath`, which SwiftPM hands over as a *relative* path when the build
// runs from the package directory, so the default silently lands in
// remotion/remotion/public/clips instead.
export const CLIP_FRAMES = {
  'line-live': 120,
  'line-dark': 90,
  annotations: 120,
  histogram: 90,
  streamgraph: 90,
  treemap: 75,
  sunburst: 75,
  sankey: 75,
  bullet: 60,
  rtl: 60,
  'dynamic-type': 45,
  legend: 75,
} as const;

export type ClipName = keyof typeof CLIP_FRAMES;

/// Every clip is exported at 800x450pt @2x.
export const CLIP_WIDTH = 1600;
export const CLIP_HEIGHT = 900;

export type ClipLoop = 'pingpong' | 'loop' | 'hold';

/// Clips are shorter than some scenes. `pingpong` is the default because the
/// breathing categorical charts read identically played backwards, while a
/// forward wrap would cut. Scrolling line clips are always given scenes no
/// longer than the clip, so they never need to wrap at all.
export const clipFrameIndex = (name: ClipName, frame: number, loop: ClipLoop): number => {
  const total = CLIP_FRAMES[name];
  const f = Math.max(0, Math.round(frame));
  if (loop === 'hold') return Math.min(f, total - 1);
  if (loop === 'loop') return f % total;
  const period = Math.max(1, 2 * total - 2);
  const phase = f % period;
  return phase < total ? phase : period - phase;
};

export const clipSrc = (name: ClipName, index: number): string =>
  staticFile(`clips/${name}/frame-${String(index).padStart(3, '0')}.png`);

export const Clip: React.FC<{
  name: ClipName;
  loop?: ClipLoop;
  offset?: number;
  style?: React.CSSProperties;
}> = ({name, loop = 'pingpong', offset = 0, style}) => {
  const frame = useCurrentFrame();
  const index = clipFrameIndex(name, frame + offset, loop);
  return (
    <Img
      src={clipSrc(name, index)}
      style={{display: 'block', width: '100%', height: '100%', objectFit: 'cover', ...style}}
    />
  );
};
