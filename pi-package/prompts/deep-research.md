---
description: Deep research using subagent fan-out for parallel source extraction
---
Load the research skill and follow its methodology to deep-research: $@

Use subagent fan-out for the extraction phase — dispatch parallel researcher agents to extract notes from each source simultaneously. This gives each extraction a fresh context window at peak quality.

Workflow:
1. Discovery phase (this agent): search, triage candidates, write .research/_criteria.md and .research/_index.md and .research/_template.md
2. Extraction phase (researcher subagents in parallel): each extracts notes to .research/approach-name.md
3. Evaluation phase (this agent): read notes files, build comparison matrix, reason about tradeoffs
4. Synthesis phase (this agent): write recommendation with evidence

Keep this agent's context clean — the heavy reading happens in subagent context windows.
