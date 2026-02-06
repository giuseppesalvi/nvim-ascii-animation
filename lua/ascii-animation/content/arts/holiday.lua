-- Holiday-themed ASCII arts
-- Themed art for built-in holidays

local M = {}

M.arts = {
  xmas = {
    {
      id = "holiday_xmas_1",
      name = "Christmas Tree",
      style = "holiday",
      lines = {
        "",
        "                        ★",
        "                       /|\\",
        "                      / | \\",
        "                     /  |  \\",
        "                    /  -o-  \\",
        "                   /   / \\   \\",
        "                  /  -o- -o-  \\",
        "                 /   / \\   / \\  \\",
        "                /  -o- -o- -o-  \\",
        "                    |     |",
        "                    |_____|",
        "",
      },
    },
    {
      id = "holiday_xmas_2",
      name = "Merry Christmas",
      style = "holiday",
      lines = {
        "",
        "        ╔══════════════════════════════╗",
        "        ║                              ║",
        "        ║    M E R R Y                 ║",
        "        ║        C H R I S T M A S     ║",
        "        ║                              ║",
        "        ╚══════════════════════════════╝",
        "",
      },
    },
  },

  halloween = {
    {
      id = "holiday_halloween_1",
      name = "Jack-o-Lantern",
      style = "holiday",
      lines = {
        "",
        "                   ___     ",
        "                  /   \\    ",
        "                 | ^ ^ |   ",
        "                 |  o  |   ",
        "                 | \\_/ |   ",
        "                  \\___/    ",
        "",
      },
    },
    {
      id = "holiday_halloween_2",
      name = "Spooky Night",
      style = "holiday",
      lines = {
        "",
        "         .  *  .    *    .  *  .",
        "            ___",
        "        .-'`   `'-.",
        "       /  ^ \\/ ^   \\     BOO!",
        "      |   (o  o)    |",
        "       \\  .--'--.  /",
        "        '-._____.-'",
        "         .  *  .    *    .  *  .",
        "",
      },
    },
  },

  valentines = {
    {
      id = "holiday_valentines_1",
      name = "Heart",
      style = "holiday",
      lines = {
        "",
        "               **       **",
        "             ****       ****",
        "            *****       *****",
        "             *****     *****",
        "              *****   *****",
        "                **** ****",
        "                  *****",
        "                   ***",
        "                    *",
        "",
      },
    },
  },

  new_year = {
    {
      id = "holiday_new_year_1",
      name = "Happy New Year",
      style = "holiday",
      lines = {
        "",
        "        ╔══════════════════════════════╗",
        "        ║                              ║",
        "        ║   H A P P Y                  ║",
        "        ║       N E W   Y E A R !      ║",
        "        ║                              ║",
        "        ╚══════════════════════════════╝",
        "",
      },
    },
  },

  new_year_eve = {
    {
      id = "holiday_nye_1",
      name = "Countdown",
      style = "holiday",
      lines = {
        "",
        "           *  .  *  .  *  .  *  .  *",
        "",
        "              N E W   Y E A R ' S",
        "                   E V E",
        "",
        "           *  .  *  .  *  .  *  .  *",
        "",
      },
    },
  },

  any = {
    {
      id = "holiday_celebrate_1",
      name = "Celebration",
      style = "holiday",
      lines = {
        "",
        "          *  .  *  .  *  .  *  .  *",
        "            .     .     .     .    ",
        "          *    C E L E B R A T E   *",
        "            .     .     .     .    ",
        "          *  .  *  .  *  .  *  .  *",
        "",
      },
    },
  },
}

-- Get arts for a specific holiday (returns specific + any fallback)
function M.get_arts_for_holiday(name)
  local result = {}
  if M.arts[name] then
    for _, art in ipairs(M.arts[name]) do
      table.insert(result, art)
    end
  end
  if M.arts.any then
    for _, art in ipairs(M.arts.any) do
      table.insert(result, art)
    end
  end
  return result
end

-- Get all holiday arts
function M.get_all_arts()
  local result = {}
  for _, holiday_arts in pairs(M.arts) do
    for _, art in ipairs(holiday_arts) do
      table.insert(result, art)
    end
  end
  return result
end

-- Get a specific art by ID
function M.get_art_by_id(id)
  for _, holiday_arts in pairs(M.arts) do
    for _, art in ipairs(holiday_arts) do
      if art.id == id then
        return art
      end
    end
  end
  return nil
end

return M
