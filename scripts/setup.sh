#!/bin/sh
npm install -g zx

# fonts
brew tap homebrew/cask-fonts
brew install font-dejavu-sans-mono-for-powerline

# tools
brew install tmux
brew install --cask alacritty
brew install neovim

## tmux config
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
brew install smug

## neovim
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

## alacritty config
brew tap homebrew/cask-fonts


