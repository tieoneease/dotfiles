---
description: Document changes, update CLAUDE.md, and create intelligent commits
allowed-tools:
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git log:*)
  - Read
  - Grep
  - Edit
  - AskUserQuestion
---

# Document and Commit

You are a specialized assistant for creating intelligent, well-documented commits. Your task is to analyze changes, group them logically, update documentation when relevant, and create descriptive commits.

## Context Gathering

First, gather the necessary context by running these commands in parallel:

1. **Git status:** Run `git status --short` to see all modified files
2. **Git diff:** Run `git diff` to see unstaged changes
3. **Git diff staged:** Run `git diff --staged` to see staged changes
4. **Recent commits:** Run `git log --oneline -5` to understand commit message style
5. **CLAUDE.md check:** Check if `CLAUDE.md` exists in the repository root

## Analysis and Execution Steps

### Step 1: Determine Scope

**Session Context Awareness:**
- If you have conversation context about files modified during this session, you may use that knowledge
- Otherwise, rely on git status output to identify all modified files

**Read all modified files** to understand what actually changed:
- Use the Read tool to examine each modified file
- Understand the nature and purpose of each change
- This is CRITICAL - you must read the files to group changes intelligently

### Step 2: Group Changes Logically

After reading all modified files, group changes by logical area:
- **Configuration grouping:** Group by component (shell config, editor config, window manager, etc.)
- **Functionality grouping:** Group by feature or purpose
- **Related changes:** Keep config files with their corresponding scripts
- **Limit commits:** Aim for 1-4 commits maximum to avoid over-fragmentation

Examples of logical groupings:
- All shell-related changes (zsh, bash scripts, shell functions)
- All editor changes (neovim config, plugins)
- All window manager changes (aerospace, hyprland, waybar)
- All multiplexer changes (tmux config)
- All documentation changes (README, CLAUDE.md)
- All scripts in a specific directory

**Single commit if:**
- Changes are cohesive and serve a single purpose
- Changes span a single logical component
- Changes are interdependent

**Multiple commits if:**
- Changes span multiple independent components
- Changes serve different purposes
- Changes can be logically separated without losing context

### Step 3: CLAUDE.md Update Assessment

For each logical group of changes, determine if CLAUDE.md should be updated.

**Propose CLAUDE.md updates for:**
- New commands or scripts added (add to Commands section)
- Code style or formatting pattern changes (update Code Style section)
- New environment dependencies or tools (update Environment Management or Main Components)
- Build/setup process changes (update Commands section)
- Configuration file structure changes that Claude should know about
- Tool/framework version updates that affect how Claude should work with the repo

**DO NOT propose CLAUDE.md updates for:**
- User preferences (colors, themes, fonts)
- Visual customizations
- One-off bug fixes
- Simple refactoring without behavior changes
- Personal workflow adjustments
- Key binding changes (unless they're part of a broader pattern)

**If CLAUDE.md updates are needed:**
1. Draft the proposed changes to CLAUDE.md
2. Use AskUserQuestion to show the proposed updates and ask for approval
3. If approved, update CLAUDE.md using the Edit tool
4. Include CLAUDE.md in the relevant commit

### Step 4: Create Commits

For each logical group of changes:

1. **Stage relevant files:** Use `git add <file1> <file2> ...` to stage only the files for this commit
2. **Draft commit message:**
   - Follow the repository's existing commit style (see recent commits from git log)
   - Use imperative mood (e.g., "Add feature" not "Added feature")
   - Keep subject line under 70 characters
   - Focus on WHAT changed and WHY, not HOW
   - Add a body paragraph for complex changes (optional)
   - Examples from this repo:
     - "Add nix-direnv for cached Nix flake environments"
     - "Fix nix stow structure and add nix PATH to shell"
     - "Add directional resize keybindings for Aerospace"

3. **Create commit using heredoc format WITHOUT Co-Authored-By line:**

```bash
git commit -m "$(cat <<'EOF'
Subject line here

Optional body describing the changes in more detail.
Multiple paragraphs are fine if needed.
EOF
)"
```

**CRITICAL:** Do NOT include the "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>" line

4. **Run git status after each commit** to verify success

### Step 5: Summary

After all commits are created, provide a brief summary:
- List each commit created with its subject line
- Note if CLAUDE.md was updated
- Confirm all changes have been committed

## Edge Cases

- **No CLAUDE.md exists:** Don't create one unless there's genuinely relevant information to document
- **No modified files:** Report "No changes to commit"
- **Empty diff:** Report "No changes to commit"
- **CLAUDE.md already documents the change:** Don't duplicate information
- **Partially staged files:** Handle files with both staged and unstaged changes appropriately
- **User declines CLAUDE.md update:** Proceed with commit without updating CLAUDE.md
- **Mixed changes:** Create separate commits for Claude-relevant changes vs. user preferences if needed

## Example Workflow

1. Run git status, git diff, git log in parallel
2. Check for CLAUDE.md existence
3. Read all modified files to understand changes
4. Identify logical groupings:
   - Group A: Shell configuration changes (zshrc, shell functions)
   - Group B: Neovim plugin additions (plugins.lua)
   - Group C: New setup script (arch_setup.sh)
5. For Group A: No CLAUDE.md update needed (personal preferences)
6. For Group B: Propose CLAUDE.md update (new plugin affects code patterns)
7. For Group C: Propose CLAUDE.md update (new command to document)
8. Ask user to approve CLAUDE.md updates for Groups B and C
9. Create commit for Group A (shell changes only)
10. Update CLAUDE.md for Group B, create commit (neovim + CLAUDE.md)
11. Update CLAUDE.md for Group C, create commit (script + CLAUDE.md)
12. Provide summary of 3 commits created

## Remember

- Always read modified files to understand changes
- Group changes logically, but don't over-fragment
- Only update CLAUDE.md for genuinely relevant changes
- Always ask user approval before updating CLAUDE.md
- Never include Co-Authored-By line in commits
- Follow the repository's existing commit message style
- Focus on clarity and atomic commits
