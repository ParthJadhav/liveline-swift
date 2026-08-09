import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Easing,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {Clip, ClipName} from './clips';
import {theme} from './theme';

// Light-mode chrome, on Apple's light palette (see ./theme.ts, which the
// platforms cut already uses). `bg` is the exact background the ShotGen clips
// are rasterized against — `lightBackground` in tools/shotgen — so a chart PNG
// dropped on the page has no seam.
//
// Every accent is 6-digit hex, never `rgb()`, because they are concatenated with
// two-digit alpha suffixes (`${ui.blue}22`) for glows and tinted chips; an
// `rgb()` string produces invalid CSS there and the glow silently drops out.
export const ui = {
  bg: '#f9fafc',
  surface: 'rgba(0, 0, 0, 0.035)',
  surfaceStrong: '#ffffff',
  border: 'rgba(0, 0, 0, 0.12)',
  borderStrong: 'rgba(0, 0, 0, 0.22)',
  text: theme.textPrimary,
  // Deliberately darker than theme.textSecondary: this copy runs at 24–32px over
  // a near-white page, where #6e6e73 only reaches ~4.4:1.
  textSecondary: '#55555c',
  textTertiary: '#76767d',
  // Accents darkened from the chart palette so they stay legible as *text* on
  // white. The charts themselves keep the library's brighter hues.
  blue: '#0064d2',
  violet: '#7b3fbf',
  cyan: '#00758f',
  green: '#17794a',
  amber: '#9a6100',
  pink: '#b3286b',
  red: '#c4292e',
};

/// The page background as an `rgba()` prefix, for the scrim gradients that sit
/// between a full-bleed clip and the copy on top of it.
const scrim = (alpha: number) => `rgba(249, 250, 252, ${alpha})`;

// ---------------------------------------------------------------------------
// Timing
// ---------------------------------------------------------------------------

export const SCENES = {
  title: {from: 0, duration: 120},
  kindsIntro: {from: 120, duration: 48},
  kindsSpotlight: {from: 168, duration: 360}, // 6 x 60
  zoomPan: {from: 528, duration: 162},
  annotations: {from: 690, duration: 120},
  legend: {from: 810, duration: 75},
  exportBeat: {from: 885, duration: 60},
  theme: {from: 945, duration: 90},
  rtl: {from: 1035, duration: 120},
  accessibility: {from: 1155, duration: 150},
  outro: {from: 1305, duration: 195},
} as const;

export const TOTAL_DURATION_060 =
  SCENES.outro.from + SCENES.outro.duration; // 1500 frames = 50s at 30fps

const SPOT_DURATION = 60;

// ---------------------------------------------------------------------------
// Shared chrome
// ---------------------------------------------------------------------------

const EASE_OUT = Easing.bezier(0.16, 1, 0.3, 1);

const useEnter = (delay = 0, damping = 200) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({frame: frame - delay, fps, config: {damping}, durationInFrames: 22});
};

/// Scenes cross-dissolve rather than cut: each `<Sequence>` runs `CROSSFADE`
/// frames past its nominal end, and the outgoing scene spends exactly those
/// frames fading out underneath the incoming one. Fading both scenes out to
/// the background instead would blink the page dark at every transition.
const CROSSFADE = 9;

const SceneShell: React.FC<{
  duration: number;
  children: React.ReactNode;
  glow?: string;
  /// Where the fade-out begins; defaults to the scene's nominal end.
  fadeOutStart?: number;
  /// How long the scene takes to dissolve in. The title scene passes 0: it has
  /// nothing to dissolve out of, and fading it up would make frame 0 — the
  /// video's poster frame — an empty page.
  fadeIn?: number;
}> = ({duration, children, glow = ui.blue, fadeOutStart, fadeIn = 8}) => {
  const frame = useCurrentFrame();
  const start = fadeOutStart ?? duration;
  const opacity = interpolate(
    frame,
    [0, Math.max(fadeIn, 0.001), start, start + CROSSFADE],
    [fadeIn === 0 ? 1 : 0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.linear},
  );
  return (
    <AbsoluteFill style={{background: ui.bg, fontFamily: theme.fontSans, opacity}}>
      <AbsoluteFill
        style={{
          background: `radial-gradient(1100px 620px at 50% 12%, ${glow}22, transparent 70%)`,
        }}
      />
      {children}
    </AbsoluteFill>
  );
};

const Eyebrow: React.FC<{children: React.ReactNode; color?: string; delay?: number}> = ({
  children,
  color = ui.blue,
  delay = 0,
}) => {
  const enter = useEnter(delay);
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 12,
        padding: '9px 20px',
        borderRadius: 999,
        border: `1.5px solid ${ui.border}`,
        background: ui.surface,
        fontSize: 22,
        fontWeight: 600,
        letterSpacing: '0.08em',
        textTransform: 'uppercase',
        color: ui.textSecondary,
        opacity: enter,
        translate: `0px ${(1 - enter) * 14}px`,
      }}
    >
      <span style={{width: 9, height: 9, borderRadius: 5, background: color}} />
      {children}
    </div>
  );
};

