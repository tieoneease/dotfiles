---
name: workflow
description: Structured plan→execute→validate workflow for agent-driven development. Use when planning multi-phase work that will be handed off to execution agents.
---

# Workflow

Methodology for planning work that agents can execute autonomously.

## Core Principle: Testability IS the Architecture

Phases aren't just logical groupings — they're testability boundaries.
If you can't test a phase independently, it's not a phase, it's a step
inside a larger phase.

The testing pyramid for agent-driven work:
1. **Unit**: Individual functions/components have tests
2. **Integration**: Components work together (API calls, DB queries)
3. **System**: The whole thing works end-to-end (browser, full stack)

Each phase should target one level of the pyramid primarily, building
confidence from the bottom up.

## Planning Methodology

### Phase Design

Ask for every proposed phase:
1. **Can I test this independently?** If no, merge with adjacent phase or restructure.
2. **What proves this works?** This becomes the validation script.
3. **What infrastructure does testing need?** This becomes validation setup.
4. **What could fail that tests won't catch?** This becomes the validator's inspection checklist.

### Validation Script Design

Validation scripts are the most important artifact. They must be:
- **Executable**: `bash .plan/validate-phase-N.sh` runs without arguments
- **Self-contained**: Sets up what it needs, cleans up after
- **Fast**: Under 60 seconds ideally (agents will run these repeatedly)
- **Specific**: Tests the phase's changes, not the whole system
- **Exit-code honest**: 0 = pass, non-zero = fail, output explains what failed

### Validation Types (by reliability)

1. **Automated tests**: Most reliable. `npm test --testPathPattern=X`
2. **Type checking**: Structural correctness. `tsc --noEmit`
3. **Lint/format**: Style consistency. `eslint`, `prettier --check`
4. **Build**: Compiles cleanly. `npm run build`
5. **Integration**: API/DB checks. Need server/DB running.
6. **Browser**: UI checks via agent-browser. Need running app.
7. **Code inspection**: Agent reads and assesses. Least reliable.

Put 1-4 in the validation script. 5-6 in the script if infrastructure
is scriptable. 7 is what the validator agent adds on top.

### Right-Sizing Phases

- Too small: agent startup overhead > work done
- Too large: agent hits context limits, quality degrades
- Sweet spot: 20-60 minutes of human-equivalent work
- Rule of thumb: one testability boundary per phase
- If the validation script has more than 10 checks, the phase is too big

### Context Budget

Each agent (executor, validator) gets a fresh context window.
The plan file + relevant codebase reading should stay under 40%.

Keep the plan file concise:
- Context section: 200-500 words
- Per-phase: 100-300 words
- Total plan: under 3000 words (ideally under 2000)
- Let agents discover code via search, don't paste it in the plan

### Common Pitfalls

- **Vague validation**: "Check that it works" → useless. Be specific.
- **Missing setup**: Validation needs a DB but setup isn't scripted → agent can't validate.
- **Coupled phases**: Phase 3 can't be tested without phase 2's uncommitted changes → merge them.
- **Over-specified tasks**: Listing every file to touch → agent can discover this. Specify the WHAT, not the HOW.
- **Under-specified validation**: Only testing happy path → agent misses edge cases.
