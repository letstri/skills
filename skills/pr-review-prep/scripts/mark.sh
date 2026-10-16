#!/usr/bin/env bash
# Usage: mark.sh <owner/repo> <pr number> <head sha from fetch> <paths file>
# Marks every path in the file as viewed, then confirms each one reads VIEWED.
# Exit 2: the author pushed since the fetch. Exit 1: some paths stayed unmarked (listed on stderr).
set -euo pipefail
repo=$1 n=$2 sha=$3 paths=$4
dir=$(dirname "$0")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

read -r id head < <(gh pr view "$n" -R "$repo" --json id,headRefOid --jq '"\(.id) \(.headRefOid)"')
if [[ $head != "$sha" ]]; then
  echo "head moved to $head since the fetch: fetch and classify again" >&2
  exit 2
fi

# Paths travel as variables, so `$` and quotes in them are safe.
mark_batch() {
  jq -n --arg id "$id" --rawfile paths "$1" '
    ($paths | split("\n") | map(select(length > 0))) as $p
    | [range($p | length)] as $i
    | {
        query: ("mutation($id:ID!," + ($i | map("$p\(.):String!") | join(",")) + "){"
          + ($i | map("m\(.):markFileAsViewed(input:{pullRequestId:$id,path:$p\(.)}){clientMutationId}") | join(" ")) + "}"),
        variables: ({id: $id} + ($i | map({key: "p\(.)", value: $p[.]}) | from_entries))
      }' | gh api graphql --input - > /dev/null 2>&1 || true
}

grep -v '^$' "$paths" | LC_ALL=C sort -u > "$tmp/want"
for round in 1 2 3 4; do
  "$dir/viewed.sh" "$repo" "$n" | jq -r 'select(.viewerViewedState == "VIEWED") | .path' |
    LC_ALL=C sort -u > "$tmp/done"
  LC_ALL=C comm -23 "$tmp/want" "$tmp/done" > "$tmp/pending"
  if [[ ! -s $tmp/pending ]]; then
    echo "viewed: $(wc -l < "$tmp/want" | tr -d ' ') files"
    exit 0
  fi
  [[ $round == 4 ]] && break
  # GitHub refuses a request past about 50 aliases (RESOURCE_LIMITS_EXCEEDED).
  split -l 40 "$tmp/pending" "$tmp/batch_"
  for batch in "$tmp"/batch_*; do
    mark_batch "$batch"
    rm "$batch"
  done
done
echo "not marked:" >&2
cat "$tmp/pending" >&2
exit 1
