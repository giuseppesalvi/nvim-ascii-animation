-- Placeholder resolution for ascii-animation
-- Replaces tokens like {name}, {project}, etc. with dynamic values

local config = require("ascii-animation.config")
local time = require("ascii-animation.time")

local M = {}

-- Cache for values that don't change during session
local value_cache = {}

-- Get user name from config or git
local function get_name()
  -- Check config first
  local opts = config.options.content or {}
  local placeholders = opts.placeholders or {}
  if placeholders.name then
    return placeholders.name
  end

  -- Try to get from git config
  if value_cache.git_name == nil then
    local handle = io.popen("git config user.name 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      result = result:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
      value_cache.git_name = result ~= "" and result or false
    else
      value_cache.git_name = false
    end
  end

  return value_cache.git_name or nil
end

-- Get current project/directory name
local function get_project()
  -- Check config first
  local opts = config.options.content or {}
  local placeholders = opts.placeholders or {}
  if placeholders.project then
    return placeholders.project
  end

  -- Get from current working directory
  local cwd = vim.fn.getcwd()
  return vim.fn.fnamemodify(cwd, ":t")
end

-- Get time-based greeting
local function get_time_greeting()
  local period = time.get_current_period()
  local greetings = {
    morning = "morning",
    afternoon = "afternoon",
    evening = "evening",
    night = "night",
    weekend = "weekend",
  }
  return greetings[period] or "day"
end

-- Get current date
local function get_date()
  -- Check config for custom format
  local opts = config.options.content or {}
  local placeholders = opts.placeholders or {}
  local format = placeholders.date_format or "%B %d, %Y"
  return os.date(format)
end

-- Get Neovim version
local function get_version()
  if value_cache.nvim_version == nil then
    local v = vim.version()
    value_cache.nvim_version = string.format("v%d.%d.%d", v.major, v.minor, v.patch)
  end
  return value_cache.nvim_version
end

-- Get number of loaded plugins
local function get_plugin_count()
  -- Try lazy.nvim first
  local ok, lazy = pcall(require, "lazy")
  if ok and lazy.stats then
    local stats = lazy.stats()
    return tostring(stats.count or 0)
  end

  -- Try packer.nvim
  local packer_ok, packer_plugins = pcall(function()
    return _G.packer_plugins
  end)
  if packer_ok and packer_plugins then
    local count = 0
    for _ in pairs(packer_plugins) do
      count = count + 1
    end
    return tostring(count)
  end

  -- Count loaded packages as fallback
  local count = 0
  for _ in pairs(package.loaded) do
    count = count + 1
  end
  return tostring(count)
end

-- Placeholder resolvers
local resolvers = {
  name = get_name,
  project = get_project,
  time = get_time_greeting,
  date = get_date,
  version = get_version,
  plugin_count = get_plugin_count,
}

-- Resolve a single placeholder
function M.resolve(placeholder)
  local resolver = resolvers[placeholder]
  if resolver then
    return resolver()
  end

  -- Check custom placeholders in config
  local opts = config.options.content or {}
  local custom = opts.placeholders or {}
  return custom[placeholder]
end

-- Process a single line string and replace all placeholders
local function process_line(text)
  if not text or type(text) ~= "string" then
    return text
  end

  -- Find and replace all {placeholder} patterns
  return text:gsub("{(%w+)}", function(placeholder)
    local value = M.resolve(placeholder)
    if value then
      return value
    else
      -- Remove unresolved placeholders
      return ""
    end
  end)
end

-- Process a string or table of strings and replace all placeholders
-- Returns: string for single-line, table of strings for multi-line
function M.process(text)
  if not text then
    return text
  end

  -- Handle table of lines (multi-line message)
  if type(text) == "table" then
    local processed = {}
    for _, line in ipairs(text) do
      table.insert(processed, process_line(line))
    end
    return processed
  end

  -- Handle single string
  return process_line(text)
end

-- Check if a message is multi-line
function M.is_multiline(text)
  return type(text) == "table"
end

-- Flatten a message to a single string (for display contexts that need it)
-- separator defaults to newline
function M.flatten(text, separator)
  if not text then
    return ""
  end
  if type(text) == "string" then
    return text
  end
  separator = separator or "\n"
  return table.concat(text, separator)
end

-- Clear the value cache (useful for testing or refreshing)
function M.clear_cache()
  value_cache = {}
end

-- Get list of available placeholder names
function M.list_placeholders()
  return { "name", "project", "time", "date", "version", "plugin_count" }
end

return M
