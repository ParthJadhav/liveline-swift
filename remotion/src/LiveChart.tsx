import React from 'react';
import {clockLabel, formatPrice, streamValue} from './chartData';
import {theme} from './theme';

type LiveChartProps = {
  // Absolute frame driving the stream, so every device stays in sync.
  streamFrame: number;
  width: number;
  height: number;
  // Multiplier for labels, badge, dot — smaller devices pass < 1.
  uiScale?: number;
  showTimeAxis?: boolean;
  showPriceLabels?: boolean;
  windowSize?: number;
};

export const LiveChart: React.FC<LiveChartProps> = ({
  streamFrame,
  width,
  height,
  uiScale = 1,
  showTimeAxis = true,
  showPriceLabels = true,
  windowSize = 110,
}) => {
  const labelFont = 19 * uiScale;
  const badgeFont = 21 * uiScale;
  const badgeW = 6 * badgeFont * 0.62 + 26 * uiScale;
  const badgeH = badgeFont * 1.85;
  // Without price labels (small screens) let the badge overhang the plot
  // instead of reserving a full empty gutter.
  const gutterRight = showPriceLabels
    ? Math.max(labelFont * 5.4, badgeW + 34 * uiScale)
    : badgeW * 0.5;
  const gutterBottom = showTimeAxis ? labelFont * 1.9 : 10 * uiScale;
  const padTop = 16 * uiScale;
  const padLeft = 10 * uiScale;
  const plotW = width - padLeft - gutterRight;
  const plotH = height - padTop - gutterBottom;

  const values: number[] = [];
  for (let i = 0; i < windowSize; i++) {
    values.push(streamValue(streamFrame - windowSize + 1 + i));
  }
  let min = Math.min(...values);
  let max = Math.max(...values);
  const span = Math.max(max - min, 1);
  min -= span * 0.12;
  max += span * 0.16;

  const xAt = (i: number) => padLeft + (i / (windowSize - 1)) * plotW;
  const yAt = (v: number) => padTop + (1 - (v - min) / (max - min)) * plotH;

  // Smooth curve through sample midpoints, matching the library's rendering.
  const pts = values.map((v, i) => [xAt(i), yAt(v)] as const);
  const segments: string[] = [`M${pts[0][0].toFixed(2)},${pts[0][1].toFixed(2)}`];
  for (let i = 1; i < pts.length - 1; i++) {
    const mx = (pts[i][0] + pts[i + 1][0]) / 2;
    const my = (pts[i][1] + pts[i + 1][1]) / 2;
    segments.push(
      `Q${pts[i][0].toFixed(2)},${pts[i][1].toFixed(2)} ${mx.toFixed(2)},${my.toFixed(2)}`,
    );
  }
  const last = pts[pts.length - 1];
  segments.push(`L${last[0].toFixed(2)},${last[1].toFixed(2)}`);
  const linePath = segments.join(' ');
  const areaPath = `${linePath} L${(padLeft + plotW).toFixed(2)},${(padTop + plotH).toFixed(2)} L${padLeft.toFixed(2)},${(padTop + plotH).toFixed(2)} Z`;

  const tip = values[values.length - 1];
  const tipX = xAt(windowSize - 1);
  const tipY = yAt(tip);
  const delta = tip - streamValue(streamFrame - 3);
  const momentum = delta > 0.015 ? 'up' : delta < -0.015 ? 'down' : 'flat';
  const momentumColor =
    momentum === 'up' ? theme.up : momentum === 'down' ? theme.down : theme.accent;

  const gridLevels = [0.18, 0.42, 0.66, 0.9].map((f) => min + (max - min) * f);
  const gradientId = `liveline-fill-${Math.round(width)}-${Math.round(height)}`;

  const dotR = 7 * uiScale;
  const badgeText = formatPrice(tip);
  const chevronX = tipX + dotR + 14 * uiScale;
  const badgeX = Math.min(chevronX + 16 * uiScale, width - badgeW - 4 * uiScale);
  const badgeY = Math.min(Math.max(tipY - badgeH / 2, padTop), padTop + plotH - badgeH);

  const timeStamps = showTimeAxis
    ? (plotW > 900 ? [0.16, 0.5, 0.84] : [0.25, 0.75]).map((f) => ({
        x: padLeft + plotW * f,
        label: clockLabel(streamFrame - windowSize * (1 - f)),
      }))
    : [];

  const chevron = (cy: number) => {
    const w = 8 * uiScale;
    const h = 4.5 * uiScale;
    const dir = momentum === 'down' ? -1 : 1;
    return `M${chevronX - w / 2},${cy + (h / 2) * dir} L${chevronX},${cy - (h / 2) * dir} L${chevronX + w / 2},${cy + (h / 2) * dir}`;
  };

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
      <defs>
        <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={theme.accent} stopOpacity={0.1} />
          <stop offset="100%" stopColor={theme.accent} stopOpacity={0} />
        </linearGradient>
      </defs>

      {gridLevels.map((level, i) => (
        <g key={i}>
          <line
            x1={padLeft}
            x2={padLeft + plotW}
            y1={yAt(level)}
            y2={yAt(level)}
            stroke={theme.gridDots}
            strokeWidth={1.6 * uiScale}
            strokeDasharray={`0.1 ${6 * uiScale}`}
            strokeLinecap="round"
          />
          {showPriceLabels && Math.abs(yAt(level) - tipY) > badgeH * 0.9 ? (
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

      <path d={areaPath} fill={`url(#${gradientId})`} />
      <path
        d={linePath}
        fill="none"
        stroke={theme.accent}
        strokeWidth={3 * uiScale}
        strokeLinejoin="round"
        strokeLinecap="round"
      />

      <line
        x1={padLeft}
        x2={tipX - dotR - 4 * uiScale}
        y1={tipY}
        y2={tipY}
        stroke={theme.accent}
        strokeOpacity={0.4}
        strokeWidth={1.8 * uiScale}
        strokeDasharray={`${6 * uiScale} ${6 * uiScale}`}
      />

      <circle cx={tipX} cy={tipY} r={dotR * 2.1} fill={momentumColor} opacity={0.18} />
      <circle
        cx={tipX}
        cy={tipY}
        r={dotR}
        fill={theme.accent}
        stroke="#ffffff"
        strokeWidth={3 * uiScale}
      />

      {momentum !== 'flat' ? (
        <g
          stroke="rgba(0,0,0,0.45)"
          strokeWidth={2.2 * uiScale}
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d={chevron(tipY - 3.5 * uiScale)} />
          <path d={chevron(tipY + 3.5 * uiScale)} />
        </g>
      ) : null}

      <g>
        <rect
          x={badgeX}
          y={badgeY}
          width={badgeW}
          height={badgeH}
          rx={badgeH / 2}
          fill={momentumColor}
        />
        <text
          x={badgeX + badgeW / 2}
          y={badgeY + badgeH / 2 + badgeFont * 0.34}
          textAnchor="middle"
          fontFamily={theme.fontMono}
          fontWeight={700}
          fontSize={badgeFont}
          fill="#ffffff"
        >
          {badgeText}
        </text>
      </g>

      {timeStamps.map((t, i) => (
        <text
          key={i}
          x={t.x}
          y={height - labelFont * 0.5}
          textAnchor="middle"
          fontFamily={theme.fontMono}
          fontSize={labelFont * 0.92}
          fill={theme.textTertiary}
        >
          {t.label}
        </text>
      ))}
    </svg>
  );
};
