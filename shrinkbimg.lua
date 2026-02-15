local engine = require("engine")

local outputDir = "resources"


local function convert(input)
    local fn = fs.getName(input)
    local img = engine.loadTexture(input, true)

    local ofn = fs.combine(outputDir, fn) .. ".lwz"
    engine.saveTexture(ofn, img, true)
end
for i, fn in ipairs(fs.list("converted")) do
    if fn:sub(-5) == ".bimg" then
        convert(fs.combine("converted", fn))
    end
end
