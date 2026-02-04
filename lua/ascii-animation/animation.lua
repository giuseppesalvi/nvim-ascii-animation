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

-- Special glitch characters for cyberpunk aesthetic
local glitch_chars = "█▓▒░▀▄▌▐▊▋▍▎▏┃┆┇┊┋╎╏│║▕▐▌"
local tear_chars = "▌▐█▓▒░"

-- Highlight groups for color glitches (using built-in Neovim highlights)
local glitch_highlights = { "ErrorMsg", "WarningMsg", "DiffDelete", "DiffChange", "Special" }

-- Create glitch reveal effect (cyberpunk-style with corruption)
-- Returns: string (normal) or table of {text, highlight} segments (color_glitch enabled)
local function glitch_line(line, reveal_ratio, line_idx, total_lines)
  local opts = config.options.animation.effect_options.glitch
  local chaos_chars_str = config.options.chaos_chars
  local chars = vim.fn.split(line, "\\zs")
  local result = {}
  local segments = {}  -- For color glitch mode: {text, highlight} pairs

  -- Calculate effective glitch intensity (decreases as reveal progresses)
  local resolve_factor = reveal_ratio ^ (1 / opts.resolve_speed)
  local effective_intensity = opts.intensity * (1 - resolve_factor)

  -- Determine if this line has a horizontal tear effect
  local has_tear = math.random() < opts.tear_chance * (1 - resolve_factor)
  local tear_offset = 0
  local tear_start = 0
  local tear_end = 0

  if has_tear and #chars > 0 then
    -- Create a horizontal offset for part of the line (tear effect)
    tear_offset = math.random(-3, 3)
    tear_start = math.random(1, math.max(1, #chars - 5))
    tear_end = math.min(#chars, tear_start + math.random(3, 10))
  end

  -- Determine if there's a block glitch on this line
  local has_block = math.random() < opts.block_chance * (1 - resolve_factor)
  local block_start = 0
  local block_end = 0

  if has_block and #chars > 0 then
    block_start = math.random(1, #chars)
    block_end = math.min(#chars, block_start + math.random(1, opts.block_size))
  end

  -- Track current segment for color glitch mode
  local current_text = ""
  local current_is_glitch = false

  local function flush_segment(base_highlight)
    if #current_text > 0 then
      if opts.color_glitch and current_is_glitch then
        local hl = glitch_highlights[math.random(1, #glitch_highlights)]
        table.insert(segments, { current_text, hl })
      else
        table.insert(segments, { current_text, base_highlight })
      end
      current_text = ""
    end
  end

  for idx, char in ipairs(chars) do
    local output_char = char
    local is_glitched = false

    if char == " " or char == "" then
      -- Handle spaces with tear offset
      if has_tear and idx >= tear_start and idx <= tear_end then
        if tear_offset > 0 then
          -- Add extra spaces (shift right)
          if idx == tear_start then
            for _ = 1, tear_offset do
              table.insert(result, " ")
              current_text = current_text .. " "
            end
          end
          table.insert(result, char)
          current_text = current_text .. char
        elseif tear_offset < 0 then
          -- Skip spaces (shift left)
          if idx >= tear_start - tear_offset then
            table.insert(result, char)
            current_text = current_text .. char
          end
        else
          table.insert(result, char)
          current_text = current_text .. char
        end
      else
        table.insert(result, char)
        current_text = current_text .. char
      end
    else
      -- Non-space character processing
      local is_revealed = math.random() < resolve_factor

      if is_revealed then
        output_char = char
        is_glitched = false
      else
        -- Apply various glitch effects
        local effect_roll = math.random()

        if has_block and idx >= block_start and idx <= block_end then
          -- Block glitch: replace with block characters
          local block_idx = math.random(1, #glitch_chars)
          output_char = glitch_chars:sub(block_idx, block_idx)
          is_glitched = true
        elseif effect_roll < effective_intensity * 0.6 then
          -- Primary glitch: use glitch block characters
          local glitch_idx = math.random(1, #glitch_chars)
          output_char = glitch_chars:sub(glitch_idx, glitch_idx)
          is_glitched = true
        elseif effect_roll < effective_intensity then
          -- Secondary glitch: use standard chaos characters
          local chaos_idx = math.random(1, #chaos_chars_str)
          output_char = chaos_chars_str:sub(chaos_idx, chaos_idx)
          is_glitched = true
        else
          -- Slight corruption: sometimes show correct char
          output_char = char
          is_glitched = false
        end
      end

      -- Apply tear offset to non-space characters
      if has_tear and idx >= tear_start and idx <= tear_end then
        if tear_offset > 0 and idx == tear_start then
          -- Add tear visual indicator
          local tear_idx = math.random(1, #tear_chars)
          local tear_char = tear_chars:sub(tear_idx, tear_idx)
          for _ = 1, tear_offset do
            table.insert(result, tear_char)
            -- Flush current segment and add tear as glitched
            if opts.color_glitch then
              flush_segment(nil)
              current_text = string.rep(tear_char, tear_offset)
              current_is_glitch = true
              flush_segment(nil)
            end
          end
        end
      end

      -- Handle segment transitions for color glitch mode
      if opts.color_glitch and is_glitched ~= current_is_glitch then
        flush_segment(nil)
        current_is_glitch = is_glitched
      end

      table.insert(result, output_char)
      current_text = current_text .. output_char
    end
  end

  -- If color glitch is enabled, return segments for multi-highlight rendering
  if opts.color_glitch then
    flush_segment(nil)
    if #segments > 0 then
      return { is_segments = true, segments = segments }
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
  glitch = glitch_line,
}

-- List of effect names for random selection
local effect_names = { "chaos", "typewriter", "diagonal", "lines", "matrix", "glitch" }

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
  elseif effect == "glitch" then
    -- Glitch uses linear progression with fast updates for flickering effect
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

      -- Handle segmented output (for color glitch effects)
      local virt_text
      if type(transformed) == "table" and transformed.is_segments then
        -- Build virt_text from segments, applying base highlight to non-glitch segments
        virt_text = {}
        for _, seg in ipairs(transformed.segments) do
          local text, hl = seg[1], seg[2]
          table.insert(virt_text, { text, hl or highlight or "Normal" })
        end
      else
        -- Simple string output
        virt_text = { { transformed, highlight or "Normal" } }
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

  -- Store state for potential stop
  animation_state.running = true
  animation_state.buf = buf
  animation_state.header_end = header_end
  animation_state.highlight = highlight
  animation_state.effect = effect

  animate(buf, win, 0, config.options.animation.steps, highlight, header_end, false)
end

return M
