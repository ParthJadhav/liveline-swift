import React from 'react';
import {Audio} from '@remotion/media';
import {Sequence, interpolate, staticFile} from 'remotion';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {AdvancedChartScene} from './ChartScene';
import {AdvancedClosingScene} from './ClosingScene';
import {AdvancedDitherScene} from './DitherScene';
import {AdvancedHeroScene} from './HeroScene';
import {advancedCharts, ditherCharts} from './catalog';

export const HERO_DURATION = 96;
export const CHART_DURATION = 72;
export const DITHER_DURATION = 90;
export const CLOSING_DURATION = 96;
export const TRANSITION_DURATION = 8;

const sceneCount = 1 + advancedCharts.length + ditherCharts.length + 1;
export const TOTAL_DURATION_ADVANCED_PR =
  HERO_DURATION +
  advancedCharts.length * CHART_DURATION +
  ditherCharts.length * DITHER_DURATION +
  CLOSING_DURATION -
  (sceneCount - 1) * TRANSITION_DURATION;

type SceneDefinition = {
  key: string;
  name: string;
  duration: number;
  content: React.ReactNode;
};

const scenes: SceneDefinition[] = [
  {
    key: 'hero',
    name: 'Advanced chart introduction',
    duration: HERO_DURATION,
    content: <AdvancedHeroScene />,
  },
  ...advancedCharts.map((chart, index) => ({
    key: chart.id,
    name: `${String(index + 1).padStart(2, '0')} · ${chart.title}`,
    duration: CHART_DURATION,
    content: <AdvancedChartScene chart={chart} index={index} />,
  })),
  ...ditherCharts.map((chart, index) => ({
    key: `dither-${chart.id}`,
    name: `Dither · ${chart.title} · ${chart.variant}`,
    duration: DITHER_DURATION,
    content: <AdvancedDitherScene chart={chart} index={index} total={ditherCharts.length} />,
  })),
  {
    key: 'closing',
    name: 'Advanced chart summary',
    duration: CLOSING_DURATION,
    content: <AdvancedClosingScene />,
  },
];

const MusicPass: React.FC = () => (
  <Audio
    src={staticFile('audio/advanced-pr-upbeat.m4a')}
    volume={(frame) =>
      interpolate(frame, [0, 18, 840, 899], [0, 0.34, 0.34, 0], {
        extrapolateLeft: 'clamp',
        extrapolateRight: 'clamp',
      })
    }
  />
);

export const AdvancedPRVideo: React.FC = () => (
  <>
    <TransitionSeries>
      {scenes.map((scene, index) => (
        <React.Fragment key={scene.key}>
          {index > 0 ? (
            <TransitionSeries.Transition
              presentation={fade()}
              timing={linearTiming({durationInFrames: TRANSITION_DURATION})}
            />
          ) : null}
          <TransitionSeries.Sequence durationInFrames={scene.duration} premountFor={24} name={scene.name}>
            {scene.content}
          </TransitionSeries.Sequence>
        </React.Fragment>
      ))}
    </TransitionSeries>
    <Sequence from={0} durationInFrames={900} name="Upbeat music · pass 1">
      <MusicPass />
    </Sequence>
    <Sequence from={840} durationInFrames={900} name="Upbeat music · pass 2">
      <MusicPass />
    </Sequence>
    <Sequence from={1680} name="Upbeat music · pass 3">
      <MusicPass />
    </Sequence>
  </>
);
