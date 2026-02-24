# Directory shortcuts
alias ws="cd ~/Workspace/"
alias pg="cd ~/Workspace/Playground"
alias dl="cd ~/Downloads/"
alias dotfiles="cd ~/dotfiles/"
alias config="cd ~/.config/"
alias brain="cd ~/Documents/Brain/"

# Editor
alias zshconfig="nvim ~/.zshrc.local"
alias nvimconfig="nvim ~/.config/nvim"
alias vs='/usr/bin/code'

# Tmux
alias tml="tmux ls"
alias tma="tmux a -t"
alias tmk="tmux kill-session -t"
alias tmn="tmux new -s"

# Git
alias gs='git status'
alias ga='git add'
alias gp='git push'
alias gpo='git push origin'
alias gtd='git tag --delete'
alias gtdr='git tag --delete origin'
alias gr='git branch -r'
alias gplo='git pull origin'
alias gb='git branch '
alias gc='git commit'
alias gcm='git commit -m '
alias gd='git diff'
alias gco='git checkout '
alias gl='git log'
alias gr='git remote'
alias grs='git remote show'
alias glo='git log --pretty="oneline"'
alias glol='git log --graph --oneline --decorate'

# llm
alias ppx='llm -m sonar-deep-research'
alias ppq='llm -m sonar'
alias csn='llm -m claude-3.7-sonnet'
alias cmd='llm cmd -m claude-3.7-sonnet'
alias claude='claude --chrome --dangerously-skip-permissions'
alias code='claude --chrome --dangerously-skip-permissions'
alias sonnet='code --model sonnet'
alias codex='codex --dangerously-bypass-approvals-and-sandbox'

# Dotfiles
alias dotfiles-sync='cd ~/dotfiles && git pull --ff-only && ./stow/stow_dotfiles.sh $([ "$(uname)" = "Linux" ] && [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && echo "--vps")'

# File manager
alias y="ya"

# Arch Linux / Package management
if command -v paru &>/dev/null; then
    alias update="paru -Syu"
    alias rmpkg="paru -Rsn"
elif command -v yay &>/dev/null; then
    alias update="yay -Syu"
    alias rmpkg="yay -Rsn"
fi
if command -v pacman &>/dev/null; then
    alias cleanup='sudo pacman -Rsn $(pacman -Qtdq 2>/dev/null)'
    alias fixpacman="sudo rm /var/lib/pacman/db.lck"
    alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
    alias jctl="journalctl -p 3 -xb"
fi

# Parallel build
if command -v nproc &>/dev/null; then
    alias make="make -j\$(nproc)"
    alias ninja="ninja -j\$(nproc)"
fi

# Other
alias todos="nvim ~/todos.todo"
