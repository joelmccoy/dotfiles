#!/usr/bin/env bash
############################
# This script creates symlinks from the home directory to any desired dotfiles in ${homedir}/dotfiles
# And also installs Homebrew Packages
############################

if [ "$#" -ne 1 ]; then
    echo "Usage: install.sh <home_directory>"
    exit 1
fi

homedir=$1

# dotfiles directory
dotfiledir=${homedir}/dotfiles

# list of files/folders to symlink in ${homedir}
files="zshrc tmux.conf"

# change to the dotfiles directory
echo "Changing to the ${dotfiledir} directory"
cd ${dotfiledir}
echo "...done"

# create symlinks (overwrite existing files/directories/symlinks)
for file in ${files}; do
    echo "Creating symlink to $file in home directory."
    rm -rf "${homedir}/.${file}"
    ln -s "${dotfiledir}/.${file}" "${homedir}/.${file}"
done

# Ghostty config
mkdir -p "${homedir}/.config/ghostty"
echo "Creating symlink for Ghostty config."
rm -rf "${homedir}/.config/ghostty/config"
ln -s "${dotfiledir}/ghostty/config" "${homedir}/.config/ghostty/config"

# OpenCode config
mkdir -p "${homedir}/.config/opencode"
echo "Creating symlink for OpenCode config."
rm -rf "${homedir}/.config/opencode/opencode.jsonc"
ln -s "${dotfiledir}/opencode/opencode.jsonc" "${homedir}/.config/opencode/opencode.jsonc"

# Starship config
mkdir -p "${homedir}/.config"
echo "Creating symlink for Starship config."
rm -rf "${homedir}/.config/starship.toml"
ln -s "${dotfiledir}/starship.toml" "${homedir}/.config/starship.toml"

# Install Oh My Zsh (overwrite existing install, keep our .zshrc symlink)
export ZSH="${homedir}/.oh-my-zsh"
rm -rf "${ZSH}"
RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Plugins (overwrite existing clones)
zsh_custom="${ZSH_CUSTOM:-${ZSH}/custom}"
rm -rf "${zsh_custom}/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-autosuggestions "${zsh_custom}/plugins/zsh-autosuggestions"

rm -rf "${zsh_custom}/plugins/zsh-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-syntax-highlighting "${zsh_custom}/plugins/zsh-syntax-highlighting"

rm -rf "${homedir}/.tmux/plugins/tpm"
git clone https://github.com/tmux-plugins/tpm "${homedir}/.tmux/plugins/tpm"
