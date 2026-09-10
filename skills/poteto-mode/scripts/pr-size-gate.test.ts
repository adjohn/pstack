import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { DEFAULTS } from "./check-pr-size.mjs";
import { decide } from "./pr-size-gate.mjs";
import { commit, lines, repo } from "./pr-size-fixture.ts";

const over = () => ({ over: true, summary: "files 12/10", report: "OVER BUDGET" });
const within = () => ({ over: false, summary: "files 2/10", report: "within budget" });
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
});
