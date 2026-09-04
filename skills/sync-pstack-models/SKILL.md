---
name: sync-pstack-models
description: Cross-check ~/.claude/pstack-models.md against Preflight's own observed model performance and suggest data-backed updates, one role at a time. Use for /sync-pstack-models, "check my pstack config against real data", or after Preflight surfaces a model_selection recommendation.
---

# Sync pstack models

`pstack-models.md` is a declared belief: someone decided once that bug-fix work goes to a given model. This skill checks a handful of those beliefs against [Preflight](https://github.com/newrelic-experimental/preflight)'s own recorded outcomes for the same person, and only proposes a change where the data actually disagrees. It never regenerates the whole file — most roles in it (the panel roles, judgment and prose, hardest tasks) don't correspond to anything Preflight measures, and this skill has no opinion about those. It edits at most a couple of lines, one at a time, always with the human's confirmation.

## Steps

### 1. Check Preflight is connected

Confirm the `nr_observe_get_model_recommendation` MCP tool is available (ToolSearch it, or attempt the call). If it's missing, either Preflight isn't installed for this project or the installed version predates the feature. Say so plainly and stop. This is a normal, silent exit for the common case of someone running pstack without Preflight, not an error.

### 2. Get the data

Call `nr_observe_get_model_recommendation` with no arguments to get the aggregate report across the user's full history: `ranked`, `recommendedModel`, `confidence`, and `byOutcome` (one ranking per task outcome type: `bug_fix`, `feature`, `refactor`, `investigation`, `configuration`, `documentation`, `failed_attempt`).

### 3. Read the current config

Read `~/.claude/pstack-models.md`. If it doesn't exist, tell the user to run `/setup-pstack` first and stop.

### 4. Map roles to outcomes — conservatively

Only these roles have a real correspondence to a Preflight outcome type. Every other role (the panel roles, `judgment and prose`, `hardest tasks`, `swarm workers`, and so on) is about a model's *character* — judgment versus mechanical, fast versus careful — not a task category, and Preflight doesn't measure that axis. Don't invent a mapping for them.

- `bug-fix` → Preflight's `bug_fix` outcome
- `feature, refactoring` → Preflight's `feature` and `refactor` outcomes. Only compare if both agree on the same top model; if they point at different models, the role is genuinely ambiguous and there's nothing confident to suggest.

### 5. Compare, using Preflight's own confidence bar

For each mapped role, compare its current model against the matching outcome's `recommendedModel`. Skip the role entirely (no output, no question) when any of these hold: the values already match, `confidence` isn't `'high'`, or `recommendedModel` is `null`. High confidence already means, per Preflight's own gating, a real gap between the top two models backed by real sample size on both sides — don't add a second threshold on top of it.

### 6. Propose changes, one role at a time

For each real mismatch, use `AskUserQuestion` (not free text) showing the current value, the suggested value, and the evidence straight from the report — session counts and average efficiency scores for both models, never a number you didn't get from the tool. Something like: "`bug-fix` is currently `sonnet`. Across 12 of your sessions, `opus` averaged a higher efficiency score (0.81 vs 0.68). Update it?" Offer per-role yes/no; if there are several mismatches, ask about each rather than bundling into one accept-all.

### 7. Apply confirmed changes

For each accepted change, edit only that one line in `~/.claude/pstack-models.md` — replace the model value after the role's colon, leave every other line and comment byte-for-byte untouched. This is a targeted edit, not a regenerate: unlike `/setup-pstack`, this skill only ever knows about two of the roles in that file, and overwriting the rest from memory would risk losing values it was never told.

### 8. Report

State plainly what changed, what was checked but already matched or lacked confidence, and that the file takes effect on new sessions (same as any other `pstack-models.md` edit).

## Notes

- This is the fork-side half of a two-part idea; see [Preflight issue #579](https://github.com/newrelic-experimental/preflight/issues/579) for the upstream Preflight side and #580 for the companion publish mechanism.
- Deliberately small: it edits, at most, the `bug-fix` and `feature, refactoring` lines, and only on explicit confirmation. Widening the role-to-outcome mapping is future work once this proves useful in practice.
- Porting to the original Cursor-based pstack: per this repo's own README port table, swap `AskUserQuestion` for `AskQuestion` and the config path for `~/.cursor/rules/pstack-models.mdc`. The `nr_observe_get_model_recommendation` MCP call itself needs no change — Preflight supports Cursor as a full-hooks platform, so the same tool call works there unmodified.
