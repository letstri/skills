---
name: user-behavior-qa
description: Tests the running app through its visible browser UI as a real user (journeys, states, validation, keyboard) and reports what works, what's broken and what went untested, without reading implementation code. Use when asked to QA, test, smoke-test or click through a feature or the app, or to check a change works for a user. Works in any repo.
---

# User Behavior QA

Review the product from the user's side. Treat the browser as the product boundary: use visible controls, navigation, forms, feedback, and persisted results. Do not inspect source code, internal APIs, database clients, server logs, or implementation details unless the user explicitly expands the scope. The browser console is fair evidence (see §4).

## 1. Intake

Before the first browser action, read what the repo says about running and opening the app (`AGENTS.md` / `CLAUDE.md` and the rule files they index, the README) and its domain or user docs for the area in scope. They give the dev URL, the product terms to use in the report, and which gaps are deliberate.

Defaults, unless the developer or the repo docs say otherwise:

- **Target:** the local dev URL — the worktree's own when testing a branch.
- **Mutations:** create, edit and delete test data on local dev. Any other environment, or an unclear one, is read-only.

Then send **one message** with every open question, and wait for the answer before the first browser action:

- **Browser**, every run, unless the developer named one in this request. Offer only the browsers this session can actually drive, each with its trade-off: the developer's own browser (their sign-ins, but it shares storage with their tabs), a built-in or embedded browser, or a separate automation browser (isolated and signed out). Repo docs that recommend a browser make it the suggested option, not the answer. Never pick one silently.
- **Sign-in**, when the app or its docs show it needs one and the chosen browser is not already signed in: the developer signs in themselves in the opened tab and says when done, or gives you credentials (ideally a test account) that you enter in the sign-in form.
- **Scope**, only what the request leaves open: the pages, workflows, entities, variants (platforms, engines, plans) and roles in scope, and the expected behavior or baseline.

If a sign-in wall appears that intake did not foresee, stop and ask the sign-in question then. Once answered, state the test charter in one sentence and start.

## 2. Operate like a user

- Stay inside the product UI. A built-in query editor or admin screen is allowed because it is part of the user experience.
- Use ordinary clicks, typing, keyboard navigation, and visible menus. Never call internal endpoints, inject application state, edit storage, or mutate the DOM to manufacture a result.
- Use browser evaluation only to read the rendered page or activate the same visible control when normal browser references fail.
- Use a recognizable test prefix such as `qa_<feature>_<purpose>` and record every artifact created.
- Enter only credentials the user gave you for this run, only into the target app's own sign-in form. Never guess, reuse or look up credentials, and never write them into the report or test artifacts.
- Treat production or unclear environments as read-only until the developer explicitly allows mutations.
- Continue past isolated failures when another path remains testable. Do not repair the application during the review.

## 3. Exercise the scoped journey

Discover available surfaces from the UI itself. For every page or workflow in scope, test the applicable path end to end:

1. Open it through normal navigation and, when useful, its direct URL.
2. Check loading, empty, populated, and unsupported states that naturally occur.
3. Create a safe representative object or record. Cover meaningful subtypes when one form creates materially different objects.
4. Exercise required-field validation and one realistic server error that is safe to trigger, such as a duplicate name or a wrong type. Never run a destructive action against shared environments.
5. Verify success feedback, count, list row, displayed values, search, filters, and refresh persistence.
6. Open the created item and verify the detail or edit view reflects what was submitted.
7. Test visible lifecycle actions such as edit, enable or disable, revoke, and delete when offered.
8. Check labels, instructions, default values, disabled and loading states, focus, keyboard use, and accessible names while following the journey.

Use the smallest starter state that unlocks the workflow. If one created record supports several tests, reuse it.

A page is complete when every applicable step above has either been observed or recorded as untestable with the visible reason.

## 4. Evidence rules

- Report only what was observed through the UI. A browser console error seen during the journey can support a finding. Label it as console evidence and do not guess the cause from it.
- Before reporting that a control does not respond or an animation is stuck, rule out the browser traps below.
- A gap the repo's docs describe as deliberate is not a finding.
- Quote exact labels and errors when they identify the problem.
- Capture a screenshot of each broken step when the chosen browser supports it, and reference it in the finding.
- Separate defects, missing capabilities, intentional unsupported states, and untested paths.
- Do not infer implementation causes.
- Do not label a platform- or vendor-native limitation as an application defect. State the visible limitation and its effect.
- Preserve useful test artifacts unless cleanup was requested. Always list the `qa_*` artifacts left behind, and name any that cannot be removed through the UI.

**Browser traps** — each one looks like an app bug and is not:

- **Any browser: the dev server reloads mid-session.** A first-time chunk load can make the bundler re-optimize dependencies and crash or reload the page. Navigate to the same URL once and continue; report it only if it repeats.
- **The developer's own browser: a background tab is frozen.** An automated tab behind another window has `visibilityState: hidden`: `requestAnimationFrame` never runs, so animations and transitions stop mid-way, rAF-scheduled popups stay shut, and global hotkeys do nothing. Check the tab's visibility before calling a control broken.
- **The developer's own browser: storage is shared with their tabs.** Preferences changed in the automated tab (pane sizes, theme, filters) change theirs on the same origin.
- **An isolated browser: it starts signed out and empty.** A missing preference, onboarding screen or empty list may be the fresh profile, not a regression.

## 5. Report

Before writing it, wrap up: restore any preferences you changed, close the tabs you opened, and in the developer's own browser ask them to reload their tab.

Return a concise report with:

### Summary

One line of counts: journeys tested, working, broken, untested; then findings by severity.

- **Blocker**: the journey cannot be completed.
- **Major**: the journey completes, but a step is wrong, lost or misleading.
- **Minor**: wording, layout, focus or polish that does not change the outcome.

### Tested

List the environment, role, pages, workflows, and objects created.

### Working

List completed user journeys without narrating every click.

### Missing or broken

For each finding include:

- page or workflow;
- short reproduction path;
- observed result;
- expected user-facing result or practical impact;
- severity, and the screenshot when one was taken.

Order findings by severity, blockers first.

### Untested and cleanup

List blocked paths, their visible blockers, and any test artifacts left behind.
