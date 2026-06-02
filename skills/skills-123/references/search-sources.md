# Search Sources Reference

This document catalogs all data sources available for discovering Claude Code skills.
Use it when you need to expand the search net or find skills in specific domains.

## Primary Sources

### 1. GitHub Topic Search
- **Query format:** `site:github.com claude-code-skill <keywords>`
- **Coverage:** Repos explicitly tagged with the `claude-code-skill` topic
- **Freshness:** Real-time (GitHub index)
- **Strengths:** High signal-to-noise ratio, tagged repos are usually well-structured
- **Limitations:** Only covers repos that added the topic tag; misses many older or less-maintained skills

### 2. GitHub Code Search
- **Query format:** `"SKILL.md" "<keywords>" site:github.com`
- **Coverage:** Any repo containing a SKILL.md file matching keywords
- **Freshness:** Real-time
- **Strengths:** Broadest coverage; finds skills anywhere in the file tree
- **Limitations:** No quality signal; includes forks, experiments, and abandoned projects

### 3. Web Search
- **Query format:** `"<keywords>" "Claude Code" skill OR skills GitHub`
- **Coverage:** Blog posts, tutorials, social media mentions, documentation
- **Freshness:** Varies (search engine dependent)
- **Strengths:** Captures skills mentioned in articles, tweets, and discussions
- **Limitations:** Lower precision; may return non-skill results

## Registry & Aggregator Sources

### 4. claude-skill-registry-core
- **URL:** `https://github.com/majiayu000/claude-skill-registry-core`
- **Format:** JSON index files updated daily
- **Coverage:** Largest aggregator — 156K+ indexed skill references
- **Access:** Clone repo or fetch raw JSON from GitHub
- **Method:**
  ```bash
  # Fetch the search index
  curl -sL "https://raw.githubusercontent.com/majiayu000/claude-skill-registry-core/main/data/search-index.json"
  # Filter with jq
  curl ... | jq '.[] | select(.description | test("kubernetes"; "i"))'
  ```

### 5. awesome-claude-skills
- **URL:** `https://github.com/travisvn/awesome-claude-skills`
- **Format:** Curated markdown list organized by category
- **Coverage:** ~500 hand-picked, verified skills
- **Strength:** Human curation ensures quality; categorized for browsing
- **Method:** WebFetch the README, parse markdown links

### 6. awesome-claude-code
- **URL:** `https://github.com/onmyway133/awesome-claude-code`
- **Format:** Curated markdown list
- **Coverage:** Broad ecosystem coverage including skills, plugins, tools
- **Strength:** Well-maintained, community-vetted
- **Method:** WebFetch the README

## Community Skill Collections

### 7. daymade/claude-code-skills
- **URL:** `https://github.com/daymade/claude-code-skills`
- **Skills:** 52 production-ready skills with skill-creator meta-skill
- **Notable skills:** skill-creator, smart-completion, context-optimizer

### 8. julianobarbosa/claude-code-skills
- **URL:** `https://github.com/julianobarbosa/claude-code-skills`
- **Skills:** 55+ focused on Python, DevOps, Azure, Kubernetes, monitoring
- **Notable skills:** python-best-practices, k8s-deploy, terraform-plan

### 9. obra/superpowers
- **URL:** `https://github.com/obra/superpowers`
- **Skills:** 20+ battle-tested skills from the superpowers marketplace
- **Notable skills:** tdd-workflow, debug-harness, spec-driven-dev

### 10. ariadoss/superskills
- **URL:** `https://github.com/ariadoss/superskills`
- **Skills:** 33+ focused on TDD, debugging, security, spec workflows
- **Notable skills:** uats-generator, tdd-pilot, security-audit

## Official Sources

### 11. anthropics/claude-plugins-official
- **URL:** `https://github.com/anthropics/claude-plugins-official`
- **Type:** Official plugin marketplace
- **Format:** marketplace.json with 200+ plugin entries
- **Access:** Clone repo, parse marketplace.json
- **Method:**
  ```bash
  curl -sL "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json"
  ```

### 12. anthropics/skills
- **URL:** `https://github.com/anthropics/skills`
- **Type:** Official skill specification and examples
- **Contains:** Reference implementations, templates, best practices
- **Stars:** 37.5K+

## Search Strategy Recommendations

### For broad searches (exploratory):
1. Start with GitHub Topic Search + Web Search
2. If few results, add GitHub Code Search
3. Check awesome-lists for curated options

### For specific technology searches:
1. GitHub Code Search with technology name
2. Web Search for articles mentioning the skill
3. Check community collections for that domain

### For quality-critical searches:
1. Start with awesome lists (curated quality)
2. Check official sources
3. Cross-reference with registry for metadata

### Rate Limit Management

GitHub's unauthenticated API: **60 requests/hour**
Mitigations:
- Cache search results aggressively (24h TTL)
- Use WebSearch as primary (bypasses API limits)
- Batch GitHub API calls
- Prefer WebFetch of static content over API calls
