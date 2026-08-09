import React from 'react';
import {Img, staticFile} from 'remotion';
import {
  CandleChart,
  DonutChart,
  GaugeChart,
  HeatmapChart,
  MultiLineChart,
  SignedBarChart,
  StackedAreaChart,
} from './charts';
import {LiveChart} from './LiveChart';
import {theme} from './theme';

const sectionTitle = (size: number): React.CSSProperties => ({
  fontFamily: theme.fontSans,
  fontWeight: 700,
  fontSize: size,
  letterSpacing: '-0.01em',
  color: theme.textPrimary,
  alignSelf: 'flex-start',
});

// Real Apple product bezels (Apple Design Resources, PNG with transparent
// screen cutouts). Screen rects below were measured from each file's alpha
// channel. Components render at the image's natural pixel size; scenes scale
// them with CSS transforms.

type DeviceProps = {
  streamFrame: number;
};

type BezelSpec = {
  file: string;
  imgW: number;
  imgH: number;
  // Screen cutout rect in image pixels + corner radius.
  sx: number;
  sy: number;
  sw: number;
  sh: number;
  sr: number | string;
};

const BezelDevice: React.FC<BezelSpec & {children: React.ReactNode}> = ({
  file,
  imgW,
  imgH,
  sx,
  sy,
  sw,
  sh,
  sr,
  children,
}) => (
  <div style={{position: 'relative', width: imgW, height: imgH}}>
    <div
      style={{
        position: 'absolute',
        left: sx,
        top: sy,
        width: sw,
        height: sh,
        borderRadius: sr,
        overflow: 'hidden',
        background: '#ffffff',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {children}
    </div>
    <Img
      src={staticFile(file)}
      style={{position: 'absolute', inset: 0, width: imgW, height: imgH}}
    />
  </div>
);

// Apple Watch Series 11 46mm — natural 560x880. Gauge renderer.
export const AppleWatch: React.FC<DeviceProps> = ({streamFrame}) => (
  <BezelDevice file="bezels/watch.png" imgW={560} imgH={880} sx={72} sy={192} sw={412} sh={492} sr={110}>
    <GaugeChart streamFrame={streamFrame} size={430} />
  </BezelDevice>
);

// iPhone 17 Pro Silver portrait — natural 1350x2760. Two-chart dashboard:
// live line on top, signed daily bars below.
export const IPhone: React.FC<DeviceProps> = ({streamFrame}) => (
  <BezelDevice file="bezels/iphone.png" imgW={1350} imgH={2760} sx={75} sy={72} sw={1200} sh={2616} sr={170}>
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 46,
        width: 1080,
      }}
    >
      <div style={sectionTitle(74)}>Portfolio</div>
      <LiveChart
        streamFrame={streamFrame}
        width={1080}
        height={1210}
        uiScale={2.6}
        windowSize={95}
      />
      <div style={{...sectionTitle(58), marginTop: 26}}>Daily P/L</div>
      <SignedBarChart streamFrame={streamFrame} width={1040} height={560} />
    </div>
  </BezelDevice>
);

// iPad Pro (M5) 13" Silver landscape — natural 3000x2300. Three-chart
// dashboard: multi-series line, allocation donut, signed bars.
export const IPad: React.FC<DeviceProps> = ({streamFrame}) => (
  <BezelDevice file="bezels/ipad.png" imgW={3000} imgH={2300} sx={124} sy={118} sw={2748} sh={2060} sr={64}>
    <div style={{display: 'flex', alignItems: 'center', gap: 90}}>
      <MultiLineChart streamFrame={streamFrame} width={1620} height={1760} uiScale={3.5} />
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 40}}>
        <DonutChart streamFrame={streamFrame} size={800} />
        <SignedBarChart streamFrame={streamFrame} width={760} height={800} />
      </div>
    </div>
  </BezelDevice>
);

// MacBook Pro M5 14" Silver — natural 3860x2540. Extra top offset keeps the
// plot clear of the camera notch that intrudes into the screen cutout.
export const MacBook: React.FC<DeviceProps> = ({streamFrame}) => (
  <BezelDevice file="bezels/macbook.png" imgW={3860} imgH={2540} sx={418} sy={290} sw={3020} sh={1960} sr={40}>
    <div style={{marginTop: 100}}>
      <CandleChart streamFrame={streamFrame} width={2780} height={1600} uiScale={4.2} />
    </div>
  </BezelDevice>
);

// Apple TV 4K on a television frame — natural 4300x2780.
export const AppleTV: React.FC<DeviceProps> = ({streamFrame}) => (
  <BezelDevice file="bezels/appletv.png" imgW={4300} imgH={2780} sx={106} sy={122} sw={3832} sh={2152} sr={24}>
    <StackedAreaChart streamFrame={streamFrame} width={3440} height={1900} uiScale={6} />
  </BezelDevice>
);

// Apple Vision Pro — real product photo (front view, studio light gray) with
// a visionOS glass window floating in front carrying the chart.
export const VisionPro: React.FC<DeviceProps & {feather?: boolean; floatShift?: number}> = ({
  streamFrame,
  feather = true,
  floatShift = 0,
}) => (
  <div style={{position: 'relative', width: 1450, height: 1340}}>
    <Img
      src={staticFile('bezels/visionpro.jpg')}
      style={{
        position: 'absolute',
        left: (1450 - 1158) / 2,
        top: 640,
        width: 1158,
        height: 690,
        ...(feather
          ? {
              WebkitMaskImage:
                'radial-gradient(ellipse 62% 62% at 50% 50%, black 55%, transparent 76%)',
              maskImage:
                'radial-gradient(ellipse 62% 62% at 50% 50%, black 55%, transparent 76%)',
            }
          : null),
      }}
    />
    <div
      style={{
        position: 'absolute',
        left: (1450 - 1240) / 2,
        top: 0,
        width: 1240,
        height: 740,
        transform: `translateY(${floatShift}px)`,
        borderRadius: 56,
        background: 'rgba(255,255,255,0.82)',
        border: '2px solid rgba(255,255,255,0.9)',
        boxShadow:
          '0 60px 120px rgba(0,0,0,0.16), 0 12px 36px rgba(0,0,0,0.08), inset 0 1px 0 rgba(255,255,255,0.9)',
        backdropFilter: 'blur(28px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <HeatmapChart streamFrame={streamFrame} width={1110} height={600} />
    </div>
  </div>
);

export const deviceTint = theme.pageGray;
