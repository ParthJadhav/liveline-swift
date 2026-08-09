import React from 'react';
import {AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';

export const QualityScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  return (
    <AbsoluteFill style={{backgroundColor: '#070b14', alignItems: 'center', justifyContent: 'center', fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif'}}>
      <Interactive.Div
        name="Quality summary"
        style={{
          textAlign: 'center',
          opacity: interpolate(frame, [0, 16, durationInFrames - 16, durationInFrames], [0, 1, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <div style={{fontSize: 26, fontWeight: 700, color: '#22d3ee', letterSpacing: '0.09em'}}>BUILT TO SHIP</div>
        <div style={{fontSize: 100, lineHeight: 1, fontWeight: 740, color: '#f5f7fb', letterSpacing: '-0.05em', marginTop: 22}}>Smaller files.<br />Stronger guarantees.</div>
        <div style={{display: 'flex', gap: 70, justifyContent: 'center', marginTop: 52}}>
          {[
            ['252', 'package tests'],
            ['<1k', 'lines per source file'],
            ['6', 'Apple platforms'],
          ].map(([value, label]) => (
            <div key={label}>
              <div style={{fontSize: 72, fontWeight: 720, color: '#1687ff'}}>{value}</div>
              <div style={{fontSize: 26, color: '#a9b1c1', marginTop: 8}}>{label}</div>
            </div>
          ))}
        </div>
        <div style={{fontFamily: 'ui-monospace, SFMono-Regular, monospace', fontSize: 30, color: '#f5f7fb', backgroundColor: '#0f1624', border: '1px solid rgba(255,255,255,0.13)', borderRadius: 16, padding: '18px 28px', marginTop: 54}}>
          .package(url: "…/liveline-swift.git", from: "0.7.0")
        </div>
      </Interactive.Div>
    </AbsoluteFill>
  );
};
