while true do
  local barrel = peripheral.wrap("front")
  if barrel ~= nil then
    print("transfer dried.")
    local success = pcall(
      barrel.pullItems,
      "back",
      3
    )
    if success then
      turtle.select(1)
      -- if turtle.suck(9) then
      --   print("pull dried.")
      --   turtle.transferTo(2, 1)
      --   turtle.transferTo(3, 1)

      --   turtle.transferTo(5, 1)
      --   turtle.transferTo(6, 1)
      --   turtle.transferTo(7, 1)

      --   turtle.transferTo(9, 1)
      --   turtle.transferTo(10, 1)
      --   turtle.transferTo(11, 1)

      --   print("craft block.")
      --   if turtle.craft(1) then
      --     print("transfer block.")
      --     turtle.turnLeft()
      --     turtle.turnLeft()

      --     turtle.drop()

      --     print("done.")
      --     turtle.turnLeft()
      --     turtle.turnLeft()
      --   end
      -- end
    end
  end

  print("idle.")
  sleep(10)
end
