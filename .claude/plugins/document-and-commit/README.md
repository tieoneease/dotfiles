# Document and Commit Skill

A custom Claude Code skill that intelligently documents changes and creates well-structured commits.

## Purpose

This skill automates the process of:
1. Analyzing changes across your repository
2. Grouping related changes into logical commits
3. Identifying when CLAUDE.md should be updated with relevant information
4. Creating descriptive, atomic commits that follow your repository's style

## Usage

```bash
/dc
```

Run this command when you have changes to commit. The skill will:
- Analyze all modified files in your working directory
- Read each file to understand the nature of changes
- Group changes by logical area (shell config, editor config, scripts, etc.)
- Propose CLAUDE.md updates for Claude-relevant changes (with your approval)
- Create one or more commits with descriptive messages

## What Gets Documented in CLAUDE.md

The skill proposes CLAUDE.md updates for:
- **New commands or scripts** - Added to Commands section
- **Code style changes** - Updated in Code Style section
- **Environment/dependency changes** - Updated in Environment Management or Main Components
- **Build/setup process changes** - Updated in Commands section
- **Configuration patterns** - Structural changes Claude should know about
- **Tool/framework updates** - Version changes that affect Claude's work

The skill does NOT update CLAUDE.md for:
- User preferences (colors, themes, fonts)
- Visual customizations
- Simple bug fixes
- Personal workflow adjustments
- Key binding changes (unless part of a broader pattern)

## Commit Strategy

### Single Commit
Created when changes are cohesive and serve a single purpose:
- All changes relate to one component
- Changes are interdependent
- Changes serve a unified goal

### Multiple Commits
Created when changes span different logical areas:
- Shell config changes → One commit
- Editor config changes → Separate commit
- New scripts → Separate commit
- Documentation updates → Included with relevant commit

The skill aims for 1-4 commits maximum to maintain clear history without over-fragmentation.

## Commit Message Style

Follows your repository's existing style:
- Imperative mood (e.g., "Add feature" not "Added feature")
- Subject line under 70 characters
- Focus on WHAT and WHY, not HOW
- Optional body for complex changes
- No Co-Authored-By footer

Example commits from this repo:
- "Add nix-direnv for cached Nix flake environments"
- "Fix nix stow structure and add nix PATH to shell"
- "Add directional resize keybindings for Aerospace"

## Session Context

The skill is smart about context:
- **Within active session:** Uses conversation context about recently modified files
- **Outside session:** Analyzes all modified files via git status

## Approval Process

Before updating CLAUDE.md, the skill will:
1. Show you the proposed changes
2. Explain why the update is relevant
3. Wait for your approval
4. Only proceed if you confirm

You maintain full control over what gets documented.

## Examples

### Example 1: Single Logical Change
```
Modified files: zshrc, shell/functions.sh
Result: 1 commit "Add git helper functions to shell config"
CLAUDE.md: Not updated (personal workflow preference)
```

### Example 2: Multiple Logical Changes
```
Modified files: nvim/plugins.lua, tmux.conf, arch_setup.sh, CLAUDE.md
Result:
  - Commit 1: "Add nvim-treesitter plugin for syntax highlighting" (includes CLAUDE.md)
  - Commit 2: "Update tmux keybindings for better navigation"
  - Commit 3: "Add Hyprland packages to arch_setup.sh" (includes CLAUDE.md)
```

### Example 3: Documentation Only
```
Modified files: CLAUDE.md
Result: 1 commit "Document stow directory structure"
```

## Integration with Stow

The skill is stored in `/Users/chungsam/dotfiles/.claude/plugins/document-and-commit/` and will be symlinked to `~/.claude/plugins/document-and-commit/` when you run your stow setup.

## Requirements

- Git repository
- Claude Code CLI
- Bash environment
- Read/write access to repository files
