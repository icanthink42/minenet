local commands = {}

---@class CommandContext
---@field id integer
---@field notifyPlayers string[]
---@field notifier table
---@field summary fun(): string
---@field infoLine fun(): string

---@param username string
---@param notifyPlayers string[]
---@return boolean
local function isNotifiedPlayer(username, notifyPlayers)
  for _, player in ipairs(notifyPlayers) do
    if username == player then
      return true
    end
  end

  return false
end

---@param username string
---@param message string
---@param context CommandContext
---@return boolean
function commands.handle(username, message, context)
  if message:match("^!all%s*$") then
    if not isNotifiedPlayer(username, context.notifyPlayers) then
      context.notifier.messagePlayer(username, "You are not on the notify list.")
      return true
    end

    context.notifier.messagePlayer(username, context.infoLine())
    return true
  end

  local requestedId = message:match("^!info%s+(%d+)%s*$")
  if not requestedId then
    return false
  end

  if tonumber(requestedId) ~= context.id then
    return true
  end

  if not isNotifiedPlayer(username, context.notifyPlayers) then
    context.notifier.messagePlayer(username, "You are not on the notify list.")
    return true
  end

  context.notifier.messagePlayer(username, context.summary())
  return true
end

return commands
