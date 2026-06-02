# skills-123

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/platform-Claude%20Code%20%7C%20Codex%20%7C%20Cursor%20%7C%20Coze%20%7C%20Windsurf%20%7C%20Gemini%20%7C%20OpenCode%20%7C%20Aider-purple" alt="Platforms">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen.svg" alt="Dependencies: Zero">
  <img src="https://img.shields.io/badge/security-scan%20%2B%20auto--reject-red.svg" alt="Security: Scan + Auto-reject">
</p>

<p align="center">
  <strong>一生二，二生三，三生万物</strong><br>
  <em>One produces two, two produces three, three produces all things.</em><br>
  — Tao Te Ching
</p>

<p align="center">
  <strong>The in-conversation skill advisor for AI coding agents.</strong><br>
  Automatically discovers, evaluates, and installs the best community skills from GitHub —<br>
  so you never need to pre-configure skills again.
</p>

<p align="center">
  🌐 Read this in: <a href="README.zh.md">简体中文</a> | <a href="README.ja.md">日本語</a> | <a href="README.ko.md">한국어</a> | <a href="README.es.md">Español</a>
</p>

---

## ✨ What It Does

```
You: "How do I set up PostgreSQL backups to S3?"
          │
          ▼
┌─────────────────────────────────┐
│  🔍 skills-123-suggest          │  Passive scout — notices "PostgreSQL" + "S3"
│  "Community skills found!        │  does a quick WebSearch, then nudges you
│   Want me to find the best one?" │
└──────────────┬──────────────────┘
               │  User: "Yes!"
               ▼
┌─────────────────────────────────┐
│  🧠 skills-123 (Phase 1-5)      │  Active engine — full pipeline
│                                  │
│  🔎 SEARCH  4 sources parallel   │  GitHub + registries + awesome lists
│  📊 EVALUATE 5-dimension score   │  Stars · Recency · Author · Relevance · Security
│  📋 PRESENT top 3 with table     │  Ranked + security flags
│  📦 INSTALL with safety scan     │  22 critical patterns auto-rejected
│  ✅ VERIFY and cache             │  Ready to use!
└──────────────────────────────────┘
          │
          ▼
You: "postgres-s3-backup skill is now installed. Ready to use!"
```

---

## 🏗️ Architecture

```
skills-123/
├── skills/
│   ├── skills-123/              🔍 Active: 5-phase search → evaluate → install
│   │   ├── SKILL.md             Core skill (self-contained instructions)
│   │   ├── scripts/             Shell accelerators
│   │   │   ├── search-github.sh       Query generator
│   │   │   ├── evaluate-skill.sh      5-dimension scoring engine
│   │   │   ├── install-from-github.sh Git clone / tarball dual-strategy
│   │   │   └── scan-security.sh      22 critical + 18 warning patterns
│   │   ├── references/          Detailed docs (on-demand loading)
│   │   │   ├── search-sources.md      12 data sources cataloged
│   │   │   ├── scoring-rubric.md      Scoring methodology + examples
│   │   │   └── safety-patterns.md     Attack vector catalog
│   │   └── cache/               Runtime cache (auto-created)
│   └── skills-123-suggest/      💡 Passive: lightweight scout, never installs
│       └── SKILL.md             3-step: assess → quick check → suggest
├── docs/                        📖 Per-agent installation guides
│   ├── codex.md                 OpenAI Codex
│   ├── cursor.md                Cursor IDE
│   ├── vscode.md                VSCode / Copilot
│   ├── coze.md                  Coze (扣子)
│   ├── windsurf.md              Windsurf
│   ├── gemini-cli.md            Google Gemini CLI
│   ├── opencode.md              OpenCode
│   └── aider.md                 Aider
├── install.sh                   ⚡ One-command installer
├── LICENSE                      MIT
└── README.md                    You are here
```

---

## 🚀 Installation

### Prerequisites
- **Claude Code** installed
- `curl` and `git` (standard on macOS/Linux)

### One-command install

```bash
curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
```

### Manual install

```bash
git clone https://github.com/<user>/skills-123.git
cd skills-123
bash install.sh
```

Then **restart Claude Code**. Two new skills will appear:
- `skills-123` — the active search engine
- `skills-123-suggest` — the passive suggestion scout

### Install on other agents

skills-123 works with all major AI coding agents. See per-agent guides:

