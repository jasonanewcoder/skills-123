# skills-123

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  <img src="https://img.shields.io/badge/dependencias-cero-brightgreen.svg" alt="Dependencias: Cero">
  <img src="https://img.shields.io/badge/seguridad-escaneo%20%2B%20rechazo%20autom%C3%A1tico-red.svg" alt="Seguridad: Escaneo + Rechazo automático">
</p>

<p align="center">
  <strong>Uno produce dos, dos produce tres, tres produce todas las cosas.</strong><br>
  — Tao Te Ching
</p>

<p align="center">
  <strong>El asesor de habilidades en conversación para agentes de codificación IA.</strong><br>
  Descubre, evalúa e instala automáticamente las mejores habilidades comunitarias de GitHub —<br>
  para que nunca más tengas que preconfigurar habilidades.
</p>

<p align="center">
  🌐 Leer en otros idiomas: <a href="README.md">English</a> | <a href="README.zh.md">简体中文</a> | <a href="README.ja.md">日本語</a> | <a href="README.ko.md">한국어</a>
</p>

---

## ✨ Qué hace

```
Tú: "¿Cómo configuro backups de PostgreSQL a S3?"
          │
          ▼
┌─────────────────────────────────┐
│  🔍 skills-123-suggest          │  Explorador pasivo
│  "Hay habilidades comunitarias   │  Búsqueda rápida → sugerencia
│   en GitHub. ¿Busco la mejor?"   │
└──────────────┬──────────────────┘
               │  Tú: "¡Sí!"
               ▼
┌─────────────────────────────────┐
│  🧠 skills-123（5 fases）        │  Motor activo
│  🔎 Buscar → 📊 Evaluar          │
│  → 📋 Presentar → 📦 Instalar    │
│  → ✅ Verificar                  │
└──────────────────────────────────┘
```

---

## 🚀 Instalación

```bash
git clone https://github.com/jasonanewcoder/skills-123.git
cd skills-123
bash install.sh
```

Reinicia Claude Code. Dos nuevas habilidades estarán disponibles: `skills-123` y `skills-123-suggest`.

### Instalar en otros agentes

| Agent | Guía |
|-------|------|
| **OpenAI Codex** | [codex.md](docs/codex.md) |
| **Cursor** | [cursor.md](docs/cursor.md) |
| **VSCode / Copilot** | [vscode.md](docs/vscode.md) |
| **Coze (扣子)** | [coze.md](docs/coze.md) |
| **Windsurf** | [windsurf.md](docs/windsurf.md) |
| **Gemini CLI** | [gemini-cli.md](docs/gemini-cli.md) |
| **OpenCode** | [opencode.md](docs/opencode.md) |
| **Aider** | [aider.md](docs/aider.md) |

---

## 💬 Uso

```
"Encuéntrame habilidades para desplegar Kubernetes"
"¿Hay buenas habilidades para backups de PostgreSQL?"
"Busca habilidades para pipelines CI/CD"
```

---

## 🛡️ Puntuación & Seguridad

| Dimensión | Peso | Criterio |
|-----------|:----:|----------|
| **Comunidad** | 0-15 | Estrellas (escala logarítmica) |
| **Actualidad** | 0-10 | ≤3 meses=10, ≤6m=7, ≤1a=4 |
| **Confianza** | 0-15 | Org verificada +5, publicador conocido +5 |
| **Relevancia** | 0-30 | Coincidencia de palabras clave × 30 |
| **Seguridad** | 0-20 | Limpio=20, avisos=10, **crítico=rechazo automático** |

---

## 👥 Autores / 📄 Licencia

**jasonanewcoder, Claude Code, DeepSeek** · MIT — ver [LICENSE](LICENSE)
