/**
 * Auto-Handoff Extension
 *
 * Monitors context usage and automatically performs a context handoff when
 * a threshold is reached. Generates a plan-aware handoff document, creates
 * a new session, and sends the handoff doc as the first message — allowing
 * the LLM to seamlessly continue working.
 *
 * Plan-aware: If a plan file exists (TODO.md, PLAN.md, etc.), the handoff
 * instructs the new session to re-read the plan and provides a progress
 * summary. The plan is the source of truth — never duplicated or summarized.
 *
 * Shows live context usage % in the footer status bar.
 *
 * Manual trigger: /auto-handoff
 *
 * Configuration: Set CONTEXT_THRESHOLD below (default: 0.30 = 30%)
 */

import { complete, type Message } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@mariozechner/pi-coding-agent";
import { BorderedLoader, convertToLlm, serializeConversation } from "@mariozechner/pi-coding-agent";

// ─── Configuration ──────────────────────────────────────

/** Context usage threshold (0–100) that triggers auto-handoff */
const CONTEXT_THRESHOLD = 30;

/** Warn color starts at this fraction of the threshold (0.7 = 70% of 30% = 21%) */
const WARN_FRACTION = 0.7;

const HANDOFF_SYSTEM_PROMPT = `You are a context transfer assistant. Given a conversation history, generate a handoff document for a new session to continue the work seamlessly.

CRITICAL RULE — Plan files are the source of truth:
- Look for any plan/task file in the conversation (TODO.md, PLAN.md, tasks.md, or ANY file that serves as a structured plan, checklist, or task list).
- If a plan file exists: DO NOT summarize or reproduce its contents. Instead, instruct the new session to READ that file. Focus your handoff entirely on PROGRESS — what's done, what's in progress, and what context is needed to continue.
- If NO plan file exists: provide a fuller summary including goals and next steps.

The new session has ZERO memory. Progress is the most important piece — be precise about where things stand, what was just being worked on, and any important details (errors hit, approaches tried, partial state) needed to pick up exactly where we left off.

Do not include any preamble like "Here's the prompt" — just output the handoff document itself.

## When a plan file exists, use this structure:

Read the plan: \`<path-to-plan-file>\`

### Progress
- [x] Completed items (brief, just enough to orient)
- [~] In progress: <item> — <exactly where it stands, what was just being done, any partial state>
- [ ] Not started (only list if relevant for context)

### Context for Continuing
[Only include details the new session NEEDS to continue: errors encountered, key decisions made, constraints discovered, files that were modified and why, tricky parts to watch out for. Skip anything already captured in the plan file.]

## When NO plan file exists, use this structure:

### Goal
[What the user is trying to accomplish]

### Progress
[What's been completed, what's in progress with current state]

### Key Context
[Decisions, constraints, files modified, important details]

### Next Steps
[What to do next]`;

// ─── Extension ──────────────────────────────────────────