/// The rounded frame every chart clip sits in. The PNGs are opaque and share
/// the page background, so the border does all the separating work.
const ChartCard: React.FC<{
  name: ClipName;
  loop?: 'pingpong' | 'loop' | 'hold';
  offset?: number;
  width: number;
  height: number;
  delay?: number;
  radius?: number;
  style?: React.CSSProperties;
}> = ({name, loop = 'pingpong', offset = 0, width, height, delay = 0, radius = 22, style}) => {
  const enter = useEnter(delay, 22);
  return (
    <div
      style={{
        width,
        height,
        borderRadius: radius,
        overflow: 'hidden',
        border: `1.5px solid ${ui.border}`,
        background: ui.bg,
        boxShadow: '0 24px 60px rgba(0, 0, 0, 0.10), 0 2px 8px rgba(0, 0, 0, 0.05)',
        opacity: Math.min(1, enter * 1.3),
        scale: 0.94 + 0.06 * enter,
        ...style,
      }}
    >
      <Clip name={name} loop={loop} offset={offset} />
    </div>
  );
};

// ---------------------------------------------------------------------------
// 1 — Title
// ---------------------------------------------------------------------------

const TitleScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  // The wordmark and the version badge animate as ONE unit. They used to have
  // separate springs — the badge's lagged 16 frames behind — which left the row
  // laying out around an invisible 200px-wide badge for the whole first half
  // second: "Liveline" rendered visibly off-centre with a hole beside it, and
  // the badge then popped in from a 0.6 scale that shifted it against the shared
  // baseline. Animating the row instead of its children keeps the internal
  // geometry identical on every frame, including frame 0.
  //
  // The lockup is also fully opaque on frame 0 rather than springing up from
  // nothing: frame 0 is the poster frame, and it should be the finished title
  // card. What remains of the entrance is a uniform settle of the whole row,
  // which cannot pull the badge off the wordmark's baseline.
  const lockupIn = spring({frame, fps, config: {damping: 200}, durationInFrames: 26});
  const subIn = spring({frame: frame - 14, fps, config: {damping: 200}, durationInFrames: 24});

  return (
    <SceneShell duration={SCENES.title.duration} fadeIn={0}>
      {/* Live footage behind the wordmark, so the very first frame of the
          video already has a chart streaming in it. */}
      <AbsoluteFill
        style={{
          opacity: interpolate(frame, [0, 26], [0.6, 0.85], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
            easing: EASE_OUT,
          }),
          scale: interpolate(frame, [0, SCENES.title.duration], [1.12, 1.02], {
            extrapolateRight: 'clamp',
            easing: Easing.linear,
          }),
        }}
      >
        <Clip name="line-live" loop="hold" />
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background: `radial-gradient(920px 540px at 50% 50%, ${scrim(0.72)} 0%, ${scrim(
            0.9,
          )} 58%, ${scrim(0.99)} 100%)`,
        }}
      />
      <AbsoluteFill
        style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column'}}
      >
        <div
          style={{
            display: 'flex',
            // Centre, not baseline. `alignItems: 'baseline'` hung the pill off
            // the wordmark's baseline, which put its box a good 30px below the
            // wordmark's optical centre; with `lineHeight: 1` on both, centring
            // the boxes lines the pill up with the cap height instead.
            alignItems: 'center',
            gap: 28,
            scale: 1.045 - 0.045 * lockupIn,
            translate: `0px ${(1 - lockupIn) * 14}px`,
          }}
        >
          <div
            style={{
              fontSize: 148,
              fontWeight: 700,
              letterSpacing: '-0.035em',
              lineHeight: 1,
              color: ui.text,
            }}
          >
            Liveline
          </div>
          <div
            style={{
              // Symmetric: the row centres the boxes, so the pill needs no
              // optical correction of its own.
              padding: '16px 26px',
              borderRadius: 16,
              background: ui.blue,
              color: '#ffffff',
              fontFamily: theme.fontMono,
              fontSize: 54,
              fontWeight: 700,
              lineHeight: 1,
              letterSpacing: '-0.01em',
            }}
          >
            0.6.0
          </div>
        </div>
        <div
          style={{
            marginTop: 34,
            fontSize: 40,
            fontWeight: 500,
            color: ui.textSecondary,
            opacity: subIn,
            translate: `0px ${(1 - subIn) * 18}px`,
            textAlign: 'center',
          }}
        >
          Live charts for SwiftUI — now faster, more accessible, everywhere.
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// 2 — Six new chart kinds
// ---------------------------------------------------------------------------

type Kind = {clip: ClipName; name: string; blurb: string; color: string};

const NEW_KINDS: Kind[] = [
  {
    clip: 'histogram',
    name: 'Histogram',
    blurb: 'Automatic binning — Freedman–Diaconis, Sturges or a fixed count',
    color: ui.violet,
  },
  {
    clip: 'streamgraph',
    name: 'Streamgraph',
    blurb: 'Stacked areas on a centred baseline',
    color: ui.blue,
  },
  {
    clip: 'bullet',
    name: 'Bullet',
    blurb: 'Measure, target and qualitative bands on one track',
    color: ui.cyan,
  },
  {
    clip: 'treemap',
    name: 'Treemap',
    blurb: 'Squarified layout with nested group headers',
    color: ui.green,
  },
  {
    clip: 'sunburst',
    name: 'Sunburst',
    blurb: 'Hierarchical shares across concentric rings',
    color: ui.amber,
  },
  {
    clip: 'sankey',
    name: 'Sankey',
    blurb: 'Weighted flows resolved across columns',
    color: ui.pink,
  },
];

