---
name: pr-mark-viewed
description: Speed up a GitHub PR review — sort every changed file into trivial / skim / review, mark the trivial ones as viewed on GitHub, and hand back a reading order for the rest. Use when the user shares a PR link or number and asks to pre-scan it, mark the easy files as viewed, or triage it before they review.
---

# Mark PR files as viewed

Take the trivial files off the reviewer's plate so they only read what matters. Marking a file as viewed is the only thing this skill writes to GitHub. Never approve, comment, or request changes.

## 1. Fetch

Use `gh`, not the browser. With no PR given, take the current branch's (`gh pr view --json number,url`). `gh pr view --json files` stops at 100 files, so page through the REST endpoint:

```sh
gh pr view <n> -R <owner/repo> --json id,title,headRefOid,baseRefName
gh api --paginate repos/<owner/repo>/pulls/<n>/files > files.json   # save to the scratchpad
jq -s 'add | length' files.json
```

Keep `headRefOid`; step 3 checks it. Then tell the user in one line how many files there are and that you're reading them.

Each entry has `filename`, `previous_filename`, `status`, `additions`, `deletions` and `patch`. Read the patches smallest first, and write them to a scratchpad file in size buckets (`jq -s -r 'add | sort_by(.additions+.deletions)[] | select(...)' > bucket.txt`) to read in pages. Printing them to the terminal overflows its output cap. `patch` is missing for very large or binary files, which go in review anyway. When the local checkout is at `headRefOid`, `git diff origin/<base>...HEAD -- <path>` gives the same diff with more context, and lets you read a source file whole.

Also fetch the viewer's viewed state, so the report can flag files they already saw:

```sh
gh api graphql --paginate -f owner=<owner> -f repo=<repo> -F n=<n> \
  -f query='query($owner:String!,$repo:String!,$n:Int!,$endCursor:String){repository(owner:$owner,name:$repo){pullRequest(number:$n){files(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{path viewerViewedState}}}}}' \
  --jq '.data.repository.pullRequest.files.nodes[]' > viewed.jsonl
```

`DISMISSED` means the reviewer viewed the file and a later push changed it.

**Judge a re-pushed file by what changed since the view, not by the whole PR diff.** When the user scopes the request to commits ("the last 3 commits", "since my review"), classify each file by `git diff <commit before the range> HEAD -- <path>` only, and leave files the range doesn't touch alone. A `DISMISSED` file's older content was already read, so judge it by the commits pushed since. GitHub doesn't say which commit the reviewer saw, so ask for the range when the user doesn't name one. Leave out a file that commits just before the range also changed, unless the user says they saw those.

## 2. Classify

**Trivial: mark as viewed.** Every hunk has to be one of these, and nothing else can change behavior or a contract:
- a pure rename or move (`status: renamed` with an empty patch), or an import path that follows a move
- import reordering, or an import swapped for a renamed symbol along with its call sites
- a local variable or parameter renamed, where it doesn't reach any exported signature
- an inline refactor with the same logic, e.g. a helper pulled out or a `useMemo` removed
- an unused export deleted, or a local made `export` without changing the local itself
- a formatting-only change

**Follows another file: mark as viewed, credit the source.** A call site that only adopts an API whose design lives elsewhere, such as an old hook or component swapped for its replacement, a literal value swapped for a named id from a shared registry, or a call updated to a changed signature. The decision gets reviewed once at the source, which is a file in this PR or code already on the base branch, and not again at every call site. Find these by grouping hunks that make the same swap across files. A file qualifies only when:
- every hunk is one of those swaps, or one of the trivial kinds above. One file can contain several different swaps.
- you read the source and confirmed that each new id or call behaves like the old one it replaced, including any options the call site still passes. Check the source entry's own flags too, such as a platform gate, an availability check or a default. A swap onto an entry that adds a gate changes where the call site works, so it goes in review.
- a loop of old calls replaced by one batched call does exactly what the loop did. If the batch differs, for example in ordering or in which item ends up selected, the file goes in review and the report names the difference.

