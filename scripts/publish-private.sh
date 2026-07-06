#!/usr/bin/env bash
set -euo pipefail

OWNER="${1:-ParthJadhav}"
REPO="${2:-liveline-swift}"
REMOTE="https://github.com/$OWNER/$REPO.git"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required." >&2
  exit 1
fi

if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$REMOTE"
  fi
else
  gh repo create "$OWNER/$REPO" --private --source . --remote origin
fi

git push -u origin main
