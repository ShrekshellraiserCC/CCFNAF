local fn = assert(arg[1], "usage: [input]")

local f = assert(fs.open(fn, "r"))
local s = f.readAll()
f.close()

local lwz = require("lualzw")
local c = lwz.compress(s)

print("Before", #s, "After", #c)
print("Ratio:", #c / #s)
