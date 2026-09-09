#!/usr/bin/env bash
# Rewrites Cursor plumbing to Claude Code plumbing across skills/, agents/, and docs/.
# Run after merging a new upstream snapshot from cursor/plugins (README, "syncing with upstream").
# Idempotent: every rule's output contains none of its inputs.
set -euo pipefail
cd "$(dirname "$0")/.."

find skills agents docs -type f \( -name '*.md' -o -name '*.ts' -o -name '*.mjs' -o -name '*.sh' -o -name '*.yaml' \) -print0 |
  xargs -0 perl -0pi -e '
my $slug = q{`<slug>` is the absolute working directory, symlinks resolved, with every character that is not a letter or digit, including `/`, `.`, and `_`, replaced by `-`, so `/Users/you/proj` becomes `-Users-you-proj`};
my $verify = q{the project'"'"'s verification skill (`verify-<app>`, created by `/create-verification-skill`)};
my @rules = (
  # model slugs -> Claude tiers
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
  ["skeptical Bugbot triage", "skeptical review-bot triage (Cursor'"'"'s Bugbot, Claude Code'"'"'s `/code-review`, or similar)"],
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
);
for my $r (@rules) { my ($from, $to) = @$r; s/\Q$from\E/$to/g; }
s{re-read this playbook from trunk with `git show origin/main:pstack/([^`]+)`}{re-read this playbook from the installed pstack plugin (`cat \${CLAUDE_PLUGIN_ROOT}/$1`; the plugin install is the canonical copy, never a copy inside a work worktree)}g;
'
