import React from 'react';
import {Video} from '@remotion/media';
import {Easing, Interactive, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {LightSceneShell, SceneLabel, fontMono, prColors} from './shared';

export type DitherChart = {
  id: string;
  title: string;
  variant: string;
  file: string;
  accent: string;
};

export const AdvancedDitherScene: React.FC<{
  chart: DitherChart;
  index: number;
  total: number;
}> = ({chart, index, total}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <LightSceneShell accent={chart.accent}>
      <Interactive.Div
        name="Dither description"
        style={{
          position: 'absolute',
          left: 92,
          top: 112,
          width: 620,
          opacity: interpolate(frame, [0, 14, durationInFrames - 10, durationInFrames], [0, 1, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [0, 18], ['0px 24px', '0px 0px'], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <SceneLabel group="Advanced Dither" accent={chart.accent} />
        <div style={{marginTop: 32, fontSize: 98, lineHeight: 0.95, fontWeight: 800, letterSpacing: '-0.06em', color: prColors.ink}}>
          {chart.title}
        </div>
        <div style={{marginTop: 24, color: chart.accent, fontFamily: fontMono, fontSize: 27, fontWeight: 760, letterSpacing: '0.08em'}}>
          {chart.variant.toUpperCase()} TEXTURE
        </div>
        <div style={{marginTop: 30, color: prColors.muted, fontSize: 34, fontWeight: 510, lineHeight: 1.35}}>
          Captured from the new {chart.title.toLowerCase()} renderer — animated sparkle, native geometry, and Reduce Motion support intact.
        </div>
        <div style={{marginTop: 42, fontFamily: fontMono, fontSize: 19, color: prColors.subtle}}>
          NEW IMPLEMENTATION · {String(index + 1).padStart(2, '0')} / {String(total).padStart(2, '0')}
        </div>
      </Interactive.Div>
      <Interactive.Div
        name={`${chart.title} Dither recording`}
        style={{
          position: 'absolute',
          left: 770,
          top: 110,
          width: 1050,
          height: 790,
          overflow: 'hidden',
          borderRadius: 36,
          border: `1px solid ${prColors.border}`,
          backgroundColor: '#fff',
          boxShadow: `0 34px 90px rgba(42,65,98,0.15), 0 0 0 10px ${chart.accent}09`,
          opacity: interpolate(frame, [4, 20, durationInFrames - 10, durationInFrames], [0, 1, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [4, 24], [0.95, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.spring({damping: 200}),
            output: 'perceptual-scale',
          }),
        }}
      >
        <Video
          name={`${chart.title} native Dither clip`}
          src={staticFile(`advanced-pr-light/dither/${chart.file}`)}
          muted
          objectFit="cover"
          style={{width: '100%', height: '100%'}}
        />
      </Interactive.Div>
    </LightSceneShell>
  );
};
