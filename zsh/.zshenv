# Source Nix
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Add nix packages to PATH
export PATH="$HOME/.nix-profile/bin:$PATH"

# Homebrew configuration
if [[ $(uname -m) == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)"
else
    eval "$(/usr/local/bin/brew shellenv 2>/dev/null)"
fi

# NVM environment variables
export NVM_DIR="$HOME/.nvm"
export NVM_NODEJS_ORG_MIRROR=https://nodejs.org/dist
