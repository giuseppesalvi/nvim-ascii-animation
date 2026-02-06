# nvim-ascii-animation

Cinematic text animation for Neovim dashboards. Watch your ASCII art materialize from chaos with a smooth ease-in-out animation effect.

<p align="center">
  <img src="assets/demo.gif" alt="Demo" width="600">
</p>

<details>
<summary>More examples</summary>
<p align="center">
  <img src="assets/demo_2.gif" alt="Demo 2" width="600">
  <img src="assets/demo_3.gif" alt="Demo 3" width="600">
</p>
</details>

## Features

- 14 **animation effects**: chaos, typewriter, diagonal, lines, matrix, wave, fade, scramble, rain, spiral, explode, implode, glitch, and random
- **Loop mode**: continuous animation replay with optional reverse
- **8 ambient effects**: glitch, shimmer, cursor trail, sparkle, scanlines, noise, shake, sound
- **Ease-in-out** timing: slow start → fast middle → slow finish
- **140+ built-in ASCII arts** in 7 styles: blocks, gradient, isometric, box, minimal, pixel, braille
- **Time-aware content**: morning, afternoon, evening, night, weekend themes
- **330+ motivational taglines** that match the time of day (including emoji variants)
- **Message browser**: browse, preview, favorite, and disable individual messages or entire themes
- **Multi-line messages**: Support for haiku-style multi-line taglines
- **Conditional messages**: Day-specific messages (Happy Friday!, Monday motivation)
- **Message history**: Track shown messages to avoid repetition
- **Customizable footer**: template-based footer with placeholders and alignment
- **Personalization placeholders**: `{name}`, `{project}`, `{time}`, `{date}`, `{version}`, `{plugin_count}`
- **Daily/session seed**: same art all day or per session for consistency
- **Favorites system**: boost selection probability of preferred arts
- **No-repeat**: avoid showing recently displayed arts
- **Terminal width detection**: automatic fallback for narrow terminals
- Works with popular dashboard plugins:
  - [snacks.nvim](https://github.com/folke/snacks.nvim)
  - [alpha-nvim](https://github.com/goolord/alpha-nvim)
  - [dashboard-nvim](https://github.com/nvimdev/dashboard-nvim)
  - [lazy.nvim](https://github.com/folke/lazy.nvim) starter screen
- Fully configurable animation speed, characters, and timing
- Respects your colorscheme and dashboard highlights
- **Phase-based highlighting**: Customize colors for chaos, revealing, and revealed states
- **Period-based color schemes**: Automatic warm/cool colors based on time of day
- **User commands**: `:AsciiPreview`, `:AsciiSettings`, `:AsciiRefresh`, `:AsciiStop`, `:AsciiRestart`, `:AsciiCharset`

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  opts = {
    animation = {
      enabled = true,
      -- Effect: "chaos" | "typewriter" | "diagonal" | "lines" | "matrix" | "wave" |
      --         "fade" | "scramble" | "rain" | "spiral" | "explode" | "implode" | "glitch" | "random"
      effect = "chaos",
      effect_options = {
        -- Wave options
        origin = "center",  -- "center" | "top-left" | "top-right" | "bottom-left" | "bottom-right" | "top" | "bottom" | "left" | "right"
        speed = 1.0,        -- Wave propagation speed multiplier
        -- Glitch options
        glitch = {
          intensity = 0.5,       -- Glitch amount (0.0-1.0)
          block_chance = 0.2,    -- Probability of block glitching
          block_size = 5,        -- Max size of glitch blocks
          resolve_speed = 1.0,   -- Resolution speed
        },
        -- Scramble options
        stagger = "left",   -- "left" | "right" | "center" | "random"
        cycles = 5,         -- Scramble cycles before settling
        -- Spiral options
        direction = "outward",   -- "outward" | "inward"
        rotation = "clockwise",  -- "clockwise" | "counter"
        tightness = 1.0,         -- Spiral tightness (0.5-2.0)
        -- Fade options
        highlight_count = 10,    -- Brightness levels (5-20)
      },
      steps = 40,        -- Total animation steps
      min_delay = 20,    -- Fastest frame delay (ms)
      max_delay = 120,   -- Slowest frame delay (ms)
      -- Loop settings
      loop = false,          -- Enable loop mode
      loop_delay = 2000,     -- Delay between loops (ms)
      loop_reverse = false,  -- Play reverse before next loop
      -- Ambient effect (when not looping)
      ambient = "none",      -- "none" | "glitch" | "shimmer" | "cursor_trail" | "sparkle" | "scanlines" | "noise" | "shake" | "sound"
      ambient_interval = 2000,
      -- Character set preset
      char_preset = "default", -- "default" | "minimal" | "matrix" | "blocks" | "braille" | "stars" | "geometric" | "binary" | "dots"
      -- Per-effect charset overrides (preset name or raw character string)
      effect_chars = {},  -- e.g. { matrix = "matrix", rain = "│┃┆┇┊┋" }
      -- Phase-based highlighting (see Highlight Groups section)
      use_phase_highlights = false,
      -- Color theme for phase highlights (auto-enables use_phase_highlights)
      color_theme = nil, -- "default" | "cyberpunk" | "matrix" | "ocean" | "sunset" | "forest" | "monochrome" | "dracula" | "nord"
      -- Color mode for line coloring
      color_mode = "default", -- "default" | "rainbow" | "gradient"
      -- Rainbow mode options
      rainbow = {
        palette = "default", -- "default" | "pastel" | "neon" | "warm" | "cool" | "mono"
      },
      -- Gradient mode options
      gradient = {
        preset = "sunset", -- "sunset" | "ocean" | "forest" | "fire" | "purple" | "pink" | "midnight" | "aurora"
      },
      -- Period-based color schemes (auto-changes phase colors by time of day)
      period_colors = false, -- Enable period-based colors (morning=warm, night=cool)
      reduced_motion = false, -- Skip animation, show final art immediately
    },
    chaos_chars = "@#$%&*+=-:;!?/\\|[]{}()<>~`'^", -- Custom chars (overrides preset)
  },
}
```

## Configuration

### With snacks.nvim

```lua
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  config = function()
    require("ascii-animation").setup({
      animation = {
        enabled = true,
        steps = 40,
        min_delay = 20,
        max_delay = 120,
      },
      snacks = {
        header_lines = 20,  -- Number of lines to animate
        highlight = "SnacksDashboardHeader",
      },
    })
  end,
}
```

### With alpha-nvim

```lua
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  config = function()
    require("ascii-animation").setup({
      animation = {
        enabled = true,
        steps = 40,
      },
    })
    require("ascii-animation").setup_alpha({
      header_lines = 15,
      highlight = "AlphaHeader",
    })
  end,
}
```

### With dashboard-nvim

```lua
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  config = function()
    require("ascii-animation").setup({
      animation = {
        enabled = true,
        steps = 40,
      },
    })
    require("ascii-animation").setup_dashboard({
      header_lines = 15,
      highlight = "DashboardHeader",
    })
  end,
}
```

### With lazy.nvim starter screen

```lua
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  config = function()
    require("ascii-animation").setup({
      animation = {
        enabled = true,
        steps = 40,
      },
    })
    require("ascii-animation").setup_lazy({
      header_lines = 15,
      highlight = "LazyH1",
    })
  end,
}
```

## Content System

The plugin includes a built-in content system with **140+ ASCII arts** and **200+ taglines** that automatically adapt to the time of day.

### Time Periods

| Period | Default Hours | Theme |
|--------|--------------|-------|
| Morning | 5:00 - 12:00 | Fresh starts, energy, coffee |
| Afternoon | 12:00 - 17:00 | Focus, momentum, productivity |
| Evening | 17:00 - 21:00 | Wind down, reflection, golden hour |
| Night | 21:00 - 5:00 | Deep work, silence, moonlight |
| Weekend | Sat & Sun | Freedom, side projects, no meetings |

### Art Styles

- **Blocks** (`██ ╚═╝ ▓█`) - Bold, modern, eye-catching
- **Gradient** (`░▒▓`) - Subtle, sophisticated, flowing
- **Isometric** (`/\ | __`) - Technical, elegant, architectural
- **Box** (`─ │ ┌ ┐ └ ┘ ╔ ╗`) - Clean, structured frames using box-drawing characters
- **Minimal** - Zen-like simplicity with lots of whitespace
- **Pixel** (`▄█▀░▓`) - Retro 8-bit style graphics
- **Braille** (`⣿⠛⣤⠀`) - High-resolution art using braille characters

### Using Content with snacks.nvim

```lua
-- In your lazy.nvim config
{
  "folke/snacks.nvim",
  opts = function()
    local ascii = require("ascii-animation")
    local header = ascii.get_header()

    return {
      dashboard = {
        preset = {
          header = table.concat(header.art, "\n") .. "\n\n" .. header.message,
        },
      },
    }
  end,
},

