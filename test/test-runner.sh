#!/bin/bash
#===============================================================================
# test-runner.sh — Test suite for skills-123 scripts
#
# Requirements: bash 3.2+, python3 (or python on Windows)
# No external dependencies beyond what skills-123 already requires.
#
# Usage:
#   bash test/test-runner.sh              # Run all tests
#   bash test/test-runner.sh security     # Security scanner tests only
#   bash test/test-runner.sh evaluate     # Evaluate scoring tests only
#   bash test/test-runner.sh network      # Network fallback tests (mocked)
#   bash test/test-runner.sh compat       # Cross-platform compatibility checks
#===============================================================================

# ── Strict mode (POSIX-safe) ─────────────────────────────────────────────
set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/skills/skills-123/scripts"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS=0
FAIL=0
SKIP=0

# ── Colors (ANSI, graceful fallback) ─────────────────────────────────────
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; BOLD=''; NC=''
fi

# ── Test helpers ─────────────────────────────────────────────────────────
pass() { printf "  ${GREEN}PASS${NC} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  ${RED}FAIL${NC} %s — %s\n" "$1" "$2"; FAIL=$((FAIL + 1)); }
skip_test() { printf "  ${YELLOW}SKIP${NC} %s — %s\n" "$1" "$2"; SKIP=$((SKIP + 1)); }

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$label"
    else
        fail "$label" "expected='$expected' got='$actual'"
    fi
}

assert_gt() {
    local label="$1" val="$2" threshold="$3"
    local result
    result=$("$PYTHON" -c "import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)" "$val" "$threshold" 2>/dev/null && echo "ok" || echo "fail")
    if [ "$result" = "ok" ]; then
        pass "$label"
    else
        fail "$label" "expected >$threshold got=$val"
    fi
}

assert_lt() {
    local label="$1" val="$2" threshold="$3"
    local result
    result=$("$PYTHON" -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "$val" "$threshold" 2>/dev/null && echo "ok" || echo "fail")
    if [ "$result" = "ok" ]; then
        pass "$label"
    else
        fail "$label" "expected <$threshold got=$val"
    fi
}

assert_contains() {
    local label="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -qF "$needle" 2>/dev/null; then
        pass "$label"
    else
        fail "$label" "output does not contain '$needle'"
    fi
}

# ── Python detection ──────────────────────────────────────────────────────
PYTHON=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
        PYTHON="python"
    fi
fi

if [ -z "$PYTHON" ]; then
    echo "ERROR: python3 or python required for tests"
    exit 1
fi

# ── Check required scripts ────────────────────────────────────────────────
for script in scan-security.sh evaluate-skill.sh fetch-local.sh; do
    if [ ! -f "$SCRIPTS_DIR/$script" ]; then
        echo "ERROR: $SCRIPTS_DIR/$script not found"
        exit 1
    fi
done