const KindsIntro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 16, stiffness: 120}});

  return (
    <SceneShell duration={SCENES.kindsIntro.duration} glow={ui.violet}>
      {/* A preview of the six clips, dimmed behind the headline. */}
      <AbsoluteFill
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          opacity: 0.62,
          filter: 'saturate(0.9)',
        }}
      >
        {NEW_KINDS.map((kind) => (
          <div key={kind.clip} style={{width: 640, height: 540, overflow: 'hidden'}}>
            <Clip name={kind.clip} />
          </div>
        ))}
      </AbsoluteFill>
      <AbsoluteFill
        style={{background: `radial-gradient(1150px 620px at 50% 50%, ${scrim(0.90)}, ${scrim(0.97)})`}}
      />
      <AbsoluteFill
        style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 26}}
      >
        <Eyebrow color={ui.violet}>New in 0.6.0</Eyebrow>
        <div
          style={{
            fontSize: 108,
            fontWeight: 700,
            letterSpacing: '-0.03em',
            color: ui.text,
            opacity: headIn,
            translate: `0px ${(1 - headIn) * 26}px`,
          }}
        >
          Six new chart kinds
        </div>
        <div style={{fontSize: 32, fontWeight: 500, color: ui.textSecondary}}>
          Each one wired through rendering, hover, accessibility and RTL.
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

