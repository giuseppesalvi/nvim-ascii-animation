-- Default configuration for ascii-animation
local M = {}

-- Color themes for phase highlights
M.color_themes = {
  default = { chaos = "#555555", revealing = "#888888", revealed = "#ffffff", cursor = "#00ff00", glitch = "#ff0055" },
  cyberpunk = { chaos = "#1a1a2e", revealing = "#4a4a6a", revealed = "#00ff41", cursor = "#ff00ff", glitch = "#ff3366" },
  matrix = { chaos = "#003300", revealing = "#00aa00", revealed = "#00ff41", cursor = "#ffffff", glitch = "#00ff00" },
  ocean = { chaos = "#1a3a4a", revealing = "#3a6a8a", revealed = "#8ad4ff", cursor = "#00ffcc", glitch = "#ff6b6b" },
  sunset = { chaos = "#2a1a2a", revealing = "#6a3a5a", revealed = "#ffaa77", cursor = "#ffff00", glitch = "#ff4466" },
  forest = { chaos = "#1a2a1a", revealing = "#3a5a3a", revealed = "#88cc88", cursor = "#ffff44", glitch = "#ff6644" },
  monochrome = { chaos = "#333333", revealing = "#666666", revealed = "#cccccc", cursor = "#ffffff", glitch = "#999999" },
  dracula = { chaos = "#282a36", revealing = "#bd93f9", revealed = "#f8f8f2", cursor = "#50fa7b", glitch = "#ff79c6" },
  nord = { chaos = "#2e3440", revealing = "#88c0d0", revealed = "#eceff4", cursor = "#a3be8c", glitch = "#bf616a" },
}

-- Ordered list of theme names for cycling
M.color_theme_names = { "default", "cyberpunk", "matrix", "ocean", "sunset", "forest", "monochrome", "dracula", "nord" }

-- Rainbow color palettes
M.rainbow_palettes = {
  default = { "#ff0000", "#ff7f00", "#ffff00", "#00ff00", "#0000ff", "#4b0082", "#9400d3" },
  pastel = { "#ffb3ba", "#ffdfba", "#ffffba", "#baffc9", "#bae1ff", "#e0bbff", "#ffb3de" },
  neon = { "#ff00ff", "#00ffff", "#ff00aa", "#00ff00", "#ffff00", "#ff5500", "#aa00ff" },
  warm = { "#ff0000", "#ff4400", "#ff8800", "#ffbb00", "#ffee00", "#ffff44", "#ffffaa" },
  cool = { "#0000ff", "#0044ff", "#0088ff", "#00bbff", "#00eeff", "#44ffff", "#aaffff" },
  mono = { "#ffffff", "#dddddd", "#bbbbbb", "#999999", "#777777", "#555555", "#333333" },
}

-- Ordered list of rainbow palette names
M.rainbow_palette_names = { "default", "pastel", "neon", "warm", "cool", "mono" }

-- Gradient presets (start -> stop colors)
M.gradient_presets = {
  sunset = { start = "#ff6b35", stop = "#f7931e" },
  ocean = { start = "#00c6ff", stop = "#0072ff" },
  forest = { start = "#11998e", stop = "#38ef7d" },
  fire = { start = "#f12711", stop = "#f5af19" },
  purple = { start = "#8e2de2", stop = "#4a00e0" },
  pink = { start = "#ee9ca7", stop = "#ffdde1" },
  midnight = { start = "#232526", stop = "#414345" },
  aurora = { start = "#00c9ff", stop = "#92fe9d" },
}

-- Ordered list of gradient preset names
M.gradient_preset_names = { "sunset", "ocean", "forest", "fire", "purple", "pink", "midnight", "aurora" }

-- Color mode names for cycling
M.color_mode_names = { "default", "rainbow", "gradient" }

-- Character set presets for animation effects
M.char_presets = {
  default = "@#$%&*+=-:;!?/\\|[]{}()<>~`'^",
  minimal = "·•○◦◌░",
  matrix = "ｱｲｳｴｵｶｷｸｹｺ01",
  blocks = "█▓▒░▄▀▌▐■□",
  braille = "⠁⠂⠃⠄⠅⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏",
  stars = "✦✧★☆✴✵✶✷⋆",
  geometric = "◆◇○●□■△▲▽▼",
  binary = "01",
  dots = ".:;+*",
}

