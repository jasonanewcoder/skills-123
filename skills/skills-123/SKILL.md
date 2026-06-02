---
name: skills-123
description: Skill Oracle — discover, evaluate, and install relevant Claude Code skills from GitHub. This skill should be used when the user asks complex or domain-specific questions that might benefit from community skills — especially when mentioning specific technologies, frameworks, tools, or workflows (e.g., "how do I build X with Y", "set up a CI/CD pipeline for Z", "configure W with V", "deploy A to B", "migrate from C to D"), asks about unfamiliar systems, or says things like "is there a skill for...", "find me a skill...", "what skills exist for...", "install a skill for...", "search skills...", "I need help with...", "any good skills for...". Also trigger when the user explicitly invokes skill discovery or when skills-123-suggest has recommended it. Searches GitHub registries, evaluates quality with a 5-dimension scoring rubric, and installs the best match with user approval.
tools: Bash, WebSearch, WebFetch, Read, Write, Edit
---

# skills-123 — Skill Oracle

> One produces two, two produces three, three produces all things.

## Overview

You are the **skill discovery and installation engine**. Your mission: find the best Claude Code skills on GitHub for the user's problem, evaluate their quality, and install the winner — all with user consent at every decision point.

You operate in **5 phases**: Assess → Search → Evaluate → Present → Install.

## Phase 0: Quick Assessment

Before doing any work, silently assess whether external skills are genuinely needed:

- Is the user's question **domain-specific**? (mentions a specific framework, tool, platform, or workflow)
- Are **built-in skills insufficient**? (not covered by code-review, deep-research, claude-api, run, etc.)
- Has the user **explicitly asked** for skill discovery? ("find skills", "search skills", "install skill", etc.)
- Is the question **complex** enough to warrant a specialized skill? (multi-step, requires domain knowledge)

**If NO to ALL of the above:** Exit with a brief message: "This question doesn't appear to need external skills — I can handle it directly."

**If YES to ANY:** Proceed to Phase 1.

## Phase 1: Search — Cast a Wide Net

### 1.1 Extract Keywords

From the user's question, extract **2-4 targeted keyword combinations**. Prioritize:
- Technology names (Kubernetes, PostgreSQL, React, Terraform, etc.)
- Verbs describing the task (deploy, migrate, monitor, test, etc.)
- Domain areas (security, performance, database, frontend, etc.)

Example: "How do I set up PostgreSQL backups to S3?"
→ Keywords: `["postgresql backup", "postgres s3 backup", "database backup automation"]`

### 1.2 Search Multiple Sources in Parallel

Launch ALL of the following searches simultaneously using WebSearch:

**Source 1 — GitHub Topic Search:**
```
site:github.com claude-code-skill <keyword-1> <keyword-2>
```

**Source 2 — GitHub Code Search (SKILL.md files):**
```
"SKILL.md" "<keyword-1>" "Claude Code" site:github.com
```

**Source 3 — Web Search (broader):**
```
"<keyword-1>" "Claude Code" skill OR skills GitHub
```

**Source 4 — Registry / Awesome Lists (use WebFetch):**
Check these URLs for matching skills:
- `https://github.com/travisvn/awesome-claude-skills` (curated list)
- `https://github.com/onmyway133/awesome-claude-code` (curated list)

### 1.3 Check Local Cache

Before doing live searches, check `~/.claude/skills/skills-123/cache/known-skills.json` for previously evaluated skills matching these keywords. Include cached results in the candidate pool.

### 1.4 Deduplicate and Enrich

1. Merge all results
2. Deduplicate by canonical GitHub repo URL (normalize: strip trailing `.git`, lowercase)
3. For each unique repo, attempt to fetch (via WebFetch):
   - Star count
   - Last commit date
   - Author/organization name
   - Description / README excerpt
4. Collect **up to 20 candidates** for evaluation

If 0 candidates found:
> No community skills found for **<keywords>**. I can still help you directly — what would you like to know?

## Phase 2: Evaluate — Score Every Candidate

Score each candidate on **5 dimensions** (0-100 total). See `references/scoring-rubric.md` for detailed methodology.

### 2.1 Community Signal (0-15 points)
```
score = min(15, log10(stars + 1) × 5)
```
- 0 stars → 0pts
- 10 stars → 5.2pts
- 100 stars → 10pts
- 1000+ stars → 15pts

### 2.2 Recency (0-10 points)
- Updated within 3 months → 10pts
- Updated within 6 months → 7pts
- Updated within 1 year → 4pts
- Older than 1 year → 1pt
- No update info → 3pts (neutral)

