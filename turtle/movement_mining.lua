local mining = {}

local allowedBlocks = {
  ["minecraft:stone"] = true,
  ["minecraft:cobblestone"] = true,
  ["minecraft:deepslate"] = true,
  ["minecraft:cobbled_deepslate"] = true,
  ["minecraft:dirt"] = true,
  ["minecraft:coarse_dirt"] = true,
  ["minecraft:rooted_dirt"] = true,
  ["minecraft:grass_block"] = true,
  ["minecraft:gravel"] = true,
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

local function isOre(block)
  if type(block.name) == "string" then
    if block.name:find("_ore") or block.name:find(":ore_") then
      return true
    end
  end

  if type(block.tags) == "table" then
    for tag, enabled in pairs(block.tags) do
      if enabled and type(tag) == "string" and tag:find("ore") then
        return true
      end
    end
  end

  return false
end

function mining.isOre(block)
  return isOre(block)
end

function mining.canMine(block)
  return allowedBlocks[block.name] or isOre(block)
end

function mining.clear(inspectFn, digFn)
  local exists, block = inspectFn()
  if not exists then
    return true
  end

  if not mining.canMine(block) then
    return false, "refusing to mine " .. tostring(block.name)
  end

  local ok, reason = digFn()
  if not ok then
    return false, reason
  end

  return true
end

function mining.allowedBlocks()
  local copy = {}
  for name, allowed in pairs(allowedBlocks) do
    copy[name] = allowed
  end

  return copy
end

function mining.allowBlock(name)
  if type(name) ~= "string" then
    return false, "block name must be a string"
  end

  allowedBlocks[name] = true
  return true
end

function mining.disallowBlock(name)
  if type(name) ~= "string" then
    return false, "block name must be a string"
  end

  allowedBlocks[name] = nil
  return true
end

return mining