| Agent | Guide | Native Support |
|-------|-------|:---:|
| **Claude Code** | *(built-in)* | ✅ Full |
| **OpenAI Codex** | [codex.md](docs/codex.md) | ✅ SKILL.md |
| **Cursor** | [cursor.md](docs/cursor.md) | ⚠️ MDC adaptation |
| **VSCode / Copilot** | [vscode.md](docs/vscode.md) | ⚠️ Flat format |
| **Coze (扣子)** | [coze.md](docs/coze.md) | ✅ Import |
| **Windsurf** | [windsurf.md](docs/windsurf.md) | ✅ SKILL.md |
| **Gemini CLI** | [gemini-cli.md](docs/gemini-cli.md) | ✅ SKILL.md |
| **OpenCode** | [opencode.md](docs/opencode.md) | ✅ SKILL.md |
| **Aider** | [aider.md](docs/aider.md) | ⚠️ Plain md |

---

## 💬 Usage

### Active Search

Just ask naturally — skills-123 triggers automatically:

```
"Find me skills for Kubernetes deployment"
"Are there any good skills for PostgreSQL backups?"
"Search for React testing skills"
"I need to set up a CI/CD pipeline — any skills for that?"
```

### Passive Suggestion

When you mention a specific technology, `skills-123-suggest` quietly checks GitHub and nudges you:

> 💡 I noticed there are community Claude Code skills for **Kubernetes** on GitHub. Would you like me to search for the best ones?

### What Happens Under the Hood

| Phase | What It Does |
|:-----:|------|
| **0 — Assess** | Determines if external skills are actually needed (avoids wasting tokens) |
| **1 — Search** | Queries 4 sources in parallel (GitHub topic, code search, registries, awesome lists) |
| **2 — Evaluate** | Scores on 5 dimensions: community · recency · author trust · relevance · security |
| **3 — Present** | Shows top 3-5 candidates with scores, security flags, and recommendations |
| **4 — Install** | Security scan → user confirmation → git clone/tarball → verify → cache |

---

## 🛡️ Scoring & Security

### 5-Dimension Quality Score (0-100)

| Dimension | Weight | What It Measures |
|-----------|:------:|------------------|
| **Community** | 0-15 | Stars on log scale — 1000+ stars = max |
| **Recency** | 0-10 | Updated ≤3mo = 10, ≤6mo = 7, ≤1y = 4, older = 1 |
| **Author Trust** | 0-15 | Verified org +5, known publisher +5, 5+ contributors +5 |
| **Relevance** | 0-30 | Keyword match ratio against your query |
| **Security** | 0-20 | Clean = 20, warnings = 10, **critical = auto-disqualify** |

### Security Model

```
Skill found → Scan SKILL.md content
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ✅ Clean     ⚠️ Warning    🚫 Critical
   Install      Flag + ask    Auto-reject
```

**22 critical patterns** trigger auto-rejection: `curl | sh`, `eval $`, base64-to-pipe, `rm -rf /`, reverse shells, credential theft, Python injection.

**18 warning patterns** flagged for review: network requests, `sudo`, `chmod`, package installs, sensitive file access.

---

## 🔬 Why skills-123?

### Compared to Existing Tools

| Differentiator | skills-123 | find-skills (Vercel) | superskillret |
|:---|:---:|:---:|:---:|
| **Form factor** | Native skill (in-conversation) | npm CLI (`npx skills`) | Hook + daemon (1.4GB RAM) |
| **External deps** | **Zero** (curl + git) | Node.js / npm | Python + ONNX |
| **Trigger mode** | **Dual**: passive + active | Manual (CLI commands) | Auto (every prompt) |
| **Search sources** | 4 parallel | skills.sh marketplace | 16K vector index |
| **Quality score** | 5-dimension (transparent) | None | Cosine similarity (black-box) |
| **Security scan** | **22 critical + 18 warn** | None | None |
| **Memory overhead** | None | None | **~1.4 GB** |

> **In one sentence:** find-skills is a search bar for the skill marketplace. superskillret is a heavy background recommendation engine. **skills-123 is your in-conversation skill advisor** — native, zero-dependency, safety-first.

---

## 📁 Project Structure

| Path | Purpose |
|------|---------|
| `skills/skills-123/SKILL.md` | Core skill with full 5-phase workflow |
| `skills/skills-123/scripts/` | Shell scripts for search, evaluate, install, security |
| `skills/skills-123/references/` | Deep-dive docs (sources, scoring, safety) |
| `skills/skills-123/cache/` | Runtime cache (auto-created on first use) |
| `skills/skills-123-suggest/SKILL.md` | Passive suggestion companion |
| `docs/` | Per-agent installation guides |
| `install.sh` | One-command installer |

---

## 👥 Authors

**jasonanewcoder, Claude Code, DeepSeek**

## 📄 License

MIT — see [LICENSE](LICENSE) for full text.
