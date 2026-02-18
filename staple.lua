---@diagnostic disable: duplicate-set-field, undefined-doc-name, inject-field, param-type-mismatch
-- Modern recreation of stitch
-- This can be used as a library or as a command-line tool
-- Scrolling requires buffering to be enabled, pass layout.buffer = true
-- This significantly slows down staple, enabling literally just wraps staple in a window

local function getNative()
    local i = 1
    while true do
        local n, v = debug.getupvalue(peripheral.call, i)
        if not n then break end
        if n == "native" then return v end
        i = i + 1
    end
    error("peripheral.call has been overwritten!")
end


local native = getNative()
local function fastwrap(side)
    local periph = peripheral.wrap(side) --[[@as table]]
    for k, v in pairs({ peripheral.find("modem", function(name, wrapped)
        return not wrapped.isWireless()
    end) }) do
        if v.isPresentRemote(side) then
            local wrapped = {}
            for method, _ in pairs(periph) do
                wrapped[method] = function(...)
                    return native.call(peripheral.getName(v), "callRemote", side, method, ...)
                end
            end
            wrapped.name = side
            return wrapped
        end
    end
    error(("Peripheral %s not found."):format(side))
end

---Create a new Stapled term object
---@param layout string[][]
---@return staple.Stapled
local function staple(layout)
    local cursorx, cursory = 1, 1
    local w, h
    local fg, bg = colors.white, colors.black
    ---@type Monitor[][]
    local monitors = {}

    ---@alias staple.monitorInfo {w:integer,h:integer,x:integer,y:integer}
    ---@type staple.monitorInfo[][]
    local monitorInfo = {}

    ---@type table<string,staple.monitorInfo>
    local monitorLookup = {}

    ---@param fun fun(x: integer, y: integer, mon: Monitor)
    local function runOnAll(fun)
        for y, row in ipairs(monitors) do
            for x, mon in ipairs(row) do
                fun(x, y, mon)
            end
        end
    end

    local function updateSize()
        -- update all monitors
        for y, row in ipairs(layout) do
            monitors[y] = {}
            for x, mon in ipairs(row) do
                monitors[y][x] = fastwrap(mon) --[[@as Monitor]]
            end
        end
        w = 0
        h = 0
        monitorLookup = {}
        runOnAll(function(x, y, mon)
            monitorInfo[y] = monitorInfo[y] or {}
            local monW, monH = mon.getSize()
            local monX, monY = 1, 1
            if x > 1 then
                -- not the leftmost monitor
                local leftMonitor = monitorInfo[y][x - 1]
                monX = leftMonitor.x + leftMonitor.w
            else
                h = h + monH
            end
            if y > 1 then
                -- not the topmost monitor
                local topMonitor = monitorInfo[y - 1][x]
                monY = topMonitor.y + topMonitor.h
            else
                w = w + monW
            end
            monitorInfo[y][x] = { w = monW, h = monH, x = monX, y = monY }
            monitorLookup[mon.name] = monitorInfo[y][x]
        end)
    end
    updateSize()

    ---@param name string
    ---@param ... any
    local function callOnAll(name, ...)
        local args = table.pack(...)
        local val
        runOnAll(function(x, y, mon)
            -- if val then
            --     return
            -- end
            local success
            success, val = pcall(mon[name], table.unpack(args, 1, args.n))
            if not success then
                error(("Called %s, Errored %s"):format(name, val))
            end
        end)
        return val
    end

    ---@class staple.Stapled : ccTweaked.term.Redirect
    local monEmu = {}

    for k, _ in pairs(monitors[1][1]) do -- allow access to window methods
        monEmu[k] = function(...)
            return callOnAll(k, ...)
        end
    end

    function monEmu.setCursorPos(x, y)
        cursorx = x
        cursory = y
        runOnAll(function(mx, my, mon)
            local monInfo = monitorInfo[my][mx]
            mon.setCursorPos(x - monInfo.x + 1, y - monInfo.y + 1)
        end)
    end

    function monEmu.blit(text, textColor, backgroundColor)
        runOnAll(function(x, y, mon)
            mon.blit(text, textColor, backgroundColor)
        end)
        cursorx = cursorx + #text
    end

    function monEmu.getCursorPos()
        return cursorx, cursory
    end

    function monEmu.getSize()
        return w, h
    end

    function monEmu.write(text)
        runOnAll(function(x, y, mon)
            mon.write(text)
        end)
        cursorx = cursorx + #text
    end

    function monEmu.getPaletteColor(col)
        return monitors[1][1].getPaletteColor(col)
    end

    monEmu.getPaletteColour = monEmu.getPaletteColor

    monEmu.setCursorPos(1, 1)

    function monEmu.setTextScale(scale)
        for yp, row in ipairs(monitors) do
            for xp, win in ipairs(row) do
                win.setTextScale(scale)
            end
        end
        updateSize()
    end

    function monEmu.scroll(y)
        error("Staple needs to be buffered for scrolling to work.")
    end

    ---Start a loop to listen for monitor_touch events on composite monitors,
    ---then requeue them as if they are monitor_touch events for the given monitor name.
    function monEmu.redirectTouches(name)
        while true do
            local _, mon, x, y = os.pullEvent("monitor_touch")
            local info = monitorLookup[mon]
            if info then
                local cx, cy = x + info.x - 1, y + info.y - 1
                if name == "term" then
                    os.queueEvent("mouse_click", 1, cx, cy)
                    os.queueEvent("mouse_up", 1, cx, cy)
                else
                    os.queueEvent("monitor_touch", name, cx, cy)
                end
            end
        end
    end

    local win = monEmu
    if layout.buffer then
        win = setmetatable(window.create(monEmu, 1, 1, w, h), { __index = monEmu })
        function win.setTextScale(scale)
            monEmu.setTextScale(scale)
            win.reposition(1, 1, w, h)
        end
    end
    return win
