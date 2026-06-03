# China / Restricted Network Setup

Guide for using skills-123 in mainland China or behind restrictive firewalls.

## Quick Start

**No configuration needed.** skills-123 auto-detects your network environment:

1. At startup, it probes `raw.githubusercontent.com` vs `cn.bing.com`
2. If GitHub is unreachable but Bing works → auto-enables CHINA_MODE=1
3. Result is cached for 24 hours

To override auto-detection:
```bash
export CHINA_MODE=1   # force-enable
export CHINA_MODE=0   # force-disable
```

## What Gets Blocked in China

| Service | Status | Impact |
|---------|--------|--------|
| `raw.githubusercontent.com` | ❌ Blocked (DNS + IP) | Can't fetch SKILL.md content |
| `api.github.com` | ⚠️ Throttled, intermittent | Slow search, rate-limited |
| `lite.duckduckgo.com` | ❌ Blocked | DDG search unavailable |
| `github.com` | ⚠️ Severely throttled (~50KB/s) | Slow git clone |
| `www.bing.com` / `cn.bing.com` | ✅ Accessible | Search works |

## How skills-123 Handles This

### Fetch chain (fetch-local.sh) — Dynamic Mirror Discovery

When `CHINA_MODE=1`, every network request uses this fallback:

```
raw.githubusercontent.com/OWNER/REPO/REF/FILE
  ├─ [1] Direct access                                      (fastest, works with proxy)
  ├─ [2] User-configured mirror (SKILLS_MIRROR_RAW)         (if set)
  ├─ [3] Dynamically discovered mirrors (6h cache)          ★ NEW
  │     ├─ Search Bing for current mirror lists
  │     ├─ Fetch top result pages to find mirror URLs
  │     ├─ Test each candidate by fetching a known file
  │     └─ Use first working mirror
  └─ [4] Degraded mode (search snippets only)               (last resort)
```

**Mirrors are NOT hardcoded.** Community mirrors (ghproxy.com, etc.) come and go — the script searches for what works *now*, not what worked when the script was written. Discovered mirrors are cached for 6 hours.

### Search fallback

```
DDG (lite.duckduckgo.com)
  └─ Blocked → falls back to Bing (www.bing.com → cn.bing.com)
```

### Install acceleration (install-from-github.sh)

```
git clone https://github.com/OWNER/REPO.git
  ├─ [1] Direct
  └─ [2] Dynamically discovered git mirror (if available)
```

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHINA_MODE` | auto | Auto-detected; set to `0` or `1` to override |
| `SKILLS_MIRROR_RAW` | (discovered) | Custom host for raw.githubusercontent.com (overrides discovery) |
| `SKILLS_MIRROR_API` | (discovered) | Custom host for api.github.com (overrides discovery) |
| `SKILLS_MIRROR_GIT` | (discovered) | Custom prefix for git clone URLs (overrides discovery) |
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
export SKILLS_MIRROR_RAW="your-mirror.com"       # https://your-mirror.com/OWNER/REPO/REF/FILE
export SKILLS_MIRROR_API="your-mirror.com"       # https://your-mirror.com/repos/...

# Or prefix proxy (works with any mirror that proxies full URLs)
export SKILLS_MIRROR_GIT="https://your-proxy.com/"  # prepends to github.com URLs
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

## Mirror Discovery

Instead of a hardcoded mirror list, skills-123 **searches for working mirrors in real-time**:

```bash
# Manually discover currently-working mirrors:
bash ~/.claude/skills/skills-123/scripts/fetch-local.sh discover-mirrors
```

Output:
```json
{
  "raw": [
    {"host": "example.com", "style": "host-replace"},
    {"host": "proxy.example.org", "style": "prefix-proxy"}
  ],
  "api": [
    {"host": "example.com", "style": "host-replace"}
  ]
}
```

**How discovery works:**
1. Searches Bing/DDG for "github mirror proxy 镜像站 加速" 
2. Fetches top result pages to find embedded mirror URLs
3. Tests each candidate by fetching a known file (`travisvn/awesome-claude-skills`)
4. Uses the first working mirror; caches results for 6 hours

**If no mirror is found:** The script falls back to "degraded mode" (search result snippets only) and suggests setting `SKILLS_MIRROR_RAW` manually.

> **Why dynamic?** Community mirrors (`ghproxy.com`, `raw.ghproxy.com`, etc.) are maintained by volunteers. Their domains expire, get blocked, or go offline without notice. Dynamic discovery ensures you always use what's available *now*.

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
  "results": "raw.githubusercontent.com(direct): FAIL, api.github.com(direct): FAIL, lite.duckduckgo.com: FAIL, bing.com: OK | mirrors: discovered-host.com: OK",
  "hint": "Tip: export CHINA_MODE=1 to enable GitHub mirrors automatically"
}
```

## Troubleshooting

### "All mirrors failed"

1. Check your internet connection: `curl -I https://www.bing.com`
2. Try manual discovery: `bash ~/.claude/skills/skills-123/scripts/fetch-local.sh discover-mirrors`
3. Try with a proxy: `export https_proxy="http://127.0.0.1:7890"`
4. Set a known-working mirror manually: `export SKILLS_MIRROR_RAW="your-mirror.com"`
5. Clear the mirror cache to force fresh discovery: `rm ~/.claude/skills/skills-123/cache/mirrors.json`

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
# No config needed — auto-detected
# If auto-detection misses, force it:
export CHINA_MODE=1
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
