#!/usr/bin/env bash

which brew && brew bundle dump --file Brewfile.bak && brew bundle && echo "Installing brew packages"
[[ $? != 0 ]] && echo "Homebrew installation not found"

# TODO: check if stow is installed correctly
echo "Symlinking config modules"
for module in $(cat .modules); do
  printf "Linking module %s" module
  stow module
done

echo "Don't forget to decrypt and import Iterm2 settings"
echo "All done"
