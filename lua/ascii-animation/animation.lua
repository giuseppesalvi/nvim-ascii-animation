-- Animation module for ascii-animation
local config = require("ascii-animation.config")

local M = {}

M.ns_id = vim.api.nvim_create_namespace("ascii_animation")

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
      table.insert(result, " ")  -- Hidden: blank
    end
  end

  return table.concat(result)
end

-- Create diagonal sweep version (top-left to bottom-right)
local function diagonal_line(line, reveal_ratio, line_idx, total_lines)
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
        table.insert(result, " ")
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
    -- Not yet revealed: blank (preserve spaces for alignment)
    local chars = vim.fn.split(line, "\\zs")
    local result = {}
    for _, char in ipairs(chars) do
      table.insert(result, " ")
    end
    return table.concat(result)
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
      elseif char_progress >= 0.3 then
        -- Falling: show random matrix character
        local rand_idx = math.random(1, #chaos_chars)
        table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
      else
        table.insert(result, " ")  -- Not started falling
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
}

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
local function animate(buf, win, step, total_steps, highlight, header_end)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.api.nvim_win_is_valid(win) then return end

  vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)

  if step > total_steps then return end

  local effect = config.options.animation.effect
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Timing varies per effect
  local reveal_ratio
  local frame_delay
  if effect == "typewriter" or effect == "diagonal" then
    reveal_ratio = step / total_steps
    frame_delay = config.options.animation.min_delay
  elseif effect == "lines" then
    reveal_ratio = ease_in_out(step / total_steps)
    frame_delay = config.options.animation.max_delay / 2
  elseif effect == "matrix" then
    reveal_ratio = step / total_steps
    frame_delay = config.options.animation.min_delay
  else  -- chaos (default)
    reveal_ratio = ease_in_out(step / total_steps)
    frame_delay = get_frame_delay(step, total_steps)
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

  vim.defer_fn(function()
    animate(buf, win, step + 1, total_steps, highlight, header_end)
  end, frame_delay)
end

-- Start animation on a buffer
function M.start(buf, header_lines, highlight)
  if not config.options.animation.enabled then return end

  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_buf_is_valid(buf) then return end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local header_end = find_header_end(lines, header_lines)

  animate(buf, win, 0, config.options.animation.steps, highlight, header_end)
end

return M
