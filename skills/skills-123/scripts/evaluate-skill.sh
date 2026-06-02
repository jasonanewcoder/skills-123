#!/bin/bash
#===============================================================================
# evaluate-skill.sh — Score a Claude Code skill candidate
#
# Usage: echo '{"candidate":{...},"query_keywords":["k8s","deploy"]}' | evaluate-skill.sh
# Output: JSON with score breakdown
#===============================================================================

set -euo pipefail

INPUT=$(cat)

# Parse input JSON
SCORE_JSON=$(python3 -c "
import sys, json, math
from datetime import datetime, timezone, timedelta

def evaluate(data):
    candidate = data.get('candidate', {})
    keywords = data.get('query_keywords', [])

    stars = candidate.get('stars', 0) or 0
    updated_str = candidate.get('updated_at', '') or ''
    author = candidate.get('author', '') or ''
    org = candidate.get('is_organization', False) or False
    contributors = candidate.get('contributors', 0) or 0
    name = candidate.get('name', '') or ''
    description = candidate.get('description', '') or ''
    warnings = candidate.get('security_warnings', 0) or 0
    critical = candidate.get('security_critical', 0) or 0

    # 1. Community Signal (0-15)
    community_score = min(15, math.log10(max(stars, 0) + 1) * 5)

    # 2. Recency (0-10)
    if updated_str:
        try:
            updated = datetime.fromisoformat(updated_str.replace('Z', '+00:00'))
            days_ago = (datetime.now(timezone.utc) - updated).days
            if days_ago <= 90:
                recency_score = 10
            elif days_ago <= 180:
                recency_score = 7
            elif days_ago <= 365:
                recency_score = 4
            else:
                recency_score = 1
        except:
            recency_score = 3  # Unknown format
    else:
        recency_score = 3  # No update info

    # 3. Author Trust (0-15)
    TRUSTED_ORGS = {
        'anthropics', 'vercel-labs', 'microsoft', 'cloudflare', 'hashicorp',
        'tailwindlabs', 'supabase', 'railwayapp', 'netlify', 'temporalio', 'prisma'
    }
    KNOWN_PUBLISHERS = {
        'daymade', 'obra', 'majiayu000', 'travisvn', 'julianobarbosa',
        'ariadoss', 'mattpocock', 'anombyte93', 'robertguss'
    }

    author_score = 0
    author_lower = author.lower()
    if org:
        author_score += 5
    if author_lower in TRUSTED_ORGS:
        author_score += 5
    if author_lower in KNOWN_PUBLISHERS:
        author_score += 5
    if contributors >= 5:
        author_score += 5
    author_score = min(15, author_score)

    # 4. Relevance (0-30)
    if keywords:
        search_text = (name + ' ' + description).lower()
        total_keywords = len(keywords)
        matches = 0.0
        for kw in keywords:
            kw_lower = kw.lower()
            if kw_lower in search_text:
                matches += 1.0
            # Check for common synonyms
            elif kw_lower == 'k8s' and 'kubernetes' in search_text:
                matches += 0.5
            elif kw_lower == 'kubernetes' and 'k8s' in search_text:
                matches += 0.5
            elif kw_lower == 'db' and 'database' in search_text:
                matches += 0.5
            elif kw_lower == 'database' and 'db' in search_text:
                matches += 0.5
            elif kw_lower in search_text.replace('-', ' ').replace('_', ' '):
                matches += 0.5
        relevance_score = (matches / total_keywords) * 30
    else:
        relevance_score = 15  # Neutral when no keywords provided

    # 5. Security (0-20)
    if critical > 0:
        security_score = -100  # Auto-disqualify
    elif warnings >= 3:
        security_score = 5
    elif warnings >= 1:
        security_score = 10
    else:
        security_score = 20

    # Total
    total = community_score + recency_score + author_score + relevance_score + security_score
    total = max(0, min(100, total))

    return {
        'name': name,
        'repo': candidate.get('repo', ''),
        'total_score': round(total, 1),
        'breakdown': {
            'community': round(community_score, 1),
            'recency': round(recency_score, 1),
            'author_trust': round(author_score, 1),
            'relevance': round(relevance_score, 1),
            'security': round(security_score, 1) if security_score > 0 else security_score
        },
        'stars': stars,
        'author': author,
        'disqualified': security_score < 0
    }

result = evaluate(json.loads(sys.stdin.read()))
print(json.dumps(result, indent=2))
" 2>/dev/null)

if [ -z "$SCORE_JSON" ]; then
    echo '{"error": "evaluation failed", "total_score": 0}'
else
    echo "$SCORE_JSON"
fi
