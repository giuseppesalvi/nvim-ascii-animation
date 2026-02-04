-- Art registry for ascii-animation
-- Combines all art modules and provides lookup/filtering

local blocks = require("ascii-animation.content.arts.blocks")
local gradient = require("ascii-animation.content.arts.gradient")
local isometric = require("ascii-animation.content.arts.isometric")

local M = {}

-- Style mappings
M.styles = {
  blocks = blocks.arts,
  gradient = gradient.arts,
  isometric = isometric.arts,
}

-- Get all arts for a specific period, optionally filtered by styles
function M.get_arts_for_period(period, style_filter)
  local arts = {}

  local styles_to_use = style_filter or { "blocks", "gradient", "isometric" }

  for _, style in ipairs(styles_to_use) do
    local style_arts = M.styles[style]
    if style_arts and style_arts[period] then
      for _, art in ipairs(style_arts[period]) do
        table.insert(arts, art)
      end
    end
  end

  return arts
end

-- Get a random art for a specific period
function M.get_random_art(period, style_filter)
  local arts = M.get_arts_for_period(period, style_filter)
  if #arts == 0 then
    return nil
  end
  return arts[math.random(#arts)]
end

-- Get art by ID
function M.get_art_by_id(id)
  for _, style_arts in pairs(M.styles) do
    for _, period_arts in pairs(style_arts) do
      for _, art in ipairs(period_arts) do
        if art.id == id then
          return art
        end
      end
    end
  end
  return nil
end

-- List all art IDs
function M.list_art_ids()
  local ids = {}
  for _, style_arts in pairs(M.styles) do
    for _, period_arts in pairs(style_arts) do
      for _, art in ipairs(period_arts) do
        table.insert(ids, art.id)
      end
    end
  end
  return ids
end

-- List art IDs for a specific period
function M.list_art_ids_for_period(period, style_filter)
  local ids = {}
  local arts = M.get_arts_for_period(period, style_filter)
  for _, art in ipairs(arts) do
    table.insert(ids, art.id)
  end
  return ids
end

-- Get available styles
function M.get_styles()
  return { "blocks", "gradient", "isometric" }
end

-- Calculate the display width of an art
function M.get_art_width(art)
  if not art or not art.lines then
    return 0
  end

  local max_width = 0
  for _, line in ipairs(art.lines) do
    local width = vim.fn.strdisplaywidth(line)
    if width > max_width then
      max_width = width
    end
  end
  return max_width
end

return M
