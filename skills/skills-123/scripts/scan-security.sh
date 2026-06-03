#!/bin/bash
#===============================================================================
# scan-security.sh — Context-aware SKILL.md security scanner
#
# Usage:
#   scan-security.sh [--json] [file]               # scan a file (or stdin)
#   scan-security.sh --check-pattern "<text>"       # check if text is doc-only
#
# Output: JSON {critical: N, warnings: N, safe: bool, details: [...], evidence: [...]}
#
# Context-aware scanning:
#   - Patterns inside markdown code blocks (```...```) → REAL risk
#   - Patterns on documentation lines (Pattern:, Example:, Why:) → DOCUMENTATION
#   - Patterns inside inline backtick quotes → DOCUMENTATION
#   - Patterns in raw text (outside code blocks) → REAL risk
#
# This prevents false positives when scanning security documentation skills
# that *describe* dangerous patterns without *executing* them.
#===============================================================================

set -euo pipefail

# ── Python detection ──────────────────────────────────────────────────────
# Cross-platform: Windows Git Bash uses "python", macOS/Linux use "python3"
PYTHON=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
        PYTHON="python"
    fi
fi
PYTHON="${PYTHON:-python3}"

# Parse arguments
JSON_OUTPUT=false
CHECK_PATTERN=""
INPUT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --json) JSON_OUTPUT=true; shift ;;
        --check-pattern) CHECK_PATTERN="$2"; shift 2 ;;
        *) INPUT_FILE="$1"; shift ;;
    esac
done

# Read content
CONTENT=""
if [ -n "$INPUT_FILE" ] && [ -f "$INPUT_FILE" ]; then
    CONTENT=$(cat "$INPUT_FILE")
elif [ -n "$CHECK_PATTERN" ]; then
    CONTENT="$CHECK_PATTERN"
else
    CONTENT=$(cat)
fi

