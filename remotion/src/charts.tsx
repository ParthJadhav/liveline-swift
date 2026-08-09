import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {formatPrice, streamValue} from './chartData';
import {theme} from './theme';

// Additional Liveline renderers recreated for the demo: gauge, signed bars,
// candlestick + volume, multi-series, stacked area, heatmap. Each animates in
// using the local sequence frame (entrance) and stays live via `streamFrame`
// (shared data clock across every device).

type Common = {streamFrame: number};

const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

const polar = (cx: number, cy: number, r: number, deg: number): [number, number] => {
  const a = ((deg - 90) * Math.PI) / 180;
  return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
};

const arcPath = (cx: number, cy: number, r: number, a0: number, a1: number) => {
  const [x0, y0] = polar(cx, cy, r, a0);
  const [x1, y1] = polar(cx, cy, r, a1);
  const large = a1 - a0 > 180 ? 1 : 0;
  return `M${x0.toFixed(2)},${y0.toFixed(2)} A${r},${r} 0 ${large} 1 ${x1.toFixed(2)},${y1.toFixed(2)}`;
};

// ── Gauge (watchOS) ─────────────────────────────────────────────────────────

export const GaugeChart: React.FC<Common & {size: number}> = ({streamFrame, size}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const reveal = spring({frame: frame - 4, fps, config: {damping: 16, stiffness: 80}});

  const live = 0.56 + 0.3 * Math.sin(streamFrame * 0.022 + 1.2) + 0.08 * Math.sin(streamFrame * 0.09);
  const pct = clamp01(live) * reveal;
  const a0 = -120;
  const a1 = a0 + 240 * pct;
  const cx = size / 2;
  const cy = size * 0.52;
  const R = size * 0.36;
  const stroke = size * 0.085;
  const [tipX, tipY] = polar(cx, cy, R, a1);
  const rising = Math.cos(streamFrame * 0.022 + 1.2) > 0;

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <defs>
        <linearGradient id="gauge-fill" x1="0" y1="1" x2="1" y2="0">
          <stop offset="0%" stopColor={theme.accent} />
          <stop offset="100%" stopColor={theme.appleTeal} />
        </linearGradient>
      </defs>
      <path
        d={arcPath(cx, cy, R, a0, a0 + 240)}
        fill="none"
        stroke={theme.trackGray}
        strokeWidth={stroke}
        strokeLinecap="round"
      />
      {pct > 0.005 ? (
        <path
          d={arcPath(cx, cy, R, a0, a1)}
          fill="none"
          stroke="url(#gauge-fill)"
          strokeWidth={stroke}
          strokeLinecap="round"
        />
      ) : null}
      <circle cx={tipX} cy={tipY} r={stroke * 0.85} fill={theme.accent} opacity={0.18} />
      <circle cx={tipX} cy={tipY} r={stroke * 0.38} fill="#fff" stroke={theme.accent} strokeWidth={3} />
      <text
        x={cx}
        y={cy + size * 0.02}
        textAnchor="middle"
        fontFamily={theme.fontMono}
        fontWeight={700}
        fontSize={size * 0.19}
        fill={theme.textPrimary}
      >
        {Math.round(clamp01(live) * 100)}%
      </text>
      <g opacity={reveal}>
        <circle
          cx={cx - size * 0.085}
          cy={cy + size * 0.115}
          r={size * 0.018}
          fill={rising ? theme.up : theme.down}
        />
        <text
          x={cx + size * 0.012}
          y={cy + size * 0.135}
          textAnchor="middle"
          fontFamily={theme.fontSans}
          fontWeight={600}
          fontSize={size * 0.062}
          fill={theme.textSecondary}
        >
          LIVE
        </text>
      </g>
      <text
        x={cx}
        y={cy + R + stroke * 0.4}
        textAnchor="middle"
        fontFamily={theme.fontMono}
        fontSize={size * 0.055}
        fill={theme.textTertiary}
      >
        {formatPrice(100 + (clamp01(live) - 0.5) * 12)}
      </text>
    </svg>
  );
};

// ── Signed bars (dashboards) ────────────────────────────────────────────────

