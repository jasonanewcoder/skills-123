# skills-123（一二三）

> **一生二，二生三，三生万物**
> **One produces two, two produces three, three produces all things.**
> **一は二を生み、二は三を生み、三は万物を生む**
> **하나가 둘을 낳고, 둘이 셋을 낳고, 셋이 만물을 낳는다**
> **Uno produce dos, dos produce tres, tres produce todas las cosas.**

— 道德经 / Tao Te Ching / 老子

---

Skills-123 is a self-bootstrapping skill discovery and installation system for Claude Code. It automatically searches GitHub for relevant Claude Code skills, evaluates their quality, and installs the best match — so you never need to pre-configure skills again.

---

## 简体中文

### 简介

skills-123（一二三）是一套 Claude Code 技能发现与安装系统。当你提出复杂或领域特定的问题时，它会自动搜索 GitHub 上的社区技能，评估质量并安装最佳匹配项。

名字来源于《道德经》"一生二，二生三，三生万物"—— 从一套技能开始，发现并安装无数技能，解决无限问题。

### 安装

```bash
git clone https://github.com/<user>/skills-123.git
cd skills-123
bash install.sh
```

或者一行命令：

```bash
curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
```

安装后重启 Claude Code 即可使用。

### 使用方式

**主动搜索：**
```
"帮我找一下 Kubernetes 部署相关的技能"
"有没有 PostgreSQL 备份的 skill？"
"find me skills for React testing"
```

**被动建议：**
当你提到特定技术时，skills-123-suggest 会自动建议相关技能：
> 💡 我发现 GitHub 上有 **Kubernetes** 的社区技能，需要我帮你搜索并安装最好的吗？

### 架构

| 组件 | 说明 |
|------|------|
| `skills-123` | 核心技能：搜索 → 评估 → 展示 → 安装 |
| `skills-123-suggest` | 被动技能：轻量检查 → 建议 |
| `scripts/` | Shell 脚本：搜索、评估、安装、安全扫描 |
| `references/` | 详细文档：数据源、评分标准、安全规则 |

### 为什么选择 skills-123？

**对话内的技能顾问。** 与其他需要离开对话界面手动执行命令的工具不同，skills-123 完全运行在 Claude Code 对话内部。你正常提问，它会在合适的时机自动出现，帮你发现并安装最佳技能。

| 差异点 | skills-123 | find-skills (Vercel) | skill-seeker | superskillret |
|:---|:---:|:---:|:---:|:---:|
| **形态** | Claude Code 原生 Skill | npm CLI (`npx skills`) | Claude Code Plugin | Hook + 后台守护进程 |
| **外部依赖** | **零**（仅需 curl/git） | Node.js / npm | Node.js + npm | Python + ONNX (~600MB) |
| **触发方式** | **双模**：被动建议 + 主动搜索 | 手动（用户执行命令） | 手动（slash command） | 全自动（每次 prompt） |
| **内存占用** | 无 | 无 | 无 | **~1.4 GB** 常驻 |
| **搜索源** | 4 类并行（GitHub + Web + Registry + Awesome List） | skills.sh 市场 | Registry + GitHub API | 预构建向量索引（16,783 技能） |
| **质量评分** | **5 维评分**（社区/时效/作者/相关/安全） | 无 | 基础评分 | 余弦相似度（黑盒） |
| **安全扫描** | **22 关键模式 + 18 警告模式 + 自动拒绝** | 无 | 9 类检测 | 无 |
| **安装方式** | git clone / tarball 双策略 | `npx skills add` | Slash command | 引用注入（无需安装） |
| **评分可审计** | 透明（shell 脚本） | 不适用 | 不透明 | 黑盒（向量嵌入） |
| **设计哲学** | 一生二，二生三，三生万物 | 实用工具 | 实用工具 | 检索系统 |

**一句话：** find-skills 是技能市场的搜索栏，superskillret 是重型的后台推荐引擎，**skills-123 是对话内的技能顾问**——原生 Claude Code 体验，零依赖，安全第一。

### 安全

