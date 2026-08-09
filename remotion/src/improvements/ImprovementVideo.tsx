import React from 'react';
import {Audio, staticFile} from 'remotion';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {AccessScene} from './AccessScene';
import {AdaptiveScene} from './AdaptiveScene';
import {HeroScene} from './HeroScene';
import {QualityScene} from './QualityScene';
import {StorybookScene} from './StorybookScene';
import {WorkbenchScene} from './WorkbenchScene';

export const TOTAL_DURATION_070 = 780;

export const Liveline070Video: React.FC = () => (
  <>
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={105} premountFor={30} name="Release title">
        <HeroScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Adaptive layout">
        <AdaptiveScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Storybook discovery">
        <StorybookScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Developer workbench">
        <WorkbenchScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Accessibility and localization">
        <AccessScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={135} premountFor={30} name="Quality and install">
        <QualityScene />
      </TransitionSeries.Sequence>
    </TransitionSeries>
    <Audio src={staticFile('audio/bgm.m4a')} volume={0.13} />
  </>
);
