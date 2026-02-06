-- Screensaver mode: full-screen animated ASCII art after idle timeout

local config = require("ascii-animation.config")
local animation = require("ascii-animation.animation")
local content = require("ascii-animation.content")

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

    -- Update position
    pos_x = pos_x + vel_x
    pos_y = pos_y + vel_y

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

    -- Move left
    pos_x = pos_x - 1

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
    -- static, bounce, marquee: start with centered art
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
