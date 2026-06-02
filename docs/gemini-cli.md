# skills-123 on Gemini CLI

## Overview

[Gemini CLI](https://github.com/google-gemini/gemini-cli) is Google's terminal-based AI agent. It supports SKILL.md files placed in `~/.gemini/skills/`, making skills-123 directly compatible.

## Prerequisites

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed (`npm install -g @google/gemini-cli`)
- A Google AI Studio API key or Vertex AI configured

## Installation

### Direct copy

```bash
git clone https://github.com/jasonanewcoder/skills-123.git /tmp/skills-123

mkdir -p ~/.gemini/skills/skills-123
cp /tmp/skills-123/skills/skills-123/SKILL.md ~/.gemini/skills/skills-123/SKILL.md
cp -r /tmp/skills-123/skills/skills-123/scripts ~/.gemini/skills/skills-123/scripts
cp -r /tmp/skills-123/skills/skills-123/references ~/.gemini/skills/skills-123/references


rm -rf /tmp/skills-123
```

### Symlink

```bash
git clone https://github.com/jasonanewcoder/skills-123.git ~/workspace/skills-123
mkdir -p ~/.gemini/skills
ln -s ~/workspace/skills-123/skills/skills-123 ~/.gemini/skills/skills-123
```

## Usage

```
"Find me skills for Kubernetes deployment"
"Search for CI/CD pipeline skills"
```

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Full |
| Shell scripts | ⚠️ Restricted |
| WebSearch | ⚠️ Google grounding, not general web |
| Auto-trigger | ✅ Supported |

**Key caveats:**
- Gemini CLI uses **Google Search grounding** instead of general WebSearch — search results may differ from Claude Code.
- `WebFetch` may not be available; skill discovery relies primarily on Gemini's built-in knowledge and Google grounding.
- Shell scripts (`scripts/`) are sandboxed. `install-from-github.sh` requires `--allow-exec` flag or manual approval.
- For the best search results, use Gemini 2.5 Pro or later (better web grounding).
