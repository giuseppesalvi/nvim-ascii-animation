-- Pixel art ASCII arts
-- Retro 8-bit style graphics using block characters

local M = {}

M.arts = {
  morning = {
    {
      id = "morning_pixel_1",
      name = "Pixel Sunrise",
      lines = {
        "                    ▄▄████▄▄",
        "                 ▄██████████▄",
        "              ▄████  GOOD  ████▄",
        "            ▄██  MORNING   ██▄",
        "         ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
        "        ▄ ▄ ▄ ▄ ▄ ▄ ▄ ▄ ▄ ▄ ▄ ▄ ▄",
      },
    },
    {
      id = "morning_pixel_2",
      name = "Pixel Coffee",
      lines = {
        "           ▄▄▄▄▄▄▄▄▄",
        "          █ COFFEE █▄▄",
        "          █  TIME  █  █",
        "          █▄▄▄▄▄▄▄█▄▄█",
        "          ███████████",
        "            ███████",
      },
    },
    {
      id = "morning_pixel_3",
      name = "Pixel Sun",
      lines = {
        "              ▄ ▄ ▄",
        "           ▄ ▄███▄ ▄",
        "          ▄██████▄",
        "           ▄█████▄",
        "           ▀ ▀█▀ ▀",
        "            RISE",
      },
    },
    {
      id = "morning_pixel_4",
      name = "Pixel Dawn",
      lines = {
        "     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░",
        "     ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░",
        "     ░░▓▓  D A W N   C O D E  ▓▓░░",
        "     ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░",
        "     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░",
      },
    },
    {
      id = "morning_pixel_5",
      name = "Pixel Boot",
      lines = {
        "       ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄",
        "       █ BOOTING NEW DAY...  █",
        "       █ ██████████████░░░░░ █",
        "       ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
      },
    },
    {
      id = "morning_pixel_6",
      name = "Pixel Rising Sun",
      lines = {
        "           ·   ▄███▄   ·",
        "             ▄███████▄",
        "         ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
        "          ~   ~   ~   ~   ~",
        "          H E L L O   S U N",
      },
    },
  },

  afternoon = {
    {
      id = "afternoon_pixel_1",
      name = "Pixel Midday",
      lines = {
        "       ████████████████████████",
        "       █                      █",
        "       █   A F T E R N O O N  █",
        "       █   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄   █",
        "       █                      █",
        "       ████████████████████████",
      },
    },
    {
      id = "afternoon_pixel_2",
      name = "Pixel Focus",
      lines = {
        "          ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
        "         ▐  F O C U S    ▌",
        "         ▐  ▄▄▄▄▄▄▄▄▄   ▌",
        "         ▐  █ ◉   ◉ █   ▌",
        "         ▐  █▄▄▄▄▄▄▄█   ▌",
        "          ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄",
      },
    },
    {
      id = "afternoon_pixel_3",
      name = "Pixel Zone",
      lines = {
        "      ░▒▓█ IN THE ZONE █▓▒░",
        "      ░▒▓██████████████▓▒░",
        "      ░▒▓█            █▓▒░",
        "      ░▒▓█  ◀ CODE ▶  █▓▒░",
        "      ░▒▓██████████████▓▒░",
      },
    },
    {
      id = "afternoon_pixel_4",
      name = "Pixel Flow",
      lines = {
        "        ████▄    ▄████",
        "        █▀▀▀█▄▄▄█▀▀▀█",
        "        █ FLOW  STATE █",
        "        █▄▄▄█▀▀▀█▄▄▄█",
        "        ████▀    ▀████",
      },
    },
    {
      id = "afternoon_pixel_5",
      name = "Pixel Power",
      lines = {
        "            ▄██▀",
        "           ▄██▀",
        "          ▄█████▀",
        "             ▄██▀",
        "            ▄█▀",
        "           ▀▀",
        "        F U L L   P O W E R",
      },
    },
    {
      id = "afternoon_pixel_6",
      name = "Pixel Target",
      lines = {
        "          ▄▄█████▄▄",
        "         ██▀     ▀██",
        "        ██    ◉    ██",
        "         ██▄     ▄██",
        "          ▀▀█████▀▀",
        "       O N   T A R G E T",
      },
    },
  },

  evening = {
    {
      id = "evening_pixel_1",
      name = "Pixel Sunset",
      lines = {
        "      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄",
        "      ██ E V E N I N G ██",
        "      ██▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓██",
        "      ██░░░░░░░░░░░░░░░░░░░░██",
        "      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
      },
    },
    {
      id = "evening_pixel_2",
      name = "Pixel Dusk",
      lines = {
        "           ▄████████▄",
        "          █▀▀▀▀▀▀▀▀▀▀█",
        "          █  D U S K  █",
        "          █▄▄▄▄▄▄▄▄▄▄█",
        "           ▀████████▀",
      },
    },
    {
      id = "evening_pixel_3",
      name = "Pixel Twilight",
      lines = {
        "       ░░░░░░░░░░░░░░░░░░░░░░░",
        "       ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░",
        "       ░░▓ TWILIGHT  ZONE ▓░░",
        "       ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░",
        "       ░░░░░░░░░░░░░░░░░░░░░░░",
      },
    },
    {
      id = "evening_pixel_4",
      name = "Pixel Moon Rise",
      lines = {
        "            ▄▄████▄▄",
        "          ▄██▀    ▀██▄",
        "          ██ ◐ MOON ██",
        "          ▀██▄    ▄██▀",
        "            ▀▀████▀▀",
      },
    },
    {
      id = "evening_pixel_5",
      name = "Pixel Save",
      lines = {
        "        ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄",
        "        █  ▀▀▀▀▀▀▀▀▀  █",
        "        █             █",
        "        █  █▀▀▀▀▀▀▀█  █",
        "        █  █▄▄▄▄▄▄▄█  █",
        "        ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
        "       S A V E  &  Q U I T",
      },
    },
    {
      id = "evening_pixel_6",
      name = "Pixel Fireside",
      lines = {
        "             ▄ ▄",
        "            ▄███▄",
        "           ▄█████▄",
        "            █████",
        "          ▄▄▀███▀▄▄",
        "         ▀▀▀▀▀▀▀▀▀▀▀",
        "        F I R E S I D E",
      },
    },
  },

  night = {
    {
      id = "night_pixel_1",
      name = "Pixel Night",
      lines = {
        "      ★  ·    ★        ·   ★",
        "       ████████████████████",
        "       █  N I G H T   █",
        "       █  O W L       █",
        "       ████████████████████",
        "         ·    ★    ·    ★",
      },
    },
    {
      id = "night_pixel_2",
      name = "Pixel Stars",
      lines = {
        "      ·  ★  ·  ·  ★  ·  ★  ·",
        "         ▄▄▄▄▄▄▄▄▄▄▄▄▄",
        "         █ MIDNIGHT █",
        "         █  C O D E █",
        "         ▀▀▀▀▀▀▀▀▀▀▀▀▀",
        "      ★  ·  ★  ·  ·  ★  ·  ★",
      },
    },
    {
      id = "night_pixel_3",
      name = "Pixel Silence",
      lines = {
        "       ░░░░░░░░░░░░░░░░░░░░░",
        "       ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░",
        "       ░░▓  S I L E N T  ▓░░",
        "       ░░▓  F O C U S    ▓░░",
        "       ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░",
        "       ░░░░░░░░░░░░░░░░░░░░░",
      },
    },
    {
      id = "night_pixel_4",
      name = "Pixel Dreams",
      lines = {
        "         ★    ·    ★",
        "        ▄██████████▄",
        "        █ D R E A M █",
        "        █  C O D E  █",
        "        ▀██████████▀",
        "         ·    ★    ·",
      },
    },
    {
      id = "night_pixel_5",
      name = "Pixel Terminal",
      lines = {
        "        ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄",
        "        █ > nvim .      █",
        "        █ > code_       █",
        "        ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
        "        ★  3 A M  M O D E  ·",
      },
    },
    {
      id = "night_pixel_6",
      name = "Pixel Crescent",
      lines = {
        "        ·      ▄███     ★",
        "              ███▀",
        "       ★      ███          ·",
        "              ███▄",
        "        ·      ▀███    ★",
        "        S L E E P   L A T E R",
      },
    },
  },

  weekend = {
    {
      id = "weekend_pixel_1",
      name = "Pixel Weekend",
      lines = {
        "      ████████████████████████████",
        "      █                          █",
        "      █   W E E K E N D   !      █",
        "      █   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀       █",
        "      █                          █",
        "      ████████████████████████████",
      },
    },
    {
      id = "weekend_pixel_2",
      name = "Pixel Projects",
      lines = {
        "          ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄",
        "          █  S  I  D  E    █",
        "          █ P R O J E C T █",
        "          █  T  I  M  E   █",
        "          ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀",
      },
    },
    {
      id = "weekend_pixel_3",
      name = "Pixel Freedom",
      lines = {
        "       ░▒▓█ F R E E D O M █▓▒░",
        "       ░▒▓████████████████▓▒░",
        "       ░▒▓█              █▓▒░",
        "       ░▒▓█  ◀ PLAY ▶    █▓▒░",
        "       ░▒▓████████████████▓▒░",
      },
    },
    {
      id = "weekend_pixel_4",
      name = "Pixel Relax",
      lines = {
        "        ████▄      ▄████",
        "        █▀▀▀██████▀▀▀█",
        "        █  NO RULES   █",
        "        █  JUST CODE  █",
        "        █▄▄▄██████▄▄▄█",
        "        ████▀      ▀████",
      },
    },
    {
      id = "weekend_pixel_5",
      name = "Pixel Invader",
      lines = {
        "          ▀▄   ▄▀",
        "         ▄█▀███▀█▄",
        "        █▀███████▀█",
        "        █ █▀▀▀▀▀█ █",
        "           ▀▀ ▀▀",
        "       I N S E R T   C O I N",
      },
    },
    {
      id = "weekend_pixel_6",
      name = "Pixel Heart",
      lines = {
        "        ▄███▄ ▄███▄",
        "        ███████████",
        "         ▀███████▀",
        "           ▀███▀",
        "             ▀",
        "       R E S T  &  P L A Y",
      },
    },
  },
}

return M