-- Don't forget to set up the animation
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  config = function()
    require("ascii-animation").setup({
      snacks = { header_lines = 20 },
    })
  end,
}
```

### Using Footer with snacks.nvim

```lua
{
  "folke/snacks.nvim",
  opts = function()
    local ascii = require("ascii-animation")
    local header = ascii.get_header()
    local footer_lines = ascii.get_footer_lines()

    return {
      dashboard = {
        preset = {
          header = table.concat(header.art, "\n"),
        },
        sections = {
          { section = "header" },
          -- ... your menu items ...
          { section = "startup" },
          { text = footer_lines, align = "center" },  -- Footer at bottom
        },
      },
    }
  end,
},

-- Configure footer template
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  config = function()
    require("ascii-animation").setup({
      footer = {
        enabled = true,
        template = "{message} • {date}",
        alignment = "center",
      },
      snacks = { header_lines = 20 },
    })
  end,
}
```

### Using Content with alpha-nvim

```lua
{
  "goolord/alpha-nvim",
  config = function()
    local alpha = require("alpha")
    local ascii = require("ascii-animation")
    local header = ascii.get_header()

    local dashboard = require("alpha.themes.dashboard")
    dashboard.section.header.val = header.art
    dashboard.section.footer.val = header.message

    alpha.setup(dashboard.config)
  end,
}
```

### Content Configuration

```lua
require("ascii-animation").setup({
  content = {
    enabled = true,               -- Enable content system
    builtin_arts = true,          -- Use built-in ASCII arts
    builtin_messages = true,      -- Use built-in taglines

    -- Filter art styles (nil = all styles)
    styles = nil,                 -- or {"blocks", "gradient", "isometric", "box", "minimal", "pixel", "braille"}

    -- Custom time periods
    time_periods = {
      morning   = { start = 5,  stop = 12 },
      afternoon = { start = 12, stop = 17 },
      evening   = { start = 17, stop = 21 },
      night     = { start = 21, stop = 5 },
    },
    weekend_override = true,      -- Use weekend content on Sat/Sun

    -- Personalization placeholders
    placeholders = {
      name = "Developer",         -- Override auto-detected git user.name
      -- project = "my-project",  -- Override auto-detected project name
      -- date_format = "%B %d, %Y", -- Custom date format
    },

    -- Randomization mode
    random = "always",            -- "always" | "daily" | "session"

    -- Favorites: arts that appear more often
    favorites = { "morning_blocks_1", "night_gradient_2" },
    favorite_weight = 3,          -- 3x more likely to be selected

    -- No-repeat: avoid showing the same art repeatedly
    no_repeat = 5,                -- Don't repeat any of the last 5 arts

    -- Add your own content (merged with built-in)
    custom_arts = {
      morning = {
        { id = "my_art", name = "Custom", lines = { "Line 1", "Line 2" } },
      },
    },
    custom_messages = {
      morning = { "My custom message!", "Another one" },
    },

    -- Message no-repeat: avoid showing the same message repeatedly
    message_no_repeat = 5,        -- Don't repeat any of the last 5 messages

    -- Message category filtering
    message_categories = nil,     -- Include-list: only these themes (e.g. {"zen", "witty"})
    exclude_categories = nil,     -- Exclude-list: disable these themes (e.g. {"cryptic"})
  },

  -- Footer settings
  footer = {
    enabled = true,
    template = "{message}",       -- Available: {message}, {date}, {time}, {version}, {plugins}, {name}, {project}
    alignment = "center",         -- "left" | "center" | "right"
  },
})
```

### Message Enhancements

The message system supports several advanced features for customization.

#### Emoji Support

Messages can include emoji (requires terminal with emoji support):

```lua
-- Built-in examples
"☀️ Rise and shine!"
"☕ Coffee time!"
"🎉 Happy Friday!"
"🌙 Night mode."
"💤 Remember to rest."
```

#### Multi-line Messages

Messages can span multiple lines for haiku-style or poetic content:

```lua
-- Built-in example (zen haiku)
{ text = { "Morning light awaits.", "Empty buffer, fresh mind.", "Code flows like water." }, theme = "zen" }

