local chest = require("chest")
local commands = require("commands")
local config = require("config")
local notifier = require("notifier")

local computerId = os.getComputerID()

local inventory, inventoryName = chest.find()
if not inventory then
  error(inventoryName)
end

if not notifier.chatBox() then
  error("chat box not found")
end

local currentSnapshot = chest.snapshot(inventory)

local function refreshInventory()
  local found, name = chest.find()
  if found then
    inventory = found
    inventoryName = name
    return true
  end

  return false, name
end

local function notifyChanged()
  local title = "Chest " .. computerId
  local message = "New resources in chest " .. computerId
  notifier.toastAll(message, title)
end

local function monitorChest()
  while true do
    os.sleep(config.pollInterval)

    if not inventory then
      refreshInventory()
    end

    if inventory then
      local nextSnapshot = chest.snapshot(inventory)
      if not chest.equals(currentSnapshot, nextSnapshot) then
        currentSnapshot = nextSnapshot
        notifyChanged()
      end
    end
  end
end

local function listenForCommands()
  local context = {
    id = computerId,
    notifyPlayers = config.notifyPlayers,
    notifier = notifier,
    summary = function()
      if not inventory then
        local ok = refreshInventory()
        if not ok then
          return "Chest " .. computerId .. " is not connected."
        end
      end

      return "Chest " .. computerId .. " contents:\n" .. chest.summary(inventory)
    end,
  }

  while true do
    local _, username, message = os.pullEvent("chat")
    commands.handle(username, message, context)
  end
end

print("Chest monitor " .. computerId .. " watching " .. inventoryName)
parallel.waitForAny(monitorChest, listenForCommands)
