local movementState = {}

local stateFile = ".movement_state"

local dirs = {
  north = { x = 0, z = -1 },
  east = { x = 1, z = 0 },
  south = { x = 0, z = 1 },
  west = { x = -1, z = 0 },
}

local dirOrder = { "north", "east", "south", "west" }
local dirIndex = {
  north = 1,
  east = 2,
  south = 3,
  west = 4,
}

local state = {
  x = 0,
  y = 0,
  z = 0,
  facing = "north",
}

local function serialize(value)
  if textutils and textutils.serialize then
    return textutils.serialize(value)
  end

  return string.format(
    "{x=%d,y=%d,z=%d,facing=%q}",
    value.x,
    value.y,
    value.z,
    value.facing
  )
end

local function unserialize(value)
  if textutils and textutils.unserialize then
    return textutils.unserialize(value)
  end

  local chunk = load("return " .. value)
  if not chunk then
    return nil
  end

  local ok, result = pcall(chunk)
  if ok then
    return result
  end

  return nil
end

local function validState(value)
  return type(value) == "table"
    and type(value.x) == "number"
    and type(value.y) == "number"
    and type(value.z) == "number"
    and dirIndex[value.facing] ~= nil
end

function movementState.save()
  local handle, err = fs.open(stateFile, "w")
  if not handle then
    return false, err
  end

  handle.write(serialize(state))
  handle.close()
  return true
end

function movementState.load()
  if not fs.exists(stateFile) then
    movementState.save()
    return true
  end

  local handle, err = fs.open(stateFile, "r")
  if not handle then
    return false, err
  end

  local content = handle.readAll()
  handle.close()

  local loaded = unserialize(content)
  if not validState(loaded) then
    return false, "invalid movement state in " .. stateFile
  end

  state.x = loaded.x
  state.y = loaded.y
  state.z = loaded.z
  state.facing = loaded.facing
  return true
end

function movementState.position()
  return {
    x = state.x,
    y = state.y,
    z = state.z,
    facing = state.facing,
  }
end

function movementState.resetHome(facing)
  if facing ~= nil and dirIndex[facing] == nil then
    return false, "unknown facing: " .. tostring(facing)
  end

  state.x = 0
  state.y = 0
  state.z = 0
  state.facing = facing or "north"
  return movementState.save()
end

function movementState.facing()
  return state.facing
end

function movementState.facingIndex(facing)
  return dirIndex[facing]
end

function movementState.turnLeft()
  movementState.setFacingIndex(dirIndex[state.facing] - 1)
end

function movementState.turnRight()
  movementState.setFacingIndex(dirIndex[state.facing] + 1)
end

function movementState.setFacingIndex(index)
  while index < 1 do
    index = index + #dirOrder
  end

  while index > #dirOrder do
    index = index - #dirOrder
  end

  state.facing = dirOrder[index]
end

function movementState.moveHorizontal(distance)
  local dir = dirs[state.facing]
  state.x = state.x + dir.x * distance
  state.z = state.z + dir.z * distance
end

function movementState.moveVertical(distance)
  state.y = state.y + distance
end

function movementState.x()
  return state.x
end

function movementState.y()
  return state.y
end

function movementState.z()
  return state.z
end

return movementState