export const SignedBarChart: React.FC<Common & {width: number; height: number}> = ({
  streamFrame,
  width,
  height,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const n = 13;
  const zero = height / 2;
  const bw = (width / n) * 0.56;
  const maxH = height * 0.44;

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      {[0.25, 0.75].map((f, i) => (
        <line
          key={i}
          x1={0}
          x2={width}
          y1={height * f}
          y2={height * f}
          stroke={theme.gridDots}
          strokeWidth={2}
          strokeDasharray={`0.1 ${9}`}
          strokeLinecap="round"
        />
      ))}
      <line x1={0} x2={width} y1={zero} y2={zero} stroke="rgba(0,0,0,0.14)" strokeWidth={2.5} />
      {Array.from({length: n}, (_, i) => {
        const v =
          0.62 * Math.sin(i * 0.93 + streamFrame * 0.028) +
          0.38 * Math.sin(i * 1.71 - streamFrame * 0.02 + 2);
        const rise = spring({frame: frame - 6 - i * 1.3, fps, config: {damping: 13, stiffness: 120}});
        const h = Math.max(6, Math.abs(v) * maxH * rise);
        const x = (width / n) * i + (width / n - bw) / 2;
        const up = v >= 0;
        return (
          <rect
            key={i}
            x={x}
            y={up ? zero - h : zero}
            width={bw}
            height={h}
            rx={bw * 0.3}
            fill={up ? theme.up : theme.down}
            opacity={0.9}
          />
        );
      })}
    </svg>
  );
};

// ── Candlestick + volume (macOS) ────────────────────────────────────────────

export const CandleChart: React.FC<
  Common & {width: number; height: number; uiScale?: number}
