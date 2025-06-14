#!/usr/bin/env bash

echo "Installing brew packages"
brew bundle

echo "Symlinking config modules"
for module in $(cat .modules); do
  printf "Linking module %s" module
  stow module
done

echo "All done"
