# skills-123 on VSCode / GitHub Copilot

## Overview

[GitHub Copilot](https://github.com/features/copilot) in VSCode is Microsoft's AI coding assistant. Copilot reads project-level instructions from `.github/copilot-instructions.md`, a flat markdown file. Since Copilot doesn't support SKILL.md's directory structure or YAML frontmatter, skills-123 needs to be adapted into a monolithic instruction block.

## Prerequisites

- [VSCode](https://code.visualstudio.com/) with [GitHub Copilot extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)
- An active Copilot subscription

## Installation

### Step 1: Create or update copilot-instructions.md

```bash
mkdir -p .github
```

### Step 2: Append skills-123 content

Add the following block to `.github/copilot-instructions.md`:

```markdown
## Skills-123: Skill Discovery System

You have access to a skill discovery capability. When the user asks complex
or domain-specific questions (especially about specific technologies, frameworks,
or tools), you should:

1. **Assess** whether community skills on GitHub might help
2. **Search** using web search for relevant Claude Code skills:
   - Search: "site:github.com claude-code-skill <keywords>"
   - Search: "SKILL.md <keywords> Claude Code site:github.com"
   - Check: github.com/travisvn/awesome-claude-skills
3. **Evaluate** candidates by:
   - Stars (community signal)
   - Recency (updated within 6 months preferred)
   - Author reputation (verified orgs, known publishers)
   - Description match against user's query
   - Security: scan for dangerous patterns before recommending
4. **Present** top 3-5 results with scores
5. **Offer to install** the best match (always ask user first)

### Safety Rules
- NEVER install a skill without user confirmation
- Auto-reject skills containing: `curl | sh`, `eval $`, base64-to-pipe,
  `rm -rf /`, `/dev/tcp/`, credential exfiltration patterns
- Flag for review: network requests, sudo, global package installs

### Search Sources
- GitHub topic: claude-code-skill
- GitHub code: SKILL.md files
- Registry: majiayu000/claude-skill-registry-core
- Awesome lists: travisvn/awesome-claude-skills, onmyway133/awesome-claude-code

### Trusted Organizations
anthropics, vercel-labs, microsoft, cloudflare, hashicorp, tailwindlabs,
supabase, railwayapp, netlify, temporalio, prisma

### Known Publishers
daymade, obra, majiayu000, travisvn, julianobarbosa, ariadoss, mattpocock,
anombyte93, robertguss
```

### Step 3: Also copy to your user settings (optional, for all projects)

VSCode Copilot also reads from a global location. Create `~/.copilot-instructions.md` with the same content for project-independent access.

## Usage

In VSCode with Copilot Chat (`Cmd+Shift+I` / `Ctrl+Shift+I`):

```
"Find me skills for React testing on GitHub"
"Search for Kubernetes deployment skills"
"Are there any good skills for PostgreSQL backups?"
```

Copilot will follow the instructions block to search for and recommend skills.

## Limitations

| Feature | Support |
|---------|:---:|
| Directory-based skill structure | ❌ — flat `.md` file only |
| YAML frontmatter triggers | ❌ — plain markdown instructions |
| Auto-trigger from context | ⚠️ — only if instructions mention it |
| Shell scripts | ❌ — inline instructions only |
| skills-123-suggest passive mode | ❌ — no background triggers |
| Security auto-scan | ⚠️ — manual via described patterns |

**Key caveats:**
- `.github/copilot-instructions.md` is a **flat file** — you can't have subdirectories with scripts and references. Everything must be inlined as markdown text.
- Copilot may not always follow the skill discovery instructions unless the user explicitly asks for skill search.
- There's no caching mechanism — every search starts fresh.
- For the best experience, use the full Claude Code installation if possible. Copilot is a "best effort" adaptation.
