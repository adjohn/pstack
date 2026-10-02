import { describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { appendFileSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { DEFAULTS, git, main, measure, resolveBase } from "./check-pr-size.mjs";
import { commit, commitOnMain, lines, repo } from "./pr-size-fixture.ts";

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

	test("runs as main through a path containing '#' and a space", () => {
		const cwd = repo();
		const dir = mkdtempSync(path.join(tmpdir(), "pr-size-"));
		const special = path.join(dir, "dir #1 x");
		mkdirSync(special);
		const dest = path.join(special, "check-pr-size.mjs");
		copyFileSync(path.join(import.meta.dir, "check-pr-size.mjs"), dest);
		const out = execFileSync("node", [dest, "--base", "main"], { cwd, encoding: "utf8" });
		expect(out).toContain("within budget");
	});

	test("runs as main through a symlink to the real file", () => {
		const cwd = repo();
		const dir = mkdtempSync(path.join(tmpdir(), "pr-size-link-"));
		const link = path.join(dir, "check-pr-size-link.mjs");
		symlinkSync(path.join(import.meta.dir, "check-pr-size.mjs"), link);
		const out = execFileSync("node", [link, "--base", "main"], { cwd, encoding: "utf8" });
		expect(out).toContain("within budget");
	});

	test("a rename out of vendor/ is measured under its new path", () => {
		const cwd = repo();
		commitOnMain(cwd, { "vendor/old.js": lines(10) });
		mkdirSync(path.join(cwd, "src"), { recursive: true });
		git(cwd, ["mv", "vendor/old.js", "src/new.js"]);
		appendFileSync(path.join(cwd, "src/new.js"), "line 10\n");
		git(cwd, ["add", "-A"]);
		git(cwd, ["commit", "-qm", "rename out of vendor"]);
		const m = measure(cwd, "main");
		expect(m.files).toBe(1);
		expect(m.lines).toBe(1);
		expect(m.free).toBe(0);
	});

	test("a renamed generated file keeps its exemption", () => {
		const cwd = repo();
		commitOnMain(cwd, { ".gitattributes": "gen/** linguist-generated\n", "gen/a.ts": lines(5) });
		git(cwd, ["mv", "gen/a.ts", "gen/b.ts"]);
		appendFileSync(path.join(cwd, "gen/b.ts"), "line 5\n");
		git(cwd, ["add", "-A"]);
		git(cwd, ["commit", "-qm", "rename generated file"]);
		const m = measure(cwd, "main");
		expect(m.files).toBe(0);
		expect(m.free).toBe(1);
	});

	test("check-attr parses a path containing ': '", () => {
		const cwd = repo();
		commitOnMain(cwd, { ".gitattributes": "notes/** linguist-generated\n" });
		commit(cwd, { "notes/draft: v2.md": lines(5) });
		const m = measure(cwd, "main");
		expect(m.files).toBe(0);
		expect(m.free).toBe(1);
	});

	test("reference and guide state the script's defaults", () => {
		const phrase = `${DEFAULTS.maxFiles} files and ${DEFAULTS.maxLines} added lines`;
		for (const rel of ["../references/pr-budget.md", "../../../docs/guide/06-verify-and-ship.md"]) {
			expect(readFileSync(path.join(import.meta.dir, rel), "utf8")).toContain(phrase);
		}
	});
});
