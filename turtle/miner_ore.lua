local config = require("miner_config")
local fuel = require("miner_fuel")
local inventory = require("miner_inventory")
local movement = require("movement")
local scanner = require("miner_scanner")

local ore = {}

local neighborDirs = {
  { x = 1, y = 0, z = 0, facing = "east" },
  { x = -1, y = 0, z = 0, facing = "west" },
  { x = 0, y = 0, z = 1, facing = "south" },
  { x = 0, y = 0, z = -1, facing = "north" },
  { x = 0, y = 1, z = 0, vertical = "up" },
  { x = 0, y = -1, z = 0, vertical = "down" },
}

local function key(x, y, z)
  return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

local function oreFamily(name)
  local namespace, path = name:match("^([^:]+):(.+)$")
  if not namespace then
    return name
  end

  path = path:gsub("^deepslate_", "")
  return namespace .. ":" .. path
end

local function fuelNeededToReachHome()
  local pos = movement.position()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z) + 64
end

local function ensureCanMineOre()
  inventory.dropTrash()

  if inventory.isFull() then
    return false, "inventory full"
  end

  if fuel.shouldReturn() then
    return false, "charcoal reserve reached"
  end

  return fuel.ensure(fuelNeededToReachHome())
end

local function absoluteBlock(block)
  local pos = movement.position()
  return {
    name = block.name,
    x = pos.x + block.x,
    y = pos.y + block.y,
    z = pos.z + block.z,
  }
end

local function nearestKnownOre(targetFamily, known, mined)
  local pos = movement.position()
  local best = nil
  local bestDistance = nil

  for blockKey, block in pairs(known) do
    if not mined[blockKey] and oreFamily(block.name) == targetFamily then
      local dx = block.x - pos.x
      local dy = block.y - pos.y
      local dz = block.z - pos.z
      local distance = dx * dx + dy * dy + dz * dz

      if not bestDistance or distance < bestDistance then
        best = block
        bestDistance = distance
      end
    end
  end

  return best
end

local function rememberVisibleOre(targetFamily, known, mined)
  movement.face("north")

  local blocks, reason = scanner.scan(config.scanRadius)
  if not blocks then
    return false, reason
  end

  for _, block in ipairs(blocks) do
    if oreFamily(block.name) == targetFamily then
      local absolute = absoluteBlock(block)
      local blockKey = key(absolute.x, absolute.y, absolute.z)
      if not mined[blockKey] then
        known[blockKey] = absolute
      end
    end
  end

  return true
end

local function digNeighborOre(targetFamily, known, mined)
  local pos = movement.position()
  local found = false

  for _, dir in ipairs(neighborDirs) do
    local neighborKey = key(pos.x + dir.x, pos.y + dir.y, pos.z + dir.z)
    local block = known[neighborKey]

    if block and oreFamily(block.name) == targetFamily and not mined[neighborKey] then
      local ok, reason
      if dir.vertical == "up" then
        ok, reason = movement.digUp()
      elseif dir.vertical == "down" then
        ok, reason = movement.digDown()
      else
        ok, reason = movement.face(dir.facing)
        if ok then
          ok, reason = movement.digForward()
        end
      end

      if not ok then
        return false, reason
      end

      mined[neighborKey] = true
      known[neighborKey] = nil
      found = true
    end
  end

  return true, found
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

  local targetFamily = oreFamily(first.name)
  local known = {}
  local mined = {}
  local minedCount = 0

  local ok
  ok, reason = rememberVisibleOre(targetFamily, known, mined)
  if not ok then
    return false, reason
  end

  while minedCount < 512 do
    ok, reason = ensureCanMineOre()
    if not ok then
      return false, reason
    end

    ok, reason = rememberVisibleOre(targetFamily, known, mined)
    if not ok then
      return false, reason
    end

    local dugAny
    ok, dugAny = digNeighborOre(targetFamily, known, mined)
    if not ok then
      return false, dugAny
    end

    if dugAny then
      minedCount = minedCount + 1
    else
      local nextOre = nearestKnownOre(targetFamily, known, mined)
      if not nextOre then
        return true, minedCount > 0
      end

      ok, reason = movement.goTo(nextOre.x, nextOre.y, nextOre.z)
      if not ok then
        return false, reason
      end

      local oreKey = key(nextOre.x, nextOre.y, nextOre.z)
      mined[oreKey] = true
      known[oreKey] = nil
      minedCount = minedCount + 1
    end
  end

  return false, "ore group exceeded mining limit"
end

return ore
