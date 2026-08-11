import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {ChartCard, SceneShell, fontMono, prColors} from './shared';

export const AdvancedHeroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <SceneShell accent={prColors.violet}>
      <AbsoluteFill style={{opacity: 0.58}}>
        <ChartCard src="contour-basic.png" label="CONTOUR" width={520} height={404} left={-80} top={-90} rotate={-6} driftX={22} />
        <ChartCard src="violin-basic.png" label="VIOLIN" width={500} height={389} left={1410} top={-60} rotate={7} delay={4} driftX={-18} />
        <ChartCard src="chord-basic.png" label="CHORD" width={540} height={420} left={-130} top={760} rotate={5} delay={8} driftX={18} driftY={-18} />
        <ChartCard src="market-depth-basic.png" label="MARKET DEPTH" width={560} height={435} left={1450} top={748} rotate={-6} delay={12} driftX={-24} driftY={-18} />
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background:
            'radial-gradient(760px 500px at 50% 50%, rgba(5,7,12,0.62), rgba(5,7,12,0.96) 78%)',
        }}
      />
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
        <Interactive.Div
          name="PR title"
          style={{
            textAlign: 'center',
            opacity: interpolate(frame, [0, 15, durationInFrames - 10, durationInFrames], [0, 1, 1, 0], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            scale: interpolate(frame, [0, 24], [0.94, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.spring({damping: 200}),
              output: 'perceptual-scale',
            }),
          }}
        >
          <div style={{fontFamily: fontMono, fontSize: 25, fontWeight: 700, letterSpacing: '0.12em', color: prColors.cyan}}>
            LIVELINE SWIFT · PR #6
          </div>
          <div style={{fontSize: 136, lineHeight: 0.9, fontWeight: 780, letterSpacing: '-0.065em', color: prColors.text, marginTop: 24}}>
            21 new<br />chart families
          </div>
          <div style={{fontSize: 38, color: prColors.secondary, fontWeight: 520, marginTop: 30}}>
            Native. Animated. Accessible. Dither-ready.
          </div>
        </Interactive.Div>
      </AbsoluteFill>
    </SceneShell>
  );
};