export default function autoHandoff(pi: ExtensionAPI) {
    let handoffPending = false;

    // ─── Status display ─────────────────────────

    function updateStatus(ctx: ExtensionContext) {
        const usage = ctx.getContextUsage();
        if (!usage || usage.percent === null) {
            ctx.ui.setStatus("auto-handoff", undefined);
            return;
        }

        const theme = ctx.ui.theme;
        const pctStr = `${Math.round(usage.percent)}%`;
        const thresholdPct = Math.round(CONTEXT_THRESHOLD);

        let label: string;
        if (handoffPending) {
            label = theme.fg("warning", `⚡ ctx ${pctStr} — handoff queued`);
        } else if (usage.percent >= CONTEXT_THRESHOLD) {
            label = theme.fg("error", `ctx ${pctStr}/${thresholdPct}%`);
        } else if (usage.percent >= CONTEXT_THRESHOLD * WARN_FRACTION) {
            label = theme.fg("warning", `ctx ${pctStr}/${thresholdPct}%`);
        } else {
            label = theme.fg("dim", `ctx ${pctStr}/${thresholdPct}%`);
        }

        ctx.ui.setStatus("auto-handoff", label);
    }

    // ─── Session lifecycle ──────────────────────

    pi.on("session_start", async (_event, ctx) => {
        handoffPending = false;
        updateStatus(ctx);
    });

    pi.on("session_switch", async (_event, ctx) => {
        handoffPending = false;
        updateStatus(ctx);
    });

    // ─── Context monitoring ─────────────────────

    pi.on("turn_end", async (_event, ctx) => {
        updateStatus(ctx);

        if (handoffPending) return;

        const usage = ctx.getContextUsage();
        if (!usage || usage.percent === null) return;

        if (usage.percent >= CONTEXT_THRESHOLD) {
            handoffPending = true;
            updateStatus(ctx);

            const pctStr = Math.round(usage.percent);
            const thresholdStr = Math.round(CONTEXT_THRESHOLD);
            ctx.ui.notify(
                `Context at ${pctStr}% (threshold: ${thresholdStr}%) — auto-handoff triggered`,
                "warning",
            );

            pi.sendUserMessage("/auto-handoff", { deliverAs: "followUp" });
        }
    });

    // ─── Handoff command ────────────────────────

    pi.registerCommand("auto-handoff", {
        description: "Generate handoff doc and continue in a fresh session",
        handler: async (_args, ctx) => {
            if (!ctx.hasUI) {
                ctx.ui.notify("auto-handoff requires interactive mode", "error");
                return;
            }

            if (!ctx.model) {
                ctx.ui.notify("No model selected", "error");
                return;
            }

            // Gather conversation from current branch
            const branch = ctx.sessionManager.getBranch();
            const messages = branch
                .filter((entry): entry is SessionEntry & { type: "message" } => entry.type === "message")
                .map((entry) => entry.message);

            if (messages.length === 0) {
                ctx.ui.notify("No conversation to hand off", "error");
                handoffPending = false;
                updateStatus(ctx);
                return;
            }

            const llmMessages = convertToLlm(messages);
            const conversationText = serializeConversation(llmMessages);
            const currentSessionFile = ctx.sessionManager.getSessionFile();

            // Generate handoff doc with loader UI
            const handoffDoc = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
                const loader = new BorderedLoader(tui, theme, "Generating handoff document...");
                loader.onAbort = () => done(null);

                const generate = async () => {
                    const apiKey = await ctx.modelRegistry.getApiKey(ctx.model!);

                    const userMessage: Message = {
                        role: "user",
                        content: [{
                            type: "text",
                            text: `## Conversation History\n\n${conversationText}`,
                        }],
                        timestamp: Date.now(),
                    };

                    const response = await complete(
                        ctx.model!,
                        { systemPrompt: HANDOFF_SYSTEM_PROMPT, messages: [userMessage] },
                        { apiKey, signal: loader.signal },
                    );

                    if (response.stopReason === "aborted") return null;

                    return response.content
                        .filter((c): c is { type: "text"; text: string } => c.type === "text")
                        .map((c) => c.text)
                        .join("\n");
                };

                generate()
                    .then(done)
                    .catch((err) => {
                        console.error("Handoff generation failed:", err);
                        done(null);
                    });

                return loader;
            });

            if (!handoffDoc) {
                ctx.ui.notify("Handoff cancelled or failed", "warning");
                handoffPending = false;
                updateStatus(ctx);
                return;
            }

            // Create new session linked to current one
            const result = await ctx.newSession({
                parentSession: currentSessionFile,
            });

            if (result.cancelled) {
                ctx.ui.notify("New session cancelled", "warning");
                handoffPending = false;
                updateStatus(ctx);
                return;
            }

            // Send handoff doc as first message — LLM picks up seamlessly
            // handoffPending resets via session_switch/session_start events
            ctx.ui.notify("Handoff complete — continuing in new session", "success");
            pi.sendUserMessage(handoffDoc);
        },
    });
}
