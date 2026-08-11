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

export const prColors = {
  background: '#05070c',
  surface: '#0c111b',
  surfaceStrong: '#111827',
  border: 'rgba(255,255,255,0.12)',
  text: '#f7f8fb',
  secondary: '#9aa6b8',
  blue: '#3b82f6',
  cyan: '#22d3ee',
  violet: '#8b5cf6',
  green: '#22c55e',
  orange: '#f97316',
  red: '#ef4444',
};

export const fontSans =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", sans-serif';
export const fontMono = '"SF Mono", ui-monospace, Menlo, monospace';

export const SceneShell: React.FC<{
  accent?: string;
  children: React.ReactNode;
}> = ({accent = prColors.blue, children}) => (
  <AbsoluteFill style={{backgroundColor: prColors.background, fontFamily: fontSans}}>
    <AbsoluteFill
      style={{
        background: `radial-gradient(980px 680px at 76% 28%, ${accent}22, transparent 72%)`,
      }}
    />
    <AbsoluteFill
      style={{
        opacity: 0.14,
        backgroundImage:
          'linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px)',
        backgroundSize: '64px 64px',
      }}
    />
    {children}
  </AbsoluteFill>
);

export const SceneCopy: React.FC<{
  eyebrow: string;
  title: string;
  summary: string;
  accent?: string;
  width?: number;
}> = ({eyebrow, title, summary, accent = prColors.cyan, width = 660}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <Interactive.Div
      name="Scene copy"
      style={{
        position: 'absolute',
        left: 86,
        top: 78,
        width,
        opacity: interpolate(
          frame,
          [0, 16, durationInFrames - 12, durationInFrames],
          [0, 1, 1, 0],
          {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          },
        ),
        translate: interpolate(frame, [0, 20], ['0px 22px', '0px 0px'], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      <div
        style={{
          color: accent,
          fontSize: 24,
          fontWeight: 720,
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
        }}
      >
        {eyebrow}
      </div>
      <div
        style={{
          color: prColors.text,
          fontSize: 88,
          fontWeight: 760,
          letterSpacing: '-0.05em',
          lineHeight: 0.96,
          marginTop: 18,
        }}
      >
        {title}
      </div>
      <div
        style={{
          color: prColors.secondary,
          fontSize: 32,
          fontWeight: 500,
          lineHeight: 1.28,
          marginTop: 26,
        }}
      >
        {summary}
      </div>
    </Interactive.Div>
  );
};

export const ChartCard: React.FC<{
  src: string;
  label: string;
  width: number;
  height: number;
  delay?: number;
  accent?: string;
  left?: number;
  top?: number;
  rotate?: number;
  driftX?: number;
  driftY?: number;
  cropTop?: string;
  cropWidth?: string;
  cropLeft?: string;
}> = ({
  src,
  label,
  width,
  height,
  delay = 0,
  accent = prColors.blue,
  left = 0,
  top = 0,
  rotate = 0,
  driftX = 0,
  driftY = -10,
  cropTop = '-27.08%',
  cropWidth = '108.65%',
  cropLeft = '-4.32%',
}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <div
      style={{
        position: 'absolute',
        left,
        top,
        width,
        height,
        overflow: 'hidden',
        borderRadius: 24,
        border: `1.5px solid ${prColors.border}`,
        backgroundColor: '#07090d',
        boxShadow: `0 28px 72px rgba(0,0,0,0.42), 0 0 42px ${accent}12`,
        opacity: interpolate(frame, [delay, delay + 15], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        scale: interpolate(frame, [delay, delay + 22], [0.94, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.spring({damping: 200}),
          output: 'perceptual-scale',
        }),
        translate: interpolate(
          frame,
          [delay, Math.max(delay + 1, durationInFrames - 1)],
          ['0px 18px', `${driftX}px ${driftY}px`],
          {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.linear,
          },
        ),
        rotate: `${rotate}deg`,
      }}
    >
      <Img
        src={staticFile(`advanced-pr/${src}`)}
        style={{
          position: 'absolute',
          left: cropLeft,
          top: cropTop,
          width: cropWidth,
          height: 'auto',
          clipPath: `inset(0 ${interpolate(frame, [delay + 4, delay + 30], [100, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          })}% 0 0 round 18px)`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 18,
          top: 16,
          padding: '8px 13px',
          borderRadius: 999,
          color: prColors.text,
          backgroundColor: 'rgba(5,7,12,0.78)',
          border: `1px solid ${accent}66`,
          backdropFilter: 'blur(12px)',
          fontFamily: fontMono,
          fontSize: 17,
          fontWeight: 650,
          letterSpacing: '-0.02em',
        }}
      >
        {label}
      </div>
    </div>
  );
};

export const Metric: React.FC<{
  value: string;
  label: string;
  accent?: string;
  delay?: number;
}> = ({value, label, accent = prColors.blue, delay = 0}) => {
  const frame = useCurrentFrame();
  return (
    <div
      style={{
        opacity: interpolate(frame, [delay, delay + 14], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        translate: interpolate(frame, [delay, delay + 18], ['0px 18px', '0px 0px'], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      <div style={{fontSize: 64, fontWeight: 760, letterSpacing: '-0.05em', color: accent}}>
        {value}
      </div>
      <div style={{fontSize: 24, color: prColors.secondary, marginTop: 5}}>{label}</div>
    </div>
  );
};
