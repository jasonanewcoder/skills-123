#!/bin/bash
#===============================================================================
# scan-security.sh — Scan a SKILL.md file for dangerous patterns
#
# Usage: cat SKILL.md | scan-security.sh
#        scan-security.sh /path/to/SKILL.md
# Output: JSON {critical: N, warnings: N, safe: bool, details: [...]}
#===============================================================================

set -euo pipefail

CONTENT=""
if [ $# -ge 1 ] && [ -f "$1" ]; then
    CONTENT=$(cat "$1")
else
    CONTENT=$(cat)
fi

# Critical patterns — any match = auto-reject
CRITICAL_PATTERNS=(
    "curl.*\|.*sh"
    "curl.*\|.*bash"
    "wget.*\|.*sh"
    "wget.*\|.*bash"
    "eval\s+[\"\']?\$"
    "base64\s+(-d|--decode).*\|"
    "exec\s*\(.*\$"
    "rm\s+-rf\s+/"
    "rm\s+-rf\s+~"
    "sudo\s+rm\s+-rf"
    "/dev/tcp/"
    "curl.*\.env"
    "curl.*credential"
    "curl.*\.ssh"
    "curl.*\.aws"
    "os\.system\s*\(.*\$"
    "subprocess.*shell\s*=\s*True"
    "__import__\s*\(\s*[\"']os[\"']"
    "exec\s*\(\s*.*\$"
    "nc\s+-[nlvp]"
    "bash\s+-i\s+>&"
    "\|.*nc\s"
    ">\/dev\/tcp\/"
)

# Warning patterns — flag for review
WARNING_PATTERNS=(
    "curl\s"
    "wget\s"
    "pip\s+install"
    "pip3\s+install"
    "npm\s+install\s+-g"
    "npm\s+i\s+-g"
    "sudo\s"
    "chmod\s+[0-7]*7[0-7]*"
    "chown\s"
    "base64\s"
    "eval\s"
    "exec\s"
    "\.env"
    "credential"
    "\.ssh/"
    "\.aws/"
    "rm\s+-rf\s"
    "DDGkm7DA4j"
    "netcat"
)

# Content integrity checks
SUSPICIOUS_PATTERNS=(
    "AAAA"           # Large base64 blocks often start with many A's from padding
    "\\u200[b-f]"    # Zero-width characters (ZWSP, ZWNJ, ZWJ, etc.)
    "\\u00ad"        # Soft hyphen
    "\\u200e"        # LRM
    "\\u200f"        # RLM
)

critical_count=0
warning_count=0
declare -a critical_details=()
declare -a warning_details=()

# Scan critical patterns
for pattern in "${CRITICAL_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qiE "$pattern" 2>/dev/null; then
        ((critical_count++))
        critical_details+=("$pattern")
    fi
done

# Scan warning patterns
for pattern in "${WARNING_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qiE "$pattern" 2>/dev/null; then
        ((warning_count++))
        warning_details+=("$pattern")
    fi
done

# Check for suspicious content
suspicious_count=0
for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qiE "$pattern" 2>/dev/null; then
        ((suspicious_count++))
    fi
done

# Check content size (excessively large files are suspicious)
line_count=$(echo "$CONTENT" | wc -l | tr -d ' ')
if [ "$line_count" -gt 10000 ]; then
    ((warning_count++))
    warning_details+=("file_too_large:${line_count}_lines")
fi

# Check for hidden content: long lines (>2000 chars) that aren't code blocks
long_lines=$(echo "$CONTENT" | awk 'length($0) > 2000 && $0 !~ /^```/' | wc -l | tr -d ' ')
if [ "$long_lines" -gt 0 ]; then
    ((warning_count++))
    warning_details+=("long_lines:${long_lines}_lines_over_2000_chars")
fi

# Build result
SAFE=$([ "$critical_count" -eq 0 ] && echo "true" || echo "false")

# Output JSON
python3 -c "
import json
result = {
    'critical': $critical_count,
    'warnings': $warning_count,
    'suspicious': $suspicious_count,
    'safe': $([ "$critical_count" -eq 0 ] && echo 'True' || echo 'False'),
    'critical_patterns': $(python3 -c "import json; print(json.dumps($(printf '%s\n' "${critical_details[@]}" | python3 -c "import sys; print(json.dumps([l.strip() for l in sys.stdin.read().splitlines() if l.strip()]))" 2>/dev/null || echo '[]')))" 2>/dev/null || echo '[]'),
    'warning_patterns': $(python3 -c "import json; print(json.dumps($(printf '%s\n' "${warning_details[@]}" | python3 -c "import sys; print(json.dumps([l.strip() for l in sys.stdin.read().splitlines() if l.strip()]))" 2>/dev/null || echo '[]')))" 2>/dev/null || echo '[]'),
    'recommendation': '$([ "$critical_count" -eq 0 ] && [ "$warning_count" -eq 0 ] && echo '"clean"' || ([ "$critical_count" -gt 0 ] && echo '"reject"' || echo '"review"') )'
}
print(json.dumps(result, indent=2))
" 2>/dev/null || echo '{"critical":0,"warnings":0,"safe":true,"recommendation":"error"}'
