-- Holiday-themed taglines for ascii-animation
-- Themed messages for built-in holidays

local M = {}

M.messages = {
  xmas = {
    { text = "Merry Christmas!", theme = "holiday" },
    { text = "Ho ho ho! Time to code!", theme = "holiday" },
    { text = "Tis the season to ship features.", theme = "holiday" },
    { text = "All I want for Christmas is clean code.", theme = "holiday" },
  },

  halloween = {
    { text = "Happy Halloween!", theme = "holiday" },
    { text = "Boo! No bugs here... right?", theme = "holiday" },
    { text = "Something spooky lurks in the codebase.", theme = "holiday" },
  },

  valentines = {
    { text = "Happy Valentine's Day!", theme = "holiday" },
    { text = "Code is my love language.", theme = "holiday" },
    { text = "You and Neovim: a perfect match.", theme = "holiday" },
  },

  new_year = {
    { text = "Happy New Year!", theme = "holiday" },
    { text = "New year, new codebase.", theme = "holiday" },
    { text = "Resolution: write better tests.", theme = "holiday" },
  },

  new_year_eve = {
    { text = "Happy New Year's Eve!", theme = "holiday" },
    { text = "One last commit before midnight.", theme = "holiday" },
    { text = "Counting down to a fresh start.", theme = "holiday" },
  },

  any = {
    { text = "Happy holidays!", theme = "holiday" },
    { text = "Time to celebrate!", theme = "holiday" },
    { text = "Today is a special day.", theme = "holiday" },
  },
}

-- Get messages for a specific holiday (returns specific + any fallback)
function M.get_messages_for_holiday(name)
  local result = {}
  if M.messages[name] then
    for _, msg in ipairs(M.messages[name]) do
      table.insert(result, msg)
    end
  end
  if M.messages.any then
    for _, msg in ipairs(M.messages.any) do
      table.insert(result, msg)
    end
  end
  return result
end

-- Wrap a custom holiday's message field into message format
function M.wrap_custom_message(entry)
  if entry.message then
    return { text = entry.message, theme = "holiday" }
  end
  return nil
end

return M
