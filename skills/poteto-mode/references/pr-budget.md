### PR budget

One PR fits one reviewer sitting. The budget is 20 files and 800 added lines, measured by `scripts/check-pr-size.mjs` against the PR's base. Deleted lines are free. Binary files, lockfiles, snapshots, minified files, `vendor/`, and anything the repo marks `linguist-generated` or `linguist-vendored` in `.gitattributes` are free. A generated file the checker keeps counting is a missing `.gitattributes` line, not a reason to override. `PSTACK_PR_MAX_FILES` and `PSTACK_PR_MAX_LINES` override the numbers; set them in the `env` block of `~/.claude/settings.json` for every repo, or of the repo's `.claude/settings.json` for one.

**Where it bites.** Three points, earliest first. Only the first is cheap.

1. Scoping. A delegate's brief, a plan's PR section, and a figure-it-out unit are each one PR. A brief that lists more files than the budget is two briefs, split before anyone writes code. `scripts/check-plan.mjs` fails a plan whose PR section lists more files than the budget.
2. Committing. The plugin hook prints the running measure after every `git commit`, files and added lines against the base. Watch it climb and split while the seams are fresh.
3. Opening. The same hook denies `gh pr create` and `gt submit` when the diff is over budget. It reads `--base` from the command when present, else `gt parent`, else `origin/HEAD`. A stack submit is measured at its top branch only; the per-commit measure covers the branches below as they were built. Reaching the deny means scoping was skipped.

**How to split.** Cut along the seams the **sequence-verifiable-units** principle skill names, so each PR stands alone and the stack reads as an argument.

- Subtraction first. Deletions, renames, and moves go in their own PR at the bottom of the stack. They review in minutes and shrink everything above.
- Scaffold before feature. The types, the data shape, and its registry or state machine land with no callers. Then one PR per caller group or feature slice.
- One data shape per PR. A PR that introduces two shapes is two PRs.
- Tests ride with the code they prove. No tests-only PR at the top of a stack.
- A mechanical sweep (one rename across forty files) ships as one PR only when a committed lever produced it and the reviewer can rerun the lever (the **build-the-lever** principle skill). Name the lever in the PR body.

Stack the pieces with Graphite (`gt`) per **Opening a PR**. Bottom-up order is the reading order.

**Override.** A diff that cannot split, such as a lever-produced sweep or a vendored drop, passes the gate when the create command starts with `PSTACK_PR_SIZE_OK=1`. State the reason in the PR's `## Tradeoffs` section. An override with no reason in the body is a defect a reviewer may bounce.
