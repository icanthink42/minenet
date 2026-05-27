local config = require("miner_config")
local fuel = require("miner_fuel")
local inventory = require("miner_inventory")
local movement = require("movement")
local scanner = require("miner_scanner")

local ore = {}

local function absolutePosition(relativeBlock)
  local pos = movement.position()
  return {
    x = pos.x + relativeBlock.x,
    y = pos.y + relativeBlock.y,
    z = pos.z + relativeBlock.z,
  }
end

local function moveToBlock(block)
  local target = absolutePosition(block)
  return movement.goTo(target.x, target.y, target.z)
end

local function fuelNeededToReachHome()
  local pos = movement.position()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z) + 64
end

function ore.mineNearestGroup()
  movement.face("north")

  local blocks, reason = scanner.scan(config.scanRadius)
  if not blocks then
    return false, reason
  end

  local first = scanner.nearestOre(blocks)
  if not first then
    return true, false
  end

  local oreName = first.name
  local mined = 0

  while mined < 256 do
    if inventory.isFull() then
      return false, "inventory full"
    end

    if fuel.shouldReturn() then
      return false, "charcoal reserve reached"
    end

    local fueled, fuelReason = fuel.ensure(fuelNeededToReachHome())
    if not fueled then
      return false, fuelReason
    end

    movement.face("north")

    blocks, reason = scanner.scan(config.scanRadius)
    if not blocks then
      return false, reason
    end

    local nextOre = scanner.nearestOreByName(blocks, oreName)
    if not nextOre then
      return true, true
    end

    local ok, moveReason = moveToBlock(nextOre)
    if not ok then
      return false, moveReason
    end

    mined = mined + 1
  end

  return false, "ore group exceeded mining limit"
end

return ore
