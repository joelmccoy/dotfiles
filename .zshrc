export ZSH="$HOME/.oh-my-zsh"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
ZSH_THEME=""  # using starship prompt instead
# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    kubectl
    aws
    docker
)

# Add local bin to path
PATH="$HOME/.local/bin:$PATH"

source $ZSH/oh-my-zsh.sh

# fzf keybindings (ctrl-r, ctrl-t, alt-c)
source <(fzf --zsh)
# oh-my-zsh git plugin aliases g=git, remove so our g() function works
unalias g 2>/dev/null

# Global Env Variables
export KUBE_EDITOR="nvim" # set k9s editor to nvim

# Load in secrets env variables
[ -f ~/.zshenv_secret ] && source ~/.zshenv_secret

# User configuration
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}
alias python=python3
alias pip=pip3
alias k=kubectl
alias vim=nvim
alias cat=bat
alias ls='eza --icons --git'
alias ll='eza -la --icons --git'

# Disable gh CLI telemetry (requires gh >= 2.91.0; takes precedence over config)
# https://cli.github.com/telemetry
export GH_TELEMETRY=disabled

# Catppuccin Mocha theme for bat and fzf
export BAT_THEME="Catppuccin Mocha"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"

# Worktree-based repo workflow
# Usage:
#   g repo       - pick a worktree via fzf, open nvim in it
#   g repo init  - (re)create default worktrees
DEFAULT_WORKTREES=(feat-1 feat-2 review-1 review-2 scratch)

