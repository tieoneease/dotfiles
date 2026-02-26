/**
 * Multi-Select Tool - Pick multiple items from a list
 * Space toggles selection, Enter submits, Esc cancels
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey, Text, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

interface OptionWithDesc {
	label: string;
	description?: string;
}

interface MultiSelectDetails {
	question: string;
	options: string[];
	selected: string[];
	cancelled: boolean;
}

const OptionSchema = Type.Object({
	label: Type.String({ description: "Display label for the option" }),
	description: Type.Optional(Type.String({ description: "Optional description shown below label" })),
});

const MultiSelectParams = Type.Object({
	question: Type.String({ description: "The question to ask the user" }),
	options: Type.Array(OptionSchema, { description: "Options the user can select (multiple)" }),
	minSelect: Type.Optional(Type.Number({ description: "Minimum selections required (default: 1)" })),
	maxSelect: Type.Optional(Type.Number({ description: "Maximum selections allowed (default: unlimited)" })),
});

export default function multiselect(pi: ExtensionAPI) {
	pi.registerTool({
		name: "multiselect",
		label: "Multi-Select",
		description:
			"Ask the user to select one or more items from a list. Use when the user needs to pick multiple options, e.g. features to enable, files to process, items to include.",
		parameters: MultiSelectParams,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) {
				return {
					content: [{ type: "text", text: "Error: UI not available (running in non-interactive mode)" }],
					details: {
						question: params.question,
						options: params.options.map((o) => o.label),
						selected: [],
						cancelled: true,
					} as MultiSelectDetails,
				};
			}

			if (params.options.length === 0) {
				return {
					content: [{ type: "text", text: "Error: No options provided" }],
					details: { question: params.question, options: [], selected: [], cancelled: true } as MultiSelectDetails,
				};
			}

			const minSelect = params.minSelect ?? 1;
			const maxSelect = params.maxSelect ?? params.options.length;

			const result = await ctx.ui.custom<{ selected: string[]; cancelled: boolean }>(
				(tui, theme, _kb, done) => {
					let cursorIndex = 0;
					const checked = new Set<number>();
					let cachedLines: string[] | undefined;

					function refresh() {
						cachedLines = undefined;
						tui.requestRender();
					}

					function canSubmit() {
						return checked.size >= minSelect && checked.size <= maxSelect;
					}

					function handleInput(data: string) {
						if (matchesKey(data, Key.up)) {
							cursorIndex = Math.max(0, cursorIndex - 1);
							refresh();
							return;
						}
						if (matchesKey(data, Key.down)) {
							cursorIndex = Math.min(params.options.length - 1, cursorIndex + 1);
							refresh();
							return;
						}

						// Space toggles checkbox
						if (matchesKey(data, Key.space)) {
							if (checked.has(cursorIndex)) {
								checked.delete(cursorIndex);
							} else if (checked.size < maxSelect) {
								checked.add(cursorIndex);
							}
							refresh();
							return;
						}

						// Enter submits if valid
						if (matchesKey(data, Key.enter)) {
							if (canSubmit()) {
								const selected = [...checked]
									.sort((a, b) => a - b)
									.map((i) => params.options[i].label);
								done({ selected, cancelled: false });
							}
							return;
						}

						// 'a' to select all / deselect all
						if (data === "a") {
							if (checked.size === params.options.length) {
								checked.clear();
							} else {
								for (let i = 0; i < Math.min(params.options.length, maxSelect); i++) {
									checked.add(i);
								}
							}
							refresh();
							return;
						}

						if (matchesKey(data, Key.escape)) {
							done({ selected: [], cancelled: true });
						}
					}

					function render(width: number): string[] {
						if (cachedLines) return cachedLines;

						const lines: string[] = [];
						const add = (s: string) => lines.push(truncateToWidth(s, width));

						add(theme.fg("accent", "─".repeat(width)));
						add(theme.fg("text", ` ${params.question}`));

						// Constraint hint
						if (minSelect > 1 || maxSelect < params.options.length) {
							const parts: string[] = [];
							if (minSelect > 1) parts.push(`min ${minSelect}`);
							if (maxSelect < params.options.length) parts.push(`max ${maxSelect}`);
							add(theme.fg("dim", `  (${parts.join(", ")})`));
						}

						lines.push("");

						for (let i = 0; i < params.options.length; i++) {
							const opt = params.options[i];
							const isCursor = i === cursorIndex;
							const isChecked = checked.has(i);

							const box = isChecked ? "☑" : "☐";
							const prefix = isCursor ? theme.fg("accent", "> ") : "  ";

							if (isCursor) {
								add(prefix + theme.fg("accent", `${box} ${opt.label}`));
							} else if (isChecked) {
								add(prefix + theme.fg("success", `${box}`) + ` ${theme.fg("text", opt.label)}`);
							} else {
								add(`  ${theme.fg("muted", box)} ${theme.fg("text", opt.label)}`);
							}

							if (opt.description) {
								add(`     ${theme.fg("muted", opt.description)}`);
							}
						}

						lines.push("");

						// Status line
						const count = checked.size;
						const countText = `${count} selected`;
						const valid = canSubmit();
						add(
							`  ${theme.fg(valid ? "success" : "dim", countText)}${
								!valid && minSelect > count ? theme.fg("warning", ` (need at least ${minSelect})`) : ""
							}`,
						);

						lines.push("");
						add(
							theme.fg(
								"dim",
								" ↑↓ navigate • Space toggle • a select all • Enter submit • Esc cancel",
							),
						);
						add(theme.fg("accent", "─".repeat(width)));

						cachedLines = lines;
						return lines;
					}

					return {
						render,
						invalidate: () => {
							cachedLines = undefined;
						},
						handleInput,
					};
				},
			);

			const simpleOptions = params.options.map((o) => o.label);

			if (result.cancelled) {
				return {
					content: [{ type: "text", text: "User cancelled the selection" }],
					details: {
						question: params.question,
						options: simpleOptions,
						selected: [],
						cancelled: true,
					} as MultiSelectDetails,
				};
			}

			const numbered = result.selected.map((s, i) => `${i + 1}. ${s}`).join(", ");
			return {
				content: [
					{
						type: "text",
						text: `User selected ${result.selected.length} item(s): ${numbered}`,
					},
				],
				details: {
					question: params.question,
					options: simpleOptions,
					selected: result.selected,
					cancelled: false,
				} as MultiSelectDetails,
			};
		},

		renderCall(args, theme) {
			let text = theme.fg("toolTitle", theme.bold("multiselect ")) + theme.fg("muted", args.question);
			const opts = Array.isArray(args.options) ? args.options : [];
			if (opts.length) {
				const labels = opts.map((o: OptionWithDesc) => o.label);
				text += `\n${theme.fg("dim", `  Options: ${labels.join(", ")}`)}`;
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const details = result.details as MultiSelectDetails | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}

			if (details.cancelled) {
				return new Text(theme.fg("warning", "Cancelled"), 0, 0);
			}

			const items = details.selected.map((s) => theme.fg("accent", `☑ ${s}`)).join("\n");
			return new Text(theme.fg("success", `✓ ${details.selected.length} selected\n`) + items, 0, 0);
		},
	});
}
