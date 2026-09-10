#!/usr/bin/env node
import process from "node:process";
import { budgetFromEnv, measure, report, resolveBase, summary, verdict } from "./check-pr-size.mjs";

const OPENS_PR = /\bgh[ \t\n\r]+pr[ \t\n\r]+create\b|\bgt[ \t\n\r]+(submit|ss)\b/;
const COMMITS = /\bgit[ \t\n\r]+commit\b/;
const OVERRIDE = /\bPSTACK_PR_SIZE_OK=1\b/;
const BASE_FLAG = /(?:--base|-B)[= ]+(\S+)/;

export function check(cwd, base) {
	const resolved = resolveBase(cwd, base);
	if (!resolved) return null;
	try {
		const m = measure(cwd, resolved);
		const budget = budgetFromEnv();
		return { over: verdict(m, budget).length > 0, summary: summary(m, budget), report: report(m, budget) };
	} catch {
		return null;
	}
}

export function decide(input, run = check) {
	const command = input?.tool_input?.command;
	if (typeof command !== "string") return null;
	const cwd = input.cwd || process.cwd();
	if (input.hook_event_name === "PostToolUse") {
		if (!COMMITS.test(command)) return null;
		const result = run(cwd);
		if (!result) return null;
		return { hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: `pstack PR budget: ${result.summary}` } };
	}
	if (input.hook_event_name !== "PreToolUse" || !OPENS_PR.test(command) || OVERRIDE.test(command)) return null;
	const base = command.match(BASE_FLAG)?.[1]?.replace(/^["']|["']$/g, "");
	const result = run(cwd, base);
	if (!result || !result.over) return null;
	return {
		hookSpecificOutput: {
			hookEventName: "PreToolUse",
			permissionDecision: "deny",
			permissionDecisionReason: [
				"pstack PR budget: this diff is over budget.",
				result.report,
				"Split it into a Graphite stack per skills/poteto-mode/references/pr-budget.md, then reopen.",
				"A diff that cannot split (generated files, a lever-produced sweep) may prefix the command with PSTACK_PR_SIZE_OK=1 and must name the reason in the PR's Tradeoffs section.",
			].join("\n"),
		},
	};
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
	let raw = "";
	process.stdin.setEncoding("utf8");
	process.stdin.on("data", (chunk) => (raw += chunk));
	process.stdin.on("end", () => {
		let input = null;
		try {
			input = JSON.parse(raw);
		} catch {
			process.exit(0);
		}
		const out = decide(input);
		if (out) process.stdout.write(JSON.stringify(out));
		process.exit(0);
	});
}