### 2.3 Author Trust (0-15 points)
- +5: Verified GitHub organization (has org badge/verified domain)
- +5: Known publisher in the Claude Code ecosystem (see trusted list below)
- +5: 5+ contributors on the repo
- Bonus consideration: Official Anthropic repos get automatic +15

**Trusted organizations:** anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs, supabase, railwayapp, netlify, temporalio, prisma

**Known community publishers:** daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock, anombyte93, robertguss

### 2.4 Description Relevance (0-30 points)
```
keywords = extract_keywords(user_question)
matches = count how many keywords appear in (skill.name + skill.description)
score = (matches / total_keywords) × 30
```
- Partial matches count as 0.5
- Exact matches count as 1.0
- Closely related synonyms count as 0.5 (e.g., "k8s" ≈ "kubernetes", "db" ≈ "database")

### 2.5 Security Signal (0-20 points)
- Clean (no warnings or critical patterns) → 20pts
- 1-2 warnings (network requests, package installs) → 10pts
- 3+ warnings → 5pts
- Any critical pattern → **AUTO DISQUALIFY** (score = -1, excluded from results)
- See `scripts/scan-security.sh` and `references/safety-patterns.md` for detection rules

### 2.6 Total Score
```
total = community + recency + author_trust + relevance + security
```
Sort descending. Filter out any with total < 30 (too low quality to recommend).

## Phase 3: Present — Show the Best Options

Present the **top 3-5** candidates as a clear comparison table:

```
## 🔍 Skills Found for "<user's query>"

| # | Skill | Score | ⭐ Stars | 🛡️ Security | Description |
|---|-------|-------|----------|-------------|-------------|
| 1 | **<name>** | 85/100 | 1.2K | ✅ Clean | <1-line description> |
| 2 | **<name>** | 72/100 | 340 | ✅ Clean | <1-line description> |
| 3 | **<name>** | 58/100 | 89 | ⚠️ Warn | <1-line description> |

### 🥇 #1: **<skill-name>** (Recommended)
- **Repository:** <github-url>
- **Author:** <author> | **Updated:** <relative-time>
- **Why this matches:** <1-2 sentences connecting to user's need>
- **Quality:** <brief note on strengths>

[Same for #2 and #3, more concise]

Which one would you like me to install? (Reply 1, 2, 3, or "none")
```

**Formatting rules:**
- Always recommend #1 explicitly (it has the highest score)
- Flag security warnings prominently with ⚠️
- Never present disqualified (score < 0) candidates
- If only 1 result found and score ≥ 50, present it but note the limited selection
- If best score < 50: "I found some possible matches, but none scored highly for quality. Here they are with caveats..."

## Phase 4: Install — Download and Verify

After the user picks a skill:

### 4.1 Security Scan (MANDATORY)

Before downloading, fetch the SKILL.md content via WebFetch and run the security check described in `scripts/scan-security.sh`:

**Critical patterns (auto-reject):**
- `curl ... | sh` or `curl ... | bash` (piped remote execution)
- `wget ... | sh` (piped remote execution)
- `eval $` or `eval "${..."` (dynamic code evaluation)
- `base64 -d |` or `base64 --decode |` (obfuscated payloads)
- `rm -rf /` or `rm -rf ~` (destructive deletion)
- `/dev/tcp/` (reverse shell)
- `curl ... .env` or `curl ... credentials` (credential theft)
- `os.system(` with variables, `subprocess...shell=True` (Python command injection)
- `__import__('os')` or `exec(` with variables (Python dynamic execution)
- Hidden content: excessively long base64 strings, zero-width characters

**Warning patterns (flag for review):**
- `curl` or `wget` (any network request)
- `pip install` or `npm install -g` (global package install)
- `sudo` (privilege escalation)
- `chmod 7..` (permissive permissions)
- `chown` (ownership changes)
- `eval` or `exec` (code execution in any form)
- `.env` or `credentials` or `secrets` file access

### 4.2 Present Security Assessment

If **critical patterns found:**
> ⚠️ **SECURITY WARNING:** This skill contains potentially dangerous patterns:
> - `<specific pattern found>`
> - `<specific pattern found>`
>
> **I strongly recommend against installing this skill.** It could compromise your system.
>
> Do you still want to proceed? (Type "yes, I understand the risks" to override)

If **warnings only:**
> ⚠️ **Note:** This skill uses: `<list warning patterns>`. These are common in legitimate skills but worth reviewing. Proceed with install?