**A sweep is checked mechanically.** When a commit renames symbols or swaps a call across dozens of files, don't read each file by eye. Build the `old → new` map from the declarations the commit changes, run every removed line through it, and compare the result with the added lines after dropping whitespace, line rewraps, trailing commas and the order of import specifiers. Then widen the check only by what the sweep actually did:
- a line a sorter moved, such as an object key or import specifier that a lint autofix reordered after its rename, counts when the moved lines match as a set
- a repo symbol that shares its name with a built-in (`valueOf`, `indexOf`) is mapped where the repo declares it, bare or on the repo's own object, and left alone on built-in calls. Dropping the name from the map instead falsely rejects every file that uses it.
- a call wrapped in a converter the sweep introduced (`f(x)` → `f(convert(x))`), plus the converter's import, once you've read the converter. This is the follows rule applied mechanically. Count it the same way when the file hoists the converted value into one local (`const y = convert(x)`) and uses `y` where it used to write `convert(x)` or `x`. A converter on both sides of a comparison (`a === b` → `convert(a) === convert(b)`) changes what counts as equal, so that file goes in review.
- a field renamed together with every reader of it
- one old name that the sweep split into two new ones by role: try each mapping per file and accept the file when one of them matches

Spot-check a few accepted files and the smallest rejected ones by eye. A rejected file with a tiny diff usually means the map is missing a case, not that the file holds a real change.

If a call site changes behavior, such as a different value, scope or default, or does anything beyond the swap, it goes in review. A file that is all swaps plus one small real change, such as an added `aria-label`, goes in skim with the note "rest follows `<source>`", so the reviewer reads only the extra change.

**Skim: leave unmarked, list it.** Small but real changes:
- a style or value tweak, like a className, color, duration or copy
- a dependency bump in `package.json`, a workspace catalog, or env files
- a generated file, like a lockfile or `.types` output
- docs, rules and skill files

**Review: leave unmarked, put it in the reading order.** Anything else, including:
- new or changed props, fields, schemas, router procedures, IPC channels or env vars
- a changed function signature, even with an additive argument
- new files, and files deleted along with the logic they held. A file deleted because its last user stops using it in this PR goes next to that user.

If you're unsure, the file is not trivial. A wrongly marked file hides code from the reviewer. A wrongly unmarked one costs a few seconds.

## 3. Mark

First check that `gh pr view <n> -R <owner/repo> --json headRefOid` still matches the SHA from step 1. If it changed, the author pushed after you read the diff, so fetch again and reclassify before marking anything.

Write the paths to mark one per line in `marked.txt`, then mark them with one aliased mutation per path, one request per batch of up to 40. Paths go in as variables, so `$` and quotes in them are safe:

```sh
jq -n --arg id <PR node id> --rawfile paths marked.txt '
  ($paths | split("\n") | map(select(length > 0))) as $p
  | [range($p | length)] as $i
  | {
      query: ("mutation($id:ID!," + ($i | map("$p\(.):String!") | join(",")) + "){"
        + ($i | map("m\(.):markFileAsViewed(input:{pullRequestId:$id,path:$p\(.)}){clientMutationId}") | join(" ")) + "}"),
      variables: ({id: $id} + ($i | map({key: "p\(.)", value: $p[.]}) | from_entries))
    }' | gh api graphql --input -
```

Each alias `m<i>` in `data` is the path on line `i` (counting from 0). A path that failed shows up in `errors`, and you report it. If the viewer has already marked a file, marking it again does nothing.

GitHub refuses one request past about 50 aliases: the rest come back `null` with `RESOURCE_LIMITS_EXCEEDED`. Send batches of 40 (`split -l 40 marked.txt batch_`, then run the command per batch) and retry any alias that failed. Afterwards fetch `viewerViewedState` again and confirm every marked path reads `VIEWED`.

## 4. Report

Keep the report short:
- **Marked (n)**: each path with a few words on why it is trivial.
- **Follows (n)**: one group per source, with its path and whether it's in this PR or on the base branch, the swap as `old → new`, the equivalence you checked, and the marked call-site paths.
- **Skim**: the paths grouped by kind, one line per group.
- **Review order**: core logic first (shared packages, then state and domain logic, then features, routes and UI), each with a one-line summary of what changed. Put a moved file next to its old path. Put each in-PR source before the files that follow it, and note how many call sites it covers.
- **Changed since viewed**: the paths in skim or review that `viewed.jsonl` shows as `DISMISSED`. Leave this line out when there are none.

Ask before marking anything outside the trivial list, e.g. a lockfile.