> = ({streamFrame, width, height, uiScale = 1}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const labelFont = 19 * uiScale;
  const badgeFont = 21 * uiScale;
  const badgeW = 6 * badgeFont * 0.62 + 26 * uiScale;
  const badgeH = badgeFont * 1.85;
  const gutterRight = Math.max(labelFont * 5.4, badgeW + 34 * uiScale);
  const volH = height * 0.16;
  const plotW = width - gutterRight;
  const plotH = height - volH - 30 * uiScale;

  const n = 22;
  const STEP = 6;
  const slot = Math.floor(streamFrame / STEP);
  type Candle = {open: number; close: number; high: number; low: number; live: boolean};
  const candles: Candle[] = [];
  for (let i = 0; i < n; i++) {
    const s = slot - (n - 1) + i;
    const t0 = s * STEP;
    const open = streamValue(t0);
    const isLive = i === n - 1;
    const close = isLive ? streamValue(streamFrame) : streamValue(t0 + STEP);
    const wig = 0.5 + 0.35 * Math.abs(Math.sin(s * 2.3));
    const high = Math.max(open, close) + wig;
    const low = Math.min(open, close) - wig;
    candles.push({open, close, high, low, live: isLive});
  }
  let min = Math.min(...candles.map((c) => c.low));
  let max = Math.max(...candles.map((c) => c.high));
  const span = Math.max(max - min, 1);
  min -= span * 0.08;
  max += span * 0.12;
  const yAt = (v: number) => (1 - (v - min) / (max - min)) * plotH;
  const cw = (plotW / n) * 0.55;

  const last = candles[n - 1];
  const lastX = (plotW / n) * (n - 0.5);
  const lastY = yAt(last.close);
  const lastUp = last.close >= last.open;
  const badgeColor = lastUp ? theme.up : theme.down;
  const badgeY = Math.min(Math.max(lastY - badgeH / 2, 0), plotH - badgeH);
  const gridLevels = [0.16, 0.5, 0.84].map((f) => min + (max - min) * f);

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      {gridLevels.map((level, i) => (
        <g key={i}>
          <line
            x1={0}
            x2={plotW}
            y1={yAt(level)}
            y2={yAt(level)}
            stroke={theme.gridDots}
            strokeWidth={1.6 * uiScale}
            strokeDasharray={`0.1 ${6 * uiScale}`}
            strokeLinecap="round"
          />
          {Math.abs(yAt(level) - lastY) > badgeH * 0.9 ? (
            <text
              x={width - 8 * uiScale}
              y={yAt(level) + labelFont * 0.34}
              textAnchor="end"
              fontFamily={theme.fontMono}
              fontSize={labelFont}
              fill={theme.gridLabel}
            >
              {formatPrice(level)}
            </text>
          ) : null}
        </g>
      ))}
      {candles.map((c, i) => {
        const cx = (plotW / n) * (i + 0.5);
        const up = c.close >= c.open;
        const color = up ? theme.up : theme.down;
        const inSpring = spring({frame: frame - 4 - i * 0.9, fps, config: {damping: 15, stiffness: 140}});
        const bodyTop = yAt(Math.max(c.open, c.close));
        const bodyH = Math.max(3 * uiScale, Math.abs(yAt(c.open) - yAt(c.close)));
        const vol = Math.abs(c.close - c.open) + 0.25;
        const vh = Math.min(1, vol / 2.2) * volH * 0.9 * inSpring;
        return (
          <g key={i} opacity={inSpring}>
            <line
              x1={cx}
              x2={cx}
              y1={yAt(c.high)}
              y2={yAt(c.low)}
              stroke={color}
              strokeWidth={2.2 * uiScale}
              strokeLinecap="round"
            />
            <rect
              x={cx - cw / 2}
              y={bodyTop}
              width={cw}
              height={bodyH}
              rx={2.5 * uiScale}
              fill={color}
            />
            {c.live ? (
              <circle cx={cx} cy={lastY} r={5 * uiScale} fill="#fff" stroke={color} strokeWidth={2.5 * uiScale} />
            ) : null}
            <rect
              x={cx - cw / 2}
              y={height - vh}
              width={cw}
              height={vh}
              rx={2 * uiScale}
              fill={color}
              opacity={0.35}
            />
          </g>
        );
      })}
      <line
        x1={0}
        x2={lastX - 8 * uiScale}
        y1={lastY}
        y2={lastY}
        stroke={badgeColor}
        strokeOpacity={0.45}
        strokeWidth={1.8 * uiScale}
        strokeDasharray={`${6 * uiScale} ${6 * uiScale}`}
      />
      <g>
        <rect
          x={width - badgeW - 4 * uiScale}
          y={badgeY}
          width={badgeW}
          height={badgeH}
          rx={badgeH / 2}
          fill={badgeColor}
        />
        <text
          x={width - badgeW / 2 - 4 * uiScale}
          y={badgeY + badgeH / 2 + badgeFont * 0.34}
          textAnchor="middle"
          fontFamily={theme.fontMono}
          fontWeight={700}
          fontSize={badgeFont}
          fill="#fff"
        >
          {formatPrice(last.close)}
        </text>
      </g>
    </svg>
  );
};

// ── Multi-series line (iPadOS) ──────────────────────────────────────────────

export const MultiLineChart: React.FC<
  Common & {width: number; height: number; uiScale?: number}
