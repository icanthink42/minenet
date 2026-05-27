local config = require("miner_config")
local fuel = require("miner_fuel")
local inventory = require("miner_inventory")
local movement = require("movement")
local ore = require("miner_ore")
local runState = require("miner_state")

local function shaftX()
  return runState.column() * config.shaftSpacing()
end

local function shaftZ()
  return 0
end

local function homeFuelNeed(extra)
  local pos = movement.position()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z) + (extra or 64)
end

local function returnHome(reason)
  print("Returning home: " .. tostring(reason))
  local ok, moveReason = movement.goTo(0, 0, 0)
  if not ok then
    error("failed to return home: " .. tostring(moveReason))
  end

  movement.face("north")
  print("Stopped at home")
end

local function ensureCanContinue()
  inventory.dropTrash()

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
  if y > config.maxHeight then
    return config.maxHeight
  end

  if y < config.minHeight then
    return config.minHeight
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

    ok, reason = movement.goTo(shaftX(), config.maxHeight, shaftZ())
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
  while true do
    local ok, reason = ensureCanContinue()
    if not ok then
      return false, reason
    end

    ok, reason = goToCurrentShaft()
    if not ok then
      return false, reason
    end

    local mined
    ok, mined = ore.mineNearestGroup()
    if not ok then
      return false, mined
    end

    ok, reason = goToCurrentShaft()
    if not ok then
      return false, reason
    end

    if not mined then
      return true
    end
  end
end

local function advanceShaft()
  local direction = runState.direction()
  local y = movement.position().y

  if direction == "down" then
    if y <= config.minHeight then
      local ok, reason = runState.advance()
      if not ok then
        return false, reason
      end

      return movement.goTo(shaftX(), config.minHeight, shaftZ())
    end

    return movement.down()
  end

  if y >= config.maxHeight then
    local ok, reason = runState.advance()
    if not ok then
      return false, reason
    end

    return movement.goTo(shaftX(), config.maxHeight, shaftZ())
  end

  return movement.up()
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
      returnHome(reason)
      return
    end

    ok, reason = goToCurrentShaft()
    if not ok then
      error(reason)
    end

    ok, reason = mineVisibleOreFromShaft()
    if not ok then
      returnHome(reason)
      return
    end

    ok, reason = ensureCanContinue()
    if not ok then
      returnHome(reason)
      return
    end

    ok, reason = advanceShaft()
    if not ok then
      error(reason)
    end
  end
end

run()
