-- shadow _ENV.fs.open to search all disks connected to the computer for the file
-- loads multipart files named *.part%d+

-- create a cache of filenames -> locations

local args = { ... }
if #args < 2 then
    print("Usage: [root] [program]")
end
local fn = args[2]
local root = args[1]

---@type table<string,string|string[]>
local filePaths = {}

local multipartFilePattern = "%.part(%d+)$"
local filenamePattern = "^([%a%d_%. ]+)%.part%d+$"

local function cacheDir(dir)
    for k, v in pairs(fs.list(dir)) do
        local fn = fs.combine(dir, v)
        if fs.isDir(fn) then
            cacheDir(fn)
        else
            local partNumber = v:match(multipartFilePattern)
            if partNumber then
                partNumber = assert(tonumber(partNumber), "Invalid multipart number")
                local fullFn = assert(v:match(filenamePattern), "Failed to get filename of multipart file.")
                print(fullFn)
                filePaths[fullFn] = filePaths[fullFn] or {}
                filePaths[fullFn][partNumber] = fn
            else
                filePaths[v] = fn
            end
        end
    end
end

-- cacheDir("/")
cacheDir(root)

local function fakeFileHandle(s)
    local i = 1
    ---@type ccTweaked.fs.ReadHandle
    local t = {}
    function t.readAll()
        local ts = s:sub(i)
        i = #s
        return ts
    end

    function t.close()

    end

    function t.read(count)
        local ts = s:sub(i, i + count - 1)
        i = i + count
        return ts
    end

    return t
end

local oldFs = fs
local newFs = setmetatable({}, { __index = oldFs })
_ENV.fs = newFs
local oldOpen = fs.open
local oldExists = fs.exists
local oldSize = fs.getSize
---@diagnostic disable-next-line: duplicate-set-field
fs.open = function(path, mode)
    if filePaths[path] then
        if type(filePaths[path]) == "string" then
            return oldOpen(filePaths[path], mode)
        end
        -- this is a multipart file
        local s = {}
        for i, v in ipairs(filePaths[path]) do
            local f = assert(oldOpen(v, "rb"))
            s[i] = f.readAll()
            f.close()
        end
        return fakeFileHandle(table.concat(s, ""))
    end
    return oldOpen(path, mode)
end
---@diagnostic disable-next-line: duplicate-set-field
fs.exists = function(path)
    if filePaths[path] then
        return true
    end
    return oldExists(path)
end
---@diagnostic disable-next-line: duplicate-set-field
fs.getSize = function(path)
    if filePaths[path] then
        if type(filePaths[path]) == "string" then
            return oldSize(filePaths[path])
        end
        local s = 0
        for i, v in ipairs(filePaths[path]) do
            s = s + oldSize(v)
        end
        return s
    end
    return oldSize(path)
end

assert(fs.exists(fn), "File does not exist.")
loadfile(fn, "t", _ENV)()
