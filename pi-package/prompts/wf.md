---
description: Start the plan→execute→validate workflow for agent-driven development
---
Load the workflow skill (/skill:workflow) and begin planning: $@

Start by understanding the current codebase relevant to this work.
Then structure a plan with phases organized around testability boundaries.

For each phase, design:
1. A clear goal (one sentence)
2. Concrete tasks
3. An executable validation script (the most important part)
4. Validation setup (infrastructure needed)

Use the questionnaire tool to clarify ambiguities.

When the plan is ready, I'll use /wf write to save the plan + validation scripts
to disk, then /wf exec to run execution agents autonomously.
