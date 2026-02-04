# CLAUDE.md - Project Development Guidelines

> **Purpose**: Quick reference for AI assistants and developers to understand project conventions, best practices, and development workflow.

---

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

---

## Project Overview

**nvim-ascii-animation** - Cinematic text animation for Neovim dashboards. Watch your ASCII art materialize from chaos with a smooth ease-in-out animation effect.

### Key Technologies

- **Lua** - Neovim plugin language
- **Neovim API** - Buffer manipulation, extmarks, timers
- **lazy.nvim** - Plugin manager compatibility

### Project Structure

```
nvim-ascii-animation/
├── .github/
│   └── ISSUE_TEMPLATE/       # Issue templates (bug, feature)
├── lua/
│   └── ascii-animation/
│       ├── init.lua          # Main entry point & public API
│       ├── animation.lua     # Animation logic & effects
│       ├── commands.lua      # User commands (:AsciiPreview, :AsciiSettings, etc.)
│       ├── config.lua        # Configuration & persistence
│       ├── time.lua          # Time period detection
│       └── content/          # Content system
│           ├── init.lua      # Content manager
│           ├── arts/         # ASCII art by style (blocks, gradient, isometric)
│           └── messages/     # Taglines by period
├── README.md
├── LICENSE
└── CLAUDE.md
```

---

## Essential Commands

### Testing Locally

```bash
# Symlink to Neovim plugins directory for testing
ln -s $(pwd) ~/.local/share/nvim/lazy/nvim-ascii-animation

# Or add to lazy.nvim config:
{ dir = "~/Documents/Projects/nvim-ascii-animation" }
```

### Testing with Worktrees

When working in a git worktree (e.g., `nvim-anim-issue-3`), update lazy.nvim config to point to the worktree:

```lua
-- In ~/.config/nvim/lua/plugins/dashboard.lua
dir = "~/Documents/Projects/nvim-anim-issue-3",  -- Point to worktree
```

**Important:** Restore to main project path after merging/cleanup:

```lua
dir = "~/Documents/Projects/nvim-ascii-animation",  -- Restore to main
```

### Git Commands

```bash
git status                    # Check status
git add -A && git commit -m "message"  # Commit
git push origin main          # Push to remote
```

---

## Coding Standards

### Lua-Specific

- **Use local variables** - avoid polluting global namespace
- **Module pattern**: Return a table `M` with public functions
- **Naming**: `snake_case` for functions/variables, `PascalCase` only for classes
- **Use `vim.api`** for Neovim API calls
- **Error handling**: Use `pcall` for operations that may fail
- **Check validity**: Always check `vim.api.nvim_buf_is_valid()` before buffer operations

### File Organization

```lua
-- Module structure
local M = {}

-- Private functions (local, not in M)
local function private_helper()
end

-- Public functions (in M)
function M.public_function()
end

return M
```

---

## Git Conventions

### Commit Message Format

**Keep commits short — prefer one-liners.**

```
<type>: <short description>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

**Examples:**
```
feat: add support for alpha-nvim
fix: resolve animation timing issue
docs: update installation instructions
```

### Branch Naming

**Format:** `<type>/<issue-number>-<short-description>`

**Rules:**
- Use lowercase and hyphens (no spaces, underscores, or special characters)
- Match type to commit types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- Include issue number when working on a tracked issue
- Keep descriptions short (2-4 words)

**Examples:**
```
feat/4-user-commands
fix/12-animation-flicker
refactor/cleanup-config
docs/update-readme
chore/ci-workflow
```

**Creating branches:**
```bash
# For issue-based work
git checkout -b feat/4-user-commands

# For general work (no issue)
git checkout -b fix/typo-in-config

# With git worktrees (parallel development)
git worktree add ../nvim-anim-issue-4 -b feat/4-user-commands
```

### GitHub Issues

**Always use issue templates** when creating issues via `gh issue create`.

**Issue Types & Prefixes:**
- `bug: <description>` - Bug reports (label: `bug`)
- `feat: <description>` - Feature requests (label: `enhancement`)

**Issue Body Structure:**
```
## Problem
[What problem does this solve / what's broken]

## Proposed Solution
[Detailed description of the fix or feature]

## API Design (for features)
```lua
-- Code examples showing proposed config/API
```

## Implementation Notes
[Technical considerations, affected files, etc.]
```

**Labels:**
- Type: `bug`, `enhancement`
- Area: `animation`, `content`, `ux`, `commands`

**Creating Issues via CLI:**
```bash
# Feature request
gh issue create --title "feat: add new effect" --label "enhancement,animation" --body "..."

# Bug report
gh issue create --title "bug: animation flickers" --label "bug" --body "..."
```

### Post-Implementation Checklist

After completing a feature or fix:

1. **Update README.md** - Keep documentation current. Add any new config options, effects, or API changes.
2. **Propose follow-up issues** - If you identify improvements or related features during implementation, propose creating new issues to track them.

---

## Adding New Settings

When adding a new user-configurable setting to `:AsciiSettings`:

1. **config.lua** - Add the setting variable and include it in `save()` and `load_saved()`
2. **commands.lua** - Add to `update_stats_content()` display, create adjustment function, add keybinding
3. **README.md** - Document the new setting

**Settings persistence pattern:**
```lua
-- In config.lua
M.my_setting = default_value  -- Add variable

function M.save()
  local to_save = {
    -- ...existing settings...
    my_setting = M.my_setting,  -- Add to save
  }
end

function M.setup(opts)
  local saved = M.load_saved()
  -- ...
  if saved.my_setting then
    M.my_setting = saved.my_setting  -- Load saved value
  end
end
```

**Current settings in :AsciiSettings:**

Animation:
- `effect` - Animation effect (chaos, typewriter, diagonal, lines, matrix, random)
- `ambient` - Ambient effect (none, glitch, shimmer)
- `loop` - Loop mode toggle
- `steps` - Animation steps (10-100)

Selection:
- `random_mode` - Art selection mode (always, daily, session)
- `no_repeat` - Don't repeat last shown art
- `favorites_weight` - Probability of picking favorite art (0-100%)

---

## Quick Reference

| Task                | Command                    |
| ------------------- | -------------------------- |
| Test in Neovim      | `:Lazy reload ascii-animation` |
| Check for errors    | `:messages`                |
| Inspect module      | `:lua print(vim.inspect(require('ascii-animation')))` |

---

## Evolving This Document

This CLAUDE.md is a **living document**. Update it when:

- After any correction — add it as a rule
- When discovering undocumented patterns
- When a workaround becomes standard

---

**Last Updated**: 2026-02-04
