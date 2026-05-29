local config = require("miner_config")
local fuel = require("miner_fuel")
local inventory = require("miner_inventory")
local log = require("logger")
local movement = require("movement")
local ore = require("miner_ore")
local recall = require("recall")
local scanner = require("miner_scanner")
local runState = require("miner_state")

local homeStateFile = ".home_state"

---@return table<string, string>? snapshot
---@return string? err
local function snapshotHome()
  local dirs = { "north", "east", "south", "west" }
  local blocks = {}

  for _, dir in ipairs(dirs) do
    local ok, reason = movement.face(dir)
    if not ok then
      return nil, "could not face " .. dir .. ": " .. tostring(reason)
    end
    local exists, block = turtle.inspect()
    blocks[dir] = exists and block.name or "air"
  end

  local ok, reason = movement.face("north")
  if not ok then
    return nil, "could not restore facing: " .. tostring(reason)
  end

  local exists, block
  exists, block = turtle.inspectUp()
  blocks.up = exists and block.name or "air"

  exists, block = turtle.inspectDown()
  blocks.down = exists and block.name or "air"

  return blocks
end

---@param snapshot table<string, string>
---@return string
local function homeStateString(snapshot)
  local parts = {}
  for _, dir in ipairs({ "north", "east", "south", "west", "up", "down" }) do
    parts[#parts + 1] = dir .. "=" .. (snapshot[dir] or "air")
  end
  return table.concat(parts, ";")
end

---@param snapshot table<string, string>
---@return boolean
---@return string?
local function saveHomeState(snapshot)
  local handle, err = fs.open(homeStateFile, "w")
  if not handle then
    return false, "failed to open home state file: " .. tostring(err)
  end
  handle.write(homeStateString(snapshot))
  handle.close()
  return true
end

---@return string?
local function loadSavedHomeState()
  if not fs.exists(homeStateFile) then
    return nil
  end
  local handle = fs.open(homeStateFile, "r")
  if not handle then
    return nil
  end
  local content = handle.readAll()
  handle.close()
  return content
end

---@return boolean
---@return string?
local function checkAndUpdateHomeState()
  local snapshot, err = snapshotHome()
  if not snapshot then
    return false, err
  end

  local current = homeStateString(snapshot)
  local saved = loadSavedHomeState()

  if not saved then
    log.info("Validation: recording initial home state")
    return saveHomeState(snapshot)
  end

  if current ~= saved then
    log.warn("Validation: home state mismatch; expected: " .. saved .. " got: " .. current)
    return false, "home state changed"
  end

  log.info("Validation: home state verified")
  return true
end

---@return integer
local function baseShaftX()
  return runState.column() * config.shaftSpacing()
end

---@return integer
local function baseShaftZ()
  return 0
end

---@return integer
local function currentColumnX()
  return baseShaftX() + runState.detourX()
end

---@return integer
local function currentColumnZ()
  return baseShaftZ() + runState.detourZ()
end

---@return integer
local function shaftX()
  return baseShaftX()
end

---@return integer
local function shaftZ()
  return baseShaftZ()
end

---@return integer
local function maxDistanceFromHome()
  return (config.maxChunksFromHome or 8) * 16
end

---@return boolean
local function nextShaftWouldExceedRange()
  local nextColumn = runState.column() + 1
  local nextX = nextColumn * config.shaftSpacing()
  return math.abs(nextX) > maxDistanceFromHome()
end

---@param extra? integer
---@return integer
local function homeFuelNeed(extra)
  local pos = movement.position()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z) + (extra or 64)
end

---@param reason string
local function returnHome(reason)
  log.warn("Returning home: " .. tostring(reason))
  fuel.ensureEmergency(homeFuelNeed(256))

  local ok, moveReason = movement.goTo(0, 0, 0)
  if not ok then
    log.warn("Failed to return home: " .. tostring(moveReason))
    while true do
      os.sleep(5)
      ok, moveReason = movement.goTo(0, 0, 0)
      if ok then
        break
      end
      log.warn("Still trying to return home: " .. tostring(moveReason))
    end
  end

  movement.face("north")
  log.info("Stopped at home")
