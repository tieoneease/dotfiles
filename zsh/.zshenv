# NVM environment variables
export NVM_DIR="$HOME/.nvm"
export NVM_NODEJS_ORG_MIRROR=https://nodejs.org/dist

# Source local environment variables if file exists
# Put sensitive information like API keys in ~/.zshenv.local
if [[ -f "$HOME/.zshenv.local" ]]; then
  source "$HOME/.zshenv.local"
fi
. "$HOME/.cargo/env"
