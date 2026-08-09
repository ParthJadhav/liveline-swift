import React from 'react';
import {
  AbsoluteFill,
  Easing,
  Img,
  Interactive,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

export const colors = {
  background: '#070b14',
  surface: '#0f1624',
  border: 'rgba(255,255,255,0.13)',
  text: '#f5f7fb',
  secondary: '#a9b1c1',
  blue: '#1687ff',
  cyan: '#22d3ee',
  green: '#22c55e',
};

export const SceneFrame: React.FC<{
  eyebrow: string;
  title: string;
  summary: string;
  children: React.ReactNode;
}> = ({eyebrow, title, summary, children}) => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();

  return (
    <AbsoluteFill style={{backgroundColor: colors.background, fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif'}}>
      <AbsoluteFill
        style={{
          background: 'radial-gradient(900px 620px at 82% 20%, rgba(22,135,255,0.14), transparent 72%)',
        }}
      />
      <Interactive.Div
        name="Scene copy"
        style={{
          position: 'absolute',
          left: 84,
          top: 72,
          width: 620,
          opacity: interpolate(frame, [0, 14, durationInFrames - 14, durationInFrames], [0, 1, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [0, 18], ['0px 22px', '0px 0px'], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <div style={{fontSize: 24, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase', color: colors.cyan}}>
          {eyebrow}
        </div>
        <div style={{fontSize: 76, lineHeight: 0.98, fontWeight: 720, letterSpacing: '-0.045em', color: colors.text, marginTop: 18}}>
          {title}
        </div>
        <div style={{fontSize: 34, lineHeight: 1.28, fontWeight: 480, color: colors.secondary, marginTop: 24}}>
          {summary}
        </div>
      </Interactive.Div>
      <Interactive.Div
        name="Scene visual"
        style={{
          position: 'absolute',
          left: 760,
          right: 80,
          top: 64,
          bottom: 64,
          opacity: interpolate(frame, [4, 22], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [4, 24], [0.96, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.spring({damping: 200}),
            output: 'perceptual-scale',
          }),
        }}
      >
        {children}
      </Interactive.Div>
      <div style={{position: 'absolute', left: 84, bottom: 58, fontSize: 22, color: '#697386', letterSpacing: '0.04em'}}>
        LIVELINE · SWIFTUI
      </div>
    </AbsoluteFill>
  );
};

export const Screenshot: React.FC<{
  src: string;
  width: number;
  height: number;
  left?: number;
  top?: number;
  rotate?: number;
}> = ({src, width, height, left = 0, top = 0, rotate = 0}) => (
  <div
    style={{
      position: 'absolute',
      left,
      top,
      width,
      height,
      overflow: 'hidden',
      borderRadius: 38,
      border: `2px solid ${colors.border}`,
      backgroundColor: '#000',
      boxShadow: '0 28px 80px rgba(0,0,0,0.36)',
      rotate: `${rotate}deg`,
    }}
  >
    <Img src={staticFile(src)} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
  </div>
);

export const FactList: React.FC<{items: string[]; width?: number; fontSize?: number}> = ({items, width, fontSize = 30}) => (
  <div style={{display: 'flex', flexDirection: 'column', gap: 18, width}}>
    {items.map((item) => (
      <div key={item} style={{display: 'flex', alignItems: 'flex-start', gap: 16, color: colors.text, fontSize, lineHeight: 1.15, fontWeight: 600}}>
        <span style={{display: 'block', width: 12, height: 12, borderRadius: 6, backgroundColor: colors.green}} />
        {item}
      </div>
    ))}
  </div>
);
