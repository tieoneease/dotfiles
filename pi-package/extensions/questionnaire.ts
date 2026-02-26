/**
 * Questionnaire Tool - Unified user input tool
 *
 * Modes (per question):
 * - single:   Pick one option (default). "Type something" if allowOther.
 * - multiple: Checkbox selection with min/max constraints.
 * - review:   Side-by-side preview of proposals. Press 'n' to annotate options.
 *
 * Single question: auto-submit, no tabs.
 * Multiple questions: tab-based navigation with submit tab.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { StringEnum } from "@mariozechner/pi-ai";
import { Editor, type EditorTheme, Key, matchesKey, Text, truncateToWidth } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";

// ─── Types ──────────────────────────────────────────────

interface QuestionOption {
	value: string;
	label: string;
	description?: string;
	content?: string; // Full proposal text shown in review preview
}

type RenderOption = QuestionOption & { isOther?: boolean };

interface Question {
	id: string;
	label: string;
	prompt: string;
	options: QuestionOption[];
	select: "single" | "multiple" | "review";
	allowOther: boolean;
	minSelect: number;
	maxSelect: number;
}

interface Selection {
	value: string;
	label: string;
	index: number; // 1-based
}

interface OptionNote {
	value: string;
	label: string;
	text: string;
}

interface Answer {
	id: string;
	value: string;
	label: string;
	wasCustom: boolean;
	index?: number; // 1-based, single/review non-custom only
	selections?: Selection[]; // multi-select only
	optionNotes?: OptionNote[]; // review mode: notes on any options
}

interface QuestionnaireResult {
	questions: Question[];
	answers: Answer[];
	cancelled: boolean;
}

// ─── Schema ─────────────────────────────────────────────

const OptionSchema = Type.Object({
	value: Type.String({ description: "The value returned when selected" }),
	label: Type.String({ description: "Display label for the option" }),
	description: Type.Optional(Type.String({ description: "Optional description shown below label" })),
	content: Type.Optional(Type.String({ description: "Full proposal/design text shown in preview panel (review mode)" })),
});

const QuestionSchema = Type.Object({
	id: Type.String({ description: "Unique identifier for this question" }),
	prompt: Type.String({ description: "The full question text to display" }),
	options: Type.Array(OptionSchema, { description: "Available options to choose from" }),
	label: Type.Optional(
		Type.String({ description: "Short contextual label for tab bar, e.g. 'Scope', 'Priority' (defaults to Q1, Q2)" }),
	),
	select: Type.Optional(
		StringEnum(["single", "multiple", "review"] as const),
	),
	allowOther: Type.Optional(
		Type.Boolean({ description: "Show 'Type something' option for custom text input (default: false, single-select and multi-select only)" }),
	),
	minSelect: Type.Optional(
		Type.Number({ description: "Minimum selections for multi-select (default: 1)" }),
	),
	maxSelect: Type.Optional(
		Type.Number({ description: "Maximum selections for multi-select (default: all)" }),
	),
});

const Params = Type.Object({
	questions: Type.Array(QuestionSchema, { description: "Questions to ask the user" }),
});

// ─── Helpers ────────────────────────────────────────────

function errorResult(
	message: string,
	questions: Question[] = [],
): { content: { type: "text"; text: string }[]; details: QuestionnaireResult } {
	return {
		content: [{ type: "text", text: message }],
		details: { questions, answers: [], cancelled: true },
	};
}

function normalizeQuestion(q: any, index: number): Question {
	const select: "single" | "multiple" | "review" = q.select || "single";
	return {
		id: q.id,
		label: q.label || `Q${index + 1}`,
		prompt: q.prompt,
		options: q.options,
		select,
		allowOther: (select === "single" || select === "multiple") ? q.allowOther === true : false,
		minSelect: select === "multiple" ? (q.minSelect ?? 1) : 1,
		maxSelect: select === "multiple" ? (q.maxSelect ?? q.options.length) : 1,
	};
}

/** Strip ANSI escape codes to get visual character count */
function stripAnsi(str: string): string {
	return str.replace(/\x1b\[[0-9;]*m/g, "");
}

/** Pad a string (possibly containing ANSI codes) to a target visual width */
function padRight(str: string, targetWidth: number): string {
	const visual = stripAnsi(str).length;
	if (visual >= targetWidth) return truncateToWidth(str, targetWidth);
	return str + " ".repeat(targetWidth - visual);
}

/** Word-wrap plain text to a given width, preserving newlines */
function wordWrap(text: string, width: number): string[] {
	if (width <= 0 || !text) return text ? [text] : [];
	const result: string[] = [];
	for (const line of text.split("\n")) {
		if (line.length === 0) {
			result.push("");
			continue;
		}
		if (line.length <= width) {
			result.push(line);
			continue;
		}
		let remaining = line;
		while (remaining.length > width) {
			let breakAt = remaining.lastIndexOf(" ", width);
			if (breakAt <= 0) breakAt = width;
			result.push(remaining.substring(0, breakAt));
			remaining = remaining.substring(breakAt).trimStart();
		}
		if (remaining) result.push(remaining);
	}
	return result;
}

// ─── Extension ──────────────────────────────────────────

export default function questionnaire(pi: ExtensionAPI) {
	pi.registerTool({
		name: "questionnaire",
		label: "Questionnaire",
		description:
			"Ask the user one or more questions. Use for clarifying requirements, getting preferences, or confirming decisions. " +
			"Each question can be single-select (pick one, default), multi-select (pick several with checkboxes, set select to 'multiple'), " +
			"or review (side-by-side preview of proposals with optional notes, set select to 'review' and provide content on each option). " +
			"For a single question, shows a simple option list. For multiple questions, shows a tab-based interface.",
		parameters: Params,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) {
				return errorResult("Error: UI not available (running in non-interactive mode)");
			}
			if (params.questions.length === 0) {
				return errorResult("Error: No questions provided");
			}

			const questions = params.questions.map(normalizeQuestion);
			const isMulti = questions.length > 1;
			const totalTabs = questions.length + 1; // questions + Submit

			const result = await ctx.ui.custom<QuestionnaireResult>((tui, theme, _kb, done) => {
				// ─── State ───
				let currentTab = 0;
				let optionIndex = 0;
				let inputMode = false; // "Type something" editor
				let inputQuestionId: string | null = null;
				let noteEditMode = false; // Review note editor
				let noteEditOptionValue: string | null = null;
				let cachedLines: string[] | undefined;
				const answers = new Map<string, Answer>();
				const checkedSets = new Map<string, Set<number>>(); // multi-select state
				const dynamicOptions = new Map<string, QuestionOption[]>(); // user-added custom options per question
				const noteMaps = new Map<string, Map<string, string>>(); // review notes per question

				// Shared editor
				const editorTheme: EditorTheme = {
					borderColor: (s) => theme.fg("accent", s),
					selectList: {
						selectedPrefix: (t) => theme.fg("accent", t),
						selectedText: (t) => theme.fg("accent", t),
						description: (t) => theme.fg("muted", t),
						scrollInfo: (t) => theme.fg("dim", t),
						noMatch: (t) => theme.fg("warning", t),
					},
				};
				const editor = new Editor(tui, editorTheme);

				// ─── Helpers ───
				function refresh() {
					cachedLines = undefined;
					tui.requestRender();
				}

				function submit(cancelled: boolean) {
					done({ questions, answers: Array.from(answers.values()), cancelled });
				}

				function currentQuestion(): Question | undefined {
					return questions[currentTab];
				}

				function currentDisplayOptions(): RenderOption[] {
					const q = currentQuestion();
					if (!q) return [];
					const opts: RenderOption[] = [...q.options];
					// For multi-select, include user-added custom options before "Type something"
					if (q.select === "multiple") {
						for (const dyn of getDynamic(q.id)) {
							opts.push({ ...dyn, isOther: false });
						}
					}
					if (q.allowOther) {
						opts.push({ value: "__other__", label: "Type something.", isOther: true });
					}
					return opts;
				}

				function allAnswered(): boolean {
					return questions.every((q) => answers.has(q.id));
				}

				function getChecked(qId: string): Set<number> {
					if (!checkedSets.has(qId)) checkedSets.set(qId, new Set());
					return checkedSets.get(qId)!;
				}

				function getDynamic(qId: string): QuestionOption[] {
					if (!dynamicOptions.has(qId)) dynamicOptions.set(qId, []);
					return dynamicOptions.get(qId)!;
				}

				function getNoteMap(qId: string): Map<string, string> {
					if (!noteMaps.has(qId)) noteMaps.set(qId, new Map());
					return noteMaps.get(qId)!;
				}

				function canSubmitMulti(q: Question): boolean {
					const checked = getChecked(q.id);
					return checked.size >= q.minSelect && checked.size <= q.maxSelect;
				}

				function advanceAfterAnswer() {
					if (!isMulti) {
						submit(false);
						return;
					}
					if (currentTab < questions.length - 1) {
						currentTab++;
					} else {
						currentTab = questions.length; // Submit tab
					}
					optionIndex = 0;
					refresh();
				}

				function saveSingleAnswer(q: Question, value: string, label: string, wasCustom: boolean, index?: number) {
					const answer: Answer = { id: q.id, value, label, wasCustom, index };
					// Attach notes if this is a review question
					if (q.select === "review") {
						const notes = getNoteMap(q.id);
						if (notes.size > 0) {
							answer.optionNotes = [...notes.entries()].map(([v, text]) => ({
								value: v,
								label: q.options.find((o) => o.value === v)?.label || v,
								text,
							}));
						}
					}
					answers.set(q.id, answer);
				}

				function saveMultiAnswer(q: Question) {
					const checked = getChecked(q.id);
					const dynamic = getDynamic(q.id);
					const allOpts = [...q.options, ...dynamic];
					const selections: Selection[] = [...checked]
						.sort((a, b) => a - b)
						.filter((i) => i < allOpts.length) // skip "Type something" index
						.map((i) => ({ value: allOpts[i].value, label: allOpts[i].label, index: i + 1 }));
					answers.set(q.id, {
						id: q.id,
						value: selections.map((s) => s.value).join(", "),
						label: selections.map((s) => s.label).join(", "),
						wasCustom: dynamic.length > 0 && selections.some((s) => dynamic.some((d) => d.value === s.value)),
						selections,
					});
				}

				// Editor submit: dispatches based on active mode
				editor.onSubmit = (value) => {
					if (noteEditMode && noteEditOptionValue) {
						const q = currentQuestion();
						if (!q) return;
						const notes = getNoteMap(q.id);
						const trimmed = value.trim();
						if (trimmed) {
							notes.set(noteEditOptionValue, trimmed);
						} else {
							notes.delete(noteEditOptionValue);
						}
						noteEditMode = false;
						noteEditOptionValue = null;
						editor.setText("");
						refresh();
					} else if (inputMode && inputQuestionId) {
						const q = questions.find((q) => q.id === inputQuestionId);
						if (!q) return;
						const trimmed = value.trim();

						if (q.select === "multiple") {
							// Multi-select: add as new custom option, auto-check it
							if (trimmed) {
								const dynamic = getDynamic(q.id);
								const newOpt: QuestionOption = { value: trimmed, label: trimmed };
								dynamic.push(newOpt);
								const newIdx = q.options.length + dynamic.length - 1;
								const checked = getChecked(q.id);
								if (checked.size < q.maxSelect) {
									checked.add(newIdx);
								}
								optionIndex = newIdx;
							}
							inputMode = false;
							inputQuestionId = null;
							editor.setText("");
							refresh();
						} else {
							// Single-select: save as answer and advance
							saveSingleAnswer(q, trimmed || "(no response)", trimmed || "(no response)", true);
							inputMode = false;
							inputQuestionId = null;
							editor.setText("");
							advanceAfterAnswer();
						}
					}
				};

				// ─── Render helpers ───
				function renderSingleOptions(opts: RenderOption[], add: (s: string) => void) {
					for (let i = 0; i < opts.length; i++) {
						const opt = opts[i];
						const selected = i === optionIndex;
						const isOther = opt.isOther === true;
						const prefix = selected ? theme.fg("accent", "> ") : "  ";
						const color = selected ? "accent" : "text";

						if (isOther && inputMode) {
							add(prefix + theme.fg("accent", `${i + 1}. ${opt.label} ✎`));
						} else {
							add(prefix + theme.fg(color as any, `${i + 1}. ${opt.label}`));
						}
						if (opt.description) {
							add(`     ${theme.fg("muted", opt.description)}`);
						}
					}
				}

				function renderMultiOptions(q: Question, add: (s: string) => void) {
					const checked = getChecked(q.id);
					const dynamic = getDynamic(q.id);
					const allOpts = [...q.options, ...dynamic];
					const totalItems = allOpts.length + (q.allowOther ? 1 : 0);

					// Predefined + dynamic options (checkboxes)
					for (let i = 0; i < allOpts.length; i++) {
						const opt = allOpts[i];
						const isCursor = i === optionIndex;
						const isChecked = checked.has(i);
						const isCustom = i >= q.options.length;
						const box = isChecked ? "☑" : "☐";
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						const customInd = isCustom ? theme.fg("warning", " ✎") : "";

						if (isCursor) {
							add(prefix + theme.fg("accent", `${box} ${opt.label}`) + customInd);
						} else if (isChecked) {
							add(prefix + theme.fg("success", box) + ` ${theme.fg("text", opt.label)}` + customInd);
						} else {
							add(`  ${theme.fg("muted", box)} ${theme.fg("text", opt.label)}` + customInd);
						}

						if (opt.description) {
							add(`     ${theme.fg("muted", opt.description)}`);
						}
					}

					// "Type something" entry (not a checkbox — it's an action)
					if (q.allowOther) {
						const idx = allOpts.length;
						const isCursor = idx === optionIndex;
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						if (isCursor && inputMode) {
							add(prefix + theme.fg("accent", `+ Type something. ✎`));
						} else if (isCursor) {
							add(prefix + theme.fg("accent", `+ Type something.`));
						} else {
							add(`  ${theme.fg("dim", "+ Type something.")}`);
						}
					}
				}

				function renderReviewOptions(q: Question, width: number, add: (s: string) => void) {
					const notes = getNoteMap(q.id);

					// Calculate column widths
					const leftWidth = Math.min(Math.max(25, Math.floor(width * 0.35)), 50);
					const dividerLen = 3; // " │ "
					const rightWidth = width - leftWidth - dividerLen;

					// Narrow fallback: stacked layout
					if (rightWidth < 20) {
						renderReviewStacked(q, width, add);
						return;
					}

					// Build left panel
					const leftLines: string[] = [];
					for (let i = 0; i < q.options.length; i++) {
						const opt = q.options[i];
						const isCursor = i === optionIndex;
						const hasNote = notes.has(opt.value);
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						const color = isCursor ? "accent" : "text";
						const noteInd = hasNote ? theme.fg("warning", " ✎") : "";
						leftLines.push(prefix + theme.fg(color as any, `${i + 1}. ${opt.label}`) + noteInd);

						// Show note preview under the option if it has one
						if (hasNote) {
							const noteText = notes.get(opt.value)!;
							const preview = noteText.length > leftWidth - 8
								? noteText.substring(0, leftWidth - 11) + "..."
								: noteText;
							leftLines.push(`     ${theme.fg("dim", `"${preview}"`)}`);
						}
					}

					// Build right panel: title + content of highlighted option
					const highlighted = q.options[optionIndex];
					const content = highlighted?.content || highlighted?.description || "(no preview available)";
					const rightTitle = theme.fg("accent", theme.bold(highlighted?.label || ""));
					const wrappedContent = wordWrap(content, rightWidth - 1);
					const rightLines: string[] = [rightTitle, theme.fg("dim", "─".repeat(rightWidth - 1)), ...wrappedContent];

					// Combine columns line by line
					const totalLines = Math.max(leftLines.length, rightLines.length);
					const divider = theme.fg("dim", " │ ");
					for (let row = 0; row < totalLines; row++) {
						const left = padRight(leftLines[row] || "", leftWidth);
						const right = truncateToWidth(rightLines[row] || "", rightWidth);
						add(`${left}${divider}${right}`);
					}
				}

				function renderReviewStacked(q: Question, width: number, add: (s: string) => void) {
					const notes = getNoteMap(q.id);

					// Options list
					for (let i = 0; i < q.options.length; i++) {
						const opt = q.options[i];
						const isCursor = i === optionIndex;
						const hasNote = notes.has(opt.value);
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						const color = isCursor ? "accent" : "text";
						const noteInd = hasNote ? theme.fg("warning", " ✎") : "";
						add(prefix + theme.fg(color as any, `${i + 1}. ${opt.label}`) + noteInd);
					}

					// Preview below
					const highlighted = q.options[optionIndex];
					const content = highlighted?.content || highlighted?.description || "";
					if (content) {
						add("");
						add(theme.fg("dim", "─── ") + theme.fg("accent", theme.bold(highlighted.label)) + theme.fg("dim", " ───"));
						for (const line of wordWrap(content, width - 2)) {
							add(` ${line}`);
						}
					}
				}

				// ─── Input ───
				function handleInput(data: string) {
					// Editor modes: route to editor
					if (inputMode || noteEditMode) {
						if (matchesKey(data, Key.escape)) {
							inputMode = false;
							inputQuestionId = null;
							noteEditMode = false;
							noteEditOptionValue = null;
							editor.setText("");
							refresh();
							return;
						}
						editor.handleInput(data);
						refresh();
						return;
					}

					const q = currentQuestion();
					const opts = currentDisplayOptions();

					// Tab navigation (multi-question only)
					if (isMulti) {
						if (matchesKey(data, Key.tab) || matchesKey(data, Key.right)) {
							currentTab = (currentTab + 1) % totalTabs;
							optionIndex = 0;
							refresh();
							return;
						}
						if (matchesKey(data, Key.shift("tab")) || matchesKey(data, Key.left)) {
							currentTab = (currentTab - 1 + totalTabs) % totalTabs;
							optionIndex = 0;
							refresh();
							return;
						}
					}

					// Submit tab
					if (currentTab === questions.length) {
						if (matchesKey(data, Key.enter) && allAnswered()) {
							submit(false);
						} else if (matchesKey(data, Key.escape)) {
							submit(true);
						}
						return;
					}

					if (!q) return;

					// Option navigation
					if (matchesKey(data, Key.up)) {
						optionIndex = Math.max(0, optionIndex - 1);
						refresh();
						return;
					}
					if (matchesKey(data, Key.down)) {
						let maxIdx: number;
						if (q.select === "multiple") {
							const dynamic = getDynamic(q.id);
							const allCount = q.options.length + dynamic.length;
							maxIdx = q.allowOther ? allCount : allCount - 1; // +1 for "Type something"
						} else {
							maxIdx = opts.length - 1;
						}
						optionIndex = Math.min(maxIdx, optionIndex + 1);
						refresh();
						return;
					}

					// ── Single-select ──
					if (q.select === "single") {
						if (matchesKey(data, Key.enter)) {
							const opt = opts[optionIndex];
							if (opt.isOther) {
								inputMode = true;
								inputQuestionId = q.id;
								editor.setText("");
								refresh();
							} else {
								saveSingleAnswer(q, opt.value, opt.label, false, optionIndex + 1);
								advanceAfterAnswer();
							}
							return;
						}
					}

					// ── Multi-select ──
					if (q.select === "multiple") {
						const checked = getChecked(q.id);
						const dynamic = getDynamic(q.id);
						const allCount = q.options.length + dynamic.length;
						const isOnTypeOption = q.allowOther && optionIndex === allCount;

						if (matchesKey(data, Key.space)) {
							if (isOnTypeOption) {
								// Open editor for custom entry
								inputMode = true;
								inputQuestionId = q.id;
								editor.setText("");
								refresh();
							} else if (checked.has(optionIndex)) {
								checked.delete(optionIndex);
							} else if (checked.size < q.maxSelect) {
								checked.add(optionIndex);
							}
							refresh();
							return;
						}

						if (data === "a") {
							if (checked.size === allCount) {
								checked.clear();
							} else {
								for (let i = 0; i < Math.min(allCount, q.maxSelect); i++) {
									checked.add(i);
								}
							}
							refresh();
							return;
						}

						if (matchesKey(data, Key.enter)) {
							if (canSubmitMulti(q)) {
								saveMultiAnswer(q);
								advanceAfterAnswer();
							}
							return;
						}
					}

					// ── Review ──
					if (q.select === "review") {
						// 'n' to add/edit notes on highlighted option
						if (data === "n") {
							const opt = q.options[optionIndex];
							const notes = getNoteMap(q.id);
							noteEditMode = true;
							noteEditOptionValue = opt.value;
							editor.setText(notes.get(opt.value) || "");
							refresh();
							return;
						}

						// Enter selects the highlighted option
						if (matchesKey(data, Key.enter)) {
							const opt = q.options[optionIndex];
							saveSingleAnswer(q, opt.value, opt.label, false, optionIndex + 1);
							advanceAfterAnswer();
							return;
						}
					}

					// Cancel
					if (matchesKey(data, Key.escape)) {
						submit(true);
					}
				}

				// ─── Render ───
				function render(width: number): string[] {
					if (cachedLines) return cachedLines;

					const lines: string[] = [];
					const q = currentQuestion();
					const opts = currentDisplayOptions();
					const add = (s: string) => lines.push(truncateToWidth(s, width));

					add(theme.fg("accent", "─".repeat(width)));

					// Tab bar (multi-question only)
					if (isMulti) {
						const tabs: string[] = ["← "];
						for (let i = 0; i < questions.length; i++) {
							const isActive = i === currentTab;
							const isAnswered = answers.has(questions[i].id);
							const lbl = questions[i].label;
							const box = isAnswered ? "■" : "□";
							const color = isAnswered ? "success" : "muted";
							const text = ` ${box} ${lbl} `;
							const styled = isActive
								? theme.bg("selectedBg", theme.fg("text", text))
								: theme.fg(color, text);
							tabs.push(`${styled} `);
						}
						const canSubmitAll = allAnswered();
						const isSubmitTab = currentTab === questions.length;
						const submitText = " ✓ Submit ";
						const submitStyled = isSubmitTab
							? theme.bg("selectedBg", theme.fg("text", submitText))
							: theme.fg(canSubmitAll ? "success" : "dim", submitText);
						tabs.push(`${submitStyled} →`);
						add(` ${tabs.join("")}`);
						lines.push("");
					}

					// ── Note editor overlay ──
					if (noteEditMode && noteEditOptionValue) {
						const q2 = currentQuestion();
						const optLabel = q2?.options.find((o) => o.value === noteEditOptionValue)?.label || noteEditOptionValue;
						add(theme.fg("text", ` Notes for: `) + theme.fg("accent", theme.bold(optLabel)));
						lines.push("");
						add(theme.fg("muted", " Your notes (empty to remove):"));
						for (const line of editor.render(width - 2)) {
							add(` ${line}`);
						}
						lines.push("");
						add(theme.fg("dim", " Enter to save • Esc to discard"));
					}
					// ── Submit tab ──
					else if (currentTab === questions.length) {
						add(theme.fg("accent", theme.bold(" Ready to submit")));
						lines.push("");
						for (const question of questions) {
							const answer = answers.get(question.id);
							if (answer) {
								const prefix = answer.wasCustom ? "(wrote) " : "";
								let display: string;
								if (answer.selections) {
									display = `${answer.selections.length} selected: ${answer.label}`;
								} else {
									display = `${prefix}${answer.label}`;
								}
								add(`${theme.fg("muted", ` ${question.label}: `)}${theme.fg("text", display)}`);

								// Show notes summary for review questions
								if (answer.optionNotes && answer.optionNotes.length > 0) {
									for (const note of answer.optionNotes) {
										const preview = note.text.length > 50 ? note.text.substring(0, 47) + "..." : note.text;
										add(`   ${theme.fg("warning", "✎ ")}${theme.fg("dim", note.label + ": ")}${theme.fg("muted", preview)}`);
									}
								}
							}
						}
						lines.push("");
						if (allAnswered()) {
							add(theme.fg("success", " Press Enter to submit"));
						} else {
							const missing = questions
								.filter((q) => !answers.has(q.id))
								.map((q) => q.label)
								.join(", ");
							add(theme.fg("warning", ` Unanswered: ${missing}`));
						}
					}
					// ── Question content ──
					else if (q) {
						add(theme.fg("text", ` ${q.prompt}`));

						// Multi-select constraint hint
						if (q.select === "multiple" && (q.minSelect > 1 || q.maxSelect < q.options.length)) {
							const parts: string[] = [];
							if (q.minSelect > 1) parts.push(`min ${q.minSelect}`);
							if (q.maxSelect < q.options.length) parts.push(`max ${q.maxSelect}`);
							add(theme.fg("dim", `  (${parts.join(", ")})`));
						}

						lines.push("");

						// Options (mode-specific)
						if (q.select === "review") {
							renderReviewOptions(q, width, add);
						} else if (q.select === "multiple") {
							renderMultiOptions(q, add);
						} else {
							renderSingleOptions(opts, add);
						}

						// "Type something" editor (single-select and multi-select)
						if (inputMode && (q.select === "single" || q.select === "multiple")) {
							lines.push("");
							add(theme.fg("muted", q.select === "multiple" ? " Add custom option:" : " Your answer:"));
							for (const line of editor.render(width - 2)) {
								add(` ${line}`);
							}
						}

						// Multi-select status
						if (q.select === "multiple") {
							lines.push("");
							const checked = getChecked(q.id);
							const count = checked.size;
							const valid = canSubmitMulti(q);
							let status = theme.fg(valid ? "success" : "dim", `${count} selected`);
							if (!valid && q.minSelect > count) {
								status += theme.fg("warning", ` (need at least ${q.minSelect})`);
							}
							add(`  ${status}`);
						}
					}

					lines.push("");

					// Help text
					if (inputMode) {
						add(theme.fg("dim", " Enter to submit • Esc to go back"));
					} else if (!noteEditMode && currentTab !== questions.length && q) {
						const nav = isMulti ? "Tab/←→ navigate • " : "";
						if (q.select === "review") {
							add(theme.fg("dim", ` ${nav}↑↓ browse • n add notes • Enter select • Esc cancel`));
						} else if (q.select === "multiple") {
							add(theme.fg("dim", ` ${nav}↑↓ move • Space toggle • a select all • Enter confirm • Esc cancel`));
						} else {
							add(theme.fg("dim", ` ${nav}↑↓ navigate • Enter select • Esc cancel`));
						}
					}

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
			});

			// ─── Format result ───
			if (result.cancelled) {
				return {
					content: [{ type: "text", text: "User cancelled the questionnaire" }],
					details: result,
				};
			}

			const answerLines = result.answers.map((a) => {
				const qLabel = questions.find((q) => q.id === a.id)?.label || a.id;
				const lines: string[] = [];

				if (a.wasCustom) {
					lines.push(`${qLabel}: user wrote: ${a.label}`);
				} else if (a.selections) {
					const items = a.selections.map((s) => `${s.index}. ${s.label}`).join(", ");
					lines.push(`${qLabel}: user selected ${a.selections.length} item(s): ${items}`);
				} else {
					lines.push(`${qLabel}: user selected: ${a.index}. ${a.label}`);
				}

				// Include notes
				if (a.optionNotes && a.optionNotes.length > 0) {
					for (const note of a.optionNotes) {
						lines.push(`  Notes on "${note.label}": ${note.text}`);
					}
				}

				return lines.join("\n");
			});

			return {
				content: [{ type: "text", text: answerLines.join("\n") }],
				details: result,
			};
		},

		renderCall(args, theme) {
			const qs = (args.questions as any[]) || [];
			const count = qs.length;
			const labels = qs.map((q) => q.label || q.id).join(", ");
			let text = theme.fg("toolTitle", theme.bold("questionnaire "));
			text += theme.fg("muted", `${count} question${count !== 1 ? "s" : ""}`);
			if (labels) {
				text += theme.fg("dim", ` (${truncateToWidth(labels, 40)})`);
			}
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const details = result.details as QuestionnaireResult | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}
			if (details.cancelled) {
				return new Text(theme.fg("warning", "Cancelled"), 0, 0);
			}
			const lines = details.answers.map((a) => {
				const answerLines: string[] = [];
				if (a.wasCustom) {
					answerLines.push(`${theme.fg("success", "✓ ")}${theme.fg("accent", a.id)}: ${theme.fg("muted", "(wrote) ")}${a.label}`);
				} else if (a.selections) {
					const items = a.selections.map((s) => s.label).join(", ");
					answerLines.push(`${theme.fg("success", "✓ ")}${theme.fg("accent", a.id)}: ${items} (${a.selections.length} selected)`);
				} else {
					const display = a.index ? `${a.index}. ${a.label}` : a.label;
					answerLines.push(`${theme.fg("success", "✓ ")}${theme.fg("accent", a.id)}: ${display}`);
				}

				// Notes
				if (a.optionNotes && a.optionNotes.length > 0) {
					for (const note of a.optionNotes) {
						answerLines.push(`  ${theme.fg("warning", "✎ ")}${theme.fg("dim", note.label + ": ")}${note.text}`);
					}
				}

				return answerLines.join("\n");
			});
			return new Text(lines.join("\n"), 0, 0);
		},
	});
}
