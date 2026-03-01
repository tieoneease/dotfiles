// Pure TypeScript plan parser module — zero pi imports.

export interface Phase {
    number: number;
    name: string;
    status: string;
    goal: string;
    tasks: string[];
    validationScript: string | null;
}

export interface Plan {
    title: string;
    phases: Phase[];
}

const PHASE_HEADER_RE = /^### Phase (\d+):\s*(.+)$/m;
const STATUS_RE = /\*\*Status:\*\*\s*(\w[\w-]*)/;
const GOAL_RE = /\*\*Goal:\*\*\s*(.+)/;
const TASK_RE = /^\d+\.\s+(.+)$/gm;
const VALIDATION_SCRIPT_RE = /Script:\s*`([^`]+)`/;

/**
 * Parse a markdown plan into structured data.
 */
export function parsePlan(content: string): Plan {
    // Extract title from first H1
    const titleMatch = content.match(/^#\s+(?:Plan:\s*)?(.+)$/m);
    const title = titleMatch ? titleMatch[1].trim() : "Untitled Plan";

    // Split content into phase sections by "### Phase N:" headers
    const phases: Phase[] = [];
    const phaseHeaderGlobal = /^### Phase (\d+):\s*(.+)$/gm;
    const headers: { index: number; number: number; name: string }[] = [];

    let match: RegExpExecArray | null;
    while ((match = phaseHeaderGlobal.exec(content)) !== null) {
        headers.push({
            index: match.index,
            number: parseInt(match[1], 10),
            name: match[2].trim(),
        });
    }

    for (let i = 0; i < headers.length; i++) {
        const start = headers[i].index;
        const end = i + 1 < headers.length ? headers[i + 1].index : content.length;
        const section = content.slice(start, end);

        const statusMatch = section.match(STATUS_RE);
        const status = statusMatch ? statusMatch[1] : "pending";

        const goalMatch = section.match(GOAL_RE);
        const goal = goalMatch ? goalMatch[1].trim() : "";

        // Extract numbered tasks
        const tasks: string[] = [];
        const taskSection = section.match(/\*\*Tasks:\*\*([\s\S]*?)(?=\*\*Validation|\*\*Notes|$)/);
        if (taskSection) {
            let taskMatch: RegExpExecArray | null;
            const taskRe = /^\d+\.\s+(.+)$/gm;
            while ((taskMatch = taskRe.exec(taskSection[1])) !== null) {
                tasks.push(taskMatch[1].trim());
            }
        }

        const validationMatch = section.match(VALIDATION_SCRIPT_RE);
        const validationScript = validationMatch ? validationMatch[1] : null;

        phases.push({
            number: headers[i].number,
            name: headers[i].name,
            status,
            goal,
            tasks,
            validationScript,
        });
    }

    return { title, phases };
}

/**
 * Update the status of a specific phase in the raw markdown content.
 * Only changes the status line belonging to the targeted phase number.
 */
export function updatePhaseStatus(
    content: string,
    phaseNumber: number,
    newStatus: string,
): string {
    // Find the specific phase header, then update the first status line after it
    const phaseHeaderGlobal = /^### Phase (\d+):\s*.+$/gm;
    let match: RegExpExecArray | null;
    let phaseStart = -1;
    let nextPhaseStart = -1;

    while ((match = phaseHeaderGlobal.exec(content)) !== null) {
        const num = parseInt(match[1], 10);
        if (num === phaseNumber) {
            phaseStart = match.index;
        } else if (phaseStart >= 0 && nextPhaseStart < 0) {
            nextPhaseStart = match.index;
            break;
        }
    }

    if (phaseStart < 0) return content;

    const sectionEnd = nextPhaseStart >= 0 ? nextPhaseStart : content.length;
    const before = content.slice(0, phaseStart);
    const section = content.slice(phaseStart, sectionEnd);
    const after = content.slice(sectionEnd);

    const updatedSection = section.replace(STATUS_RE, `**Status:** ${newStatus}`);
    return before + updatedSection + after;
}

/**
 * Return the first actionable phase: first pending, then first failed, else null.
 */
export function nextActionablePhase(plan: Plan): Phase | null {
    const pending = plan.phases.find((p) => p.status === "pending");
    if (pending) return pending;

    const failed = plan.phases.find((p) => p.status === "failed");
    if (failed) return failed;

    return null;
}

/**
 * Scan output for "Verdict: PASS" or "Verdict: FAIL".
 */
export function parseVerdict(output: string): "PASS" | "FAIL" | "UNKNOWN" {
    if (/Verdict:\s*PASS/i.test(output)) return "PASS";
    if (/Verdict:\s*FAIL/i.test(output)) return "FAIL";
    return "UNKNOWN";
}

/**
 * Extract the "## Failures" section content from validator output.
 * Returns everything between "## Failures" and the next heading or end of string.
 */
export function extractFailures(output: string): string {
    const failureMatch = output.match(/## Failures\n([\s\S]*?)(?=\n##\s|\n$|$)/);
    return failureMatch ? failureMatch[1].trim() : "";
}
