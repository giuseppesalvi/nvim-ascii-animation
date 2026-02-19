-- Content manager for ascii-animation
-- Provides unified access to arts and messages

local config = require("ascii-animation.config")
local time = require("ascii-animation.time")
local arts = require("ascii-animation.content.arts")
local messages = require("ascii-animation.content.messages")
local state = require("ascii-animation.state")
local placeholders = require("ascii-animation.placeholders")
local holidays_mod = require("ascii-animation.holidays")
local holiday_arts = require("ascii-animation.content.arts.holiday")
local holiday_messages = require("ascii-animation.content.messages.holidays")

local M = {}

local function get_current_width()
  local ok, win = pcall(vim.api.nvim_get_current_win)
  if ok and win and vim.api.nvim_win_is_valid(win) then
    local width_ok, width = pcall(vim.api.nvim_win_get_width, win)
    if width_ok and type(width) == "number" and width > 0 then
      return width
    end
  end
  return vim.o.columns
end

-- Cache for arts loaded from custom_arts_dir
local loaded_dir_arts = nil -- { by_period = { morning = {}, ... }, all = {} }

-- Parse a .txt art file with optional metadata header
local function parse_art_file(filepath)
  local ok, file_lines = pcall(vim.fn.readfile, filepath)
  if not ok or not file_lines then return nil end

  local metadata = {}
  local art_lines = {}
  local in_header = true

  for _, line in ipairs(file_lines) do
    if in_header and line:match("^#%s+(%w+):%s*(.+)") then
      local key, value = line:match("^#%s+(%w+):%s*(.+)")
      metadata[key] = vim.trim(value)
    else
      in_header = false
      table.insert(art_lines, line)
    end
  end

  -- Strip trailing empty lines
  while #art_lines > 0 and art_lines[#art_lines]:match("^%s*$") do
    table.remove(art_lines)
  end

  if #art_lines == 0 then return nil end

  -- Generate ID from filename
  local filename = vim.fn.fnamemodify(filepath, ":t:r")
  local id = "custom_" .. filename:gsub("[^%w_]", "_")

  return {
    id = metadata.id or id,
    name = metadata.name or filename,
    lines = art_lines,
    period = metadata.period,
    style = metadata.style or "custom",
    tags = metadata.tags,
  }
end

-- Load arts from custom_arts_dir (cached after first call)
local valid_periods = { morning = true, afternoon = true, evening = true, night = true, weekend = true }

local function load_arts_from_dir()
  if loaded_dir_arts then return loaded_dir_arts end

  loaded_dir_arts = { by_period = {}, all = {} }
  local opts = config.options.content or {}
  local dir = opts.custom_arts_dir
  if not dir then return loaded_dir_arts end

  dir = vim.fn.expand(dir)
  if vim.fn.isdirectory(dir) ~= 1 then return loaded_dir_arts end

  -- Load .txt files from root directory
  local files = vim.fn.glob(dir .. "/*.txt", false, true)
  for _, filepath in ipairs(files) do
    local art = parse_art_file(filepath)
    if art then
      table.insert(loaded_dir_arts.all, art)
      if art.period and valid_periods[art.period] then
        loaded_dir_arts.by_period[art.period] = loaded_dir_arts.by_period[art.period] or {}
        table.insert(loaded_dir_arts.by_period[art.period], art)
      end
    end
  end

  -- Load from period subdirectories (morning/, night/, etc.)
  for period_name in pairs(valid_periods) do
    local subdir = dir .. "/" .. period_name
    if vim.fn.isdirectory(subdir) == 1 then
      local sub_files = vim.fn.glob(subdir .. "/*.txt", false, true)
      for _, filepath in ipairs(sub_files) do
        local art = parse_art_file(filepath)
        if art then
          art.period = period_name
          table.insert(loaded_dir_arts.all, art)
          loaded_dir_arts.by_period[period_name] = loaded_dir_arts.by_period[period_name] or {}
          table.insert(loaded_dir_arts.by_period[period_name], art)
        end
      end
    end
  end

  return loaded_dir_arts
