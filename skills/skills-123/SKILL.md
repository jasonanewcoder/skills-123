---
name: skills-123
description: "Skill Oracle — discover, evaluate, and use community Claude Code skills from GitHub to improve the quality of any task. Invoke this skill whenever the user asks to accomplish something concrete — building, creating, writing, setting up, deploying, designing, making anything with a deliverable. Works with ALL languages based on semantic intent (not trigger words): if the user wants something BUILT or CREATED or SOLVED, invoke this skill. This includes Chinese (帮我做X、写一个X、做一个X、搭建X、部署X), English (build me X, create X, write X, set up X, make X), Japanese (Xを作って、Xを構築して、Xを設定して), Korean (X 만들어 줘, X 구축해 줘, X 작성해 줘), Spanish (construye X, crea X, haz X, configura X), and any other language. The key signal is TASK INTENT — the user wants a deliverable, not just information. Proxy mode (default): search GitHub → fetch skill content → inject into context → complete task with improved quality. Install mode: full evaluation + user selection + security scan + git clone for persistent use."
tools: Bash, WebSearch, WebFetch, Read, Write, Edit
---

# skills-123 — The Skill Proxy

> One produces two, two produces three, three produces all things.

## ⚠️ Mandatory Self-Check (Read Before Anything Else)

**You are a meta-skill — a skill that discovers skills.** Your core job is to search for community knowledge before producing a deliverable. If you write code, create a file, design a UI, or output any artifact without first checking GitHub for relevant skills, **you have failed at your primary function.**

Before you output any deliverable, pause and ask yourself:

1. *"Did I search for community skills for this task?"*
2. *"Could a skill from GitHub make this better?"*

**If the answer to #1 is NO and #2 is YES → go back and search NOW, before writing a single line.**

This applies to ALL deliverables — not just code. Articles, presentations, configs, designs, scripts, documentation. If the user asked you to produce something, search first.

---

## Mode Selection

```
User prompt →
  ├─ "install skill" / "find skills" / "search skill" → Install Mode
  ├─ "--check" / "verify skills-123" / "test skills-123" → Self-Check Mode
  ├─ Concrete task? (build/create/write/setup/deploy/design + deliverable) → Proxy Mode
  └─ Pure chat / trivia / already handled by built-in skill → skip
```

---

## Self-Check Mode (--check)

When the user asks to verify skills-123 is working ("--check", "verify skills-123 works", "test the skill"):

1. Run a test search: `"dashboard" "Claude Code" skill GitHub`
2. Test WebFetch: fetch one `raw.githubusercontent.com` URL
3. Test local connectivity: `bash ~/.claude/skills/skills-123/scripts/fetch-local.sh check`
4. Report: number of results found, WebFetch status, local-curl status, cache files present, skip-list entries
5. If all checks pass: "✅ skills-123 is operational. [N] skills in cache. WebFetch: OK. Local curl: [all_ok|degraded]."
6. If WebFetch fails but local curl OK: "⚠️ WebFetch unreachable (claude.ai proxy issue). Local curl is available — I'll use it as fallback."
7. If both fail: "❌ skills-123 offline. Both WebFetch and local curl are unreachable. Check your network."

---

## Proxy Mode (DEFAULT)

Proxy mode fetches community skill knowledge from GitHub and injects it into context. The user just gets a better result — no install, no extra steps.

### Step 1: Detect Task Intent

If the user wants a **deliverable** (webpage, script, config, dashboard, report, setup…) → proceed. Don't require specific technology names. "Make a dashboard" triggers just like "Deploy a Kubernetes cluster."

### Step 2: Search (2-3 parallel queries, with local fallback)

Extract the task **domain** (what they want, not what they named):

**Primary (WebSearch):**
```
Query 1: "<domain keywords>" "Claude Code" skill GitHub
Query 2: "<domain keywords>" SKILL.md Claude site:github.com
Query 3: <alternative angle>
```

Also check: `https://github.com/travisvn/awesome-claude-skills` for matching entries.

**⚠️ Local fallback — if WebSearch fails or returns nothing:**
```
# GitHub repo search (no auth needed):
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh search "<domain keywords>"

# DuckDuckGo web search (automatically falls back to Bing if DDG blocked):
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh ddg "<domain keywords> Claude Code skill"

# Awesome-lists:
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh awesome
```
This bypasses claude.ai's proxy entirely and uses your machine's network. Requires `curl` and `python3`.

> **China / restricted networks:** The script respects `CHINA_MODE=1` env var which enables GitHub mirror chains (ghproxy.com etc.) for raw.githubusercontent.com and api.github.com, and switches search to Bing. Also respects `https_proxy` / `all_proxy` for custom proxies. See `references/china-network.md` for detailed setup.

Collect up to 10 candidate repo URLs. **If 0 → exit silently, handle directly.**

