#!/bin/bash
#===============================================================================
# fetch-local.sh — Local curl fallback for WebFetch/WebSearch
#
# Bypasses claude.ai proxy entirely. Uses local machine's network stack
# to fetch content from GitHub (raw, API) and search the web via DuckDuckGo.
#
# Usage:
#   fetch-local.sh raw     <owner/repo> [ref] [file]    # raw.githubusercontent.com
#   fetch-local.sh api     <owner/repo> <file-path>      # api.github.com (base64 decode)
#   fetch-local.sh skill   <owner/repo>                  # multi-tier fetch for SKILL.md
#   fetch-local.sh search  "keywords"                    # GitHub repo search (no auth)
#   fetch-local.sh ddg     "search terms"                # DuckDuckGo Lite web search
#   fetch-local.sh repo    <owner/repo>                  # repo metadata (stars, desc)
#   fetch-local.sh awesome                               # fetch awesome-list READMEs
#   fetch-local.sh check                                # connectivity self-test
#
# Output: JSON on stdout — {ok: true, content: ...} or {ok: false, error: "..."}
#
# Respects GITHUB_TOKEN env var for higher rate limits (5000 vs 60 req/hr).
#===============================================================================

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
TIMEOUT=15
RETRIES=2
USER_AGENT="skills-123-fallback/1.0"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# ── China / Mirror network config ───────────────────────────────────────────
# CHINA_MODE is auto-detected by default (probes network connectivity).
# Set CHINA_MODE=0 or 1 explicitly to override auto-detection.
# Or set individual mirror vars for fine-grained control.
# curl already respects https_proxy / all_proxy env vars — set them if you use a proxy.
#
#   CHINA_MODE=1                              # force-enable mirrors + Bing search
#   CHINA_MODE=0                              # force-disable (skip detection)
#   SKILLS_MIRROR_RAW="your-mirror.com"        # host-replacement for raw.githubusercontent.com
#   SKILLS_MIRROR_API="your-mirror.com"        # host-replacement for api.github.com
#   SKILLS_MIRROR_GIT="https://your-proxy.com/" # prefix for git clone URLs
#   SKILLS_SEARCH_BING=1                      # force Bing search

# Save whether user explicitly set CHINA_MODE before we apply defaults
if [ -n "${CHINA_MODE+x}" ]; then
    CHINA_MODE_EXPLICIT=1   # user set it — don't auto-detect
else
    CHINA_MODE_EXPLICIT=0   # not set — auto-detect
fi
CHINA_MODE="${CHINA_MODE:-0}"
SKILLS_MIRROR_RAW="${SKILLS_MIRROR_RAW:-}"
SKILLS_MIRROR_API="${SKILLS_MIRROR_API:-}"
SKILLS_MIRROR_GIT="${SKILLS_MIRROR_GIT:-}"
SKILLS_SEARCH_BING="${SKILLS_SEARCH_BING:-0}"

# Built-in mirror candidates — removed. Mirrors are community-maintained and expire.
# When CHINA_MODE=1, use discover_mirrors() below to find currently-working mirrors.
# Users can also set their own: SKILLS_MIRROR_RAW, SKILLS_MIRROR_API, SKILLS_MIRROR_GIT.

# ── Mirror cache config ──────────────────────────────────────────────────
MIRROR_CACHE_DIR="${HOME}/.claude/skills/skills-123/cache"
MIRROR_CACHE="${MIRROR_CACHE_DIR}/mirrors.json"
MIRROR_CACHE_TTL=21600  # 6 hours — mirrors are ephemeral; re-discover often
NETWORK_PROFILE="${MIRROR_CACHE_DIR}/network-profile.json"
NETWORK_PROFILE_TTL=86400  # 24 hours — network environment changes slowly
RAW_GITHUB_OK="unknown"

# ── Runtime failure tracking ──────────────────────────────────────────────
# RAW_FAILURE_COUNT prevents a single transient empty-body response from
# poisoning all subsequent raw-tier attempts within one invocation.
# Only mark raw as unavailable after 3 consecutive connection-level failures.
RAW_FAILURE_COUNT=0
RAW_FAILURE_THRESHOLD=3

# ── Auto-detect restricted network ──────────────────────────────────────
# If the user hasn't explicitly set CHINA_MODE, probe the network to
# determine if we're behind a firewall that blocks raw.githubusercontent.com
# but allows Bing (typical of mainland China / restricted networks).
# Detection result is cached for 24h to avoid probing every invocation.
#
# Priority: user-set CHINA_MODE → cached detection → live probe → default off
auto_detect_network() {
    # User explicitly set CHINA_MODE — respect their choice, skip detection
    if [ "$CHINA_MODE_EXPLICIT" = "1" ]; then
        return 0
    fi

    # Check cache
    if [ -f "$NETWORK_PROFILE" ]; then
        local cache_age
        cache_age=$(($(timestamp_now) - $(timestamp_from_file "$NETWORK_PROFILE")))
        if [ "${cache_age:-99999}" -lt "$NETWORK_PROFILE_TTL" ] 2>/dev/null; then
            # Read cached china_mode with grep (avoids Python Windows path issues)
            local cached_mode
            cached_mode=$(grep -o '"china_mode":[0-9]*' "$NETWORK_PROFILE" 2>/dev/null | grep -o '[0-9]*' || echo "0")
            RAW_GITHUB_OK=$(grep -o '"raw_ok":\(true\|false\)' "$NETWORK_PROFILE" 2>/dev/null | sed 's/.*://' || echo "unknown")
            [ -n "$RAW_GITHUB_OK" ] || RAW_GITHUB_OK="unknown"
            if [ "$cached_mode" = "1" ]; then
                CHINA_MODE=1
                SKILLS_SEARCH_BING=1
            fi
            return 0
        fi
    fi

    # ── Live probe (5s timeout each, one retry, total max ~12s) ─────────
    local raw_ok=false
    local bing_ok=false

    # Probe 1: raw.githubusercontent.com (test known file, same URL fetch_check uses)
    local raw_code
    raw_code=$(curl -sS --max-time 5 --connect-timeout 3 --retry 1 --retry-delay 1 \
        -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null || echo "000")
    if [ "$raw_code" = "200" ]; then
        raw_ok=true
    fi
    RAW_GITHUB_OK="$raw_ok"

    # Probe 2: cn.bing.com (China-accessible search engine)
    local bing_code
    bing_code=$(curl -sS --max-time 5 --connect-timeout 3 \
        -o /dev/null -w "%{http_code}" \
        "https://cn.bing.com/" 2>/dev/null || echo "000")
    if [ "$bing_code" = "200" ] || [ "$bing_code" = "301" ] || [ "$bing_code" = "302" ]; then
        bing_ok=true
    fi

    # ── Heuristic: GitHub unreachable + Bing reachable = restricted network ──
    if ! $raw_ok && $bing_ok; then
        CHINA_MODE=1
        SKILLS_SEARCH_BING=1
    fi

    # ── Cache the result ─────────────────────────────────────────────────
    mkdir -p "$MIRROR_CACHE_DIR" 2>/dev/null || true
    local _ts
    _ts=$(iso_timestamp)
    printf '{"china_mode":%s,"raw_ok":%s,"bing_ok":%s,"detected_at":"%s"}\n' \
        "$CHINA_MODE" "$raw_ok" "$bing_ok" "$_ts" > "$NETWORK_PROFILE" 2>/dev/null || true
}

