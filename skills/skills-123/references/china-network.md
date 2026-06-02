# China / Restricted Network Setup

Guide for using skills-123 in mainland China or behind restrictive firewalls.

## Quick Start

```bash
# Add to ~/.bashrc, ~/.zshrc, or set per-session:
export CHINA_MODE=1
```

That's it. With `CHINA_MODE=1`, all scripts automatically use mirror chains and China-friendly alternatives.

## What Gets Blocked in China

| Service | Status | Impact |
|---------|--------|--------|
| `raw.githubusercontent.com` | ❌ Blocked (DNS + IP) | Can't fetch SKILL.md content |
| `api.github.com` | ⚠️ Throttled, intermittent | Slow search, rate-limited |
| `lite.duckduckgo.com` | ❌ Blocked | DDG search unavailable |
| `github.com` | ⚠️ Severely throttled (~50KB/s) | Slow git clone |
| `www.bing.com` / `cn.bing.com` | ✅ Accessible | Search works |
| `ghproxy.com` mirrors | ✅ Usually accessible | Content fetch works |

## How skills-123 Handles This

### Fetch chain (fetch-local.sh)

When `CHINA_MODE=1`, every network request goes through a tiered fallback:

```
raw.githubusercontent.com/OWNER/REPO/REF/FILE
  ├─ [1] Direct                         (fastest, fails in China)
  ├─ [2] raw.ghproxy.com/OWNER/REPO/...  (host-replacement mirror)
  ├─ [3] raw.mghproxy.com/OWNER/REPO/... (alternative mirror)
  └─ [4] ghproxy.com/https://raw...      (prefix-proxy mirror)

api.github.com/repos/OWNER/REPO/...
  ├─ [1] Direct                         (sometimes works)
  ├─ [2] gh.api.99988866.xyz/...        (host-replacement mirror)
  └─ [3] ghproxy.com/https://api...     (prefix-proxy mirror)
```

### Search fallback

```
DDG (lite.duckduckgo.com)
  └─ Blocked → falls back to Bing (www.bing.com → cn.bing.com)
```

### Install acceleration (install-from-github.sh)

```
git clone https://github.com/OWNER/REPO.git
  ├─ [1] Direct
  └─ [2] https://ghproxy.com/https://github.com/OWNER/REPO.git
```

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHINA_MODE` | `0` | Set to `1` to enable all built-in mirrors |
| `SKILLS_MIRROR_RAW` | (auto) | Custom host for raw.githubusercontent.com |
| `SKILLS_MIRROR_API` | (auto) | Custom host for api.github.com |
| `SKILLS_MIRROR_GIT` | (auto) | Custom prefix for git clone URLs |
| `SKILLS_SEARCH_BING` | `0` | Set to `1` to always use Bing search |
| `GITHUB_TOKEN` | — | GitHub PAT for 5000 req/hr vs 60 |
| `https_proxy` | — | Standard proxy (respected by curl) |
| `all_proxy` | — | Standard proxy (respected by curl) |

### Using a Local Proxy

If you run a local proxy (Clash, V2Ray, Shadowsocks, etc.):

```bash
export https_proxy="http://127.0.0.1:7890"
export all_proxy="socks5://127.0.0.1:7891"
```

Curl (used by fetch-local.sh and install-from-github.sh) respects these env vars automatically. With a working proxy, you don't need `CHINA_MODE` — direct GitHub access works through the proxy.

### Custom Mirrors

If the built-in mirrors go down or you prefer different ones:

```bash
# Host replacement (cleaner — your mirror must have the same path structure as GitHub)
export SKILLS_MIRROR_RAW="raw.ghproxy.com"      # https://raw.ghproxy.com/OWNER/REPO/REF/FILE
export SKILLS_MIRROR_API="gh.api.99988866.xyz"  # https://gh.api.99988866.xyz/repos/...

