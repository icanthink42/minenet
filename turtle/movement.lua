local movement = {}
local state = require("movement_state")
local mining = require("movement_mining")
local pathfinder = require("movement_pathfinder")
local log = require("logger")

---@param inspectFn fun(): boolean, Block
---@return boolean
local function isClear(inspectFn)
  if not inspectFn then
    return false
  end

  local exists = inspectFn()
  return not exists
end

---@param turtleFn fun(): boolean, string?
---@param updateState fun()
---@param inspectFn? fun(): boolean, Block
---@param digFn? fun(): boolean, string?
---@return boolean
---@return string?
local function move(turtleFn, updateState, inspectFn, digFn)
  for _ = 1, 16 do
    if inspectFn and digFn then
      local cleared, clearReason = mining.clear(inspectFn, digFn)
      if not cleared then
        return false, clearReason
      end
    end

    local ok, reason = turtleFn()
    if ok then
      updateState()
      local saved, saveReason = state.save()
      if not saved then
        return false, saveReason
      end

      log.gauge("turtle_x", state.x())
      log.gauge("turtle_y", state.y())
      log.gauge("turtle_z", state.z())
      log.flush_gauges()

      return true
    end

    if not inspectFn then
      return false, reason
    end

    if isClear(inspectFn) then
      os.sleep(0.25)
    else
      return false, reason
    end
  end

  if inspectFn and isClear(inspectFn) then
    return false, "blocked by liquid or entity"
  end

  return false, "blocked after repeated mining attempts"
end

---@return boolean
---@return string?
function movement.load()
  return state.load()
end

---@return boolean
---@return string?
function movement.save()
  return state.save()
end

---@return Position
function movement.position()
  return state.position()
end

---@return table<string, boolean>
function movement.allowedBlocks()
  return mining.allowedBlocks()
end

---@param name string
---@return boolean
---@return string?
function movement.allowBlock(name)
  return mining.allowBlock(name)
end

---@param name string
---@return boolean
---@return string?
function movement.disallowBlock(name)
  return mining.disallowBlock(name)
end

---@param facing? Facing
---@return boolean
---@return string?
function movement.resetHome(facing)
  return state.resetHome(facing)
end

---@return boolean
---@return string?
function movement.forward()
  return move(turtle.forward, function()
    state.moveHorizontal(1)
  end, turtle.inspect, turtle.dig)
end

---@return boolean
---@return string?
function movement.back()
  if turtle.back() then
    state.moveHorizontal(-1)
    return state.save()
  end

  local ok, reason = movement.turnAround()
  if not ok then
    return false, reason
  end

  ok, reason = mining.clear(turtle.inspect, turtle.dig)
  local restored, restoreReason = movement.turnAround()
  if not restored then
    return false, restoreReason
  end

  if not ok then
    return false, reason
  end

  return move(turtle.back, function()
    state.moveHorizontal(-1)
  end)
end

---@return boolean
---@return string?
function movement.up()
  return move(turtle.up, function()
    state.moveVertical(1)
  end, turtle.inspectUp, turtle.digUp)
end

---@return boolean
---@return string?
function movement.down()
  return move(turtle.down, function()
    state.moveVertical(-1)
  end, turtle.inspectDown, turtle.digDown)
end

---@return boolean
---@return string?
function movement.digForward()
  return mining.clear(turtle.inspect, turtle.dig)
end

---@return boolean
---@return string?
function movement.digUp()
  return mining.clear(turtle.inspectUp, turtle.digUp)
end

---@return boolean
---@return string?
function movement.digDown()
  return mining.clear(turtle.inspectDown, turtle.digDown)
end

---@return boolean
---@return string?
function movement.forwardWithoutMining()
  return move(turtle.forward, function()
    state.moveHorizontal(1)
  end)
end

---@return boolean
---@return string?
function movement.backWithoutMining()
  return move(turtle.back, function()
    state.moveHorizontal(-1)
  end)
end

---@return boolean
---@return string?
function movement.turnLeft()
  return move(turtle.turnLeft, function()
    state.turnLeft()
  end)
end

---@return boolean
---@return string?
function movement.turnRight()
  return move(turtle.turnRight, function()
    state.turnRight()
  end)
end

---@return boolean
---@return string?
function movement.turnAround()
  local ok, reason = movement.turnRight()
  if not ok then
    return false, reason
  end

  return movement.turnRight()
end

---@param facing Facing
---@return boolean
---@return string?
function movement.face(facing)
  if state.facingIndex(facing) == nil then
    return false, "unknown facing: " .. tostring(facing)
  end

  while state.facing() ~= facing do
    local current = state.facingIndex(state.facing())
    local target = state.facingIndex(facing)
    local rightTurns = (target - current) % 4

    local ok, reason
    if rightTurns == 3 then
      ok, reason = movement.turnLeft()
    else
      ok, reason = movement.turnRight()
    end

    if not ok then
      return false, reason
    end
  end

  return true
end

---@return Vec3
local function currentPosition()
  return {
    x = state.x(),
    y = state.y(),
    z = state.z(),
  }
end

---@param nextNode Vec3
---@return boolean
---@return string?
local function stepTo(nextNode)
  local pos = currentPosition()
  local dx = nextNode.x - pos.x
  local dy = nextNode.y - pos.y
  local dz = nextNode.z - pos.z

  if dy == 1 and dx == 0 and dz == 0 then
    return movement.up()
  end

  if dy == -1 and dx == 0 and dz == 0 then
    return movement.down()
  end

  local ok, reason
  if dx == 1 and dy == 0 and dz == 0 then
    ok, reason = movement.face("east")
  elseif dx == -1 and dy == 0 and dz == 0 then
    ok, reason = movement.face("west")
  elseif dz == 1 and dx == 0 and dy == 0 then
    ok, reason = movement.face("south")
  elseif dz == -1 and dx == 0 and dy == 0 then
    ok, reason = movement.face("north")
  else
    return false, "path step is not adjacent"
  end

  if not ok then
    return false, reason
  end

  return movement.forward()
end

---@param x number
---@param y number
---@param z number
---@param keepTrying boolean
---@return boolean
---@return string?
local function navigateTo(x, y, z, keepTrying)
  if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
    return false, "goTo expects numeric x, y, z"
  end

  local target = { x = x, y = y, z = z }
  local blocked = {}
  local padding = 2
  local failedSteps = 0

  while true do
    local start = currentPosition()
    if start.x == x and start.y == y and start.z == z then
      return true
    end

    if not keepTrying and blocked[pathfinder.key(x, y, z)] then
      return false, "target blocked"
    end

    local path = pathfinder.findPath(start, target, blocked, padding)
    if not path then
      if not keepTrying and padding >= 12 then
        return false, "no route found"
      end

      padding = padding + 2
      os.sleep(0.25)
    else
      for _, nextNode in ipairs(path) do
        local ok, stepReason = stepTo(nextNode)
        if not ok then
          failedSteps = failedSteps + 1
          if stepReason ~= "blocked by liquid or entity" then
            blocked[pathfinder.key(nextNode.x, nextNode.y, nextNode.z)] = true
          end

          padding = math.max(padding, 4)
          if not keepTrying and failedSteps >= 8 then
            return false, "route blocked"
          end

          os.sleep(0.25)
          break
        end
      end
    end
  end
end

---@param x number
---@param y number
---@param z number
---@return boolean
---@return string?
function movement.tryGoTo(x, y, z)
  return navigateTo(x, y, z, false)
end

---@param x number
---@param y number
---@param z number
---@return boolean
---@return string?
function movement.goTo(x, y, z)
  return navigateTo(x, y, z, true)
end

state.load()

return movement
