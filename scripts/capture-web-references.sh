#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/scripts/web-reference"
APP_DIR="$ROOT_DIR/.build/liveline-web-reference-app"
UPSTREAM_DIR="${UPSTREAM_DIR:-$ROOT_DIR/.build/liveline-upstream}"
UPSTREAM_REF="${UPSTREAM_REF:-069899598a11e00094ea1eb6b838404825f828be}"
MEDIA_DIR="${WEB_REFERENCE_OUT_DIR:-$ROOT_DIR/Media/web-reference}"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required to capture upstream web references." >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to capture upstream web references." >&2
  exit 1
fi

if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
  mkdir -p "$(dirname "$UPSTREAM_DIR")"
  git clone --no-checkout https://github.com/benjitaylor/liveline.git "$UPSTREAM_DIR"
fi

git -C "$UPSTREAM_DIR" fetch --depth 1 origin "$UPSTREAM_REF"
git -C "$UPSTREAM_DIR" checkout --detach FETCH_HEAD

mkdir -p "$APP_DIR"
rsync -a --delete "$TEMPLATE_DIR/" "$APP_DIR/"

cd "$APP_DIR"
npm ci

npx playwright install chromium

mkdir -p "$MEDIA_DIR"
LIVELINE_UPSTREAM_DIR="$UPSTREAM_DIR" WEB_REFERENCE_OUT_DIR="$MEDIA_DIR" npm run capture -- "$@"
