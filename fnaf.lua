-- images are at 21.69%
-- 6x4 monitor at 242 x 156 pixels (121 x 52 chars)
-- the screen is 52 characters too narrow to fit the office
local engine  = require "engine"
local audio   = require "audio"
local bigfont = require "bigfont"


---@alias LOCATION integer
local LOCATIONS = {
  ["1A"]         = 1, -- STAGE
  STAGE          = 1,
  ["1B"]         = 2, -- DINING
  DINING_NEAR    = 2,
  DINING_FAR     = 3,
  ["1C"]         = 4,  -- PIRATE_COVE
  PIRATE_COVE    = 4,
  ["2A"]         = 5,  -- L_HALL_UPPER
  L_HALL_UPPER   = 5,
  ["2B"]         = 6,  -- L_HALL_LOWER
  L_HALL_LOWER   = 6,
  ["3"]          = 7,  -- JANITOR_CLOSET
  JANITOR_CLOSET = 7,
  ["4A"]         = 8,  -- R_HALL_UPPER
  R_HALL_UPPER   = 8,
  ["4B"]         = 9,  -- R_HALL_LOWER
  R_HALL_LOWER   = 9,
  ["5"]          = 10, -- SERVICE_CLOSET
  SERVICE_CLOSET = 10,
  ["6"]          = 11, -- KITCHEN
  KITCHEN        = 11,
  ["7"]          = 12, -- BATHROOMS
  BATHROOMS      = 12,
  LEFT_DOOR      = 13,
  RIGHT_DOOR     = 14,
  IN_OFFICE      = 15, -- RIP
}

setmetatable(LOCATIONS, { __index = function(_, k) error(("Invalid location %s"):format(k)) end })



