import React from 'react';
import {Clip} from '../clips';
import {colors, FactList, SceneFrame} from './shared';

export const AccessScene: React.FC = () => (
  <SceneFrame
    eyebrow="Inclusive by default"
    title="More legible. More local."
    summary="Canvas labels now scale farther at accessibility sizes. Spanish chart and control terminology ships in the package alongside VoiceOver and Audio Graph support."
  >
    <div style={{position: 'absolute', left: 0, right: 0, top: 36, height: 520, overflow: 'hidden', borderRadius: 28, border: `2px solid ${colors.border}`}}>
      <Clip name="dynamic-type" loop="pingpong" />
    </div>
    <div style={{position: 'absolute', left: 6, top: 610}}>
      <FactList items={['1.8× accessible canvas text', 'Bundled Spanish localization', 'VoiceOver-adjustable chart inspection']} />
    </div>
  </SceneFrame>
);
