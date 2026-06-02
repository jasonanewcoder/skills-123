# skills-123 on OpenCode

## Overview

[OpenCode](https://github.com/opencode-ai/opencode) is an open-source AI coding agent. It stores skills at `~/.config/opencode/skills/<name>/SKILL.md` (Linux/macOS) and supports the SKILL.md standard.

## Prerequisites

- [OpenCode](https://github.com/opencode-ai/opencode) installed
- An LLM provider configured (Anthropic, OpenAI, or open-source)

## Installation

### Linux / macOS

```bash
git clone https://github.com/<user>/skills-123.git /tmp/skills-123

mkdir -p ~/.config/opencode/skills/skills-123
cp /tmp/skills-123/skills/skills-123/SKILL.md ~/.config/opencode/skills/skills-123/SKILL.md
cp -r /tmp/skills-123/skills/skills-123/scripts ~/.config/opencode/skills/skills-123/scripts
cp -r /tmp/skills-123/skills/skills-123/references ~/.config/opencode/skills/skills-123/references

mkdir -p ~/.config/opencode/skills/skills-123-suggest
cp /tmp/skills-123/skills/skills-123-suggest/SKILL.md ~/.config/opencode/skills/skills-123-suggest/SKILL.md

rm -rf /tmp/skills-123
```

### Symlink

```bash
git clone https://github.com/<user>/skills-123.git ~/workspace/skills-123
mkdir -p ~/.config/opencode/skills
ln -s ~/workspace/skills-123/skills/skills-123 ~/.config/opencode/skills/skills-123
ln -s ~/workspace/skills-123/skills/skills-123-suggest ~/.config/opencode/skills/skills-123-suggest
```

## Usage

```
"Find me skills for Kubernetes deployment"
"Search for React testing skills on GitHub"
```

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Full |
| Shell scripts | ✅ Supported (with approval) |
| WebSearch | ⚠️ Provider-dependent |
| Auto-trigger | ✅ Supported |

**Key caveats:**
- OpenCode is **LLM-agnostic** — WebSearch/WebFetch availability depends on your configured provider. Anthropic models have the best tool support.
- Configuration path varies: `~/.config/opencode/skills/` (Linux/macOS) or `%APPDATA%/opencode/skills/` (Windows).
- Skill auto-trigger quality depends heavily on the underlying model. Claude models trigger skills most reliably; open-source models may miss triggers.
- OpenCode's open-source nature means you can modify skill loading behavior. See `~/.config/opencode/config.yaml` for skill path configuration.
