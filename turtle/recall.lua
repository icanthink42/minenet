local recall = {}
local _requested = false

function recall.request()
  _requested = true
end

function recall.requested()
  return _requested
end

return recall
