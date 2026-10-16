---
name: cleanup
description: Shrinks the current branch's diff without changing behaviour. Reuses what the stack already provides, deletes dead code and indirection, splits files by subject, strips non-warning comments, and ends with a summary of what was optimized. Use when asked to clean up, simplify, shrink or tidy a branch, diff or PR before review or merge. Works in any repo.
---

# Cleanup

Make the branch's diff as small as it can be **while every observable behaviour stays identical**. The bar is not "tidier" — it is "could this be written in half the lines with what the project already has?" The only behaviour change allowed is a real bug found on the way, reported as one.

Everything below is a rule, not a recipe. Apply each one with the project's own languages, tools and conventions; the project's instructions decide how, this skill decides what.

## 1. Setup

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
- **Know who else writes to the working tree.** Other sessions, agents or tools may share the checkout. Watch for edits you did not make for the whole run; stay out of files someone else is changing; never commit, revert or stash work that is not yours; keep your own changes in commits of their own so the summary can separate them.
- **Read every changed file whole.** The branch may have made code outside its hunks dead.
- **Write a behaviour ledger**: each thing the branch makes the program do — outputs, side effects, error paths, UI and keyboard states, and the platforms and runtime versions it promises to support. Every cut is checked against it.

## 2. Map the stack

Code is only shorter if you know what you may reuse. Build an **inventory**, one line per concern and its owner, before cutting anything:

- **The project's own stack map**, if its rules have one. It is the starting inventory and outranks anything discovered.
- **Dependencies per workspace**: what each workspace containing a changed file declares. Only those resolve in that file; a sibling workspace's dependency is a proposal, not a reuse.
- **The project's own toolbox**: its shared utilities, hooks, services and UI components with their variants — by name, not just by location.
- **Options of what the diff already uses**: for each dependency the changed files import, read the **installed** version's types or docs for options and helpers that replace surrounding code, and note the lowest runtime or platform version each one needs. Memory describes some other version.

## 3. Scan with tools

Tools find dead code and copies a read-through misses. Run the ecosystem's analysers for:

- unused files, exports, types and dependencies;
- copy-paste across the touched directories, including against untouched code;
- the compiler's unused-locals and unused-parameters checks, as a one-off run, never a config change;
- the linter's report of suppressions that suppress nothing.

Their output is a list of leads, never verdicts. Keep only findings in changed files or in code the diff orphaned; drop anything that predates the branch; verify each survivor against step 6's dynamic-use search and architecture check. Expect noise from entry points reached by globs, filename-based routing, styles and test runners, and from per-variant code a project duplicates on purpose.

## 4. Fan out on large diffs

A small diff (roughly under 15 files and 600 lines, or a single module): do steps 5–9 yourself. Otherwise partition the changed files into **disjoint** groups by module — a file travels with its tests and styles — and start one subagent per group, all at once. Each brief carries the base, its file list, the inventory, the tool findings for its files, the applicable rule files and ledger lines, steps 5–9 and the traps in step 11, and these constraints:

- Edit only your files. A change needed elsewhere — a shared helper, a missing component variant, a caller in another module, a cross-module duplicate — goes in the report.
- No repo-wide autofix or formatters. Check only your files and ignore errors in others; they are mid-edit.
- No commits, stashes or resets.
- Report per-file net lines; what was replaced, deleted, split, fixed and left alone; cross-module findings; and how each ledger entry was verified.

When all return: act on the cross-module findings, hand-review any file two agents touched, and check every agent's cut against the ledger yourself — "no behaviour change" in a report is a claim, not a result. Then run steps 10–11 over the whole tree.

## 5. Replace with what exists

Walk every hand-written mechanism in the diff — an effect, loop, parser, state sync, cache, retry, listener, formatter, validation, cast, conditional styling, block of markup — and ask what already owns it, in this order:

1. A language or runtime built-in.
2. The project's own helper.
3. A shared component, or a new variant on it. A call site restyling a shared component's surface means the component lacks a variant: add the variant where the component lives, and the call site keeps layout only. If the project uses a component registry, search it before writing markup.
4. An option or helper of an installed dependency.
5. A well-known format or algorithm with no dependency yet: name a package in the report. Adding one is the user's call.

**The owner must do the same thing.** Check its edge cases — empty input, rounding, locale, ordering, the error it raises — and the lowest version it needs against the ledger before swapping.

## 6. Delete

- **Dead code the branch created or orphaned**, including the old path its new code supersedes and a dependency nothing uses any more. Search each symbol for dynamic use too (registries, filename routes, configuration, string keys) before removing it. Orphaned files, fixtures, flags and environment variables count; tests that only covered deleted code go with it.
- **Imagined states**: guards, error handlers, null checks and defaults for states the types or callers rule out, and compatibility code nobody outside needs. Validate once at the boundary, then trust the type.
- **Indirection**: a helper, wrapper, variable, type or option with one use or no setter; an abstraction with one implementation. Inline it.
- **Name-only functions**: a function whose body is one expression no harder to read than its name — a comparison, a property path, a null check, a call that only forwards — is inlined at every call site, however many there are. Its parameter defaults move to where the value enters, and any contract its documentation carried moves to the code that relies on it.
- **Duplication and derivable state**: near-identical blocks that differ only in data become one block over a table. For each new function, search the repo for the key call it makes; an existing function of the same shape wins and the new one goes. A value that mirrors something computable is computed where it is read, and its sync code is deleted.
- **No-ops**: an argument equal to the callee's default (read the callee first), a re-check of an already-gated condition, branches returning the same thing, casts and annotations the compiler does not need, suppressions that suppress nothing.

