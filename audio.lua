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
        if os.epoch("utc") > lastYieldTime + 1000 then
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
    ---@alias SpeakerInfo ccTweaked.peripherals.Speaker
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

    local function setSpeakerBusy(name, speaker, data, volume, priority, rep)
        availableSpeakers[name] = nil
        local bs = {
            peripheral = speaker,
            queue = shallowClone(data),
            priority = priority,
            volume = volume,
            rep = rep
        }
        busySpeakers[name] = bs
        if rep then
            busySpeakers[name].original = data
        end
        return bs
    end
    ---Find a channel to overwrite with the given audio, rep not supported
    ---@param data table
    ---@param volume number?
    ---@param priority integer?
    ---@return BusySpeaker?
    local function overwriteSpeaker(data, volume, priority)
        for speakerName, v in pairs(busySpeakers) do
            if v.priority < priority then
                local bs = setSpeakerBusy(speakerName, v.peripheral, data, volume, priority, nil)
                tickSpeaker(speakerName)
                return bs
            end
        end
    end

    local function stopSpeaker(name)
        local info = busySpeakers[name]
        if info then
            info.peripheral.stop()
            availableSpeakers[name] = info.peripheral
            busySpeakers[name] = nil
        end
    end

    ---@param speaker BusySpeaker
    local function stopBusySpeaker(speaker)
        local name = peripheral.getName(speaker.peripheral)
        if busySpeakers[name] == speaker then
            stopSpeaker(name)
        end
    end
    ---Play some audio, returns speaker it was played on if successful, otherwise returns nothing
    ---@param data table
    ---@param volume number?
    ---@param priority integer?
    ---@param rep (fun(): boolean)|boolean|integer?
    ---@return BusySpeaker? handle
    function self.playAudio(data, volume, priority, rep)
        priority = priority or self.defaultPriority
        volume = volume or self.defaultVolume
        local speakerName, speaker = next(availableSpeakers)
        if speaker and speakerName then
            local bs = setSpeakerBusy(speakerName, speaker, data, volume, priority, rep)
            tickSpeaker(speakerName)
            return bs
        elseif not rep then
            return overwriteSpeaker(data, volume, priority)
        end
    end

    ---Cancel the audio playing on a given speaker
    ---@param handle BusySpeaker
    function self.cancelAudio(handle)
        stopBusySpeaker(handle)
    end

    function self.stopAllAudio()
        for k, v in pairs(busySpeakers) do
            stopSpeaker(k)
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
