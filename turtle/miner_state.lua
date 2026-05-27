local minerState = {}

local stateFile = ".miner_state"

local state = {
  column = 0,
  direction = "down",
  initialized = false,
  bedrockY = nil,
  detourX = 0,
  detourZ = 0,
}

local function serialize(value)
  if textutils and textutils.serialize then
    return textutils.serialize(value)
  end

  local bedrock = "nil"
  if type(value.bedrockY) == "number" then
    bedrock = tostring(value.bedrockY)
  end

  return string.format(
    "{column=%d,direction=%q,initialized=%s,bedrockY=%s,detourX=%d,detourZ=%d}",
    value.column,
    value.direction,
    tostring(value.initialized),
    bedrock,
    value.detourX or value.offsetX or 0,
    value.detourZ or value.offsetZ or 0
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

local function valid(value)
  return type(value) == "table"
    and type(value.column) == "number"
    and (value.direction == "down" or value.direction == "up")
    and (value.initialized == nil or type(value.initialized) == "boolean")
    and (value.bedrockY == nil or type(value.bedrockY) == "number")
    and (value.offsetX == nil or type(value.offsetX) == "number")
    and (value.offsetZ == nil or type(value.offsetZ) == "number")
    and (value.detourX == nil or type(value.detourX) == "number")
    and (value.detourZ == nil or type(value.detourZ) == "number")
end

function minerState.save()
  local handle, err = fs.open(stateFile, "w")
  if not handle then
    return false, err
  end

  handle.write(serialize(state))
  handle.close()
  return true
end

function minerState.load()
  if not fs.exists(stateFile) then
    minerState.save()
    return true
  end

  local handle, err = fs.open(stateFile, "r")
  if not handle then
    return false, err
  end

  local content = handle.readAll()
  handle.close()

  local loaded = unserialize(content)
  if not valid(loaded) then
    return false, "invalid miner state in " .. stateFile
  end

  state.column = loaded.column
  state.direction = loaded.direction
  state.initialized = loaded.initialized == true
  state.bedrockY = loaded.bedrockY
  state.detourX = loaded.detourX or loaded.offsetX or 0
  state.detourZ = loaded.detourZ or loaded.offsetZ or 0
  return true
end

function minerState.get()
  return {
    column = state.column,
    direction = state.direction,
    initialized = state.initialized,
    bedrockY = state.bedrockY,
    detourX = state.detourX,
    detourZ = state.detourZ,
  }
end

function minerState.column()
  return state.column
end

function minerState.direction()
  return state.direction
end

function minerState.detourX()
  return state.detourX
end

function minerState.detourZ()
  return state.detourZ
end

function minerState.setDetour(x, z)
  if type(x) ~= "number" or type(z) ~= "number" then
    return false, "detour x and z must be numbers"
  end

  state.detourX = x
  state.detourZ = z
  return minerState.save()
end

function minerState.clearDetour()
  return minerState.setDetour(0, 0)
end

function minerState.initialized()
  return state.initialized
end

function minerState.bedrockY()
  return state.bedrockY
end

function minerState.setBedrockY(y)
  if type(y) ~= "number" then
    return false, "bedrock y must be a number"
  end

  state.bedrockY = y
  return minerState.save()
end

function minerState.markInitialized()
  state.initialized = true
  return minerState.save()
end

function minerState.set(column, direction)
  if type(column) ~= "number" then
    return false, "column must be a number"
  end

  if direction ~= "down" and direction ~= "up" then
    return false, "direction must be down or up"
  end

  state.column = column
  state.direction = direction
  return minerState.save()
end

function minerState.advance()
  state.column = state.column + 1
  state.detourX = 0
  state.detourZ = 0
  if state.direction == "down" then
    state.direction = "up"
  else
    state.direction = "down"
  end

  return minerState.save()
end

return minerState
