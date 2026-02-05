-- Message registry for ascii-animation
-- Provides access to taglines and messages

local taglines = require("ascii-animation.content.messages.taglines")

local M = {}

-- Expose themes list and names
M.themes = taglines.themes
M.theme_names = taglines.theme_names

-- Get all messages for a specific period (returns objects with text and theme)
function M.get_messages_for_period(period)
  return taglines.messages[period] or {}
end

-- Get message text for a specific period (for backwards compatibility)
function M.get_message_texts_for_period(period)
  local messages = taglines.messages[period] or {}
  local texts = {}
  for _, msg in ipairs(messages) do
    table.insert(texts, msg.text)
  end
  return texts
end

-- Get a random message for a specific period
function M.get_random_message(period)
  local messages = M.get_messages_for_period(period)
  if #messages == 0 then
    return nil
  end
  local msg = messages[math.random(#messages)]
  return msg.text
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

-- Get message count for a specific theme
function M.get_message_count_for_theme(theme)
  local count = 0
  for _, period_messages in pairs(taglines.messages) do
    for _, msg in ipairs(period_messages) do
      if msg.theme == theme then
        count = count + 1
      end
    end
  end
  return count
end

-- Get all messages for a specific theme (across all periods)
function M.get_messages_for_theme(theme)
  local result = {}
  for period, period_messages in pairs(taglines.messages) do
    for i, msg in ipairs(period_messages) do
      if msg.theme == theme then
        table.insert(result, {
          text = msg.text,
          theme = msg.theme,
          period = period,
          index = i,
        })
      end
    end
  end
  return result
end

return M
