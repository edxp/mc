local sides = require("sides")
local colors = require("colors")

-- Settings
--=======================================================================
local requiredRedstoneLevel = 13
local redstoneComparatorSide = sides.right
local redstoneAlertSide = sides.left
local useInternalComparator = false
--=======================================================================

--------------------------------------------
local component = require("component")
local computer = require("computer")
local robot = require("robot")
--local event = require("event")
local term = require("term")
local fs = require("filesystem")
local note = require("note")

local redstone
local animatedString = "|/-\\|/-\\"
local animatedStringIndex = 1
local logFilePath = "/var/log/emmonitor.log"
--------------------------------------------

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
local UI_CTRL_BOTTOMBAR = 207

local STR_GOOD =                        "GOOD   "
local STR_BAD =                         "BAD    "
local STR_READY =                       "GOOD   "
local STR_FAIL =                        "WARNING"
local STR_ALERT =                       "ALERT  "
local STR_CURRENT_REDSTONE_LEVEL =      "Current redstone level                "
local STR_CONDITIONS_NOT_MET =          "ONE OR MORE CONDITIONS ARE NOT MET    "
local STR_DISMOUNTING_CORE =            "DISMOUNTING CORE...                   "
local STR_DISMOUNT_SUCCESS =            "CORE HAS BEEN SUCCESSFULLY DISMOUNTED "
local STR_DISMOUNT_FAIL =               "FAILED TO DISMOUNT REACTOR CORE       "
local STR_CHECK_ASAP =                  "CHECK CURRENT CONFIGURATION ASAP      "
local STR_NOTHING =                     "                                      "

local logFilePath = "/var/log/emmonitor.log"

local function ClearLog()
    local logFile = io.open(logFilePath, "w")

    if (logFile ~= nil) then
        logFile:close()

        return true
    end

    return false
end

local function LogLine(str)
    local logFile = io.open(logFilePath, "a")

    if (logFile ~= nil) then
        logFile:write("["..os.date().."] "..str)
        logFile:close()

        return true
    end

    return false
end

local function CreateLogFile(isForced)
    if ((isForced and ClearLog()) or ((not isForced) and (fs.exists(logFilePath)) and (fs.size(logFilePath) > 131072) and (ClearLog()))) then
        return (LogLine("Log file opened\n\n"))
    end

    return false
end

local function GetInternalPower()
    return (computer.energy() / computer.maxEnergy())
end

local function CheckInternalPower()
    return (GetInternalPower() >= 0.5)
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

-- Use normal or comparator signals
local function GetCurrentRedstoneLevel()
    if (useInternalComparator) then
        return redstone.getComparatorInput(redstoneComparatorSide)
    else
        return redstone.getInput(redstoneComparatorSide)
    end
end

local function CheckElectromagnetsPower()
    local currentRedstoneLevel = GetCurrentRedstoneLevel()
    LogLine("Current redstone level: "..currentRedstoneLevel.."\n")

    return (currentRedstoneLevel >= requiredRedstoneLevel)
end

-- Use normal only signal
local function CheckAlertStatus()
    return ((redstone.getInput(redstoneAlertSide)) == REDSTONE_FALSE)
end

local function ReactorControl(state)
    if (state == REACTOR_ON) then
        redstone.setOutput(sides.front, REDSTONE_FALSE)

        return true
    elseif (state == REACTOR_OFF) then
        redstone.setOutput(sides.front, REDSTONE_TRUE)

        return true
    end

    return false
end

local function SetAlertStatus(state)
    if (state == STATUS_ALERT_HIGH) then
        redstone.setOutput(redstoneAlertSide, REDSTONE_TRUE)
        os.sleep(0.2)
        redstone.setOutput(redstoneAlertSide, REDSTONE_FALSE)

        return true
    elseif (state == STATUS_ALERT_LOW) then
        redstone.setOutput(redstoneAlertSide, REDSTONE_FALSE)

        return true
    end

    return false
end

local function CoreDismount()
    local swingResult = false
    local swingIsOk, swingCode = robot.swing(sides.front)

    if (swingIsOk and (swingCode == "block")) then
        swingResult = true
    end

    -- suck dick anyway, just in case
    robot.suck()

    return swingResult
end

local function ResetRedstoneOutput()
    for robotSide = 0, 5, 1 do
        redstone.setOutput(robotSide, REDSTONE_FALSE)
    end
end

local function UpdateScreenStatus(field, status)
    if (field == UI_CTRL_POWER) then
        term.setCursor(44, 8)
    elseif (field == UI_CTRL_TOOL) then
        term.setCursor(44, 9)
    elseif (field == UI_CTRL_SPACE) then
        term.setCursor(44, 10)
    elseif (field == UI_CTRL_ELECTROMAGNETS) then
        term.setCursor(44, 11)
    elseif (field == UI_CTRL_ALERT) then
        term.setCursor(44, 12)
    elseif (field == UI_CTRL_CURRENTSTATUS) then
        term.setCursor(44, 14)
    elseif (field == UI_CTRL_REDSTONELEVEL) then
        term.setCursor(44, 15)
    elseif (field == UI_CTRL_BOTTOMBAR) then
        term.setCursor(1, 16)
    elseif (field == UI_CTRL_TIME) then
        term.setCursor(39, 16)
    end

    term.write(status, false)
    term.setCursor(1, 16)

    return true
end

