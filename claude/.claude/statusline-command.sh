#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract user and hostname
user=$(whoami)
host=$(hostname -s)

# Extract context remaining percentage - handle both null and numeric values
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // "null"')

# Extract current project directory
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir')
project_name=$(basename "$project_dir")

# Extract model display name
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id')

# Get git branch/worktree info (skip optional locks for performance)
if [ -d "$project_dir/.git" ]; then
    cd "$project_dir" 2>/dev/null || true
    git_info=$(git -c core.useBuiltinFSMonitor=false config --get-regexp 'core.bare|core.worktree' 2>/dev/null)

    if echo "$git_info" | grep -q "core.bare true"; then
        # Bare repository
        branch="(bare)"
    elif echo "$git_info" | grep -q "core.worktree"; then
        # Worktree
        worktree_dir=$(git rev-parse --git-dir 2>/dev/null | sed 's/\.git.*/.git/')
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] && branch="worktree:$branch" || branch="(worktree)"
    else
        # Normal git repository
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "(no branch)")
    fi
else
    branch=""
fi

# Build the status line
status="[$user@$host $project_name | $model_name"

if [ -n "$branch" ]; then
    status="$status ($branch)"
fi

# Show context if we have a value (not "null" string and not empty)
if [ -n "$context_remaining" ] && [ "$context_remaining" != "null" ]; then
    # Round to integer if it's a decimal
    context_int=$(printf "%.0f" "$context_remaining" 2>/dev/null || echo "$context_remaining")
    status="$status | ${context_int}% left"
fi

status="$status]"

echo "$status"