function g() {
    local repo="$1"
    local repo_dir="$HOME/github/$repo"

    if [[ -z "$repo" ]]; then
        echo "Usage: g <repo> [init]"
        return 1
    fi

    if [[ ! -d "$repo_dir" ]]; then
        echo "Repo not found: $repo_dir"
        return 1
    fi

    cd "$repo_dir" || return 1

    # Init: ensure default worktrees exist
    if [[ "$2" == "init" ]] || [[ ! -d "$repo_dir.feat-1" ]]; then
        echo "Setting up worktrees for $repo..."
        local base_branch="main"
        for wt in "${DEFAULT_WORKTREES[@]}"; do
            if [[ ! -d "$repo_dir.$wt" ]]; then
                git worktree add "$repo_dir.$wt" -b "$repo/$wt" "$base_branch" &>/dev/null \
                    || git worktree add "$repo_dir.$wt" "$repo/$wt" &>/dev/null
                echo "  created: $wt"
            fi
        done
        [[ "$2" == "init" ]] && return 0
    fi

    # Build worktree list: main + all worktrees
    local choices=()
    local main_branch=$(git branch --show-current 2>/dev/null)
    local main_changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    local main_status=""
    [[ "$main_changed" -gt 0 ]] && main_status=" [$main_changed changes]"
    choices+=("main\t($main_branch)$main_status")
    for wt in "${DEFAULT_WORKTREES[@]}"; do
        local wt_dir="$repo_dir.$wt"
        if [[ -d "$wt_dir" ]]; then
            local branch=$(git -C "$wt_dir" branch --show-current 2>/dev/null)
            local changed=$(git -C "$wt_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            local wt_status=""
            [[ "$changed" -gt 0 ]] && wt_status=" [$changed changes]"
            choices+=("$wt\t($branch)$wt_status")
        fi
    done

    # Fuzzy pick a worktree
    local pick
    pick=$(printf '%b\n' "${choices[@]}" | column -t -s $'\t' | fzf --height=40% --reverse --prompt="$repo > ")
    [[ -z "$pick" ]] && return 0

    # Extract worktree name from selection
    local wt_name="${pick%% *}"
    local target_dir
    if [[ "$wt_name" == "main" ]]; then
        target_dir="$repo_dir"
    else
        target_dir="$repo_dir.$wt_name"
    fi

    # Session name: repo-worktree
    local session_name="$repo-$wt_name"

    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux attach-session -t "$session_name"
    else
        tmux new-session -s "$session_name" -c "$target_dir" -n editor -d "nvim" \; new-window -n claude -c "$target_dir" "claude" \; new-window -n git -c "$target_dir" "lazygit" \; select-window -t editor \; attach-session -t "$session_name"
    fi
}

# Setup Bash my AWS
export PATH="$PATH:${BMA_HOME:-$HOME/.bash-my-aws}/bin"
export BMA_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT=true
source ${BMA_HOME:-$HOME/.bash-my-aws}/aliases

# Custom completions (must be before compinit)
fpath=(~/.zsh/completions $fpath)

# For ZSH users, uncomment the following two lines:
autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit

source ${BMA_HOME:-$HOME/.bash-my-aws}/bash_completion.sh


# Add go libs to path
export PATH=$PATH:$HOME/go/bin

# Setup vim mode ref: https://gist.github.com/LukeSmithxyz/e62f26e55ea8b0ed41a65912fbebbe52
bindkey -v
export KEYTIMEOUT=1
# Change cursor shape for different vi modes.
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'
  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

# Certinfo script
function certinfo {
  FILE_TYPE=`file -L $1`
  if $(echo "$FILE_TYPE"|grep -q "Java KeyStore")
  then
    echo "Java KeyStore File:"
    keytool -list -v -keystore $1| egrep "(Certificate\[|Owner: |Issuer: )"
  elif openssl req -text -noout -verify -in $1 > /dev/null 2>&1
  then
    echo "Cert Request File:"
    openssl req -text -noout -verify -in $1
  elif openssl rsa -in $1 -check > /dev/null 2>&1
  then
    echo "RSA Private Key File, password once more please:"
    openssl rsa -in $1 -check
  elif openssl pkcs12 -info -in $1 -nodes > /dev/null 2>&1
  then
    echo "PKCS12, .p12 file, password once more please:"
    openssl pkcs12 -info -in $1 -nodes | openssl x509 -noout -subject -issuer
  elif openssl x509 -in $1 -text -noout > /dev/null 2>&1
  then
    echo "X509 Certificates:"
    awk '
    BEGIN {
        cert = "";
        in_cert = 0;
    }

    /-----BEGIN CERTIFICATE-----/ {
        cert = $0;
        in_cert = 1;
        next;
    }

    /-----END CERTIFICATE-----/ {
        cert = cert "\n" $0;

        # Extract certificate info
        cmd = "echo \"" cert "\" | openssl x509 -subject -issuer -noout -dates";
        first_line = 0;
        while ((cmd | getline line) > 0) {
            if (first_line == 0) {
                print line;
                first_line = 1;
            } else {
                print "  " line;
            }
        }
        close(cmd);

        # Extract Subject Alternative Name
        cmd = "echo \"" cert "\" | openssl x509 -text -noout | grep -A1 \"Subject Alternative Name\"";
        while ((cmd | getline line) > 0) {
            print "  " line;
        }
        close(cmd);

        cert = "";
        in_cert = 0;
        next;
    }

    {
        if (in_cert) {
            cert = cert "\n" $0;
        }
    }' "$1"
  elif openssl pkcs7 -text -in $1 > /dev/null 2>&1
  then
    echo "PKCS7, .p7b file; contains a full cert chain, but no keys"
    echo "Top level cert:"
    openssl pkcs7 -print_certs -in $1 | openssl x509 -noout -subject -issuer -dates
    openssl pkcs7 -print_certs -in $1 | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

    echo "Full chain:"
    openssl pkcs7 -print_certs -in $1 | grep -E '(subject|issuer)'
  else
    echo "Unknown filetype."
  fi
}

# Fuzzy-find and open GitHub repos in Chrome
# Searches defenseunicorns + uds-packages orgs live via GitHub API
GH_REPO_HISTORY="$HOME/.gh_repo_history"
function ghr() {
    local search_cmd='gh search repos --limit=50 --json fullName -q ".[].fullName" {q}'
    local history_list=""
    [[ -f "$GH_REPO_HISTORY" ]] && history_list=$(cat "$GH_REPO_HISTORY")

    local selection
    selection=$(echo "$history_list" | fzf --height=40% --reverse --prompt="GitHub repo > " \
        --header="Type to search GitHub API" \
        --bind "change:reload:$search_cmd || true" \
        --phony)
    [[ -z "$selection" ]] && return 0

    # Update MRU history
    { echo "$selection"; [[ -f "$GH_REPO_HISTORY" ]] && grep -v "^${selection}$" "$GH_REPO_HISTORY"; } | head -50 > "${GH_REPO_HISTORY}.tmp"
    mv "${GH_REPO_HISTORY}.tmp" "$GH_REPO_HISTORY"

    open -a "Google Chrome" "https://github.com/$selection"
}

# Open/reattach dotfiles tmux session with nvim + claude
alias dot='tmux has-session -t dotfiles 2>/dev/null && tmux attach-session -t dotfiles || tmux new-session -s dotfiles -c "$HOME/dotfiles" -n editor -d "nvim" \; new-window -n claude -c "$HOME/dotfiles" "claude" \; new-window -n git -c "$HOME/dotfiles" "lazygit" \; select-window -t editor \; attach-session -t dotfiles'

# Open/reattach nvim config tmux session with nvim + claude
alias nvc='tmux has-session -t nvim-config 2>/dev/null && tmux attach-session -t nvim-config || tmux new-session -s nvim-config -c "$HOME/.config/nvim" -n editor -d "nvim" \; new-window -n claude -c "$HOME/.config/nvim" "claude" \; new-window -n git -c "$HOME/.config/nvim" "lazygit" \; select-window -t editor \; attach-session -t nvim-config'

# Alias for killing all tmux sessions
alias tkill='tmux ls 2>/dev/null | cut -d: -f1 | xargs -r -n1 tmux kill-session -t'

# Interactive tmux session killer (multi-select with Tab, Enter to kill)
tks() {
  local lines=()
  while IFS='|' read -r name attached windows; do
    local pane_path=$(tmux display -t "$name" -p '#{pane_current_path}' 2>/dev/null)
    local branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
    local state=""
    [[ "$attached" == "1" ]] && state="● attached" || state="○ detached"
    [[ -n "$branch" ]] && branch=" $branch" || branch=""
    printf -v line "%-28s  %s  %-14s  %dw" "$name" "$state" "$branch" "$windows"
    lines+=("$line")
  done < <(tmux ls -F '#{session_name}|#{session_attached}|#{session_windows}' 2>/dev/null)

  [[ ${#lines[@]} -eq 0 ]] && { echo "No tmux sessions running."; return 0; }

  local selected
  selected=$(printf '%s\n' "${lines[@]}" | fzf \
    --multi \
    --ansi \
    --header=$'Session                       Status       Branch          Win\n───────────────────────────────────────────────────────────────' \
    --prompt="Kill session(s) > " \
    --marker="✗" \
    --color='marker:red,prompt:yellow,header:dim' \
    --preview='tmux capture-pane -t $(echo {} | awk "{print \$1}") -p 2>/dev/null || echo "No preview"' \
    --preview-window=right:50%:wrap) || return 0

  local killed=0
  echo "$selected" | awk '{print $1}' | while read -r s; do
    tmux kill-session -t "$s" && echo "  ✗ $s"
    ((killed++))
  done
}

# Fuzzy-browse a prepared oci-layout directory. Walks index -> manifests
# recursively, lists layers by title annotation, previews/reads with bat.
# Used by both ocitar (local archive) and ocitarr (remote ref).
function _ocitar_browse() {
    local root="$1" label="$2"
    local idx="$root/index.json"
    [[ -f "$idx" && -d "$root/blobs" ]] || {
        echo "Not an OCI layout: $root"
        return 1
    }

    # Recursive walker: emits "label<TAB>blob_path" per layer. Descends into
    # nested image-indexes, prefixing labels with the manifest ref.name so
    # same-named files in different packages stay distinguishable.
    _ocitar_walk() {
        local blob="$1" prefix="$2"
        [[ -f "$blob" ]] || return
        local media
        media=$(jq -r '.mediaType // ""' "$blob" 2>/dev/null)
        case "$media" in
            *image.index*|*manifest.list*)
                jq -r '.manifests[] |
                    ((.annotations["org.opencontainers.image.ref.name"]
                      // .artifactType
                      // (.digest | .[7:19]))
                     + "\t" + .digest)' "$blob" \
                | while IFS=$'\t' read -r sub digest; do
                    _ocitar_walk "$root/blobs/${digest%%:*}/${digest#*:}" "${prefix}${sub}/"
                done
                ;;
            *)
                jq -r --arg p "$prefix" --arg b "$root/blobs/" '
                    .layers[]? |
                    ($p + (.annotations["org.opencontainers.image.title"]
                           // .annotations["org.opencontainers.artifact.title"]
                           // .digest))
                    + "\t" + ($b + (.digest | sub(":"; "/")))
                ' "$blob"
                ;;
        esac
    }

    local rows
    rows=$(_ocitar_walk "$idx" "")
    unset -f _ocitar_walk

    if [[ -z "$rows" ]]; then
        echo "No layers found in OCI manifests"
        return 1
    fi

    local pick
    pick=$(printf '%s\n' "$rows" | fzf --height=80% --reverse \
        --delimiter=$'\t' --with-nth=1 \
        --prompt="$label > " \
        --preview='bat --color=always --style=plain {2}' \
        --preview-window=right:60%:wrap) || return 0
    [[ -z "$pick" ]] && return 0

    local title="${pick%%$'\t'*}"
    local blob="${pick##*$'\t'}"
    bat --file-name="$title" --paging=always "$blob"
}

# Fuzzy-browse an OCI image: local oci-layout archive (any compression) or
# remote registry reference. Auto-detects: existing file => extract, else
# treat as ref and crane pull. Handles nested "oci/" dir like UDS bundles.
# Usage: ocipeek <oci-archive|registry/repo:tag|@digest>
function ocipeek() {
    local src="$1"
    if [[ -z "$src" ]]; then
        echo "Usage: ocipeek <oci-archive|oci-ref>"
        return 1
    fi

    local tmp
    tmp=$(mktemp -d -t ocipeek.XXXXXX) || return 1
    trap "rm -rf '$tmp'" EXIT INT TERM

    local root label
    if [[ -f "$src" ]]; then
        if ! tar -xf "$src" -C "$tmp" 2>/dev/null; then
            echo "Failed to extract $src"
            return 1
        fi
        # Locate oci-layout root: index.json sibling to blobs/ dir
        local idx
        idx=$(find "$tmp" -maxdepth 4 -type f -name index.json 2>/dev/null | while read -r f; do
            [[ -d "${f:h}/blobs" ]] && { echo "$f"; break; }
        done)
        if [[ -z "$idx" ]]; then
            echo "Not an OCI layout (no index.json + blobs/ found)"
            return 1
        fi
        root="${idx:h}"
        label="$(basename "$src")"
    else
        if ! command -v crane >/dev/null 2>&1; then
            echo "crane not found (brew install crane)"
            return 1
        fi
        echo "Pulling $src ..." >&2
        if ! crane pull --format=oci "$src" "$tmp"; then
            echo "crane pull failed"
            return 1
        fi
        root="$tmp"
        label="$src"
    fi

    _ocitar_browse "$root" "$label"
}

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi

# Starship prompt
eval "$(starship init zsh)"
