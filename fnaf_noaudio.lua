-- images are at 21.69%
-- 6x4 monitor at 242 x 156 pixels (121 x 52 chars)
-- the screen is 52 characters too narrow to fit the office
local engine = require "engine"

local g = engine.game("top")
local t_office = engine.loadTexture("office.bimg")
local t_left_door = engine.loadTexture("left_door.bimg")
local t_left_button = engine.loadTexture("left_button.bimg")
local t_left_bar = engine.loadTexture("left.bimg")
local t_right_bar = engine.loadTexture("right.bimg")
local t_bar = engine.loadTexture("bar.bimg")
local t_camera = engine.loadTexture("camera.bimg")
local t_bonnie = engine.loadTexture("bonnie.bimg")

local officeView = engine.object(g.root.w, g.root.h)
officeView.label = "officeView"

local leftLightOn = false
g.root:addChild(officeView,1,1)
local office = engine.statedObject(t_office, function (self)
  if leftLightOn then
    return 1
  end
  return 2
end)
office.label = "office"
officeView:addChild(office, 1, 1)

local cameraButton = engine.staticObject(t_bar, 1)
cameraButton.z = 2
officeView:addChild(cameraButton, 25, 47)

local leftDoor = engine.animatedObject(t_left_door, "FORWARD", function (self)
  if self.direction == -1 then
    self.visible = false
  end
end)
leftDoor.isOpen = false
leftDoor.label = "leftDoor"
office:addChild(leftDoor, 12, 1)
local leftButton = engine.statedObject(t_left_button, function(self)
  if leftDoor.isOpen and not leftLightOn then
    return 4
  elseif not leftLightOn then
    return 3
  elseif leftDoor.isOpen then
    return 2
  end
  return 1
end)

leftButton.label = "leftButton"
leftButton.onClick = function (self, x, y)
  if y < 7 then
    -- door
    if true or not leftDoor.animate then
      if leftDoor.isOpen then
        engine.setAnimationMode(leftDoor, "FORWARD")
        leftDoor.visible = true
      else
        engine.setAnimationMode(leftDoor, "BACKWARD")
      end
      leftDoor.animate = true
      leftDoor.isOpen = not leftDoor.isOpen
    end
  else
    leftLightOn = not leftLightOn
  end
end
office:addChild(leftButton, 5, 18)

local lookLeft
local lookRight = engine.staticObject(t_right_bar)
lookRight.z = 2
lookRight.label = "lookRight"
lookRight.onClick = function (self, x, y)
  self.visible = false
  self.active = false
  lookLeft.visible = true
  lookLeft.active = true
  office:linearMove(-52, 1, 1000)
end
officeView:addChild(lookRight, officeView.w - lookRight.w - 1, 2)

lookLeft = engine.staticObject(t_left_bar)
lookLeft.label = "lookLeft"
lookLeft.z = 2
lookLeft.onClick = function (self, x, y)
  self.visible = false
  self.active = false
  lookRight.visible = true
  lookRight.active = true
  office:linearMove(1, 1, 1000)
end
lookLeft.visible = false
lookLeft.active = false
officeView:addChild(lookLeft, 2, 2)

local moveTime = 4000
local waitTime = 5000
local cameraView = engine.object(g.root.w, g.root.h)
local cameraContents = engine.staticObject(t_bonnie)
cameraContents:addTimer(function (self)
  if self.x < -25 then
    self:linearMove(1,1,moveTime)
  else
    self:linearMove(-52,1,moveTime)
  end
end, waitTime, true)
cameraContents:linearMove(-52,1,moveTime)

cameraView:addChild(cameraContents, 1, 1)

local closeCameraButton = engine.staticObject(t_bar)
cameraView:addChild(closeCameraButton, 25, 47)


cameraView.visible = false
cameraView.active = false

local cameraAnimation = engine.animatedObject(t_camera, "FORWARD", function (self)
  self.visible = false
  self.active = false
  if self.direction == 1 then
    cameraView.visible = true
    cameraView.active = true
  else
    officeView.visible = true
    officeView.active = true
  end
end)
cameraAnimation.visible = false
cameraAnimation.active = false

closeCameraButton.onClick = function (self, x, y)
  cameraView.visible = false
  cameraView.active = false
  cameraAnimation.frame = #cameraAnimation.image
  cameraAnimation.visible = true
  cameraAnimation.active = true
  cameraAnimation.animate = true
  engine.setAnimationMode(cameraAnimation, "BACKWARD")
end


cameraButton.onClick = function (self, x, y)
  officeView.visible = false
  officeView.active = false
  cameraAnimation.frame = 1
  cameraAnimation.visible = true
  cameraAnimation.active = true
  cameraAnimation.animate = true
  engine.setAnimationMode(cameraAnimation, "FORWARD")
end

g.root:addChild(cameraAnimation, 1, 1)
g.root:addChild(cameraView, 1, 1)

g.setPalette(t_office.palette)

g.root:enableDebug()

g.start()