#!/bin/bash

# Replace @USER@ placeholder with actual username
sed -i "s/@USER@/$USER/g" flake.nix

# Run home-manager switch
nix --extra-experimental-features "nix-command flakes" run home-manager/master -- switch --flake .#$USER

# Restore the placeholder for git
sed -i "s/$USER/@USER@/g" flake.nix
