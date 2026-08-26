---
name: setup-benny
description: Configure Benny and prepare its triage and repro automations. Use when installing Benny or changing its Slack, tracker, repository, routing, control, model, or budget settings.
disable-model-invocation: true
---

# Set up Benny

Benny ships as a dormant automation pack inside pstack. The plugin manifest exposes only pstack's normal skill root, so the `automations/` pack is not auto-loaded; this file and the two operational files become committed project skills only after setup copies them into the target repository's `.claude/skills/`.

The human enters setup by pointing Claude Code at the pack's `FOR_AGENTS.md`. The bootstrap flow copies the whole pack into the target repository, then reads this file directly at `.claude/skills/setup-benny/SKILL.md`.

Benny needs external configuration and two live scheduled agents: Claude Code cloud routines created with the built-in `/schedule` skill, or, when a true post-time trigger is required, a GitHub Actions workflow running headless Claude Code (`claude -p`).

Do not create or update an automation until the user explicitly asks. Never put a secret value in plugin files, prompts, or committed configuration.

## 1. Copy the pack and enable shared pstack skills

Do this before asking for Benny configuration and before invoking the built-in `/schedule` skill.

Ask which repository will run the automations. The source pack is the directory containing `FOR_AGENTS.md`. The destination is the target repository's `.claude/skills/`.

Merge the entire source pack into the destination:

1. Create `<target-repository>/.claude/skills/` when it is absent.
2. Copy each directory under the pack's `skills/` to `<target-repository>/.claude/skills/<name>/`, preserving every relative path inside it.
3. Copy the pack's `FOR_AGENTS.md`, `README.md`, and `templates/` into `<target-repository>/.claude/skills/setup-benny/`.
4. Preserve destination-only files. Never delete unrelated files or skills during install or refresh.
5. Keep user-owned configuration, feature maps, and routing maps outside the destination. Never overwrite them.
6. When an existing source-managed file differs, inspect the diff and merge without discarding local edits. If ownership is ambiguous, stop and ask before replacing it.
7. Verify that the destination contains `FOR_AGENTS.md`, this setup file, both operational files, their references, and the templates.

If this file is already being read from the target destination, treat the copy as complete and run the same verification before continuing.

Add pstack to the target repository's `.claude/settings.json`. If the file or `.claude` directory does not exist, create it.

Merge this entry into the existing JSON:

```json
{
	"enabledPlugins": {
		"pstack@pstack": true
	}
}
```

Preserve every unrelated top-level setting and every other plugin entry. If the `pstack@pstack` entry already exists, change only its value. Validate the file after editing it. The pstack marketplace must also be known to Claude Code in every environment that runs the automations; add it with `claude plugin marketplace add` when it is missing.

Restart Claude Code in the target project or start a fresh agent rooted there. Verify that these shared pstack skills resolve from project scope:

- `how`
- `why`
- `tdd`
- `unslop`
- `principle-separate-before-serializing-shared-state`
- `principle-minimize-reader-load`
- `principle-guard-the-context-window`
- `principle-sequence-verifiable-units`
- `principle-fix-root-causes`
- `principle-prove-it-works`

Do not count a skill loaded from the current session or a user-scoped plugin. The check must show that a fresh agent in the target repository receives pstack through project settings.

If project-scoped plugin installation is unavailable or any shared dependency does not resolve, stop and explain the failure.

The Benny operational files are read directly from `.claude/skills/`. Do not add them to a plugin manifest. They are committed project skills with model invocation disabled; live automation prompts read them by their repository paths instead of invoking them as slash skills.

Tell the user that `.claude/settings.json`, the copied Benny skills under `.claude/skills/`, and any referenced secret-free configuration must be committed before either automation is enabled. Do not commit them unless the user asks.

Once this check passes, live automation prompts may read the committed operational files by their stable repository-relative paths. They must not embed a plugin cache path or copy the file contents.

## 2. Adapt the configuration

Open these copied examples:

- `./templates/configuration.example.yaml`
- `../reproduce-and-fix-issues/references/feature-map.example.md`

Create user-owned copies outside the copied Benny skills. These are configuration files, not pack files. Example locations:

- Project config, such as `.claude/benny/configuration.yaml`
- Project feature map, such as `.claude/benny/feature-map.md`
- Project routing map, such as `.claude/benny/routing.md`
- User config, such as `~/.config/benny/configuration.yaml`
- User feature map, such as `~/.config/benny/feature-map.md`

