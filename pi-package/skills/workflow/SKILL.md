---
name: workflow
description: Structured plan→execute→validate workflow for agent-driven development. Use when planning multi-step work that will be handed off to execution agents.
---

# Workflow

Methodology for planning work that agents can execute autonomously.

## Core Principle: Clean Context, Atomic Work

Every spawned agent gets a fresh context window and does ONE thing.
The orchestrator iterates. The agent focuses.

Compaction is the enemy — once context gets summarized, reasoning
quality drops. The benchmark: **<40% context usage per task**.

If an agent needs to read the plan context, read relevant files,
implement, and verify — all of that combined must stay under 40%.

## Planning Methodology

### Step Design

The step is the atomic unit of execution. Each step gets its own
agent spawn with a clean context window.

Ask for every proposed step:
1. **Is this ONE thing?** If it has "and" in it, split it.
2. **Can an agent do this under 40% context?** Estimate the token cost: reading context + reading files + reasoning + output. All under budget.
3. **What proves this works?** A single bash command that returns 0.
4. **What does the agent need to know?** Just enough context, not the whole codebase.

### Step Sizing

Size by estimated token cost and reasoning complexity:

- The agent reads: plan context (~500 words) + step instruction (~100 words) + relevant source files
- The agent reasons: how complex is the logic? Simple wiring = cheap. Algorithm design = expensive.
- The agent writes: implementation output
- The agent verifies: check command output
- **Total must stay under 40% of context window**

Reasoning complexity is the key variable:
- Simple boilerplate (rename, add field, wire up import) → low reasoning cost, step can cover more ground
- Complex logic (state machines, parsers, concurrent patterns) → high reasoning cost, step must be smaller
- Multiple interacting concerns → split into separate steps even if each is small

If the agent would need to hold two complex things in mind at once, it's two steps.

### Check Commands

Every step has a `Check` field — a bash command that returns 0 on success:

- `tsc --noEmit` — types check
- `grep -q 'export function createUser' src/models/user.ts` — expected export exists
- `npm test -- --testPathPattern=user.test` — specific test passes
- `curl -s localhost:3000/health | jq -e .status` — endpoint responds

Keep checks fast and focused on the step's specific change.

### Checkpoints

Checkpoints are integration validation boundaries between groups of related steps.
They run a validation script that tests the combined effect:

- Place after a natural integration boundary (data layer done, API layer done, etc.)
- Script tests that the steps work together, not individually
- The orchestrator runs checkpoint scripts directly — no agent spawn needed
- If a checkpoint fails, execution stops for human review

### Plan Format

```markdown
# Plan: [title]

## Context
[200-500 words — project state, goal, constraints.
This is what every agent reads for orientation.
Keep it dense with signal, not padded with filler.]

## Steps

### Step 1: [name]
**Status:** pending
**Do:** [atomic instruction — what to implement/change]
**Check:** `[bash command returning 0 on success]`

### Step 2: [name]
**Status:** pending
**Do:** [atomic instruction]
**Check:** `[bash command]`

### Checkpoint: [milestone name]
**Status:** pending
**Script:** `.plan/validate-[name].sh`

### Step 3: [name]
**Status:** pending
**Do:** [atomic instruction]
**Check:** `[bash command]`
```

### Context Budget

Each agent gets a fresh context window. Budget allocation:

- Plan context section: ~500 words (read once from task prompt)
- Step instruction: ~100 words
- File reads: 1-3 files the agent discovers it needs
- Reasoning: depends on complexity — this is the variable cost
- Implementation: the actual code output
- Verification: check command output

**Total target: <40% context usage.**

The plan file itself is NOT read by executors — the orchestrator injects
only the context section + the specific step into the task prompt.
This keeps executor context lean.

Keep the plan file concise:
- Context section: 200-500 words
- Per-step: 50-150 words
- Total plan: under 3000 words
- Let agents discover code via search, don't paste it in the plan

### Common Pitfalls

- **Fat steps**: "Create the model and add validation and write tests" → three steps.
- **Vague checks**: "Verify it works" → useless. Concrete bash command.
- **Over-specified**: Listing every line to write → agent can figure out HOW. Specify the WHAT.
- **Under-specified check**: No check command → no automated verification.
- **Too much context**: Pasting file contents in the plan → agent should read files itself.
- **Coupled steps**: Step 3 can't verify without step 2's uncommitted changes → reorder or merge.
- **Underestimating reasoning cost**: A "simple" step that requires understanding 5 interacting modules is not simple.
