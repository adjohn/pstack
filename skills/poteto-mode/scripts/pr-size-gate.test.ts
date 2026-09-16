import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { DEFAULTS } from "./check-pr-size.mjs";
import { baseOf, decide, shellCommands } from "./pr-size-gate.mjs";
import { commit, lines, repo } from "./pr-size-fixture.ts";

const over = () => ({ kind: "measured", over: true, summary: "files 12/10", report: "OVER BUDGET" });
const within = () => ({ kind: "measured", over: false, summary: "files 2/10", report: "within budget" });
const pre = (command: string) => ({ cwd: "/repo", hook_event_name: "PreToolUse", tool_input: { command } });
const post = (command: string) => ({ cwd: "/repo", hook_event_name: "PostToolUse", tool_input: { command } });
const gate = path.join(import.meta.dir, "pr-size-gate.sh");
const runGate = (input: object) => execFileSync("sh", [gate], { input: JSON.stringify(input), encoding: "utf8" });

describe("pr-size-gate", () => {
	test("ignores commands that neither commit nor open a PR", () => {
		let calls = 0;
		expect(decide(pre("git push && gh pr view 12"), () => (calls++, over()))).toBeNull();
		expect(decide(post("git push"), () => (calls++, over()))).toBeNull();
		expect(calls).toBe(0);
	});

	test("denies gh pr create and gt submit when over budget, across spaces, tabs, and newlines", () => {
		for (const cmd of ["gh pr create --title x", "gt submit --stack", "gt ss", "gh\tpr\tcreate", "gh\npr\ncreate --title x", "gt\tsubmit"]) {
			const out = decide(pre(cmd), over);
			expect(out?.hookSpecificOutput.permissionDecision).toBe("deny");
			expect(out?.hookSpecificOutput.permissionDecisionReason).toContain("OVER BUDGET");
		}
	});

	test("allows within budget, with the override prefix, and when nothing can be measured", () => {
		expect(decide(pre("gh pr create"), within)).toBeNull();
		expect(decide(pre("PSTACK_PR_SIZE_OK=1 gh pr create"), over)).toBeNull();
		expect(decide(pre("gh pr create"), () => null)).toBeNull();
	});

	test("never denies outside PreToolUse", () => {
		expect(decide(post("gh pr create"), over)).toBeNull();
		expect(decide({ cwd: "/repo", tool_input: { command: "gh pr create" } }, over)).toBeNull();
	});

	test("passes --base from the command to the check", () => {
		let seen: string | undefined;
		decide(pre("gh pr create --base feature-a --title x"), (_cwd, base) => ((seen = base), within()));
		expect(seen).toBe("feature-a");
		decide(pre("gh pr create -B 'stack/2'"), (_cwd, base) => ((seen = base), within()));
		expect(seen).toBe("stack/2");
	});

	test("reports the running measure after a commit", () => {
		for (const cmd of ["git commit -m x", "git\tcommit -m x"]) {
			const out = decide(post(cmd), over);
			expect(out?.hookSpecificOutput.hookEventName).toBe("PostToolUse");
			expect(out?.hookSpecificOutput.additionalContext).toContain("files 12/10");
		}
	});

	test("shell gate denies an over-budget open, reports after commit, and stays silent otherwise", () => {
		const cwd = repo();
		commit(cwd, { "big.ts": lines(DEFAULTS.maxLines + 1) });
		for (const command of ["gh pr create --base main", "gh\tpr\ncreate --base main"]) {
			const denied = runGate({ cwd, hook_event_name: "PreToolUse", tool_input: { command } });
			expect(JSON.parse(denied).hookSpecificOutput.permissionDecision).toBe("deny");
		}
		for (const command of ["git commit -m x", "git\tcommit -m x"]) {
			const measured = runGate({ cwd, hook_event_name: "PostToolUse", tool_input: { command } });
			expect(JSON.parse(measured).hookSpecificOutput.additionalContext).toContain(`added lines ${DEFAULTS.maxLines + 1}/${DEFAULTS.maxLines}`);
		}
		expect(runGate({ cwd, hook_event_name: "PreToolUse", tool_input: { command: "ls" } })).toBe("");
		expect(runGate({ cwd, hook_event_name: "PostToolUse", tool_input: { command: "gh pr create --base main" } })).toBe("");
	});

	test("shellCommands tokenizes quotes and separators, and strips leading env assignments", () => {
		const commands = shellCommands(`FOO=1 git add . && gh pr create --title "a && b" -B 'stack/2'`);
		expect(commands).toEqual([
			["git", "add", "."],
			["gh", "pr", "create", "--title", "a && b", "-B", "stack/2"],
		]);
		expect(baseOf(commands[1])).toBe("stack/2");
	});

	test("resolves --base from tokens, not from a substring inside a quoted title", () => {
		let seen: string | undefined;
		decide(pre('gh pr create --title "notes -B nothing" --base main'), (_cwd, base) => ((seen = base), within()));
		expect(seen).toBe("main");
	});

	test("denies and names the attempted base when it cannot be measured", () => {
		const out = decide(pre("gh pr create --base mian"), () => ({ kind: "unmeasurable", reason: "bad base" }));
		expect(out?.hookSpecificOutput.permissionDecision).toBe("deny");
		expect(out?.hookSpecificOutput.permissionDecisionReason).toContain("mian");
	});

	test("allows when no base can be resolved at all", () => {
		expect(decide(pre("gh pr create"), () => ({ kind: "no-base" }))).toBeNull();
	});

	test("recognizes gt and git commit variants for the running count, not push or submit", () => {
		const commitCmds = [
			"gt create -am x",
			"gt modify -a",
			"gt absorb",
			"git -C /tmp commit -m x",
			"git -c user.name=x commit -m x",
			"git --no-verify commit -m x",
			"git add . && git commit -m x",
		];
		for (const cmd of commitCmds) {
			const out = decide(post(cmd), over);
			expect(out?.hookSpecificOutput.hookEventName).toBe("PostToolUse");
		}
		expect(decide(post("git push"), over)).toBeNull();
		expect(decide(post("gt submit"), over)).toBeNull();
	});

	test("shell gate denies a PreToolUse open when node is missing from PATH, unless overridden", () => {
		const bins = execFileSync("sh", ["-c", "command -v sh cat grep printf dirname"], { encoding: "utf8" }).trim().split("\n");
		const dir = mkdtempSync(path.join(tmpdir(), "pr-size-nopath-"));
		for (const bin of bins) symlinkSync(bin, path.join(dir, path.basename(bin)));
		const runWithout = (input: object) => execFileSync("sh", [gate], { input: JSON.stringify(input), encoding: "utf8", env: { PATH: dir } });
		const denied = runWithout({ cwd: "/repo", hook_event_name: "PreToolUse", tool_input: { command: "gh pr create --base main" } });
		const parsed = JSON.parse(denied);
		expect(parsed.hookSpecificOutput.permissionDecision).toBe("deny");
		expect(parsed.hookSpecificOutput.permissionDecisionReason).toContain("node");
		expect(runWithout({ cwd: "/repo", hook_event_name: "PreToolUse", tool_input: { command: "PSTACK_PR_SIZE_OK=1 gh pr create --base main" } })).toBe("");
		expect(runWithout({ cwd: "/repo", hook_event_name: "PostToolUse", tool_input: { command: "git commit -m x" } })).toBe("");
	});
});
