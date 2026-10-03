import {prColors} from './shared';

export type AdvancedChart = {
  id: string;
  title: string;
  group: string;
  detail: string;
  accent: string;
};

export const advancedCharts: AdvancedChart[] = [
  {id: 'violin-basic', title: 'Violin', group: 'Distribution', detail: 'Live density', accent: prColors.blue},
  {id: 'ridgeline-basic', title: 'Ridgeline', group: 'Distribution', detail: 'Shifting populations', accent: prColors.violet},
  {id: 'calendar-heatmap-basic', title: 'Calendar heatmap', group: 'Planning', detail: 'Activity, day by day', accent: prColors.green},
  {id: 'gantt-basic', title: 'Gantt', group: 'Planning', detail: 'Progress in motion', accent: prColors.blue},
  {id: 'bump-basic', title: 'Bump', group: 'Planning', detail: 'Rankings change', accent: prColors.orange},
  {id: 'horizon-basic', title: 'Horizon', group: 'Planning', detail: 'Signals, compressed', accent: prColors.red},
  {id: 'chord-basic', title: 'Chord', group: 'Relationships', detail: 'Connections evolve', accent: prColors.violet},
  {id: 'parallel-basic', title: 'Parallel coordinates', group: 'Multivariate', detail: 'Many dimensions. One view.', accent: prColors.cyan},
  {id: 'hexbin-basic', title: 'Hexbin', group: 'Relationships', detail: 'Density comes alive', accent: prColors.cyan},
  {id: 'network-basic', title: 'Network', group: 'Relationships', detail: 'Topology in motion', accent: prColors.blue},
  {id: 'contour-basic', title: 'Contour', group: 'Multivariate', detail: 'A living surface', accent: prColors.green},
  {id: 'ternary-basic', title: 'Ternary', group: 'Multivariate', detail: 'Balance shifts', accent: prColors.orange},
  {id: 'marimekko-basic', title: 'Marimekko', group: 'Composition', detail: 'Share meets scale', accent: prColors.blue},
  {id: 'polar-area-basic', title: 'Polar area', group: 'Composition', detail: 'Magnitude by area', accent: prColors.violet},
  {id: 'waffle-basic', title: 'Waffle', group: 'Composition', detail: 'Every cell counts', accent: prColors.cyan},
  {id: 'volume-profile-basic', title: 'Volume profile', group: 'Financial', detail: 'Liquidity takes shape', accent: prColors.blue},
  {id: 'renko-basic', title: 'Renko', group: 'Financial', detail: 'Price builds', accent: prColors.green},
  {id: 'heikin-ashi-basic', title: 'Heikin-Ashi', group: 'Financial', detail: 'Trend, smoothed', accent: prColors.red},
  {id: 'market-depth-basic', title: 'Market depth', group: 'Financial', detail: 'The spread moves', accent: prColors.green},
  {id: 'ohlc-volume-basic', title: 'OHLC + volume', group: 'Financial', detail: 'Price meets volume', accent: prColors.orange},
  {id: 'point-figure-basic', title: 'Point-and-figure', group: 'Financial', detail: 'Reversals revealed', accent: prColors.violet},
];

export const ditherCharts = [
  {id: 'violin-basic', title: 'Violin', variant: 'Gradient', file: 'violin-basic-gradient.mp4', accent: prColors.blue},
  {id: 'chord-basic', title: 'Chord', variant: 'Dotted', file: 'chord-basic-dotted.mp4', accent: prColors.violet},
  {id: 'contour-basic', title: 'Contour', variant: 'Hatched', file: 'contour-basic-hatched.mp4', accent: prColors.green},
  {id: 'market-depth-basic', title: 'Market depth', variant: 'Solid', file: 'market-depth-basic-solid.mp4', accent: prColors.red},
];
