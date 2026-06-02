#!/bin/bash
# Generate screenshots of all example HTML files for READMEs
# Requires: macOS with qlmanage
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
LANGS="zh en ja ko es"

echo "Generating thumbnails for all example HTML files..."
for lang in $LANGS; do
    for type in with without; do
        file="$DIR/../${lang}/output-${type}-skill.html"
        dest="$DIR/${lang}-${type}.png"
        echo -n "  ${lang}-${type}... "
        qlmanage -t -s 1400 -o /tmp/ql-skills-123 "$file" 2>/dev/null
        cp /tmp/ql-skills-123/output-${type}-skill.html.png "$dest" 2>/dev/null || true
        rm -f /tmp/ql-skills-123/output-${type}-skill.html.png 2>/dev/null || true
        echo "✓"
    done
done
echo "Done! $(ls "$DIR"/*.png 2>/dev/null | wc -l) screenshots in $DIR/"
