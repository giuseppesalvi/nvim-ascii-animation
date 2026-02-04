-- Time period detection for ascii-animation
local config = require("ascii-animation.config")

local M = {}

-- Get the current time period based on hour and day of week
function M.get_current_period()
  local hour = tonumber(os.date("%H"))
  local day = tonumber(os.date("%w")) -- 0 = Sunday, 6 = Saturday
  local is_weekend = (day == 0 or day == 6)

  local opts = config.options.content or {}
  local time_periods = opts.time_periods or config.defaults.content.time_periods

  -- Check weekend override first
  if is_weekend and (opts.weekend_override ~= false) then
    return "weekend"
  end

  -- Check each time period
  for period, times in pairs(time_periods) do
    if period ~= "weekend" then
      local start_hour = times.start
      local stop_hour = times.stop

      -- Handle overnight periods (e.g., night: 21-5)
      if start_hour > stop_hour then
        if hour >= start_hour or hour < stop_hour then
          return period
        end
      else
        if hour >= start_hour and hour < stop_hour then
          return period
        end
      end
    end
  end

  -- Default fallback
  return "morning"
end

-- Check if current time is within a specific period
function M.is_period(period)
  return M.get_current_period() == period
end

-- Get all available periods
function M.get_periods()
  return { "morning", "afternoon", "evening", "night", "weekend" }
end

return M
