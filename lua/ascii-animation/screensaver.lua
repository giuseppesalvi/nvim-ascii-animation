-- Screensaver mode: full-screen animated ASCII art after idle timeout

local config = require("ascii-animation.config")
local animation = require("ascii-animation.animation")
local content = require("ascii-animation.content")
local audio = require("ascii-animation.audio")

local M = {}

local state = {
  idle_timer = nil,
  active = false,
  buf = nil,
  win = nil,
  enabled = true,
  prev_win = nil,
  augroup = nil,
  resize_autocmd = nil,
  original_loop = nil,
  original_effect = nil,
  movement_timer = nil,
  art_lines = nil,
  screen_width = nil,
  screen_height = nil,
  display_mode = nil,
  audio_modulator = nil,
  original_loop_delay = nil,
  original_ambient_interval = nil,
}

-- Reset idle timer on activity
local function reset_idle_timer()
  if not state.enabled or state.active then
    return
  end

  local opts = config.options.screensaver or {}
  local timeout = opts.timeout or (1000 * 60 * 5)

  if state.idle_timer then
    state.idle_timer:stop()
    state.idle_timer:close()
    state.idle_timer = nil
  end

  state.idle_timer = vim.uv.new_timer()
  state.idle_timer:start(timeout, 0, vim.schedule_wrap(function()
    M.trigger()
  end))
end

-- Setup dismiss keybindings on the screensaver buffer
local function setup_dismiss_keys(buf)
  local opts = config.options.screensaver or {}
  local dismiss = opts.dismiss or "any"
  local map_opts = { buffer = buf, nowait = true, silent = true }

  if dismiss == "escape" then
    vim.keymap.set("n", "<Esc>", function() M.dismiss() end, map_opts)
  else
    -- Map all printable characters, special keys, and mouse events
    for i = 32, 126 do
      local char = string.char(i)
      pcall(vim.keymap.set, "n", char, function() M.dismiss() end, map_opts)
    end
    local special_keys = { "<Esc>", "<CR>", "<Space>", "<BS>", "<Tab>", "<LeftMouse>", "<RightMouse>" }
    for _, key in ipairs(special_keys) do
      pcall(vim.keymap.set, "n", key, function() M.dismiss() end, map_opts)
    end
  end
end

