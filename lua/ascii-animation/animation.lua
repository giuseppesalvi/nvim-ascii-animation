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
local function chaos_line(line, reveal_ratio)
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
local function typewriter_line(line, reveal_ratio)
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

  -- Typewriter uses linear timing, chaos uses ease-in-out
  local reveal_ratio
  local frame_delay
  if effect == "typewriter" then
    reveal_ratio = step / total_steps
    frame_delay = config.options.animation.min_delay
  else
    reveal_ratio = ease_in_out(step / total_steps)
    frame_delay = get_frame_delay(step, total_steps)
  end

  for i = 1, header_end do
    local line = lines[i]
    if line and #line > 0 then
      local transformed
      if effect == "typewriter" then
        transformed = typewriter_line(line, reveal_ratio)
      else
        transformed = chaos_line(line, reveal_ratio)
      end
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
