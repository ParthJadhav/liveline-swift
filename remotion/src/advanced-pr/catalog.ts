import {prColors} from './shared';

export type AdvancedChart = {
  id: string;
  title: string;
  group: string;
  detail: string;
  accent: string;
};

export const advancedCharts: AdvancedChart[] = [
  {id: 'violin-basic', title: 'Violin', group: 'Distribution', detail: 'Mirrored density, quartiles, and medians compare every client at a glance.', accent: prColors.blue},
  {id: 'ridgeline-basic', title: 'Ridgeline', group: 'Distribution', detail: 'Layered density profiles make shifts between populations immediately visible.', accent: prColors.violet},
  {id: 'calendar-heatmap-basic', title: 'Calendar heatmap', group: 'Planning', detail: 'Civil-day activity becomes a compact, readable fourteen-week rhythm.', accent: prColors.green},
  {id: 'gantt-basic', title: 'Gantt', group: 'Planning', detail: 'Task progress and dependencies stay aligned on one release timeline.', accent: prColors.blue},
  {id: 'bump-basic', title: 'Bump', group: 'Planning', detail: 'Rank crossings remain traceable through color and direct endpoint labels.', accent: prColors.orange},
  {id: 'horizon-basic', title: 'Horizon', group: 'Planning', detail: 'Positive and negative traffic deviations fold into three dense bands.', accent: prColors.red},
  {id: 'chord-basic', title: 'Chord', group: 'Relationships', detail: 'Weighted collaboration curves between proportional team arcs.', accent: prColors.violet},
  {id: 'parallel-basic', title: 'Parallel coordinates', group: 'Multivariate', detail: 'Four candidates compare cleanly across five independently scaled dimensions.', accent: prColors.cyan},
  {id: 'hexbin-basic', title: 'Hexbin', group: 'Relationships', detail: 'Dense observations aggregate into stable, density-preserving hexagons.', accent: prColors.cyan},
  {id: 'network-basic', title: 'Network', group: 'Relationships', detail: 'Weighted nodes and edges expose a service dependency topology.', accent: prColors.blue},
  {id: 'contour-basic', title: 'Contour', group: 'Multivariate', detail: 'Filled scalar-field bands retain continuous shapes and crisp level boundaries.', accent: prColors.green},
  {id: 'ternary-basic', title: 'Ternary', group: 'Multivariate', detail: 'Three-part workload compositions plot inside a normalized triangular domain.', accent: prColors.orange},
  {id: 'marimekko-basic', title: 'Marimekko', group: 'Composition', detail: 'Column width and stacked height encode two proportional dimensions.', accent: prColors.blue},
  {id: 'polar-area-basic', title: 'Polar area', group: 'Composition', detail: 'Equal-angle sectors compare plan magnitude by area without losing labels.', accent: prColors.violet},
  {id: 'waffle-basic', title: 'Waffle', group: 'Composition', detail: 'One hundred cells turn category share into an exact countable whole.', accent: prColors.cyan},
  {id: 'volume-profile-basic', title: 'Volume profile', group: 'Financial', detail: 'Horizontal volume bars reveal the price level where participation concentrates.', accent: prColors.blue},
  {id: 'renko-basic', title: 'Renko', group: 'Financial', detail: 'Fixed-size bricks suppress time noise and emphasize directional moves.', accent: prColors.green},
  {id: 'heikin-ashi-basic', title: 'Heikin-Ashi', group: 'Financial', detail: 'Derived candles reduce short-term noise while preserving trend direction.', accent: prColors.red},
  {id: 'market-depth-basic', title: 'Market depth', group: 'Financial', detail: 'Cumulative bid and ask liquidity frame the spread around the midpoint.', accent: prColors.green},
  {id: 'ohlc-volume-basic', title: 'OHLC + volume', group: 'Financial', detail: 'Synchronized panes align candle movement with traded volume.', accent: prColors.orange},
  {id: 'point-figure-basic', title: 'Point-and-figure', group: 'Financial', detail: 'X and O columns expose price reversals without a continuous time axis.', accent: prColors.violet},
];

export const ditherCharts = [
  {id: 'violin-basic', title: 'Violin', variant: 'Gradient', file: 'violin-basic-gradient.mp4', accent: prColors.blue},
  {id: 'chord-basic', title: 'Chord', variant: 'Dotted', file: 'chord-basic-dotted.mp4', accent: prColors.violet},
  {id: 'contour-basic', title: 'Contour', variant: 'Hatched', file: 'contour-basic-hatched.mp4', accent: prColors.green},
  {id: 'market-depth-basic', title: 'Market depth', variant: 'Solid', file: 'market-depth-basic-solid.mp4', accent: prColors.red},
];
