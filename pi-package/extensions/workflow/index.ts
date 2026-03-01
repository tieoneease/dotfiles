/**
 * Workflow Extension — /wf command
 *
 * Orchestrates plan→execute→validate development loops.
 * Spawns one agent per atomic step with a clean context window.
 * The orchestrator iterates — agents focus on one thing.
 *
 * Subcommands:
 *   /wf plan <goal>    — Enter planning mode (read-only tools)
 *   /wf write          — Exit planning, agent writes .plan/plan.md
 *   /wf exec [step]    — Execute all remaining steps (optionally start from given step)
 *   /wf validate [step] — Run a step's check command or checkpoint script
 *   /wf status         — Show step statuses
 *   /wf (no args)      — Status if plan exists, else start planning
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { exec as execCb } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";

import {
    parsePlan,
    updateStepStatus,
    updateCheckpointStatus,
    isStep,
    isCheckpoint,
    getSteps,
    type Step,
    type Checkpoint,
    type Plan,
} from "./plan.js";
import { dispatchAgent, loadAgentDefinition } from "./dispatch.js";
import { renderWidget, renderStatus, type WorkflowState, type WorkerInfo } from "./progress.js";

// ─── Constants ──────────────────────────────────────────

const PLAN_FILE = ".plan/plan.md";
const PLAN_DIR = ".plan";
const AGENTS_DIR = path.join(os.homedir(), ".pi", "agent", "agents");
const MAX_RETRIES = 2;
const CHECK_TIMEOUT_MS = 60_000;

const PLANNING_TOOLS = ["read", "bash", "grep", "find", "ls", "questionnaire"];

// Destructive patterns blocked in planning mode
const DESTRUCTIVE_PATTERNS = [
    /\brm\b/,
    /\brmdir\b/,
    /\bmv\b/,
    /\bcp\b/,
    /\bmkdir\b/,
    /\btouch\b/,
    /\bchmod\b/,
    /\bchown\b/,
    /\bln\b/,
    /\btee\b/,
    /\bdd\b/,
    /(^|[^<])>(?!>)/,
    />>/,
    /\bnpm\s+(install|uninstall|update|ci|link|publish)/i,
    /\byarn\s+(add|remove|install|publish)/i,
    /\bpnpm\s+(add|remove|install|publish)/i,
    /\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|branch\s+-[dD]|stash|cherry-pick|revert|tag|init|clone)/i,
    /\bsudo\b/,
];

function isDestructiveCommand(command: string): boolean {
    return DESTRUCTIVE_PATTERNS.some((p) => p.test(command));
}

// ─── Check runner ───────────────────────────────────────

/** Run a bash command and return exit code + output. */
function runCheck(command: string, cwd: string): Promise<{ exitCode: number; output: string }> {
    return new Promise((resolve) => {
        execCb(command, { cwd, timeout: CHECK_TIMEOUT_MS, maxBuffer: 1024 * 1024, shell: "/bin/bash" }, (err, stdout, stderr) => {
            const output = `${stdout || ""}${stderr ? "\n" + stderr : ""}`.trim();
            if (!err) {
                resolve({ exitCode: 0, output });
            } else if (typeof (err as any).code === "number") {
                resolve({ exitCode: (err as any).code, output });
            } else {
                resolve({ exitCode: 1, output: output || err.message });
            }
        });
    });
}

// ─── Extension ──────────────────────────────────────────

