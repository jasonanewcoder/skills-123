#!/bin/bash
#===============================================================================
# search-github.sh — Search GitHub for Claude Code skills
#
# Usage: echo '{"keywords":["kubernetes","deploy"]}' | search-github.sh
# Output: JSON array of candidate repos
#
# NOTE: This script generates search query suggestions for WebSearch.
# When WebSearch is unreachable, use the local fallback instead:
#   bash ~/.claude/skills/skills-123/scripts/fetch-local.sh search "<keywords>"
#   bash ~/.claude/skills/skills-123/scripts/fetch-local.sh ddg "<keywords>"
#===============================================================================

set -euo pipefail

# ── Python detection ──────────────────────────────────────────────────────
# On Windows (Git Bash) and some Linux distros, python3 may be "python".
PYTHON=""
if command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
        PYTHON="python"
    fi
fi
PYTHON="${PYTHON:-python3}"  # fallback string if neither found

# Read keywords from stdin (JSON format)
INPUT=$(cat)
KEYWORDS=$(echo "$INPUT" | $PYTHON -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(' '.join(data.get('keywords', [])))
except:
    print('')
" 2>/dev/null || echo "")

if [ -z "$KEYWORDS" ]; then
    echo '[]'
    exit 0
fi

# This script is designed to be called by Claude Code which has WebSearch access.
# When run standalone, it outputs search query suggestions.
#
# It transforms keyword combinations into GitHub search queries.
# Claude Code should use these queries with WebSearch in parallel.

IFS=' ' read -r -a KW_ARRAY <<< "$KEYWORDS"

# Generate GitHub search URLs for the keywords
FIRST_KW="${KW_ARRAY[0]:-}"
SECOND_KW="${KW_ARRAY[1]:-$FIRST_KW}"

# Output search instructions as JSON for Claude to execute
cat << EOF
{
  "searches": [
    {
      "source": "github-topic",
      "query": "site:github.com claude-code-skill ${FIRST_KW}",
      "description": "GitHub repos tagged claude-code-skill matching '${FIRST_KW}'"
    },
    {
      "source": "github-code",
      "query": "\"SKILL.md\" \"${FIRST_KW}\" \"Claude Code\" site:github.com",
      "description": "GitHub files named SKILL.md matching '${FIRST_KW}'"
    },
    {
      "source": "web-search",
      "query": "\"${FIRST_KW}\" \"Claude Code\" skill OR skills GitHub",
      "description": "Web search for Claude Code skills about '${FIRST_KW}'"
    }
  ],
  "registry_urls": [
    "https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md",
    "https://raw.githubusercontent.com/onmyway133/awesome-claude-code/main/README.md"
  ]
}
EOF
