# skills-123 on Coze (扣子)

## Overview

[Coze (扣子)](https://www.coze.cn) is ByteDance's AI agent platform. With the Coze 3.0 release (June 2026), Coze now supports importing Claude Code Skills — making skills-123 available on Coze's visual agent builder and marketplace.

## Prerequisites

- A [Coze account](https://www.coze.cn) (free tier available)
- Access to Coze Skills (3.0+)

## Installation

Coze uses a web-based interface, not local files. You upload skill packages as `.zip` archives.

### Method 1: Upload via Web UI

1. Package skills-123:

```bash
cd ~/workspace/skills-123
zip -r skills-123.zip skills/ -x "*.DS_Store" "*/cache/*"
```

2. Go to [Coze Skills](https://www.coze.cn/skills)
3. Click **"创建技能"** (Create Skill) → **"导入"** (Import)
4. Upload `skills-123.zip`
5. Coze auto-parses the SKILL.md files and creates Coze-native skills

### Method 2: Create from scratch in Coze

If the import option isn't available:

1. Go to [Coze Skills](https://www.coze.cn/skills) → **"创建技能"**
2. Set the skill name to `skills-123`
3. In the description field, paste:
   ```
   Skill Oracle — discover and install relevant AI skills from GitHub.
   Use when asking complex or domain-specific questions about specific
   technologies, frameworks, or workflows.
   ```
4. Paste the body of `skills/skills-123/SKILL.md` into the instruction field

### Method 3: Via Skills Marketplace

If skills-123 is published on the [skillsmp.com](https://skillsmp.com) marketplace:

1. Browse to the skills-123 page
2. One-click "Install to Coze"

## Usage

In Coze, invoke skills-123 via the `@` mention in a conversation:

```
@skills-123 Find me skills for Kubernetes deployment
@skills-123 Search for PostgreSQL backup skills on GitHub
```

Or in Coze's agent builder, add skills-123 as a tool to your custom agent. The agent will then have access to skill discovery capabilities.

## Coze-Specific Features

Coze 3.0 offers features not available in the local Claude Code version:

| Feature | Description |
|---------|-------------|
| **One-click sharing** | Share your configured skills-123 with team members |
| **Visual workflow editor** | Modify the discovery pipeline visually |
| **Multi-agent orchestration** | Combine skills-123 with other Coze agents |
| **Built-in marketplace** | Discover skills directly from Coze's ecosystem |
| **Monetization** | Publish your own skill variants |

## Limitations

| Feature | Support |
|---------|:---:|
| SKILL.md (YAML frontmatter) | ✅ Auto-parsed on import |
| Shell scripts (`scripts/`) | ✅ Runs in Coze sandbox |
| References (`references/`) | ✅ Loaded on demand |
| `WebSearch` tool | ✅ Via Coze's built-in search plugin |
| `WebFetch` tool | ✅ Via Coze's HTTP plugin |
| Local file system access | ❌ Coze is cloud-based |

**Key caveats:**
- **No local filesystem** — installed skills go to Coze's cloud workspace, not your local `.claude/skills/`. Skills discovered by skills-123 on Coze cannot install to your local machine.
- **Import size limits** — Coze may have limits on zip file size. The core skill files are small, but keep scripts minimal.
- **Chinese interface** — Coze's primary UI is Chinese. English users may prefer the Claude Code native experience.

## Comparison: Coze vs Claude Code

| Aspect | Claude Code | Coze |
|--------|:---:|:---:|
| Installation | Local (`~/.claude/skills/`) | Cloud (web upload) |
| Auto-trigger | ✅ | ❌ (@ mention required) |
| Shell scripts | Full access | Sandboxed |
| Discovered skills install target | Local machine | Coze workspace |
| Cost | API usage fees | Free tier available |
| Access in China | Requires proxy | Direct access |
| Skill marketplace | GitHub + registries | Coze + skillsmp.com |
