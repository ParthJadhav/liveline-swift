import React from 'react';
import {Easing, Interactive, interpolate, useCurrentFrame} from 'remotion';
import {LightSceneShell, fontMono, prColors} from './shared';

export const AdvancedClosingScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <LightSceneShell accent={prColors.violet}>
      <Interactive.Div
        name="Closing statement"
        style={{
          position: 'absolute',
          left: 110,
          top: 150,
          width: 1380,
          opacity: interpolate(frame, [0, 20], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [0, 24], ['0px 30px', '0px 0px'], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <div style={{fontFamily: fontMono, fontSize: 23, fontWeight: 750, color: prColors.violet, letterSpacing: '0.09em'}}>
          LIVELINE SWIFT · ADVANCED CHART CATALOG
        </div>
        <div style={{marginTop: 36, color: prColors.ink, fontSize: 142, lineHeight: 0.92, fontWeight: 820, letterSpacing: '-0.067em'}}>
          21 new families.
          <br />48 native charts.
        </div>
        <div style={{marginTop: 42, color: prColors.muted, fontSize: 40, fontWeight: 520, lineHeight: 1.3}}>
          Typed APIs, native interaction, VoiceOver, Audio Graphs, light and dark themes, plus universal Dither rendering.
        </div>
      </Interactive.Div>
      <Interactive.Div
        name="Closing pull request"
        style={{
          position: 'absolute',
          left: 110,
          bottom: 110,
          display: 'flex',
          alignItems: 'center',
          gap: 18,
          padding: '18px 24px',
          borderRadius: 18,
          backgroundColor: prColors.surface,
          border: `1px solid ${prColors.border}`,
          color: prColors.ink,
          fontFamily: fontMono,
          fontSize: 25,
          fontWeight: 720,
          opacity: interpolate(frame, [24, 44], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <span style={{width: 13, height: 13, borderRadius: 99, backgroundColor: prColors.green}} />
        github.com/ParthJadhav/liveline-swift · PR #6
      </Interactive.Div>
    </LightSceneShell>
  );
};
