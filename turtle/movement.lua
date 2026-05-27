local movement = {}
local state = require("movement_state")
local mining = require("movement_mining")

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

function movement.goTo(x, y, z)
  if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
    return false, "goTo expects numeric x, y, z"
  end

  while state.y() < y do
    local ok, reason = movement.up()
    if not ok then
      return false, reason
    end
  end

  while state.y() > y do
    local ok, reason = movement.down()
    if not ok then
      return false, reason
    end
  end

  while state.x() < x do
    local ok, reason = movement.face("east")
    if not ok then
      return false, reason
    end

    ok, reason = movement.forward()
    if not ok then
      return false, reason
    end
  end

  while state.x() > x do
    local ok, reason = movement.face("west")
    if not ok then
      return false, reason
    end

    ok, reason = movement.forward()
    if not ok then
      return false, reason
    end
  end

  while state.z() < z do
    local ok, reason = movement.face("south")
    if not ok then
      return false, reason
    end

    ok, reason = movement.forward()
    if not ok then
      return false, reason
    end
  end

  while state.z() > z do
    local ok, reason = movement.face("north")
    if not ok then
      return false, reason
    end

    ok, reason = movement.forward()
    if not ok then
      return false, reason
    end
  end

  return true
end

state.load()

return movement
