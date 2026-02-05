-- User commands for ascii-animation
-- Provides :AsciiPreview, :AsciiList, :AsciiSettings, :AsciiRefresh, :AsciiStop, :AsciiRestart, :AsciiCharset

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
  submenu = nil,  -- nil | "wave" | "glitch" | "scramble" | "spiral" | "fade" | "timing" | "styles" | "messages" | "footer"
}

-- Import messages module for period counts
local messages = require("ascii-animation.content.messages")

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

-- All message periods
local ALL_PERIODS = { "morning", "afternoon", "evening", "night", "weekend" }

-- Message browser state
local message_browser = {
  messages = {},      -- All messages with IDs
  filtered = {},      -- Filtered list (by period/theme)
  index = 1,          -- Current selected message index
  page = 1,           -- Current page
  page_size = 10,     -- Messages per page
  period_filter = nil, -- nil = all, or specific period
  theme_filter = nil,  -- nil = all, or specific theme
  view = "messages",   -- "messages" | "themes"
}

-- Initialize/refresh message browser list
local function refresh_message_list()
  message_browser.messages = content.get_all_messages_with_ids()
  message_browser.filtered = {}

  for _, msg in ipairs(message_browser.messages) do
    local include = true
    -- Filter by period if set
    if message_browser.period_filter and msg.period ~= message_browser.period_filter then
      include = false
    end
    -- Filter by theme if set
    if message_browser.theme_filter and msg.theme ~= message_browser.theme_filter then
      include = false
    end
    if include then
      table.insert(message_browser.filtered, msg)
    end
  end

  -- Sort by theme for grouped display
  local theme_order = {}
  for i, theme in ipairs(content.themes or {}) do
    theme_order[theme] = i
  end
  table.sort(message_browser.filtered, function(a, b)
    local order_a = theme_order[a.theme] or 99
    local order_b = theme_order[b.theme] or 99
    if order_a ~= order_b then
      return order_a < order_b
    end
    return a.index < b.index
  end)

  -- Reset selection if out of bounds
  if message_browser.index > #message_browser.filtered then
    message_browser.index = math.max(1, #message_browser.filtered)
  end
  -- Recalculate page
  message_browser.page = math.ceil(message_browser.index / message_browser.page_size)
  if message_browser.page < 1 then message_browser.page = 1 end
end

-- Get themes submenu lines
local function get_themes_submenu_lines()
  local themes = content.themes or {}
  local theme_names = content.theme_names or {}

  local lines = {
    "",
    "  Message Themes",
    "  " .. string.rep("─", 38),
    "",
  }

  for i, theme in ipairs(themes) do
    local is_disabled = config.is_theme_disabled(theme)
    local checkbox = is_disabled and "[ ]" or "[x]"
    local count = content.get_message_count_for_theme(theme)
    local name = theme_names[theme] or theme
    table.insert(lines, string.format("  [%d] %s %-14s (%d)", i, checkbox, name, count))
  end

  local enabled = #themes - #config.themes_disabled
  table.insert(lines, "")
  table.insert(lines, string.format("  %d/%d themes enabled", enabled, #themes))
  table.insert(lines, "")
  table.insert(lines, "  Keys:")
  table.insert(lines, "    1-7: toggle theme on/off")
  table.insert(lines, "    b: browse individual messages")
  table.insert(lines, "    Backspace: back to main")
  table.insert(lines, "")

  return lines
end

-- Get messages submenu lines
local function get_messages_submenu_lines()
  -- Show themes view
  if message_browser.view == "themes" then
    return get_themes_submenu_lines()
  end

  -- Ensure list is populated
  if #message_browser.messages == 0 then
    refresh_message_list()
  end

  local lines = {
    "",
    "  Message Browser",
    "  " .. string.rep("─", 38),
    "",
  }

  -- Stats
  local fav_count = #config.message_favorites
  local disabled_count = #config.message_disabled
  local themes_disabled = #config.themes_disabled

  -- Build filter label
  local filter_parts = {}
  if message_browser.period_filter then
    table.insert(filter_parts, message_browser.period_filter)
  end
  if message_browser.theme_filter then
    local theme_names = content.theme_names or {}
    table.insert(filter_parts, theme_names[message_browser.theme_filter] or message_browser.theme_filter)
  end
  local filter_label = #filter_parts > 0 and table.concat(filter_parts, "+") or "all"

  table.insert(lines, string.format("  Filter: %-12s (%d msgs)", filter_label, #message_browser.filtered))
  table.insert(lines, string.format("  ★ %d fav  ✗ %d msg  ✗ %d themes", fav_count, disabled_count, themes_disabled))
  table.insert(lines, "")

  -- Build display with theme headers
  local display_items = {}  -- {type="header"|"msg", theme=, msg=, idx=}
  local current_theme = nil
  local theme_names = content.theme_names or {}

  for i, msg in ipairs(message_browser.filtered) do
    -- Add header when theme changes
    if msg.theme ~= current_theme then
      current_theme = msg.theme
      table.insert(display_items, {
        type = "header",
        theme = msg.theme,
        theme_name = theme_names[msg.theme] or msg.theme,
      })
    end
    table.insert(display_items, {
      type = "msg",
      msg = msg,
      idx = i,
    })
  end

  -- Calculate page bounds (including headers in display)
  local items_per_page = message_browser.page_size + 2  -- Allow extra for headers
  local start_item = (message_browser.page - 1) * message_browser.page_size + 1

  -- Find the display position for the current page start
  local display_start = 1
  local msg_count = 0
  for i, item in ipairs(display_items) do
    if item.type == "msg" then
      msg_count = msg_count + 1
      if msg_count == start_item then
        -- Back up to include header if this is first msg of a theme
        if i > 1 and display_items[i-1].type == "header" then
          display_start = i - 1
        else
          display_start = i
        end
        break
      end
    end
  end

  local total_pages = math.max(1, math.ceil(#message_browser.filtered / message_browser.page_size))
  local lines_shown = 0
  local max_lines = items_per_page

  -- Display items for current page
  for i = display_start, #display_items do
    if lines_shown >= max_lines then break end

    local item = display_items[i]
    if item.type == "header" then
      local is_disabled = config.is_theme_disabled(item.theme)
      local status = is_disabled and " ✗" or ""
      table.insert(lines, string.format("  ── %s%s ──", item.theme_name, status))
      lines_shown = lines_shown + 1
    else
      local msg = item.msg
      local is_selected = (item.idx == message_browser.index)
      local is_fav = config.is_message_favorite(msg.id)
      local is_disabled = config.is_message_disabled(msg.id)
      local theme_disabled = config.is_theme_disabled(msg.theme)

      local prefix = is_selected and "► " or "  "
      local fav_icon = is_fav and "★" or " "
      local status_icon = (is_disabled or theme_disabled) and "✗" or "✓"

      -- Truncate message text
      local max_len = 26
      local text = msg.text
      if #text > max_len then
        text = text:sub(1, max_len - 2) .. ".."
      end

      table.insert(lines, string.format("%s%s %s %s", prefix, fav_icon, status_icon, text))
      lines_shown = lines_shown + 1
    end
  end

  -- Pad to consistent height
  while lines_shown < max_lines do
    table.insert(lines, "")
    lines_shown = lines_shown + 1
  end

  table.insert(lines, "")
  table.insert(lines, string.format("  Page %d/%d", message_browser.page, total_pages))
  table.insert(lines, "")
  table.insert(lines, "  Keys:")
  table.insert(lines, "    j/k: navigate  n/N: page")
  table.insert(lines, "    F: favorite  d: disable  p: preview")
  table.insert(lines, "    1-5: filter period  c: clear filter")
  table.insert(lines, "    t: back to themes  BS: main menu")
  table.insert(lines, "")

  return lines
end

-- Get footer submenu lines
local function get_footer_submenu_lines()
  local footer_opts = config.options.footer or {}
  local alignments = { "left", "center", "right" }
  local align_idx = 1
  for i, a in ipairs(alignments) do
    if a == footer_opts.alignment then align_idx = i break end
  end

  local lines = {
    "",
    "  Footer Settings",
    "  " .. string.rep("─", 38),
    "",
    string.format("  [e] Enabled:   %s", footer_opts.enabled and "ON " or "OFF"),
    string.format("  [a] Alignment: %-8s  ◀ %d/%d ▶", footer_opts.alignment or "center", align_idx, #alignments),
    "",
    "  [t] Edit template...",
    string.format("      Current: %s", footer_opts.template or "{message}"),
    "",
    "  Available placeholders:",
    "    {message} {date} {time} {version}",
    "    {plugins} {name} {project}",
    "",
  }

  -- Add footer preview
  local ascii = require("ascii-animation")
  local preview_text = ascii.get_footer()
  if preview_text and preview_text ~= "" then
    table.insert(lines, "  Preview:")
    table.insert(lines, string.format("    \"%s\"", preview_text))
    table.insert(lines, "")
  end

  table.insert(lines, "  Keys: e/a/t: adjust  Backspace: back")
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
    elseif settings_state.submenu == "messages" then
      lines = get_messages_submenu_lines()
    elseif settings_state.submenu == "footer" then
      lines = get_footer_submenu_lines()
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

    -- Charset preset options
    local char_preset = opts.animation.char_preset or "default"
    local charset_idx = 1
    for i, p in ipairs(config.char_preset_names) do
      if p == char_preset then charset_idx = i break end
    end

    -- Build options indicator
    local has_opts = effect_has_options(effect)
    local opts_hint = has_opts and "  [o] Options..." or ""

    local styles_count = get_enabled_styles_count()
    local styles_label = styles_count == #ALL_STYLES and "all" or tostring(styles_count)

    -- Footer info
    local footer_opts = opts.footer or {}
    local footer_label = footer_opts.enabled and footer_opts.alignment or "OFF"

    -- Unicode warning for charset
    local charset_warning = ""
    if config.preset_requires_unicode(char_preset) then
      charset_warning = "      (requires Unicode font)"
    end

    lines = {
      "",
      "  Animation",
      "  " .. string.rep("─", 38),
      "",
      string.format("  [e] Effect:   %-10s ◀ %d/%d ▶", effect, effect_idx, #effects),
      opts_hint,
      string.format("  [a] Ambient:  %-10s ◀ %d/%d ▶", opts.animation.ambient, ambient_idx, #ambients),
      string.format("  [l] Loop:     %s", opts.animation.loop and "ON " or "OFF"),
      string.format("  [s] Steps:    %d", opts.animation.steps),
      string.format("  [c] Charset:  %-10s ◀ %d/%d ▶", char_preset, charset_idx, #config.char_preset_names),
      charset_warning,
      "  [t] Timing...",
      "",
      "  Content",
      "  " .. string.rep("─", 38),
      string.format("  [m] Mode:     %-10s ◀ %d/%d ▶", opts.selection.random_mode, random_idx, #random_modes),
      string.format("  [n] No repeat: %s", opts.selection.no_repeat and "ON " or "OFF"),
      string.format("  [w] Fav weight: %d%%", config.favorites_weight),
      string.format("  [y] Styles...  (%s/%d)", styles_label, #ALL_STYLES),
      string.format("  [g] Themes...    (%d/%d)", 7 - #config.themes_disabled, 7),
      "",
      "  Footer",
      "  " .. string.rep("─", 38),
      string.format("  [f] Footer...  (%s)", footer_label),
      "",
      string.format("  Arts: %d (%d favs)", art_count, fav_count),
      "",
      "  [Space] Replay  [R] Reset  [q] Close",
      "",
    }

    -- Remove empty options/warning lines
    local new_lines = {}
    for _, line in ipairs(lines) do
      local skip = false
      -- Skip empty opts_hint if no options
      if line == opts_hint and not has_opts then skip = true end
      -- Skip empty charset_warning
      if line == "" and charset_warning == "" then
        -- Only skip if this would create a double empty line
        if #new_lines > 0 and new_lines[#new_lines] == "" then skip = true end
      end
      if line == charset_warning and charset_warning == "" then skip = true end
      if not skip then
        table.insert(new_lines, line)
      end
    end
    lines = new_lines
  end

  vim.bo[settings_state.settings_buf].modifiable = true
  vim.api.nvim_buf_set_lines(settings_state.settings_buf, 0, -1, false, lines)
  vim.bo[settings_state.settings_buf].modifiable = false
end

-- Forward declaration for replay
local replay_preview
-- Forward declaration for preview buffer update
local update_preview_buffer

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

-- Cycle through charset presets
local function cycle_charset(delta)
  local presets = config.char_preset_names
  local current = config.options.animation.char_preset or "default"
  local idx = 1
  for i, p in ipairs(presets) do
    if p == current then idx = i break end
  end
  idx = idx + delta
  if idx < 1 then idx = #presets
  elseif idx > #presets then idx = 1 end
  config.options.animation.char_preset = presets[idx]
  config.save()
  update_settings_content()
  replay_preview()
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
  local was_footer = settings_state.submenu == "footer"
  local was_messages = settings_state.submenu == "messages"
  settings_state.submenu = nil
  update_settings_content()
  -- Restore preview to normal view
  if was_footer or was_messages then
    update_preview_buffer()
    replay_preview()
  end
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

-- Update preview buffer content (implements forward declaration)
update_preview_buffer = function()
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

-- Update preview buffer to show footer when in footer submenu
local function update_preview_with_footer()
  if not settings_state.preview_buf or not vim.api.nvim_buf_is_valid(settings_state.preview_buf) then
    return
  end

  local art = settings_state.current_art
  if not art or not art.lines then return end

  -- Calculate preview width from art
  local art_width = 0
  for _, line in ipairs(art.lines) do
    art_width = math.max(art_width, vim.fn.strdisplaywidth(line))
  end
  local preview_width = math.max(40, art_width + 4)

  -- Build content with padding
  local lines = { "" }
  for _, line in ipairs(art.lines) do
    table.insert(lines, "  " .. line)
  end
  table.insert(lines, "")
  table.insert(lines, string.format("  %s", art.name or art.id))

  -- Add footer preview if in footer submenu
  if settings_state.submenu == "footer" then
    local ascii = require("ascii-animation")
    local footer_opts = config.options.footer or {}

    table.insert(lines, "")
    table.insert(lines, "  ┌" .. string.rep("─", preview_width - 4) .. "┐")

    if footer_opts.enabled then
      local footer_text = ascii.get_footer()
      if footer_text and footer_text ~= "" then
        -- Apply alignment for preview
        local alignment = footer_opts.alignment or "center"
        local text_width = vim.fn.strdisplaywidth(footer_text)
        local inner_width = preview_width - 6  -- Account for borders and padding
        local aligned_footer

        if text_width > inner_width then
          -- Truncate if too long
          footer_text = footer_text:sub(1, inner_width - 2) .. ".."
          text_width = vim.fn.strdisplaywidth(footer_text)
        end

        if alignment == "center" then
          local left_pad = math.floor((inner_width - text_width) / 2)
          local right_pad = inner_width - text_width - left_pad
          aligned_footer = string.rep(" ", left_pad) .. footer_text .. string.rep(" ", right_pad)
        elseif alignment == "right" then
          local pad = inner_width - text_width
          aligned_footer = string.rep(" ", pad) .. footer_text
        else  -- left
          local pad = inner_width - text_width
          aligned_footer = footer_text .. string.rep(" ", pad)
        end

        table.insert(lines, "  │ " .. aligned_footer .. " │")
      else
        local empty = string.rep(" ", preview_width - 6)
        table.insert(lines, "  │ " .. empty .. " │")
      end
    else
      local disabled_text = "(footer disabled)"
      local inner_width = preview_width - 6
      local pad = math.floor((inner_width - #disabled_text) / 2)
      local padded = string.rep(" ", pad) .. disabled_text .. string.rep(" ", inner_width - #disabled_text - pad)
      table.insert(lines, "  │ " .. padded .. " │")
    end

    table.insert(lines, "  └" .. string.rep("─", preview_width - 4) .. "┘")

    -- Show alignment indicator
    local alignment = footer_opts.alignment or "center"
    local indicator
    if alignment == "left" then
      indicator = "  ◀ left"
    elseif alignment == "right" then
      indicator = string.rep(" ", preview_width - 10) .. "right ▶"
    else
      indicator = string.rep(" ", math.floor((preview_width - 8) / 2)) .. "center"
    end
    table.insert(lines, indicator)
  end

  table.insert(lines, "")

  vim.bo[settings_state.preview_buf].modifiable = true
  vim.api.nvim_buf_set_lines(settings_state.preview_buf, 0, -1, false, lines)
  vim.bo[settings_state.preview_buf].modifiable = false
end

-- Update preview buffer to show selected message when in messages submenu
local function update_preview_with_message()
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

  -- Add message preview if in messages submenu
  if settings_state.submenu == "messages" then
    local msg = message_browser.filtered[message_browser.index]
    if msg then
      table.insert(lines, "  " .. string.rep("─", 30))
      table.insert(lines, "")

      local placeholders = require("ascii-animation.placeholders")
      local processed = placeholders.process(msg.text)

      -- Word wrap long messages
      local max_width = 34
      local words = {}
      for word in processed:gmatch("%S+") do
        table.insert(words, word)
      end

      local current_line = "  "
      for _, word in ipairs(words) do
        if #current_line + #word + 1 > max_width then
          table.insert(lines, current_line)
          current_line = "  " .. word
        else
          if current_line == "  " then
            current_line = "  " .. word
          else
            current_line = current_line .. " " .. word
          end
        end
      end
      if current_line ~= "  " then
        table.insert(lines, current_line)
      end

      table.insert(lines, "")

      -- Show message metadata
      local is_fav = config.is_message_favorite(msg.id)
      local is_disabled = config.is_message_disabled(msg.id)
      local theme_disabled = config.is_theme_disabled(msg.theme)
      local status = ""
      if is_fav then status = status .. " ★" end
      if is_disabled then status = status .. " ✗msg" end
      if theme_disabled then status = status .. " ✗theme" end
      if status == "" then status = " ✓" end

      local theme_names = content.theme_names or {}
      local theme_label = theme_names[msg.theme] or msg.theme
      table.insert(lines, string.format("  [%s · %s]%s", msg.period, theme_label, status))
      table.insert(lines, "")
    end
  end

  vim.bo[settings_state.preview_buf].modifiable = true
  vim.api.nvim_buf_set_lines(settings_state.preview_buf, 0, -1, false, lines)
  vim.bo[settings_state.preview_buf].modifiable = false
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

  -- Charset cycling (main menu) / Scramble cycles / Message browser clear filter
  vim.keymap.set("n", "c", function()
    if not settings_state.submenu then
      cycle_charset(1)
    elseif settings_state.submenu == "scramble" then
      adjust_scramble_cycles(1)
    elseif settings_state.submenu == "messages" and message_browser.view == "messages" then
      message_browser.period_filter = nil
      message_browser.theme_filter = nil
      message_browser.index = 1
      message_browser.page = 1
      refresh_message_list()
      update_settings_content()
      update_preview_with_message()
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "C", function()
    if not settings_state.submenu then
      cycle_charset(-1)
    elseif settings_state.submenu == "scramble" then
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

  -- Messages/Themes submenu - starts with Themes view
  vim.keymap.set("n", "g", function()
    if not settings_state.submenu then
      settings_state.submenu = "messages"
      message_browser.period_filter = nil
      message_browser.theme_filter = nil
      message_browser.view = "themes"  -- Start with themes view
      message_browser.index = 1
      message_browser.page = 1
      refresh_message_list()
      update_settings_content()
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Browse individual messages (from themes view)
  vim.keymap.set("n", "b", function()
    if settings_state.submenu == "messages" and message_browser.view == "themes" then
      message_browser.view = "messages"
      refresh_message_list()
      update_settings_content()
      -- Resize preview window for message preview
      if settings_state.preview_win and vim.api.nvim_win_is_valid(settings_state.preview_win) then
        local art = settings_state.current_art
        if art then
          local new_height = #art.lines + 14
          vim.api.nvim_win_set_config(settings_state.preview_win, { height = new_height })
        end
      end
      update_preview_with_message()
    elseif settings_state.submenu == "glitch" then
      adjust_glitch_block_chance(0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Back to themes from messages view (or footer template edit)
  vim.keymap.set("n", "t", function()
    if settings_state.submenu == "messages" and message_browser.view == "messages" then
      message_browser.view = "themes"
      update_settings_content()
      update_preview_buffer()
    elseif settings_state.submenu == "footer" then
      vim.ui.input({
        prompt = "Footer template: ",
        default = config.options.footer.template or "{message}",
      }, function(input)
        if input then
          config.options.footer.template = input
          config.save()
          update_settings_content()
          update_preview_with_footer()
        end
      end)
    elseif not settings_state.submenu then
      open_timing_submenu()
    elseif settings_state.submenu == "spiral" then
      adjust_spiral_tightness(0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Clear all filters in message browser (note: 'c' for main menu charset is handled above)

  -- Message browser navigation (j/k)
  vim.keymap.set("n", "j", function()
    if settings_state.submenu == "messages" then
      if message_browser.index < #message_browser.filtered then
        message_browser.index = message_browser.index + 1
        message_browser.page = math.ceil(message_browser.index / message_browser.page_size)
        update_settings_content()
        update_preview_with_message()
      end
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "k", function()
    if settings_state.submenu == "messages" then
      if message_browser.index > 1 then
        message_browser.index = message_browser.index - 1
        message_browser.page = math.ceil(message_browser.index / message_browser.page_size)
        update_settings_content()
        update_preview_with_message()
      end
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Message browser page navigation (n/N)
  vim.keymap.set("n", "n", function()
    if settings_state.submenu == "messages" then
      local total_pages = math.max(1, math.ceil(#message_browser.filtered / message_browser.page_size))
      if message_browser.page < total_pages then
        message_browser.page = message_browser.page + 1
        message_browser.index = (message_browser.page - 1) * message_browser.page_size + 1
        update_settings_content()
        update_preview_with_message()
      end
    elseif not settings_state.submenu then
      toggle_no_repeat()
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "N", function()
    if settings_state.submenu == "messages" then
      if message_browser.page > 1 then
        message_browser.page = message_browser.page - 1
        message_browser.index = (message_browser.page - 1) * message_browser.page_size + 1
        update_settings_content()
        update_preview_with_message()
      end
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Message favorite toggle (in messages submenu, 'f' key)
  vim.keymap.set("n", "F", function()
    if settings_state.submenu == "messages" then
      local msg = message_browser.filtered[message_browser.index]
      if msg then
        local added = config.toggle_message_favorite(msg.id)
        vim.notify(added and "Added to favorites" or "Removed from favorites", vim.log.levels.INFO)
        update_settings_content()
      end
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Message disable toggle (in messages submenu)
  vim.keymap.set("n", "d", function()
    if settings_state.submenu == "messages" then
      local msg = message_browser.filtered[message_browser.index]
      if msg then
        local disabled = config.toggle_message_disabled(msg.id)
        vim.notify(disabled and "Message disabled" or "Message enabled", vim.log.levels.INFO)
        update_settings_content()
      end
    elseif settings_state.submenu == "spiral" then
      cycle_spiral_direction(1)
    elseif settings_state.submenu == "timing" then
      adjust_loop_delay(100)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Footer submenu
  vim.keymap.set("n", "f", function()
    if not settings_state.submenu then
      settings_state.submenu = "footer"
      update_settings_content()
      -- Resize preview window to fit footer
      if settings_state.preview_win and vim.api.nvim_win_is_valid(settings_state.preview_win) then
        local art = settings_state.current_art
        if art then
          local new_height = #art.lines + 12  -- Extra for footer box
          vim.api.nvim_win_set_config(settings_state.preview_win, { height = new_height })
        end
      end
      -- Show footer preview below art
      update_preview_with_footer()
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Footer-specific keys
  vim.keymap.set("n", "e", function()
    if settings_state.submenu == "footer" then
      config.options.footer.enabled = not config.options.footer.enabled
      config.save()
      update_settings_content()
      update_preview_with_footer()
    elseif not settings_state.submenu then
      cycle_effect(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "E", function()
    if not settings_state.submenu then
      cycle_effect(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Footer alignment cycling / Ambient cycling
  vim.keymap.set("n", "a", function()
    if settings_state.submenu == "footer" then
      local alignments = { "left", "center", "right" }
      local current = config.options.footer.alignment or "center"
      local idx = 1
      for i, a in ipairs(alignments) do
        if a == current then idx = i break end
      end
      idx = idx + 1
      if idx > #alignments then idx = 1 end
      config.options.footer.alignment = alignments[idx]
      config.save()
      update_settings_content()
      update_preview_with_footer()
    elseif not settings_state.submenu then
      cycle_ambient(1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "A", function()
    if settings_state.submenu == "footer" then
      local alignments = { "left", "center", "right" }
      local current = config.options.footer.alignment or "center"
      local idx = 1
      for i, a in ipairs(alignments) do
        if a == current then idx = i break end
      end
      idx = idx - 1
      if idx < 1 then idx = #alignments end
      config.options.footer.alignment = alignments[idx]
      config.save()
      update_settings_content()
      update_preview_with_footer()
    elseif not settings_state.submenu then
      cycle_ambient(-1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "T", function()
    if settings_state.submenu == "spiral" then
      adjust_spiral_tightness(-0.1)
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- Message preview (show full message in notification)
  vim.keymap.set("n", "p", function()
    if settings_state.submenu == "messages" then
      local msg = message_browser.filtered[message_browser.index]
      if msg then
        local placeholders = require("ascii-animation.placeholders")
        local processed = placeholders.process(msg.text)
        vim.notify(processed, vim.log.levels.INFO)
      else
        vim.notify("No message selected", vim.log.levels.WARN)
      end
    end
  end, { buffer = buf, nowait = true, silent = true })

  -- All themes for filtering
  local ALL_THEMES = content.themes or { "motivational", "personalized", "philosophical", "cryptic", "poetic", "zen", "witty" }

  -- Number keys for toggles (1-7 for styles, 1-5 for period, 6-9+0 for theme in messages)
  vim.keymap.set("n", "0", function()
    if settings_state.submenu == "messages" then
      if message_browser.view == "messages" then
        -- 0 = witty theme filter (7th theme)
        message_browser.theme_filter = ALL_THEMES[7]
        message_browser.index = 1
        message_browser.page = 1
        refresh_message_list()
        update_settings_content()
        update_preview_with_message()
      end
    end
  end, { buffer = buf, nowait = true, silent = true })

  for i = 1, 9 do
    vim.keymap.set("n", tostring(i), function()
      if settings_state.submenu == "styles" then
        if i <= #ALL_STYLES then
          toggle_style(ALL_STYLES[i])
          update_settings_content()
          -- Pick a new random art from enabled styles for preview
          local arts = get_arts_list(nil)
          if #arts > 0 then
            settings_state.current_art = arts[math.random(1, #arts)]
            replay_preview()
          end
        end
      elseif settings_state.submenu == "messages" then
        if message_browser.view == "themes" then
          -- In themes view: 1-7 toggles themes
          if i <= #ALL_THEMES then
            local disabled = config.toggle_theme_disabled(ALL_THEMES[i])
            vim.notify(disabled and "Theme disabled" or "Theme enabled", vim.log.levels.INFO)
            update_settings_content()
          end
        else
          -- In messages view: 1-5 = period, 6-9 = theme
          if i <= 5 then
            message_browser.period_filter = ALL_PERIODS[i]
            message_browser.index = 1
            message_browser.page = 1
            refresh_message_list()
            update_settings_content()
            update_preview_with_message()
          elseif i >= 6 and i <= 9 then
            -- 6=motivational, 7=personalized, 8=philosophical, 9=cryptic
            local theme_idx = i - 5
            if theme_idx <= #ALL_THEMES then
              message_browser.theme_filter = ALL_THEMES[theme_idx]
              message_browser.index = 1
              message_browser.page = 1
              refresh_message_list()
              update_settings_content()
              update_preview_with_message()
            end
          end
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

  local settings_height = 32
  -- Extra height for footer/message preview (6 lines for footer box + alignment indicator)
  local preview_height = #art.lines + 12

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

  vim.api.nvim_create_user_command("AsciiStop", function()
    animation.stop()
    vim.notify("Animation stopped", vim.log.levels.INFO)
  end, {
    desc = "Stop current ASCII animation",
  })

  vim.api.nvim_create_user_command("AsciiRestart", function()
    M.refresh()
    vim.notify("Animation restarted", vim.log.levels.INFO)
  end, {
    desc = "Restart ASCII animation from beginning",
  })

  vim.api.nvim_create_user_command("AsciiCharset", function(opts)
    local preset = opts.args
    if preset == "" then
      -- Show current preset
      local current = config.options.animation.char_preset or "default"
      vim.notify("Current charset: " .. current .. " (" .. config.get_chaos_chars() .. ")", vim.log.levels.INFO)
      return
    end
    -- Validate preset name
    if not config.char_presets[preset] then
      local valid = table.concat(config.char_preset_names, ", ")
      vim.notify("Invalid charset preset. Valid options: " .. valid, vim.log.levels.WARN)
      return
    end
    config.options.animation.char_preset = preset
    config.save()
    local msg = "Charset set to: " .. preset
    if config.preset_requires_unicode(preset) then
      msg = msg .. " (requires Unicode font support)"
    end
    vim.notify(msg, vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function(arg_lead)
      local matches = {}
      for _, name in ipairs(config.char_preset_names) do
        if name:find(arg_lead, 1, true) then
          table.insert(matches, name)
        end
      end
      return matches
    end,
    desc = "Set character set preset for animation",
  })
end

return M
