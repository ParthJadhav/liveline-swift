import React from 'react';
import {FactList, SceneFrame, Screenshot} from './shared';

export const WorkbenchScene: React.FC = () => (
  <SceneFrame
    eyebrow="From preview to production"
    title="Every example teaches."
    summary="Scenario details now pair the real interactive renderer with gesture guidance and a selectable SwiftUI recipe you can copy or share."
  >
    <Screenshot src="improvements/workbench-phone.png" width={460} height={996} left={390} top={-20} rotate={-1.5} />
    <div style={{position: 'absolute', left: 14, top: 600}}>
      <FactList width={330} fontSize={25} items={['Contextual gesture guidance', 'Selectable Swift source', 'Copy and share actions']} />
    </div>
  </SceneFrame>
);
