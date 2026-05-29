package.path = "/?.lua;" .. package.path
local log = require("logger")

while true do
  local fn, loadErr = loadfile("/main.lua")
  if not fn then
    log.error("main failed to load: " .. tostring(loadErr))
    os.sleep(5)
  else
    setfenv(fn, getfenv())
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
      break
    end
    log.error("main crashed: " .. tostring(err))
    os.sleep(5)
  end
end
