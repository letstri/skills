#!/usr/bin/env bash
# Usage: fetch.sh <owner/repo> <pr number> <out dir>
# Writes pr.json, files.json (smallest diff first), patches.txt and viewed.jsonl.
set -euo pipefail
repo=$1 n=$2 out=$3
mkdir -p "$out"
gh pr view "$n" -R "$repo" --json id,title,headRefOid,baseRefName > "$out/pr.json"
# The REST endpoint, not `gh pr view --json files`, which stops at 100 files.
gh api --paginate "repos/$repo/pulls/$n/files" |
  jq -s 'add | sort_by(.additions + .deletions)' > "$out/files.json"
jq -r '.[] | "=== \(.filename) [\(.status)\(if .previous_filename then " from \(.previous_filename)" else "" end)] +\(.additions) -\(.deletions)\n\(.patch // "(no patch: too large or binary)")\n"' \
  "$out/files.json" > "$out/patches.txt"
"$(dirname "$0")/viewed.sh" "$repo" "$n" > "$out/viewed.jsonl"
jq -r --slurpfile files "$out/files.json" \
  '"\(.title): \($files[0] | length) files, head \(.headRefOid), base \(.baseRefName)"' "$out/pr.json"
