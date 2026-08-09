import React from 'react';
import {FactList, SceneFrame, Screenshot} from './shared';

export const StorybookScene: React.FC = () => (
  <SceneFrame
    eyebrow="71 scenarios · 27 families"
    title="Find the right chart fast."
    summary="Search by chart, feature, or scenario ID. Filter by family. Every gallery preview is now static, so the whole card is one clear navigation target."
  >
    <Screenshot src="improvements/storybook-phone.png" width={460} height={996} left={360} top={-20} rotate={1.5} />
    <div style={{position: 'absolute', left: 10, top: 580}}>
      <FactList width={330} fontSize={25} items={['Search and family filters', 'Responsive multi-column gallery', 'No nested chart interactions']} />
    </div>
  </SceneFrame>
);
