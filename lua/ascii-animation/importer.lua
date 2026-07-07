-- Import user-selected ASCII art from web pages into custom_arts_dir.

local config = require("ascii-animation.config")
local content = require("ascii-animation.content")

local M = {}

local state = {
  buf = nil,
  win = nil,
  source = nil,
  candidates = {},
  index = 1,
}

local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf = nil
  state.win = nil
end

local function html_decode(text)
  local entities = {
    amp = "&",
    lt = "<",
    gt = ">",
    quot = '"',
    apos = "'",
    nbsp = " ",
  }

  text = text:gsub("&#(%d+);", function(n)
    local code = tonumber(n)
    if code then
      return vim.fn.nr2char(code)
    end
    return ""
  end)

  text = text:gsub("&#x(%x+);", function(n)
    local code = tonumber(n, 16)
    if code then
      return vim.fn.nr2char(code)
    end
    return ""
  end)

  return text:gsub("&([%a]+);", function(name)
    return entities[name] or ("&" .. name .. ";")
  end)
end

local function strip_html(html)
  local text = html:gsub("\r\n", "\n"):gsub("\r", "\n")
  text = text:gsub("<script.-</script>", "")
  text = text:gsub("<style.-</style>", "")
  text = text:gsub("<br%s*/?>", "\n")
  text = text:gsub("</[^>]+>", "\n")
  text = text:gsub("<[^>]+>", "")
  return html_decode(text)
end

local function trim_blank_edges(lines)
  while #lines > 0 and lines[1]:match("^%s*$") do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end
end

