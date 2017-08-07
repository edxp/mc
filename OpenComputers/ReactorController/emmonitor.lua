local component = require("component")
local robot = require("robot")
local computer = require("computer")
local term = require("term")
local sides = require("sides")
local note = require("note")

-- Settings
--=======================================================================
local requiredRedstoneLevel = 14
local redstoneComparatorSide = sides.back
local redstoneAlertSide = sides.right
local useInternalComparator = false
--=======================================================================

local redstone
local isRunning = false

-- #define... :)
local REDSTONE_FALSE = 0
local REDSTONE_TRUE = 15

local REACTOR_ON = 100
local REACTOR_OFF = 101
local STATUS_ALERT_LOW = 102
local STATUS_ALERT_HIGH = 103

local UI_CTRL_POWER = 200
local UI_CTRL_TOOL = 201
local UI_CTRL_SPACE = 202
local UI_CTRL_ELECTROMAGNETS = 203
local UI_CTRL_ALERT = 204
local UI_CTRL_CURRENTSTATUS = 205
local UI_CTRL_REDSTONELEVEL = 206

local STR_GOOD =                        "GOOD  "
local STR_BAD =                         "BAD   "
local STR_READY =                       "READY "
local STR_FAIL =                        "FAIL  "
local STR_CURRENT_REDSTONE_LEVEL =      "Current redstone level                            "
local STR_CONDITIONS_NOT_MET =          "ONE OR MORE CONDITIONS ARE NOT MET                "
local STR_UNMOUNTING_CORE =             "UNMOUNTING CORE...                                "
local STR_UNMOUNT_SUCCESS =             "REACTOR CORE HAS BEEN SUCCESSFULLY UNMOUNTED      "
local STR_UNMOUNT_FAIL =                "FAILED TO UNMOUNT REACTOR CORE                    "
local STR_CHECK_ASAP =                  "CHECK CURRENT CONFIGURATION ASAP                  "
local STR_NOTHING =                     "                                                  "

local function CheckInternalPower()
    return ((computer.energy() / computer.maxEnergy()) >= 0.5)
end

local function CheckToolValidity()
    local toolDurability = robot.durability()
    return ((toolDurability ~= nil) and (toolDurability > 0.01))
end

local function CheckInventorySpace()
    for currentSlot = 1, 16, 1 do
        if (robot.space(currentSlot) == 64) then
            return true
        end
    end

    return false
end

local function GetCurrentRedstoneLevel()
    if (useInternalComparator) then
        return redstone.getComparatorInput(redstoneComparatorSide)
    else
        return redstone.getInput(redstoneComparatorSide)
    end
end

local function CheckElectromagnetsPower()
    return (GetCurrentRedstoneLevel() >= requiredRedstoneLevel)
end

local function CheckAlertStatus()
    return ((redstone.getInput(redstoneAlertSide)) == REDSTONE_FALSE)
end

local function ReactorControl(state)
    if (state == REACTOR_ON) then
        redstone.setOutput(sides.front, REDSTONE_FALSE)
        isRunning = true

        return true
    elseif (state == REACTOR_OFF) then
        redstone.setOutput(sides.front, REDSTONE_TRUE)
        isRunning = false

        return true
    end

    return false
end

local function SetAlertStatus(state)
    if (state == STATUS_ALERT_HIGH) then
        redstone.setOutput(redstoneAlertSide, REDSTONE_TRUE)
        os.sleep(0.2)
        redstone.setOutput(redstoneAlertSide, REDSTONE_FALSE)
    else
        -- Reserved for future
        redstone.setOutput(redstoneAlertSide, REDSTONE_FALSE)
    end

    return true
end

local function CoreUnmount()
    local swingResult = false
    local swingIsOk, swingCode = robot.swing(sides.front)

    if (swingIsOk and (swingCode == "block")) then
        swingResult = true
    end

    -- suck anyway, just in case
    robot.suck()

    return swingResult
end

local function UpdateScreenStatus(field, status)
    if (field == UI_CTRL_POWER) then
        term.setCursor(45, 8)
    elseif (field == UI_CTRL_TOOL) then
        term.setCursor(45, 9)
    elseif (field == UI_CTRL_SPACE) then
        term.setCursor(45, 10)
    elseif (field == UI_CTRL_ELECTROMAGNETS) then
        term.setCursor(45, 11)
    elseif (field == UI_CTRL_ALERT) then
        term.setCursor(45, 12)
    elseif (field == UI_CTRL_CURRENTSTATUS) then
        term.setCursor(45, 14)
    elseif (field == UI_CTRL_REDSTONELEVEL) then
        term.setCursor(45, 15)
    elseif (field == UI_CTRL_BOTTOMBAR) then
        term.setCursor(1, 16)
    end

    term.write(status, false)
    term.setCursor(1, 16)

    return true
