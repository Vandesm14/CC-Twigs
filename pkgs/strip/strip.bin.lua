-- TODO: Make sure that the slot being placed is a proper block, not a torch or so on.

local lava = "minecraft:lava"
local torch = "minecraft:torch"

local function fillLava()
    local exists, info = turtle.inspect()

    if exists and info.name == lava then
        if not turtle.place() then
            for i = 1, 4 * 4, 1 do
                turtle.select(i)
                if turtle.place() then return end
            end

            error("Cannot place block to prevent danger")
        end
    end
end

local function fillLavaUp()
    local exists, info = turtle.inspectUp()

    if exists and info.name == lava then
        if not turtle.placeUp() then
            for i = 1, 4 * 4, 1 do
                turtle.select(i)
                if turtle.placeUp() then return end
            end

            error("Cannot place block to prevent danger")
        end
    end
end

local function fillLavaOrHoleDown()
    local exists, info = turtle.inspectDown()

    if not exists or exists and info.name == lava then
        if not turtle.placeDown() then
            for i = 1, 4 * 4, 1 do
                turtle.select(i)
                if turtle.placeDown() then return end
            end

            error("Cannot place block to prevent danger")
        end
    end
end

while true do
    for _ = 1, 10, 1 do
        turtle.dig()
        turtle.forward()

        fillLavaOrHoleDown()

        turtle.turnLeft()

        fillLava()

        turtle.turnRight()
        turtle.turnRight()

        fillLava()

        turtle.digUp()
        turtle.up()

        fillLavaUp()
        fillLava()

        turtle.turnLeft()
        turtle.turnLeft()

        fillLava()

        turtle.turnRight()

        turtle.dig()
        turtle.forward()

        fillLavaUp()

        turtle.turnLeft()

        fillLava()

        turtle.turnRight()
        turtle.turnRight()

        fillLava()

        turtle.digDown()
        turtle.down()

        fillLavaOrHoleDown()
        fillLava()

        turtle.turnLeft()
        turtle.turnLeft()

        fillLava()

        turtle.turnRight()
    end

    print("Placing torch...")

    for i = 1, 4 * 4, 1 do
        local info = turtle.getItemDetail(i)
        if info and info.name == torch then
            turtle.select(i)
            if turtle.placeUp() then break end
        end
    end
end