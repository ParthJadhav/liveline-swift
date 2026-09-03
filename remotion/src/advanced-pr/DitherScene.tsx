import React from 'react';
import {Video} from '@remotion/media';
import {Interactive, staticFile} from 'remotion';
import {LightSceneShell, SceneLabel, fontMono, prColors} from './shared';

export type DitherChart = {
  id: string;
  title: string;
  variant: string;
  file: string;
  accent: string;
};

export const AdvancedDitherScene: React.FC<{
  chart: DitherChart;
  index: number;
  total: number;
}> = ({chart, index, total}) => {
  return (
    <LightSceneShell accent={chart.accent}>
      <Interactive.Div
        name="Dither description"
        style={{
          position: 'absolute',
          left: 92,
          top: 190,
          width: 620,
        }}
      >
        <SceneLabel group="Advanced Dither" accent={chart.accent} />
        <div style={{marginTop: 32, fontSize: 98, lineHeight: 0.95, fontWeight: 800, letterSpacing: '-0.06em', color: prColors.ink}}>
          {chart.title}
        </div>
        <div style={{marginTop: 24, color: chart.accent, fontFamily: fontMono, fontSize: 27, fontWeight: 760, letterSpacing: '0.08em'}}>
          {chart.variant.toUpperCase()} TEXTURE
        </div>
        <div style={{marginTop: 38, fontFamily: fontMono, fontSize: 20, color: prColors.subtle}}>
          NATIVE LIVE CHART · {String(index + 1).padStart(2, '0')} / {String(total).padStart(2, '0')}
        </div>
      </Interactive.Div>
      <Interactive.Div
        name={`${chart.title} Dither recording`}
        style={{
          position: 'absolute',
          left: 770,
          top: 110,
          width: 1050,
          height: 790,
          overflow: 'hidden',
          borderRadius: 36,
          border: `1px solid ${prColors.border}`,
          backgroundColor: '#fff',
          boxShadow: `0 34px 90px rgba(42,65,98,0.15), 0 0 0 10px ${chart.accent}09`,
        }}
      >
        <Video
          name={`${chart.title} native Dither clip`}
          src={staticFile(`advanced-pr-light/dither/${chart.file}`)}
          muted
          objectFit="cover"
          style={{width: '100%', height: '100%'}}
        />
      </Interactive.Div>
    </LightSceneShell>
  );
};
