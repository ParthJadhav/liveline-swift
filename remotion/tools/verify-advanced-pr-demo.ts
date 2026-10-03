import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {advancedCharts, ditherCharts} from '../src/advanced-pr/catalog';

const fail = (message: string): never => {
  throw new Error(`Advanced PR demo verification failed: ${message}`);
};

const assertNoSustainedBlackFrames = (asset: string): void => {
  const result = Bun.spawnSync(
    [
      'ffmpeg',
      '-hide_banner',
      '-loglevel',
      'info',
      '-i',
      asset,
      '-vf',
      'blackdetect=d=0.25:pix_th=0.10',
      '-an',
      '-f',
      'null',
      '-',
    ],
    {stdout: 'pipe', stderr: 'pipe'},
  );

  if (result.exitCode !== 0) {
    fail(`could not inspect ${asset}`);
  }

  const diagnostics = result.stderr.toString();
  if (diagnostics.includes('black_start:')) {
    fail(`sustained black frames found in ${asset}`);
  }
};

if (advancedCharts.length !== 21) {
  fail(`expected 21 standard chart scenes, found ${advancedCharts.length}`);
}

const chartIDs = advancedCharts.map((chart) => chart.id);
if (new Set(chartIDs).size !== chartIDs.length) {
  fail('standard chart scene IDs must be unique');
}

for (const id of chartIDs) {
  const stillAsset = resolve(import.meta.dir, `../public/advanced-pr-light/${id}.png`);
  const liveAsset = resolve(import.meta.dir, `../public/advanced-pr-light/live/${id}.mp4`);
  if (!existsSync(stillAsset)) {
    fail(`missing native light still for ${id}`);
  }
  if (!existsSync(liveAsset)) {
    fail(`missing native live recording for ${id}`);
  }
  assertNoSustainedBlackFrames(liveAsset);
}

for (const chart of ditherCharts) {
  if (!chartIDs.includes(chart.id)) {
    fail(`Dither scene ${chart.id} is not one of the new advanced charts`);
  }
  const asset = resolve(import.meta.dir, `../public/advanced-pr-light/dither/${chart.file}`);
  if (!existsSync(asset)) {
    fail(`missing native Dither recording ${chart.file}`);
  }
  assertNoSustainedBlackFrames(asset);
}

console.log(`Verified ${advancedCharts.length} unique native-live chart scenes and ${ditherCharts.length} advanced Dither scenes.`);
