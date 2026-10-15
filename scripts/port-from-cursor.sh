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

  # 0.15.25: these rules match text the rules above already rewrote, so they stay last
  # Grok/Composer family fallbacks and the xhigh default slug -> Claude tiers
  ["If the Agent tool rejects a configured entry, run that seat on its family'"'"'s default and say so. Families go by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refused `composer-*` entry runs on `haiku`. With no family match, use `claude-opus-5-5-xhigh`. If it rejects a default, use the closest valid slug of the same family from its error message.",
   "If the Agent tool rejects a configured entry, run that seat on `opus` and say so."],
  ["If the Agent tool rejects a configured entry, run that reviewer on its family'"'"'s table default and say so. Families go by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refused `composer-*` entry runs on Reviewer B'"'"'s default. With no family match, use Reviewer A'"'"'s default. If it rejects a table default,",
   "If the Agent tool rejects a configured entry, run that reviewer on Reviewer A'"'"'s default and say so. If it rejects a table default,"],
  ["(prefer the same family and reasoning tier)", "(prefer the nearest Claude tier)"],
  ["claude-opus-5-5-xhigh", "opus"],

  # readonly flag and Cursor MCP discovery -> prompt instruction and Claude Code MCP surface
  ["Every spawn is a subagent with `subagent_type: general-purpose` and `readonly: true`.",
   "Every spawn is a read-only subagent with `subagent_type: general-purpose`: its prompt forbids file writes and mutating commands."],
  ["Each reviewer gets `subagent_type: general-purpose`, `readonly: true`, and",
   "Each reviewer gets `subagent_type: general-purpose`, a prompt that forbids file writes and mutating commands, and"],
  [", and readonly strips MCPs.", ". Subagents inherit MCP tools by default."],
  ["Every spawn is `general-purpose` with `readonly: false` (agent mode). **Do not use readonly/Ask mode.** It strips MCP access, which disables the MCP-backed investigators and the synthesizer'"'"'s citation spot-checks. Investigators still shouldn'"'"'t write anything.",
   "Every spawn is `general-purpose`. Subagents inherit MCP tools by default, which the MCP-backed investigators and the synthesizer'"'"'s citation spot-checks need. Investigators must not write anything. That'"'"'s an instruction in their prompt, not a sandbox."],
  ["list the available MCPs from the Cursor environment. Use the available-tools map when present. Otherwise inspect the `mcps/` directory Cursor exposes for enabled MCP servers.",
   "list the MCP servers available in the session (`claude mcp list`, or the `mcp__*` tools visible in-session)."],
  ["(open files, recent edits, cursor location, what was just discussed)", "(recent edits and what was just discussed)"],

  # cloud workers and cursor-team-kit control skills -> worktrees and verify-<app>
  ["pass `cloud_base_branch`.", "say so in its brief: it checks out that branch first, in its own worktree (`git worktree add <dir> origin/<branch>`)."],
  ["**Control skill.** Pick it by surface. Browser, Electron, and web UIs use `control-ui` from `cursor-team-kit`. CLIs and TUIs use `control-cli` from `cursor-team-kit`.",
   "**Verification skill.** Pick it by surface. Browser, Electron, web UIs, CLIs, and TUIs use $verify."],
  ["A surface with no control skill is", "A surface with no verification skill is"],
  ["Each live lane runs on its own cloud VM at the PR head. Drive through `control-ui` or `control-cli` from `cursor-team-kit`.",
   "Each live lane runs as its own background worker in its own worktree or checkout at the PR head. Drive through the project'"'"'s verification skill (`verify-<app>`)."],
  ["its verification skill (such as `control-ui` or `control-cli` from `cursor-team-kit`)", $verify],
  ["Run `/simplify` from `cursor-team-kit`", "Run Claude Code'"'"'s built-in `/simplify`"],
  ["`/simplify` ships in the `cursor-team-kit` plugin, not in pstack.", "`/simplify` is a Claude Code built-in, not part of pstack."],
  [", not Cursor'"'"'s built-in babysit skill, whose description matches the same words.", "."],
  ["a Cursor restart", "a Claude Code restart"],

  # transcripts, plugin paths, and tool names in reflect and its reviewer prompts
  ["find this conversation'"'"'s transcript in the `agent-transcripts/` directory the system prompt names.",
   "find this conversation'"'"'s transcript under `~/.claude/projects/<slug>/`, one `.jsonl` per session with one JSON message per line, where $slug. Derive the directory from the current working directory."],
  ["(under `.claude/skills/`, `~/.claude/skills/`, or `~/.cursor/plugins/`), a `Task` prompt naming its path, or a tool call (Shell, Grep, MCP, etc.) matching its documented commands.",
   "(under `.claude/skills/`, `~/.claude/skills/`, or `~/.claude/plugins/`), an `Agent` prompt naming its path, a `Skill` tool call naming it (a skill invoked that way never shows a `SKILL.md` Read), or a tool call (Bash, Grep, MCP, etc.) matching its documented commands."],
  ["Re-read the execution playbook from trunk.", "Re-read the execution playbook from the installed pstack plugin."],

  # Cursor'"'"'s /visualize -> plain charts; setup-pstack'"'"'s default budget is the fork'"'"'s unlimited
  ["a chart or diagram from `/visualize`", "a chart"],
  ["a `/visualize` chart for numbers", "a chart for numbers"],
  ["With no rule, say that `large` matches the skill defaults.", "With no file, say that `unlimited` matches the skill defaults."],

  # poteto-agent plugin lookup; guide pages: Custom Modes, cloud subagents, Cursor Projects, make-bot-ui
  ["and every Task spawn.",
   "and every Agent spawn."],
  ["search `~/.cursor/plugins/` for a file whose path ends in `skills/poteto-mode/SKILL.md`. If more than one file matches, use the copy whose `.cursor-plugin/plugin.json` has the highest `version`.",
   "search `~/.claude/plugins/` for a file whose path ends in `skills/poteto-mode/SKILL.md`. If more than one file matches, use the copy whose `.claude-plugin/plugin.json` has the highest `version`."],
  ["The defaults run at `xhigh` reasoning, the same as the `large` budget. `unlimited` lifts each model to its highest tier, up to `max`. Opus goes to `max`. Grok tops out at `xhigh`, so it stays there. `medium` and `small` lower the reasoning and spend fewer tokens.",
   "The defaults leave each model at its own reasoning effort, the same as the `unlimited` budget. `large`, `medium`, and `small` set one session-wide effort level, `xhigh`, `high`, or `medium`, in `~/.claude/settings.json`. Lower levels spend fewer tokens."],
  ["a rule written before the change",
   "a file written before the change"],
  ["To keep `/poteto-mode` on for the whole chat, pick it from the `/` menu with Option+Enter (Mac) or Alt+Enter (Windows) instead of Enter. That makes it a [Custom Mode](https://cursor.com/docs/skills), which stays in context on every turn until you exit it. Custom Modes are available in the Agents Window and the CLI. Plain Enter attaches the skill to one message, and it fades as the chat moves on.",
   "`/poteto-mode` attaches the skill to the message it starts, and it fades as the session moves on. To keep it in context on every turn, use the always-on setup in the [README](../../README.md#always-on), or start each new task with `/poteto-mode`."],
  ["and a Custom Mode keeps `/poteto-mode` in context on every turn.",
   "and the always-on setup keeps `/poteto-mode` in context on every turn."],
  ["The cleanest isolation is a [cloud subagent](https://cursor.com/docs/subagents#cloud-subagents). Each one gets its own VM and branch, so it can install dependencies, run your app, and record video of the result without touching your machine. Type `/in-cloud` before the task, or ask the parent chat to hand work to cloud subagents.",
   "The cleanest isolation is a [Claude Code cloud session](https://code.claude.com/docs/en/claude-code-on-the-web). Each one gets its own VM and branch, so it can install dependencies and run your app without touching your machine."],
  ["an isolated worktree or cloud agent,",
   "an isolated worktree or cloud session,"],
  ["A [Cursor Project](https://cursor.com/blog/projects) gives one coordinator agent a persistent thread. The coordinator doesn'"'"'t write code. It directs subagents, which run in the cloud by default, so the work continues when your laptop is closed.",
   "A long-running Claude Code session gives one coordinator agent a persistent thread. The coordinator doesn'"'"'t write code. It directs subagents. Run the coordinator as a cloud session and the work continues when your laptop is closed."],
  ["Run them as cloud agents, or say \"own worktree per attempt\".",
   "Say \"own worktree per attempt\", or run them as cloud sessions."],
  ["## Build a bot UI with `/make-bot-ui`\n\nOne situational skill is for Grok Bot users. [`/make-bot-ui`](../../skills/make-bot-ui/SKILL.md) builds a small page whose buttons wake a bot over a webhook routine. For example, you could swipe through a review queue and have each swipe ask the bot to act on that item. A server on your machine holds the webhook'"'"'s sender key, so the key never reaches the browser or the chat. The skill also covers exposing the page on Tailscale.\n\n",
   ""],

  # per-spawn effort and fast-mode picks (Cursor slug suffixes) -> model tier per spawn
  ["**Match the model to the job.** Before each spawn, start from the role'"'"'s line or default and pick the reasoning level and speed the job needs. The `/setup-pstack` budget sets each role'"'"'s starting level, xhigh by default. Raise it one step, up to max, for the hardest or subtlest work. Lower it one step for judgment and two or more steps for routine work. Use fast mode only when the job is urgent, meaning CI or trunk is red or a person is blocked on the result right now. Otherwise use standard speed, the same slug without `-fast`. Verification is the exception and stays on the `swarm workers` model and speed (`haiku` by default). Change only the effort level and whether the slug is fast, and keep the family the role names, so a diverse panel stays diverse. If the family has no slug at that level and speed, use its nearest slug. A role on `auto` or `inherit-parent` stays on the parent model. If the Agent tool rejects the adjusted slug, do not try another adjusted slug. Use the role'"'"'s line or default and say so.",
   "**Match the model to the job.** Before each spawn, start from the role'"'"'s line or default. The `Agent` tool takes only a model, and reasoning effort follows the session (the `/setup-pstack` budget), so match the job by tier. Move a single-model role up one tier, such as `sonnet` to `opus`, only for the hardest or subtlest work, and keep routine work on the role'"'"'s model. Keep panel entries as configured, so a diverse panel stays diverse. Verification is the exception and stays on the `swarm workers` model (`haiku` by default). A role on `auto` or `inherit-parent` stays on the parent model. If the Agent tool rejects a model, use the role'"'"'s line or default and say so."],
  ["Pick each subagent'"'"'s reasoning level and fast or standard speed for the job",
   "Pick each subagent'"'"'s model tier for the job"],
  ["Spawn `Task` with `subagent_type: \"pstack:comment-sicko\"`.",
   "Spawn Comment Sicko with `Agent` (the subagent-launching tool) and `subagent_type: \"pstack:comment-sicko\"`."],
  ["Reviewers return findings in the `Task` response body.",
   "Reviewers return findings in the `Agent` response body."],
  ["cloud-agent URL",
   "cloud session URL"],
);
for my $r (@rules) { my ($from, $to) = @$r; s/\Q$from\E/$to/g; }
s{re-read this playbook from trunk with `git show origin/main:pstack/([^`]+)`}{re-read this playbook from the installed pstack plugin (`cat \${CLAUDE_PLUGIN_ROOT}/$1`; the plugin install is the canonical copy, never a copy inside a work worktree)}g;
s{`git show origin/main:pstack/([^`]+)`}{`cat \${CLAUDE_PLUGIN_ROOT}/$1`}g;
'

leftovers=$(grep -rnE --exclude-dir=node_modules 'environment: "|/deslop|\.mdc\b|AskQuestion|\bTask tool|grok-[0-9]|gpt-5|claude-[a-z]+-[0-9]|cursor-team-kit|cloud_base_branch|`Task`|fast or standard speed|/visualize|Custom Mode' skills agents docs || true)
if [ -n "$leftovers" ]; then
  printf 'Cursor-specific text the rules did not port:\n%s\n' "$leftovers" >&2
  exit 1
fi
