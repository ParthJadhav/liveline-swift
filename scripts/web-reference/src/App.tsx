import { createRoot } from 'react-dom/client'
import { Liveline } from '@liveline-upstream'
import type {
  BadgeVariant,
  CandlePoint,
  DegenOptions,
  LivelinePoint,
  LivelineProps,
  LivelineSeries,
  Momentum,
  OrderbookData,
  ReferenceLine,
  ThemeMode,
  WindowOption,
  WindowStyle,
} from '@liveline-upstream'

type Shape = 'calm' | 'normal' | 'spiky' | 'rising' | 'falling'

interface Scenario {
  id: string
  group: string
  title: string
  detail: string
  background: string
  height: number
  props: LivelineProps
}

interface LineConfigOptions {
  theme: ThemeMode
  window?: number
  windows?: WindowOption[]
  windowStyle?: WindowStyle
  grid?: boolean
  badge?: boolean
  badgeVariant?: BadgeVariant
  fill?: boolean
  momentum?: Momentum
  exaggerate?: boolean
  showValue?: boolean
  valueMomentumColor?: boolean
  loading?: boolean
  emptyText?: string
  referenceLine?: ReferenceLine
  orderbook?: OrderbookData
  degen?: DegenOptions
  lineMode?: boolean
  seriesToggleCompact?: boolean
}

const colors = {
  darkBackground: '#0a0a0a',
  blue: '#3b82f6',
  red: '#ef4444',
  green: '#22c55e',
  cyan: '#06b6d4',
  orange: '#f97316',
  bitcoinOrange: '#f7931a',
  violet: '#8b5cf6',
  indigo: '#6366f1',
  teal: '#14b8a6',
}

const baseTime = 1_788_888_000

const windows: WindowOption[] = [
  { label: '15s', secs: 15 },
  { label: '30s', secs: 30 },
  { label: '2m', secs: 120 },
  { label: '5m', secs: 300 },
]

const orderbook: OrderbookData = {
  bids: Array.from({ length: 12 }, (_, index) => {
    const level = index + 1
    return [100 - level * 0.2, level * 0.8 + 1.4]
  }),
  asks: Array.from({ length: 12 }, (_, index) => {
    const level = index + 1
    return [100 + level * 0.2, (13 - level) * 0.7 + 1.1]
  }),
}

function points(shape: Shape, count = 260, step = 1): LivelinePoint[] {
  return Array.from({ length: count }, (_, index) => {
    const t = index
    let value: number

    switch (shape) {
      case 'calm':
        value = 100 + Math.sin(t * 0.13) * 0.42 + Math.cos(t * 0.037) * 0.18
        break
      case 'normal':
        value = 100 + Math.sin(t * 0.10) * 2.5 + Math.cos(t * 0.031) * 4.2 + Math.sin(t * 0.015) * 1.6
        break
      case 'spiky': {
        const spike = index % 37 === 0 ? (index % 74 === 0 ? 7.5 : -5.8) : 0
        value = 100 + Math.sin(t * 0.12) * 3.8 + Math.cos(t * 0.055) * 2.7 + spike
        break
      }
      case 'rising':
        value = 96 + t * 0.035 + Math.sin(t * 0.11) * 1.7 + Math.cos(t * 0.04) * 0.8
        break
      case 'falling':
        value = 108 - t * 0.033 + Math.sin(t * 0.11) * 1.7 + Math.cos(t * 0.04) * 0.8
        break
    }

    return {
      time: baseTime - (count - index - 1) * step,
      value,
    }
  })
}

function lastValue(data: LivelinePoint[]): number {
  return data[data.length - 1]?.value ?? 0
}

function series(): LivelineSeries[] {
  const first = points('normal', 240)
  const second = first.map((point, index) => ({
    time: point.time,
    value: point.value - 3.2 + Math.cos(index * 0.07) * 2.4,
  }))
  const third = first.map((point, index) => ({
    time: point.time,
    value: point.value + 4.4 + Math.sin(index * 0.06 + 1.4) * 3.2,
  }))

  return [
    { id: 'alpha', data: first, value: lastValue(first), color: colors.blue, label: 'Alpha' },
    { id: 'beta', data: second, value: lastValue(second), color: colors.red, label: 'Beta' },
    { id: 'gamma', data: third, value: lastValue(third), color: colors.green, label: 'Gamma' },
  ]
}

