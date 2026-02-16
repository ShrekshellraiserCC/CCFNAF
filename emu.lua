---@diagnostic disable: undefined-global
periphemu.create("top", "monitor", 61, 26)
periphemu.create("left", "modem")
for i = 1, 8 do
    periphemu.create(tostring(i), "speaker")
end
