# skills-123

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/%EC%9D%98%EC%A1%B4%EC%84%B1-%EC%A0%9C%EB%A1%9C-brightgreen.svg" alt="의존성: 제로">
  <img src="https://img.shields.io/badge/%EB%B3%B4%EC%95%88-%EC%8A%A4%EC%BA%94%20%2B%20%EC%9E%90%EB%8F%99%20%EA%B1%B0%EB%B6%80-red.svg" alt="보안: 스캔 + 자동 거부">
</p>

<p align="center">
  <strong>하나가 둘을 낳고, 둘이 셋을 낳고, 셋이 만물을 낳는다</strong><br>
  — 노자
</p>

<p align="center">
  <strong>AI 코딩 에이전트를 위한 대화 내 스킬 어드바이저.</strong><br>
  GitHub에서 최고의 커뮤니티 스킬을 자동으로 발견, 평가, 설치합니다——<br>
  더 이상 스킬을 수동으로 설정할 필요가 없습니다.
</p>

<p align="center">
  🌐 다른 언어로 읽기: <a href="README.md">English</a> | <a href="README.zh.md">简体中文</a> | <a href="README.ja.md">日本語</a> | <a href="README.es.md">Español</a>
</p>

---

## ✨ 기능

```
당신: "PostgreSQL 백업을 S3에 설정하려면?"
          │
          ▼
┌─────────────────────────────────┐
│  🔍 skills-123-suggest          │  패시브 스카우트
│  "GitHub에 관련 스킬이 있습니다.  │  빠른 검색 → 제안
│   가장 좋은 걸 찾아볼까요?"       │
└──────────────┬──────────────────┘
               │  당신: "네!"
               ▼
┌─────────────────────────────────┐
│  🧠 skills-123（5단계）          │  액티브 엔진
│  🔎 검색 → 📊 평가 → 📋 표시     │
│  → 📦 설치 → ✅ 검증             │
└──────────────────────────────────┘
```

---

## 🚀 설치

```bash
git clone https://github.com/jasonanewcoder/skills-123.git
cd skills-123
bash install.sh
```

Claude Code를 재시작하면 `skills-123`과 `skills-123-suggest`가 활성화됩니다.

### 다른 에이전트에 설치

| Agent | 가이드 |
|-------|-------|
| **OpenAI Codex** | [codex.md](docs/codex.md) |
| **Cursor** | [cursor.md](docs/cursor.md) |
| **VSCode / Copilot** | [vscode.md](docs/vscode.md) |
| **Coze (扣子)** | [coze.md](docs/coze.md) |
| **Windsurf** | [windsurf.md](docs/windsurf.md) |
| **Gemini CLI** | [gemini-cli.md](docs/gemini-cli.md) |
| **OpenCode** | [opencode.md](docs/opencode.md) |
| **Aider** | [aider.md](docs/aider.md) |

---

## 💬 사용법

```
"Kubernetes 배포 관련 스킬 찾아줘"
"PostgreSQL 백업 스킬 있어?"
"CI/CD 파이프라인 구축 관련 스킬은?"
```

---

## 🛡️ 평가 & 보안

| 차원 | 가중치 | 기준 |
|------|:----:|------|
| **커뮤니티** | 0-15 | 스타 수 (로그 스케일) |
| **최신성** | 0-10 | ≤3개월=10, ≤6개월=7, ≤1년=4 |
| **작성자 신뢰** | 0-15 | 인증 조직+5, 알려진 게시자+5 |
| **관련성** | 0-30 | 키워드 일치율 × 30 |
| **보안** | 0-20 | 깨끗함=20, 경고=10, **심각=자동 거부** |

---

## 👥 저자 / 📄 라이선스

**jasonanewcoder, Claude Code, DeepSeek** · MIT — [LICENSE](LICENSE) 참조
