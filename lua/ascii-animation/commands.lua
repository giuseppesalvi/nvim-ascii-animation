-- User commands for ascii-animation
-- Provides :AsciiPreview, :AsciiList, :AsciiStats, :AsciiRefresh

local config = require("ascii-animation.config")
local animation = require("ascii-animation.animation")
local content = require("ascii-animation.content")
local time = require("ascii-animation.time")

local M = {}

-- State for preview window
local preview_state = {
  buf = nil,
  win = nil,
  arts = {},      -- List of all arts for browsing
  index = 1,      -- Current index in arts list
  filter = nil,   -- Current period filter (or "favorites")
}

-- Close preview window if open
local function close_preview()
  animation.stop()
  if preview_state.win and vim.api.nvim_win_is_valid(preview_state.win) then
    vim.api.nvim_win_close(preview_state.win, true)
  end
  if preview_state.buf and vim.api.nvim_buf_is_valid(preview_state.buf) then
    vim.api.nvim_buf_delete(preview_state.buf, { force = true })
  end
  preview_state.win = nil
  preview_state.buf = nil
end

-- Get filtered arts list
local function get_arts_list(filter)
  local arts = {}
  local ids

  if filter == "favorites" then
    -- Return only favorited arts
    for _, id in ipairs(config.favorites) do
      local art = content.get_art_by_id(id)
      if art then
        table.insert(arts, art)
      end
    end
    return arts
  elseif filter then
    ids = content.list_arts_for_period(filter)
  else
    ids = content.list_arts()
  end

  for _, id in ipairs(ids) do
    local art = content.get_art_by_id(id)
    if art then
      table.insert(arts, art)
    end
  end
  return arts
end

-- Update preview window content
local function update_preview_content()
  if not preview_state.buf or not vim.api.nvim_buf_is_valid(preview_state.buf) then
    return
  end

  local art = preview_state.arts[preview_state.index]
  if not art then return end

  local is_fav = config.is_favorite(art.id)
  local fav_icon = is_fav and " ★" or ""

  -- Build content
  local lines = {}
  table.insert(lines, "")
  for _, line in ipairs(art.lines) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "")
  table.insert(lines, string.format("  ID: %s%s", art.id, fav_icon))
  table.insert(lines, string.format("  %d / %d%s",
    preview_state.index,
    #preview_state.arts,
    preview_state.filter and (" [" .. preview_state.filter .. "]") or " [all]"
  ))
  table.insert(lines, "")
  table.insert(lines, "  n/p: next/prev  │  1-5: filter  │  0: all  │  f: fav  │  F: favs only")
  table.insert(lines, "  r: replay  │  q: quit")

  -- Update buffer
  vim.bo[preview_state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(preview_state.buf, 0, -1, false, lines)
  vim.bo[preview_state.buf].modifiable = false

  -- Update window title
  if preview_state.win and vim.api.nvim_win_is_valid(preview_state.win) then
    vim.api.nvim_win_set_config(preview_state.win, {
      title = " " .. (art.name or art.id) .. " ",
      title_pos = "center",
    })
  end

  -- Resize window if needed
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 4, math.floor(vim.o.columns * 0.9))
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.8))

  if preview_state.win and vim.api.nvim_win_is_valid(preview_state.win) then
    vim.api.nvim_win_set_config(preview_state.win, {
      width = width,
      height = height,
    })
  end

  -- Run animation
  vim.defer_fn(function()
    if preview_state.buf and vim.api.nvim_buf_is_valid(preview_state.buf) then
      animation.stop()
      animation.start(preview_state.buf, #art.lines + 1, "Normal")
    end
  end, 50)
end

-- Navigate to next/previous art
local function navigate_preview(delta)
  local new_index = preview_state.index + delta
  if new_index < 1 then
    new_index = #preview_state.arts
  elseif new_index > #preview_state.arts then
    new_index = 1
  end
  preview_state.index = new_index
  update_preview_content()
end

-- Set period filter
local function set_filter(filter)
  preview_state.filter = filter
  preview_state.arts = get_arts_list(filter)
  preview_state.index = 1
  update_preview_content()
end

-- Toggle favorite for current art
local function toggle_favorite()
  local art = preview_state.arts[preview_state.index]
  if not art then return end
  local added = config.toggle_favorite(art.id)
  vim.notify(added and "Added to favorites" or "Removed from favorites", vim.log.levels.INFO)
  update_preview_content()
end

-- Create interactive preview window
local function create_preview_window(art)
  close_preview()

  local is_fav = config.is_favorite(art.id)
  local fav_icon = is_fav and " ★" or ""

  -- Build initial content
  local lines = {}
  table.insert(lines, "")
  for _, line in ipairs(art.lines) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "")
  table.insert(lines, string.format("  ID: %s%s", art.id, fav_icon))
  table.insert(lines, string.format("  %d / %d%s",
    preview_state.index,
    #preview_state.arts,
    preview_state.filter and (" [" .. preview_state.filter .. "]") or " [all]"
  ))
  table.insert(lines, "")
  table.insert(lines, "  n/p: next/prev  │  1-5: filter  │  0: all  │  f: fav  │  F: favs only")
  table.insert(lines, "  r: replay  │  q: quit")

  -- Calculate window dimensions
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 4, math.floor(vim.o.columns * 0.9))
  local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.8))

  -- Center the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. (art.name or art.id) .. " ",
    title_pos = "center",
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  preview_state.buf = buf
  preview_state.win = win

  -- Keybindings
  local keymaps = {
    { "q", close_preview },
    { "<Esc>", close_preview },
    { "n", function() navigate_preview(1) end },
    { "p", function() navigate_preview(-1) end },
    { "j", function() navigate_preview(1) end },
    { "k", function() navigate_preview(-1) end },
    { "<Tab>", function() navigate_preview(1) end },
    { "<S-Tab>", function() navigate_preview(-1) end },
    { "r", update_preview_content },
    { "0", function() set_filter(nil) end },
    { "1", function() set_filter("morning") end },
    { "2", function() set_filter("afternoon") end },
    { "3", function() set_filter("evening") end },
    { "4", function() set_filter("night") end },
    { "5", function() set_filter("weekend") end },
    { "f", toggle_favorite },
    { "F", function()
      if #config.favorites == 0 then
        vim.notify("No favorites yet", vim.log.levels.WARN)
        return
      end
      set_filter("favorites")
    end },
  }

  for _, map in ipairs(keymaps) do
    vim.keymap.set("n", map[1], map[2], { buffer = buf, nowait = true, silent = true })
  end

  -- Run animation
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(buf) then
      animation.start(buf, #art.lines + 1, "Normal")
    end
  end, 50)

  return buf, win