---@type table<string,BIMG> Texture table
local texture = {}
---@type table<string,table>
local sound   = {}
--- Resource loading
do
  ---@type string[]
  local textureFiles               = {
    "office",
    "fan",
    "left_door",
    "left_button",
    "right_door",
    "right_button",
    "left_bar",
    "right_bar",
    "bar",
    "camera",
    "map",
    "cam_1a",
    "cam_1b",
    "cam_1c",
    "cam_2a",
    "cam_2b",
    "cam_3",
    "cam_4a",
    "cam_4b",
    "cam_5",
    "cam_7",
  }
  local soundFiles                 = {
    "door",
    "camera",
    "fan",
    "light_buzz"
  }
  local soundFileFramerateOverride = {
    light_buzz = 1000
  }
  local monitor                    = assert(peripheral.wrap("top"), "FNAF Requires a monitor on top.")
  monitor.setPaletteColor(colors.white, 0xFFFFFF)
  monitor.setPaletteColor(colors.black, 0) -- Assure the palette is something visible
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()
  monitor.setTextScale(0.5)
  local w, h = monitor.getSize()
  if w < 121 or h < 52 then
    local eMsg = "FNAF requires at least a 6x4 monitor attached on top."
    monitor.write(eMsg)
    error(eMsg, 0)
  end
  local function centerWrite(text, y, size)
    size = size or 1
    if size == 0 then
      monitor.setCursorPos((w - #text) / 2, y)
      monitor.write(text)
    else
      bigfont.writeOn(monitor, size, text, (w - (#text * size * 3)) / 2, y)
    end
  end
  local loadStartTime = os.epoch("utc")
  centerWrite("FNAF", h / 2 - 10, 2)
  centerWrite("Loading Textures...", h / 2)
  local y = h / 2 + 4
  local function progressBar(v, y)
    monitor.setCursorPos(1, y)
    local fChars = math.ceil(w * v)
    local t = ("\127"):rep(fChars)
    monitor.write(t .. ("_"):rep(w - fChars))
  end
  local function printProgress(v, vt, fn)
    progressBar(vt, y)
    progressBar(v, y + 1)
    centerWrite(fn, y + 2, 0)
  end
  local totalTextures = #textureFiles
  local totalSounds = #soundFiles
  local totalResources = totalTextures + totalSounds
  for i, name in ipairs(textureFiles) do
    printProgress(i / totalTextures, i / totalResources, name)
    texture[name] = engine.loadTexture(name .. ".bimg", true)
  end
  local textureTime = os.epoch("utc")
  monitor.clear()
  centerWrite("FNAF", h / 2 - 10, 2)
  centerWrite("Loading Audio...", h / 2)
  for i, name in ipairs(soundFiles) do
    printProgress(i / totalSounds, (i + totalTextures) / totalResources, name)
    sound[name] = audio.loadAudio(name .. ".dfpwm", true, soundFileFramerateOverride[name])
  end
  local audioTime = os.epoch("utc")
  print(("*** Done ***\nTextures: %dms\nAudio: %dms\nTotal: %dms")
    :format(textureTime - loadStartTime, audioTime - textureTime, audioTime - loadStartTime))
end


---@param night integer
---@param bonnieDifficulty integer?
---@param chicaDifficulty integer?
---@param freddyDifficulty integer?
---@param foxyDifficulty integer?
local function fnaf(night, bonnieDifficulty, chicaDifficulty, freddyDifficulty, foxyDifficulty)
  local g               = engine.game("top")
  local scrollWidth     = g.root.w - #texture.office[1][1][1] + 1 -- width of office

  local black           = colors.purple
  local white           = colors.lightBlue

  local power_remaining = 100
  local power_usage     = 1

  local gameObject      = engine.object(g.root.w, g.root.h)
  local soundEngine     = audio.new()
  g.root:addChild(gameObject, 1, 1)

  ---Create an animatronic object
  ---@param name any
  ---@param location any
  ---@return AnimatronicObject
  local function create_animatronic(name, location)
    ---@class AnimatronicObject : Object
    ---@field location LOCATION
    local obj = engine.object(1, 1)
    gameObject:addChild(obj, 1, 1)
    obj.visible = false
    obj.label = name
    obj.location = location
    return obj
  end

  -- Animatronic levels vary from 0 - 20
  -- Default values:
  -- Freddy Bonnie Chica Foxy
  -- 0      0      0     0
  -- 0      3      1     1
  -- 1      0      5     2
  -- 1 or 2 2      4     6
  -- 3      5      7     5
  -- 4      10     12    16
  local difficulties        = {
    { 0, 0,  0,  0 },
    { 0, 3,  1,  1 },
    { 1, 0,  5,  2 },
    { 2, 2,  4,  6 }, -- just hardcoding 2
    { 3, 5,  7,  5 },
    { 4, 10, 12, 16 }
  }
  local appliedDifficulties = difficulties[night] or difficulties[6]
  freddyDifficulty          = freddyDifficulty or appliedDifficulties[1]
  bonnieDifficulty          = bonnieDifficulty or appliedDifficulties[2]
  chicaDifficulty           = chicaDifficulty or appliedDifficulties[3]
  foxyDifficulty            = foxyDifficulty or appliedDifficulties[4]


  -- Power drainage
  -- Night 2 -1% Every 6 seconds
  -- Night 3 -1% Every 5 seconds
  -- Night 4 -1% Every 4 seconds
  -- Night 5+ -1% Every 3 seconds

  -- AI
  -- Random number 1-20
  -- If AI Level >= random number then AI moves

  -- Freddy 3.02 seconds
  -- Bonnie 4.97 seconds
  -- Chica 4.98 seconds
  -- Foxy 5.01 seconds

  -- Foxy TODO
  -- Each successful move advances by 1 stage
  -- When cameras are on lock movement
  -- Remain locked from 0.83 to 16.67 seconds
  -- Attack when check left hall or after 25 seconds
  -- If blocked takes power

  -- Bonnie/chica try to get in on next movement opportunity
  -- Door is disabled when they move in
  -- Wait for lower camera to attack or 30 seconds
  -- If blocked return to dining room

  -- Freddy fails movement while cameras are up TODO
  -- Upon succeeding it starts a countdown from 1000 - 100x frames (where x is ai level) @ 60fps
  -- Once at 4B he cannot be frozen by looking at cameras
  -- looking at 4B will keep him in place
  -- Cannot move into office while camera is down
  -- If blocked he returns to 4A
  -- 25% chance to jumpscare when in office each second while camera is down
  -- Does not pull down camera

  -- power out
  -- Every 5 seconds 20% chance for freddy to show up
  -- up to a max of 20 seconds
  -- music box has 20% every 5 seconds up to 20 seconds
  -- 20% chance to be jumpscared every 2 seconds

  local endscreenText         = "Uh Oh."
  local gameEndscreenObject   = engine.object(g.root.w, g.root.h)
  local gameReturnValue       = false
  local endscreenBG           = black
  local endscreenFG           = white
  local clickDebounceTime     = 0 -- Timer to prevent accidental dismissal of end screen
  gameEndscreenObject.draw    = function(self, delta)
    self.window.setBackgroundColor(endscreenBG)
    self.window.setTextColor(endscreenFG)
    self.window.clear()
    local mh = math.floor(self.h / 2)
    bigfont.writeOn(self.window, 1, endscreenText, math.floor((self.w - (#endscreenText * 3)) / 2), mh)
    self.window.setCursorPos((self.w - 19) / 2, mh + 3)
    self.window.write("[Touch to continue]")
  end
  gameEndscreenObject.visible = false
  gameEndscreenObject.active  = false
  gameEndscreenObject.onClick = function(self, x, y)
    if os.epoch("utc") > clickDebounceTime then
      g.exit(gameReturnValue)
    end
  end
  g.root:addChild(gameEndscreenObject, 1, 1)

  ---Show the End screen
  ---@param reason string
  ---@param retValue any
  ---@param bg ccTweaked.colors.color?
  ---@param fg ccTweaked.colors.color?
  local function showEndScreen(reason, retValue, bg, fg)
    gameObject.visible = false
    gameObject.active = false
    endscreenText = reason
    endscreenBG = bg or endscreenBG
    endscreenFG = fg or endscreenFG
    gameEndscreenObject.visible = true
    gameEndscreenObject.active = true
    gameReturnValue = retValue
    clickDebounceTime = os.epoch("utc") + 1000
  end


  local function jumpscare()
    showEndScreen("L+RATIO", false)
  end

  local function gameWin()
    showEndScreen("You Won!", true)
  end

  ---Return a random value from the provided list, with extra weight on the first option
  ---@param ... any
  ---@return any
  local function weighted_choice(...)
    local t = { ... }
    local rnd = math.random(1, #t + 1)
    rnd = rnd - 1
    if rnd == 0 then
      rnd = 1 -- double % chance of landing on first option
    end
    return t[rnd]
  end

  local leftDoor, rightDoor

  local bonnieObject = create_animatronic("Bonnie", LOCATIONS.STAGE)
  bonnieObject:addTimer(
  ---@param self AnimatronicObject
    function(self)
      if math.random(1, 20) <= bonnieDifficulty then
        -- movement succeeds
        if self.location == LOCATIONS.STAGE then
          self.location = weighted_choice(LOCATIONS.DINING_FAR, LOCATIONS.DINING_NEAR, LOCATIONS.SERVICE_CLOSET)
        elseif self.location == LOCATIONS.SERVICE_CLOSET then
          self.location = weighted_choice(LOCATIONS.L_HALL_UPPER, LOCATIONS.DINING_FAR, LOCATIONS.DINING_NEAR)
        elseif self.location == LOCATIONS.DINING_FAR then
          self.location = weighted_choice(LOCATIONS.L_HALL_UPPER, LOCATIONS.DINING_NEAR, LOCATIONS.SERVICE_CLOSET,
            LOCATIONS.JANITOR_CLOSET)
        elseif self.location == LOCATIONS.DINING_NEAR then
          self.location = weighted_choice(LOCATIONS.L_HALL_UPPER, LOCATIONS.SERVICE_CLOSET, LOCATIONS.JANITOR_CLOSET)
        elseif self.location == LOCATIONS.L_HALL_UPPER then
          self.location = weighted_choice(LOCATIONS.L_HALL_LOWER, LOCATIONS.JANITOR_CLOSET)
        elseif self.location == LOCATIONS.JANITOR_CLOSET then
          self.location = weighted_choice(LOCATIONS.L_HALL_LOWER, LOCATIONS.LEFT_DOOR, LOCATIONS.L_HALL_UPPER)
        elseif self.location == LOCATIONS.L_HALL_LOWER then
          self.location = weighted_choice(LOCATIONS.LEFT_DOOR, LOCATIONS.JANITOR_CLOSET)
        elseif self.location == LOCATIONS.LEFT_DOOR then
          if leftDoor.isOpen then
            self.location = LOCATIONS.IN_OFFICE
            jumpscare()
          else
            self.location = LOCATIONS.DINING_FAR
          end
        end
      end
    end, 4970, true)
  local chicaObject = create_animatronic("Chica", LOCATIONS.STAGE)
  chicaObject:addTimer(
  ---@param self AnimatronicObject
    function(self)
      if math.random(1, 20) <= chicaDifficulty then
        if self.location == LOCATIONS.STAGE then
          self.location = weighted_choice(LOCATIONS.DINING_FAR, LOCATIONS.DINING_NEAR)
        elseif self.location == LOCATIONS.DINING_NEAR then
          self.location = weighted_choice(LOCATIONS.R_HALL_UPPER, LOCATIONS.DINING_FAR, LOCATIONS.BATHROOMS)
        elseif self.location == LOCATIONS.DINING_FAR then
          self.location = weighted_choice(LOCATIONS.R_HALL_UPPER, LOCATIONS.DINING_NEAR, LOCATIONS.BATHROOMS)
        elseif self.location == LOCATIONS.BATHROOMS then
          self.location = weighted_choice(LOCATIONS.R_HALL_UPPER, LOCATIONS.KITCHEN)
        elseif self.location == LOCATIONS.KITCHEN then
          self.location = weighted_choice(LOCATIONS.R_HALL_UPPER, LOCATIONS.BATHROOMS)
        elseif self.location == LOCATIONS.R_HALL_UPPER then
          self.location = weighted_choice(LOCATIONS.R_HALL_LOWER, LOCATIONS.DINING_FAR, LOCATIONS.DINING_NEAR)
        elseif self.location == LOCATIONS.R_HALL_LOWER then
          self.location = weighted_choice(LOCATIONS.RIGHT_DOOR, LOCATIONS.R_HALL_UPPER)
        elseif self.location == LOCATIONS.RIGHT_DOOR then
          if rightDoor.isOpen then
            self.location = LOCATIONS.IN_OFFICE
            jumpscare()
          else
            self.location = LOCATIONS.DINING_FAR
          end
        end
      end
    end, 4980, true)
  local freddyObject = create_animatronic("Freddy", LOCATIONS.STAGE)
  ---@class Foxy : AnimatronicObject
  ---@field stage integer
  local foxyObject = create_animatronic("Foxy", LOCATIONS.PIRATE_COVE)
  foxyObject.stage = 1


  ---@type "OFFICE"|"CAMERA"|"CAMERA_ANIM"
  local state
  local setState

  local time = 0

  local power_out = false
  soundEngine.playAudio(sound.fan, 1, nil, function() return not power_out end)

  local officeView = engine.object(gameObject.w, gameObject.h)
  officeView.label = "officeView"

  ---@type "left"|"right"|nil
  local lightOn
  gameObject:addChild(officeView, 1, 1)
  local office = engine.statedObject(texture.office, function(self)
    if power_out then
      return 6 -- 7 when freddy shows up
    elseif lightOn == "left" then
      if bonnieObject.location == LOCATIONS.LEFT_DOOR then
        return 3
      end
      return 2
    elseif lightOn == "right" then
      if chicaObject.location == LOCATIONS.RIGHT_DOOR then
        return 5
      end
      return 4
    end
    return 1
  end)
  officeView:addChild(office, 1, 1)
  office.label = "office"
  local fan = engine.animatedObject(texture.fan, "FORWARD_LOOP", nil, 10)
  office:addChild(fan, 85, 23)

  local cameraButton = engine.staticObject(texture.bar, 1)
  cameraButton.z = 2
  officeView:addChild(cameraButton, 25, 47)

  local batteryIndicator = engine.object(15, 4)
  batteryIndicator.draw = function(self, delta)
    self.window.setBackgroundColor(black)
    self.window.setTextColor(white)
    self.window.clear()
    self.window.setCursorPos(1, 1)
    self.window.write(("-"):rep(power_usage))
    bigfont.writeOn(self.window, 1, string.format("%3u%%", power_remaining), 1, 2)
  end
  batteryIndicator.z = 2
  gameObject:addChild(batteryIndicator, 4, 46)

  local nightIndicator = engine.object(15, 4)
  nightIndicator.draw = function(self, delta)
    self.window.setBackgroundColor(black)
    self.window.setTextColor(white)
    self.window.clear()
    self.window.setCursorPos(1, 1)
    local displayTime = time
    if displayTime < 1 then
      displayTime = 12
    end
    bigfont.writeOn(self.window, 1, string.format("%2u AM", displayTime), 1, 1)
    self.window.setCursorPos(1, 4)
    self.window.write(("Night %u"):format(night))
  end
  nightIndicator.z = 2
  gameObject:addChild(nightIndicator, 98, 3)

  -- AI level increases at times
  -- 2AM +1 bonnie
  -- 3AM +1 bonnie, chica, foxy
  -- 4AM +1 bonnie, chica, foxy

  -- Time control
  gameObject:addTimer(function(self)
    time = 1
    gameObject:addTimer(function(self)
      time = time + 1
      if time == 6 then
        gameWin()
      end
      if time == 2 then
        bonnieDifficulty = bonnieDifficulty + 1
      elseif time == 3 or time == 4 then
        bonnieDifficulty = bonnieDifficulty + 1
        chicaDifficulty = chicaDifficulty + 1
        foxyDifficulty = foxyDifficulty + 1
      end
    end, 89000, 5)
  end, 90000, false) -- first hour is a little longer I think?

  ---@class Door : AnimatedObject
  ---@field isOpen boolean
  leftDoor = engine.animatedObject(texture.left_door, "FORWARD", function(self)
    if self.direction == -1 then
      self.visible = false
    end
    soundEngine.cancelAudio(self.channel)
  end, 60)
  ---@type Door
  rightDoor = engine.animatedObject(texture.right_door, "FORWARD", function(self)
    if self.direction == -1 then
      self.visible = false
    end
    soundEngine.cancelAudio(self.channel)
  end, 60) --[[@as Door]]

  local function close_door(door)
    engine.setAnimationMode(door, "FORWARD")
    door.visible = true
    door.animate = true
    door.isOpen = false
  end

  local function open_door(door)
    engine.setAnimationMode(door, "BACKWARD")
    door.animate = true
    door.isOpen = true
  end
  local leftButton, rightButton
  do -- door + buttons setup code
    leftDoor.isOpen = false
    leftDoor.label = "leftDoor"
    office:addChild(leftDoor, 12, 1)

    leftButton = engine.statedObject(texture.left_button, function(self)
      if leftDoor.isOpen and lightOn ~= "left" then
        return 4
      elseif lightOn ~= "left" then
        return 3
      elseif leftDoor.isOpen then
        return 2
      end
      return 1
    end)
    leftButton:addRenderCallback("post", function(self)
      self.window.setTextColor(white)
      self.window.setBackgroundColor(black)
      self.window.setCursorPos(3, 7)
      self.window.write("DOOR")
      self.window.setCursorPos(3, 13)
      self.window.write("LIGHT")
      return true
    end)

    local buzzSpeaker

    local function onClickGen(door, lightMode)
      return function(self, x, y)
        if y < 7 then
          -- door
          if not door.animate then
            if door.isOpen then
              close_door(door)
              power_usage = power_usage + 1
            else
              open_door(door)
              power_usage = power_usage - 1
            end
            self.channel = soundEngine.playAudio(sound.door)
          end
        else
          if buzzSpeaker then
            soundEngine.cancelAudio(buzzSpeaker)
          end
          if lightOn == lightMode then
            power_usage = power_usage - 1
            lightOn = nil
          else
            if not lightOn then
              power_usage = power_usage + 1
            end
            lightOn = lightMode
            buzzSpeaker = soundEngine.playAudio(sound.light_buzz, 1, 2, function() return not power_out end)
          end
        end
      end
    end

    leftButton.label = "leftButton"
    leftButton.onClick = onClickGen(leftDoor, "left")
    office:addChild(leftButton, 5, 18)
    open_door(leftDoor)

    rightDoor.isOpen = false
    rightDoor.label = "leftDoor"
    office:addChild(rightDoor, 139, 1)

    rightButton = engine.statedObject(texture.right_button, function(self)
      if rightDoor.isOpen and lightOn ~= "right" then
        return 4
      elseif lightOn ~= "right" then
        return 3
      elseif rightDoor.isOpen then
        return 2
      end
      return 1
    end)
    rightButton:addRenderCallback("post", function(self)
      self.window.setTextColor(white)
      self.window.setBackgroundColor(black)
      self.window.setCursorPos(2, 7)
      self.window.write("DOOR")
      self.window.setCursorPos(2, 13)
      self.window.write("LIGHT")
      return true
    end)

    rightButton.label = "rightButton"
    rightButton.onClick = onClickGen(rightDoor, "right")
    office:addChild(rightButton, 166, 18)
    open_door(rightDoor)
  end

  do -- look buttons
    local lookLeft
    local lookRight = engine.staticObject(texture.right_bar)
    lookRight.z = 2
    lookRight.label = "lookRight"
    lookRight.onClick = function(self, x, y)
      self.visible = false
      self.active = false
      lookLeft.visible = true
      lookLeft.active = true
      office:linearMove(scrollWidth, 1, 500)
    end
    officeView:addChild(lookRight, officeView.w - lookRight.w - 1, 2)

    lookLeft = engine.staticObject(texture.left_bar)
    lookLeft.label = "lookLeft"
    lookLeft.z = 2
    lookLeft.onClick = function(self, x, y)
      self.visible = false
      self.active = false
      lookRight.visible = true
      lookRight.active = true
      office:linearMove(1, 1, 500)
    end
    lookLeft.visible = false
    lookLeft.active = false
    officeView:addChild(lookLeft, 2, 2)
  end

  local CAMERAS = {}
  local active_camera
  local easter_egg_active = false
  --- Change active camera
  local function set_camera(location)
    for _, camera in pairs(CAMERAS) do
      camera.visible = false
    end
    active_camera = location
    CAMERAS[location].visible = true
    easter_egg_active = math.random(1, 15) == 1
  end

  do -- camera setup
    local moveTime = 4000
    local waitTime = 5000
    local cameraContainer = engine.object(gameObject.w, gameObject.h)
    local cameraViewbox = engine.object(#texture.office[1][1][1], #texture.office[1])
    gameObject:addChild(cameraContainer, 1, 1)
    cameraContainer:addChild(cameraViewbox, 1, 1)

    ---@param location LOCATION
    ---@param texture BIMG
    ---@param statefunc fun(self: Object): integer
    local function add_camera(location, texture, statefunc)
      local cam = engine.statedObject(texture, statefunc)
      cameraViewbox:addChild(cam, 1, 1)
      CAMERAS[location] = cam
    end

    add_camera(LOCATIONS["1A"], texture.cam_1a, function(self)
      local bonnieHere = bonnieObject.location == LOCATIONS["1A"]
      local chicaHere = chicaObject.location == LOCATIONS["1A"]
      local freddyHere = freddyObject.location == LOCATIONS["1A"]
      if bonnieHere and chicaHere then
        if easter_egg_active then
          return 7 -- staring at camera
        end
        return 6
      elseif bonnieHere then
        return 4
      elseif chicaHere then
        return 5
      elseif freddyHere then
        if easter_egg_active then
          return 3 -- staring at camera
        end
        return 2
      end
      return 1
    end)

    add_camera(LOCATIONS["2B"], texture.cam_2b, function(self)
      if bonnieObject.location == LOCATIONS["2B"] then
        if easter_egg_active then
          return 5
        end
        return math.random(3, 4)
      end
      if easter_egg_active then
        return 2
      end
      return 1
    end)

    local foxyRunCycle = 0
    local lastFoxyRunCycleUpdate = os.epoch("utc")
    add_camera(LOCATIONS["2A"], texture.cam_2a, function(self)
      if foxyObject.location == LOCATIONS["2A"] then
        if os.epoch("utc") - lastFoxyRunCycleUpdate > 0.05 then
          foxyRunCycle = foxyRunCycle + 1
          lastFoxyRunCycleUpdate = os.epoch("utc")
        end
        if foxyRunCycle > 9 then
          foxyObject.location = LOCATIONS.IN_OFFICE
          return 1
        end
        return 2 + foxyRunCycle
      elseif bonnieObject.location == LOCATIONS["2A"] then
        return 2
      end
      return 1
    end)

    add_camera(LOCATIONS["1B"], texture.cam_1b, function(self)
      if bonnieObject.location == LOCATIONS.DINING_FAR then
        return 2
      elseif bonnieObject.location == LOCATIONS.DINING_NEAR then
        return 3
      elseif chicaObject.location == LOCATIONS.DINING_FAR then
        return 4
      elseif chicaObject.location == LOCATIONS.DINING_NEAR then
        return 5
      elseif freddyObject.location == LOCATIONS.DINING_FAR then
        return 6
      end
      return 1
    end)

    add_camera(LOCATIONS["1C"], texture.cam_1c, function(self)
      if foxyObject.location ~= LOCATIONS["1C"] then
        return 4
      end
      return foxyObject.stage
    end)

    add_camera(LOCATIONS["7"], texture.cam_7, function(self)
      if freddyObject.location == LOCATIONS["7"] then
        return 4
      elseif chicaObject.location == LOCATIONS["7"] then
        if easter_egg_active then
          return 3
        end
        return 2
      end
      return 1
    end)

    add_camera(LOCATIONS["5"], texture.cam_5, function(self)
      if bonnieObject.location == LOCATIONS["5"] then
        if easter_egg_active then
          return 3
        end
        return 2
      end
      if easter_egg_active then
        return 4
      end
      return 1
    end)

    add_camera(LOCATIONS["3"], texture.cam_3, function(self)
      if bonnieObject.location == LOCATIONS["3"] then
        return 2
      end
      return 1
    end)

    local camera6 = engine.object(#texture.cam_1a[1][1][1], #texture.cam_1a[1])
    camera6.draw = function(self, delta)
      self.window.setBackgroundColor(black)
      self.window.setTextColor(white)
      self.window.clear()
      bigfont.writeOn(self.window, 1, "CAMERA DISABLED", math.floor(#texture.cam_1a[1][1][1] / 2) - 10, 4)
    end
    cameraViewbox:addChild(camera6, 1, 1)
    CAMERAS[LOCATIONS["6"]] = camera6

    add_camera(LOCATIONS["4A"], texture.cam_4a, function(self)
      if chicaObject.location == LOCATIONS["4A"] then
        if easter_egg_active then
          return 3
        end
        return 2
      elseif freddyObject.location == LOCATIONS["4A"] then
        return 4
      end
      if easter_egg_active then
        return 5
      end
      return 1
    end)

    add_camera(LOCATIONS["4B"], texture.cam_4b, function(self)
      if chicaObject.location == LOCATIONS["4B"] then
        if easter_egg_active then
          return 4
        end
        return math.random(2, 3)
      elseif freddyObject.location == LOCATIONS["4B"] then
        return 5
      end
      return 1
    end)

    set_camera(LOCATIONS.STAGE)

    cameraViewbox:pingPong(scrollWidth, 1, moveTime, waitTime)


    local cameraMap = engine.staticObject(texture.map)
    cameraContainer:addChild(cameraMap, 80, 23)
    cameraMap.z = 2
    cameraMap.label = "cameraMap"

    local function add_camera_button(camera, x, y)
      local cam_button = engine.object(4, 3)
      cam_button.draw = function(self, delta)
        if active_camera == LOCATIONS[camera] then
          self.window.setBackgroundColor(white)
          self.window.setTextColor(black)
        else
          self.window.setBackgroundColor(black)
          self.window.setTextColor(white)
        end
        self.window.clear()
        self.window.setCursorPos(2, 2)
        self.window.write(camera)
      end
      cam_button.onClick = function(self, x, y)
        set_camera(LOCATIONS[camera])
      end
      cameraMap:addChild(cam_button, x, y)
    end
    add_camera_button("1A", 14, 3)
    add_camera_button("1B", 12, 7)
    add_camera_button("1C", 8, 12)
    add_camera_button("2A", 13, 19)
    add_camera_button("2B", 13, 24)
    add_camera_button("3", 5, 20)
    add_camera_button("4A", 25, 19)
    add_camera_button("4B", 25, 24)
    add_camera_button("5", 1, 8)
    add_camera_button("6", 34, 19)
    add_camera_button("7", 33, 8)

    local closeCameraButton = engine.staticObject(texture.bar)
    cameraContainer:addChild(closeCameraButton, 25, 47)
    closeCameraButton.z = 3

    cameraContainer.visible = false
    cameraContainer.active = false

    local cameraAnimation = engine.animatedObject(texture.camera, "FORWARD", function(self)
      if self.direction == 1 then
        setState("CAMERA")
      else
        setState("OFFICE")
      end
    end)
    gameObject:addChild(cameraAnimation, 1, 1)
    cameraAnimation.visible = false
    cameraAnimation.active = false

    closeCameraButton.onClick = function(self, x, y)
      soundEngine.playAudio(sound.camera)
      setState("CAMERA_ANIM")
      cameraAnimation.frame = #cameraAnimation.image
      cameraAnimation.animate = true
      engine.setAnimationMode(cameraAnimation, "BACKWARD")
      power_usage = power_usage - 1
    end

    cameraButton.onClick = function(self, x, y)
      soundEngine.playAudio(sound.camera)
      setState("CAMERA_ANIM")
      cameraAnimation.frame = 1
      cameraAnimation.animate = true
      engine.setAnimationMode(cameraAnimation, "FORWARD")
      power_usage = power_usage + 1
    end

    local function setEnabled(obj, act)
      obj.visible = act
      obj.active = act
    end

    ---@param ns "OFFICE"|"CAMERA"|"CAMERA_ANIM"
    function setState(ns)
      state = ns
      if state == "OFFICE" then
        setEnabled(officeView, true)
        setEnabled(cameraAnimation, false)
        setEnabled(cameraContainer, false)
      elseif state == "CAMERA" then
        setEnabled(officeView, false)
        setEnabled(cameraAnimation, false)
        setEnabled(cameraContainer, true)
      elseif state == "CAMERA_ANIM" then
        setEnabled(officeView, false)
        setEnabled(cameraAnimation, true)
        setEnabled(cameraContainer, false)
      end
    end
  end

  local function out_of_power()
    bonnieObject.active = false
    chicaObject.active = false
    freddyObject.active = false
    foxyObject.active = false
    open_door(leftDoor)
    open_door(rightDoor)
    leftButton.active = false
    rightButton.active = false
    batteryIndicator.visible = false
    lightOn = nil
    setState("OFFICE")
    cameraButton.visible = false
    cameraButton.active = false
    fan.visible = false
    power_out = true
    -- TODO end game timer
  end

  gameObject:addTimer(function(self)
    if power_remaining > 0 then
      power_remaining = power_remaining - (0.1041666666666666666 * power_usage)
      if power_remaining <= 0 then
        out_of_power()
      end
    end
  end, 1000, true) -- Battery drain

  g.setPalette(texture.office.palette)

  g.root:enableDebug()

  parallel.waitForAny(g.start, soundEngine.start)
  return gameReturnValue
end

local function getNumber(text, min, max)
  local num
  repeat
    write(text)
    num = tonumber(read())
  until num and num >= min and num <= max
  return num
end
while true do
  local night = getNumber("Night(1-7)? ", 1, 7)
  if night == 7 then
    print("CUSTOM NIGHT!")
    local bonnie, chica, freddy, foxy = 0, 0, 0, 0
    bonnie = getNumber("Bonnie? ", 0, 20)
    chica = getNumber("Chica? ", 0, 20)
    fnaf(night, bonnie, chica)
  else
    fnaf(night)
  end
  print("Game exited.")
  sleep(5)
end
