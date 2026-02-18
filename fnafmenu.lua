local fnaf = require "fnaf"
local bigfont = require "bigfont"

local monitorName = assert(select(1, ...), "fnafmenu.lua [monitor]")

fnaf.setMonitor(monitorName)

fnaf.resourceLoader.addTextures({
    "title",
    "headshots"
})

local resources = fnaf.loadResources()

local engine = require "engine"
local g = engine.game(monitorName)

local menuTexture = resources.texture.title
local headshotsTexture = resources.texture.headshots

local data = {
    highestNightComplete = 1,
    currentNight = 1
}
local resumedNight = "Night 3"

local function saveData()
    local f = assert(fs.open(".fnaf", "w"))
    f.write(data.currentNight)
    f.write("\n")
    f.write(data.highestNightComplete)
    f.close()
end
local loadData
local function runGame(night)
    data.currentNight = night
    saveData()
    local won = fnaf.fnaf(night)
    if won then
        data.highestNightComplete = math.max(data.highestNightComplete or 0, night)
        saveData()
        if night < 5 then
            return runGame(night + 1)
        end
    end
    loadData()
end

local i = 1
local menuObject = engine.statedObject(menuTexture, function(self)
    return i
end)
function menuObject:onClick(x, y)
    i = i + 1
    if i == 5 then i = 1 end
end

g.root:addChild(menuObject, 1, 1)
local titleTextObject = engine.object(8 * 4 + 2, 14)
function titleTextObject:draw(delta)
    self.window.setTextColor(colors.white)
    bigfont.writeOn(self.window, 1, "Five", 2, 2)
    bigfont.writeOn(self.window, 1, "Nights", 2, 5)
    bigfont.writeOn(self.window, 1, "at", 2, 8)
    bigfont.writeOn(self.window, 1, "Freddy's", 2, 11)
    self.window.setTextColor(colors.purple)
    bigfont.writeOn(self.window, 1, "CC", 28, 11)
end

menuObject:addChild(titleTextObject, 3, 3)

local newGameButton = engine.object(10 * 4, 4)
function newGameButton:draw(delta)
    bigfont.writeOn(self.window, 1, "New Game", 1, 1)
end

function newGameButton:onClick()
    runGame(1)
end

menuObject:addChild(newGameButton, 5, 25)

local continueGameButton = engine.object(10 * 4, 5)
function continueGameButton:draw(delta)
    bigfont.writeOn(self.window, 1, "Continue", 1, 1)
    self.window.setCursorPos(2, 4)
    self.window.write(resumedNight)
end

function continueGameButton:onClick()
    runGame(data.currentNight or 1)
end

menuObject:addChild(continueGameButton, 5, 30)

local night6Button = engine.object(10 * 4, 4)
function night6Button:draw(delta)
    bigfont.writeOn(self.window, 1, "6th Night", 1, 1)
end

function night6Button:onClick()
    local won = fnaf.fnaf(6)
    if won then
        data.highestNightComplete = math.max(data.highestNightComplete or 5, 6)
        saveData()
        loadData()
    end
end

menuObject:addChild(night6Button, 5, 35)

local customNightButton = engine.object(10 * 4, 4)
function customNightButton:draw(delta)
    bigfont.writeOn(self.window, 1, "Custom Night", 1, 1)
end

local customNightMenu
function customNightButton:onClick()
    customNightMenu.visible = true
    customNightMenu.active = true
    menuObject.visible = false
    menuObject.active = false
end

menuObject:addChild(customNightButton, 5, 40)

local stars = engine.object(6 * 5, 8)
function stars:draw(delta)
    bigfont.writeOn(self.window, 2, ("\4"):rep((data.highestNightComplete or 0) - 4), 1, 1)
end

menuObject:addChild(stars, 6, 17)

local copyright = engine.object(60, 1)
function copyright:draw(delta)
    self.window.setCursorPos(1, 1)
    self.window.write("Original game by Scott Cawthon, Ported by ShreksHellraiser")
end

menuObject:addChild(copyright, 1, 50)

function loadData()
    if not fs.exists(".fnaf") then
        data = {}
    else
        local f = assert(fs.open(".fnaf", "r"))
        local currentNight = tonumber(f.readLine())
        local highestNight = tonumber(f.readLine())
        f.close()
        data = {
            highestNightComplete = highestNight,
            currentNight = currentNight
        }
    end
    resumedNight = "Night " .. (data.currentNight or 1)
    continueGameButton.visible = data.currentNight ~= nil
    continueGameButton.active = data.currentNight ~= nil
    night6Button.visible = (data.highestNightComplete or 0) >= 5
    night6Button.active = (data.highestNightComplete or 0) >= 5
    customNightButton.visible = (data.highestNightComplete or 0) >= 6
    customNightButton.active = (data.highestNightComplete or 0) >= 6
end

loadData()

customNightMenu = engine.staticObject(menuTexture)
local customNightHeader = engine.object(15 * 4, 4)
function customNightHeader:draw(delta)
    bigfont.writeOn(self.window, 1, "Customize Night", 1, 1)
end

g.root:addChild(customNightMenu, 1, 1)
customNightMenu:addChild(customNightHeader, 3, 3)

local customDifficulties = { 0, 0, 0, 0 }
for i = 1, 4 do
    local headshot = engine.staticObject(headshotsTexture, i)
    local x = 5 + ((i - 1) * 25)
    customNightMenu:addChild(headshot, x, 20)
    local input = engine.object(20, 4)
    function input:draw()
        bigfont.writeOn(self.window, 1, ("\27 %2u \26"):format(customDifficulties[i]), 1, 1)
    end

    function input:onClick(x, y)
        local dir = x > 10 and 1 or -1
        local n = customDifficulties[i]
        n = math.max(0, math.min(20, n + dir))
        customDifficulties[i] = n
    end

    customNightMenu:addChild(input, x + 1, 35)
end

local startCustomNight = engine.object(16, 4)
function startCustomNight:draw()
    bigfont.writeOn(self.window, 1, "Start", 1, 1)
end

function startCustomNight:onClick()
    local won = fnaf.fnaf(7, table.unpack(customDifficulties))
    if won and customDifficulties[1] == 20 and customDifficulties[2] == 20 and customDifficulties[3] == 20 and customDifficulties[4] == 20 then
        data.highestNightComplete = 7
        saveData()
        loadData()
    end
    customNightMenu.visible = false
    customNightMenu.active = false
    menuObject.visible = true
    menuObject.active = true
end

customNightMenu:addChild(startCustomNight, 100, 45)

local backCustomNight = engine.object(20, 4)
function backCustomNight:draw()
    bigfont.writeOn(self.window, 1, "Cancel", 1, 1)
end

function backCustomNight:onClick()
    customNightMenu.visible = false
    customNightMenu.active = false
    menuObject.visible = true
    menuObject.active = true
end

customNightMenu.visible = false
customNightMenu.active = false

customNightMenu:addChild(backCustomNight, 10, 45)

g.setPalette(menuTexture.palette)
g.start()
