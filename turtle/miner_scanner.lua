local config = require("miner_config")
local mining = require("movement_mining")

local scanner = {}

local function findScanner()
  if peripheral and peripheral.find then
    return peripheral.find("geoScanner") or peripheral.find("geo_scanner")
  end

  return nil
end

local function distanceSquared(block)
  return block.x * block.x + block.y * block.y + block.z * block.z
end

function scanner.scan(radius)
  local geo = findScanner()
  if not geo then
    return nil, "geo scanner not found"
  end

  for _ = 1, config.scanMaxAttempts do
    local blocks, reason = geo.scan(radius or config.scanRadius)
    if blocks then
      return blocks
    end

    os.sleep(config.scanRetryDelay)
    if reason and not reason:find("cooldown") and not reason:find("wait") then
      -- Some failures are permanent for this scan, but the retry keeps behavior
      -- stable across different Advanced Peripherals versions.
    end
  end

  return nil, "geo scanner scan failed after retries"
end

function scanner.nearestOre(blocks)
  local best = nil
  local bestDistance = nil

  for _, block in ipairs(blocks) do
    if mining.isOre(block) then
      local distance = distanceSquared(block)
      if not bestDistance or distance < bestDistance then
        best = block
        bestDistance = distance
      end
    end
  end

  return best
end

function scanner.nearestOreByName(blocks, name)
  local best = nil
  local bestDistance = nil

  for _, block in ipairs(blocks) do
    if block.name == name then
      local distance = distanceSquared(block)
      if not bestDistance or distance < bestDistance then
        best = block
        bestDistance = distance
      end
    end
  end

  return best
end

return scanner
