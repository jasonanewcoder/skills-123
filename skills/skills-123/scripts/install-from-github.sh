#!/bin/bash
#===============================================================================
# install-from-github.sh — Install a Claude Code skill from a GitHub repo
#
# Usage: install-from-github.sh <repo-url> [skill-subpath]
# Example: install-from-github.sh https://github.com/anthropics/skills skills/docx
#          install-from-github.sh https://github.com/daymade/claude-code-skills
#
# Installs to: ~/.claude/skills/<skill-name>/
#===============================================================================

set -euo pipefail

REPO_URL="${1:-}"
SKILL_SUBPATH="${2:-.}"
SKILLS_DIR="${HOME}/.claude/skills"

if [ -z "$REPO_URL" ]; then
    echo '{"error": "usage: install-from-github.sh <repo-url> [skill-subpath]"}'
    exit 1
fi

# Normalize URL: strip .git suffix, ensure https
REPO_URL=$(echo "$REPO_URL" | sed 's/\.git$//')
REPO_URL=$(echo "$REPO_URL" | sed 's|^git@github.com:|https://github.com/|')

# Extract owner/repo from URL
OWNER_REPO=$(echo "$REPO_URL" | sed 's|https://github.com/||' | sed 's|/$||')
if [ -z "$OWNER_REPO" ] || [ "$OWNER_REPO" = "$REPO_URL" ]; then
    echo '{"error": "invalid GitHub URL format"}'
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "{\"status\":\"installing\",\"repo\":\"${OWNER_REPO}\",\"subpath\":\"${SKILL_SUBPATH}\"}"

# Method 1: Try git clone (preferred)
if command -v git &>/dev/null; then
    echo '{"status":"cloning","method":"git"}'
    if git clone --depth 1 --filter=blob:none "https://github.com/${OWNER_REPO}.git" "$TMPDIR" 2>/dev/null; then
        echo '{"status":"cloned","method":"git"}'
    else
        echo '{"status":"git_failed","trying":"tarball"}'
        # Method 2: Fall back to tarball
        TARBALL_URL="https://api.github.com/repos/${OWNER_REPO}/tarball"
        curl -sL "$TARBALL_URL" -o "$TMPDIR/repo.tar.gz"
        mkdir -p "$TMPDIR/repo"
        tar xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR/repo" --strip-components=1 2>/dev/null || true
        # Move contents to TMPDIR root for consistent access
        if [ -d "$TMPDIR/repo" ]; then
            rm -rf "$TMPDIR"/*
            mv "$TMPDIR/repo"/* "$TMPDIR/" 2>/dev/null || true
            rmdir "$TMPDIR/repo" 2>/dev/null || true
        fi
    fi
else
    # Method 2: Use tarball directly (no git)
    echo '{"status":"downloading","method":"tarball"}'
    TARBALL_URL="https://api.github.com/repos/${OWNER_REPO}/tarball"
    curl -sL "$TARBALL_URL" -o "$TMPDIR/repo.tar.gz"
    mkdir -p "$TMPDIR/extracted"
    tar xzf "$TMPDIR/repo.tar.gz" -C "$TMPDIR/extracted" --strip-components=1 2>/dev/null || true
    rm -rf "$TMPDIR"/*
    if [ -d "$TMPDIR/extracted" ]; then
        mv "$TMPDIR/extracted"/* "$TMPDIR/" 2>/dev/null || true
        rmdir "$TMPDIR/extracted" 2>/dev/null || true
    fi
fi

# Find SKILL.md
SKILL_MD_PATH=""
if [ "$SKILL_SUBPATH" != "." ]; then
    # Check specific subpath first
    if [ -f "$TMPDIR/$SKILL_SUBPATH/SKILL.md" ]; then
        SKILL_MD_PATH="$TMPDIR/$SKILL_SUBPATH"
    fi
fi

# Search for SKILL.md if not found at subpath
if [ -z "$SKILL_MD_PATH" ]; then
    SKILL_MD_PATH=$(find "$TMPDIR" -name "SKILL.md" -not -path "*/.git/*" -not -path "*/node_modules/*" | head -1 | xargs dirname 2>/dev/null || echo "")
fi

if [ -z "$SKILL_MD_PATH" ] || [ ! -f "$SKILL_MD_PATH/SKILL.md" ]; then
    echo '{"error":"no SKILL.md found in repository"}'
    exit 1
fi

# Extract skill name from SKILL.md frontmatter
SKILL_NAME=$(grep -m1 "^name:" "$SKILL_MD_PATH/SKILL.md" | sed 's/^name: *//' | tr -d '\r' || echo "")
if [ -z "$SKILL_NAME" ]; then
    # Fallback: use directory name
    SKILL_NAME=$(basename "$SKILL_MD_PATH")
fi

# Check for name conflicts
if [ -d "$SKILLS_DIR/$SKILL_NAME" ]; then
    echo "{\"warning\":\"skill already exists at ${SKILLS_DIR}/${SKILL_NAME}\",\"overwriting\":true}"
fi

# Copy skill to target
TARGET="$SKILLS_DIR/$SKILL_NAME"
mkdir -p "$TARGET"

# Copy everything from the skill directory
cp -r "$SKILL_MD_PATH"/* "$TARGET/" 2>/dev/null || cp "$SKILL_MD_PATH/SKILL.md" "$TARGET/SKILL.md"

# Make scripts executable
find "$TARGET" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
find "$TARGET" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

# Verify installation
if [ -f "$TARGET/SKILL.md" ]; then
    INSTALLED_NAME=$(grep -m1 "^name:" "$TARGET/SKILL.md" | sed 's/^name: *//' | tr -d '\r' || echo "$SKILL_NAME")
    echo "{\"status\":\"installed\",\"name\":\"${INSTALLED_NAME}\",\"path\":\"${TARGET}\"}"
else
    echo '{"error":"installation verification failed"}'
    exit 1
fi
