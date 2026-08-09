import React from 'react';
import {AbsoluteFill, Easing, Img, Interactive, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Clip} from '../clips';

export const HeroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <AbsoluteFill style={{backgroundColor: '#070b14', fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif'}}>
      <AbsoluteFill style={{opacity: 0.38, scale: 1.08}}>
        <Clip name="line-live" loop="hold" />
      </AbsoluteFill>
      <AbsoluteFill style={{background: 'radial-gradient(860px 560px at 50% 50%, rgba(7,11,20,0.60), rgba(7,11,20,0.96))'}} />
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
        <Interactive.Div
          name="Release lockup"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 38,
            opacity: interpolate(frame, [0, 14], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
            scale: interpolate(frame, [0, 22], [0.94, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.spring({damping: 200}),
              output: 'perceptual-scale',
            }),
          }}
        >
          <Img src={staticFile('improvements/app-icon.png')} style={{width: 190, height: 190, borderRadius: 44}} />
          <div>
            <div style={{fontSize: 118, lineHeight: 0.95, fontWeight: 740, letterSpacing: '-0.05em', color: '#f5f7fb'}}>Liveline</div>
            <div style={{fontSize: 38, fontWeight: 650, color: '#22d3ee', marginTop: 20}}>0.7.0 · A clearer native chart workbench</div>
          </div>
        </Interactive.Div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
