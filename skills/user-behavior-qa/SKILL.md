---
name: user-behavior-qa
description: Tests the running app through its visible browser UI as a real user (journeys, states, validation, keyboard, visibly broken layout, consistency with the project's design) and reports what works, what's broken and what went untested, without reading implementation code. Use when asked to QA, test, smoke-test or click through a feature or the app, or to check a change works for a user. Works in any repo.
---

# User Behavior QA

Test the product from the user's side; the browser is the boundary. Don't inspect source, internal APIs, DB clients, server logs or implementation unless the user expands the scope. Console errors are fair evidence (§4).

## 1. Intake

Before any browser action, read how the repo runs and opens the app (`AGENTS.md` / `CLAUDE.md` and the rule files they index, README) and its domain, user and design docs (style guide, design system, mockup links) for the scope. They give the dev URL, the product terms for the report, the design to compare against, and the deliberate gaps.

Defaults, unless the developer or the docs say otherwise:

- **Target:** the local dev URL, the worktree's own for a branch. If nothing runs there, start it with the documented command, or ask when there is none.
- **Mutations:** create, edit and delete test data on local dev. Any other or unclear environment is read-only until the developer explicitly allows mutations.
- **Screenshots:** unless the developer chose none, saved as files in a folder of their own per run, `.qa/<YYYY-MM-DD>-<HHMM>-<slug>/`, at the root of the checkout under test (the worktree's own for a branch), or in the working directory outside git. `<slug>` is two to four kebab-case words naming the scope, e.g. `.qa/2026-10-21-1430-orders-create/`, so parallel runs never share a folder and its name tells what was tested; add `-2` only if the name is taken. Before creating it, add `.qa/` to the file `git rev-parse --git-path info/exclude` prints, if missing, so screenshots are never committed and `.gitignore` stays untouched.
- **Rerun:** an earlier `.qa/` folder with the same slug, or one the developer names, makes this run a rerun of the latest such folder. Re-test each of its `broken/` findings first, then the rest of the scope.

Then send **one message** with every open question and wait for the answer:

- **Browser**, every run unless the request names one. Offer only browsers this session can drive, each with its trade-off and whether it saves screenshots to a file: the developer's own (their sign-ins, shared storage with their tabs), a built-in or embedded one, or a separate automation browser (isolated, signed out). A docs recommendation is the suggested option, not the answer. Never pick silently.
- **Screenshots**, every run unless the request says: of working steps and findings, of findings only, or none. None saves no files and creates no folder; you still look at screenshots to test, and each finding quotes the exact text and location seen instead of citing a file.
- **Sign-in**, when the app needs it and the chosen browser isn't signed in: the developer signs in in the opened tab and says when done, or gives credentials (ideally a test account) that you enter in the sign-in form.
- **Scope**, only what the request leaves open: pages, workflows, entities, variants (platforms, engines, plans), roles, expected behavior or baseline, and a mockup or design reference when the docs give none.

An unforeseen sign-in wall: stop and ask then. Once answered, state the test charter in one sentence and start.

## 2. Operate like a user

- Stay inside the product UI; a built-in query editor or admin screen counts. Use ordinary clicks, typing, keyboard and visible menus. Never call internal endpoints, inject state, edit storage or mutate the DOM to manufacture a result. Use browser evaluation only to read the rendered page or to activate a visible control when normal references fail.
- Prefix test data recognizably, e.g. `qa_<feature>_<purpose>`, and record every artifact created.
- Enter only credentials given for this run, only into the app's own sign-in form. Never guess, reuse or look them up, or write them into the report or artifacts.
- Continue past isolated failures when another path remains. Don't repair the app.

## 3. Exercise the scoped journey

Discover surfaces from the UI. For every page or workflow in scope, end to end where applicable:

1. Open it through navigation and, when useful, its direct URL.
2. Check the loading, empty, populated and unsupported states that naturally occur.
3. Create a safe representative record; cover subtypes when one form creates materially different objects.
4. Exercise required-field validation and one realistic server error that is safe to trigger (duplicate name, wrong type). Never run a destructive action on a shared environment.
5. Verify success feedback, count, list row, displayed values, search, filters and persistence after refresh.
6. Open the created item and check the detail or edit view reflects what was submitted.
7. Test visible lifecycle actions: edit, enable or disable, revoke, delete.
8. Along the way, check labels, instructions, defaults, disabled and loading states, focus, keyboard use and accessible names.
9. **Broken UI.** Inspect every screenshot at the default viewport, once at a narrow width (~1024px, or 375px if the app supports mobile) and in the dark theme if offered, for: overlapping elements; a popup or dropdown clipped or behind another layer; text cut off without ellipsis or tooltip; a number or date wrapped mid-value; raw keys, `undefined`, `null`, `NaN`, `[object Object]` or unformatted values; page-level horizontal scroll; a table or card spilling out of its container; an unreadably narrow column; a missing icon or image; unstyled content; text unreadable against its background; layout jumping between loading and loaded; a spinner that never ends. Confirm overflow from the rendered page (`scrollWidth > clientWidth`), never from the picture. Report only what a user would call broken, not taste.
10. **Design.** Compare with the mockup or design docs when present, and always with two or three established pages of the same app showing the same kind of element. Report concrete deviations, each naming the reference it breaks: a button, table, filter, badge, field, modal, empty state or pagination that looks or behaves unlike its counterpart; differing colors, fonts, sizes, icons or spacing; a status color that means something else elsewhere; dates, numbers, currency, capitalization, tone or language of copy unlike the rest of the app. No reference, no finding. Screenshot the reference next to the deviation.
11. When the developer chose working screenshots, save one per working journey: the shot that proves its end result (the created row after refresh, the edited detail view), plus one for a state that no later shot shows. With findings only, save none for working steps. Either way a step counts as working once observed.

Use the smallest starter state and reuse a record across tests. A page is complete when every applicable step is observed or recorded as untestable with the visible reason.

## 4. Evidence rules

- Report only what the UI showed. A console error seen during the journey can support a finding: label it console evidence. Never infer implementation causes, from the console or otherwise.
- Before calling a control unresponsive or an animation stuck, rule out the browser traps below.
- A gap the docs call deliberate is not a finding. A platform- or vendor-native limitation is not an app defect: state it and its effect.
- Quote exact labels and errors when they identify the problem.
- **Screenshots go only to the §1 folder**, sorted into subfolders: `working/` for verified working steps (only when chosen), `broken/` for findings, and on a rerun `fixed/` for the previous run's findings that now work, saved unless none was chosen and named after the previous run's file, e.g. `fixed/04-logic-orders-save-fails.png`. A previous finding still broken gets a new `broken/` shot as usual. Name them `NN-<page>-<what it shows>.png`, numbered in journey order across both; in `broken/`, prefix the kind after the number: `logic` for a functional defect (a step fails, data is wrong or lost, an error appears), `ui` for a broken-UI or design finding (§3 steps 9–10, its reference screenshot included). A shot showing both is `logic`. Cite them in the report by relative path, e.g. `working/03-orders-filter-by-status.png`, `broken/04-logic-orders-save-fails.png`, `broken/05-ui-orders-table-overflow.png`. Save through the browser tool's file option, else an OS screenshot of the browser window. Report a step whose screenshot couldn't be saved; never skip it silently.
- **Save sparingly.** Look at as many screenshots as testing needs, but save only those a reader of the report needs: one per finding (plus its design reference), one per working journey, one per fixed finding. One defect seen on several pages or viewports gets one shot, its other places listed in the report. Narrow-width and dark-theme passes save only what is broken there.
- A visual finding states its viewport width and theme and its screenshot shows the broken spot. A design finding also names its reference (mockup, doc section or page) and the reference's screenshot.
- Never screenshot a typed password or other secret. Screenshots are kept; they aren't artifacts to clean up.
- Separate defects, missing capabilities, intentional unsupported states and untested paths.
- Keep test artifacts unless cleanup was requested. Always list the `qa_*` ones left, naming any the UI can't remove.

**Browser traps** — each looks like an app bug and isn't:

- **Any browser: dev server reloads mid-session.** A first-time chunk load can make the bundler re-optimize dependencies and crash or reload the page. Reopen the same URL once; report it only if it repeats.
- **Developer's browser: background tab is frozen.** A tab behind another window has `visibilityState: hidden`, so `requestAnimationFrame` never runs: animations stop mid-way, rAF-scheduled popups stay shut, global hotkeys do nothing. Check visibility first.
- **Developer's browser: shared storage.** Preferences changed in the automated tab (pane sizes, theme, filters) change theirs on the same origin.
- **Isolated browser: fresh profile.** A missing preference, onboarding screen or empty list may be the profile, not a regression.

## 5. Report

First wrap up: restore changed preferences, close the tabs you opened, and in the developer's browser ask them to reload their tab.

Return a concise report with the screenshot folder's absolute path at the top when one was made, then these sections:

- **Summary:** one line of counts (journeys tested, working, broken, untested, and on a rerun fixed), then findings by severity:
  - **Blocker**: the journey can't be completed.
  - **Major**: it completes, but a step is wrong, lost or misleading; broken layout hides, covers or garbles data or a control; or a design deviation misleads (a status color that means the opposite elsewhere).
  - **Minor**: wording, layout, design deviation, focus or polish that changes no outcome and hides nothing.
- **Tested:** environment, role, pages, workflows, objects created.
- **Fixed**, on a rerun: each previous finding now working, with its old and new screenshot paths (new only when saved). Previous findings still broken are listed under Missing or broken, marked "still broken" with the old path.
- **Working:** completed journeys without click narration, each with its screenshot file names when saved.
- **Missing or broken**, blockers first, each with: page or workflow, short reproduction, observed result, expected result or practical impact, severity, screenshot path when saved.
- **Untested and cleanup:** blocked paths with their visible blockers, and test artifacts left behind.
