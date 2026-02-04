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

- Five **animation effects**: chaos, typewriter, diagonal, lines, and matrix
- **Ease-in-out** timing: slow start → fast middle → slow finish
- **60+ built-in ASCII arts** in 3 styles: blocks, gradient, isometric
- **Time-aware content**: morning, afternoon, evening, night, weekend themes
- **200+ motivational taglines** that match the time of day
- Works with popular dashboard plugins:
  - [snacks.nvim](https://github.com/folke/snacks.nvim)
  - [alpha-nvim](https://github.com/goolord/alpha-nvim)
  - [dashboard-nvim](https://github.com/nvimdev/dashboard-nvim)
  - [lazy.nvim](https://github.com/folke/lazy.nvim) starter screen
- Fully configurable animation speed, characters, and timing
- Respects your colorscheme and dashboard highlights

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "giuseppesalvi/nvim-ascii-animation",
  event = "VimEnter",
  opts = {
    animation = {
      enabled = true,
      effect = "chaos",  -- "chaos" | "typewriter" | "diagonal" | "lines" | "matrix"
      steps = 40,        -- Total animation steps
      min_delay = 20,    -- Fastest frame delay (ms)
      max_delay = 120,   -- Slowest frame delay (ms)
    },
    chaos_chars = "@#$%&*+=-:;!?/\\|[]{}()<>~`'^",
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

The plugin includes a built-in content system with **60+ ASCII arts** and **200+ taglines** that automatically adapt to the time of day.

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
    styles = nil,                 -- or {"blocks", "gradient", "isometric"}

    -- Custom time periods
    time_periods = {
      morning   = { start = 5,  stop = 12 },
      afternoon = { start = 12, stop = 17 },
      evening   = { start = 17, stop = 21 },
      night     = { start = 21, stop = 5 },
    },
    weekend_override = true,      -- Use weekend content on Sat/Sun

    -- Add your own content (merged with built-in)
    custom_arts = {
      morning = {
        { id = "my_art", name = "Custom", lines = { "Line 1", "Line 2" } },
      },
    },
    custom_messages = {
      morning = { "My custom message!", "Another one" },
    },
  },
})
```

## Options

### Animation Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `animation.enabled` | boolean | `true` | Enable/disable animation |
| `animation.effect` | string | `"chaos"` | Animation effect: `"chaos"`, `"typewriter"`, `"diagonal"`, `"lines"`, or `"matrix"` |
| `animation.steps` | number | `40` | Total animation steps (more = smoother) |
| `animation.min_delay` | number | `20` | Fastest frame delay in ms (middle of animation) |
| `animation.max_delay` | number | `120` | Slowest frame delay in ms (start/end) |
| `chaos_chars` | string | `"@#$%&*..."` | Characters used for chaos/typewriter effect |
| `header.padding` | number | `3` | Extra lines to include after header |

### Content Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `content.enabled` | boolean | `true` | Enable content system |
| `content.builtin_arts` | boolean | `true` | Use built-in ASCII art collection |
| `content.builtin_messages` | boolean | `true` | Use built-in taglines |
| `content.styles` | table/nil | `nil` | Filter styles: `{"blocks", "gradient", "isometric"}` |
| `content.weekend_override` | boolean | `true` | Use weekend content on Sat/Sun |
| `content.custom_arts` | table | `{}` | User-defined arts by period |
| `content.custom_messages` | table | `{}` | User-defined messages by period |

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
--   period = "morning",                -- Current period
--   art_id = "morning_blocks_1",       -- Art identifier
--   art_name = "Good Morning",         -- Art display name
-- }

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
ascii.get_styles()                       -- {"blocks", "gradient", "isometric"}
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

All effects use Neovim's extmarks with virtual text overlay, preserving your original buffer content and highlights.

## Credits

Inspired by the "decryption" text effects seen in movies and games.

## License

MIT
