-- Message registry for ascii-animation
-- Provides access to taglines and messages

local taglines = require("ascii-animation.content.messages.taglines")

local M = {}

-- Get all messages for a specific period
function M.get_messages_for_period(period)
  return taglines.messages[period] or {}
end

-- Get a random message for a specific period
function M.get_random_message(period)
  local messages = M.get_messages_for_period(period)
  if #messages == 0 then
    return nil
  end
  return messages[math.random(#messages)]
end

-- Get all available periods
function M.get_periods()
  local periods = {}
  for period, _ in pairs(taglines.messages) do
    table.insert(periods, period)
  end
  return periods
end

-- Get total message count
function M.get_message_count()
  local count = 0
  for _, messages in pairs(taglines.messages) do
    count = count + #messages
  end
  return count
end

-- Get message count for a specific period
function M.get_message_count_for_period(period)
  local messages = taglines.messages[period]
  return messages and #messages or 0
end

return M
