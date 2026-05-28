local fuel = require("miner_fuel")
local inventory = require("miner_inventory")
local config = require("miner_config")
local movement = require("movement")
local mining = require("movement_mining")

local ore = {}

local neighborDirs = {
  { x = 1, y = 0, z = 0, facing = "east", inspect = turtle.inspect, dig = movement.digForward },
  { x = -1, y = 0, z = 0, facing = "west", inspect = turtle.inspect, dig = movement.digForward },
  { x = 0, y = 0, z = 1, facing = "south", inspect = turtle.inspect, dig = movement.digForward },
  { x = 0, y = 0, z = -1, facing = "north", inspect = turtle.inspect, dig = movement.digForward },
  { x = 0, y = 1, z = 0, inspect = turtle.inspectUp, dig = movement.digUp },
  { x = 0, y = -1, z = 0, inspect = turtle.inspectDown, dig = movement.digDown },
}

local function key(x, y, z)
  return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

local function oreFamily(name)
  return config.oreFamily(name)
end

local function fuelNeededToReachHome()
  local pos = movement.position()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z) + 64
end

local function ensureCanMineOre()
  inventory.cleanup()

  if inventory.isFull() then
    return false, "inventory full"
  end

  if fuel.shouldReturn() then
    return false, "charcoal reserve reached"
  end

  return fuel.ensure(fuelNeededToReachHome())
end

local function inspectDirection(dir)
  if dir.facing then
    local ok, reason = movement.face(dir.facing)
    if not ok then
      return false, nil, reason
    end
  end

  local exists, block = dir.inspect()
  return exists, block
end

local function digDirection(dir)
  if dir.facing then
    local ok, reason = movement.face(dir.facing)
    if not ok then
      return false, reason
    end
  end

  return dir.dig()
end

local function moveIntoDirection(dir)
  if dir.y == 1 then
    return movement.up()
  end

  if dir.y == -1 then
    return movement.down()
  end

  local ok, reason = movement.face(dir.facing)
  if not ok then
    return false, reason
  end

  return movement.forward()
end

local function findAdjacentOre(targetFamily, visited)
  local pos = movement.position()

  for _, dir in ipairs(neighborDirs) do
    local x = pos.x + dir.x
    local y = pos.y + dir.y
    local z = pos.z + dir.z
    local blockKey = key(x, y, z)

    if not visited[blockKey] then
      local exists, block, reason = inspectDirection(dir)
      if reason then
        return nil, reason
      end

      if exists
        and mining.isOre(block)
        and config.allowsOre(block.name)
        and oreFamily(block.name) == targetFamily then
        return {
          x = x,
          y = y,
          z = z,
          dir = dir,
        }
      end
    end
  end

  return nil
end

local function mineConnectedOre(targetFamily, visited)
  local origin = movement.position()

  while true do
    local ok, reason = ensureCanMineOre()
    if not ok then
      return false, reason
    end

    local nextOre
    nextOre, reason = findAdjacentOre(targetFamily, visited)
    if reason then
      return false, reason
    end

    if not nextOre then
      return true
    end

    ok, reason = digDirection(nextOre.dir)
    if not ok then
      return false, reason
    end

    visited[key(nextOre.x, nextOre.y, nextOre.z)] = true

    ok, reason = moveIntoDirection(nextOre.dir)
    if not ok then
      return false, reason
    end

    ok, reason = mineConnectedOre(targetFamily, visited)
    if not ok then
      return false, reason
    end

    ok, reason = movement.goTo(origin.x, origin.y, origin.z)
    if not ok then
      return false, reason
    end
  end
end

function ore.mineVeinAt(target)
  local targetFamily = oreFamily(target.name)
  local approach = {
    { x = 1, y = 0, z = 0 },
    { x = -1, y = 0, z = 0 },
    { x = 0, y = 0, z = 1 },
    { x = 0, y = 0, z = -1 },
    { x = 0, y = 1, z = 0 },
    { x = 0, y = -1, z = 0 },
  }

  local ok, reason
  local found = false

  for _, dir in ipairs(approach) do
    ok, reason = movement.tryGoTo(target.x + dir.x, target.y + dir.y, target.z + dir.z)
    if ok then
      local adjacent = findAdjacentOre(targetFamily, {})
      if adjacent
        and adjacent.x == target.x
        and adjacent.y == target.y
        and adjacent.z == target.z then
        found = true
        break
      end
    end
  end

  if not found then
    return true, {}
  end

  ok, reason = movement.goTo(target.x, target.y, target.z)
  if not ok then
    return false, reason
  end

  local visited = {
    [key(target.x, target.y, target.z)] = true,
  }

  ok, reason = mineConnectedOre(targetFamily, visited)
  if not ok then
    return false, reason
  end

  return true, visited
end

function ore.family(name)
  return oreFamily(name)
end

return ore