-- Resolve "random" display mode to a concrete mode
local function resolve_display_mode()
  local ss_opts = config.options.screensaver or {}
  local display = ss_opts.display or "static"
  if display == "random" then
    local modes = { "static", "bounce", "tile", "marquee", "zoom" }
    if audio.check_sox() then
      modes = { "static", "bounce", "tile", "marquee", "zoom", "pulse", "waves", "rain", "shatter", "fireworks", "heartbeat" }
    end
    return modes[math.random(1, #modes)]
  end
  return display
end

-- Build full-screen line array with art positioned at (row, col), clipped to bounds
local function build_positioned_buffer(art_lines, row, col, w, h)
  local lines = {}
  -- Get max art width for clipping
  local art_widths = {}
  for i, line in ipairs(art_lines) do
    art_widths[i] = vim.fn.strdisplaywidth(line)
  end

  for y = 1, h do
    local art_row = y - row
    if art_row >= 1 and art_row <= #art_lines then
      local art_line = art_lines[art_row]
      local line_width = art_widths[art_row]
      if col >= 0 and col + line_width <= w then
        -- Fully visible
        table.insert(lines, string.rep(" ", col) .. art_line)
      elseif col >= 0 and col < w then
        -- Partially visible (right edge clipped)
        local visible_chars = w - col
        local chars = vim.fn.split(art_line, "\\zs")
        local result = {}
        local display_w = 0
        for _, c in ipairs(chars) do
          local cw = vim.fn.strdisplaywidth(c)
          if display_w + cw > visible_chars then break end
          table.insert(result, c)
          display_w = display_w + cw
        end
        table.insert(lines, string.rep(" ", col) .. table.concat(result))
      elseif col < 0 and col + line_width > 0 then
        -- Partially visible (left edge clipped)
        local skip = -col
        local chars = vim.fn.split(art_line, "\\zs")
        local result = {}
        local skipped = 0
        for _, c in ipairs(chars) do
          local cw = vim.fn.strdisplaywidth(c)
          if skipped < skip then
            skipped = skipped + cw
          else
            table.insert(result, c)
          end
        end
        table.insert(lines, table.concat(result))
      else
        table.insert(lines, "")
      end
    else
      table.insert(lines, "")
    end
  end

  return lines
end

-- Tile art in a grid pattern to fill screen
local function tile_art(art_lines, w, h)
  local art_height = #art_lines
  if art_height == 0 then return {} end

  -- Compute max art width
  local art_width = 0
  for _, line in ipairs(art_lines) do
    local lw = vim.fn.strdisplaywidth(line)
    if lw > art_width then art_width = lw end
  end

  local h_gap = 2  -- horizontal gap between tiles
  local v_gap = 1  -- vertical gap between tiles
  local tile_w = art_width + h_gap
  local tile_h = art_height + v_gap

  local lines = {}
  for y = 1, h do
    local tile_row = ((y - 1) % tile_h) + 1
    if tile_row <= art_height then
      -- Build a row by repeating the art line
      local art_line = art_lines[tile_row]
      local art_lw = vim.fn.strdisplaywidth(art_line)
      local pad = string.rep(" ", art_width - art_lw)
      local tile_unit = art_line .. pad .. string.rep(" ", h_gap)
      local cols_needed = math.ceil(w / tile_w) + 1
      local row = string.rep(tile_unit, cols_needed)
      -- Trim to screen width
      local chars = vim.fn.split(row, "\\zs")
      local result = {}
      local display_w = 0
      for _, c in ipairs(chars) do
        local cw = vim.fn.strdisplaywidth(c)
        if display_w + cw > w then break end
        table.insert(result, c)
        display_w = display_w + cw
      end
      table.insert(lines, table.concat(result))
    else
      table.insert(lines, "")
    end
  end

  return lines
end

-- Zoom art: double each character horizontally and duplicate each line vertically
local function zoom_art(art_lines)
  local zoomed = {}
  for _, line in ipairs(art_lines) do
    local chars = vim.fn.split(line, "\\zs")
    local doubled = {}
    for _, c in ipairs(chars) do
      if c == " " then
        table.insert(doubled, "  ")
      else
        table.insert(doubled, c .. c)
      end
    end
    local zoomed_line = table.concat(doubled)
    table.insert(zoomed, zoomed_line)
    table.insert(zoomed, zoomed_line)  -- duplicate vertically
  end
  return zoomed
end

-- Start DVD-style bounce movement after animation completes
local function start_bounce(buf, art_lines, w, h)
  -- Calculate art dimensions
  local art_height = #art_lines
  local art_width = 0
  for _, line in ipairs(art_lines) do
    local lw = vim.fn.strdisplaywidth(line)
    if lw > art_width then art_width = lw end
  end

  -- Starting position (centered)
  local pos_x = math.max(0, math.floor((w - art_width) / 2))
  local pos_y = math.max(0, math.floor((h - art_height) / 2))
  local vel_x = 1
  local vel_y = 1

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(70, 70, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Audio-reactive speed multiplier
    local move_mult = 1
    if audio.is_running() then
      move_mult = math.max(1, math.floor(1 + audio.get_level() * 3))
    end

    -- Update position
    pos_x = pos_x + vel_x * move_mult
    pos_y = pos_y + vel_y * move_mult

    -- Bounce off edges
    if pos_x <= 0 then
      pos_x = 0
      vel_x = 1
    elseif pos_x + art_width >= w then
      pos_x = w - art_width
      vel_x = -1
    end

    if pos_y <= 0 then
      pos_y = 0
      vel_y = 1
    elseif pos_y + art_height >= h then
      pos_y = h - art_height
      vel_y = -1
    end

    -- Build and set buffer content
    local lines = build_positioned_buffer(art_lines, pos_y + 1, pos_x, w, h)
    pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  end))
end

-- Start marquee (horizontal scroll) movement after animation completes
local function start_marquee(buf, art_lines, w, h)
  local art_height = #art_lines
  local art_width = 0
  for _, line in ipairs(art_lines) do
    local lw = vim.fn.strdisplaywidth(line)
    if lw > art_width then art_width = lw end
  end

  -- Start from current centered position, scroll left
  local pos_x = math.floor((w - art_width) / 2)
  local pos_y = math.max(0, math.floor((h - art_height) / 2))

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(50, 50, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Audio-reactive speed multiplier
    local scroll_speed = 1
    if audio.is_running() then
      scroll_speed = math.max(1, math.floor(1 + audio.get_level() * 3))
    end

    -- Move left
    pos_x = pos_x - scroll_speed

    -- Wrap when fully off-screen left
    if pos_x + art_width < 0 then
      pos_x = w
    end

    -- Build and set buffer content
    local lines = build_positioned_buffer(art_lines, pos_y + 1, pos_x, w, h)
    pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  end))
end

-- Build centered buffer content for art
local function build_centered_buffer(art_lines, w, h)
  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  local lines = {}
  for _ = 1, top_pad do
    table.insert(lines, "")
  end
  for _, line in ipairs(art_lines) do
    local line_width = vim.fn.strdisplaywidth(line)
    local left_pad = math.max(0, math.floor((w - line_width) / 2))
    table.insert(lines, string.rep(" ", left_pad) .. line)
  end
  local remaining = h - #lines
  for _ = 1, remaining do
    table.insert(lines, "")
  end

  return lines, top_pad, art_height
end