local function art_width(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

local function normalize_block(lines)
  trim_blank_edges(lines)
  if #lines == 0 then return lines end

  local min_indent = nil
  for _, line in ipairs(lines) do
    if not line:match("^%s*$") then
      local indent = #(line:match("^%s*") or "")
      min_indent = min_indent and math.min(min_indent, indent) or indent
    end
  end

  if min_indent and min_indent > 0 then
    for i, line in ipairs(lines) do
      lines[i] = line:sub(min_indent + 1)
    end
  end

  return lines
end

local function candidate_name(prefix, index)
  prefix = vim.trim(prefix or "")
  prefix = prefix:gsub("[:%-]+$", "")
  if prefix ~= "" and #prefix <= 80 then
    return prefix
  end
  return "Imported ASCII " .. index
end

local function extract_pre_blocks(html)
  local candidates = {}
  for block in html:gmatch("<pre[^>]*>(.-)</pre>") do
    local lines = vim.split(html_decode(block), "\n", { plain = true })
    normalize_block(lines)
    if #lines >= 4 and art_width(lines) >= 12 then
      table.insert(candidates, {
        name = "Imported ASCII " .. (#candidates + 1),
        lines = lines,
      })
    end
  end
  return candidates
end

local function extract_indented_blocks(text)
  local candidates = {}
  local lines = vim.split(text, "\n", { plain = true })
  local block = {}
  local previous_label = ""
  local last_text = ""

  local function flush()
    local copy = vim.deepcopy(block)
    normalize_block(copy)
    if #copy >= 6 and art_width(copy) >= 20 then
      table.insert(candidates, {
        name = candidate_name(previous_label, #candidates + 1),
        lines = copy,
      })
    end
    block = {}
  end

  for _, line in ipairs(lines) do
    local is_art_line = line:match("^%s%s%s+%S") ~= nil
      or line:match("^%s*$") and #block > 0

    if is_art_line then
      table.insert(block, line)
    else
      if #block > 0 then
        flush()
      end
      local trimmed = vim.trim(line)
      if trimmed ~= "" then
        previous_label = last_text
        last_text = trimmed
      end
    end
  end

  if #block > 0 then
    flush()
  end

  return candidates
end

local function extract_candidates(body)
  local candidates = extract_pre_blocks(body)
  if #candidates == 0 then
    candidates = extract_indented_blocks(strip_html(body))
  end

  table.sort(candidates, function(a, b)
    return (#a.lines * art_width(a.lines)) > (#b.lines * art_width(b.lines))
  end)

  return candidates
end

local function import_dir()
  local opts = config.options.content or {}
  local dir = opts.custom_arts_dir
  if not dir or dir == "" then
    dir = vim.fn.stdpath("data") .. "/ascii-animation/imports"
    config.options.content.custom_arts_dir = dir
    config.save()
  end
  return vim.fn.expand(dir)
end

local function slugify(value)
  value = value:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if value == "" then
    value = "imported_ascii"
  end
  return value
end

local function write_art(candidate)
  local dir = import_dir()
  if vim.fn.isdirectory(dir) ~= 1 then
    vim.fn.mkdir(dir, "p")
  end

  local slug = slugify(candidate.name)
  local path = dir .. "/" .. slug .. ".txt"
  local suffix = 1
  while vim.fn.filereadable(path) == 1 do
    suffix = suffix + 1
    path = dir .. "/" .. slug .. "_" .. suffix .. ".txt"
  end

  local id = "imported_" .. vim.fn.fnamemodify(path, ":t:r")
  local lines = {
    "# id: " .. id,
    "# name: " .. candidate.name,
    "# style: imported",
    "# tags: imported, portrait",
    "# source: " .. (state.source or ""),
    "# license: unknown",
    "",
  }

  for _, line in ipairs(candidate.lines) do
    table.insert(lines, line)
  end

  local ok, result = pcall(vim.fn.writefile, lines, path)
  if not ok or result ~= 0 then
    vim.notify("[ascii-animation] Import failed: " .. tostring(result), vim.log.levels.ERROR)
    return
  end

  content.reload_custom_arts()
  vim.notify("[ascii-animation] Saved imported art: " .. path, vim.log.levels.INFO)
end

local function render_preview()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local candidate = state.candidates[state.index]
  if not candidate then return end

  local width = art_width(candidate.lines)
  local lines = {
    "Import Preview",
    string.format("%d / %d  %s  (%dx%d)", state.index, #state.candidates, candidate.name, width, #candidate.lines),
    "s: save  n/p: next/previous  q: quit",
    "",
  }

  for _, line in ipairs(candidate.lines) do
    table.insert(lines, line)
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function move(delta)
  state.index = state.index + delta
  if state.index < 1 then
    state.index = #state.candidates
  elseif state.index > #state.candidates then
    state.index = 1
  end
  render_preview()
end

local function open_preview(source, candidates)
  close_window()
  state.source = source
  state.candidates = candidates
  state.index = 1

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
  vim.bo[state.buf].modifiable = false

  local width = math.max(50, math.floor(vim.o.columns * 0.85))
  local height = math.max(12, math.floor(vim.o.lines * 0.85))
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " ASCII Import ",
    title_pos = "center",
  })

  vim.wo[state.win].wrap = false
  vim.wo[state.win].cursorline = false

  local opts = { buffer = state.buf, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_window, opts)
  vim.keymap.set("n", "<Esc>", close_window, opts)
  vim.keymap.set("n", "n", function() move(1) end, opts)
  vim.keymap.set("n", "p", function() move(-1) end, opts)
  vim.keymap.set("n", "j", function() move(1) end, opts)
  vim.keymap.set("n", "k", function() move(-1) end, opts)
  vim.keymap.set("n", "s", function()
    local candidate = state.candidates[state.index]
    if candidate then
      write_art(candidate)
    end
  end, opts)

  render_preview()
end

function M.import_url(url)
  if not url or url == "" then
    vim.notify("[ascii-animation] Usage: :AsciiImport <url>", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("curl") ~= 1 then
    vim.notify("[ascii-animation] curl is required for URL imports", vim.log.levels.ERROR)
    return
  end
  if not vim.system then
    vim.notify("[ascii-animation] URL imports require Neovim 0.10+ (vim.system)", vim.log.levels.ERROR)
    return
  end

  vim.notify("[ascii-animation] Fetching ASCII art candidates...", vim.log.levels.INFO)
  vim.system({ "curl", "-fsSL", url }, { text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      vim.notify("[ascii-animation] Import fetch failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end

    local candidates = extract_candidates(result.stdout or "")
    if #candidates == 0 then
      vim.notify("[ascii-animation] No ASCII art blocks found at URL", vim.log.levels.WARN)
      return
    end

    open_preview(url, candidates)
  end))
end

function M.import_file(path)
  if not path or path == "" then
    vim.notify("[ascii-animation] Usage: :AsciiImportFile <path>", vim.log.levels.WARN)
    return
  end

  path = vim.fn.expand(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    vim.notify("[ascii-animation] Could not read file: " .. path, vim.log.levels.ERROR)
    return
  end

  local normalized = normalize_block(lines)
  if #normalized == 0 then
    vim.notify("[ascii-animation] File is empty: " .. path, vim.log.levels.WARN)
    return
  end

  open_preview(path, {
    {
      name = vim.fn.fnamemodify(path, ":t:r"),
      lines = normalized,
    },
  })
end

return M