- 安装前始终征得用户同意
- 自动扫描 SKILL.md 中的危险模式
- 关键模式（管道执行、反向 shell）自动拒绝
- 警告模式（网络请求、提权）标记审查

---

## English

### Overview

skills-123 (一二三) is a Claude Code skill discovery and installation system. When you ask a complex or domain-specific question, it automatically searches GitHub for community skills, evaluates their quality using a 5-dimension rubric, and installs the best match — all with your consent.

Named after the Tao Te Ching verse "One produces two, two produces three, three produces all things" — from a single skill springs a universe of capabilities.

### Installation

```bash
git clone https://github.com/<user>/skills-123.git
cd skills-123
bash install.sh
```

Or one-liner:

```bash
curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
```

Restart Claude Code after installation.

### Usage

**Active search:**
```
"Find me skills for Kubernetes deployment"
"Are there any good skills for PostgreSQL backups?"
"Search for React testing skills"
```

**Passive suggestion:**
When you mention specific technologies, skills-123-suggest notices and suggests:
> 💡 I noticed there are community Claude Code skills for **Kubernetes** on GitHub. Would you like me to search for the best ones?

### Architecture

| Component | Role |
|-----------|------|
| `skills-123` | Core skill: Search → Evaluate → Present → Install (5-phase pipeline) |
| `skills-123-suggest` | Passive skill: Quick check → Suggest (lightweight, never installs) |
| `scripts/` | Shell scripts: search-github.sh, evaluate-skill.sh, install-from-github.sh, scan-security.sh |
| `references/` | Detailed docs: search sources catalog, scoring rubric, security patterns |

### Scoring Rubric (5 Dimensions)

| Dimension | Weight | Criteria |
|-----------|--------|----------|
| Community | 0-15 | Stars (log scale) |
| Recency | 0-10 | Last update ≤3mo=10, ≤6mo=7, ≤1y=4, older=1 |
| Author Trust | 0-15 | Verified org, known publisher, contributor count |
| Relevance | 0-30 | Keyword match ratio against user's query |
| Security | 0-20 | Clean=20, warnings=10, critical=disqualified |

### Security

- **Always** asks for user confirmation before installing
- **Auto-scans** SKILL.md for dangerous patterns (piped shell execution, reverse shells, credential theft)
- **Critical patterns** trigger automatic rejection
- **Warning patterns** (network requests, sudo, package installs) are flagged for review
- **Trusted author whitelist** boosts scores for verified publishers

### Why skills-123?

**The in-conversation skill advisor.** Unlike other tools that require you to leave your conversation and run CLI commands, skills-123 lives inside Claude Code. You talk normally — it notices opportunities and helps you find the right skills without breaking your flow.

| Differentiator | skills-123 | find-skills (Vercel) | skill-seeker | superskillret |
|:---|:---:|:---:|:---:|:---:|
| **Form factor** | Native Claude Code Skill | npm CLI (`npx skills`) | Claude Code Plugin | Hook + background daemon |
| **External dependencies** | **Zero** (curl + git only) | Node.js / npm | Node.js + npm | Python + ONNX (~600MB) |
| **Trigger mode** | **Dual**: passive suggestion + active search | Manual (user runs commands) | Manual (slash command) | Fully automatic (every prompt) |
| **Memory overhead** | None | None | None | **~1.4 GB** resident |
| **Search sources** | 4 parallel (GitHub + Web + Registry + Awesome Lists) | skills.sh marketplace | Registry + GitHub API | Prebuilt vector index (16,783 skills) |
| **Quality scoring** | **5-dimension** (community, recency, author, relevance, security) | None | Basic | Cosine similarity (black-box) |
| **Security scanning** | **22 critical + 18 warning patterns + auto-reject** | None | 9 categories | None |
| **Installation** | git clone / tarball dual strategy | `npx skills add` | Slash command | Reference injection (no install) |
| **Scoring auditability** | Transparent (shell script) | N/A | Opaque | Black-box (embedding vectors) |
| **Design philosophy** | Tao-inspired: from one skill springs all things | Utility tool | Utility tool | Retrieval system |

