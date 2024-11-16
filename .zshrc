export ZSH="$HOME/.oh-my-zsh"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
ZSH_THEME="gozilla"
# Plugins
plugins=(
    git
    zsh-autosuggestions
    kubectl
    aws
    docker
)

source $ZSH/oh-my-zsh.sh

# User configuration
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}
alias python=python3
alias pip=pip3
alias k=kubectl
alias vim=nvim
alias notes="(export CUR=$PWD; cd '/Users/jmccoy/Library/Mobile Documents/iCloud~md~obsidian/Documents/brain'; nvim; cd $CUR)"
alias brain="(export CUR=$PWD; cd '/Users/jmccoy/Library/Mobile Documents/iCloud~md~obsidian/Documents/brain'; lazygit; cd $CUR)"

# Function for opening a tmux session for a github repo
alias g='function _g() { 
    if tmux has-session -t $1 2>/dev/null; then
        tmux attach-session -t $1;
    else 
        cd ~/github/$1 && tmux new-session -s $1 -n editor -d "nvim" \; new-window -n lazygit "lazygit" \; attach-session -t $1;
    fi 
}; _g'

alias core='uds deploy k3d-core-demo:latest --confirm'
alias slim='uds deploy k3d-slim-dev:latest --confirm'

# Setup Bash my AWS
export PATH="$PATH:${BMA_HOME:-$HOME/.bash-my-aws}/bin"
export BMA_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT=true
source ${BMA_HOME:-$HOME/.bash-my-aws}/aliases

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
