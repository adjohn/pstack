#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, uncommitted work, remote/PR state, and the most recent chat that
# operated in it. Emits a table sorted by size with a suggested bucket. Never
# deletes anything; deletion stays a human-gated step in the playbook.
#
# Usage: worktree-audit.sh [repo-path]   (defaults to the current repo)
set -u

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1

# Main worktree is the first entry; everything else is a candidate.
main_wt=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')

# The remote default branch drives the merge check. Best-effort; stale is fine
# for a first pass.
def=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
def=${def:-main}
git fetch origin "$def" --quiet 2>/dev/null || echo "warn: could not fetch origin/$def; merged column may be stale" >&2

# PR state by branch, fetched once. Empty if gh is unavailable.
prs=$(mktemp)
gh pr list --author "@me" --state all --limit 1000 \
	--json number,state,headRefName 2>/dev/null > "$prs" || echo "[]" > "$prs"

# Transcripts dir: ~/.claude/projects/<slug>, one .jsonl per session. The slug is
# the resolved path with every non-alphanumeric character replaced by "-".
slugify() { printf '%s' "$1" | sed 's#[^A-Za-z0-9]#-#g'; }
mtime() { perl -e 'my @s = stat($ARGV[0]); print $s[9] // 0' "$1" 2>/dev/null || echo 0; }
fmt_date() { perl -e 'my @t = localtime($ARGV[0]); printf "%04d-%02d-%02d", $t[5]+1900, $t[4]+1, $t[3]' "$1"; }
main_wt_real=$(cd "$main_wt" && pwd -P)
slug=$(slugify "$main_wt_real")
transcripts="$HOME/.claude/projects/$slug"
[ -d "$transcripts" ] || echo "warn: no transcripts dir at $transcripts; LAST_CHAT column may silently degrade" >&2
now=$(date +%s)

printf "SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_CHAT\tBUCKET\tWORKTREE\n"

git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
	[ "$wt" = "$main_wt" ] && continue

	size=$(du -sh "$wt" 2>/dev/null | awk '{print $1}')
	head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( (now - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of main, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	git merge-base --is-ancestor "$head" "origin/$def" 2>/dev/null && merged=YES || merged=no

	# Distinguish real WIP (tracked edits) from disposable untracked scratch.
	porcelain=$(git -C "$wt" status --porcelain 2>/dev/null)
	if [ -z "$porcelain" ]; then dirty=clean
	elif printf '%s\n' "$porcelain" | grep -qv '^??'; then
		dirty="wip:$(printf '%s\n' "$porcelain" | grep -cv '^??')"
	else dirty="scratch:$(printf '%s\n' "$porcelain" | grep -c '^??')"; fi

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")
	if [ -z "$branch" ]; then remote=detached
	elif git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		[ "$(git -C "$wt" rev-parse "origin/$branch" 2>/dev/null)" = "$head" ] \
			&& remote=pushed \
			|| remote="ahead$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null)"
	else remote=no-remote; fi

	pr=$([ -n "$branch" ] && jq -r --arg b "$branch" \
		'.[] | select(.headRefName==$b) | "#\(.number)/\(.state)"' "$prs" 2>/dev/null | head -1)
	[ -z "$pr" ] && pr="-"

	# Most recent chat whose transcript operated in this worktree. Match path
	# followed by "/" or a quote so glint-482 does not match glint-482-r37.
	last="-"; last_ts=0
	if [ -d "$transcripts" ]; then
		if command -v rg >/dev/null 2>&1; then
			files=$(rg -l -e "${wt}/" -e "${wt}\"" "$transcripts" 2>/dev/null)
		else
			files=$(grep -rl -e "${wt}/" -e "${wt}\"" "$transcripts" 2>/dev/null)
		fi
		for f in $files; do
			ts=$(mtime "$f")
			[ "$ts" -gt "$last_ts" ] && last_ts=$ts
		done
	fi
	# A session launched with cwd inside the worktree writes its transcript under
	# the worktree's own slug dir, not the main repo's. Check that too.
	wslug=$(slugify "$(cd "$wt" && pwd -P)")
	wdir="$HOME/.claude/projects/$wslug"
	if [ -d "$wdir" ]; then
		for f in "$wdir"/*.jsonl; do
			[ -e "$f" ] || continue
			ts=$(mtime "$f")
			[ "$ts" -gt "$last_ts" ] && last_ts=$ts
		done
	fi
	[ "$last_ts" -gt 0 ] && last=$(fmt_date "$last_ts")
	recent=$([ "$last_ts" -gt 0 ] 2>/dev/null && [ $(( (now - last_ts) / 86400 )) -le 4 ] && echo yes || echo no)

	case "$dirty" in wip:*) bucket=hold-wip ;; *)
		case "$pr" in *OPEN*) bucket=hold-open-pr ;; *)
			if [ "$recent" = yes ]; then bucket=verify-recent-chat
			elif [ "$merged" = YES ] || [ "$pr" != "-" ]; then bucket=safe
			else bucket=review; fi ;;
		esac ;;
	esac

	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$bucket" "$wt"
done | sort -t$'\t' -k1,1 -rh

rm -f "$prs"
