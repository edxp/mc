local component = require("component")
local shell = require("shell")
local sides = require("sides")
local colors = require("colors")
local term = require("term")

io.write("==================================================\n")
io.write("| Redstone Checker v1.1.0 by Prodavec, 2017      |\n")
io.write("==================================================\n\n")

if not component.isAvailable("redstone") then
    io.stderr:write("Redstone interface has not been detected\n")
    io.write("==================================================\n")
    return 1
end

local rs = component.redstone

local function PutRedstoneValueAsConsoleText(normalValue, comparatorValue)
    local carriageX, carriageY = term.getCursor()
    --term.setCursor(9, carriageY)
    --term.write("|")
    term.setCursor(14, carriageY)
    term.write(tostring(normalValue), false)
    term.setCursor(26, carriageY)
    term.write(tostring(comparatorValue), false)
end

io.write("SIDE       Normal    Comparator\n")
io.write("--------------------------------------------------\n")

io.write("Left:")
PutRedstoneValueAsConsoleText(rs.getInput(sides.left), rs.getComparatorInput(sides.left))

io.write("\nRight:")
PutRedstoneValueAsConsoleText(rs.getInput(sides.right), rs.getComparatorInput(sides.right))

io.write("\nFront:")
PutRedstoneValueAsConsoleText(rs.getInput(sides.front), rs.getComparatorInput(sides.front))

io.write("\nBack:")
PutRedstoneValueAsConsoleText(rs.getInput(sides.back), rs.getComparatorInput(sides.back))

io.write("\nTop:")
PutRedstoneValueAsConsoleText(rs.getInput(sides.top), rs.getComparatorInput(sides.top))

io.write("\nBottom:")
PutRedstoneValueAsConsoleText(rs.getInput(sides.bottom), rs.getComparatorInput(sides.bottom))

io.write("\n==================================================\n")