# skills-123 on Aider

## Overview

[Aider](https://aider.chat) is a terminal-based AI pair programming tool. Aider uses `CONVENTIONS.md` files and a `.aider/` directory for project-level instructions. It doesn't natively support SKILL.md, so skills-123 must be adapted into Aider's conventions format.

## Prerequisites

- [Aider](https://aider.chat/docs/install.html) installed (`pip install aider-chat` or `brew install aider`)
- An LLM API key (Anthropic, OpenAI, etc.)

## Installation

Aider reads `.aider.conf.yml` (global) and `CONVENTIONS.md` (project-level) for instructions. Skills-123 needs to be converted to Aider's format.

### Step 1: Add to project CONVENTIONS.md

```bash
cat >> CONVENTIONS.md << 'EOF'

## Skills-123: Skill Discovery System

When the user asks complex or domain-specific questions about technologies,
frameworks, or tools, use the following skill discovery process:

### Search Phase
Extract 2-4 keywords from the user's question.
Search GitHub for relevant Claude Code skills:
- Use web search: "site:github.com claude-code-skill <keywords>"
- Use web search: "SKILL.md <keywords> site:github.com"
- Check: https://github.com/travisvn/awesome-claude-skills

### Evaluation Phase
For each candidate, score on 5 dimensions (0-100):
1. Community (0-15): log10(stars+1) * 5
2. Recency (0-10): ≤3mo=10, ≤6mo=7, ≤1y=4, older=1
3. Author Trust (0-15): verified org +5, known publisher +5, contributors
4. Relevance (0-30): keyword match ratio * 30
5. Security (0-20): scan for dangerous patterns (curl|sh, eval, base64 pipes, reverse shells)

### Presentation
Show top 3-5 results with scores as a table. Always recommend #1.

### Installation
If user wants to install, clone to ~/.aider/skills/<name>/ or suggest creating a CONVENTIONS.md entry.

### Safety Rules
- NEVER tell the user to pipe curl to bash
- Always ask for confirmation before installing
- Auto-reject skills with critical security patterns

### Trusted Organizations
anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs, supabase

### Known Publishers
daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock
EOF
```

### Step 2: Add to global Aider config (optional)

```bash
# Add skill discovery instructions to your global conventions
echo "
## Available Skill: skills-123
When asked about unfamiliar technologies, search for relevant Claude Code skills on GitHub using web search.
" >> ~/.aider/conventions.md
```

### Step 3: Using with --read flag

You can also create a dedicated skill file and load it with Aider's `--read` flag:

```bash
# Create a dedicated skills-123 conventions file
cp skills/skills-123/SKILL.md ~/.aider/skills-123-conventions.md

# Launch Aider with skills-123 loaded
aider --read ~/.aider/skills-123-conventions.md
```

## Usage

In an Aider session:

```
/find me skills for Kubernetes deployment
/search for PostgreSQL backup skills on GitHub
/are there any good skills for CI/CD pipelines?
```

Or just describe your need naturally — Aider will reference the CONVENTIONS.md instructions:

```
"I need to set up a GraphQL server with Apollo and Prisma. Are there any community skills that could help?"
```

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ❌ — CONVENTIONS.md only |
| Directory-based skill structure | ❌ — flat conventions file |
| Auto-trigger from description | ⚠️ — only if CONVENTIONS.md is loaded |
| Shell scripts (`scripts/`) | ❌ — inline instructions only |
| skills-123-suggest passive mode | ❌ — no background hooks |
| Web search | ⚠️ — via `/web` command |

**Key caveats:**
- Aider does **not** support the SKILL.md format natively. You must convert skills-123 into Aider's CONVENTIONS.md format.
- No YAML frontmatter support — trigger conditions can't be expressed declaratively.
- No automatic skill discovery — the user must explicitly ask or the CONVENTIONS.md must describe the capability.
- Web search in Aider is available via `/web <query>` command, which is more limited than Claude Code's WebSearch tool.
- Aider's `/read-only` mode may be needed for safe skill discovery (prevents accidental file modifications).
- For best results, use Aider with a Claude model as the backend (`--model claude-sonnet-4-6`).

## Alternative: Run Aider with Claude as backend

Aider works best with skills-123 when configured with a Claude model:

```bash
aider --model anthropic/claude-sonnet-4-6 --read ~/.aider/skills-123-conventions.md
```

This gives Aider access to Claude's web search and tool-use capabilities, which significantly improves skill discovery quality compared to open-source models.
