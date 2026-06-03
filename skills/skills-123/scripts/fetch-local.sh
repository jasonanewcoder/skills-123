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
# Set CHINA_MODE=1 to enable built-in China-friendly mirrors and search sources.
# Or set individual mirror vars for fine-grained control.
# curl already respects https_proxy / all_proxy env vars — set them if you use a proxy.
#
#   CHINA_MODE=1                              # auto-enable all mirrors
#   SKILLS_MIRROR_RAW="raw.ghproxy.com"       # host-replacement for raw.githubusercontent.com
#   SKILLS_MIRROR_API="gh.api.99988866.xyz"   # host-replacement for api.github.com
#   SKILLS_MIRROR_GIT="https://ghproxy.com/"  # prefix for git clone URLs
#   SKILLS_SEARCH_BING=1                      # use Bing instead of DuckDuckGo
CHINA_MODE="${CHINA_MODE:-0}"
SKILLS_MIRROR_RAW="${SKILLS_MIRROR_RAW:-}"
SKILLS_MIRROR_API="${SKILLS_MIRROR_API:-}"
SKILLS_MIRROR_GIT="${SKILLS_MIRROR_GIT:-}"
SKILLS_SEARCH_BING="${SKILLS_SEARCH_BING:-0}"

# Built-in mirror candidates (tried in order when direct access fails).
# Each entry is "type|template" where {host} is replaced with the original host,
# and {url} is replaced with the full original URL.
# Host-replace mirrors (raw/api): "raw|raw.ghproxy.com"
# Prefix-proxy mirrors:           "raw|ghproxy.com/https://{host}/{path}"
readonly BUILTIN_MIRRORS=(
    # host-replace style (cleaner, faster)
    "raw|raw.ghproxy.com"
    "raw|raw.mghproxy.com"
    "api|gh.api.99988866.xyz"
    # prefix-proxy style (works with any GitHub URL)
    "raw|ghproxy.com/https://raw.githubusercontent.com"
    "api|ghproxy.com/https://api.github.com"
)

# ── Python detection ──────────────────────────────────────────────────────
# On Windows (Git Bash) and some Linux distros, python3 may be "python".
# Detect the available interpreter once and use it everywhere.
PYTHON=""
if command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    # Verify it's Python 3, not Python 2
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
        PYTHON="python"
    fi
fi

if [ -z "$PYTHON" ]; then
    echo '{"ok":false,"error":"python3/python not found in PATH — required by fetch-local.sh"}' >&2
    exit 1
fi

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

    local mirrors=()
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
    local user_mirror_var="SKILLS_MIRROR_${mirror_type^^}"  # raw→RAW, api→API
    local user_mirror
    user_mirror=$(eval "echo \${${user_mirror_var}:-}")
    if [ -n "$user_mirror" ]; then
        mirrors+=("https://${user_mirror}${path}")
    fi

    # 2. Built-in mirrors (when CHINA_MODE=1 or user configured mirrors)
    if [ "$CHINA_MODE" = "1" ] || [ -n "$user_mirror" ]; then
        for entry in "${BUILTIN_MIRRORS[@]}"; do
            local e_type="${entry%%|*}"
            local e_tmpl="${entry#*|}"
            [ "$e_type" != "$mirror_type" ] && continue

            # Skip if same as user-configured mirror
            if [ "$e_tmpl" = "$user_mirror" ]; then continue; fi

            if echo "$e_tmpl" | grep -q "/"; then
                # Prefix-proxy style: ghproxy.com/https://{host}/{path}
                mirrors+=("https://${e_tmpl}${path}")
            else
                # Host-replace style: raw.ghproxy.com
                mirrors+=("https://${e_tmpl}${path}")
            fi
        done
    fi

    printf '%s\n' "${mirrors[@]}"
}

# Fetch a URL with mirror fallback chain (for China/unreachable scenarios)
fetch_url_mirrored() {
    local url="$1"
    local mirror_type="$2"   # "raw" or "api"
    local extra_flags="${3:-}"

    # Try direct first
    local body
    body=$(fetch_url "$url" "$extra_flags") || true
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
    echo "$body" | grep -qi "404: Not Found\|400: Invalid\|not found\|rate limit exceeded" && return 0
    # GitHub API error messages
    echo "$body" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if d.get('message'): sys.exit(0)
except: pass
sys.exit(1)
" 2>/dev/null && return 0
    return 1
}