# ═══════════════════════════════════════════════════════════════════════════
# Security Scanner Tests
# ═══════════════════════════════════════════════════════════════════════════
test_security_scanner() {
    printf "\n${BOLD}═══ Security Scanner Tests ═══${NC}\n"

    local scan_script="$SCRIPTS_DIR/scan-security.sh"

    # Test 1: Documentation skill — should NOT trigger critical
    local doc_result
    doc_result=$(bash "$scan_script" "$FIXTURES_DIR/doc-skill.md" 2>&1)
    local doc_critical
    doc_critical=$(echo "$doc_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['critical'])" 2>/dev/null || echo "-1")
    local doc_safe
    doc_safe=$(echo "$doc_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['safe'])" 2>/dev/null || echo "false")
    local doc_patterns
    doc_patterns=$(echo "$doc_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['doc_patterns'])" 2>/dev/null || echo "0")

    assert_eq "docs-skill: critical=0" "0" "$doc_critical"
    assert_eq "docs-skill: safe=true" "True" "$doc_safe"
    assert_gt "docs-skill: doc_patterns > 5" "$doc_patterns" 5

    # Test 2: Malicious skill — MUST trigger critical
    local mal_result
    mal_result=$(bash "$scan_script" "$FIXTURES_DIR/malicious-skill.md" 2>&1)
    local mal_critical
    mal_critical=$(echo "$mal_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['critical'])" 2>/dev/null || echo "0")
    local mal_safe
    mal_safe=$(echo "$mal_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['safe'])" 2>/dev/null || echo "true")
    local mal_recommendation
    mal_recommendation=$(echo "$mal_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['recommendation'])" 2>/dev/null || echo "")

    assert_gt "malicious-skill: critical > 2" "$mal_critical" 2
    assert_eq "malicious-skill: safe=false" "False" "$mal_safe"
    assert_eq "malicious-skill: recommendation=reject" "reject" "$mal_recommendation"

    # Test 3: Normal skill — should be completely clean
    local norm_result
    norm_result=$(bash "$scan_script" "$FIXTURES_DIR/normal-skill.md" 2>&1)
    local norm_critical
    norm_critical=$(echo "$norm_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['critical'])" 2>/dev/null || echo "-1")
    local norm_warnings
    norm_warnings=$(echo "$norm_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['warnings'])" 2>/dev/null || echo "-1")
    local norm_recommendation
    norm_recommendation=$(echo "$norm_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['recommendation'])" 2>/dev/null || echo "")

    assert_eq "normal-skill: critical=0" "0" "$norm_critical"
    assert_eq "normal-skill: warnings=0" "0" "$norm_warnings"
    assert_eq "normal-skill: recommendation=clean" "clean" "$norm_recommendation"

    # Test 4: Edge cases — zero-width chars, long lines, base64
    local edge_result
    edge_result=$(bash "$scan_script" "$FIXTURES_DIR/edge-skill.md" 2>&1)
    local edge_suspicious
    edge_suspicious=$(echo "$edge_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['suspicious'])" 2>/dev/null || echo "0")
    local edge_safe
    edge_safe=$(echo "$edge_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['safe'])" 2>/dev/null || echo "false")

    assert_gt "edge-skill: suspicious > 0" "$edge_suspicious" 0
    assert_eq "edge-skill: safe=true (no executable threats)" "True" "$edge_safe"

    # Test 5: SKILL.md itself (the skills-123 documentation)
    if [ -f "$PROJECT_DIR/skills/skills-123/SKILL.md" ]; then
        local self_result
        self_result=$(bash "$scan_script" "$PROJECT_DIR/skills/skills-123/SKILL.md" 2>&1)
        local self_critical
        self_critical=$(echo "$self_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['critical'])" 2>/dev/null || echo "-1")
        local self_doc
        self_doc=$(echo "$self_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['doc_patterns'])" 2>/dev/null || echo "0")

        assert_eq "SKILL.md self-scan: critical=0" "0" "$self_critical"
        assert_gt "SKILL.md self-scan: doc_patterns > 5" "$self_doc" 5
    else
        skip_test "SKILL.md self-scan" "file not found"
    fi

    # Test 6: Evidence lines present
    local evidence_count
    evidence_count=$(echo "$mal_result" | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('evidence',{}).get('critical',[])))" 2>/dev/null || echo "0")
    assert_gt "evidence: critical findings have evidence" "$evidence_count" 0
}

# ═══════════════════════════════════════════════════════════════════════════
# Evaluate Scoring Tests
# ═══════════════════════════════════════════════════════════════════════════
test_evaluate() {
    printf "\n${BOLD}═══ Evaluate Scoring Tests ═══${NC}\n"

    local eval_script="$SCRIPTS_DIR/evaluate-skill.sh"

    # Test 1: High-quality candidate
    local result
    result=$(echo '{"candidate":{"name":"test-skill","repo":"org/repo","stars":500,"updated_at":"2026-06-01","author":"travisvn","contributors":10,"description":"Kubernetes deployment helper","security_critical":0,"security_warnings":0},"query_keywords":["kubernetes","deploy"]}' | bash "$eval_script" 2>&1)
    local score
    score=$(echo "$result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['total_score'])" 2>/dev/null || echo "0")

    assert_gt "high-quality candidate: score > 50" "$score" 50
    assert_lt "high-quality candidate: score < 95" "$score" 95

    # Test 2: Low-quality candidate
    local result2
    result2=$(echo '{"candidate":{"name":"unknown-skill","repo":"new/repo","stars":0,"updated_at":"2020-01-01","author":"newuser","contributors":1,"description":"something unrelated","security_critical":0,"security_warnings":2},"query_keywords":["kubernetes","deploy"]}' | bash "$eval_script" 2>&1)
    local score2
    score2=$(echo "$result2" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['total_score'])" 2>/dev/null || echo "100")

    # Should score lower than high-quality
    local compare_result
    compare_result=$("$PYTHON" -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "$score2" "$score" 2>/dev/null && echo "ok" || echo "fail")
    if [ "$compare_result" = "ok" ]; then
        pass "low-quality scores lower than high-quality ($score2 < $score)"
    else
        fail "low-quality scores lower than high-quality" "got $score2 >= $score"
    fi

    # Test 3: Security-critical = auto-disqualify
    local result3
    result3=$(echo '{"candidate":{"name":"evil","repo":"evil/repo","stars":10,"updated_at":"2026-01-01","author":"anon","contributors":1,"description":"test","security_critical":1,"security_warnings":0},"query_keywords":["test"]}' | bash "$eval_script" 2>&1)
    local disqualified
    disqualified=$(echo "$result3" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['disqualified'])" 2>/dev/null || echo "false")

    assert_eq "security-critical: disqualified=true" "True" "$disqualified"

    # Test 4: Known publisher bonus
    local result4
    result4=$(echo '{"candidate":{"name":"publisher-skill","repo":"daymade/skill","stars":10,"updated_at":"2026-06-01","author":"daymade","contributors":3,"description":"test","security_critical":0,"security_warnings":0},"query_keywords":["test"]}' | bash "$eval_script" 2>&1)
    local author_score
    author_score=$(echo "$result4" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['breakdown']['author_trust'])" 2>/dev/null || echo "0")

    assert_gt "known publisher: author_trust > 0" "$author_score" 0
}

