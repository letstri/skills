---
name: cleanup
description: Shrinks the current branch's diff without changing behaviour. Reuses what the stack already provides, deletes dead code and indirection, splits files by subject, strips non-warning comments, and ends with a summary of what was optimized. Use when asked to clean up, simplify, shrink or tidy a branch, diff or PR before review or merge. Not a bug hunt or a code review; it only makes the same behaviour smaller. Works in any repo.
---

# Cleanup

Make the branch's diff as small as it can be **while every observable behaviour stays identical**. The bar is not "tidier" — it is "could this be written in half the lines with what the project already has?" The only behaviour change allowed is a real bug found on the way, reported as one.

Everything here is a rule, not a recipe. Apply each one with the project's own languages, tools and conventions: the project's instructions decide how, this skill decides what.

The work runs in three phases: **Prepare** what may be cut, **Cut** it by following [cutting.md](cutting.md), then **Prove** the result and report it.

## Prepare

### Scope and baseline

- **Project instructions outrank this skill.** Read the repo's agent instruction files and every rule file they index that the diff touches, before anything else.
- **Compatibility code is owed only to consumers outside the repo**: a published package, a public API, persisted data, a released app. Establish which of these exist; everything else gets no shims, aliases, fallbacks or migrations.
- **Pick the base**, first match wins. An argument overrides it (a ref becomes the base) or narrows it (a path limits the scope).
  1. The branch has an open pull request: the merge base with the request's target branch.
  2. The branch has commits ahead of the default branch: the merge base with the default branch.
  3. Only uncommitted work: the current commit.
  4. None of these: say so and stop.
- **The target is everything since the base**: commits, uncommitted edits and untracked files. Refresh the remote first.
- **Record the starting size** of the diff (files, lines added, lines removed). It is the number to beat and the "before" column of the summary.
- **Baseline the checks.** Run the project's typecheck, tests and lint before any edit and note what already fails, so a later failure can be attributed.
- **Know who else writes to the working tree.** Other sessions, agents or tools may share the checkout. Watch for edits you did not make for the whole run, stay out of files someone else is changing, and never commit, revert or stash work that is not yours.
- **Write a behaviour ledger**: each thing the branch makes the program do — outputs, side effects, error paths, UI and keyboard states, and the platforms and runtime versions it promises to support. Every cut is checked against it.

### Inventory

Code is only shorter if you know what you may reuse. Build an **inventory**, one line per concern and its owner, before cutting anything:

- **The project's own stack map**, if its rules have one. It is the starting inventory and outranks anything discovered.
- **Dependencies per workspace**: what each workspace containing a changed file declares. Only those resolve in that file; a sibling workspace's dependency is a proposal, not a reuse.
- **The project's own toolbox**: its shared utilities, hooks, services and UI components with their variants — by name, not just by location.
- **Options of what the diff already uses**: for each dependency the changed files import, read the **installed** version's types or docs for options and helpers that replace surrounding code, and note the lowest runtime or platform version each one needs. Memory describes some other version.

### Scan

Tools find dead code and copies a read-through misses. Run the ecosystem's analysers for:

- unused files, exports, types and dependencies;
- copy-paste across the touched directories, including against untouched code;
- the compiler's unused-locals and unused-parameters checks, as a one-off run, never a config change;
- the linter's report of suppressions that suppress nothing.

Their output is a list of leads, never verdicts. Keep only findings in changed files or in code the diff orphaned, and drop anything that predates the branch. Expect noise from entry points reached by globs, filename-based routing, styles and test runners, and from per-variant code a project duplicates on purpose.

## Cut

### Triage

Partition the changed files into **disjoint** groups by module; a file travels with its tests and styles. Skim each group and rate its potential from the scan leads and a quick read: *high* (leads, hand-written mechanisms the inventory owns, files with several subjects) or *low* (wiring the types demand, per-variant data, generated or moved code). Generated files, lockfiles and pure moves are out of scope.

### Who cuts

- **Cut it yourself** when the high-potential part is small (roughly under 15 files and 600 lines, or a single module), and for every low-potential group.
- **Fan out** otherwise: one subagent per high-potential group, all started at once. Low-potential groups never get an agent of their own.

Each subagent's brief carries only: the base, its file list, the inventory, its scan leads, the rule files and ledger lines that apply, the path to [cutting.md](cutting.md) with the instruction to follow it, and these constraints:

- Edit only your files. A change needed elsewhere (a shared helper, a missing component variant, a caller in another module, a cross-module duplicate) goes in the report.
- No repo-wide autofix or formatters. Check only your files and ignore errors in others; they are mid-edit.
- No commits, stashes or resets.
- Report the counts and lists that the **Report** section below asks for, for your files, plus cross-module findings.

### Merge

When all return: act on the cross-module findings, hand-review any file two agents touched, and check every agent's cut against the ledger and the traps in [cutting.md](cutting.md) yourself. "No behaviour change" in a report is a claim, not a result. Then run the cutting checklist once more over the whole diff, since cuts in one group open deletions in another.

## Prove

- **Verify the whole tree**: lint, typecheck and tests; a failure not in the baseline is yours. Never edit a test to make a cleanup pass: revert the cut instead.
- **Walk the ledger**: exercise each entry, including keyboard flow and accessibility of every touched surface, or say whether it was checked by tests only, by types only, or not at all.
- **Commit once, at the end.** Only the coordinator commits, only after verification, and only its own changes, in a commit of its own so the summary can separate them from anyone else's. Push only when the project's or the user's instructions say so; otherwise leave the commit local and say so.
- **Feed the project**: a project-specific trap hit on the way goes into the project's rule files; a reuse the inventory lacked goes into its stack map.

## Report

Measure the diff against the same base as at the start.

### Summary

Open with a table of the size change and keep every row, writing 0 where nothing happened:

| Metric | Before | After | Change |
| --- | --- | --- | --- |
| Files changed | | | |
| Lines added | | | |
| Lines removed | | | |
| Net lines | | | absolute and % |

Follow it with one line of counts. Each change counts once, under the first category that fits:

1. **Bugs fixed**: a cut that changed behaviour because the old behaviour was wrong.
2. **Replaced**: hand-written code swapped for an owner from the inventory.
3. **Restructured**: a shape change (lookup table, merged functions, object parameter).
4. **Split**: a subject moved to its own file.
5. **Deleted**: code removed with nothing in its place, inlining included.
6. **Comments removed**.
7. **Tests removed or merged**.
8. **Reverted**: attempts undone because they failed a check or did not shrink the diff.
9. **Proposed**: changes left for the user (a package, an out-of-scope file).
10. **Left alone**: findings examined and kept.

Then:

- **Checks**: typecheck, tests and lint, each as passing or failing against the baseline.
- **Ledger coverage**: how many entries were exercised, checked by tests only, checked by types only, or not verified.
- **Attribution**: if someone else committed to the branch during the run, how much of the size change is theirs and how much is the cleanup's.
- **Commit**: the cleanup's commit, and whether it was pushed.

### Details

- **Bugs fixed**, each with its failure scenario.
- **Replaced**: what, and which owner replaced it.
- **Restructured**, **split** and **deleted**: what, one line each.
- **Proposed, not done**: location and expected saving.
- **Left alone and why**: every kept piece that looks like cruft, and every dismissed scan lead in a changed file, one line each, so the next pass does not re-argue it.
