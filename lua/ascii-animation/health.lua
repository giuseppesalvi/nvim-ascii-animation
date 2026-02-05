-- Health check module for :checkhealth ascii-animation
local M = {}

-- Core modules that must load for the plugin to work
local CORE_MODULES = {
  "ascii-animation",
  "ascii-animation.config",
  "ascii-animation.animation",
  "ascii-animation.commands",
  "ascii-animation.content",
  "ascii-animation.content.arts",
  "ascii-animation.content.messages",
  "ascii-animation.time",
  "ascii-animation.state",
  "ascii-animation.placeholders",
}

-- Dashboard integrations to detect
local INTEGRATIONS = {
  { name = "snacks.nvim", module = "snacks" },
  { name = "alpha.nvim", module = "alpha" },
  { name = "dashboard-nvim", module = "dashboard" },
  { name = "lazy.nvim", module = "lazy" },
}

-- Minimum recommended terminal width for ASCII art
local MIN_TERMINAL_WIDTH = 60
local RECOMMENDED_TERMINAL_WIDTH = 80

--- Check if all core modules load without error
local function check_modules()
  vim.health.start("Module Loading")

  local all_ok = true
  for _, mod_name in ipairs(CORE_MODULES) do
    local ok, err = pcall(require, mod_name)
    if ok then
      vim.health.ok(mod_name .. " loaded")
    else
      vim.health.error("Failed to load " .. mod_name .. ": " .. tostring(err))
      all_ok = false
    end
  end

  return all_ok
end

