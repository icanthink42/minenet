local inventory = {}

function inventory.isFull()
  for slot = 1, 16 do
    if turtle.getItemCount(slot) == 0 then
      return false
    end
  end

  return true
end

function inventory.countMatching(items)
  local count = 0
  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and items[detail.name] then
      count = count + detail.count
    end
  end

  return count
end

function inventory.findMatching(items, minCount)
  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and items[detail.name] and detail.count >= (minCount or 1) then
      return slot, detail
    end
  end

  return nil
end

return inventory
