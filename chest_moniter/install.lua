local repo = "https://raw.githubusercontent.com/icanthink42/minenet"

local files = {
  "startup.lua",
  "main.lua",
  "config.lua",
  "chest.lua",
  "commands.lua",
  "notifier.lua",
}

local function trim(value)
  return value:match("^%s*(.-)%s*$")
end

local function promptBranch()
  write("Branch [main]: ")
  local branch = trim(read() or "")
  if branch == "" then
    return "main"
  end

  return branch
end

local function urlFor(branch, path)
  return repo .. "/refs/heads/" .. branch .. "/chest_moniter/" .. path
end

local function download(url)
  local response, reason = http.get(url)
  if not response then
    return nil, reason or "request failed"
  end

  local body = response.readAll()
  response.close()
  return body
end

local function writeFile(path, content)
  local handle, reason = fs.open(path, "w")
  if not handle then
    return false, reason
  end

  handle.write(content)
  handle.close()
  return true
end

local function install(branch)
  for _, file in ipairs(files) do
    write("Installing " .. file .. "... ")

    local content, downloadReason = download(urlFor(branch, file))
    if not content then
      print("failed")
      return false, downloadReason
    end

    local ok, writeReason = writeFile(file, content)
    if not ok then
      print("failed")
      return false, writeReason
    end

    print("ok")
  end

  return true
end

if not http then
  error("HTTP API is disabled. Enable http in ComputerCraft config.")
end

local branch = promptBranch()
local ok, reason = install(branch)
if not ok then
  error("install failed: " .. tostring(reason))
end

print("Installed chest monitor files from branch " .. branch)
print("Run 'main' now, or reboot to start through startup.lua.")