**One-liner:** find-skills is the search bar for the skill marketplace. superskillret is a heavy background recommendation engine. **skills-123 is your in-conversation skill advisor** — native Claude Code experience, zero dependencies, safety-first.

### License

MIT — see [LICENSE](LICENSE)

---

## 日本語

### 概要

skills-123（一二三）は、Claude Code 用のスキル発見・インストールシステムです。複雑な質問や特定の技術に関する質問をすると、GitHub 上のコミュニティスキルを自動的に検索し、5次元の評価基準で品質を評価し、最適なものをインストールします。

名前は老子の「一は二を生み、二は三を生み、三は万物を生む」に由来します—— 一つのスキルから無限の可能性が生まれます。

### インストール

```bash
git clone https://github.com/<user>/skills-123.git
cd skills-123
bash install.sh
```

または一行で：

```bash
curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
```

インストール後、Claude Code を再起動してください。

### 使い方

**アクティブ検索：**
```
"Kubernetes のデプロイに関するスキルを探して"
"PostgreSQL のバックアップのスキルはある？"
"React のテストスキルを検索して"
```

**パッシブ提案：**
特定の技術について話すと、skills-123-suggest が自動的に提案します：
> 💡 GitHub に **Kubernetes** のコミュニティスキルがあります。検索してインストールしましょうか？

### アーキテクチャ

| コンポーネント | 役割 |
|----------------|------|
| `skills-123` | コアスキル：検索→評価→提示→インストール（5フェーズ） |
| `skills-123-suggest` | パッシブスキル：簡易チェック→提案（軽量、インストール不可） |
| `scripts/` | シェルスクリプト：検索、評価、インストール、セキュリティスキャン |
| `references/` | 詳細ドキュメント：データソース、評価基準、セキュリティルール |

### セキュリティ

- インストール前に必ずユーザー確認
- SKILL.md の危険パターンを自動スキャン
- クリティカルパターン（パイプ実行、リバースシェル）は自動拒否
- 警告パターン（ネットワーク通信、sudo）は確認対象

### ライセンス

MIT — [LICENSE](LICENSE) 参照

---

## 한국어

### 개요

skills-123(一二三)은 Claude Code용 스킬 검색 및 설치 시스템입니다. 복잡하거나 도메인 특화된 질문을 하면 GitHub에서 커뮤니티 스킬을 자동으로 검색하고, 5차원 평가 기준으로 품질을 평가하여 최적의 스킬을 설치합니다.

이름은 노자의 "하나가 둘을 낳고, 둘이 셋을 낳고, 셋이 만물을 낳는다"에서 유래했습니다 — 하나의 스킬에서 무한한 가능성이 생겨납니다.

### 설치

```bash
git clone https://github.com/<user>/skills-123.git
cd skills-123
bash install.sh
```

또는 한 줄로:

```bash
curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
```

설치 후 Claude Code를 재시작하세요.

### 사용법

**능동 검색:**
```
"Kubernetes 배포 관련 스킬 찾아줘"
"PostgreSQL 백업 스킬 있어?"
"React 테스트 스킬 검색해줘"
```

**수동 제안:**
특정 기술을 언급하면 skills-123-suggest가 자동으로 제안합니다:
> 💡 GitHub에 **Kubernetes** 커뮤니티 스킬이 있습니다. 검색해서 설치할까요?

### 아키텍처

| 구성 요소 | 역할 |
|-----------|------|
| `skills-123` | 코어 스킬: 검색 → 평가 → 제시 → 설치 (5단계) |
| `skills-123-suggest` | 패시브 스킬: 빠른 확인 → 제안 (경량, 설치 안 함) |
| `scripts/` | 셸 스크립트: 검색, 평가, 설치, 보안 스캔 |
| `references/` | 상세 문서: 데이터 소스, 평가 기준, 보안 규칙 |

### 보안

- 설치 전 항상 사용자 확인
- SKILL.md의 위험 패턴 자동 스캔
- 치명적 패턴(파이프 실행, 리버스 셸) 자동 거부
- 경고 패턴(네트워크 요청, sudo) 검토 플래그

### 라이선스

