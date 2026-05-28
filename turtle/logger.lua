local logger = {}

local loki_endpoint = "http://127.0.0.1:3100/loki/api/v1/push"
local fallback_endpoint = "https://log.neelema.net/loki/api/v1/push"
local use_fallback = false

local prometheus_endpoint = "http://127.0.0.1:9091"

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

  local line = string.format('{"message":%s,"turtle_id":%d}',
    textutils.serializeJSON(tostring(message)),
    os.getComputerID())

  local timestamp = string.format("%.0f000000", os.epoch("utc"))

  local body = string.format(
    '{"streams":[{"stream":{"service":"turtle","level":"%s"},"values":[["%s",%s]]}]}',
    level, timestamp, textutils.serializeJSON(line))

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

local pending_gauges = {}

function logger.gauge(name, value)
  pending_gauges[name] = value
end

function logger.delete_gauges()
  if not http then return end

  local url = string.format("%s/metrics/job/turtle/instance/%d", prometheus_endpoint, os.getComputerID())
  pcall(function()
    local response = http.request({ url = url, method = "DELETE" })
    if response then response.close() end
  end)
end

function logger.flush_gauges()
  if not http then return end
  if next(pending_gauges) == nil then return end

  local url = string.format("%s/metrics/job/turtle/instance/%d", prometheus_endpoint, os.getComputerID())
  local parts = {}
  for name, value in pairs(pending_gauges) do
    parts[#parts + 1] = string.format("# TYPE %s gauge\n%s %s\n", name, name, tostring(value))
  end
  local body = table.concat(parts)
  local headers = { ["Content-Type"] = "text/plain; version=0.0.4" }

  pcall(function()
    local response = http.post(url, body, headers)
    if response then response.close() end
  end)

  pending_gauges = {}
end

function logger.info(message)
  print("[" .. now() .. "] " .. tostring(message))
  post("info", message)
end

function logger.warn(message)
  print("[" .. now() .. "] WARN " .. tostring(message))
  post("warn", message)
end

function logger.error(message)
  print("[" .. now() .. "] ERROR " .. tostring(message))
  post("error", message)
end

return logger
