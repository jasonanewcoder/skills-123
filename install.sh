#!/bin/bash
#===============================================================================
# skills-123 — One-command installer
#
# One produces two, two produces three, three produces all things.
#
# Usage:
#   # Pipe directly from GitHub (no local clone needed):
#   curl -sL https://raw.githubusercontent.com/jasonanewcoder/skills-123/main/install.sh | bash
#
#   # Or run from a local clone:
#   git clone https://github.com/jasonanewcoder/skills-123.git
#   cd skills-123
#   bash install.sh
#===============================================================================

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
REPO_URL="https://github.com/jasonanewcoder/skills-123.git"
TMP_DIR=""

# Detect how we're being run
# BASH_SOURCE[0] is non-empty only when run from a file (not piped)
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    # Running from a local file — use its directory as source
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SOURCE_DIR="${SCRIPT_DIR}"
    SHOULD_CLEANUP=false
else
    # Piped via curl — clone the repo to a temp dir
    SOURCE_DIR="$(mktemp -d)"
    TMP_DIR="${SOURCE_DIR}"
    SHOULD_CLEANUP=true
fi

cleanup() {
    if [ "${SHOULD_CLEANUP}" = true ] && [ -n "${TMP_DIR}" ] && [ -d "${TMP_DIR}" ]; then
        rm -rf "${TMP_DIR}"
    fi
}
trap cleanup EXIT

echo "============================================"
echo " skills-123 Installer"
echo " One produces two, two produces three, three produces all things."
echo "============================================"
echo ""

# If piped, clone the repo first
if [ "${SHOULD_CLEANUP}" = true ]; then
    echo "→ Cloning skills-123 from GitHub..."
    if command -v git &>/dev/null; then
        git clone --depth 1 --quiet "${REPO_URL}" "${SOURCE_DIR}" 2>/dev/null || {
            echo "✗ ERROR: Failed to clone ${REPO_URL}"
            echo "  Make sure git is installed and you have network access."
            exit 1
        }
    else
        echo "✗ ERROR: git is not installed."
        echo "  Please install git or run this script from a local clone."
        exit 1
    fi
    echo "✓ Repository cloned"
fi

# Create target directories
mkdir -p "${SKILLS_DIR}/skills-123/scripts"
mkdir -p "${SKILLS_DIR}/skills-123/references"
mkdir -p "${SKILLS_DIR}/skills-123/cache"
mkdir -p "${SKILLS_DIR}/skills-123-suggest"

SRC="${SOURCE_DIR}/skills"

# Copy core skill
if [ -f "${SRC}/skills-123/SKILL.md" ]; then
    cp "${SRC}/skills-123/SKILL.md" "${SKILLS_DIR}/skills-123/SKILL.md"
    echo "✓ Installed skills-123/SKILL.md"
else
    echo "✗ ERROR: skills/skills-123/SKILL.md not found at ${SRC}"
    echo "  Source directory contents:"
    ls -la "${SOURCE_DIR}/" 2>/dev/null || echo "  (source directory missing)"
    exit 1
fi

# Copy scripts
if [ -d "${SRC}/skills-123/scripts" ]; then
    cp -r "${SRC}/skills-123/scripts/"* "${SKILLS_DIR}/skills-123/scripts/"
    chmod +x "${SKILLS_DIR}/skills-123/scripts/"*.sh 2>/dev/null || true
    echo "✓ Installed skills-123/scripts/"
fi

# Copy references
if [ -d "${SRC}/skills-123/references" ]; then
    cp -r "${SRC}/skills-123/references/"* "${SKILLS_DIR}/skills-123/references/"
    echo "✓ Installed skills-123/references/"
fi

# Copy suggest skill
if [ -f "${SRC}/skills-123-suggest/SKILL.md" ]; then
    cp "${SRC}/skills-123-suggest/SKILL.md" "${SKILLS_DIR}/skills-123-suggest/SKILL.md"
    echo "✓ Installed skills-123-suggest/SKILL.md"
else
    echo "✗ ERROR: skills/skills-123-suggest/SKILL.md not found"
    exit 1
fi

echo ""
echo "============================================"
echo " Installation complete!"
echo ""
echo " Skills installed to:"
echo "   ${SKILLS_DIR}/skills-123/"
echo "   ${SKILLS_DIR}/skills-123-suggest/"
echo ""
echo " Restart Claude Code to activate."
echo "============================================"
