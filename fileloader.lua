-- shadow _ENV.fs.open to search all disks connected to the computer for the file

-- create a cache of filenames -> locations

---@type table<string,string>
local filePaths = {}

local function cacheDir(dir)
    for k, v in pairs(fs.list(dir)) do
        local fn = fs.combine(dir, v)
        if fs.isDir(fn) then
            cacheDir(fn)
        else
            filePaths[v] = fn
        end
    end
end

cacheDir("/")

local oldFs = fs
local newFs = setmetatable({}, { __index = oldFs })
_ENV.fs = newFs
local oldOpen = fs.open
local oldExists = fs.exists
---@diagnostic disable-next-line: duplicate-set-field
fs.open = function(path, mode)
    if filePaths[path] then
        return oldOpen(filePaths[path], mode)
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

local fn = ({ ... })[1]
assert(fs.exists(fn), "File does not exist.")
loadfile(fn, "t", _ENV)()