--- Check content availability (arts and messages)
local function check_content()
  vim.health.start("Content System")

  local ok, content = pcall(require, "ascii-animation.content")
  if not ok then
    vim.health.error("Content module failed to load")
    return false
  end

  -- Check arts
  local arts_ok, arts = pcall(require, "ascii-animation.content.arts")
  if arts_ok then
    local art_ids = arts.list_art_ids()
    local art_count = #art_ids
    local styles = arts.get_styles()
    local style_count = #styles

    if art_count > 0 then
      vim.health.ok(string.format("Arts: %d available across %d styles (%s)", art_count, style_count, table.concat(styles, ", ")))
    else
      vim.health.warn("No ASCII arts found")
    end
  else
    vim.health.error("Arts module failed to load")
  end

  -- Check messages
  local msgs_ok, messages = pcall(require, "ascii-animation.content.messages")
  if msgs_ok then
    local msg_count = messages.get_message_count()
    local themes = messages.themes or {}

    if msg_count > 0 then
      vim.health.ok(string.format("Messages: %d available across %d themes", msg_count, #themes))
    else
      vim.health.warn("No messages found")
    end
  else
    vim.health.error("Messages module failed to load")
  end

  return arts_ok and msgs_ok
end

--- Check terminal capabilities
local function check_terminal()
  vim.health.start("Terminal Capabilities")

  -- Check terminal width
  local width = vim.o.columns
  if width >= RECOMMENDED_TERMINAL_WIDTH then
    vim.health.ok(string.format("Terminal width: %d columns", width))
  elseif width >= MIN_TERMINAL_WIDTH then
    vim.health.warn(string.format("Terminal width (%d) may clip some wider arts. Recommended: %d+", width, RECOMMENDED_TERMINAL_WIDTH))
  else
    vim.health.warn(string.format("Terminal width (%d) is narrow. Some arts may not display correctly. Minimum: %d", width, MIN_TERMINAL_WIDTH))
  end

  -- Check for true color support
  if vim.fn.has("termguicolors") == 1 and vim.o.termguicolors then
    vim.health.ok("True color (24-bit) enabled")
  else
    vim.health.info("True color disabled. Some highlight effects may look different")
  end

  -- Check unicode support (basic test)
  local encoding = vim.o.encoding
  if encoding == "utf-8" or encoding == "utf8" then
    vim.health.ok("UTF-8 encoding enabled")
  else
    vim.health.warn(string.format("Encoding is '%s'. UTF-8 recommended for special characters", encoding))
  end

  return true
end

--- Check configuration and persistence
local function check_config()
  vim.health.start("Configuration")

  local ok, config = pcall(require, "ascii-animation.config")
  if not ok then
    vim.health.error("Config module failed to load")
    return false
  end

  -- Check data directory
  local data_path = vim.fn.stdpath("data")
  if vim.fn.isdirectory(data_path) == 1 then
    vim.health.ok("Data directory exists: " .. data_path)
  else
    vim.health.error("Data directory not found: " .. data_path)
  end

  -- Check settings file
  local settings_file = data_path .. "/ascii-animation.json"
  if vim.fn.filereadable(settings_file) == 1 then
    -- Try to load and validate
    local saved = config.load_saved()
    if saved then
      vim.health.ok("Settings file readable: ascii-animation.json")

      -- Report key settings
      if saved.effect then
        vim.health.info("Current effect: " .. saved.effect)
      end
      if saved.random_mode then
        vim.health.info("Random mode: " .. saved.random_mode)
      end
    else
      vim.health.warn("Settings file exists but could not be parsed")
    end
  else
    vim.health.info("No saved settings (using defaults)")
  end

  -- Check favorites
  if config.favorites and #config.favorites > 0 then
    vim.health.info(string.format("Favorites: %d art(s) marked", #config.favorites))
  end

  return true
end

--- Check state persistence
local function check_state()
  vim.health.start("State Persistence")

  local ok, state = pcall(require, "ascii-animation.state")
  if not ok then
    vim.health.error("State module failed to load")
    return false
  end

  -- Check state directory
  local state_path = vim.fn.stdpath("state")
  if vim.fn.isdirectory(state_path) == 1 then
    vim.health.ok("State directory exists: " .. state_path)
  else
    vim.health.warn("State directory not found: " .. state_path)
  end

  -- Check state file
  local state_file = state_path .. "/ascii-animation.json"
  if vim.fn.filereadable(state_file) == 1 then
    local loaded = state.load()
    if loaded then
      vim.health.ok("State file readable: ascii-animation.json")

      -- Report some state info
      if loaded.last_art_id then
        vim.health.info("Last shown art: " .. loaded.last_art_id)
      end
      if loaded.recent_arts then
        vim.health.info(string.format("Recent history: %d art(s)", #loaded.recent_arts))
      end
    else
      vim.health.warn("State file exists but could not be parsed")
    end
  else
    vim.health.info("No state file yet (will be created on first use)")
  end

  return true
end

--- Check available integrations
local function check_integrations()
  vim.health.start("Dashboard Integrations")

  local found_any = false

  for _, integration in ipairs(INTEGRATIONS) do
    local ok, _ = pcall(require, integration.module)
    if ok then
      vim.health.ok(integration.name .. " detected")
      found_any = true
    end
  end

  if not found_any then
    vim.health.info("No dashboard plugins detected. Use standalone with :AsciiPreview")
  end

  return true
end

--- Check time period system
local function check_time()
  vim.health.start("Time System")

  local ok, time = pcall(require, "ascii-animation.time")
  if not ok then
    vim.health.error("Time module failed to load")
    return false
  end

  local current_period = time.get_current_period()
  if current_period then
    local periods = time.get_periods()
    vim.health.ok(string.format("Current period: %s (available: %s)", current_period, table.concat(periods, ", ")))
  else
    vim.health.warn("Could not determine current time period")
  end

  return true
end

--- Check user commands
local function check_commands()
  vim.health.start("User Commands")

  local commands = {
    "AsciiPreview",
    "AsciiSettings",
    "AsciiRandom",
    "AsciiBrowse",
    "AsciiMessageBrowse",
  }

  local all_ok = true
  for _, cmd in ipairs(commands) do
    if vim.fn.exists(":" .. cmd) == 2 then
      vim.health.ok(":" .. cmd .. " registered")
    else
      vim.health.warn(":" .. cmd .. " not registered")
      all_ok = false
    end
  end

  return all_ok
end

--- Main health check entry point
function M.check()
  vim.health.start("ascii-animation")

  -- Run all checks
  local modules_ok = check_modules()

  if modules_ok then
    check_content()
    check_terminal()
    check_config()
    check_state()
    check_integrations()
    check_time()
    check_commands()
  else
    vim.health.error("Core modules failed to load. Cannot continue health check.")
    vim.health.info("Try reinstalling the plugin or check for syntax errors")
  end
end

return M