const KindSpotlight: React.FC<{kind: Kind; index: number}> = ({kind, index}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const labelIn = spring({frame: frame - 6, fps, config: {damping: 200}, durationInFrames: 20});

  return (
    <SceneShell duration={SPOT_DURATION} glow={kind.color}>
      <AbsoluteFill style={{alignItems: 'center', paddingTop: 92}}>
        <ChartCard
          name={kind.clip}
          width={1240}
          height={698}
          // A slow drift keeps the frame alive even on the calmer charts.
          style={{
            scale: interpolate(frame, [0, SPOT_DURATION], [1, 1.018], {
              extrapolateRight: 'clamp',
              easing: Easing.linear,
            }),
          }}
        />
        <div
          style={{
            marginTop: 40,
            display: 'flex',
            alignItems: 'center',
            gap: 24,
            opacity: labelIn,
            translate: `0px ${(1 - labelIn) * 20}px`,
          }}
        >
          <div
            style={{
              fontFamily: theme.fontMono,
              fontSize: 26,
              fontWeight: 700,
              color: kind.color,
              padding: '6px 14px',
              borderRadius: 10,
              border: `1.5px solid ${kind.color}55`,
              background: `${kind.color}14`,
            }}
          >
            {String(index + 1).padStart(2, '0')} / 06
          </div>
          <div
            style={{
              fontSize: 62,
              fontWeight: 700,
              letterSpacing: '-0.02em',
              color: ui.text,
            }}
          >
            {kind.name}
          </div>
        </div>
        <div
          style={{
            marginTop: 14,
            fontSize: 30,
            fontWeight: 500,
            color: ui.textSecondary,
            opacity: labelIn,
          }}
        >
          {kind.blurb}
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// 3 — Zoom, pan and follow-live (SVG recreation, so the gesture can be shown)
// ---------------------------------------------------------------------------

const ZOOM_DURATION = SCENES.zoomPan.duration;
const SAMPLES = 260;

const zoomValue = (i: number): number =>
  100 +
  6.4 * Math.sin(i * 0.052 + 1.2) +
  3.1 * Math.sin(i * 0.129 + 4.0) +
  1.5 * Math.sin(i * 0.31 + 2.2) +
  0.5 * Math.sin(i * 0.83 + 0.5) +
  i * 0.012;

const ZoomPanScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const plotW = 1400;
  const plotH = 560;

  // The x-domain the viewport shows, in sample space. The data itself keeps
  // streaming underneath (see `zoomValue(i + frame)`), so even a frozen,
  // zoomed-in viewport is still watching a live chart.
  const zoomT = interpolate(frame, [22, 52], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });
  const panT = interpolate(frame, [64, 100], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });
  const releaseT = interpolate(frame, [116, 146], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });

  const fullStart = 0;
  const fullEnd = SAMPLES - 1;
  const zoomStart = 150;
  const zoomEnd = 236;
  const panStart = 62;
  const panEnd = 148;

  const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
  let domainStart = lerp(fullStart, zoomStart, zoomT);
  let domainEnd = lerp(fullEnd, zoomEnd, zoomT);
  domainStart = lerp(domainStart, panStart, panT);
  domainEnd = lerp(domainEnd, panEnd, panT);
  domainStart = lerp(domainStart, fullStart, releaseT);
  domainEnd = lerp(domainEnd, fullEnd, releaseT);

  const following = releaseT > 0.55 || zoomT < 0.08;

  const step = Math.max(0.4, (domainEnd - domainStart) / 300);
  const points: Array<[number, number]> = [];
  let minV = Infinity;
  let maxV = -Infinity;
  for (let i = domainStart; i <= domainEnd + 1e-6; i += step) {
    const v = zoomValue(i + frame * 0.9);
    minV = Math.min(minV, v);
    maxV = Math.max(maxV, v);
    points.push([i, v]);
  }
  const pad = (maxV - minV) * 0.18 + 0.2;
  const lo = minV - pad;
  const hi = maxV + pad;
  const px = (i: number) => ((i - domainStart) / (domainEnd - domainStart)) * plotW;
  const py = (v: number) => plotH - ((v - lo) / (hi - lo)) * plotH;

  const path = points
    .map(([i, v], n) => `${n === 0 ? 'M' : 'L'}${px(i).toFixed(1)},${py(v).toFixed(1)}`)
    .join(' ');
  const area = `${path} L${plotW},${plotH} L0,${plotH} Z`;
  const [lastI, lastV] = points[points.length - 1];

  const chipPulse = 1 + 0.16 * Math.sin((frame / 22) * Math.PI * 2);
  const captions = [
    {at: 20, text: 'Pinch to zoom'},
    {at: 62, text: 'Drag to pan'},
    {at: 114, text: 'Release — snaps back and follows live'},
  ];

  // Two-finger pinch indicator, then a single dragging finger.
  const pinchSpread = interpolate(frame, [22, 52], [150, 400], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });
  const pinchOpacity = interpolate(frame, [18, 24, 52, 58], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const dragX = interpolate(frame, [64, 100], [-220, 240], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });
  const dragOpacity = interpolate(frame, [60, 66, 100, 108], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <SceneShell duration={ZOOM_DURATION} glow={ui.cyan}>
      <AbsoluteFill style={{alignItems: 'center', paddingTop: 76}}>
        <Eyebrow color={ui.cyan}>Interaction</Eyebrow>
        <div
          style={{
            marginTop: 20,
            fontSize: 66,
            fontWeight: 700,
            letterSpacing: '-0.025em',
            color: ui.text,
            opacity: spring({frame: frame - 4, fps, config: {damping: 200}, durationInFrames: 20}),
          }}
        >
          Pinch-zoom, pan, and auto-follow-live
        </div>

        <div
          style={{
            marginTop: 34,
            width: plotW + 80,
            height: plotH + 80,
            borderRadius: 22,
            border: `1.5px solid ${ui.border}`,
            background: '#ffffff',
            boxShadow: '0 24px 60px rgba(0, 0, 0, 0.10), 0 2px 8px rgba(0, 0, 0, 0.05)',
            padding: 40,
            position: 'relative',
          }}
        >
          <svg width={plotW} height={plotH} viewBox={`0 0 ${plotW} ${plotH}`}>
            <defs>
              <linearGradient id="zoomFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={ui.cyan} stopOpacity={0.30} />
                <stop offset="100%" stopColor={ui.cyan} stopOpacity={0} />
              </linearGradient>
              <clipPath id="zoomClip">
                <rect x={0} y={0} width={plotW} height={plotH} />
              </clipPath>
            </defs>
            <g clipPath="url(#zoomClip)">
              {[0.2, 0.4, 0.6, 0.8].map((t) => (
                <line
                  key={t}
                  x1={0}
                  x2={plotW}
                  y1={plotH * t}
                  y2={plotH * t}
                  stroke="rgba(0,0,0,0.07)"
                  strokeWidth={1}
                />
              ))}
              <path d={area} fill="url(#zoomFill)" />
              <path
                d={path}
                fill="none"
                stroke={ui.cyan}
                strokeWidth={3.2}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              {/* The dashed guide and tip dot the library draws for the live
                  value, so the recreation reads as the same chart. */}
              <line
                x1={0}
                x2={plotW}
                y1={py(lastV)}
                y2={py(lastV)}
                stroke="rgba(0,117,143,0.45)"
                strokeWidth={1.5}
                strokeDasharray="7 7"
              />
              <circle
                cx={px(lastI)}
                cy={py(lastV)}
                r={7}
                fill={ui.cyan}
                stroke={ui.bg}
                strokeWidth={3}
              />
            </g>
            {/* Value-axis labels, matching the exported charts' gutter. */}
            {[0.12, 0.36, 0.6, 0.84].map((t) => (
              <text
                key={t}
                x={plotW - 8}
                y={plotH * t + 6}
                textAnchor="end"
                fill="rgba(0,0,0,0.42)"
                fontFamily={theme.fontMono}
                fontSize={17}
              >
                {(lo + (1 - t) * (hi - lo)).toFixed(1)}
              </text>
            ))}
          </svg>
          {/* Live value badge, pinned to the tip of the curve. */}
          <div
            style={{
              position: 'absolute',
              left: 40 + px(lastI) + 18,
              top: 40 + py(lastV) - 21,
              padding: '7px 16px',
              borderRadius: 999,
              background: ui.green,
              color: '#ffffff',
              fontFamily: theme.fontMono,
              fontSize: 22,
              fontWeight: 700,
              whiteSpace: 'nowrap',
              translate: '-100% 0px',
            }}
          >
            {lastV.toFixed(2)}
          </div>

          {/* Gesture indicators */}
          <div
            style={{
              position: 'absolute',
              inset: 40,
              opacity: pinchOpacity,
              pointerEvents: 'none',
            }}
          >
            {[-1, 1].map((side) => (
              <div
                key={side}
                style={{
                  position: 'absolute',
                  left: plotW / 2 + (side * pinchSpread) / 2 - 30,
                  top: plotH / 2 - 30,
                  width: 60,
                  height: 60,
                  borderRadius: 30,
                  background: 'rgba(0,0,0,0.10)',
                  border: '2px solid rgba(0,0,0,0.38)',
                }}
              />
            ))}
          </div>
          <div
            style={{
              position: 'absolute',
              left: 40 + plotW / 2 + dragX - 30,
              top: 40 + plotH / 2 - 30,
              width: 60,
              height: 60,
              borderRadius: 30,
              background: 'rgba(0,0,0,0.10)',
              border: '2px solid rgba(0,0,0,0.38)',
              opacity: dragOpacity,
            }}
          />

          {/* The live chip: green and pulsing while following, grey once a
              gesture takes the viewport off the leading edge. */}
          <div
            style={{
              position: 'absolute',
              top: 62,
              right: 62,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              padding: '9px 18px',
              borderRadius: 999,
              background: following ? 'rgba(23,121,74,0.12)' : 'rgba(0,0,0,0.05)',
              border: `1.5px solid ${following ? 'rgba(23,121,74,0.45)' : ui.border}`,
              color: following ? ui.green : ui.textTertiary,
              fontSize: 22,
              fontWeight: 700,
              letterSpacing: '0.10em',
            }}
          >
            <span
              style={{
                width: 11,
                height: 11,
                borderRadius: 6,
                background: following ? ui.green : ui.textTertiary,
                scale: following ? chipPulse : 1,
              }}
            />
            {following ? 'LIVE' : 'PAUSED'}
          </div>
        </div>

        <div style={{marginTop: 30, height: 46, position: 'relative', width: 1200}}>
          {captions.map((caption, i) => {
            const next = captions[i + 1]?.at ?? ZOOM_DURATION;
            return (
              <div
                key={caption.text}
                style={{
                  position: 'absolute',
                  width: '100%',
                  textAlign: 'center',
                  fontSize: 32,
                  fontWeight: 600,
                  color: ui.textSecondary,
                  opacity: interpolate(
                    frame,
                    [caption.at, caption.at + 8, next - 6, next],
                    [0, 1, 1, 0],
                    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
                  ),
                }}
              >
                {caption.text}
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// 4 — Annotations, legend, image export
// ---------------------------------------------------------------------------

const AnnotationsScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 200}, durationInFrames: 20});

  const chips = [
    {label: 'Multiple reference lines', color: ui.amber, at: 16},
    {label: 'Both axes — value and time', color: ui.violet, at: 34},
    {label: 'Shaded reference bands', color: ui.green, at: 52},
  ];

  return (
    <SceneShell duration={SCENES.annotations.duration} glow={ui.amber}>
      <AbsoluteFill style={{alignItems: 'center', paddingTop: 74}}>
        <Eyebrow color={ui.amber}>Annotations</Eyebrow>
        <div
          style={{
            marginTop: 20,
            fontSize: 66,
            fontWeight: 700,
            letterSpacing: '-0.025em',
            color: ui.text,
            opacity: headIn,
            translate: `0px ${(1 - headIn) * 20}px`,
          }}
        >
          Mark the moment that mattered
        </div>
        <ChartCard
          name="annotations"
          loop="hold"
          width={1280}
          height={720}
          delay={4}
          style={{marginTop: 30}}
        />
        <div style={{position: 'absolute', bottom: 44, display: 'flex', gap: 16}}>
          {chips.map((chip) => (
            <div
              key={chip.label}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 11,
                padding: '11px 22px',
                borderRadius: 999,
                border: `1.5px solid ${chip.color}44`,
                background: `${chip.color}12`,
                fontSize: 26,
                fontWeight: 600,
                color: ui.text,
                opacity: interpolate(frame, [chip.at, chip.at + 12], [0, 1], {
                  extrapolateLeft: 'clamp',
                  extrapolateRight: 'clamp',
                  easing: EASE_OUT,
                }),
                translate: `0px ${
                  interpolate(frame, [chip.at, chip.at + 12], [16, 0], {
                    extrapolateLeft: 'clamp',
                    extrapolateRight: 'clamp',
                    easing: EASE_OUT,
                  })
                }px`,
              }}
            >
              <span style={{width: 10, height: 10, borderRadius: 5, background: chip.color}} />
              {chip.label}
            </div>
          ))}
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

const LegendScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 200}, durationInFrames: 18});

  return (
    <SceneShell duration={SCENES.legend.duration} glow={ui.green}>
      <AbsoluteFill
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 84,
          padding: '0 120px',
        }}
      >
        <div style={{width: 640, opacity: headIn, translate: `${(1 - headIn) * -24}px 0px`}}>
          <Eyebrow color={ui.green}>Composition</Eyebrow>
          <div
            style={{
              marginTop: 22,
              fontSize: 68,
              fontWeight: 700,
              letterSpacing: '-0.025em',
              color: ui.text,
              lineHeight: 1.08,
            }}
          >
            A legend you can
            <br />
            place anywhere
          </div>
          <div style={{marginTop: 22, fontSize: 30, color: ui.textSecondary, lineHeight: 1.45}}>
            <code style={{fontFamily: theme.fontMono, color: ui.green}}>LivelineLegend</code> is a
            standalone view — build its items from any chart and lay it out beside, above or below
            the canvas.
          </div>
          <div
            style={{
              marginTop: 26,
              display: 'inline-block',
              padding: '14px 22px',
              borderRadius: 14,
              border: `1.5px solid ${ui.border}`,
              background: ui.surface,
              fontFamily: theme.fontMono,
              fontSize: 24,
              color: ui.textSecondary,
            }}
          >
            LivelineLegendItem.items(donut:style:)
          </div>
        </div>
        <ChartCard name="legend" width={860} height={484} delay={4} />
      </AbsoluteFill>
    </SceneShell>
  );
};

const ExportScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 16, stiffness: 120}});

  return (
    <SceneShell duration={SCENES.exportBeat.duration} glow={ui.blue}>
      <AbsoluteFill style={{opacity: 0.65}}>
        <Clip name="line-live" offset={40} />
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background:
            `radial-gradient(1020px 570px at 50% 50%, ${scrim(0.86)}, ${scrim(0.97)})`,
        }}
      />
      <AbsoluteFill
        style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 26}}
      >
        <Eyebrow>Image export</Eyebrow>
        <div
          style={{
            fontSize: 58,
            fontWeight: 700,
            letterSpacing: '-0.02em',
            color: ui.text,
            textAlign: 'center',
            opacity: headIn,
            translate: `0px ${(1 - headIn) * 22}px`,
            maxWidth: 1400,
            lineHeight: 1.2,
          }}
        >
          Every chart in this video was rendered by
        </div>
        <div
          style={{
            fontFamily: theme.fontMono,
            fontSize: 52,
            fontWeight: 700,
            color: ui.blue,
            padding: '16px 32px',
            borderRadius: 16,
            border: `1.5px solid ${ui.blue}55`,
            background: `${ui.blue}14`,
            opacity: interpolate(frame, [12, 26], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: EASE_OUT,
            }),
            scale: interpolate(frame, [12, 26], [0.9, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: EASE_OUT,
            }),
          }}
        >
          LivelineChartImageExporter
        </div>
        <div
          style={{
            fontSize: 30,
            color: ui.textSecondary,
            opacity: interpolate(frame, [24, 38], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          One PNG per frame, pinned to a deterministic <code style={{fontFamily: theme.fontMono}}>elapsedTime</code>.
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// 5 — Theme, RTL and localization
// ---------------------------------------------------------------------------

const ThemeScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 200}, durationInFrames: 18});
  // The two clips are the same stream rendered in both themes — same window
  // function, same elapsed time — so the crossfade lands frame-for-frame on the
  // same curve and only the palette moves.
  //
  // This is a light-mode cut, so the scene starts and ends light and visits dark
  // in the middle; a one-way light→dark dissolve would leave the page sitting on
  // a dark card at the hand-off into the RTL scene.
  const toDark = interpolate(frame, [26, 48, 64, 84], [0, 1, 1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });

  return (
    <SceneShell duration={SCENES.theme.duration} glow={ui.blue}>
      <AbsoluteFill style={{alignItems: 'center', paddingTop: 82}}>
        <Eyebrow>Theming</Eyebrow>
        <div
          style={{
            marginTop: 20,
            fontSize: 66,
            fontWeight: 700,
            letterSpacing: '-0.025em',
            color: ui.text,
            opacity: headIn,
            translate: `0px ${(1 - headIn) * 20}px`,
          }}
        >
          <code style={{fontFamily: theme.fontMono, color: ui.blue}}>.automatic</code> follows the
          system
        </div>
        <div
          style={{
            marginTop: 30,
            width: 1280,
            height: 720,
            borderRadius: 22,
            overflow: 'hidden',
            border: `1.5px solid ${ui.border}`,
            boxShadow: '0 24px 60px rgba(0, 0, 0, 0.10), 0 2px 8px rgba(0, 0, 0, 0.05)',
            position: 'relative',
          }}
        >
          <AbsoluteFill>
            <Clip name="line-live" loop="hold" />
          </AbsoluteFill>
          <AbsoluteFill style={{opacity: toDark}}>
            <Clip name="line-dark" loop="hold" />
          </AbsoluteFill>
        </div>
        <div
          style={{
            position: 'absolute',
            bottom: 46,
            display: 'flex',
            gap: 14,
            fontSize: 27,
            fontWeight: 600,
          }}
        >
          {[
            {label: 'Light', active: toDark < 0.5},
            {label: 'Dark', active: toDark >= 0.5},
          ].map((mode) => (
            <div
              key={mode.label}
              style={{
                padding: '11px 28px',
                borderRadius: 999,
                border: `1.5px solid ${mode.active ? ui.blue : ui.border}`,
                background: mode.active ? `${ui.blue}22` : ui.surface,
                color: mode.active ? ui.text : ui.textTertiary,
              }}
            >
              {mode.label}
            </div>
          ))}
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

const RtlScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 200}, durationInFrames: 18});

  const strings = [
    {locale: 'ar', text: 'مباشر'},
    {locale: 'he', text: 'חי'},
    {locale: 'ja', text: 'ライブ'},
    {locale: 'de', text: 'Live'},
  ];

  return (
    <SceneShell duration={SCENES.rtl.duration} glow={ui.violet}>
      <AbsoluteFill
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 80,
          padding: '0 110px',
        }}
      >
        <ChartCard name="rtl" width={880} height={495} delay={4} />
        <div style={{width: 680, opacity: headIn, translate: `${(1 - headIn) * 24}px 0px`}}>
          <Eyebrow color={ui.violet}>Internationalization</Eyebrow>
          <div
            style={{
              marginTop: 22,
              fontSize: 66,
              fontWeight: 700,
              letterSpacing: '-0.025em',
              color: ui.text,
              lineHeight: 1.08,
            }}
          >
            Right-to-left,
            <br />
            end to end
          </div>
          <div style={{marginTop: 22, fontSize: 29, color: ui.textSecondary, lineHeight: 1.45}}>
            An explicit coordinate transform mirrors the whole layout — axis, badge, gutter and
            hover — and every user-facing string now resolves through a stable-key localization
            layer with locale-aware value and time formatters.
          </div>
          <div style={{marginTop: 28, display: 'flex', gap: 12, flexWrap: 'wrap'}}>
            {strings.map((entry, i) => (
              <div
                key={entry.locale}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '10px 20px',
                  borderRadius: 999,
                  border: `1.5px solid ${ui.border}`,
                  background: ui.surface,
                  fontSize: 26,
                  color: ui.text,
                  opacity: interpolate(frame, [30 + i * 9, 42 + i * 9], [0, 1], {
                    extrapolateLeft: 'clamp',
                    extrapolateRight: 'clamp',
                    easing: EASE_OUT,
                  }),
                }}
              >
                <span style={{fontFamily: theme.fontMono, fontSize: 20, color: ui.textTertiary}}>
                  {entry.locale}
                </span>
                {entry.text}
              </div>
            ))}
          </div>
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// 6 — Accessibility
// ---------------------------------------------------------------------------

const AccessibilityScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 200}, durationInFrames: 18});

  const beats = [
    {
      title: 'VoiceOver Audio Graph',
      body: 'Every chart kind now vends an AXChartDescriptor, so the data can be played as sound.',
      color: ui.cyan,
      at: 18,
    },
    {
      title: 'Dynamic Type',
      body: 'All canvas-drawn text scales with the reader’s preferred size, up to the accessibility sizes.',
      color: ui.green,
      at: 42,
    },
    {
      title: 'Memoized accessibility model',
      body: 'The description is cached, so none of this costs a redraw.',
      color: ui.violet,
      at: 66,
    },
  ];

  return (
    <SceneShell duration={SCENES.accessibility.duration} glow={ui.cyan}>
      <AbsoluteFill
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 72,
          padding: '0 104px',
        }}
      >
        <div style={{width: 780}}>
          <div style={{opacity: headIn, translate: `${(1 - headIn) * -20}px 0px`}}>
            <Eyebrow color={ui.cyan}>Accessibility</Eyebrow>
            <div
              style={{
                marginTop: 22,
                fontSize: 66,
                fontWeight: 700,
                letterSpacing: '-0.025em',
                color: ui.text,
                lineHeight: 1.08,
              }}
            >
              Readable, hearable,
              <br />
              scalable
            </div>
          </div>
          <div style={{marginTop: 34, display: 'flex', flexDirection: 'column', gap: 22}}>
            {beats.map((beat) => (
              <div
                key={beat.title}
                style={{
                  padding: '20px 24px',
                  borderRadius: 16,
                  border: `1.5px solid ${ui.border}`,
                  background: ui.surface,
                  borderLeft: `4px solid ${beat.color}`,
                  opacity: interpolate(frame, [beat.at, beat.at + 14], [0, 1], {
                    extrapolateLeft: 'clamp',
                    extrapolateRight: 'clamp',
                    easing: EASE_OUT,
                  }),
                  translate: `${interpolate(frame, [beat.at, beat.at + 14], [-22, 0], {
                    extrapolateLeft: 'clamp',
                    extrapolateRight: 'clamp',
                    easing: EASE_OUT,
                  })}px 0px`,
                }}
              >
                <div style={{fontSize: 32, fontWeight: 700, color: ui.text}}>{beat.title}</div>
                <div style={{marginTop: 7, fontSize: 24, color: ui.textSecondary, lineHeight: 1.4}}>
                  {beat.body}
                </div>
              </div>
            ))}
          </div>
        </div>
        <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18}}>
          <ChartCard name="dynamic-type" width={840} height={473} delay={6} />
          <div style={{fontSize: 25, color: ui.textTertiary, fontFamily: theme.fontMono}}>
            dynamicTypeSize · .accessibility3
          </div>
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// 7 — Stats and outro
// ---------------------------------------------------------------------------

