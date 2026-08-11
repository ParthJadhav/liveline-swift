import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Interactive,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {ChartCard, Metric, SceneShell, fontMono, prColors} from './shared';

export const AdvancedQualityScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  return (
    <SceneShell accent={prColors.cyan}>
      <ChartCard src="polar-area-basic.png" label="POLAR AREA" width={510} height={397} left={-80} top={-54} rotate={-6} accent={prColors.blue} />
      <ChartCard src="waffle-basic.png" label="WAFFLE" width={510} height={397} left={1490} top={-46} rotate={6} accent={prColors.green} delay={5} />
      <ChartCard src="point-figure-basic.png" label="POINT + FIGURE" width={520} height={404} left={-100} top={760} rotate={5} accent={prColors.red} delay={10} />
      <ChartCard src="contour-basic.png" label="CONTOUR" width={520} height={404} left={1490} top={752} rotate={-5} accent={prColors.cyan} delay={15} />
      <AbsoluteFill style={{background: 'radial-gradient(880px 600px at 50% 50%, rgba(5,7,12,0.66), rgba(5,7,12,0.97))'}} />
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
        <Interactive.Div
          name="Quality close"
          style={{
            width: 1240,
            textAlign: 'center',
            opacity: interpolate(frame, [0, 16, durationInFrames - 14, durationInFrames], [0, 1, 1, 0], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          <div style={{fontFamily: fontMono, fontSize: 24, fontWeight: 700, letterSpacing: '0.1em', color: prColors.cyan}}>
            BUILT FOR REAL APPS
          </div>
          <div style={{fontSize: 108, lineHeight: 0.95, fontWeight: 780, letterSpacing: '-0.06em', color: prColors.text, marginTop: 24}}>
            Inspectable by touch.<br />Readable by VoiceOver.
          </div>
          <div style={{display: 'flex', justifyContent: 'center', gap: 110, marginTop: 54}}>
            <Metric value="48" label="native chart families" accent={prColors.blue} delay={10} />
            <Metric value="92" label="visual scenarios" accent={prColors.violet} delay={18} />
            <Metric value="269" label="passing tests" accent={prColors.green} delay={26} />
          </div>
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 16,
              marginTop: 58,
              padding: '16px 24px',
              borderRadius: 16,
              border: `1px solid ${prColors.border}`,
              background: 'rgba(12,17,27,0.88)',
              fontFamily: fontMono,
              fontSize: 25,
              color: prColors.text,
            }}
          >
            <span style={{color: prColors.secondary}}>github.com/ParthJadhav/liveline-swift</span>
            <span style={{color: prColors.cyan}}>PR #6</span>
          </div>
        </Interactive.Div>
      </AbsoluteFill>
    </SceneShell>
  );
};
