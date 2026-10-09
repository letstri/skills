# Skills

Agent skills for Claude Code, Codex, Cursor and other agents that support [skills.sh](https://skills.sh).

[![skills.sh](https://skills.sh/b/letstri/skills)](https://skills.sh/letstri/skills)

## Install

```sh
npx skills add letstri/skills            # pick skills interactively
npx skills add letstri/skills --all      # install every skill
npx skills add letstri/skills --skill cleanup -g   # one skill, globally
npx skills add letstri/skills --list     # list without installing
```

## Skills

| Skill | Use it when |
| --- | --- |
| [`cleanup`](skills/cleanup/SKILL.md) | Manual (`/cleanup`), before opening or updating a PR: shrinks the branch's diff without changing behaviour — reuses what the stack already provides, deletes dead code and indirection, one subject per file, warning-only comments; repeats until a pass stops paying. |
| [`user-behavior-qa`](skills/user-behavior-qa/SKILL.md) | Asked for QA, a smoke test or to "click through it like a user": tests the running app only through its visible browser UI and reports what works, what's broken and what went untested. |

## Adding a skill

Each skill lives in its own folder, `skills/<name>/SKILL.md`, with `name` (matching the folder) and `description` in its frontmatter. Supporting files sit next to `SKILL.md` in the same folder. Add a row to the table above.
