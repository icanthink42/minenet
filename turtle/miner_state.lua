local minerState = {}

local stateFile = ".miner_state"

local state = {
  column = 0,
  direction = "down",
  initialized = false,
}

local function serialize(value)
  if textutils and textutils.serialize then
    return textutils.serialize(value)
  end

  return string.format(
    "{column=%d,direction=%q,initialized=%s}",
    value.column,
    value.direction,
    tostring(value.initialized)
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
  return true
end

function minerState.get()
  return {
    column = state.column,
    direction = state.direction,
    initialized = state.initialized,
  }
end

function minerState.column()
  return state.column
end

function minerState.direction()
  return state.direction
end

function minerState.initialized()
  return state.initialized
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
  if state.direction == "down" then
    state.direction = "up"
  else
    state.direction = "down"
  end

  return minerState.save()
end

return minerState
