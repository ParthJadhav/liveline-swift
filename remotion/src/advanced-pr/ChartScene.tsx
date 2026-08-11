import React from 'react';
import {Easing, Img, Interactive, interpolate, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import type {AdvancedChart} from './catalog';
import {AnimatedSceneCopy, LightSceneShell, SceneProgress, prColors} from './shared';

export const AdvancedChartScene: React.FC<{
  chart: AdvancedChart;
  index: number;
}> = ({chart, index}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  return (
    <LightSceneShell accent={chart.accent}>
      <AnimatedSceneCopy
        eyebrow={chart.group}
        title={chart.title}
        detail={chart.detail}
        accent={chart.accent}
      />
      <Interactive.Div
        name={`${chart.title} native capture`}
        style={{
          position: 'absolute',
          left: 748,
          top: 72,
          width: 1084,
          height: 900,
          overflow: 'hidden',
          borderRadius: 34,
          border: `1px solid ${prColors.border}`,
          backgroundColor: prColors.surface,
          boxShadow: `0 34px 90px rgba(42,65,98,0.14), 0 0 0 10px ${chart.accent}08`,
          opacity: interpolate(frame, [4, 18, durationInFrames - 9, durationInFrames], [0, 1, 1, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [4, 22], [0.955, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.spring({damping: 200}),
            output: 'perceptual-scale',
          }),
          translate: interpolate(frame, [4, durationInFrames - 1], ['26px 0px', '-8px 0px'], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: Easing.linear,
          }),
        }}
      >
        <Img
          name={`${chart.title} screenshot`}
          src={staticFile(`advanced-pr-light/${chart.id}.png`)}
          style={{
            position: 'absolute',
            left: 0,
            top: -154,
            width: '100%',
            height: 'auto',
            clipPath: `inset(0 ${interpolate(frame, [7, 30], [100, 0], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            })}% 0 0)`,
          }}
        />
        <div
          style={{
            position: 'absolute',
            left: 28,
            top: 26,
            padding: '10px 14px',
            borderRadius: 11,
            color: chart.accent,
            backgroundColor: 'rgba(255,255,255,0.9)',
            border: `1px solid ${chart.accent}2e`,
            backdropFilter: 'blur(16px)',
            fontFamily: '"SF Mono", ui-monospace, Menlo, monospace',
            fontSize: 17,
            fontWeight: 700,
          }}
        >
          {chart.id}
        </div>
      </Interactive.Div>
      <SceneProgress current={index + 1} accent={chart.accent} />
    </LightSceneShell>
  );
};
