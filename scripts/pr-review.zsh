#!/usr/bin/env zsh
# gr <github-pr-url>: persistent PR worktree with nvim, Pi review, and lazygit.
emulate -LR zsh
setopt pipefail

# Compatibility with the earlier opt-in flag; trust now runs by default.
[[ "$1" == --trust ]] && shift
if (( $# != 1 )) || [[ ! "$1" =~ '^https://github\.com/([A-Za-z0-9-]+)/([A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)(/[^?#]*)?([?#].*)?$' ]]; then
    print -u2 'Usage: gr <https://github.com/owner/repo/pull/number>'
    exit 1
fi
local owner="$match[1]" repo="$match[2]" number="$match[3]"
[[ "$repo" != . && "$repo" != .. ]] || exit 1
for dependency in git gh tmux nvim pi lazygit; do
    command -v "$dependency" >/dev/null 2>&1 || {
        print -u2 "Missing dependency: $dependency"
        exit 1
    }
done

local metadata
metadata=$(gh api "repos/$owner/$repo/pulls/$number" --jq '.base.ref, .head.ref, .head.repo.full_name, .title') || exit 1
local fields=("${(@f)metadata}")
local base="$fields[1]" branch="$fields[2]" head_repo="$fields[3]" title="$fields[4]"
if [[ -z "$head_repo" || "$head_repo" == null ]]; then
    print -u2 'The PR source repository no longer exists.'
    exit 1
fi
git check-ref-format "refs/heads/$branch" || exit 1
git check-ref-format "refs/heads/$base" || exit 1

# Git metadata and checked-out files both need to survive macOS temp cleanup.
local storage="${GR_DIR:-$HOME/.local/share/gr}"
local root="$storage/${owner:l}/${repo:l}"
local clone="$root/repo"
local worktree="$root/pr-$number"
local session="gr-${owner}-${repo//./_}-${number}"
mkdir -p "${clone:h}" "${worktree:h}" || exit 1
if [[ ! -e "$clone" ]]; then
    gh repo clone "$owner/$repo" "$clone" -- --no-checkout || exit 1
fi
git -C "$clone" rev-parse --git-dir >/dev/null || exit 1
git -C "$clone" fetch origin \
    "+refs/pull/$number/head:refs/remotes/origin/pr/$number" \
    "+refs/heads/${base}:refs/remotes/origin/$base" || exit 1

if [[ ! -e "$worktree" ]]; then
    if git -C "$clone" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$clone" worktree add "$worktree" "$branch" || exit 1
    else
        git -C "$clone" worktree add -b "$branch" "$worktree" "refs/remotes/origin/pr/$number" || exit 1
    fi
fi
git -C "$worktree" rev-parse --git-dir >/dev/null || exit 1
local current
current=$(git -C "$worktree" branch --show-current) || exit 1
if [[ "$current" != "$branch" ]]; then
    print -u2 "Worktree is on '$current', expected '$branch'. Leaving it unchanged."
    exit 1
fi

# A real source-branch upstream supports both git pull and lazygit, even for forks.
local remote=origin
if [[ "${head_repo:l}" != "${owner:l}/${repo:l}" ]]; then
    remote="pr-$number"
    local origin_url head_url
    origin_url=$(git -C "$clone" remote get-url origin) || exit 1
    case "$origin_url" in
        git@*|ssh://*) head_url="git@github.com:$head_repo.git" ;;
        *) head_url="https://github.com/$head_repo.git" ;;
    esac
    if git -C "$clone" remote get-url "$remote" >/dev/null 2>&1; then
        git -C "$clone" remote set-url "$remote" "$head_url" || exit 1
    else
        git -C "$clone" remote add "$remote" "$head_url" || exit 1
    fi
fi
git -C "$clone" fetch "$remote" "+refs/heads/${branch}:refs/remotes/$remote/$branch" || exit 1
git -C "$worktree" branch --set-upstream-to="$remote/$branch" "$branch" || exit 1

if command -v mise >/dev/null 2>&1; then
    (cd "$worktree" && mise trust --all --yes) || exit 1
fi
print "Review worktree: $worktree"

# Reconnect without restarting running apps; restore any missing windows.
if ! tmux has-session -t "=$session" 2>/dev/null; then
    tmux new-session -s "$session" -c "$worktree" -n editor -d nvim || exit 1
fi
local windows
windows=$(tmux list-windows -t "$session" -F '#{window_name}') || exit 1
if ! print -r -- "$windows" | grep -qx editor; then
    tmux new-window -d -t "${session}:" -n editor -c "$worktree" nvim || exit 1
fi
if ! print -r -- "$windows" | grep -qx pi; then
    local prompt="/review origin/$base"
    # Keep a shell open if Pi exits, so startup errors don't disappear with the tab.
    tmux new-window -d -t "${session}:" -n pi -c "$worktree" \
        "pi --approve ${(q)prompt}; exec zsh" || exit 1
fi
if ! print -r -- "$windows" | grep -qx git; then
    tmux new-window -d -t "${session}:" -n git -c "$worktree" lazygit || exit 1
fi
title="${title//[[:cntrl:]]/}"
tmux set-option -t "$session" @pr_title "$title" \
    \; set-option -t "$session" set-titles on \
    \; set-option -t "$session" set-titles-string '#{@pr_title}' \
    \; select-window -t "${session}:editor" || exit 1
if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "=$session"
else
    tmux attach-session -t "=$session"
fi
