// Pure TypeScript plan parser module — zero pi imports.

// ─── Types ──────────────────────────────────────────────

export interface Step {
    type: "step";
    number: number;
    name: string;
    status: string; // pending, in-progress, validated, failed
    do: string;
    check: string | null;
}

export interface Checkpoint {
    type: "checkpoint";
    name: string;
    status: string; // pending, in-progress, validated, failed
    script: string;
}

export type PlanItem = Step | Checkpoint;

export interface Plan {
    title: string;
    context: string;
    items: PlanItem[];
}

// ─── Type guards ────────────────────────────────────────

export function isStep(item: PlanItem): item is Step {
    return item.type === "step";
}

export function isCheckpoint(item: PlanItem): item is Checkpoint {
    return item.type === "checkpoint";
}

// ─── Convenience accessors ──────────────────────────────

export function getSteps(plan: Plan): Step[] {
    return plan.items.filter(isStep);
}

export function getCheckpoints(plan: Plan): Checkpoint[] {
    return plan.items.filter(isCheckpoint);
}

// ─── Regexes ────────────────────────────────────────────

const STEP_HEADER_RE = /^### Step (\d+):\s*(.+)$/;
const CHECKPOINT_HEADER_RE = /^### Checkpoint:\s*(.+)$/;
const STATUS_RE = /\*\*Status:\*\*\s*(\w[\w-]*)/;
const CHECK_RE = /\*\*Check:\*\*\s*`([^`]+)`/;
const SCRIPT_RE = /\*\*Script:\*\*\s*`([^`]+)`/;

// ─── Parser ─────────────────────────────────────────────

/**
 * Parse a markdown plan into structured data.
 *
 * Expected format:
 *   # Plan: Title
 *   ## Context
 *   ...
 *   ## Steps
 *   ### Step 1: Name
 *   **Status:** pending
 *   **Do:** ...
 *   **Check:** `command`
 *   ### Checkpoint: Name
 *   **Status:** pending
 *   **Script:** `.plan/validate-name.sh`
 */
export function parsePlan(content: string): Plan {
    // Title from first H1
    const titleMatch = content.match(/^#\s+(?:Plan:\s*)?(.+)$/m);
    const title = titleMatch ? titleMatch[1].trim() : "Untitled Plan";

    // Context section
    const contextMatch = content.match(/## Context\n([\s\S]*?)(?=\n## Steps|\n### Step|\n### Checkpoint|$)/);
    const context = contextMatch ? contextMatch[1].trim() : "";

    // Parse items by scanning headers
    const items: PlanItem[] = [];
    const lines = content.split("\n");

    let i = 0;
    while (i < lines.length) {
        const line = lines[i];

        // Step header
        const stepMatch = line.match(STEP_HEADER_RE);
        if (stepMatch) {
            const section = collectSection(lines, ++i);
            i = section.endLine;

            const statusMatch = section.text.match(STATUS_RE);
            const checkMatch = section.text.match(CHECK_RE);

            // Do field: everything between **Do:** and the next **Field:** or end
            const doMatch = section.text.match(/\*\*Do:\*\*\s*([\s\S]*?)(?=\n\*\*(?:Check|Status|Script):\*\*|$)/);

            items.push({
                type: "step",
                number: parseInt(stepMatch[1], 10),
                name: stepMatch[2].trim(),
                status: statusMatch ? statusMatch[1] : "pending",
                do: doMatch ? doMatch[1].trim() : "",
                check: checkMatch ? checkMatch[1] : null,
            });
            continue;
        }

        // Checkpoint header
        const cpMatch = line.match(CHECKPOINT_HEADER_RE);
        if (cpMatch) {
            const section = collectSection(lines, ++i);
            i = section.endLine;

            const statusMatch = section.text.match(STATUS_RE);
            const scriptMatch = section.text.match(SCRIPT_RE);

            items.push({
                type: "checkpoint",
                name: cpMatch[1].trim(),
                status: statusMatch ? statusMatch[1] : "pending",
                script: scriptMatch ? scriptMatch[1] : "",
            });
            continue;
        }

        i++;
    }

    return { title, context, items };
}

/** Collect all lines from `start` until the next Step/Checkpoint header. */
function collectSection(lines: string[], start: number): { text: string; endLine: number } {
    let end = start;
    while (end < lines.length) {
        if (STEP_HEADER_RE.test(lines[end]) || CHECKPOINT_HEADER_RE.test(lines[end])) break;
        end++;
    }
    return { text: lines.slice(start, end).join("\n"), endLine: end };
}

// ─── Status updates ─────────────────────────────────────

/** Update the **Status:** field within a step's section. */
export function updateStepStatus(content: string, stepNumber: number, newStatus: string): string {
    return updateSectionStatus(
        content,
        new RegExp(`^### Step ${stepNumber}:\\s*.+$`, "m"),
        newStatus,
    );
}

/** Update the **Status:** field within a checkpoint's section. */
export function updateCheckpointStatus(content: string, name: string, newStatus: string): string {
    return updateSectionStatus(
        content,
        new RegExp(`^### Checkpoint:\\s*${escapeRegex(name)}\\s*$`, "m"),
        newStatus,
    );
}

function updateSectionStatus(content: string, headerRe: RegExp, newStatus: string): string {
    const match = headerRe.exec(content);
    if (!match || match.index === undefined) return content;

    const start = match.index;
    const rest = content.slice(start + match[0].length);
    const nextMatch = rest.match(/^### (?:Step \d+:|Checkpoint:)/m);
    const end = nextMatch && nextMatch.index !== undefined
        ? start + match[0].length + nextMatch.index
        : content.length;

    const before = content.slice(0, start);
    const section = content.slice(start, end);
    const after = content.slice(end);

    return before + section.replace(STATUS_RE, `**Status:** ${newStatus}`) + after;
}

function escapeRegex(s: string): string {
    return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ─── Navigation ─────────────────────────────────────────

/** First pending or failed item in the plan. */
export function nextActionableItem(plan: Plan): PlanItem | null {
    return plan.items.find((item) => item.status === "pending" || item.status === "failed") ?? null;
}

/** First pending or failed step (skips checkpoints). */
export function nextActionableStep(plan: Plan): Step | null {
    for (const item of plan.items) {
        if (isStep(item) && (item.status === "pending" || item.status === "failed")) {
            return item;
        }
    }
    return null;
}

// ─── Validator output parsing ───────────────────────────

/** Scan output for "Verdict: PASS" or "Verdict: FAIL". */
export function parseVerdict(output: string): "PASS" | "FAIL" | "UNKNOWN" {
    if (/Verdict:\s*PASS/i.test(output)) return "PASS";
    if (/Verdict:\s*FAIL/i.test(output)) return "FAIL";
    return "UNKNOWN";
}

/** Extract the "## Failures" section from validator output. */
export function extractFailures(output: string): string {
    const match = output.match(/## Failures\n([\s\S]*?)(?=\n##\s|\n$|$)/);
    return match ? match[1].trim() : "";
}
