local component = require("component")
local robot = require("robot")
local sides = require("sides")

io.write("==================================================\n")
io.write("| Cotton Farmer v1.0.0 by Prodavec, 2017         |\n")
io.write("==================================================\n\n")

local isCompatible = true

if (not component.isAvailable("robot")) then
    io.stderr:write("This program requires robot to run\n")
    isCompatible = false
elseif (not component.isAvailable("inventory_controller")) then
    io.stderr:write("This program requires Inventory Controller to be installed\n")
    isCompatible = false
end

if (not isCompatible) then
    io.write("==================================================\n")

    return -1
end

while (true) do
    -- Count available bone meal
    if (robot.count(16) == 0) then
        robot.suckUp()
    end

    -- Equip
    component.inventory_controller.equip()

    -- Prepare slot 1 and use tool
    robot.select(1)
    robot.useDown()

    -- Wait for growth a bit
    os.sleep(0.3)

    -- Suck cotton
    robot.suckDown()

    -- Drop cotton into the box
    robot.drop(robot.count())

    -- Reserved for Seeds
    --robot.select(2)
    --robot.drop(robot.count())

    -- Select slot 16
    robot.select(16)

    -- Unequip
    component.inventory_controller.equip()

    -- Wait a bit
    os.sleep(0.3)
end