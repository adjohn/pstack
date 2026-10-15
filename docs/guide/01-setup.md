# Set up pstack

In this page you install the plugin, pick which models pstack uses, and run your first task. Setup is a couple of commands plus a short conversation.

## Install the plugin

In a Claude Code session, run:

```text
/plugin marketplace add adjohn/pstack
/plugin install pstack@pstack
```

Or from your shell:

```bash
claude plugin marketplace add adjohn/pstack
claude plugin install pstack@pstack
```

`claude plugin list` shows `pstack@pstack` as enabled after the install.

To install from a local clone instead, register the checkout as the marketplace with `claude plugin marketplace add /absolute/path/to/pstack`, then run `claude plugin install pstack@pstack`. The path is the directory containing `.claude-plugin/marketplace.json`, and the marketplace name in `pstack@pstack` comes from the `name` field in that file.

Prerequisites:

- Claude Code 2.x.
- Node.js on your PATH. The PR size hook runs on `node`. Without it, `gh pr create` and `gt submit` are refused until you install node or prefix the command with `PSTACK_PR_SIZE_OK=1`. Commits are unaffected.
- The `gh` CLI, for the PR playbooks (opening a PR, babysit, shipping).
- Graphite's `gt`, optional, for stacked PRs.

## Pick your models

Run:

```text
/setup-pstack
```

[`/setup-pstack`](../../skills/setup-pstack/SKILL.md) detects the models you have access to, asks for a reasoning budget, shows you each role (code delegates, judgment, the review panels), and asks what you want. Answer the questions. It writes `~/.claude/pstack-models.md`, a small config file every pstack skill reads, and adds the line `@~/.claude/pstack-models.md` to `~/.claude/CLAUDE.md` so the file is always loaded.

The defaults leave each model at its own reasoning effort, the same as the `unlimited` budget. `large`, `medium`, and `small` set one session-wide effort level, `xhigh`, `high`, or `medium`, in `~/.claude/settings.json`. Lower levels spend fewer tokens.

You only override what you care about. A role with no line in the file keeps the skill's default. To restore a default, delete that role's line. A rerun of `/setup-pstack` keeps any role whose model differs from the default. When a default changes, a file written before the change still pins the old default, so delete those role lines, or delete the file, then run `/setup-pstack` again.

You might be wondering what happens if you use Auto. Set a role to `inherit-parent` or `auto` and pstack omits the subagent `model` field, so the subagent inherits your parent chat model. Both values mean the same thing, and neither is a model slug. For a panel role the value is a list, and one subagent runs per entry, so the list length sets the panel size. Setup also configures `swarm workers`, the default model for every `/swarm` worker unless a race names a model for each arm.

## Accept the verification offer, or don't

At the end of setup, `/setup-pstack` looks for a way to prove app behavior in your project, either a `verify-*` skill or an existing harness. If it finds neither, it offers once to generate one with [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md).

Say yes and it writes `.claude/skills/verify-<app>/`, a project-local skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. Say no and setup moves on. You can run `/create-verification-skill` yourself any time. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers it in depth.

If you're new to pstack, say yes. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

After setup, start a new session. The model config applies to new sessions.

## Keep the cost in check

pstack spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Rerun `/setup-pstack` and pick a smaller reasoning budget or cheaper models. A strong model in the main chat with cheaper, faster models in the code roles is a good split.
- Set a role to `auto` or `inherit-parent` so it runs on the chat's own model.
- Shorten a panel list. Each entry runs one subagent.
- Save `/poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. `/poteto-mode` attaches the skill to the message it starts, and it fades as the session moves on. To keep it in context on every turn, use the always-on setup in the [README](../../README.md#always-on), or start each new task with `/poteto-mode`.

Next: [Route work through `/poteto-mode`](./02-poteto-mode.md).
