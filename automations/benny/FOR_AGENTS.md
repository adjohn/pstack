# benny automation intent

## what i want to automate

i want two claude code scheduled agents that work together in one slack issue channel. each runs on a cron cadence and scans the channel for new reports. when i need a true post-time trigger instead of a polling cadence, the alternative is a webhook-triggered ci job i build myself outside this pack (a slack events bridge firing a github actions workflow that runs headless claude code, `claude -p`).

### automation 1: triage issue reports

- trigger: when someone posts a new top-level report in my configured source slack channel, i want the next scheduled run to pick up that report and keep its original thread coordinates. a report that already carries a benny verdict reply must not be triaged again.
- behavior: i want it to read the thread and attachments, classify the report as a bug or performance issue, feature request, question or feedback, or reroute, and trace the likely owning layer before routing.
- tracker: i want it to search my configured tracker for duplicates, update a confident duplicate, and create a ticket only for a clear net-new bug.
- tools: i want slack thread read and reply access, my configured tracker integration, and my optional routing map.
- outcome: i want exactly one reply in the source thread with a short verdict and `[benny:bug]`, `[benny:performance]`, or `[benny:other]`. a bug or performance marker may include the tracker url.
- boundary: i never want this automation to post a root message in the source channel.

### automation 2: reproduce and fix confirmed bugs

- trigger: i want this automation to pick up the same new top-level reports on its own scheduled runs, or another supported trigger chosen during setup, then wait for the trusted triage marker in the original thread.
- gates: i want it to stop when someone clearly owns the fix. if an existing pull request or merged commit may fix the report, i want verification instead of a competing change.
- behavior: i want it to use my configured control adapter and feature map, reproduce the exact symptom twice through the real ui, and capture screenshots, video, and a read-only state cross-check.
- fix: i want it to verify existing pull requests without authoring over them. after a confirmed repro, it may attempt one bounded root-cause fix, use tdd when the test is cheap, smoke the blast radius, and open a draft pull request only when before-and-after proof passes.
- tools: i want slack thread read and reply access, repository and history access, draft pull request creation, my configured tracker, and my control adapter.
- outcome: i want evidence and a verified result in the source or optional operations threads, plus an optional draft pull request. updates should be concise.
- boundary: i never want this automation to post a root message in the source channel.

### shared rules

- i want the source channel and root thread coordinates to stay immutable for the whole run.
- i treat utility and debug bots as evidence, not delegation or fix ownership.
- i allow subagents to help, but they cannot post to slack or receive slack credentials.
- i want this entire pack committed under `.claude/skills/` in the target repository. its `SKILL.md` files are direct automation instructions committed as project skills, not registered plugin skills.
- i want pstack enabled through the target repository's committed `.claude/settings.json` only for shared dependencies such as `how`, `why`, `tdd`, `unslop`, and the required principle skills.
- i want each live automation prompt to read its committed operational file directly. i do not want plugin cache paths, copied excerpts, or slash-skill discovery.
- i keep user-owned configuration, feature maps, routing maps, and secrets outside the copied benny skills, for example in `.claude/benny/`, so pack refreshes cannot overwrite them.
- i want both automations to fail closed when channel coordinates, tracker access, the control adapter, or the feature map are missing or uncertain.
- i want draft pull requests only. do not merge or deploy.

### my configuration

- source slack channel: `<channel>`
- optional operations channel: `<channel or none>`
- repository and default branch: `<repo>`, `<branch>`
- tracker: `<type, team, project, labels, intake status>`
- routing map: `<path or none>`
- triage identity: `<slack identity>`
- control skill: `<configured skill or adapter>`
- feature map: `<committed same-repo path outside the copied pack, or behavior to paraphrase>`
- models: `<triage, reproduce, code, media review>`
- schedule: `<cron cadence, or github actions trigger>`
- status emoji strings: `<seen, reproducing, reproduced, blocked, fixing, failed, pull request opened>`
- budgets: `<polling, verdict wait, follow-up, repro, rejection, fix>`
- optional bot token capability: `<none, file download, or editable operations status>`

start from [`configuration.example.yaml`](./templates/configuration.example.yaml) and [`feature-map.example.md`](./skills/reproduce-and-fix-issues/references/feature-map.example.md). copy and fill them outside this pack, for example under `.claude/benny/`. keep secret values in a secret manager or environment.

## for the agent

the human enters setup by pointing claude code at this file. do not look for or invoke a discovered benny slash skill.

1. ask which repository will run the automations.
2. treat the directory containing this `FOR_AGENTS.md` as the source pack.
3. merge the entire source pack into `<target-repository>/.claude/skills/`: each directory under the pack's `skills/` goes to `.claude/skills/<name>/`, and the pack's `FOR_AGENTS.md`, `README.md`, and `templates/` go into `.claude/skills/setup-benny/`.
4. preserve every destination-only file. never delete unrelated files or overwrite user-owned configuration, feature maps, or routing maps.
5. when an existing destination file at a source-managed path differs, review the diff and merge without discarding local edits. if ownership is ambiguous, stop and ask before replacing it.
6. verify that `.claude/skills/setup-benny/FOR_AGENTS.md` and `.claude/skills/setup-benny/SKILL.md` exist in the target repository.
7. read and follow `.claude/skills/setup-benny/SKILL.md` directly from the target repository.

i want you to merge this entry into the target repository's `.claude/settings.json`:

```json
{
	"enabledPlugins": {
		"pstack@pstack": true
	}
}
```

preserve every unrelated setting and plugin entry.

i want verification from a fresh agent rooted in the target repository. confirm that pstack's `how`, `why`, `tdd`, `unslop`, and the principle skills used by benny resolve in project scope. do not count skills loaded from the current session or a user-scoped install.

if project-scoped plugins are unavailable or any shared dependency does not resolve, stop and explain what failed. the pstack marketplace must be known to claude code in every environment that runs the automations; add it with `claude plugin marketplace add` when it is missing. do not add the copied benny skills to a plugin manifest. they are committed project skills with model invocation disabled, and the live automation prompts read the operational files directly by path.

tell me that `.claude/settings.json`, the copied benny skills under `.claude/skills/`, and any referenced secret-free configuration must be committed before either automation is enabled. do not create or update an automation until i explicitly ask.

for first-time creation, use the built-in `/schedule` skill once for triage and once for repro and fix. complete the draft review, approval, and schedule confirmation for the first routine before starting the second. when i need a true post-time trigger, set up the github actions workflow running headless claude code instead, through a committed and reviewed workflow file.

paraphrase this intent and the finished configuration into each draft. the triage prompt must read and follow `.claude/skills/triage-issue-reports/SKILL.md`. the repro prompt must read and follow `.claude/skills/reproduce-and-fix-issues/SKILL.md`. use these repo-relative paths only after confirming they are committed in the repository where the routine will run.

for existing routines, validate the configuration, then use the concise field checklist in the copied setup file and apply each update through `/schedule`. do not create duplicates.