local function UpdateScreenTime()
    local onlyTime = os.date()
    onlyTime = onlyTime:sub(#onlyTime - 7, -1)
    
    UpdateScreenStatus(UI_CTRL_TIME, "["..animatedString:sub(animatedStringIndex, animatedStringIndex).."] "..onlyTime)
    animatedStringIndex = animatedStringIndex + 1

    if (animatedStringIndex > 8) then
        animatedStringIndex = 1
    end

    return true
end

local function main()
    io.write("==================================================\n")
    io.write("| Electormagnets Monitor v1.0.0 by Prodavec, 2017|\n")
    io.write("==================================================\n")
    io.write("\n")

    local isCompatible = true

    CreateLogFile(true)

    if (not component.isAvailable("robot")) then
        io.stderr:write("This program requires robot to run\n")
        isCompatible = false
    elseif (not component.isAvailable("redstone")) then
        io.stderr:write("Redstone interface has not been detected\n")
        isCompatible = false
    end

    if (not isCompatible) then
        io.write("==================================================\n")
        LogLine("System is NOT compatible\n")
        os.exit()
    end

    LogLine("System is compatible\n\n")

    -- Get redstone component
    redstone = component.redstone

    -- Set STATUS_ALERT_LOW, it's already stored in S-R Latch or Data Cell
    SetAlertStatus(STATUS_ALERT_LOW)

    --------- Draw static elements ---------
    io.write("----------------- SYSTEM STATUS -------------1.0.0\n")
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

    -- Init vars before entering loop
    local pendingCoreDismount = false

    -- While true do - optimizaciyu v pizdu
    while (true) do
        local isConditionsOk = true
        local notePlayed = false

        UpdateScreenTime()
        CreateLogFile(false)
        LogLine("New iteration\n")
        LogLine("Free memory:"..tostring(computer.freeMemory()).."\n")

        -- Internal power
        -------
        if (CheckInternalPower()) then
            UpdateScreenStatus(UI_CTRL_POWER, STR_GOOD)
            LogLine("Power is GOOD\n")
        else
            UpdateScreenStatus(UI_CTRL_POWER, STR_BAD)
            isConditionsOk = false

            if (GetInternalPower() < 0.1) then
                pendingCoreDismount = true
                SetAlertStatus(STATUS_ALERT_HIGH)
                LogLine("Power is BAD and below 10%\n")
            else
                LogLine("Power is BAD\n")
            end
        end
        -------

        -- Tool
        -------
        if (CheckToolValidity()) then
            UpdateScreenStatus(UI_CTRL_TOOL, STR_GOOD)
            LogLine("Tool is GOOD\n")
        else
            UpdateScreenStatus(UI_CTRL_TOOL, STR_BAD)
            isConditionsOk = false
            LogLine("Tool is BAD\n")
        end
        -------

        -- Inventory space
        -------
        if (CheckInventorySpace()) then
            UpdateScreenStatus(UI_CTRL_SPACE, STR_GOOD)
            LogLine("Inventory is GOOD\n")
        else
            UpdateScreenStatus(UI_CTRL_SPACE, STR_BAD)
            isConditionsOk = false
            LogLine("Inventory is BAD\n")
        end
        -------

        -- Get current redstone level
        UpdateScreenStatus(UI_CTRL_REDSTONELEVEL, tostring(GetCurrentRedstoneLevel()))

        -- Electromagnets power
        -------
        if (CheckElectromagnetsPower()) then
            UpdateScreenStatus(UI_CTRL_ELECTROMAGNETS, STR_GOOD)
            LogLine("Electromagnets are GOOD\n")
        else
            UpdateScreenStatus(UI_CTRL_ELECTROMAGNETS, STR_BAD)
            isConditionsOk = false
            pendingCoreDismount = true
            SetAlertStatus(STATUS_ALERT_HIGH)
            LogLine("Electromagnets are BAD\n")
        end
        -------

        -- Alert status
        -------
        if (CheckAlertStatus()) then
            UpdateScreenStatus(UI_CTRL_ALERT, STR_GOOD)
            LogLine("Alert is GOOD\n")
        else
            UpdateScreenStatus(UI_CTRL_ALERT, STR_BAD)
            isConditionsOk = false
            pendingCoreDismount = true
            LogLine("Alert is BAD\n")

            -- TODO: What should we do here, probably nothing?
        end
        -------

        if (isConditionsOk) then
            -- Moved out
            --ReactorControl(REACTOR_ON)

            UpdateScreenStatus(UI_CTRL_CURRENTSTATUS, STR_READY)
            UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_NOTHING)
            LogLine("Conditions are GOOD\n")
        else
            UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_CHECK_ASAP)
            LogLine("Conditions are BAD\n")

            if (pendingCoreDismount) then
                UpdateScreenStatus(UI_CTRL_CURRENTSTATUS, STR_ALERT)
                note.play("E5", 2) -- TODO: change tone for alert
                notePlayed = true
                LogLine("if (pendingCoreDismount) pass\n")
                ReactorControl(REACTOR_OFF)

                UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_DISMOUNTING_CORE)
                LogLine("Dismounting core...\n")

                if (CoreDismount()) then
                    UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_DISMOUNT_SUCCESS)
                    LogLine("Dismount success\n")
                else
                    UpdateScreenStatus(UI_CTRL_BOTTOMBAR, STR_DISMOUNT_FAIL)
                    LogLine("Dismount failed\n")
                end

                -- TODO: infinite beep loop?
                UpdateScreenTime()
                LogLine("Exit\n")
                io.write("\n")
                os.exit()
                return 1
            else
                UpdateScreenStatus(UI_CTRL_CURRENTSTATUS, STR_FAIL)
                note.play("E5", 2) -- TODO: change tone for warning
            end
        end

        -- If bad conditions are good or not critical, we are here
        -- Pay attention for this
        ReactorControl(REACTOR_ON)

        --computer.pullSignal()
        --event.pull(1)

        LogLine("Wait for sleep()\n\n")

        -- Remove excessive sleep
        if (notePlayed) then
            os.sleep(1)
        else
            os.sleep(3)
        end
    end

    return 0
end

main()