end

-- Preview an ASCII art in a floating window (interactive browser)
function M.preview(name)
  -- Initialize arts list
  preview_state.filter = nil
  preview_state.arts = get_arts_list(nil)
  preview_state.index = 1

  local art
  if name and name ~= "" then
    -- Find the art and set index
    for i, a in ipairs(preview_state.arts) do
      if a.id == name or a.id:find(name, 1, true) then
        art = a
        preview_state.index = i
        break
      end
    end
    if not art then
      vim.notify("Art not found: " .. name, vim.log.levels.WARN)
      return
    end
  else
    -- Random art for current period
    local period = time.get_current_period()
    preview_state.filter = period
    preview_state.arts = get_arts_list(period)
    preview_state.index = math.random(1, #preview_state.arts)
    art = preview_state.arts[preview_state.index]
  end

  if not art or not art.lines then
    vim.notify("No art available", vim.log.levels.WARN)
    return
  end

  create_preview_window(art)
end

-- List all available ASCII arts
function M.list()
  -- Check for telescope
  local has_telescope = pcall(require, "telescope.pickers")
  if has_telescope then
    M._list_telescope()
    return
  end

  -- Fallback: use preview browser
  M.preview()
end

-- Telescope picker for arts (if available)
function M._list_telescope()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  local entries = {}
  local all_ids = content.list_arts()

  for _, id in ipairs(all_ids) do
    local art = content.get_art_by_id(id)
    if art then
      table.insert(entries, {
        id = id,
        name = art.name or id,
        lines = art.lines,
        display = string.format("%s - %s", id, art.name or ""),
      })
    end
  end

  pickers.new({}, {
    prompt_title = "ASCII Arts",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      title = "Preview",
      define_preview = function(self, entry)
        local art = entry.value
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, art.lines)
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          M.preview(selection.value.id)
        end
      end)
      return true
    end,
  }):find()
end

-- State for settings window (enhanced with preview)
local settings_state = {
  settings_buf = nil,
  settings_win = nil,
  preview_buf = nil,
  preview_win = nil,
  current_art = nil,
  submenu = nil,  -- nil | "wave" | "glitch" | "scramble" | "spiral" | "fade" | "timing"
}

-- Close settings windows (both panels)
local function close_settings()
  animation.stop()
  if settings_state.settings_win and vim.api.nvim_win_is_valid(settings_state.settings_win) then
    vim.api.nvim_win_close(settings_state.settings_win, true)
  end
  if settings_state.preview_win and vim.api.nvim_win_is_valid(settings_state.preview_win) then
    vim.api.nvim_win_close(settings_state.preview_win, true)
  end
  if settings_state.settings_buf and vim.api.nvim_buf_is_valid(settings_state.settings_buf) then
    vim.api.nvim_buf_delete(settings_state.settings_buf, { force = true })
  end
  if settings_state.preview_buf and vim.api.nvim_buf_is_valid(settings_state.preview_buf) then
    vim.api.nvim_buf_delete(settings_state.preview_buf, { force = true })
  end
  settings_state.settings_win = nil
  settings_state.settings_buf = nil
  settings_state.preview_win = nil
  settings_state.preview_buf = nil
  settings_state.submenu = nil
end

