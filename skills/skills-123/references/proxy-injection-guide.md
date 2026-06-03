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

## Degraded Mode Injection

When all fetch tiers (WebFetch, local curl, API recursive tree) have been exhausted and only search-result snippets, README content, or legacy-format .md files are available, use the degraded injection template.

### When Degraded Mode Activates

1. The repo has no SKILL.md file (old slash-command format or non-skill repo)
2. All fetch URLs return errors (network issues, rate limits, private repos, blocked domains)
3. Only search snippets from WebSearch are available
4. Content came from `fetch-local.sh` tagged with `"format":"legacy"`
5. Content length is < 200 characters (search snippet, not full skill)

### Degraded Template Format

Always use this exact structure to distinguish from full-skill injection:

```
⚠️ Augmented with partial community patterns from search results (limited quality)

**Domain patterns observed (apply with caution):**
1. <observed pattern/convention> — inferred from search context, not a verified skill
2. <common approach or library> — appears across multiple search results
3. <naming convention or structure> — community preference based on available snippets

> This task used degraded-mode knowledge. For higher-quality results, ask me to install a relevant skill for this domain.
```

### Extracting Value from Snippets

Search snippets are typically 100-300 characters. Extract domain patterns from them:

- **Naming conventions**: How the community names things in this domain (e.g., "use kebab-case for Kubernetes resources")
- **Tool mentions**: Libraries, frameworks, or CLIs that appear across multiple results
- **Structural patterns**: Common file layouts, config formats, or project structures implied by repo structures
- **Gotchas**: Warnings or common mistakes mentioned in snippet descriptions

### Quality Signaling

The "⚠️" prefix and "(limited quality)" label serve a dual purpose:
1. **Honesty**: The user knows this isn't a full, verified skill — patterns are inferred, not authoritative
2. **Upsell**: The offer to install a relevant skill converts a degraded experience into a path to higher quality

Never use the full-skill template ("💡 Enhanced with community knowledge from...") for degraded content. The templates must remain visually distinct so users learn to recognize quality tiers at a glance.

### Edge Cases

- **Search found 0 results**: Don't use any injection template. Proceed with the task directly.
- **All candidates fail the degraded gate (< 50 chars)**: Skip injection entirely. Proceed directly.
- **Multiple degraded snippets from different repos**: Merge their patterns under a single degraded template. Don't stack multiple ⚠️ banners.