# Or prefix proxy (works with any mirror that proxies full URLs)
export SKILLS_MIRROR_GIT="https://ghproxy.com/"  # prepends to github.com URLs
```

### Persistent Configuration

Create `~/.claude/skills/skills-123/config.sh`:

```bash
#!/bin/bash
# skills-123 China config — sourced automatically if present
export CHINA_MODE=1
export GITHUB_TOKEN="ghp_your_token_here"     # optional
# export https_proxy="http://127.0.0.1:7890"  # optional
```

Then in your `~/.bashrc` or `~/.zshrc`:

```bash
[ -f ~/.claude/skills/skills-123/config.sh ] && source ~/.claude/skills/skills-123/config.sh
```

## Built-in Mirror Sources

The following public mirrors are tried automatically when `CHINA_MODE=1`:

### Raw content mirrors (raw.githubusercontent.com)

| Mirror | URL Pattern | Status |
|--------|-------------|--------|
| ghproxy.com (host) | `https://raw.ghproxy.com/{owner}/{repo}/{ref}/{file}` | Community-maintained |
| mghproxy.com | `https://raw.mghproxy.com/{owner}/{repo}/{ref}/{file}` | Community-maintained |
| ghproxy.com (prefix) | `https://ghproxy.com/https://raw.githubusercontent.com/{owner}/{repo}/{ref}/{file}` | Community-maintained |

### API mirrors (api.github.com)

| Mirror | URL Pattern | Status |
|--------|-------------|--------|
| 99988866.xyz | `https://gh.api.99988866.xyz/{path}` | Community-maintained |
| ghproxy.com (prefix) | `https://ghproxy.com/https://api.github.com/{path}` | Community-maintained |

> **Note:** Community mirrors are maintained by volunteers. If a mirror is down, the script automatically tries the next one. If all mirrors fail, it falls back to degraded mode (search snippet + README).

## Verify Your Setup

Run the connectivity check:

```bash
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh check
```

Expected output when everything works via mirrors:

```json
{
  "ok": true,
  "status": "all_ok",
  "results": "raw.githubusercontent.com(direct): FAIL, api.github.com(direct): FAIL, lite.duckduckgo.com: FAIL, bing.com: OK | mirrors: raw.ghproxy.com: OK, gh.api.99988866.xyz: OK",
  "hint": "Tip: export CHINA_MODE=1 to enable GitHub mirrors automatically"
}
```

## Troubleshooting

### "All mirrors failed"

1. Check your internet connection: `curl -I https://www.bing.com`
2. Try with a proxy: `export https_proxy="http://127.0.0.1:7890"`
3. Manual test a mirror: `curl -I https://raw.ghproxy.com/travisvn/awesome-claude-skills/main/README.md`
4. The mirror list may be outdated — set `SKILLS_MIRROR_RAW` to a known-working mirror

### "GitHub API rate limit exceeded"

Set a GitHub personal access token:
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```
Without a token: 60 requests/hour. With a token: 5000 requests/hour.

### "Tarball download failed"

The GitHub API tarball endpoint is often slow in China. Try:
1. `export CHINA_MODE=1` (enables git clone via mirror)
2. Or set up a proxy: `export https_proxy="http://127.0.0.1:7890"`

## Recommended Setup by Scenario

### Scenario A: You have a proxy (Clash, V2Ray, etc.)

```bash
export https_proxy="http://127.0.0.1:7890"
# No need for CHINA_MODE — proxy handles all GitHub access
```

### Scenario B: No proxy, direct connection

```bash
export CHINA_MODE=1
# Relies on public GitHub mirrors
```

### Scenario C: No proxy + frequent use

```bash
export CHINA_MODE=1
export GITHUB_TOKEN="ghp_xxx"  # Get from github.com → Settings → Developer settings → PAT
# Higher API rate limits + mirror fallback
```

### Scenario D: Corporate firewall / VPN required

```bash
export https_proxy="http://corporate-proxy:8080"
export CHINA_MODE=1              # extra safety if proxy has issues
```
