export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="gozilla"
# Plugins
plugins=(
    git
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}
alias python=python3
alias pip=pip3
alias k=kubectl
alias vim=nvim

