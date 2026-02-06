-- ascii-animation: Cinematic text animation for Neovim dashboards
-- https://github.com/giuseppesalvi/nvim-ascii-animation

local config = require("ascii-animation.config")
local animation = require("ascii-animation.animation")
local time = require("ascii-animation.time")
local content = require("ascii-animation.content")
local commands = require("ascii-animation.commands")
local placeholders = require("ascii-animation.placeholders")

local M = {}

-- Setup function to configure the plugin
function M.setup(opts)
  config.setup(opts)

  -- Register user commands
  commands.register_commands()

  -- Setup screensaver if enabled
  if config.options.screensaver and config.options.screensaver.enabled then
    require("ascii-animation.screensaver").setup()
  end

  -- Create autocommand for snacks.nvim dashboard
  if opts and opts.snacks then
    M.setup_snacks(opts.snacks)
  end
end

-- Setup for snacks.nvim dashboard integration
function M.setup_snacks(snacks_opts)
  local header_lines = snacks_opts.header_lines or 20
  local highlight = snacks_opts.highlight or "SnacksDashboardHeader"

  vim.api.nvim_create_autocmd("User", {
    pattern = "SnacksDashboardOpened",
    callback = function(ev)
      local buf = ev.buf
      animation.start(buf, header_lines, highlight)
    end,
  })
end

-- Setup for alpha.nvim dashboard integration
function M.setup_alpha(alpha_opts)
  local header_lines = alpha_opts.header_lines or 20
  local highlight = alpha_opts.highlight or "AlphaHeader"

  vim.api.nvim_create_autocmd("User", {
    pattern = "AlphaReady",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      animation.start(buf, header_lines, highlight)
    end,
  })
end

-- Setup for dashboard-nvim integration
function M.setup_dashboard(dashboard_opts)
  local header_lines = dashboard_opts.header_lines or 20
  local highlight = dashboard_opts.highlight or "DashboardHeader"

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "dashboard",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        animation.start(buf, header_lines, highlight)
      end, 10)
    end,
  })
end

-- Setup for lazy.nvim starter screen integration
function M.setup_lazy(lazy_opts)
  local header_lines = lazy_opts.header_lines or 20
  local highlight = lazy_opts.highlight or "LazyH1"

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "lazy",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        animation.start(buf, header_lines, highlight)
      end, 10)
    end,
  })
end

-- Manual trigger for any buffer
function M.animate_buffer(buf, lines, highlight)
  buf = buf or vim.api.nvim_get_current_buf()
  lines = lines or 20
  highlight = highlight or "Normal"
  animation.start(buf, lines, highlight)
end

-- Expose animation module for advanced usage
M.animation = animation
M.config = config

-- ============================================
-- Content API
-- ============================================

-- Get the current time period
function M.get_current_period()
  return time.get_current_period()
end

-- Get a complete header (art + message) for current period
-- Returns: { art = lines[], message = string, period = string, art_id = string, art_name = string }
function M.get_header()
  local anim_opts = config.options.animation or {}
  local min_width = anim_opts.min_width or 60
  local fallback = anim_opts.fallback or "tagline"

  -- Check if terminal is wide enough
  if vim.o.columns < min_width then
    local period = time.get_current_period()
    local message = content.get_message()
    local footer = M.get_footer()

    if fallback == "none" then
      return {
        art = {},
        message = "",
        footer = footer,
        period = period,
        art_id = nil,
        art_name = nil,
      }
    elseif fallback == "tagline" then
      return {
        art = {},
        message = message or "",
        footer = footer,
        period = period,
        art_id = nil,
        art_name = nil,
      }
    else
      -- fallback is an art_id
      local art = content.get_art_by_id(fallback)
      if art then
        return {
          art = art.lines or {},
          message = message or "",
          footer = footer,
          period = period,
          art_id = art.id,
          art_name = art.name,
        }
      end
      -- Art not found, fall back to tagline
      return {
        art = {},
        message = message or "",
        footer = footer,
        period = period,
        art_id = nil,
        art_name = nil,
      }
    end
  end

  local header = content.get_header()
  header.footer = M.get_footer()
  return header
end

-- Get a complete header for a specific period
function M.get_header_for_period(period)
  return content.get_header_for_period(period)
end

-- Get a random art for the current period
-- Returns: { id = string, name = string, lines = string[] }
function M.get_art()
  return content.get_art()
end

