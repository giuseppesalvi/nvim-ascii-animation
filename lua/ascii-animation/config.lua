-- Default configuration for ascii-animation
local M = {}

-- Path for persistent settings
local data_path = vim.fn.stdpath("data") .. "/ascii-animation.json"

M.defaults = {
  -- Animation settings
  animation = {
    enabled = true,
    -- Animation effect: "chaos" | "typewriter" | "diagonal" | "lines" | "matrix" | "wave" | "fade" | "random"
    effect = "chaos",
    -- Effect-specific options (used by wave effect)
    effect_options = {
      -- Wave effect origin: "center" | "top-left" | "top-right" | "bottom-left" | "bottom-right" | "top" | "bottom" | "left" | "right"
      origin = "center",
      -- Wave propagation speed multiplier (1.0 = normal, >1 = faster, <1 = slower)
      speed = 1.0,
    },
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
    -- Terminal width handling
    auto_fit = false,       -- Skip arts wider than terminal
    min_width = 60,         -- Minimum terminal width for animation
    fallback = "tagline",   -- "tagline" | "none" | art_id
  },

  -- Content selection settings
  selection = {
    -- Randomization mode: "always" | "daily" | "session"
    -- "always": New random art each time (default)
    -- "daily": Same art all day (based on date seed)
    -- "session": Same art within Neovim session
    random_mode = "always",
    -- No-repeat: Don't show the same art twice in a row
    no_repeat = false,
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

    -- Randomization mode: "always" | "daily" | "session"
    -- "always": New random art each time (default, current behavior)
    -- "daily": Same art all day (based on date seed)
    -- "session": Same art within Neovim session, different on restart
    random = "always",

    -- Favorites system
    favorites = {},              -- List of art IDs for higher selection probability
    favorite_weight = 2,         -- Multiplier for favorites in selection pool

    -- No-repeat: false | true | number
    -- false: No filtering (default)
    -- true: Don't repeat the last shown art
    -- number N: Don't repeat any of the last N shown arts
    no_repeat = false,
  },
}

M.options = {}

-- Load saved settings from disk
function M.load_saved()
  local file = io.open(data_path, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()
  local ok, saved = pcall(vim.json.decode, content)
  if ok and saved then
    return saved
  end
  return {}
end

-- Favorites list (art IDs)
M.favorites = {}

-- Favorites weight (0-100): chance of picking a favorite when available
M.favorites_weight = 70

-- Save current settings to disk
function M.save()
  -- Only save settings that can be changed via UI
  local to_save = {
    animation = {
      effect = M.options.animation.effect,
      ambient = M.options.animation.ambient,
      loop = M.options.animation.loop,
      steps = M.options.animation.steps,
    },
    selection = {
      random_mode = M.options.selection.random_mode,
      no_repeat = M.options.selection.no_repeat,
    },
    favorites = M.favorites,
    favorites_weight = M.favorites_weight,
  }
  local ok, json = pcall(vim.json.encode, to_save)
  if not ok then
    return false
  end
  local file = io.open(data_path, "w")
  if not file then
    return false
  end
  file:write(json)
  file:close()
  return true
end

-- Clear saved settings (reset to config defaults)
function M.clear_saved()
  os.remove(data_path)
  M.favorites = {}
  M.favorites_weight = 70
  M.options.selection.random_mode = M.defaults.selection.random_mode
  M.options.selection.no_repeat = M.defaults.selection.no_repeat
end

-- Toggle favorite status for an art ID
function M.toggle_favorite(art_id)
  for i, id in ipairs(M.favorites) do
    if id == art_id then
      table.remove(M.favorites, i)
      M.save()
      return false -- removed
    end
  end
  table.insert(M.favorites, art_id)
  M.save()
  return true -- added
end

-- Check if an art is favorited
function M.is_favorite(art_id)
  for _, id in ipairs(M.favorites) do
    if id == art_id then
      return true
    end
  end
  return false
end

function M.setup(opts)
  -- Load saved settings (from UI changes)
  local saved = M.load_saved()
  -- Merge: defaults < user opts < saved UI settings
  -- This ensures UI-changed settings persist over config file settings
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {}, saved)
  -- Load favorites separately
  if saved.favorites then
    M.favorites = saved.favorites
  end
  if saved.favorites_weight then
    M.favorites_weight = saved.favorites_weight
  end
end

-- Initialize with defaults
M.setup()

return M
