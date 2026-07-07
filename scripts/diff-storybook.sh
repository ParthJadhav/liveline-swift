#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.build/storybook-diff-venv"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to diff storybook screenshots." >&2
  exit 1
fi

if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null
  "$VENV_DIR/bin/python" -m pip install Pillow >/dev/null
fi

cd "$ROOT_DIR"
"$VENV_DIR/bin/python" "$ROOT_DIR/scripts/storybook_diff.py" "$@"
