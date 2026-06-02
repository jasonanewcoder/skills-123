# skills-123 on Aider

## Overview

[Aider](https://github.com/Aider-AI/aider) is an AI pair programming tool for the terminal. It doesn't natively support SKILL.md files, but it reads convention files and can use them as persistent instructions. skills-123 needs to be adapted into Aider's convention format.

## Prerequisites

- [Aider](https://github.com/Aider-AI/aider) installed (`pip install aider-chat` or `brew install aider`)
- An AI provider API key configured

## Installation

Aider reads from `CONVENTIONS.md` or files specified with `--read`. There's no directory-based skill structure.

### Method 1: Conventions file (recommended)

Create `~/.aider/skills-123.md`:

```bash
mkdir -p ~/.aider
```

Then copy the adapted skill content (see below) into `~/.aider/skills-123.md`.

### Method 2: Launch Aider with the skill loaded

```bash
aider --read ~/workspace/skills-123/skills/skills-123/SKILL.md
```

### Adapted content for `~/.aider/skills-123.md`

```markdown
# Skills-123: Skill Discovery System

## Capability
You have the ability to discover and install community AI agent skills from GitHub.
When the user asks complex or domain-specific questions, you can search for relevant
skills, evaluate their quality, and recommend the best match.

## When to Use
- User asks a complex question about a specific technology, framework, or tool
- User says "find me a skill for...", "search skills...", "any good skills for..."
- User describes a workflow that might have pre-built skill solutions

## Search Process
1. Search GitHub for relevant skills:
   - "site:github.com claude-code-skill <keywords>"
   - "SKILL.md <keywords> site:github.com"
2. Check community registries and awesome lists
3. Deduplicate and enrich results with metadata

## Quality Evaluation (5 dimensions, 0-100)
- Community Signal (0-15): log10(stars+1) × 5
- Recency (0-10): ≤3mo=10, ≤6mo=7, ≤1y=4, older=1
- Author Trust (0-15): verified orgs, known publishers, contributor count
- Relevance (0-30): keyword match ratio × 30
- Security (0-20): clean=20, warnings=10, critical=disqualified

## Safety Rules
- NEVER recommend a skill without review
- Auto-reject: `curl | sh`, `eval $`, base64-to-pipe, `rm -rf /`, `/dev/tcp/`
- Flag: network requests, sudo, global package installs

## Trusted Orgs
anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs,
supabase, railwayapp, netlify

## Known Publishers
daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock
```

## Usage

Launch Aider with the skill file:

```bash
aider --read ~/.aider/skills-123.md
```

Then in the Aider chat:

```
"Find me skills for Kubernetes deployment"
"Search for Python testing skills on GitHub"
```

Or add it to your `.aider.conf.yml` for automatic loading:

```yaml
# .aider.conf.yml
read:
  - ~/.aider/skills-123.md
```

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ❌ — plain markdown only |
| Directory-based structure | ❌ — flat file only |
| Auto-trigger | ❌ — must be loaded with `--read` |
| Shell scripts | ⚠️ — Aider has `/run` command for shell |
| skills-123-suggest passive mode | ❌ — no hook/background system |
| WebSearch tool | ⚠️ — Aider doesn't have built-in web search |
| Caching | ❌ — no persistent cache between sessions |

**Key caveats:**
- **No built-in web search** — Aider cannot directly search the web. The skill discovery instructions will guide Aider's reasoning, but actual GitHub searches would need to be done outside Aider or via the `/web` command if available.
- **Flat format** — Aider's `CONVENTIONS.md` is plain markdown. The rich directory structure of skills-123 (scripts, references) is reduced to a single text block.
- **Manual loading** — You must explicitly load the skill file with `--read` or in your config. It won't auto-discover.
- **Best used as a reference** — skills-123 in Aider serves more as a mental checklist for the model than a fully automated pipeline. For the full experience, use Claude Code.

## Alternative: Use Aider with Claude API

If Aider is configured to use the Claude API as its backend, the skill instructions will be followed more reliably than with other models, since Claude has been specifically trained on the Agent Skills format.