> = ({streamFrame, width, height, uiScale = 1}) => {
  const frame = useCurrentFrame();
  const labelFont = 19 * uiScale;
  const gutterRight = labelFont * 5.4;
  const legendH = labelFont * 2.6;
  const plotW = width - gutterRight;
  const plotH = height - legendH - 14 * uiScale;
  const windowSize = 100;

  const seriesA: number[] = [];
  const seriesB: number[] = [];
  for (let i = 0; i < windowSize; i++) {
    const t = streamFrame - windowSize + 1 + i;
    seriesA.push(streamValue(t));
    seriesB.push(100 + (streamValue(t * 0.92 + 260) - 100) * 0.72 - 2.4);
  }
  const all = [...seriesA, ...seriesB];
  let min = Math.min(...all);
  let max = Math.max(...all);
  const span = Math.max(max - min, 1);
  min -= span * 0.1;
  max += span * 0.12;
  const xAt = (i: number) => (i / (windowSize - 1)) * plotW;
  const yAt = (v: number) => legendH + (1 - (v - min) / (max - min)) * plotH;
  const toPath = (vals: number[]) => {
    const pts = vals.map((v, i) => [xAt(i), yAt(v)] as const);
    const seg = [`M${pts[0][0].toFixed(1)},${pts[0][1].toFixed(1)}`];
    for (let i = 1; i < pts.length - 1; i++) {
      const mx = (pts[i][0] + pts[i + 1][0]) / 2;
      const my = (pts[i][1] + pts[i + 1][1]) / 2;
      seg.push(`Q${pts[i][0].toFixed(1)},${pts[i][1].toFixed(1)} ${mx.toFixed(1)},${my.toFixed(1)}`);
    }
    return seg.join(' ');
  };

  const revealW = interpolate(frame, [4, 34], [0, width], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const gridLevels = [0.2, 0.5, 0.8].map((f) => min + (max - min) * f);
  const legend: Array<[string, string]> = [
    ['Series A', theme.accent],
    ['Series B', theme.appleGreen],
  ];

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      <defs>
        <clipPath id={`ml-reveal-${width}`}>
          <rect x={0} y={0} width={revealW} height={height} />
        </clipPath>
        <linearGradient id="ml-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={theme.accent} stopOpacity={0.1} />
          <stop offset="100%" stopColor={theme.accent} stopOpacity={0} />
        </linearGradient>
      </defs>
      {legend.map(([label, color], i) => (
        <g key={label} transform={`translate(${i * labelFont * 8.2}, 0)`}>
          <circle cx={labelFont * 0.5} cy={labelFont * 0.72} r={labelFont * 0.34} fill={color} />
          <text
            x={labelFont * 1.2}
            y={labelFont * 1.05}
            fontFamily={theme.fontSans}
            fontWeight={600}
            fontSize={labelFont}
            fill={theme.textSecondary}
          >
            {label}
          </text>
        </g>
      ))}
      {gridLevels.map((level, i) => (
        <g key={i}>
          <line
            x1={0}
            x2={plotW}
            y1={yAt(level)}
            y2={yAt(level)}
            stroke={theme.gridDots}
            strokeWidth={1.6 * uiScale}
            strokeDasharray={`0.1 ${6 * uiScale}`}
            strokeLinecap="round"
          />
          <text
            x={width - 8 * uiScale}
            y={yAt(level) + labelFont * 0.34}
            textAnchor="end"
            fontFamily={theme.fontMono}
            fontSize={labelFont}
            fill={theme.gridLabel}
          >
            {formatPrice(level)}
          </text>
        </g>
      ))}
      <g clipPath={`url(#ml-reveal-${width})`}>
        <path
          d={`${toPath(seriesA)} L${plotW},${legendH + plotH} L0,${legendH + plotH} Z`}
          fill="url(#ml-fill)"
        />
        <path d={toPath(seriesA)} fill="none" stroke={theme.accent} strokeWidth={3 * uiScale} strokeLinecap="round" />
        <path
          d={toPath(seriesB)}
          fill="none"
          stroke={theme.appleGreen}
          strokeWidth={3 * uiScale}
          strokeLinecap="round"
        />
      </g>
      {revealW >= width ? (
        <>
          <circle
            cx={plotW}
            cy={yAt(seriesA[windowSize - 1])}
            r={6 * uiScale}
            fill={theme.accent}
            stroke="#fff"
            strokeWidth={3 * uiScale}
          />
          <circle
            cx={plotW}
            cy={yAt(seriesB[windowSize - 1])}
            r={6 * uiScale}
            fill={theme.appleGreen}
            stroke="#fff"
            strokeWidth={3 * uiScale}
          />
        </>
      ) : null}
    </svg>
  );
};

// ── Donut (iPadOS side panel) ───────────────────────────────────────────────

