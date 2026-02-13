---@diagnostic disable: inject-field
--- Rudamentary 2D Click based game engine
-- This game engine supports up to 8 channels of priority based sound
-- And can render BIMG static images and animations

local expect = require "cc.expect".expect

local function tickCallbacks(callbackTable, self, delta)
  for k, v in pairs(callbackTable) do
    local cont = v(self, delta)
    if not cont then
      callbackTable[k] = nil
    end
  end
end

---@class ObjectInterface
local objectInterface = {}
---@param self Object
---@param delta number
function objectInterface._draw(self, delta)
  if self.visible then
    tickCallbacks(self.preRenderCallbacks, self, delta)
    self.window.clear()
    if self.draw then
      self:draw(delta)
    end
    local drawOrder = {}
    for k, v in pairs(self.children) do
      if v.visible then
        drawOrder[#drawOrder + 1] = v
      end
    end
    table.sort(drawOrder, function(a, b)
      return a.z < b.z -- higher z == drawn on top
    end)
    for k, v in ipairs(drawOrder) do
      v:_draw(delta)
    end
    tickCallbacks(self.postRenderCallbacks, self, delta)
    self.window.setVisible(true)
    self.window.redraw()
    self.window.setVisible(false)
  end
end

---Check if a given x,y position is within a region
---@param x integer
---@param y integer
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@return boolean
local function within(x, y, x1, y1, x2, y2)
  expect(1, x, "number")
  expect(2, y, "number")
  expect(3, x1, "number")
  expect(4, y1, "number")
  expect(5, x2, "number")
  expect(6, y2, "number")
  return x >= x1 and y >= y1 and x <= x2 and y <= y2
end

---@param self Object
---@param x integer
---@param y integer
function objectInterface._onClick(self, x, y)
  expect(2, x, "number")
  expect(3, y, "number")
  if self.debug then
    print("_onClick", self.label or self, x, y)
  end
  if self.onClick then
    self:onClick(x, y)
  end
end

---Enable printing out click coordinates for this object and all current children
---@param self Object
function objectInterface.enableDebug(self)
  self.debug = true
  for k, v in pairs(self.children) do
    v:enableDebug()
  end
end

---@param self Object
---@param x integer
---@param y integer
---@param w integer?
---@param h integer?
---@param parent ccTweaked.Window?
function objectInterface.reposition(self, x, y, w, h, parent)
  self.window.reposition(x, y, w, h, parent)
  self.x = x
  self.y = y
  self.w = self.w or w
  self.h = self.h or h
end

---comment
---@param self Object
---@param event string
---@param args any
---@return boolean
function objectInterface._isClick(self, event, args)
  return self.parent:_isClick(event, args)
end

---@param self Object
---@param event string
---@param ... any
function objectInterface.tick(self, event, ...)
  -- tick timers
  for k, v in pairs(self.timers) do
    self:tickTimer(k)
  end
  -- tick threads
  for k, co in pairs(self.threads) do
    if not self._threadFilters[co] or self._threadFilters[co] == "" or self._threadFilters[co] == event then
      local ok, filter = coroutine.resume(co, event, ...)
      if not ok then
        self.threads[k] = nil
        self._threadFilters[co] = nil
      end
      self._threadFilters[co] = filter
    end
  end
  -- tick children
  local args = { ... }
  local x, y = args[2], args[3]
  local clickAte = false
  for k, v in pairs(self.children) do
    if v.active then
      if self:_isClick(event, args) then
        local child_w, child_h = v.w, v.h
        local child_x, child_y = x - v.x + 1, y - v.y + 1
        if within(child_x, child_y, 1, 1, child_w, child_h) then
          v:tick(event, args[1], child_x, child_y)
          clickAte = true
        end
      else
        v:tick(event, ...)
      end
    end
  end
  if self:_isClick(event, args) and not clickAte then
    self:_onClick(x, y)
  end
end

---@param self Object
---@param func fun(self: Object)
function objectInterface.addThread(self, func)
  local coro = coroutine.create(func)
  local ok, filt = coroutine.resume(coro, self)
  if ok then
    self._threadFilters[coro] = filt
    self.threads[coro] = coro
  end
end

---@param self Object
---@param child Object
---@param x integer
---@param y integer
function objectInterface.addChild(self, child, x, y)
  child.parent = self
  self.children[child] = child
  child.x, child.y = x, y
  self:resetWindows()
end

---@param self Object
---@param child Object
function objectInterface.removeChild(self, child)
  self.children[child] = nil
end

---@param self Object
function objectInterface.resetWindows(self)
  if not self.parent then
    print(debug.traceback("No parent"))
    return -- cannot reset windows if we don't have a parent
  end
  if not self.parent.window then
    print(debug.traceback("No parent window"))
    return
  end
  self.window = window.create(self.parent.window, self.x, self.y, self.w, self.h, false)
  for k, v in pairs(self.children) do
    v:resetWindows()
  end
end

---Add a timer to this object
---@param self Object
---@param func fun(self: Object):boolean?
---@param interval number milliseconds
---@param rep integer|boolean?
---@return integer handle
function objectInterface.addTimer(self, func, interval, rep)
  ---@type timer
  local timer = {
    func = func,
    interval = interval,
    ["repeat"] = rep,
    startTime = os.epoch("utc"),
    paused = false
  }
  self.lastTimerId = self.lastTimerId + 1
  self.timers[self.lastTimerId] = timer
  return self.lastTimerId
end

---Cancel a timer on this object
---@param self Object
---@param id integer
function objectInterface.cancelTimer(self, id)
  expect(2, id, "number")
  self.timers[id] = nil
end

---Pause/unpause a timer on this object
---@param self Object
---@param id integer
---@param paused boolean
function objectInterface.setTimerPaused(self, id, paused)
  expect(2, id, "number")
  if not self.timers[id] then return end -- TODO redecide this
  self.timers[id].paused = paused
end

---Restart a timer, unpauses as well. Timer must still exist.
---@param self Object
---@param id integer
function objectInterface.restartTimer(self, id)
  expect(2, id, "number")
  if not self.timers[id] then return end -- TODO redecide this
  local timer = self.timers[id]
  timer.startTime = os.epoch("utc")
  timer.paused = false
end

---@param self Object
---@param timerId integer
local function handleTimerRepeat(self, timerId)
  local timer = self.timers[timerId]
  local rep = timer["repeat"]
  if type(rep) == "number" then
    timer["repeat"] = rep - 1
    if timer["repeat"] == 0 then
      -- self.timers[timerId] = nil -- TODO redecide this. Might want to restart a one shot timer.
      self.timers[timerId].paused = true
      return
    end
  end
  timer.startTime = os.epoch("utc")
  -- self.timers[timerId] = timer
end

---@param self Object
---@param timerId integer
function objectInterface.tickTimer(self, timerId)
  local timer = self.timers[timerId]
  if timer and (timer.startTime + timer.interval < os.epoch("utc")) and not timer.paused then
    if timer.func(self) then
      self.timers[timerId] = nil
      return
    end
    local rep = timer["repeat"]
    if rep then
      return handleTimerRepeat(self, timerId)
    else
      self.timers[timerId] = nil
    end
  end
end

---@param v0 number
---@param v1 number
---@param t number
---@return number
local function lerp(v0, v1, t)
  return v0 + t * (v1 - v0)
end


---@param self Object
---@param delta number
local function lerpRenderCallback(self, delta)
  self.timeElapsed = self.timeElapsed + delta
  local progress = math.min(self.timeElapsed / self.totalTime, 1)
  local newX = lerp(self.x1, self.x2, progress)
  local newY = lerp(self.y1, self.y2, progress)
  self:reposition(newX, newY)
  return progress ~= 1
end

---@param self Object
---@param x integer
---@param y integer
---@param delta number time to move ms
function objectInterface.linearMove(self, x, y, delta)
  self.timeElapsed = 0
  self.x1 = self.x
  self.y1 = self.y
  self.x2 = x
  self.y2 = y
  self.totalTime = delta
  self:addRenderCallback("post", lerpRenderCallback)
end

---@param self Object
---@param delta number
local function pingPongRenderCallback(self, delta)
  self.timeElapsed = self.timeElapsed + delta
  if self.stopped then
    local progress = math.min(self.timeElapsed / self.totalTime, 1)
    if progress == 1 then
      self.stopped = false
      self.timeElapsed = 0
    end
    return true
  end
  local progress = math.min(self.timeElapsed / self.totalTime, 1)
  local toX, toY, fromX, fromY
  if self.moveDirection == 1 then
    toX, toY = self.x2, self.y2
    fromX, fromY = self.x1, self.y1
  elseif self.moveDirection == -1 then
    toX, toY = self.x1, self.y1
    fromX, fromY = self.x2, self.y2
  end
  local newX = lerp(fromX, toX, progress)
  local newY = lerp(fromY, toY, progress)
  self:reposition(newX, newY)
  if progress == 1 then
    self.stopped = true
    self.timeElapsed = 0
    self.moveDirection = self.moveDirection * -1
  end
  return true
end

---Apply a ping pong animation to this object
---@param self Object
---@param x number
---@param y number
---@param delta number
---@param hold number
function objectInterface.pingPong(self, x, y, delta, hold)
  self.timeElapsed = 0
  self.x1 = self.x
  self.y1 = self.y
  self.x2 = x
  self.y2 = y
  self.totalTime = delta
  self.holdTime = hold
  self.moveDirection = 1
  self.stopped = false
  self:addRenderCallback("post", pingPongRenderCallback)
end

---@alias renderCallback fun(self: Object, delta: number): boolean

---Add a render thread
---@param self Object
---@param pos "pre"|"post"
---@param func renderCallback
function objectInterface.addRenderCallback(self, pos, func)
  if pos == "pre" then
    self.preRenderCallbacks[func] = func
  elseif pos == "post" then
    self.postRenderCallbacks[func] = func
  else
    error("Invalid argument for pos", 2)
  end
end

---@param self Object
---@param palette table<integer,integer[]>
function objectInterface.setPalette(self, palette)
  for k, v in pairs(palette) do
    self.window.setPaletteColor(2 ^ k, table.unpack(v))
  end
  for k, v in pairs(self.children) do
    v:setPalette(palette)
  end
end

---@param w integer
---@param h integer
---@return Object
local function object(w, h)
  ---@class Object : ObjectInterface
  ---@field parent Object?
  ---@field onClick fun(self: Object, x: integer, y:integer)?
  ---@field draw fun(self: Object, delta: number)?
  ---@field timers table<integer,timer>
  ---@field lastTimerId integer Last timerID used
  ---@field debug boolean?
  ---@field label string?
  ---@field window ccTweaked.Window?
  local self = {}

  ---@alias timer {func: function, interval: integer, paused: boolean, repeat: boolean|integer?, startTime: number?}
  ---@type table<integer,timer>
  self.timers = {}
  self.lastTimerId = 0

  self.w, self.h = w, h
  self.x, self.y = 1, 1
  self.z = 1
  self.visible = true
  self.active = true

  ---@type table<thread,string>
  self._threadFilters = {}
  ---@type table<thread,thread>
  self.threads = {}
  ---@type table<renderCallback,renderCallback>
  self.preRenderCallbacks = {}
  ---@type table<renderCallback,renderCallback>
  self.postRenderCallbacks = {}
  ---@type table<Object,Object>
  self.children = {}

  for k, v in pairs(objectInterface) do
    self[k] = v
  end
  return self
end

---@alias BIMGFrame {[1]: string, [2]: string, [3]: string}[]

---@param self Object
local function drawBIMGFrame(self)
  local window = assert(self.window, "No window")
  for k, v in ipairs(self.image[self.frame]) do
    window.setCursorPos(1, k)
    window.blit(table.unpack(v))
  end
end

---@return string
local function loadFile(filename)
  local f = fs.open(filename, "rb")
  if f then
    local read = f.readAll() or ""
    f.close()
    return read
  end
  error(("File %s does not exist."):format(filename))
end

local function loadTableFromFile(filename)
  local filedata = loadFile(filename)
  return assert(textutils.unserialise(filedata), ("File %s is not a table."):format(filename))
end

---@alias BIMG {[1]: BIMGFrame, palette: table<integer,table|number>}



---@param obj AnimatedObject
local function modeSensitiveBounds(obj)
  if obj.frame < 1 then
    if obj.mode == "BACKWARD" then
      obj.frame = 1
      obj.animate = false
      if obj.stopCallback then
        obj:stopCallback()
      end
      return
    elseif obj.mode == "BACKWARD_LOOP" then
      obj.frame = #obj.image
      return
    elseif obj.mode == "PING_PONG" then
      obj.direction = obj.direction * -1
      obj.frame = 1
      return
    end
    error(("Mode %s should never go < 1"):format(obj.mode))
  elseif obj.frame > #obj.image then
    if obj.mode == "FORWARD" then
      obj.frame = #obj.image
      obj.animate = false
      if obj.stopCallback then
        obj:stopCallback()
      end
      return
    elseif obj.mode == "FORWARD_LOOP" then
      obj.frame = 1
      return
    elseif obj.mode == "PING_PONG" then
      obj.direction = obj.direction * -1
      obj.frame = #obj.image
      return
    end
    error(("Mode %s should never go > n"):format(obj.mode))
  end
end

local function drawAnimation(self, delta)
  drawBIMGFrame(self)
  if self.animate then
    self.frametime = self.frametime + delta
    local msPerFrame = 1000 / self.fps
    if self.frametime >= msPerFrame then
      local frames = math.floor(self.frametime / msPerFrame)
      self.frame = self.frame + (frames * self.direction)
      self.frametime = 0
      modeSensitiveBounds(self)
    end
  end
end

---@alias animationMode "FORWARD" | "FORWARD_LOOP" | "BACKWARD" | "BACKWARD_LOOP" | "PING_PONG"

---@param obj AnimatedObject
---@param mode animationMode
local function setAnimationMode(obj, mode)
  if mode == "BACKWARD" or mode == "BACKWARD_LOOP" then
    obj.direction = -1
  elseif mode == "FORWARD" or mode == "FORWARD_LOOP" then
    obj.direction = 1
  end
  obj.direction = obj.direction or 1
  obj.mode = mode
end

---@param obj Object
---@param bimg BIMG
---@param mode animationMode
---@param stopCallback function?
---@param fps number? Desired FPS (defaults to 20fps)
---@return AnimatedObject
local function animation(obj, bimg, mode, stopCallback, fps)
  ---@class AnimatedObject : Object
  ---@field mode animationMode
  ---@field animate boolean whether to animate this object
  ---@field frame integer current frame displayed
  ---@field stopCallback function? function to call when endpoint reached
  ---@field direction integer direction to increment frames
  ---@field image BIMG
  ---@field frametime number time spent on this frame
  obj.image = bimg
  obj.frame = 1
  obj.animate = true
  obj.fps = fps or 20
  obj.frametime = 0
  setAnimationMode(obj --[[@as AnimatedObject]], mode)
  obj.stopCallback = stopCallback
  obj.draw = drawAnimation
  return obj --[[@as AnimatedObject]]
end

local function loadBIMGRaw(s)
  return textutils.unserialise(s)
end

local unpackCache = {}
for i = 0, 255 do
  unpackCache[i] = {
    colors.toBlit(2 ^ bit32.rshift(i, 4)),
    colors.toBlit(2 ^ bit32.band(i, 15))
  }
end
local function unpackLine(s, i, w)
  local us = {}
  local fi = math.min(#s, i + math.ceil(w / 2) - 1)
  for j = i, fi do
    local u = unpackCache[s:byte(j, j)]
    us[#us + 1] = u[1]
    us[#us + 1] = u[2]
  end
  local fs = table.concat(us, ""):sub(1, w)
  return fs, fi + 1
end

local lualzw = require "lualzw"

local t0 = os.epoch("utc")
local function loadSBIMGRaw(s)
  local i = 1
  local w, h, frames, hasPalette, i = string.unpack("HHHB", s, i)
  local bimg = loadBIMGRaw(lualzw.decompress(s))
  -- if hasPalette ~= 0 then
  --   bimg.palette = {}
  --   for c = 0, 15 do
  --     local col
  --     col, i = string.unpack("I3", s, i)
  --     bimg.palette[c] = { col }
  --   end
  -- end
  -- local fs = s:sub(i)
  -- i = 1
  -- for frame = 1, frames do
  --   bimg[frame] = {}
  --   for y = 1, h do
  --     bimg[frame][y] = {}
  --     local line = bimg[frame][y]
  --     line[1], i = s:sub(i, i + w - 1), i + w
  --     line[2], i = unpackLine(fs, i, w)
  --     line[3], i = unpackLine(fs, i, w)
  --   end
  -- end
  if t0 + 1000 < os.epoch('utc') then
    t0 = os.epoch 'utc'
    os.queueEvent("fakeevent")
    os.pullEvent("fakeevent")
  end
  return bimg
end
local packCache = {}
for i = 0, 15 do
  local n = bit32.lshift(i, 4)
  local ch1 = colors.toBlit(2 ^ i)
  for j = 0, 15 do
    local n2 = bit32.bor(n, j)
    local ch2 = colors.toBlit(2 ^ j)
    packCache[ch1 .. ch2] = n2
  end
end
local function packLine(s)
  local ns = {}
  for i = 1, #s, 2 do
    local ch = s:sub(i, i + 1)
    if #ch == 1 then
      ch = ch .. "0"
    end
    ns[#ns + 1] = string.char(packCache[ch])
  end
  return table.concat(ns, "")
end

local function serializeSBIMG(img)
  -- local w, h, frames = #img[1][1][1], #img[1], #img
  -- local header = string.pack("HHHB", w, h, frames, img.palette and 1 or 0)
  -- local s = {}
  -- if img.palette then
  --   for v = 0, 15 do
  --     local r, g, b = table.unpack(img.palette[v] or { 0 })
  --     if g and b then
  --       r = colors.packRGB(r, g, b)
  --     end
  --     s[#s + 1] = string.pack("I3", r)
  --   end
  -- end
  -- for frame, data in ipairs(img) do
  --   for y, line in ipairs(data) do
  --     s[#s + 1] = line[1]
  --     s[#s + 1] = packLine(line[2])
  --     s[#s + 1] = packLine(line[3])
  --   end
  -- end
  -- return header .. (table.concat(s, ""))
  return lualzw.compress(textutils.serialise(img))
end

local function saveTexture(filename, img, verbose)
  local t0 = os.epoch("utc")
  if verbose then
    print(("Saving textures.%s..."):format(filename))
  end
  local s = serializeSBIMG(img)
  local f = assert(fs.open(filename, "w"))
  f.write(s)
  f.close()
  if verbose then
    print(("Saved textures.%s in %.2fsec"):format(filename, (os.epoch("utc") - t0) / 1000))
  end
end

---@param filename string
---@param verbose boolean?
---@return BIMG
local function loadTexture(filename, verbose)
  local t0 = os.epoch("utc")
  if verbose then
    print(("Loading textures.%s..."):format(filename))
  end
  local s = loadFile(filename)
  local texture
  if filename:sub(-5) == ".bimg" then
    texture = loadBIMGRaw(s) --[[@as BIMG]]
  elseif filename:sub(-5) == "sbimg" then
    texture = loadSBIMGRaw(s) --[[@as BIMG]]
  end
  assert(texture, ("Failed to load textures.%s!"):format(filename))
  if verbose then
    print(("Loaded textures.%s in %.2fsec"):format(filename, (os.epoch("utc") - t0) / 1000))
  end
  return texture
end

---Create a simple static image object
---@param texture BIMG
---@param frame integer?
---@return Object
local function staticObject(texture, frame)
  local bimg = texture
  local o = object(#bimg[1][1][1], #bimg[1])
  o.frame = frame or 1
  o.image = bimg
  o.draw = drawBIMGFrame
  return o
end

---Create a simple animated image object
---@param texture BIMG
---@param mode animationMode
---@param stopCallback fun(self: Object)?
---@param fps number? Desired FPS (defaults to 20fps)
---@return AnimatedObject
local function animatedObject(texture, mode, stopCallback, fps)
  local bimg = texture
  local o = object(#bimg[1][1][1], #bimg[1])
  return animation(o, bimg, mode, stopCallback, fps)
end

local function drawStatedObject(self, delta)
  self.frame = self:stateProvider()
  drawBIMGFrame(self)
end

---Create a static object, that changes the texture frame based on a function
---@param texture BIMG
---@param frame fun(self: Object): integer
---@return Object
local function statedObject(texture, frame)
  local bimg = texture
  local o = object(#bimg[1][1][1], #bimg[1])
  o.stateProvider = frame
  o.draw = drawStatedObject
  o.image = bimg
  return o
end

---Context initializer, manage resource loading and object running
---@param displayName string
---@return Context
local function context(displayName)
  ---@class Context
  local self = {}

  local w, h, display, win
  if displayName ~= "term" then
    ---@type ccTweaked.peripherals.Monitor
    display = assert(peripheral.wrap(displayName), "Invalid display") --[[@as ccTweaked.peripherals.Monitor]]
    display.setTextScale(0.5)
  else
    display = term.current()
  end
  w, h = display.getSize()
  win = window.create(display, 1, 1, w, h)

  self.root = object(w, h)
  self.root.parent = {
    window = win,
    _isClick = function(self, event, args)
      if event == "mouse_click" and displayName == "term" then
        return true
      elseif event == "monitor_touch" and args[1] == displayName then
        return true
      end
      return false
    end,
    lastTimerId = 0,
    timers = {}
  }
  self.root:resetWindows()
  self.root.label = "root"

  local running = true
  local retVal
  local renderTimer
  function self.start()
    local lastRendertime = os.epoch("utc")
    while running do
      if not renderTimer then
        renderTimer = os.startTimer(0.05)
      end
      local e = table.pack(os.pullEvent())
      if e[1] == "timer" and e[2] == renderTimer then
        win.setVisible(false)
        win.clear()
        renderTimer = nil
        local currentTime = os.epoch("utc")
        self.root:_draw(currentTime - lastRendertime)
        lastRendertime = currentTime
        win.setVisible(true)
        win.redraw()
      end
      -- assert(xpcall(self.root.tick, function() print(debug.traceback()) end, self.root, table.unpack(e, 1, e.n)))
      self.root:tick(table.unpack(e, 1, e.n))
    end
    return retVal
  end

  function self.exit(returnValue)
    retVal = returnValue
    running = false
  end

  ---@param palette table<integer,integer[]>
  function self.setPalette(palette)
    for k, v in pairs(palette) do
      display.setPaletteColor(2 ^ k, table.unpack(v))
    end
    self.root:setPalette(palette)
  end

  return self
end

return {
  game = context,
  object = object,
  drawBIMGFrame = drawBIMGFrame,
  setAnimationMode = setAnimationMode,
  staticObject = staticObject,
  animatedObject = animatedObject,
  statedObject = statedObject,
  loadTexture = loadTexture,
  saveTexture = saveTexture
}
