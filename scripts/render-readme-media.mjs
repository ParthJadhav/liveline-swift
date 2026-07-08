#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const rootDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..')

async function loadPlaywright() {
  try {
    return await import('playwright')
  } catch {
    const candidates = [
      path.join(rootDir, '.build', 'liveline-web-reference-app', 'node_modules', 'playwright', 'index.mjs'),
      path.join(rootDir, 'scripts', 'web-reference', 'node_modules', 'playwright', 'index.mjs'),
    ]
    for (const candidate of candidates) {
      if (fs.existsSync(candidate)) {
        return await import(pathToFileURL(candidate).href)
      }
    }
    throw new Error('Playwright is required. Run scripts/capture-web-references.sh once to install the local browser tooling.')
  }
}

const [htmlPath, outputPath, selector = '.capture'] = process.argv.slice(2)
if (!htmlPath || !outputPath) {
  console.error('Usage: render-readme-media.mjs <html-path> <output-path> [selector]')
  process.exit(2)
}

const { chromium } = await loadPlaywright()
const browser = await chromium.launch({ headless: true })
try {
  const context = await browser.newContext({
    viewport: { width: 1800, height: 1200 },
    deviceScaleFactor: 1,
    colorScheme: 'light',
  })
  const page = await context.newPage()
  await page.goto(pathToFileURL(path.resolve(htmlPath)).href, { waitUntil: 'load' })
  const target = page.locator(selector)
  await target.waitFor({ state: 'visible' })
  await target.screenshot({
    path: path.resolve(outputPath),
    animations: 'disabled',
    scale: 'css',
  })
  await context.close()
} finally {
  await browser.close()
}