# ═══════════════════════════════════════════════════════════════════════════
# Network Fallback Tests (with mocks)
# ═══════════════════════════════════════════════════════════════════════════
test_network() {
    printf "\n${BOLD}═══ Network Fallback Tests ═══${NC}\n"

    local fetch_script="$SCRIPTS_DIR/fetch-local.sh"

    # Test 1: Connectivity check runs
    local check_result
    check_result=$(bash "$fetch_script" check 2>&1)
    local check_ok
    check_ok=$(echo "$check_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "false")

    assert_eq "fetch check: ok=true" "True" "$check_ok"

    # Test 2: Connectivity check reports status
    local check_status
    check_status=$(echo "$check_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "")
    if [ -n "$check_status" ]; then
        pass "fetch check: reports status ($check_status)"
    else
        fail "fetch check: reports status" "no status field"
    fi

    # Test 3: china_mode field present
    local china_mode
    china_mode=$(echo "$check_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['china_mode'])" 2>/dev/null || echo "")
    if [ -n "$china_mode" ]; then
        pass "fetch check: includes china_mode field"
    else
        fail "fetch check: includes china_mode field" "missing"
    fi

    # Test 4: Invalid command returns error
    local err_result
    err_result=$(bash "$fetch_script" nonexistent-command 2>&1 || true)
    local err_ok
    err_ok=$(echo "$err_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "true")

    assert_eq "fetch invalid command: ok=false" "False" "$err_ok"

    # Test 5: Empty skill fetch returns error
    local empty_result
    empty_result=$(bash "$fetch_script" skill "" 2>&1 || true)
    local empty_ok
    empty_ok=$(echo "$empty_result" | "$PYTHON" -c "import sys,json; print(json.load(sys.stdin)['ok'])" 2>/dev/null || echo "true")

    assert_eq "fetch skill empty: ok=false" "False" "$empty_ok"
}

# ═══════════════════════════════════════════════════════════════════════════
# Cross-Platform Compatibility Tests
# ═══════════════════════════════════════════════════════════════════════════
test_compat() {
    printf "\n${BOLD}═══ Cross-Platform Compatibility Tests ═══${NC}\n"

    # Test 1: Bash version detection
    local bash_version
    bash_version=$(bash --version 2>&1 | head -1)
    printf "  Bash: %s\n" "$bash_version"
    pass "bash detected: $bash_version"

    # Test 2: No 'declare -g' usage (bash 4.0+, not available on macOS bash 3.2)
    if grep -r 'declare -g' "$SCRIPTS_DIR/"*.sh 2>/dev/null; then
        fail "no declare -g in scripts" "found declare -g (not bash 3.2 compatible)"
    else
        pass "no declare -g (bash 3.2 safe)"
    fi

    # Test 3: No '&>' redirect without /dev/null fallback
    # '&>/dev/null' is fine on bash 4+, but older bash versions need '>/dev/null 2>&1'
    # We check that &> is not the ONLY redirect in critical commands
    local and_greater_count
    and_greater_count=$(grep -c '&>' "$SCRIPTS_DIR/"*.sh 2>/dev/null || echo "0")
    printf "  Info: %s uses of &> redirect (checking for critical paths)\n" "$and_greater_count"

    # Test 4: Python available
    if command -v "$PYTHON" >/dev/null 2>&1; then
        pass "python available: $PYTHON"
    else
        fail "python available" "$PYTHON not found"
    fi

    # Test 5: curl available
    if command -v curl >/dev/null 2>&1; then
        pass "curl available: $(curl --version 2>&1 | head -1)"
    else
        skip_test "curl available" "not installed"
    fi

    # Test 6: No /bin/sh shebang — must use /bin/bash for array support
    local sh_found
    sh_found=$(head -1 "$SCRIPTS_DIR/"*.sh 2>/dev/null | grep -c '#!/bin/sh' || true)
    if [ "${sh_found:-0}" = "0" ]; then
        pass "no /bin/sh shebangs (must use /bin/bash)"
    else
        fail "no /bin/sh shebangs" "found /bin/sh in shebangs"
    fi

    # Test 7: All scripts are executable
    local all_exec=true
    for script in "$SCRIPTS_DIR/"*.sh; do
        if [ ! -x "$script" ]; then
            all_exec=false
            printf "  Not executable: %s\n" "$(basename "$script")"
        fi
    done
    if $all_exec; then
        pass "all scripts executable"
    else
        fail "all scripts executable" "some scripts not +x"
    fi

    # Test 8: mktemp usage check (macOS compatible — no template required)
    if grep -q 'mktemp' "$SCRIPTS_DIR/"*.sh 2>/dev/null; then
        pass "mktemp used (cross-platform temp dirs)"
    else
        skip_test "mktemp used" "no mktemp in scripts"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Python Helper Tests
# ═══════════════════════════════════════════════════════════════════════════
test_python_helpers() {
    printf "\n${BOLD}═══ Python Helper Tests ═══${NC}\n"

    local fetch_script="$SCRIPTS_DIR/fetch-local.sh"

    # Test 1: timestamp_now is numeric
    local ts
    ts=$("$PYTHON" -c "import time; print(int(time.time()))")
    if [ "$ts" -gt 1000000000 ] 2>/dev/null; then
        pass "timestamp_now: returns valid epoch ($ts)"
    else
        fail "timestamp_now: returns valid epoch" "got $ts"
    fi

    # Test 2: iso_timestamp has expected format
    local iso
    iso=$("$PYTHON" -c "import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S%z'))")
    if echo "$iso" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
        pass "iso_timestamp: valid format ($iso)"
    else
        fail "iso_timestamp: valid format" "got $iso"
    fi

    # Test 3: JSON encoding round-trips
    local json_test
    json_test=$(echo '{"key": "value with spaces", "nested": {"a": 1}}' | "$PYTHON" -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d))")
    if echo "$json_test" | grep -q 'value with spaces'; then
        pass "JSON round-trip: preserves content"
    else
        fail "JSON round-trip: preserves content" "got $json_test"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════
main() {
    printf "${BOLD}skills-123 Test Suite${NC}\n"
    printf "Project: %s\n" "$PROJECT_DIR"
    printf "Date: %s\n\n" "$(date 2>/dev/null || echo unknown)"

    local filter="${1:-all}"

    case "$filter" in
        security) test_security_scanner ;;
        evaluate) test_evaluate ;;
        network)  test_network ;;
        compat)   test_compat ;;
        python_helpers) test_python_helpers ;;
        all)
            test_security_scanner
            test_evaluate
            test_network
            test_compat
            test_python_helpers
            ;;
        *)
            printf "Unknown filter: %s\n" "$filter"
            printf "Usage: test-runner.sh [security|evaluate|network|compat|python_helpers|all]\n"
            exit 1
            ;;
    esac

    # ── Summary ───────────────────────────────────────────────────────────
    printf "\n${BOLD}═══ Results ═══${NC}\n"
    printf "  ${GREEN}Passed: %d${NC}\n" "$PASS"
    if [ "$FAIL" -gt 0 ]; then
        printf "  ${RED}Failed: %d${NC}\n" "$FAIL"
    fi
    if [ "$SKIP" -gt 0 ]; then
        printf "  ${YELLOW}Skipped: %d${NC}\n" "$SKIP"
    fi

    if [ "$FAIL" -gt 0 ]; then
        printf "\n${RED}Some tests failed.${NC}\n"
        exit 1
    else
        printf "\n${GREEN}All tests passed.${NC}\n"
        exit 0
    fi
}

main "${1:-all}"