# Auto-detect will be called after Python is available (see below)

# ── Dynamic mirror discovery ─────────────────────────────────────────────
# When CHINA_MODE=1 and direct GitHub access fails, this function searches the
# web for currently-available GitHub mirrors, tests them, and returns working URLs.
# Results are cached for MIRROR_CACHE_TTL seconds to avoid re-searching every call.
#
# Output: one mirror per line in "host|style" format (e.g. "example.com|host-replace")
discover_mirrors() {
    local mirror_type="$1"  # "raw" or "api"

    # ── 1. Check cache ──────────────────────────────────────────────────
    if [ -f "$MIRROR_CACHE" ]; then
        local cache_age
        cache_age=$(($(timestamp_now) - $(timestamp_from_file "$MIRROR_CACHE")))
        if [ "${cache_age:-99999}" -lt "$MIRROR_CACHE_TTL" ] 2>/dev/null; then
            # Read cached mirrors for this type
            local cached
            cached=$($PYTHON -c "
import sys, json, os
try:
    with open(os.environ.get('SKILLS_MIRROR_CACHE','')) as f:
        data = json.load(f)
    for m in data.get(os.environ.get('SKILLS_MIRROR_TYPE',''), []):
        sys.stdout.write(m['host'] + '|' + m.get('style','host-replace') + '\n')
except: pass
" 2>/dev/null)
            if [ -n "$cached" ]; then
                echo "$cached"
                return 0
            fi
        fi
    fi

    # ── 2. Search for current mirrors via Bing ──────────────────────────
    local search_query
    if [ "$mirror_type" = "raw" ]; then
        search_query="raw.githubusercontent.com github mirror proxy 镜像站 加速 2024 2025"
    else
        search_query="api.github.com github mirror proxy 镜像站 加速 2024 2025"
    fi

    # Use Bing (works in China) — fetch raw HTML for parsing
    local encoded_query
    encoded_query=$(echo "$search_query" | $PYTHON -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))" 2>/dev/null)
    local bing_html
    bing_html=$(fetch_url "https://cn.bing.com/search?q=${encoded_query}&count=10")
    if [ -z "$bing_html" ]; then
        bing_html=$(fetch_url "https://www.bing.com/search?q=${encoded_query}&count=10")
    fi
    if [ -z "$bing_html" ]; then
        return 1
    fi

    # ── 3. Extract mirror candidates from search result pages & test ────
    # We also fetch the top 2 result pages directly to find mirror URLs
    # embedded in those pages
    local result_urls
    result_urls=$(echo "$bing_html" | $PYTHON -c "
import sys, re, json
html = sys.stdin.read()
# Extract href URLs from Bing result links
urls = re.findall(r'<a[^>]+href=[\"']([^\"']+)[\"'][^>]*>', html)
# Filter: keep only non-Bing, non-ad URLs that look like real pages
filtered = []
for u in urls:
    u = u.strip()
    if not u or u.startswith('#') or u.startswith('javascript:'): continue
    if 'bing.com' in u or 'microsoft.com' in u or 'go.microsoft.com' in u: continue
    if u not in filtered:
        filtered.append(u)
print(json.dumps(filtered[:5]))
" 2>/dev/null || echo '[]')

    # Merge: Bing HTML + top result pages → extract hostnames → test
    local discovered
    discovered=$(echo "$bing_html" | SKILLS_MIRROR_TYPE="$mirror_type" SKILLS_MIRROR_CACHE="$MIRROR_CACHE" RESULT_URLS="$result_urls" $PYTHON -c "
import sys, re, json, urllib.request, ssl, os, time

mirror_type = os.environ.get('SKILLS_MIRROR_TYPE', 'raw')
cache_file = os.environ.get('SKILLS_MIRROR_CACHE', '')

# Combine text sources: Bing HTML + top result page bodies
text_sources = [sys.stdin.read()]

# Fetch top result pages to look for mirror URLs in their content
try:
    result_urls = json.loads(os.environ.get('RESULT_URLS', '[]'))
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    for url in result_urls[:3]:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'skills-123/1.0'})
            resp = urllib.request.urlopen(req, timeout=6, context=ctx)
            body = resp.read().decode('utf-8', errors='replace')[:50000]
            text_sources.append(body)
        except:
            pass
except:
    pass

combined_text = '\n'.join(text_sources)

# ── Extract candidate hostnames ──────────────────────────────────────────
# Pattern 1: GitHub raw content structure → https://HOST/owner/repo/ref/file
github_raw = re.findall(
    r'https?://([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}/'
    r'[\w.\-]+/[\w.\-]+/(?:main|master|HEAD|raw|blob)/',
    combined_text, re.IGNORECASE
)

# Pattern 2: Explicit mirror URLs in lists/tables (common format on mirror-list pages)
# e.g. \"| raw.xxx.com | ...\" or \"- https://raw.xxx.com\" or \"raw.xxx.com\"
mirror_mentions = re.findall(
    r'(?:mirror|proxy|镜像|加速|cdn|ghproxy|fastgit)[^>]*?'
    r'(?:https?://)?([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,})'
    r'(?:/\S*)?',
    combined_text, re.IGNORECASE
)

# Pattern 3: Any URL on the page that looks like it could proxy GitHub
all_urls = re.findall(r'https?://([a-zA-Z0-9][^/\s<>\"\'\]\)]+)/', combined_text)

candidate_hosts = set()
skip_domains = {
    'github.com', 'raw.githubusercontent.com', 'api.github.com', 'gist.githubusercontent.com',
    'bing.com', 'cn.bing.com', 'www.bing.com', 'google.com', 'microsoft.com',
    'github.io', 'w3.org', 'schema.org', 'twitter.com', 'facebook.com', 'youtube.com',
    'npmjs.com', 'pypi.org', 'stackoverflow.com', 'medium.com', 'reddit.com',
    'linkedin.com', 'instagram.com', 'wikipedia.org', 'baidu.com', 'zhihu.com',
    'csdn.net', 'jianshu.com', 'juejin.cn', 'segmentfault.com', 'cloudflare.com',
}

for host in github_raw + mirror_mentions + all_urls:
    host = host.strip().lower()
    if not host: continue
    # Remove trailing punctuation
    host = host.rstrip('.,;:!?)]}>\"\'')
    # Skip known non-mirror domains
    if host in skip_domains: continue
    if any(skip in host for skip in ['bing.com', 'google.com', 'microsoft.com', 'github.com/blog']):
        continue
    # Must be a plausible hostname
    if '.' not in host or len(host) < 4: continue
    if host.startswith('.') or host.startswith('-'): continue
    candidate_hosts.add(host)

# ── Test candidates ─────────────────────────────────────────────────────
test_file = 'travisvn/awesome-claude-skills/main/README.md'
test_marker = 'awesome-claude-skills'
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

working = []
for host in list(candidate_hosts)[:20]:  # limit to avoid long discovery
    # Test 1: host-replace style
    try:
        test_url = f'https://{host}/{test_file}'
        req = urllib.request.Request(test_url, headers={'User-Agent': 'skills-123/1.0'})
        resp = urllib.request.urlopen(req, timeout=5, context=ctx)
        body = resp.read().decode('utf-8', errors='replace')
        if len(body) > 200 and test_marker.lower() in body.lower():
            working.append({'host': host, 'style': 'host-replace'})
            continue
    except Exception:
        pass

    # Test 2: prefix-proxy style
    try:
        test_url = f'https://{host}/https://raw.githubusercontent.com/{test_file}'
        req = urllib.request.Request(test_url, headers={'User-Agent': 'skills-123/1.0'})
        resp = urllib.request.urlopen(req, timeout=5, context=ctx)
        body = resp.read().decode('utf-8', errors='replace')
        if len(body) > 200 and test_marker.lower() in body.lower():
            working.append({'host': host, 'style': 'prefix-proxy'})
            continue
    except Exception:
        pass

# ── Cache results ───────────────────────────────────────────────────────
if cache_file:
    os.makedirs(os.path.dirname(cache_file), exist_ok=True)
    existing = {}
    try:
        if os.path.exists(cache_file):
            with open(cache_file) as f:
                existing = json.load(f)
    except: pass
    existing[mirror_type] = working
    existing['updated_at'] = time.strftime('%Y-%m-%dT%H:%M:%S%z')
    try:
        with open(cache_file, 'w') as f:
            json.dump(existing, f, ensure_ascii=False)
    except: pass

# ── Output discovered mirrors ───────────────────────────────────────────
for m in working:
    sys.stdout.write(m['host'] + '|' + m['style'] + '\n')
" 2>/dev/null)

    if [ -n "$discovered" ]; then
        echo "$discovered"
        return 0
    fi

    return 1
}

# ── Python detection ──────────────────────────────────────────────────────
# On Windows (Git Bash) and some Linux distros, python3 may be "python".
# Detect the available interpreter once and use it everywhere.
PYTHON=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    # Verify it's Python 3, not Python 2
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
        PYTHON="python"
    fi
fi

if [ -z "$PYTHON" ]; then
    echo '{"ok":false,"error":"python3/python not found in PATH — required by fetch-local.sh"}' >&2
    exit 1
fi

# ── Cross-platform helpers ────────────────────────────────────────────────
# Bash timestamp: use Python for consistency across BSD/GNU/macOS.
# BSD date uses `-r file`, GNU uses `-d @epoch`. Python is the same everywhere.
timestamp_now() {
    "$PYTHON" -c "import time; print(int(time.time()))"
}

timestamp_from_file() {
    local f="$1"
    "$PYTHON" -c "import os, sys; print(int(os.path.getmtime(sys.argv[1])))" "$f" 2>/dev/null || echo "0"
}

# ISO timestamp for cache files (cross-platform)
iso_timestamp() {
    "$PYTHON" -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S%z'))" 2>/dev/null || echo ""
}

# ── Run network auto-detection (now that Python is available) ──────────
auto_detect_network

# ── Helpers ─────────────────────────────────────────────────────────────────
json_ok() {
    local content="$1"
    content=$(echo "$content" | "$PYTHON" -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    printf '{"ok":true,"content":%s}\n' "$content"
}

json_ok_raw() {
    # For already-JSON content (arrays, objects) — don't double-encode
    local content="$1"
    printf '{"ok":true,"content":%s}\n' "$content"
}

json_err() {
    local msg="$1"
    msg=$(echo "$msg" | "$PYTHON" -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    printf '{"ok":false,"error":%s}\n' "$msg"
}

fetch_url() {
    local url="$1"
    local extra_flags="${2:-}"
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -sS -L \
            --connect-timeout 5 \
            --max-time "$TIMEOUT" \
            --retry "$RETRIES" \
            --retry-delay 1 \
            -H "Authorization: Bearer $GITHUB_TOKEN" \
            -H "User-Agent: $USER_AGENT" \
            -H "Accept: application/vnd.github.v3+json" \
            $extra_flags \
            "$url" 2>/dev/null
    else
        curl -sS -L \
            --connect-timeout 5 \
            --max-time "$TIMEOUT" \
            --retry "$RETRIES" \
            --retry-delay 1 \
            -H "User-Agent: $USER_AGENT" \
            $extra_flags \
            "$url" 2>/dev/null
    fi
}

# ── Mirror helpers ────────────────────────────────────────────────────────────
# Generate mirror URLs for a given original URL and mirror type (raw/api/git)
generate_mirror_urls() {
    local original_url="$1"
    local mirror_type="$2"   # "raw" or "api"

    local mirrors=""
    local host path

    # Determine original host based on type
    if [ "$mirror_type" = "raw" ]; then
        host="raw.githubusercontent.com"
    elif [ "$mirror_type" = "api" ]; then
        host="api.github.com"
    else
        return
    fi

    # Extract path after the host
    path=$(echo "$original_url" | sed "s|https://${host}||")

    # 1. User-configured host-replacement mirror
    local user_mirror_var
    case "$mirror_type" in
        raw) user_mirror_var="SKILLS_MIRROR_RAW" ;;
        api) user_mirror_var="SKILLS_MIRROR_API" ;;
        *) return ;;
    esac
    local user_mirror
    user_mirror=$(eval "printf '%s' \"\${${user_mirror_var}:-}\"")
    if [ -n "$user_mirror" ]; then
        mirrors="${mirrors}https://${user_mirror}${path}
"
    fi

    # 2. Discovered mirrors (when CHINA_MODE=1 or user configured mirrors)
    if [ "$CHINA_MODE" = "1" ] || [ -n "$user_mirror" ]; then
        local discovered
        discovered=$(discover_mirrors "$mirror_type" 2>/dev/null)
        if [ -n "$discovered" ]; then
            while IFS='|' read -r mirror_host mirror_style; do
                [ -z "$mirror_host" ] && continue
                # Skip if same as user-configured mirror
                if [ "$mirror_host" = "$user_mirror" ]; then continue; fi

                if [ "$mirror_style" = "prefix-proxy" ]; then
                    mirrors="${mirrors}https://${mirror_host}/https://${host}${path}
"
                else
                    # Default: host-replace style
                    mirrors="${mirrors}https://${mirror_host}${path}
"
                fi
            done <<< "$discovered"
        fi
    fi

    if [ -n "$mirrors" ]; then
        printf '%s' "$mirrors"
    fi
}

# Fetch a URL with mirror fallback chain (for China/unreachable scenarios)
fetch_url_mirrored() {
    local url="$1"
    local mirror_type="$2"   # "raw" or "api"
    local extra_flags="${3:-}"

    # Try direct first
    local body
    body=$(fetch_url "$url" "$extra_flags") || true
    if [ "$mirror_type" = "raw" ] && [ -z "$body" ]; then
        RAW_FAILURE_COUNT=$((RAW_FAILURE_COUNT + 1))
        if [ "$RAW_FAILURE_COUNT" -ge "$RAW_FAILURE_THRESHOLD" ]; then
            RAW_GITHUB_OK=false
        fi
    elif [ "$mirror_type" = "raw" ] && [ -n "$body" ]; then
        RAW_FAILURE_COUNT=0  # reset on any successful raw fetch
    fi
    if [ -n "$body" ] && ! is_error_page "$body"; then
        echo "$body"
        return 0
    fi

    # Try mirrors
    local mirrors
    mirrors=$(generate_mirror_urls "$url" "$mirror_type")
    if [ -n "$mirrors" ]; then
        while IFS= read -r mirror_url; do
            [ -z "$mirror_url" ] && continue
            body=$(fetch_url "$mirror_url" "$extra_flags") || true
            if [ -n "$body" ] && ! is_error_page "$body"; then
                echo "$body"
                return 0
            fi
        done <<< "$mirrors"
    fi

    return 1
}

is_error_page() {
    local body="$1"
    local body_len=${#body}

    # ── Guard: legitimate SKILL.md content is large; error pages are small ──
    # GitHub 404 pages are ~200 bytes; API error JSON is ~50-150 bytes.
    # Content > 500 bytes that is valid JSON with a short message is the only
    # large-body error pattern. Everything else large is presumed legitimate.
    if [ "$body_len" -gt 500 ]; then
        # Only flag if it's GitHub API error JSON with exactly a message field
        echo "$body" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict) and len(d) <= 3 and 'message' in d:
        msg = str(d.get('message', ''))
        if 'not found' in msg.lower() and len(msg) < 60:
            sys.exit(0)
        if 'API rate limit exceeded' in msg:
            sys.exit(0)
except: pass
sys.exit(1)
" 2>/dev/null && return 0
        return 1
    fi

    # ── Small body: precise patterns only ──────────────────────────────────
    # Match HTTP status lines (GitHub's standard error format)
    echo "$body" | grep -qiE "404: Not Found|400: Invalid|403: Forbidden|401: Unauthorized" && return 0

    # Match GitHub-specific error phrases (not general English substrings)
    echo "$body" | grep -qiE "Repository not found|API rate limit exceeded" && return 0

    # JSON API error: short body, JSON with "message" key
    echo "$body" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict) and 'message' in d:
        msg = str(d.get('message', ''))
        if ('not found' in msg.lower() or 'API rate limit' in msg) and len(d) <= 3:
            sys.exit(0)
except: pass
sys.exit(1)
" 2>/dev/null && return 0

    return 1
}