end

---@return boolean
local function tryDepositAroundHome()
  for _ = 1, 4 do
    local ok = inventory.depositNonFuel()
    if ok then
      return true
    end

    ok = movement.turnRight()
    if not ok then
      return false
    end
  end

  movement.face("north")

  if inventory.depositNonFuel(turtle.inspectUp, turtle.dropUp) then
    return true
  end

  if inventory.depositNonFuel(turtle.inspectDown, turtle.dropDown) then
    return true
  end

  return false
end

---@return boolean
local function unloadAtHome()
  log.info("Inventory full, returning home to unload")
  local resume = movement.position()
  fuel.ensureEmergency(homeFuelNeed(256))

  local ok, reason = movement.goTo(0, 0, 0)
  if not ok then
    return false
  end

  movement.face("north")

  if not tryDepositAroundHome() then
    log.warn("No chest with space next to home")
    return false
  end

  movement.face("north")
  if inventory.isFull() then
    log.warn("Inventory still full after unloading")
    return false
  end

  ok, reason = movement.goTo(resume.x, resume.y, resume.z)
  if not ok then
    log.warn("Failed to resume after unload: " .. tostring(reason))
    return false
  end

  log.info("Unloaded at home and resumed mining position")
  return movement.face(resume.facing)
end

---@param reason string
---@return boolean
local function handleCannotContinue(reason)
  if reason == "inventory full" then
    if unloadAtHome() then
      return true
    end
  end

  returnHome(reason)
  return false
end

---@param reason string
---@return false
local function recoverOrStop(reason)
  returnHome(reason)
  return false
end

---@return boolean
---@return string?
local function ensureCanContinue()
  if recall.requested() then
    return false, "recall requested"
  end

  inventory.cleanup()

  if inventory.isFull() then
    return false, "inventory full"
  end

  if fuel.shouldReturn() then
    return false, "charcoal reserve reached"
  end

  local ok, reason = fuel.ensure(homeFuelNeed())
  if not ok then
    return false, reason
  end

  return true
end

---@return number
local function currentShaftY()
  local y = movement.position().y
  if y > 0 then
    return 0
  end

  if runState.direction() == "up" then
    return y
  end

  local bottomY = runState.bottomY()
  if bottomY and y < bottomY then
    return bottomY
  end

  return y
end

---@return boolean
---@return string?
local function goToCurrentShaft()
  local ok, reason = movement.goTo(shaftX(), currentShaftY(), shaftZ())
  if not ok then
    return false, reason
  end

  return movement.face("north")
end

---@return boolean
---@return string?
local function initialize()
  log.info("Initializing miner in mode " .. tostring(config.mode or "normal"))

  local ok, reason = movement.load()
  if not ok then
    return false, reason
  end

  ok, reason = runState.load()
  if not ok then
    return false, reason
  end

  if not runState.initialized() then
    log.info("First run setup: moving to home column")

    if config.validation and fs.exists(homeStateFile) then
      fs.delete(homeStateFile)
      log.info("Validation: cleared stale home state for fresh run")
    end

    ok, reason = ensureCanContinue()
    if not ok then
      return false, reason
    end

    ok, reason = movement.goTo(shaftX(), 0, shaftZ())
    if not ok then
      return false, reason
    end

    ok, reason = movement.face("north")
    if not ok then
      return false, reason
    end

    return runState.markInitialized()
  end

  local pos = movement.position()
  log.info("Resuming at x=" .. pos.x .. " y=" .. pos.y .. " z=" .. pos.z .. " facing=" .. pos.facing)
  return true
end