const CountUp: React.FC<{from: number; to: number; delay: number}> = ({from, to, delay}) => {
  const frame = useCurrentFrame();
  const value = interpolate(frame, [delay, delay + 26], [from, to], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: EASE_OUT,
  });
  return <>{Math.round(value)}</>;
};

const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const headIn = spring({frame: frame - 2, fps, config: {damping: 16, stiffness: 120}});
  const pulse = 1 + 0.14 * Math.sin((frame / 40) * Math.PI * 2);

  const stats: Array<{value: React.ReactNode; label: string; color: string; at: number}> = [
    {
      value: <CountUp from={113} to={251} delay={18} />,
      label: 'tests, up from 113',
      color: ui.green,
      at: 14,
    },
    {
      value: <CountUp from={21} to={27} delay={26} />,
      label: 'chart kinds, six of them new',
      color: ui.violet,
      at: 22,
    },
    {value: 'iOS 15+', label: 'macOS 12 · watchOS 8 · tvOS 16 · visionOS 1', color: ui.cyan, at: 30},
  ];

  return (
    <SceneShell
      duration={SCENES.outro.duration}
      glow={ui.blue}
      fadeOutStart={SCENES.outro.duration - 22}
    >
      <AbsoluteFill style={{opacity: 0.6}}>
        <Clip name="line-live" offset={70} loop="pingpong" />
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          background:
            `radial-gradient(1240px 720px at 50% 45%, ${scrim(0.86)}, ${scrim(0.97)})`,
        }}
      />
      <AbsoluteFill
        style={{alignItems: 'center', justifyContent: 'center', flexDirection: 'column'}}
      >
        <div
          style={{
            fontSize: 82,
            fontWeight: 700,
            letterSpacing: '-0.03em',
            color: ui.text,
            opacity: headIn,
            translate: `0px ${(1 - headIn) * 28}px`,
          }}
        >
          Liveline 0.6.0 is out
        </div>

        <div style={{marginTop: 52, display: 'flex', gap: 26}}>
          {stats.map((stat) => (
            <div
              key={stat.label}
              style={{
                width: 460,
                padding: '30px 32px',
                borderRadius: 20,
                border: `1.5px solid ${ui.border}`,
                background: ui.surfaceStrong,
                opacity: interpolate(frame, [stat.at, stat.at + 14], [0, 1], {
                  extrapolateLeft: 'clamp',
                  extrapolateRight: 'clamp',
                  easing: EASE_OUT,
                }),
                translate: `0px ${interpolate(frame, [stat.at, stat.at + 14], [26, 0], {
                  extrapolateLeft: 'clamp',
                  extrapolateRight: 'clamp',
                  easing: EASE_OUT,
                })}px`,
              }}
            >
              <div
                style={{
                  fontSize: 68,
                  fontWeight: 700,
                  letterSpacing: '-0.02em',
                  color: stat.color,
                  fontFamily: theme.fontMono,
                }}
              >
                {stat.value}
              </div>
              <div style={{marginTop: 8, fontSize: 25, color: ui.textSecondary}}>{stat.label}</div>
            </div>
          ))}
        </div>

        <div
          style={{
            marginTop: 52,
            padding: '24px 38px',
            borderRadius: 18,
            border: `1.5px solid ${ui.border}`,
            background: '#ffffff',
            fontFamily: theme.fontMono,
            fontSize: 28,
            color: ui.text,
            opacity: interpolate(frame, [56, 72], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
              easing: EASE_OUT,
            }),
          }}
        >
          <span style={{color: ui.textSecondary}}>.package(url: </span>
          <span style={{color: ui.blue}}>
            "https://github.com/ParthJadhav/liveline-swift.git"
          </span>
          <span style={{color: ui.textSecondary}}>, from: </span>
          <span style={{color: ui.green}}>"0.6.0"</span>
          <span style={{color: ui.textSecondary}}>)</span>
        </div>

        <div
          style={{
            marginTop: 44,
            display: 'flex',
            alignItems: 'center',
            gap: 14,
            opacity: interpolate(frame, [76, 92], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
          }}
        >
          <div
            style={{
              width: 14,
              height: 14,
              borderRadius: 7,
              background: ui.green,
              scale: pulse,
              boxShadow: `0 0 0 ${7 * pulse}px rgba(23,121,74,0.14)`,
            }}
          />
          <div style={{fontSize: 32, fontWeight: 600, color: ui.text}}>
            github.com/ParthJadhav/liveline-swift
          </div>
        </div>
      </AbsoluteFill>
    </SceneShell>
  );
};

