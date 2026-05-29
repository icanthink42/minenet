local config = require("miner_config")
local inventory = require("miner_inventory")
local log = require("logger")

local fuel = {}

---@return boolean
local function isUnlimited()
  return turtle.getFuelLevel() == "unlimited"
end

---@return integer
function fuel.charcoalCount()
  return inventory.countMatching(config.charcoalItems)
end

---@return boolean
function fuel.shouldReturn()
  if isUnlimited() then
    return false
  end

  return fuel.charcoalCount() <= config.charcoalReserve
end

---@param level integer
---@param reserve integer
---@return boolean
---@return string?
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

---@param level integer
---@return boolean
---@return string?
function fuel.ensure(level)
  return ensureWithReserve(level, config.charcoalReserve)
end

---@param level integer
---@return boolean
---@return string?
function fuel.ensureEmergency(level)
  return ensureWithReserve(level, 0)
end

---@return boolean
---@return string?
function fuel.refuelFromCharcoal()
  return fuel.ensure(config.minFuelLevel)
end

return fuel
