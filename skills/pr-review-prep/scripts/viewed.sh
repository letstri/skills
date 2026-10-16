#!/usr/bin/env bash
# Usage: viewed.sh <owner/repo> <pr number>
# Prints one {"path","viewerViewedState"} object per line for every file in the PR.
set -euo pipefail
repo=$1 n=$2
gh api graphql --paginate -f owner="${repo%/*}" -f repo="${repo#*/}" -F n="$n" \
  -f query='query($owner:String!,$repo:String!,$n:Int!,$endCursor:String){repository(owner:$owner,name:$repo){pullRequest(number:$n){files(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{path viewerViewedState}}}}}' \
  --jq '.data.repository.pullRequest.files.nodes[]'