-- Ordered list of preset names for cycling
M.char_preset_names = { "default", "minimal", "matrix", "blocks", "braille", "stars", "geometric", "binary", "dots" }

-- Presets that require Unicode font support (not pure ASCII)
M.char_presets_unicode = {
  minimal = true,
  matrix = true,
  blocks = true,
  braille = true,
  stars = true,
  geometric = true,
}

-- Check if a preset requires Unicode font support
function M.preset_requires_unicode(preset)
  return M.char_presets_unicode[preset] or false
end

-- Get the current chaos characters (resolves preset to actual string)
function M.get_chaos_chars()
  local preset = M.options.animation and M.options.animation.char_preset or "default"
  return M.char_presets[preset] or M.char_presets.default
end

-- Get effective phase colors (theme colors merged with custom overrides)
function M.get_phase_colors()
  local theme_name = M.options.animation and M.options.animation.color_theme
  local theme = theme_name and M.color_themes[theme_name] or M.color_themes.default
  local custom = M.options.animation and M.options.animation.phase_colors or {}

  return {
    chaos = custom.chaos or theme.chaos,
    revealing = custom.revealing or theme.revealing,
    revealed = custom.revealed or theme.revealed,
    cursor = custom.cursor or theme.cursor,
    glitch = custom.glitch or theme.glitch,
  }
end

-- Check if phase highlights should be active (explicit setting or theme set)
function M.use_phase_highlights()
  local opts = M.options.animation or {}
  return opts.use_phase_highlights or opts.color_theme ~= nil
end

-- Get current color mode
function M.get_color_mode()
  local opts = M.options.animation or {}
  return opts.color_mode or "default"
end

-- Get rainbow colors (palette or custom)
function M.get_rainbow_colors()
  local opts = M.options.animation or {}
  local rainbow = opts.rainbow or {}
  if rainbow.custom_colors and #rainbow.custom_colors > 0 then
    return rainbow.custom_colors
  end
  local palette_name = rainbow.palette or "default"
  return M.rainbow_palettes[palette_name] or M.rainbow_palettes.default
end

-- Get gradient colors (preset or custom)
function M.get_gradient_colors()
  local opts = M.options.animation or {}
  local gradient = opts.gradient or {}
  local preset_name = gradient.preset or "sunset"
  local preset = M.gradient_presets[preset_name] or M.gradient_presets.sunset
  return {
    start = gradient.start or preset.start,
    stop = gradient.stop or preset.stop,
  }
end

-- Interpolate between two hex colors
function M.interpolate_color(start_hex, end_hex, ratio)
  -- Extract RGB from hex
  local function hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    return {
      r = tonumber(hex:sub(1, 2), 16),
      g = tonumber(hex:sub(3, 4), 16),
      b = tonumber(hex:sub(5, 6), 16),
    }
  end

  -- Convert RGB to hex
  local function rgb_to_hex(r, g, b)
    return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
  end

  local start_rgb = hex_to_rgb(start_hex)
  local end_rgb = hex_to_rgb(end_hex)

  local r = start_rgb.r + (end_rgb.r - start_rgb.r) * ratio
  local g = start_rgb.g + (end_rgb.g - start_rgb.g) * ratio
  local b = start_rgb.b + (end_rgb.b - start_rgb.b) * ratio

  return rgb_to_hex(r, g, b)
end

-- Path for persistent settings
local data_path = vim.fn.stdpath("data") .. "/ascii-animation.json"