function candles(width: number): { committed: CandlePoint[]; live?: CandlePoint } {
  const source = points('normal', 360)
  const committed: CandlePoint[] = []
  let current: CandlePoint | undefined

  for (const point of source) {
    const bucket = Math.floor(point.time / width) * width
    if (!current) {
      current = { time: bucket, open: point.value, high: point.value, low: point.value, close: point.value }
    } else if (current.time === bucket) {
      current = {
        ...current,
        high: Math.max(current.high, point.value),
        low: Math.min(current.low, point.value),
        close: point.value,
      }
    } else {
      committed.push(current)
      current = { time: bucket, open: point.value, high: point.value, low: point.value, close: point.value }
    }
  }

  return { committed, live: current }
}

function money(value: number): string {
  return `$${value.toFixed(2)}`
}

function lineConfig(options: LineConfigOptions): Partial<LivelineProps> {
  return {
    theme: options.theme,
    window: options.window ?? 60,
    windows: options.windows ?? [],
    grid: options.grid ?? true,
    badge: options.badge ?? true,
    badgeVariant: options.badgeVariant ?? 'default',
    fill: options.fill ?? true,
    momentum: options.momentum,
    exaggerate: options.exaggerate ?? false,
    showValue: options.showValue ?? false,
    valueMomentumColor: options.valueMomentumColor ?? false,
    degen: options.degen,
    loading: options.loading ?? false,
    emptyText: options.emptyText ?? 'No data to display',
    windowStyle: options.windowStyle,
    orderbook: options.orderbook,
    referenceLine: options.referenceLine,
    formatValue: money,
    lineMode: options.lineMode ?? false,
    seriesToggleCompact: options.seriesToggleCompact ?? false,
  }
}

function lineScenario(
  id: string,
  group: string,
  title: string,
  detail: string,
  background: string,
  shape: Shape,
  color: string,
  config: Partial<LivelineProps>,
  height = 280,
): Scenario {
  const data = points(shape)
  return {
    id,
    group,
    title,
    detail,
    background,
    height,
    props: {
      data,
      value: lastValue(data),
      color,
      ...config,
    },
  }
}

function candleScenario(
  id: string,
  title: string,
  detail: string,
  background: string,
  width: number,
  config: Partial<LivelineProps>,
  options: { live?: boolean; lineMode?: boolean } = { live: true },
): Scenario {
  const data = points('normal')
  const candleSet = candles(width)
  const live = options.live === false ? undefined : candleSet.live
  const lineMode = options.lineMode ?? false

  return {
    id,
    group: 'Candles',
    title,
    detail,
    background,
    height: 280,
    props: {
      mode: 'candle',
      data,
      value: options.live === false ? candleSet.committed[candleSet.committed.length - 1]?.close ?? 0 : lastValue(data),
      candles: candleSet.committed,
      candleWidth: width,
      liveCandle: live,
      lineData: live || lineMode ? data : undefined,
      lineValue: live || lineMode ? lastValue(data) : undefined,
      color: colors.bitcoinOrange,
      ...config,
    },
  }
}

