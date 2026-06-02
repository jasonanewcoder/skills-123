# skills-123 on OpenAI Codex CLI

## Overview

[OpenAI Codex CLI](https://github.com/openai/codex) is OpenAI's terminal-based AI coding agent. Since early 2026, Codex has adopted the SKILL.md standard, making it directly compatible with skills-123.

## Prerequisites

- [Codex CLI](https://github.com/openai/codex) installed (`npm install -g @openai/codex` or `brew install codex`)
- An OpenAI API key configured

## Installation

Skills in Codex live under `~/.agents/skills/<skill-name>/SKILL.md`.

### Method 1: Direct copy (recommended)

```bash
# Clone skills-123
git clone https://github.com/jasonanewcoder/skills-123.git /tmp/skills-123

# Copy into Codex skills directory
mkdir -p ~/.agents/skills/skills-123
cp /tmp/skills-123/skills/skills-123/SKILL.md ~/.agents/skills/skills-123/SKILL.md
cp -r /tmp/skills-123/skills/skills-123/scripts ~/.agents/skills/skills-123/scripts
cp -r /tmp/skills-123/skills/skills-123/references ~/.agents/skills/skills-123/references


# Clean up
rm -rf /tmp/skills-123
```

### Method 2: Symlink (for keeping up-to-date)

```bash
git clone https://github.com/jasonanewcoder/skills-123.git ~/workspace/skills-123
mkdir -p ~/.agents/skills
ln -s ~/workspace/skills-123/skills/skills-123 ~/.agents/skills/skills-123
```

## Usage

Works identically to Claude Code. Just talk to Codex normally:

```
"Find me skills for PostgreSQL backups"
"Search for Kubernetes deployment skills"
```

Codex will detect the skill's description and trigger it automatically when your question matches.

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Full |
| `description`-based auto-trigger | ✅ Supported |
| Shell scripts (`scripts/`) | ⚠️ Limited — Codex sandboxes script execution |
| References (`references/`) | ✅ Loaded on demand |
| `WebSearch` tool | ✅ Available |

**Key caveats:**
- Shell scripts may run with restricted permissions in Codex's sandbox. The `install-from-github.sh` and `scan-security.sh` scripts may need the `--allow-all` flag or manual `chmod +x`.
- Codex does not support all Claude Code tools — `skills-123`'s SKILL.md declares `tools: Bash, WebSearch, WebFetch, Read, Write, Edit`. Codex ignores unknown tool declarations.

## Skill Format Compatibility

Codex supports the Anthropic Agent Skills spec (SKILL.md). The YAML frontmatter fields `name` and `description` are fully recognized. Codex ignores Claude Code-specific fields like `tools:` and `hooks:`.

For full Codex skill documentation, see: [OpenAI Codex Skills](https://platform.openai.com/docs/guides/codex-skills)
