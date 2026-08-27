Audio = {
    rigs = {},
}

local xSound

local function sound()
    if GetResourceState('xsound') ~= 'started' then
        return nil
    end
    xSound = xSound or exports.xsound
    return xSound
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

function Audio.Stop(rigId)
    local entry = Audio.rigs[rigId]
    if not entry then
        return
    end
    destroyNames(entry.names)
    Audio.rigs[rigId] = nil
end

function Audio.StopAll()
    for rigId in pairs(Audio.rigs) do
        Audio.Stop(rigId)
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

local function applyMix(entry)
    local xs = sound()
    if not xs then
        return
    end
    for i = 1, #entry.names do
        local name = entry.names[i]
        local point = entry.points and entry.points[i]
        pcall(function()
            if xs:soundExists(name) and point then
                xs:Distance(name, (point.radius or Config.DefaultRadius) + 0.0)
                xs:setVolumeMax(name, (point.volume or Config.DefaultVolume) + 0.0)
            end
        end)
    end
end

--- points = { { coords = vector3, volume = n, radius = n } }
function Audio.ApplyRig(rigId, points, state, endedEvent)
    local xs = sound()
    if not xs then
        return
    end

    if not rigId or not state or not state.current or not state.current.url or not points or #points == 0 then
        Audio.Stop(rigId)
        return
    end

    if xs.isPlayerInStreamerMode and xs:isPlayerInStreamerMode() then
        Audio.Stop(rigId)
        return
    end

    local entry = Audio.rigs[rigId]
    local url = state.current.url
    local sameTrack = entry and entry.url == url and entry.count == #points

    if not sameTrack then
        Audio.Stop(rigId)
        local names = {}
        for i = 1, #points do
            local name = ('djbooth_%s_%s'):format(rigId, i)
            names[i] = name
            local point = points[i]
            local volume = DJ.Clamp(point.volume or state.volume or Config.DefaultVolume, 0.0, Config.MaxVolume)
            local radius = DJ.Clamp(point.radius or state.radius or Config.DefaultRadius, 1.0, Config.MaxRadius)
            pcall(function()
                xs:PlayUrlPos(name, url, volume, point.coords, false, {
                    onPlayStart = function()
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
                        if endedEvent then
                            TriggerServerEvent(endedEvent, rigId, state.playToken)
                        end
                    end,
                })
            end)
        end

        Audio.rigs[rigId] = {
            url = url,
            names = names,
            points = points,
            count = #points,
            token = state.playToken,
        }
        return
    end

    entry.token = state.playToken
    entry.points = points
    applyMix(entry)
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

local function boothPoints(booth, state)
    local volume = DJ.Clamp(state.volume or booth.volume or Config.DefaultVolume, 0.0, Config.MaxVolume)
    local radius = DJ.Clamp(state.radius or booth.radius or Config.DefaultRadius, Config.MinRadius, Config.MaxRadius)
    local points = {
        { coords = DJ.ToVector3(booth.coords), volume = volume, radius = radius },
    }
    if booth.speakers then
        for i = 1, #booth.speakers do
            points[#points + 1] = {
                coords = DJ.ToVector3(booth.speakers[i]),
                volume = volume,
                radius = radius,
            }
        end
    end
    return points
end

function Audio.Apply(booth, state)
    if not booth then
        return
    end
    Audio.ApplyRig(booth.id, boothPoints(booth, state or {}), state, 'djbooth:trackEnded')
end

function Audio.Timestamp(rigId)
    local xs = sound()
    local entry = Audio.rigs[rigId]
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
