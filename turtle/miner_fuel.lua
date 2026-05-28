local config = require("miner_config")
local inventory = require("miner_inventory")
local log = require("logger")

local fuel = {}

local function isUnlimited()
  return turtle.getFuelLevel() == "unlimited"
end

function fuel.charcoalCount()
  return inventory.countMatching(config.charcoalItems)
end

function fuel.shouldReturn()
  if isUnlimited() then
    return false
  end

  return fuel.charcoalCount() <= config.charcoalReserve
end

local function ensureWithReserve(level, reserve)
  if isUnlimited() then
    return true
  end

  while turtle.getFuelLevel() < level do
    if fuel.charcoalCount() <= reserve then
      return false, "charcoal reserve reached"
    end

    local slot = inventory.findMatching(config.charcoalItems, 1)
    if not slot then
      return false, "no charcoal found"
    end

    local previousSlot = turtle.getSelectedSlot()
    turtle.select(slot)
    local ok, reason = turtle.refuel(1)
    turtle.select(previousSlot)

    if not ok then
      return false, reason
    end

    log.info("Refueled with charcoal; fuel level=" .. tostring(turtle.getFuelLevel()))
  end

  return true
end

function fuel.ensure(level)
  return ensureWithReserve(level, config.charcoalReserve)
end

function fuel.ensureEmergency(level)
  return ensureWithReserve(level, 0)
end

function fuel.refuelFromCharcoal()
  return fuel.ensure(config.minFuelLevel)
end

return fuel