// ---------------------------------------------------------------------------
// Composition
// ---------------------------------------------------------------------------

export const Liveline060Video: React.FC = () => {
  const musicA = 0;
  const musicB = 855; // bgm.m4a is 30s; two crossfaded passes cover the 50s cut.

  return (
    <AbsoluteFill style={{background: ui.bg}}>
      <Audio
        src={staticFile('audio/bgm.m4a')}
        volume={(f) =>
          interpolate(f, [0, 24, 825, 885], [0, 0.34, 0.34, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })
        }
      />
      <Sequence from={musicB} durationInFrames={TOTAL_DURATION_060 - musicB}>
        <Audio
          src={staticFile('audio/bgm.m4a')}
          volume={(f) =>
            interpolate(
              f,
              [0, 30, TOTAL_DURATION_060 - musicB - 90, TOTAL_DURATION_060 - musicB],
              [0, 0.34, 0.34, 0],
              {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
            )
          }
        />
      </Sequence>

      <Sequence from={SCENES.kindsIntro.from - 8} durationInFrames={40}>
        <Audio src={staticFile('audio/sfx/whoosh-cinematic.mp3')} volume={0.12} />
      </Sequence>
      <Sequence from={SCENES.zoomPan.from - 4} durationInFrames={34}>
        <Audio src={staticFile('audio/sfx/whoosh-short.mp3')} volume={0.09} />
      </Sequence>
      <Sequence from={SCENES.exportBeat.from + 10} durationInFrames={40}>
        <Audio src={staticFile('audio/sfx/pop.mp3')} volume={0.16} />
      </Sequence>
      <Sequence from={SCENES.outro.from + 4} durationInFrames={60}>
        <Audio src={staticFile('audio/sfx/sparkle.mp3')} volume={0.13} />
      </Sequence>

      <Sequence from={SCENES.title.from} durationInFrames={SCENES.title.duration + CROSSFADE} premountFor={30}>
        <TitleScene />
      </Sequence>
      <Sequence
        from={SCENES.kindsIntro.from}
        durationInFrames={SCENES.kindsIntro.duration + CROSSFADE}
        premountFor={30}
      >
        <KindsIntro />
      </Sequence>
      {NEW_KINDS.map((kind, i) => (
        <Sequence
          key={kind.clip}
          from={SCENES.kindsSpotlight.from + i * SPOT_DURATION}
          durationInFrames={SPOT_DURATION + CROSSFADE}
          premountFor={30}
        >
          <KindSpotlight kind={kind} index={i} />
        </Sequence>
      ))}
      <Sequence from={SCENES.zoomPan.from} durationInFrames={SCENES.zoomPan.duration + CROSSFADE} premountFor={30}>
        <ZoomPanScene />
      </Sequence>
      <Sequence
        from={SCENES.annotations.from}
        durationInFrames={SCENES.annotations.duration + CROSSFADE}
        premountFor={30}
      >
        <AnnotationsScene />
      </Sequence>
      <Sequence from={SCENES.legend.from} durationInFrames={SCENES.legend.duration + CROSSFADE} premountFor={30}>
        <LegendScene />
      </Sequence>
      <Sequence
        from={SCENES.exportBeat.from}
        durationInFrames={SCENES.exportBeat.duration + CROSSFADE}
        premountFor={30}
      >
        <ExportScene />
      </Sequence>
      <Sequence from={SCENES.theme.from} durationInFrames={SCENES.theme.duration + CROSSFADE} premountFor={30}>
        <ThemeScene />
      </Sequence>
      <Sequence from={SCENES.rtl.from} durationInFrames={SCENES.rtl.duration + CROSSFADE} premountFor={30}>
        <RtlScene />
      </Sequence>
      <Sequence
        from={SCENES.accessibility.from}
        durationInFrames={SCENES.accessibility.duration + CROSSFADE}
        premountFor={30}
      >
        <AccessibilityScene />
      </Sequence>
      <Sequence from={SCENES.outro.from} durationInFrames={SCENES.outro.duration} premountFor={30}>
        <OutroScene />
      </Sequence>
    </AbsoluteFill>
  );
};
