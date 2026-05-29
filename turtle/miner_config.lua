---@class MinerConfig
---@field scanRadius integer
---@field charcoalReserve integer
---@field minFuelLevel integer
---@field scanRetryDelay number
---@field scanMaxAttempts integer
---@field maxChunksFromHome integer
---@field oreFamilies? table<string, boolean>
---@field oreNames? table<string, boolean>
---@field charcoalItems table<string, boolean>
---@field mode string
---@field validation? boolean
---@field shaftSpacing fun(): integer
---@field oreFamily fun(name: string): string
---@field allowsOre fun(name: string): boolean

---@type MinerConfig
local config = {}

local modeFile = ".miner_mode"

config.scanRadius = 8
config.charcoalReserve = 16
config.minFuelLevel = 128
config.scanRetryDelay = 2
config.scanMaxAttempts = 8
config.maxChunksFromHome = 8
config.oreFamilies = nil
config.oreNames = nil

config.charcoalItems = {
  ["minecraft:charcoal"] = true,
}

---@return string
local function readMode()
  if not fs.exists(modeFile) then
    return "normal"
  end

  local handle = fs.open(modeFile, "r")
  if not handle then
    return "normal"
  end

  local mode = handle.readAll()
  handle.close()
  mode = mode:match("^%s*(.-)%s*$")

  if mode == "" then
    return "normal"
  end

  return mode
end

---@param source table
local function merge(source)
  for key, value in pairs(source) do
    config[key] = value
  end
end

---@param name string
---@return string
local function oreFamily(name)
  local namespace, path = name:match("^([^:]+):(.+)$")
  if not namespace then
    return name
  end

  path = path:gsub("^deepslate_", "")
  return namespace .. ":" .. path
end

config.mode = readMode()

local modeConfigPath = "modes/" .. config.mode .. "/config.lua"
if fs.exists(modeConfigPath) then
  local ok, modeConfig = pcall(dofile, modeConfigPath)
  if ok and type(modeConfig) == "table" then
    merge(modeConfig)
  else
    config.mode = "normal"
  end
end

---@return integer
function config.shaftSpacing()
  return config.scanRadius * 2
end

---@param name string
---@return string
function config.oreFamily(name)
  return oreFamily(name)
end

---@param name string
---@return boolean
function config.allowsOre(name)
  if config.oreNames and config.oreNames[name] then
    return true
  end

  if config.oreFamilies and config.oreFamilies[oreFamily(name)] then
    return true
  end

  return config.oreNames == nil and config.oreFamilies == nil
end

return config
