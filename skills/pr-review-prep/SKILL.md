---
name: pr-review-prep
description: Prepares a GitHub PR for its reviewer. Sorts every changed file into trivial, follows, skim and review, marks the trivial ones as viewed on GitHub, and hands back a reading order for the rest with a summary of how much was taken off the reviewer's plate. Use when the user shares a PR link or number and asks to pre-scan it, triage it, mark the easy files as viewed, or prepare it before they review.
---

# PR review prep

Take the trivial files off the reviewer's plate so they only read what matters. Marking a file as viewed is the only thing this skill writes to GitHub. Never approve, comment or request changes.

The scripts live next to this file in `scripts/`; run them by absolute path. They need `gh` (signed in) and `jq`.

## 1. Fetch

With no PR given, take the current branch's (`gh pr view --json number,url`). Then:

```sh
scripts/fetch.sh <owner/repo> <n> <scratchpad dir>
```

It prints the title, file count, head SHA and base, and writes to the directory:

- `pr.json`: the PR's node id, title, head SHA and base branch. Keep the head SHA; marking checks it.
- `files.json`: every changed file, smallest diff first, with its status, previous name, line counts and patch.
- `patches.txt`: the same patches as one text file, smallest first, each headed by its path, status and line counts. Read it in pages; printing it whole overflows the terminal. A file with no patch (too large or binary) goes in review.
- `viewed.jsonl`: the viewer's viewed state per file. `DISMISSED` means they viewed it and a later push changed it.

Tell the user in one line how many files there are and that you are reading them. When the local checkout is at the head SHA, the local diff against the base gives the same changes with more context, and lets you read a source file whole.

## 2. Classify

### Scope

Judge a file by what the reviewer has not read yet, not by the whole PR diff:

- **A commit range** ("the last 3 commits", "since my review"): classify each file by its diff across that range only, and leave files the range does not touch alone. Leave out a file that commits just before the range also changed, unless the user says they saw those.
- **A `DISMISSED` file**: its older content was already read, so judge it by the commits pushed since. GitHub does not say which commit the reviewer saw, so ask for the range when the user does not name one.

### Categories

If you are unsure, the file is not trivial. A wrongly marked file hides code from the reviewer; a wrongly unmarked one costs a few seconds.

**Trivial: mark as viewed.** Every hunk is one of these, and nothing else changes behaviour or a contract:

- a pure rename or move (renamed with an empty patch), or an import path that follows a move;
- import reordering, or an import swapped for a renamed symbol along with its call sites;
- a local variable or parameter renamed, where it does not reach any exported signature;
- a helper extracted or inlined with the same logic and the same evaluation (no loop, callback or asynchronous step moved in between);
- an export deleted after a search of the repo, including dynamic uses (registries, filename routes, configuration, string keys), finds no user; or a local made exported without changing the local itself;
- a formatting-only change.

Removing memoization or caching is **not** trivial: it changes the identity of a value and what depends on it. It goes in skim, unless the project's rules say its compiler memoizes that code.

**Follows: mark as viewed, credit the source.** A call site that only adopts an API whose design lives elsewhere: an old hook or component swapped for its replacement, a literal swapped for a named id from a shared registry, a call updated to a changed signature. The decision is reviewed once at the source (a file in this PR, or code already on the base branch), not again at every call site. Find these by grouping hunks that make the same swap across files. A file qualifies only when:

- every hunk is one of those swaps or one of the trivial kinds; one file can hold several different swaps;
- you read the source and confirmed that each new id or call behaves like the old one, including any options the call site still passes, and the source entry's own flags (a platform gate, an availability check, a default). A swap onto an entry that adds a gate changes where the call site works, so it goes in review;
- a loop of old calls replaced by one batched call does exactly what the loop did. If the batch differs, for example in ordering or in which item ends up selected, the file goes in review and the report names the difference.

When one commit renames or swaps across many files, check it mechanically as [sweep.md](sweep.md) describes instead of reading each file.

A call site that changes behaviour (a different value, scope or default) or does anything beyond the swap goes in review. A file that is all swaps plus one small real change goes in skim with the note "rest follows <source>", so the reviewer reads only the extra change.

**Skim: leave unmarked, list it.** Small but real changes:

- a style, value or copy tweak;
- a dependency bump in a manifest, a version catalog or an environment file;
- a generated file, such as a lockfile or generated types;
- docs, rules and skill files.

**Review: leave unmarked, put it in the reading order.** Anything else, including:

- new or changed props, fields, schemas, API procedures, message channels or environment variables;
- a changed function signature, even with an additive argument;
- new files, and files deleted along with the logic they held. A file deleted because its last user stops using it in this PR goes next to that user.

## 3. Mark

Write every **trivial** and **follows** path, one per line, to a file in the scratchpad, then:

```sh
scripts/mark.sh <owner/repo> <n> <head SHA from pr.json> <paths file>
```

It refuses (exit 2) when the author pushed since the fetch: fetch again and reclassify before marking anything. Otherwise it marks the paths in batches GitHub accepts, retries the ones that failed, and confirms each reads `VIEWED`. Paths still unmarked at the end are listed on stderr (exit 1); report them. Marking a file the viewer already marked does nothing.

Ask before marking anything outside those two categories, such as a lockfile.

## 4. Report

Keep it short.

### Summary

One line: files in total, marked trivial, marked follows, skim, review. Then the lines of diff taken off the reviewer's plate (the added plus removed lines of every marked file), as a number and as a share of the PR's total.

### Details

- **Marked (n)**: each path with a few words on why it is trivial.
- **Follows (n)**: one group per source, with its path and whether it is in this PR or on the base branch, the swap as old → new, the equivalence you checked, and the marked call-site paths.
- **Skim**: the paths grouped by kind, one line per group.
- **Review order**: core logic first (shared packages, then state and domain logic, then features, routes and UI), each with a one-line summary of what changed. Put a moved file next to its old path. Put each in-PR source before the files that follow it, and note how many call sites it covers.
- **Changed since viewed**: the paths in skim or review that `viewed.jsonl` shows as `DISMISSED`. Leave this line out when there are none.
- **Not marked**: any path the mark script could not mark. Leave this line out when there are none.