const scenarios: Scenario[] = [
  lineScenario(
    'line-basic-dark',
    'Line',
    'Basic Dark',
    'Default line, fill, grid, badge, pulse.',
    colors.darkBackground,
    'normal',
    colors.blue,
    lineConfig({ theme: 'dark' }),
  ),
  lineScenario(
    'line-basic-light',
    'Line',
    'Basic Light',
    'Default line in light theme.',
    '#ffffff',
    'normal',
    colors.blue,
    lineConfig({ theme: 'light' }),
  ),
  lineScenario(
    'line-no-grid-no-fill',
    'Line',
    'No Grid / No Fill',
    'Minimal canvas with line and live badge.',
    colors.darkBackground,
    'calm',
    colors.cyan,
    lineConfig({ theme: 'dark', grid: false, fill: false }),
  ),
  lineScenario(
    'line-minimal-badge',
    'Line',
    'Minimal Badge',
    'White badge variant with tail.',
    colors.darkBackground,
    'normal',
    colors.orange,
    lineConfig({ theme: 'dark', badgeVariant: 'minimal' }),
  ),
  lineScenario(
    'line-no-badge',
    'Line',
    'No Badge',
    'Right padding collapses to grid label width.',
    colors.darkBackground,
    'spiky',
    colors.violet,
    lineConfig({ theme: 'dark', badge: false }),
  ),
  lineScenario(
    'line-momentum-up',
    'Line',
    'Momentum Up',
    'Forced up momentum, green dot and arrows.',
    colors.darkBackground,
    'rising',
    colors.blue,
    lineConfig({ theme: 'dark', momentum: 'up' }),
  ),
  lineScenario(
    'line-momentum-down',
    'Line',
    'Momentum Down',
    'Forced down momentum, red dot and arrows.',
    colors.darkBackground,
    'falling',
    colors.blue,
    lineConfig({ theme: 'dark', momentum: 'down' }),
  ),
  lineScenario(
    'line-exaggerated',
    'Line',
    'Exaggerated Range',
    'Small changes fill the vertical space.',
    colors.darkBackground,
    'calm',
    colors.teal,
    lineConfig({ theme: 'dark', exaggerate: true }),
  ),
  lineScenario(
    'line-show-value-windows',
    'Line',
    'Value + Windows',
    'Live value display and default window control.',
    colors.darkBackground,
    'normal',
    colors.blue,
    lineConfig({ theme: 'dark', windows, showValue: true, valueMomentumColor: true }),
    310,
  ),
  lineScenario(
    'line-rounded-windows',
    'Line',
    'Rounded Windows',
    'Rounded control style.',
    colors.darkBackground,
    'normal',
    colors.blue,
    lineConfig({ theme: 'dark', windows, windowStyle: 'rounded' }),
    300,
  ),
  lineScenario(
    'line-text-windows',
    'Line',
    'Text Windows',
    'Text-only window style.',
    colors.darkBackground,
    'normal',
    colors.blue,
    lineConfig({ theme: 'dark', windows, windowStyle: 'text' }),
    300,
  ),
  lineScenario(
    'line-reference',
    'Line',
    'Reference Line',
    'Reference label and always-visible range.',
    colors.darkBackground,
    'normal',
    colors.indigo,
    lineConfig({ theme: 'dark', referenceLine: { value: 100.8, label: 'Open' } }),
  ),
  lineScenario(
    'line-orderbook',
    'Line',
    'Orderbook',
    'Streaming bid/ask labels behind the chart.',
    colors.darkBackground,
    'spiky',
    colors.orange,
    lineConfig({ theme: 'dark', orderbook }),
  ),
  lineScenario(
    'line-degen',
    'Line',
    'Degen',
    'Particles and shake on momentum changes.',
    colors.darkBackground,
    'rising',
    colors.orange,
    lineConfig({ theme: 'dark', momentum: 'up', degen: { scale: 1, downMomentum: true } }),
  ),
  {
    id: 'line-loading',
    group: 'States',
    title: 'Loading',
    detail: 'Breathing loading shape.',
    background: colors.darkBackground,
    height: 280,
    props: {
      data: [],
      value: 0,
      color: colors.blue,
      ...lineConfig({ theme: 'dark', loading: true }),
    },
  },
  {
    id: 'line-empty',
    group: 'States',
    title: 'Empty',
    detail: 'Empty state label.',
    background: colors.darkBackground,
    height: 280,
    props: {
      data: [],
      value: 0,
      color: colors.blue,
      ...lineConfig({ theme: 'dark', emptyText: 'No data to display' }),
    },
  },
  candleScenario(
    'candle-basic',
    'Basic Candles',
    'OHLC bodies, wicks, live candle.',
    colors.darkBackground,
    30,
    lineConfig({ theme: 'dark', window: 240, badge: false }),
  ),
  candleScenario(
    'candle-light',
    'Light Candles',
    'Candle mode in light theme.',
    '#ffffff',
    30,
    lineConfig({ theme: 'light', window: 240, badge: false }),
  ),
  candleScenario(
    'candle-line-mode',
    'Candle Line Mode',
    'Candle data rendered as dense line.',
    colors.darkBackground,
    30,
    lineConfig({ theme: 'dark', window: 240, lineMode: true }),
    { live: true, lineMode: true },
  ),
  {
    id: 'candle-mode-controls',
    group: 'Candles',
    title: 'Mode Controls',
    detail: 'Built-in candle and line mode toggle.',
    background: colors.darkBackground,
    height: 300,
    props: (() => {
      const data = points('normal')
      const candleSet = candles(30)
      return {
        mode: 'candle',
        data,
        value: lastValue(data),
        candles: candleSet.committed,
        candleWidth: 30,
        liveCandle: candleSet.live,
        lineData: data,
        lineValue: lastValue(data),
        color: colors.bitcoinOrange,
        ...lineConfig({ theme: 'dark', window: 240 }),
        onModeChange: () => {},
      }
    })(),
  },
  candleScenario(
    'candle-no-live',
    'No Live Candle',
    'Committed OHLC bars only.',
    colors.darkBackground,
    30,
    lineConfig({ theme: 'dark', window: 240, badge: false }),
    { live: false },
  ),
  candleScenario(
    'candle-wide-window',
    'Wide Window',
    'Small candle bodies across wider time range.',
    colors.darkBackground,
    15,
    lineConfig({ theme: 'dark', window: 360, badge: false }),
  ),
  {
    id: 'candle-loading',
    group: 'States',
    title: 'Candle Loading',
    detail: 'Loading state in candle setup.',
    background: colors.darkBackground,
    height: 280,
    props: {
      mode: 'candle',
      data: [],
      value: 0,
      candles: [],
      candleWidth: 30,
      color: colors.bitcoinOrange,
      ...lineConfig({ theme: 'dark', loading: true }),
    },
  },
  {
    id: 'multi-basic',
    group: 'Multi-series',
    title: 'Basic Multi',
    detail: 'Three overlapping lines, shared grid.',
    background: colors.darkBackground,
    height: 280,
    props: {
      data: [],
      value: 0,
      series: series(),
      ...lineConfig({ theme: 'dark', window: 180 }),
    },
  },
  {
    id: 'multi-light',
    group: 'Multi-series',
    title: 'Light Multi',
    detail: 'Multi-series in light theme.',
    background: '#ffffff',
    height: 280,
    props: {
      data: [],
      value: 0,
      series: series(),
      ...lineConfig({ theme: 'light', window: 180 }),
    },
  },
  {
    id: 'multi-compact',
    group: 'Multi-series',
    title: 'Compact Toggles',
    detail: 'Dot-only series controls.',
    background: colors.darkBackground,
    height: 280,
    props: {
      data: [],
      value: 0,
      series: series(),
      ...lineConfig({ theme: 'dark', window: 180, seriesToggleCompact: true }),
    },
  },
  {
    id: 'multi-two-series',
    group: 'Multi-series',
    title: 'Two Series',
    detail: 'Two-line comparison.',
    background: colors.darkBackground,
    height: 280,
    props: {
      data: [],
      value: 0,
      series: series().slice(0, 2),
      ...lineConfig({ theme: 'dark', window: 180 }),
    },
  },
]

