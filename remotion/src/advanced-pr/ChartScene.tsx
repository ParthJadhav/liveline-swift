import React from 'react';
import {Video} from '@remotion/media';
import {Interactive, staticFile} from 'remotion';
import type {AdvancedChart} from './catalog';
import {AnimatedSceneCopy, LightSceneShell, SceneProgress, prColors} from './shared';

export const AdvancedChartScene: React.FC<{
  chart: AdvancedChart;
  index: number;
}> = ({chart, index}) => {
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
        }}
      >
        <Video
          name={`${chart.title} native live chart`}
          src={staticFile(`advanced-pr-light/live/${chart.id}.mp4`)}
          muted
          objectFit="contain"
          style={{width: '100%', height: '100%', backgroundColor: '#fff'}}
        />
      </Interactive.Div>
      <SceneProgress current={index + 1} accent={chart.accent} />
    </LightSceneShell>
  );
};
