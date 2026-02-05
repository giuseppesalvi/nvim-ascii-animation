-- State persistence for ascii-animation
-- Handles tracking of shown arts and session seeds

local M = {}

-- State file path
local state_path = vim.fn.stdpath("state") .. "/ascii-animation.json"

-- In-memory session seed (persists only within Neovim session)
local session_seed = nil

-- Load state from file
function M.load()
  local file = io.open(state_path, "r")
  if not file then
    return {}
  end

  local content = file:read("*a")
  file:close()

  local ok, state = pcall(vim.fn.json_decode, content)
  if not ok or type(state) ~= "table" then
    return {}
  end

  return state
end

-- Save state to file
function M.save(state)
  -- Ensure parent directory exists
  local parent = vim.fn.fnamemodify(state_path, ":h")
  vim.fn.mkdir(parent, "p")

  local ok, json = pcall(vim.fn.json_encode, state)
  if not ok then
    return false
  end

  local file = io.open(state_path, "w")
  if not file then
    return false
  end

  file:write(json)
  file:close()
  return true
end

-- Record that an art was shown
function M.record_art_shown(art_id)
  if not art_id then
    return
  end

  local state = M.load()
  local today = os.date("%Y-%m-%d")

  state.last_art_id = art_id
  state.last_art_date = today

  -- Initialize recent_arts if needed
  if type(state.recent_arts) ~= "table" then
    state.recent_arts = {}
  end

  -- Add to front of recent_arts (most recent first)
  -- Remove if already exists to avoid duplicates
  local new_recent = { art_id }
  for _, id in ipairs(state.recent_arts) do
    if id ~= art_id then
      table.insert(new_recent, id)
    end
  end

  -- Keep only last 50 entries
  state.recent_arts = {}
  for i = 1, math.min(50, #new_recent) do
    state.recent_arts[i] = new_recent[i]
  end

  M.save(state)
end

-- Check if art was shown in last N sessions
function M.was_recently_shown(art_id, n)
  if not art_id or not n or n <= 0 then
    return false
  end

  local state = M.load()
  if type(state.recent_arts) ~= "table" then
    return false
  end

  -- Check first N entries
  for i = 1, math.min(n, #state.recent_arts) do
    if state.recent_arts[i] == art_id then
      return true
    end
  end

  return false
end

-- Get the last shown art ID
function M.get_last_art_id()
  local state = M.load()
  return state.last_art_id
end

-- Get the date of the last shown art
function M.get_last_art_date()
  local state = M.load()
  return state.last_art_date
end

-- Get or create session seed (persists within Neovim session only)
function M.get_session_seed()
  if not session_seed then
    session_seed = os.time() + math.floor(os.clock() * 1000)
  end
  return session_seed
end

-- Get daily seed (same value for entire day)
function M.get_daily_seed()
  return tonumber(os.date("%Y%m%d"))
end

-- Record that a message was shown
function M.record_message_shown(msg_id)
  if not msg_id then
    return
  end

  local state = M.load()

  -- Initialize recent_messages if needed
  if type(state.recent_messages) ~= "table" then
    state.recent_messages = {}
  end

  -- Add to front of recent_messages (most recent first)
  -- Remove if already exists to avoid duplicates
  local new_recent = { msg_id }
  for _, id in ipairs(state.recent_messages) do
    if id ~= msg_id then
      table.insert(new_recent, id)
    end
  end

  -- Keep only last 20 entries (messages are shown more frequently than arts)
  state.recent_messages = {}
  for i = 1, math.min(20, #new_recent) do
    state.recent_messages[i] = new_recent[i]
  end

  M.save(state)
end

-- Check if message was shown in last N displays
function M.was_message_recently_shown(msg_id, n)
  if not msg_id or not n or n <= 0 then
    return false
  end

  local state = M.load()
  if type(state.recent_messages) ~= "table" then
    return false
  end

  -- Check first N entries
  for i = 1, math.min(n, #state.recent_messages) do
    if state.recent_messages[i] == msg_id then
      return true
    end
  end

  return false
end

-- Get the last shown message ID
function M.get_last_message_id()
  local state = M.load()
  if type(state.recent_messages) == "table" and #state.recent_messages > 0 then
    return state.recent_messages[1]
  end
  return nil
end

-- Get recent message IDs (up to n)
function M.get_recent_messages(n)
  local state = M.load()
  if type(state.recent_messages) ~= "table" then
    return {}
  end

  local result = {}
  for i = 1, math.min(n or 10, #state.recent_messages) do
    table.insert(result, state.recent_messages[i])
  end
  return result
end

-- Record a usage date for streak tracking
function M.record_usage_date(date)
  date = date or os.date("%Y-%m-%d")
  local state = M.load()

  if type(state.streak_dates) ~= "table" then
    state.streak_dates = {}
  end

  -- Don't add duplicates
  for _, d in ipairs(state.streak_dates) do
    if d == date then
      return
    end
  end

  -- Insert at front (most recent first)
  table.insert(state.streak_dates, 1, date)

  -- Keep only last 365 entries
  if #state.streak_dates > 365 then
    local trimmed = {}
    for i = 1, 365 do
      trimmed[i] = state.streak_dates[i]
    end
    state.streak_dates = trimmed
  end

  M.save(state)
end

-- Count consecutive usage days ending with today or yesterday
function M.get_streak_count()
  local state = M.load()
  if type(state.streak_dates) ~= "table" or #state.streak_dates == 0 then
    return 0
  end

  local today = os.date("%Y-%m-%d")

  -- Convert date string to os.time for day arithmetic
  local function date_to_time(d)
    local y, m, day = d:match("(%d+)-(%d+)-(%d+)")
    if not y then
      return nil
    end
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(day), hour = 12 })
  end

  -- Build a set of dates for fast lookup
  local date_set = {}
  for _, d in ipairs(state.streak_dates) do
    date_set[d] = true
  end

  -- Start counting from today (or yesterday if today not recorded yet)
  local start_time = date_to_time(today)
  if not start_time then
    return 0
  end

  local streak = 0
  if date_set[today] then
    streak = 1
  elseif date_set[os.date("%Y-%m-%d", start_time - 86400)] then
    -- Start from yesterday
    start_time = start_time - 86400
    streak = 1
  else
    return 0
  end

  -- Count consecutive days backwards
  local check_time = start_time - 86400
  while true do
    local check_date = os.date("%Y-%m-%d", check_time)
    if date_set[check_date] then
      streak = streak + 1
      check_time = check_time - 86400
    else
      break
    end
  end

  return streak
end

return M
