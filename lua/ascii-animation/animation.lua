-- Animation module for ascii-animation
local config = require("ascii-animation.config")

local M = {}

M.ns_id = vim.api.nvim_create_namespace("ascii_animation")

-- Timer for ambient effects
local ambient_timer = nil

-- Fade effect state
local fade_state = {
  highlight_count = 10,     -- Number of brightness levels
  base_highlight = nil,     -- Track which highlight was used to create groups
}

-- Glitch effect constants
local glitch_chars = "█▓▒░▀▄▌▐▊▋▍▎▏┃┆┇┊┋╎╏│║▕▐▌"
local glitch_highlights = { "ErrorMsg", "WarningMsg", "DiffDelete", "DiffChange", "Special" }

-- State for tracking current animation
local animation_state = {
  running = false,
  buf = nil,
  header_end = nil,
  highlight = nil,
  effect = nil,  -- Resolved effect (for "random" mode)
}

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
  local chaos_chars = config.options.chaos_chars
  local result = {}
  local chars = vim.fn.split(line, "\\zs")

  for _, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    elseif math.random() < reveal_ratio then
      table.insert(result, char)
    else
      local idx = math.random(1, #chaos_chars)
      table.insert(result, chaos_chars:sub(idx, idx))
    end
  end

  return table.concat(result)
end

-- Create typewriter version of a line (left-to-right reveal with cursor)
local function typewriter_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local cursor_pos = math.floor(#chars * reveal_ratio)

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    elseif idx == cursor_pos then
      table.insert(result, "▌")  -- Cursor at typing position
    elseif idx < cursor_pos then
      table.insert(result, char)  -- Revealed
    else
      -- Hidden: show chaos char
      local rand_idx = math.random(1, #chaos_chars)
      table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
    end
  end

  return table.concat(result)
end

-- Create diagonal sweep version (top-left to bottom-right)
local function diagonal_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  -- Offset reveal based on line position (top lines reveal first)
  local line_offset = (line_idx - 1) / total_lines * 0.3
  local adjusted_ratio = math.max(0, reveal_ratio - line_offset) / 0.7

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      local char_ratio = (idx - 1) / #chars
      if char_ratio < adjusted_ratio then
        table.insert(result, char)
      else
        -- Not yet revealed: show chaos char
        local rand_idx = math.random(1, #chaos_chars)
        table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
      end
    end
  end
  return table.concat(result)
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
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      -- Each character has its own "fall" timing based on position
      local seed = (line_idx * 100 + idx) % 50
      local char_progress = reveal_ratio + seed / 100

      if char_progress >= 0.8 then
        table.insert(result, char)  -- Settled
      else
        -- Falling or waiting: show random matrix character
        local rand_idx = math.random(1, #chaos_chars)
        table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
      end
    end
  end
  return table.concat(result)
end

-- Create wave effect (ripple reveal from origin point)
local function wave_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}

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

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      -- Normalize x position
      local norm_x = line_width > 1 and (idx - 1) / (line_width - 1) or 0.5

      -- Calculate euclidean distance from origin
      local dx = norm_x - origin_x
      local dy = norm_y - origin_y
      local dist = math.sqrt(dx * dx + dy * dy)

      -- Reveal if within wave radius
      if dist <= wave_radius then
        table.insert(result, char)
      else
        -- Show chaos char
        local rand_idx = math.random(1, #chaos_chars)
        table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
      end
    end
  end

  return table.concat(result)
end

-- Create fade highlight groups with varying brightness
local function create_fade_highlights(base_highlight)
  -- Check if we need to recreate (different base highlight)
  if fade_state.base_highlight == base_highlight then
    return
  end

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
  local effect_opts = config.options.animation.effect_options or {}
  local stagger = effect_opts.stagger or "left"
  local charset = effect_opts.charset or config.options.chaos_chars

  local chars = vim.fn.split(line, "\\zs")
  local result = {}
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

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      local stagger_offset = get_stagger_offset(idx)
      local settle_time = stagger_offset * stagger_spread + settle_duration
      if reveal_ratio >= settle_time then
        table.insert(result, char)
      else
        local rand_idx = math.random(1, #charset)
        table.insert(result, charset:sub(rand_idx, rand_idx))
      end
    end
  end
  return table.concat(result)
end

-- Create rain/drip effect (characters fall and stack from bottom)
local function rain_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}

  local inverted_pos = (total_lines - line_idx + 1) / total_lines
  local line_threshold = inverted_pos * 0.6
  local line_progress = math.max(0, (reveal_ratio - line_threshold) / (1 - line_threshold))

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
        local rand_idx = math.random(1, #chaos_chars)
        table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
      end
    end
  end
  return table.concat(result)
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
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}

  local effect_opts = config.options.animation.effect_options or {}
  local direction = effect_opts.direction or "outward"
  local rotation = effect_opts.rotation or "clockwise"
  local tightness = (effect_opts.tightness or 1.0) * 3
  local clockwise = rotation == "clockwise"

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
        local rand_idx = math.random(1, #chaos_chars)
        table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
      end
    end
  end
  return table.concat(result)
end

-- Create explode effect (center-outward reveal)
local function explode_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local len = #chars
  local center = len / 2
  local line_center = total_lines / 2
  local line_dist = math.abs(line_idx - line_center) / total_lines
  local line_offset = line_dist * 0.2

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
        local seed = (line_idx * 17 + idx * 31) % #chaos_chars + 1
        local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars
        local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars) + 1
        table.insert(result, chaos_chars:sub(chaos_idx, chaos_idx))
      end
    end
  end
  return table.concat(result)
end

-- Create implode effect (edge-inward reveal)
local function implode_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local len = #chars
  local center = len / 2
  local line_center = total_lines / 2
  local line_dist = 1 - math.abs(line_idx - line_center) / total_lines
  local line_offset = line_dist * 0.2

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
        local seed = (line_idx * 17 + idx * 31) % #chaos_chars + 1
        local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars
        local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars) + 1
        table.insert(result, chaos_chars:sub(chaos_idx, chaos_idx))
      end
    end
  end
  return table.concat(result)
end

-- Create glitch reveal effect (cyberpunk-style with corruption)
local function glitch_line(line, reveal_ratio, line_idx, total_lines)
  local opts = config.options.animation.effect_options.glitch or {}
  local intensity = opts.intensity or 0.5
  local block_chance = opts.block_chance or 0.2
  local block_size = opts.block_size or 5
  local resolve_speed = opts.resolve_speed or 1.0

  local chaos_chars_str = config.options.chaos_chars
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
  local current_is_glitch = false

  local function flush_segment()
    if #current_text > 0 then
      if current_is_glitch then
        local hl = glitch_highlights[math.random(1, #glitch_highlights)]
        table.insert(segments, { current_text, hl })
      else
        table.insert(segments, { current_text, nil })
      end
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    local output_char = char
    local is_glitched = false

    if char == " " or char == "" then
      table.insert(result, char)
      current_text = current_text .. char
    else
      local is_revealed = math.random() < resolve_factor

      if is_revealed then
        output_char = char
        is_glitched = false
      else
        local effect_roll = math.random()
        if has_block and idx >= block_start and idx <= block_end then
          local block_idx = math.random(1, #glitch_chars)
          output_char = glitch_chars:sub(block_idx, block_idx)
          is_glitched = true
        elseif effect_roll < effective_intensity * 0.6 then
          local glitch_idx = math.random(1, #glitch_chars)
          output_char = glitch_chars:sub(glitch_idx, glitch_idx)
          is_glitched = true
        elseif effect_roll < effective_intensity then
          local chaos_idx = math.random(1, #chaos_chars_str)
          output_char = chaos_chars_str:sub(chaos_idx, chaos_idx)
          is_glitched = true
        else
          output_char = char
          is_glitched = false
        end
      end

      -- Handle segment transitions
      if is_glitched ~= current_is_glitch then
        flush_segment()
        current_is_glitch = is_glitched
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

-- Pick a random effect
local function get_random_effect()
  return effect_names[math.random(1, #effect_names)]
end

-- Apply glitch effect: randomly replace a few characters with chaos chars
local function apply_glitch(line, intensity)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}

  for _, char in ipairs(chars) do
    if char ~= " " and char ~= "" and math.random() < intensity then
      local idx = math.random(1, #chaos_chars)
      table.insert(result, chaos_chars:sub(idx, idx))
    else
      table.insert(result, char)
    end
  end
  return table.concat(result)
end

-- Apply shimmer effect: one random character shows chaos
local function apply_shimmer(line, char_index)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")

  if char_index <= #chars and chars[char_index] ~= " " and chars[char_index] ~= "" then
    local idx = math.random(1, #chaos_chars)
    chars[char_index] = chaos_chars:sub(idx, idx)
  end
  return table.concat(chars)
end

-- Stop ambient effects timer
local function stop_ambient()
  if ambient_timer then
    ambient_timer:stop()
    ambient_timer:close()
    ambient_timer = nil
  end
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
          pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
            virt_text = { { transformed, highlight or "Normal" } },
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
        pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, line_idx - 1, 0, {
          virt_text = { { transformed, highlight or "Normal" } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end

    -- Clear effect after brief display
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
      end
    end, 100)
  end

  ambient_timer = vim.uv.new_timer()
  ambient_timer:start(opts.ambient_interval, opts.ambient_interval, vim.schedule_wrap(run_ambient))
end

-- Detect where header ends (before menu items)
-- Menu items are detected as lines starting with multi-byte icons after a gap
local function find_header_end(lines, max_lines)
  local found_content = false
  local empty_streak = 0
  local last_content_line = 0

  for i = 1, math.min(max_lines, #lines) do
    local line = lines[i]
    local is_empty = not line or line:match("^%s*$")

    if not is_empty then
      found_content = true
      if empty_streak >= 1 then
        local trimmed = line:match("^%s*(.+)") or ""
        local first_byte = string.byte(trimmed, 1)
        if first_byte and first_byte >= 0xC0 and #trimmed < 80 then
          return last_content_line
        end
      end
      last_content_line = i
      empty_streak = 0
    elseif found_content then
      empty_streak = empty_streak + 1
    end
  end

  return last_content_line > 0 and last_content_line or max_lines
end

-- Main animation function using extmarks overlay
local function animate(buf, win, step, total_steps, highlight, header_end, reverse)
  if not vim.api.nvim_buf_is_valid(buf) then
    animation_state.running = false
    return
  end
  if not vim.api.nvim_win_is_valid(win) then
    animation_state.running = false
    return
  end

  -- Check if animation is complete
  local animation_done = (not reverse and step > total_steps) or (reverse and step < 0)

  if animation_done then
    local opts = config.options.animation

    if opts.loop then
      -- Loop mode: keep last frame visible during delay, then restart
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          animation_state.running = false
          return
        end
        if opts.loop_reverse and not reverse then
          -- Play reverse first (keep same effect)
          animate(buf, win, total_steps, total_steps, highlight, header_end, true)
        else
          -- Restart forward: pick new random effect if in random mode
          if config.options.animation.effect == "random" then
            animation_state.effect = get_random_effect()
            -- Create fade highlights if random selected fade
            if animation_state.effect == "fade" then
              create_fade_highlights(highlight)
            end
          end
          animate(buf, win, 0, total_steps, highlight, header_end, false)
        end
      end, opts.loop_delay)
    else
      -- Not looping: animation finished, clear and start ambient effects
      vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)
      animation_state.running = false
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
  else  -- chaos (default)
    reveal_ratio = ease_in_out(actual_step / total_steps)
    frame_delay = get_frame_delay(actual_step, total_steps)
  end

  local effect_fn = effects[effect] or effects.chaos

  for i = 1, header_end do
    local line = lines[i]
    if line and #line > 0 then
      local transformed, brightness = effect_fn(line, reveal_ratio, i, header_end)
      local line_highlight = highlight or "Normal"

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
    animate(buf, win, next_step, total_steps, highlight, header_end, reverse)
  end, frame_delay)
end

-- Stop any running animation and ambient effects
function M.stop()
  stop_ambient()
  animation_state.running = false
  if animation_state.buf and vim.api.nvim_buf_is_valid(animation_state.buf) then
    vim.api.nvim_buf_clear_namespace(animation_state.buf, M.ns_id, 0, -1)
  end
end

-- Start animation on a buffer
function M.start(buf, header_lines, highlight)
  if not config.options.animation.enabled then return end

  -- Stop any existing animation/ambient
  M.stop()

  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_buf_is_valid(buf) then return end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local header_end = find_header_end(lines, header_lines)

  -- Resolve effect (pick random if "random")
  local effect = config.options.animation.effect
  if effect == "random" then
    effect = get_random_effect()
  end

  -- Create fade highlight groups if needed
  if effect == "fade" then
    create_fade_highlights(highlight)
  end

  -- Store state for potential stop
  animation_state.running = true
  animation_state.buf = buf
  animation_state.header_end = header_end
  animation_state.highlight = highlight
  animation_state.effect = effect

  animate(buf, win, 0, config.options.animation.steps, highlight, header_end, false)
end

return M
