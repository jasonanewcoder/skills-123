# skills-123 on Cursor

## Overview

[Cursor](https://cursor.com) is an AI-first code editor built on VSCode. It supports Claude Code skills through its `.cursor/rules/` system, which uses `.mdc` files with YAML frontmatter. While Cursor doesn't natively read SKILL.md files, you can adapt skills-123 to work via Cursor Rules.

## Prerequisites

- [Cursor IDE](https://cursor.com/downloads) installed
- A project with `.cursor/rules/` directory

## Installation

Cursor uses `.mdc` (Markdown with frontmatter Configuration) files, not SKILL.md. You need to convert skills-123 into Cursor Rules format.

### Step 1: Create the Cursor Rule files

```bash
mkdir -p .cursor/rules
```

### Step 2: Convert skills-123 to .mdc format

Create `.cursor/rules/skills-123-core.mdc`:

```yaml
---
description: Skill discovery and installation — searches GitHub for relevant Claude Code skills, evaluates quality, and installs the best match. Use when asking complex domain-specific questions.
globs:
alwaysApply: false
---
```

Then append the full content of `skills/skills-123/SKILL.md` (without its YAML frontmatter).

### Step 3: Convert skills-123-suggest to .mdc format

Create `.cursor/rules/skills-123-suggest.mdc`:

```yaml
---
description: Passive skill suggestion — notices when community skills might help and suggests running skills-123.
globs:
alwaysApply: false
---
```

Then append the content of `skills/skills-123-suggest/SKILL.md` (without its YAML frontmatter).

### Automated conversion script

```bash
#!/bin/bash
# Convert skills-123 to Cursor .mdc format
SKILLS_REPO="${1:-~/workspace/skills-123}"
CURSOR_RULES="${2:-.cursor/rules}"

mkdir -p "$CURSOR_RULES"

# Convert core skill
cat > "$CURSOR_RULES/skills-123-core.mdc" << 'HEADER'
---
description: Skill Oracle — discover, evaluate, and install relevant Claude Code skills from GitHub. Use when asking complex or domain-specific questions about specific technologies, frameworks, or workflows.
globs:
alwaysApply: false
---
HEADER

tail -n +6 "$SKILLS_REPO/skills/skills-123/SKILL.md" >> "$CURSOR_RULES/skills-123-core.mdc"

# Convert suggest skill
cat > "$CURSOR_RULES/skills-123-suggest.mdc" << 'HEADER'
---
description: Skill Suggest — passive skill suggestion engine. Notices opportunities to recommend community skills.
globs:
alwaysApply: false
---
HEADER

tail -n +6 "$SKILLS_REPO/skills/skills-123-suggest/SKILL.md" >> "$CURSOR_RULES/skills-123-suggest.mdc"

echo "✅ Converted skills-123 to Cursor Rules format"
```

## Usage

In Cursor, skills-123 won't auto-trigger like it does in Claude Code. Instead:

1. Open the AI chat panel (`Cmd+L` / `Ctrl+L`)
2. Type `@skills-123-core` to manually invoke it
3. Describe what you need: `"Find me skills for Kubernetes deployment"`

Or use the Agent mode (`Cmd+I` / `Ctrl+I`) and mention the rule:
```
"Use the skills-123-core rule to find me skills for PostgreSQL backups"
```

## Limitations

| Feature | Support |
|---------|:---:|
| Auto-trigger from description | ⚠️ Manual (`@rule-name`) |
| 5-phase search pipeline | ✅ Works (WebSearch via Cursor) |
| Shell scripts | ⚠️ Needs execution approval |
| skills-123-suggest passive mode | ❌ Not supported (no auto-trigger) |
| Security scanning | ✅ Works if scripts are allowed |

**Key caveats:**
- Cursor Rules don't have the same auto-trigger mechanism as Claude Code skills. Users must manually invoke the rule.
- `alwaysApply: false` means the rule only activates when explicitly referenced.
- If you want skills-123 to always be available, set `alwaysApply: true` — but this will consume context tokens every session.
- Cursor's agent may not have the full `WebSearch` capability; skill search quality may vary.

## Alternative: Use with Claude Code extension

If you use Cursor with the Claude Code extension, you can install skills-123 directly into `~/.claude/skills/` and use it via the Claude Code panel — this gives you the full native experience.
