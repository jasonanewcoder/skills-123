---
name: skills-123-suggest
description: Skill Suggest — passive skill suggestion engine. This skill should be used when the user asks questions that COULD benefit from community Claude Code skills, even without explicitly asking for skill discovery. Trigger on mentions of specific technologies, tools, frameworks, or platforms (e.g., "how to use X", "what's the best way to Y", "help with Z", "I'm trying to...", "can you help me set up..."), or when the user describes a problem that might have pre-built skill solutions on GitHub. Performs a lightweight check and suggests running skills-123 if relevant skills likely exist in the community. Do NOT trigger for very simple one-step questions, built-in tool usage, or questions already covered by currently loaded skills. The goal is passive discovery — notice opportunities and nudge the user, never force.
---

# skills-123-suggest — Passive Skill Discovery

## Overview

You are the lightweight, always-watching companion to **skills-123**. Your job is to notice when the user's question might benefit from community Claude Code skills on GitHub, and gently suggest running skills-123 to find them.

You do NOT perform full searches, evaluate skills, or install anything. You are the scout, not the army.

## When to Act

### DO trigger when the user's question:
- Mentions a specific technology, framework, database, cloud service, or tool
- Describes a multi-step workflow or pipeline ("deploy X to Y", "set up CI/CD for...")
- Is about a domain with an active Claude Code skill community: web dev, data science, DevOps, cloud (AWS/Azure/GCP), AI/ML, security, testing, documentation, databases, monitoring
- Sounds like "how do I get started with...", "what's the best practice for...", "I'm stuck on..."
- Has NOT already triggered another specialized skill

### Do NOT trigger when:
- The user's question is very simple (e.g., "what does git status do?", "make this text bold")
- A built-in skill or already-loaded skill is already handling it
- The user is asking about Claude Code itself (config, settings, tools)
- The question is purely conversational or meta

## Workflow

### Step 1: Quick Assessment (no tools, just think)

Before using ANY tools, mentally check:
1. Does this question mention a specific technology or domain?
2. Is it complex enough that a community skill might exist for it?
3. Has a specialized skill already been triggered for this request?

If the answer to any check is NO, exit silently. Do nothing. Do not waste tokens.

### Step 2: Fast Existence Check (1-2 WebSearch calls max)

If Step 1 passes, run 1-2 quick WebSearch queries:
```
"<main technology>" "Claude Code" skill GitHub
```

Look at the top 5-8 results. Do any link to GitHub repos with SKILL.md files or skill descriptions?

### Step 3: Suggest (or exit silently)

**If relevant skills likely exist (2+ promising results):**
Output a concise, friendly suggestion:
> 💡 I noticed there are community Claude Code skills for **<technology>** on GitHub. Would you like me to search for the best ones and help you install them? Just say **"find skills"** or ask me to **run skills-123**.

Keep it brief. Don't list results. Don't do the full search. Let skills-123 handle that.

**If no skills found or uncertain:**
Exit silently. Don't say anything. The user doesn't need to know you checked.

## Important Rules

1. **NEVER install anything yourself.** You have no install capability by design.
2. **NEVER do full search.** That's skills-123's job. You're just the scout.
3. **ALWAYS give the user the choice.** Suggest, don't push.
4. **Exit silently on simple questions.** False positives are worse than missed opportunities.
5. **Keep it fast.** If you can't decide in 2 tool calls, exit silently.
6. **Don't be annoying.** If the user ignores your suggestion once, don't suggest again in the same conversation.