-- Get effect-specific options submenu lines
local function get_effect_submenu_lines(effect)
  local opts = config.options.animation.effect_options or {}
  local lines = {}

  if effect == "wave" then
    local origins = { "center", "top", "bottom", "left", "right", "top-left", "top-right", "bottom-left", "bottom-right" }
    local origin_idx = 1
    for i, o in ipairs(origins) do
      if o == opts.origin then origin_idx = i break end
    end
    lines = {
      "",
      "  Wave Effect Options",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [o] Origin:  %-12s  ◀ %d/%d ▶", opts.origin or "center", origin_idx, #origins),
      string.format("  [s] Speed:   %.1fx             ◀/▶ ±0.1", opts.speed or 1.0),
      "",
      "  Keys: o/s: cycle/adjust  Backspace: back",
      "",
    }
  elseif effect == "glitch" then
    local glitch = opts.glitch or {}
    lines = {
      "",
      "  Glitch Effect Options",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [i] Intensity:     %.1f        ◀/▶ ±0.1", glitch.intensity or 0.5),
      string.format("  [b] Block chance:  %.1f        ◀/▶ ±0.1", glitch.block_chance or 0.2),
      string.format("  [s] Block size:    %d          ◀/▶ ±1", glitch.block_size or 5),
      string.format("  [r] Resolve speed: %.1f        ◀/▶ ±0.1", glitch.resolve_speed or 1.0),
      "",
      "  Keys: adjust with key  Backspace: back",
      "",
    }
  elseif effect == "scramble" then
    local staggers = { "left", "right", "center", "random" }
    local stagger_idx = 1
    for i, s in ipairs(staggers) do
      if s == opts.stagger then stagger_idx = i break end
    end
    lines = {
      "",
      "  Scramble Effect Options",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [s] Stagger: %-8s       ◀ %d/%d ▶", opts.stagger or "left", stagger_idx, #staggers),
      string.format("  [c] Cycles:  %d              ◀/▶ ±1", opts.cycles or 5),
      "",
      "  Keys: s/c: cycle/adjust  Backspace: back",
      "",
    }
  elseif effect == "spiral" then
    local directions = { "outward", "inward" }
    local dir_idx = opts.direction == "inward" and 2 or 1
    local rotations = { "clockwise", "counter" }
    local rot_idx = opts.rotation == "counter" and 2 or 1
    lines = {
      "",
      "  Spiral Effect Options",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [d] Direction: %-10s   ◀ %d/%d ▶", opts.direction or "outward", dir_idx, #directions),
      string.format("  [r] Rotation:  %-10s   ◀ %d/%d ▶", opts.rotation or "clockwise", rot_idx, #rotations),
      string.format("  [t] Tightness: %.1f           ◀/▶ ±0.1", opts.tightness or 1.0),
      "",
      "  Keys: d/r/t: cycle/adjust  Backspace: back",
      "",
    }
  elseif effect == "fade" then
    lines = {
      "",
      "  Fade Effect Options",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [h] Highlight levels: %d     ◀/▶ ±1", opts.highlight_count or 10),
      "",
      "  More levels = smoother fade (5-20)",
      "",
      "  Keys: h: adjust  Backspace: back",
      "",
    }
  end

  return lines
end

-- Get timing submenu lines
local function get_timing_submenu_lines()
  local opts = config.options.animation
  return {
    "",
    "  Animation Timing",
    "  " .. string.rep("─", 38),
    "",
    string.format("  [m] Min delay:       %dms      ◀/▶ ±10", opts.min_delay),
    string.format("  [M] Max delay:       %dms     ◀/▶ ±10", opts.max_delay),
    string.format("  [d] Loop delay:      %dms   ◀/▶ ±100", opts.loop_delay),
    string.format("  [v] Loop reverse:    %s", opts.loop_reverse and "ON " or "OFF"),
    string.format("  [i] Ambient interval: %dms  ◀/▶ ±100", opts.ambient_interval),
    "",
    "  Keys: adjust with key  Backspace: back",
    "",
  }
end

-- All available styles
local ALL_STYLES = { "blocks", "gradient", "isometric", "box", "minimal", "pixel", "braille" }

-- Check if a style is enabled
local function is_style_enabled(style)
  local styles = config.options.content.styles
  if styles == nil then
    return true  -- nil means all styles enabled
  end
  for _, s in ipairs(styles) do
    if s == style then
      return true
    end
  end
  return false
end

-- Toggle a style on/off
local function toggle_style(style)
  local styles = config.options.content.styles

  -- If nil (all enabled), create list with all styles then remove this one
  if styles == nil then
    styles = {}
    for _, s in ipairs(ALL_STYLES) do
      if s ~= style then
        table.insert(styles, s)
      end
    end
    config.options.content.styles = styles
  else
    -- Check if style is in the list
    local found_idx = nil
    for i, s in ipairs(styles) do
      if s == style then
        found_idx = i
        break
      end
    end

    if found_idx then
      -- Remove it (disable)
      table.remove(styles, found_idx)
      -- If all styles would be disabled, keep at least one
      if #styles == 0 then
        vim.notify("At least one style must be enabled", vim.log.levels.WARN)
        table.insert(styles, style)
        return
      end
    else
      -- Add it (enable)
      table.insert(styles, style)
    end

    -- If all styles are now enabled, set to nil
    if #styles == #ALL_STYLES then
      config.options.content.styles = nil
    else
      config.options.content.styles = styles
    end
  end

  config.save()
end

-- Get count of enabled styles
local function get_enabled_styles_count()
  local styles = config.options.content.styles
  if styles == nil then
    return #ALL_STYLES
  end
  return #styles
end

-- Get styles submenu lines
local function get_styles_submenu_lines()
  local lines = {
    "",
    "  Art Styles Filter",
    "  " .. string.rep("─", 38),
    "",
  }

  for i, style in ipairs(ALL_STYLES) do
    local enabled = is_style_enabled(style)
    local checkbox = enabled and "[x]" or "[ ]"
    table.insert(lines, string.format("  [%d] %s %-12s", i, checkbox, style))
  end

  table.insert(lines, "")
  table.insert(lines, string.format("  %d/%d styles enabled", get_enabled_styles_count(), #ALL_STYLES))
  table.insert(lines, "")
  table.insert(lines, "  Keys: 1-7: toggle  Backspace: back")
  table.insert(lines, "")

  return lines
end

-- Check if effect has options submenu
local function effect_has_options(effect)
  return effect == "wave" or effect == "glitch" or effect == "scramble" or effect == "spiral" or effect == "fade"
end

-- Update settings panel content
local function update_settings_content()
  if not settings_state.settings_buf or not vim.api.nvim_buf_is_valid(settings_state.settings_buf) then
    return
  end

  local opts = config.options
  local effect = opts.animation.effect
  local lines

  -- Show submenu if active
  if settings_state.submenu then
    if settings_state.submenu == "timing" then
      lines = get_timing_submenu_lines()
    elseif settings_state.submenu == "styles" then
      lines = get_styles_submenu_lines()
    else
      lines = get_effect_submenu_lines(settings_state.submenu)
    end
  else
    -- Main settings view
    local all_arts = content.list_arts()
    local art_count = #all_arts
    local fav_count = #config.favorites

    -- Effect options for display
    local effects = { "chaos", "typewriter", "diagonal", "lines", "matrix", "wave", "fade", "scramble", "rain", "spiral", "explode", "implode", "glitch", "random" }
    local effect_idx = 1
    for i, e in ipairs(effects) do
      if e == effect then effect_idx = i break end
    end

    -- Ambient options
    local ambients = { "none", "glitch", "shimmer" }
    local ambient_idx = 1
    for i, a in ipairs(ambients) do
      if a == opts.animation.ambient then ambient_idx = i break end
    end

    -- Random mode options
    local random_modes = { "always", "daily", "session" }
    local random_idx = 1
    for i, m in ipairs(random_modes) do
      if m == opts.selection.random_mode then random_idx = i break end
    end

    -- Build options indicator
    local has_opts = effect_has_options(effect)
    local opts_hint = has_opts and "  [o] Options..." or ""

    local styles_count = get_enabled_styles_count()
    local styles_label = styles_count == #ALL_STYLES and "all" or tostring(styles_count)

    lines = {
      "",
      "  Animation Settings",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [e] Effect:   %-10s ◀ %d/%d ▶", effect, effect_idx, #effects),
      opts_hint,
      string.format("  [a] Ambient:  %-10s ◀ %d/%d ▶", opts.animation.ambient, ambient_idx, #ambients),
      string.format("  [l] Loop:     %s", opts.animation.loop and "ON " or "OFF"),
      string.format("  [s] Steps:    %d", opts.animation.steps),
      "  [t] Timing...",
      "",
      "  Selection",
      "  " .. string.rep("─", 38),
      string.format("  [m] Mode:     %-10s ◀ %d/%d ▶", opts.selection.random_mode, random_idx, #random_modes),
      string.format("  [n] No repeat: %s", opts.selection.no_repeat and "ON " or "OFF"),
      string.format("  [w] Fav weight: %d%%", config.favorites_weight),
      string.format("  [y] Styles...  (%s/%d)", styles_label, #ALL_STYLES),
      "",
      string.format("  Arts: %d (%d favs)", art_count, fav_count),
      "",
      "  [Space] Replay  [R] Reset  [q] Close",
      "",
    }

    -- Remove empty options line if effect has no options
    if not has_opts then
      local new_lines = {}
      for _, line in ipairs(lines) do
        if line ~= "" or #new_lines == 0 or new_lines[#new_lines] ~= "" then
          if line ~= opts_hint or has_opts then
            table.insert(new_lines, line)
          end
        end
      end
      lines = new_lines
    end
  end

  vim.bo[settings_state.settings_buf].modifiable = true
  vim.api.nvim_buf_set_lines(settings_state.settings_buf, 0, -1, false, lines)
  vim.bo[settings_state.settings_buf].modifiable = false
end

-- Forward declaration for replay
local replay_preview

-- Cycle through effect options
local function cycle_effect(delta)
  local effects = { "chaos", "typewriter", "diagonal", "lines", "matrix", "wave", "fade", "scramble", "rain", "spiral", "explode", "implode", "glitch", "random" }
  local current = config.options.animation.effect
  local idx = 1
  for i, e in ipairs(effects) do
    if e == current then idx = i break end
  end
  idx = idx + delta
  if idx < 1 then idx = #effects
  elseif idx > #effects then idx = 1 end
  config.options.animation.effect = effects[idx]
  config.save()
  update_settings_content()
  replay_preview()
end

-- Cycle through ambient options
local function cycle_ambient(delta)
  local ambients = { "none", "glitch", "shimmer" }
  local current = config.options.animation.ambient
  local idx = 1
  for i, a in ipairs(ambients) do
    if a == current then idx = i break end
  end
  idx = idx + delta
  if idx < 1 then idx = #ambients
  elseif idx > #ambients then idx = 1 end
  config.options.animation.ambient = ambients[idx]
  config.save()
  update_settings_content()
end

-- Toggle loop
local function toggle_loop()
  config.options.animation.loop = not config.options.animation.loop
  config.save()
  update_settings_content()
  replay_preview()
end

-- Adjust steps
local function adjust_steps(delta)
  local new_steps = config.options.animation.steps + delta
  if new_steps >= 10 and new_steps <= 100 then
    config.options.animation.steps = new_steps
    config.save()
    update_settings_content()
    replay_preview()
  end
end

-- Cycle through random mode options
local function cycle_random_mode(delta)
  local modes = { "always", "daily", "session" }
  local current = config.options.selection.random_mode
  local idx = 1
  for i, m in ipairs(modes) do
    if m == current then idx = i break end
  end
  idx = idx + delta
  if idx < 1 then idx = #modes
  elseif idx > #modes then idx = 1 end
  config.options.selection.random_mode = modes[idx]
  config.save()
  update_settings_content()
end

-- Toggle no-repeat
local function toggle_no_repeat()
  config.options.selection.no_repeat = not config.options.selection.no_repeat
  config.save()
  update_settings_content()
end

-- Adjust favorites weight
local function adjust_fav_weight(delta)
  local new_weight = config.favorites_weight + delta
  if new_weight >= 0 and new_weight <= 100 then
    config.favorites_weight = new_weight
    config.save()
    update_settings_content()
  end
end

-- Open effect options submenu
local function open_effect_options()
  local effect = config.options.animation.effect
  if effect_has_options(effect) then
    settings_state.submenu = effect
    update_settings_content()
  end
end

-- Open timing submenu
local function open_timing_submenu()
  settings_state.submenu = "timing"
  update_settings_content()
end

-- Close submenu (go back)
local function close_submenu()
  settings_state.submenu = nil
  update_settings_content()
end

-- Wave options adjusters
local function cycle_wave_origin(delta)
  local origins = { "center", "top", "bottom", "left", "right", "top-left", "top-right", "bottom-left", "bottom-right" }
  local opts = config.options.animation.effect_options
  local idx = 1
  for i, o in ipairs(origins) do
    if o == opts.origin then idx = i break end
  end
  idx = idx + delta
  if idx < 1 then idx = #origins
  elseif idx > #origins then idx = 1 end
  opts.origin = origins[idx]
  config.save()
  update_settings_content()
  replay_preview()
end

local function adjust_wave_speed(delta)
  local opts = config.options.animation.effect_options
  local new_speed = (opts.speed or 1.0) + delta
  if new_speed >= 0.1 and new_speed <= 3.0 then
    opts.speed = math.floor(new_speed * 10 + 0.5) / 10  -- Round to 1 decimal
    config.save()
    update_settings_content()
    replay_preview()
  end
end

-- Glitch options adjusters
local function adjust_glitch_intensity(delta)
  local glitch = config.options.animation.effect_options.glitch
  local new_val = (glitch.intensity or 0.5) + delta
  if new_val >= 0.1 and new_val <= 1.0 then
    glitch.intensity = math.floor(new_val * 10 + 0.5) / 10
    config.save()
    update_settings_content()
    replay_preview()
  end
end

local function adjust_glitch_block_chance(delta)
  local glitch = config.options.animation.effect_options.glitch
  local new_val = (glitch.block_chance or 0.2) + delta
  if new_val >= 0 and new_val <= 1.0 then
    glitch.block_chance = math.floor(new_val * 10 + 0.5) / 10
    config.save()
    update_settings_content()
    replay_preview()
  end
end

local function adjust_glitch_block_size(delta)
  local glitch = config.options.animation.effect_options.glitch
  local new_val = (glitch.block_size or 5) + delta
  if new_val >= 1 and new_val <= 20 then
    glitch.block_size = new_val
    config.save()
    update_settings_content()
    replay_preview()
  end
end

local function adjust_glitch_resolve_speed(delta)
  local glitch = config.options.animation.effect_options.glitch
  local new_val = (glitch.resolve_speed or 1.0) + delta
  if new_val >= 0.1 and new_val <= 3.0 then
    glitch.resolve_speed = math.floor(new_val * 10 + 0.5) / 10
    config.save()
    update_settings_content()
    replay_preview()
  end
end

-- Scramble options adjusters
local function cycle_scramble_stagger(delta)
  local staggers = { "left", "right", "center", "random" }
  local opts = config.options.animation.effect_options
  local idx = 1
  for i, s in ipairs(staggers) do
    if s == opts.stagger then idx = i break end
  end
  idx = idx + delta
  if idx < 1 then idx = #staggers
  elseif idx > #staggers then idx = 1 end
  opts.stagger = staggers[idx]
  config.save()
  update_settings_content()
  replay_preview()
end

local function adjust_scramble_cycles(delta)
  local opts = config.options.animation.effect_options
  local new_val = (opts.cycles or 5) + delta
  if new_val >= 1 and new_val <= 20 then
    opts.cycles = new_val
    config.save()
    update_settings_content()
    replay_preview()
  end
end

-- Spiral options adjusters
local function cycle_spiral_direction(delta)
  local directions = { "outward", "inward" }
  local opts = config.options.animation.effect_options
  local idx = opts.direction == "inward" and 2 or 1
  idx = idx + delta
  if idx < 1 then idx = #directions
  elseif idx > #directions then idx = 1 end
  opts.direction = directions[idx]
  config.save()
  update_settings_content()
  replay_preview()
end

local function cycle_spiral_rotation(delta)
  local rotations = { "clockwise", "counter" }
  local opts = config.options.animation.effect_options
  local idx = opts.rotation == "counter" and 2 or 1
  idx = idx + delta
  if idx < 1 then idx = #rotations
  elseif idx > #rotations then idx = 1 end
  opts.rotation = rotations[idx]
  config.save()
  update_settings_content()
  replay_preview()
end

local function adjust_spiral_tightness(delta)
  local opts = config.options.animation.effect_options
  local new_val = (opts.tightness or 1.0) + delta
  if new_val >= 0.5 and new_val <= 2.0 then
    opts.tightness = math.floor(new_val * 10 + 0.5) / 10
    config.save()
    update_settings_content()
    replay_preview()
  end
end

-- Fade options adjusters
local function adjust_fade_highlight_count(delta)
  local opts = config.options.animation.effect_options
  local new_val = (opts.highlight_count or 10) + delta
  if new_val >= 5 and new_val <= 20 then
    opts.highlight_count = new_val
    config.save()
    update_settings_content()
    replay_preview()
  end
end

-- Timing adjusters
local function adjust_min_delay(delta)
  local opts = config.options.animation
  local new_val = opts.min_delay + delta
  if new_val >= 10 and new_val <= opts.max_delay - 10 then
    opts.min_delay = new_val
    config.save()
    update_settings_content()
    replay_preview()
  end
end

local function adjust_max_delay(delta)
  local opts = config.options.animation
  local new_val = opts.max_delay + delta
  if new_val >= opts.min_delay + 10 and new_val <= 500 then
    opts.max_delay = new_val
    config.save()
    update_settings_content()
    replay_preview()
  end
end

local function adjust_loop_delay(delta)
  local opts = config.options.animation
  local new_val = opts.loop_delay + delta
  if new_val >= 500 and new_val <= 10000 then
    opts.loop_delay = new_val
    config.save()
    update_settings_content()
  end
end

local function toggle_loop_reverse()
  config.options.animation.loop_reverse = not config.options.animation.loop_reverse
  config.save()
  update_settings_content()
end

local function adjust_ambient_interval(delta)
  local opts = config.options.animation
  local new_val = opts.ambient_interval + delta
  if new_val >= 500 and new_val <= 10000 then
    opts.ambient_interval = new_val
    config.save()
    update_settings_content()
  end
end

-- Reset to config defaults
local function reset_to_defaults()
  config.clear_saved()
  vim.notify("Settings reset to defaults", vim.log.levels.INFO)
  update_settings_content()
  replay_preview()
end

-- Update preview buffer content
local function update_preview_buffer()
  if not settings_state.preview_buf or not vim.api.nvim_buf_is_valid(settings_state.preview_buf) then
    return
  end

  local art = settings_state.current_art
  if not art or not art.lines then return end

  -- Build content with padding
  local lines = { "" }
  for _, line in ipairs(art.lines) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "")
  table.insert(lines, string.format("  %s", art.name or art.id))
  table.insert(lines, "")

  vim.bo[settings_state.preview_buf].modifiable = true
  vim.api.nvim_buf_set_lines(settings_state.preview_buf, 0, -1, false, lines)
  vim.bo[settings_state.preview_buf].modifiable = false
end

-- Replay preview animation (implements forward declaration)
replay_preview = function()
  if not settings_state.preview_buf or not vim.api.nvim_buf_is_valid(settings_state.preview_buf) then
    return
  end

  local art = settings_state.current_art
  if not art then return end

  animation.stop()
  update_preview_buffer()

  vim.defer_fn(function()
    if settings_state.preview_buf and vim.api.nvim_buf_is_valid(settings_state.preview_buf) then
      animation.start(settings_state.preview_buf, #art.lines + 1, "Normal")
    end
  end, 50)
end

-- Setup keybindings for settings buffer
local function setup_settings_keybindings(buf)
  -- Common keybindings
  local common_keymaps = {
    { "q", close_settings },
    { "<Esc>", close_settings },
    { "<Space>", replay_preview },
    { "R", reset_to_defaults },
  }

  for _, map in ipairs(common_keymaps) do
    vim.keymap.set("n", map[1], map[2], { buffer = buf, nowait = true, silent = true })
  end

  -- Context-aware keybindings
  -- Main menu keys
  vim.keymap.set("n", "e", function()
    if not settings_state.submenu then
      cycle_effect(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "E", function()
    if not settings_state.submenu then
      cycle_effect(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "a", function()
    if not settings_state.submenu then
      cycle_ambient(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "A", function()
    if not settings_state.submenu then
      cycle_ambient(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "l", function()
    if not settings_state.submenu then
      toggle_loop()
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "s", function()
    if not settings_state.submenu then
      adjust_steps(5)
    elseif settings_state.submenu == "wave" then
      adjust_wave_speed(0.1)
    elseif settings_state.submenu == "glitch" then
      adjust_glitch_block_size(1)
    elseif settings_state.submenu == "scramble" then
      cycle_scramble_stagger(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "S", function()
    if not settings_state.submenu then
      adjust_steps(-5)
    elseif settings_state.submenu == "wave" then
      adjust_wave_speed(-0.1)
    elseif settings_state.submenu == "glitch" then
      adjust_glitch_block_size(-1)
    elseif settings_state.submenu == "scramble" then
      cycle_scramble_stagger(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "m", function()
    if not settings_state.submenu then
      cycle_random_mode(1)
    elseif settings_state.submenu == "timing" then
      adjust_min_delay(10)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "M", function()
    if not settings_state.submenu then
      cycle_random_mode(-1)
    elseif settings_state.submenu == "timing" then
      adjust_min_delay(-10)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "n", function()
    if not settings_state.submenu then
      toggle_no_repeat()
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "w", function()
    if not settings_state.submenu then
      adjust_fav_weight(10)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "W", function()
    if not settings_state.submenu then
      adjust_fav_weight(-10)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "o", function()
    if not settings_state.submenu then
      open_effect_options()
    elseif settings_state.submenu == "wave" then
      cycle_wave_origin(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "O", function()
    if settings_state.submenu == "wave" then
      cycle_wave_origin(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "t", function()
    if not settings_state.submenu then
      open_timing_submenu()
    elseif settings_state.submenu == "spiral" then
      adjust_spiral_tightness(0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "T", function()
    if settings_state.submenu == "spiral" then
      adjust_spiral_tightness(-0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Backspace to go back from submenu
  vim.keymap.set("n", "<BS>", function()
    if settings_state.submenu then
      close_submenu()
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Glitch-specific keys
  vim.keymap.set("n", "i", function()
    if settings_state.submenu == "glitch" then
      adjust_glitch_intensity(0.1)
    elseif settings_state.submenu == "timing" then
      adjust_ambient_interval(100)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "I", function()
    if settings_state.submenu == "glitch" then
      adjust_glitch_intensity(-0.1)
    elseif settings_state.submenu == "timing" then
      adjust_ambient_interval(-100)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "b", function()
    if settings_state.submenu == "glitch" then
      adjust_glitch_block_chance(0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "B", function()
    if settings_state.submenu == "glitch" then
      adjust_glitch_block_chance(-0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "r", function()
    if settings_state.submenu == "glitch" then
      adjust_glitch_resolve_speed(0.1)
    elseif settings_state.submenu == "spiral" then
      cycle_spiral_rotation(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Scramble-specific keys
  vim.keymap.set("n", "c", function()
    if settings_state.submenu == "scramble" then
      adjust_scramble_cycles(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "C", function()
    if settings_state.submenu == "scramble" then
      adjust_scramble_cycles(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Spiral-specific keys
  vim.keymap.set("n", "d", function()
    if settings_state.submenu == "spiral" then
      cycle_spiral_direction(1)
    elseif settings_state.submenu == "timing" then
      adjust_loop_delay(100)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "D", function()
    if settings_state.submenu == "spiral" then
      cycle_spiral_direction(-1)
    elseif settings_state.submenu == "timing" then
      adjust_loop_delay(-100)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Fade-specific keys
  vim.keymap.set("n", "h", function()
    if settings_state.submenu == "fade" then
      adjust_fade_highlight_count(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "H", function()
    if settings_state.submenu == "fade" then
      adjust_fade_highlight_count(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Timing-specific keys
  vim.keymap.set("n", "x", function()
    if settings_state.submenu == "timing" then
      adjust_max_delay(10)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "X", function()
    if settings_state.submenu == "timing" then
      adjust_max_delay(-10)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "v", function()
    if settings_state.submenu == "timing" then
      toggle_loop_reverse()
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Styles submenu
  vim.keymap.set("n", "y", function()
    if not settings_state.submenu then
      settings_state.submenu = "styles"
      update_settings_content()
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Style toggles (1-7) - only in styles submenu
  for i, style in ipairs(ALL_STYLES) do
    vim.keymap.set("n", tostring(i), function()
      if settings_state.submenu == "styles" then
        toggle_style(style)
        update_settings_content()
        -- Pick a new random art from enabled styles for preview
        local arts = get_arts_list(nil)  -- This uses the styles filter
        if #arts > 0 then
          settings_state.current_art = arts[math.random(1, #arts)]
          replay_preview()
        end
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

-- Display interactive settings with live preview
function M.stats()
  close_settings()

  -- Get a random art for preview
  local period = time.get_current_period()
  local arts = get_arts_list(period)
  if #arts == 0 then
    arts = get_arts_list(nil)
  end
  if #arts == 0 then
    vim.notify("No arts available", vim.log.levels.WARN)
    return
  end
  settings_state.current_art = arts[math.random(1, #arts)]

  -- Calculate dimensions for side-by-side layout
  local total_width = math.min(120, math.floor(vim.o.columns * 0.9))
  local settings_width = 44
  local preview_width = total_width - settings_width - 3  -- Gap between panels

  -- Calculate art display width
  local art = settings_state.current_art
  local art_width = 0
  for _, line in ipairs(art.lines) do
    art_width = math.max(art_width, vim.fn.strdisplaywidth(line))
  end
  preview_width = math.max(preview_width, art_width + 6)

  local settings_height = 24
  local preview_height = #art.lines + 5

  local total_height = math.max(settings_height, preview_height)
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - (settings_width + preview_width + 3)) / 2)

  -- Create settings buffer
  local settings_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[settings_buf].bufhidden = "wipe"

  -- Create settings window (left panel)
  local settings_win = vim.api.nvim_open_win(settings_buf, true, {
    relative = "editor",
    width = settings_width,
    height = settings_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Settings ",
    title_pos = "center",
  })

  vim.wo[settings_win].wrap = false
  vim.wo[settings_win].cursorline = false

  settings_state.settings_buf = settings_buf
  settings_state.settings_win = settings_win

  -- Create preview buffer
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[preview_buf].bufhidden = "wipe"

  -- Create preview window (right panel)
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    width = preview_width,
    height = preview_height,
    row = row,
    col = col + settings_width + 3,
    style = "minimal",
    border = "rounded",
    title = " Live Preview ",
    title_pos = "center",
  })

  vim.wo[preview_win].wrap = false
  vim.wo[preview_win].cursorline = false

  settings_state.preview_buf = preview_buf
  settings_state.preview_win = preview_win

  -- Set up content
  update_settings_content()
  update_preview_buffer()

  -- Set up keybindings
  setup_settings_keybindings(settings_buf)

  -- Start preview animation
  vim.defer_fn(function()
    if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
      animation.start(preview_buf, #art.lines + 1, "Normal")
    end
  end, 100)
end

-- Refresh animation on current buffer
function M.refresh()
  local buf = vim.api.nvim_get_current_buf()

  -- Stop any running animation
  animation.stop()

  -- Try to detect dashboard type and use appropriate settings
  local ft = vim.bo[buf].filetype
  local highlight = "Normal"
  local header_lines = 20

  if ft == "snacks_dashboard" or ft == "dashboard" then
    highlight = ft == "snacks_dashboard" and "SnacksDashboardHeader" or "DashboardHeader"
  elseif ft == "alpha" then
    highlight = "AlphaHeader"
  elseif ft == "lazy" then
    highlight = "LazyH1"
  end

  -- Start animation
  animation.start(buf, header_lines, highlight)
end

-- Register user commands
function M.register_commands()
  vim.api.nvim_create_user_command("AsciiPreview", function(opts)
    M.preview(opts.args)
  end, {
    nargs = "?",
    complete = function(arg_lead)
      local ids = content.list_arts()
      if arg_lead == "" then
        return ids
      end
      local matches = {}
      for _, id in ipairs(ids) do
        if id:find(arg_lead, 1, true) then
          table.insert(matches, id)
        end
      end
      return matches
    end,
    desc = "Preview an ASCII art in a floating window",
  })

  vim.api.nvim_create_user_command("AsciiSettings", function()
    M.stats()
  end, {
    desc = "Open ASCII animation settings panel",
  })

  vim.api.nvim_create_user_command("AsciiRefresh", function()
    M.refresh()
  end, {
    desc = "Re-run animation on current buffer",
  })
end

return M
