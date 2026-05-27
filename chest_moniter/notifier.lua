local config = require("config")

local notifier = {}

local function findChatBox()
  return peripheral.find("chatBox") or peripheral.find("chat_box")
end

function notifier.chatBox()
  return findChatBox()
end

function notifier.toastAll(message, title)
  local chatBox = findChatBox()
  if not chatBox then
    return false, "chat box not found"
  end

  for _, player in ipairs(config.notifyPlayers) do
    chatBox.sendToastToPlayer(message, title, player, config.chatPrefix)
    os.sleep(0.2)
  end

  return true
end

function notifier.messagePlayer(player, message)
  local chatBox = findChatBox()
  if not chatBox then
    return false, "chat box not found"
  end

  return chatBox.sendMessageToPlayer(message, player, config.chatPrefix)
end

return notifier
