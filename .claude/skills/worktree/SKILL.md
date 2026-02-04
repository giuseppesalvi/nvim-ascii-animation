---
name: worktree
description: Create a git worktree for a GitHub issue with proper branch naming
argument-hint: <issue-number> [type]
allowed-tools: Bash(git *), Bash(gh *)
---

# Create Git Worktree for Issue

Set up an isolated git worktree for GitHub issue **#$1**.

## Instructions

1. **Fetch issue details:**
   ```bash
   gh issue view $1 --json number,title,labels
   ```

2. **Determine branch type:**
   - If `$2` is provided, use it as the type
   - Otherwise, infer from labels: `bug` → `fix`, `enhancement` → `feat`
   - Default to `feat` if unclear

3. **Create branch name** following project convention:
   - Format: `<type>/<issue-number>-<short-description>`
   - Convert title to lowercase, replace spaces with hyphens
   - Remove special characters, keep only `a-z`, `0-9`, `-`
   - Truncate to ~4 words max

4. **Create worktree:**
   ```bash
   git worktree add ../nvim-anim-issue-$1 -b <branch-name>
   ```

5. **Output summary:**
   - Worktree path
   - Branch name
   - Commands to start working:
     ```
     cd ../nvim-anim-issue-$1
     claude
     ```

## Branch Naming Examples

| Issue | Title | Labels | Branch |
|-------|-------|--------|--------|
| 4 | feat: add user commands | enhancement | `feat/4-user-commands` |
| 12 | Animation flickers on startup | bug | `fix/12-animation-flickers` |

## Cleanup Instructions

When done with the worktree:
```bash
git worktree remove ../nvim-anim-issue-$1
# Or if changes were merged:
git branch -d <branch-name>
```
