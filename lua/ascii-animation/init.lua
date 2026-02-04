-- ascii-animation: Cinematic text animation for Neovim dashboards
-- https://github.com/yourusername/nvim-ascii-animation

local config = require("ascii-animation.config")
local animation = require("ascii-animation.animation")

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

return M
