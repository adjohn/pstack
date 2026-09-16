#!/bin/sh
input=$(cat)
sep='( |\\[tnr])+'
printf '%s' "$input" | grep -qE "gh${sep}pr${sep}create|gt${sep}(submit|ss)|git${sep}commit" || exit 0
printf '%s' "$input" | exec node "$(dirname "$0")/pr-size-gate.mjs"
