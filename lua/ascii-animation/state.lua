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

return M
