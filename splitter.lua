--- take an input folder, an output folder pattern, and maximum folder size
--- then split the files in the input folder into equally sized output folders

if #arg < 2 then
    print("splitter input size")
    return
end

local maxSize = assert(tonumber(arg[2]), "Second argument must be a number")
local input = arg[1]

assert(fs.isDir(input), "Input must be a directory")
fs.delete("split")
fs.makeDir("split")

local fileNames = fs.list(input)
---@type {name:string,size:integer}[]
local remainingFiles = {}
for _, v in ipairs(fileNames) do
    if not fs.isDir(v) then
        -- is a file
        local size = fs.getSize(fs.combine(input, v))
        if size > maxSize then
            term.setTextColor(colors.red)
            print(("File %s too large."):format(v))
            fs.makeDir("split/too_large")
            fs.copy(fs.combine(input, v), fs.combine("split/too_large", v))
            term.setTextColor(colors.white)
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
            if folderSize + remainingFiles[i].size < maxSize then
                -- add the file
                local file = remainingFiles[i]
                folderSize = folderSize + file.size
                fs.copy(file.name, fs.combine("split", "disk" .. di, fs.getName(file.name)))
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
end
