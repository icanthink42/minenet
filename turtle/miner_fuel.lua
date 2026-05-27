local config = require("miner_config")
local inventory = require("miner_inventory")

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

function fuel.ensure(level)
  if isUnlimited() then
    return true
  end

  while turtle.getFuelLevel() < level do
    if fuel.charcoalCount() <= config.charcoalReserve then
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
  end

  return true
end

function fuel.refuelFromCharcoal()
  return fuel.ensure(config.minFuelLevel)
end

return fuel