---@return boolean
---@return string?
local function mineVisibleOreFromShaft()
  local ok, reason = ensureCanContinue()
  if not ok then
    return false, reason
  end

  ok, reason = goToCurrentShaft()
  if not ok then
    return false, reason
  end

  local shaftPos = movement.position()
  log.info("Scanning shaft x=" .. shaftPos.x .. " y=" .. shaftPos.y .. " z=" .. shaftPos.z)

  local blocks
  blocks, reason = scanner.scan(config.scanRadius)
  if not blocks then
    return false, reason
  end

  ---@type OreTarget[]
  local targets = {}
  for _, block in ipairs(blocks) do
    if scanner.isOre(block) then
      table.insert(targets, {
        name = block.name,
        family = ore.family(block.name),
        x = shaftPos.x + block.x,
        y = shaftPos.y + block.y,
        z = shaftPos.z + block.z,
      })
    end
  end

  log.info("Scan found " .. #targets .. " ore target(s)")

  local minedTargets = {}
  while true do
    local pos = movement.position()
    local bestIdx = nil
    local bestDist = nil
    for i, target in ipairs(targets) do
      local targetKey = tostring(target.x) .. "," .. tostring(target.y) .. "," .. tostring(target.z)
      if not minedTargets[targetKey] then
        local dist = math.abs(target.x - pos.x) + math.abs(target.y - pos.y) + math.abs(target.z - pos.z)
        if not bestDist or dist < bestDist then
          bestDist = dist
          bestIdx = i
        end
      end
    end

    if not bestIdx then
      break
    end

    local target = targets[bestIdx]
    local targetKey = tostring(target.x) .. "," .. tostring(target.y) .. "," .. tostring(target.z)
    ok, reason = ensureCanContinue()
    if not ok then
      return false, reason
    end

    local minedVein
    log.info("Mining vein target " .. target.name .. " at x=" .. target.x .. " y=" .. target.y .. " z=" .. target.z)
    ok, minedVein = ore.mineVeinAt(target)
    if not ok then
      log.warn("Vein mining failed: " .. tostring(minedVein))
      return false, minedVein
    end

    minedTargets[targetKey] = true
    for minedKey in pairs(minedVein) do
      minedTargets[minedKey] = true
    end

    if config.validation then
      fuel.ensureEmergency(homeFuelNeed(256))

      ok, reason = movement.goTo(0, 0, 0)
      if not ok then
        return false, reason
      end

      ok, reason = movement.face("north")
      if not ok then
        return false, reason
      end

      if not tryDepositAroundHome() then
        log.warn("Validation: deposit at home failed")
      end

      ok, reason = movement.face("north")
      if not ok then
        return false, reason
      end

      ok, reason = checkAndUpdateHomeState()
      if not ok then
        return false, reason
      end

      ok, reason = movement.goTo(shaftPos.x, shaftPos.y, shaftPos.z)
      if not ok then
        return false, reason
      end

      ok, reason = movement.face("north")
      if not ok then
        return false, reason
      end
    end
  end

  ok, reason = movement.goTo(shaftPos.x, shaftPos.y, shaftPos.z)
  if not ok then
    log.warn("Failed returning to shaft after ore: " .. tostring(reason))
    return false, reason
  end

  log.info("Finished shaft scan targets; returned to shaft")
  return movement.face("north")
end

local detourDirections = {
  { x = 1, z = 0 },
  { x = -1, z = 0 },
  { x = 0, z = 1 },
  { x = 0, z = -1 },
}

---@param verticalStep integer
---@return boolean
---@return string?
local function detourVertical(verticalStep)
  local current = movement.position()
  log.warn("Vertical movement blocked; searching detour from x=" .. current.x .. " y=" .. current.y .. " z=" .. current.z)

  local distance = 1
  while true do
    for _, dir in ipairs(detourDirections) do
      local detourX = runState.detourX() + dir.x * distance
      local detourZ = runState.detourZ() + dir.z * distance
      local ok, reason = runState.setDetour(detourX, detourZ)
      if not ok then
        return false, reason
      end

      ok, reason = movement.tryGoTo(currentColumnX(), current.y + verticalStep, currentColumnZ())
      if ok then
        log.info("Using detour column offset x=" .. detourX .. " z=" .. detourZ)
        return true
      end
    end

    distance = distance + 1
    os.sleep(0.25)
  end
end

---@return boolean
---@return string?
local function advanceShaft()
  local direction = runState.direction()
  local y = movement.position().y
  log.info("Advancing shaft direction=" .. direction .. " y=" .. y)

  if direction == "down" then
    local bottomY = runState.bottomY()
    if bottomY and y <= bottomY then
      log.info("Reached safe bottom y=" .. bottomY .. "; switching upward")

      local ok, reason = runState.clearDetour()
      if not ok then
        return false, reason
      end

      ok, reason = runState.advance()
      if not ok then
        return false, reason
      end

      return true
    end

    local ok, reason = movement.down()
    if ok then
      return true
    end

    if reason and reason:find("minecraft:bedrock") then
      log.warn("Bedrock detected at y=" .. y .. "; calibrating safe bottom")

      ok, reason = movement.goTo(shaftX(), y, shaftZ())
      if not ok then
        return false, reason
      end

      ok, reason = runState.clearDetour()
      if not ok then
        return false, reason
      end

      ok, reason = runState.setBedrockY(y)
      if not ok then
        return false, reason
      end

      local bottomY = y + 5
      ok, reason = runState.setBottomY(bottomY)
      if not ok then
        return false, reason
      end

      ok, reason = movement.goTo(shaftX(), bottomY, shaftZ())
      if not ok then
        return false, reason
      end

      ok, reason = runState.advance()
      if not ok then
        return false, reason
      end

      log.info("Safe bottom set to y=" .. bottomY .. "; switching upward")
      return true
    end

    log.warn("Down blocked by " .. tostring(reason))
    return detourVertical(-1)
  end

  if y >= 0 then
    log.info("Reached home level; moving to next shaft column")

    if nextShaftWouldExceedRange() then
      log.info("Max range reached: " .. tostring(config.maxChunksFromHome or 8) .. " chunks from home")
      return false, "max chunk range reached"
    end

    local ok, reason = runState.advance()
    if not ok then
      return false, reason
    end

    return movement.goTo(shaftX(), y, shaftZ())
  end

  local ok, reason = movement.up()
  if ok then
    return true
  end

  log.warn("Up blocked by " .. tostring(reason))
  return detourVertical(1)
end

local function reportGauges()
  local pos = movement.position()
  local charcoal = fuel.charcoalCount()
  local effectiveFuel = charcoal * 80 + (turtle.getFuelLevel() == "unlimited" and 0 or turtle.getFuelLevel())
  local homeDist = math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z)

  log.gauge("turtle_effective_fuel", effectiveFuel)
  log.gauge("turtle_home_distance", homeDist)
  log.gauge("turtle_column", runState.column())
  log.gauge("turtle_shaft_y", currentShaftY())
  log.flush_gauges()