Fill one feature-map section for every user-facing feature the automation may reproduce. Keep it at the user point of view. Do not freeze implementation details or current code paths in the map.

Do not edit the copied examples. Pack refreshes may update source-managed files after conflict review, but they must never touch the user-owned copies.

Prefer committed, secret-free files in the target repository when a fresh automation checkout must read them. Otherwise paraphrase the required values into the live prompt. Reference a repository file only after confirming that the file is committed in the repository where the automation runs.

Use stable repository-relative paths for committed pack and configuration files. Never reference the plugin source directory or a plugin cache path from a live automation.

## 3. Fill the required choices

Ask for or confirm:

- Source Slack channel ID
- Optional operations or status channel ID
- Repository URL and default branch
- Triage identity or Slack user ID
- Issue tracker type, team, project, labels, and intake status
- Tracker adapter skill or MCP actions
- Optional routing map path
- Required control skill name
- Required user-facing feature-map path
- Status emoji strings
- Pull request URL format
- Routine schedule cron cadence
- Polling and effort budgets
- Model for triage, repro, code work, and media review

Use only model names available to the user's Claude Code, such as the aliases `haiku`, `sonnet`, `opus`, and `fable`, or a full model ID from the supported model list. Do not guess a model ID and do not carry over a private default.

The source channel, triage identity, repository, tracker adapter, control skill, and feature map must be explicit. Fail setup if any required value stays ambiguous.

Use pstack's `unslop` skill on the final automation names, descriptions, and prompt shims before saving them.

## 4. Check integration capabilities

The triage automation needs:

- Read access to the configured source Slack channel and its threads
- Thread-reply access in that channel
- Attachment metadata and file download access when reports include media
- Search, read, create, and update access through the configured issue-tracker adapter

The repro automation needs:

- Read access to the source thread
- Thread-reply access in the source channel
- Optional post and edit access in the configured operations channel
- Repository read and history access
- A pull request action that can open a draft pull request
- The configured control-adapter skill

Prefer the Slack MCP tools available to the automation's session for reads and posts (`claude mcp list` shows the configured servers). The optional `BENNY_SLACK_BOT_TOKEN` may fill a narrow gap such as editing one operations status message or downloading an attachment. Store the value in a secret manager or environment, not in YAML.

Do not use undocumented integration endpoints.

## 5. Prepare the routing map

If the user wants reroutes or owner pings:

1. Copy `../triage-issue-reports/references/routing.example.md` outside the copied Benny skills, for example to `.claude/benny/routing.md`.
2. Replace every placeholder with public or organization-local values.
3. Keep owner pings off by default.
4. Allow a ping only for a configured feature owner or a confirmed likely regression author.

If no routing map is configured, triage may classify a report but must not guess a destination or owner.

## 6. Verify the control adapter

Read `../reproduce-and-fix-issues/references/control-adapter.md` and the user's completed feature map.

Confirm that the named skill can:

- Bring up the target app
- Navigate every mapped feature through the real UI
- Exercise mapped states through declared adapter actions
- Inspect state without forcing the result
- Capture screenshots
- Start and stop a recording
- Clean up its processes and temporary data

If any capability is missing, leave the repro automation disabled. It must fail closed rather than claim a reproduction it did not perform.

## 7. Prepare the live automations

Ask whether this is first-time creation or configuration of existing automations.

Read `./FOR_AGENTS.md` from the copied pack as the primary user-intent source for either path. Use it to understand the two triggers, tools, instructions, outcomes, and shared rules.

Claude Code routines run on a cron schedule, not a Slack event. Each scheduled run scans the configured source channel for new top-level reports and processes each one by its operational file. When the user needs a true post-time trigger instead of the polling cadence, that is a webhook-triggered CI job they build themselves, outside this pack's scope: a Slack Events API consumer that fires a GitHub Actions `repository_dispatch` or `workflow_dispatch` workflow running headless Claude Code (`claude -p`), with the Anthropic and Slack secrets wired into the workflow. If they build one, its prompt should carry the same intent, read the same committed operational file, and ship only as a committed, reviewed workflow file.

### First-time creation

Create one automation at a time.

For each automation:

