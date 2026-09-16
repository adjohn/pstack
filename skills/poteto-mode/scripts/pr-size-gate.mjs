#!/usr/bin/env node
import process from "node:process";
import { budgetFromEnv, measure, report, resolveBase, summary, verdict } from "./check-pr-size.mjs";

const ENV_ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;
const GT_COMMIT_VERBS = new Set(["create", "modify", "absorb", "c", "m"]);

export function shellCommands(command) {
	const commands = [];
	let tokens = [];
	let cur = "";
	let hasCur = false;
	const endToken = () => {
		if (hasCur) tokens.push(cur);
		[cur, hasCur] = ["", false];
	};
	const endCommand = () => {
		endToken();
		if (tokens.length) commands.push(tokens);
		tokens = [];
	};
	for (let i = 0; i < command.length; i++) {
		const c = command[i];
		if (c === '"' || c === "'") {
			const j = command.indexOf(c, i + 1);
			cur += command.slice(i + 1, j === -1 ? command.length : j);
			hasCur = true;
			i = j === -1 ? command.length : j;
		} else if ((c === "&" && command[i + 1] === "&") || (c === "|" && command[i + 1] === "|")) {
			endCommand();
			i++;
		} else if (c === "|" || c === ";") endCommand();
		else if (c === " " || c === "\t" || c === "\n" || c === "\r") endToken();
		else [cur, hasCur] = [cur + c, true];
	}
	endCommand();
	let override = false;
	const result = commands.map((toks) => {
		while (toks.length && ENV_ASSIGNMENT.test(toks[0])) if (toks.shift() === "PSTACK_PR_SIZE_OK=1") override = true;
		return toks;
	});
	result.override = override;
	return result;
}

export function opensPr(cmd) {
	if (cmd[0] === "gh" && cmd[1] === "pr" && cmd[2] === "create") return true;
	return cmd[0] === "gt" && (cmd[1] === "submit" || cmd[1] === "ss");
}

export function commits(cmd) {
	if (cmd[0] === "gt") return GT_COMMIT_VERBS.has(cmd[1]);
	if (cmd[0] !== "git") return false;
	let i = 1;
	while (i < cmd.length && cmd[i].startsWith("-")) i += cmd[i] === "-C" || cmd[i] === "-c" ? 2 : 1;
	return cmd[i] === "commit";
}

export function baseOf(cmd) {
	for (const t of cmd) {
		if (t.startsWith("--base=")) return t.slice("--base=".length);
	}
	const i = cmd.findIndex((t) => t === "--base" || t === "-B");
	return i === -1 ? undefined : cmd[i + 1];
}

function firstStderrLine(err) {
	const text = (err?.stderr || err?.message || "").toString();
	return text.split("\n").find((line) => line.trim().length > 0) ?? "unknown git error";
}

export function check(cwd, base) {
	const resolved = resolveBase(cwd, base);
	if (!resolved) return { kind: "no-base" };
	try {
		const m = measure(cwd, resolved);
		const budget = budgetFromEnv();
		return { kind: "measured", over: verdict(m, budget).length > 0, summary: summary(m, budget), report: report(m, budget) };
	} catch (err) {
		return { kind: "unmeasurable", reason: `base "${resolved}" did not resolve: ${firstStderrLine(err)}` };
	}
}

export function decide(input, run = check) {
	const raw = input?.tool_input?.command;
	if (typeof raw !== "string") return null;
	const cwd = input.cwd || process.cwd();
	const commands = shellCommands(raw);
	if (input.hook_event_name === "PostToolUse") {
		if (!commands.some(commits)) return null;
		const result = run(cwd);
		if (!result || result.kind !== "measured") return null;
		return { hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: `pstack PR budget: ${result.summary}` } };
	}
	if (input.hook_event_name !== "PreToolUse" || commands.override) return null;
	const opening = commands.find(opensPr);
	if (!opening) return null;
	const base = baseOf(opening);
	const result = run(cwd, base);
	if (!result || result.kind === "no-base") return null;
	if (result.kind === "unmeasurable") {
		return {
			hookSpecificOutput: {
				hookEventName: "PreToolUse",
				permissionDecision: "deny",
				permissionDecisionReason: [
					`pstack PR budget: cannot measure this PR against base "${base ?? "(auto-resolved)"}".`,
					result.reason,
					"Pass a correct --base or prefix the command with PSTACK_PR_SIZE_OK=1.",
				].join("\n"),
			},
		};
	}
	if (!result.over) return null;
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
