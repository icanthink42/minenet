local chest = {}

local ignoredPeripheralTypes = {
  chatBox = true,
  chat_box = true,
  modem = true,
  monitor = true,
  printer = true,
  drive = true,
  speaker = true,
}

local function isInventory(name)
  local types = { peripheral.getType(name) }

  for _, peripheralType in ipairs(types) do
    if ignoredPeripheralTypes[peripheralType] then
      return false
    end
  end

  local wrapped = peripheral.wrap(name)
  return wrapped and type(wrapped.list) == "function"
end

function chest.find()
  for _, name in ipairs(peripheral.getNames()) do
    if isInventory(name) then
      return peripheral.wrap(name), name
    end
  end

  return nil, "no chest/inventory peripheral found"
end

function chest.snapshot(inventory)
  local items = inventory.list()
  local snapshot = {}

  for slot, item in pairs(items) do
    snapshot[slot] = {
      name = item.name,
      count = item.count,
      nbt = item.nbt,
    }
  end

  return snapshot
end

function chest.equals(left, right)
  for slot = 1, math.max(#left, #right, 256) do
    local a = left[slot]
    local b = right[slot]

    if a or b then
      if not a or not b then
        return false
      end

      if a.name ~= b.name or a.count ~= b.count or a.nbt ~= b.nbt then
        return false
      end
    end
  end

  return true
end

function chest.summary(inventory)
  local totals = {}
  local names = {}

  for _, item in pairs(inventory.list()) do
    if not totals[item.name] then
      totals[item.name] = 0
      table.insert(names, item.name)
    end

    totals[item.name] = totals[item.name] + item.count
  end

  table.sort(names)

  if #names == 0 then
    return "Chest is empty."
  end

  local lines = {}
  for _, name in ipairs(names) do
    table.insert(lines, totals[name] .. "x " .. name)
  end

  return table.concat(lines, "\n")
end

function chest.itemCount(inventory)
  local total = 0

  for _, item in pairs(inventory.list()) do
    total = total + item.count
  end

  return total
end

return chest
