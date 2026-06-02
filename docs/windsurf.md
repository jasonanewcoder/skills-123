# skills-123 on Windsurf

## Overview

[Windsurf](https://codeium.com/windsurf) is Codeium's AI-powered IDE. It supports a skills directory at `.windsurf/skills/` that is compatible with the SKILL.md format, making skills-123 mostly plug-and-play.

## Prerequisites

- [Windsurf IDE](https://codeium.com/windsurf/download) installed
- A project directory

## Installation

### Method 1: Direct copy

```bash
git clone https://github.com/jasonanewcoder/skills-123.git /tmp/skills-123

mkdir -p .windsurf/skills/skills-123
cp /tmp/skills-123/skills/skills-123/SKILL.md .windsurf/skills/skills-123/SKILL.md
cp -r /tmp/skills-123/skills/skills-123/scripts .windsurf/skills/skills-123/scripts
cp -r /tmp/skills-123/skills/skills-123/references .windsurf/skills/skills-123/references

mkdir -p .windsurf/skills/skills-123-suggest
cp /tmp/skills-123/skills/skills-123-suggest/SKILL.md .windsurf/skills/skills-123-suggest/SKILL.md

rm -rf /tmp/skills-123
```

### Method 2: Symlink

```bash
git clone https://github.com/jasonanewcoder/skills-123.git ~/workspace/skills-123
mkdir -p .windsurf/skills
ln -s ~/workspace/skills-123/skills/skills-123 .windsurf/skills/skills-123
ln -s ~/workspace/skills-123/skills/skills-123-suggest .windsurf/skills/skills-123-suggest
```

### Method 3: Global installation

```bash
mkdir -p ~/.windsurf/skills
# Copy skills-123 into global Windsurf skills
cp -r ~/workspace/skills-123/skills/skills-123 ~/.windsurf/skills/
cp -r ~/workspace/skills-123/skills/skills-123-suggest ~/.windsurf/skills/
```

## Usage

In Windsurf, use Cascade (the AI assistant, `Cmd+L`):

```
"Find me skills for Kubernetes deployment"
"Search for CI/CD pipeline skills on GitHub"
"Are there any good skills for API documentation?"
```

Windsurf detects SKILL.md files in `.windsurf/skills/` and loads them as available capabilities.

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Supported |
| Multi-file skill directory | ✅ Supported |
| Shell scripts (`scripts/`) | ⚠️ Execution requires approval |
| References (`references/`) | ✅ Loaded on demand |
| skills-123-suggest passive mode | ❓ Unconfirmed |
| `WebSearch` tool | ⚠️ Via Cascade's web capability |
| Auto-trigger from description | ⚠️ Partial (less reliable than Claude Code) |

**Key caveats:**
- Windsurf's Cascade AI may not auto-trigger skills as reliably as Claude Code. You may need to explicitly mention skill discovery in your prompt.
- Cascade's web search capability may be limited compared to Claude Code's WebSearch tool, which could affect search result quality.
- Shell script execution is sandboxed — `install-from-github.sh` may need manual `chmod` approval.
- The `.windsurf/` directory is project-local. For global availability, use `~/.windsurf/skills/`.

## Format Compatibility

Windsurf follows the Agent Skills specification and supports the standard SKILL.md format with `name` and `description` YAML frontmatter. Claude Code-specific declarations (like `tools:` and `hooks:`) are ignored.

For a full project setup, combine `.windsurf/skills/` with `.windsurfrules` for project-level instructions:

```markdown
# .windsurfrules
When the user mentions unfamiliar technologies or asks complex setup questions,
check if the skills-123 skill can find relevant community skills on GitHub.
```
