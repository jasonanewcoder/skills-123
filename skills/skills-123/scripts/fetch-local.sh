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

# ── Helpers ─────────────────────────────────────────────────────────────────
json_ok() {
    local content="$1"
    content=$(echo "$content" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    printf '{"ok":true,"content":%s}\n' "$content"
}

json_ok_raw() {
    # For already-JSON content (arrays, objects) — don't double-encode
    local content="$1"
    printf '{"ok":true,"content":%s}\n' "$content"
}

json_err() {
    local msg="$1"
    msg=$(echo "$msg" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
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

is_error_page() {
    local body="$1"
    echo "$body" | grep -qi "404: Not Found\|400: Invalid\|not found\|rate limit exceeded" && return 0
    # GitHub API error messages
    echo "$body" | python3 -c "
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
    body=$(fetch_url "$url") || true

    if [ -n "$body" ] && ! is_error_page "$body"; then
        json_ok "$body"
        return 0
    fi

    # If HEAD failed, try main
    if [ "$ref" = "HEAD" ]; then
        url="https://raw.githubusercontent.com/${owner_repo}/main/${file}"
        body=$(fetch_url "$url") || true
        if [ -n "$body" ] && ! is_error_page "$body"; then
            json_ok "$body"
            return 0
        fi
    fi

    # If main failed, try master
    url="https://raw.githubusercontent.com/${owner_repo}/master/${file}"
    body=$(fetch_url "$url") || true
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
    body=$(fetch_url "$url") || true

    if [ -z "$body" ]; then
        return 1
    fi

    # Check for API-level errors
    local err_msg
    err_msg=$(echo "$body" | python3 -c "
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
    content=$(echo "$body" | python3 -c "
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
    tree_body=$(fetch_url "$tree_url") || true
    if [ -n "$tree_body" ]; then
        local skill_path
        skill_path=$(echo "$tree_body" | python3 -c "
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
    query=$(echo "$keywords" | python3 -c "
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
    body=$(fetch_url "$url") || true

    if [ -z "$body" ]; then
        json_err "search returned empty for '${keywords}'"
        return 1
    fi

    if echo "$body" | grep -q "API rate limit exceeded"; then
        json_err "GitHub API rate limit exceeded. Set GITHUB_TOKEN for 5000 req/hr."
        return 1
    fi

    local repos
    repos=$(echo "$body" | python3 -c "
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

# ── DuckDuckGo Lite web search ───────────────────────────────────────────────
fetch_ddg() {
    local query="$1"

    local encoded
    encoded=$(echo "$query" | python3 -c "
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
        json_err "DDG returned empty for '${query}'"
        return 1
    fi

    # Extract result links and titles from DDG Lite HTML
    local results
    results=$(echo "$body" | python3 -c "
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
    body=$(fetch_url "$url") || true

    if [ -z "$body" ]; then
        json_err "repo meta empty for ${owner_repo}"
        return 1
    fi

    local meta
    meta=$(echo "$body" | python3 -c "
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
        body=$(fetch_url "$url") || true
        if [ -n "$body" ] && [ ${#body} -gt 100 ]; then
            local repos
            repos=$(echo "$body" | grep -oE 'https://github\.com/[\w.-]+/[\w.-]+' | sort -u | head -20 | python3 -c "
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
    local all_ok=true

    # Test 1: raw.githubusercontent.com
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md" 2>/dev/null | grep -q "200"; then
        results+="raw.githubusercontent.com: OK, "
    else
        results+="raw.githubusercontent.com: FAIL, "
        all_ok=false
    fi

    # Test 2: api.github.com
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://api.github.com/" 2>/dev/null | grep -q "200"; then
        results+="api.github.com: OK, "
    else
        results+="api.github.com: FAIL, "
        all_ok=false
    fi

    # Test 3: DuckDuckGo
    if curl -sS --max-time 5 -o /dev/null -w "%{http_code}" \
        "https://lite.duckduckgo.com/lite/" 2>/dev/null | grep -q "200"; then
        results+="lite.duckduckgo.com: OK"
    else
        results+="lite.duckduckgo.com: FAIL"
        all_ok=false
    fi

    local status="degraded"
    if $all_ok; then status="all_ok"; fi

    printf '{"ok":true,"status":"%s","results":"%s"}\n' "$status" "$results"
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
    *)
        json_err "usage: fetch-local.sh <raw|api|skill|search|ddg|repo|awesome|check> [args...]"
        exit 1
        ;;
esac
