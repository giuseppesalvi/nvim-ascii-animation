-- Animation module for ascii-animation
local config = require("ascii-animation.config")

local M = {}

-- Animation namespace
M.ns_id = vim.api.nvim_create_namespace("ascii_animation")

-- Ease-in-out cubic function for smooth acceleration/deceleration
function M.ease_in_out(t)
  if t < 0.5 then
    return 4 * t * t * t
  else
    return 1 - math.pow(-2 * t + 2, 3) / 2
  end
end

-- Calculate frame delay based on position (slow-fast-slow)
function M.get_frame_delay(step, total_steps)
  local opts = config.options.animation
  local t = step / total_steps

  -- Distance from center (0 at edges, 1 at center)
  local center_dist = 1 - math.abs(t - 0.5) * 2

  -- Apply ease curve for smoother transitions
  local speed_factor = M.ease_in_out(center_dist)

  return math.floor(opts.max_delay - (speed_factor * (opts.max_delay - opts.min_delay)))
end

-- Create chaotic version of a line (preserving spaces for alignment)
function M.chaos_line(line, reveal_ratio)
  local chaos_chars = config.options.chaos_chars
  local result = {}
  local chars = vim.fn.split(line, "\\zs") -- Split into characters (UTF-8 safe)

  for _, char in ipairs(chars) do
    if char == " " or char == "" then
      table.insert(result, char)
    elseif math.random() < reveal_ratio then
      table.insert(result, char)
    else
      local rand_idx = math.random(1, #chaos_chars)
      table.insert(result, chaos_chars:sub(rand_idx, rand_idx))
    end
  end

  return table.concat(result)
end

-- Main animation function using extmarks overlay
function M.animate(buf, win, step, total_steps, header_lines, highlight)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.api.nvim_win_is_valid(win) then return end

  -- Clear previous extmarks
  vim.api.nvim_buf_clear_namespace(buf, M.ns_id, 0, -1)

  -- If animation complete, we're done (let original text show)
  if step > total_steps then
    return
  end

  -- Apply easing to reveal ratio for smoother visual progression
  local linear_progress = step / total_steps
  local reveal_ratio = M.ease_in_out(linear_progress)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local animate_lines = math.min(header_lines, #lines)

  for i = 0, animate_lines - 1 do
    local line = lines[i + 1]
    if line and #line > 0 then
      local chaotic = M.chaos_line(line, reveal_ratio)
      -- Overlay chaotic text using virtual text
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns_id, i, 0, {
        virt_text = { { chaotic, highlight or "Normal" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end

  -- Schedule next step with variable delay (slow-fast-slow)
  local delay = M.get_frame_delay(step, total_steps)
  vim.defer_fn(function()
    M.animate(buf, win, step + 1, total_steps, header_lines, highlight)
  end, delay)
end

-- Start animation on a buffer
function M.start(buf, header_lines, highlight)
  if not config.options.animation.enabled then return end

  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_buf_is_valid(buf) then return end

  local total_steps = config.options.animation.steps
  M.animate(buf, win, 0, total_steps, header_lines, highlight)
end

return M
