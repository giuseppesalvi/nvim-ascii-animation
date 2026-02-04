-- ascii-animation: Cinematic text animation for Neovim dashboards
-- https://github.com/giuseppesalvi/nvim-ascii-animation

local config = require("ascii-animation.config")
local animation = require("ascii-animation.animation")
local time = require("ascii-animation.time")
local content = require("ascii-animation.content")

local M = {}

-- Setup function to configure the plugin
function M.setup(opts)
  config.setup(opts)

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

    if fallback == "none" then
      return {
        art = {},
        message = "",
        period = period,
        art_id = nil,
        art_name = nil,
      }
    elseif fallback == "tagline" then
      return {
        art = {},
        message = message or "",
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
          period = period,
          art_id = art.id,
          art_name = art.name,
        }
      end
      -- Art not found, fall back to tagline
      return {
        art = {},
        message = message or "",
        period = period,
        art_id = nil,
        art_name = nil,
      }
    end
  end

  return content.get_header()
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

-- Expose modules for advanced usage
M.content = content
M.time = time
M.state = require("ascii-animation.state")

return M
