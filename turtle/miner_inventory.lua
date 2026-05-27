local inventory = {}

local trashItems = {
  ["minecraft:stone"] = true,
  ["minecraft:cobblestone"] = true,
  ["minecraft:deepslate"] = true,
  ["minecraft:cobbled_deepslate"] = true,
  ["minecraft:dirt"] = true,
  ["minecraft:coarse_dirt"] = true,
  ["minecraft:rooted_dirt"] = true,
  ["minecraft:grass_block"] = true,
  ["minecraft:gravel"] = true,
  ["minecraft:flint"] = true,
  ["minecraft:sand"] = true,
  ["minecraft:red_sand"] = true,
  ["minecraft:sandstone"] = true,
  ["minecraft:red_sandstone"] = true,
  ["minecraft:clay"] = true,
  ["minecraft:granite"] = true,
  ["minecraft:diorite"] = true,
  ["minecraft:andesite"] = true,
  ["minecraft:tuff"] = true,
  ["minecraft:calcite"] = true,
  ["minecraft:dripstone_block"] = true,
  ["minecraft:mud"] = true,
  ["minecraft:packed_mud"] = true,
  ["minecraft:terracotta"] = true,
  ["minecraft:white_terracotta"] = true,
  ["minecraft:orange_terracotta"] = true,
  ["minecraft:magenta_terracotta"] = true,
  ["minecraft:light_blue_terracotta"] = true,
  ["minecraft:yellow_terracotta"] = true,
  ["minecraft:lime_terracotta"] = true,
  ["minecraft:pink_terracotta"] = true,
  ["minecraft:gray_terracotta"] = true,
  ["minecraft:light_gray_terracotta"] = true,
  ["minecraft:cyan_terracotta"] = true,
  ["minecraft:purple_terracotta"] = true,
  ["minecraft:blue_terracotta"] = true,
  ["minecraft:brown_terracotta"] = true,
  ["minecraft:green_terracotta"] = true,
  ["minecraft:red_terracotta"] = true,
  ["minecraft:black_terracotta"] = true,
  ["minecraft:netherrack"] = true,
  ["minecraft:basalt"] = true,
  ["minecraft:smooth_basalt"] = true,
  ["minecraft:blackstone"] = true,
  ["minecraft:soul_sand"] = true,
  ["minecraft:soul_soil"] = true,
  ["minecraft:end_stone"] = true,
}

function inventory.dropTrash()
  local previousSlot = turtle.getSelectedSlot()

  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and trashItems[detail.name] then
      turtle.select(slot)
      turtle.drop()
    end
  end

  turtle.select(previousSlot)
end

function inventory.isFull()
  inventory.dropTrash()

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

function inventory.trashItems()
  local copy = {}
  for name, trash in pairs(trashItems) do
    copy[name] = trash
  end

  return copy
end

function inventory.addTrash(name)
  if type(name) ~= "string" then
    return false, "item name must be a string"
  end

  trashItems[name] = true
  return true
end

function inventory.removeTrash(name)
  if type(name) ~= "string" then
    return false, "item name must be a string"
  end

  trashItems[name] = nil
  return true
end

return inventory
