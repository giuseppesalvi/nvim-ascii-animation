-- Animation module for ascii-animation
local config = require("ascii-animation.config")

local M = {}

M.ns_id = vim.api.nvim_create_namespace("ascii_animation")

-- Timer for ambient effects
local ambient_timer = nil

-- Fade effect state
local fade_state = {
  highlight_count = nil,    -- Number of brightness levels (from config)
  base_highlight = nil,     -- Track which highlight was used to create groups
}

-- Glitch effect constants
local glitch_chars = "█▓▒░▀▄▌▐▊▋▍▎▏┃┆┇┊┋╎╏│║▕▐▌"
local glitch_chars_table = vim.fn.split(glitch_chars, "\\zs")
local glitch_highlights = { "ErrorMsg", "WarningMsg", "DiffDelete", "DiffChange", "Special" }

-- Map config keys to highlight group names
local phase_highlight_groups = {
  chaos = "AsciiAnimationChaos",
  revealing = "AsciiAnimationRevealing",
  revealed = "AsciiAnimationRevealed",
  cursor = "AsciiAnimationCursor",
  glitch = "AsciiAnimationGlitch",
}

-- Track last applied colors to detect changes
local last_applied_colors = {}

-- Setup phase highlights with colors from config (theme + custom overrides)
local function setup_phase_highlights()
  local phase_colors = config.get_phase_colors()

  -- Check if colors changed since last setup
  local colors_changed = false
  for key, _ in pairs(phase_highlight_groups) do
    if last_applied_colors[key] ~= phase_colors[key] then
      colors_changed = true
      break
    end
  end

  -- Skip if no changes and already initialized
  if not colors_changed and next(last_applied_colors) ~= nil then
    return
  end

  -- Apply highlights
  for key, hl_name in pairs(phase_highlight_groups) do
    local color = phase_colors[key]
    local def
    if key == "cursor" then
      def = { fg = color, bold = true }
    else
      def = { fg = color }
    end
    vim.api.nvim_set_hl(0, hl_name, def)
    last_applied_colors[key] = color
  end
end

-- Force refresh of phase highlights (called when colors change)
local function refresh_phase_highlights()
  last_applied_colors = {}
  setup_phase_highlights()
end

-- State for rainbow/gradient highlights
local color_mode_state = {
  mode = nil,
  line_count = 0,
  rainbow_colors = nil,
  gradient_start = nil,
  gradient_stop = nil,
}

-- Setup rainbow highlight groups (one per color in palette, cycling for lines)
local function setup_rainbow_highlights()
  local colors = config.get_rainbow_colors()
  color_mode_state.rainbow_colors = colors

  for i, color in ipairs(colors) do
    local hl_name = "AsciiRainbow" .. i
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

-- Setup gradient highlight groups (one per line)
local function setup_gradient_highlights(line_count)
  local gradient = config.get_gradient_colors()
  color_mode_state.gradient_start = gradient.start
  color_mode_state.gradient_stop = gradient.stop
  color_mode_state.line_count = line_count

  for i = 1, line_count do
    local ratio = (i - 1) / math.max(1, line_count - 1)
    local color = config.interpolate_color(gradient.start, gradient.stop, ratio)
    local hl_name = "AsciiGradient" .. i
    vim.api.nvim_set_hl(0, hl_name, { fg = color })
  end
end

