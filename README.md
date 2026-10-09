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

| Skill | What it does |
| --- | --- |
| [`cleanup`](skills/cleanup/SKILL.md) | Shrink a branch's diff without changing behaviour |
| [`user-behavior-qa`](skills/user-behavior-qa/SKILL.md) | QA the running app through its browser UI, like a real user |

## Adding a skill

Each skill lives in its own folder, `skills/<name>/SKILL.md`, with `name` (matching the folder) and `description` in its frontmatter. Supporting files sit next to `SKILL.md` in the same folder. Add a row to the table above.
