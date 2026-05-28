local logger = {}

local function now()
  if textutils and textutils.formatTime and os.time then
    return textutils.formatTime(os.time(), true)
  end

  return tostring(os.clock())
end

function logger.info(message)
  print("[" .. now() .. "] " .. tostring(message))
end

function logger.warn(message)
  print("[" .. now() .. "] WARN " .. tostring(message))
end

return logger
