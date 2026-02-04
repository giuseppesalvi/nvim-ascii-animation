-- Content manager for ascii-animation
-- Provides unified access to arts and messages

local config = require("ascii-animation.config")
local time = require("ascii-animation.time")
local arts = require("ascii-animation.content.arts")
local messages = require("ascii-animation.content.messages")
local state = require("ascii-animation.state")
local placeholders = require("ascii-animation.placeholders")

local M = {}

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

  local terminal_width = vim.o.columns
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

-- Get style filter from config
local function get_style_filter()
  local opts = config.options.content or {}
  return opts.styles
end

-- Get a random art for the current time period
function M.get_art()
  ensure_random_seed()
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

-- Get a random message for a specific period
function M.get_message_for_period(period)
  ensure_random_seed()

  local opts = config.options.content or {}
  local all_messages = {}

  -- Add built-in messages if enabled
  if opts.builtin_messages ~= false then
    local builtin = messages.get_messages_for_period(period)
    for _, m in ipairs(builtin) do
      table.insert(all_messages, m)
    end
  end

  -- Add custom messages if configured
  if opts.custom_messages and opts.custom_messages[period] then
    for _, m in ipairs(opts.custom_messages[period]) do
      table.insert(all_messages, m)
    end
  end

  if #all_messages == 0 then
    return nil
  end

  local message = all_messages[math.random(#all_messages)]
  -- Process placeholders at render time
  return placeholders.process(message)
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

-- List all art IDs
function M.list_arts()
  return arts.list_art_ids()
end

-- List art IDs for a specific period
function M.list_arts_for_period(period)
  local style_filter = get_style_filter()
  return arts.list_art_ids_for_period(period, style_filter)
end

-- Get a specific art by ID
function M.get_art_by_id(id)
  return arts.get_art_by_id(id)
end

-- Get available styles
function M.get_styles()
  return arts.get_styles()
end

-- Expose sub-modules for advanced usage
M.arts = arts
M.messages = messages

return M
