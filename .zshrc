export ZSH="$HOME/.oh-my-zsh"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
ZSH_THEME="simple"
# Plugins
plugins=(
    git
    zsh-autosuggestions
    kubectl
    aws
    docker
)

source $ZSH/oh-my-zsh.sh

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


# Added by Windsurf
export PATH="/Users/jmccoy/.codeium/windsurf/bin:$PATH"
