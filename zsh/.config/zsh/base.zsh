# ZSH Base Configuration (managed by dotfiles)
# Sourced from ~/.zshrc — do not add machine-specific config here

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# PATH
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"
[[ -d "$HOME/.fly/bin" ]] && export PATH="$HOME/.fly/bin:$PATH"
[[ -d "$HOME/.nix-profile/bin" ]] && export PATH="$HOME/.nix-profile/bin:$PATH"

# Completion
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Key bindings
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# Plugins (installed via package manager to /usr/share/zsh/plugins/)
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# History search: substring search (matches anywhere) with fallback to prefix search
if [[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
else
    bindkey '^[[A' history-beginning-search-backward
    bindkey '^[[B' history-beginning-search-forward
fi

# Command-not-found handler (suggests packages via pkgfile)
[[ -f /usr/share/doc/pkgfile/command-not-found.zsh ]] && source /usr/share/doc/pkgfile/command-not-found.zsh

# Fallback: plugins cloned to ~/.zsh/ (macOS or manual install)
[[ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Initialize mise (version manager for node, python, etc.)
command -v mise >/dev/null && eval "$(mise activate zsh)"

# Initialize Starship prompt
command -v starship >/dev/null && eval "$(starship init zsh)"

# Initialize direnv
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# Yazi: change directory on exit
function ya() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# Source secrets (API keys, tokens — never committed)
[[ -f ~/.config/secrets/env ]] && source ~/.config/secrets/env

# Source aliases
[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh

# Source machine-specific interactive config
[[ -f ~/.config/zsh/local.zsh ]] && source ~/.config/zsh/local.zsh
