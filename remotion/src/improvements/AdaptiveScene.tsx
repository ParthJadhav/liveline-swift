import React from 'react';
import {FactList, SceneFrame, Screenshot} from './shared';

export const AdaptiveScene: React.FC = () => (
  <SceneFrame
    eyebrow="Native everywhere"
    title="Readable at every size."
    summary="Automatic light and dark themes, stronger axis contrast, Dynamic Type, and an iPad layout built for the canvas it receives."
  >
    <Screenshot src="improvements/live-ipad.png" width={930} height={720} left={-30} top={90} />
    <Screenshot src="improvements/live-phone.png" width={300} height={650} left={610} top={-10} rotate={2} />
    <div style={{position: 'absolute', left: 18, bottom: 8}}>
      <FactList items={['Automatic theme coherence', 'Higher-contrast small labels', 'Adaptive two-column iPad dashboard']} />
    </div>
  </SceneFrame>
);
