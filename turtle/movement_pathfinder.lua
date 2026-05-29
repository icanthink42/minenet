local pathfinder = {}

---@class Bounds
---@field minX number
---@field maxX number
---@field minY number
---@field maxY number
---@field minZ number
---@field maxZ number

local directions = {
  { x = 1, y = 0, z = 0 },
  { x = -1, y = 0, z = 0 },
  { x = 0, y = 0, z = 1 },
  { x = 0, y = 0, z = -1 },
  { x = 0, y = 1, z = 0 },
  { x = 0, y = -1, z = 0 },
}

---@param x number
---@param y number
---@param z number
---@return string
local function key(x, y, z)
  return tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
end

---@param node Vec3
---@param bounds Bounds
---@return boolean
local function insideBounds(node, bounds)
  return node.x >= bounds.minX
    and node.x <= bounds.maxX
    and node.y >= bounds.minY
    and node.y <= bounds.maxY
    and node.z >= bounds.minZ
    and node.z <= bounds.maxZ
end

---@param start Vec3
---@param target Vec3
---@param padding number
---@return Bounds
local function boundsFor(start, target, padding)
  return {
    minX = math.min(start.x, target.x) - padding,
    maxX = math.max(start.x, target.x) + padding,
    minY = math.min(start.y, target.y) - padding,
    maxY = math.max(start.y, target.y) + padding,
    minZ = math.min(start.z, target.z) - padding,
    maxZ = math.max(start.z, target.z) + padding,
  }
end

---@param cameFrom table<string, string>
---@param currentKey string
---@param nodes table<string, Vec3>
---@return Vec3[]
local function buildPath(cameFrom, currentKey, nodes)
  local path = {}

  while cameFrom[currentKey] do
    table.insert(path, 1, nodes[currentKey])
    currentKey = cameFrom[currentKey]
  end

  return path
end

---@param x number
---@param y number
---@param z number
---@return string
function pathfinder.key(x, y, z)
  return key(x, y, z)
end

---@param start Vec3
---@param target Vec3
---@param blocked table<string, boolean>
---@param padding number
---@return Vec3[]?
function pathfinder.findPath(start, target, blocked, padding)
  local startKey = key(start.x, start.y, start.z)
  local targetKey = key(target.x, target.y, target.z)

  if startKey == targetKey then
    return {}
  end

  local bounds = boundsFor(start, target, padding)
  local queue = { start }
  local queueIndex = 1
  local visited = { [startKey] = true }
  local cameFrom = {}
  local nodes = { [startKey] = start }

  while queueIndex <= #queue do
    local current = queue[queueIndex]
    queueIndex = queueIndex + 1

    for _, dir in ipairs(directions) do
      local nextNode = {
        x = current.x + dir.x,
        y = current.y + dir.y,
        z = current.z + dir.z,
      }
      local nextKey = key(nextNode.x, nextNode.y, nextNode.z)

      if not visited[nextKey] and not blocked[nextKey] and insideBounds(nextNode, bounds) then
        visited[nextKey] = true
        cameFrom[nextKey] = key(current.x, current.y, current.z)
        nodes[nextKey] = nextNode

        if nextKey == targetKey then
          return buildPath(cameFrom, nextKey, nodes)
        end

        table.insert(queue, nextNode)
      end
    end
  end

  return nil
end

return pathfinder
