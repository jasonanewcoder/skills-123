#!/bin/bash
#===============================================================================
# skills-123 — One-command installer
#
# One produces two, two produces three, three produces all things.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/<user>/skills-123/main/install.sh | bash
#   bash install.sh
#===============================================================================

set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo " skills-123 Installer"
echo " One produces two, two produces three, three produces all things."
echo "============================================"
echo ""

# Create target directories
mkdir -p "${SKILLS_DIR}/skills-123/scripts"
mkdir -p "${SKILLS_DIR}/skills-123/references"
mkdir -p "${SKILLS_DIR}/skills-123/cache"
mkdir -p "${SKILLS_DIR}/skills-123-suggest"

# Copy core skill
if [ -f "${SCRIPT_DIR}/skills/skills-123/SKILL.md" ]; then
    cp "${SCRIPT_DIR}/skills/skills-123/SKILL.md" "${SKILLS_DIR}/skills-123/SKILL.md"
    echo "✓ Installed skills-123/SKILL.md"
else
    echo "✗ ERROR: skills/skills-123/SKILL.md not found"
    echo "  Please run this script from the skills-123 project root."
    exit 1
fi

# Copy scripts
if [ -d "${SCRIPT_DIR}/skills/skills-123/scripts" ]; then
    cp -r "${SCRIPT_DIR}/skills/skills-123/scripts/"* "${SKILLS_DIR}/skills-123/scripts/"
    chmod +x "${SKILLS_DIR}/skills-123/scripts/"*.sh 2>/dev/null || true
    echo "✓ Installed skills-123/scripts/"
fi

# Copy references
if [ -d "${SCRIPT_DIR}/skills/skills-123/references" ]; then
    cp -r "${SCRIPT_DIR}/skills/skills-123/references/"* "${SKILLS_DIR}/skills-123/references/"
    echo "✓ Installed skills-123/references/"
fi

# Copy suggest skill
if [ -f "${SCRIPT_DIR}/skills/skills-123-suggest/SKILL.md" ]; then
    cp "${SCRIPT_DIR}/skills/skills-123-suggest/SKILL.md" "${SKILLS_DIR}/skills-123-suggest/SKILL.md"
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
