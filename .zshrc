export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="gozilla"
# Plugins
plugins=(
    git
    zsh-autosuggestions
    kubectl
)

source $ZSH/oh-my-zsh.sh

# User configuration
code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}
alias python=python3
alias pip=pip3
alias k=kubectl
alias vim=nvim
alias notes="(export CUR=$PWD; cd ~/Documents/Joel\'s\ Vault; nvim; cd $CUR)"

# Add to path
export PATH=$PATH:$HOME/go/bin