-- In custom_messages config
content = {
  custom_messages = {
    morning = {
      { "First line of the message.", "Second line continues here." },  -- Simple multi-line
      { text = { "With theme:", "And multiple lines." }, theme = "poetic" },  -- With theme
    },
  },
}
```

Multi-line messages are rendered with each line on a separate row in the dashboard.

#### Message History (No-Repeat)

Avoid showing recently displayed messages:

```lua
content = {
  message_no_repeat = true,   -- Don't repeat the last message
  -- or
  message_no_repeat = 5,      -- Don't repeat any of the last 5 messages
}
```

#### Conditional Messages

Messages can have condition functions that determine when they appear:

```lua
-- Built-in examples
{ text = "🎉 Happy Friday!", theme = "witty", condition = function() return os.date("%A") == "Friday" end }
{ text = "💪 Monday: New week, fresh start!", theme = "motivational", condition = function() return os.date("%A") == "Monday" end }
{ text = "🌙 Late night coding session?", theme = "zen", condition = function() return tonumber(os.date("%H")) >= 23 end }

-- In custom_messages config
content = {
  custom_messages = {
    afternoon = {
      -- Only show on Wednesdays
      { text = "Hump day! Halfway there.", condition = function() return os.date("%A") == "Wednesday" end },
      -- Only show in December
      { text = "🎄 Holiday season coding!", condition = function() return os.date("%m") == "12" end },
    },
  },
}
```

Condition functions receive no arguments and should return `true` for the message to be included in the pool.

#### Message Favorites

Favorite messages appear 3x more often. Manage favorites in `:AsciiSettings` → `g` → `b` (Message Browser), then press `F` on any message.

## Commands

The plugin provides user commands for browsing and previewing ASCII arts:

### `:AsciiPreview [name]`

Opens a floating window with an animated preview of an ASCII art.

```vim
:AsciiPreview                  " Preview random art for current time period
:AsciiPreview morning_blocks_1 " Preview specific art by ID
:AsciiPreview gradient         " Fuzzy match on art ID
```

Interactive keybindings:
- `n`/`p` or `j`/`k`: next/previous art
- `1`-`5`: filter by period (morning, afternoon, evening, night, weekend)
- `0`: show all arts
- `f`: toggle favorite (starred arts appear more often)
- `F`: show favorites only
- `r`: replay animation
- `q`: close

### `:AsciiSettings`

Opens an interactive settings panel with **live preview**:

```vim
:AsciiSettings
```

**Features:**
- **Live preview panel**: See animation changes instantly in a side-by-side preview
- Change animation effect, ambient effect, loop mode, steps
- **Effect-specific options**: Configure wave origin, glitch intensity, spiral direction, and more
- **Timing settings**: Adjust min/max delays, loop delay, ambient interval
- Settings are automatically saved and persist across sessions
- Press `R` to reset to defaults

**Main Menu Keybindings:**
- `e`/`E`: cycle effect (14 effects)
- `o`: open effect options (for wave, glitch, scramble, spiral, fade)
- `a`/`A`: cycle ambient effect (9 options)
- `l`: toggle loop
- `r`: toggle reduced motion (skip animation)
- `s`/`S`: adjust steps (±5)
- `c`: cycle charset preset forward (9 presets)
- `p`: toggle phase highlights
- `z`: toggle period-based colors (morning=warm, night=cool)
- `P`: open phase colors (when phase highlights enabled)
- `C`: open color mode settings (rainbow/gradient)
- `t`: open timing settings
- `m`/`M`: cycle random mode (always/daily/session)
- `n`: toggle no-repeat
- `w`/`W`: adjust favorites weight (±10%)
- `y`: open styles filter
- `g`: open themes/messages settings
- `f`: open footer settings
- `Space`: replay preview animation
- `R`: reset to defaults
- `q`/`Esc`: close

**Effect Options (press `o`):**

*Wave:*
- `o`/`O`: cycle origin (center, top, bottom, left, right, corners)
- `s`/`S`: adjust speed (±0.1)

*Glitch:*
- `i`/`I`: adjust intensity (±0.1)
- `b`/`B`: adjust block chance (±0.1)
- `s`/`S`: adjust block size (±1)
- `r`: adjust resolve speed (±0.1)

*Scramble:*
- `s`/`S`: cycle stagger (left, right, center, random)
- `c`/`C`: adjust cycles (±1)

*Spiral:*
- `d`/`D`: cycle direction (outward, inward)
- `r`: cycle rotation (clockwise, counter)
- `t`/`T`: adjust tightness (±0.1)

*Fade:*
- `h`/`H`: adjust highlight levels (±1, range 5-20)

**Timing Settings (press `t`):**
- `m`/`M`: adjust min delay (±10ms)
- `x`/`X`: adjust max delay (±10ms)
- `d`/`D`: adjust loop delay (±100ms)
- `v`: toggle loop reverse
- `i`/`I`: adjust ambient interval (±100ms)
- `Backspace`: back to main menu

**Phase Colors (press `P` when phase highlights enabled):**
- `T`: cycle through color themes (default, cyberpunk, matrix, ocean, sunset, forest, monochrome, dracula, nord)
- `1`: edit Chaos color (hex input)
- `2`: edit Revealing color (hex input)
- `3`: edit Revealed color (hex input)
- `4`: edit Cursor color (hex input)
- `5`: edit Glitch color (hex input)
- `r`: reset custom colors (uses current theme colors)
- `Backspace`: back to main menu

**Color Mode (press `C`):**
- `m`/`M`: cycle color mode (default, rainbow, gradient)

*In rainbow mode:*
- `p`: cycle rainbow palette (default, pastel, neon, warm, cool, mono)

*In gradient mode:*
- `g`: cycle gradient preset (sunset, ocean, forest, fire, purple, pink, midnight, aurora)
- `1`: edit start color (hex input)
- `2`: edit stop color (hex input)
- `r`: reset custom colors (uses preset)
- `Backspace`: back to main menu

**Styles Filter (press `y`):**
- `1`-`7`: toggle individual styles (blocks, gradient, isometric, box, minimal, pixel, braille)
- `Backspace`: back to main menu

**Themes (press `g`):**
- `1`-`7`: toggle theme on/off (disables all messages of that theme)
- `b`: browse individual messages
- `Backspace`: back to main menu

Available themes: Motivational, Personalized, Philosophical, Cryptic, Poetic, Zen, Witty

**Message Browser (press `b` from Themes):**
- `j`/`k`: navigate up/down through messages
- `n`/`N`: next/previous page
- `1`-`5`: filter by period (morning, afternoon, evening, night, weekend)
- `c`: clear filter
- `F`: toggle favorite (favorites appear 3x more often)
- `d`: disable/enable individual message
- `p`: preview full message
- `t`: back to themes
- `Backspace`: back to main menu

**Footer Settings (press `f`):**
- `e`: toggle footer enabled/disabled
- `a`/`A`: cycle alignment (left, center, right)
- `t`: edit template (opens input prompt)
- `Backspace`: back to main menu

Available footer placeholders: `{message}`, `{date}`, `{time}`, `{version}`, `{plugins}`, `{name}`, `{project}`

### `:AsciiRefresh`

Re-runs the animation on the current buffer. Useful after returning to your dashboard.

```vim
:AsciiRefresh
```

### `:AsciiStop`

Stops the current animation and any ambient effects. Useful for taking screenshots or when you want a static display.

```vim
:AsciiStop
```

### `:AsciiRestart`

Restarts the animation from the beginning. Useful for demos or presentations.

```vim
:AsciiRestart
```

### `:AsciiCharset [preset]`

Change or view the character set used for animation effects.

```vim
:AsciiCharset           " Show current charset
:AsciiCharset matrix    " Use matrix-style characters
:AsciiCharset minimal   " Use minimal dots/circles
```

**Available presets:**
| Preset | Characters |
|--------|-----------|
| `default` | `@#$%&*+=-:;!?/\|[]{}()<>~\`'^` |
| `minimal` | `·•○◦◌░` |
| `matrix` | `ｱｲｳｴｵｶｷｸｹｺ01` |
| `blocks` | `█▓▒░▄▀▌▐■□` |
| `braille` | `⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏` |
| `stars` | `✦✧★☆✴✵✶✷⋆` |
| `geometric` | `◆◇○●□■△▲▽▼` |
| `binary` | `01` |
| `dots` | `.:;+*` |

