local function doYield()
    os.queueEvent("fakeEvent")
    os.pullEvent("fakeEvent")
end

---@return string
local function loadFile(filename)
    local f = fs.open(filename, "rb")
    if f then
        local read = f.readAll() or ""
        f.close()
        return read
    end
    error(("File %s does not exist."):format(filename))
end

local function shallowClone(t)
    local c = {}
    for k, v in pairs(t) do
        c[k] = v
    end
    return c
end

local audioFramerate = 6000

---Load some audio data from a file.
---Can yield, loading may take awhile
---@param filename string
---@param verbose boolean?
---@param framerate integer?
---@return table
local function loadAudio(filename, verbose, framerate)
    framerate = framerate or audioFramerate
    if verbose then
        print(("Loading audio.%s..."):format(filename))
    end
    doYield()
    local t0 = os.epoch("utc")
    -- load a dfpwm file, decode it into chunks
    local rawData = loadFile(filename)
    ---@type table[]
    local audioData = {}
    local dfpwm = require("cc.audio.dfpwm")
    local lastYieldTime = os.epoch('utc')

    local decoder = dfpwm.make_decoder()
    for i = 1, #rawData, framerate do
        audioData[#audioData + 1] = decoder(rawData:sub(i, i + framerate))
        if os.epoch("utc") > lastYieldTime + 5000 then
            lastYieldTime = os.epoch("utc")
            doYield()
        end
    end

    if verbose then
        print(("Loaded audio.%s in %.2fsec"):format(filename, (os.epoch("utc") - t0) / 1000))
    end
    return audioData
end

---Create a new audio manager, if speakers is not provided use all connected speakers
---@param speakers table<any,string|ccTweaked.peripherals.Speaker>?
local function audio(speakers)
    local self = {}

    self.defaultPriority = 1
    self.defaultVolume = 1

    --- Initialize sound system
    ---@alias SpeakerInfo {playAudio: fun(audio: table, volume: integer?): boolean}
    ---@alias BusySpeaker {peripheral: SpeakerInfo, queue: table[], priority: integer, volume: number?, rep: (fun(): boolean)|boolean|number?, original: table?}

    local speakerList = {}
    if not speakers then
        speakerList = { peripheral.find("speaker") }
    end
    ---@type table<string,SpeakerInfo>
    local availableSpeakers = {}
    ---@type table<string,BusySpeaker>
    local busySpeakers = {}

    for k, v in pairs(speakers or {}) do
        if type(v) == "string" then
            availableSpeakers[v] = peripheral.wrap(v)
        elseif type(v) == "table" then
            speakerList[#speakerList + 1] = v
        else
            error(("Invalid speaker: %s"):format(v))
        end
    end

    for k, v in pairs(speakerList) do
        availableSpeakers[peripheral.getName(v)] = v
    end

    ---@param name string
    local function tickSpeaker(name)
        local speaker = busySpeakers[name]
        local sample = table.remove(speaker.queue, 1)
        if sample then
            speaker.peripheral.playAudio(sample, speaker.volume)
            return
        end
        if speaker.rep then
            if type(speaker.rep) == "number" then
                speaker.queue = shallowClone(speaker.original)
                speaker.rep = speaker.rep - 1
                if speaker.rep > 0 then
                    return tickSpeaker(name)
                end
            elseif type(speaker.rep) == "function" then
                if speaker.rep() then
                    speaker.queue = shallowClone(speaker.original)
                    return tickSpeaker(name)
                end
            else -- boolean true fall through
                speaker.queue = shallowClone(speaker.original)
                return tickSpeaker(name)
            end
        end
        busySpeakers[name] = nil
        availableSpeakers[name] = speaker.peripheral
    end

    ---Find a channel to overwrite with the given audio
    ---@param data table
    ---@param volume number?
    ---@param priority integer?
    ---@return string|nil
    local function overwriteSpeaker(data, volume, priority)
        for speakerName, v in pairs(busySpeakers) do
            if v.priority < priority then
                -- overwrite this sound
                for i, sample in ipairs(data) do
                    v.queue[i] = sample
                end
                v.volume = volume or self.defaultVolume
                v.priority = priority or self.defaultPriority
                tickSpeaker(speakerName)
                return speakerName
            end
        end
    end

    ---Play some audio, returns speaker it was played on if successful, otherwise returns nothing
    ---@param data table
    ---@param volume number?
    ---@param priority integer?
    ---@param rep (fun(): boolean)|boolean|integer?
    ---@return string|nil speaker
    function self.playAudio(data, volume, priority, rep)
        priority = priority or self.defaultPriority
        volume = volume or self.defaultVolume
        local speakerName, speaker = next(availableSpeakers)
        if speaker and speakerName then
            availableSpeakers[speakerName] = nil
            busySpeakers[speakerName] = {
                peripheral = speaker,
                queue = shallowClone(data),
                priority = priority,
                volume = volume,
                rep = rep
            }
            if rep then
                busySpeakers[speakerName].original = data
            end
            tickSpeaker(speakerName)
            return speakerName
        elseif not rep then
            return overwriteSpeaker(data, volume, priority)
        end
    end

    ---Cancel the audio playing on a given speaker
    ---@param speakerName string
    function self.cancelAudio(speakerName)
        local info = busySpeakers[speakerName]
        if info then
            availableSpeakers[speakerName] = info.peripheral
            busySpeakers[speakerName] = nil
        end
    end

    ---Start ticking the sound system
    function self.start()
        while true do
            local name, speaker = os.pullEvent("speaker_audio_empty")
            local playingSpeaker = busySpeakers[speaker]
            if playingSpeaker then
                tickSpeaker(speaker)
            end
        end
    end

    return self
end

return {
    new = audio,
    loadAudio = loadAudio
}