export const DonutChart: React.FC<Common & {size: number}> = ({streamFrame, size}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const reveal = spring({frame: frame - 6, fps, config: {damping: 100, stiffness: 60}});

  const base = [0.38, 0.27, 0.2, 0.15];
  const wiggled = base.map((b, i) => b + 0.028 * Math.sin(streamFrame * 0.02 + i * 1.9));
  const total = wiggled.reduce((a, b) => a + b, 0);
  const fracs = wiggled.map((w) => w / total);
  const colors = [theme.accent, theme.appleGreen, theme.appleOrange, theme.applePurple];

  const cx = size / 2;
  const cy = size / 2;
  const R = size * 0.38;
  const stroke = size * 0.13;
  const sweep = 360 * reveal;

  let acc = 0;
  const segs = fracs.map((f, i) => {
    const a0 = acc * 360;
    acc += f;
    const a1 = acc * 360;
    return {a0: Math.min(a0, sweep), a1: Math.min(a1, sweep), color: colors[i]};
  });

  const liveTotal = 1180 + 60 * Math.sin(streamFrame * 0.018);

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {segs.map((s, i) =>
        s.a1 - s.a0 > 1 ? (
          <path
            key={i}
            d={arcPath(cx, cy, R, s.a0 + 1, s.a1 - 1)}
            fill="none"
            stroke={s.color}
            strokeWidth={stroke}
          />
        ) : null,
      )}
      <text
        x={cx}
        y={cy - size * 0.005}
        textAnchor="middle"
        fontFamily={theme.fontMono}
        fontWeight={700}
        fontSize={size * 0.13}
        fill={theme.textPrimary}
      >
        {`$${liveTotal.toFixed(0)}`}
      </text>
      <text
        x={cx}
        y={cy + size * 0.085}
        textAnchor="middle"
        fontFamily={theme.fontSans}
        fontWeight={600}
        fontSize={size * 0.055}
        fill={theme.textTertiary}
      >
        Total
      </text>
    </svg>
  );
};

// ── Stacked area (tvOS) ─────────────────────────────────────────────────────

export const StackedAreaChart: React.FC<
  Common & {width: number; height: number; uiScale?: number}
> = ({streamFrame, width, height, uiScale = 1}) => {
  const frame = useCurrentFrame();
  const labelFont = 19 * uiScale;
  const gutterRight = labelFont * 4.6;
  const legendH = labelFont * 2.6;
  const plotW = width - gutterRight;
  const plotH = height - legendH - 16 * uiScale;
  const windowSize = 90;

  const layer = (t: number, k: number) =>
    18 +
    7 * Math.sin(t * 0.045 + k * 2.1) +
    3.5 * Math.sin(t * 0.11 + k * 0.9) +
    1.4 * Math.sin(t * 0.31 + k * 1.7);

  const stacks: number[][] = [];
  for (let i = 0; i < windowSize; i++) {
    const t = streamFrame - windowSize + 1 + i;
    const l0 = layer(t, 0);
    const l1 = layer(t, 1) * 0.8;
    const l2 = layer(t, 2) * 0.6;
    stacks.push([l0, l0 + l1, l0 + l1 + l2]);
  }
  const maxTotal = Math.max(...stacks.map((s) => s[2])) * 1.15;
  const xAt = (i: number) => (i / (windowSize - 1)) * plotW;
  const yAt = (v: number) => legendH + (1 - v / maxTotal) * plotH;

  const smooth = (vals: number[]) => {
    const pts = vals.map((v, i) => [xAt(i), yAt(v)] as const);
    const seg = [`M${pts[0][0].toFixed(1)},${pts[0][1].toFixed(1)}`];
    for (let i = 1; i < pts.length - 1; i++) {
      const mx = (pts[i][0] + pts[i + 1][0]) / 2;
      const my = (pts[i][1] + pts[i + 1][1]) / 2;
      seg.push(`Q${pts[i][0].toFixed(1)},${pts[i][1].toFixed(1)} ${mx.toFixed(1)},${my.toFixed(1)}`);
    }
    seg.push(`L${pts[pts.length - 1][0].toFixed(1)},${pts[pts.length - 1][1].toFixed(1)}`);
    return seg.join(' ');
  };

  const floor = `L${plotW},${legendH + plotH} L0,${legendH + plotH} Z`;
  const layers = [
    {path: `${smooth(stacks.map((s) => s[2]))} ${floor}`, color: theme.appleOrange, alpha: 0.5},
    {path: `${smooth(stacks.map((s) => s[1]))} ${floor}`, color: theme.appleGreen, alpha: 0.55},
    {path: `${smooth(stacks.map((s) => s[0]))} ${floor}`, color: theme.accent, alpha: 0.65},
  ];
  const revealW = interpolate(frame, [4, 36], [0, width], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const legend: Array<[string, string]> = [
    ['Compute', theme.accent],
    ['Storage', theme.appleGreen],
    ['Network', theme.appleOrange],
  ];
  const gridLevels = [0.25, 0.55, 0.85];

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      <defs>
        <clipPath id={`sa-reveal-${width}`}>
          <rect x={0} y={0} width={revealW} height={height} />
        </clipPath>
      </defs>
      {legend.map(([label, color], i) => (
        <g key={label} transform={`translate(${i * labelFont * 8.6}, 0)`}>
          <rect
            x={0}
            y={labelFont * 0.3}
            width={labelFont * 0.85}
            height={labelFont * 0.85}
            rx={labelFont * 0.24}
            fill={color}
          />
          <text
            x={labelFont * 1.3}
            y={labelFont * 1.05}
            fontFamily={theme.fontSans}
            fontWeight={600}
            fontSize={labelFont}
            fill={theme.textSecondary}
          >
            {label}
          </text>
        </g>
      ))}
      {gridLevels.map((f, i) => (
        <g key={i}>
          <line
            x1={0}
            x2={plotW}
            y1={legendH + plotH * (1 - f)}
            y2={legendH + plotH * (1 - f)}
            stroke={theme.gridDots}
            strokeWidth={1.6 * uiScale}
            strokeDasharray={`0.1 ${6 * uiScale}`}
            strokeLinecap="round"
          />
          <text
            x={width - 8 * uiScale}
            y={legendH + plotH * (1 - f) + labelFont * 0.34}
            textAnchor="end"
            fontFamily={theme.fontMono}
            fontSize={labelFont}
            fill={theme.gridLabel}
          >
            {`${Math.round(maxTotal * f)} GB`}
          </text>
        </g>
      ))}
      <g clipPath={`url(#sa-reveal-${width})`}>
        {layers.map((l, i) => (
          <path key={i} d={l.path} fill={l.color} opacity={l.alpha} />
        ))}
        <path
          d={smooth(stacks.map((s) => s[2]))}
          fill="none"
          stroke={theme.appleOrange}
          strokeWidth={2.5 * uiScale}
        />
      </g>
    </svg>
  );
};

