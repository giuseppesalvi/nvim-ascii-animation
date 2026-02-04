-- Animation module for ascii-animation
local config = require("ascii-animation.config")

local M = {}

M.ns_id = vim.api.nvim_create_namespace("ascii_animation")

-- Timer for ambient effects
local ambient_timer = nil

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

-- Create explode effect (center-outward reveal with scatter)
local function explode_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local len = #chars
  local center = len / 2

  -- Add line offset for staggered effect (center lines reveal first)
  local line_center = total_lines / 2
  local line_dist = math.abs(line_idx - line_center) / total_lines
  local line_offset = line_dist * 0.2

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      -- Distance from center (0 = center, 1 = edge)
      local dist_from_center = math.abs(idx - center) / (len / 2 + 0.001)
      -- Characters closer to center reveal first
      local threshold = dist_from_center + line_offset

      -- Snap phase: last 20% reveals everything quickly
      local adjusted_ratio = reveal_ratio < 0.8 and reveal_ratio * 1.1 or (0.88 + (reveal_ratio - 0.8) * 0.6)

      if adjusted_ratio > threshold then
        table.insert(result, char)
      else
        -- Scatter effect: chaos chars with position-based seed
        local seed = (line_idx * 17 + idx * 31) % #chaos_chars + 1
        local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars
        local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars) + 1
        table.insert(result, chaos_chars:sub(chaos_idx, chaos_idx))
      end
    end
  end
  return table.concat(result)
end

-- Create implode effect (edge-inward reveal with converge)
local function implode_line(line, reveal_ratio, line_idx, total_lines)
  local chaos_chars = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local len = #chars
  local center = len / 2

  -- Add line offset for staggered effect (edge lines reveal first)
  local line_center = total_lines / 2
  local line_dist = 1 - math.abs(line_idx - line_center) / total_lines
  local line_offset = line_dist * 0.2

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      -- Distance from edge (0 = edge, 1 = center)
      local dist_from_center = math.abs(idx - center) / (len / 2 + 0.001)
      local dist_from_edge = 1 - dist_from_center
      -- Characters closer to edge reveal first (converging inward)
      local threshold = dist_from_edge + line_offset

      -- Snap phase: last 20% converges everything quickly to center
      local adjusted_ratio = reveal_ratio < 0.8 and reveal_ratio * 1.1 or (0.88 + (reveal_ratio - 0.8) * 0.6)

      if adjusted_ratio > threshold then
        table.insert(result, char)
      else
        -- Scatter effect: chaos chars with position-based seed
        local seed = (line_idx * 17 + idx * 31) % #chaos_chars + 1
        local rand_offset = math.floor(reveal_ratio * 10) % #chaos_chars
        local chaos_idx = ((seed + rand_offset - 1) % #chaos_chars) + 1
        table.insert(result, chaos_chars:sub(chaos_idx, chaos_idx))
      end
    end
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
  explode = explode_line,
  implode = implode_line,
}

-- List of effect names for random selection
local effect_names = { "chaos", "typewriter", "diagonal", "lines", "matrix", "explode", "implode" }

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
  elseif effect == "explode" or effect == "implode" then
    -- Fast timing for dramatic scatter/converge effect
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
      local transformed = effect_fn(line, reveal_ratio, i, header_end)
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i - 1, 0, {
        virt_text = { { transformed, highlight or "Normal" } },
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

  -- Store state for potential stop
  animation_state.running = true
  animation_state.buf = buf
  animation_state.header_end = header_end
  animation_state.highlight = highlight
  animation_state.effect = effect

  animate(buf, win, 0, config.options.animation.steps, highlight, header_end, false)
end

return M
