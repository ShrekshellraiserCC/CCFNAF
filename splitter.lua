--- take an input folder, an output folder pattern, and maximum folder size
--- then split the files in the input folder into equally sized output folders

if #arg < 2 then
    print("splitter input size [-split]")
    return
end

local maxSize = assert(tonumber(arg[2]), "Second argument must be a number")
local splitSize = math.min(500000, maxSize)
local input = arg[1]
local splitFiles = arg[3] == "-split"

assert(fs.isDir(input), "Input must be a directory")
fs.delete("split")
fs.makeDir("split")

local fileNames = fs.list(input)
---@type {name:string,size:integer}[]
local remainingFiles = {}
local function splitFileIntoParts(fn, writeFiles)
    local name = fs.getName(fn)
    local size = fs.getSize(fn)
    local ofn = fs.combine("split/too_large", name)
    local f = assert(fs.open(fn, "rb"))
    local s = f.readAll() --[[@as string]]
    f.close()
    local parts = math.ceil(size / splitSize)
    local pos = 1
    local partNames = {}
    for i = 1, parts do
        local name = ofn .. ".part" .. i
        local data = s:sub(pos, pos + splitSize - 1)
        partNames[i] = { name, data }
        if writeFiles then
            local of = assert(fs.open(name, "wb"))
            of.write(data)
            of.close()
        end
        pos = pos + splitSize
    end
    return partNames
end
for _, v in ipairs(fileNames) do
    if not fs.isDir(v) then
        -- is a file
        local fn = fs.combine(input, v)
        local size = fs.getSize(fn)
        if size > splitSize and splitFiles then
            print(("Splitting file %s into parts."):format(v))
            local parts = splitFileIntoParts(fn)
            for i, v in ipairs(parts) do
                remainingFiles[#remainingFiles + 1] = {
                    name = v[1],
                    size = #v[2],
                    data = v[2]
                }
            end
        elseif size > maxSize then
            term.setTextColor(colors.red)
            print(("File %s too large."):format(v))
            fs.makeDir("split/too_large")
            term.setTextColor(colors.white)
            fs.copy(fn, fs.combine("split/too_large", v))
        else
            remainingFiles[#remainingFiles + 1] = {
                name = fs.combine(input, v),
                size = size
            }
        end
    end
end

table.sort(remainingFiles, function(a, b)
    return a.size < b.size
end)

local di = 1
while #remainingFiles > 0 do
    fs.makeDir(fs.combine("split", "disk" .. di))
    local folderSize = 0
    while true do
        local fileFit = false
        for i = #remainingFiles, 1, -1 do
            if folderSize + remainingFiles[i].size <= maxSize then
                -- add the file
                local file = remainingFiles[i]
                folderSize = folderSize + file.size
                if not file.data then
                    fs.copy(file.name, fs.combine("split", "disk" .. di, fs.getName(file.name)))
                else
                    local f = assert(fs.open(fs.combine("split", "disk" .. di, fs.getName(file.name)), "wb"))
                    f.write(file.data)
                    f.close()
                end
                table.remove(remainingFiles, i)
                fileFit = true
                break
            end
        end
        if not fileFit then
            break
        end
    end
    di = di + 1
    if di > 100 then
        error("Too many folders created, is this bugged?")
    end
end
