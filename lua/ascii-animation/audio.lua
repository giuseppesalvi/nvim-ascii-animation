-- Audio level sampling for audio-reactive screensaver mode
-- Uses sox (rec) to sample microphone input levels

local M = {}

local state = {
  timer = nil,                   -- vim.uv.new_timer() for periodic sampling
  level = 0.0,                   -- Smoothed audio level (0.0-1.0)
  running = false,
  sox_available = nil,           -- Cached sox check (nil = unchecked)
  sampling_in_progress = false,  -- Guard against overlapping async calls
}

-- Check if sox (rec) is available on the system
function M.check_sox()
  if state.sox_available == nil then
    state.sox_available = vim.fn.executable("rec") == 1
  end
  return state.sox_available
end

-- Start audio level sampling
-- opts: { interval = ms, smoothing = 0.0-1.0 }
function M.start(opts)
  if state.running then
    return true
  end

  if not M.check_sox() then
    vim.notify("Audio-reactive mode requires sox. Install: brew install sox / apt install sox", vim.log.levels.WARN)
    return false
  end

  opts = opts or {}
  local interval = opts.interval or 100
  local smoothing = opts.smoothing or 0.3

  state.timer = vim.uv.new_timer()
  state.running = true
  state.level = 0.0

  state.timer:start(interval, interval, vim.schedule_wrap(function()
    if not state.running then
      return
    end

    -- Prevent overlapping async calls
    if state.sampling_in_progress then
      return
    end
    state.sampling_in_progress = true

    local cmd = { "rec", "-n", "trim", "0", "0.1", "stat" }
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
      state.sampling_in_progress = false

      if not state.running then
        return
      end

      -- Parse RMS amplitude from sox stat output (sent to stderr)
      local raw = 0.0
      if result and result.stderr then
        local rms = result.stderr:match("RMS%s+amplitude:%s+([%d%.]+)")
        if rms then
          raw = tonumber(rms) or 0.0
          -- Clamp to 0.0-1.0
          if raw > 1.0 then raw = 1.0 end
          if raw < 0.0 then raw = 0.0 end
        end
      end

      -- Exponential moving average for smoothing
      state.level = smoothing * raw + (1 - smoothing) * state.level
    end))
  end))

  return true
end

-- Stop audio level sampling
function M.stop()
  state.running = false

  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end

  state.level = 0.0
  state.sampling_in_progress = false
end

-- Get current smoothed audio level (always safe to call)
function M.get_level()
  return state.level
end

-- Check if audio sampling is running
function M.is_running()
  return state.running
end

return M
