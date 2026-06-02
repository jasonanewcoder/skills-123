# Proxy Injection Guide

Detailed methodology for the "inject" step of Proxy Mode.

## Domain Keyword Mapping

When extracting keywords from user prompts, think in terms of what the user wants to accomplish, not what technologies they name:

| User says | Extract domain keywords |
|-----------|------------------------|
| "帮我写一个酷炫的dashboard网页" | `dashboard web ui visualization` |
| "写一个html的ppt介绍AI+CAE" | `presentation slides html ppt AI CAE simulation` |
| "Build a real estate project tracker" | `dashboard project tracker real estate` |
| "Set up a CI/CD pipeline" | `CI/CD pipeline deployment automation` |
| "做个房产项目进度看板" | `dashboard project management real estate` |
| "Kubernetesのデプロイを設定して" | `kubernetes deployment orchestration` |
| "Crea un panel de control inmobiliario" | `dashboard real estate panel UI` |
| "대시보드 만들어 줘" | `dashboard web visualization` |
| "How to optimize PostgreSQL queries" | `postgresql performance optimization database` |

## Extraction Priorities

When reading a SKILL.md, prioritize extracting:

1. **Code templates / scaffolding** — anything the user can use immediately
2. **Design patterns / architecture** — structural decisions, not just syntax
3. **Domain best practices** — "in this domain, do X, avoid Y"
4. **Library/tool recommendations** — "use X for Y" with rationale
5. **Clarifying questions** — if the skill says "before building, ask about X"

## Merging Multiple Skills

If 2-3 skills are found, merge complementary knowledge:
- Skill A has design patterns → use those
- Skill B has code templates → use those
- Skill C has domain best practices → use those

If skills conflict, prefer the one with higher stars / more recent updates.

## Size Limits

- SKILL.md > 500 lines: take overview + patterns + templates. Skip tool listings, edge cases, meta-docs.
- Multiple >500 line skills: use only the best 2, extract 5 principles each max.
- If extraction yields < 3 actionable items: the skill is too thin, skip it.

## Anti-Slop Detection

Community skills that teach design patterns to avoid generic AI aesthetics are high-priority:
- Design system skills (color palettes, typography choices)
- Frontend skills that explicitly reject "Inter font + purple gradient" patterns
- Architecture skills that promote distinctive structures over generic card grids
