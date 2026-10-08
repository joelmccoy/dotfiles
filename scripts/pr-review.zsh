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

# Query once for both refs, including the exact branch name on fork PRs.
local metadata base branch head_repo
metadata=$(gh api "repos/$owner/$repo/pulls/$number" --jq '.base.ref, .head.ref, .head.repo.full_name') || exit 1
local refs=("${(@f)metadata}")
base="$refs[1]"
branch="$refs[2]"
head_repo="$refs[3]"
[[ -n "$base" && "$base" != null && -n "$branch" && "$branch" != null ]] || exit 1
if [[ -z "$head_repo" || "$head_repo" == null ]]; then
    print -u2 'The PR source repository no longer exists; cannot configure a pullable upstream.'
    exit 1
fi
git check-ref-format --branch "$branch" >/dev/null || exit 1

function configure_pr_branch() {
    local current
    current=$(git -C "$1" branch --show-current) || return 1
    [[ -n "$current" ]] || return 1
    if [[ "$current" != "$branch" ]]; then
        # Rename older gr review branches without resetting commits or edits.
        git -C "$1" branch -m "$branch" || return 1
    fi
    # Track a real source branch: lazygit assumes upstreams are refs/heads/*.
    local remote=origin
    if [[ "${head_repo:l}" != "${owner:l}/${repo:l}" ]]; then
        remote="pr-$number"
        local origin_url head_url
        origin_url=$(git -C "$1" remote get-url origin) || return 1
        # Match the cached clone's transport so SSH users keep using SSH.
        case "$origin_url" in
            git@*|ssh://*) head_url="git@github.com:$head_repo.git" ;;
            *) head_url="https://github.com/$head_repo.git" ;;
        esac
        if git -C "$1" remote get-url "$remote" >/dev/null 2>&1; then
            git -C "$1" remote set-url "$remote" "$head_url" || return 1
        else
            git -C "$1" remote add "$remote" "$head_url" || return 1
        fi
    fi
    local upstream="refs/remotes/$remote/$branch"
    local refspec="+refs/heads/${branch}:$upstream"
    if ! git -C "$1" config --get-all "remote.$remote.fetch" | grep -Fxq -- "$refspec"; then
        git -C "$1" config --add "remote.$remote.fetch" "$refspec" || return 1
    fi
    git -C "$1" fetch "$remote" "$refspec" || return 1
    git -C "$1" config "branch.$branch.remote" "$remote" || return 1
    git -C "$1" config "branch.$branch.merge" "refs/heads/$branch"
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
    configure_pr_branch "$existing_dir" || exit 1
    connect
    exit $?
fi

# TMPDIR is stable across invocations. Keep clones/worktrees until temp cleanup.
local cache="${GPR_CACHE_DIR:-${TMPDIR:-/tmp}/github-pr-reviews-$UID}"
local root="$cache/${owner:l}/${repo:l}"
local clone="$root/repo"
mkdir -p -m 700 "$root/reviews" || exit 1

if [[ ! -d "$clone" ]]; then
    gh repo clone "$owner/$repo" "$clone" -- --no-checkout || exit 1
fi
git -C "$clone" rev-parse --git-dir >/dev/null || exit 1
# Fetch the target repo's pull ref, including PRs coming from forks, and its base.
git -C "$clone" fetch origin \
    "+refs/pull/$number/head:refs/remotes/origin/pr/$number" \
    "+refs/heads/${base}:refs/remotes/origin/$base" || exit 1

# A branch can only be checked out in one worktree. Reuse it when present,
# preserving earlier review edits and commits instead of forcing a reset.
local worktree="" candidate line
git -C "$clone" worktree prune || exit 1
while IFS= read -r line; do
    case "$line" in
        'worktree '*) candidate="${line#worktree }" ;;
        "branch refs/heads/$branch") worktree="$candidate"; break ;;
    esac
done < <(git -C "$clone" worktree list --porcelain)
if [[ -z "$worktree" ]]; then
    local review_dir
    review_dir=$(mktemp -d "$root/reviews/pr-$number.XXXXXX") || exit 1
    worktree="$review_dir/worktree"
    if git -C "$clone" show-ref --verify --quiet "refs/heads/$branch"; then
        git -C "$clone" worktree add "$worktree" "$branch" || exit 1
    elif ! git -C "$clone" worktree add -b "$branch" "$worktree" "refs/remotes/origin/pr/$number"; then
        rmdir "$review_dir"
        exit 1
    fi
fi
configure_pr_branch "$worktree" || exit 1
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
