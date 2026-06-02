# skills-123 on OpenCode

## Overview

[OpenCode](https://github.com/opencode-ai/opencode) is an open-source AI coding agent that supports the Agent Skills specification. Skills are stored at `~/.config/opencode/skills/<name>/SKILL.md`.

## Prerequisites

- [OpenCode](https://github.com/opencode-ai/opencode) installed
- An AI provider API key configured (Claude, OpenAI, etc.)

## Installation

### Method 1: Direct copy

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

### Method 2: Symlink

```bash
git clone https://github.com/<user>/skills-123.git ~/workspace/skills-123
mkdir -p ~/.config/opencode/skills
ln -s ~/workspace/skills-123/skills/skills-123 ~/.config/opencode/skills/skills-123
ln -s ~/workspace/skills-123/skills/skills-123-suggest ~/.config/opencode/skills/skills-123-suggest
```

### OS-Specific Paths

| OS | Skills location |
|----|----------------|
| macOS | `~/Library/Application Support/opencode/skills/` |
| Linux | `~/.config/opencode/skills/` |
| Windows | `%APPDATA%/opencode/skills/` |

## Usage

```
"Find me skills for CI/CD pipeline setup"
"Search for monitoring and observability skills"
```

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Supported |
| Multi-file skill directory | ✅ Supported |
| Shell scripts (`scripts/`) | ⚠️ Provider-dependent |
| References (`references/`) | ✅ Loaded on demand |
| skills-123-suggest passive mode | ❓ Unknown |
| WebSearch tool | ⚠️ Provider-dependent |

**Key caveats:**
- OpenCode can use different AI providers. Tool availability (WebSearch, WebFetch) depends on which provider you use. Claude API as the backend gives the best skills-123 experience.
- Skill auto-trigger reliability depends on the provider model's instruction-following capability.
- The config path varies by OS — check `opencode --help` for your platform's exact path.