# ── Tier 1: Raw content from raw.githubusercontent.com ───────────────────────
fetch_raw() {
    local owner_repo="$1"   # e.g. "daymade/claude-code-skills"
    local ref="${2:-main}"  # branch or HEAD
    local file="${3:-SKILL.md}"

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

# ── Tier 1-3 combined: Multi-tier SKILL.md fetch ─────────────────────────────
fetch_skill() {
    local owner_repo="$1"
    local ref="${2:-HEAD}"

    local result

    # Tier 1: raw with HEAD
    result=$(fetch_raw "$owner_repo" "$ref" "SKILL.md") && { echo "$result"; return 0; }

    # Tier 2: raw with common skill subpaths
    local skill_name
    skill_name=$(echo "$owner_repo" | sed 's|.*/||')

    for subpath in \
        "skills/${skill_name}/SKILL.md" \
        "skills/default/SKILL.md" \
        "skill/SKILL.md" \
        ".claude/skills/${skill_name}/SKILL.md" \
        "SKILL.md"; do

        # Try raw first (faster, no rate limit)
        result=$(fetch_raw "$owner_repo" "HEAD" "$subpath") && { echo "$result"; return 0; }
        # Then API (can find files at any path)
        result=$(fetch_api "$owner_repo" "$subpath") && { echo "$result"; return 0; }
    done

    # Tier 3: Try api.github.com for root SKILL.md
    result=$(fetch_api "$owner_repo" "SKILL.md") && { echo "$result"; return 0; }

    # Tier 4: Try to list repo contents to find SKILL.md location
    local tree_url="https://api.github.com/repos/${owner_repo}/git/trees/HEAD?recursive=1"
    local tree_body
    tree_body=$(fetch_url_mirrored "$tree_url" "api") || true
    if [ -n "$tree_body" ]; then
        local skill_path
        skill_path=$(echo "$tree_body" | "$PYTHON" -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for item in data.get('tree', []):
        if item.get('path', '').endswith('SKILL.md'):
            print(item['path'])
            break
except: pass
" 2>/dev/null || echo "")
        if [ -n "$skill_path" ]; then
            result=$(fetch_api "$owner_repo" "$skill_path") && { echo "$result"; return 0; }
            result=$(fetch_raw "$owner_repo" "HEAD" "$skill_path") && { echo "$result"; return 0; }
        fi
    fi

    json_err "all fetch tiers failed for ${owner_repo}"
    return 1
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
            repos=$(echo "$body" | grep -oE 'https://github\.com/[\w.-]+/[\w.-]+' | sort -u | head -20 | "$PYTHON" -c "
import sys, json
lines = [l.strip() for l in sys.stdin if l.strip()]
print(json.dumps(lines, ensure_ascii=False))
" 2>/dev/null || echo "[]")

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

        # Test raw mirrors
        for mirror in raw.ghproxy.com raw.mghproxy.com; do
            if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
                "https://${mirror}/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null | grep -q "200"; then
                mirrors_ok+="${mirror}: OK, "
                all_ok=true  # mirror works → not a total failure
                break
            fi
        done
        if [ -z "$mirrors_ok" ]; then
            # Try prefix-proxy style
            if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
                "https://ghproxy.com/https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null | grep -q "200"; then
                mirrors_ok+="ghproxy.com(prefix): OK, "
                all_ok=true
            else
                mirrors_ok+="raw-mirrors: ALL_FAILED, "
            fi
        fi
    fi

    # Test 2: api.github.com (direct)
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://api.github.com/" 2>/dev/null | grep -q "200"; then
        results+="api.github.com(direct): OK, "
    else
        results+="api.github.com(direct): FAIL, "
        all_ok=false

        # Test API mirrors
        if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
            "https://gh.api.99988866.xyz/" 2>/dev/null | grep -q "200"; then
            mirrors_ok+="gh.api.99988866.xyz: OK, "
            all_ok=true
        else
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

    # Recommend CHINA_MODE if mirrors help
    local hint=""
    if echo "$diag" | grep -q "raw.githubusercontent.com(direct): FAIL" && echo "$diag" | grep -q "mirrors:.*OK"; then
        hint=" | Tip: export CHINA_MODE=1 to enable GitHub mirrors automatically"
    fi

    printf '{"ok":true,"status":"%s","results":"%s%s"}\n' "$status" "$diag" "$hint"
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
    mirror-git)
        # Output the configured git mirror prefix for install-from-github.sh
        if [ -n "$SKILLS_MIRROR_GIT" ]; then
            echo "$SKILLS_MIRROR_GIT"
        elif [ "$CHINA_MODE" = "1" ]; then
            echo "https://ghproxy.com/"
        else
            echo ""
        fi
        ;;
    *)
        json_err "usage: fetch-local.sh <raw|api|skill|search|ddg|repo|awesome|check|mirror-git> [args...]"
        exit 1
        ;;
esac
