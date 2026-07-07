import path from 'node:path'
import { fileURLToPath } from 'node:url'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

const appDir = path.dirname(fileURLToPath(import.meta.url))
const upstreamDir = path.resolve(process.env.LIVELINE_UPSTREAM_DIR ?? path.join(appDir, '..', 'liveline-upstream'))

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@liveline-upstream': path.join(upstreamDir, 'src', 'index.ts'),
    },
    dedupe: ['react', 'react-dom'],
  },
  server: {
    fs: {
      allow: [appDir, upstreamDir],
    },
  },
  optimizeDeps: {
    exclude: ['@liveline-upstream'],
  },
})
