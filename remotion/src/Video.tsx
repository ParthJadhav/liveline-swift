import React from 'react';
import {
  AbsoluteFill,
  Audio,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {formatPrice, streamValue} from './chartData';
import {AppleTV, AppleWatch, IPad, IPhone, MacBook, VisionPro} from './devices';
import {theme} from './theme';

export const INTRO_DURATION = 84;
export const SPOT_DURATION = 55;
export const GRID_DURATION = 141;
export const OUTRO_DURATION = 105;

type Platform = {
  key: string;
  charts: string;
  os: string;
  device: string;
  version: string;
  width: number;
  height: number;
  bg: string;
  render: (streamFrame: number, opts?: {feather?: boolean}) => React.ReactNode;
};

// Minimum OS versions from Package.swift — the single source of truth for the
// platform claims made in this video.
export const PLATFORMS: Platform[] = [
  {
    key: 'watchos',
    charts: 'Gauge',
    os: 'watchOS',
    device: 'Apple Watch Series 11',
    version: '9+',
    width: 560,
    height: 880,
    bg: theme.pageWhite,
    render: (f) => <AppleWatch streamFrame={f} />,
  },
  {
    key: 'ios',
    charts: 'Line · Signed bars',
    os: 'iOS',
    device: 'iPhone 17 Pro',
    version: '16+',
    width: 1350,
    height: 2760,
    bg: theme.pageGray,
    render: (f) => <IPhone streamFrame={f} />,
  },
  {
    key: 'ipados',
    charts: 'Multi-series · Donut · Bars',
    os: 'iPadOS',
    device: 'iPad Pro',
    version: '16+',
    width: 3000,
    height: 2300,
    bg: theme.pageWhite,
    render: (f) => <IPad streamFrame={f} />,
  },
  {
    key: 'macos',
    charts: 'Candlestick · Volume',
    os: 'macOS',
    device: 'MacBook Pro',
    version: '13+',
    width: 3860,
    height: 2540,
    bg: theme.pageGray,
    render: (f) => <MacBook streamFrame={f} />,
  },
  {
    key: 'tvos',
    charts: 'Stacked area',
    os: 'tvOS',
    device: 'Apple TV 4K',
    version: '16+',
    width: 4300,
    height: 2780,
    bg: theme.pageWhite,
    render: (f) => <AppleTV streamFrame={f} />,
  },
  {
    key: 'visionos',
    charts: 'Heatmap',
    os: 'visionOS',
    device: 'Apple Vision Pro',
    version: '1+',
    width: 1450,
    height: 1340,
    bg: theme.photoGray,
    render: (f, opts) => <VisionPro streamFrame={f} feather={opts?.feather} />,
  },
];

export const TOTAL_DURATION =
  INTRO_DURATION + SPOT_DURATION * PLATFORMS.length + GRID_DURATION + OUTRO_DURATION;

const SceneBg: React.FC<{color: string}> = ({color}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 8], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return <AbsoluteFill style={{background: color, opacity}} />;
};

