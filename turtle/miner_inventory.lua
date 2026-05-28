local inventory = {}
local config = require("miner_config")
local log = require("logger")

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
  ["create:limestone"] = true,
  ["create:scoria"] = true,
  ["create:scorchia"] = true,
  ["create:asurine"] = true,
  ["create:crimsite"] = true,
  ["create:ochrum"] = true,
  ["create:veridium"] = true,
}

function inventory.dropTrash()
  local previousSlot = turtle.getSelectedSlot()

  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and trashItems[detail.name] then
      log.info("Dropping trash " .. detail.count .. "x " .. detail.name)
      turtle.select(slot)
      turtle.drop()
    end
  end

  turtle.select(previousSlot)

  local itemCount, slotsFull = 0, 0
  for slot = 1, 16 do
    local n = turtle.getItemCount(slot)
    itemCount = itemCount + n
    if n > 0 then slotsFull = slotsFull + 1 end
  end
  log.gauge("turtle_item_count", itemCount)
  log.gauge("turtle_slots_used", slotsFull)
  log.flush_gauges()
end

function inventory.compact()
  local previousSlot = turtle.getSelectedSlot()

  for source = 1, 16 do
    local sourceDetail = turtle.getItemDetail(source)
    if sourceDetail then
      for target = 1, 16 do
        if source ~= target then
          local targetDetail = turtle.getItemDetail(target)
          if targetDetail and targetDetail.name == sourceDetail.name then
            turtle.select(source)
            turtle.transferTo(target)

            if turtle.getItemCount(source) == 0 then
              break
            end
          end
        end
      end
    end
  end

  turtle.select(previousSlot)
end

function inventory.cleanup()
  inventory.dropTrash()
  inventory.compact()
end

function inventory.isFull()
  inventory.cleanup()

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

function inventory.hasNonFuel()
  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and not config.charcoalItems[detail.name] then
      return true
    end
  end

  return false
end

local function isChestLike(block)
  if not block or type(block.name) ~= "string" then
    return false
  end

  if block.name == "minecraft:chest"
    or block.name == "minecraft:trapped_chest"
    or block.name == "minecraft:barrel" then
    return true
  end

  if block.name:find("chest") or block.name:find("barrel") then
    return true
  end

  if type(block.tags) == "table" then
    for tag, enabled in pairs(block.tags) do
      if enabled
        and type(tag) == "string"
        and (tag:find("chest") or tag:find("barrel")) then
        return true
      end
    end
  end

  return false
end

function inventory.depositNonFuel(inspectFn, dropFn)
  inspectFn = inspectFn or turtle.inspect
  dropFn = dropFn or turtle.drop

  inventory.cleanup()

  local exists, block = inspectFn()
  if not exists or not isChestLike(block) then
    return false, "no chest"
  end

  local depositedAny = false
  local previousSlot = turtle.getSelectedSlot()

  for slot = 1, 16 do
    local detail = turtle.getItemDetail(slot)
    if detail and not config.charcoalItems[detail.name] then
      turtle.select(slot)
      if dropFn() then
        log.info("Deposited " .. detail.count .. "x " .. detail.name)
        depositedAny = true
      end
    end
  end

  turtle.select(previousSlot)
  inventory.cleanup()

  if not depositedAny then
    return false, "no chest or chest full"
  end

  if inventory.hasNonFuel() then
    return false, "chest full"
  end

  return true
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