M.defaults = {
  -- Animation settings
  animation = {
    enabled = true,
    -- Animation effect: "chaos" | "typewriter" | "diagonal" | "lines" | "matrix" | "wave" | "fade" | "scramble" | "rain" | "spiral" | "explode" | "implode" | "glitch" | "random"
    effect = "chaos",
    -- Effect-specific options
    effect_options = {
      -- Wave effect options
      origin = "center",  -- "center" | "top-left" | "top-right" | "bottom-left" | "bottom-right" | "top" | "bottom" | "left" | "right"
      speed = 1.0,        -- Wave propagation speed multiplier
      -- Glitch effect options
      glitch = {
        intensity = 0.5,       -- Glitch amount (0.0-1.0)
        block_chance = 0.2,    -- Probability of block-based glitching
        block_size = 5,        -- Maximum size of glitch blocks
        resolve_speed = 1.0,   -- Speed of glitch resolution (higher = faster)
      },
      -- Scramble effect options
      stagger = "left",        -- "left" | "right" | "center" | "random"
      cycles = 5,              -- Number of scramble cycles before settling
      -- Spiral effect options
      direction = "outward",   -- "outward" | "inward"
      rotation = "clockwise",  -- "clockwise" | "counter"
      tightness = 1.0,         -- Spiral tightness (0.5-2.0)
      -- Fade effect options
      highlight_count = 10,    -- Number of brightness levels (5-20)
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
    -- Character set preset for chaos/scramble effects
    char_preset = "default", -- "default" | "minimal" | "matrix" | "blocks" | "braille" | "stars" | "geometric" | "binary" | "dots"
    -- Phase-based highlighting (uses AsciiAnimation* highlight groups)
    use_phase_highlights = false,
    -- Color theme for phase highlights (auto-enables use_phase_highlights)
    -- Options: "default" | "cyberpunk" | "matrix" | "ocean" | "sunset" | "forest" | "monochrome" | "dracula" | "nord"
    color_theme = nil,
    -- Custom colors for phase highlights (overrides theme colors, nil = use theme/defaults)
    phase_colors = {
      chaos = nil,      -- Default: #555555
      revealing = nil,  -- Default: #888888
      revealed = nil,   -- Default: #ffffff
      cursor = nil,     -- Default: #00ff00
      glitch = nil,     -- Default: #ff0055
    },
    -- Terminal width handling
    auto_fit = false,       -- Skip arts wider than terminal
    min_width = 60,         -- Minimum terminal width for animation
    fallback = "tagline",   -- "tagline" | "none" | art_id
    -- Color mode for line coloring
    color_mode = "default", -- "default" | "rainbow" | "gradient"
    -- Rainbow mode options
    rainbow = {
      palette = "default",  -- "default" | "pastel" | "neon" | "warm" | "cool" | "mono"
      custom_colors = nil,  -- Custom color array (overrides palette)
    },
    -- Gradient mode options
    gradient = {
      preset = "sunset",    -- "sunset" | "ocean" | "forest" | "fire" | "purple" | "pink" | "midnight" | "aurora"
      start = nil,          -- Custom start color (overrides preset)
      stop = nil,           -- Custom stop color (overrides preset)
    },
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
    -- Available: "blocks", "gradient", "isometric", "box", "minimal", "pixel", "braille"
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

    -- Message no-repeat: false | true | number
    -- false: No filtering (default)
    -- true: Don't repeat the last shown message
    -- number N: Don't repeat any of the last N shown messages
    message_no_repeat = false,

  },

  -- Footer settings
  footer = {
    enabled = true,
    template = "{message}",  -- Available: {message}, {date}, {time}, {version}, {plugins}, {name}, {project}
    alignment = "center",    -- "left" | "center" | "right"
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

-- Message favorites (message IDs like "morning_1", "afternoon_5")
M.message_favorites = {}

-- Disabled messages (message IDs)
M.message_disabled = {}

-- Disabled themes (theme names like "cryptic", "philosophical")
M.themes_disabled = {}

-- Save current settings to disk
function M.save()
  -- Only save settings that can be changed via UI
  local to_save = {
    animation = {
      effect = M.options.animation.effect,
      effect_options = M.options.animation.effect_options,
      ambient = M.options.animation.ambient,
      loop = M.options.animation.loop,
      loop_delay = M.options.animation.loop_delay,
      loop_reverse = M.options.animation.loop_reverse,
      steps = M.options.animation.steps,
      min_delay = M.options.animation.min_delay,
      max_delay = M.options.animation.max_delay,
      ambient_interval = M.options.animation.ambient_interval,
      char_preset = M.options.animation.char_preset,
      use_phase_highlights = M.options.animation.use_phase_highlights,
      color_theme = M.options.animation.color_theme,
      phase_colors = M.options.animation.phase_colors,
      color_mode = M.options.animation.color_mode,
      rainbow = M.options.animation.rainbow,
      gradient = M.options.animation.gradient,
    },
    selection = {
      random_mode = M.options.selection.random_mode,
      no_repeat = M.options.selection.no_repeat,
    },
    content = {
      styles = M.options.content.styles,
      message_no_repeat = M.options.content.message_no_repeat,
    },
    message_favorites = M.message_favorites,
    message_disabled = M.message_disabled,
    themes_disabled = M.themes_disabled,
    footer = {
      enabled = M.options.footer.enabled,
      template = M.options.footer.template,
      alignment = M.options.footer.alignment,
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
  -- Reset animation settings
  M.options.animation.effect = M.defaults.animation.effect
  M.options.animation.effect_options = vim.deepcopy(M.defaults.animation.effect_options)
  M.options.animation.ambient = M.defaults.animation.ambient
  M.options.animation.loop = M.defaults.animation.loop
  M.options.animation.loop_delay = M.defaults.animation.loop_delay
  M.options.animation.loop_reverse = M.defaults.animation.loop_reverse
  M.options.animation.steps = M.defaults.animation.steps
  M.options.animation.min_delay = M.defaults.animation.min_delay
  M.options.animation.max_delay = M.defaults.animation.max_delay
  M.options.animation.ambient_interval = M.defaults.animation.ambient_interval
  M.options.animation.char_preset = M.defaults.animation.char_preset
  M.options.animation.use_phase_highlights = M.defaults.animation.use_phase_highlights
  M.options.animation.color_theme = M.defaults.animation.color_theme
  M.options.animation.phase_colors = vim.deepcopy(M.defaults.animation.phase_colors)
  M.options.animation.color_mode = M.defaults.animation.color_mode
  M.options.animation.rainbow = vim.deepcopy(M.defaults.animation.rainbow)
  M.options.animation.gradient = vim.deepcopy(M.defaults.animation.gradient)
  -- Reset content settings
  M.options.content.styles = M.defaults.content.styles
  M.options.content.message_no_repeat = M.defaults.content.message_no_repeat
  -- Reset message settings
  M.message_favorites = {}
  M.message_disabled = {}
  M.themes_disabled = {}
  -- Reset footer settings
  M.options.footer.enabled = M.defaults.footer.enabled
  M.options.footer.template = M.defaults.footer.template
  M.options.footer.alignment = M.defaults.footer.alignment
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

-- Toggle favorite status for a message ID
function M.toggle_message_favorite(msg_id)
  for i, id in ipairs(M.message_favorites) do
    if id == msg_id then
      table.remove(M.message_favorites, i)
      M.save()
      return false -- removed
    end
  end
  table.insert(M.message_favorites, msg_id)
  M.save()
  return true -- added
end

-- Check if a message is favorited
function M.is_message_favorite(msg_id)
  for _, id in ipairs(M.message_favorites) do
    if id == msg_id then
      return true
    end
  end
  return false
end

-- Toggle disabled status for a message ID
function M.toggle_message_disabled(msg_id)
  for i, id in ipairs(M.message_disabled) do
    if id == msg_id then
      table.remove(M.message_disabled, i)
      M.save()
      return false -- now enabled
    end
  end
  table.insert(M.message_disabled, msg_id)
  M.save()
  return true -- now disabled
end

-- Check if a message is disabled
function M.is_message_disabled(msg_id)
  for _, id in ipairs(M.message_disabled) do
    if id == msg_id then
      return true
    end
  end
  return false
end

-- Toggle disabled status for a theme
function M.toggle_theme_disabled(theme)
  for i, t in ipairs(M.themes_disabled) do
    if t == theme then
      table.remove(M.themes_disabled, i)
      M.save()
      return false -- now enabled
    end
  end
  table.insert(M.themes_disabled, theme)
  M.save()
  return true -- now disabled
end

-- Check if a theme is disabled
function M.is_theme_disabled(theme)
  for _, t in ipairs(M.themes_disabled) do
    if t == theme then
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
  -- Load message settings
  if saved.message_favorites then
    M.message_favorites = saved.message_favorites
  end
  if saved.message_disabled then
    M.message_disabled = saved.message_disabled
  end
  if saved.themes_disabled then
    M.themes_disabled = saved.themes_disabled
  end
end

-- Initialize with defaults
M.setup()

return M
