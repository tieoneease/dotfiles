# Nix
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi

# Source aliases if exists
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases