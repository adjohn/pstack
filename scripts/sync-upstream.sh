#!/usr/bin/env bash
# Pulls a new upstream pstack into the port: snapshots it onto upstream-vendor,
# merges that into the current branch with the README's conflict policy, runs
# port-from-cursor.sh, bumps the manifests, and runs the tests.
#
# Usage: scripts/sync-upstream.sh [upstream-ref]   (default: main of cursor/plugins)
# Exit codes: 0 synced and green, 3 already up to date, 1 needs a person
# (leftover Cursor text, a failing test, or an unresolved conflict).
# Leaves the merge uncommitted so the caller reviews it, then commits.
set -euo pipefail
cd "$(dirname "$0")/.."

ref="${1:-main}"
hand_maintained=(README.md plugin.json .claude-plugin/plugin.json skills/setup-pstack/SKILL.md
	skills/poteto-mode/scripts/worktree-audit.sh)
not_shipped=(.cursor-plugin assets skills/make-bot-ui docs/harness)

[ -z "$(git status --porcelain)" ] || { echo "error: working tree is not clean" >&2; exit 1; }
branch=$(git symbolic-ref --short HEAD)
work=$(mktemp -d)
trap 'git worktree remove --force "$work/vendor" 2>/dev/null || true; rm -rf "$work"' EXIT

git clone --quiet --filter=blob:none --sparse --no-checkout https://github.com/cursor/plugins.git "$work/plugins"
git -C "$work/plugins" sparse-checkout set pstack
git -C "$work/plugins" checkout --quiet "$ref"
upstream_head=$(git -C "$work/plugins" rev-parse --short "$ref")
last_touch=$(git -C "$work/plugins" log -1 --format=%h "$ref" -- pstack)
last_pr=$(git -C "$work/plugins" log -1 --format=%s "$ref" -- pstack | grep -oE '\(#[0-9]+\)$' || true)
version=$(node -p 'require(process.argv[1]).version' "$work/plugins/pstack/.cursor-plugin/plugin.json")

git fetch --quiet origin upstream-vendor
vendored=$(git log -1 --format=%s origin/upstream-vendor | sed -n 's/.*cursor\/plugins@\([0-9a-f]*\).*/\1/p')
if [ -n "$vendored" ] && [ "$(git -C "$work/plugins" rev-parse --verify --quiet "$vendored^{commit}" || true)" = "$(git -C "$work/plugins" rev-parse "$last_touch")" ]; then
	echo "up to date: upstream-vendor already holds cursor/plugins@$last_touch (pstack $version)"
	exit 3
fi
old_vendor=$(git rev-parse origin/upstream-vendor)

git worktree add --quiet -B upstream-vendor "$work/vendor" origin/upstream-vendor
find "$work/vendor" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$work/plugins/pstack/." "$work/vendor/"
git -C "$work/vendor" add -A
git -C "$work/vendor" commit --quiet -F - <<EOF
Import pstack from cursor/plugins@$last_touch (upstream v$version, MIT, Lauren Tan)

Pure snapshot of the pstack/ directory at cursor/plugins $upstream_head. Last
pstack-touching upstream commit is $last_touch${last_pr:+ $last_pr}.
EOF
echo "upstream-vendor: $(git rev-parse --short upstream-vendor) imports pstack $version"

git merge --no-commit --no-ff upstream-vendor >/dev/null 2>&1 || true
git rev-parse --verify --quiet MERGE_HEAD >/dev/null || { echo "error: merge of upstream-vendor did not start" >&2; exit 1; }

is_hand_maintained() { local f; for f in "${hand_maintained[@]}"; do [ "$f" = "$1" ] && return 0; done; return 1; }
unresolved=()
while IFS= read -r f; do
	[ -n "$f" ] || continue
	stages=$(git ls-files -u -- "$f" | awk '{print $3}' | sort -u | tr -d '\n')
	if is_hand_maintained "$f"; then
		git checkout --ours -- "$f" && git add -- "$f"
	elif [ "$stages" = 123 ]; then
		git show ":1:$f" > "$work/base"; git show ":2:$f" > "$work/ours"; git show ":3:$f" > "$work/theirs"
		git merge-file --theirs -p "$work/ours" "$work/base" "$work/theirs" > "$f"
		git add -- "$f"
	elif [ "$stages" = 13 ] || [ "$stages" = 12 ]; then
		git rm --quiet -- "$f"
	else
		unresolved+=("$f ($stages)")
	fi
done < <(git diff --name-only --diff-filter=U)
for f in "${hand_maintained[@]}"; do
	git cat-file -e "HEAD:$f" 2>/dev/null && git checkout HEAD -- "$f"
done
for p in "${not_shipped[@]}"; do git rm -r -f --quiet --ignore-unmatch -- "$p"; rm -rf -- "$p"; done

status=0
if [ ${#unresolved[@]} -gt 0 ]; then
	printf 'unresolved conflicts:\n'; printf '  %s\n' "${unresolved[@]}"; status=1
fi
for f in plugin.json .claude-plugin/plugin.json; do
	node -e 'const fs=require("fs"),f=process.argv[1],j=JSON.parse(fs.readFileSync(f,"utf8"));j.version=process.argv[2];fs.writeFileSync(f,JSON.stringify(j,null,f.startsWith(".")?"\t":2)+"\n")' "$f" "$version"
done
node -e 'const fs=require("fs"),f=process.argv[1],j=JSON.parse(fs.readFileSync(f,"utf8"));if(!/\bpr-size\b/.test(j.scripts.test)){j.scripts.test=j.scripts.test.replace(/^bun test /,"bun test pr-size ");fs.writeFileSync(f,JSON.stringify(j,null,2)+"\n")}' skills/poteto-mode/scripts/package.json
bash scripts/port-from-cursor.sh || status=1
git add -A

echo "upstream changes to hand-maintained files (port these by hand):"
for f in "${hand_maintained[@]}"; do
	case "$f" in .claude-plugin/*) continue ;; esac
	git --no-pager diff --stat "$old_vendor" upstream-vendor -- "$f"
done

(cd skills/poteto-mode/scripts && bun install --frozen-lockfile >/dev/null && bun run test && bun run typecheck) || status=1
# The launcher's relative-symlink test misresolves under macOS's symlinked /var tmpdir.
(cd skills/statechart/scripts && npm install --no-package-lock --no-audit --no-fund && TMPDIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)" npm test) >/dev/null || { echo "statechart tests failed" >&2; status=1; }

echo "branch $branch: merge of pstack $version staged, not committed; exit $status"
echo "after review: commit, then push both upstream-vendor and $branch"
exit $status