-- Start pulse (audio-reactive equalizer chaos overlay) after animation completes
local function start_pulse(buf, art_lines, w, h)
  -- Auto-start audio if not already running
  if not audio.is_running() then
    if not audio.start() then
      -- sox unavailable: art stays clean (no overlay)
      return
    end
  end

  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  -- Cache chaos characters
  local chaos_str = config.get_chaos_chars()
  local chaos_tbl = vim.fn.split(chaos_str, "\\zs")
  local function random_chaos()
    return chaos_tbl[math.random(1, #chaos_tbl)]
  end

  local smoothed = 0.0
  local ns_id = animation.ns_id

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(80, 80, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Read audio level with 10x gain, clamped to 0-1
    local raw = math.min(audio.get_level() * 10, 1.0)
    -- Smooth to avoid jitter (0.4 blend factor)
    smoothed = smoothed + (raw - smoothed) * 0.4

    -- Clear previous overlays
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)

    -- Skip work when silent
    if smoothed < 0.02 then return end

    -- Overlay chaos on each art row, bottom-heavy like an equalizer
    for i = 1, art_height do
      local line = art_lines[i]
      if line and #line > 0 then
        local row_position = i / art_height -- 0=top, 1=bottom
        local row_weight = row_position * row_position -- bottom-heavy curve
        local zone_start = 1.0 - smoothed

        if row_position >= zone_start then
          local zone_depth = (row_position - zone_start) / smoothed
          local disruption = zone_depth * row_weight * 0.85

          local chars = vim.fn.split(line, "\\zs")
          local modified = false
          for j = 1, #chars do
            if chars[j] ~= " " and math.random() < disruption then
              chars[j] = random_chaos()
              modified = true
            end
          end

          if modified then
            -- Pad to match centered position in buffer
            local line_width = vim.fn.strdisplaywidth(line)
            local left_pad = math.max(0, math.floor((w - line_width) / 2))
            local overlay_text = string.rep(" ", left_pad) .. table.concat(chars)
            local buf_row = top_pad + i - 1 -- 0-indexed buffer row
            pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, buf_row, 0, {
              virt_text = { { overlay_text, "Normal" } },
              virt_text_pos = "overlay",
              hl_mode = "combine",
            })
          end
        end
      end
    end
  end))
end