### `:checkhealth ascii-animation`

Run the health check to diagnose issues with the plugin:

```vim
:checkhealth ascii-animation
```

**Checks performed:**
- Module loading - verifies all core modules load without error
- Content system - counts available arts and messages
- Terminal capabilities - width, true color, and UTF-8 encoding
- Configuration - validates settings file and reports current values
- State persistence - checks state file for recent history
- Dashboard integrations - detects snacks.nvim, alpha-nvim, dashboard-nvim, lazy.nvim
- Time system - verifies period detection
- User commands - ensures all commands are registered

### Personalization Placeholders

Taglines support placeholder tokens that get replaced at render time:

| Placeholder | Description | Auto-detected |
|-------------|-------------|---------------|
| `{name}` | User's name | From `git config user.name` |
| `{project}` | Current project/directory name | From `cwd` |
| `{time}` | Time-based greeting | morning/afternoon/evening/night/weekend |
| `{date}` | Current date | Formatted date |
| `{version}` | Neovim version | e.g., `v0.10.0` |
| `{plugin_count}` | Number of loaded plugins | From lazy.nvim/packer |
| `{day}` | Day of the week | e.g., "Monday", "Friday" |
| `{hour}` | Current hour (12h format) | e.g., "9 AM", "11 PM" |
| `{greeting}` | Natural greeting | "Good morning" / "Good afternoon" / "Good evening" / "Hey" |
| `{git_branch}` | Current git branch | From `git branch --show-current` |
| `{uptime}` | Session uptime | e.g., "1h 23m", "5m" |
| `{streak}` | Consecutive usage days | e.g., "3" |
| `{random_emoji}` | Random themed emoji | Session-stable pick |

#### Example Taglines with Placeholders

```lua
-- Built-in examples
"Good {time}, {name}!"           -- "Good morning, John!"
"Welcome back to {project}."     -- "Welcome back to my-project."
"Neovim {version} • {plugin_count} plugins loaded."  -- "Neovim v0.10.0 • 42 plugins loaded."
"{date} — Make it count."        -- "February 04, 2026 — Make it count."
"{greeting}, {name}!"            -- "Good afternoon, John!"
"Happy {day}! Let's code."       -- "Happy Friday! Let's code."
"Working on {git_branch}?"       -- "Working on feat/new-feature?"
"You've been coding for {uptime}!" -- "You've been coding for 1h 23m!"
"{streak} day streak! Keep going." -- "3 day streak! Keep going."
"{random_emoji} Time to code!"   -- "🚀 Time to code!"
```

#### Custom Messages with Placeholders

```lua
require("ascii-animation").setup({
  content = {
    placeholders = {
      name = "Developer",  -- Override auto-detected name
    },
    custom_messages = {
      morning = {
        "Rise and shine, {name}!",
        "Ready to build {project}?",
      },
    },
  },
})
```

### Daily Seed Mode

Keep the same art all day for a consistent dashboard experience:

```lua
content = {
  random = "daily",  -- Same art throughout the day
}
```

