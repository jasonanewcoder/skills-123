# skills-123

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/%E4%BE%9D%E5%AD%98-%E3%82%BC%E3%83%AD-brightgreen.svg" alt="依存: ゼロ">
  <img src="https://img.shields.io/badge/%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3-%E3%82%B9%E3%82%AD%E3%83%A3%E3%83%B3%20%2B%20%E8%87%AA%E5%8B%95%E6%8B%92%E5%90%A6-red.svg" alt="セキュリティ: スキャン + 自動拒否">
</p>

<p align="center">
  <strong>一は二を生み、二は三を生み、三は万物を生む</strong><br>
  — 老子
</p>

<p align="center">
  <strong>AI コーディングエージェントのための会話内スキルアドバイザー。</strong><br>
  GitHub から最適なコミュニティスキルを自動的に発見、評価、インストールします——<br>
  スキルを事前設定する必要はもうありません。
</p>

<p align="center">
  🌐 他の言語で読む: <a href="README.md">English</a> | <a href="README.zh.md">简体中文</a> | <a href="README.ko.md">한국어</a> | <a href="README.es.md">Español</a>
</p>

---

## ✨ 機能概要

```
あなた：「PostgreSQL のバックアップを S3 に設定するには？」
          │
          ▼
┌─────────────────────────────────┐
│  🔍 skills-123-suggest          │  パッシブスカウト
│  「GitHub に関連スキルがあります。  │  クイック検索 → 提案
│   最適なものを探しましょうか？」    │
└──────────────┬──────────────────┘
               │  あなた：「はい！」
               ▼
┌─────────────────────────────────┐
│  🧠 skills-123（5フェーズ）       │  アクティブエンジン
│                                  │
│  🔎 検索   4ソース並列            │
│  📊 評価   5次元スコア            │
│  📋 表示   トップ3をテーブルで     │
│  📦 インストール  セキュリティ検査 │
│  ✅ 検証   キャッシュに記録       │
└──────────────────────────────────┘
```

---

## 🚀 インストール

```bash
git clone https://github.com/jasonanewcoder/skills-123.git
cd skills-123
bash install.sh
```

Claude Code を再起動すると、`skills-123` と `skills-123-suggest` が利用可能になります。

### 他のエージェントへのインストール

| Agent | ガイド |
|-------|-------|
| **OpenAI Codex** | [codex.md](docs/codex.md) |
| **Cursor** | [cursor.md](docs/cursor.md) |
| **VSCode / Copilot** | [vscode.md](docs/vscode.md) |
| **Coze（扣子）** | [coze.md](docs/coze.md) |
| **Windsurf** | [windsurf.md](docs/windsurf.md) |
| **Gemini CLI** | [gemini-cli.md](docs/gemini-cli.md) |
| **OpenCode** | [opencode.md](docs/opencode.md) |
| **Aider** | [aider.md](docs/aider.md) |

---

## 💬 使い方

```
"Kubernetes のデプロイに関するスキルを探して"
"PostgreSQL のバックアップのスキルはある？"
"CI/CD パイプラインを構築したい——関連スキルは？"
```

---

## 🛡️ スコアリング & セキュリティ

| 次元 | 重み | 基準 |
|------|:----:|------|
| **コミュニティ** | 0-15 | スター数（対数スケール） |
| **最新性** | 0-10 | ≤3ヶ月=10, ≤6ヶ月=7, ≤1年=4 |
| **作者の信頼** | 0-15 | 認証済み組織+5, 既知の公開者+5 |
| **関連性** | 0-30 | キーワード一致率 × 30 |
| **セキュリティ** | 0-20 | クリーン=20, 警告=10, **重大=自動拒否** |

---

## 👥 作者 / 📄 ライセンス

**jasonanewcoder, Claude Code, DeepSeek** · MIT — [LICENSE](LICENSE) 参照
