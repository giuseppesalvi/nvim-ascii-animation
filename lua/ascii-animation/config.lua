-- Default configuration for ascii-animation
local M = {}

M.defaults = {
  -- Animation settings
  animation = {
    enabled = true,
    -- Animation effect: "chaos" | "typewriter" | "diagonal" | "lines" | "matrix" | "random"
    effect = "chaos",
    -- Total steps in the animation
    steps = 40,
    -- Frame delay range (ms)
    min_delay = 20,   -- Fastest (middle of animation)
    max_delay = 120,  -- Slowest (start/end of animation)
    -- Loop settings
    loop = false,           -- Enable loop mode
    loop_delay = 2000,      -- Delay between loops (ms)
    loop_reverse = false,   -- Play reverse before next loop
    -- Ambient effect (when not looping)
    ambient = "none",       -- "none" | "glitch" | "shimmer"
    ambient_interval = 2000, -- How often ambient effect triggers (ms)
  },

  -- Chaos characters used during animation
  chaos_chars = "@#$%&*+=-:;!?/\\|[]{}()<>~`'^",

  -- Header content settings
  header = {
    -- Extra lines to include after header (for tagline, date, etc.)
    padding = 3,
  },

  -- Content system settings
  content = {
    enabled = true,              -- Enable content management
    builtin_arts = true,         -- Use built-in ASCII art collection
    builtin_messages = true,     -- Use built-in taglines

    -- User additions (merged with built-in)
    custom_arts = {},            -- User-defined arts by period
    custom_messages = {},        -- User-defined messages by period

    -- Personalization placeholders
    -- Supported: {name}, {project}, {time}, {date}, {version}, {plugin_count}
    placeholders = {
      -- name = "Developer",     -- Override auto-detected git user.name
      -- project = nil,          -- Override auto-detected project name
      -- date_format = "%B %d, %Y",  -- Custom date format
    },

    -- Time configuration
    time_periods = {
      morning   = { start = 5,  stop = 12 },
      afternoon = { start = 12, stop = 17 },
      evening   = { start = 17, stop = 21 },
      night     = { start = 21, stop = 5 },
    },
    weekend_override = true,     -- Use weekend content on Sat/Sun

    -- Style filter (nil = all styles)
    -- Available: "blocks", "gradient", "isometric"
    styles = nil,
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

-- Initialize with defaults
M.setup()

return M