-- Get highlight name for a line based on color mode
local function get_line_highlight(line_num, base_highlight)
  local color_mode = config.get_color_mode()

  if color_mode == "rainbow" then
    local colors = color_mode_state.rainbow_colors or config.get_rainbow_colors()
    local color_idx = ((line_num - 1) % #colors) + 1
    return "AsciiRainbow" .. color_idx
  elseif color_mode == "gradient" then
    return "AsciiGradient" .. line_num
  else
    return base_highlight
  end
end

-- Setup color mode highlights based on current settings
local function setup_color_mode_highlights(line_count)
  local color_mode = config.get_color_mode()
  color_mode_state.mode = color_mode

  if color_mode == "rainbow" then
    setup_rainbow_highlights()
  elseif color_mode == "gradient" then
    setup_gradient_highlights(line_count)
  end
end

-- Force refresh of color mode highlights
local function refresh_color_mode_highlights(line_count)
  color_mode_state.mode = nil
  setup_color_mode_highlights(line_count or color_mode_state.line_count)
end

-- Get phase highlight name based on reveal ratio
local function get_phase_highlight(reveal_ratio, is_cursor, is_glitch)
  if is_glitch then
    return "AsciiAnimationGlitch"
  elseif is_cursor then
    return "AsciiAnimationCursor"
  elseif reveal_ratio >= 0.9 then
    return "AsciiAnimationRevealed"
  elseif reveal_ratio >= 0.3 then
    return "AsciiAnimationRevealing"
  else
    return "AsciiAnimationChaos"
  end
end

-- Cache for split chaos chars (to handle UTF-8 properly)
local chaos_chars_cache = {
  str = nil,
  chars = nil,
}

-- Get chaos chars as a table (handles UTF-8 multi-byte characters)
local function get_chaos_chars_table()
  local current = current_effect_name
    and config.get_chars_for_effect(current_effect_name)
    or config.get_chaos_chars()
  if chaos_chars_cache.str ~= current then
    chaos_chars_cache.str = current
    chaos_chars_cache.chars = vim.fn.split(current, "\\zs")
  end
  return chaos_chars_cache.chars
end

-- Get a random chaos character (UTF-8 safe)
local function random_chaos_char()
  local chars = get_chaos_chars_table()
  return chars[math.random(1, #chars)]
end

-- State for cursor trail ambient effect
local cursor_trail_state = { line = 1, col = 0 }

-- State for scanline highlight creation
local scanline_hl_created = false

-- Track current effect name for per-effect charset resolution
local current_effect_name = nil

-- State for tracking current animation
local animation_state = {
  running = false,
  paused = false,
  buf = nil,
  header_end = nil,
  highlight = nil,
  effect = nil,  -- Resolved effect (for "random" mode)
  step = nil,           -- Current step when paused
  total_steps = nil,    -- Total steps for resume
  win = nil,            -- Window for resume
  reverse = nil,        -- Direction for resume
  on_complete = nil,    -- Callback fired when animation finishes (non-looping)
  generation = 0,       -- Incremented on stop() to invalidate pending deferred callbacks
}

local loop_count = 0

local function fire_hook(hook_name, autocmd_pattern, ...)
  local hooks = config.options.hooks
  if hooks and hooks[hook_name] then
    local ok, err = pcall(hooks[hook_name], ...)
    if not ok then
      vim.schedule(function()
        vim.notify("[ascii-animation] Hook error (" .. hook_name .. "): " .. tostring(err), vim.log.levels.WARN)
      end)
    end
  end
  pcall(vim.api.nvim_exec_autocmds, "User", { pattern = autocmd_pattern })
end

-- Ease-in-out cubic function for smooth acceleration/deceleration
local function ease_in_out(t)
  if t < 0.5 then
    return 4 * t * t * t
  else
    return 1 - math.pow(-2 * t + 2, 3) / 2
  end
end

-- Calculate frame delay based on position (slow-fast-slow)
local function get_frame_delay(step, total_steps)
  local opts = config.options.animation
  local t = step / total_steps
  local center_dist = 1 - math.abs(t - 0.5) * 2
  local speed_factor = ease_in_out(center_dist)
  return math.floor(opts.max_delay - (speed_factor * (opts.max_delay - opts.min_delay)))
end

-- Create chaotic version of a line (preserving spaces for alignment)
local function chaos_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")

  if not use_phases then
    local result = {}
    for _, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      elseif math.random() < reveal_ratio then
        table.insert(result, char)
      else
        table.insert(result, random_chaos_char())
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for _, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local is_revealed = math.random() < reveal_ratio
      local output_char, phase
      if is_revealed then
        output_char = char
        phase = get_phase_highlight(reveal_ratio, false, false)
      else
        output_char = random_chaos_char()
        phase = "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create typewriter version of a line (left-to-right reveal with cursor)
local function typewriter_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")
  local cursor_pos = math.floor(#chars * reveal_ratio)

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      elseif idx == cursor_pos then
        table.insert(result, "▌")  -- Cursor at typing position
      elseif idx < cursor_pos then
        table.insert(result, char)  -- Revealed
      else
        table.insert(result, random_chaos_char())
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local output_char, phase
      if idx == cursor_pos then
        output_char = "▌"
        phase = "AsciiAnimationCursor"
      elseif idx < cursor_pos then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = random_chaos_char()
        phase = "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create diagonal sweep version (top-left to bottom-right)
local function diagonal_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")
  -- Offset reveal based on line position (top lines reveal first)
  local line_offset = (line_idx - 1) / total_lines * 0.3
  local adjusted_ratio = math.max(0, reveal_ratio - line_offset) / 0.7

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local char_ratio = (idx - 1) / #chars
        if char_ratio < adjusted_ratio then
          table.insert(result, char)
        else
          table.insert(result, random_chaos_char())
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local char_ratio = (idx - 1) / #chars
      local output_char, phase
      if char_ratio < adjusted_ratio then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = random_chaos_char()
        phase = "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create line-by-line sequential reveal
local function lines_line(line, reveal_ratio, line_idx, total_lines)
  local lines_revealed = math.floor(reveal_ratio * total_lines)

  if line_idx <= lines_revealed then
    return line  -- Fully revealed
  elseif line_idx == lines_revealed + 1 then
    -- Current line: use chaos effect for transition
    local sub_ratio = (reveal_ratio * total_lines) % 1
    return chaos_line(line, sub_ratio, line_idx, total_lines)
  else
    -- Not yet revealed: show as chaos
    return chaos_line(line, 0, line_idx, total_lines)
  end
end

-- Create matrix rain effect (characters fall and settle)
local function matrix_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local seed = (line_idx * 100 + idx) % 50
        local char_progress = reveal_ratio + seed / 100
        if char_progress >= 0.8 then
          table.insert(result, char)
        else
          table.insert(result, random_chaos_char())
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local seed = (line_idx * 100 + idx) % 50
      local char_progress = reveal_ratio + seed / 100
      local output_char, phase
      if char_progress >= 0.8 then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = random_chaos_char()
        -- Use revealing phase for chars close to settling
        phase = char_progress >= 0.5 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create wave effect (ripple reveal from origin point)
local function wave_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")

  -- Get wave options with defaults
  local effect_opts = config.options.animation.effect_options or {}
  local origin = effect_opts.origin or "center"
  local speed = effect_opts.speed or 1.0

  local line_count = total_lines
  local line_width = #chars

  -- Normalize line position (0-1 range)
  local norm_y = line_count > 1 and (line_idx - 1) / (line_count - 1) or 0.5

  -- Determine origin coordinates (normalized 0-1)
  local origin_x, origin_y
  if origin == "center" then
    origin_x, origin_y = 0.5, 0.5
  elseif origin == "top-left" then
    origin_x, origin_y = 0, 0
  elseif origin == "top-right" then
    origin_x, origin_y = 1, 0
  elseif origin == "bottom-left" then
    origin_x, origin_y = 0, 1
  elseif origin == "bottom-right" then
    origin_x, origin_y = 1, 1
  elseif origin == "top" then
    origin_x, origin_y = 0.5, 0
  elseif origin == "bottom" then
    origin_x, origin_y = 0.5, 1
  elseif origin == "left" then
    origin_x, origin_y = 0, 0.5
  elseif origin == "right" then
    origin_x, origin_y = 1, 0.5
  else
    origin_x, origin_y = 0.5, 0.5  -- Default to center
  end

  -- Max distance for normalization (diagonal of unit square)
  local max_dist = math.sqrt(2)

  -- Wave front radius based on reveal_ratio with speed multiplier
  -- Extra margin (1.2) ensures complete coverage
  local wave_radius = reveal_ratio * max_dist * speed * 1.2

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local norm_x = line_width > 1 and (idx - 1) / (line_width - 1) or 0.5
        local dx = norm_x - origin_x
        local dy = norm_y - origin_y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= wave_radius then
          table.insert(result, char)
        else
          table.insert(result, random_chaos_char())
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local norm_x = line_width > 1 and (idx - 1) / (line_width - 1) or 0.5
      local dx = norm_x - origin_x
      local dy = norm_y - origin_y
      local dist = math.sqrt(dx * dx + dy * dy)
      local output_char, phase
      if dist <= wave_radius then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = random_chaos_char()
        -- Characters near the wave front are "revealing"
        local proximity = (dist - wave_radius) / max_dist
        phase = proximity < 0.2 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create fade highlight groups with varying brightness
local function create_fade_highlights(base_highlight)
  -- Get highlight count from config
  local effect_opts = config.options.animation.effect_options or {}
  local new_count = effect_opts.highlight_count or 10

  -- Check if we need to recreate (different base highlight or count changed)
  if fade_state.base_highlight == base_highlight and fade_state.highlight_count == new_count then
    return
  end

  fade_state.highlight_count = new_count

  -- Get the base highlight's foreground color
  local hl_name = base_highlight or "Normal"
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = hl_name, link = false })
  local base_fg = ok and hl.fg

  if not base_fg then
    -- Try to get Normal highlight as fallback
    ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
    base_fg = ok and hl.fg
  end

  if not base_fg then
    -- Ultimate fallback: use white
    base_fg = 0xFFFFFF
  end

  -- Extract RGB components using math operations (avoids bit library dependency)
  local base_r = math.floor(base_fg / 0x10000) % 0x100
  local base_g = math.floor(base_fg / 0x100) % 0x100
  local base_b = base_fg % 0x100

  -- Create highlights with increasing brightness (1 = dimmest, N = brightest)
  for i = 1, fade_state.highlight_count do
    local brightness = i / fade_state.highlight_count
    local r = math.floor(base_r * brightness)
    local g = math.floor(base_g * brightness)
    local b = math.floor(base_b * brightness)
    local dimmed_color = r * 0x10000 + g * 0x100 + b

    vim.api.nvim_set_hl(0, "AsciiFade" .. i, { fg = dimmed_color })
  end

  fade_state.base_highlight = base_highlight
end

-- Get fade highlight for a given brightness level (0-1)
local function get_fade_highlight(brightness)
  local level = math.ceil(brightness * fade_state.highlight_count)
  level = math.max(1, math.min(fade_state.highlight_count, level))
  return "AsciiFade" .. level
end

-- Fade effect: returns original line (brightness controlled via highlight groups)
local function fade_line(line, reveal_ratio, line_idx, total_lines)
  -- Fade effect doesn't modify the text, only the highlight
  -- Line stagger: top lines fade in first
  local line_offset = (line_idx - 1) / total_lines * 0.3
  local adjusted_ratio = math.max(0, (reveal_ratio - line_offset) / 0.7)

  -- Return original line - brightness handled in render loop
  return line, adjusted_ratio
end

-- Create scramble version (password reveal / slot machine effect)
local function scramble_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local effect_opts = config.options.animation.effect_options or {}
  local stagger = effect_opts.stagger or "left"
  -- Use custom charset if provided, otherwise use chaos chars table
  local charset_str = effect_opts.charset
  local charset_table = charset_str and vim.fn.split(charset_str, "\\zs") or get_chaos_chars_table()

  local chars = vim.fn.split(line, "\\zs")
  local num_chars = #chars
  if num_chars == 0 then return "" end

  local stagger_delay = effect_opts.stagger_delay or 30
  local stagger_spread = math.max(0.3, math.min(0.8, stagger_delay / 50))
  local cycles = effect_opts.cycles or 5
  local settle_duration = math.max(0.2, math.min(0.5, 0.1 + cycles / 25))

  local function get_stagger_offset(idx)
    if stagger == "right" then
      return 1 - (idx - 1) / math.max(1, num_chars - 1)
    elseif stagger == "center" then
      local mid = (num_chars + 1) / 2
      return math.abs(idx - mid) / math.max(1, mid - 1)
    elseif stagger == "random" then
      return ((line_idx * 17 + idx * 31) % 100) / 100
    else
      return (idx - 1) / math.max(1, num_chars - 1)
    end
  end

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local stagger_offset = get_stagger_offset(idx)
        local settle_time = stagger_offset * stagger_spread + settle_duration
        if reveal_ratio >= settle_time then
          table.insert(result, char)
        else
          table.insert(result, charset_table[math.random(1, #charset_table)])
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local stagger_offset = get_stagger_offset(idx)
      local settle_time = stagger_offset * stagger_spread + settle_duration
      local output_char, phase
      if reveal_ratio >= settle_time then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = charset_table[math.random(1, #charset_table)]
        -- Characters close to settling are "revealing"
        local progress = reveal_ratio / settle_time
        phase = progress >= 0.7 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create rain/drip effect (characters fall and stack from bottom)
local function rain_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")

  local inverted_pos = (total_lines - line_idx + 1) / total_lines
  local line_threshold = inverted_pos * 0.6
  local line_progress = math.max(0, (reveal_ratio - line_threshold) / (1 - line_threshold))

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local col_seed = ((idx * 17 + line_idx * 7) % 100) / 100
        local char_delay = col_seed * 0.25
        local char_progress = math.max(0, (line_progress - char_delay) / (1 - char_delay))
        if char_progress >= 0.7 then
          table.insert(result, char)
        else
          table.insert(result, random_chaos_char())
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local col_seed = ((idx * 17 + line_idx * 7) % 100) / 100
      local char_delay = col_seed * 0.25
      local char_progress = math.max(0, (line_progress - char_delay) / (1 - char_delay))
      local output_char, phase
      if char_progress >= 0.7 then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = random_chaos_char()
        phase = char_progress >= 0.4 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- State for spiral effect
local spiral_state = { max_width = 0, center_x = 0, center_y = 0, max_spiral_dist = 0 }

local function get_spiral_distance(x, y, center_x, center_y, clockwise, tightness)
  local dx = x - center_x
  local dy = (y - center_y) * 2
  local radius = math.sqrt(dx * dx + dy * dy)
  local angle = math.atan2(dy, dx)
  if angle < 0 then angle = angle + 2 * math.pi end
  if not clockwise then angle = 2 * math.pi - angle end
  return radius + (angle / (2 * math.pi)) * tightness
end

-- Create spiral reveal effect
local function spiral_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chars = vim.fn.split(line, "\\zs")

  local effect_opts = config.options.animation.effect_options or {}
  local direction = effect_opts.direction or "outward"
  local rotation = effect_opts.rotation or "clockwise"
  local tightness = (effect_opts.tightness or 1.0) * 3
  local clockwise = rotation == "clockwise"

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local spiral_dist = get_spiral_distance(idx, line_idx, spiral_state.center_x, spiral_state.center_y, clockwise, tightness)
        local normalized_dist = spiral_dist / spiral_state.max_spiral_dist
        if direction == "inward" then normalized_dist = 1 - normalized_dist end
        if normalized_dist <= reveal_ratio then
          table.insert(result, char)
        else
          table.insert(result, random_chaos_char())
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local spiral_dist = get_spiral_distance(idx, line_idx, spiral_state.center_x, spiral_state.center_y, clockwise, tightness)
      local normalized_dist = spiral_dist / spiral_state.max_spiral_dist
      if direction == "inward" then normalized_dist = 1 - normalized_dist end
      local output_char, phase
      if normalized_dist <= reveal_ratio then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        output_char = random_chaos_char()
        local proximity = normalized_dist - reveal_ratio
        phase = proximity < 0.15 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create explode effect (center-outward reveal)
local function explode_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chaos_chars_tbl = get_chaos_chars_table()
  local chars = vim.fn.split(line, "\\zs")
  local len = #chars
  local center = len / 2
  local line_center = total_lines / 2
  local line_dist = math.abs(line_idx - line_center) / total_lines
  local line_offset = line_dist * 0.2

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local dist_from_center = math.abs(idx - center) / (len / 2 + 0.001)
        local threshold = dist_from_center + line_offset
        local adjusted_ratio = reveal_ratio < 0.8 and reveal_ratio * 1.1 or (0.88 + (reveal_ratio - 0.8) * 0.6)
        if adjusted_ratio > threshold then
          table.insert(result, char)
        else
          local seed = (line_idx * 17 + idx * 31) % #chaos_chars_tbl + 1
          local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars_tbl
          local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars_tbl) + 1
          table.insert(result, chaos_chars_tbl[chaos_idx])
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local dist_from_center = math.abs(idx - center) / (len / 2 + 0.001)
      local threshold = dist_from_center + line_offset
      local adjusted_ratio = reveal_ratio < 0.8 and reveal_ratio * 1.1 or (0.88 + (reveal_ratio - 0.8) * 0.6)
      local output_char, phase
      if adjusted_ratio > threshold then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        local seed = (line_idx * 17 + idx * 31) % #chaos_chars_tbl + 1
        local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars_tbl
        local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars_tbl) + 1
        output_char = chaos_chars_tbl[chaos_idx]
        local proximity = threshold - adjusted_ratio
        phase = proximity < 0.15 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create implode effect (edge-inward reveal)
local function implode_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local chaos_chars_tbl = get_chaos_chars_table()
  local chars = vim.fn.split(line, "\\zs")
  local len = #chars
  local center = len / 2
  local line_center = total_lines / 2
  local line_dist = 1 - math.abs(line_idx - line_center) / total_lines
  local line_offset = line_dist * 0.2

  if not use_phases then
    local result = {}
    for idx, char in ipairs(chars) do
      if char == " " or char == "" then
        table.insert(result, char)
      else
        local dist_from_center = math.abs(idx - center) / (len / 2 + 0.001)
        local dist_from_edge = 1 - dist_from_center
        local threshold = dist_from_edge + line_offset
        local adjusted_ratio = reveal_ratio < 0.8 and reveal_ratio * 1.1 or (0.88 + (reveal_ratio - 0.8) * 0.6)
        if adjusted_ratio > threshold then
          table.insert(result, char)
        else
          local seed = (line_idx * 17 + idx * 31) % #chaos_chars_tbl + 1
          local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars_tbl
          local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars_tbl) + 1
          table.insert(result, chaos_chars_tbl[chaos_idx])
        end
      end
    end
    return table.concat(result)
  end

  -- Phase highlight mode: return segments
  local segments = {}
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      current_text = current_text .. char
    else
      local dist_from_center = math.abs(idx - center) / (len / 2 + 0.001)
      local dist_from_edge = 1 - dist_from_center
      local threshold = dist_from_edge + line_offset
      local adjusted_ratio = reveal_ratio < 0.8 and reveal_ratio * 1.1 or (0.88 + (reveal_ratio - 0.8) * 0.6)
      local output_char, phase
      if adjusted_ratio > threshold then
        output_char = char
        phase = "AsciiAnimationRevealed"
      else
        local seed = (line_idx * 17 + idx * 31) % #chaos_chars_tbl + 1
        local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars_tbl
        local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars_tbl) + 1
        output_char = chaos_chars_tbl[chaos_idx]
        local proximity = threshold - adjusted_ratio
        phase = proximity < 0.15 and "AsciiAnimationRevealing" or "AsciiAnimationChaos"
      end
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end
      current_text = current_text .. output_char
    end
  end
  flush_segment()

  return { is_segments = true, segments = segments }
end

-- Create glitch reveal effect (cyberpunk-style with corruption)
local function glitch_line(line, reveal_ratio, line_idx, total_lines)
  local use_phases = config.use_phase_highlights()
  local opts = config.options.animation.effect_options.glitch or {}
  local intensity = opts.intensity or 0.5
  local block_chance = opts.block_chance or 0.2
  local block_size = opts.block_size or 5
  local resolve_speed = opts.resolve_speed or 1.0

  local chaos_chars_tbl = get_chaos_chars_table()
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local segments = {}

  -- Calculate effective glitch intensity (decreases as reveal progresses)
  local resolve_factor = reveal_ratio ^ (1 / resolve_speed)
  local effective_intensity = intensity * (1 - resolve_factor)

  -- Determine if there's a block glitch on this line
  local has_block = math.random() < block_chance * (1 - resolve_factor)
  local block_start, block_end = 0, 0
  if has_block and #chars > 0 then
    block_start = math.random(1, #chars)
    block_end = math.min(#chars, block_start + math.random(1, block_size))
  end

  -- Track segments for multi-highlight rendering
  local current_text = ""
  local current_phase = nil

  local function flush_segment()
    if #current_text > 0 then
      table.insert(segments, { current_text, current_phase })
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    local output_char = char
    local phase = nil

    if char == " " or char == "" then
      table.insert(result, char)
      current_text = current_text .. char
    else
      local is_revealed = math.random() < resolve_factor

      if is_revealed then
        output_char = char
        phase = use_phases and "AsciiAnimationRevealed" or nil
      else
        local effect_roll = math.random()
        if has_block and idx >= block_start and idx <= block_end then
          output_char = glitch_chars_table[math.random(1, #glitch_chars_table)]
          phase = use_phases and "AsciiAnimationGlitch" or glitch_highlights[math.random(1, #glitch_highlights)]
        elseif effect_roll < effective_intensity * 0.6 then
          output_char = glitch_chars_table[math.random(1, #glitch_chars_table)]
          phase = use_phases and "AsciiAnimationGlitch" or glitch_highlights[math.random(1, #glitch_highlights)]
        elseif effect_roll < effective_intensity then
          output_char = chaos_chars_tbl[math.random(1, #chaos_chars_tbl)]
          phase = use_phases and "AsciiAnimationChaos" or glitch_highlights[math.random(1, #glitch_highlights)]
        else
          output_char = char
          phase = use_phases and "AsciiAnimationRevealing" or nil
        end
      end

      -- Handle segment transitions
      if phase ~= current_phase then
        flush_segment()
        current_phase = phase
      end

      table.insert(result, output_char)
      current_text = current_text .. output_char
    end
  end

  flush_segment()

  -- Return segments for multi-highlight rendering
  if #segments > 0 then
    return { is_segments = true, segments = segments }
  end
  return table.concat(result)
end

-- Effect dispatch table
local effects = {
  chaos = chaos_line,
  typewriter = typewriter_line,
  diagonal = diagonal_line,
  lines = lines_line,
  matrix = matrix_line,
  wave = wave_line,
  fade = fade_line,
  scramble = scramble_line,
  rain = rain_line,
  spiral = spiral_line,
  explode = explode_line,
  implode = implode_line,
  glitch = glitch_line,
}

-- List of effect names for random selection
local effect_names = { "chaos", "typewriter", "diagonal", "lines", "matrix", "wave", "fade", "scramble", "rain", "spiral", "explode", "implode", "glitch" }

-- Custom effect delay overrides
local custom_delays = {}

-- Pick a random effect
local function get_random_effect()
  return effect_names[math.random(1, #effect_names)]
end

-- Apply glitch effect: randomly replace a few characters with chaos chars
local function apply_glitch(line, intensity)
  local chars = vim.fn.split(line, "\\zs")
  local result = {}

  for _, char in ipairs(chars) do
    if char ~= " " and char ~= "" and math.random() < intensity then
      table.insert(result, random_chaos_char())
    else
      table.insert(result, char)
    end
  end
  return table.concat(result)
end

-- Apply shimmer effect: one random character shows chaos
local function apply_shimmer(line, char_index)
  local chars = vim.fn.split(line, "\\zs")

  if char_index <= #chars and chars[char_index] ~= " " and chars[char_index] ~= "" then
    chars[char_index] = random_chaos_char()
  end
  return table.concat(chars)
end

-- Apply cursor trail effect: moving cursor with fading trail
local function apply_cursor_trail(buf, lines, header_end, highlight)
  local opts = config.options.animation.ambient_options.cursor_trail
  local trail_chars = vim.fn.split(opts.trail_chars, "\\zs")

  -- Advance cursor position
  cursor_trail_state.col = cursor_trail_state.col + opts.move_speed
  local current_line = lines[cursor_trail_state.line]

  if not current_line or cursor_trail_state.col >= #vim.fn.split(current_line, "\\zs") then
    cursor_trail_state.line = cursor_trail_state.line + 1
    cursor_trail_state.col = 0
    if cursor_trail_state.line > header_end then
      cursor_trail_state.line = 1
    end
    return
  end

  -- Build modified line with trail
  local chars = vim.fn.split(current_line, "\\zs")
  for i = 0, math.min(opts.trail_length, #trail_chars) - 1 do
    local trail_col = cursor_trail_state.col - i
    if trail_col >= 1 and trail_col <= #chars and chars[trail_col] ~= " " then
      chars[trail_col] = trail_chars[i + 1] or trail_chars[#trail_chars]
    end
  end

  local transformed = table.concat(chars)
  local line_hl = get_line_highlight(cursor_trail_state.line, highlight or "Normal")
  pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, cursor_trail_state.line - 1, 0, {
    virt_text = { { transformed, line_hl } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

-- Apply sparkle effect: random sparkle chars at random positions
local function apply_sparkle(buf, lines, header_end, highlight)
  local opts = config.options.animation.ambient_options.sparkle
  local sparkle_chars = vim.fn.split(opts.chars, "\\zs")

  for i = 1, header_end do
    local line = lines[i]
    if line and #line > 0 then
      local chars = vim.fn.split(line, "\\zs")
      local modified = false
      for col = 1, #chars do
        if chars[col] ~= " " and chars[col] ~= "" and math.random() < opts.density then
          chars[col] = sparkle_chars[math.random(1, #sparkle_chars)]
          modified = true
        end
      end
      if modified then
        local transformed = table.concat(chars)
        pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
          virt_text = { { transformed, "Special" } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
  end
end

-- Apply scanlines effect: CRT-style dimmed overlay on every Nth line
local function apply_scanlines(buf, lines, header_end, highlight)
  local opts = config.options.animation.ambient_options.scanlines

  -- Create scanline highlight group once
  if not scanline_hl_created then
    local dim = opts.dim_amount
    local ok, base_hl = pcall(vim.api.nvim_get_hl, 0, { name = highlight or "Normal", link = false })
    if ok and base_hl.fg then
      local fg = base_hl.fg
      local r = math.floor((math.floor(fg / 65536) % 256) * dim)
      local g = math.floor((math.floor(fg / 256) % 256) * dim)
      local b = math.floor((fg % 256) * dim)
      local dimmed = r * 65536 + g * 256 + b
      vim.api.nvim_set_hl(0, "AsciiScanline", { fg = string.format("#%06x", dimmed) })
    else
      vim.api.nvim_set_hl(0, "AsciiScanline", { fg = "#555555" })
    end
    scanline_hl_created = true
  end

  -- Overlay every Nth line with dimmed version
  for i = 1, header_end, opts.spacing do
    local line = lines[i]
    if line and #line > 0 then
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
        virt_text = { { line, "AsciiScanline" } },
        virt_text_pos = "overlay",
        hl_mode = "replace",
      })
    end
  end
end

-- Apply noise effect: random chaos chars replace some chars briefly
local function apply_noise(buf, lines, header_end, highlight)
  local opts = config.options.animation.ambient_options.noise

  for i = 1, header_end do
    local line = lines[i]
    if line and #line > 0 then
      local chars = vim.fn.split(line, "\\zs")
      local modified = false
      for col = 1, #chars do
        if chars[col] ~= " " and chars[col] ~= "" and math.random() < opts.intensity then
          chars[col] = random_chaos_char()
          modified = true
        end
      end
      if modified then
        local transformed = table.concat(chars)
        local line_hl = get_line_highlight(i, highlight or "Normal")
        pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
          virt_text = { { transformed, line_hl } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
  end
end

-- Apply shake effect: offset lines horizontally by prepending spaces
local function apply_shake(buf, lines, header_end, highlight)
  local opts = config.options.animation.ambient_options.shake

  for i = 1, header_end do
    local line = lines[i]
    if line and #line > 0 and math.random() < opts.line_probability then
      local offset = math.random(1, opts.max_offset)
      local shifted = string.rep(" ", offset) .. line
      local line_hl = get_line_highlight(i, highlight or "Normal")
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
        virt_text = { { shifted, line_hl } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end
end

-- Play sound effect: uses system sound player
local function play_sound()
  local opts = config.options.animation.ambient_options.sound
  if not opts.file_path then return end

  local cmd
  if vim.fn.has("mac") == 1 then
    local volume = tostring(opts.volume / 100)
    cmd = { "afplay", "-v", volume, vim.fn.expand(opts.file_path) }
  elseif vim.fn.has("unix") == 1 then
    local volume = tostring(math.floor(opts.volume / 100 * 65536))
    cmd = { "paplay", "--volume", volume, vim.fn.expand(opts.file_path) }
  else
    return
  end

  pcall(vim.fn.jobstart, cmd, { detach = true })
end

-- Stop ambient effects timer
local function stop_ambient()
  if ambient_timer then
    ambient_timer:stop()
    ambient_timer:close()
    ambient_timer = nil
  end
  -- Reset ambient state
  cursor_trail_state.line = 1
  cursor_trail_state.col = 0
  scanline_hl_created = false
end

-- Start ambient effects after animation completes
local function start_ambient(buf, header_end, highlight)
  local opts = config.options.animation
  if opts.ambient == "none" then return end

  stop_ambient()

  local function run_ambient()
    if not vim.api.nvim_buf_is_valid(buf) then
      stop_ambient()
      return
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    if opts.ambient == "glitch" then
      -- Apply glitch to random lines briefly
      for i = 1, header_end do
        local line = lines[i]
        if line and #line > 0 and math.random() < 0.3 then
          local transformed = apply_glitch(line, 0.05)
          local line_hl = get_line_highlight(i, highlight or "Normal")
          pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
            virt_text = { { transformed, line_hl } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        end
      end
    elseif opts.ambient == "shimmer" then
      -- Shimmer one random character
      local line_idx = math.random(1, header_end)
      local line = lines[line_idx]
      if line and #line > 0 then
        local chars = vim.fn.split(line, "\\zs")
        local char_idx = math.random(1, #chars)
        local transformed = apply_shimmer(line, char_idx)
        local line_hl = get_line_highlight(line_idx, highlight or "Normal")
        pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, line_idx - 1, 0, {
          virt_text = { { transformed, line_hl } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    elseif opts.ambient == "cursor_trail" then
      apply_cursor_trail(buf, lines, header_end, highlight)
    elseif opts.ambient == "sparkle" then
      apply_sparkle(buf, lines, header_end, highlight)
    elseif opts.ambient == "scanlines" then
      apply_scanlines(buf, lines, header_end, highlight)
    elseif opts.ambient == "noise" then
      apply_noise(buf, lines, header_end, highlight)
    elseif opts.ambient == "shake" then
      apply_shake(buf, lines, header_end, highlight)
    elseif opts.ambient == "sound" then
      play_sound()
      return -- No visual effect, no clear needed
    end

    -- Clear effect after brief display (scanlines are persistent)
    if opts.ambient ~= "scanlines" then
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
        end
      end, 100)
    end
  end

  ambient_timer = vim.uv.new_timer()
  ambient_timer:start(opts.ambient_interval, opts.ambient_interval, vim.schedule_wrap(run_ambient))
end

-- Detect where header ends (before menu items)
-- Menu items are detected after a gap when a line looks like:
--   <icon> <spaces> <ascii label>
-- This avoids cutting Unicode-heavy ASCII art that may contain internal gaps.
local function find_header_end(lines, max_lines)
  local found_content = false
  local empty_streak = 0
  local last_content_line = 0
  local first_content_line = nil

  local function is_menu_line(line)
    local trimmed = line and (line:match("^%s*(.+)") or "")
    if trimmed == "" or #trimmed >= 120 then
      return false
    end

    -- First displayed character should be a multi-byte icon.
    local first_char = vim.fn.strcharpart(trimmed, 0, 1)
    if first_char == "" or #first_char < 2 then
      return false
    end

    -- Remaining text should begin with an ASCII label (e.g. "Find File").
    local rest = vim.fn.strcharpart(trimmed, 1)
    if not rest:match("^%s*[%a]") then
      return false
    end

    return true
  end

  for i = 1, #lines do
    local line = lines[i]
    if line and not line:match("^%s*$") then
      first_content_line = i
      break
    end
  end

  if not first_content_line then
    if type(max_lines) == "number" and max_lines > 0 then
      return math.min(max_lines, #lines)
    end
    return #lines
  end

  local scan_end
  if type(max_lines) == "number" and max_lines > 0 then
    -- header_lines should count from the first visible header content,
    -- not from buffer row 1 (which can be top padding on large/tall layouts).
    scan_end = math.min(#lines, first_content_line + max_lines - 1)
  else
    scan_end = #lines
  end

  for i = first_content_line, scan_end do
    local line = lines[i]
    local is_empty = not line or line:match("^%s*$")

    if not is_empty then
      found_content = true
      if empty_streak >= 1 and is_menu_line(line) then
        return last_content_line
      end
      last_content_line = i
      empty_streak = 0
    elseif found_content then
      empty_streak = empty_streak + 1
    end
  end

  return last_content_line > 0 and last_content_line or scan_end
end

-- Main animation function using extmarks overlay
local function animate(buf, win, step, total_steps, highlight, header_end, reverse, gen)
  -- Bail out if this callback belongs to a stopped/replaced animation
  if gen ~= animation_state.generation then return end

  if not vim.api.nvim_buf_is_valid(buf) then
    animation_state.running = false
    return
  end
  if not vim.api.nvim_win_is_valid(win) then
    animation_state.running = false
    return
  end

  if animation_state.paused then
    animation_state.step = step
    animation_state.total_steps = total_steps
    animation_state.win = win
    animation_state.reverse = reverse
    return
  end

  -- Check if animation is complete
  local animation_done = (not reverse and step > total_steps) or (reverse and step < 0)

  if animation_done then
    local opts = config.options.animation

    if opts.loop then
      -- Loop mode: keep last frame visible during delay, then restart
      vim.defer_fn(function()
        if gen ~= animation_state.generation then return end
        if not vim.api.nvim_buf_is_valid(buf) then
          animation_state.running = false
          return
        end
        loop_count = loop_count + 1
        fire_hook("on_loop", "AsciiAnimationLoop", loop_count)
        if opts.loop_reverse and not reverse then
          -- Play reverse first (keep same effect)
          animate(buf, win, total_steps, total_steps, highlight, header_end, true, gen)
        else
          -- Restart forward: pick new random effect if in random mode
          if config.options.animation.effect == "random" then
            animation_state.effect = get_random_effect()
            -- Create fade highlights if random selected fade
            if animation_state.effect == "fade" then
              create_fade_highlights(highlight)
            end
          end
          animate(buf, win, 0, total_steps, highlight, header_end, false, gen)
        end
      end, opts.loop_delay)
    else
      -- Not looping: animation finished, clear and start ambient effects
      vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
      animation_state.running = false
      fire_hook("on_animation_complete", "AsciiAnimationComplete", animation_state.effect)
      local cb = animation_state.on_complete
      animation_state.on_complete = nil
      if cb then cb() end
      start_ambient(buf, header_end, highlight)
    end
    return
  end

  -- Clear previous frame before rendering new one
  vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)

  local effect = animation_state.effect
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Calculate reveal_ratio (same for both directions)
  local actual_step = step
  local reveal_ratio
  local frame_delay

  -- Timing varies per effect
  if effect == "typewriter" or effect == "diagonal" then
    reveal_ratio = actual_step / total_steps
    frame_delay = config.options.animation.min_delay
  elseif effect == "lines" then
    reveal_ratio = ease_in_out(actual_step / total_steps)
    frame_delay = config.options.animation.max_delay / 2
  elseif effect == "matrix" then
    reveal_ratio = actual_step / total_steps
    frame_delay = config.options.animation.min_delay
  elseif effect == "wave" then
    reveal_ratio = ease_in_out(actual_step / total_steps)
    frame_delay = config.options.animation.min_delay
  elseif effect == "fade" then
    reveal_ratio = ease_in_out(actual_step / total_steps)
    frame_delay = config.options.animation.max_delay / 2
  elseif effect == "glitch" then
    reveal_ratio = actual_step / total_steps
    frame_delay = config.options.animation.min_delay
  else
    reveal_ratio = ease_in_out(actual_step / total_steps)
    if custom_delays[effect] then
      local ok, delay = pcall(custom_delays[effect], actual_step, total_steps)
      frame_delay = ok and type(delay) == "number" and delay or get_frame_delay(actual_step, total_steps)
    else
      frame_delay = get_frame_delay(actual_step, total_steps)
    end
  end

  current_effect_name = effect
  local effect_fn = effects[effect] or effects.chaos

  for i = 1, header_end do
    local line = lines[i]
    if line and #line > 0 then
      local transformed, brightness = effect_fn(line, reveal_ratio, i, header_end)
      local base_highlight = highlight or "Normal"

      -- Apply color mode (rainbow/gradient) for line-specific coloring
      local line_highlight = get_line_highlight(i, base_highlight)

      -- Fade effect uses dynamic highlight groups based on brightness
      if effect == "fade" and brightness then
        line_highlight = get_fade_highlight(brightness)
      end

      -- Handle segment-based output (glitch effect with multi-highlight)
      local virt_text
      if type(transformed) == "table" and transformed.is_segments then
        virt_text = {}
        for _, seg in ipairs(transformed.segments) do
          table.insert(virt_text, { seg[1], seg[2] or line_highlight })
        end
      else
        virt_text = { { transformed, line_highlight } }
      end

      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
        virt_text = virt_text,
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end

  -- Schedule next frame
  local next_step = reverse and (step - 1) or (step + 1)
  vim.defer_fn(function()
    animate(buf, win, next_step, total_steps, highlight, header_end, reverse, gen)
  end, frame_delay)
end

-- Stop any running animation and ambient effects
function M.stop()
  stop_ambient()
  animation_state.generation = animation_state.generation + 1
  animation_state.running = false
  animation_state.paused = false
  animation_state.on_complete = nil
  if animation_state.buf and vim.api.nvim_buf_is_valid(animation_state.buf) then
    vim.api.nvim_buf_clear_namespace(animation_state.buf, M.ns_id, 0, -1)
  end
end

-- Pause a running animation (keeps current frame visible)
function M.pause()
  if not animation_state.running or animation_state.paused then return false end
  animation_state.paused = true
  stop_ambient()
  return true
end

-- Resume a paused animation from where it left off
function M.resume()
  if not animation_state.paused then return false end
  animation_state.paused = false
  local s = animation_state
  if s.buf and vim.api.nvim_buf_is_valid(s.buf) and s.win and vim.api.nvim_win_is_valid(s.win) then
    animate(s.buf, s.win, s.step, s.total_steps, s.highlight, s.header_end, s.reverse, s.generation)
  end
  return true
end

-- Cycle to the next animation effect
function M.next_effect()
  local old = config.options.animation.effect
  local idx = 1
  for i, name in ipairs(effect_names) do
    if name == old then idx = i break end
  end
  idx = idx % #effect_names + 1
  config.options.animation.effect = effect_names[idx]
  config.save()
  fire_hook("on_effect_change", "AsciiEffectChange", old, effect_names[idx])
  if animation_state.buf and vim.api.nvim_buf_is_valid(animation_state.buf) then
    M.start(animation_state.buf, animation_state.header_end, animation_state.highlight)
  end
  return effect_names[idx]
end

-- Set a specific animation effect by name
function M.set_effect(name)
  if not effects[name] and name ~= "random" then return false end
  local old = config.options.animation.effect
  config.options.animation.effect = name
  config.save()
  fire_hook("on_effect_change", "AsciiEffectChange", old, name)
  if animation_state.buf and vim.api.nvim_buf_is_valid(animation_state.buf) then
    M.start(animation_state.buf, animation_state.header_end, animation_state.highlight)
  end
  return true
end

-- Start animation on a buffer
function M.start(buf, header_lines, highlight, on_complete)
  if not config.options.animation.enabled then return end

  -- Stop any existing animation/ambient
  M.stop()

  -- Setup phase highlights if enabled
  if config.use_phase_highlights() then
    setup_phase_highlights()
  end

  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_buf_is_valid(buf) then return end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local header_end = find_header_end(lines, header_lines)

  -- Reduced motion: skip animation, show final art immediately
  if config.options.animation.reduced_motion then
    setup_color_mode_highlights(header_end)
    start_ambient(buf, header_end, highlight)
    return
  end

  -- Resolve effect (pick random if "random")
  local effect = config.options.animation.effect
  if effect == "random" then
    effect = get_random_effect()
  end

  -- Create fade highlight groups if needed
  if effect == "fade" then
    create_fade_highlights(highlight)
  end

  -- Setup color mode highlights (rainbow/gradient)
  setup_color_mode_highlights(header_end)

  -- Store state for potential stop
  animation_state.running = true
  animation_state.buf = buf
  animation_state.header_end = header_end
  animation_state.highlight = highlight
  animation_state.effect = effect
  animation_state.on_complete = on_complete

  loop_count = 0
  fire_hook("on_animation_start", "AsciiAnimationStart", effect)

  animate(buf, win, 0, config.options.animation.steps, highlight, header_end, false, animation_state.generation)
end

-- Register a custom animation effect
function M.register_effect(name, def)
  if type(name) ~= "string" or name == "" then
    vim.notify("[ascii-animation] register_effect: name must be a non-empty string", vim.log.levels.ERROR)
    return false
  end
  if type(def) ~= "table" or type(def.transform) ~= "function" then
    vim.notify("[ascii-animation] register_effect: definition must have a transform function", vim.log.levels.ERROR)
    return false
  end
  effects[name] = function(line, reveal_ratio, line_idx, total_lines)
    local ok, result = pcall(def.transform, line, reveal_ratio, line_idx, total_lines, {
      random_char = random_chaos_char,
      ease_in_out = ease_in_out,
      clamp = function(v, min, max) return math.min(math.max(v, min), max) end,
    })
    if not ok then
      return line
    end
    return result
  end
  local found = false
  for _, n in ipairs(effect_names) do
    if n == name then found = true break end
  end
  if not found then
    table.insert(effect_names, name)
  end
  if type(def.get_delay) == "function" then
    custom_delays[name] = def.get_delay
  end
  return true
end

-- Expose effect names for dynamic completion/cycling
M.effect_names = effect_names

-- Export for manual highlight setup
M.setup_phase_highlights = setup_phase_highlights
M.refresh_phase_highlights = refresh_phase_highlights
M.refresh_color_mode_highlights = refresh_color_mode_highlights

return M
