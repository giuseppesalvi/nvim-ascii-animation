---
name: nvim-dev-switch
description: Switch Neovim lazy.nvim config to load plugin from current worktree or main
argument-hint: [path-override]
allowed-tools: Bash(git *), Bash(pwd), Read, Edit
---

# Switch Neovim Plugin Dev Path

Update lazy.nvim config to load the ascii-animation plugin from the current working directory (worktree or main repo).

## Instructions

1. **Determine current directory:**
   ```bash
   pwd
   ```

2. **Verify it's a valid plugin directory:**
   - Check that `lua/ascii-animation/init.lua` exists in the current directory
   - If not, abort with error

3. **Get current branch info** (for display):
   ```bash
   git branch --show-current
   ```

4. **Update the lazy.nvim config:**
   - Config file: `~/.config/nvim/lua/plugins/dashboard.lua`
   - Find the line with `dir = "~/Documents/Projects/nvim-..."`
   - Replace with current directory path (use `~` shorthand if in home directory)

5. **Output summary:**
   - Previous path
   - New path
   - Current branch
   - Reminder: "Restart Neovim to load the plugin from the new path"

## Path Override

If `$1` is provided, use it as the path instead of the current directory. Useful for:
- `main` - Switch to main project: `~/Documents/Projects/nvim-ascii-animation`
- Any other path - Use as-is

## Examples

```bash
# From a worktree directory
cd ../nvim-anim-issue-4
/nvim-dev-switch
# → Updates config to: dir = "~/Documents/Projects/nvim-anim-issue-4"

# Switch back to main explicitly
/nvim-dev-switch main
# → Updates config to: dir = "~/Documents/Projects/nvim-ascii-animation"
```