// ── Heatmap (visionOS glass window) ─────────────────────────────────────────

export const HeatmapChart: React.FC<
  Common & {width: number; height: number; cols?: number; rows?: number}
> = ({streamFrame, width, height, cols = 13, rows = 6}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const gap = Math.min(width / cols, height / rows) * 0.12;
  const cw = (width - gap * (cols - 1)) / cols;
  const ch = (height - gap * (rows - 1)) / rows;
  const showValues = cw > 58;

  const cellColor = (v: number) => {
    if (v > 0.86) return theme.up;
    const t = clamp01(v / 0.86);
    const mix = (a: number, b: number) => Math.round(a + (b - a) * t);
    return `rgb(${mix(238, 0)}, ${mix(243, 122)}, ${mix(248, 255)})`;
  };

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      {Array.from({length: rows}, (_, r) =>
        Array.from({length: cols}, (_, c) => {
          const v =
            0.5 +
            0.32 * Math.sin(c * 0.74 + r * 1.13 + streamFrame * 0.045) +
            0.18 * Math.sin(c * 1.4 - r * 0.8 + streamFrame * 0.02 + 3);
          const val = clamp01(v);
          const pop = spring({
            frame: frame - 3 - (c + r) * 0.8,
            fps,
            config: {damping: 14, stiffness: 160},
          });
          const x = c * (cw + gap);
          const y = r * (ch + gap);
          return (
            <g key={`${r}-${c}`} opacity={pop} transform={`translate(${x + cw / 2}, ${y + ch / 2}) scale(${0.6 + 0.4 * pop})`}>
              <rect x={-cw / 2} y={-ch / 2} width={cw} height={ch} rx={Math.min(cw, ch) * 0.22} fill={cellColor(val)} />
              {showValues ? (
                <text
                  x={0}
                  y={ch * 0.09}
                  textAnchor="middle"
                  fontFamily={theme.fontMono}
                  fontWeight={600}
                  fontSize={Math.min(cw, ch) * 0.3}
                  fill={val > 0.55 ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.45)'}
                >
                  {Math.round(val * 99)}
                </text>
              ) : null}
            </g>
          );
        }),
      )}
    </svg>
  );
};
