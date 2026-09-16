#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import process from "node:process";

export const DEFAULTS = { maxFiles: 20, maxLines: 800 };

const FREE = [
	/(^|\/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lock|bun\.lockb|Cargo\.lock|Gemfile\.lock|poetry\.lock|uv\.lock|go\.sum|composer\.lock|Podfile\.lock|Package\.resolved|flake\.lock)$/,
	/(^|\/)__snapshots__\//,
	/\.snap$/,
	/\.min\.(js|css)$/,
	/\.map$/,
	/(^|\/)(vendor|node_modules)\//,
];

const TRUNKS = ["origin/main", "origin/master", "main", "master"];

export const git = (cwd, args, input) =>
	execFileSync("git", args, { cwd, input, encoding: "utf8", stdio: [input === undefined ? "ignore" : "pipe", "pipe", "pipe"] }).trim();

const tryRun = (fn) => {
	try {
		return fn();
	} catch {
		return null;
	}
};

export function resolveBase(cwd, explicit) {
	if (explicit) return explicit;
	const parent = tryRun(() => execFileSync("gt", ["parent"], { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim());
	if (parent) return parent;
	const head = tryRun(() => git(cwd, ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"]));
	if (head) return head;
	return TRUNKS.find((ref) => tryRun(() => git(cwd, ["rev-parse", "--verify", "--quiet", `${ref}^{commit}`]))) ?? null;
}

function attributed(cwd, paths) {
	if (paths.length === 0) return new Set();
	const out = git(cwd, ["check-attr", "--stdin", "linguist-generated", "linguist-vendored"], paths.join("\n") + "\n");
	const marked = new Set();
	for (const line of out.split("\n")) {
		const [path, , value] = line.split(": ");
		if (value === "set" || value === "true") marked.add(path);
	}
	return marked;
}

export function measure(cwd, base) {
	const mergeBase = git(cwd, ["merge-base", base, "HEAD"]);
	const rows = git(cwd, ["diff", "--numstat", mergeBase, "HEAD"])
		.split("\n")
		.filter(Boolean)
		.map((line) => {
			const [added, deleted, path] = line.split("\t");
			return { path, added: added === "-" ? 0 : Number(added), deleted: deleted === "-" ? 0 : Number(deleted), binary: added === "-" };
		});
	const marked = attributed(cwd, rows.map((r) => r.path));
	const counted = rows.filter((r) => !r.binary && !marked.has(r.path) && !FREE.some((re) => re.test(r.path)));
	return {
		base,
		mergeBase,
		files: counted.length,
		lines: counted.reduce((sum, r) => sum + r.added, 0),
		free: rows.length - counted.length,
		largest: [...counted].sort((a, b) => b.added - a.added).slice(0, 5),
	};
}

export function verdict(m, budget) {
	const over = [];
	if (m.files > budget.maxFiles) over.push(`${m.files} files, budget ${budget.maxFiles}`);
	if (m.lines > budget.maxLines) over.push(`${m.lines} added lines, budget ${budget.maxLines}`);
	return over;
}

export const summary = (m, budget) =>
	`base ${m.base} (${m.mergeBase.slice(0, 8)})  files ${m.files}/${budget.maxFiles}  added lines ${m.lines}/${budget.maxLines}  free files ${m.free}`;

export function report(m, budget) {
	const over = verdict(m, budget);
	const out = [summary(m, budget), ...m.largest.map((r) => `  +${r.added} -${r.deleted}  ${r.path}`)];
	if (over.length) {
		out.push(`OVER BUDGET: ${over.join("; ")}.`);
		out.push("Split into a stack before opening. See skills/poteto-mode/references/pr-budget.md.");
	} else {
		out.push("within budget");
	}
	return out.join("\n");
}

export function budgetFromEnv(env = process.env) {
	const num = (v, d) => (v && Number.isFinite(Number(v)) ? Number(v) : d);
	return { maxFiles: num(env.PSTACK_PR_MAX_FILES, DEFAULTS.maxFiles), maxLines: num(env.PSTACK_PR_MAX_LINES, DEFAULTS.maxLines) };
}

export function main(argv, cwd = process.cwd(), env = process.env) {
	const budget = budgetFromEnv(env);
	let base;
	if (argv.length === 0) base = undefined;
	else if (argv.length === 2 && argv[0] === "--base") base = argv[1];
	else {
		console.error("Usage: node check-pr-size.mjs [--base <ref>]");
		return 2;
	}
	const resolved = resolveBase(cwd, base);
	if (!resolved) {
		console.error("check-pr-size: no base found. Pass --base <ref> or fetch origin/main.");
		return 2;
	}
	const m = measure(cwd, resolved);
	const over = verdict(m, budget);
	(over.length ? console.error : console.log)(report(m, budget));
	return over.length ? 1 : 0;
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
	process.exit(main(process.argv.slice(2)));
}
