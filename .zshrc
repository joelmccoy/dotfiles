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
alias g='function _g() { cd ~/github/$1 && tmux new-session -d -s $1 "nvim" \; new-window -n lazygit "lazygit" \; attach; }; _g'

# Add to path
export PATH=$PATH:$HOME/go/bin

# Set vim keybindings
bindkey -v
