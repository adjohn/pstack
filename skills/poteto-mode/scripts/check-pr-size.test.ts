import { describe, expect, test } from "bun:test";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { DEFAULTS, git, main, measure, resolveBase } from "./check-pr-size.mjs";
import { commit, lines, repo } from "./pr-size-fixture.ts";

describe("check-pr-size", () => {
	test("counts added lines and files against main, deletions free", () => {
		const cwd = repo();
		commit(cwd, { "a.txt": "", "b.txt": lines(3), "c.txt": lines(2) });
		const m = measure(cwd, "main");
		expect(m.files).toBe(3);
		expect(m.lines).toBe(5);
	});

	test("lockfiles, snapshots, vendored, attributed, and binary files are free", () => {
		const cwd = repo();
		commit(cwd, {
			".gitattributes": "gen/** linguist-generated\nthird_party/** linguist-vendored=true\n",
			"bun.lock": lines(500),
			"src/__snapshots__/x.snap": lines(50),
			"gen/api.ts": lines(50),
			"third_party/lib.js": lines(50),
			"vendor/lib.js": lines(50),
			"src/real.ts": lines(2),
		});
		writeFileSync(path.join(cwd, "pic.png"), Buffer.from([0x89, 0x50, 0x4e, 0x47, 0, 1, 2, 3]));
		git(cwd, ["add", "."]);
		git(cwd, ["commit", "-qm", "bin"]);
		const m = measure(cwd, "main");
		expect(m.files).toBe(2);
		expect(m.lines).toBe(4);
		expect(m.free).toBe(6);
	});

	test("exit 1 over the line budget, 0 within the env override", () => {
		const cwd = repo();
		commit(cwd, { "big.ts": lines(DEFAULTS.maxLines + 1) });
		expect(main(["--base", "main"], cwd)).toBe(1);
		expect(main(["--base", "main"], cwd, { PSTACK_PR_MAX_LINES: "1000" })).toBe(0);
	});

	test("exit 1 over the file budget", () => {
		const cwd = repo();
		const files: Record<string, string> = {};
		for (let i = 0; i <= DEFAULTS.maxFiles; i++) files[`f${i}.ts`] = "x\n";
		commit(cwd, files);
		expect(main(["--base", "main"], cwd)).toBe(1);
		expect(main(["--base", "main"], cwd, { PSTACK_PR_MAX_FILES: "50" })).toBe(0);
	});

	test("base resolves to origin/HEAD, then a local trunk", () => {
		const cwd = repo();
		expect(resolveBase(cwd)).toBe("main");
		git(cwd, ["remote", "add", "origin", cwd]);
		git(cwd, ["fetch", "-q", "origin"]);
		git(cwd, ["symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/feature"]);
		expect(resolveBase(cwd)).toBe("origin/feature");
		expect(resolveBase(cwd, "explicit")).toBe("explicit");
	});

	test("reference and guide state the script's defaults", () => {
		const phrase = `${DEFAULTS.maxFiles} files and ${DEFAULTS.maxLines} added lines`;
		for (const rel of ["../references/pr-budget.md", "../../../docs/guide/06-verify-and-ship.md"]) {
			expect(readFileSync(path.join(import.meta.dir, rel), "utf8")).toContain(phrase);
		}
	});
});
