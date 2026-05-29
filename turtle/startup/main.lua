-- yield one tick so the filesystem is mounted before require runs
os.sleep(0)

local log = require("logger")

while true do
  local fn, loadErr = loadfile("/main.lua")
  if not fn then
    log.error("main failed to load: " .. tostring(loadErr))
    os.sleep(5)
  else
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
      break
    end
    log.error("main crashed: " .. tostring(err))
    os.sleep(5)
  end
end
