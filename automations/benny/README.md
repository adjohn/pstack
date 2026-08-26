# benny

benny gives you two claude code scheduled agents for slack issue reports. one triages each report. the other reproduces confirmed bugs and may prepare a small draft fix.

the files in this directory are dormant setup and automation sources. the plugin does not auto-load `automations/`, so nothing here appears as a slash skill. setup-benny copies the pack's skills into a target project's `.claude/skills/`.

## set it up

1. point claude code at [`FOR_AGENTS.md`](./FOR_AGENTS.md) and name the target repository.
2. let setup merge this whole pack into the target's `.claude/skills/`. the three skill directories land at `.claude/skills/<name>/`; the pack docs and templates land under `.claude/skills/setup-benny/`. it must preserve destination-only files and review conflicts instead of overwriting local edits.
3. let setup enable pstack in the target repository's `.claude/settings.json` for shared dependencies:

```json
{
	"enabledPlugins": {
		"pstack@pstack": true
	}
}
```

4. keep user-owned configuration outside the copied pack, for example in `.claude/benny/`. adapt [`configuration.example.yaml`](./templates/configuration.example.yaml) and [`feature-map.example.md`](./skills/reproduce-and-fix-issues/references/feature-map.example.md).
5. commit `.claude/settings.json`, the copied benny skills, and any secret-free configuration before enabling either automation.
6. create each routine with the built-in `/schedule` skill and review its draft, or update existing routines through `/schedule`. the routines run on a cron cadence and scan the source channel for new reports; when a true post-time trigger matters, that needs a webhook-triggered ci job you build yourself, outside this pack's scope (a slack events bridge firing a github actions workflow that runs headless claude code, `claude -p`); the pack ships no template for it. then send a harmless test report and verify every source-channel post stays in the original thread.
