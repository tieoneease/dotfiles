/**
 * Workflow Extension — /wf command
 *
 * Orchestrates plan→execute→validate development loops.
 * Delegates execution to spawned pi subprocesses via dispatch module.
 *
 * Subcommands:
 *   /wf plan <goal>    — Enter planning mode (read-only tools)
 *   /wf write          — Exit planning, agent writes .plan/plan.md
 *   /wf exec [phase]   — Execute and validate phases autonomously
 *   /wf validate [phase] — Run standalone validation
 *   /wf status         — Show phase statuses
 *   /wf (no args)      — Status if plan exists, else start planning
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";

import { parsePlan, updatePhaseStatus, nextActionablePhase, parseVerdict, extractFailures } from "./plan.js";
import { dispatchAgent, loadAgentDefinition } from "./dispatch.js";
import { renderWidget, renderStatus, type WorkflowState } from "./progress.js";

// ─── Constants ──────────────────────────────────────────

const PLAN_FILE = ".plan/plan.md";
const PLAN_DIR = ".plan";
const AGENTS_DIR = path.join(os.homedir(), ".pi", "agent", "agents");
const MAX_RETRIES = 2;

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

// ─── Extension ──────────────────────────────────────────

export default function workflowExtension(pi: ExtensionAPI): void {
    // ─── State ──────────────────────────────────────────
    let state: WorkflowState = {
        planningMode: false,
        currentPhase: null,
        retryCount: 0,
    };

    let planningGoal = "";

    // ─── Helpers ────────────────────────────────────────

    function persistState(): void {
        pi.appendEntry("workflow-state", { ...state });
    }

    function updateUI(ctx: ExtensionContext): void {
        // Footer status
        ctx.ui.setStatus("workflow", renderStatus(state, ctx.ui.theme));

        // Widget — only show when we have a plan and are executing
        if (state.currentPhase !== null) {
            const planPath = path.resolve(ctx.cwd, PLAN_FILE);
            try {
                const content = fs.readFileSync(planPath, "utf-8");
                const plan = parsePlan(content);
                ctx.ui.setWidget("workflow", renderWidget(plan, state, ctx.ui.theme));
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
        const planPath = path.resolve(cwd, PLAN_FILE);
        try {
            return fs.readFileSync(planPath, "utf-8");
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

    // ─── Execute Phase Loop ─────────────────────────────

    async function executePhaseLoop(
        phaseNumber: number,
        cwd: string,
        ctx: ExtensionContext,
    ): Promise<void> {
        const content = readPlanFile(cwd);
        if (!content) {
            ctx.ui.notify("No .plan/plan.md found", "error");
            return;
        }

        let plan = parsePlan(content);
        const phase = plan.phases.find((p) => p.number === phaseNumber);
        if (!phase) {
            ctx.ui.notify(`Phase ${phaseNumber} not found`, "error");
            return;
        }

        // Load agent definitions
        const executorDef = loadAgentDefinition("executor", AGENTS_DIR);
        const validatorDef = loadAgentDefinition("validator", AGENTS_DIR);
        if (!executorDef) {
            ctx.ui.notify("executor agent not found. Run pi_setup.sh to deploy agents.", "error");
            return;
        }
        if (!validatorDef) {
            ctx.ui.notify("validator agent not found. Run pi_setup.sh to deploy agents.", "error");
            return;
        }

        // Update status to in-progress
        state.currentPhase = phaseNumber;
        state.retryCount = 0;
        let planContent = updatePhaseStatus(content, phaseNumber, "in-progress");
        writePlanFile(cwd, planContent);
        persistState();
        updateUI(ctx);

        const executorTask = `Read the plan file at ${PLAN_FILE} and implement Phase ${phaseNumber}: ${phase.name}.\n\nGoal: ${phase.goal}\n\nTasks:\n${phase.tasks.map((t, i) => `${i + 1}. ${t}`).join("\n")}${phase.validationScript ? `\n\nAfter implementing, run the validation script: bash ${phase.validationScript}` : ""}`;

        // Executor dispatch
        ctx.ui.notify(`⚡ Executing Phase ${phaseNumber}: ${phase.name}`, "info");
        const execResult = await dispatchAgent({
            agent: "executor",
            task: executorTask,
            cwd,
            model: executorDef.model || undefined,
            tools: executorDef.tools.length > 0 ? executorDef.tools : undefined,
            systemPrompt: executorDef.systemPrompt || undefined,
            onProgress: (_update) => {
                updateUI(ctx);
            },
        });

        // Update status to done
        planContent = readPlanFile(cwd) || planContent;
        planContent = updatePhaseStatus(planContent, phaseNumber, "done");
        writePlanFile(cwd, planContent);
        updateUI(ctx);

        // Validation loop with retries
        for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
            state.retryCount = attempt;
            persistState();
            updateUI(ctx);

            const validatorTask = `Read the plan file at ${PLAN_FILE} and validate Phase ${phaseNumber}: ${phase.name}.\n\nGoal: ${phase.goal}${phase.validationScript ? `\n\nRun the validation script: bash ${phase.validationScript}` : ""}\n\nAfter validation, output exactly one of:\n  Verdict: PASS\n  Verdict: FAIL\n\nIf FAIL, include a "## Failures" section describing what failed.`;

            ctx.ui.notify(`🔍 Validating Phase ${phaseNumber} (attempt ${attempt + 1})`, "info");
            const valResult = await dispatchAgent({
                agent: "validator",
                task: validatorTask,
                cwd,
                model: validatorDef.model || undefined,
                tools: validatorDef.tools.length > 0 ? validatorDef.tools : undefined,
                systemPrompt: validatorDef.systemPrompt || undefined,
                onProgress: (_update) => {
                    updateUI(ctx);
                },
            });

            const verdict = parseVerdict(valResult.output);

            if (verdict === "PASS") {
                planContent = readPlanFile(cwd) || planContent;
                planContent = updatePhaseStatus(planContent, phaseNumber, "validated");
                writePlanFile(cwd, planContent);
                state.currentPhase = null;
                state.retryCount = 0;
                persistState();
                updateUI(ctx);
                ctx.ui.notify(`✅ Phase ${phaseNumber}: ${phase.name} — validated!`, "info");
                return;
            }

            // FAIL or UNKNOWN
            if (attempt < MAX_RETRIES) {
                const failures = extractFailures(valResult.output);
                const retryTask = `Read the plan file at ${PLAN_FILE}. Phase ${phaseNumber}: ${phase.name} failed validation.\n\nFailure details:\n${failures || valResult.output}\n\nFix the issues and re-run the validation script.`;

                ctx.ui.notify(`⚠️ Phase ${phaseNumber} validation failed. Retrying (${attempt + 1}/${MAX_RETRIES})...`, "warning");
                await dispatchAgent({
                    agent: "executor",
                    task: retryTask,
                    cwd,
                    model: executorDef.model || undefined,
                    tools: executorDef.tools.length > 0 ? executorDef.tools : undefined,
                    systemPrompt: executorDef.systemPrompt || undefined,
                    onProgress: (_update) => {
                        updateUI(ctx);
                    },
                });
            } else {
                // Max retries exhausted
                planContent = readPlanFile(cwd) || planContent;
                planContent = updatePhaseStatus(planContent, phaseNumber, "failed");
                writePlanFile(cwd, planContent);
                state.currentPhase = null;
                state.retryCount = 0;
                persistState();
                updateUI(ctx);

                // Write failure report
                const failures = extractFailures(valResult.output);
                const reportPath = path.resolve(cwd, PLAN_DIR, `phase-${phaseNumber}-failure.md`);
                const report = `# Phase ${phaseNumber} Failure Report: ${phase.name}\n\n**Status:** failed after ${MAX_RETRIES + 1} attempts\n\n## Validator Output\n\n${valResult.output}\n\n## Extracted Failures\n\n${failures || "(none extracted)"}\n\n## Executor Final Output\n\n${execResult.output}\n`;
                fs.writeFileSync(reportPath, report, "utf-8");

                ctx.ui.notify(`❌ Phase ${phaseNumber}: ${phase.name} — failed after ${MAX_RETRIES + 1} attempts. See ${reportPath}`, "error");
                return;
            }
        }
    }

    // ─── Show Status ────────────────────────────────────

    function showStatus(cwd: string, ctx: ExtensionContext): void {
        const content = readPlanFile(cwd);
        if (!content) {
            ctx.ui.notify("No .plan/plan.md found. Use /wf plan <goal> to start.", "info");
            return;
        }

        const plan = parsePlan(content);
        const lines = plan.phases.map((p) => {
            const icon = p.status === "validated" ? "✅"
                : p.status === "done" ? "✓"
                : p.status === "in-progress" ? "⏳"
                : p.status === "failed" ? "❌"
                : "·";
            return `  ${icon} Phase ${p.number}: ${p.name} — ${p.status}`;
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
                    pi.sendUserMessage(`/skill:workflow\n\nPlanning goal: ${goal}\n\nExplore the codebase and create a detailed, phased plan. Each phase must have a clear validation strategy with executable test scripts.`);
                    break;
                }

                case "write": {
                    if (!state.planningMode) {
                        ctx.ui.notify("Not in planning mode. Use /wf plan <goal> first.", "warning");
                        return;
                    }
                    exitPlanningMode(ctx);
                    pi.sendUserMessage(`Now write the plan to .plan/plan.md using the format from the workflow skill.\n\nRequirements:\n- Follow the exact markdown format: # Plan title, ### Phase N: Name, **Status:** pending, **Goal:**, **Tasks:**, **Validation:**\n- Each phase needs a validation script at .plan/validate-phase-N.sh\n- Write the validation scripts too (they should be executable bash scripts)\n- Make validation scripts thorough — they're the contract for automated execution\n- Mark all phases as **Status:** pending`);
                    break;
                }

                case "exec": {
                    const phaseNum = rest ? parseInt(rest, 10) : null;
                    const content = readPlanFile(ctx.cwd);
                    if (!content) {
                        ctx.ui.notify("No .plan/plan.md found. Create a plan first.", "error");
                        return;
                    }

                    const plan = parsePlan(content);
                    let targetPhase: number;

                    if (phaseNum !== null && !isNaN(phaseNum)) {
                        targetPhase = phaseNum;
                    } else {
                        const next = nextActionablePhase(plan);
                        if (!next) {
                            ctx.ui.notify("All phases are complete or validated!", "info");
                            return;
                        }
                        targetPhase = next.number;
                    }

                    await executePhaseLoop(targetPhase, ctx.cwd, ctx);
                    break;
                }

                case "validate": {
                    const phaseNum = rest ? parseInt(rest, 10) : null;
                    const content = readPlanFile(ctx.cwd);
                    if (!content) {
                        ctx.ui.notify("No .plan/plan.md found.", "error");
                        return;
                    }

                    const plan = parsePlan(content);
                    let targetPhase: number;

                    if (phaseNum !== null && !isNaN(phaseNum)) {
                        targetPhase = phaseNum;
                    } else {
                        const next = nextActionablePhase(plan);
                        if (!next) {
                            ctx.ui.notify("No phases to validate.", "info");
                            return;
                        }
                        targetPhase = next.number;
                    }

                    const phase = plan.phases.find((p) => p.number === targetPhase);
                    if (!phase) {
                        ctx.ui.notify(`Phase ${targetPhase} not found.`, "error");
                        return;
                    }

                    const validatorDef = loadAgentDefinition("validator", AGENTS_DIR);
                    if (!validatorDef) {
                        ctx.ui.notify("validator agent not found. Run pi_setup.sh to deploy agents.", "error");
                        return;
                    }

                    state.currentPhase = targetPhase;
                    persistState();
                    updateUI(ctx);

                    ctx.ui.notify(`🔍 Validating Phase ${targetPhase}: ${phase.name}`, "info");
                    const valResult = await dispatchAgent({
                        agent: "validator",
                        task: `Read the plan file at ${PLAN_FILE} and validate Phase ${targetPhase}: ${phase.name}.\n\nGoal: ${phase.goal}${phase.validationScript ? `\n\nRun the validation script: bash ${phase.validationScript}` : ""}\n\nAfter validation, output exactly one of:\n  Verdict: PASS\n  Verdict: FAIL\n\nIf FAIL, include a "## Failures" section describing what failed.`,
                        cwd: ctx.cwd,
                        model: validatorDef.model || undefined,
                        tools: validatorDef.tools.length > 0 ? validatorDef.tools : undefined,
                        systemPrompt: validatorDef.systemPrompt || undefined,
                    });

                    const verdict = parseVerdict(valResult.output);
                    let planContent = readPlanFile(ctx.cwd) || content;

                    if (verdict === "PASS") {
                        planContent = updatePhaseStatus(planContent, targetPhase, "validated");
                        writePlanFile(ctx.cwd, planContent);
                        ctx.ui.notify(`✅ Phase ${targetPhase}: ${phase.name} — PASS`, "info");
                    } else {
                        const failures = extractFailures(valResult.output);
                        ctx.ui.notify(`❌ Phase ${targetPhase}: ${phase.name} — ${verdict}\n${failures}`, "warning");
                    }

                    state.currentPhase = null;
                    persistState();
                    updateUI(ctx);
                    break;
                }

                case "status": {
                    showStatus(ctx.cwd, ctx);
                    break;
                }

                default: {
                    // No subcommand — if plan exists show status, else start planning
                    const content = readPlanFile(ctx.cwd);
                    if (content) {
                        showStatus(ctx.cwd, ctx);
                    } else {
                        const goal = (args || "").trim() || "Plan the current project";
                        enterPlanningMode(goal, ctx);
                        pi.sendUserMessage(`/skill:workflow\n\nPlanning goal: ${goal}\n\nExplore the codebase and create a detailed, phased plan. Each phase must have a clear validation strategy with executable test scripts.`);
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
2. Design phases with clear testability boundaries
3. Each phase must be independently verifiable
4. Think about what validation scripts would prove each phase works

Use the workflow skill methodology: testability IS the architecture.
When ready, the user will run /wf write to have you produce the plan file.`,
                display: false,
            },
        };
    });

    // ─── Restore state on session start ─────────────────

    pi.on("session_start", async (_event, ctx) => {
        const entries = ctx.sessionManager.getEntries();

        // Find the last workflow-state entry
        const stateEntry = entries
            .filter((e: { type: string; customType?: string }) => e.type === "custom" && e.customType === "workflow-state")
            .pop() as { data?: WorkflowState } | undefined;

        if (stateEntry?.data) {
            state = { ...stateEntry.data };
        }

        if (state.planningMode) {
            pi.setActiveTools(PLANNING_TOOLS);
        }

        updateUI(ctx);
    });
}
