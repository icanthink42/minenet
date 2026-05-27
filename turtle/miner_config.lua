local config = {}

config.maxHeight = 50
config.minHeight = -60
config.scanRadius = 8
config.charcoalReserve = 16
config.minFuelLevel = 128
config.scanRetryDelay = 2
config.scanMaxAttempts = 8

config.charcoalItems = {
  ["minecraft:charcoal"] = true,
}

function config.shaftSpacing()
  return config.scanRadius * 2
end

return config
