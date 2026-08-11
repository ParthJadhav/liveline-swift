import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {advancedCharts, ditherCharts} from '../src/advanced-pr/catalog';

const fail = (message: string): never => {
  throw new Error(`Advanced PR demo verification failed: ${message}`);
};

if (advancedCharts.length !== 21) {
  fail(`expected 21 standard chart scenes, found ${advancedCharts.length}`);
}

const chartIDs = advancedCharts.map((chart) => chart.id);
if (new Set(chartIDs).size !== chartIDs.length) {
  fail('standard chart scene IDs must be unique');
}

for (const id of chartIDs) {
  const asset = resolve(import.meta.dir, `../public/advanced-pr-light/${id}.png`);
  if (!existsSync(asset)) {
    fail(`missing native light capture for ${id}`);
  }
}

for (const chart of ditherCharts) {
  if (!chartIDs.includes(chart.id)) {
    fail(`Dither scene ${chart.id} is not one of the new advanced charts`);
  }
  const asset = resolve(import.meta.dir, `../public/advanced-pr-light/dither/${chart.file}`);
  if (!existsSync(asset)) {
    fail(`missing native Dither recording ${chart.file}`);
  }
}

console.log(`Verified ${advancedCharts.length} unique chart scenes and ${ditherCharts.length} advanced Dither scenes.`);
