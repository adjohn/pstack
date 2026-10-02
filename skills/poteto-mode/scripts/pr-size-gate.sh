#!/bin/sh
input=$(cat)
printf '%s' "$input" | grep -qE '\b(gh|gt|git)\b' || exit 0
if ! command -v node >/dev/null 2>&1; then
	if printf '%s' "$input" | grep -q '"PreToolUse"' && ! printf '%s' "$input" | grep -q 'PSTACK_PR_SIZE_OK=1'; then
		printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"pstack PR budget: node is not on PATH, so the pstack PR size gate cannot run. Install node or prefix the command with PSTACK_PR_SIZE_OK=1."}}'
	fi
	exit 0
fi
printf '%s' "$input" | exec node "$(dirname "$0")/pr-size-gate.mjs"
