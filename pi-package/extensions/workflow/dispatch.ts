/**
 * Agent Dispatch Module
 *
 * Spawns pi subprocesses in JSON mode, streams their output,
 * and returns structured results. Follows the same spawn pattern
 * as the subagent extension but with a simpler single-dispatch API.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

// ─── Types ──────────────────────────────────────────────

export interface UsageStats {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
    cost: number;
    turns: number;
}

export interface ProgressUpdate {
    text: string;
    toolCalls: string[];
    usage: UsageStats;
}

export interface AgentResult {
    agent: string;
    exitCode: number;
    output: string;
    messages: any[];
    usage: UsageStats;
    verdict?: string;
}

export interface DispatchOptions {
    agent: string;
    task: string;
    cwd: string;
    model?: string;
    tools?: string[];
    systemPrompt?: string;
    signal?: AbortSignal;
    onProgress?: (update: ProgressUpdate) => void;
}

// ─── Helpers ────────────────────────────────────────────

function emptyUsage(): UsageStats {
    return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
}

/**
 * Extract the last assistant text from accumulated messages.
 */
function getFinalOutput(messages: any[]): string {
    for (let i = messages.length - 1; i >= 0; i--) {
        const msg = messages[i];
        if (msg.role === "assistant") {
            for (const part of msg.content) {
                if (part.type === "text") return part.text;
            }
        }
    }
    return "";
}

/**
 * Extract all tool call names from accumulated messages.
 */
function getToolCallNames(messages: any[]): string[] {
    const names: string[] = [];
    for (const msg of messages) {
        if (msg.role === "assistant") {
            for (const part of msg.content) {
                if (part.type === "toolCall") names.push(part.name);
            }
        }
    }
    return names;
}

/**
 * Write system prompt to a temp file for --append-system-prompt.
 */
