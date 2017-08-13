local component = require("component")
local robot = require("robot")
local sides = require("sides")
local colors = require("colors")
local terminal = require("term")
local shell = require("shell")

-- Settings
-------------------------------------------
local stepsX = 1
local stepsY = 1
local step = 1
-------------------------------------------

local params = table.pack(...)
local STR_BADARGUMENTS = "Bad argument(s) given, type buildlayer without parameters to get help\n"

local function Move(stepsToMove)
    for i = 1, math.abs(stepsToMove), 1 do
        if (stepsToMove > 0) then
            while (not robot.forward()) do
                os.sleep(0.25)
            end
        else
            while (not robot.back()) do
                os.sleep(0.25)
            end
        end

        os.sleep(0.1)
    end

    return true
end

local function Place()
    if (robot.count() > 0) then
        return robot.placeDown()
    else
        for currentSlot = 1, 16, 1 do
            if (robot.count(currentSlot) > 0) then
                robot.select(currentSlot)

                return robot.placeDown()
            end
        end
    end

    return false
end

local function FillForward(stepsToFill)
    local absSteps = math.abs(stepsToFill)

    for currentStep = 1, absSteps, 1 do
        Place()

        if (currentStep < absSteps) then
            Move(step)
        end
    end

    return true
end

local function main()
    io.write("==================================================\n")
    io.write("| Layer Builder v1.0.0 by Prodavec, 2017         |\n")
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

    -- Extract arguments (iz mogily)
    -----------------------------
    if (params.n == 0) then
        io.write("Usage: buildlayer <X> <Y> <step>\n")
        io.write("  rows   - positive or negative natural number\n")
        io.write("  colums - positive or negative natural number\n")
        io.write("  step   - must be >=1 natural number\n")
        io.write("\n")
        io.write("    ^Y       \n")
        io.write("    |        \n")
        io.write("    |        \n")
        io.write("----O---->   \n")
        io.write("    |    X   \n")
        io.write("    |        \n")
        io.write("    |        \n")

        return 1
    elseif (params.n == 3) then
        stepsX = tonumber(params[1])
        stepsY = tonumber(params[2])
        step = tonumber(params[3])
    else
        io.stderr:write(STR_BADARGUMENTS)

        return -1
    end

    if ((stepsX == nil) or (stepsY == nil) or (step == nil) or ((stepsX < 1) and (stepsX > -1)) or ((stepsY < 1) and (stepsY > -1)) or (step < 1)) then
        io.stderr:write(STR_BADARGUMENTS)

        return -1
    end
    -----------------------------

    io.write("Building...")

    -- Determine quarter
    -----------------------------
    local quarter = 0

    if ((stepsX > 0) and (stepsY > 0)) then
        quarter = 1
    elseif ((stepsX < 0) and (stepsY > 0)) then
        quarter = 2
    elseif ((stepsX < 0) and (stepsY < 0)) then
        quarter = 3
    elseif ((stepsX > 0) and (stepsY < 0)) then
        quarter = 4
    end
    -----------------------------

    -- Turn around
    -----------------------------
    if ((quarter == 3) or (quarter == 4)) then
        robot.turnAround()
    end
    -----------------------------

    -- Fill grid
    -----------------------------
    robot.select(1)
    local absStepsX = math.abs(stepsX)

    for x = 1, absStepsX, 1 do
        FillForward(math.abs(stepsY))

        if (x < absStepsX) then
            if ((((x % 2) == 0) and ((quarter == 1) or (quarter == 3))) or (((x % 2) ~= 0) and ((quarter == 2) or (quarter == 4)))) then
                robot.turnLeft()
                os.sleep(0.1)
                Move(step)
                robot.turnLeft()
                os.sleep(0.1)
            elseif ((((x % 2) == 0) and ((quarter == 2) or (quarter == 4))) or (((x % 2) ~= 0) and ((quarter == 1) or (quarter == 3)))) then
                robot.turnRight()
                os.sleep(0.1)
                Move(step)
                robot.turnRight()
                os.sleep(0.1)
            end
        end
    end
    -----------------------------

    robot.select(1)
    io.write("done")
end

main()