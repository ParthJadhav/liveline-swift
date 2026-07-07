import fs from 'node:fs/promises'
import http from 'node:http'
import net from 'node:net'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'
import { chromium } from 'playwright'

const baseTime = 1_788_888_000
const randomSeed = 12_345
const appDir = path.dirname(fileURLToPath(import.meta.url))
const rootDir = path.resolve(appDir, '..', '..')
const defaultOutDir = path.join(rootDir, 'Media', 'web-reference')

const args = process.argv.slice(2)

function argValue(name, fallback) {
  const index = args.indexOf(name)
  if (index === -1 || index + 1 >= args.length) return fallback
  return args[index + 1]
}

async function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer()
    server.once('error', reject)
    server.listen(0, '127.0.0.1', () => {
      const address = server.address()
      server.close(() => {
        resolve(typeof address === 'object' && address ? address.port : 5179)
      })
    })
  })
}

async function waitForHttp(url, timeoutMs = 30_000) {
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    const ok = await new Promise((resolve) => {
      const request = http.get(url, (response) => {
        response.resume()
        resolve((response.statusCode ?? 500) < 500)
      })
      request.on('error', () => resolve(false))
      request.setTimeout(1_000, () => {
        request.destroy()
        resolve(false)
      })
    })
    if (ok) return
    await new Promise((resolve) => setTimeout(resolve, 150))
  }
  throw new Error(`Timed out waiting for ${url}`)
}

async function main() {
  const outDir = path.resolve(argValue('--out-dir', process.env.WEB_REFERENCE_OUT_DIR ?? defaultOutDir))
  const scenarioArg = argValue('--scenario', process.env.WEB_REFERENCE_SCENARIO ?? '')
  const waitMs = Number(argValue('--wait-ms', process.env.WEB_REFERENCE_WAIT_MS ?? '2200'))
  const configuredPort = Number(argValue('--port', process.env.WEB_REFERENCE_PORT ?? '0'))
  const port = configuredPort > 0 ? configuredPort : await freePort()
  const baseUrl = `http://127.0.0.1:${port}`
  const viteBin = path.join(appDir, 'node_modules', '.bin', process.platform === 'win32' ? 'vite.cmd' : 'vite')

  await fs.mkdir(outDir, { recursive: true })

  const server = spawn(viteBin, ['--host', '127.0.0.1', '--port', String(port), '--strictPort'], {
    cwd: appDir,
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  })

  let serverOutput = ''
  server.stdout.on('data', (chunk) => { serverOutput += chunk.toString() })
  server.stderr.on('data', (chunk) => { serverOutput += chunk.toString() })

  try {
    await waitForHttp(baseUrl)

    const browser = await chromium.launch({ headless: true })
    const context = await browser.newContext({
      viewport: { width: 402, height: 874 },
      deviceScaleFactor: 3,
      timezoneId: 'Asia/Kolkata',
      colorScheme: 'light',
    })

    await context.addInitScript(({ fixedNow, seed }) => {
      Date.now = () => fixedNow
      let randomState = seed >>> 0
      Math.random = () => {
        let t = randomState += 0x6D2B79F5
        t = Math.imul(t ^ (t >>> 15), t | 1)
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296
      }
    }, { fixedNow: baseTime * 1000, seed: randomSeed })

    const page = await context.newPage()
    await page.goto(baseUrl, { waitUntil: 'networkidle' })
    const allScenarios = await page.evaluate(() => window.__LIVELINE_STORYBOOK_IDS__ ?? [])
    const scenarios = scenarioArg ? [scenarioArg] : allScenarios

    if (scenarios.length === 0) {
      throw new Error('No scenarios were exposed by the reference app.')
    }

    for (const scenario of scenarios) {
      await page.goto(`${baseUrl}/?scenario=${encodeURIComponent(scenario)}`, { waitUntil: 'networkidle' })
      const capture = page.locator('#capture')
      await capture.waitFor({ state: 'visible' })
      await page.waitForTimeout(waitMs)
      await capture.screenshot({
        path: path.join(outDir, `${scenario}.png`),
        animations: 'allow',
        scale: 'device',
      })
      console.log(`Captured ${scenario}`)
    }

    await browser.close()
    console.log(`Web reference screenshots written to ${outDir}`)
  } catch (error) {
    console.error(serverOutput)
    throw error
  } finally {
    server.kill()
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
