# Cutting

The procedure for shrinking a set of files without changing behaviour. The coordinator follows it on a small diff; every subagent follows it for its group. Run the checklist top to bottom, then repeat it on the new diff (see **Repeat**).

## Inputs

- The base, the files in scope, and the inventory (concern → owner, installed dependencies included).
- The tool findings for these files.
- The project's rule files that apply, and the behaviour ledger lines for these files.

Read every file in scope whole before the first edit.

## 1. Replace hand-rolled code

The largest wins live here, so hunt rather than skim. Walk every hand-rolled mechanism (an effect, loop, parser, state sync, cache, retry, debounce, listener, formatter, date or number math, validation, deep comparison, cast, conditional styling, block of markup) and ask what already owns it, in this order:

1. A language or runtime built-in.
2. The project's own helper.
3. A shared component, or a new variant on it. A call site restyling a shared component's surface means the component lacks a variant: add the variant where the component lives, and the call site keeps layout only. If the project uses a component registry, search it before writing markup.
4. An installed dependency, whether or not these files import it yet: look up its installed API for the helper or option that does the job.
5. A package that is not a direct dependency of this workspace: a **candidate package**. Raise one when it replaces a mechanism with edge cases of its own (date math, parsing, deep comparison, retries, validation schemas, virtualised lists, accessibility primitives) or several copies of one; a few-line helper stays hand-rolled. Record the package, the code it replaces with its line count, and its cost (a new dependency, its install size, the lowest runtime it needs), and leave the code as it is: the coordinator asks the user.

**The owner must do the same thing.** Check its edge cases (empty input, rounding, locale, ordering, the error it raises) and the lowest version it needs against the ledger before swapping.

The step is done when every hand-rolled mechanism in scope is swapped for an owner, recorded as a candidate package, or noted with the reason it stays.

## 2. Delete

- **Dead code the branch created or orphaned**, including the old path its new code supersedes and a dependency nothing uses any more. Search each symbol for dynamic use too (registries, filename routes, configuration, string keys) before removing it. Orphaned files, fixtures, flags and environment variables count; tests that only covered deleted code go with it.
- **Imagined states**: guards, error handlers, null checks and defaults for states the types or callers rule out, and compatibility code nobody outside needs. Validate once at the boundary, then trust the type.
- **Indirection**: a helper, wrapper, variable, type or option with one use or no setter; an abstraction with one implementation. Inline it.
- **Name-only functions**: a function whose body is one expression no harder to read than its name (a comparison, a property path, a null check, a call that only forwards) is inlined at every call site, however many there are. Its parameter defaults move to where the value enters, and any contract its documentation carried moves to the code that relies on it.
- **Duplication and derivable state**: near-identical blocks that differ only in data become one block over a table. For each new function, search the repo for the key call it makes; an existing function of the same shape wins and the new one goes. A value that mirrors something computable is computed where it is read, and its sync code is deleted.
- **No-ops**: an argument equal to the callee's default (read the callee first), a re-check of an already-gated condition, branches returning the same thing, casts and annotations the compiler does not need, suppressions that suppress nothing.

**Architecture is not cruft.** Before replacing, deleting, inlining or merging anything, check whether it is a pattern the project uses on purpose: a layer boundary, a module's public entry, an adapter or port, a registry, a wrapper every sibling has, a split the rules require. It is architecture if the project's rules or docs describe it, or if most siblings share the shape. A one-use wrapper on a layer boundary stays even when inlining would be shorter. Only what the diff introduces *against* the pattern goes.

An unused *option* is speculation and goes; an unused *behaviour* a project doc describes is a decision: report it, do not cut it. Update any doc that describes what you delete.

## 3. Restructure

Line-level deletion stalls; the large wins are shape changes. Ask of each module: *written today, knowing the final behaviour and the inventory, what would it look like?*

- A branch chain over one value's cases becomes a lookup table; parallel per-variant functions become one function plus per-variant data.
- An adapter that unpacks an object into a callee's parameters goes; the callee takes the object.
- State always set together becomes one value; calls always made in sequence become one.
- Anything only its own file uses stops being exported.

## 4. One subject per file

For every file in scope, **list its subjects**: each component, class, stateful service, variant branch or adapter. Anything past the first moves to its own file shaped like its siblings; importers are repointed, never served through a re-export; then check what the old file still exports for newly dead values. A split is the one change allowed to add lines.

## 5. Shape, comments, tests, bugs

- **Read like a person wrote it.** Compression is not golf: plain branches over clever one-liners. Where siblings disagree, use the majority spelling everywhere. A linter's demand outranks taste, and a cut that breaks a lint limit (complexity, length, nesting) is reverted, not suppressed.
- **Comments**: keep one only if, without it, the next reader would misunderstand or break the code. A comment explaining *what* is a naming problem: rename until the code says it, then delete the comment.
- **Tests** in scope are held to the project's test-quality skill or rules, if it has one.
- **Stand-ins**: copies the project keeps in sync with real UI (loading shells, skeletons, snapshots; its instructions name them) mirror any visible change a cut made.
- **Bugs** found on the way are fixed and listed separately, each with its failure scenario.

## Repeat

Shape changes open new deletions. Run the checklist again on the new diff until a pass saves under about 2% of its lines. Measure each rewrite against the version before it: one that needs new types, constants or suppressions to stand up, or that did not shrink the diff (splits aside), is reverted.

## Traps

Each one turns a cut into a behaviour change. Check every cut against all of them.

- **Defaults are behaviour.** Removing a parameter default changes every caller that relied on it, including callers that pass the function by reference.
- **Inlining moves evaluation.** Inlined into a loop, callback or render, an expression runs once per pass; moved across an asynchronous step or a mutation, it reads a different value.
- **Identity is behaviour.** Merging separate values, memoized results or subscriptions into one changes what dependency tracking and equality checks see.
- **Falsy is not nullish.** Swapping a falsy check for a nullish one, or back, changes the result for zero, empty text and false.
- **Errors move.** Removing an error handler, or turning synchronous code asynchronous, changes where and when a failure surfaces.
- **A library is not a drop-in.** Its trimming, locale, sort stability or error type can differ from the code it replaces.
- **Version floors are behaviour.** An API newer than the lowest runtime, platform or browser the project promises silently changes or breaks behaviour there. Check every replacement against every declared floor, not just the version installed locally.

## Verify

Run the project's lint, typecheck and tests on the files in scope; a failure not in the baseline is yours. **Never edit a test to make a cut pass**: revert the cut instead. For each ledger entry, exercise it or say whether it was checked by tests only, by types only, or not at all.
