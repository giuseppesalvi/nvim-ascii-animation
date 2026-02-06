-- Holiday detection for ascii-animation
-- Detects active holidays based on current date

local M = {}

-- Built-in holiday calendar
M.builtin_calendar = {
  {
    name = "new_year",
    display_name = "New Year's Day",
    month = 1,
    day = 1,
  },
  {
    name = "valentines",
    display_name = "Valentine's Day",
    month = 2,
    day = 14,
  },
  {
    name = "halloween",
    display_name = "Halloween",
    month = 10,
    day = 31,
  },
  {
    name = "xmas",
    display_name = "Christmas",
    from = { month = 12, day = 24 },
    to = { month = 12, day = 26 },
  },
  {
    name = "new_year_eve",
    display_name = "New Year's Eve",
    month = 12,
    day = 31,
  },
}

-- Day-of-year cache to avoid recalculation
local last_doy = nil
local cached_result = nil

-- Check if an entry matches a given month/day
local function matches_date(entry, month, day)
  if entry.from and entry.to then
    -- Range check
    local from_val = entry.from.month * 100 + entry.from.day
    local to_val = entry.to.month * 100 + entry.to.day
    local cur_val = month * 100 + day
    return cur_val >= from_val and cur_val <= to_val
  else
    -- Single day
    return entry.month == month and entry.day == day
  end
end

-- Get list of active holidays (builtin + custom)
function M.get_active_holidays(custom_calendar)
  local now = os.date("*t")
  local doy = now.yday

  -- Return cached result if same day
  if doy == last_doy and cached_result then
    return cached_result
  end

  local month = now.month
  local day = now.day
  local active = {}

  -- Check built-in holidays
  for _, entry in ipairs(M.builtin_calendar) do
    if matches_date(entry, month, day) then
      table.insert(active, entry)
    end
  end

  -- Check custom holidays
  if custom_calendar then
    for _, entry in ipairs(custom_calendar) do
      if matches_date(entry, month, day) then
        table.insert(active, entry)
      end
    end
  end

  -- Cache result
  last_doy = doy
  cached_result = active

  return active
end

-- Check if today is a holiday
function M.is_holiday(custom_calendar)
  return #M.get_active_holidays(custom_calendar) > 0
end

-- Get names of active holidays
function M.get_active_holiday_names(custom_calendar)
  local active = M.get_active_holidays(custom_calendar)
  local names = {}
  for _, entry in ipairs(active) do
    table.insert(names, entry.name)
  end
  return names
end

return M
