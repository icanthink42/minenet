local movement = {}
local state = require("movement_state")
local mining = require("movement_mining")
local pathfinder = require("movement_pathfinder")

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

      return true
    end

    if not inspectFn then
      return false, reason
    end
  end

  return false, "blocked after repeated mining attempts"
end

function movement.load()
  return state.load()
end

function movement.save()
  return state.save()
end

function movement.position()
  return state.position()
end

function movement.allowedBlocks()
  return mining.allowedBlocks()
end

function movement.allowBlock(name)
  return mining.allowBlock(name)
end

function movement.disallowBlock(name)
  return mining.disallowBlock(name)
end

function movement.resetHome(facing)
  return state.resetHome(facing)
end

function movement.forward()
  return move(turtle.forward, function()
    state.moveHorizontal(1)
  end, turtle.inspect, turtle.dig)
end

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

function movement.up()
  return move(turtle.up, function()
    state.moveVertical(1)
  end, turtle.inspectUp, turtle.digUp)
end

function movement.down()
  return move(turtle.down, function()
    state.moveVertical(-1)
  end, turtle.inspectDown, turtle.digDown)
end

function movement.forwardWithoutMining()
  return move(turtle.forward, function()
    state.moveHorizontal(1)
  end)
end

function movement.backWithoutMining()
  return move(turtle.back, function()
    state.moveHorizontal(-1)
  end)
end

function movement.turnLeft()
  return move(turtle.turnLeft, function()
    state.turnLeft()
  end)
end

function movement.turnRight()
  return move(turtle.turnRight, function()
    state.turnRight()
  end)
end

function movement.turnAround()
  local ok, reason = movement.turnRight()
  if not ok then
    return false, reason
  end

  return movement.turnRight()
end

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

local function currentPosition()
  return {
    x = state.x(),
    y = state.y(),
    z = state.z(),
  }
end

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
        local ok = stepTo(nextNode)
        if not ok then
          failedSteps = failedSteps + 1
          blocked[pathfinder.key(nextNode.x, nextNode.y, nextNode.z)] = true
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

function movement.tryGoTo(x, y, z)
  return navigateTo(x, y, z, false)
end

function movement.goTo(x, y, z)
  return navigateTo(x, y, z, true)
end

state.load()

return movement
