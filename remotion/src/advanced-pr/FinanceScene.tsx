import React from 'react';
import {AbsoluteFill, Easing, interpolate, useCurrentFrame} from 'remotion';
import {ChartCard, SceneCopy, SceneShell, fontMono, prColors} from './shared';

export const AdvancedFinanceScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <SceneShell accent={prColors.green}>
      <SceneCopy
        eyebrow="Financial market structure"
        title="More than candles."
        summary="Price construction, liquidity, volume, and reversal logic are modeled as first-class native charts."
        accent={prColors.green}
        width={620}
      />
      <AbsoluteFill style={{left: 744}}>
        <ChartCard src="market-depth-basic.png" label="MARKET DEPTH" width={650} height={505} left={60} top={72} accent={prColors.green} driftX={9} />
        <ChartCard src="renko-basic.png" label="RENKO" width={500} height={389} left={742} top={102} accent={prColors.red} delay={10} driftX={-8} />
        <ChartCard src="point-figure-basic.png" label="POINT + FIGURE" width={650} height={505} left={490} top={554} accent={prColors.orange} delay={20} driftX={-10} driftY={-9} />
        <div
          style={{
            position: 'absolute',
            left: 96,
            top: 642,
            width: 320,
            padding: '26px 28px',
            borderRadius: 22,
            background: 'rgba(12,17,27,0.90)',
            border: `1px solid ${prColors.border}`,
            opacity: interpolate(frame, [24, 40], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        >
          <div style={{fontFamily: fontMono, fontSize: 19, color: prColors.secondary}}>DERIVED SERIES</div>
          <div style={{fontSize: 28, lineHeight: 1.35, fontWeight: 650, color: prColors.text, marginTop: 13}}>
            Deterministic transforms.<br />Shared by every reader.
          </div>
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};
