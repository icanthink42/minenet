local logger = {}
local endpoint = "https://log.neelema.net"

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

  local body = textutils.serializeJSON({
    id = os.getComputerID(),
    level = level,
    message = tostring(message),
  })

  pcall(function()
    local response = http.post(
      endpoint,
      body,
      { ["Content-Type"] = "application/json" }
    )

    if response then
      response.close()
    end
  end)
end

function logger.info(message)
  local line = "[" .. now() .. "] " .. tostring(message)
  print(line)
  post("info", line)
end

function logger.warn(message)
  local line = "[" .. now() .. "] WARN " .. tostring(message)
  print(line)
  post("warn", line)
end

return logger
