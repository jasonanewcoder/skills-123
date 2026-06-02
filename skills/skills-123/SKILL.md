---
name: skills-123
description: Skill Oracle — discover, evaluate, and use community Claude Code skills from GitHub to improve the quality of any task. Invoke this skill whenever the user asks to accomplish something concrete — building, creating, writing, setting up, deploying, designing, making anything with a deliverable. Works with ALL languages based on semantic intent (not trigger words): if the user wants something BUILT or CREATED or SOLVED, invoke this skill. This includes Chinese (帮我做X、写一个X、做一个X、搭建X、部署X), English (build me X, create X, write X, set up X, make X), Japanese (Xを作って、Xを構築して、Xを設定して), Korean (X 만들어 줘, X 구축해 줘, X 작성해 줘), Spanish (construye X, crea X, haz X, configura X), and any other language. The key signal is TASK INTENT — the user wants a deliverable, not just information. Proxy mode (default): search GitHub → fetch skill content → inject into context → complete task with improved quality. Install mode: full evaluation + user selection + security scan + git clone for persistent use.
tools: Bash, WebSearch, WebFetch, Read, Write, Edit
---

# skills-123 — The Skill Proxy

> One produces two, two produces three, three produces all things.

## Mode Selection

```
User prompt →
  ├─ "install skill" / "find skills" / "search skill" → Install Mode
  ├─ Concrete task? (build/create/write/setup/deploy/design + deliverable) → Proxy Mode
  └─ Pure chat / trivia / already handled by built-in skill → skip
```

---

## Proxy Mode (DEFAULT)

Proxy mode fetches community skill knowledge from GitHub and injects it into context. The user just gets a better result — no install, no extra steps.

### Step 1: Detect Task Intent

If the user wants a **deliverable** (webpage, script, config, dashboard, report, setup…) → proceed. Don't require specific technology names. "Make a dashboard" triggers just like "Deploy a Kubernetes cluster."

### Step 2: Search (2-3 parallel WebSearch queries)

Extract the task **domain** (what they want, not what they named):

```
Query 1: "<domain keywords>" "Claude Code" skill GitHub
Query 2: "<domain keywords>" SKILL.md Claude site:github.com
Query 3: <alternative angle>
```

Also check: `https://github.com/travisvn/awesome-claude-skills` for matching entries.
Collect up to 10 candidate repo URLs. **If 0 → exit silently, handle directly.**

### Step 3: Fetch with Fallback (try each tier, stop when content obtained)

For the top 3-5 candidates, try to get their SKILL.md content. **Must use a fallback chain — one failure doesn't block the flow:**

| Tier | Source | URL Pattern |
|:----:|--------|-------------|
| 1 | Raw GitHub (preferred) | `https://raw.githubusercontent.com/<owner>/<repo>/HEAD/SKILL.md` |
| 2 | Raw GitHub (main branch) | `https://raw.githubusercontent.com/<owner>/<repo>/main/SKILL.md` |
| 3 | GitHub API | `https://api.github.com/repos/<owner>/<repo>/contents/SKILL.md` (returns JSON with base64-encoded content — decode it) |
| 4 | Degraded (search context) | Use the search result snippet, repo description, and README as partial knowledge |

**Always try Tier 1 first. If it fails or is blocked, immediately try Tier 2, then 3. Tier 4 is always available as a degraded fallback.** Don't announce failures — just degrade gracefully.

### Step 4: Quality Gate (quick 3-check before injecting)

Before using a skill's content, verify:

1. **Has substance** — SKILL.md content > 200 characters (not just a stub)
2. **No critical patterns** — scan for `curl | sh`, `eval $`, `rm -rf /`, `/dev/tcp/`, base64-to-pipe (see Security section below for full list)
3. **Some community signal** — stars > 0, OR from a known org/publisher (anthropics, vercel-labs, daymade, travisvn, obra…)

**Fail any check → skip that skill, use the next candidate.** A bad skill is worse than no skill.

### Step 5: Inject — Structured Template

Don't dump raw SKILL.md text into context. Extract and format:

```
💡 Enhanced with community knowledge from **[skill-name]** (<repo-url>)

**Key patterns applied:**
1. <principle/pattern> — how it shaped this output
2. <principle/pattern> — how it shaped this output
3. <principle/pattern> — how it shaped this output
```

Extract **3-5 actionable items**: design patterns, code templates, best practices, library recommendations, or clarifying questions the skill suggests asking the user. Apply them while completing the task.

### Step 6: Complete Task + Record

After completing the task, offer once (optional):

> Want me to install **[skill-name]** for future use? (y/n)

Then record to `~/.claude/skills/skills-123/cache/proxy-usage.json`:
```json
{"skill": "<name>", "repo": "<url>", "domain": "<task domain>", "used_at": "<ISO timestamp>"}
```
If the file doesn't exist, create it. On future searches, boost skills that appear in this log.

---

## Install Mode (on explicit request)

Triggered by: "install skill", "find skills for X", "search skills", "install that", or user says yes to Proxy's install offer.

Full pipeline: **Search** (4 sources parallel, same as Proxy Step 2) → **Evaluate** (5-dimension score — see `references/scoring-rubric.md`) → **Present** (top 3-5 with comparison table) → **Security Scan** (critical = auto-reject) → **Install** (git clone to `~/.claude/skills/`, see `scripts/install-from-github.sh`) → **Verify + Cache**.

If 0 candidates: "No community skills found for **<topic>**. I can still help directly."

---

## Security Checklist

These patterns apply to both Proxy (quality gate) and Install (auto-reject):

**Critical — auto-reject:**
`curl | sh`, `wget | sh`, `eval $`, `eval "`, `base64 -d |`, `base64 --decode |`, `rm -rf /`, `rm -rf ~`, `/dev/tcp/`, `curl .env`, `curl credentials`, `os.system(` with variables, `subprocess.*shell=True`, `__import__('os')`, `exec(` with variables, excessively long base64 strings, zero-width characters.

**Warning — flag for review:**
`curl`, `wget`, `pip install`, `npm install -g`, `sudo`, `chmod 7..`, `chown`, `eval`, `exec`, `.env`, `credentials`, `secrets`.

> See `references/safety-patterns.md` for the full detection methodology.

---

## Quick Reference

**Search sources:** GitHub topic search, code search, web search, awesome-lists (travisvn, onmyway133).

**Trusted orgs:** anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs, supabase, railwayapp, netlify, temporalio, prisma.

**Known publishers:** daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock, anombyte93, robertguss.

**Registries:** majiayu000/claude-skill-registry-core, travisvn/awesome-claude-skills, onmyway133/awesome-claude-code, daymade/claude-code-skills, obra/superpowers.

**Cache files** (auto-created in `~/.claude/skills/skills-123/cache/`):
- `proxy-usage.json` — skills used in Proxy mode, boosts future searches
- `known-skills.json` — evaluated skills (Install mode), 30-day TTL
- `search-cache.json` — query→results mapping, 24-hour TTL

**Edge cases:** Fetch fails → fallback. Skill too large → extract overview + patterns only. Multiple good skills → merge top 2-3 (prefer complementary). Already installed → mention and ask if user wants alternatives.

> Detailed procedures live in `references/` and `scripts/`. This SKILL.md is self-contained for core operation — the bundled files are accelerators, not requirements.
