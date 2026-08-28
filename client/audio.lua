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

local function destroyName(name)
    local xs = sound()
    if not xs or not name then
        return
    end
    pcall(function()
        if xs:soundExists(name) then
            xs:Destroy(name)
        end
    end)
end

function Audio.Stop(rigId)
    local entry = Audio.rigs[rigId]
    if not entry then
        return
    end
    destroyName(entry.name)
    Audio.rigs[rigId] = nil
end

function Audio.StopAll()
    for rigId in pairs(Audio.rigs) do
        Audio.Stop(rigId)
    end
end

local function samePoint(a, b)
    if not a or not b then
        return false
    end
    return #(a.coords - b.coords) < 0.2
end

local function closestPoint(points, last)
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist
    local lastLive, lastDist
    for i = 1, #points do
        local dist = #(pos - points[i].coords)
        if not bestDist or dist < bestDist then
            best = points[i]
            bestDist = dist
        end
        if last and samePoint(last, points[i]) then
            lastLive = points[i]
            lastDist = dist
        end
    end
    local hysteresis = Config.AudioFollowHysteresis or 2.5
    if lastLive and lastDist and bestDist and lastDist <= bestDist + hysteresis then
        return lastLive, lastDist
    end
    return best, bestDist or 0.0
end

local function expectedElapsed(entry)
    if not entry then
        return 0
    end
    if entry.paused then
        return entry.elapsed or 0
    end
    return (entry.elapsed or 0) + math.max(0, (GetGameTimer() - (entry.receivedAt or GetGameTimer())) / 1000.0)
end

local function applyPoint(entry, point)
    local xs = sound()
    if not xs or not entry or not point or not xs:soundExists(entry.name) then
        return
    end
    local volume = DJ.Clamp(point.volume or Config.DefaultVolume, 0.0, Config.MaxVolume)
    local radius = DJ.Clamp(point.radius or Config.DefaultRadius, 1.0, Config.MaxRadius)
    pcall(function()
        xs:Position(entry.name, point.coords)
        xs:Distance(entry.name, radius + 0.0)
        xs:setVolumeMax(entry.name, volume + 0.0)
        if xs.setVolume then
            xs:setVolume(entry.name, volume + 0.0)
        end
    end)
    entry.lastPoint = point
end

local function applyPause(entry, paused)
    local xs = sound()
    if not xs or not entry or not xs:soundExists(entry.name) then
        return
    end
    pcall(function()
        if paused then
            if not xs:isPaused(entry.name) then
                xs:Pause(entry.name)
            end
        elseif xs:isPaused(entry.name) then
            xs:Resume(entry.name)
        end
    end)
end

local function seekTo(entry, stamp)
    local xs = sound()
    if not xs or not entry then
        return
    end
    stamp = math.max(0, math.floor(tonumber(stamp) or 0))
    pcall(function()
        if xs:soundExists(entry.name) then
            xs:setTimeStamp(entry.name, stamp)
        end
    end)
    entry.lastSeekAt = GetGameTimer()
end

--- One xsound stream per rig. Extra booth/group speakers only move that
--- stream to the closest emitter so every player hears the same clock.
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

    local url = state.current.url
    local name = ('lumina_%s'):format(rigId)
    local entry = Audio.rigs[rigId]
    local point = closestPoint(points, entry and entry.lastPoint)
    local volume = DJ.Clamp(point.volume or state.volume or Config.DefaultVolume, 0.0, Config.MaxVolume)
    local radius = DJ.Clamp(point.radius or state.radius or Config.DefaultRadius, 1.0, Config.MaxRadius)
    local sameTrack = entry and entry.url == url and entry.name == name

    local received = {
        url = url,
        name = name,
        points = points,
        count = #points,
        token = state.playToken,
        paused = state.paused and true or false,
        elapsed = tonumber(state.elapsed) or 0,
        receivedAt = GetGameTimer(),
        endedEvent = endedEvent,
        loop = state.loop,
        lastPoint = point,
        lastSeekAt = entry and entry.lastSeekAt or 0,
    }

    if not sameTrack then
        Audio.Stop(rigId)
        Audio.rigs[rigId] = received
        pcall(function()
            xs:PlayUrlPos(name, url, volume, point.coords, false, {
                onPlayStart = function()
                    local live = Audio.rigs[rigId]
                    if not live or live.url ~= url then
                        return
                    end
                    pcall(function()
                        xs:Distance(name, radius + 0.0)
                        xs:setVolumeMax(name, volume + 0.0)
                        if xs.setVolume then
                            xs:setVolume(name, volume + 0.0)
                        end
                        xs:destroyOnFinish(name, false)
                        -- Server owns looping so every client restarts together.
                        xs:setSoundLoop(name, false)
                        local elapsed = expectedElapsed(live)
                        if elapsed > 0.75 then
                            xs:setTimeStamp(name, math.floor(elapsed))
                            live.lastSeekAt = GetGameTimer()
                        end
                        if live.paused then
                            xs:Pause(name)
                        end
                    end)
                end,
                onPlayEnd = function()
                    local live = Audio.rigs[rigId]
                    if not live or not live.endedEvent then
                        return
                    end
                    if live.paused then
                        return
                    end
                    -- Ignore iframe failures that end in the first seconds.
                    if expectedElapsed(live) < 3.0 then
                        return
                    end
                    TriggerServerEvent(live.endedEvent, rigId, live.token)
                end,
            })
        end)
        return
    end

    entry.points = points
    entry.token = state.playToken
    entry.paused = received.paused
    entry.elapsed = received.elapsed
    entry.receivedAt = received.receivedAt
    entry.loop = state.loop
    entry.endedEvent = endedEvent
    applyPoint(entry, point)
    applyPause(entry, entry.paused)

    if state.seekTo ~= nil then
        entry.elapsed = tonumber(state.seekTo) or entry.elapsed
        entry.receivedAt = GetGameTimer()
        seekTo(entry, state.seekTo)
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
    if not xs or not entry then
        return 0, 0
    end

    local elapsed, duration = expectedElapsed(entry), 0
    pcall(function()
        if xs:soundExists(entry.name) then
            elapsed = xs:getTimeStamp(entry.name) or elapsed
            duration = xs:getMaxDuration(entry.name) or 0
        end
    end)
    return elapsed, duration
end

CreateThread(function()
    while true do
        local wait = Config.AudioFollowMs or 250
        local xs = sound()
        if xs then
            local drift = Config.AudioSyncDrift or 2.4
            local seekCd = Config.AudioSeekCooldownMs or 4500
            local now = GetGameTimer()
            for rigId, entry in pairs(Audio.rigs) do
                if entry.points and entry.points[1] then
                    applyPoint(entry, closestPoint(entry.points, entry.lastPoint))
                    pcall(function()
                        if not xs:soundExists(entry.name) then
                            return
                        end
                        xs:setSoundLoop(entry.name, false)
                        if entry.paused then
                            return
                        end
                        local actual = xs:getTimeStamp(entry.name) or 0
                        local expect = expectedElapsed(entry)
                        if actual < 0.2 then
                            return
                        end
                        if expect > 1.5 and math.abs(actual - expect) > drift then
                            if now - (entry.lastSeekAt or 0) >= seekCd then
                                xs:setTimeStamp(entry.name, math.floor(expect))
                                entry.lastSeekAt = now
                            end
                        end
                    end)
                end
            end
        else
            wait = 1000
        end
        Wait(wait)
    end
end)