raw_github_unavailable() {
    [ "${RAW_GITHUB_OK:-unknown}" = "false" ] && \
        [ "$CHINA_MODE" != "1" ] && \
        [ -z "$SKILLS_MIRROR_RAW" ]
}

# ── Tier 1: Raw content from raw.githubusercontent.com ───────────────────────
fetch_raw() {
    local owner_repo="$1"   # e.g. "daymade/claude-code-skills"
    local ref="${2:-main}"  # branch or HEAD
    local file="${3:-SKILL.md}"

    # Check availability once at entry — not after every attempt
    raw_github_unavailable && return 1

    local url="https://raw.githubusercontent.com/${owner_repo}/${ref}/${file}"
    local body
    body=$(fetch_url_mirrored "$url" "raw") || true

    if [ -n "$body" ] && ! is_error_page "$body"; then
        json_ok "$body"
        return 0
    fi

    # If HEAD failed, try main
    if [ "$ref" = "HEAD" ]; then
        url="https://raw.githubusercontent.com/${owner_repo}/main/${file}"
        body=$(fetch_url_mirrored "$url" "raw") || true
        if [ -n "$body" ] && ! is_error_page "$body"; then
            json_ok "$body"
            return 0
        fi
    fi

    # If main failed, try master
    url="https://raw.githubusercontent.com/${owner_repo}/master/${file}"
    body=$(fetch_url_mirrored "$url" "raw") || true
    if [ -n "$body" ] && ! is_error_page "$body"; then
        json_ok "$body"
        return 0
    fi

    return 1
}