### Step 3: Fetch with Fallback (each candidate, stop when content obtained)

For the top 3-5 candidates, try to get their SKILL.md content. **Must use a fallback chain — one failure doesn't block the flow.**

#### Layer A: WebFetch (goes through claude.ai proxy — try first)

| Tier | Source | URL Pattern |
|:----:|--------|-------------|
| 1 | Raw GitHub (preferred) | `https://raw.githubusercontent.com/<owner>/<repo>/HEAD/SKILL.md` |
| 2 | Raw GitHub (main) | `https://raw.githubusercontent.com/<owner>/<repo>/main/SKILL.md` |
| 3 | GitHub API | `https://api.github.com/repos/<owner>/<repo>/contents/SKILL.md` (decode base64 `content` field) |

Try Tier 1 → 2 → 3 in order. If any succeeds, skip straight to quality gate.

#### Layer B: Local curl (BYPASSES claude.ai proxy — mandatory when WebFetch fails)

**If ALL WebFetch tiers fail for a candidate, do NOT skip it. Immediately retry with local curl:**

```
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh skill <owner/repo>
```

This single command tries raw→api→recursive-tree via your machine's local network. If it returns `"ok":true`, use the content exactly as if WebFetch had succeeded — feed it through the same quality gate (Step 4), same injection template (Step 5).

**Layer B is not optional.** When WebFetch fails, local curl is the next tier, not degraded mode. WebFetch failures are often claude.ai proxy issues — the target server is reachable from your machine.

#### Layer C: Degraded (last resort, only when Layer B also fails)

Use search result snippets, repo description, and README as partial knowledge.

```
Fallback order (per candidate):
  WebFetch Tier 1 → 2 → 3 → Local curl (Bash) → Degraded
```

**Never announce failures or tier switches. Just get the content and move on.**

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

**Negative feedback loop:** If the user indicates the result was poor ("that didn't help", "not what I wanted", etc.), record the skill to `~/.claude/skills/skills-123/cache/skip-list.json`:
```json
{"skill": "<name>", "repo": "<url>", "reason": "<brief>", "skipped_at": "<ISO timestamp>"}
```
Skills in the skip-list are excluded from future Proxy searches. Check this file during Step 2 (Search) and filter out any matches.

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

**Search sources:** GitHub topic search, code search, web search, awesome-lists (travisvn, onmyway133). Local fallback via `scripts/fetch-local.sh` — bypasses claude.ai proxy.

**Trusted orgs:** anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs, supabase, railwayapp, netlify, temporalio, prisma.

**Known publishers:** daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock, anombyte93, robertguss.

**Registries:** majiayu000/claude-skill-registry-core, travisvn/awesome-claude-skills, onmyway133/awesome-claude-code, daymade/claude-code-skills, obra/superpowers.

**Cache files** (auto-created in `~/.claude/skills/skills-123/cache/`):
- `proxy-usage.json` — skills used in Proxy mode, boosts future searches
- `known-skills.json` — evaluated skills (Install mode), 30-day TTL
- `search-cache.json` — query→results mapping, 24-hour TTL

**Edge cases:** Fetch fails → fallback. Skill too large → extract overview + patterns only. Multiple good skills → merge top 2-3 (prefer complementary). Already installed → mention and ask if user wants alternatives.

### 🌐 China / Restricted Networks

If you're in mainland China or behind a restrictive firewall, set these env vars before invoking skills-123:

```bash
export CHINA_MODE=1                          # enables mirror chain + Bing search
export GITHUB_TOKEN="ghp_xxx"                # optional: higher API rate limits
export https_proxy="http://127.0.0.1:7890"   # optional: local proxy (Clash/V2Ray)
```

**What CHINA_MODE=1 does:**
- `raw.githubusercontent.com` → tries `raw.ghproxy.com` → `raw.mghproxy.com` → `ghproxy.com` prefix proxy
- `api.github.com` → tries `gh.api.99988866.xyz` → `ghproxy.com` prefix proxy
- Search: prefers Bing (`cn.bing.com`) over DuckDuckGo (blocked in China)
- `git clone` / tarball download: prepends `https://ghproxy.com/` when direct fails

**Custom mirrors:** You can override individual mirror targets:
```bash
export SKILLS_MIRROR_RAW="raw.ghproxy.com"     # raw.githubusercontent.com replacement
export SKILLS_MIRROR_API="gh.api.99988866.xyz" # api.github.com replacement
export SKILLS_MIRROR_GIT="https://ghproxy.com/" # git clone prefix
export SKILLS_SEARCH_BING=1                     # use Bing instead of DDG
```

**Verify connectivity:**
```bash
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh check
```

> See `references/china-network.md` for detailed setup guide, recommended mirrors, and troubleshooting.

> Detailed procedures live in `references/` and `scripts/`. This SKILL.md is self-contained for core operation — the bundled files are accelerators, not requirements.
