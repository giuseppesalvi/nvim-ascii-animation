-- Content manager for ascii-animation
-- Provides unified access to arts and messages

local config = require("ascii-animation.config")
local time = require("ascii-animation.time")
local arts = require("ascii-animation.content.arts")
local messages = require("ascii-animation.content.messages")

local M = {}

-- Initialize random seed
local function ensure_random_seed()
  math.randomseed(os.time() + math.floor(os.clock() * 1000))
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
  local art = arts.get_random_art(period, style_filter)

  -- Include custom arts if configured
  local opts = config.options.content or {}
  if opts.custom_arts and opts.custom_arts[period] then
    local all_arts = {}

    -- Add built-in arts if enabled
    if opts.builtin_arts ~= false then
      local builtin = arts.get_arts_for_period(period, style_filter)
      for _, a in ipairs(builtin) do
        table.insert(all_arts, a)
      end
    end

    -- Add custom arts
    for _, a in ipairs(opts.custom_arts[period]) do
      table.insert(all_arts, a)
    end

    if #all_arts > 0 then
      return all_arts[math.random(#all_arts)]
    end
  end

  return art
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

  return all_messages[math.random(#all_messages)]
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