# ── Tier 2: GitHub API content fetch (base64 decode) ─────────────────────────
fetch_api() {
    local owner_repo="$1"   # e.g. "daymade/claude-code-skills"
    local file_path="$2"    # e.g. "skills/docx/SKILL.md"

    local url="https://api.github.com/repos/${owner_repo}/contents/${file_path}"
    local body
    body=$(fetch_url_mirrored "$url" "api") || true

    if [ -z "$body" ]; then
        return 1
    fi

    # Check for API-level errors
    local err_msg
    err_msg=$(echo "$body" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict) and 'message' in d:
        print(d['message'])
except: pass
" 2>/dev/null || echo "")

    if [ -n "$err_msg" ]; then
        # Don't print error here — caller handles fallback
        return 1
    fi

    # Decode base64 content
    local content
    content=$(echo "$body" | "$PYTHON" -c "
import sys, json, base64
data = json.load(sys.stdin)
if isinstance(data, dict) and 'content' in data:
    decoded = base64.b64decode(data['content']).decode('utf-8', errors='replace')
    print(decoded)
" 2>/dev/null) || true

    if [ -n "$content" ]; then
        json_ok "$content"
        return 0
    fi

    return 1
}

# ── Skill path ranking ────────────────────────────────────────────────────
# Ranks SKILL.md paths by relevance to SKILLS_QUERY_KEYWORDS (env var).
# Without keywords, sorts by depth then alphabetically (deterministic).
rank_skill_paths() {
    local query="${SKILLS_QUERY_KEYWORDS:-}"
    if [ -z "$query" ]; then
        cat | "$PYTHON" -c "
import sys
paths = [l.strip() for l in sys.stdin if l.strip()]
paths.sort(key=lambda p: (p.count('/'), p.lower()))
for p in paths: print(p)
"
    else
        cat | "$PYTHON" -c "
import sys, os
query = os.environ.get('SKILLS_QUERY_KEYWORDS', '').lower().split()
paths = [l.strip() for l in sys.stdin if l.strip()]

def score(path):
    parts = path.split('/')
    # Extract the directory containing SKILL.md
    skill_dir = ''
    for i, p in enumerate(parts):
        if p == 'SKILL.md' and i > 0:
            skill_dir = parts[i-1].lower()
            break
    if not skill_dir:
        skill_dir = parts[0].lower() if parts else ''

    s = 0
    search_text = skill_dir + ' ' + path.lower().replace('-', ' ').replace('_', ' ')
    for kw in query:
        kw_clean = kw.replace('-', '').replace('_', '')
        if kw in search_text.split():
            s += 2  # exact word match
        elif kw_clean in search_text.replace('-', '').replace('_', ''):
            s += 1  # match ignoring separators
    return (-s, path.count('/'), path.lower())

paths.sort(key=score)
for p in paths: print(p)
"
    fi
}

# ── Validate repo exists ──────────────────────────────────────────────────
validate_repo() {
    local owner_repo="$1"
    local url="https://api.github.com/repos/${owner_repo}"
    local http_code
    http_code=$(curl -sS --max-time 5 --connect-timeout 3 \
        -o /dev/null -w '%{http_code}' \
        -H "User-Agent: $USER_AGENT" \
        ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "$url" 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
        return 0
    fi
    if [ "$http_code" = "404" ]; then
        return 1
    fi
    # Any other code: assume exists (don't block on transient errors)
    return 0
}

# ── Tier 1-3 combined: Multi-tier SKILL.md fetch ─────────────────────────────
# Strategy: when raw.githubusercontent.com is known-unavailable (cached), skip
# slow raw timeouts and go directly to API. When raw status is unknown, try both
# in parallel for speed.
#
# Environment: SKILLS_QUERY_KEYWORDS — space-separated keywords for ranking
#              multiple SKILL.md files in multi-skill repos (optional).
fetch_skill() {
    local owner_repo="$1"
    local ref="${2:-HEAD}"

    # Validate input
    if [ -z "$owner_repo" ] || [ "$owner_repo" = "/" ]; then
        json_err "empty or invalid owner/repo"
        return 1
    fi

    local skill_name
    skill_name=$(echo "$owner_repo" | sed 's|.*/||')
    if [ -z "$skill_name" ]; then
        json_err "could not extract repo name from '${owner_repo}'"
        return 1
    fi

    # Validate repo exists (lightweight HEAD check, avoids wasted API calls)
    if ! validate_repo "$owner_repo"; then
        json_err "repository '${owner_repo}' not found (possibly renamed or moved)"
        return 1
    fi

    local result

    # ── Fast path: raw known-good → try raw first (no rate limit) ────────────
    if [ "${RAW_GITHUB_OK:-unknown}" != "false" ]; then
        # Try root SKILL.md first (most common pattern for single-skill repos)
        result=$(fetch_raw "$owner_repo" "$ref" "SKILL.md") 2>/dev/null && { echo "$result"; return 0; }

        # Try common subpaths (repo name as skill dir)
        for subpath in \
            "skills/${skill_name}/SKILL.md" \
            "skill/SKILL.md" \
            ".claude/skills/${skill_name}/SKILL.md" \
            "skills/default/SKILL.md"; do
            result=$(fetch_raw "$owner_repo" "HEAD" "$subpath") 2>/dev/null && { echo "$result"; return 0; }
        done

        # Enumerate skills/ directory via API contents endpoint
        # (needed when skill directories are NOT named after the repo)
        local skills_dir_url="https://api.github.com/repos/${owner_repo}/contents/skills"
        local skills_list
        skills_list=$(fetch_url_mirrored "$skills_dir_url" "api") || true
        if [ -n "$skills_list" ]; then
            local skill_dirs
            skill_dirs=$(echo "$skills_list" | "$PYTHON" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for item in data:
        if item.get('type') == 'dir':
            print(f'skills/{item[\"name\"]}/SKILL.md')
except: pass
" 2>/dev/null)
            if [ -n "$skill_dirs" ]; then
                while IFS= read -r subpath; do
                    [ -z "$subpath" ] && continue
                    result=$(fetch_raw "$owner_repo" "HEAD" "$subpath") 2>/dev/null && { echo "$result"; return 0; }
                done <<< "$skill_dirs"
            fi
        fi
    fi

    # ── API-first path (main path when raw is blocked) ───────────────────────
    # Try recursive tree FIRST — one API call finds the exact path, then one
    # more API call fetches it. More efficient than guessing paths when
    # raw.githubusercontent.com is down.

    # Attempt 1: API recursive tree to find SKILL.md paths (ranked by relevance)
    local tree_url="https://api.github.com/repos/${owner_repo}/git/trees/HEAD?recursive=1"
    local tree_body
    tree_body=$(fetch_url_mirrored "$tree_url" "api") || true
    if [ -n "$tree_body" ]; then
        local skill_paths
        skill_paths=$(echo "$tree_body" | "$PYTHON" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    paths = []
    for item in data.get('tree', []):
        p = item.get('path', '')
        if p.endswith('SKILL.md'):
            paths.append(p)
    for p in paths:
        print(p)
except: pass
" 2>/dev/null | rank_skill_paths)
        if [ -n "$skill_paths" ]; then
            local path_count
            path_count=$(echo "$skill_paths" | grep -c . || echo "0")
            # Limit to top 5 for repos with many skills (e.g. 139)
            if [ "$path_count" -gt 5 ] 2>/dev/null; then
                skill_paths=$(echo "$skill_paths" | head -5)
                path_count=5
            fi
            while IFS= read -r skill_path; do
                [ -z "$skill_path" ] && continue
                # Try API content (works even when raw is blocked)
                result=$(fetch_api "$owner_repo" "$skill_path") 2>/dev/null || true
                if [ -n "$result" ]; then
                    # Inject metadata: skills_found and selected_skill
                    echo "$result" | "$PYTHON" -c "
import sys, json
data = json.load(sys.stdin)
data['skills_found'] = int('${path_count:-0}')
data['selected_skill'] = '${skill_path}'
print(json.dumps(data))
" 2>/dev/null && return 0
                fi
                # Fallback: try raw (might work via mirror)
                result=$(fetch_raw "$owner_repo" "HEAD" "$skill_path") 2>/dev/null && { echo "$result"; return 0; }
            done <<< "$skill_paths"
        fi
    fi

    # Attempt 2: Direct API content for common paths (tree might be too large)
    for subpath in \
        "SKILL.md" \
        "skills/${skill_name}/SKILL.md" \
        "skill/SKILL.md" \
        "skills/default/SKILL.md" \
        ".claude/skills/${skill_name}/SKILL.md"; do
        result=$(fetch_api "$owner_repo" "$subpath") 2>/dev/null && { echo "$result"; return 0; }
    done

    # Attempt 3: Enumerate skills/ via API contents + try each
    if [ -n "${skills_list:-}" ]; then
        while IFS= read -r subpath; do
            [ -z "$subpath" ] && continue
            result=$(fetch_api "$owner_repo" "$subpath") 2>/dev/null && { echo "$result"; return 0; }
        done <<< "$skill_dirs"
    fi

    # Attempt 4: Last-resort raw (might have been fixed since last probe)
    if [ "${RAW_GITHUB_OK:-unknown}" = "false" ]; then
        result=$(fetch_raw "$owner_repo" "HEAD" "SKILL.md") 2>/dev/null && { echo "$result"; return 0; }
    fi

    # ── Degraded fallback: try non-SKILL.md .md files (old-format repos) ───
    local old_tree_body
    old_tree_body=$(fetch_url_mirrored "$tree_url" "api") || true
    if [ -n "$old_tree_body" ]; then
        local md_paths
        md_paths=$(echo "$old_tree_body" | "$PYTHON" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    paths = []
    for item in data.get('tree', []):
        p = item.get('path', '')
        if p.endswith('.md') and 'SKILL' not in p.upper():
            score = 0
            if '.claude/' in p or 'skills/' in p.lower() or 'Skill' in p: score = 2
            elif '/' not in p: score = 1
            paths.append((score, p))
    paths.sort(key=lambda x: (-x[0], x[1].count('/'), len(x[1])))
    for _, p in paths[:5]:
        print(p)
except: pass
" 2>/dev/null)
        if [ -n "$md_paths" ]; then
            while IFS= read -r md_path; do
                [ -z "$md_path" ] && continue
                result=$(fetch_api "$owner_repo" "$md_path") 2>/dev/null || true
                if [ -n "$result" ]; then
                    echo "$result" | "$PYTHON" -c "
import sys, json
data = json.load(sys.stdin)
data['format'] = 'legacy'
data['source_file'] = '${md_path}'
print(json.dumps(data))
" 2>/dev/null && return 0
                fi
            done <<< "$md_paths"
        fi
    fi

    json_err "all fetch tiers failed for ${owner_repo}"
    return 1
}

# ── GitHub Web Search (no auth, scrapes github.com/search) ──────────────────
# Last-resort fallback when API is rate-limited. Parses GitHub's HTML search
# results page. Brittle but better than nothing.
fetch_search_web() {
    local keywords="$1"

    local encoded
    encoded=$(echo "$keywords" | "$PYTHON" -c "
import sys, urllib.parse
kw = sys.stdin.read().strip()
q = f'{kw} Claude Code skill'
print(urllib.parse.quote(q))
" 2>/dev/null || echo "")

    if [ -z "$encoded" ]; then
        return 1
    fi

    local url="https://github.com/search?q=${encoded}&type=repositories&s=stars&o=desc"
    local body
    body=$(fetch_url "$url") || true

    if [ -z "$body" ]; then
        return 1
    fi

    # Extract repo names from GitHub search result HTML
    echo "$body" | "$PYTHON" -c "
import sys, re, json
html = sys.stdin.read()
# GitHub search results: links like /owner/repo in h3 or a tags
pattern = r'href=[\"'](/[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?/[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?)[\"']'
matches = re.findall(pattern, html)
seen = set()
results = []
for path in matches:
    full = path.strip('/')
    parts = full.split('/')
    if len(parts) != 2: continue
    owner, repo = parts
    # Skip non-repo pages
    if owner in ('search', 'settings', 'notifications', 'explore', 'marketplace',
                 'topics', 'collections', 'trending', 'new', 'organizations',
                 'pulls', 'issues', 'login', 'signup', 'features', 'mobile',
                 'readme', 'security', 'pricing', 'enterprise', 'team'):
        continue
    repo_full = f'{owner}/{repo}'
    if repo_full in seen: continue
    seen.add(repo_full)
    results.append({
        'repo': repo_full,
        'url': f'https://github.com/{repo_full}',
        'stars': 0,
        'desc': '',
        'topics': [],
        'updated': '',
    })
print(json.dumps(results[:10], ensure_ascii=False))
" 2>/dev/null || echo "[]"
}

# ── GitHub Repository Search (no auth needed) ────────────────────────────────
fetch_search() {
    local keywords="$1"
    local page="${2:-1}"

    local query
    query=$(echo "$keywords" | "$PYTHON" -c "
import sys, urllib.parse
kw = sys.stdin.read().strip()
q = f'{kw} Claude Code skill'
print(urllib.parse.quote(q))
" 2>/dev/null || echo "")

    if [ -z "$query" ]; then
        json_err "empty search query"
        return 1
    fi

    local url="https://api.github.com/search/repositories?q=${query}&sort=stars&per_page=10&page=${page}"
    local body
    body=$(fetch_url_mirrored "$url" "api") || true

    if [ -z "$body" ]; then
        json_err "search returned empty for '${keywords}'"
        return 1
    fi

    if echo "$body" | grep -q "API rate limit exceeded"; then
        # Try web-scrape fallback before giving up
        local web_results
        web_results=$(fetch_search_web "$keywords") || true
        if [ -n "$web_results" ]; then
            json_ok_raw "$web_results"
            return 0
        fi
        json_err "GitHub API rate limit exceeded. Set GITHUB_TOKEN for 5000 req/hr."
        return 1
    fi

    local repos
    repos=$(echo "$body" | "$PYTHON" -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('items', [])
seen = set()
results = []
for item in items:
    full = item.get('full_name', '')
    if full and full not in seen:
        seen.add(full)
        results.append({
            'repo': full,
            'url': item.get('html_url', ''),
            'stars': item.get('stargazers_count', 0),
            'desc': (item.get('description') or '').strip(),
            'topics': item.get('topics', []),
            'updated': (item.get('updated_at') or '')[:10],
        })
print(json.dumps(results, ensure_ascii=False))
" 2>/dev/null || echo "[]")

    json_ok_raw "$repos"
}

# ── Bing web search (China-friendly alternative to DDG) ──────────────────────
fetch_bing() {
    local query="$1"

    local encoded
    encoded=$(echo "$query" | "$PYTHON" -c "
import sys, urllib.parse
print(urllib.parse.quote(sys.stdin.read().strip()))
" 2>/dev/null || echo "")

    if [ -z "$encoded" ]; then
        json_err "empty Bing query"
        return 1
    fi

    # Bing search — accessible in China (cn.bing.com)
    local url="https://www.bing.com/search?q=${encoded}&count=15"
    local body
    body=$(fetch_url "$url") || true

    if [ -z "$body" ]; then
        # Try cn.bing.com as fallback
        url="https://cn.bing.com/search?q=${encoded}&count=15"
        body=$(fetch_url "$url") || true
    fi

    if [ -z "$body" ]; then
        json_err "Bing returned empty for '${query}'"
        return 1
    fi

    # Extract result links and titles from Bing HTML
    local results
    results=$(echo "$body" | "$PYTHON" -c "
import sys, re, json
html = sys.stdin.read()
# Bing results: <h2><a href='url'>title</a></h2>
# Or: <li class='b_algo'><h2><a href='url'>title</a></h2><p>snippet</p>
pattern = r\"<h2[^>]*>.*?<a[^>]*href=['\\\"]([^'\\\"]+)['\\\"][^>]*>([^<]+)</a>\"
matches = re.findall(pattern, html, re.DOTALL)
seen = set()
items = []
for url, title in matches:
    title = re.sub(r'<[^>]+>', '', title).strip()
    url = url.strip()
    if not title or not url: continue
    if url.startswith('//'): url = 'https:' + url
    if url in seen: continue
    seen.add(url)
    items.append({'title': title, 'url': url})
print(json.dumps(items[:15], ensure_ascii=False))
" 2>/dev/null || echo "[]")

    json_ok_raw "$results"
}

# ── DuckDuckGo Lite web search ───────────────────────────────────────────────
fetch_ddg() {
    local query="$1"

    # If CHINA_MODE or SKILLS_SEARCH_BING, prefer Bing (DDG blocked in China)
    if [ "$CHINA_MODE" = "1" ] || [ "$SKILLS_SEARCH_BING" = "1" ]; then
        fetch_bing "$query" && return 0
    fi

    local encoded
    encoded=$(echo "$query" | "$PYTHON" -c "
import sys, urllib.parse
print(urllib.parse.quote(sys.stdin.read().strip()))
" 2>/dev/null || echo "")

    if [ -z "$encoded" ]; then
        json_err "empty DDG query"
        return 1
    fi

    # DuckDuckGo Lite — returns minimal HTML, easy to parse
    local url="https://lite.duckduckgo.com/lite/?q=${encoded}"
    local body
    body=$(fetch_url "$url") || true

    if [ -z "$body" ]; then
        # DDG blocked? Try Bing as fallback
        fetch_bing "$query" && return 0
        json_err "DDG returned empty for '${query}'"
        return 1
    fi

    # Extract result links and titles from DDG Lite HTML
    local results
    results=$(echo "$body" | "$PYTHON" -c "
import sys, re
html = sys.stdin.read()
# DDG Lite format: <a href='url'>title</a><br><span class='...'>snippet</span>
# Also handles: <a rel='nofollow' href='url' ...>title</a>
pattern = r\"<a[^>]*href=['\\\"]([^'\\\"]+)['\\\"][^>]*>([^<]+)</a>\"
matches = re.findall(pattern, html)
seen = set()
items = []
for url, title in matches:
    title = title.strip()
    url = url.strip()
    if not title or not url: continue
    if url.startswith('//'): url = 'https:' + url
    if url in seen: continue
    seen.add(url)
    items.append({'title': title, 'url': url})
print(json.dumps(items[:15], ensure_ascii=False))
" 2>/dev/null || echo "[]")

    json_ok_raw "$results"
}

# ── Repo metadata ────────────────────────────────────────────────────────────
fetch_repo_meta() {
    local owner_repo="$1"

    local url="https://api.github.com/repos/${owner_repo}"
    local body
    body=$(fetch_url_mirrored "$url" "api") || true

    if [ -z "$body" ]; then
        json_err "repo meta empty for ${owner_repo}"
        return 1
    fi

    local meta
    meta=$(echo "$body" | "$PYTHON" -c "
import sys, json
data = json.load(sys.stdin)
if 'message' in data:
    print(json.dumps({'error': data['message']}))
else:
    print(json.dumps({
        'stars': data.get('stargazers_count', 0),
        'description': (data.get('description') or '').strip(),
        'topics': data.get('topics', []),
        'updated_at': (data.get('updated_at') or '')[:10],
        'license': (data.get('license') or {}).get('spdx_id', ''),
        'default_branch': data.get('default_branch', 'main'),
    }, ensure_ascii=False))
" 2>/dev/null || echo "{}")

    json_ok_raw "$meta"
}

# ── Fetch awesome-lists ──────────────────────────────────────────────────────
fetch_awesome() {
    local urls=(
        "https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md"
        "https://raw.githubusercontent.com/onmyway133/awesome-claude-code/main/README.md"
    )

    local results="["
    local first=true
    for url in "${urls[@]}"; do
        local body
        # Use mirrored fetch for raw.githubusercontent.com URLs
        if echo "$url" | grep -q "raw.githubusercontent.com"; then
            body=$(fetch_url_mirrored "$url" "raw") || true
        else
            body=$(fetch_url "$url") || true
        fi
        if [ -n "$body" ] && [ ${#body} -gt 100 ]; then
            local repos
            repos=$(echo "$body" | { grep -oE 'https://github\.com/[\w.-]+/[\w.-]+' || true; } | sort -u | head -20 | "$PYTHON" -c "
import sys, json
lines = [l.strip() for l in sys.stdin if l.strip()]
print(json.dumps(lines, ensure_ascii=False))
" 2>/dev/null)
            [ -n "$repos" ] || repos="[]"

            if [ "$first" = false ]; then results+=","; fi
            first=false
            results+="{\"source\":\"${url}\",\"repos\":${repos}}"
        fi
    done
    results+="]"

    json_ok_raw "$results"
}

# ── Connectivity self-test ───────────────────────────────────────────────────
fetch_check() {
    local results=""
    local mirrors_ok=""
    local all_ok=true

    # Test 1: raw.githubusercontent.com (direct)
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null | grep -q "200"; then
        results+="raw.githubusercontent.com(direct): OK, "
    else
        results+="raw.githubusercontent.com(direct): FAIL, "
        all_ok=false

        # Test raw mirrors via discovery
        local discovered
        discovered=$(discover_mirrors "raw" 2>/dev/null || true)
        if [ -n "$discovered" ]; then
            while IFS='|' read -r mirror_host mirror_style; do
                [ -z "$mirror_host" ] && continue
                if [ "$mirror_style" = "prefix-proxy" ]; then
                    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
                        "https://${mirror_host}/https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null | grep -q "200"; then
                        mirrors_ok+="${mirror_host}(prefix): OK, "
                        all_ok=true
                        break
                    fi
                else
                    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
                        "https://${mirror_host}/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null | grep -q "200"; then
                        mirrors_ok+="${mirror_host}: OK, "
                        all_ok=true
                        break
                    fi
                fi
            done <<< "$discovered"
        fi
        if [ -z "$mirrors_ok" ]; then
            mirrors_ok+="raw-mirrors: ALL_FAILED, "
        fi
    fi

    # Test 2: api.github.com (direct)
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://api.github.com/" 2>/dev/null | grep -q "200"; then
        results+="api.github.com(direct): OK, "
    else
        results+="api.github.com(direct): FAIL, "
        all_ok=false

        # Test API mirrors via discovery
        local discovered_api
        discovered_api=$(discover_mirrors "api" 2>/dev/null || true)
        if [ -n "$discovered_api" ]; then
            while IFS='|' read -r mirror_host mirror_style; do
                [ -z "$mirror_host" ] && continue
                if [ "$mirror_style" = "prefix-proxy" ]; then
                    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
                        "https://${mirror_host}/https://api.github.com/" 2>/dev/null | grep -q "200"; then
                        mirrors_ok+="${mirror_host}(prefix): OK, "
                        all_ok=true
                        break
                    fi
                else
                    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
                        "https://${mirror_host}/" 2>/dev/null | grep -q "200"; then
                        mirrors_ok+="${mirror_host}: OK, "
                        all_ok=true
                        break
                    fi
                fi
            done <<< "$discovered_api"
        fi
        if ! echo "$mirrors_ok" | grep -q "api"; then
            mirrors_ok+="api-mirrors: ALL_FAILED, "
        fi
    fi

    # Test 3: DuckDuckGo (for default search)
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://lite.duckduckgo.com/lite/" 2>/dev/null | grep -q "200"; then
        results+="lite.duckduckgo.com: OK, "
    else
        results+="lite.duckduckgo.com: FAIL, "
        all_ok=false
    fi

    # Test 4: Bing (China-friendly search alternative)
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://www.bing.com/" 2>/dev/null | grep -q "200"; then
        results+="bing.com: OK"
        # If DDG failed but Bing works, search is still functional
        if echo "$results" | grep -q "lite.duckduckgo.com: FAIL"; then
            all_ok=true   # Bing available as fallback
        fi
    else
        results+="bing.com: FAIL"
    fi

    # Build combined diagnostics
    local diag="$results"
    if [ -n "$mirrors_ok" ]; then diag+=" | mirrors: ${mirrors_ok}"; fi

    local status="degraded"
    if $all_ok; then status="all_ok"; fi

    # Network auto-detection info
    local hint=""
    if [ "$CHINA_MODE_EXPLICIT" = "1" ]; then
        hint=" | CHINA_MODE: user-set ($CHINA_MODE)"
    elif [ "$CHINA_MODE" = "1" ]; then
        hint=" | CHINA_MODE: auto-detected (restricted network)"
    else
        hint=" | CHINA_MODE: auto-detected (open network)"
    fi

    printf '{"ok":true,"status":"%s","china_mode":%s,"china_mode_source":"%s","results":"%s"}\n' \
        "$status" \
        "$CHINA_MODE" \
        "$([ "$CHINA_MODE_EXPLICIT" = "1" ] && echo "user" || echo "auto")" \
        "$diag"
}

# ── Main dispatch ────────────────────────────────────────────────────────────
case "${1:-}" in
    raw)
        fetch_raw "${2:-}" "${3:-HEAD}" "${4:-SKILL.md}" || {
            json_err "raw fetch failed for ${2:-}"
            exit 1
        }
        ;;
    api)
        fetch_api "${2:-}" "${3:-SKILL.md}" || {
            json_err "API fetch failed for ${2:-}/${3:-SKILL.md}"
            exit 1
        }
        ;;
    skill)
        fetch_skill "${2:-}" "${3:-HEAD}" || exit 1
        ;;
    search)
        fetch_search "${2:-}" "${3:-1}" || exit 1
        ;;
    ddg)
        fetch_ddg "${2:-}" || exit 1
        ;;
    repo)
        fetch_repo_meta "${2:-}" || exit 1
        ;;
    awesome)
        fetch_awesome || exit 1
        ;;
    check)
        fetch_check
        ;;
    discover-mirrors)
        # Explicitly discover and output currently-working mirrors.
        # Use shorter timeout for discovery (Bing search should be fast or fail fast).
        # Turn off pipefail: discover_mirrors returns 1 when nothing found,
        # but python still outputs valid [].
        set +o pipefail
        _save_timeout="$TIMEOUT"
        TIMEOUT=5  # quick timeout for discovery
        raw_mirrors=$(discover_mirrors "raw" 2>/dev/null | $PYTHON -c "
import sys, json
lines = [l.strip() for l in sys.stdin.read().splitlines() if l.strip()]
result = [{'host': l.split('|')[0], 'style': l.split('|')[1]} for l in lines if '|' in l]
sys.stdout.write(json.dumps(result) + '\n')
" 2>/dev/null)
        [ -n "$raw_mirrors" ] || raw_mirrors='[]'
        raw_mirrors="${raw_mirrors//$'\r'/}"

        api_mirrors=$(discover_mirrors "api" 2>/dev/null | $PYTHON -c "
import sys, json
lines = [l.strip() for l in sys.stdin.read().splitlines() if l.strip()]
result = [{'host': l.split('|')[0], 'style': l.split('|')[1]} for l in lines if '|' in l]
sys.stdout.write(json.dumps(result) + '\n')
" 2>/dev/null)
        [ -n "$api_mirrors" ] || api_mirrors='[]'
        api_mirrors="${api_mirrors//$'\r'/}"

        set -o pipefail  # restore
        TIMEOUT="$_save_timeout"
        printf '{"raw":%s,"api":%s}\n' "$raw_mirrors" "$api_mirrors"
        ;;
    mirror-git)
        # Output the configured git mirror prefix for install-from-github.sh
        if [ -n "$SKILLS_MIRROR_GIT" ]; then
            echo "$SKILLS_MIRROR_GIT"
        elif [ "$CHINA_MODE" = "1" ]; then
            # Try to discover a working git mirror
            git_mirror=$(discover_mirrors "raw" 2>/dev/null | head -1)
            if [ -n "$git_mirror" ]; then
                host="${git_mirror%%|*}"
                style="${git_mirror#*|}"
                if [ "$style" = "prefix-proxy" ]; then
                    echo "https://${host}/"
                else
                    echo ""
                fi
            else
                echo ""
            fi
        else
            echo ""
        fi
        ;;
    *)
        json_err "usage: fetch-local.sh <raw|api|skill|search|ddg|repo|awesome|check|discover-mirrors|mirror-git> [args...]"
        exit 1
        ;;
esac
