---
name: cleanup
description: Review the current branch's diff against its base, then shrink it — delete code that carries no logic, split files that hold more than one subject, make new code look like the code around it, replace per-page styling with component props, strip every comment that is not a warning, and fix bugs the pass surfaces. Use before opening or updating a PR, or when the user says the branch got messy.
---

# Cleanup

Shrink a branch's diff without changing what it does. **Fewer lines, fewer overrides, fewer comments, one subject per file** — every change is behaviour-preserving unless it fixes a real bug found on the way.

Read first: the repo's agent instructions (`AGENTS.md` / `CLAUDE.md` and whatever rule files they index) and its lint config. They define what "clean" means in that repo; this skill is the pass that enforces them. Where a repo rule contradicts a step below, the repo wins.

## 1. Get the diff

```sh
BASE_BRANCH=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
git fetch -q origin "$BASE_BRANCH"
BASE=$(git merge-base HEAD "origin/$BASE_BRANCH")
git diff --stat $BASE   # keep for the report
git diff $BASE          # committed + uncommitted work
git status --short      # untracked files are part of the review
```

Read every changed file **whole**, not only the hunks — a hunk hides the helper above it that is now unused.

## 2. Delete

In rough order of payoff:

- **Dead code the branch created**: unused exports, props never passed, state never read, helpers with one caller (inline them). Grep each new symbol repo-wide before keeping it.
- **Imagined states**: a guard or `try`/`catch` the surrounding module would not write, protecting a state that cannot occur; compatibility shims, aliases, retries and fallbacks nobody is owed; casts that launder types (`as any`, `as unknown as T`, `!` where narrowing works); intermediate variables that name nothing.
- **Reinvention**: markup re-implementing a component the UI kit already has, a hand-rolled effect where a library option exists, a loop where a built-in reads better.
- **Hand-written code for a well-known format or algorithm** (CSV, diff, glob, semver, date math…): check for a small, maintained, zero-dependency package. Adding a dependency is the user's call — list it under "left alone and why" with the package name; don't keep it silently.
- **Speculative shape**: an abstraction with one implementation, an option nobody sets, a wrapper that forwards. Collapse it.
- **Duplicate logic** added next to an existing helper — reuse the helper. The same inline type in two files is one named type exported by the file that owns it.
- **No-op code**: a prop set to the component's default (read the default before keeping it); an `onClick` re-checking the condition that already sets `disabled`; branches that all return the same value; a caller spelling out `undefined`/`false` fields only read truthily; recomputing a value already in scope.
- **Unused lint escapes**: run the linter with its report-unused-directives option on the changed files and delete every disable that suppresses nothing — a moved line often leaves its directive behind.
- **Orphan files**: a patch, asset or fixture nothing references. Check the registry a file needs to be in, not just imports.

Do **not** delete a behaviour the repo's docs describe on purpose — an unused *option* is speculation, an unused *behaviour* someone wrote down is a decision. Speculation goes; a decision gets asked about. Either way, **the doc describing what you deleted is updated in the same pass**.

## 3. One subject per file

Ask it of every changed file, whatever its length: **list its subjects.** A subject is a component, a hook with its own refs or effects, one branch of a layout switch, or an adapter that unpacks one object into another's parameters. Anything past the first moves out:

- A layout branch whose sibling already has its own file gets its own file, shaped like the sibling.
- A cluster of refs, an effect and an imperative handle serving one job is a `use<Job>` hook in its own file.
- An adapter that spreads an object into callbacks for a single callee means the callee should take the object.
- After a split, grep what the old file exported — a value only the moved code used is now dead.

Lines a split adds do not count against the shorter diff. Repoint importers at the new file; never re-export from the old one.

## 4. Match the house shape

New code should be indistinguishable from the code beside it, and read as written by a person, not compressed. Plain branches beat a clever one-liner; an `if` chain over one field's values is a lookup record; a class ternary repeating its shared classes is `cn(shared, cond ? a : b)`; several `useState`s always set together are one object state. Pick the majority spelling — one hook for one job, one import path, one prop-type style across sibling files.

Look at what the repo actually does before "fixing" a file to a rule: when the linter demands something a style rule forbids, the linter wins.

## 5. UI

- **A className on a kit component is a missing prop.** Surface classes (padding, radius, background, border, font size, height) move into a `size`/`variant` on the component; the call site keeps layout only.
- **A popup driven by nullable data must close with its fade.** A dialog, drawer or popover with `open={!!item}` that renders `item && <DialogContent>` unmounts the moment it closes — no exit animation — and `item?.x` in the body fades out an empty box. Keep the last non-null value and clear it once the exit animation ends (Base UI / Radix-style `onOpenChangeComplete`, or the library's equivalent):

  ```tsx
  const [shown, setShown] = useState(item)
  if (item && item !== shown) {
    setShown(item)
  }
  <Dialog open={!!item} onOpenChangeComplete={(open) => !open && setShown(null)}>
    {shown && <DialogContent>…</DialogContent>}
  </Dialog>
  ```

  `open`, closing and actions read the live `item`; everything the user sees reads `shown`. Sweep the whole repo for `open={!!x}` / `open={x !== null}` when you find one.
- **Never reset a popup's state where it closes** (submit success, Cancel, `onOpenChange(false)`) — it is still animating out, so the form blanks mid-fade. Reset on open or after the exit animation.
- Every new surface is keyboard-operable: arrows within, Enter descends, Escape ascends one step at a time; opening focuses something useful and closing returns focus to the trigger.
- Changed chrome is mirrored in any skeletons or loading shells that copy it.

## 6. Comments

A comment is a warning or it does not exist. For each one: *without it, would the next reader misunderstand what this code does, or break it?* If not, delete it. A comment needed to explain *what* code does is a naming problem — rename or extract until the code says it, then delete the comment.

## 7. Fix what the pass surfaces

A pass over the whole diff finds real defects — a wrong dependency, a missed error path, a stale cache key, an `await` that isn't. Fix them and say so in the report. Verify library behaviour against official docs, not memory.

## 8. Verify

Run the repo's autofix, lint, type check and the tests the branch touches — all must be clean. Then run the app and exercise the changed screens. Behaviour-preserving means verified, not assumed; when the app can't be run, say which checks did run instead of implying the screens were seen.

Traps this pass keeps hitting:

- **A default parameter is part of the behaviour.** Re-signing `createItem(value = '')` → `createItem()` silently changes every `.map(createItem)` call site. Re-read each caller after touching a signature.
- **Inlining has a lint limit.** Folding a helper into its caller can push the caller past a complexity rule — then the helper stays.
- **Lint vetoes some obvious rewrites** (`no-nested-ternary` and similar). Check before rewriting.
- **A "simpler" rewrite that needs new types, consts or lint escapes to stand up is not simpler.** Measure it against the original and revert if it lost. The one exception is a split by subject (step 3).

## 9. Report

`git diff --stat` before vs after, then four lists: **deleted**, **split**, **bugs fixed**, **left alone and why**. Anything intentionally kept that looks like cruft gets a line, so the next pass does not re-litigate it.
