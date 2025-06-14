#!/usr/bin/env bash

echo "Installing brew packages"
brew bundle

echo "Symlinking config modules"
for module in $(cat .modules); do
  printf "Linking module %s" module
  stow module
done

echo "Don't forget to decrypt and import Iterm2 settings"
echo "All done"