MIT — [LICENSE](LICENSE) 참조

---

## Español

### Descripción General

skills-123 (一二三) es un sistema de descubrimiento e instalación de habilidades para Claude Code. Cuando haces una pregunta compleja o específica de un dominio, busca automáticamente habilidades comunitarias en GitHub, evalúa su calidad usando una rúbrica de 5 dimensiones e instala la mejor opción — siempre con tu consentimiento.

El nombre proviene del verso del Tao Te Ching "Uno produce dos, dos produce tres, tres produce todas las cosas" — de una sola habilidad surge un universo de capacidades.

### Instalación

```bash
git clone https://github.com/<user>/skills-123.git
cd skills-123
bash install.sh
```

O en una línea:

```bash
curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
```

Reinicia Claude Code después de la instalación.

### Uso

**Búsqueda activa:**
```
"Encuéntrame habilidades para desplegar Kubernetes"
"¿Hay buenas habilidades para backups de PostgreSQL?"
"Busca habilidades de testing para React"
```

**Sugerencia pasiva:**
Cuando mencionas tecnologías específicas, skills-123-suggest lo nota y sugiere:
> 💡 He notado que hay habilidades comunitarias de Claude Code para **Kubernetes** en GitHub. ¿Quieres que busque las mejores?

### Arquitectura

| Componente | Rol |
|------------|-----|
| `skills-123` | Habilidad principal: Buscar → Evaluar → Presentar → Instalar (5 fases) |
| `skills-123-suggest` | Habilidad pasiva: Verificación rápida → Sugerir (ligera, nunca instala) |
| `scripts/` | Scripts shell: búsqueda, evaluación, instalación, análisis de seguridad |
| `references/` | Documentos detallados: fuentes de búsqueda, rúbrica de puntuación, patrones de seguridad |

### Seguridad

- **Siempre** solicita confirmación antes de instalar
- **Auto-analiza** SKILL.md en busca de patrones peligrosos
- **Patrones críticos** (ejecución remota, shells inversos) se rechazan automáticamente
- **Patrones de advertencia** (solicitudes de red, sudo) se marcan para revisión
- **Lista blanca de autores** confiables mejora las puntuaciones

### Licencia

MIT — ver [LICENSE](LICENSE)

---

## 🌐 跨 Agent 支持 / Cross-Agent Support

skills-123 的 SKILL.md 格式已被主流 AI 编程 Agent 广泛支持。以下是各平台的安装指南：

The SKILL.md format is supported across all major AI coding agents. Click the links below for per-platform installation guides:

| Agent | 指南 Guide | 支持度 Support |
|-------|-----------|:---:|
| **Claude Code** | (内置 / built-in) | ✅ 完整 Full |
| **OpenAI Codex** | [codex.md](docs/codex.md) | ✅ SKILL.md 原生 |
| **Cursor** | [cursor.md](docs/cursor.md) | ⚠️ 需适配 MDC |
| **VSCode / Copilot** | [vscode.md](docs/vscode.md) | ⚠️ 扁平格式 |
| **Coze (扣子)** | [coze.md](docs/coze.md) | ✅ 一键导入 |
| **Windsurf** | [windsurf.md](docs/windsurf.md) | ✅ SKILL.md 兼容 |
| **Gemini CLI** | [gemini-cli.md](docs/gemini-cli.md) | ✅ SKILL.md 兼容 |
| **OpenCode** | [opencode.md](docs/opencode.md) | ✅ SKILL.md 兼容 |
| **Aider** | [aider.md](docs/aider.md) | ⚠️ 纯文本适配 |

> 💡 **最佳体验**: Claude Code > Codex > Windsurf / Gemini CLI / OpenCode >
> Cursor / VSCode Copilot / Aider > Coze（云端限制）
>
> **Best experience**: Claude Code > Codex > Windsurf / Gemini CLI / OpenCode >
> Cursor / VSCode Copilot / Aider > Coze (cloud limitations)

---

## Contributing

Contributions welcome! Please open an issue or PR on GitHub.

## License

MIT — see [LICENSE](LICENSE) for full text.
# skills-123
