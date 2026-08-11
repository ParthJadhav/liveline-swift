import React from 'react';
import {Audio, staticFile} from 'remotion';
import {TransitionSeries, linearTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {AdvancedCatalogScene} from './CatalogScene';
import {AdvancedDitherScene} from './DitherScene';
import {AdvancedFinanceScene} from './FinanceScene';
import {AdvancedHeroScene} from './HeroScene';
import {AdvancedQualityScene} from './QualityScene';
import {AdvancedRelationshipScene} from './RelationshipScene';

export const TOTAL_DURATION_ADVANCED_PR = 750;

export const AdvancedPRVideo: React.FC = () => (
  <>
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={105} premountFor={30} name="PR title">
        <AdvancedHeroScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Distribution and planning">
        <AdvancedCatalogScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Relationships and multivariate">
        <AdvancedRelationshipScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={150} premountFor={30} name="Financial charts">
        <AdvancedFinanceScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={135} premountFor={30} name="Dither style">
        <AdvancedDitherScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={linearTiming({durationInFrames: 12})} />
      <TransitionSeries.Sequence durationInFrames={120} premountFor={30} name="Quality and accessibility">
        <AdvancedQualityScene />
      </TransitionSeries.Sequence>
    </TransitionSeries>
    <Audio src={staticFile('audio/bgm.m4a')} volume={0.3} />
  </>
);
