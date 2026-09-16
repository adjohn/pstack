import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { git } from "./check-pr-size.mjs";

export function repo() {
	const cwd = mkdtempSync(path.join(tmpdir(), "pr-size-"));
	git(cwd, ["init", "-q", "-b", "main"]);
	git(cwd, ["config", "user.email", "t@t"]);
	git(cwd, ["config", "user.name", "t"]);
	writeFileSync(path.join(cwd, "a.txt"), "base\n");
	git(cwd, ["add", "."]);
	git(cwd, ["commit", "-qm", "base"]);
	git(cwd, ["checkout", "-qb", "feature"]);
	return cwd;
}

export function commit(cwd: string, files: Record<string, string>) {
	for (const [name, body] of Object.entries(files)) {
		mkdirSync(path.dirname(path.join(cwd, name)), { recursive: true });
		writeFileSync(path.join(cwd, name), body);
	}
	git(cwd, ["add", "."]);
	git(cwd, ["commit", "-qm", "change"]);
}

export const lines = (n: number) => Array.from({ length: n }, (_, i) => `line ${i}`).join("\n") + "\n";