### Session Seed Mode

Same art within a Neovim session, but different when you restart:

```lua
content = {
  random = "session",
}
```

### Terminal Width Handling

Configure fallback behavior for narrow terminals:

```lua
animation = {
  auto_fit = true,       -- Skip arts wider than terminal
  min_width = 80,        -- Require at least 80 columns
  fallback = "tagline",  -- Show only tagline if too narrow
  -- fallback = "none",  -- Show nothing if too narrow
  -- fallback = "small_art_id",  -- Show specific smaller art
}
```

## Options

### Animation Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `animation.enabled` | boolean | `true` | Enable/disable animation |
| `animation.effect` | string | `"chaos"` | Animation effect (see Effects section) |
| `animation.effect_options.origin` | string | `"center"` | Wave origin point |
| `animation.effect_options.speed` | number | `1.0` | Wave propagation speed |
| `animation.effect_options.glitch.intensity` | number | `0.5` | Glitch amount (0-1) |
| `animation.effect_options.glitch.block_chance` | number | `0.2` | Block glitch probability |
| `animation.effect_options.glitch.block_size` | number | `5` | Max glitch block size |
| `animation.effect_options.glitch.resolve_speed` | number | `1.0` | Glitch resolution speed |
| `animation.effect_options.stagger` | string | `"left"` | Scramble stagger direction |
| `animation.effect_options.cycles` | number | `5` | Scramble cycles |
| `animation.effect_options.direction` | string | `"outward"` | Spiral direction |
| `animation.effect_options.rotation` | string | `"clockwise"` | Spiral rotation |
| `animation.effect_options.tightness` | number | `1.0` | Spiral tightness |
| `animation.effect_options.highlight_count` | number | `10` | Fade brightness levels |
| `animation.steps` | number | `40` | Total animation steps (more = smoother) |
| `animation.min_delay` | number | `20` | Fastest frame delay in ms (middle of animation) |
| `animation.max_delay` | number | `120` | Slowest frame delay in ms (start/end) |
| `animation.loop` | boolean | `false` | Enable loop mode (animation replays continuously) |
| `animation.loop_delay` | number | `2000` | Delay between loops in ms |
| `animation.loop_reverse` | boolean | `false` | Play animation in reverse before next loop |
| `animation.ambient` | string | `"none"` | Ambient effect: `"none"`, `"glitch"`, `"shimmer"`, `"cursor_trail"`, `"sparkle"`, `"scanlines"`, `"noise"`, `"shake"`, `"sound"` |
| `animation.ambient_interval` | number | `2000` | How often ambient effect triggers in ms |
| `animation.ambient_options` | table | see below | Per-effect ambient configuration options |
| `animation.char_preset` | string | `"default"` | Character preset: `"default"`, `"minimal"`, `"matrix"`, `"blocks"`, `"braille"`, `"stars"`, `"geometric"`, `"binary"`, `"dots"` |
| `animation.effect_chars` | table | `{}` | Per-effect charset overrides. Keys are effect names, values are preset names or raw character strings. e.g. `{ matrix = "matrix", rain = "│┃┆┇┊┋" }` |
| `animation.use_phase_highlights` | boolean | `false` | Enable phase-based highlight groups (see Highlight Groups section) |
| `animation.color_theme` | string | `nil` | Color theme for phase highlights (auto-enables phase highlights): `"default"`, `"cyberpunk"`, `"matrix"`, `"ocean"`, `"sunset"`, `"forest"`, `"monochrome"`, `"dracula"`, `"nord"` |
| `animation.color_mode` | string | `"default"` | Line coloring mode: `"default"`, `"rainbow"`, `"gradient"` |
| `animation.rainbow.palette` | string | `"default"` | Rainbow palette: `"default"`, `"pastel"`, `"neon"`, `"warm"`, `"cool"`, `"mono"` |
| `animation.gradient.preset` | string | `"sunset"` | Gradient preset: `"sunset"`, `"ocean"`, `"forest"`, `"fire"`, `"purple"`, `"pink"`, `"midnight"`, `"aurora"` |
| `animation.gradient.start` | string | `nil` | Custom gradient start color (hex, overrides preset) |
| `animation.gradient.stop` | string | `nil` | Custom gradient stop color (hex, overrides preset) |
| `animation.period_colors` | boolean | `false` | Enable period-based color schemes (auto-enables phase highlights) |
| `animation.period_color_overrides` | table | `{}` | Override specific period colors: `{ morning = { revealed = "#ff6600" } }` |
| `animation.reduced_motion` | boolean | `false` | Skip animation entirely and show final ASCII art immediately. Ambient effects still work. |
| `animation.auto_fit` | boolean | `false` | Skip arts wider than terminal width |
| `animation.min_width` | number | `60` | Minimum terminal width for animation |
| `animation.fallback` | string | `"tagline"` | Fallback when terminal too narrow: `"tagline"`, `"none"`, or art ID |
| `chaos_chars` | string | `"@#$%&*..."` | Characters used for chaos/typewriter effect |
| `header.padding` | number | `3` | Extra lines to include after header |

### Content Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `content.enabled` | boolean | `true` | Enable content system |
| `content.builtin_arts` | boolean | `true` | Use built-in ASCII art collection |
| `content.builtin_messages` | boolean | `true` | Use built-in taglines |
| `content.styles` | table/nil | `nil` | Filter styles: `{"blocks", "gradient", "isometric", "box", "minimal", "pixel", "braille"}` |
| `content.weekend_override` | boolean | `true` | Use weekend content on Sat/Sun |
| `content.placeholders` | table | `{}` | Override auto-detected placeholder values |
| `content.placeholders.name` | string | auto | User's name (auto: git user.name) |
| `content.placeholders.project` | string | auto | Project name (auto: cwd basename) |
| `content.placeholders.date_format` | string | `"%B %d, %Y"` | Date format string |
| `content.custom_arts` | table | `{}` | User-defined arts by period |
| `content.custom_messages` | table | `{}` | User-defined messages by period |
| `content.random` | string | `"always"` | Randomization mode: `"always"`, `"daily"`, or `"session"` |
| `content.favorites` | table | `{}` | List of art IDs for higher selection probability |
| `content.favorite_weight` | number | `2` | Multiplier for favorites in selection pool |
| `content.no_repeat` | boolean/number | `false` | Don't repeat last N arts: `false`, `true` (1), or number |
| `content.message_no_repeat` | boolean/number | `false` | Don't repeat last N messages: `false`, `true` (1), or number |
| `content.message_categories` | table/nil | `nil` | Include-list: only show messages from these theme categories (e.g. `{"zen", "witty"}`) |
| `content.exclude_categories` | table/nil | `nil` | Exclude-list: hide messages from these theme categories (e.g. `{"cryptic"}`) |