const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const letters = 'Liveline'.split('');
  const lineDraw = interpolate(frame, [16, 58], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const tagIn = spring({frame: frame - 26, fps, config: {damping: 200}, durationInFrames: 22});
  const badgeIn = spring({frame: frame - 58, fps, config: {damping: 13, stiffness: 160}});
  const fadeOut = interpolate(frame, [INTRO_DURATION - 12, INTRO_DURATION], [1, 0], {
    extrapolateLeft: 'clamp',
  });
  const exitLift = interpolate(frame, [INTRO_DURATION - 12, INTRO_DURATION], [0, -30], {
    extrapolateLeft: 'clamp',
  });

  // Mini live line under the wordmark, sampled so the tip dot and badge track
  // the real end of the revealed curve.
  const lineW = 560;
  const lineH = 52;
  const introY = (x: number) =>
    26 -
    14 * Math.sin((x / lineW) * Math.PI * 1.9 + 0.4) -
    6 * Math.sin((x / lineW) * Math.PI * 4.3 + 2.0) -
    (x / lineW) * 8;
  const samples = 90;
  const shown = Math.max(2, Math.round(samples * lineDraw));
  const introPts: Array<[number, number]> = [];
  for (let i = 0; i < shown; i++) {
    const x = (i / (samples - 1)) * lineW;
    introPts.push([x, introY(x)]);
  }
  const introPath = introPts
    .map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`)
    .join(' ');
  const [tipX, tipY] = introPts[introPts.length - 1];
  const tipValue = 100 + (26 - tipY) * 0.45;

  return (
    <AbsoluteFill
      style={{
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        fontFamily: theme.fontSans,
        opacity: fadeOut,
        transform: `translateY(${exitLift}px)`,
      }}
    >
      <div style={{display: 'flex'}}>
        {letters.map((ch, i) => {
          const s = spring({
            frame: frame - 4 - i * 2.5,
            fps,
            config: {damping: 16, stiffness: 130},
          });
          return (
            <span
              key={i}
              style={{
                fontSize: 134,
                fontWeight: 700,
                letterSpacing: '-0.02em',
                color: theme.textPrimary,
                opacity: s,
                transform: `translateY(${(1 - s) * 42}px)`,
                display: 'inline-block',
              }}
            >
              {ch}
            </span>
          );
        })}
      </div>
      <div style={{position: 'relative', width: lineW, height: 60, marginTop: 26}}>
        <svg
          width={lineW}
          height={lineH}
          viewBox={`0 0 ${lineW} ${lineH}`}
          style={{overflow: 'visible'}}
        >
          <path
            d={introPath}
            fill="none"
            stroke={theme.accent}
            strokeWidth={4.5}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {lineDraw > 0.02 ? (
            <circle cx={tipX} cy={tipY} r={7} fill={theme.accent} stroke="#fff" strokeWidth={2.5} />
          ) : null}
        </svg>
        <div
          style={{
            position: 'absolute',
            left: lineW + 18,
            top: tipY - 20,
            padding: '7px 16px',
            borderRadius: 999,
            background: theme.up,
            color: '#fff',
            fontFamily: theme.fontMono,
            fontWeight: 700,
            fontSize: 21,
            opacity: badgeIn,
            transform: `scale(${0.5 + 0.5 * badgeIn})`,
            transformOrigin: 'left center',
            whiteSpace: 'nowrap',
          }}
        >
          {formatPrice(tipValue)}
        </div>
      </div>
      <div
        style={{
          marginTop: 26,
          fontSize: 38,
          fontWeight: 500,
          color: theme.textSecondary,
          opacity: tagIn,
          transform: `translateY(${(1 - tagIn) * 20}px)`,
        }}
      >
        Real-time SwiftUI charts
      </div>
    </AbsoluteFill>
  );
};

const Spotlight: React.FC<{platform: Platform; index: number; streamOffset: number}> = ({
  platform,
  index,
  streamOffset,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const streamFrame = streamOffset + frame;

  const enter = spring({frame, fps, config: {damping: 15, stiffness: 90}});
  const exit = interpolate(frame, [SPOT_DURATION - 9, SPOT_DURATION], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const labelIn = spring({frame: frame - 5, fps, config: {damping: 100, stiffness: 100}});

  const scaleFit = Math.min(660 / platform.height, 1250 / platform.width);
  // Slow confident push-in while the device is on screen.
  const drift = 1 + 0.035 * (frame / SPOT_DURATION);
  const scale = scaleFit * drift * (1 - 0.03 * exit);
  const bob = Math.sin((frame / 90) * Math.PI * 2 + index) * 5;
  const dir = index % 2 === 0 ? 1 : -1;
  const slideX = (1 - enter) * 90 * dir - exit * 80 * dir;
  const opacity = Math.min(enter * 1.4, 1) * (1 - exit);

  return (
    <AbsoluteFill style={{fontFamily: theme.fontSans}}>
      <SceneBg color={platform.bg} />
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          top: -84,
          opacity,
          transform: `translateX(${slideX}px) translateY(${(1 - enter) * 110 + bob}px)`,
        }}
      >
        <div
          style={{
            transform: `scale(${scale})`,
            filter: 'drop-shadow(0 40px 60px rgba(0,0,0,0.18))',
          }}
        >
          {platform.render(streamFrame)}
        </div>
      </AbsoluteFill>
      <div
        style={{
          position: 'absolute',
          bottom: 64,
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 14,
          opacity: labelIn * (1 - exit),
          transform: `translateY(${(1 - labelIn) * 24}px)`,
        }}
      >
        <div
          style={{
            fontSize: 64,
            fontWeight: 700,
            letterSpacing: '-0.015em',
            color: theme.textPrimary,
          }}
        >
          {platform.os}
        </div>
        <div
          style={{
            padding: '8px 20px',
            borderRadius: 999,
            border: `1.5px solid ${theme.chipBorder}`,
            background: 'rgba(255,255,255,0.7)',
            fontSize: 24,
            fontWeight: 500,
            color: theme.textSecondary,
          }}
        >
          {platform.device} · {platform.os} {platform.version}
          <span style={{color: theme.accent, fontWeight: 600}}> · {platform.charts}</span>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Grid: React.FC<{streamOffset: number}> = ({streamOffset}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const streamFrame = streamOffset + frame;

  const headIn = spring({frame: frame - 2, fps, config: {damping: 15, stiffness: 110}});
  const fadeOut = interpolate(frame, [GRID_DURATION - 12, GRID_DURATION], [1, 0], {
    extrapolateLeft: 'clamp',
  });

  const cols = 3;
  const cellW = 590;
  const cellH = 396;
  const originX = (1920 - cols * cellW) / 2;
  const rowY = [190, 610];

  return (
    <AbsoluteFill style={{fontFamily: theme.fontSans, opacity: fadeOut}}>
      <SceneBg color={theme.pageWhite} />
      <div
        style={{
          position: 'absolute',
          top: 74,
          width: '100%',
          textAlign: 'center',
          fontSize: 56,
          fontWeight: 700,
          letterSpacing: '-0.015em',
          color: theme.textPrimary,
          opacity: headIn,
          transform: `translateY(${(1 - headIn) * 26}px)`,
        }}
      >
        27 chart types. Every Apple platform.
      </div>
      {PLATFORMS.map((p, i) => {
        const row = Math.floor(i / cols);
        const col = i % cols;
        const enter = spring({
          frame: frame - 7 - i * 4,
          fps,
          config: {damping: 15, stiffness: 100},
        });
        const bob = Math.sin((frame / 100) * Math.PI * 2 + i * 1.1) * 3;
        const scale = Math.min(300 / p.height, 500 / p.width) * (0.94 + 0.06 * enter);
        return (
          <div
            key={p.key}
            style={{
              position: 'absolute',
              left: originX + col * cellW,
              top: rowY[row],
              width: cellW,
              height: cellH,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              opacity: enter,
              transform: `translateY(${(1 - enter) * 40 + bob}px)`,
            }}
          >
            <div
              style={{
                height: cellH - 70,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <div
                style={{
                  transform: `scale(${scale})`,
                  filter: 'drop-shadow(0 18px 28px rgba(0,0,0,0.14))',
                }}
              >
                {p.render(streamFrame, {feather: true})}
              </div>
            </div>
            <div style={{marginTop: 6, fontSize: 26, fontWeight: 600, color: theme.textPrimary}}>
              {p.os} <span style={{color: theme.textTertiary, fontWeight: 500}}>{p.version}</span>
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const headIn = spring({frame: frame - 2, fps, config: {damping: 15, stiffness: 110}});
  const codeIn = spring({frame: frame - 14, fps, config: {damping: 100, stiffness: 100}});
  const pulse = 1 + 0.12 * Math.sin((frame / 45) * Math.PI * 2);

  return (
    <AbsoluteFill
      style={{
        fontFamily: theme.fontSans,
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
      }}
    >
      <SceneBg color={theme.pageGray} />
      <div
        style={{
          fontSize: 78,
          fontWeight: 700,
          letterSpacing: '-0.015em',
          color: theme.textPrimary,
          opacity: headIn,
          transform: `translateY(${(1 - headIn) * 30}px)`,
          zIndex: 1,
        }}
      >
        One package. Every Apple platform.
      </div>
      <div
        style={{
          marginTop: 48,
          padding: '24px 40px',
          borderRadius: 18,
          background: '#ffffff',
          border: `1.5px solid ${theme.chipBorder}`,
          boxShadow: '0 10px 30px rgba(0,0,0,0.06)',
          fontFamily: theme.fontMono,
          fontSize: 27,
          color: theme.textPrimary,
          opacity: codeIn,
          transform: `translateY(${(1 - codeIn) * 24}px)`,
          zIndex: 1,
        }}
      >
        <span style={{color: theme.textSecondary}}>.package(url: </span>
        <span style={{color: theme.linkBlue}}>
          "https://github.com/ParthJadhav/liveline-swift.git"
        </span>
        <span style={{color: theme.textSecondary}}>, from: </span>
        <span style={{color: theme.up}}>"0.4.0"</span>
        <span style={{color: theme.textSecondary}}>)</span>
      </div>
      <div style={{marginTop: 46, display: 'flex', gap: 14, zIndex: 1}}>
        {PLATFORMS.map((p, i) => {
          const s = spring({
            frame: frame - 22 - i * 3,
            fps,
            config: {damping: 14, stiffness: 130},
          });
          return (
            <div
              key={p.key}
              style={{
                padding: '10px 22px',
                borderRadius: 999,
                border: `1.5px solid ${theme.chipBorder}`,
                background: '#ffffff',
                fontSize: 22,
                fontWeight: 500,
                color: theme.textSecondary,
                opacity: s,
                transform: `translateY(${(1 - s) * 18}px)`,
              }}
            >
              {p.os} {p.version}
            </div>
          );
        })}
      </div>
      <div
        style={{
          marginTop: 52,
          display: 'flex',
          alignItems: 'center',
          gap: 14,
          opacity: interpolate(frame, [40, 56], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
          zIndex: 1,
        }}
      >
        <div
          style={{
            width: 14,
            height: 14,
            borderRadius: 7,
            background: theme.accent,
            transform: `scale(${pulse})`,
            boxShadow: `0 0 0 ${6 * pulse}px rgba(0,122,255,0.12)`,
          }}
        />
        <div style={{fontSize: 30, fontWeight: 600, color: theme.textPrimary}}>Liveline</div>
      </div>
    </AbsoluteFill>
  );
};

export const LivelinePlatformsVideo: React.FC = () => {
  const gridStart = INTRO_DURATION + SPOT_DURATION * PLATFORMS.length;
  const outroStart = gridStart + GRID_DURATION;

  return (
    <AbsoluteFill style={{background: theme.pageWhite}}>
      <Audio
        src={staticFile('audio/bgm.m4a')}
        volume={(f) =>
          interpolate(
            f,
            [0, 18, TOTAL_DURATION - 48, TOTAL_DURATION - 4],
            [0, 0.6, 0.6, 0],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          )
        }
      />
      <Sequence from={INTRO_DURATION - 14} durationInFrames={40}>
        <Audio src={staticFile('audio/sfx/whoosh-cinematic.mp3')} volume={0.14} />
      </Sequence>
      {PLATFORMS.map((_, i) =>
        i === 0 ? null : (
          <Sequence
            key={`sfx-${i}`}
            from={INTRO_DURATION + i * SPOT_DURATION - 4}
            durationInFrames={30}
          >
            <Audio src={staticFile('audio/sfx/whoosh-short.mp3')} volume={0.1} />
          </Sequence>
        ),
      )}
      <Sequence from={gridStart + 2} durationInFrames={30}>
        <Audio src={staticFile('audio/sfx/pop.mp3')} volume={0.22} />
      </Sequence>
      <Sequence from={outroStart + 6} durationInFrames={60}>
        <Audio src={staticFile('audio/sfx/sparkle.mp3')} volume={0.14} />
      </Sequence>

      <Sequence durationInFrames={INTRO_DURATION}>
        <Intro />
      </Sequence>
      {PLATFORMS.map((p, i) => {
        const from = INTRO_DURATION + i * SPOT_DURATION;
        return (
          <Sequence key={p.key} from={from} durationInFrames={SPOT_DURATION}>
            <Spotlight platform={p} index={i} streamOffset={from} />
          </Sequence>
        );
      })}
      <Sequence from={gridStart} durationInFrames={GRID_DURATION}>
        <Grid streamOffset={gridStart} />
      </Sequence>
      <Sequence from={outroStart} durationInFrames={OUTRO_DURATION}>
        <Outro />
      </Sequence>
    </AbsoluteFill>
  );
};
