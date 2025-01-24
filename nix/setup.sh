#!/bin/bash

# Replace @USER@ placeholder with actual username
sed -i "s/@USER@/$USER/g" ~/.config/home-manager/flake.nix

# Run home-manager switch with impure evaluation and backup
home-manager switch --flake ~/.config/home-manager#$USER --impure -b backup

# Restore the placeholder for git
sed -i "s/$USER/@USER@/g" ~/.config/home-manager/flake.nix