Message favorites and disabled states are managed via `:AsciiSettings` → `g` (Message Browser) and persist automatically.

### Footer Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `footer.enabled` | boolean | `true` | Enable/disable footer |
| `footer.template` | string | `"{message}"` | Template with placeholders: `{message}`, `{date}`, `{time}`, `{version}`, `{plugins}`, `{name}`, `{project}` |
| `footer.alignment` | string | `"center"` | Footer alignment: `"left"`, `"center"`, or `"right"` |

## API

### Manual Animation

You can trigger the animation manually on any buffer:

```lua
-- Animate current buffer
require("ascii-animation").animate_buffer()

-- Animate specific buffer with options
require("ascii-animation").animate_buffer(bufnr, lines_count, highlight_group)
```

### Content API

```lua
local ascii = require("ascii-animation")

-- Get complete header for current time period
local header = ascii.get_header()
-- Returns: {
--   art = { "line1", "line2", ... },  -- ASCII art lines
--   message = "Rise and shine!",       -- Tagline
--   footer = "Rise and shine!",        -- Rendered footer (from template)
--   period = "morning",                -- Current period
--   art_id = "morning_blocks_1",       -- Art identifier
--   art_name = "Good Morning",         -- Art display name
-- }

-- Get rendered footer string
local footer = ascii.get_footer()  -- "Rise and shine! • February 05, 2026"

-- Get footer lines aligned for dashboard integration
local footer_lines = ascii.get_footer_lines(80)  -- width optional, defaults to terminal width
-- Returns: { "                    Rise and shine!" }  -- center-aligned

-- Get current time period
ascii.get_current_period()  -- "morning" | "afternoon" | "evening" | "night" | "weekend"

-- Get random art for current period
local art = ascii.get_art()
-- Returns: { id = "...", name = "...", lines = {...} }

-- Get random message for current period
local message = ascii.get_message()  -- "Rise and shine!"

-- Period-specific selection
ascii.get_art_for_period("evening")
ascii.get_message_for_period("night")
ascii.get_header_for_period("weekend")

-- List and lookup
ascii.list_arts()                        -- All art IDs
ascii.list_arts_for_period("morning")    -- Art IDs for period
ascii.get_art_by_id("morning_blocks_1")  -- Specific art by ID
ascii.get_styles()                       -- {"blocks", "gradient", "isometric", "box", "minimal", "pixel", "braille"}

-- Commands (programmatic access)
ascii.preview("morning_blocks_1")        -- Preview art in floating window
ascii.settings()                         -- Open settings panel
ascii.refresh()                          -- Re-run animation on current buffer
ascii.stop()                             -- Stop any running animation
```

### Placeholders API

```lua
local placeholders = require("ascii-animation").placeholders

-- Process a string with placeholders
local text = placeholders.process("Hello, {name}! Working on {project}?")
-- Returns: "Hello, John! Working on my-project?"

-- Process multi-line messages (returns table of processed strings)
local lines = placeholders.process({ "Hello, {name}!", "Welcome to {project}." })
-- Returns: { "Hello, John!", "Welcome to my-project." }

-- Check if a message is multi-line
placeholders.is_multiline({ "Line 1", "Line 2" })  -- true
placeholders.is_multiline("Single line")           -- false

-- Flatten multi-line to single string (for display contexts that need it)
placeholders.flatten({ "Line 1", "Line 2" })       -- "Line 1\nLine 2"
placeholders.flatten({ "A", "B" }, " • ")          -- "A • B"

-- Resolve a single placeholder
placeholders.resolve("name")     -- "John"
placeholders.resolve("project")  -- "my-project"
placeholders.resolve("time")     -- "morning"
placeholders.resolve("version")  -- "v0.10.0"

-- List available placeholders
placeholders.list_placeholders() -- {"name", "project", "time", "date", "version", "plugin_count"}

-- Clear cached values (useful for testing)
placeholders.clear_cache()
```

### Advanced Usage

Access the animation module directly for custom implementations:

```lua
local animation = require("ascii-animation").animation

-- Start animation with full control
animation.start(buf, header_lines, highlight)

-- Use individual functions
local chaotic = animation.chaos_line("Hello World", 0.5)  -- 50% revealed
local delay = animation.get_frame_delay(10, 40)  -- Frame 10 of 40
```

## How It Works

### Chaos Effect (default)
1. **Chaos Phase**: Text starts as random characters from the `chaos_chars` pool
2. **Reveal Phase**: Characters progressively reveal randomly using an ease-in-out curve
3. **Timing**: Frame delays vary from slow (edges) to fast (middle) for cinematic effect

### Typewriter Effect
1. **Left-to-right**: Characters reveal sequentially from left to right
2. **Cursor**: A cursor (`▌`) shows the current typing position
3. **Unrevealed**: Characters not yet typed are hidden

### Diagonal Effect
1. **Sweep**: Reveal spreads from top-left corner to bottom-right
2. **Wave**: Top lines reveal before bottom lines, creating a diagonal wave
3. **Timing**: Linear progression with fast frame delays

### Lines Effect
1. **Sequential**: Each line reveals one at a time from top to bottom
2. **Transition**: Current line uses chaos effect while revealing
3. **Timing**: Ease-in-out with moderate frame delays

### Matrix Effect
1. **Rain**: Characters "fall" and settle into place like the Matrix
2. **Staggered**: Each character has unique timing based on position
3. **Chaos**: Falling characters display random matrix-style symbols

