# skills-123 — The Skill Proxy

> One produces two, two produces three, three produces all things.

## What this project does

skills-123 is a meta-skill: it discovers community Claude Code skills on GitHub, fetches their knowledge, and injects it into context — so users get better output without installing anything.

## How you should behave in this project

### Core rule: Proactively use skills-123 for tasks

When a user asks to **accomplish something with a deliverable** — building, creating, writing, setting up, deploying, designing — invoke `/skills-123` (or `skills-123-suggest` for a lighter check). Judge by **semantic intent** in any language, not trigger words.

### How skills-123 works

- **Proxy mode (default):** Search GitHub → fetch SKILL.md with fallback chain → quality gate → structured inject → complete task → record usage. No installation.
- **Install mode:** Full evaluate + user selection + security scan + git clone. Only on explicit request.

### Project structure

- `skills/skills-123/SKILL.md` — Core skill (~150 lines, self-contained)
- `skills/skills-123/references/` — Scoring rubric, safety patterns, injection guide (loaded on-demand)
- `skills/skills-123/scripts/` — Shell utilities for search, evaluate, install
- `skills/skills-123-suggest/SKILL.md` — Lightweight passive scout
- `example/` — Before/after comparisons in 5 languages
- `install.sh` — One-command installer
