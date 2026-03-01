/**
 * Workflow Progress UI
 *
 * Renders widget lines and footer status for the workflow extension.
 * Pure functions — take plan/state/theme, return strings.
 */

import type { Plan } from "./plan.js";

// ─── Types ──────────────────────────────────────────────

export interface WorkflowState {
    planningMode: boolean;
    currentPhase: number | null;
    retryCount: number;
}

// ─── Status icons ───────────────────────────────────────

const STATUS_ICONS: Record<string, string> = {
    validated: "✓",
    done: "✓",
    "in-progress": "⏳",
    pending: "·",
    failed: "✗",
};

function statusIcon(status: string): string {
    return STATUS_ICONS[status] ?? "?";
}

// ─── Widget ─────────────────────────────────────────────

/**
 * Render compact widget lines showing workflow progress.
 *
 * Example output:
 *   📋 Phase 2/4 [✓✓⏳·] — "API endpoints"
 */
export function renderWidget(plan: Plan, state: WorkflowState, theme: any): string[] {
    if (!plan || plan.phases.length === 0) return [];

    const total = plan.phases.length;
    const current = state.currentPhase;
    const currentPhase = current !== null ? plan.phases.find((p) => p.number === current) : null;

    // Build progress bar: [✓✓⏳·]
    const icons = plan.phases.map((p) => {
        const icon = statusIcon(p.status);
        if (p.status === "validated") return theme.fg("success", icon);
        if (p.status === "done") return theme.fg("accent", icon);
        if (p.status === "in-progress") return theme.fg("warning", icon);
        if (p.status === "failed") return theme.fg("error", icon);
        return theme.fg("dim", icon);
    });
    const bar = `[${icons.join("")}]`;

    // Phase label
    const phaseLabel = current !== null ? `Phase ${current}/${total}` : `${total} phases`;
    const phaseName = currentPhase ? ` — "${currentPhase.name}"` : "";

    const lines: string[] = [];
    lines.push(`📋 ${phaseLabel} ${bar}${theme.fg("muted", phaseName)}`);

    // Show retry info if retrying
    if (state.retryCount > 0 && current !== null) {
        lines.push(theme.fg("warning", `   ⟳ Retry ${state.retryCount}/2`));
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

    if (state.currentPhase !== null) {
        const retryInfo = state.retryCount > 0 ? ` ⟳${state.retryCount}` : "";
        return theme.fg("accent", `⚡ phase ${state.currentPhase}${retryInfo}`);
    }

    return undefined;
}