1. Read the matching copied prompt template as secondary internal source material.
2. Turn `FOR_AGENTS.md`, the finished Benny configuration, and the template intent into a complete natural-language routine prompt.
3. Tell the live prompt to read and follow its exact committed operational file under `.claude/skills/`.
4. Use the stable repository-relative path, not a plugin source or cache path. Do not copy the operational file contents into the live prompt.
5. Read and follow the built-in `/schedule` skill.
6. Let `/schedule` create the routine on the configured repository, default branch, and cron cadence.
7. Confirm that the copied pack and any referenced configuration files are committed in the same repository and branch the routine checks out.
8. Show the routine draft, obtain approval, and save it through `/schedule`.
9. Finish and verify this automation before starting the next one.

Give `/schedule` this complete triage intent, filled from configuration:

- Name `benny-triage`.
- Read and follow `.claude/skills/triage-issue-reports/SKILL.md` for every run.
- Run on the configured cron cadence. Scan the configured source Slack channel for new top-level reports without a Benny verdict reply and process each one.
- Read each report's thread and reply only inside it.
- Use the configured issue-tracker integration.
- Classify, inspect evidence, trace cause, dedupe, and create only clear new bugs.
- End one thread-only verdict with the configured `[benny:bug]`, `[benny:performance]`, or `[benny:other]` marker and optional tracker URL.
- Never post a source-channel root message.

After the triage routine is saved and verified, give `/schedule` this complete repro and fix intent:

- Name `benny-reproduce`.
- Read and follow `.claude/skills/reproduce-and-fix-issues/SKILL.md` for every run.
- Run on the configured cron cadence and pick up the same new top-level reports in the configured source Slack channel.
- Use the configured repository and default branch.
- Read the source thread and reply only inside it.
- Include pull request creation and the configured tracker, control-adapter, and feature-map requirements. Paraphrase mapped user paths and states unless an eligible committed file in the same repository is confirmed.
- Wait for a trusted triage marker before acting.
- Reproduce the exact symptom twice through the mapped real UI and capture evidence.
- Verify an existing fix without authoring over it.
- Attempt an optional bounded fix only after confirmed repro, then open a draft pull request when proof and checks pass.
- Never post a source-channel root message.

Let `/schedule` own routine creation, scheduling, drafting, and saving. Do not duplicate its work.

### Existing automations

Use `/schedule` to list and update the existing routines. Do not use it to create replacements or duplicates.

Finish configuration, routing, control-adapter, and feature-map validation. Then apply this concise field checklist through `/schedule`.

For the existing triage automation, update:

- Name and description
- Direct instruction to read `.claude/skills/triage-issue-reports/SKILL.md`
- Cron cadence and the source-channel scan for new top-level reports
- Slack thread read and reply capabilities
- Issue-tracker integration
- Paraphrased triage instructions, thread-only rule, and Benny verdict markers

For the existing repro automation, update:

- Name and description
- Direct instruction to read `.claude/skills/reproduce-and-fix-issues/SKILL.md`
- Matching cron cadence and source channel
- Repository and default branch
- Slack thread read and reply capabilities
- Pull request action
- Tracker, control-adapter, and feature-map requirements
- Paraphrased marker wait, evidence, verification, and bounded-fix instructions

Apply each update to the existing routine. Do not create replacements or duplicates.

### Creation boundary

Never call a scheduling backend service directly or hand-build a routine record. Never use a browser URL that carries draft fields. For new routines, the only finish path is the built-in `/schedule` skill's reviewed draft and save. For the GitHub Actions alternative, the only finish path is a committed workflow file that went through normal review.

Do not enable either automation until the thread-safety test passes after the routine is saved.

## 8. Test thread safety

Use a test channel or a harmless test report.

Before testing, confirm that the target repository's `.claude/settings.json`, the copied Benny skills under `.claude/skills/`, and every referenced secret-free configuration file are committed on the branch used by the automation checkout. Confirm that both live prompts point at their exact committed operational files. If any check fails, stop. Tell the user that the automation cannot be enabled yet.

Verify:

1. Triage stores the root `thread_ts` and posts exactly one verdict as a reply.
2. The verdict contains one configured marker.
3. Repro accepts the marker only from the configured triage identity.
4. Repro keeps the same immutable source coordinates.
5. No source-channel root message appears.
6. A delegated worker cannot use any Slack write action.
7. Missing coordinates, a deleted parent, or a failed preflight produces no post and no tracker issue.

Enable normal traffic only after all seven checks pass.