export default function workflowExtension(pi: ExtensionAPI): void {
    // ─── State ──────────────────────────────────────────
    let state: WorkflowState = {
        planningMode: false,
        currentStep: null,
        currentCheckpoint: null,
        retryCount: 0,
    };

    let planningGoal = "";
    let workerInfo: WorkerInfo | null = null;

    // ─── Helpers ────────────────────────────────────────

    function persistState(): void {
        pi.appendEntry("workflow-state", { ...state });
    }

    function updateUI(ctx: ExtensionContext): void {
        ctx.ui.setStatus("workflow", renderStatus(state, ctx.ui.theme));

        if (state.currentStep !== null || state.currentCheckpoint !== null) {
            const planPath = path.resolve(ctx.cwd, PLAN_FILE);
            try {
                const content = fs.readFileSync(planPath, "utf-8");
                const plan = parsePlan(content);
                ctx.ui.setWidget("workflow", renderWidget(plan, state, ctx.ui.theme, workerInfo));
            } catch {
                ctx.ui.setWidget("workflow", undefined);
            }
        } else if (state.planningMode) {
            ctx.ui.setWidget("workflow", [ctx.ui.theme.fg("warning", "📝 Planning mode — read-only tools")]);
        } else {
            ctx.ui.setWidget("workflow", undefined);
        }
    }

    function readPlanFile(cwd: string): string | null {
        try {
            return fs.readFileSync(path.resolve(cwd, PLAN_FILE), "utf-8");
        } catch {
            return null;
        }
    }

    function writePlanFile(cwd: string, content: string): void {
        const planPath = path.resolve(cwd, PLAN_FILE);
        const dir = path.dirname(planPath);
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(planPath, content, "utf-8");
    }

    // ─── Planning Mode ─────────────────────────────────

    function enterPlanningMode(goal: string, ctx: ExtensionContext): void {
        state.planningMode = true;
        planningGoal = goal;
        pi.setActiveTools(PLANNING_TOOLS);
        persistState();
        updateUI(ctx);
        ctx.ui.notify(`Planning mode enabled. Tools restricted to: ${PLANNING_TOOLS.join(", ")}`, "info");
    }

    function exitPlanningMode(ctx: ExtensionContext): void {
        state.planningMode = false;
        planningGoal = "";
        pi.setActiveTools(pi.getAllTools().map((t) => t.name));
        persistState();
        updateUI(ctx);
    }

    // ─── Execute Step ───────────────────────────────────

    /**
     * Execute a single step: spawn executor, verify check, retry on failure.
     * Each attempt gets a clean context window.
     */
    async function executeStep(
        step: Step,
        planContext: string,
        executorDef: ReturnType<typeof loadAgentDefinition> & {},
        cwd: string,
        ctx: ExtensionContext,
    ): Promise<boolean> {
        let lastFailure = "";

        for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            state.currentStep = step.number;
            state.retryCount = attempt;
            persistState();

            // Update plan status
            let content = readPlanFile(cwd)!;
            content = updateStepStatus(content, step.number, "in-progress");
            writePlanFile(cwd, content);
            updateUI(ctx);

            // Build focused task prompt — context + one step, nothing else
            let task: string;
            if (attempt === 0) {
                task = [
                    "## Context",
                    planContext,
                    "",
                    `## Your Task`,
                    `Step ${step.number}: ${step.name}`,
                    "",
                    `**Do:** ${step.do}`,
                    step.check ? `\n**Check:** \`${step.check}\`\n\nImplement this step, then run the check command to verify. If the check fails, fix the issue and re-run.` : "\nImplement this step.",
                ].join("\n");
            } else {
                task = [
                    "## Context",
                    planContext,
                    "",
                    `## Retry — Step ${step.number}: ${step.name}`,
                    "",
                    `Previous attempt failed. Check output:`,
                    "```",
                    lastFailure.slice(0, 2000),
                    "```",
                    "",
                    `**Do:** ${step.do}`,
                    step.check ? `\n**Check:** \`${step.check}\`\n\nFix the issue and ensure the check passes.` : "\nFix the issue.",
                ].join("\n");
            }

            ctx.ui.notify(`⏳ Step ${step.number}: ${step.name}${attempt > 0 ? ` (retry ${attempt})` : ""}`, "info");

            // Spawn executor — clean context window, atomic task
            await dispatchAgent({
                agent: "executor",
                task,
                cwd,
                model: executorDef.model || undefined,
                tools: executorDef.tools.length > 0 ? executorDef.tools : undefined,
                systemPrompt: executorDef.systemPrompt || undefined,
                onProgress: (update) => {
                    workerInfo = {
                        toolCalls: update.toolCalls,
                        usage: { input: update.usage.input, output: update.usage.output, turns: update.usage.turns, cost: update.usage.cost },
                    };
                    updateUI(ctx);
                },
            });
            workerInfo = null;

            // Orchestrator independently verifies the check command
            if (step.check) {
                const checkResult = await runCheck(step.check, cwd);
                if (checkResult.exitCode === 0) {
                    content = readPlanFile(cwd)!;
                    content = updateStepStatus(content, step.number, "validated");
                    writePlanFile(cwd, content);
                    state.currentStep = null;
                    state.retryCount = 0;
                    persistState();
                    updateUI(ctx);
                    ctx.ui.notify(`✅ Step ${step.number}: ${step.name}`, "info");
                    return true;
                }
                lastFailure = checkResult.output;
            } else {
                // No check command — trust executor
                content = readPlanFile(cwd)!;
                content = updateStepStatus(content, step.number, "validated");
                writePlanFile(cwd, content);
                state.currentStep = null;
                state.retryCount = 0;
                persistState();
                updateUI(ctx);
                ctx.ui.notify(`✅ Step ${step.number}: ${step.name}`, "info");
                return true;
            }
        }

        // All retries exhausted
        let content = readPlanFile(cwd)!;
        content = updateStepStatus(content, step.number, "failed");
        writePlanFile(cwd, content);
        state.currentStep = null;
        state.retryCount = 0;
        persistState();
        updateUI(ctx);

        const reportPath = path.resolve(cwd, PLAN_DIR, `step-${step.number}-failure.md`);
        fs.writeFileSync(reportPath, [
            `# Step ${step.number} Failure: ${step.name}`,
            "",
            `**Failed after ${MAX_RETRIES + 1} attempts**`,
            "",
            "## Last Check Output",
            "```",
            lastFailure || "(none)",
            "```",
            "",
        ].join("\n"));

        ctx.ui.notify(`❌ Step ${step.number}: ${step.name} — failed after ${MAX_RETRIES + 1} attempts. See ${reportPath}`, "error");
        return false;
    }

    // ─── Run Checkpoint ─────────────────────────────────

    /**
     * Run a checkpoint's integration script directly (no agent spawn).
     * Checkpoints verify the combined effect of preceding steps.
     */
    async function runCheckpointValidation(
        checkpoint: Checkpoint,
        cwd: string,
        ctx: ExtensionContext,
    ): Promise<boolean> {
        state.currentCheckpoint = checkpoint.name;
        persistState();

        let content = readPlanFile(cwd)!;
        content = updateCheckpointStatus(content, checkpoint.name, "in-progress");
        writePlanFile(cwd, content);
        updateUI(ctx);

        ctx.ui.notify(`🔍 Checkpoint: ${checkpoint.name}`, "info");

        const result = await runCheck(`bash ${checkpoint.script}`, cwd);
        content = readPlanFile(cwd)!;

        if (result.exitCode === 0) {
            content = updateCheckpointStatus(content, checkpoint.name, "validated");
            writePlanFile(cwd, content);
            state.currentCheckpoint = null;
            persistState();
            updateUI(ctx);
            ctx.ui.notify(`✅ Checkpoint: ${checkpoint.name}`, "info");
            return true;
        }

        // Checkpoint failed
        content = updateCheckpointStatus(content, checkpoint.name, "failed");
        writePlanFile(cwd, content);
        state.currentCheckpoint = null;
        persistState();
        updateUI(ctx);

        const safeName = checkpoint.name.toLowerCase().replace(/[^a-z0-9]+/g, "-");
        const reportPath = path.resolve(cwd, PLAN_DIR, `checkpoint-${safeName}-failure.md`);
        fs.writeFileSync(reportPath, [
            `# Checkpoint Failure: ${checkpoint.name}`,
            "",
            `## Script: ${checkpoint.script}`,
            "",
            "## Output",
            "```",
            result.output,
            "```",
            "",
        ].join("\n"));

        ctx.ui.notify(`❌ Checkpoint: ${checkpoint.name}\n${result.output.slice(0, 500)}`, "error");
        return false;
    }

    // ─── Execute Loop ───────────────────────────────────

    /**
     * Execute all items sequentially from a starting point.
     * Steps spawn one agent each. Checkpoints run scripts directly.
     * Stops on first failure.
     */
    async function executeLoop(
        startFromStep: number | null,
        cwd: string,
        ctx: ExtensionContext,
    ): Promise<void> {
        let content = readPlanFile(cwd);
        if (!content) {
            ctx.ui.notify("No .plan/plan.md found", "error");
            return;
        }

        let plan = parsePlan(content);
        if (plan.items.length === 0) {
            ctx.ui.notify("No steps in plan", "error");
            return;
        }

        // Already done?
        const remaining = plan.items.filter((i) => i.status !== "validated");
        if (remaining.length === 0) {
            ctx.ui.notify("🎉 All steps and checkpoints already validated!", "info");
            return;
        }

        const executorDef = loadAgentDefinition("executor", AGENTS_DIR);
        if (!executorDef) {
            ctx.ui.notify("executor agent not found. Run pi_setup.sh to deploy agents.", "error");
            return;
        }

        // Warn if skipping unvalidated steps
        if (startFromStep !== null) {
            const skipped = getSteps(plan).filter((s) => s.number < startFromStep && s.status !== "validated");
            if (skipped.length > 0) {
                ctx.ui.notify(`⚠️ Steps ${skipped.map((s) => s.number).join(", ")} are not validated. Starting from step ${startFromStep} anyway.`, "warning");
            }
        }

        // null = start from the top, skip validated items
        let started = startFromStep === null;

        for (const item of plan.items) {
            // Skip until we reach the start point
            if (!started) {
                if (isStep(item) && item.number === startFromStep) {
                    started = true;
                } else {
                    continue;
                }
            }

            // Skip already validated
            if (item.status === "validated") continue;

            if (isStep(item)) {
                const success = await executeStep(item, plan.context, executorDef, cwd, ctx);
                if (!success) {
                    ctx.ui.notify(`Execution stopped at Step ${item.number}: ${item.name}`, "error");
                    return;
                }
            } else if (isCheckpoint(item)) {
                const success = await runCheckpointValidation(item, cwd, ctx);
                if (!success) {
                    ctx.ui.notify(`Execution stopped at Checkpoint: ${item.name}`, "error");
                    return;
                }
            }

            // Re-read plan to pick up status updates
            content = readPlanFile(cwd) || content;
            plan = parsePlan(content);
        }

        state.currentStep = null;
        state.currentCheckpoint = null;
        persistState();
        updateUI(ctx);
        ctx.ui.notify("🎉 All steps completed!", "info");
    }

    // ─── Show Status ────────────────────────────────────

    function showStatus(cwd: string, ctx: ExtensionContext): void {
        const content = readPlanFile(cwd);
        if (!content) {
            ctx.ui.notify("No .plan/plan.md found. Use /wf plan <goal> to start.", "info");
            return;
        }

        const plan = parsePlan(content);
        const lines = plan.items.map((item) => {
            if (isStep(item)) {
                const icon = item.status === "validated" ? "✅"
                    : item.status === "in-progress" ? "⏳"
                    : item.status === "failed" ? "❌"
                    : "·";
                return `  ${icon} Step ${item.number}: ${item.name} — ${item.status}`;
            } else {
                const icon = item.status === "validated" ? "◆"
                    : item.status === "failed" ? "✗"
                    : "◇";
                return `  ${icon} Checkpoint: ${item.name} — ${item.status}`;
            }
        });

        ctx.ui.notify(`📋 ${plan.title}\n${lines.join("\n")}`, "info");
    }

    // ─── Command Registration ───────────────────────────

    pi.registerCommand("wf", {
        description: "Workflow: plan→execute→validate development loop",
        handler: async (args, ctx) => {
            const parts = (args || "").trim().split(/\s+/);
            const subcommand = parts[0] || "";
            const rest = parts.slice(1).join(" ");

            switch (subcommand) {
                case "plan": {
                    const goal = rest || "Plan the current project";
                    enterPlanningMode(goal, ctx);
                    pi.sendUserMessage(`/skill:workflow\n\nPlanning goal: ${goal}\n\nExplore the codebase and design atomic steps. Each step must be sized so a fresh agent can complete it under 40% context usage. Think about token cost and reasoning complexity, not time.`);
                    break;
                }

                case "write": {
                    if (!state.planningMode) {
                        ctx.ui.notify("Not in planning mode. Use /wf plan <goal> first.", "warning");
                        return;
                    }
                    exitPlanningMode(ctx);
                    pi.sendUserMessage([
                        "Now write the plan to .plan/plan.md using the exact format from the workflow skill.",
                        "",
                        "Requirements:",
                        "- # Plan: [title]",
                        "- ## Context section (200-500 words — project state, goal, enough for a fresh agent to orient)",
                        "- ## Steps section with flat, ordered steps",
                        "- ### Step N: [name] with **Status:** pending, **Do:** [instruction], **Check:** `[command]`",
                        "- ### Checkpoint: [name] with **Status:** pending, **Script:** `.plan/validate-[name].sh` at integration boundaries",
                        "- Write all checkpoint validation scripts (executable bash, exit 0 on success)",
                        "- Each step must be atomic: one agent, one clean context window, <40% usage",
                        "- Size by token cost and reasoning complexity — simple boilerplate can be bigger, complex logic must be smaller",
                        "- Check commands: fast bash one-liners that return 0 on success",
                        "- Mark everything **Status:** pending",
                    ].join("\n"));
                    break;
                }

                case "exec": {
                    const stepNum = rest ? parseInt(rest, 10) : null;
                    if (!readPlanFile(ctx.cwd)) {
                        ctx.ui.notify("No .plan/plan.md found. Create a plan first.", "error");
                        return;
                    }
                    // null = run everything from the top, skip validated
                    await executeLoop(stepNum ?? null, ctx.cwd, ctx);
                    break;
                }

                case "validate": {
                    const stepNum = rest ? parseInt(rest, 10) : null;
                    const content = readPlanFile(ctx.cwd);
                    if (!content) {
                        ctx.ui.notify("No .plan/plan.md found.", "error");
                        return;
                    }

                    const plan = parsePlan(content);

                    if (stepNum !== null && !isNaN(stepNum)) {
                        // Validate specific step
                        const step = getSteps(plan).find((s) => s.number === stepNum);
                        if (!step) {
                            ctx.ui.notify(`Step ${stepNum} not found.`, "error");
                            return;
                        }
                        if (!step.check) {
                            ctx.ui.notify(`Step ${stepNum} has no check command.`, "warning");
                            return;
                        }

                        ctx.ui.notify(`🔍 Running check for Step ${stepNum}: ${step.name}`, "info");
                        const result = await runCheck(step.check, ctx.cwd);

                        let planContent = content;
                        if (result.exitCode === 0) {
                            planContent = updateStepStatus(planContent, stepNum, "validated");
                            writePlanFile(ctx.cwd, planContent);
                            ctx.ui.notify(`✅ Step ${stepNum}: ${step.name} — PASS\n${result.output.slice(0, 300)}`, "info");
                        } else {
                            ctx.ui.notify(`❌ Step ${stepNum}: ${step.name} — FAIL\n${result.output.slice(0, 500)}`, "warning");
                        }
                    } else {
                        // Validate all: run every check/script and report
                        ctx.ui.notify("🔍 Running all checks...", "info");
                        const results: string[] = [];
                        for (const item of plan.items) {
                            if (isStep(item) && item.check) {
                                const r = await runCheck(item.check, ctx.cwd);
                                const icon = r.exitCode === 0 ? "✅" : "❌";
                                results.push(`  ${icon} Step ${item.number}: ${item.name}`);
                            } else if (isCheckpoint(item) && item.script) {
                                const r = await runCheck(`bash ${item.script}`, ctx.cwd);
                                const icon = r.exitCode === 0 ? "✅" : "❌";
                                results.push(`  ${icon} Checkpoint: ${item.name}`);
                            }
                        }
                        ctx.ui.notify(`📋 Validation results:\n${results.join("\n")}`, "info");
                    }
                    break;
                }

                case "status": {
                    showStatus(ctx.cwd, ctx);
                    break;
                }

                default: {
                    const content = readPlanFile(ctx.cwd);
                    if (content) {
                        showStatus(ctx.cwd, ctx);
                    } else {
                        const goal = (args || "").trim() || "Plan the current project";
                        enterPlanningMode(goal, ctx);
                        pi.sendUserMessage(`/skill:workflow\n\nPlanning goal: ${goal}\n\nExplore the codebase and design atomic steps. Each step must be sized so a fresh agent can complete it under 40% context usage. Think about token cost and reasoning complexity, not time.`);
                    }
                    break;
                }
            }
        },
    });

    // ─── Block destructive bash in planning mode ────────

    pi.on("tool_call", async (event) => {
        if (!state.planningMode || event.toolName !== "bash") return;

        const command = event.input.command as string;
        if (isDestructiveCommand(command)) {
            return {
                block: true,
                reason: `Planning mode: destructive command blocked. Use /wf write to exit planning mode first.\nCommand: ${command}`,
            };
        }
    });

    // ─── Inject planning context ────────────────────────

    pi.on("before_agent_start", async () => {
        if (!state.planningMode) return;

        return {
            message: {
                customType: "workflow-planning-context",
                content: `[WORKFLOW PLANNING MODE]
You are in planning mode for the workflow extension.

Goal: ${planningGoal}

Restrictions:
- You can only use: ${PLANNING_TOOLS.join(", ")}
- Bash is restricted — destructive commands are blocked
- Do NOT modify files — only read and analyze

Your task:
1. Explore the codebase to understand the current state
2. Design atomic steps — each gets ONE agent with a clean context window
3. Size steps by token cost and reasoning complexity — target <40% context per step
4. Simple boilerplate steps can cover more ground; complex reasoning steps must be small
5. Place checkpoints at integration boundaries
6. Every step needs a check command (bash one-liner, exit 0 = pass)

Use the workflow skill methodology: clean context, atomic work.
When ready, the user will run /wf write to have you produce the plan file.`,
                display: false,
            },
        };
    });

    // ─── Restore state on session start ─────────────────

    pi.on("session_start", async (_event, ctx) => {
        const entries = ctx.sessionManager.getEntries();

        const stateEntry = entries
            .filter((e: { type: string; customType?: string }) => e.type === "custom" && e.customType === "workflow-state")
            .pop() as { data?: any } | undefined;

        if (stateEntry?.data) {
            // Handle migration from old phase-based state
            state = {
                planningMode: stateEntry.data.planningMode ?? false,
                currentStep: stateEntry.data.currentStep ?? stateEntry.data.currentPhase ?? null,
                currentCheckpoint: stateEntry.data.currentCheckpoint ?? null,
                retryCount: stateEntry.data.retryCount ?? 0,
            };
        }

        if (state.planningMode) {
            pi.setActiveTools(PLANNING_TOOLS);
        }

        updateUI(ctx);
    });
}
