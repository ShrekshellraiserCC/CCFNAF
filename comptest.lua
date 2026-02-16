local fn = assert(arg[1], "usage: [input]")

local f = assert(fs.open(fn, "r"))
local s = f.readAll()
f.close()

local gz = require "gzdecompress"
local c = gz.decompressGZ(s)

print("Before", #s, "After", #c)
print("Ratio:", #c / #s)