-- Get a random art for a specific period
function M.get_art_for_period(period)
  return content.get_art_for_period(period)
end

-- Get a random message/tagline for the current period
function M.get_message()
  return content.get_message()
end

-- Get a random message for a specific period
function M.get_message_for_period(period)
  return content.get_message_for_period(period)
end

-- List all available art IDs
function M.list_arts()
  return content.list_arts()
end

-- List art IDs for a specific period
function M.list_arts_for_period(period)
  return content.list_arts_for_period(period)
end

-- Get a specific art by ID
function M.get_art_by_id(id)
  return content.get_art_by_id(id)
end

-- Get available art styles
function M.get_styles()
  return content.get_styles()
end

-- ============================================
-- Footer API
-- ============================================

-- Get the rendered footer string
-- Processes the template with available placeholders
function M.get_footer()
  local footer_opts = config.options.footer or {}
  if not footer_opts.enabled then
    return ""
  end

  local template = footer_opts.template or "{message}"

  -- Get a message for the {message} placeholder
  local message = content.get_message() or ""

  -- Build placeholder values
  local values = {
    message = message,
    date = placeholders.resolve("date") or "",
    time = placeholders.resolve("time") or "",
    version = placeholders.resolve("version") or "",
    plugins = placeholders.resolve("plugin_count") or "",
    name = placeholders.resolve("name") or "",
    project = placeholders.resolve("project") or "",
  }

  -- Replace placeholders in template
  local result = template:gsub("{(%w+)}", function(key)
    return values[key] or ""
  end)

  -- Clean up any double spaces from empty placeholders
  result = result:gsub("  +", " "):gsub("^ +", ""):gsub(" +$", "")

  return result
end

-- Get footer lines formatted for dashboard integration
-- @param width (optional) Width for alignment, defaults to terminal width
-- @return table of strings (footer lines)
function M.get_footer_lines(width)
  local footer_opts = config.options.footer or {}
  if not footer_opts.enabled then
    return {}
  end

  local footer_text = M.get_footer()
  if footer_text == "" then
    return {}
  end

  width = width or vim.o.columns
  local alignment = footer_opts.alignment or "center"

  local lines = {}
  -- Handle multi-line footers (split by newline)
  for line in footer_text:gmatch("[^\n]+") do
    local aligned_line = line
    local line_width = vim.fn.strdisplaywidth(line)

    if alignment == "center" then
      local padding = math.floor((width - line_width) / 2)
      aligned_line = string.rep(" ", math.max(0, padding)) .. line
    elseif alignment == "right" then
      local padding = width - line_width
      aligned_line = string.rep(" ", math.max(0, padding)) .. line
    end
    -- "left" alignment: no padding needed

    table.insert(lines, aligned_line)
  end

  return lines
end

-- Expose modules for advanced usage
M.content = content
M.time = time
M.state = require("ascii-animation.state")
M.placeholders = placeholders

-- ============================================
-- User Commands API
-- ============================================

-- Preview an ASCII art in a floating window
-- @param name (optional) Art ID or partial match; if nil, shows random art
function M.preview(name)
  commands.preview(name)
end

-- Open settings panel
-- @return table with stats (arts, taglines, styles, effect, period, animation)
function M.settings()
  return commands.stats()
end

-- Refresh animation on current buffer
function M.refresh()
  commands.refresh()
end

-- Stop any running animation
function M.stop()
  animation.stop()
end

-- Pause current animation
function M.pause()
  animation.pause()
end

-- Resume paused animation
function M.resume()
  animation.resume()
end

-- Cycle to the next animation effect
function M.next_effect()
  return animation.next_effect()
end

-- Set a specific animation effect by name
function M.set_effect(name)
  return animation.set_effect(name)
end

-- Apply a named theme preset
function M.apply_preset(name)
  return config.apply_preset(name)
end

-- List all available theme preset names
function M.list_presets()
  local names = vim.deepcopy(config.theme_preset_names)
  for k in pairs(config.options.content.custom_presets or {}) do
    table.insert(names, k)
  end
  return names
end

-- ============================================
-- Screensaver API
-- ============================================

-- Trigger the screensaver manually
function M.screensaver()
  require("ascii-animation.screensaver").trigger()
end

-- Dismiss the screensaver if active
function M.dismiss_screensaver()
  require("ascii-animation.screensaver").dismiss()
end

-- Expose commands module
M.commands = commands

return M