end

---Load a stapled term object from a file
---@param filename string
---@return staple.Stapled
local function loadStaple(filename)
    local f = assert(fs.open(filename, "r"))
    local d = assert(textutils.unserialise(f.readAll() --[[@as string]]), "Invalid file.") --[[@as table]]
    f.close()
    return staple(d)
end

local function runProgram(side, monitor, filename, args)
    local oldWrap = peripheral.wrap
    _ENV.peripheral = setmetatable({}, { __index = _G.peripheral })
    _ENV.peripheral.wrap = function(s)
        if s == side then
            return monitor
        end
        return oldWrap(s)
    end
    parallel.waitForAny(
        function()
            monitor.redirectTouches(side)
        end,
        function()
            loadfile(shell.resolve(filename), "t", _ENV)(table.unpack(args, 1, args.n))
        end
    )
end

local args = { ... }
local argsLookup = {
    setup = function()
        if #args < 4 then
            print("Usage: staple setup <width> <height> <filename> [buffer?]")
            return
        end
        local w = assert(tonumber(args[2]), help)
        local h = assert(tonumber(args[3]), help)
        local f = assert(fs.open(args[4], "w"))
        local monitors = {}
        print("Touch the monitors in order, from top left to bottom right.")
        for y = 1, h do
            monitors[y] = {}
            for x = 1, w do
                local _, side, _, _ = os.pullEvent("monitor_touch")
                local mon = peripheral.wrap(side) --[[@as Monitor]]
                local info = ("%s attached at (%u,%u)"):format(side, x, y)
                print(info)
                monitors[y][x] = side
                mon.setTextScale(1)
                local mw, mh = mon.getSize()
                mon.setTextScale(mw / (#info * 1.25))
                mw, mh = mon.getSize()
                mon.setBackgroundColor(2 ^ ((x + (y * w)) % 15))
                mon.clear()
                mon.setCursorPos((mw - #info) / 2, mh / 2)
                mon.write(info)
            end
        end
        monitors.buffer = not not args[5]
        f.write(textutils.serialise(monitors))
        f.close()
    end,
    attach = function()
        if #args < 4 then
            print("Usage: staple attach <filename> <side> <program_filename> <args...>")
            return
        end
        local stapled = loadStaple(args[2])
        runProgram(args[3], stapled, args[4], table.pack(table.unpack(args, 5, args.n)))
    end,
    redirect = function()
        if #args < 3 then
            print("Usage: staple redirect <filename> <program> <args...>")
            return
        end
        local stapled = loadStaple(args[2])
        term.redirect(stapled)
        parallel.waitForAny(
            function()
                stapled.redirectTouches("term")
            end, function()
                shell.run(args[3], table.unpack(args, 4, args.n))
            end
        )
    end
}

if #args == 2 and type(package.loaded[args[1]]) == "table" and not next(package.loaded[args[1]]) then
    return {
        staple = staple,
        load = loadStaple,
    }
end

-- running from commandline
if #args < 1 or not argsLookup[args[1]] then
    print("Usage:")
    for k, v in pairs(argsLookup) do
        print("staple", k)
    end
    return
end
return argsLookup[args[1]]()
