---
name: research
description: Structured research methodology for evaluating technical approaches, libraries, and patterns. Extracts findings to files to survive compaction and avoid context rot. Prefers first-class sources (official docs, maintainer examples). Use when comparing approaches, choosing between libraries, or investigating how to implement something.
---

# Research

Methodology for technical research that keeps context clean and preserves findings in files.

## Principles

1. **Context is for computation, files are for storage** — write findings to files, don't accumulate raw docs in context
2. **One-in-one-out** — hold at most ONE raw source in context at a time; extract to file, move on
3. **Stay under 40% context** — reasoning quality degrades beyond this; your research files are extended memory
4. **First-class sources first** — official docs > maintainer posts > community guides. When sources conflict, higher authority wins
5. **Extract, don't summarize** — capture verbatim code, exact API signatures, and specific caveats rather than narrative summaries
6. **Explicitly extract gotchas** — caveats, limitations, and edge cases are the most commonly lost information; always call them out

## Workflow

1. **Discover** — search broadly, identify candidate approaches, triage by source authority
2. **Extract** — for each source sequentially: read it, write structured notes to a file, move on. Never hold two raw sources simultaneously
3. **Evaluate** — with clean context, read only your notes files, reason about tradeoffs from first principles
4. **Synthesize** — write recommendation with evidence anchored to your notes files

Write all findings to a research directory (e.g., `.research/`). One file per approach or source, plus whatever index or comparison files are useful. The structure should fit the research question — don't force a rigid template.

## Source Authority

1. **Official documentation** — docs site, README in the source repo
2. **Maintainer communications** — blog posts, talks, RFCs by core team
3. **Official examples** — example directories in the source repo
4. **Established community voices** — well-known contributors, curated guides
5. **Tutorials and articles** — general tech blogs
6. **Forums and Q&A** — useful for discovering gotchas; verify claims against higher sources

## What to Capture in Notes

For each source, always include the source URL (for verification) and authority level. Beyond that, prioritize:

- **Verbatim code examples** — never paraphrase code
- **Gotchas, caveats, limitations** — extract these explicitly; they're what gets lost
- **Why it works** — first principles, not just surface mechanics
- **Version and compatibility constraints** — breaking changes, minimum versions
- **Applicability** — how well it fits the specific requirements at hand

## Web Research

Requires the **brave-search** skill. Load it for search and content extraction commands:
```
/skill:brave-search
```

When reading large documentation pages, scan structure first, then read only the sections relevant to your evaluation criteria.

## Subagent Fan-Out (4+ Sources)

When researching 4 or more sources, consider dispatching parallel `researcher` subagents. Each gets a fresh context window at peak quality.

Write your criteria and a notes template to files first so the subagents have context. After fan-out, return to evaluation with a clean context — the heavy reading happened in subagent windows.

## Local Codebase Research

Same principles apply. Use `grep` and `find` to locate code, `read` with specific line ranges, extract notes to files, move on. The code is always re-readable — your notes capture the key patterns and interfaces.
