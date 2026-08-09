import React from 'react';
import {Composition, Folder} from 'remotion';
import {LivelinePlatformsVideo, TOTAL_DURATION} from './Video';
import {Liveline060Video, TOTAL_DURATION_060} from './Video060';
import {Liveline070Video, TOTAL_DURATION_070} from './improvements/ImprovementVideo';
import {AccessScene} from './improvements/AccessScene';
import {AdaptiveScene} from './improvements/AdaptiveScene';
import {HeroScene} from './improvements/HeroScene';
import {QualityScene} from './improvements/QualityScene';
import {StorybookScene} from './improvements/StorybookScene';
import {WorkbenchScene} from './improvements/WorkbenchScene';

export const Root: React.FC = () => {
  return (
    <>
      <Composition
        id="LivelinePlatforms"
        component={LivelinePlatformsVideo}
        durationInFrames={TOTAL_DURATION}
        fps={30}
        width={1920}
        height={1080}
      />
      <Folder name="Liveline-070-Scenes">
        <Composition id="Liveline070-Hero" component={HeroScene} durationInFrames={105} fps={30} width={1920} height={1080} />
        <Composition id="Liveline070-Adaptive" component={AdaptiveScene} durationInFrames={150} fps={30} width={1920} height={1080} />
        <Composition id="Liveline070-Storybook" component={StorybookScene} durationInFrames={150} fps={30} width={1920} height={1080} />
        <Composition id="Liveline070-Workbench" component={WorkbenchScene} durationInFrames={150} fps={30} width={1920} height={1080} />
        <Composition id="Liveline070-Accessibility" component={AccessScene} durationInFrames={150} fps={30} width={1920} height={1080} />
        <Composition id="Liveline070-Quality" component={QualityScene} durationInFrames={135} fps={30} width={1920} height={1080} />
      </Folder>
      <Composition
        id="Liveline070"
        component={Liveline070Video}
        durationInFrames={TOTAL_DURATION_070}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="Liveline060"
        component={Liveline060Video}
        durationInFrames={TOTAL_DURATION_060}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
