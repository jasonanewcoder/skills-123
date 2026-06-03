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

# ── Mirror config for China / slow networks ──────────────────────────────────
# Set CHINA_MODE=1 or SKILLS_MIRROR_GIT to enable mirror acceleration.
# Mirrors are dynamically discovered (no hardcoded list — they expire).
# SKILLS_MIRROR_GIT: prefix prepended to github.com URLs for clone/download.
#   e.g. "https://your-mirror.com/"  →  https://your-mirror.com/https://github.com/...
CHINA_MODE="${CHINA_MODE:-0}"
SKILLS_MIRROR_GIT="${SKILLS_MIRROR_GIT:-}"
GIT_MIRROR=""
if [ -n "$SKILLS_MIRROR_GIT" ]; then
    GIT_MIRROR="$SKILLS_MIRROR_GIT"
elif [ "$CHINA_MODE" = "1" ]; then
    # Try dynamic mirror discovery via fetch-local.sh
    local_fetch_script="${HOME}/.claude/skills/skills-123/scripts/fetch-local.sh"
    if [ -x "$local_fetch_script" ]; then
        GIT_MIRROR=$(bash "$local_fetch_script" mirror-git 2>/dev/null || echo "")
    fi
fi

# Build mirrored URL if mirror configured
mirror_url() {
    local url="$1"
    if [ -n "$GIT_MIRROR" ]; then
        echo "${GIT_MIRROR}${url}"
    else
        echo "$url"
    fi
}

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

# Determine download method and execute
download_repo() {
    local dest="$1"
    local owner_repo="$2"

    # Method 1: git clone (preferred, --depth 1 is fast)
    if command -v git &>/dev/null; then
        echo '{"status":"cloning","method":"git"}'

        # Try direct git clone first
        if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --filter=blob:none \
            "https://github.com/${owner_repo}.git" "$dest" 2>/dev/null; then
            echo '{"status":"cloned","method":"git","via":"direct"}'
            return 0
        fi

        # Direct failed — try mirrored clone if configured
        if [ -n "$GIT_MIRROR" ]; then
            local mirrored_git_url
            mirrored_git_url="$(mirror_url "https://github.com/${owner_repo}.git")"
            echo "{\"status\":\"cloning_mirror\",\"method\":\"git\",\"url\":\"${mirrored_git_url}\"}"
            if GIT_TERMINAL_PROMPT=0 git clone --depth 1 --filter=blob:none \
                "$mirrored_git_url" "$dest" 2>/dev/null; then
                echo '{"status":"cloned","method":"git","via":"mirror"}'
                return 0
            fi
        fi

        # Git clone failed — fall through to tarball
        echo '{"status":"git_failed","trying":"tarball"}'
    fi

    # Method 2: Tarball download (works without git)
    echo '{"status":"downloading","method":"tarball"}'

    local tarball_url="https://api.github.com/repos/${owner_repo}/tarball"
    local tarball_file="$dest/repo.tar.gz"

    # Try direct tarball first, then mirrored
    if ! curl -sSL --max-time 120 --retry 2 \
        -H "User-Agent: skills-123-installer/1.0" \
        -o "$tarball_file" "$tarball_url" 2>/dev/null; then
        if [ -n "$GIT_MIRROR" ]; then
            local mirrored_tarball
            mirrored_tarball="$(mirror_url "$tarball_url")"
            curl -sSL --max-time 120 --retry 2 \
                -H "User-Agent: skills-123-installer/1.0" \
                -o "$tarball_file" "$mirrored_tarball" 2>/dev/null || true
        fi
    fi

    if [ -f "$tarball_file" ] && [ -s "$tarball_file" ]; then
        mkdir -p "$dest/extracted"
        tar xzf "$tarball_file" -C "$dest/extracted" --strip-components=1 2>/dev/null || true
        rm -rf "$dest"/*
        if [ -d "$dest/extracted" ]; then
            mv "$dest/extracted"/* "$dest/" 2>/dev/null || true
            rmdir "$dest/extracted" 2>/dev/null || true
        fi
        rm -f "$tarball_file"
        return 0
    fi

    return 1
}

download_repo "$TMPDIR" "$OWNER_REPO" || {
    echo '{"error":"failed to download repository"}'
    exit 1
}

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