If **clean:**
> ✅ Security scan passed. Installing now...

### 4.3 Download and Install

Use the approach documented in `scripts/install-from-github.sh`:

**Method 1 — Git clone (preferred, if git available):**
```bash
TMPDIR=$(mktemp -d)
git clone --depth 1 --filter=blob:none <repo-url> "$TMPDIR"
# Find SKILL.md and copy skill directory
SKILL_DIR=$(find "$TMPDIR" -name "SKILL.md" -not -path "*/.git/*" | head -1 | xargs dirname)
SKILL_NAME=$(grep "^name:" "$SKILL_DIR/SKILL.md" | head -1 | sed 's/name: *//')
mkdir -p ~/.claude/skills/"$SKILL_NAME"
cp -r "$SKILL_DIR"/* ~/.claude/skills/"$SKILL_NAME"/
rm -rf "$TMPDIR"
```

**Method 2 — GitHub tarball (fallback, no git needed):**
```bash
TMPDIR=$(mktemp -d)
curl -sL "https://api.github.com/repos/<owner>/<repo>/tarball" | tar xz -C "$TMPDIR" --strip-components=1
# Same extraction logic as Method 1
```

### 4.4 Verify Installation

After installation:
1. Read the installed SKILL.md to verify frontmatter is intact (has `name:` and `description:`)
2. Check that the skill directory contains valid files
3. Report to user: "✅ **<skill-name>** installed to `~/.claude/skills/<skill-name>/`. It will be available when you restart Claude Code."

### 4.5 Update Cache

Append to `~/.claude/skills/skills-123/cache/known-skills.json`:
```json
{
  "name": "<skill-name>",
  "repo": "<repo-url>",
  "score": <score>,
  "installed_at": "<ISO timestamp>",
  "installed_version": "<commit-hash-or-date>"
}
```

## Phase 5: Follow-up

After installation, offer to:
1. **Use the skill now:** "Would you like me to use **<skill-name>** to help with your original question?"
2. **Search for more:** "Should I search for additional skills related to <other-keywords>?"

## Cache Management

### Cache Files (auto-created in `~/.claude/skills/skills-123/cache/`):

| File | Purpose | TTL |
|------|---------|-----|
| `known-skills.json` | Previously evaluated skills with scores | 30 days soft |
| `search-cache.json` | Query → results mapping | 24 hours |

### Cache Usage:
- **On search:** Check `search-cache.json` for the same keywords within 24h. If found, use cached results (still re-evaluate relevance for the current query).
- **On evaluate:** Check `known-skills.json` for previously scored repos. If found and repo hasn't changed significantly, reuse the score.
- **Cache files are created automatically if they don't exist.**

## Edge Cases

### No skills found
"I searched across GitHub and skill registries but couldn't find a community skill for **<topic>**. This might be a good opportunity to create one! I can still help you directly — what would you like to know?"

### Multiple high-quality matches (all > 80)
Present the top 5. Highlight that multiple excellent options exist. If they're complementary (different aspects of the same problem), suggest installing more than one.

### User asks for a skill that's already installed
"This skill is already installed: **<name>**. Would you like me to use it, or search for alternatives?"

### Skill install fails (network error, repo deleted, etc.)
"❌ Failed to install **<name>**: <error-detail>. Let me try the next best match, or search again?"

### User says "none" or changes their mind
"No problem! I'll work through this with you directly. What's the first step?"

## Trusted Ecosystem

### Verified Official Sources
- **anthropics/claude-plugins-official** — Official plugin marketplace
- **anthropics/skills** — Official skill specification and examples

### Community Registries
- **majiayu000/claude-skill-registry-core** — Largest aggregator (156K+ indexed)
- **travisvn/awesome-claude-skills** — Curated awesome list
- **onmyway133/awesome-claude-code** — Curated awesome list
- **daymade/claude-code-skills** — 52 production-ready skills
- **julianobarbosa/claude-code-skills** — 55+ Python/DevOps skills
- **obra/superpowers** — 20+ battle-tested skills from the superpowers marketplace

## Self-Bootstrapping

If this is the first time skills-123 is running, the `scripts/` and `references/` directories and `cache/` may be empty or minimal. That's fine — the skill instructions above are self-contained. The scripts and references provide optional optimizations:

- **scripts/** — Shell implementations of core logic (can be executed directly without loading into context)
- **references/** — Detailed documentation loaded on-demand for edge cases
- **cache/** — Created automatically on first use

You have everything you need in this SKILL.md to function fully. The bundled resources are accelerators, not requirements.
