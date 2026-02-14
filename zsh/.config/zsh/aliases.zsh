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
alias claude='claude --chrome'
alias code='claude --chrome --dangerously-skip-permissions'
alias sonnet='code --model sonnet'

# File manager
alias y="ya"

# Other
alias todos="nvim ~/todos.todo"
