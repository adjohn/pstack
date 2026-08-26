---
name: setup-pstack
description: Configure which models pstack uses per role. Detects your available models and writes an always-loaded memory file that overrides the skill defaults. Use for /setup-pstack, "configure pstack models", or changing pstack's model choices.
---

# Setup pstack

Write `~/.claude/pstack-models.md`, an always-loaded override file that sets pstack's model per role, imported into every session from `~/.claude/CLAUDE.md`. The skills read it and fall back to their inline defaults when a line is absent, so this is an override layer, not a requirement.

## Steps

### 1. Detect available models

Start from the documented model aliases as candidates: `haiku`, `sonnet`, `opus`, and `fable`. Full model IDs also work when the user's account exposes them. There is no in-session API that lists the user's entitled models, so where availability is uncertain (`fable`, full model IDs), either test-spawn a one-line background subagent per candidate and treat a slug-rejection error as unavailable, or ask the user which models their account has. If you cannot confirm any, ask the user to paste the slugs they have access to. Never write a real slug you have not confirmed is available. The aliases `inherit-parent` and `auto` are always valid even though they are not detected slugs.

### 2. Load current state

The default role-to-model mapping is the file shape shown in step 5 below. If `~/.claude/pstack-models.md` already exists, read it and treat its values as the current choices. Otherwise start from those defaults.

### 3. Map and confirm

Show every role with its current model, marking any real slug not in the detected set as needing a choice. Ask whether to accept as-is or change specific roles, offering the detected models plus `inherit-parent` and `auto` (both mean: this role runs on the parent chat model, which is how users on the default model setting stay on it) as the options. Prefer AskUserQuestion over free text. For panel roles (how critics, arena runners, architect runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena selects one value from it whose model tier differs from the parent's when possible. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every real slug written must be in the detected set; `inherit-parent` and `auto` always pass. If a chosen real slug is not available, stop and ask again. An override file pointing at a model the user cannot use breaks every delegation that reads it.

### 5. Write the override file

Write `~/.claude/pstack-models.md` with one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. Shape:

```
# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit the Agent `model`). Alias entries in a panel list still count toward its fan-out.
feature, refactoring: haiku
bug-fix: sonnet
perf-issue: sonnet
hillclimb: sonnet
judgment and prose: fable
hardest tasks: fable
how explorer: haiku
how explainer: fable
how critics: fable, sonnet, haiku, opus
why investigators: haiku
why synthesizer: fable
reflect tooling: sonnet
reflect judgment, divergent, synthesizer: fable
arena runners: fable, sonnet, haiku, opus
arena cross-judge pool: fable, sonnet, haiku, opus
swarm workers: haiku
architect runners: fable, sonnet, haiku, opus
interrogate reviewers: fable, sonnet, haiku, opus
```

Then make it always loaded: read `~/.claude/CLAUDE.md` (create it if it does not exist) and add the line `@~/.claude/pstack-models.md` if it is not already present. That memory import pulls the file into every session. Adding the line is idempotent: skip it when it is already there, and never duplicate it.

### 6. Confirm

Tell the user the override file was written, that `~/.claude/CLAUDE.md` imports it, and that it applies to new sessions. Re-running this skill updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /create-verification-skill." On yes, invoke `/create-verification-skill` (resolves wherever pstack is installed — workspace, user, or plugin). On no, move on without pushing.
