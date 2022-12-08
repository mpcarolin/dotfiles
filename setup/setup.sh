# This file installs any dependencies needed for my neovim work environment.
# It is backed up by the dotfiles repo

brew install zx
sudo chown -R $(whoami):staff /usr/local/lib/node_modules/

# terminal
brew install --cask alacritty
brew install tmux

# neovim
brew install neovim

# get nerd fonts
brew tap homebrew/cask-fonts
brew install --cask font-dejavu-sans-mono-nerd-font