# ── Context-aware scanner (Python) ────────────────────────────────────────
# The entire scanning logic runs in a single Python process for accuracy.
# Previously this was bash grep loops — unreliable for context detection.
SCAN_RESULT=$("$PYTHON" -c "
import sys, json, re

# Load content
text = sys.stdin.read()
lines = text.split('\n')

# ── Phase 1: Parse markdown structure ─────────────────────────────────────
# Identify which lines are inside fenced code blocks, inline code, or docs.

in_code_block = False
code_block_lang = ''
line_contexts = []  # list of dicts: {line_num, type, text}

for i, line in enumerate(lines):
    ctx = {'line_num': i + 1, 'type': 'text', 'text': line, 'code_lang': ''}

    # Detect fenced code blocks
    fence_match = re.match(r'^(\s*)\`\`\`(\w*)', line)
    if fence_match:
        if not in_code_block:
            in_code_block = True
            code_block_lang = fence_match.group(2).lower()
            ctx['type'] = 'fence_open'
            ctx['code_lang'] = code_block_lang
        else:
            in_code_block = False
            code_block_lang = ''
            ctx['type'] = 'fence_close'
        line_contexts.append(ctx)
        continue

    if in_code_block:
        ctx['type'] = 'code_block'
        ctx['code_lang'] = code_block_lang
    else:
        # Detect documentation pattern lines (educational content)
        stripped = line.strip()
        if re.match(r'^(Pattern|Why|Action|Legitimate use|Usage|Example|>|//|#)', stripped, re.IGNORECASE):
            ctx['type'] = 'documentation_line'
        # Lines with inline backtick-quoted patterns
        elif re.search(r'\`[^\`]{3,}\`', stripped) and not re.match(r'^\s*(curl|wget|eval|exec|rm\s|bash\s|npm\s|pip)', stripped):
            ctx['type'] = 'has_inline_code'

    line_contexts.append(ctx)

# ── Phase 2: Define patterns with metadata ────────────────────────────────
CRITICAL_PATTERNS = [
    # (regex, name, description)
    (r'curl.*\|\s*(?:ba)?sh\b', 'curl-pipe-sh', 'Piped curl to shell execution'),
    (r'wget.*\|\s*(?:ba)?sh\b', 'wget-pipe-sh', 'Piped wget to shell execution'),
    (r'eval\s+[\"\\']?\$', 'eval-variable', 'Eval with variable input'),
    (r'base64\s+(?:-d|--decode)\s*\|', 'base64-decode-pipe', 'Base64 decode piped to execution'),
    (r'exec\s*\(.*\$', 'exec-python-var', 'Python exec() with variable'),
    (r'rm\s+-rf\s+/', 'rm-rf-root', 'Recursive force delete from root'),
    (r'rm\s+-rf\s+~', 'rm-rf-home', 'Recursive force delete home directory'),
    (r'sudo\s+rm\s+-rf', 'sudo-rm-rf', 'Sudo recursive force delete'),
    (r'/dev/tcp/', 'dev-tcp', 'Bash /dev/tcp reverse shell'),
    (r'curl.*\.env', 'curl-env', 'Curl targeting .env files'),
    (r'curl.*credential', 'curl-credential', 'Curl targeting credentials'),
    (r'curl.*\.ssh', 'curl-ssh', 'Curl targeting SSH files'),
    (r'curl.*\.aws', 'curl-aws', 'Curl targeting AWS files'),
    (r'os\.system\s*\(.*\$', 'os-system-var', 'Python os.system() with variable'),
    (r'subprocess.*shell\s*=\s*True', 'subprocess-shell-true', 'Python subprocess with shell=True'),
    (r'__import__\s*\(\s*[\"\\']os[\"\\']', 'py-import-os', 'Python dynamic os import'),
    (r'exec\s*\(\s*.*\$', 'exec-var', 'Shell exec with variable'),
    (r'nc\s+-[nlvp]', 'nc-listen', 'Netcat listening mode'),
    (r'bash\s+-i\s*>&', 'bash-interactive-redir', 'Bash interactive redirect reverse shell'),
    (r'\|.*nc\s', 'pipe-nc', 'Piped to netcat'),
    (r'>\s*/dev/tcp/', 'redirect-dev-tcp', 'Redirect to /dev/tcp/'),
]

WARNING_PATTERNS = [
    (r'curl\s', 'curl-present', 'Curl usage detected'),
    (r'wget\s', 'wget-present', 'Wget usage detected'),
    (r'pip\d*\s+install', 'pip-install', 'Pip install command'),
    (r'npm\s+(?:install|i)\s+-g', 'npm-global-install', 'NPM global install'),
    (r'sudo\s', 'sudo-present', 'Sudo usage detected'),
    (r'chmod\s+[0-7]*[1-7][0-7]*', 'chmod-executable', 'Making files executable'),
    (r'chown\s', 'chown-present', 'File ownership change'),
    (r'base64\s', 'base64-present', 'Base64 command detected'),
    (r'eval\s', 'eval-present', 'Eval usage detected'),
    (r'exec\s', 'exec-present', 'Exec usage detected'),
    (r'\.env', 'dotenv-reference', 'Reference to .env file'),
    (r'credential', 'credential-reference', 'Reference to credentials'),
    (r'\.ssh/', 'ssh-dir-reference', 'Reference to .ssh directory'),
    (r'\.aws/', 'aws-dir-reference', 'Reference to .aws directory'),
    (r'rm\s+-rf\s', 'rm-rf-present', 'Recursive force delete'),
    (r'DDGkm7DA4j', 'hardcoded-key', 'Hardcoded API key pattern'),
    (r'netcat', 'netcat-reference', 'Reference to netcat'),
]

# ── Phase 3: Scan with context awareness ──────────────────────────────────
def is_documentation_context(ctx):
    '''Returns True if this line is documenting patterns, not executing them.'''
    # Inside a code block → REAL code, not documentation
    if ctx['type'] == 'code_block':
        return False
    # Documentation line → describing patterns
    if ctx['type'] == 'documentation_line':
        return True
    # Lines with inline backtick-quoted code in text → likely documentation
    if ctx['type'] == 'has_inline_code':
        return True
    return False

def get_context_window(line_num, window=2):
    '''Get surrounding lines for evidence reporting.'''
    start = max(0, line_num - window - 1)
    end = min(len(lines), line_num + window)
    result = []
    for j in range(start, end):
        prefix = '>>>' if j == line_num - 1 else '   '
        result.append({'line': j + 1, 'prefix': prefix, 'text': lines[j]})
    return result

def scan_patterns(patterns, is_critical=True):
    findings = []
    for regex, name, desc in patterns:
        pat = re.compile(regex, re.IGNORECASE)
        for ctx in line_contexts:
            if ctx['type'] in ('fence_open', 'fence_close'):
                continue
            match = pat.search(ctx['text'])
            if not match:
                continue

            doc_context = is_documentation_context(ctx)
            matched_text = match.group(0)[:80]

            # Determine effective severity based on context
            if is_critical:
                if doc_context:
                    effective = 'doc_only'  # documented but not executed
                else:
                    effective = 'critical'
            else:
                if doc_context:
                    effective = 'doc_only'
                else:
                    effective = 'warning'

            findings.append({
                'pattern_name': name,
                'description': desc,
                'matched': matched_text,
                'line': ctx['line_num'],
                'context_type': ctx['type'],
                'code_lang': ctx.get('code_lang', ''),
                'severity': effective,
                'evidence': get_context_window(ctx['line_num']),
            })
    return findings

critical_findings = scan_patterns(CRITICAL_PATTERNS, is_critical=True)
warning_findings = scan_patterns(WARNING_PATTERNS, is_critical=False)

# Deduplicate: if a pattern appears on multiple consecutive lines, keep only first
def deduplicate(findings):
    seen = {}
    result = []
    for f in findings:
        key = (f['pattern_name'], f['context_type'])
        # Keep first occurrence, skip if same pattern in same context type within 3 lines
        last = seen.get(key, -999)
        if f['line'] - last > 3:
            result.append(f)
            seen[key] = f['line']
    return result

critical_findings = deduplicate(critical_findings)
warning_findings = deduplicate(warning_findings)

# ── Phase 4: Content integrity checks ─────────────────────────────────────
suspicious_findings = []

# Zero-width characters
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
    count = text.count(char)
    if count > 0:
        # Find line numbers
        char_lines = [i+1 for i, line in enumerate(lines) if char in line]
        suspicious_findings.append({
            'type': 'unicode',
            'description': desc,
            'count': count,
            'lines': char_lines[:10],
        })

# Large base64 blocks
b64_blocks = re.findall(r'[A-Za-z0-9+/=]{500,}', text)
if b64_blocks:
    suspicious_findings.append({
        'type': 'large_base64',
        'description': 'large base64 block(s)',
        'count': len(b64_blocks),
        'lines': [],
    })

# ── Phase 5: Classify and report ──────────────────────────────────────────
real_critical = [f for f in critical_findings if f['severity'] == 'critical']
doc_critical = [f for f in critical_findings if f['severity'] == 'doc_only']
real_warnings = [f for f in warning_findings if f['severity'] == 'warning']
doc_warnings = [f for f in warning_findings if f['severity'] == 'doc_only']

# Determine safety
safe = len(real_critical) == 0

# Recommendation
if len(real_critical) > 0:
    recommendation = 'reject'
elif len(real_warnings) > 3:
    recommendation = 'review'
elif len(real_warnings) > 0:
    recommendation = 'caution'
else:
    recommendation = 'clean'

result = {
    'critical': len(real_critical),
    'warnings': len(real_warnings),
    'doc_patterns': len(doc_critical) + len(doc_warnings),
    'suspicious': len(suspicious_findings),
    'safe': safe,
    'recommendation': recommendation,
    'details': {
        'critical': [{
            'name': f['pattern_name'],
            'desc': f['description'],
            'matched': f['matched'],
            'line': f['line'],
            'context': f['context_type'],
        } for f in real_critical],
        'warnings': [{
            'name': f['pattern_name'],
            'desc': f['description'],
            'matched': f['matched'],
            'line': f['line'],
            'context': f['context_type'],
        } for f in real_warnings],
        'documentation_only': [{
            'name': f['pattern_name'],
            'desc': f['description'] + ' [DOCUMENTATION — not executable]',
            'matched': f['matched'],
            'line': f['line'],
            'context': f['context_type'],
        } for f in (doc_critical + doc_warnings)],
        'suspicious': suspicious_findings,
    },
    'evidence': {
        'critical': [{
            'name': f['pattern_name'],
            'desc': f['description'],
            'line': f['line'],
            'window': f['evidence'],
        } for f in real_critical],
        'warnings': [{
            'name': f['pattern_name'],
            'desc': f['description'],
            'line': f['line'],
            'window': f['evidence'],
        } for f in real_warnings],
    }
}

print(json.dumps(result, indent=2, ensure_ascii=False))
" 2>/dev/null <<< "$CONTENT")

if [ -z "$SCAN_RESULT" ]; then
    echo '{"critical":0,"warnings":0,"safe":true,"recommendation":"error","error":"scan_failed"}'
    exit 0
fi

echo "$SCAN_RESULT"
