# Hook Configuration — Guaranteed Skill Triggering

For users who want skills-123 to trigger **reliably on every task**, regardless of model behavior. This bypasses the model's trigger decision entirely.

## How It Works

Claude Code supports hooks — system-level callbacks that fire on tool-use events. A `PreToolUse` hook can inject a reminder signal before the model writes any file, prompting it to consider skills-123.

## Setup

Create or edit `.claude/settings.local.json` in your project root (project-level) or `~/.claude/settings.json` (global):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "echo '[skills-123 guard] Have you searched for community skills? Invoke skills-123 before writing this file.'"
          }
        ]
      }
    ]
  }
}
```

## What Happens

1. Model calls `Write` or `Edit`
2. Hook fires before the tool executes
3. The reminder text appears in the tool result
4. Model sees the reminder and pauses to consider skills-123
5. If it hasn't searched yet, it should invoke skills-123 first

## Trade-offs

| Pros | Cons |
|------|------|
| Guaranteed triggering — no model discretion needed | Adds ~100ms latency per Write/Edit call |
| Works with ANY project, not just this one | Reminder text consumes a small amount of context |
| One-time setup, zero maintenance | Hook must be configured per-project |

## Tuning

If the hook fires too frequently, narrow the matcher:

```json
"matcher": "Write"
```
(Watches only `Write` calls, not `Edit`)

Or make it session-level by using a `Stop` hook instead:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import json,os; p=os.path.expanduser('~/.claude/skills/skills-123/cache/proxy-usage.json'); u=json.load(open(p)) if os.path.exists(p) else []; print(f'[skills-123] {len(u)} skills used this session. Next task: remember to search first.')\""
          }
        ]
      }
    ]
  }
}
```

This reports skill usage at session end rather than checking every write — lighter, but doesn't prevent missed triggers mid-session.

## Without Hooks

If you prefer not to use hooks, skills-123 still works via the model's built-in description matching. The self-check in SKILL.md and the guard in CLAUDE.md provide semantic-level protection. Hooks are the **hardened** option for users who want maximum reliability.
