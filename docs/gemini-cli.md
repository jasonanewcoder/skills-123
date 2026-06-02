# skills-123 on Gemini CLI

## Overview

[Gemini CLI](https://github.com/google-gemini/gemini-cli) is Google's open-source AI coding agent for the terminal. It supports the Agent Skills specification and can load SKILL.md files from `~/.gemini/skills/`.

## Prerequisites

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed (`npm install -g @google/gemini-cli` or `brew install gemini-cli`)
- A Google AI Studio API key configured

## Installation

### Method 1: Direct copy

```bash
git clone https://github.com/<user>/skills-123.git /tmp/skills-123

mkdir -p ~/.gemini/skills/skills-123
cp /tmp/skills-123/skills/skills-123/SKILL.md ~/.gemini/skills/skills-123/SKILL.md
cp -r /tmp/skills-123/skills/skills-123/scripts ~/.gemini/skills/skills-123/scripts
cp -r /tmp/skills-123/skills/skills-123/references ~/.gemini/skills/skills-123/references

mkdir -p ~/.gemini/skills/skills-123-suggest
cp /tmp/skills-123/skills/skills-123-suggest/SKILL.md ~/.gemini/skills/skills-123-suggest/SKILL.md

rm -rf /tmp/skills-123
```

### Method 2: Symlink

```bash
git clone https://github.com/<user>/skills-123.git ~/workspace/skills-123
mkdir -p ~/.gemini/skills
ln -s ~/workspace/skills-123/skills/skills-123 ~/.gemini/skills/skills-123
ln -s ~/workspace/skills-123/skills/skills-123-suggest ~/.gemini/skills/skills-123-suggest
```

## Usage

```
"Find me skills for Kubernetes deployment"
"Search for database migration skills on GitHub"
```

Gemini CLI detects skills in `~/.gemini/skills/` and includes them in its available capabilities.

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Supported |
| Multi-file skill directory | ✅ Supported |
| Shell scripts (`scripts/`) | ⚠️ Sandboxed |
| `WebSearch` tool | ❌ Not directly — Gemini uses Google grounding instead |
| `WebFetch` tool | ⚠️ Via Gemini's URL fetching capability |
| skills-123-suggest passive mode | ❓ Unknown |

**Key caveats:**
- **No WebSearch tool** — Gemini CLI does not expose a generic WebSearch tool like Claude Code. Instead, Gemini uses **Google Search grounding** internally. The skill discovery search queries in skills-123 may need to be adapted: use Gemini's built-in grounding for web facts, and `curl` via Bash for fetching specific URLs.
- **Shell sandboxing** — Gemini CLI sandboxes shell execution more strictly than Claude Code. Scripts in `scripts/` may need approval for each execution.
- **No hook system** — Gemini CLI doesn't support the hooks that `skills-123-suggest` uses for passive suggestion. Only active search works.

## Adaptation Notes

For best results with Gemini CLI, modify the search phase to use Gemini grounding:

Instead of:
```
WebSearch: "site:github.com claude-code-skill kubernetes"
```

Use:
```
Search Google for: claude-code-skill kubernetes site:github.com
```

Also adapt the `WebFetch` step — Gemini CLI can fetch URLs via curl in Bash or use its built-in content fetching if available.