function writePromptToTempFile(agentName: string, prompt: string): { dir: string; filePath: string } {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-dispatch-"));
    const safeName = agentName.replace(/[^\w.-]+/g, "_");
    const filePath = path.join(tmpDir, `prompt-${safeName}.md`);
    fs.writeFileSync(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
    return { dir: tmpDir, filePath };
}

// ─── Agent Definition Loading ───────────────────────────

/**
 * Parse YAML-like frontmatter from a markdown file.
 * Frontmatter is delimited by --- lines at the start.
 */
function parseFrontmatter(content: string): { frontmatter: Record<string, string>; body: string } {
    const match = content.match(/^---\s*\n([\s\S]*?)\n---\s*\n?([\s\S]*)$/);
    if (!match) return { frontmatter: {}, body: content };

    const frontmatter: Record<string, string> = {};
    const rawFrontmatter = match[1];
    const body = match[2];

    for (const line of rawFrontmatter.split("\n")) {
        const kvMatch = line.match(/^(\w[\w-]*)\s*:\s*(.+)$/);
        if (kvMatch) {
            frontmatter[kvMatch[1].trim()] = kvMatch[2].trim();
        }
    }

    return { frontmatter, body };
}

/**
 * Load an agent definition from a .md file in the given directory.
 * Returns null if the file doesn't exist or is malformed.
 */
export function loadAgentDefinition(
    name: string,
    agentsDir: string,
): { name: string; model: string; tools: string[]; systemPrompt: string } | null {
    const filePath = path.join(agentsDir, `${name}.md`);

    let content: string;
    try {
        content = fs.readFileSync(filePath, "utf-8");
    } catch {
        return null;
    }

    const { frontmatter, body } = parseFrontmatter(content);

    if (!frontmatter.name) return null;

    const tools = frontmatter.tools
        ? frontmatter.tools
              .split(",")
              .map((t) => t.trim())
              .filter(Boolean)
        : [];

    return {
        name: frontmatter.name,
        model: frontmatter.model || "",
        tools,
        systemPrompt: body.trim(),
    };
}

// ─── Dispatch ───────────────────────────────────────────

/**
 * Spawn a pi subprocess in JSON mode, stream output, return structured result.
 *
 * Follows the same pattern as the subagent extension's runSingleAgent:
 * - --mode json -p --no-session
 * - --append-system-prompt with temp file
 * - JSON line parsing from stdout
 * - message_end / tool_result_end event tracking
 * - SIGTERM on abort, SIGKILL after 5s timeout
 * - Temp file cleanup in finally block
 */
export async function dispatchAgent(options: DispatchOptions): Promise<AgentResult> {
    const { agent, task, cwd, model, tools, systemPrompt, signal, onProgress } = options;

    const result: AgentResult = {
        agent,
        exitCode: 0,
        output: "",
        messages: [],
        usage: emptyUsage(),
    };

    // Build pi args
    const args: string[] = ["--mode", "json", "-p", "--no-session"];
    if (model) args.push("--model", model);
    if (tools && tools.length > 0) args.push("--tools", tools.join(","));

    let tmpPromptDir: string | null = null;
    let tmpPromptPath: string | null = null;

    try {
        // Write system prompt to temp file if provided
        if (systemPrompt && systemPrompt.trim()) {
            const tmp = writePromptToTempFile(agent, systemPrompt);
            tmpPromptDir = tmp.dir;
            tmpPromptPath = tmp.filePath;
            args.push("--append-system-prompt", tmpPromptPath);
        }

        // Task is the final positional argument
        args.push(`Task: ${task}`);

        let wasAborted = false;

        const emitProgress = () => {
            if (onProgress) {
                onProgress({
                    text: getFinalOutput(result.messages) || "(running...)",
                    toolCalls: getToolCallNames(result.messages),
                    usage: { ...result.usage },
                });
            }
        };

        const exitCode = await new Promise<number>((resolve) => {
            const proc = spawn("pi", args, {
                cwd,
                shell: false,
                stdio: ["ignore", "pipe", "pipe"],
            });

            let buffer = "";
            let stderr = "";

            const processLine = (line: string) => {
                if (!line.trim()) return;
                let event: any;
                try {
                    event = JSON.parse(line);
                } catch {
                    return;
                }

                // Track assistant messages and usage from message_end events
                if (event.type === "message_end" && event.message) {
                    const msg = event.message;
                    result.messages.push(msg);

                    if (msg.role === "assistant") {
                        result.usage.turns++;
                        const usage = msg.usage;
                        if (usage) {
                            result.usage.input += usage.input || 0;
                            result.usage.output += usage.output || 0;
                            result.usage.cacheRead += usage.cacheRead || 0;
                            result.usage.cacheWrite += usage.cacheWrite || 0;
                            result.usage.cost += usage.cost?.total || 0;
                        }
                    }
                    emitProgress();
                }

                // Track tool results
                if (event.type === "tool_result_end" && event.message) {
                    result.messages.push(event.message);
                    emitProgress();
                }
            };

            proc.stdout.on("data", (data: Buffer) => {
                buffer += data.toString();
                const lines = buffer.split("\n");
                buffer = lines.pop() || "";
                for (const line of lines) processLine(line);
            });

            proc.stderr.on("data", (data: Buffer) => {
                stderr += data.toString();
            });

            proc.on("close", (code: number | null) => {
                // Process any remaining buffered data
                if (buffer.trim()) processLine(buffer);
                resolve(code ?? 0);
            });

            proc.on("error", (err: Error) => {
                stderr += err.message;
                resolve(1);
            });

            // Abort handling: SIGTERM first, SIGKILL after 5s timeout
            if (signal) {
                const killProc = () => {
                    wasAborted = true;
                    proc.kill("SIGTERM");
                    setTimeout(() => {
                        if (!proc.killed) proc.kill("SIGKILL");
                    }, 5000);
                };
                if (signal.aborted) killProc();
                else signal.addEventListener("abort", killProc, { once: true });
            }
        });

        result.exitCode = exitCode;
        result.output = getFinalOutput(result.messages);

        if (wasAborted) {
            result.exitCode = result.exitCode || 1;
            result.output = result.output || "(aborted)";
        }

        return result;
    } finally {
        // Cleanup temp files
        if (tmpPromptPath) try { fs.unlinkSync(tmpPromptPath); } catch { /* ignore */ }
        if (tmpPromptDir) try { fs.rmdirSync(tmpPromptDir); } catch { /* ignore */ }
    }
}