**Architecture is not cruft.** Before replacing, deleting, inlining or merging anything in steps 5–7, check whether it is a pattern the project uses on purpose: a layer boundary, a module's public entry, an adapter or port, a registry, a wrapper every sibling has, a split the rules require. It is architecture if the project's rules or docs describe it, or if most siblings share the shape. A one-use wrapper on a layer boundary stays even when inlining would be shorter. Only what the diff introduces *against* the pattern goes.

An unused *option* is speculation and goes; an unused *behaviour* a project doc describes is a decision — ask. Update any doc that describes what you delete.

## 7. Restructure

Line-level deletion stalls; the large wins are shape changes. Ask of each module: *written today, knowing the final behaviour and the inventory, what would it look like?*

- A branch chain over one value's cases becomes a lookup table; parallel per-variant functions become one function plus per-variant data.
- An adapter that unpacks an object into a callee's parameters goes; the callee takes the object.
- State always set together becomes one value; calls always made in sequence become one.
- Anything only its own file uses stops being exported.

## 8. One subject per file

For every changed file, **list its subjects**: each component, class, stateful service, variant branch or adapter. Anything past the first moves to its own file shaped like its siblings; importers are repointed, never served through a re-export; then check what the old file still exports for newly dead values. A split is the one change allowed to add lines.

## 9. Shape, comments, tests, bugs

- **Read like a person wrote it.** Compression is not golf: plain branches over clever one-liners. Where siblings disagree, use the majority spelling everywhere. A linter's demand outranks taste, and a cut that breaks a lint limit (complexity, length, nesting) is reverted, not suppressed.
- **Comments**: keep one only if, without it, the next reader would misunderstand or break the code. A comment explaining *what* is a naming problem: rename until the code says it, then delete the comment.
- **Tests** the diff adds or changes are held to the project's test-quality skill or rules, if it has one.
- **Stand-ins**: copies the project keeps in sync with real UI (loading shells, skeletons, snapshots — its instructions name them) mirror any visible change the cleanup made.
- **Exit transitions are behaviour.** An overlay whose visibility derives from nullable data keeps rendering its last value until its exit transition ends; unmounting or emptying its content at the moment it closes kills the transition. Finding one violation means sweeping the repo for the rest.
- **Bugs** the pass finds are fixed and listed separately.

## 10. Repeat

Shape changes open new deletions. Re-run steps 3 and 5–9 on the new diff until a pass saves under about 2% of its lines. Measure each rewrite against the version before it: one that needs new types, constants or suppressions to stand up, or that did not shrink the diff (splits aside), is reverted.

## 11. Verify

Run lint, typecheck and tests; a failure not in the step-1 baseline is yours. **Never edit a test to make a cleanup pass** — revert the cut instead. Walk the ledger and exercise each entry, including keyboard flow and accessibility of every touched surface, or state which entries were checked only by tests, only by types, or not at all.

Traps that turn a cut into a behaviour change:

- **Defaults are behaviour.** Removing a parameter default changes every caller that relied on it, including callers that pass the function by reference.
- **Inlining moves evaluation.** Inlined into a loop, callback or render, an expression runs once per pass; moved across an asynchronous step or a mutation, it reads a different value.
- **Identity is behaviour.** Merging separate values, memoized results or subscriptions into one changes what dependency tracking and equality checks see.
- **Falsy is not nullish.** Swapping a falsy check for a nullish one, or back, changes the result for zero, empty text and false.
- **Errors move.** Removing an error handler, or turning synchronous code asynchronous, changes where and when a failure surfaces.
- **A library is not a drop-in.** Its trimming, locale, sort stability or error type can differ from the code it replaces.
- **Version floors are behaviour.** An API newer than the lowest runtime, platform or browser the project promises silently changes or breaks behaviour there. Check every replacement against every declared floor, not just the version installed locally.

## 12. Report

Measure the diff against the same base as in step 1, then give the report in this order.

### Summary

Open with a table of the size change and keep every row, writing 0 where nothing happened:

| Metric | Before | After | Change |
| --- | --- | --- | --- |
| Files changed | | | |
| Lines added | | | |
| Lines removed | | | |
| Net lines | | | absolute and % |

Follow it with one line of counts: replaced, deleted, inlined, split, comments removed, tests removed or merged, bugs fixed, packages proposed, attempts reverted, findings left alone.

Then:

- **Checks**: typecheck, tests and lint, each as passing or failing against the step-1 baseline.
- **Ledger coverage**: how many entries were exercised, checked by tests only, checked by types only, or not verified.
- **Attribution**: if someone else committed to the branch during the run, how much of the size change is theirs and how much is the cleanup's.

### Details

- **Replaced**: what, and which owner replaced it.
- **Deleted**, **split**, **bugs fixed** (each with its failure scenario), **packages proposed**.
- **Left alone and why**: every kept piece that looks like cruft, and every dismissed tool finding in a changed file, one line each, so the next pass does not re-argue it.
- **Proposed, not done**: cross-module or out-of-scope changes, with location and expected saving.

A project-specific trap hit on the way goes into the project's rule files; a reuse the inventory lacked goes into its stack map.
