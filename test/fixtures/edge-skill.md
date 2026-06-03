---
name: edge-skill
description: Edge cases — zero-width chars, long lines, base64 blocks
---

# Edge Case Skill

## Zero-width characters test​​​ (3 zero-width spaces after "test")

## Long line test
This line is intentionally very long to test the long line detection — it contains repeated patterns that could hide malicious content beyond the visible area in editors and review tools that do not properly handle horizontal scrolling or line wrapping for security review purposes and might allow attackers to smuggle commands past human reviewers by placing them far to the right where they are not visible without scrolling horizontally which is a known attack vector in supply chain attacks against code review processes and automated scanning tools that only check the visible portion of a file or truncate lines at a certain width before analysis making them vulnerable to content that is placed beyond the truncation point in the file and therefore escaping detection by static analysis tools that rely on line-by-line scanning without considering the full width of extremely long lines that may contain arbitrary commands or data.

## Base64 block test (not a real payload, just padding)
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
