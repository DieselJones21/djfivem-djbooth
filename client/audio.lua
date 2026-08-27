Audio = {
    booths = {},
}

local xSound

local function sound()
    if GetResourceState('xsound') ~= 'started' then
        return nil
    end
    xSound = xSound or exports.xsound
    return xSound
end

local function soundName(boothId, index)
    return ('djbooth_%s_%s'):format(boothId, index)
end

local function positionsFor(booth)
    local points = {}
    points[#points + 1] = DJ.ToVector3(booth.coords)
    if booth.speakers then
        for i = 1, #booth.speakers do
            points[#points + 1] = DJ.ToVector3(booth.speakers[i])
        end
    end
    return points
end

local function destroyNames(names)
    local xs = sound()
    if not xs or not names then
        return
    end
    for i = 1, #names do
        pcall(function()
            if xs:soundExists(names[i]) then
                xs:Destroy(names[i])
            end
        end)
    end
end

function Audio.Stop(boothId)
    local entry = Audio.booths[boothId]
    if not entry then
        return
    end
    destroyNames(entry.names)
    Audio.booths[boothId] = nil
end

function Audio.StopAll()
    for boothId in pairs(Audio.booths) do
        Audio.Stop(boothId)
    end
end

local function applyPause(entry, paused)
    local xs = sound()
    if not xs then
        return
    end
    for i = 1, #entry.names do
        local name = entry.names[i]
        pcall(function()
            if not xs:soundExists(name) then
                return
            end
            if paused then
                if not xs:isPaused(name) then
                    xs:Pause(name)
                end
            else
                if xs:isPaused(name) then
                    xs:Resume(name)
                end
            end
        end)
    end
end

local function applyVolumeAndDistance(entry, volume, radius)
    local xs = sound()
    if not xs then
        return
    end
    for i = 1, #entry.names do
        local name = entry.names[i]
        pcall(function()
            if xs:soundExists(name) then
                xs:Distance(name, radius + 0.0)
                xs:setVolumeMax(name, volume + 0.0)
            end
        end)
    end
end

function Audio.Apply(booth, state)
    local xs = sound()
    if not xs then
        return
    end

    if not booth or not state or not state.current or not state.current.url then
        Audio.Stop(booth and booth.id)
        return
    end

    if xs.isPlayerInStreamerMode and xs:isPlayerInStreamerMode() then
        Audio.Stop(booth.id)
        return
    end

    local entry = Audio.booths[booth.id]
    local url = state.current.url
    local volume = DJ.Clamp(state.volume or booth.volume or Config.DefaultVolume, 0.0, Config.MaxVolume)
    local radius = DJ.Clamp(state.radius or booth.radius or Config.DefaultRadius, Config.MinRadius, Config.MaxRadius)
    local points = positionsFor(booth)

    local sameTrack = entry and entry.url == url
    if not sameTrack then
        Audio.Stop(booth.id)
        local names = {}
        local started = 0

        for i = 1, #points do
            local name = soundName(booth.id, i)
            names[i] = name
            pcall(function()
                xs:PlayUrlPos(name, url, volume, points[i], false, {
                    onPlayStart = function()
                        started = started + 1
                        pcall(function()
                            xs:Distance(name, radius + 0.0)
                            xs:setVolumeMax(name, volume + 0.0)
                            xs:destroyOnFinish(name, false)
                            xs:setSoundLoop(name, state.loop == 'track')
                            local elapsed = tonumber(state.elapsed) or 0
                            if elapsed > 1 then
                                xs:setTimeStamp(name, math.floor(elapsed))
                            end
                            if state.paused then
                                xs:Pause(name)
                            end
                        end)
                    end,
                    onPlayEnd = function()
                        TriggerServerEvent('djbooth:trackEnded', booth.id, state.playToken)
                    end,
                })
            end)
        end

        Audio.booths[booth.id] = {
            url = url,
            names = names,
            token = state.playToken,
        }
        return
    end

    entry.token = state.playToken
    applyVolumeAndDistance(entry, volume, radius)
    applyPause(entry, state.paused and true or false)

    if state.seekTo then
        for i = 1, #entry.names do
            pcall(function()
                if xs:soundExists(entry.names[i]) then
                    xs:setTimeStamp(entry.names[i], math.floor(state.seekTo))
                end
            end)
        end
    end
end

function Audio.Timestamp(boothId)
    local xs = sound()
    local entry = Audio.booths[boothId]
    if not xs or not entry or not entry.names[1] then
        return 0, 0
    end

    local elapsed, duration = 0, 0
    pcall(function()
        if xs:soundExists(entry.names[1]) then
            elapsed = xs:getTimeStamp(entry.names[1]) or 0
            duration = xs:getMaxDuration(entry.names[1]) or 0
        end
    end)
    return elapsed, duration
end
