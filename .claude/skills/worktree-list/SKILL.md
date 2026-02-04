---
name: worktree-list
description: List all git worktrees with their branches and status
allowed-tools: Bash(git *)
---

# List Git Worktrees

Show all active git worktrees for this project.

## Instructions

1. **List worktrees:**
   ```bash
   git worktree list
   ```

2. **For each worktree, show:**
   - Path
   - Branch name
   - Whether it has uncommitted changes (run `git -C <path> status --porcelain`)

3. **Format output as a table:**
   ```
   Worktrees:

   | Path                      | Branch                | Status |
   |---------------------------|----------------------|--------|
   | /path/to/main             | main                 | clean  |
   | ../nvim-anim-issue-4      | feat/4-user-commands | dirty  |
   ```

4. **Show cleanup hint** if there are worktrees:
   ```
   To remove a worktree: /worktree-cleanup <path>
   ```
