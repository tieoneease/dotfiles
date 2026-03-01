/**
 * Workflow Progress UI
 *
 * Renders widget lines and footer status for the workflow extension.
 * Pure functions — take plan/state/theme, return strings.
 */

import type { Plan, Step } from "./plan.js";
import { isStep } from "./plan.js";

// ─── Types ──────────────────────────────────────────────

export interface WorkflowState {
    planningMode: boolean;
    currentStep: number | null;
    currentCheckpoint: string | null;
    retryCount: number;
}

export interface WorkerInfo {
    toolCalls: string[];
    usage: { input: number; output: number; turns: number; cost: number };
}

// ─── Formatting ─────────────────────────────────────────

function fmtTokens(n: number): string {
    if (n >= 10_000) return (n / 1000).toFixed(0) + "k";
    if (n >= 1_000) return (n / 1000).toFixed(1) + "k";
    return String(n);
}

function fmtCost(n: number): string {
    if (n < 0.001) return "";
    return `$${n.toFixed(3)}`;
}

// ─── Status icons ───────────────────────────────────────

const STEP_ICONS: Record<string, string> = {
    validated: "✓",
    "in-progress": "⏳",
    pending: "·",
    failed: "✗",
};

const CHECKPOINT_ICONS: Record<string, string> = {
    validated: "◆",
    "in-progress": "◈",
    pending: "◇",
    failed: "✗",
};

// ─── Widget ─────────────────────────────────────────────

/**
 * Render compact widget lines showing workflow progress.
 *
 * Example output:
 *   📋 Step 5/12 [✓✓✓✓⏳·····◇·] — "Add user routes"
 */
export function renderWidget(plan: Plan, state: WorkflowState, theme: any, worker?: WorkerInfo | null): string[] {
    if (!plan || plan.items.length === 0) return [];

    const totalSteps = plan.items.filter(isStep).length;
    const current = state.currentStep;
    const currentItem = current !== null
        ? plan.items.find((i): i is Step => isStep(i) && i.number === current)
        : null;

    // Build progress bar with step and checkpoint icons
    const icons = plan.items.map((item) => {
        const iconMap = isStep(item) ? STEP_ICONS : CHECKPOINT_ICONS;
        const icon = iconMap[item.status] ?? "?";

        if (item.status === "validated") return theme.fg("success", icon);
        if (item.status === "in-progress") return theme.fg("warning", icon);
        if (item.status === "failed") return theme.fg("error", icon);
        return theme.fg("dim", icon);
    });
    const bar = `[${icons.join("")}]`;

    // Label
    const label = current !== null ? `Step ${current}/${totalSteps}` : `${totalSteps} steps`;
    const name = currentItem ? ` — "${currentItem.name}"` : "";

    const lines: string[] = [];
    lines.push(`📋 ${label} ${bar}${theme.fg("muted", name)}`);

    if (state.retryCount > 0 && current !== null) {
        lines.push(theme.fg("warning", `   ⟳ Retry ${state.retryCount}/2`));
    }

    if (state.currentCheckpoint) {
        lines.push(theme.fg("accent", `   🔍 Checkpoint: ${state.currentCheckpoint}`));
    }

    // Worker activity — tool chain + token usage
    if (worker && worker.toolCalls.length > 0) {
        const chain = worker.toolCalls.slice(-8).join("→");
        const parts: string[] = [
            `${fmtTokens(worker.usage.input)}↓ ${fmtTokens(worker.usage.output)}↑`,
            `turn ${worker.usage.turns}`,
        ];
        const cost = fmtCost(worker.usage.cost);
        if (cost) parts.push(cost);
        lines.push(theme.fg("dim", `   ⚡ ${chain}  ${parts.join(" · ")}`));
    }

    return lines;
}

// ─── Status ─────────────────────────────────────────────

/**
 * Render footer status text.
 * Returns undefined to clear the status.
 */
export function renderStatus(state: WorkflowState, theme: any): string | undefined {
    if (state.planningMode) {
        return theme.fg("warning", "⏸ planning");
    }

    if (state.currentCheckpoint) {
        return theme.fg("accent", `🔍 checkpoint: ${state.currentCheckpoint}`);
    }

    if (state.currentStep !== null) {
        const retryInfo = state.retryCount > 0 ? ` ⟳${state.retryCount}` : "";
        return theme.fg("accent", `⚡ step ${state.currentStep}${retryInfo}`);
    }

    return undefined;
}