### Wave Effect
1. **Ripple**: Characters reveal in an expanding circular pattern from an origin point
2. **Origin**: Configurable starting point - center, corners, or edges
3. **Organic**: Creates water-like ripple reveal pattern using euclidean distance

**Origin Options:**
- `"center"` (default) - Ripple expands from the center
- `"top-left"`, `"top-right"`, `"bottom-left"`, `"bottom-right"` - Corner origins
- `"top"`, `"bottom"`, `"left"`, `"right"` - Edge origins

```lua
animation = {
  effect = "wave",
  effect_options = {
    origin = "center",  -- Starting point for the wave
    speed = 1.0,        -- 1.0 = normal, >1 = faster, <1 = slower
  },
}
```

### Fade Effect
1. **Brightness**: Text fades in from dim to bright using dynamic highlight groups
2. **Stagger**: Top lines fade in first, creating a cascading brightness wave
3. **Smooth**: Uses ease-in-out timing for a cinematic feel
4. **Configurable**: Adjust `highlight_count` (5-20) for smoother or more stepped fade

### Scramble Effect
1. **Slot machine**: Characters cycle through random symbols before settling
2. **Stagger**: Characters settle in order based on stagger direction (left, right, center, random)
3. **Configurable**: Adjust `cycles` for longer/shorter scramble duration

### Rain Effect
1. **Falling**: Characters "rain" down and stack from the bottom up
2. **Column-based**: Each column has unique timing for natural rain feel
3. **Atmospheric**: Creates a digital rain aesthetic

### Spiral Effect
1. **Geometric**: Characters reveal in a spiral pattern from center or edges
2. **Direction**: Choose `outward` (center→edge) or `inward` (edge→center)
3. **Rotation**: Select `clockwise` or `counter`-clockwise spiral
4. **Tightness**: Adjust spiral coil density (0.5-2.0)

### Explode Effect
1. **Outward**: Characters reveal from center outward like an explosion
2. **Radial**: Creates expanding ring pattern from the middle
3. **Dynamic**: Fast middle, slowing at edges

### Implode Effect
1. **Inward**: Characters reveal from edges inward, opposite of explode
2. **Converging**: Creates collapsing effect toward center
3. **Dramatic**: Good for attention-grabbing reveals

### Glitch Effect
1. **Cyberpunk**: Characters progressively stabilize through digital corruption
2. **Block glitches**: Random rectangular areas show corrupted characters
3. **Multi-highlight**: Glitched sections use varied error colors
4. **Configurable**: Adjust intensity, block chance, block size, and resolve speed

### Random Effect
1. **Variety**: Randomly selects one of the 13 effects each time animation starts
2. **Loop variety**: When looping, picks a new random effect for each cycle

All effects use Neovim's extmarks with virtual text overlay, preserving your original buffer content and highlights.

### Loop Mode

When `loop` is enabled, the animation replays continuously after a configurable delay:

```lua
animation = {
  loop = true,           -- Enable loop mode
  loop_delay = 2000,     -- Wait 2 seconds between loops
  loop_reverse = true,   -- Play in reverse before looping (optional)
}
```

With `loop_reverse`, the animation will: forward → pause → reverse → pause → forward → ...

### Ambient Effects

Ambient effects add subtle ongoing visual interest after the animation completes (only when not looping):

- **`"glitch"`**: Random characters briefly flicker to chaos characters
- **`"shimmer"`**: Single random characters briefly flash
- **`"cursor_trail"`**: A virtual cursor moves through the art leaving a fading trail
- **`"sparkle"`**: Random sparkle characters (✦✧★·) appear at random positions
- **`"scanlines"`**: CRT-style horizontal dimmed lines overlay
- **`"noise"`**: Random noise characters replace some chars briefly
- **`"shake"`**: Simulates screen shake by offsetting text positions
- **`"sound"`**: Plays a sound file at each interval (requires configuration)

```lua
animation = {
  ambient = "sparkle",      -- Choose your ambient effect
  ambient_interval = 2000,  -- Trigger every 2 seconds

  -- Per-effect options (only the selected effect's options are used)
  ambient_options = {
    cursor_trail = {
      trail_chars = "▓▒░",   -- Trail characters (brightest to dimmest)
      trail_length = 3,       -- Number of trail chars
      move_speed = 1,         -- Chars to move per tick
    },
    sparkle = {
      chars = "✦✧★·",        -- Sparkle characters
      density = 0.05,         -- % of non-space chars to sparkle (0.05 = 5%)
    },
    scanlines = {
      spacing = 2,            -- Every Nth line gets dimmed
      dim_amount = 0.5,       -- Brightness reduction (0.5 = 50% dimmer)
    },
    noise = {
      intensity = 0.1,        -- % of non-space chars affected (0.1 = 10%)
    },
    shake = {
      max_offset = 2,         -- Maximum chars to offset
      line_probability = 0.3, -- Probability each line shakes (0.3 = 30%)
    },
    sound = {
      file_path = nil,        -- Path to sound file (required for sound effect)
      volume = 50,            -- Volume 0-100 (macOS: afplay, Linux: paplay)
    },
  },
}
```

> **Note:** The `sound` effect requires a configured `file_path` and uses system audio commands: `afplay` (macOS, built-in) or `paplay` (Linux, requires PulseAudio).

### Highlight Groups

When `use_phase_highlights` is enabled, the animation uses dedicated highlight groups for different character states. This allows you to customize colors based on whether a character is in the chaos, revealing, or revealed phase.

**Enable with a color theme (recommended):**

```lua
animation = {
  color_theme = "cyberpunk", -- or "matrix", "ocean", "sunset", "forest", "monochrome", "dracula", "nord"
}
```

**Enable with default colors:**

```lua
animation = {
  use_phase_highlights = true,
}
```

**Available highlight groups:**

| Highlight Group | Default | Description |
|-----------------|---------|-------------|
| `AsciiAnimationChaos` | `#555555` | Unrevealed chaos characters |
| `AsciiAnimationRevealing` | `#888888` | Characters about to reveal |
| `AsciiAnimationRevealed` | `#ffffff` | Fully revealed characters |
| `AsciiAnimationCursor` | `#00ff00` bold | Typewriter cursor |
| `AsciiAnimationGlitch` | `#ff0055` | Glitch effect corruption |

