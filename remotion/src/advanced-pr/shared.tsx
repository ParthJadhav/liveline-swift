import React from 'react';
import {AbsoluteFill, Interactive} from 'remotion';

export const prColors = {
  canvas: '#f5f8fd',
  canvasWarm: '#fffdf8',
  surface: '#ffffff',
  ink: '#111827',
  muted: '#5f6c80',
  subtle: '#8b98aa',
  border: '#dce5f0',
  blue: '#2f7df4',
  cyan: '#08a9c2',
  violet: '#8157e8',
  green: '#18a765',
  orange: '#e96b1f',
  red: '#e5484d',
};

export const fontSans =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", sans-serif';
export const fontMono = '"SF Mono", ui-monospace, Menlo, monospace';

export const LightSceneShell: React.FC<{
  accent: string;
  children: React.ReactNode;
}> = ({accent, children}) => (
  <AbsoluteFill style={{backgroundColor: prColors.canvas, fontFamily: fontSans, overflow: 'hidden'}}>
    <AbsoluteFill
      style={{
        background: `radial-gradient(880px 620px at 86% 12%, ${accent}1c, transparent 72%), radial-gradient(720px 620px at 8% 94%, #ffffff, transparent 72%)`,
      }}
    />
    <AbsoluteFill
      style={{
        opacity: 0.42,
        backgroundImage:
          'linear-gradient(rgba(54,75,104,0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(54,75,104,0.035) 1px, transparent 1px)',
        backgroundSize: '72px 72px',
      }}
    />
    {children}
  </AbsoluteFill>
);

export const SceneProgress: React.FC<{
  current: number;
  total?: number;
  accent: string;
}> = ({current, total = 21, accent}) => (
  <div
    style={{
      position: 'absolute',
      left: 88,
      right: 88,
      bottom: 46,
      display: 'flex',
      alignItems: 'center',
      gap: 20,
    }}
  >
    <div
      style={{
        width: 100,
        color: prColors.subtle,
        fontFamily: fontMono,
        fontSize: 20,
        fontWeight: 700,
      }}
    >
      {String(current).padStart(2, '0')} / {String(total).padStart(2, '0')}
    </div>
    <div style={{height: 4, flex: 1, borderRadius: 999, overflow: 'hidden', backgroundColor: '#dfe7f1'}}>
      <div
        style={{
          width: `${(current / total) * 100}%`,
          height: '100%',
          borderRadius: 999,
          backgroundColor: accent,
        }}
      />
    </div>
  </div>
);

export const SceneLabel: React.FC<{
  group: string;
  accent: string;
}> = ({group, accent}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      padding: '10px 16px',
      borderRadius: 999,
      border: `1px solid ${accent}38`,
      backgroundColor: `${accent}0d`,
      color: accent,
      fontFamily: fontMono,
      fontSize: 19,
      fontWeight: 720,
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
    }}
  >
    <span style={{width: 9, height: 9, borderRadius: 99, backgroundColor: accent}} />
    {group}
  </div>
);

export const AnimatedSceneCopy: React.FC<{
  eyebrow: string;
  title: string;
  detail: string;
  accent: string;
}> = ({eyebrow, title, detail, accent}) => {
  return (
    <Interactive.Div
      name="Chart description"
      style={{
        position: 'absolute',
        left: 88,
        top: 180,
        width: 600,
      }}
    >
      <SceneLabel group={eyebrow} accent={accent} />
      <div
        style={{
          marginTop: 30,
          color: prColors.ink,
          fontSize: 96,
          fontWeight: 790,
          letterSpacing: '-0.055em',
          lineHeight: 0.96,
        }}
      >
        {title}
      </div>
      <div
        style={{
          marginTop: 24,
          color: prColors.muted,
          fontSize: 38,
          fontWeight: 560,
          lineHeight: 1.2,
        }}
      >
        {detail}
      </div>
    </Interactive.Div>
  );
};