end

local function run()
  local ok, reason = initialize()
  if not ok then
    returnHome(reason)
    return
  end

  while true do
    reportGauges()
    ok, reason = ensureCanContinue()
    if not ok then
      if handleCannotContinue(reason) then
        ok, reason = goToCurrentShaft()
        if not ok then
          recoverOrStop(reason)
          return
        end
      else
        return
      end
    end

    ok, reason = goToCurrentShaft()
    if not ok then
      recoverOrStop(reason)
      return
    end

    if runState.direction() == "down" then
      ok, reason = mineVisibleOreFromShaft()
      if not ok then
        if handleCannotContinue(reason) then
          ok, reason = goToCurrentShaft()
          if not ok then
            recoverOrStop(reason)
            return
          end
        else
          return
        end
      end
    end

    ok, reason = ensureCanContinue()
    if not ok then
      if handleCannotContinue(reason) then
        ok, reason = goToCurrentShaft()
        if not ok then
          recoverOrStop(reason)
          return
        end
      else
        return
      end
    end

    ok, reason = advanceShaft()
    if not ok then
      recoverOrStop(reason)
      return
    end
  end
end

local function keyListener()
  while true do
    local _, key = os.pullEvent("key")
    if key == keys.r then
      print("Recall requested - returning home")
      recall.request()
    end
  end
end

parallel.waitForAny(run, keyListener)
log.delete_gauges()
