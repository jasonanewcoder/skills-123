# skills-123（一二三）

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/%E4%BE%9D%E8%B5%96-%E9%9B%B6-brightgreen.svg" alt="依赖: 零">
  <img src="https://img.shields.io/badge/%E5%AE%89%E5%85%A8-%E6%89%AB%E6%8F%8F%20%2B%20%E8%87%AA%E5%8A%A8%E6%8B%92%E7%BB%9D-red.svg" alt="安全: 扫描 + 自动拒绝">
</p>

<p align="center">
  <strong>一生二，二生三，三生万物</strong><br>
  — 道德经
</p>

<p align="center">
  <strong>AI 编程助手的对话内技能顾问。</strong><br>
  自动发现、评估并安装 GitHub 上最优质的社区技能——<br>
  你再也不需要手动预配技能了。
</p>

<p align="center">
  🌐 阅读其他语言：<a href="README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.ko.md">한국어</a> | <a href="README.es.md">Español</a>
</p>

---

## ✨ 它能做什么

```
你："怎么把 PostgreSQL 备份到 S3？"
          │
          ▼
┌─────────────────────────────────┐
│  🔍 skills-123-suggest          │  被动侦察——注意到"PostgreSQL"+"S3"
│  "GitHub 上有相关的社区技能，      │  快速 WebSearch，然后提醒你
│   要我帮你找最好的吗？"            │
└──────────────┬──────────────────┘
               │  你："好！"
               ▼
┌─────────────────────────────────┐
│  🧠 skills-123（5 阶段流水线）    │  主动引擎——全流程
│                                  │
│  🔎 搜索   4 源并行               │  GitHub + 注册中心 + Awesome List
│  📊 评估   5 维评分               │  社区 · 时效 · 作者 · 相关度 · 安全
│  📋 展示   Top 3，表格对比        │  排名 + 安全标记
│  📦 安装   安全扫描先行            │  22 关键模式自动拒绝
│  ✅ 验证   缓存记录               │  安装完成，即刻可用！
└──────────────────────────────────┘
          │
          ▼
你："postgres-s3-backup 技能已安装，开始用吧！"
```

---

## 🏗️ 架构

```
skills-123/
├── skills/
│   ├── skills-123/              🔍 主动技能：搜索 → 评估 → 安装
│   │   ├── SKILL.md             核心技能（自包含指令）
│   │   ├── scripts/             Shell 加速脚本
│   │   ├── references/          深度文档（按需加载）
│   │   └── cache/               运行缓存（自动创建）
│   └── skills-123-suggest/      💡 被动技能：轻量侦察，从不安装
│       └── SKILL.md
├── docs/                        📖 各平台安装指南
├── install.sh                   ⚡ 一键安装
├── LICENSE                      MIT
└── README.md
```

---

## 🚀 安装

### 前置条件
- **Claude Code** 已安装
- `curl` 和 `git`（macOS/Linux 标配）

### 一键安装

```bash
curl -sL https://raw.githubusercontent.com/jasonanewcoder/skills-123/main/install.sh | bash
```

### 手动安装

```bash
git clone https://github.com/jasonanewcoder/skills-123.git
cd skills-123
bash install.sh
```

重启 Claude Code。两个新技能会出现在可用列表中：
- `skills-123` — 主动搜索引擎
- `skills-123-suggest` — 被动建议侦察兵

### 安装到其他 Agent

skills-123 兼容所有主流 AI 编程助手：

| Agent | 安装指南 | 原生支持 |
|-------|-------|:---:|
| **Claude Code** | *(内置)* | ✅ 完整 |
| **OpenAI Codex** | [codex.md](docs/codex.md) | ✅ SKILL.md |
| **Cursor** | [cursor.md](docs/cursor.md) | ⚠️ MDC 适配 |
| **VSCode / Copilot** | [vscode.md](docs/vscode.md) | ⚠️ 扁平格式 |
| **Coze（扣子）** | [coze.md](docs/coze.md) | ✅ 导入 |
| **Windsurf** | [windsurf.md](docs/windsurf.md) | ✅ SKILL.md |
| **Gemini CLI** | [gemini-cli.md](docs/gemini-cli.md) | ✅ SKILL.md |
| **OpenCode** | [opencode.md](docs/opencode.md) | ✅ SKILL.md |
| **Aider** | [aider.md](docs/aider.md) | ⚠️ 纯文本 |

---

## 💬 使用方式

### 主动搜索

自然地提问——skills-123 自动触发：

```
"帮我找一下 Kubernetes 部署相关的技能"
"有没有 PostgreSQL 备份的 skill？"
"搜索 React 测试相关的技能"
"我需要搭建 CI/CD 流水线——有相关技能吗？"
```

### 被动建议

当你提到特定技术时，`skills-123-suggest` 会静默检测并提醒你：

> 💡 我发现 GitHub 上有 **Kubernetes** 的社区技能，需要我帮你搜索最好的吗？

---

## 🛡️ 评分与安全

### 5 维质量评分（0-100）

| 维度 | 权重 | 衡量标准 |
|------|:----:|----------|
| **社区** | 0-15 | 星数（对数尺度）— 1000+ 星 = 满分 |
| **时效** | 0-10 | ≤3月=10, ≤6月=7, ≤1年=4, 更旧=1 |
| **作者信任** | 0-15 | 认证组织+5, 知名发布者+5, 5+贡献者+5 |
| **相关度** | 0-30 | 关键词匹配率 × 30 |
| **安全** | 0-20 | 干净=20, 警告=10, **关键问题=自动拒绝** |

### 安全模型

**22 项关键模式**自动拒绝：`curl | sh`、`eval $`、base64 解码管道、`rm -rf /`、反向 Shell、凭证窃取……

**18 项警告模式**标记审查：网络请求、`sudo`、`chmod`、全局包安装、敏感文件访问……

---

## 🔬 为什么选择 skills-123？

| 差异点 | skills-123 | find-skills (Vercel) | superskillret |
|:---|:---:|:---:|:---:|
| **形态** | 原生技能（对话内） | npm CLI (`npx skills`) | Hook + 守护进程（1.4GB） |
| **外部依赖** | **零**（curl + git） | Node.js / npm | Python + ONNX |
| **触发方式** | **双模**：被动 + 主动 | 手动（CLI 命令） | 自动（每次 prompt） |
| **搜索源** | 4 路并行 | skills.sh 市场 | 16K 向量索引 |
| **质量评分** | 5 维透明 | 无 | 余弦相似度（黑盒） |
| **安全扫描** | **22 关键 + 18 警告** | 无 | 无 |

> **一句话：** find-skills 是技能市场的搜索栏，superskillret 是重型的后台推荐引擎，**skills-123 是你的对话内技能顾问**——原生体验，零依赖，安全第一。

---

## 👥 作者

**jasonanewcoder, Claude Code, DeepSeek**

## 📄 许可证

MIT — 详见 [LICENSE](LICENSE)
