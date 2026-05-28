while true do
  local ok = shell.run("main")
  if ok then
    break
  end

  print("main crashed; restarting in 5 seconds")
  os.sleep(5)
end
