import React from 'react';
import {
  AbsoluteFill,
  AnimatedImage,
  Easing,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {SceneShell, fontMono, prColors} from './shared';

export const AdvancedDitherScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  return (
    <SceneShell accent={prColors.violet}>
      <Interactive.Div
        name="Dither copy"
        style={{
          position: 'absolute',
          left: 104,
          top: 158,
          width: 760,
          opacity: interpolate(frame, [0, 16, durationInFrames - 12, durationInFrames], [0, 1, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [0, 20], ['0px 22px', '0px 0px'], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <div style={{fontFamily: fontMono, fontSize: 25, fontWeight: 700, letterSpacing: '0.1em', color: prColors.violet}}>
          DITHER / LIVELINE
        </div>
        <div style={{fontSize: 108, lineHeight: 0.94, fontWeight: 780, letterSpacing: '-0.06em', color: prColors.text, marginTop: 26}}>
          One style.<br />Every chart.
        </div>
        <div style={{fontSize: 34, color: prColors.secondary, lineHeight: 1.35, marginTop: 30}}>
          Gradient, dotted, hatched, and solid variants — with bloom, sparkle, and Reduce Motion support.
        </div>
        <div style={{display: 'flex', gap: 14, marginTop: 34}}>
          {['GRADIENT', 'DOTTED', 'HATCHED', 'SOLID'].map((label, index) => (
            <div
              key={label}
              style={{
                padding: '10px 15px',
                borderRadius: 999,
                border: `1px solid ${prColors.violet}66`,
                background: `${prColors.violet}18`,
                color: index === 1 ? prColors.cyan : prColors.text,
                fontFamily: fontMono,
                fontSize: 17,
                fontWeight: 680,
              }}
            >
              {label}
            </div>
          ))}
        </div>
      </Interactive.Div>
      <div
        style={{
          position: 'absolute',
          right: 174,
          top: 48,
          width: 560,
          height: 986,
          borderRadius: 50,
          overflow: 'hidden',
          border: `1.5px solid ${prColors.border}`,
          boxShadow: `0 36px 100px rgba(0,0,0,0.48), 0 0 70px ${prColors.violet}22`,
          background: '#080808',
          opacity: interpolate(frame, [4, 22], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [4, 26], [0.94, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.spring({damping: 200}),
            output: 'perceptual-scale',
          }),
          rotate: '-2deg',
        }}
      >
        <AnimatedImage
          src={staticFile('advanced-pr/dither-showcase.gif')}
          style={{width: '100%', height: '100%', objectFit: 'cover'}}
        />
      </div>
    </SceneShell>
  );
};