-- Start waves (audio-reactive concentric ripples from art edges) after animation completes
local function start_waves(buf, art_lines, w, h)
  -- Auto-start audio if not already running
  if not audio.is_running() then
    if not audio.start() then
      -- sox unavailable: art stays clean (no ripples)
      return
    end
  end

  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  -- Precompute art structure: chars and widths per line, and left padding
  local art_chars = {}
  local art_widths = {}
  local art_left_pads = {}
  for i, line in ipairs(art_lines) do
    art_chars[i] = vim.fn.split(line, "\\zs")
    local lw = vim.fn.strdisplaywidth(line)
    art_widths[i] = lw
    art_left_pads[i] = math.max(0, math.floor((w - lw) / 2))
  end

  -- Art bounding box in buffer coordinates (0-indexed)
  local art_top = top_pad
  local art_bottom = top_pad + art_height - 1
  -- Use max art width for left/right bounds
  local max_art_width = 0
  for _, lw in ipairs(art_widths) do
    if lw > max_art_width then max_art_width = lw end
  end
  local art_left = math.max(0, math.floor((w - max_art_width) / 2))
  local art_right = art_left + max_art_width - 1

  -- Cache chaos characters
  local chaos_str = config.get_chaos_chars()
  local chaos_tbl = vim.fn.split(chaos_str, "\\zs")
  local function random_chaos()
    return chaos_tbl[math.random(1, #chaos_tbl)]
  end

  local smoothed = 0.0
  local prev_smoothed = 0.0
  local ns_id = animation.ns_id
  local waves = {}
  local spawn_cooldown = 0

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(80, 80, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Read audio level with 10x gain, clamped to 0-1
    local raw = math.min(audio.get_level() * 10, 1.0)
    prev_smoothed = smoothed
    smoothed = smoothed + (raw - smoothed) * 0.4

    -- Spawn new wave on audio spike
    if spawn_cooldown > 0 then
      spawn_cooldown = spawn_cooldown - 1
    end
    local delta = smoothed - prev_smoothed
    if smoothed > 0.15 and delta > 0.05 and spawn_cooldown == 0 and #waves < 8 then
      table.insert(waves, { radius = 0, intensity = math.min(smoothed * 1.5, 1.0), thickness = 3 })
      spawn_cooldown = 3
    end

    -- Advance waves
    local active_waves = {}
    local max_dim = math.max(w, h)
    for _, wave in ipairs(waves) do
      wave.radius = wave.radius + 0.8
      wave.intensity = wave.intensity * 0.92
      if wave.intensity >= 0.05 and wave.radius < max_dim then
        table.insert(active_waves, wave)
      end
    end
    waves = active_waves

    -- Clear previous overlays
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)

    -- Skip rendering when silent and no active waves
    if smoothed < 0.02 and #waves == 0 then return end

    -- Render waves
    for row = 0, h - 1 do
      local in_art_rows = (row >= art_top and row <= art_bottom)
      local art_row_idx = row - art_top + 1 -- 1-indexed into art_lines

      -- Compute Chebyshev distance to art bounding box for each column
      local dy = 0
      if row < art_top then
        dy = art_top - row
      elseif row > art_bottom then
        dy = row - art_bottom
      end

      local overlay_chars = {}
      local has_content = false

      for col = 0, w - 1 do
        local dx = 0
        if col < art_left then
          dx = art_left - col
        elseif col > art_right then
          dx = col - art_right
        end

        local distance = math.max(dx, dy)

        -- Check if this cell is inside the art region
        local in_art_region = in_art_rows and col >= art_left and col <= art_right

        if in_art_region then
          -- Preserve art character: reproduce from precomputed data
          local line_left = art_left_pads[art_row_idx]
          local local_col = col - line_left
          local chars = art_chars[art_row_idx]
          if local_col >= 0 and chars and local_col < #chars then
            local ch = chars[local_col + 1]
            if ch then
              table.insert(overlay_chars, ch)
            else
              table.insert(overlay_chars, " ")
            end
          else
            table.insert(overlay_chars, " ")
          end
        elseif distance > 0 then
          -- Outside art: check if any wave covers this cell
          local max_intensity = 0
          for _, wave in ipairs(waves) do
            if distance >= wave.radius and distance < wave.radius + wave.thickness then
              -- Fade across band width (stronger at inner edge)
              local band_pos = (distance - wave.radius) / wave.thickness
              local cell_intensity = wave.intensity * (1 - band_pos)
              if cell_intensity > max_intensity then
                max_intensity = cell_intensity
              end
            end
          end

          if max_intensity > 0 and math.random() < max_intensity then
            table.insert(overlay_chars, random_chaos())
            has_content = true
          else
            table.insert(overlay_chars, " ")
          end
        else
          table.insert(overlay_chars, " ")
        end
      end

      if has_content or in_art_rows then
        local overlay_text = table.concat(overlay_chars)
        pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0, {
          virt_text = { { overlay_text, "Normal" } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
  end))
end

-- Start rain (audio-reactive falling characters) after animation completes
local function start_rain(buf, art_lines, w, h)
  -- Auto-start audio if not already running
  if not audio.is_running() then
    if not audio.start() then
      return
    end
  end

  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  -- Precompute art structure for reproduction
  local art_chars = {}
  local art_widths = {}
  local art_left_pads = {}
  for i, line in ipairs(art_lines) do
    art_chars[i] = vim.fn.split(line, "\\zs")
    local lw = vim.fn.strdisplaywidth(line)
    art_widths[i] = lw
    art_left_pads[i] = math.max(0, math.floor((w - lw) / 2))
  end

  -- Art bounding box in buffer coordinates (0-indexed)
  local art_top = top_pad
  local art_bottom = top_pad + art_height - 1
  local max_art_width = 0
  for _, lw in ipairs(art_widths) do
    if lw > max_art_width then max_art_width = lw end
  end
  local art_left = math.max(0, math.floor((w - max_art_width) / 2))
  local art_right = art_left + max_art_width - 1

  -- Cache chaos characters
  local chaos_str = config.get_chaos_chars()
  local chaos_tbl = vim.fn.split(chaos_str, "\\zs")
  local function random_chaos()
    return chaos_tbl[math.random(1, #chaos_tbl)]
  end

  local smoothed = 0.0
  local ns_id = animation.ns_id
  local drops = {}

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(80, 80, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Read audio level with 10x gain, clamped to 0-1
    local raw = math.min(audio.get_level() * 10, 1.0)
    smoothed = smoothed + (raw - smoothed) * 0.4

    -- Spawn new drops based on audio level
    local count = math.floor(smoothed * 8)
    for _ = 1, count do
      if #drops < 150 then
        table.insert(drops, {
          col = math.random(0, w - 1),
          row = -1,
          speed = 0.8 + math.random() * 0.4,
          char = random_chaos(),
        })
      end
    end

    -- Move drops and remove those off-screen
    local active_drops = {}
    for _, drop in ipairs(drops) do
      drop.row = drop.row + drop.speed
      if drop.row < h then
        table.insert(active_drops, drop)
      end
    end
    drops = active_drops

    -- Clear previous overlays
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)

    -- Skip rendering when silent and no drops
    if smoothed < 0.02 and #drops == 0 then return end

    -- Build a grid of drop characters
    local grid = {}
    for _, drop in ipairs(drops) do
      local r = math.floor(drop.row)
      if r >= 0 and r < h then
        -- Skip drops inside art region
        local in_art = (r >= art_top and r <= art_bottom and drop.col >= art_left and drop.col <= art_right)
        if not in_art then
          if not grid[r] then grid[r] = {} end
          grid[r][drop.col] = drop.char
        end
      end
    end

    -- Render overlays row by row
    for row = 0, h - 1 do
      local in_art_rows = (row >= art_top and row <= art_bottom)
      local art_row_idx = row - art_top + 1
      local has_drops = grid[row] ~= nil

      if in_art_rows or has_drops then
        local overlay_chars = {}
        local has_content = false

        for col = 0, w - 1 do
          local in_art_region = in_art_rows and col >= art_left and col <= art_right

          if in_art_region then
            -- Preserve art character
            local line_left = art_left_pads[art_row_idx]
            local local_col = col - line_left
            local chars = art_chars[art_row_idx]
            if local_col >= 0 and chars and local_col < #chars then
              local ch = chars[local_col + 1]
              if ch then
                table.insert(overlay_chars, ch)
              else
                table.insert(overlay_chars, " ")
              end
            else
              table.insert(overlay_chars, " ")
            end
          elseif has_drops and grid[row][col] then
            table.insert(overlay_chars, grid[row][col])
            has_content = true
          else
            table.insert(overlay_chars, " ")
          end
        end

        if has_content or in_art_rows then
          local overlay_text = table.concat(overlay_chars)
          pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0, {
            virt_text = { { overlay_text, "Normal" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        end
      end
    end
  end))
end

-- Start shatter (audio-reactive exploding/reassembling art) after animation completes
local function start_shatter(buf, art_lines, w, h)
  -- Auto-start audio if not already running
  if not audio.is_running() then
    if not audio.start() then
      return
    end
  end

  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  -- Build particles from non-space art chars at their centered buffer positions
  local particles = {}
  local center_x = w / 2
  local center_y = top_pad + art_height / 2

  for i, line in ipairs(art_lines) do
    local chars = vim.fn.split(line, "\\zs")
    local lw = vim.fn.strdisplaywidth(line)
    local left_pad = math.max(0, math.floor((w - lw) / 2))
    for j, ch in ipairs(chars) do
      if ch ~= " " then
        local px = left_pad + j - 1
        local py = top_pad + i - 1
        table.insert(particles, {
          char = ch,
          home_x = px,
          home_y = py,
          x = px,
          y = py,
          vx = 0,
          vy = 0,
        })
      end
    end
  end

  local smoothed = 0.0
  local prev_smoothed = 0.0
  local ns_id = animation.ns_id

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(80, 80, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Read audio level with 10x gain, clamped to 0-1
    local raw = math.min(audio.get_level() * 10, 1.0)
    prev_smoothed = smoothed
    smoothed = smoothed + (raw - smoothed) * 0.4

    -- Explode on audio spike
    local delta = smoothed - prev_smoothed
    if delta > 0.1 then
      for _, p in ipairs(particles) do
        local angle = math.atan2(p.home_y - center_y, p.home_x - center_x)
        local speed = smoothed * 2.0
        p.vx = p.vx + math.cos(angle) * speed
        p.vy = p.vy + math.sin(angle) * speed
      end
    end

    -- Physics: spring back to home position
    local spring = (smoothed < 0.05) and 0.25 or 0.15
    for _, p in ipairs(particles) do
      p.x = p.x + p.vx
      p.y = p.y + p.vy
      local fx = (p.home_x - p.x) * spring
      local fy = (p.home_y - p.y) * spring
      p.vx = p.vx * 0.85 + fx
      p.vy = p.vy * 0.85 + fy
    end

    -- Clear previous overlays
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)

    -- Build grid from particles
    local grid = {}
    for _, p in ipairs(particles) do
      local px = math.floor(p.x)
      local py = math.floor(p.y)
      if px >= 0 and px < w and py >= 0 and py < h then
        if not grid[py] then grid[py] = {} end
        grid[py][px] = p.char
      end
    end

    -- Render overlays
    for row = 0, h - 1 do
      if grid[row] then
        local overlay_chars = {}
        local has_content = false
        for col = 0, w - 1 do
          if grid[row][col] then
            table.insert(overlay_chars, grid[row][col])
            has_content = true
          else
            table.insert(overlay_chars, " ")
          end
        end
        if has_content then
          local overlay_text = table.concat(overlay_chars)
          pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0, {
            virt_text = { { overlay_text, "Normal" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        end
      end
    end
  end))
end

-- Start fireworks (audio-reactive burst explosions around art) after animation completes
local function start_fireworks(buf, art_lines, w, h)
  -- Auto-start audio if not already running
  if not audio.is_running() then
    if not audio.start() then
      return
    end
  end

  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  -- Precompute art structure for reproduction
  local art_chars = {}
  local art_widths = {}
  local art_left_pads = {}
  for i, line in ipairs(art_lines) do
    art_chars[i] = vim.fn.split(line, "\\zs")
    local lw = vim.fn.strdisplaywidth(line)
    art_widths[i] = lw
    art_left_pads[i] = math.max(0, math.floor((w - lw) / 2))
  end

  -- Art bounding box in buffer coordinates (0-indexed)
  local art_top = top_pad
  local art_bottom = top_pad + art_height - 1
  local max_art_width = 0
  for _, lw in ipairs(art_widths) do
    if lw > max_art_width then max_art_width = lw end
  end
  local art_left = math.max(0, math.floor((w - max_art_width) / 2))
  local art_right = art_left + max_art_width - 1

  -- Cache chaos characters
  local chaos_str = config.get_chaos_chars()
  local chaos_tbl = vim.fn.split(chaos_str, "\\zs")
  local function random_chaos()
    return chaos_tbl[math.random(1, #chaos_tbl)]
  end

  local smoothed = 0.0
  local prev_smoothed = 0.0
  local ns_id = animation.ns_id
  local bursts = {}
  local spawn_cooldown = 0

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(80, 80, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Read audio level with 10x gain, clamped to 0-1
    local raw = math.min(audio.get_level() * 10, 1.0)
    prev_smoothed = smoothed
    smoothed = smoothed + (raw - smoothed) * 0.4

    -- Spawn burst on audio spike
    if spawn_cooldown > 0 then
      spawn_cooldown = spawn_cooldown - 1
    end
    local delta = smoothed - prev_smoothed
    if smoothed > 0.2 and delta > 0.08 and spawn_cooldown == 0 and #bursts < 5 then
      -- Random position 5-15 chars from art edge
      local offset = math.random(5, 15)
      local side = math.random(1, 4)
      local cx, cy
      if side == 1 then -- top
        cx = math.random(art_left, art_right)
        cy = art_top - offset
      elseif side == 2 then -- bottom
        cx = math.random(art_left, art_right)
        cy = art_bottom + offset
      elseif side == 3 then -- left
        cx = art_left - offset
        cy = math.random(art_top, art_bottom)
      else -- right
        cx = art_right + offset
        cy = math.random(art_top, art_bottom)
      end

      local burst_particles = {}
      local num = math.random(15, 25)
      for _ = 1, num do
        local angle = math.random() * math.pi * 2
        local speed = 0.5 + math.random() * 1.5
        table.insert(burst_particles, {
          dx = 0,
          dy = 0,
          vx = math.cos(angle) * speed,
          vy = math.sin(angle) * speed,
          char = random_chaos(),
          alpha = 1.0,
        })
      end
      table.insert(bursts, { cx = cx, cy = cy, particles = burst_particles })
      spawn_cooldown = 4
    end

    -- Move burst particles and decay
    local active_bursts = {}
    for _, burst in ipairs(bursts) do
      local alive = {}
      for _, p in ipairs(burst.particles) do
        p.dx = p.dx + p.vx
        p.dy = p.dy + p.vy
        p.alpha = p.alpha * 0.88
        if p.alpha >= 0.1 then
          table.insert(alive, p)
        end
      end
      if #alive > 0 then
        burst.particles = alive
        table.insert(active_bursts, burst)
      end
    end
    bursts = active_bursts

    -- Clear previous overlays
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)

    -- Skip rendering when silent and no bursts
    if smoothed < 0.02 and #bursts == 0 then return end

    -- Build grid from burst particles
    local grid = {}
    for _, burst in ipairs(bursts) do
      for _, p in ipairs(burst.particles) do
        if math.random() < p.alpha then
          local px = math.floor(burst.cx + p.dx)
          local py = math.floor(burst.cy + p.dy)
          if px >= 0 and px < w and py >= 0 and py < h then
            -- Skip art region
            local in_art = (py >= art_top and py <= art_bottom and px >= art_left and px <= art_right)
            if not in_art then
              if not grid[py] then grid[py] = {} end
              grid[py][px] = p.char
            end
          end
        end
      end
    end

    -- Render overlays row by row
    for row = 0, h - 1 do
      local in_art_rows = (row >= art_top and row <= art_bottom)
      local art_row_idx = row - art_top + 1
      local has_burst_chars = grid[row] ~= nil

      if in_art_rows or has_burst_chars then
        local overlay_chars = {}
        local has_content = false

        for col = 0, w - 1 do
          local in_art_region = in_art_rows and col >= art_left and col <= art_right

          if in_art_region then
            -- Preserve art character
            local line_left = art_left_pads[art_row_idx]
            local local_col = col - line_left
            local chars = art_chars[art_row_idx]
            if local_col >= 0 and chars and local_col < #chars then
              local ch = chars[local_col + 1]
              if ch then
                table.insert(overlay_chars, ch)
              else
                table.insert(overlay_chars, " ")
              end
            else
              table.insert(overlay_chars, " ")
            end
          elseif has_burst_chars and grid[row][col] then
            table.insert(overlay_chars, grid[row][col])
            has_content = true
          else
            table.insert(overlay_chars, " ")
          end
        end

        if has_content or in_art_rows then
          local overlay_text = table.concat(overlay_chars)
          pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0, {
            virt_text = { { overlay_text, "Normal" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
          })
        end
      end
    end
  end))
end

-- Start heartbeat (audio-reactive pulsing aura border around art) after animation completes
local function start_heartbeat(buf, art_lines, w, h)
  -- Auto-start audio if not already running
  if not audio.is_running() then
    if not audio.start() then
      return
    end
  end

  local art_height = #art_lines
  local top_pad = math.max(0, math.floor((h - art_height) / 2))

  -- Precompute art structure for reproduction
  local art_chars = {}
  local art_widths = {}
  local art_left_pads = {}
  for i, line in ipairs(art_lines) do
    art_chars[i] = vim.fn.split(line, "\\zs")
    local lw = vim.fn.strdisplaywidth(line)
    art_widths[i] = lw
    art_left_pads[i] = math.max(0, math.floor((w - lw) / 2))
  end

  -- Art bounding box in buffer coordinates (0-indexed)
  local art_top = top_pad
  local art_bottom = top_pad + art_height - 1
  local max_art_width = 0
  for _, lw in ipairs(art_widths) do
    if lw > max_art_width then max_art_width = lw end
  end
  local art_left = math.max(0, math.floor((w - max_art_width) / 2))
  local art_right = art_left + max_art_width - 1

  -- Cache chaos characters
  local chaos_str = config.get_chaos_chars()
  local chaos_tbl = vim.fn.split(chaos_str, "\\zs")
  local function random_chaos()
    return chaos_tbl[math.random(1, #chaos_tbl)]
  end

  local smoothed = 0.0
  local prev_smoothed = 0.0
  local ns_id = animation.ns_id
  local aura_intensity = 0.0
  local beat_cooldown = 0

  -- Stop any existing movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  state.movement_timer = vim.uv.new_timer()
  state.movement_timer:start(80, 80, vim.schedule_wrap(function()
    if not state.active or not buf or not vim.api.nvim_buf_is_valid(buf) then
      if state.movement_timer then
        state.movement_timer:stop()
        state.movement_timer:close()
        state.movement_timer = nil
      end
      return
    end

    -- Read audio level with 10x gain, clamped to 0-1
    local raw = math.min(audio.get_level() * 10, 1.0)
    prev_smoothed = smoothed
    smoothed = smoothed + (raw - smoothed) * 0.4

    -- Beat detection
    if beat_cooldown > 0 then
      beat_cooldown = beat_cooldown - 1
    end
    local delta = smoothed - prev_smoothed
    if smoothed > 0.25 and delta > 0.12 and beat_cooldown == 0 then
      aura_intensity = math.min(smoothed * 1.5, 1.0)
      beat_cooldown = 8
    end

    -- Decay aura
    aura_intensity = aura_intensity * 0.85

    -- Clear previous overlays
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns_id, 0, -1)

    -- Skip rendering when aura is negligible
    if aura_intensity < 0.02 then return end

    local thickness = math.ceil(aura_intensity * 4)

    -- Render aura around art
    for row = 0, h - 1 do
      local in_art_rows = (row >= art_top and row <= art_bottom)
      local art_row_idx = row - art_top + 1

      -- Chebyshev distance to art bounding box
      local dy = 0
      if row < art_top then
        dy = art_top - row
      elseif row > art_bottom then
        dy = row - art_bottom
      end

      local overlay_chars = {}
      local has_content = false

      for col = 0, w - 1 do
        local dx = 0
        if col < art_left then
          dx = art_left - col
        elseif col > art_right then
          dx = col - art_right
        end

        local distance = math.max(dx, dy)
        local in_art_region = in_art_rows and col >= art_left and col <= art_right

        if in_art_region then
          -- Preserve art character
          local line_left = art_left_pads[art_row_idx]
          local local_col = col - line_left
          local chars = art_chars[art_row_idx]
          if local_col >= 0 and chars and local_col < #chars then
            local ch = chars[local_col + 1]
            if ch then
              table.insert(overlay_chars, ch)
            else
              table.insert(overlay_chars, " ")
            end
          else
            table.insert(overlay_chars, " ")
          end
        elseif distance >= 1 and distance <= thickness then
          -- Aura zone: probability falls off with distance
          local probability = aura_intensity * (1 - (distance - 1) / thickness)
          if probability > 0 and math.random() < probability then
            table.insert(overlay_chars, random_chaos())
            has_content = true
          else
            table.insert(overlay_chars, " ")
          end
        else
          table.insert(overlay_chars, " ")
        end
      end

      if has_content or in_art_rows then
        local overlay_text = table.concat(overlay_chars)
        pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, row, 0, {
          virt_text = { { overlay_text, "Normal" } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
  end))
end

-- Trigger the screensaver
function M.trigger()
  if state.active then
    return
  end

  -- Don't trigger in insert, visual, or command-line mode
  local mode = vim.api.nvim_get_mode().mode
  if mode:match("[icvtV\x16]") then
    reset_idle_timer()
    return
  end

  -- Get random art
  local art = content.get_art()
  if not art then
    reset_idle_timer()
    return
  end

  state.prev_win = vim.api.nvim_get_current_win()

  -- Calculate dimensions
  local width = vim.o.columns
  local height = vim.o.lines
  state.screen_width = width
  state.screen_height = height

  local art_lines = art.lines or {}
  state.art_lines = art_lines

  -- Resolve display mode
  local display_mode = resolve_display_mode()
  state.display_mode = display_mode

  -- Build buffer content based on display mode
  local lines, top_pad, art_height

  if display_mode == "tile" then
    lines = tile_art(art_lines, width, height)
    top_pad = 0
    art_height = height  -- entire screen is art
  elseif display_mode == "zoom" then
    local zoomed = zoom_art(art_lines)
    lines, top_pad, art_height = build_centered_buffer(zoomed, width, height)
  else
    -- static, bounce, marquee, pulse, waves, rain, shatter, fireworks, heartbeat: start with centered art
    lines, top_pad, art_height = build_centered_buffer(art_lines, width, height)
  end

  -- Create scratch buffer
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)

  -- Open full-screen floating window
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = 0,
    col = 0,
    style = "minimal",
    border = "none",
    zindex = 100,
  })

  -- Temporarily override animation settings for screensaver
  local ss_opts = config.options.screensaver or {}
  local ss_effect = ss_opts.effect or "random"
  state.original_effect = config.options.animation.effect
  state.original_loop = config.options.animation.loop

  config.options.animation.effect = ss_effect

  -- Determine loop and on_complete based on display mode
  local on_complete = nil

  if display_mode == "bounce" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_bounce(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "marquee" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_marquee(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "pulse" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_pulse(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "waves" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_waves(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "rain" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_rain(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "shatter" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_shatter(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "fireworks" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_fireworks(state.buf, art_lines, width, height)
      end
    end
  elseif display_mode == "heartbeat" then
    config.options.animation.loop = false
    on_complete = function()
      if state.active and state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        start_heartbeat(state.buf, art_lines, width, height)
      end
    end
  else
    -- static, tile, zoom: loop the animation
    config.options.animation.loop = true
  end

  -- Start animation (total lines = top_pad + art_height)
  local total_anim_lines = top_pad + art_height
  vim.defer_fn(function()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      animation.start(state.buf, total_anim_lines, "Normal", on_complete)
    end
  end, 10)

  -- Start audio-reactive mode if enabled
  if ss_opts.audio_reactive then
    -- Save originals before modifying
    state.original_loop_delay = config.options.animation.loop_delay
    state.original_ambient_interval = config.options.animation.ambient_interval

    if audio.start() then
      -- For looping modes (static/tile/zoom): modulate loop_delay based on audio level
      if display_mode == "static" or display_mode == "tile" or display_mode == "zoom" then
        state.audio_modulator = vim.uv.new_timer()
        state.audio_modulator:start(200, 200, vim.schedule_wrap(function()
          if not state.active or not audio.is_running() then
            return
          end
          local level = audio.get_level()
          -- Map level to loop_delay: 2000ms (silence) → 200ms (loud)
          local base = state.original_loop_delay or 2000
          local min_delay = 200
          config.options.animation.loop_delay = math.floor(base - (base - min_delay) * level)
        end))
      end
    end
  end

  -- Setup dismiss keybindings
  setup_dismiss_keys(state.buf)

  -- Handle VimResized: dismiss and re-trigger
  state.resize_autocmd = vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = function()
      M.dismiss()
      vim.defer_fn(function()
        M.trigger()
      end, 100)
    end,
  })

  state.active = true
end

-- Dismiss the screensaver
function M.dismiss()
  if not state.active then
    return
  end

  animation.stop()

  -- Stop audio sampling and modulator
  audio.stop()
  if state.audio_modulator then
    state.audio_modulator:stop()
    state.audio_modulator:close()
    state.audio_modulator = nil
  end

  -- Restore audio-modified settings
  if state.original_loop_delay ~= nil then
    config.options.animation.loop_delay = state.original_loop_delay
    state.original_loop_delay = nil
  end
  if state.original_ambient_interval ~= nil then
    config.options.animation.ambient_interval = state.original_ambient_interval
    state.original_ambient_interval = nil
  end

  -- Stop movement timer
  if state.movement_timer then
    state.movement_timer:stop()
    state.movement_timer:close()
    state.movement_timer = nil
  end

  -- Restore original animation settings
  if state.original_effect ~= nil then
    config.options.animation.effect = state.original_effect
    state.original_effect = nil
  end
  if state.original_loop ~= nil then
    config.options.animation.loop = state.original_loop
    state.original_loop = nil
  end

  -- Clean up resize autocmd
  if state.resize_autocmd then
    pcall(vim.api.nvim_del_autocmd, state.resize_autocmd)
    state.resize_autocmd = nil
  end

  -- Close window
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end

  -- Delete buffer
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end

  state.win = nil
  state.buf = nil
  state.active = false
  state.art_lines = nil
  state.screen_width = nil
  state.screen_height = nil
  state.display_mode = nil

  -- Restore previous window focus
  if state.prev_win and vim.api.nvim_win_is_valid(state.prev_win) then
    pcall(vim.api.nvim_set_current_win, state.prev_win)
  end
  state.prev_win = nil

  reset_idle_timer()
end

-- Setup screensaver (called from init.lua)
function M.setup()
  state.augroup = vim.api.nvim_create_augroup("AsciiScreensaver", { clear = true })

  -- Register activity autocmds
  local events = { "CursorMoved", "CursorMovedI", "ModeChanged", "InsertCharPre", "TextChanged", "TextChangedI", "BufEnter" }
  vim.api.nvim_create_autocmd(events, {
    group = state.augroup,
    callback = function()
      reset_idle_timer()
    end,
  })

  -- Start initial idle timer
  reset_idle_timer()
end

-- Enable screensaver
function M.enable()
  state.enabled = true
  -- Setup if augroup doesn't exist yet
  if not state.augroup then
    M.setup()
  else
    reset_idle_timer()
  end
end

-- Restart idle timer (called from settings panel when timeout changes)
function M.restart_timer()
  if state.enabled then
    reset_idle_timer()
  end
end

-- Disable screensaver
function M.disable()
  state.enabled = false
  if state.active then
    M.dismiss()
  end
  if state.idle_timer then
    state.idle_timer:stop()
    state.idle_timer:close()
    state.idle_timer = nil
  end
end

return M