end

-- Track if seed was set this session (for 'session' mode)
local session_seed_set = false

-- Initialize random seed based on config
local function ensure_random_seed()
  local opts = config.options.content or {}
  local random_mode = opts.random or "always"

  if random_mode == "daily" then
    -- Same seed all day
    math.randomseed(state.get_daily_seed())
  elseif random_mode == "session" then
    -- Same seed within session
    math.randomseed(state.get_session_seed())
    if not session_seed_set then
      session_seed_set = true
    end
  else
    -- "always" - different each time
    math.randomseed(os.time() + math.floor(os.clock() * 1000))
  end
end

-- Check if an art should be excluded due to no-repeat setting
local function should_exclude_recent(art_id)
  local opts = config.options.content or {}
  local no_repeat = opts.no_repeat

  if not no_repeat or no_repeat == false then
    return false
  end

  -- true means don't repeat last 1
  local n = (no_repeat == true) and 1 or tonumber(no_repeat) or 0
  if n <= 0 then
    return false
  end

  return state.was_recently_shown(art_id, n)
end

-- Check if terminal is wide enough for an art
local function fits_terminal(art)
  local opts = config.options.animation or {}
  if not opts.auto_fit then
    return true
  end

  local terminal_width = get_current_width()
  local art_width = arts.get_art_width(art)
  return art_width <= terminal_width
end

-- Apply favorites weighting to selection pool
local function apply_favorites_weighting(art_list)
  local opts = config.options.content or {}
  local favorites = opts.favorites or {}
  local weight = opts.favorite_weight or 2

  if #favorites == 0 or weight <= 1 then
    return art_list
  end

  -- Create lookup for favorites
  local fav_lookup = {}
  for _, id in ipairs(favorites) do
    fav_lookup[id] = true
  end

  -- Build weighted pool
  local weighted = {}
  for _, art in ipairs(art_list) do
    if fav_lookup[art.id] then
      -- Add favorites multiple times
      for _ = 1, weight do
        table.insert(weighted, art)
      end
    else
      table.insert(weighted, art)
    end
  end

  return weighted
end

-- Check if should pick from favorites based on weight
local function should_pick_favorite()
  if #config.favorites == 0 then
    return false
  end
  ensure_random_seed()
  return math.random(100) <= config.favorites_weight
end

-- Get style filter from config
local function get_style_filter()
  local opts = config.options.content or {}
  return opts.styles
end

