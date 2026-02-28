/**
 * Questionnaire Tool - Unified user input tool
 *
 * Modes (per question):
 * - single:   Pick one option (default). "Type something" if allowOther.
 * - multiple: Checkbox selection with min/max constraints.
 * - review:   Side-by-side preview of proposals with optional notes.
 *             j/k to scroll the preview panel.
 *
 * All modes: Press 'n' to annotate the highlighted option.
 *            Press 'c' to add a comment to the question.
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
	content?: string;
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
	index: number;
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
	index?: number;
	selections?: Selection[];
	optionNotes?: OptionNote[];
	comment?: string;
}

interface QuestionnaireResult {
	questions: Question[];
	answers: Answer[];
	cancelled: boolean;
}

// ─── Schema ─────────────────────────────────────────────

const OptionSchema = Type.Object({
	value: Type.String(),
	label: Type.String(),
	description: Type.Optional(Type.String()),
	content: Type.Optional(Type.String({ description: "Preview text (review mode)" })),
});

const QuestionSchema = Type.Object({
	id: Type.String(),
	prompt: Type.String(),
	options: Type.Array(OptionSchema),
	label: Type.Optional(Type.String({ description: "Tab label (defaults to Q1, Q2)" })),
	select: Type.Optional(StringEnum(["single", "multiple", "review"] as const)),
	allowOther: Type.Optional(Type.Boolean({ description: "Allow custom input (default: true, single-select only)" })),
	minSelect: Type.Optional(Type.Number({ description: "Min selections for multi-select (default: 1)" })),
	maxSelect: Type.Optional(Type.Number({ description: "Max selections for multi-select (default: all)" })),
});

const Params = Type.Object({
	questions: Type.Array(QuestionSchema),
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
		allowOther: select === "single" ? q.allowOther !== false : select === "multiple" ? q.allowOther === true : false,
		minSelect: select === "multiple" ? (q.minSelect ?? 1) : 1,
		maxSelect: select === "multiple" ? (q.maxSelect ?? q.options.length) : 1,
	};
}

function stripAnsi(str: string): string {
	return str.replace(/\x1b\[[0-9;]*m/g, "");
}

function padRight(str: string, targetWidth: number): string {
	const visual = stripAnsi(str).length;
	if (visual >= targetWidth) return truncateToWidth(str, targetWidth);
	return str + " ".repeat(targetWidth - visual);
}

function wordWrap(text: string, width: number): string[] {
	if (width <= 0 || !text) return text ? [text] : [];
	const result: string[] = [];
	for (const line of text.split("\n")) {
		if (line.length === 0) { result.push(""); continue; }
		if (line.length <= width) { result.push(line); continue; }
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
			"Ask the user one or more questions. Modes per question: single-select (default), " +
			"multi-select (select='multiple'), review (select='review', provide content). " +
			"Single question auto-submits; multiple shows tabs.",
		parameters: Params,

		async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
			if (!ctx.hasUI) return errorResult("Error: UI not available (running in non-interactive mode)");
			if (params.questions.length === 0) return errorResult("Error: No questions provided");

			const questions = params.questions.map(normalizeQuestion);
			const isMulti = questions.length > 1;
			const totalTabs = questions.length + 1;

			const result = await ctx.ui.custom<QuestionnaireResult>((tui, theme, _kb, done) => {
				// ─── State ───
				let currentTab = 0;
				let optionIndex = 0;
				let inputMode = false;
				let inputQuestionId: string | null = null;
				let noteEditMode = false;
				let noteEditOptionValue: string | null = null;
				let cachedLines: string[] | undefined;
				const answers = new Map<string, Answer>();
				const checkedSets = new Map<string, Set<number>>();
				const dynamicOptions = new Map<string, QuestionOption[]>();
				const noteMaps = new Map<string, Map<string, string>>();
				let previewScroll = 0;
				let previewMaxScroll = 0;
				let commentMode = false;
				const questionComments = new Map<string, string>();

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
				function refresh() { cachedLines = undefined; tui.requestRender(); }
				function submit(cancelled: boolean) { done({ questions, answers: Array.from(answers.values()), cancelled }); }
				function currentQuestion(): Question | undefined { return questions[currentTab]; }

				function currentDisplayOptions(): RenderOption[] {
					const q = currentQuestion();
					if (!q) return [];
					const opts: RenderOption[] = [...q.options];
					if (q.select === "multiple") {
						for (const dyn of getDynamic(q.id)) opts.push({ ...dyn, isOther: false });
					}
					if (q.allowOther) opts.push({ value: "__other__", label: "Type something.", isOther: true });
					return opts;
				}

				function allAnswered(): boolean { return questions.every((q) => answers.has(q.id)); }

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
					if (!isMulti) { submit(false); return; }
					if (currentTab < questions.length - 1) currentTab++;
					else currentTab = questions.length;
					optionIndex = 0;
					previewScroll = 0;
					refresh();
				}

				function saveSingleAnswer(q: Question, value: string, label: string, wasCustom: boolean, index?: number) {
					const answer: Answer = { id: q.id, value, label, wasCustom, index };
					const comment = questionComments.get(q.id);
					if (comment) answer.comment = comment;
					const notes = getNoteMap(q.id);
					if (notes.size > 0) {
						answer.optionNotes = [...notes.entries()].map(([v, text]) => ({
							value: v,
							label: q.options.find((o) => o.value === v)?.label || v,
							text,
						}));
					}
					answers.set(q.id, answer);
				}

				function saveMultiAnswer(q: Question) {
					const checked = getChecked(q.id);
					const dynamic = getDynamic(q.id);
					const allOpts = [...q.options, ...dynamic];
					const selections: Selection[] = [...checked]
						.sort((a, b) => a - b)
						.filter((i) => i < allOpts.length)
						.map((i) => ({ value: allOpts[i].value, label: allOpts[i].label, index: i + 1 }));
					const answer: Answer = {
						id: q.id,
						value: selections.map((s) => s.value).join(", "),
						label: selections.map((s) => s.label).join(", "),
						wasCustom: dynamic.length > 0 && selections.some((s) => dynamic.some((d) => d.value === s.value)),
						selections,
					};
					const notes = getNoteMap(q.id);
					if (notes.size > 0) {
						answer.optionNotes = [...notes.entries()].map(([v, text]) => ({
							value: v,
							label: allOpts.find((o) => o.value === v)?.label || v,
							text,
						}));
					}
					const comment = questionComments.get(q.id);
					if (comment) answer.comment = comment;
					answers.set(q.id, answer);
				}

				editor.onSubmit = (value) => {
					if (commentMode) {
						const q = currentQuestion();
						if (!q) return;
						const trimmed = value.trim();
						if (trimmed) questionComments.set(q.id, trimmed);
						else questionComments.delete(q.id);
						commentMode = false;
						editor.setText("");
						refresh();
					} else if (noteEditMode && noteEditOptionValue) {
						const q = currentQuestion();
						if (!q) return;
						const notes = getNoteMap(q.id);
						const trimmed = value.trim();
						if (trimmed) notes.set(noteEditOptionValue, trimmed);
						else notes.delete(noteEditOptionValue);
						noteEditMode = false;
						noteEditOptionValue = null;
						editor.setText("");
						refresh();
					} else if (inputMode && inputQuestionId) {
						const q = questions.find((q) => q.id === inputQuestionId);
						if (!q) return;
						const trimmed = value.trim();
						if (q.select === "multiple") {
							if (trimmed) {
								const dynamic = getDynamic(q.id);
								const newOpt: QuestionOption = { value: trimmed, label: trimmed };
								dynamic.push(newOpt);
								const newIdx = q.options.length + dynamic.length - 1;
								const checked = getChecked(q.id);
								if (checked.size < q.maxSelect) checked.add(newIdx);
								optionIndex = newIdx;
							}
							inputMode = false;
							inputQuestionId = null;
							editor.setText("");
							refresh();
						} else {
							saveSingleAnswer(q, trimmed || "(no response)", trimmed || "(no response)", true);
							inputMode = false;
							inputQuestionId = null;
							editor.setText("");
							advanceAfterAnswer();
						}
					}
				};

				// ─── Render helpers ───

				function renderSingleOptions(opts: RenderOption[], notes: Map<string, string>, add: (s: string) => void, width: number): number {
					let cursorOffset = 0;
					let lineCount = 0;
					for (let i = 0; i < opts.length; i++) {
						const opt = opts[i];
						const selected = i === optionIndex;
						const isOther = opt.isOther === true;
						const hasNote = !isOther && notes.has(opt.value);
						const noteInd = hasNote ? theme.fg("warning", " ✎") : "";
						const prefix = selected ? theme.fg("accent", "> ") : "  ";
						const color = selected ? "accent" : "text";
						if (selected) cursorOffset = lineCount;
						if (isOther && inputMode) {
							add(prefix + theme.fg("accent", `${i + 1}. ${opt.label} ✎`));
						} else {
							add(prefix + theme.fg(color as any, `${i + 1}. ${opt.label}`) + noteInd);
						}
						lineCount++;
						if (opt.description) {
							for (const dLine of wordWrap(opt.description, width - 6)) {
								add(`     ${theme.fg("muted", dLine)}`);
								lineCount++;
							}
						}
						if (hasNote) {
							const noteText = notes.get(opt.value)!;
							const maxLen = Math.max(8, width - 10);
							const preview = noteText.length > maxLen ? noteText.substring(0, maxLen - 3) + "..." : noteText;
							add(`     ${theme.fg("dim", `"${preview}"`)}`);
							lineCount++;
						}
					}
					return cursorOffset;
				}

				function renderMultiOptions(q: Question, notes: Map<string, string>, add: (s: string) => void, width: number): number {
					const checked = getChecked(q.id);
					const dynamic = getDynamic(q.id);
					const allOpts = [...q.options, ...dynamic];
					let cursorOffset = 0;
					let lineCount = 0;

					for (let i = 0; i < allOpts.length; i++) {
						const opt = allOpts[i];
						const isCursor = i === optionIndex;
						const isChecked = checked.has(i);
						const isCustom = i >= q.options.length;
						const hasNote = notes.has(opt.value);
						const box = isChecked ? "☑" : "☐";
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						const customInd = isCustom ? theme.fg("warning", " ✎") : "";
						const noteInd = hasNote ? theme.fg("warning", " ✎") : "";
						if (isCursor) cursorOffset = lineCount;
						if (isCursor) {
							add(prefix + theme.fg("accent", `${box} ${opt.label}`) + customInd + noteInd);
						} else if (isChecked) {
							add(prefix + theme.fg("success", box) + ` ${theme.fg("text", opt.label)}` + customInd + noteInd);
						} else {
							add(`  ${theme.fg("muted", box)} ${theme.fg("text", opt.label)}` + customInd + noteInd);
						}
						lineCount++;
						if (opt.description) {
							for (const dLine of wordWrap(opt.description, width - 6)) {
								add(`     ${theme.fg("muted", dLine)}`);
								lineCount++;
							}
						}
						if (hasNote) {
							const noteText = notes.get(opt.value)!;
							const maxLen = Math.max(8, width - 10);
							const preview = noteText.length > maxLen ? noteText.substring(0, maxLen - 3) + "..." : noteText;
							add(`     ${theme.fg("dim", `"${preview}"`)}`);
							lineCount++;
						}
					}

					if (q.allowOther) {
						const idx = allOpts.length;
						const isCursor = idx === optionIndex;
						if (isCursor) cursorOffset = lineCount;
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						if (isCursor && inputMode) {
							add(prefix + theme.fg("accent", `+ Type something. ✎`));
						} else if (isCursor) {
							add(prefix + theme.fg("accent", `+ Type something.`));
						} else {
							add(`  ${theme.fg("dim", "+ Type something.")}`);
						}
						lineCount++;
					}
					return cursorOffset;
				}

				function renderReviewOptions(q: Question, width: number, add: (s: string) => void, maxBodyRows: number): number {
					const notes = getNoteMap(q.id);

					// Dynamic left width: fit actual labels instead of fixed percentage
					const labelWidths = q.options.map((o, i) => {
						return 2 + `${i + 1}. `.length + o.label.length + 2; // "> " + "N. " + label + " ✎"
					});
					const maxLabelWidth = Math.max(...labelWidths, 15);
					const leftWidth = Math.min(maxLabelWidth + 2, Math.floor(width * 0.5));
					const dividerLen = 3;
					const rightWidth = width - leftWidth - dividerLen;

					if (rightWidth < 25) {
						return renderReviewStacked(q, width, add, maxBodyRows);
					}

					// Build left panel
					const leftLines: string[] = [];
					let cursorRow = 0;
					for (let i = 0; i < q.options.length; i++) {
						const opt = q.options[i];
						const isCursor = i === optionIndex;
						if (isCursor) cursorRow = leftLines.length;
						const hasNote = notes.has(opt.value);
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						const color = isCursor ? "accent" : "text";
						const noteInd = hasNote ? theme.fg("warning", " ✎") : "";
						leftLines.push(prefix + theme.fg(color as any, `${i + 1}. ${opt.label}`) + noteInd);
						if (hasNote) {
							const noteText = notes.get(opt.value)!;
							const maxPreviewLen = Math.max(8, leftWidth - 8);
							const preview = noteText.length > maxPreviewLen
								? noteText.substring(0, maxPreviewLen - 3) + "..."
								: noteText;
							leftLines.push(`     ${theme.fg("dim", `"${preview}"`)}`);
						}
					}

					// Build full right panel content
					const highlighted = q.options[optionIndex];
					const content = highlighted?.content || highlighted?.description || "(no preview available)";
					const rightTitle = theme.fg("accent", theme.bold(highlighted?.label || ""));
					const wrappedContent = wordWrap(content, rightWidth - 1);
					const rightAllLines: string[] = [rightTitle, theme.fg("dim", "─".repeat(rightWidth - 1)), ...wrappedContent];

					// Right panel viewport
					const visibleRows = Math.max(leftLines.length, maxBodyRows);

					if (rightAllLines.length <= visibleRows) {
						previewScroll = 0;
						previewMaxScroll = 0;
						const totalLines = Math.max(leftLines.length, rightAllLines.length);
						const divider = theme.fg("dim", " │ ");
						for (let row = 0; row < totalLines; row++) {
							const left = padRight(leftLines[row] || "", leftWidth);
							const right = truncateToWidth(rightAllLines[row] || "", rightWidth);
							add(`${left}${divider}${right}`);
						}
						return cursorRow;
					}

					// Scrolling needed
					const maxScroll = Math.max(0, rightAllLines.length - (visibleRows - 1));
					if (previewScroll > maxScroll) previewScroll = maxScroll;
					previewMaxScroll = maxScroll;

					const hasUpIndicator = previewScroll > 0;
					let contentHeight = visibleRows - (hasUpIndicator ? 1 : 0);
					const hasDownIndicator = (previewScroll + contentHeight) < rightAllLines.length;
					if (hasDownIndicator) contentHeight--;
					contentHeight = Math.max(1, contentHeight);

					const rightSlice = rightAllLines.slice(previewScroll, previewScroll + contentHeight);
					const rightVisible: string[] = [];
					if (hasUpIndicator) {
						const above = previewScroll;
						rightVisible.push(theme.fg("dim", `▲ ${above} more line${above !== 1 ? "s" : ""} (k)`));
					}
					rightVisible.push(...rightSlice);
					if (hasDownIndicator) {
						const below = rightAllLines.length - previewScroll - contentHeight;
						rightVisible.push(theme.fg("dim", `▼ ${below} more line${below !== 1 ? "s" : ""} (j)`));
					}

					const totalLines = Math.max(leftLines.length, rightVisible.length);
					const divider = theme.fg("dim", " │ ");
					for (let row = 0; row < totalLines; row++) {
						const left = padRight(leftLines[row] || "", leftWidth);
						const right = truncateToWidth(rightVisible[row] || "", rightWidth);
						add(`${left}${divider}${right}`);
					}
					return cursorRow;
				}

				function renderReviewStacked(q: Question, width: number, add: (s: string) => void, maxBodyRows: number): number {
					const notes = getNoteMap(q.id);
					let cursorOffset = 0;
					let lineCount = 0;

					for (let i = 0; i < q.options.length; i++) {
						const opt = q.options[i];
						const isCursor = i === optionIndex;
						if (isCursor) cursorOffset = lineCount;
						const hasNote = notes.has(opt.value);
						const prefix = isCursor ? theme.fg("accent", "> ") : "  ";
						const color = isCursor ? "accent" : "text";
						const noteInd = hasNote ? theme.fg("warning", " ✎") : "";
						add(prefix + theme.fg(color as any, `${i + 1}. ${opt.label}`) + noteInd);
						lineCount++;
					}

					const highlighted = q.options[optionIndex];
					const content = highlighted?.content || highlighted?.description || "";
					if (content) {
						add("");
						lineCount++;
						add(theme.fg("dim", "─── ") + theme.fg("accent", theme.bold(highlighted.label)) + theme.fg("dim", " ───"));
						lineCount++;

						const allPreviewLines = wordWrap(content, width - 2);
						const availableForPreview = Math.max(3, maxBodyRows - lineCount);

						if (allPreviewLines.length <= availableForPreview) {
							previewScroll = 0;
							previewMaxScroll = 0;
							for (const line of allPreviewLines) add(` ${line}`);
						} else {
							const maxScroll = Math.max(0, allPreviewLines.length - (availableForPreview - 1));
							if (previewScroll > maxScroll) previewScroll = maxScroll;
							previewMaxScroll = maxScroll;

							const hasUpIndicator = previewScroll > 0;
							let contentHeight = availableForPreview - (hasUpIndicator ? 1 : 0);
							const hasDownIndicator = (previewScroll + contentHeight) < allPreviewLines.length;
							if (hasDownIndicator) contentHeight--;
							contentHeight = Math.max(1, contentHeight);

							if (hasUpIndicator) {
								const above = previewScroll;
								add(theme.fg("dim", ` ▲ ${above} more line${above !== 1 ? "s" : ""} (k)`));
							}
							for (const line of allPreviewLines.slice(previewScroll, previewScroll + contentHeight)) {
								add(` ${line}`);
							}
							if (hasDownIndicator) {
								const below = allPreviewLines.length - previewScroll - contentHeight;
								add(theme.fg("dim", ` ▼ ${below} more line${below !== 1 ? "s" : ""} (j)`));
							}
						}
					}
					return cursorOffset;
				}

				// ─── Input ───
				function handleInput(data: string) {
					if (inputMode || noteEditMode || commentMode) {
						if (matchesKey(data, Key.escape)) {
							inputMode = false;
							inputQuestionId = null;
							noteEditMode = false;
							noteEditOptionValue = null;
							commentMode = false;
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

					if (isMulti) {
						if (matchesKey(data, Key.tab) || matchesKey(data, Key.right)) {
							currentTab = (currentTab + 1) % totalTabs;
							optionIndex = 0;
							previewScroll = 0;
							refresh();
							return;
						}
						if (matchesKey(data, Key.shift("tab")) || matchesKey(data, Key.left)) {
							currentTab = (currentTab - 1 + totalTabs) % totalTabs;
							optionIndex = 0;
							previewScroll = 0;
							refresh();
							return;
						}
					}

					if (currentTab === questions.length) {
						if (matchesKey(data, Key.enter) && allAnswered()) submit(false);
						else if (matchesKey(data, Key.escape)) submit(true);
						return;
					}

					if (!q) return;

					if (matchesKey(data, Key.up)) {
						optionIndex = Math.max(0, optionIndex - 1);
						previewScroll = 0;
						refresh();
						return;
					}
					if (matchesKey(data, Key.down)) {
						let maxIdx: number;
						if (q.select === "multiple") {
							const dynamic = getDynamic(q.id);
							const allCount = q.options.length + dynamic.length;
							maxIdx = q.allowOther ? allCount : allCount - 1;
						} else {
							maxIdx = opts.length - 1;
						}
						optionIndex = Math.min(maxIdx, optionIndex + 1);
						previewScroll = 0;
						refresh();
						return;
					}

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

					if (q.select === "multiple") {
						const checked = getChecked(q.id);
						const dynamic = getDynamic(q.id);
						const allCount = q.options.length + dynamic.length;
						const isOnTypeOption = q.allowOther && optionIndex === allCount;

						if (matchesKey(data, Key.space)) {
							if (isOnTypeOption) {
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
							if (checked.size === allCount) checked.clear();
							else for (let i = 0; i < Math.min(allCount, q.maxSelect); i++) checked.add(i);
							refresh();
							return;
						}

						if (matchesKey(data, Key.enter)) {
							if (canSubmitMulti(q)) { saveMultiAnswer(q); advanceAfterAnswer(); }
							return;
						}
					}

					if (q.select === "review") {
						if (data === "j") {
							previewScroll = Math.min(previewScroll + 3, previewMaxScroll);
							refresh();
							return;
						}
						if (data === "k") {
							previewScroll = Math.max(0, previewScroll - 3);
							refresh();
							return;
						}
						if (matchesKey(data, Key.enter)) {
							const opt = q.options[optionIndex];
							saveSingleAnswer(q, opt.value, opt.label, false, optionIndex + 1);
							advanceAfterAnswer();
							return;
						}
					}

					if (data === "n") {
						let optValue: string | null = null;
						if (q.select === "review") {
							optValue = q.options[optionIndex]?.value || null;
						} else if (q.select === "multiple") {
							const dynamic = getDynamic(q.id);
							const allOpts = [...q.options, ...dynamic];
							if (optionIndex < allOpts.length) optValue = allOpts[optionIndex].value;
						} else {
							const opt = opts[optionIndex];
							if (opt && !opt.isOther) optValue = opt.value;
						}
						if (optValue) {
							const notes = getNoteMap(q.id);
							noteEditMode = true;
							noteEditOptionValue = optValue;
							editor.setText(notes.get(optValue) || "");
							refresh();
						}
						return;
					}

					if (data === "c") {
						commentMode = true;
						editor.setText(questionComments.get(q!.id) || "");
						refresh();
						return;
					}

					if (matchesKey(data, Key.escape)) submit(true);
				}

				// ─── Render ───
				function render(width: number): string[] {
					if (cachedLines) return cachedLines;

					const lines: string[] = [];
					const q = currentQuestion();
					const opts = currentDisplayOptions();
					const add = (s: string) => lines.push(truncateToWidth(s, width));

					let bodyStart = 0;
					let bodyEnd = 0;
					let cursorLine = 0;

					// === HEADER ===
					add(theme.fg("accent", "─".repeat(width)));

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

					// === BODY ===
					if (commentMode) {
						bodyStart = lines.length;
						const q2 = currentQuestion()!;
						add(theme.fg("text", ` Comment on: `) + theme.fg("accent", theme.bold(truncateToWidth(q2.prompt, width - 14))));
						lines.push("");
						add(theme.fg("muted", " Your comment (empty to remove):"));
						cursorLine = lines.length;
						for (const line of editor.render(width - 2)) add(` ${line}`);
						lines.push("");
						add(theme.fg("dim", " Enter to save • Esc to discard"));
						bodyEnd = lines.length;
					} else if (noteEditMode && noteEditOptionValue) {
						bodyStart = lines.length;
						const q2 = currentQuestion();
						const optLabel = q2?.options.find((o) => o.value === noteEditOptionValue)?.label || noteEditOptionValue;
						add(theme.fg("text", ` Notes for: `) + theme.fg("accent", theme.bold(optLabel)));
						lines.push("");
						add(theme.fg("muted", " Your notes (empty to remove):"));
						cursorLine = lines.length;
						for (const line of editor.render(width - 2)) add(` ${line}`);
						lines.push("");
						add(theme.fg("dim", " Enter to save • Esc to discard"));
						bodyEnd = lines.length;
					} else if (currentTab === questions.length) {
						bodyStart = lines.length;
						cursorLine = lines.length;
						add(theme.fg("accent", theme.bold(" Ready to submit")));
						lines.push("");
						for (const question of questions) {
							const answer = answers.get(question.id);
							if (answer) {
								const prefix = answer.wasCustom ? "(wrote) " : "";
								let display: string;
								if (answer.selections) display = `${answer.selections.length} selected: ${answer.label}`;
								else display = `${prefix}${answer.label}`;
								add(`${theme.fg("muted", ` ${question.label}: `)}${theme.fg("text", display)}`);
								if (answer.optionNotes && answer.optionNotes.length > 0) {
									for (const note of answer.optionNotes) {
										const preview = note.text.length > 50 ? note.text.substring(0, 47) + "..." : note.text;
										add(`   ${theme.fg("warning", "✎ ")}${theme.fg("dim", note.label + ": ")}${theme.fg("muted", preview)}`);
									}
								}
								if (answer.comment) {
									const cPreview = answer.comment.length > 60 ? answer.comment.substring(0, 57) + "..." : answer.comment;
									add(`   ${theme.fg("warning", "✎ ")}${theme.fg("dim", "Comment: ")}${theme.fg("muted", cPreview)}`);
								}
							}
						}
						lines.push("");
						if (allAnswered()) {
							add(theme.fg("success", " Press Enter to submit"));
						} else {
							const missing = questions.filter((q) => !answers.has(q.id)).map((q) => q.label).join(", ");
							add(theme.fg("warning", ` Unanswered: ${missing}`));
						}
						bodyEnd = lines.length;
					} else if (q) {
						for (const pLine of wordWrap(q.prompt, width - 2)) {
							add(theme.fg("text", ` ${pLine}`));
						}
						if (q.select === "multiple" && (q.minSelect > 1 || q.maxSelect < q.options.length)) {
							const parts: string[] = [];
							if (q.minSelect > 1) parts.push(`min ${q.minSelect}`);
							if (q.maxSelect < q.options.length) parts.push(`max ${q.maxSelect}`);
							add(theme.fg("dim", `  (${parts.join(", ")})`));
						}
						if (questionComments.has(q.id)) {
							const comment = questionComments.get(q.id)!;
							const maxLen = Math.max(20, width - 12);
							const preview = comment.length > maxLen ? comment.substring(0, maxLen - 3) + "..." : comment;
							add(`  ${theme.fg("warning", "✎ ")}${theme.fg("dim", preview)}`);
						}
						lines.push("");

						bodyStart = lines.length;

						// Compute available body rows for review viewport
						const termHeight = process.stdout.rows || 24;
						const footerEstimate = 3;
						const availableBodyRows = Math.max(5, termHeight - 4 - lines.length - footerEstimate);

						let cursorOffset = 0;
						if (q.select === "review") {
							cursorOffset = renderReviewOptions(q, width, add, availableBodyRows);
						} else if (q.select === "multiple") {
							cursorOffset = renderMultiOptions(q, getNoteMap(q.id), add, width);
						} else {
							cursorOffset = renderSingleOptions(opts, getNoteMap(q.id), add, width);
						}
						cursorLine = bodyStart + cursorOffset;

						if (inputMode && (q.select === "single" || q.select === "multiple")) {
							lines.push("");
							add(theme.fg("muted", q.select === "multiple" ? " Add custom option:" : " Your answer:"));
							cursorLine = lines.length;
							for (const line of editor.render(width - 2)) add(` ${line}`);
						}

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
						bodyEnd = lines.length;
					}

					// === FOOTER ===
					lines.push("");
					if (inputMode) {
						add(theme.fg("dim", " Enter to submit • Esc to go back"));
					} else if (!noteEditMode && !commentMode && currentTab !== questions.length && q) {
						const nav = isMulti ? "Tab/←→ navigate • " : "";
						if (q.select === "review") {
							add(theme.fg("dim", ` ${nav}↑↓ browse • j/k scroll • n notes • c comment • Enter select • Esc cancel`));
						} else if (q.select === "multiple") {
							add(theme.fg("dim", ` ${nav}↑↓ move • Space toggle • a all • n notes • c comment • Enter confirm • Esc cancel`));
						} else {
							add(theme.fg("dim", ` ${nav}↑↓ navigate • n notes • c comment • Enter select • Esc cancel`));
						}
					}
					add(theme.fg("accent", "─".repeat(width)));

					// === VIEWPORT ===
					const termHeight = process.stdout.rows || 24;
					const maxLines = termHeight - 4;

					if (lines.length <= maxLines) {
						cachedLines = lines;
						return lines;
					}

					const headerLines = lines.slice(0, bodyStart);
					const bodyLines = lines.slice(bodyStart, bodyEnd);
					const footerLines = lines.slice(bodyEnd);
					const availableForBody = maxLines - headerLines.length - footerLines.length;

					if (availableForBody <= 3) {
						cachedLines = lines.slice(0, maxLines);
						return cachedLines;
					}

					const cursorInBody = Math.max(0, Math.min(cursorLine - bodyStart, bodyLines.length - 1));
					let viewStart = Math.max(0, cursorInBody - Math.floor(availableForBody / 2));
					if (viewStart + availableForBody > bodyLines.length) {
						viewStart = Math.max(0, bodyLines.length - availableForBody);
					}
					const viewEnd = Math.min(viewStart + availableForBody, bodyLines.length);
					const visibleBody = bodyLines.slice(viewStart, viewEnd);

					if (viewStart > 0) {
						const above = viewStart;
						visibleBody[0] = truncateToWidth(theme.fg("dim", `  ▲ ${above} more line${above !== 1 ? "s" : ""}`), width);
					}
					if (viewEnd < bodyLines.length) {
						const below = bodyLines.length - viewEnd;
						visibleBody[visibleBody.length - 1] = truncateToWidth(theme.fg("dim", `  ▼ ${below} more line${below !== 1 ? "s" : ""}`), width);
					}

					cachedLines = [...headerLines, ...visibleBody, ...footerLines];
					return cachedLines;
				}

				return {
					render,
					invalidate: () => { cachedLines = undefined; },
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
					lines.push(`${qLabel}: (custom) ${a.label}`);
				} else if (a.selections) {
					lines.push(`${qLabel}: ${a.selections.map((s) => `${s.index}. ${s.label}`).join(", ")}`);
				} else {
					lines.push(`${qLabel}: ${a.index}. ${a.label}`);
				}
				if (a.optionNotes) {
					for (const note of a.optionNotes) lines.push(`  "${note.label}": ${note.text}`);
				}
				if (a.comment) lines.push(`  Comment: ${a.comment}`);
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
			if (labels) text += theme.fg("dim", ` (${truncateToWidth(labels, 40)})`);
			return new Text(text, 0, 0);
		},

		renderResult(result, _options, theme) {
			const details = result.details as QuestionnaireResult | undefined;
			if (!details) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "", 0, 0);
			}
			if (details.cancelled) return new Text(theme.fg("warning", "Cancelled"), 0, 0);
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
				if (a.optionNotes && a.optionNotes.length > 0) {
					for (const note of a.optionNotes) {
						answerLines.push(`  ${theme.fg("warning", "✎ ")}${theme.fg("dim", note.label + ": ")}${note.text}`);
					}
				}
				if (a.comment) {
					answerLines.push(`  ${theme.fg("warning", "✎ ")}${theme.fg("dim", "Comment: ")}${a.comment}`);
				}
				return answerLines.join("\n");
			});
			return new Text(lines.join("\n"), 0, 0);
		},
	});
}
