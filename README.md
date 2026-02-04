# nvim-ascii-animation

Cinematic text animation for Neovim dashboards. Watch your ASCII art materialize from chaos with a smooth ease-in-out animation effect.

![Demo](https://github.com/giuseppesalvi/nvim-ascii-animation/assets/demo.gif)

## Features

- Smooth **chaos-to-reveal** animation effect
- **Ease-in-out** timing: slow start → fast middle → slow finish
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

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `animation.enabled` | boolean | `true` | Enable/disable animation |
| `animation.steps` | number | `40` | Total animation steps (more = smoother) |
| `animation.min_delay` | number | `20` | Fastest frame delay in ms (middle of animation) |
| `animation.max_delay` | number | `120` | Slowest frame delay in ms (start/end) |
| `chaos_chars` | string | `"@#$%&*..."` | Characters used for chaos effect |
| `header.padding` | number | `3` | Extra lines to include after header |

## API

### Manual Animation

You can trigger the animation manually on any buffer:

```lua
-- Animate current buffer
require("ascii-animation").animate_buffer()

-- Animate specific buffer with options
require("ascii-animation").animate_buffer(bufnr, lines_count, highlight_group)
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

1. **Chaos Phase**: Text starts as random characters from the `chaos_chars` pool
2. **Reveal Phase**: Characters progressively reveal using an ease-in-out curve
3. **Timing**: Frame delays vary from slow (edges) to fast (middle) for cinematic effect

The animation uses Neovim's extmarks with virtual text overlay, preserving your original buffer content and highlights.

## Credits

Inspired by the "decryption" text effects seen in movies and games.

## License

MIT
