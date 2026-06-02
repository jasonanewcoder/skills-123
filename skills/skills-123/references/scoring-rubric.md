# Scoring Rubric — Detailed Methodology

## Overview

The skills-123 scoring system evaluates candidate skills on **5 dimensions** producing a **0-100 total score**. Scores below 30 are filtered out. Any skill with critical security issues is automatically disqualified.

## Dimension 1: Community Signal (0-15 points)

Measures community adoption and validation.

```
score = min(15, log₁₀(stars + 1) × 5)
```

| Stars | Score | Interpretation |
|-------|-------|---------------|
| 0 | 0.0 | No community validation |
| 1 | 1.5 | Minimal validation |
| 10 | 5.2 | Some community interest |
| 50 | 8.5 | Moderate adoption |
| 100 | 10.0 | Well-adopted |
| 500 | 13.5 | Highly popular |
| 1000+ | 15.0 | Maximum community signal |

**Rationale:** Logarithmic scale prevents star count from dominating. A skill with 100 stars is meaningfully better than one with 10, but a skill with 5000 stars isn't meaningfully better than one with 1000.

**Fallback:** If star count is unavailable (e.g., from a registry without GitHub data), assign 3 (neutral).

## Dimension 2: Recency (0-10 points)

Measures how recently the skill was updated.

| Last Update | Score | Rationale |
|-------------|-------|-----------|
| ≤ 3 months | 10 | Actively maintained |
| ≤ 6 months | 7 | Recently maintained |
| ≤ 1 year | 4 | Possibly maintained |
| > 1 year | 1 | Likely abandoned |
| Unknown | 3 | Neutral — could be stable or abandoned |

**Special consideration:** Some skills are "complete" and don't need updates (e.g., a skill for a stable API). If the skill has high stars AND the underlying technology is stable, cap recency penalty at 4 minimum.

## Dimension 3: Author Trust (0-15 points)

Measures the credibility of the skill's author.

| Criterion | Points |
|-----------|--------|
| GitHub verified organization | +5 |
| Known publisher in Claude Code ecosystem | +5 |
| 5+ contributors on the repo | +5 |

**Trusted Organizations:**
anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs, supabase, railwayapp, netlify, temporalio, prisma

**Known Community Publishers:**
daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock, anombyte93, robertguss

**Special cases:**
- Official Anthropic repos (e.g., anthropics/skills, anthropics/claude-plugins-official): automatic 15
- Repos with no identifiable author: 0
- New authors with high-quality README: give +2 bonus (manual assessment)

## Dimension 4: Description Relevance (0-30 points)

Measures how well the skill matches the user's specific need.

```
keywords = extract_keywords(user_query)  # typically 2-4 keywords
matches = count_keyword_matches(keywords, skill.name + " " + skill.description)
score = (matches / total_keywords) × 30
```

**Matching rules:**
- **Exact match** (keyword appears verbatim): counts as 1.0
- **Synonym match** (recognized equivalent): counts as 0.5
  - k8s ↔ kubernetes
  - db ↔ database
  - cicd ↔ ci/cd ↔ continuous integration
  - auth ↔ authentication
  - FE ↔ frontend
  - BE ↔ backend
  - ML ↔ machine learning
- **Hyphen/underscore variant** (keyword matches when hyphens/underscores replaced with spaces): counts as 0.5
- **Substring match** (keyword is part of a longer word): counts as 0.3

**Edge cases:**
- If no keywords extracted: assign 15 (neutral)
- If description is empty: assign max(5, community_score/3) (use other signals)

## Dimension 5: Security Signal (0-20 points)

Measures the safety of the skill based on content scanning.

| Status | Score | Condition |
|--------|-------|-----------|
| Clean | 20 | No warnings, no critical patterns |
| Minor flags | 10 | 1-2 warning patterns detected |
| Needs review | 5 | 3+ warning patterns detected |
| **Disqualified** | **AUTO-REJECT** | Any critical pattern detected |

**Critical patterns** (see `safety-patterns.md` for full catalog):
- Piped shell execution (`curl ... | sh`, `wget ... | bash`)
- Dynamic code evaluation (`eval $`, `exec($`)
- Obfuscated payloads (base64 decode piped to execution)
- Destructive operations (`rm -rf /`, `rm -rf ~`)
- Reverse shells (`/dev/tcp/`, `nc -lvp`)
- Credential theft (`curl ... .env`, `curl ... .aws`)

**Warning patterns:**
- Any network request (`curl`, `wget`)
- Package installation (`pip install`, `npm install -g`)
- Privilege escalation (`sudo`)
- Permission changes (`chmod`, `chown`)
- Code evaluation (`eval`, `exec`)
- Sensitive file access (`.env`, `credentials`, `.ssh/`, `.aws/`)

## Total Score Calculation

```
total = community + recency + author_trust + relevance + security

if security == AUTO_REJECT:
    disqualified = true
    total = -1

result = max(0, min(100, total))
```

## Filtering Thresholds

| Total Score | Action |
|-------------|--------|
| ≥ 80 | Strongly recommend (highlight as 🥇) |
| 60-79 | Recommend with confidence |
| 40-59 | Present with caveat notes |
| 30-39 | Present only if nothing better available |
| < 30 | Filter out (don't show) |
| < 0 (disqualified) | Never show |

## Worked Examples

### Example 1: High-quality skill
```
Skill: apollo-graphql-setup
Stars: 1,200 → community = min(15, log10(1201) × 5) = min(15, 15.4) = 15
Updated: 2 weeks ago → recency = 10
Author: vercel-labs (trusted org) → author_trust = 5 + 5 + 0 = 10
Query: "graphql apollo server setup" → 4/4 keywords match → relevance = 30
Security: clean → 20
Total: 15 + 10 + 10 + 30 + 20 = 85 ✅ Strongly recommend
```

### Example 2: Mediocre skill
```
Skill: random-k8s-helper
Stars: 23 → community = log10(24) × 5 = 6.9
Updated: 8 months ago → recency = 4
Author: unknown-developer (individual, 1 contributor) → author_trust = 0
Query: "kubernetes deployment" → 1.5/2 keywords → relevance = 22.5
Security: 2 warnings → 10
Total: 6.9 + 4 + 0 + 22.5 + 10 = 43.4 ⚠️ Present with caveats
```

### Example 3: Dangerous skill (disqualified)
```
Skill: super-installer
Stars: 50 → community = log10(51) × 5 = 8.5
Updated: 1 month ago → recency = 10
Author: new-user-2026 → author_trust = 0
Query: "auto install tools" → 2/3 keywords → relevance = 20
Security: CRITICAL (curl | bash) → DISQUALIFIED
Total: -1 🚫 Never show
```

## Periodic Review

The scoring weights and trusted lists should be reviewed quarterly:
- Add new trusted orgs as the ecosystem grows
- Adjust recency thresholds if skill lifecycle patterns change
- Update warning pattern catalog as new attack vectors emerge