-- Get a random art for the current time period
-- Considers favorites weight setting
function M.get_art()
  ensure_random_seed()

  -- Check if we should pick from favorites
  if should_pick_favorite() then
    local fav_art = arts.get_art_by_id(config.favorites[math.random(#config.favorites)])
    if fav_art then
      return fav_art
    end
  end

  local period = time.get_current_period()
  return M.get_art_for_period(period)
end

-- Get a random art for a specific period
function M.get_art_for_period(period)
  ensure_random_seed()
  local style_filter = get_style_filter()
  local opts = config.options.content or {}

  -- 1. Collect all candidate arts (built-in + custom)
  local all_arts = {}

  -- Add built-in arts if enabled
  if opts.builtin_arts ~= false then
    local builtin = arts.get_arts_for_period(period, style_filter)
    for _, a in ipairs(builtin) do
      table.insert(all_arts, a)
    end
  end

  -- Add custom arts if configured
  if opts.custom_arts and opts.custom_arts[period] then
    for _, a in ipairs(opts.custom_arts[period]) do
      table.insert(all_arts, a)
    end
  end

  -- Add arts loaded from custom_arts_dir
  local dir_arts = load_arts_from_dir()
  if dir_arts.by_period[period] then
    for _, a in ipairs(dir_arts.by_period[period]) do
      table.insert(all_arts, a)
    end
  end
  -- Add period-less dir arts (available for all periods)
  for _, a in ipairs(dir_arts.all) do
    if not a.period then
      table.insert(all_arts, a)
    end
  end

  -- Add holiday arts if enabled and a holiday is active
  local holidays_cfg = opts.holidays or {}
  if holidays_cfg.enabled ~= false then
    local active = holidays_mod.get_active_holidays(holidays_cfg.custom)
    local priority = holidays_cfg.priority or 3
    for _, h in ipairs(active) do
      local h_arts = holiday_arts.get_arts_for_holiday(h.name)
      for _, a in ipairs(h_arts) do
        for _ = 1, priority do
          table.insert(all_arts, a)
        end
      end
    end
  end

  if #all_arts == 0 then
    return nil
  end

  -- 2. Filter by terminal width (if auto_fit enabled)
  local width_filtered = {}
  for _, art in ipairs(all_arts) do
    if fits_terminal(art) then
      table.insert(width_filtered, art)
    end
  end

  -- If all arts filtered out, use original list
  if #width_filtered == 0 then
    width_filtered = all_arts
  end

  -- 3. Filter no-repeat (exclude recently shown)
  local no_repeat_filtered = {}
  for _, art in ipairs(width_filtered) do
    if not should_exclude_recent(art.id) then
      table.insert(no_repeat_filtered, art)
    end
  end

  -- If all arts filtered out, use width-filtered list
  if #no_repeat_filtered == 0 then
    no_repeat_filtered = width_filtered
  end

  -- 4. Apply favorites weighting
  local weighted_pool = apply_favorites_weighting(no_repeat_filtered)

  -- 5. Select random art
  local selected = weighted_pool[math.random(#weighted_pool)]

  -- 6. Record selection
  if selected and selected.id then
    state.record_art_shown(selected.id)
  end

  return selected
end

-- Get a random message for the current time period
function M.get_message()
  ensure_random_seed()
  local period = time.get_current_period()
  return M.get_message_for_period(period)
end

-- Generate message ID from period and index
local function get_message_id(period, index)
  return period .. "_" .. index
end

-- Expose themes
M.themes = messages.themes
M.theme_names = messages.theme_names

-- Get all messages with IDs for a period
function M.get_messages_with_ids(period)
  local result = {}
  local period_messages = messages.get_messages_for_period(period)
  for i, msg in ipairs(period_messages) do
    table.insert(result, {
      id = get_message_id(period, i),
      text = msg.text,
      theme = msg.theme,
      period = period,
      index = i,
    })
  end
  return result
end

-- Get all messages with IDs across all periods
function M.get_all_messages_with_ids()
  local all = {}
  local periods = { "morning", "afternoon", "evening", "night", "weekend" }
  for _, period in ipairs(periods) do
    local period_msgs = M.get_messages_with_ids(period)
    for _, msg in ipairs(period_msgs) do
      table.insert(all, msg)
    end
  end
  return all
end

-- Get message count for a theme
function M.get_message_count_for_theme(theme)
  return messages.get_message_count_for_theme(theme)
end

-- Extract text from a message (handles both string and table formats)
-- For custom messages, they can be:
--   "simple string"
--   { "line1", "line2" }  -- multi-line as array
--   { text = "...", theme = "..." }  -- same format as built-in
--   { text = { "line1", "line2" }, theme = "..." }  -- multi-line built-in style
local function extract_message_text(msg)
  if type(msg) == "string" then
    return msg
  elseif type(msg) == "table" then
    -- Check if it's an array of strings (multi-line)
    if #msg > 0 and type(msg[1]) == "string" and not msg.text then
      return msg  -- Return table as-is for multi-line
    end
    -- Otherwise it's a message object with text field
    return msg.text
  end
  return nil
end

-- Check if a message's condition function passes (if it has one)
-- Returns true if message should be included (no condition or condition passes)
local function check_message_condition(msg)
  if type(msg) ~= "table" then
    return true  -- Simple strings have no condition
  end

  -- Check if message has a condition function
  if msg.condition and type(msg.condition) == "function" then
    local ok, result = pcall(msg.condition)
    if not ok then
      -- Condition function errored, exclude the message
      return false
    end
    return result == true
  end

  return true  -- No condition means always include
end

-- Check if a message should be excluded due to no-repeat setting
local function should_exclude_recent_message(msg_id)
  local opts = config.options.content or {}
  local no_repeat = opts.message_no_repeat

  if not no_repeat or no_repeat == false then
    return false
  end

  -- true means don't repeat last 1
  local n = (no_repeat == true) and 1 or tonumber(no_repeat) or 0
  if n <= 0 then
    return false
  end

  return state.was_message_recently_shown(msg_id, n)
end

-- Get a random message for a specific period
function M.get_message_for_period(period)
  ensure_random_seed()

  local opts = config.options.content or {}
  local all_messages = {}  -- Each entry: { id = msg_id, text = msg_text }

  -- Add built-in messages if enabled, filtering disabled ones and themes
  if opts.builtin_messages ~= false then
    local builtin = messages.get_messages_for_period(period)
    for i, m in ipairs(builtin) do
      local msg_id = get_message_id(period, i)
      -- Check if message is disabled OR theme is disabled
      if not config.is_message_disabled(msg_id) and not config.is_theme_disabled(m.theme) then
        -- Check condition function (if present)
        if check_message_condition(m) then
          -- Check no-repeat filter
          if not should_exclude_recent_message(msg_id) then
            -- Add with weighting for favorites
            local weight = config.is_message_favorite(msg_id) and 3 or 1
            for _ = 1, weight do
              table.insert(all_messages, { id = msg_id, text = m.text })
            end
          end
        end
      end
    end
  end

  -- Add custom messages if configured
  if opts.custom_messages and opts.custom_messages[period] then
    for i, m in ipairs(opts.custom_messages[period]) do
      -- Check condition function (if present)
      if check_message_condition(m) then
        local text = extract_message_text(m)
        if text then
          local msg_id = "custom_" .. period .. "_" .. i
          if not should_exclude_recent_message(msg_id) then
            table.insert(all_messages, { id = msg_id, text = text })
          end
        end
      end
    end
  end

  -- Add holiday messages if enabled and a holiday is active
  local holidays_cfg = opts.holidays or {}
  if holidays_cfg.enabled ~= false then
    local active = holidays_mod.get_active_holidays(holidays_cfg.custom)
    local priority = holidays_cfg.priority or 3
    for _, h in ipairs(active) do
      -- Built-in holiday messages
      local h_msgs = holiday_messages.get_messages_for_holiday(h.name)
      for _, m in ipairs(h_msgs) do
        for _ = 1, priority do
          table.insert(all_messages, { id = "holiday_" .. h.name, text = m.text })
        end
      end
      -- Custom holiday message field
      local wrapped = holiday_messages.wrap_custom_message(h)
      if wrapped then
        for _ = 1, priority do
          table.insert(all_messages, { id = "holiday_custom_" .. h.name, text = wrapped.text })
        end
      end
    end
  end

  -- If all messages in this period are filtered out, try other periods
  if #all_messages == 0 then
    local periods = { "morning", "afternoon", "evening", "night", "weekend" }
    for _, p in ipairs(periods) do
      if p ~= period then
        local fallback = messages.get_messages_for_period(p)
        for i, m in ipairs(fallback) do
          local msg_id = get_message_id(p, i)
          if not config.is_message_disabled(msg_id) and not config.is_theme_disabled(m.theme) then
            if not should_exclude_recent_message(msg_id) then
              table.insert(all_messages, { id = msg_id, text = m.text })
            end
          end
        end
        if #all_messages > 0 then break end
      end
    end
  end

  -- Last resort: if still no messages, ignore no-repeat filter
  if #all_messages == 0 then
    if opts.builtin_messages ~= false then
      local builtin = messages.get_messages_for_period(period)
      for i, m in ipairs(builtin) do
        local msg_id = get_message_id(period, i)
        if not config.is_message_disabled(msg_id) and not config.is_theme_disabled(m.theme) then
          table.insert(all_messages, { id = msg_id, text = m.text })
        end
      end
    end
  end

  if #all_messages == 0 then
    return nil
  end

  local selected = all_messages[math.random(#all_messages)]
  -- Record the message as shown
  state.record_message_shown(selected.id)
  -- Process placeholders at render time (handles both string and table)
  return placeholders.process(selected.text)
end

-- Get a complete header (art + message) for the current time period
function M.get_header()
  local art = M.get_art()
  local message = M.get_message()

  return {
    art = art and art.lines or {},
    message = message or "",
    period = time.get_current_period(),
    art_id = art and art.id or nil,
    art_name = art and art.name or nil,
  }
end

-- Get a complete header for a specific period
function M.get_header_for_period(period)
  local art = M.get_art_for_period(period)
  local message = M.get_message_for_period(period)

  return {
    art = art and art.lines or {},
    message = message or "",
    period = period,
    art_id = art and art.id or nil,
    art_name = art and art.name or nil,
  }
end

-- List all art IDs (respects style filter)
function M.list_arts()
  local style_filter = get_style_filter()
  local all_ids = {}
  local seen = {}

  if style_filter == nil then
    for _, id in ipairs(arts.list_art_ids()) do
      if not seen[id] then
        seen[id] = true
        table.insert(all_ids, id)
      end
    end
  else
    -- Collect IDs from all periods with style filtering
    local periods = { "morning", "afternoon", "evening", "night", "weekend" }
    for _, period in ipairs(periods) do
      local period_ids = arts.list_art_ids_for_period(period, style_filter)
      for _, id in ipairs(period_ids) do
        if not seen[id] then
          seen[id] = true
          table.insert(all_ids, id)
        end
      end
    end
  end

  -- Add holiday art IDs
  for _, art in ipairs(holiday_arts.get_all_arts()) do
    if not seen[art.id] then
      seen[art.id] = true
      table.insert(all_ids, art.id)
    end
  end

  -- Add custom dir art IDs
  local dir_arts = load_arts_from_dir()
  for _, art in ipairs(dir_arts.all) do
    if not seen[art.id] then
      seen[art.id] = true
      table.insert(all_ids, art.id)
    end
  end

  return all_ids
end

-- List art IDs for a specific period
function M.list_arts_for_period(period)
  local style_filter = get_style_filter()
  local ids = arts.list_art_ids_for_period(period, style_filter)
  -- Add custom dir arts for this period
  local dir_arts = load_arts_from_dir()
  if dir_arts.by_period[period] then
    for _, art in ipairs(dir_arts.by_period[period]) do
      table.insert(ids, art.id)
    end
  end
  -- Add period-less arts
  for _, art in ipairs(dir_arts.all) do
    if not art.period then
      table.insert(ids, art.id)
    end
  end
  return ids
end

-- Get a specific art by ID
function M.get_art_by_id(id)
  local result = arts.get_art_by_id(id)
  if result then return result end
  -- Search holiday arts
  local h_art = holiday_arts.get_art_by_id(id)
  if h_art then return h_art end
  -- Search custom dir arts
  local dir_arts = load_arts_from_dir()
  for _, art in ipairs(dir_arts.all) do
    if art.id == id then return art end
  end
  return nil
end

-- Get available styles
function M.get_styles()
  return arts.get_styles()
end

-- Expose sub-modules for advanced usage
M.arts = arts
M.messages = messages

return M
