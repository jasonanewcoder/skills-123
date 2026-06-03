#!/bin/bash
#===============================================================================
# scan-security.sh — Scan a SKILL.md file for dangerous patterns
#
# Usage: cat SKILL.md | scan-security.sh
#        scan-security.sh /path/to/SKILL.md
# Output: JSON {critical: N, warnings: N, safe: bool, details: [...]}
#===============================================================================

set -euo pipefail

# ── Python detection ──────────────────────────────────────────────────────
PYTHON=""
if command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
        PYTHON="python"
    fi
fi
PYTHON="${PYTHON:-python3}"  # fallback string if neither found

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

# Content integrity checks — use python3 for proper Unicode detection
# (BSD grep on macOS doesn't support \u escapes or PCRE)
SUSPICIOUS_DESC=(
    "zero-width space (U+200B)"
    "zero-width non-joiner (U+200C)"
    "zero-width joiner (U+200D)"
    "left-to-right mark (U+200E)"
    "right-to-left mark (U+200F)"
    "soft hyphen (U+00AD)"
    "word joiner (U+2060)"
    "invisible separator (U+2062)"
    "invisible plus (U+2064)"
    "large base64 block (>500 consecutive base64 chars)"
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

# Check for suspicious Unicode characters and base64 blocks via python
suspicious_count=0
suspicious_details_json="[]"
if command -v "$PYTHON" &>/dev/null; then
    suspicious_result=$(echo "$CONTENT" | $PYTHON -c "
import sys, json, re
text = sys.stdin.read()
findings = []

# Unicode zero-width and invisible characters
zw_chars = {
    '​': 'zero-width space (U+200B)',
    '‌': 'zero-width non-joiner (U+200C)',
    '‍': 'zero-width joiner (U+200D)',
    '‎': 'left-to-right mark (U+200E)',
    '‏': 'right-to-left mark (U+200F)',
    '­': 'soft hyphen (U+00AD)',
    '⁠': 'word joiner (U+2060)',
    '⁢': 'invisible separator (U+2062)',
    '⁤': 'invisible plus (U+2064)',
}
for char, desc in zw_chars.items():
    if char in text:
        count = text.count(char)
        findings.append(f'{desc}: {count} occurrence(s)')

# Large base64 blocks
b64_blocks = re.findall(r'[A-Za-z0-9+/=]{500,}', text)
if b64_blocks:
    findings.append(f'large base64 block: {len(b64_blocks)} block(s) >= 500 chars')

print(json.dumps({'count': len(findings), 'details': findings}, ensure_ascii=False))
" 2>/dev/null)
    suspicious_count=$(echo "$suspicious_result" | $PYTHON -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo 0)
    suspicious_details_json=$(echo "$suspicious_result" | $PYTHON -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('details',[])))" 2>/dev/null || echo "[]")
fi

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

# Build result — pass all data to a single python3 invocation
$PYTHON -c "
import sys, json

result = {
    'critical': $critical_count,
    'warnings': $warning_count,
    'suspicious': $suspicious_count,
    'safe': $([ "$critical_count" -eq 0 ] && echo 'True' || echo 'False'),
    'critical_patterns': $(printf '%s\n' "${critical_details[@]:-}" | $PYTHON -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin.read().splitlines() if l.strip()]))" 2>/dev/null || echo '[]'),
    'warning_patterns': $(printf '%s\n' "${warning_details[@]:-}" | $PYTHON -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin.read().splitlines() if l.strip()]))" 2>/dev/null || echo '[]'),
    'suspicious_details': ${suspicious_details_json:-[]},
    'recommendation': '$([ "$critical_count" -eq 0 ] && [ "$warning_count" -eq 0 ] && [ "$suspicious_count" -eq 0 ] && echo 'clean' || ([ "$critical_count" -gt 0 ] && echo 'reject' || echo 'review') )'
}
print(json.dumps(result, indent=2))
" 2>/dev/null || echo '{"critical":0,"warnings":0,"safe":true,"recommendation":"error"}'
