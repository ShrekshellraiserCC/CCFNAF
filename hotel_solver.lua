local leftstart, leftend, rightstart, rightend = 1, 512, 513, 1024
local target = 666

for i = 1, 10 do
    if target <= leftend then
        print("L")
        local oldleftend = leftend
        leftend = math.floor((leftend - leftstart) / 2) + leftstart
        rightstart = leftend + 1
        rightend = oldleftend
    else
        print("R")
        local oldrightstart = rightstart
        leftend = math.floor((rightend - rightstart) / 2) + rightstart
        rightstart = leftend + 1
        leftstart = oldrightstart
    end
    print(("%d-%d or %d-%d"):format(leftstart,leftend,rightstart,rightend))
        
end
