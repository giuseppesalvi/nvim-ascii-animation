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

-- State for stats window
local stats_state = {
  buf = nil,
  win = nil,
}

-- Close stats window
local function close_stats()
  if stats_state.win and vim.api.nvim_win_is_valid(stats_state.win) then
    vim.api.nvim_win_close(stats_state.win, true)
  end
  if stats_state.buf and vim.api.nvim_buf_is_valid(stats_state.buf) then
    vim.api.nvim_buf_delete(stats_state.buf, { force = true })
  end
  stats_state.win = nil
  stats_state.buf = nil
end

-- Update stats window content
local function update_stats_content()
  if not stats_state.buf or not vim.api.nvim_buf_is_valid(stats_state.buf) then
    return
  end

  local opts = config.options
  local all_arts = content.list_arts()
  local art_count = #all_arts
  local message_count = content.messages.get_message_count()
  local styles = content.get_styles()
  local effect = opts.animation.effect
  local period = time.get_current_period()
  local fav_count = #config.favorites

  -- Effect options for display
  local effects = { "chaos", "typewriter", "diagonal", "lines", "matrix", "random" }
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

  local lines = {
    "",
    "  ASCII Animation Settings",
    "  " .. string.rep("─", 45),
    "",
    string.format("  Arts:        %d available (%d favorites)", art_count, fav_count),
    string.format("  Taglines:    %d available", message_count),
    string.format("  Styles:      %s", table.concat(styles, ", ")),
    string.format("  Period:      %s", period),
    "",
    "  Animation:",
    "  " .. string.rep("─", 45),
    string.format("  [e] Effect:      %-10s  ◀ %d/%d ▶", effect, effect_idx, #effects),
    string.format("  [a] Ambient:     %-10s  ◀ %d/%d ▶", opts.animation.ambient, ambient_idx, #ambients),
    string.format("  [l] Loop:        %s", opts.animation.loop and "ON " or "OFF"),
    string.format("  [s] Steps:       %d", opts.animation.steps),
    "",
    "  Selection:",
    "  " .. string.rep("─", 45),
    string.format("  [m] Random mode: %-10s  ◀ %d/%d ▶", opts.selection.random_mode, random_idx, #random_modes),
    string.format("  [n] No repeat:   %s", opts.selection.no_repeat and "ON " or "OFF"),
    string.format("  [w] Fav weight:  %d%%", config.favorites_weight),
    "",
    "  Keys: e/a/m: cycle  l/n: toggle  s/w: ±adjust",
    "  r: refresh  p: preview  R: reset  q: close",
    "",
  }

  vim.bo[stats_state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(stats_state.buf, 0, -1, false, lines)
  vim.bo[stats_state.buf].modifiable = false
end

-- Cycle through effect options
local function cycle_effect(delta)
  local effects = { "chaos", "typewriter", "diagonal", "lines", "matrix", "random" }
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
  update_stats_content()
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
  update_stats_content()
end

-- Toggle loop
local function toggle_loop()
  config.options.animation.loop = not config.options.animation.loop
  config.save()
  update_stats_content()
end

-- Adjust steps
local function adjust_steps(delta)
  local new_steps = config.options.animation.steps + delta
  if new_steps >= 10 and new_steps <= 100 then
    config.options.animation.steps = new_steps
    config.save()
    update_stats_content()
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
  update_stats_content()
end

-- Toggle no-repeat
local function toggle_no_repeat()
  config.options.selection.no_repeat = not config.options.selection.no_repeat
  config.save()
  update_stats_content()
end

-- Adjust favorites weight
local function adjust_fav_weight(delta)
  local new_weight = config.favorites_weight + delta
  if new_weight >= 0 and new_weight <= 100 then
    config.favorites_weight = new_weight
    config.save()
    update_stats_content()
  end
end

-- Reset to config defaults
local function reset_to_defaults()
  config.clear_saved()
  -- Reload defaults
  config.options.animation.effect = config.defaults.animation.effect
  config.options.animation.ambient = config.defaults.animation.ambient
  config.options.animation.loop = config.defaults.animation.loop
  config.options.animation.steps = config.defaults.animation.steps
  vim.notify("Settings reset to defaults", vim.log.levels.INFO)
  update_stats_content()
end

-- Display interactive statistics
function M.stats()
  close_stats()

  local opts = config.options
  local all_arts = content.list_arts()
  local art_count = #all_arts
  local message_count = content.messages.get_message_count()
  local styles = content.get_styles()
  local effect = opts.animation.effect
  local period = time.get_current_period()
  local fav_count = #config.favorites

  local effects = { "chaos", "typewriter", "diagonal", "lines", "matrix", "random" }
  local effect_idx = 1
  for i, e in ipairs(effects) do
    if e == effect then effect_idx = i break end
  end

  local ambients = { "none", "glitch", "shimmer" }
  local ambient_idx = 1
  for i, a in ipairs(ambients) do
    if a == opts.animation.ambient then ambient_idx = i break end
  end

  local random_modes = { "always", "daily", "session" }
  local random_idx = 1
  for i, m in ipairs(random_modes) do
    if m == opts.selection.random_mode then random_idx = i break end
  end

  local lines = {
    "",
    "  ASCII Animation Settings",
    "  " .. string.rep("─", 45),
    "",
    string.format("  Arts:        %d available (%d favorites)", art_count, fav_count),
    string.format("  Taglines:    %d available", message_count),
    string.format("  Styles:      %s", table.concat(styles, ", ")),
    string.format("  Period:      %s", period),
    "",
    "  Animation:",
    "  " .. string.rep("─", 45),
    string.format("  [e] Effect:      %-10s  ◀ %d/%d ▶", effect, effect_idx, #effects),
    string.format("  [a] Ambient:     %-10s  ◀ %d/%d ▶", opts.animation.ambient, ambient_idx, #ambients),
    string.format("  [l] Loop:        %s", opts.animation.loop and "ON " or "OFF"),
    string.format("  [s] Steps:       %d", opts.animation.steps),
    "",
    "  Selection:",
    "  " .. string.rep("─", 45),
    string.format("  [m] Random mode: %-10s  ◀ %d/%d ▶", opts.selection.random_mode, random_idx, #random_modes),
    string.format("  [n] No repeat:   %s", opts.selection.no_repeat and "ON " or "OFF"),
    string.format("  [w] Fav weight:  %d%%", config.favorites_weight),
    "",
    "  Keys: e/a/m: cycle  l/n: toggle  s/w: ±adjust",
    "  r: refresh  p: preview  R: reset  q: close",
    "",
  }

  -- Calculate dimensions
  local width = 52
  local height = #lines + 2

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Stats & Settings ",
    title_pos = "center",
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  stats_state.buf = buf
  stats_state.win = win

  -- Keybindings
  local keymaps = {
    { "q", close_stats },
    { "<Esc>", close_stats },
    { "e", function() cycle_effect(1) end },
    { "E", function() cycle_effect(-1) end },
    { "a", function() cycle_ambient(1) end },
    { "A", function() cycle_ambient(-1) end },
    { "l", toggle_loop },
    { "s", function() adjust_steps(5) end },
    { "S", function() adjust_steps(-5) end },
    { "m", function() cycle_random_mode(1) end },
    { "M", function() cycle_random_mode(-1) end },
    { "n", toggle_no_repeat },
    { "w", function() adjust_fav_weight(10) end },
    { "W", function() adjust_fav_weight(-10) end },
    { "r", function() close_stats() M.refresh() end },
    { "R", reset_to_defaults },
    { "p", function() close_stats() M.preview() end },
  }

  for _, map in ipairs(keymaps) do
    vim.keymap.set("n", map[1], map[2], { buffer = buf, nowait = true, silent = true })
  end

  return {
    arts = art_count,
    taglines = message_count,
    styles = styles,
    effect = effect,
    period = period,
    animation = opts.animation,
  }
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
