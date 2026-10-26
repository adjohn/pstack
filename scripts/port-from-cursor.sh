#!/usr/bin/env bash
# Rewrites Cursor plumbing to Claude Code plumbing across skills/, agents/, and docs/.
# Run after merging a new upstream snapshot from cursor/plugins (README, "syncing with upstream").
# Idempotent: every rule's output contains none of its inputs.
set -euo pipefail
cd "$(dirname "$0")/.."

find skills agents docs -path '*/node_modules' -prune -o -type f \( -name '*.md' -o -name '*.ts' -o -name '*.mjs' -o -name '*.sh' -o -name '*.yaml' \) -print0 |
  xargs -0 perl -0pi -e '
my $slug = q{`<slug>` is the absolute working directory, symlinks resolved, with every character that is not a letter or digit, including `/`, `.`, and `_`, replaced by `-`, so `/Users/you/proj` becomes `-Users-you-proj`};
my $verify = q{the project'"'"'s verification skill (`verify-<app>`, created by `/create-verification-skill`)};
my @rules = (
  # model fallbacks: provider families -> Claude tiers
  ["If the Task tool rejects a configured entry, run that seat on its family'"'"'s default and say so. Families go by prefix: `claude-*`, `gpt-*`, and `grok-*`. With no family match, use `claude-opus-5-5-max`. If it rejects a default, use the closest valid slug of the same family from its error message.",
   "If the Agent tool rejects a configured entry, run that seat on `claude-opus-5-5-max` and say so."],
  ["If the Task tool rejects a configured entry, run that reviewer on the table default of its family and say so. Families go by prefix: `claude-*`, `gpt-*`, and `grok-*`. With no family match, use Reviewer A'"'"'s default. If it rejects a table default,",
   "If the Agent tool rejects a configured entry, run that reviewer on Reviewer A'"'"'s default and say so. If it rejects a table default,"],
  ["If it rejects the default, use the closest valid slug of the same family from its error message.", "If it rejects the default, use the nearest Claude tier from its error message."],
  ["the `pstack-models.mdc` rule", "`~/.claude/pstack-models.md`"],
  ["If the rule or that line is missing", "If the file or that line is missing"],
  ["If the rule or the line is missing", "If the file or the line is missing"],
  ["if the rule or the line is missing", "if the file or the line is missing"],
  ["A role with no line in the rule", "A role with no line in the file"],
  ["A rule written before 0.15.3", "A file written before 0.15.3"],
  ["a rule written before 0.15.3", "a file written before 0.15.3"],

  # model slugs -> Claude tiers
  ["claude-opus-5-5-max", "opus"],
  ["grok-4.7-xhigh-fast", "haiku"],
  ["claude-fable-5-1-thinking-max", "fable"],
  ["claude-fable-5-thinking-max", "fable"],
  ["gpt-5.6-sol-max", "sonnet"],
  ["grok-4.6-fast-xhigh", "haiku"],
  ["claude-opus-5-thinking-xhigh", "opus"],
  ["model family", "model tier"],
  ["(prefer the highest-reasoning tier of the same family)", "(prefer the nearest Claude tier)"],
  ["which is how Auto users stay on Auto", "which is how users on the default model setting stay on it"],

  # config, transcript, and worktree paths
  ["~/.cursor/rules/pstack-models.mdc", "~/.claude/pstack-models.md"],
  ["Per-role lines in the `/setup-pstack` rule override", "Per-role lines in `~/.claude/pstack-models.md` (created by `/setup-pstack`) override"],
  ["~/.cursor/projects/*/", "~/.claude/projects/*/"],
  [".cursor/worktrees/myrepo/x", ".claude/worktrees/x"],
  [".cursor/skills/", ".claude/skills/"],
  ["node pstack/skills/poteto-mode/scripts/check-plan.mjs", "node \${CLAUDE_PLUGIN_ROOT}/skills/poteto-mode/scripts/check-plan.mjs"],
  ["The system prompt names the active workspace'"'"'s `agent-transcripts/` directory. Use that path.",
   "Transcripts live at `~/.claude/projects/<slug>/`, one `.jsonl` per session with one JSON message per line, where $slug. Derive the directory from the current working directory."],
  ["under the active workspace'"'"'s `agent-transcripts/` directory (the system prompt names the path. ",
   "under `~/.claude/projects/<slug>/` (one `.jsonl` per session with one JSON message per line, where $slug. "],
  ["under the active workspace'"'"'s `agent-transcripts/` directory (the system prompt names this path)",
   "under `~/.claude/projects/<slug>/` (one `.jsonl` per session with one JSON message per line, where $slug)"],
  ["under the active workspace'"'"'s `agent-transcripts/` directory (the system prompt names the path)",
   "under `~/.claude/projects/<slug>/` (one `.jsonl` per session with one JSON message per line, where $slug)"],
  ["local transcripts under `agent-transcripts/`", "local transcripts under `~/.claude/projects/`"],
  ["`~/Library/Application Support/Cursor` (`state.vscdb.backup`, and `snapshots/roots/<root>` where a `<root>` named for a folder you opened as a workspace balloons)",
   "`~/.claude/projects` (a `<slug>` directory named for a workspace you have since deleted balloons with old transcripts)"],
  ["Create `orchestrate/<project-slug>/` in the current agent'"'"'s store (path in the system prompt).",
   "Create the store at `~/.claude/orchestrate/<project-slug>/`, a durable directory outside the repo, and point `orch` at it (`--store` or `ORCH_STORE`)."],

  # tool surface: AskQuestion -> AskUserQuestion, Task -> Agent, readonly flag -> prompt instruction
  ["AskQuestion", "AskUserQuestion"],
  ["generalPurpose", "general-purpose"],
  ["**Defaults for every `Task` call.** `run_in_background: true`, agent mode (readonly strips MCP), ", "**Defaults for every `Agent` call.** `run_in_background: true`, "],
  ["(omit Task `model`)", "(omit the Agent `model`)"],
  ["Task subagent", "subagent"],
  ["subagent_type: \"poteto-agent\"", "subagent_type: \"pstack:poteto-agent\""],
  ["Spawn `Task` with `subagent_type: \"Comment Sicko\"`.", "Spawn Comment Sicko with `Agent` (the subagent-launching tool) and `subagent_type: \"pstack:comment-sicko\"`."],
  ["subagent_type: \"comment-sicko\"", "subagent_type: \"pstack:comment-sicko\""],
  ["full Task schema including `environment`", "full Agent tool schema"],
  ["the Task tool", "the Agent tool"],
  ["`Task` call", "`Agent` call"],
  ["a `Task` subagent", "an `Agent` subagent"],
  ["- `readonly`: `true`", "- Read-only by instruction: the prompt forbids file writes and mutating commands"],
  [", agent mode (`readonly: false`)", ""],
  ["Readonly strips MCPs.", "Subagents inherit MCP tools by default."],
  ["- `readonly`: `false` (agent mode). **Do not use readonly/Ask mode.** It strips MCP access, which disables MCP-backed investigators entirely. Investigators still shouldn'"'"'t write anything.",
   "- Investigators must not write anything. That'"'"'s an instruction in their prompt, not a sandbox. Subagents inherit MCP tools by default, which the MCP-backed investigators need."],
  ["- `readonly`: `false` (agent mode). The synthesizer'"'"'s quality check spot-verifies citations, which can require MCP access. Readonly/Ask mode strips MCPs and defeats that.",
   "- The synthesizer must not write anything. That'"'"'s an instruction in its prompt. Its quality check spot-verifies citations, which can require MCP access, and subagents inherit MCP tools by default."],
  ["Always `environment: \"cloud\"` unless", "Always cloud unless"],
  [", `environment: \"cloud\"`", ""],
  [" Use `environment: \"local\"` only when the worker needs access to something on the user'"'"'s computer.", ""],
  ["Simulators and local IDE state.", "Simulators and local machine state."],

  # Cursor product surface -> Claude Code equivalents
  ["Cursor'"'"'s `/loop` command", "Claude Code'"'"'s `/loop` command"],
  ["Cursor cloud agent", "Claude Code cloud agent"],
  ["restart Cursor", "restart Claude Code"],
  ["After a Cursor restart", "After a Claude Code restart"],
  ["in the Cursor dashboard", "in the Claude Code cloud dashboard (claude.ai/code)"],
  ["arm a `/goal` with the full program objective. The goal continues",
   "write the full program objective verbatim to a pinned goal file, `GOAL.md` next to the plan or in the run'"'"'s store, and re-read it at every audit tick. The goal file continues"],
  ["re-read the armed `/goal`", "re-read the pinned goal file"],
  ["This playbook replaces Cursor'"'"'s built-in babysit skill for these requests, so do not route there even though its description matches the same words. ", ""],
  [", and not Cursor'"'"'s built-in babysit skill, whose description matches the same words", ""],

  # cursor-team-kit: control skills -> verify-<app>, deslop -> /simplify, create-skill -> skill-creator
  ["with the matching control skill (such as `control-ui` or `control-cli` from `cursor-team-kit`)", "with $verify"],
  ["with the matching control skill, such as `control-cli` or `control-ui` from `cursor-team-kit`, or a named driver", "with $verify, or a named driver"],
  ["the matching control skill. `cursor-team-kit` publishes `control-cli` (CLIs and TUIs) and `control-ui` (browser / Electron / web UIs).", "$verify."],
  ["`control-ui` or `control-cli` runtime verification (from `cursor-team-kit`)", "runtime verification via $verify"],
  ["(`control-ui` or `control-cli` from `cursor-team-kit` as the change demands)", "(the project'"'"'s verification skill, `verify-<app>` created by `/create-verification-skill`, as the change demands)"],
  ["(`control-cli` or `control-ui` from `cursor-team-kit` as the change demands)", "(the project'"'"'s verification skill, `verify-<app>` created by `/create-verification-skill`, as the change demands)"],
  ["via the control skill (Non-negotiables)", "via the project'"'"'s verification skill (`verify-<app>`, created by `/create-verification-skill`; Non-negotiables)"],
  ["the matching control skill", $verify],
  ["the relevant control skill", $verify],
  ["via the control skill", "via $verify"],
  ["through its control skill", "through its verification skill"],
  ["the control surface", "the verification surface"],
  ["the `deslop` skill from the `cursor-team-kit` plugin (`/deslop`)", "Claude Code'"'"'s built-in `/simplify`"],
  ["`/deslop`", "`/simplify`"],
  ["skeptical Bugbot triage", "skeptical review-bot triage (Cursor'"'"'s Bugbot, Claude Code'"'"'s `/code-review`, or similar)"],
  ["every Bugbot and security-reviewer comment", "every review-bot comment (Cursor'"'"'s Bugbot, Claude Code'"'"'s `/code-review`, or similar) and security-reviewer comment"],
  ["**Bugbot is triaged skeptically, always.**", "**Review bots are triaged skeptically, always.**"],
  ["the watcher'"'"'s Bugbot pass count", "the watcher'"'"'s review-bot pass count"],
  ["Skip when: Bugbot flags", "Skip when: The review bot flags"],
  ["Cursor'"'"'s built-in `create-skill` (authoring)", "the `skill-creator` skill for authoring (from anthropics/skills, when installed; otherwise author the SKILL.md directly per step 4)"],
  ["follow `create-skill`'"'"'s YAML rules. ", ""],
  ["`create-skill`'"'"'s writing guidelines", "`skill-creator`'"'"'s writing guidelines (when installed)"],
  ["`create-skill` alone", "`skill-creator` alone (or author the SKILL.md directly)"],
  ["the **create-skill** skill (Cursor'"'"'s built-in for authoring SKILL.md files)", "the **skill-creator** skill if installed (from anthropics/skills); otherwise author the SKILL.md directly"],

  # worktree cleanup: Cursor pinned chats -> Claude Code sessions
  ["The pinned and active chats are the real artifact (principle-prove-it-works). Get that set from the user or sidebar and cross-check every candidate. The lever has marked `safe` a worktree the user had pinned, so the pinned set wins.",
   "The chats the user still has active or means to resume are the real artifact (principle-prove-it-works). Get that set from the user, or derive it from transcript recency (`ls -t ~/.claude/projects/<slug>/*.jsonl | head`; the newest-modified sessions are the live or resumable ones), and cross-check every candidate. `claude --resume` is the interactive picker the user can consult to tell you which chats they mean to keep. It is not parseable from a script. The lever has marked `safe` a worktree whose chat the user was still keeping around, so the user'"'"'s set wins."],
  ["report whether the chat is pinned or ongoing", "report whether the chat is still ongoing"],
  ["A pinned chat spawns", "A long-running chat spawns"],
  ["never hit the sidebar", "never hit the session list"],

  # multi-phase plan checklist: /goal -> GOAL.md, trunk reads -> installed plugin
  ["On the operator'"'"'s go, arm a `/goal` with this exact text.", "On the operator'"'"'s go, write the pinned goal file, `GOAL.md` next to this plan, with this exact text."],
  ["- [ ] Read these from trunk at program start. Re-read them at every tick.", "- [ ] Read these at program start. Re-read them at every tick. The installed plugin is the canonical copy, never a copy inside a work worktree."],
  ["`git show origin/main:<control skill path>`", "`git show origin/main:<verification skill path>`"],
  ["Re-read the execution playbook from trunk and the armed /goal.", "Re-read the execution playbook from the installed pstack plugin and the pinned goal file."],

  # setup-pstack and its guide: Cursor rule -> always-loaded memory file
  ["writes an always-applied rule", "writes an always-loaded memory file"],
  ["the rule shape shown in step 5", "the file shape shown in step 5"],
  ["when the rule records one", "when the file records one"],
  ["with `alwaysApply: true`, a", "with a"],
  ["a small rule every pstack skill reads.", "a small config file every pstack skill reads, and adds the line `@~/.claude/pstack-models.md` to `~/.claude/CLAUDE.md` so the file is always loaded."],

  # 0.15.32: family fallbacks with composer and cursor-grok prefixes, xhigh defaults, per-spawn effort
  ["run that seat on its family'"'"'s default and say so. Families go by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refused `composer-*` entry runs on `haiku`. With no family match, use `claude-opus-5-5-xhigh`. If it rejects a default, use the closest valid slug of the same family from its error message.",
   "run that seat on `opus` and say so. If it rejects a default, use the nearest Claude tier from its error message."],
  ["run that reviewer on its family'"'"'s table default and say so. Families go by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refused `composer-*` entry runs on Reviewer B'"'"'s default. With no family match, use Reviewer A'"'"'s default. If it rejects a table default,",
   "run that reviewer on Reviewer A'"'"'s default and say so. If it rejects a table default,"],
  ["(prefer the same family and reasoning tier)", "(prefer the nearest Claude tier)"],
  ["claude-opus-5-5-xhigh", "opus"],
  ["reasoning level and fast or standard speed", "reasoning level (the Agent `effort`)"],
  ["**Match the model to the job.** Before each spawn, start from the role'"'"'s line or default and pick the reasoning level and speed the job needs. The `/setup-pstack` budget sets each role'"'"'s starting level, xhigh by default. Raise it one step, up to max, for the hardest or subtlest work. Lower it one step for judgment and two or more steps for routine work. Use fast mode only when the job is urgent, meaning CI or trunk is red or a person is blocked on the result right now. Otherwise use standard speed, the same slug without `-fast`. Verification is the exception and stays on the `swarm workers` model and speed (`haiku` by default). Change only the effort level and whether the slug is fast, and keep the family the role names, so a diverse panel stays diverse. If the family has no slug at that level and speed, use its nearest slug. A role on `auto` or `inherit-parent` stays on the parent model. If the Agent tool rejects the adjusted slug, do not try another adjusted slug. Use the role'"'"'s line or default and say so.",
   "**Match the model to the job.** Before each spawn, start from the role'"'"'s line or default and pick the reasoning level the job needs, passed as the Agent `effort` (`low`, `medium`, `high`, `xhigh`, `max`). Without `effort`, a subagent runs at the session'"'"'s level, which the `/setup-pstack` budget sets. Raise it one step, up to `max`, for the hardest or subtlest work. Lower it one step for judgment and two or more steps for routine work. Verification is the exception and stays on the `swarm workers` model at the session'"'"'s level (`haiku` by default). Change only the effort, and keep the tier the role names, so a diverse panel stays diverse. A role on `auto` or `inherit-parent` stays on the parent model. If the Agent tool rejects the effort, spawn once more without `effort` and say so."],

  # 0.15.32: readonly and MCP wording
  ["`subagent_type: general-purpose` and `readonly: true`.", "`subagent_type: general-purpose`, read-only by instruction: the prompt forbids file writes and mutating commands."],
  ["`subagent_type: general-purpose`, `readonly: true`, and `model`", "`subagent_type: general-purpose`, a prompt that forbids file writes and mutating commands, and `model`"],
  [", and readonly strips MCPs.", ". Subagents inherit MCP tools by default."],
  ["Every spawn is `general-purpose` with `readonly: false` (agent mode). **Do not use readonly/Ask mode.** It strips MCP access, which disables the MCP-backed investigators and the synthesizer'"'"'s citation spot-checks. Investigators still shouldn'"'"'t write anything.",
   "Every spawn is `general-purpose`. Subagents inherit MCP tools by default, which the MCP-backed investigators and the synthesizer'"'"'s citation spot-checks need. Investigators still must not write anything. That'"'"'s an instruction in their prompt, not a sandbox."],

  # 0.15.32: agents, plugin paths, transcripts, skill authoring
  ["\nis_background: true\n", "\n"],
  ["every Task spawn", "every Agent spawn"],
  ["Spawn `Task` with", "Spawn `Agent` with"],
  ["~/.cursor/plugins/", "~/.claude/plugins/"],
  ["`.cursor-plugin/plugin.json`", "`.claude-plugin/plugin.json`"],
  ["a `Task` prompt naming its path, or a tool call (Shell, Grep, MCP, etc.) matching its documented commands.",
   "an `Agent` prompt naming its path, a `Skill` tool call naming it (a skill invoked via `Skill` shows no `SKILL.md` Read), or a tool call (Bash, Grep, MCP, etc.) matching its documented commands."],
  ["find this conversation'"'"'s transcript in the `agent-transcripts/` directory the system prompt names.",
   "find this conversation'"'"'s transcript under `~/.claude/projects/<slug>/` (one `.jsonl` per session with one JSON message per line, where $slug). Derive the directory from the current working directory."],
  ["hand to Cursor'"'"'s built-in `create-skill` skill and run its draft / test / iterate loop.",
   "hand to the `skill-creator` skill if installed (from anthropics/skills) and run its draft / test / iterate loop; otherwise the parent drafts the section directly."],
  ["hand to `create-skill` and run its description-optimization loop.", "hand to `skill-creator` and run its description-optimization loop, or tune the description directly if it isn'"'"'t installed."],
  ["`new skill via create-skill: <kebab-name>`: hand creation to `create-skill`.", "`new skill via skill-creator: <kebab-name>`: hand creation to `skill-creator` if installed; otherwise author the SKILL.md directly."],

  # 0.15.32: Cursor product surface
  [", not Cursor'"'"'s built-in babysit skill, whose description matches the same words.", "."],
  ["a Cursor restart", "a Claude Code restart"],
  ["`/simplify` from `cursor-team-kit`", "Claude Code'"'"'s built-in `/simplify`"],
  ["Re-read the execution playbook from trunk.", "Re-read the execution playbook from the installed pstack plugin."],
  ["reviewers on different model families", "reviewers on different model tiers"],
  ["through its verification skill (such as `control-ui` or `control-cli` from `cursor-team-kit`)", "through its verification skill (`verify-<app>`, created by `/create-verification-skill`)"],
  ["It doesn'"'"'t load on its own, so type `/typescript-best-practices` when a task touches `.ts` or `.tsx` files.",
   "Its `paths` frontmatter loads it whenever the agent reads or edits a `.ts` or `.tsx` file, so you rarely type `/typescript-best-practices` yourself."],

  # fork features: the PR size budget (references/pr-budget.md, hooks/hooks.json)
  ["**Size and stacks.** Prefer five narrow PRs to one large PR.",
   "**Size and stacks.** Every PR fits the budget in `../references/pr-budget.md`. The plugin hook denies an over-budget `gh pr create` or `gt submit`. Split along the seams the reference names, then stack the pieces and keep the ordered stack visible to reviewers."],
  ["(the **sequence-verifiable-units** principle skill). Name the execution playbook",
   "(the **sequence-verifiable-units** principle skill), and its Files block fits the budget in `../references/pr-budget.md`. Name the execution playbook"],
  ["Use for poteto, /poteto-mode, or requests to work in this style.\n",
   "Use for poteto, /poteto-mode, or requests to work in this style; apply it to new tasks that match a playbook or need rigor, not to casual turns or when the user opts out.\n"],
  # 0.15.32: guide pages and /poteto-help, which upstream wrote for Cursor with a Claude Code side note
  ["In Claude Code, run `/plugin marketplace add cursor/plugins`, then `/plugin install pstack\@cursor-plugins`. Claude Code prefixes plugin commands, so each command in this guide takes a `pstack:` prefix there, such as `/pstack:setup-pstack`, which writes its model rule to `~/.claude/rules/pstack-models.md`. The [Claude Code adapter](../harness/claude-code.md) covers the other differences.\n\n",
   ""],
  ["The defaults run at `xhigh` reasoning, the same as the `large` budget. `unlimited` lifts each model to its highest tier, up to `max`. Opus goes to `max`. Grok tops out at `xhigh`, so it stays there. `medium` and `small` lower the reasoning and spend fewer tokens.",
   "The budget sets `effortLevel` in `~/.claude/settings.json`, which every subagent inherits unless a spawn passes its own `effort`. `large`, `medium`, and `small` set it to `xhigh`, `high`, and `medium`. `unlimited` removes it, so each model runs at its own default, and `/effort max` reaches `max` for one session. Lower budgets spend fewer tokens."],
  ["a rule written before the change still pins",
   "a file written before the change still pins"],
  ["To keep `/poteto-mode` on for the whole chat, pick it from the `/` menu with Option+Enter (Mac) or Alt+Enter (Windows) instead of Enter. That makes it a [Custom Mode](https://cursor.com/docs/skills#using-a-skill-as-a-custom-mode), which stays in context on every turn until you exit it. Custom Modes are available in the Agents Window and the CLI. Plain Enter attaches the skill to one message, and it fades as the chat moves on.",
   "`/poteto-mode` is sticky. It stays on for the conversation until you opt out by saying so."],
  ["and a Custom Mode keeps `/poteto-mode` in context on every turn. [Set up pstack](./01-setup.md#run-your-first-task) shows how to start one.",
   "and `/poteto-mode` stays in context for the rest of the conversation once you invoke it."],
  ["The cleanest isolation is a [cloud subagent](https://cursor.com/docs/subagents#cloud-subagents). Each one gets its own VM and branch, so it can install dependencies, run your app, and record video of the result without touching your machine. Type `/in-cloud` before the task, or ask the parent chat to hand work to cloud subagents.",
   "The cleanest isolation is a Claude Code cloud session at claude.ai/code. Each one gets its own container and branch, so it can install dependencies, run your app, and capture the result without touching your machine. On one machine, ask the parent chat for worktree-isolated subagents (`isolation: \"worktree\"`), which each get their own git worktree."],
  ["A [Cursor Project](https://cursor.com/blog/projects) gives one coordinator agent a persistent thread. The coordinator doesn'"'"'t write code. It directs subagents, which run in the cloud by default, so the work continues when your laptop is closed.",
   "A long-lived Claude Code session gives one coordinator agent a persistent thread. Resume it with `claude --resume`, or run it as a cloud session at claude.ai/code so the work continues when your laptop is closed. The coordinator doesn'"'"'t write code. It directs subagents."],
  ["- Give each body of work its own Project,",
   "- Give each body of work its own coordinator session,"],
  ["- Drag related chats into the Project, finished ones included. They become context for every agent in it.",
   "- Point the coordinator at related chats, finished ones included, with `/recall`. They become context for the agents it briefs."],
  ["One prompt can carry a whole Project,",
   "One prompt can carry a whole program,"],
  ["pstack is built for Cursor, and it also installs in Claude Code with `/plugin marketplace add cursor/plugins`, then `/plugin install pstack\@cursor-plugins`. There, each command takes a `pstack:` prefix, such as `/pstack:poteto-mode`. The [Claude Code adapter](../../docs/harness/claude-code.md) maps the Cursor names, and a step that needs a Cursor-only feature, such as Bugbot or Automations, is skipped with a one-line note.",
   "This is the Claude Code port of pstack, installed with `claude plugin marketplace add adjohn/pstack`, then `claude plugin install pstack\@pstack`. Each command also answers to a `pstack:` prefix, such as `/pstack:poteto-mode`. The original is a Cursor plugin, and the [README](../../README.md) lists what the port changed."],
  ["spawn Cursor subagents with per-role models, and Custom Modes and `/loop` are Cursor features, so those parts may not work there.",
   "spawn Claude Code subagents with per-role models, so those parts may not work there."],
  ["- Enter on `/poteto-mode` attaches the skill to one message. It fades as the chat moves on.\n- Option+Enter on Mac or Alt+Enter on Windows, or Use as Mode from the skill entry, makes it a Custom Mode. It stays in context every turn until the user exits the mode, and it stays out of casual turns.\n- Cursor'"'"'s docs list Custom Modes in the Agents Window and the CLI. Elsewhere, start each new task with `/poteto-mode`.\n\nLink [Cursor'"'"'s skills docs](https://cursor.com/docs/skills) when this comes up. ",
   "- Once invoked, the skill stays in the conversation'"'"'s context, so it applies to later turns until the user opts out.\n- Context compaction can summarize it away in a long chat. Invoke `/poteto-mode` again, or start each new task with it.\n- To have it on in every session, the README'"'"'s \"always on\" section imports it from `~/.claude/CLAUDE.md`.\n\n"],
  ["| Build a page whose buttons wake a Grok Bot over a webhook | [`/make-bot-ui`](../make-bot-ui/SKILL.md) |\n",
   ""],
  ["- `/simplify`, `control-cli`, and `control-ui` ship in the `cursor-team-kit` plugin.\n- `/loop` and `/create-skill` are Cursor built-ins.",
   "- `/simplify` and `/loop` are Claude Code built-ins. App driving comes from the project'"'"'s own `verify-<app>` skill, which `/create-verification-skill` generates.\n- Skill authoring uses the `skill-creator` skill from anthropics/skills when it is installed."],
  ["Without `/poteto-mode`, a phrase such as \"babysit this pr\" can start Cursor'"'"'s own skill for the same job instead.",
   "Without `/poteto-mode`, a phrase such as \"babysit this pr\" can start another plugin'"'"'s skill for the same job instead."],
  [", and mention once that a Custom Mode keeps it on.", "."],
  ["and Projects and automations that scale past one agent.", "and long-lived sessions and automations that scale past one agent."],
  ["Whether `/poteto-mode` stays on depends on how the user starts it:", "How long `/poteto-mode` stays on:"],
  ["That covers the legacy flat (`<id>.jsonl`), current nested (`<id>/<id>.jsonl`), and subagent (`<parent>/subagents/<child>.jsonl`) layouts. For each candidate, read the first JSONL line. Take the file whose `message.content[0].text` contains the conversation'"'"'s opening user prompt.",
   "There is one flat `<session-uuid>.jsonl` per session, and its subagents write under `<session-uuid>/subagents/`. For each candidate, read the first JSONL lines. Take the file whose earliest user message contains the conversation'"'"'s opening user prompt."],
  ["a chart or diagram from `/visualize`,", "a chart or diagram you render,"],
  ["and a `/visualize` chart for numbers.", "and a rendered chart (an SVG or image you generate from the data) for numbers."],
  ["pstack has no planning skill. Cursor'"'"'s Plan Mode works alongside it.",
   "pstack has no planning skill. Claude Code'"'"'s plan mode works alongside it."],
  ["| It was started with Enter. Start it as a Custom Mode, or start each task with `/poteto-mode`. |",
   "| Compaction summarized it away, or the user opted out. Invoke it again, or start each task with `/poteto-mode`. |"],
  ["The rule from `/setup-pstack` applies to new chats.",
   "The file from `/setup-pstack` applies to new chats."],
  ["which saves tokens when the chat runs on Auto or a cheaper model.",
   "which saves tokens when the chat runs on a cheaper model."],
);
for my $r (@rules) { my ($from, $to) = @$r; s/\Q$from\E/$to/g; }
s{re-read this playbook from trunk with `git show origin/main:pstack/([^`]+)`}{re-read this playbook from the installed pstack plugin (`cat \${CLAUDE_PLUGIN_ROOT}/$1`; the plugin install is the canonical copy, never a copy inside a work worktree)}g;
s{`git show origin/main:pstack/([^`]+)`}{`cat \${CLAUDE_PLUGIN_ROOT}/$1`}g;
s{## Build a bot UI with `/make-bot-ui`\n\n[^\n]*\n\n}{}g;
s{(- Nontrivial multi-step → write the throughput checkpoint \(Feature step 3\)\.\n)(?!- Scoping a delegate)}{$1- Scoping a delegate'"'"'s brief, a plan'"'"'s PR list, or a stack → the PR budget in `references/pr-budget.md`. Over budget means split at scoping time, never after the diff exists. The plugin hook denies an over-budget `gh pr create` or `gt submit`.\n}g;
'

leftovers=$(grep -rnE --exclude-dir=node_modules 'environment: "|/deslop|\.mdc\b|AskQuestion|\bTask tool|grok-[0-9]|gpt-5|claude-[a-z]+-[0-9]|cursor-team-kit|cloud_base_branch|\.cursor/|cursor-plugin|agent-transcripts|readonly: (true|false)|is_background|`create-skill`|`Task` (with|call)|pstack@cursor-plugins|cursor\.com/|make-bot-ui|Custom Mode|/visualize|/in-cloud' skills agents docs || true)
if [ -n "$leftovers" ]; then
  printf 'Cursor-specific text the rules did not port:\n%s\n' "$leftovers" >&2
  exit 1
fi
