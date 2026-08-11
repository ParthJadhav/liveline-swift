import React from 'react';
import {AbsoluteFill} from 'remotion';
import {ChartCard, SceneCopy, SceneShell, prColors} from './shared';

export const AdvancedCatalogScene: React.FC = () => (
  <SceneShell accent={prColors.cyan}>
    <SceneCopy
      eyebrow="Distribution + planning"
      title="Shape, rank, and time."
      summary="Purpose-built geometry for distributions, schedules, activity, and changing rank."
      accent={prColors.cyan}
      width={610}
    />
    <AbsoluteFill style={{left: 740}}>
      <ChartCard src="violin-basic.png" label="VIOLIN" width={530} height={412} left={60} top={82} accent={prColors.blue} />
      <ChartCard src="calendar-heatmap-basic.png" label="CALENDAR HEATMAP" width={530} height={412} left={620} top={82} accent={prColors.green} delay={8} driftY={-7} cropWidth="126.8%" cropLeft="-13.3%" cropTop="-31.6%" />
      <ChartCard src="horizon-basic.png" label="HORIZON" width={530} height={412} left={60} top={548} accent={prColors.red} delay={16} driftY={-8} cropWidth="136%" cropLeft="-18%" cropTop="-34%" />
      <ChartCard src="waffle-basic.png" label="WAFFLE" width={530} height={412} left={620} top={548} accent={prColors.violet} delay={24} driftY={-9} />
    </AbsoluteFill>
  </SceneShell>
);
