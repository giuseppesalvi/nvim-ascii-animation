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

-- Create scramble version (password reveal / slot machine effect)
local function scramble_line(line, reveal_ratio, line_idx, total_lines)
  local effect_opts = config.options.effect_options or {}
  local stagger = effect_opts.stagger or "left"
  local charset = effect_opts.charset or config.options.chaos_chars

  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local num_chars = #chars
  if num_chars == 0 then return "" end

  -- Convert stagger_delay to spread factor (30 = 0.6 spread, range 0.3-0.8)
  local stagger_delay = effect_opts.stagger_delay or 30
  local stagger_spread = math.max(0.3, math.min(0.8, stagger_delay / 50))

  -- Convert cycles to settle duration (5 cycles = 0.3, range 0.2-0.5)
  local cycles = effect_opts.cycles or 5
  local settle_duration = math.max(0.2, math.min(0.5, 0.1 + cycles / 25))

  -- Calculate stagger offset for each character position (0 to 1)
  local function get_stagger_offset(idx)
    if stagger == "right" then
      return 1 - (idx - 1) / math.max(1, num_chars - 1)
    elseif stagger == "center" then
      local mid = (num_chars + 1) / 2
      return math.abs(idx - mid) / math.max(1, mid - 1)
    elseif stagger == "random" then
      -- Deterministic pseudo-random based on line and position
      return ((line_idx * 17 + idx * 31) % 100) / 100
    else -- "left" (default)
      return (idx - 1) / math.max(1, num_chars - 1)
    end
  end

  for idx, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    else
      local stagger_offset = get_stagger_offset(idx)
      -- Character settle time based on stagger position
      local settle_time = stagger_offset * stagger_spread + settle_duration

      if reveal_ratio >= settle_time then
        -- Settled: show final character
        table.insert(result, char)
      else
        -- Scrambling: show random character from charset
        local rand_idx = math.random(1, #charset)
        table.insert(result, charset:sub(rand_idx, rand_idx))
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
  scramble = scramble_line,
}

-- List of effect names for random selection
local effect_names = { "chaos", "typewriter", "diagonal", "lines", "matrix", "scramble" }

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
  elseif effect == "scramble" then
    -- Linear progression with fast frame rate for slot-machine feel
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
