import React from 'react';
import {AbsoluteFill} from 'remotion';
import {ChartCard, SceneCopy, SceneShell, prColors} from './shared';

export const AdvancedRelationshipScene: React.FC = () => (
  <SceneShell accent={prColors.violet}>
    <SceneCopy
      eyebrow="Relationships + multivariate"
      title="See the structure."
      summary="Flows, clusters, fields, and many-dimensional comparisons stay legible and directly inspectable."
      accent={prColors.violet}
      width={620}
    />
    <AbsoluteFill style={{left: 738}}>
      <ChartCard src="contour-basic.png" label="CONTOUR" width={700} height={544} left={60} top={118} accent={prColors.cyan} driftX={8} driftY={-12} />
      <ChartCard src="chord-basic.png" label="CHORD" width={500} height={389} left={724} top={58} accent={prColors.blue} delay={10} rotate={2} driftX={-8} />
      <ChartCard src="hexbin-basic.png" label="HEXBIN" width={500} height={389} left={760} top={548} accent={prColors.green} delay={20} rotate={-2} driftX={-12} driftY={-8} />
    </AbsoluteFill>
  </SceneShell>
);
