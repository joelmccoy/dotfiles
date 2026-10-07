#!/usr/bin/env zsh
# gr <github-pr-url>: cached clone, fresh worktree, and g-style tmux windows.
emulate -LR zsh
setopt pipefail

# Keep accepting --trust for compatibility; trust now runs by default.
[[ "$1" == --trust ]] && shift

if (( $# != 1 )) || [[ ! "$1" =~ '^https://github\.com/([A-Za-z0-9-]+)/([A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)(/[^?#]*)?([?#].*)?$' ]]; then
    print -u2 'Usage: gr <https://github.com/owner/repo/pull/number>'
    exit 1
fi
local owner="$match[1]" repo="$match[2]" number="$match[3]"
if [[ "$repo" == '.' || "$repo" == '..' ]]; then
    print -u2 'Invalid repository name.'
    exit 1
fi

for dependency in git gh tmux nvim pi lazygit; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        print -u2 "Missing dependency: $dependency"
        exit 1
    fi
done

function trust_worktree() {
    command -v mise >/dev/null 2>&1 || return 0
    print "Trusting mise configs in: $1"
    (cd "$1" && mise trust --all --yes)
}

# Include the owner, and avoid dots in tmux session names.
local session="pr-${owner}-${repo//./_}-${number}"
function connect() {
    local title
    title=$(gh api "repos/$owner/$repo/pulls/$number" --jq '.title') || return 1
    # Keep control characters out of the terminal title. Store the title as data,
    # not a tmux format, so PR titles containing #{...} remain literal text.
    title="${title//[[:cntrl:]]/}"
    tmux set-option -t "$session" @pr_title "$title" \
        \; set-option -t "$session" set-titles on \
        \; set-option -t "$session" set-titles-string '#{@pr_title}' || return 1
    if [[ -n "$TMUX" ]]; then
        tmux switch-client -t "=$session"
    else
        tmux attach-session -t "=$session"
    fi
}
if tmux has-session -t "=$session" 2>/dev/null; then
    local existing_dir
    existing_dir=$(tmux display-message -p -t "${session}:" '#{pane_current_path}') || exit 1
    trust_worktree "$existing_dir" || exit 1
    connect
    exit $?
fi

# TMPDIR is stable across invocations. Keep clones/worktrees until temp cleanup.
local cache="${GPR_CACHE_DIR:-${TMPDIR:-/tmp}/github-pr-reviews-$UID}"
local root="$cache/${owner:l}/${repo:l}"
local clone="$root/repo"
mkdir -p -m 700 "$root/reviews" || exit 1

# Query before cloning so invalid/inaccessible PRs don't leave a large clone.
local base
base=$(gh api "repos/$owner/$repo/pulls/$number" --jq '.base.ref') || exit 1
[[ -n "$base" && "$base" != null ]] || exit 1

if [[ ! -d "$clone" ]]; then
    gh repo clone "$owner/$repo" "$clone" -- --no-checkout || exit 1
fi
git -C "$clone" rev-parse --git-dir >/dev/null || exit 1
# Fetch the target repo's pull ref, including PRs coming from forks, and its base.
git -C "$clone" fetch origin \
    "+refs/pull/$number/head:refs/review/pr-$number" \
    "+refs/heads/${base}:refs/remotes/origin/$base" || exit 1

# Every new session gets a fresh worktree. Never reset an earlier review's work.
local review_dir
review_dir=$(mktemp -d "$root/reviews/pr-$number.XXXXXX") || exit 1
local worktree="$review_dir/worktree"
local branch="review/pr-$number-${review_dir:t}"
if ! git -C "$clone" worktree add -b "$branch" "$worktree" "refs/review/pr-$number"; then
    rmdir "$review_dir"
    exit 1
fi
print "Review worktree: $worktree"
trust_worktree "$worktree" || exit 1

# Passing the slash command as Pi's initial prompt avoids send-keys startup races.
local prompt="/review origin/$base"
local pi_command="pi --approve ${(q)prompt}"
tmux new-session -s "$session" -c "$worktree" -n editor -d nvim \
    \; new-window -t "${session}:" -n pi -c "$worktree" "$pi_command" \
    \; new-window -t "${session}:" -n git -c "$worktree" lazygit \
    \; select-window -t "${session}:editor" || exit 1
connect
