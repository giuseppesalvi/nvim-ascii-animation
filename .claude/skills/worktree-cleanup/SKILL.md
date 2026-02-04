---
name: worktree-cleanup
description: Remove a git worktree and optionally delete its branch
argument-hint: <worktree-path-or-issue-number>
allowed-tools: Bash(git *)
---

# Cleanup Git Worktree

Remove a git worktree and clean up associated branches.

## Instructions

1. **Resolve the worktree path:**
   - If `$ARGUMENTS` is a number, assume it's an issue: `../nvim-anim-issue-$ARGUMENTS`
   - Otherwise, use it as the path directly

2. **Check worktree status:**
   ```bash
   git -C <path> status --porcelain
   ```
   - If there are uncommitted changes, **warn the user** and ask for confirmation
   - List what would be lost

3. **Get the branch name** before removing:
   ```bash
   git -C <path> branch --show-current
   ```

4. **Remove the worktree:**
   ```bash
   git worktree remove <path>
   ```
   - If forced removal needed: `git worktree remove --force <path>`

5. **Ask about branch deletion:**
   - If the branch was merged to main, offer to delete it:
     ```bash
     git branch -d <branch-name>
     ```
   - If not merged, warn and offer force delete:
     ```bash
     git branch -D <branch-name>
     ```

6. **Prune stale worktree references:**
   ```bash
   git worktree prune
   ```

## Usage Examples

```
/worktree-cleanup 4                    # Remove worktree for issue #4
/worktree-cleanup ../nvim-anim-issue-4 # Remove by path
```

## Output

```
Removing worktree: ../nvim-anim-issue-4
  Branch: feat/4-user-commands
  Status: clean

Worktree removed.
Branch 'feat/4-user-commands' deleted (was merged to main).
```
