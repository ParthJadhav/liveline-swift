#!/usr/bin/env bash
set -euo pipefail

branch="${RELEASE_BRANCH:-main}"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI is required to verify release readiness." >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$branch" ]]; then
  echo "Release blocked: expected branch '$branch', found '$current_branch'." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Release blocked: tracked files contain uncommitted changes." >&2
  exit 1
fi

repository="${RELEASE_REPOSITORY:-$(gh repo view --json nameWithOwner --jq '.nameWithOwner')}"
head_sha="$(git rev-parse HEAD)"
remote_sha="$(gh api "repos/$repository/commits/$branch" --jq '.sha')"

if [[ "$head_sha" != "$remote_sha" ]]; then
  echo "Release blocked: local $branch ($head_sha) is not remote $branch ($remote_sha)." >&2
  exit 1
fi

run_line="$(
  gh run list \
    --repo "$repository" \
    --workflow CI \
    --branch "$branch" \
    --commit "$head_sha" \
    --limit 1 \
    --json status,conclusion,headSha,url \
    --jq '.[0] | [.status, .conclusion, .headSha, .url] | @tsv'
)"

if [[ -z "$run_line" ]]; then
  echo "Release blocked: no CI run exists for $head_sha." >&2
  exit 1
fi

IFS=$'\t' read -r status conclusion run_sha run_url <<< "$run_line"
if [[ "$run_sha" != "$head_sha" || "$status" != "completed" || "$conclusion" != "success" ]]; then
  echo "Release blocked: CI for $head_sha is $status/$conclusion." >&2
  echo "$run_url" >&2
  exit 1
fi

echo "Release ready: $repository@$head_sha passed CI."
echo "$run_url"