**Customize in your colorscheme or config:**

```lua
-- In your Neovim config (after colorscheme is loaded)
vim.api.nvim_set_hl(0, "AsciiAnimationChaos", { fg = "#1a1a2e" })
vim.api.nvim_set_hl(0, "AsciiAnimationRevealing", { fg = "#4a4a6a" })
vim.api.nvim_set_hl(0, "AsciiAnimationRevealed", { link = "Title" })
vim.api.nvim_set_hl(0, "AsciiAnimationCursor", { fg = "#00ff41", bold = true })
vim.api.nvim_set_hl(0, "AsciiAnimationGlitch", { fg = "#ff0066", bold = true })
```

**Colorscheme integration example:**

```lua
-- In your custom colorscheme file
local colors = {
  chaos = "#2d2d44",
  revealing = "#5a5a8a",
  revealed = "#e0e0e0",
  cursor = "#00ff41",
  glitch = "#ff3366",
}

vim.api.nvim_set_hl(0, "AsciiAnimationChaos", { fg = colors.chaos })
vim.api.nvim_set_hl(0, "AsciiAnimationRevealing", { fg = colors.revealing })
vim.api.nvim_set_hl(0, "AsciiAnimationRevealed", { fg = colors.revealed })
vim.api.nvim_set_hl(0, "AsciiAnimationCursor", { fg = colors.cursor, bold = true })
vim.api.nvim_set_hl(0, "AsciiAnimationGlitch", { fg = colors.glitch })
```

**Color Themes:**

Setting `color_theme` automatically enables phase highlights. Available themes:

| Theme | Description |
|-------|-------------|
| `default` | Neutral gray-to-white with green cursor |
| `cyberpunk` | Neon green/magenta on dark purple |
| `matrix` | Classic green-on-black terminal style |
| `ocean` | Cool blue tones with cyan accents |
| `sunset` | Warm orange/amber on dark purple |
| `forest` | Natural green palette with yellow cursor |
| `monochrome` | Elegant grayscale |
| `dracula` | Popular Dracula colorscheme colors |
| `nord` | Arctic, bluish-gray Nord palette |

**Using `:AsciiSettings` (recommended for quick customization):**

Press `P` in the settings panel to access the Phase Colors submenu, where you can:
- Press `T` to cycle through all 9 color themes
- Edit individual colors by pressing `1`-`5` and entering a hex color
- Reset custom colors with `r` (reverts to current theme defaults)

Settings are automatically persisted across sessions.

**Note:** The plugin applies custom colors from `:AsciiSettings` first. If you want to override via your colorscheme, define the highlight groups before the animation runs. When `use_phase_highlights` is disabled (default), the animation uses the dashboard's base highlight for all characters.

### Rainbow and Gradient Color Modes

In addition to phase-based highlighting, you can apply line-based coloring with rainbow or gradient modes.

**Rainbow Mode:**

Each line gets a different color from a palette, cycling through the colors:

```lua
animation = {
  color_mode = "rainbow",
  rainbow = {
    palette = "neon", -- or "default", "pastel", "warm", "cool", "mono"
  },
}
```

**Available Rainbow Palettes:**

| Palette | Colors |
|---------|--------|
| `default` | Classic ROYGBIV rainbow |
| `pastel` | Soft, muted tones |
| `neon` | Bright, vibrant colors |
| `warm` | Red to yellow gradient |
| `cool` | Blue to cyan gradient |
| `mono` | White to dark grayscale |

**Gradient Mode:**

Smooth color transition from top to bottom of the ASCII art:

```lua
animation = {
  color_mode = "gradient",
  gradient = {
    preset = "ocean", -- or "sunset", "forest", "fire", "purple", "pink", "midnight", "aurora"
    -- Custom colors override preset:
    -- start = "#ff0000",
    -- stop = "#0000ff",
  },
}
```

**Available Gradient Presets:**

| Preset | Transition |
|--------|------------|
| `sunset` | Orange to yellow |
| `ocean` | Cyan to blue |
| `forest` | Teal to green |
| `fire` | Red to orange |
| `purple` | Purple to indigo |
| `pink` | Rose to light pink |
| `midnight` | Dark gray gradient |
| `aurora` | Cyan to green |

**Using `:AsciiSettings` (press `C` from main menu):**

- Press `m` to cycle through color modes (default, rainbow, gradient)
- In rainbow mode: press `p` to cycle palettes
- In gradient mode: press `g` to cycle presets, `1`/`2` to edit start/stop colors

### Period-Based Color Schemes

Automatically apply different color schemes based on the time of day. Morning feels warm and energetic, night feels cool and calm.

**Enable in config:**

```lua
animation = {
  period_colors = true, -- Auto-enables phase highlights
}
```

**Default period color mapping:**

| Period | Chaos | Revealing | Revealed | Mood |
|--------|-------|-----------|----------|------|
| Morning | `#1a0a00` | `#ff9500` (warm orange) | `#ffcc00` (golden yellow) | warm |
| Afternoon | `#001a1a` | `#00aa88` (teal) | `#00ffcc` (bright cyan) | teal |
| Evening | `#0a0015` | `#ff6b9d` (soft pink) | `#ffa07a` (light salmon) | soft |
| Night | `#0a0a1a` | `#6666ff` (soft blue) | `#aaaaff` (light purple) | cool |
| Weekend | `#0a1a0a` | `#66ff66` (light green) | `#aaffaa` (pale green) | fresh |

**Override specific periods:**

```lua
animation = {
  period_colors = true,
  period_color_overrides = {
    morning = {
      revealed = "#ff6600", -- Custom morning revealed color
    },
    night = {
      chaos = "#000033",
      revealing = "#4444cc",
      revealed = "#8888ff",
    },
  },
}
```

**Using `:AsciiSettings`:** Press `z` to toggle period colors on/off. The current period and mood are shown next to the setting.

## Credits

Inspired by the "decryption" text effects seen in movies and games.

## License

MIT