declare global {
  interface Window {
    __LIVELINE_STORYBOOK_IDS__?: string[]
  }
}

window.__LIVELINE_STORYBOOK_IDS__ = scenarios.map((scenario) => scenario.id)

function App() {
  const params = new URLSearchParams(window.location.search)
  const selected = params.get('scenario') ?? scenarios[0].id
  const scenario = scenarios.find((entry) => entry.id === selected) ?? scenarios[0]

  document.title = `Liveline Reference - ${scenario.id}`

  return (
    <main className="stage">
      <div
        id="capture"
        className="capture"
        data-scenario={scenario.id}
        style={{
          background: scenario.background,
          height: scenario.height + 8,
        }}
      >
        <Liveline {...scenario.props} />
      </div>
    </main>
  )
}

const root = createRoot(document.getElementById('root')!)
root.render(<App />)

const style = document.createElement('style')
style.textContent = `
  html,
  body,
  #root {
    margin: 0;
    min-height: 100%;
    background: #fff;
  }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
    text-rendering: geometricPrecision;
  }

  button,
  canvas {
    -webkit-tap-highlight-color: transparent;
  }

  .stage {
    width: 402px;
    min-height: 874px;
    box-sizing: border-box;
    padding: 78px 16px 0;
    background: #fff;
  }

  .capture {
    width: 370px;
    box-sizing: border-box;
    padding: 0 4px 8px;
    border-radius: 8px;
    overflow: hidden;
  }
`
document.head.append(style)