end

local function main()
    io.write("==================================================\n")
    io.write("| Electormagnets Monitor v1.0.0 by Prodavec, 2017|\n")
    io.write("==================================================\n")
    io.write("\n")

    local isCompatible = true

    if (not component.isAvailable("robot")) then
        io.stderr:write("This program requires robot to run\n")
        isCompatible = false
    elseif (not component.isAvailable("redstone")) then
        io.stderr:write("Redstone interface has not been detected\n")
        isCompatible = false
    end

    if (not isCompatible) then
        io.write("==================================================\n")
        os.exit()
    end

    -- Get redstone component
    redstone = component.redstone

    -- Set TRUE on front side immediately
    ReactorControl(REACTOR_OFF)

    -- Set STATUS_ALERT_LOW to Alert, it's already stored in S-R Latch or Data Cell
    SetAlertStatus(STATUS_ALERT_LOW)

    --------- Draw static elements ---------
    io.write("----------------- SYSTEM STATUS ------------------\n")
    io.write("Required redstone level                     "..tostring(requiredRedstoneLevel).."\n")
    io.write("Electromagnets comparator input             "..sides[redstoneComparatorSide].."\n")
    io.write("Alert signal output                         "..sides[redstoneAlertSide].."\n")
    io.write("Use internal comparator                     "..tostring(useInternalComparator).."\n")
    io.write("--------------------------------------------------\n")

    io.write("\n")

    io.write("Internal power\n")
    io.write("Tool\n")
    io.write("Free inventory space\n")
    io.write("Electromagnets power\n")
    io.write("Alert status\n")

    io.write("\n")

    io.write("Current status\n")
    io.write("Current redstone level\n")
    ----------------------------------------

    while (true) do
        local isConditionsOk = true
        local pendingCoreDismount = false

        -- Internal power
        -------
        if (CheckInternalPower()) then
            UpdateScreenStatus(UI_CTRL_POWER, STR_GOOD)
        else
            UpdateScreenStatus(UI_CTRL_POWER, STR_BAD)
            isConditionsOk = false
        end
        -------

        -- Tool
        -------
        if (CheckToolValidity()) then
            UpdateScreenStatus(UI_CTRL_TOOL, STR_GOOD)
        else
            UpdateScreenStatus(UI_CTRL_TOOL, STR_BAD)
            isConditionsOk = false
        end
        -------

        -- Inventory space
        -------
        if (CheckInventorySpace()) then
            UpdateScreenStatus(UI_CTRL_SPACE, STR_GOOD)
        else
            UpdateScreenStatus(UI_CTRL_SPACE, STR_BAD)
            isConditionsOk = false
        end
        -------

        -- Get current redstone level
        UpdateScreenStatus(UI_CTRL_REDSTONELEVEL, tostring(GetCurrentRedstoneLevel()))

        -- Electromagnets power
        -------
        if (CheckElectromagnetsPower()) then
            UpdateScreenStatus(UI_CTRL_ELECTROMAGNETS, STR_GOOD)
        else
            UpdateScreenStatus(UI_CTRL_ELECTROMAGNETS, STR_BAD)
            isConditionsOk = false
            pendingCoreDismount = true
            SetAlertStatus(STATUS_ALERT_HIGH)
        end
        -------

        -- Alert status
        -------
        if (CheckAlertStatus()) then
            UpdateScreenStatus(UI_CTRL_ALERT, STR_GOOD)
        else
            UpdateScreenStatus(UI_CTRL_ALERT, STR_BAD)
            isConditionsOk = false

            -- TODO: What should we do here, probably nothing?
        end
        -------

        if (isConditionsOk) then
            ReactorControl(REACTOR_ON)
            UpdateScreenStatus(UI_CTRL_CURRENTSTATUS, STR_READY)
            UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_NOTHING)
        else
            UpdateScreenStatus(UI_CTRL_CURRENTSTATUS, STR_FAIL)

            if (isRunning) then
                UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_CHECK_ASAP)
                note.play("E5", 2)

                if (pendingCoreDismount) then
                    ReactorControl(REACTOR_OFF)

                    UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_UNMOUNTING_CORE)

                    if (CoreUnmount()) then
                        UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_UNMOUNT_SUCCESS)
                    else
                        UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_UNMOUNT_FAIL)
                    end

                    -- TODO: infinite beep loop?

                    io.write("\n")
                    os.exit()
                end
            else
                UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_CONDITIONS_NOT_MET)
                io.write("\n")
                os.exit()
            end
        end

        os.sleep(3)
    end

    return 0
end

main()