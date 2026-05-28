local logger = {}

local loki_endpoint = "http://192.168.0.36:3100/loki/api/v1/push"
local fallback_endpoint = "https://log.neelema.net/loki/api/v1/push"
local use_fallback = false

local function now()
  if textutils and textutils.formatTime and os.time then
    return textutils.formatTime(os.time(), true)
  end

  return tostring(os.clock())
end

local function post(level, message)
  if not http or not textutils or not textutils.serializeJSON then
    return
  end

  local line = textutils.serializeJSON({
    message = tostring(message),
    turtle_id = os.getComputerID(),
  })

  local body = textutils.serializeJSON({
    streams = {{
      stream = {
        service = "turtle",
        level = level,
      },
      values = {
        { tostring(os.epoch("utc") * 1000000), line },
      },
    }},
  })

  local headers = { ["Content-Type"] = "application/json" }

  if not use_fallback then
    local ok, err = pcall(function()
      local response = http.post(loki_endpoint, body, headers)
      if response then
        response.close()
      else
        error("no response")
      end
    end)

    if ok then
      return
    end

    use_fallback = true
    print("Loki unavailable, falling back to " .. fallback_endpoint)
  end

  pcall(function()
    local response = http.post(fallback_endpoint, body, headers)
    if response then
      response.close()
    end
  end)
end

function logger.info(message)
  print("[" .. now() .. "] " .. tostring(message))
  post("info", message)
end

function logger.warn(message)
  print("[" .. now() .. "] WARN " .. tostring(message))
  post("warn", message)
end

return logger
