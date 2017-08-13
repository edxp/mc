local component = require("component")
local robot = require("robot")
local keyboard = require("keyboard")
local sides = require("sides")
local colors = require("colors")
local terminal = require("term")

local totalObsidianProduced = -1

local function GetMinValue(value_a, value_b)
    if (value_a > value_b) then
        return value_b
    else
        return value_a
    end
end

-- true: wait for valid tool
-- false: do not wait
local function WaitForValidTool(isWait)
    while (true) do
        --print("[WaitForValidTool()] iteration...")

        local toolDurability = robot.durability()

        if ((toolDurability ~= nil) and (toolDurability > 0.01)) then
            --print("[WaitForValidTool()] true")
            return true
        elseif (not isWait) then
            --print("[WaitForValidTool()] false")
            return false
        end

        os.sleep(0.2)
    end
end

-- true: wait for solid block
-- false: do not wait
local function WaitForSolidBlock(isWait)
    while (true) do
        --print("[WaitForSolidBlock()] iteration...")

        local isBlock, blockType = robot.detectDown()

        if (isBlock and (blockType == "solid")) then
            return true
        elseif (not isWait) then
            return false
        end

        os.sleep(0.2)
    end
end

local function UpdateProducedBlocks()
    totalObsidianProduced = totalObsidianProduced + 1

    -- wtf? \r doesn't work
    --io.write("\rTotal Obsidian blocks produced: "..tostring(totalObsidianProduced))
    local carriageX, carriageY = terminal.getCursor()
    terminal.write(tostring(totalObsidianProduced), false)
    terminal.setCursor(carriageX, carriageY)
end

-- true: wait for tool and/or block
-- false: do not wait
local function DoMine(isWaitForValidTool, isWaitForSolidBlock, isAutoEject)
    if (WaitForValidTool(isWaitForValidTool) and WaitForSolidBlock(isWaitForSolidBlock)) then
        --print("[DoMine()] conditions ok")

        if (robot.swingDown(sides.front) and isAutoEject) then
            robot.dropUp(robot.count())
            UpdateProducedBlocks()
        end

        --print("[DoMine()] true")
        return true
    else
        --print("[DoMine()] false")
        return false
    end
end

-- true: wait for free space for lava
-- false: do not wait
local function WaitForLiquidBlock(isWait)
    while (true) do
        local isBlock, blockType = robot.detectDown()
        local isNotTank = (component.tank_controller.getFluidInTank(sides.bottom).n == 0)

        if ((not isBlock) and (blockType == "liquid") and isNotTank) then
            return true
        elseif (not isWait) then
            return false
        end

        -- Try to remove possible solid block to free space
        DoMine(true, false, true)

        os.sleep(0.2)
    end
end

-- true: drain until 1000 mB
-- false: drain available lava and return
local function WaitForLavaInTank(isWait)
    while (true) do
        local fluidNeeded = 4000 - robot.tankLevel()
        local fluidDescriptor = component.tank_controller.getFluidInTank(sides.front)

        if (fluidNeeded and (fluidDescriptor[1].name == "lava")) then
            robot.drain(GetMinValue(fluidNeeded, fluidDescriptor[1].amount))
        end

        if (robot.tankLevel() >= 1000) then
            return true
        elseif (not isWait) then
            return false
        end

        os.sleep(0.2)
    end
end

-- true: wait for water block before filling with lava
-- false: do not wait and return false
local function FillLava(isWait)
    if ((robot.tankLevel() >= 1000) and WaitForLiquidBlock(isWait)) then
        while (true) do
            local fillResult = robot.fillDown(1000)

            if (fillResult) then
                -- message: ok
                return true
            elseif (not isWait) then
                return false
            else
                DoMine(true, false, true)
                -- message: cant place lava
            end

            os.sleep(0.2)
        end
    else
        -- message: cant detect proper liquid block or no lava in tank
        return false
    end
end

local function WorkerThread()
    io.write("Total Obsidian blocks produced: ")
    UpdateProducedBlocks()

    DoMine(true, false, true)

    while (true) do
        --print("[WorkerThread()] calling WaitForLavaInTank()")
        WaitForLavaInTank(true)

        --print("[WorkerThread()] calling FillLava()")
        FillLava(true)

        --print("[WorkerThread()] calling DoMine()")
        DoMine(true, true, true)
    end
end

-------------------------------
-- main()
-------------------------------

io.write("==================================================\n")
io.write("| Obsidian Miner v1.0.1 by Prodavec, 2017        |\n")
io.write("==================================================\n\n")

local isCompatible = true

if (not component.isAvailable("robot")) then
    io.stderr:write("This program requires robot to run\n")
    isCompatible = false
elseif (not component.isAvailable("tank_controller")) then
    io.stderr:write("This program requires Tank Controller to be installed\n")
    isCompatible = false
--elseif (not component.isAvailable("inventory_controller")) then
--    io.stderr:write("This program requires Inventory Controller to be installed\n")
--    isCompatible = false
end

if (isCompatible) then
    -- Must be in separate thread
    WorkerThread()
else
    io.write("==================================================\n")

    return -1
end