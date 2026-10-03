import React from 'react';
import {Easing, Interactive, interpolate, useCurrentFrame} from 'remotion';
import {LightSceneShell, fontMono, prColors} from './shared';

export const AdvancedHeroScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <LightSceneShell accent={prColors.blue}>
      <Interactive.Div
        name="Pull request label"
        style={{
          position: 'absolute',
          left: 100,
          top: 94,
          padding: '12px 18px',
          borderRadius: 999,
          backgroundColor: `${prColors.blue}10`,
          border: `1px solid ${prColors.blue}32`,
          color: prColors.blue,
          fontFamily: fontMono,
          fontSize: 20,
          fontWeight: 750,
          letterSpacing: '0.08em',
          opacity: interpolate(frame, [0, 14], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        LIVELINE SWIFT
      </Interactive.Div>
      <Interactive.Div
        name="Hero headline"
        style={{
          position: 'absolute',
          left: 96,
          top: 230,
          width: 1250,
          color: prColors.ink,
          fontSize: 142,
          fontWeight: 810,
          letterSpacing: '-0.065em',
          lineHeight: 0.91,
          opacity: interpolate(frame, [5, 24], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: interpolate(frame, [5, 28], ['0px 32px', '0px 0px'], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        21 new charts.
        <br />
        Built to move.
      </Interactive.Div>
      <Interactive.Div
        name="Hero summary"
        style={{
          position: 'absolute',
          left: 104,
          bottom: 112,
          width: 980,
          color: prColors.muted,
          fontSize: 38,
          fontWeight: 520,
          lineHeight: 1.28,
          opacity: interpolate(frame, [22, 40], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        Native SwiftUI. Live data. Every chart.
      </Interactive.Div>
      <Interactive.Div
        name="Total family metric"
        style={{
          position: 'absolute',
          right: 112,
          bottom: 100,
          width: 430,
          padding: '38px 40px',
          borderRadius: 30,
          border: `1px solid ${prColors.border}`,
          backgroundColor: 'rgba(255,255,255,0.88)',
          boxShadow: '0 24px 70px rgba(42,65,98,0.13)',
          opacity: interpolate(frame, [28, 48], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [28, 52], [0.92, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.spring({damping: 200}),
            output: 'perceptual-scale',
          }),
        }}
      >
        <div style={{fontSize: 96, fontWeight: 810, letterSpacing: '-0.06em', color: prColors.blue}}>48</div>
        <div style={{fontSize: 25, fontWeight: 650, color: prColors.muted}}>native chart families total</div>
      </Interactive.Div>
    </LightSceneShell>
  );
};
