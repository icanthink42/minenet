local config = require("miner_config")
local fuel = require("miner_fuel")
local inventory = require("miner_inventory")
local movement = require("movement")
local ore = require("miner_ore")
local scanner = require("miner_scanner")
local runState = require("miner_state")

local function baseShaftX()
  return runState.column() * config.shaftSpacing()
end

local function baseShaftZ()
  return 0
end

local function currentColumnX()
  return baseShaftX() + runState.detourX()
end

local function currentColumnZ()
  return baseShaftZ() + runState.detourZ()
end

local function shaftX()
  return baseShaftX()
end

local function shaftZ()
  return baseShaftZ()
end

local function homeFuelNeed(extra)
  local pos = movement.position()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z) + (extra or 64)
end

local function returnHome(reason)
  print("Returning home: " .. tostring(reason))
  fuel.ensureEmergency(homeFuelNeed(256))

  local ok, moveReason = movement.goTo(0, 0, 0)
  if not ok then
    print("Failed to return home: " .. tostring(moveReason))
    while true do
      os.sleep(5)
      ok, moveReason = movement.goTo(0, 0, 0)
      if ok then
        break
      end
      print("Still trying to return home: " .. tostring(moveReason))
    end
  end

  movement.face("north")
  print("Stopped at home")
end

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

local function unloadAtHome()
  print("Inventory full, returning home to unload")
  local resume = movement.position()
  fuel.ensureEmergency(homeFuelNeed(256))

  local ok, reason = movement.goTo(0, 0, 0)
  if not ok then
    return false
  end

  movement.face("north")

  if not tryDepositAroundHome() then
    print("No chest with space next to home")
    return false
  end

  movement.face("north")
  if inventory.isFull() then
    return false
  end

  ok, reason = movement.goTo(resume.x, resume.y, resume.z)
  if not ok then
    return false
  end

  return movement.face(resume.facing)
end

local function handleCannotContinue(reason)
  if reason == "inventory full" then
    if unloadAtHome() then
      return true
    end
  end

  returnHome(reason)
  return false
end

local function recoverOrStop(reason)
  returnHome(reason)
  return false
end

local function ensureCanContinue()
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

local function currentShaftY()
  local y = movement.position().y
  if y > 0 then
    return 0
  end

  if runState.direction() == "up" then
    return y
  end

  local bedrockY = runState.bedrockY()
  if bedrockY and y < bedrockY then
    return bedrockY
  end

  return y
end

local function goToCurrentShaft()
  local ok, reason = movement.goTo(shaftX(), currentShaftY(), shaftZ())
  if not ok then
    return false, reason
  end

  return movement.face("north")
end

local function initialize()
  local ok, reason = movement.load()
  if not ok then
    return false, reason
  end

  ok, reason = runState.load()
  if not ok then
    return false, reason
  end

  if not runState.initialized() then
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

  return true
end

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
  local blocks
  blocks, reason = scanner.scan(config.scanRadius)
  if not blocks then
    return false, reason
  end

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

  local minedTargets = {}
  for _, target in ipairs(targets) do
    local targetKey = tostring(target.x) .. "," .. tostring(target.y) .. "," .. tostring(target.z)
    if not minedTargets[targetKey] then
      ok, reason = ensureCanContinue()
      if not ok then
        return false, reason
      end

      local minedVein
      ok, minedVein = ore.mineVeinAt(target)
      if not ok then
        return false, minedVein
      end

      for minedKey in pairs(minedVein) do
        minedTargets[minedKey] = true
      end
    end
  end

  ok, reason = movement.goTo(shaftPos.x, shaftPos.y, shaftPos.z)
  if not ok then
    return false, reason
  end

  return movement.face("north")
end

local detourDirections = {
  { x = 1, z = 0 },
  { x = -1, z = 0 },
  { x = 0, z = 1 },
  { x = 0, z = -1 },
}

local function detourVertical(verticalStep)
  local current = movement.position()

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
        return true
      end
    end

    distance = distance + 1
    os.sleep(0.25)
  end
end

local function advanceShaft()
  local direction = runState.direction()
  local y = movement.position().y

  if direction == "down" then
    local ok, reason = movement.down()
    if ok then
      return true
    end

    if reason and reason:find("minecraft:bedrock") then
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

      ok, reason = runState.advance()
      if not ok then
        return false, reason
      end

      ok, reason = movement.up()
      if ok then
        return true
      end

      return detourVertical(1)
    end

    return detourVertical(-1)
  end

  if y >= 0 then
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

  return detourVertical(1)
end

local function run()
  local ok, reason = initialize()
  if not ok then
    returnHome(reason)
    return
  end

  while true do
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

run()
